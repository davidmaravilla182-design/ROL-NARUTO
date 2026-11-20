class_name PajaroPapel
extends Node3D
## Pájaro de papel mensajero (modelo de Meshy desde la imagen de GPT: assets/modelos/pajaro_papel.glb).
## Entra volando desde lo alto, revolotea junto al hombro del jugador mientras se lee la escena y se va.
## Las alas aletean en el shader (toon_tex con aleteo): los vértices más allá del cuerpo giran alrededor de su eje.

const RUTA := "res://assets/modelos/pajaro_papel.glb"
var objetivo: Node3D          # el jugador
var duracion := 4.0
var _t := 0.0
var _desde := Vector3.ZERO
var _modelo: Node3D
var _se_va := false


static func disponible() -> bool:
	return ResourceLoader.exists(RUTA)


func construir(jugador: Node3D, dur: float) -> void:
	objetivo = jugador
	duracion = dur
	_modelo = Node3D.new()
	add_child(_modelo)
	_modelo.scale = Vector3.ONE * float(Datos.graficos.get("pajaro_escala", 1.4))
	var mi := MeshInstance3D.new()
	mi.mesh = Kit.malla("pajaro_papel")
	mi.material_override = Shaders.toon_tex_aleteo("pajaro_papel", float(Datos.graficos.get("pajaro_ala_inicio", 0.12)))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_modelo.add_child(mi)
	var luz := OmniLight3D.new()   # bordes que brillan un poco (como en la imagen)
	luz.light_color = Color(0.85, 0.7, 1.0)
	luz.light_energy = 0.6
	luz.omni_range = 2.5
	_modelo.add_child(luz)
	_desde = Vector3.INF   # se calcula en el primer cuadro (ya dentro del árbol)


func _punto_hombro() -> Vector3:
	if objetivo == null or not is_instance_valid(objetivo) or not objetivo.is_inside_tree():
		return global_position
	return objetivo.global_position + objetivo.global_transform.basis.x * 1.1 + Vector3(0, 2.3, 0)


func _process(d: float) -> void:
	var hombro := _punto_hombro()
	if _desde == Vector3.INF:
		_desde = hombro + Vector3(-14.0, 11.0, -10.0)
		global_position = _desde
		return
	_t += d
	var pos: Vector3
	if _t < 1.2:
		# Llega en curva (cae desde lo alto y frena).
		var u := 1.0 - pow(1.0 - _t / 1.2, 3.0)
		pos = _desde.lerp(hombro, u) + Vector3(0, sin(u * PI) * 2.5, 0)
	elif _t < duracion:
		pos = hombro + Vector3(sin(_t * 1.3) * 0.25, sin(_t * 2.6) * 0.15, cos(_t * 1.3) * 0.25)
	else:
		_se_va = true
		var v := _t - duracion
		pos = hombro + Vector3(v * 6.0, v * v * 4.0 + v * 3.0, -v * 8.0)
		if v > 2.5:
			queue_free()
			return
	var dir := pos - global_position
	global_position = pos
	if dir.length() > 0.002:
		var mirar := Vector3(dir.x, dir.y * 0.4, dir.z)
		if mirar.length() > 0.001:
			var b := Basis.looking_at(-mirar.normalized(), Vector3.UP)   # el frente del modelo es +Z
			_modelo.global_basis = _modelo.global_basis.slerp(b, minf(1.0, d * 6.0))
	# Aleteo más rápido al volar, lento al revolotear.
	var m := (_modelo.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	m.set_shader_parameter("aleteo_t", _t * (13.0 if (_t < 1.2 or _se_va) else 8.0))
