class_name PergaminoSuelo
extends Node3D
## Pergamino ganado en una misión (modelo de Meshy desde la imagen de GPT: assets/modelos/pergamino.glb).
## Cae girando delante del jugador, flota sobre un círculo de luz lila y, al acercarse (o tras un rato),
## vuela hasta el jugador y se deshace en papel: «Aprendiste: <jutsu>».

signal recogido(nombre: String)

const RADIO_RECOGER := 1.4
const ESPERA_MAX := 45.0
var jugador: Node3D
var nombre_jutsu := ""
var _t := 0.0
var _suelo := Vector3.ZERO
var _modelo: Node3D
var _circulo: MeshInstance3D
var _luz: OmniLight3D
var _volando := -1.0


static func disponible() -> bool:
	return ResourceLoader.exists("res://assets/modelos/pergamino.glb")


func construir(j: Node3D, pos_suelo: Vector3, nombre: String) -> void:
	jugador = j
	nombre_jutsu = nombre
	_suelo = pos_suelo
	_modelo = Node3D.new()
	add_child(_modelo)
	var pm := Kit.instancia("pergamino", Transform3D.IDENTITY, false)
	pm.scale = Vector3.ONE * 3.0
	pm.position.y = -0.18   # centro del modelo en el pivote (gira sobre sí mismo)
	_modelo.add_child(pm)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(0.8, 0.6, 1.0)
	_luz.light_energy = 1.6
	_luz.omni_range = 3.0
	add_child(_luz)
	# Círculo de luz en el suelo (sello) que late.
	_circulo = MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.75
	disco.bottom_radius = 0.75
	disco.height = 0.01
	disco.radial_segments = 32
	_circulo.mesh = disco
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.75, 0.5, 1.0, 0.35)
	_circulo.material_override = mat
	_circulo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_circulo)


func _process(d: float) -> void:
	if _modelo == null:
		return
	_t += d
	if _volando < 0.0:
		# Cae desde arriba girando y se queda flotando.
		var caida := clampf(_t / 0.9, 0.0, 1.0)
		var alto := lerpf(4.0, 0.75, 1.0 - pow(1.0 - caida, 3.0)) + sin(_t * 2.2) * 0.08 * caida
		global_position = _suelo + Vector3(0, alto, 0)
		_circulo.global_position = _suelo + Vector3(0, 0.03, 0)
		var pulso := 1.0 + sin(_t * 3.0) * 0.08
		_circulo.scale = Vector3(pulso, 1, pulso) * caida
		_modelo.rotation = Vector3(0.25, _t * 1.4, 0)
		_luz.light_energy = 1.6 + sin(_t * 3.0) * 0.4
		var cerca := jugador != null and is_instance_valid(jugador) and jugador.is_inside_tree() \
			and Vector2(jugador.global_position.x - _suelo.x, jugador.global_position.z - _suelo.z).length() < RADIO_RECOGER
		if (_t > 1.0 and cerca) or _t > ESPERA_MAX:
			_volando = 0.0
			recogido.emit(nombre_jutsu)
		return
	# Vuela al pecho del jugador, se encoge y se deshace.
	_volando += d
	var u := clampf(_volando / 0.45, 0.0, 1.0)
	var destino := _suelo + Vector3(0, 1.2, 0)
	if jugador != null and is_instance_valid(jugador) and jugador.is_inside_tree():
		destino = jugador.global_position + Vector3(0, 1.2, 0)
	global_position = global_position.lerp(destino, u)
	_modelo.rotation.y += d * 14.0
	_modelo.scale = Vector3.ONE * (1.0 - u * 0.9)
	_circulo.scale = Vector3.ONE * (1.0 - u)
	_luz.light_energy = 3.0 * (1.0 - u)
	if u >= 1.0:
		queue_free()
