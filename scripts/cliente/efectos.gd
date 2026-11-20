class_name Efectos
extends Node3D
## Efectos visuales del cliente. Cada nivel de poder escala tamaño, partículas,
## luz, sacudida de cámara y marcas en el suelo según /data/jutsus.json.

const COLOR_FUEGO := Color(1.0, 0.45, 0.08)
const COLOR_FUEGO_NUCLEO := Color(1.0, 0.85, 0.35)
const COLOR_RAYO := Color(0.55, 0.85, 1.0)
const COLOR_RAYO_NUCLEO := Color(0.92, 0.97, 1.0)
const COLOR_AGUA := Color(0.35, 0.6, 1.0)
const MAX_MARCAS := 24

var camara: CamaraTercera
var escenario: Escenario
var sonidos: Sonidos
var _mult_particulas := 1.0
var _marcas: Array = []
var _segmento_malla: BoxMesh


func _ready() -> void:
	_segmento_malla = BoxMesh.new()
	_segmento_malla.size = Vector3(1, 1, 1)
	_mult_particulas = float(Ajustes.g("particulas", 1.0))


# ------------------------------------------------------------ utilidades

## Crea un sistema de partículas GPU configurable.
func particulas(cfg: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.add_to_group("particulas")
	p.amount = maxi(int(float(cfg.get("cantidad", 20)) * _mult_particulas), 1)
	p.lifetime = float(cfg.get("vida", 0.6))
	p.one_shot = bool(cfg.get("una_vez", false))
	p.explosiveness = float(cfg.get("explosividad", 0.0))
	p.local_coords = bool(cfg.get("local", false))
	p.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = float(cfg.get("radio", 0.1))
	pm.direction = cfg.get("direccion", Vector3.UP)
	pm.spread = float(cfg.get("dispersion", 180.0))
	pm.initial_velocity_min = float(cfg.get("vel_min", 1.0))
	pm.initial_velocity_max = float(cfg.get("vel_max", 3.0))
	pm.gravity = cfg.get("gravedad", Vector3.ZERO)
	pm.damping_min = float(cfg.get("frenado", 0.0))
	pm.damping_max = float(cfg.get("frenado", 0.0))
	pm.scale_min = float(cfg.get("tam_min", 0.2))
	pm.scale_max = float(cfg.get("tam_max", 0.4))
	var curva := Curve.new()
	curva.add_point(Vector2(0, float(cfg.get("escala_inicio", 0.6))))
	curva.add_point(Vector2(0.3, 1.0))
	curva.add_point(Vector2(1, float(cfg.get("escala_fin", 0.0))))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	var g := Gradient.new()
	var c0: Color = cfg.get("color", Color.WHITE)
	var c1: Color = cfg.get("color_fin", Color(c0.r, c0.g, c0.b, 0.0))
	g.set_color(0, c0)
	g.set_color(1, c1)
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = cfg.get("tam_quad", Vector2(1, 1))
	q.material = Materiales.particula(Color.WHITE, bool(cfg.get("aditivo", true)))
	if cfg.has("estirado"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		pm.particle_flag_align_y = true
		q.material = m
	p.draw_pass_1 = q
	return p


## Lanza una ráfaga de partículas en un punto y la borra al terminar.
func rafaga(pos: Vector3, cfg: Dictionary) -> void:
	cfg["una_vez"] = true
	if not cfg.has("explosividad"):
		cfg["explosividad"] = 0.9
	var p := particulas(cfg)
	add_child(p)
	p.global_position = pos
	p.emitting = true
	_borrar_en(p, p.lifetime + 0.3)


func luz_temporal(pos: Vector3, color: Color, energia: float, rango: float, duracion: float) -> void:
	if energia <= 0.0:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energia
	l.omni_range = rango
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, duracion).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


func _borrar_en(n: Node, segundos: float) -> void:
	# Tween ligado a este nodo: si la escena se descarga, se cancela sin errores.
	var tw := create_tween()
	tw.tween_interval(segundos)
	tw.tween_callback(n.queue_free)


var _sacudidas: Array = []   # instantes (ms) de las últimas sacudidas aceptadas


## Temblor de cámara con límite: como máximo N sacudidas por ventana y un trauma total acotado
## (data/graficos.json → limites). Las explosiones se ven igual; solo se recorta el temblor sobrante.
func sacudir_desde(pos: Vector3, fuerza: float) -> void:
	if camara == null or fuerza <= 0.0:
		return
	var lim: Dictionary = Datos.graficos.get("limites", {})
	var ahora := Time.get_ticks_msec()
	var ventana := int(float(lim.get("ventana", 0.6)) * 1000.0)
	while not _sacudidas.is_empty() and ahora - int(_sacudidas[0]) > ventana:
		_sacudidas.pop_front()
	if _sacudidas.size() >= int(lim.get("sacudidas", 3)):
		return
	_sacudidas.append(ahora)
	var d := camara.global_position.distance_to(pos)
	camara.sacudir(fuerza * clampf(1.4 - d / 30.0, 0.25, 1.0), float(lim.get("trauma_max", 0.9)))


## Marca en el suelo (quemadura o grietas) que se desvanece.
func marca_suelo(pos: Vector3, radio: float, color: Color, grietas := false) -> void:
	if radio <= 0.0:
		return
	var nodo := Node3D.new()
	add_child(nodo)
	nodo.global_position = Vector3(pos.x, 0.02 + _marcas.size() * 0.0015, pos.z)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = Materiales.textura_suave()
	mat.albedo_color = color
	mat.disable_receive_shadows = true
	var disco := Materiales.plano_suelo(radio, mat)
	nodo.add_child(disco)
	if grietas:
		# Grietas radiales oscuras con brillo residual.
		var mat_g := Materiales.solido(Color(0.04, 0.04, 0.05), 0.9)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var n := 5 + int(radio * 2.0)
		for i in n:
			var a := rng.randf() * TAU
			var largo := radio * rng.randf_range(0.5, 1.1)
			var g := MeshInstance3D.new()
			g.mesh = _segmento_malla
			g.material_override = mat_g
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.scale = Vector3(rng.randf_range(0.03, 0.06), 0.01, largo * 0.8)
			g.rotation = Vector3(0, a, 0)
			g.position = Vector3(sin(a), 0, cos(a)) * largo * 0.5 + Vector3(0, 0.004, 0)
			nodo.add_child(g)
	_marcas.append(nodo)
	if _marcas.size() > MAX_MARCAS:
		var vieja: Node = _marcas.pop_front()
		if is_instance_valid(vieja):
			vieja.queue_free()
	var tw := create_tween()
	tw.tween_interval(10.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 4.0)
	tw.tween_callback(func():
		_marcas.erase(nodo)
		if is_instance_valid(nodo):
			nodo.queue_free())


## Línea quebrada (rayo) entre dos puntos usando segmentos de caja.
func rayo_zigzag(padre: Node3D, desde: Vector3, hasta: Vector3, grosor: float, mat: Material, saltos := 6, desvio := 0.3) -> Array:
	var segs: Array = []
	var puntos: Array = [desde]
	for i in range(1, saltos):
		var t := float(i) / saltos
		var p := desde.lerp(hasta, t) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * desvio
		puntos.append(p)
	puntos.append(hasta)
	for i in puntos.size() - 1:
		var a: Vector3 = puntos[i]
		var b: Vector3 = puntos[i + 1]
		var largo := a.distance_to(b)
		if largo < 0.001:
			continue
		var s := MeshInstance3D.new()
		s.mesh = _segmento_malla
		s.material_override = mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		padre.add_child(s)
		s.global_position = (a + b) * 0.5
		var arriba := Vector3.UP if absf((b - a).normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		s.look_at(b, arriba)
		s.scale = Vector3(grosor, grosor, largo)
		segs.append(s)
	return segs


# ------------------------------------------------------------ proyectiles

func _sonido(nombre: String, vol := 0.0, tono := 1.0) -> void:
	if sonidos != null:
		sonidos.tocar(nombre, vol, tono)


## Esfera de fuego con shader de ruido (núcleo brillante, cuerpo naranja, borde rojo).
func esfera_fuego(radio: float, intensidad := 3.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radio
	sm.height = radio * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	var mat := Shaders.material("fuego")
	mat.set_shader_parameter("intensidad", intensidad)
	mat.set_shader_parameter("escala_ruido", 1.0 / maxf(radio, 0.1))
	mat.set_shader_parameter("desplazamiento", 0.22)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Visual de un proyectil del servidor. Devuelve el nodo que el cliente moverá.
func crear_proyectil(datos: Dictionary) -> Node3D:
	var jutsu := str(datos["jutsu"])
	var nivel := int(datos["nivel"])
	var radio := float(datos["radio"])
	var nd := Datos.nivel_jutsu(jutsu, nivel)
	var nodo := Node3D.new()
	add_child(nodo)
	nodo.global_position = datos["pos"]
	if jutsu == "bola_fuego":
		var cuerpo := esfera_fuego(radio, 1.05 + nivel * 0.08)
		nodo.add_child(cuerpo)
		var nucleo := Materiales.esfera(radio * 0.3, Materiales.emisivo(COLOR_FUEGO_NUCLEO, 1.6 + nivel * 0.2), 12)
		nodo.add_child(nucleo)
		if Ajustes.g("distorsion_calor", false):
			var calor := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = radio * 1.6
			sm.height = radio * 3.2
			sm.radial_segments = 16
			sm.rings = 8
			calor.mesh = sm
			var mat_calor := Shaders.material("calor")
			mat_calor.render_priority = -1
			calor.material_override = mat_calor
			calor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			nodo.add_child(calor)
		var llamas := particulas({
			"cantidad": mini(int(nd.get("particulas", 40)), 90), "vida": 0.4 + nivel * 0.15, "radio": radio * 0.8,
			"vel_min": 0.5, "vel_max": 1.5 + nivel, "dispersion": 180.0, "gravedad": Vector3(0, 3.0, 0),
			"tam_min": radio * 0.4, "tam_max": radio * 0.9, "color": Color(1.0, 0.5, 0.12, 0.3), "color_fin": Color(0.6, 0.08, 0.0, 0.0),
		})
		nodo.add_child(llamas)
		llamas.emitting = true
		var humo := particulas({
			"cantidad": maxi(int(nd.get("particulas", 40)) / 3, 10), "vida": 1.4, "radio": radio,
			"vel_min": 0.2, "vel_max": 1.0, "gravedad": Vector3(0, 1.8, 0), "tam_min": radio * 0.9, "tam_max": radio * 2.0,
			"color": Color(0.12, 0.1, 0.1, 0.4), "aditivo": false, "escala_inicio": 0.4, "escala_fin": 1.0,
		})
		nodo.add_child(humo)
		humo.emitting = true
		var brasas := particulas({
			"cantidad": 20 + nivel * 30, "vida": 0.9, "radio": radio, "vel_min": 1.5, "vel_max": 4.0 + nivel * 2.0,
			"gravedad": Vector3(0, -3, 0), "tam_min": 0.04, "tam_max": 0.09, "color": Color(1, 0.75, 0.3), "escala_fin": 0.2,
		})
		nodo.add_child(brasas)
		brasas.emitting = true
		var luz := OmniLight3D.new()
		luz.light_color = COLOR_FUEGO
		luz.light_energy = float(nd.get("luz", 3.0))
		luz.omni_range = float(nd.get("luz_rango", 6.0))
		nodo.add_child(luz)
		nodo.set_meta("pulso", nucleo)
		_sonido("fuego", -2.0 + nivel * 2.0, 1.2 - nivel * 0.15)
	else:
		var gota := Materiales.esfera(radio, Materiales.emisivo(COLOR_AGUA, 0.9), 10)
		nodo.add_child(gota)
		var brillo := Materiales.esfera(radio * 1.4, Materiales.transparente(Color(0.5, 0.75, 1.0, 0.25), true), 10)
		nodo.add_child(brillo)
		var estela := particulas({
			"cantidad": int(nd.get("particulas", 20)), "vida": 0.3, "radio": radio * 0.5,
			"vel_min": 0.1, "vel_max": 0.6, "tam_min": radio * 0.5, "tam_max": radio * 0.8, "color": Color(0.4, 0.65, 1.0, 0.35),
		})
		nodo.add_child(estela)
		estela.emitting = true
		_sonido("agua", -8.0, 1.5)
	return nodo


func explosion(ev: Dictionary) -> void:
	var jutsu := str(ev["jutsu"])
	var nivel := int(ev["nivel"])
	var nd := Datos.nivel_jutsu(jutsu, nivel)
	var pos: Vector3 = ev["pos"]
	var r := float(ev["radio"])
	if jutsu == "bola_fuego":
		# Bola de fuego que se expande y se apaga (shader de ruido).
		var bola := esfera_fuego(r * 0.4, 1.15 + nivel * 0.1)
		add_child(bola)
		bola.global_position = pos
		var mat: ShaderMaterial = bola.material_override
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(bola, "scale", Vector3.ONE * 2.2, 0.55 + nivel * 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw.tween_method(func(v): mat.set_shader_parameter("opacidad", v), 1.0, 0.0, 0.6 + nivel * 0.2).set_delay(0.1)
		tw.chain().tween_callback(bola.queue_free)
		var cant := int(nd.get("particulas", 40))
		rafaga(pos, {"cantidad": mini(cant, 100), "vida": 0.5 + nivel * 0.2, "radio": r * 0.3, "vel_min": r * 1.0, "vel_max": r * 2.4,
			"frenado": r * 2.0, "tam_min": r * 0.25, "tam_max": r * 0.5, "color": Color(1.0, 0.45, 0.1, 0.28), "color_fin": Color(0.5, 0.05, 0.0, 0.0)})
		rafaga(pos, {"cantidad": cant, "vida": 1.8 + nivel * 0.5, "radio": r * 0.5, "vel_min": 0.5, "vel_max": r * 0.7,
			"gravedad": Vector3(0, 2.0, 0), "tam_min": r * 0.5, "tam_max": r * 1.1, "color": Color(0.1, 0.09, 0.09, 0.5), "aditivo": false,
			"explosividad": 0.6, "escala_inicio": 0.3, "escala_fin": 1.0})
		rafaga(pos, {"cantidad": 20 + cant / 2, "vida": 1.3, "radio": r * 0.2, "vel_min": 4.0, "vel_max": 9.0 + nivel * 4.0,
			"gravedad": Vector3(0, -9, 0), "tam_min": 0.05, "tam_max": 0.12, "color": Color(1, 0.75, 0.3), "escala_fin": 0.3})
		if nivel >= 3:
			var suelo: Vector3 = ev["suelo"]
			rafaga(suelo + Vector3(0, 0.3, 0), {"cantidad": 90, "vida": 0.9, "radio": 0.5, "direccion": Vector3(1, 0, 0), "dispersion": 180.0,
				"vel_min": 10.0, "vel_max": 16.0, "frenado": 10.0, "tam_min": 0.7, "tam_max": 1.3, "color": Color(1.0, 0.45, 0.1, 0.35)})
			for i in 6:
				var a := TAU * i / 6.0
				var llama := esfera_fuego(0.6, 2.5)
				add_child(llama)
				llama.global_position = suelo + Vector3(cos(a), 0.3, sin(a)) * r * 0.45
				llama.scale = Vector3(1.0, 1.8, 1.0)
				var tw2 := create_tween()
				tw2.tween_interval(3.0)
				tw2.tween_property(llama, "scale", Vector3(0.01, 0.01, 0.01), 1.0)
				tw2.tween_callback(llama.queue_free)
			if escenario != null:
				escenario.destello(COLOR_FUEGO, 2.0, 0.8)
		luz_temporal(pos, COLOR_FUEGO, float(nd.get("luz", 3.0)) * 1.6, float(nd.get("luz_rango", 6.0)) * 1.3, 0.5 + nivel * 0.3)
		sacudir_desde(pos, float(nd.get("sacudida", 0.3)))
		marca_suelo(ev["suelo"], float(nd.get("marca", 1.0)) * float(ev.get("escala", 1.0)), Color(0.05, 0.03, 0.02, 0.85))
		_sonido("explosion", -6.0 + nivel * 3.0, 1.15 - nivel * 0.12)
	else:
		rafaga(pos, {"cantidad": 24, "vida": 0.5, "radio": 0.2, "vel_min": 2.0, "vel_max": 5.0, "gravedad": Vector3(0, -9, 0),
			"tam_min": 0.05, "tam_max": 0.12, "color": Color(0.6, 0.8, 1.0, 0.8)})
		sacudir_desde(pos, float(nd.get("sacudida", 0.1)))
		_sonido("chapoteo", -4.0, 0.8)


# ------------------------------------------------------------ rayo (embiste)

## Carga del rayo en la mano: rayos ramificados, chispas, luz y sonido de "pájaros".
func crear_carga_rayo(pv: PersonajeVisual, nivel: int) -> Node3D:
	var nd := Datos.nivel_jutsu("chidori", nivel)
	var nodo := CargaRayo.new()
	nodo.efectos = self
	nodo.nivel = nivel
	nodo.datos = nd
	pv.mano_derecha().add_child(nodo)
	nodo.position = Vector3(0, -0.08, 0.03)
	nodo.construir()
	var suelo := Vector3(pv.global_position.x, 0, pv.global_position.z)
	if nivel >= 2:
		marca_suelo(suelo, float(nd.get("marca", 1.0)) * 0.6, Color(0.1, 0.15, 0.25, 0.7), true)
	return nodo


## Rayos ramificados que se ven un instante y desaparecen.
func rayos_fugaces(pares: Array, grosor: float, duracion: float, ramas := 2) -> void:
	var r := Rayos.new()
	add_child(r)
	for par in pares:
		r.agregar_rayo(par[0], par[1], grosor, ramas, 0.28)
	if camara != null:
		r.dibujar(camara.global_position)
	var tw := create_tween()
	tw.tween_interval(duracion * 0.5)
	tw.tween_callback(func():
		r.limpiar()
		for par in pares:
			r.agregar_rayo(par[0], par[1], grosor * 0.7, ramas, 0.32)
		if camara != null and is_instance_valid(r):
			r.dibujar(camara.global_position))
	tw.tween_interval(duracion * 0.5)
	tw.tween_callback(r.queue_free)


func impacto_rayo(pos: Vector3, nivel: int) -> void:
	var nd := Datos.nivel_jutsu("chidori", nivel)
	rafaga(pos, {"cantidad": int(nd.get("particulas", 50)), "vida": 0.35 + nivel * 0.1, "radio": 0.2, "vel_min": 6.0, "vel_max": 12.0 + nivel * 5.0,
		"frenado": 8.0, "tam_min": 0.04, "tam_max": 0.09, "color": COLOR_RAYO_NUCLEO, "color_fin": Color(0.3, 0.6, 1.0, 0.0), "estirado": true, "tam_quad": Vector2(0.4, 2.5)})
	luz_temporal(pos, COLOR_RAYO, float(nd.get("luz", 3.0)) * 2.5, float(nd.get("luz_rango", 8.0)), 0.4 + nivel * 0.15)
	sacudir_desde(pos, float(nd.get("sacudida", 0.4)))
	marca_suelo(Vector3(pos.x, 0, pos.z), float(nd.get("marca", 1.0)), Color(0.06, 0.08, 0.14, 0.85), true)
	var pares: Array = []
	for i in 2 + nivel * 2:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
		pares.append([pos, pos + dir * (1.2 + nivel * 1.3)])
	rayos_fugaces(pares, 0.025 + nivel * 0.008, 0.22, nivel)
	if escenario != null:
		escenario.destello(COLOR_RAYO, 1.5 + nivel * 1.3, 0.25 + nivel * 0.15)
	_sonido("golpe", 0.0, 0.7)


## Cadena de rayo entre los puntos (enemigos sobre charcos).
func cadena(puntos: Array, nivel: int) -> void:
	var pares: Array = []
	for i in puntos.size() - 1:
		pares.append([puntos[i], puntos[i + 1]])
		var b: Vector3 = puntos[i + 1]
		luz_temporal(b, COLOR_RAYO, 6.0, 8.0, 0.5)
		rafaga(b, {"cantidad": 30, "vida": 0.3, "radio": 0.3, "vel_min": 4.0, "vel_max": 9.0, "tam_min": 0.04, "tam_max": 0.08,
			"color": COLOR_RAYO_NUCLEO, "estirado": true, "tam_quad": Vector2(0.3, 2.0)})
		chapoteo(Vector3(b.x, 0, b.z), 1.5)
	rayos_fugaces(pares, 0.06 + nivel * 0.015, 0.4, 2)


## Salpicadura de agua (pisar charcos, caídas, cadena eléctrica).
func chapoteo(pos: Vector3, fuerza := 1.0, y_suelo := 0.0) -> void:
	rafaga(Vector3(pos.x, y_suelo + 0.08, pos.z), {"cantidad": int(10 * fuerza) + 4, "vida": 0.45, "radio": 0.15 * fuerza, "direccion": Vector3.UP, "dispersion": 35.0,
		"vel_min": 1.5 * fuerza, "vel_max": 3.5 * fuerza, "gravedad": Vector3(0, -14, 0), "tam_min": 0.04, "tam_max": 0.08,
		"color": Color(0.75, 0.85, 1.0, 0.7), "aditivo": false, "escala_fin": 0.6})
	# Anillo de onda que se expande.
	var anillo := Materiales.disco(0.3, Materiales.transparente(Color(0.8, 0.9, 1.0, 0.35), true), 16)
	add_child(anillo)
	anillo.global_position = Vector3(pos.x, y_suelo + 0.03, pos.z)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(anillo, "scale", Vector3(3, 1, 3) * fuerza, 0.5)
	tw.tween_property(anillo, "transparency", 1.0, 0.5)
	tw.chain().tween_callback(anillo.queue_free)


## Paso con chakra: chispas azules y gotas que salen de la superficie (pared o agua) en la dirección normal.
func paso_chakra(pos: Vector3, normal: Vector3) -> void:
	rafaga(pos, {"cantidad": 8, "vida": 0.35, "radio": 0.12, "direccion": normal, "dispersion": 50.0,
		"vel_min": 1.2, "vel_max": 3.0, "gravedad": Vector3(0, -10, 0), "tam_min": 0.04, "tam_max": 0.07,
		"color": Color(0.75, 0.85, 1.0, 0.75), "aditivo": false, "escala_fin": 0.6})
	rafaga(pos, {"cantidad": 5, "vida": 0.3, "radio": 0.1, "direccion": normal, "dispersion": 70.0,
		"vel_min": 0.5, "vel_max": 1.4, "tam_min": 0.05, "tam_max": 0.09, "color": Color(0.45, 0.75, 1.0, 0.9)})
	if normal.y > 0.7:
		var anillo := Materiales.disco(0.3, Materiales.transparente(Color(0.55, 0.8, 1.0, 0.45), true), 16)
		add_child(anillo)
		anillo.global_position = pos + Vector3(0, 0.02, 0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(anillo, "scale", Vector3(3.2, 1, 3.2), 0.7)
		tw.tween_property(anillo, "transparency", 1.0, 0.7)
		tw.chain().tween_callback(anillo.queue_free)


# ------------------------------------------------------------ varios

func golpe_fisico(pos: Vector3, fuerte: bool, sacude := true) -> void:
	rafaga(pos, {"cantidad": 14 if not fuerte else 30, "vida": 0.25, "radio": 0.1, "vel_min": 2.0, "vel_max": 6.0,
		"tam_min": 0.08, "tam_max": 0.18, "color": Color(1, 0.95, 0.8, 0.9)})
	if camara != null and sacude:
		camara.sacudir(0.25 if fuerte else 0.1)


## Estela de la mano o el pie que golpea (según la animación del paso del combo).
func golpe_estela(pv: PersonajeVisual, paso: Dictionary, mio: bool) -> void:
	if pv == null or pv.esqueleto == null:
		return
	var an := str(paso.get("anim", ""))
	var hueso := "ManoD"
	if "patada" in an or "barrido" in an:
		hueso = "PieI" if an == "m_patada_frontal" else "PieD"
	elif "izq" in an or "gancho" in an:
		hueso = "ManoI"
	if pv.esqueleto.find_bone(hueso) < 0:
		return
	var fuerte := bool(paso.get("fuerte", false))
	var ba := BoneAttachment3D.new()
	ba.bone_name = hueso
	pv.esqueleto.add_child(ba)
	var p := particulas({"cantidad": 48 if fuerte else 28, "vida": 0.16 if not fuerte else 0.22, "radio": 0.05, "vel_min": 0.0, "vel_max": 0.2,
		"tam_min": 0.16 if fuerte else 0.11, "tam_max": 0.24 if fuerte else 0.16, "escala_inicio": 1.0,
		"color": Color(1.0, 0.97, 0.88, 0.75 if mio else 0.5), "color_fin": Color(0.6, 0.8, 1.0, 0.0)})
	ba.add_child(p)
	p.emitting = true
	var dur := float(paso.get("duracion", 0.4))
	var tw := create_tween()
	tw.tween_interval(dur * 0.85)
	tw.tween_callback(func(): if is_instance_valid(p): p.emitting = false)
	_borrar_en(ba, dur + 0.4)


## Avance rápido hacia el rival: polvo a los pies y un rastro de líneas.
func estela_avance(pos: Vector3, pv: Node3D) -> void:
	polvo(pos, 12)
	if pv == null:
		return
	var atras := -pv.global_transform.basis.z
	rafaga(pos + Vector3(0, 1.0, 0), {"cantidad": 18, "vida": 0.25, "radio": 0.35, "direccion": atras, "dispersion": 8.0,
		"vel_min": 6.0, "vel_max": 10.0, "tam_min": 0.25, "tam_max": 0.4, "estirado": true, "tam_quad": Vector2(0.06, 1.2),
		"color": Color(0.9, 0.95, 1.0, 0.45)})


## Shunshin: humo donde estaba y donde aparece, con una estela de humo entre ambos.
func shunshin(desde: Vector3, hasta: Vector3) -> void:
	for k in 6:
		var t := float(k) / 5.0
		var pt := desde.lerp(hasta, t) + Vector3(0, 0.9, 0)
		rafaga(pt, {"cantidad": 10, "vida": 0.6 + t * 0.3, "radio": 0.35, "direccion": Vector3.UP, "dispersion": 80.0, "vel_min": 0.3,
			"vel_max": 1.2, "tam_min": 0.5, "tam_max": 0.9, "color": Color(0.72, 0.74, 0.78, 0.6), "aditivo": false, "escala_fin": 1.8})
	for pt2 in [desde, hasta]:
		rafaga(pt2 + Vector3(0, 0.9, 0), {"cantidad": 26, "vida": 0.9, "radio": 0.5, "dispersion": 180.0, "vel_min": 0.8, "vel_max": 2.5,
			"tam_min": 0.7, "tam_max": 1.2, "color": Color(0.8, 0.82, 0.86, 0.8), "aditivo": false, "escala_fin": 2.0, "frenado": 3.0})
	_sonido("golpe", -10.0, 2.2)


## Choque de golpes: chispas anaranjadas en abanico y un destello.
func choque(pos: Vector3) -> void:
	rafaga(pos, {"cantidad": 40, "vida": 0.35, "radio": 0.05, "vel_min": 5.0, "vel_max": 11.0, "gravedad": Vector3(0, -9, 0),
		"tam_min": 0.15, "tam_max": 0.3, "estirado": true, "tam_quad": Vector2(0.04, 0.5), "color": Color(1.0, 0.85, 0.45, 1.0)})
	rafaga(pos, {"cantidad": 6, "vida": 0.12, "radio": 0.02, "vel_min": 0.0, "vel_max": 0.1, "tam_min": 1.2, "tam_max": 1.8,
		"escala_inicio": 1.0, "color": Color(1, 1, 0.95, 0.9)})
	luz_temporal(pos, Color(1.0, 0.85, 0.6), 4.0, 6.0, 0.25)


## Remate contra el suelo: cráter, anillo de polvo y piedras.
func estrellar(pos: Vector3) -> void:
	marca_suelo(pos, 1.7, Color(0.08, 0.08, 0.1, 0.85), true)
	rafaga(pos + Vector3(0, 0.2, 0), {"cantidad": 36, "vida": 0.9, "radio": 0.6, "direccion": Vector3.UP, "dispersion": 85.0,
		"vel_min": 2.0, "vel_max": 5.0, "gravedad": Vector3(0, -3, 0), "tam_min": 0.6, "tam_max": 1.1, "frenado": 2.0,
		"color": Color(0.55, 0.58, 0.62, 0.55), "aditivo": false, "escala_fin": 1.6})
	rafaga(pos + Vector3(0, 0.2, 0), {"cantidad": 16, "vida": 0.8, "radio": 0.4, "direccion": Vector3.UP, "dispersion": 50.0,
		"vel_min": 4.0, "vel_max": 8.0, "gravedad": Vector3(0, -18, 0), "tam_min": 0.1, "tam_max": 0.2,
		"color": Color(0.3, 0.3, 0.33, 1.0), "aditivo": false})


## Golpe fuerte: onda expansiva y líneas que salen en la dirección del golpe.
func onda_golpe(pos: Vector3, dir: Vector3) -> void:
	var d := dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	rafaga(pos, {"cantidad": 22, "vida": 0.22, "radio": 0.1, "direccion": d, "dispersion": 35.0, "vel_min": 9.0, "vel_max": 15.0,
		"tam_min": 0.2, "tam_max": 0.35, "estirado": true, "tam_quad": Vector2(0.05, 0.9), "color": Color(1, 1, 1, 0.85)})
	var anillo := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.47
	tm.outer_radius = 0.5
	tm.rings = 24
	tm.ring_segments = 4
	anillo.mesh = tm
	anillo.material_override = Materiales.emisivo(Color(0.9, 0.95, 1.0), 1.5)
	anillo.transparency = 0.55
	anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(anillo)
	anillo.global_position = pos
	# El anillo queda perpendicular a la dirección del golpe.
	var eje := d.cross(Vector3.UP)
	if eje.length() > 0.01:
		anillo.global_transform.basis = Basis(eje.normalized(), PI * 0.5)
	var tw := create_tween()
	tw.set_parallel(true)
	anillo.scale = Vector3(0.6, 0.6, 0.6)
	tw.tween_property(anillo, "scale", Vector3(2.6, 2.6, 2.6), 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(anillo, "transparency", 1.0, 0.2)
	tw.chain().tween_callback(anillo.queue_free)


## Bomba de humo: nube gris densa que se expande y se disipa.
func humo(pos: Vector3) -> void:
	rafaga(pos + Vector3(0, 0.8, 0), {"cantidad": 40, "vida": 1.6, "radio": 0.8, "direccion": Vector3.UP, "dispersion": 90.0,
		"vel_min": 0.6, "vel_max": 2.2, "gravedad": Vector3(0, 0.4, 0), "tam_min": 0.9, "tam_max": 1.6,
		"color": Color(0.62, 0.64, 0.68, 0.75), "aditivo": false, "escala_fin": 2.2})
	golpe_fisico(pos + Vector3(0, 1.0, 0), false)


func polvo(pos: Vector3, cantidad := 16) -> void:
	rafaga(Vector3(pos.x, 0.15, pos.z), {"cantidad": cantidad, "vida": 0.6, "radio": 0.3, "direccion": Vector3.UP, "dispersion": 70.0,
		"vel_min": 0.8, "vel_max": 2.0, "gravedad": Vector3(0, -2, 0), "tam_min": 0.3, "tam_max": 0.5, "color": Color(0.6, 0.65, 0.7, 0.35), "aditivo": false})


## Número de daño flotante. Color según la naturaleza; más grande con ventaja.
func numero(pos: Vector3, cantidad: float, color: Color, mult := 1.0) -> void:
	var l := Label3D.new()
	l.text = str(int(round(cantidad)))
	if mult > 1.01:
		l.text += "!"
	l.font = Estilo.fuente_titulo()
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.02, 0.02, 1.0)
	l.outline_size = 14
	l.font_size = 72 if mult > 1.01 else (44 if mult < 0.99 else 56)
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.8, randf_range(-0.3, 0.3))
	l.scale = Vector3.ONE * 0.4
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE * (1.25 if mult > 1.01 else 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.3, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.55)
	tw.chain().tween_callback(l.queue_free)


## Aviso de ataque enemigo (visible con el modo ocular activo).
func aviso(desde: Vector3, hacia: Vector3, duracion: float, melee := false) -> void:
	var nodo := Node3D.new()
	add_child(nodo)
	var mat := Materiales.transparente(Color(1.0, 0.1, 0.1, 0.45), true)
	var a := Vector3(desde.x, 0.05, desde.z)
	var b := Vector3(hacia.x, 0.05, hacia.z)
	var largo := a.distance_to(b)
	if largo > 0.1:
		var franja := MeshInstance3D.new()
		franja.mesh = _segmento_malla
		franja.material_override = mat
		franja.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nodo.add_child(franja)
		franja.global_position = (a + b) * 0.5
		franja.look_at(b, Vector3.UP)
		franja.scale = Vector3(1.4 if melee else 0.8, 0.02, largo)
	var circulo := Materiales.disco(1.0 if melee else 1.2, mat, 16)
	nodo.add_child(circulo)
	circulo.global_position = b
	var tw := create_tween()
	tw.tween_property(nodo, "scale", Vector3(1, 1, 1), 0.0)
	tw.tween_interval(maxf(duracion, 0.2) + 0.4)
	tw.tween_callback(nodo.queue_free)


## Aviso en el suelo de un ataque de área (telegraph): aro en el borde y un relleno que crece hasta el impacto.
## Rojo si te puede dañar; azul tenue si es tuyo o de un aliado (para no confundirlo con una amenaza).
func aviso_suelo(pos: Vector3, radio: float, duracion: float, peligro: bool) -> void:
	if duracion <= 0.05 or radio <= 0.1:
		return
	var col := Color(1.0, 0.18, 0.12) if peligro else Color(0.35, 0.65, 1.0)
	var raiz := Node3D.new()
	add_child(raiz)
	raiz.global_position = Vector3(pos.x, pos.y + 0.06, pos.z)
	var aro := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(radio - 0.14, 0.05)
	tm.outer_radius = radio
	tm.rings = 48
	tm.ring_segments = 4
	aro.mesh = tm
	aro.scale = Vector3(1, 0.05, 1)
	aro.material_override = Materiales.transparente(Color(col.r, col.g, col.b, 1.0 if peligro else 0.45), not peligro)
	aro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(aro)
	var relleno := Materiales.disco(radio, Materiales.transparente(Color(col.r, col.g, col.b, 0.38 if peligro else 0.12), not peligro), 40)
	relleno.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	relleno.scale = Vector3(0.05, 1, 0.05)
	raiz.add_child(relleno)
	var tw := create_tween()
	tw.tween_property(relleno, "scale", Vector3(1, 1, 1), duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(raiz, "scale", Vector3(1.08, 1, 1.08), 0.08)
	tw.tween_callback(raiz.queue_free)
