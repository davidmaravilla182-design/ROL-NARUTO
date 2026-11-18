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
var _marcas: Array = []
var _segmento_malla: BoxMesh


func _ready() -> void:
	_segmento_malla = BoxMesh.new()
	_segmento_malla.size = Vector3(1, 1, 1)


# ------------------------------------------------------------ utilidades

## Crea un sistema de partículas GPU configurable.
func particulas(cfg: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(int(cfg.get("cantidad", 20)), 1)
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
	get_tree().create_timer(segundos).timeout.connect(func():
		if is_instance_valid(n):
			n.queue_free())


func sacudir_desde(pos: Vector3, fuerza: float) -> void:
	if camara == null or fuerza <= 0.0:
		return
	var d := camara.global_position.distance_to(pos)
	camara.sacudir(fuerza * clampf(1.4 - d / 30.0, 0.25, 1.0))


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
			g.scale = Vector3(rng.randf_range(0.04, 0.1) * (1.0 + radio * 0.1), 0.01, largo)
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
		var exterior := Materiales.esfera(radio, Materiales.transparente(Color(1.0, 0.35, 0.05, 0.55), true), 12)
		nodo.add_child(exterior)
		var nucleo := Materiales.esfera(radio * 0.7, Materiales.emisivo(COLOR_FUEGO_NUCLEO, 3.0 + nivel), 10)
		nodo.add_child(nucleo)
		var llamas := particulas({
			"cantidad": int(nd.get("particulas", 40)), "vida": 0.45 + nivel * 0.15, "radio": radio * 0.9,
			"vel_min": 0.5, "vel_max": 1.5 + nivel, "dispersion": 180.0, "gravedad": Vector3(0, 2.5, 0),
			"tam_min": radio * 0.7, "tam_max": radio * 1.4, "color": Color(1.0, 0.5, 0.12, 0.6), "color_fin": Color(0.6, 0.08, 0.0, 0.0),
		})
		nodo.add_child(llamas)
		llamas.emitting = true
		if nivel >= 2:
			var humo := particulas({
				"cantidad": int(nd.get("particulas", 40)) / 3, "vida": 1.2, "radio": radio,
				"vel_min": 0.2, "vel_max": 1.0, "gravedad": Vector3(0, 1.5, 0), "tam_min": radio, "tam_max": radio * 2.0,
				"color": Color(0.15, 0.13, 0.12, 0.45), "aditivo": false,
			})
			nodo.add_child(humo)
			humo.emitting = true
		if nivel >= 3:
			var brasas := particulas({
				"cantidad": 80, "vida": 1.0, "radio": radio, "vel_min": 2.0, "vel_max": 6.0,
				"gravedad": Vector3(0, -4, 0), "tam_min": 0.05, "tam_max": 0.12, "color": Color(1, 0.8, 0.3), "escala_fin": 0.2,
			})
			nodo.add_child(brasas)
			brasas.emitting = true
		var luz := OmniLight3D.new()
		luz.light_color = COLOR_FUEGO
		luz.light_energy = float(nd.get("luz", 3.0))
		luz.omni_range = float(nd.get("luz_rango", 6.0))
		nodo.add_child(luz)
		nodo.set_meta("pulso", nucleo)
	else:
		var gota := Materiales.esfera(radio, Materiales.emisivo(COLOR_AGUA, 0.7), 8)
		nodo.add_child(gota)
		var estela := particulas({
			"cantidad": int(nd.get("particulas", 20)), "vida": 0.3, "radio": radio * 0.5,
			"vel_min": 0.1, "vel_max": 0.6, "tam_min": radio * 0.5, "tam_max": radio * 0.8, "color": Color(0.4, 0.65, 1.0, 0.35),
		})
		nodo.add_child(estela)
		estela.emitting = true
	return nodo


func explosion(ev: Dictionary) -> void:
	var jutsu := str(ev["jutsu"])
	var nivel := int(ev["nivel"])
	var nd := Datos.nivel_jutsu(jutsu, nivel)
	var pos: Vector3 = ev["pos"]
	var r := float(ev["radio"])
	if jutsu == "bola_fuego":
		var cant := int(nd.get("particulas", 40))
		rafaga(pos, {"cantidad": cant * 2, "vida": 0.5 + nivel * 0.25, "radio": r * 0.3, "vel_min": r * 1.2, "vel_max": r * 3.0,
			"frenado": r * 2.0, "tam_min": r * 0.4, "tam_max": r * 0.9, "color": Color(1.0, 0.55, 0.15, 0.6), "color_fin": Color(0.7, 0.1, 0.0, 0.0)})
		rafaga(pos, {"cantidad": cant, "vida": 1.6 + nivel * 0.4, "radio": r * 0.5, "vel_min": 0.5, "vel_max": r * 0.8,
			"gravedad": Vector3(0, 2.0, 0), "tam_min": r * 0.6, "tam_max": r * 1.2, "color": Color(0.12, 0.1, 0.1, 0.55), "aditivo": false, "explosividad": 0.6})
		if nivel >= 2:
			rafaga(pos, {"cantidad": cant, "vida": 1.2, "radio": r * 0.2, "vel_min": 4.0, "vel_max": 10.0 + nivel * 4.0,
				"gravedad": Vector3(0, -9, 0), "tam_min": 0.06, "tam_max": 0.15, "color": Color(1, 0.75, 0.3), "escala_fin": 0.3})
		if nivel >= 3:
			# Anillo de fuego que se expande por el suelo y llamas que quedan ardiendo.
			var suelo: Vector3 = ev["suelo"]
			rafaga(suelo + Vector3(0, 0.3, 0), {"cantidad": 200, "vida": 0.9, "radio": 0.5, "direccion": Vector3(1, 0, 0), "dispersion": 180.0,
				"vel_min": 10.0, "vel_max": 16.0, "frenado": 10.0, "tam_min": 1.0, "tam_max": 2.0, "color": Color(1.0, 0.5, 0.1, 0.9)})
			for i in 6:
				var a := TAU * i / 6.0
				var fp := suelo + Vector3(cos(a), 0, sin(a)) * r * 0.45
				var fuego := particulas({"cantidad": 24, "vida": 0.7, "radio": 0.5, "vel_min": 0.5, "vel_max": 1.5,
					"gravedad": Vector3(0, 3, 0), "tam_min": 0.5, "tam_max": 1.0, "color": Color(1, 0.5, 0.1, 0.8)})
				add_child(fuego)
				fuego.global_position = fp
				fuego.emitting = true
				_borrar_en(fuego, 5.0)
				get_tree().create_timer(4.0).timeout.connect(func():
					if is_instance_valid(fuego):
						fuego.emitting = false)
			if escenario != null:
				escenario.destello(COLOR_FUEGO, 3.0, 0.7)
		luz_temporal(pos, COLOR_FUEGO, float(nd.get("luz", 3.0)) * 2.0, float(nd.get("luz_rango", 6.0)) * 1.3, 0.5 + nivel * 0.25)
		sacudir_desde(pos, float(nd.get("sacudida", 0.3)))
		marca_suelo(ev["suelo"], float(nd.get("marca", 1.0)) * float(ev.get("escala", 1.0)), Color(0.05, 0.03, 0.02, 0.85))
	else:
		rafaga(pos, {"cantidad": 24, "vida": 0.5, "radio": 0.2, "vel_min": 2.0, "vel_max": 5.0, "gravedad": Vector3(0, -9, 0),
			"tam_min": 0.08, "tam_max": 0.2, "color": Color(0.6, 0.8, 1.0, 0.9)})
		sacudir_desde(pos, float(nd.get("sacudida", 0.1)))


# ------------------------------------------------------------ rayo (embiste)

## Carga del rayo en la mano: chispas, arcos y luz que crecen con el nivel.
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


func impacto_rayo(pos: Vector3, nivel: int) -> void:
	var nd := Datos.nivel_jutsu("chidori", nivel)
	rafaga(pos, {"cantidad": int(nd.get("particulas", 50)) * 2, "vida": 0.35 + nivel * 0.1, "radio": 0.2, "vel_min": 6.0, "vel_max": 14.0 + nivel * 6.0,
		"frenado": 8.0, "tam_min": 0.05, "tam_max": 0.12, "color": COLOR_RAYO_NUCLEO, "color_fin": Color(0.3, 0.6, 1.0, 0.0), "estirado": true, "tam_quad": Vector2(0.4, 2.5)})
	luz_temporal(pos, COLOR_RAYO, float(nd.get("luz", 3.0)) * 2.5, float(nd.get("luz_rango", 8.0)), 0.4 + nivel * 0.15)
	sacudir_desde(pos, float(nd.get("sacudida", 0.4)))
	marca_suelo(Vector3(pos.x, 0, pos.z), float(nd.get("marca", 1.0)), Color(0.06, 0.08, 0.14, 0.85), true)
	var mat := Materiales.emisivo(COLOR_RAYO_NUCLEO, 6.0)
	var n := 2 + nivel * 2
	for i in n:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized()
		var segs := rayo_zigzag(self, pos, pos + dir * (1.0 + nivel * 1.2), 0.03 + nivel * 0.015, mat, 5, 0.25 * nivel)
		for s in segs:
			_borrar_en(s, 0.18)
	if escenario != null:
		escenario.destello(COLOR_RAYO, 2.0 + nivel * 2.5, 0.25 + nivel * 0.15)


## Cadena de rayo entre los puntos (enemigos sobre charcos).
func cadena(puntos: Array, nivel: int) -> void:
	var mat := Materiales.emisivo(COLOR_RAYO_NUCLEO, 7.0)
	for i in puntos.size() - 1:
		var a: Vector3 = puntos[i]
		var b: Vector3 = puntos[i + 1]
		for k in 2:
			var segs := rayo_zigzag(self, a, b, 0.05 + nivel * 0.015, mat, 8, 0.45)
			for s in segs:
				_borrar_en(s, 0.3 + k * 0.1)
		luz_temporal(b, COLOR_RAYO, 6.0, 8.0, 0.5)
		rafaga(b, {"cantidad": 40, "vida": 0.3, "radio": 0.3, "vel_min": 4.0, "vel_max": 9.0, "tam_min": 0.05, "tam_max": 0.1,
			"color": COLOR_RAYO_NUCLEO, "estirado": true, "tam_quad": Vector2(0.3, 2.0)})
		# Salpicadura del charco electrificado
		rafaga(Vector3(b.x, 0.1, b.z), {"cantidad": 30, "vida": 0.5, "radio": 0.6, "direccion": Vector3.UP, "dispersion": 40.0,
			"vel_min": 2.0, "vel_max": 5.0, "gravedad": Vector3(0, -12, 0), "tam_min": 0.08, "tam_max": 0.16, "color": Color(0.6, 0.85, 1.0, 0.9)})


# ------------------------------------------------------------ varios

func golpe_fisico(pos: Vector3, fuerte: bool) -> void:
	rafaga(pos, {"cantidad": 14 if not fuerte else 30, "vida": 0.25, "radio": 0.1, "vel_min": 2.0, "vel_max": 6.0,
		"tam_min": 0.08, "tam_max": 0.18, "color": Color(1, 0.95, 0.8, 0.9)})
	if camara != null:
		camara.sacudir(0.25 if fuerte else 0.1)


func polvo(pos: Vector3, cantidad := 16) -> void:
	rafaga(Vector3(pos.x, 0.15, pos.z), {"cantidad": cantidad, "vida": 0.6, "radio": 0.3, "direccion": Vector3.UP, "dispersion": 70.0,
		"vel_min": 0.8, "vel_max": 2.0, "gravedad": Vector3(0, -2, 0), "tam_min": 0.3, "tam_max": 0.5, "color": Color(0.6, 0.65, 0.7, 0.35), "aditivo": false})


## Número de daño flotante.
func numero(pos: Vector3, cantidad: float, color: Color, extra := "") -> void:
	var l := Label3D.new()
	l.text = str(int(round(cantidad))) + extra
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.outline_size = 10
	l.font_size = 64
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.8, randf_range(-0.3, 0.3))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.2, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
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
