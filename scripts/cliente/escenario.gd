class_name Escenario
extends Node3D
## Sector de la aldea de la lluvia generado por código a partir de Mapa:
## torres de metal, tuberías, pasarelas, charcos, cielo gris, niebla y luces.
## Usa MultiMesh para que todo el escenario cueste pocas llamadas de dibujo.

var mapa: Mapa
var entorno: Environment
var sol: DirectionalLight3D
var _luz_global: OmniLight3D
var _destello_t := 0.0
var _destello_dur := 0.0
var _destello_color := Color.WHITE
var _destello_energia := 0.0
var _sol_energia_base := 0.55
var _ambiente_base := 0.55
var _colores: Dictionary
var sonidos: Sonidos
var camara: Camera3D
var _nubes_mat: ShaderMaterial
var _rayo_cielo: Rayos
var _t_relampago := 6.0
var _relampago := 0.0


func construir(p_mapa: Mapa) -> void:
	mapa = p_mapa
	_colores = Datos.escenario.get("colores", {})
	Materiales.grosor_contorno = 0.03 if Ajustes.g("contorno_escenario", false) else 0.0
	_entorno()
	_suelo()
	_charcos()
	_torres()
	_campo_entrenamiento()
	_fondo_lejano()
	_atmosfera()
	Materiales.grosor_contorno = 0.0


func _c(clave: String) -> Color:
	return Datos.color(str(_colores.get(clave, "#808080")))


func _entorno() -> void:
	var cielo_mat := ProceduralSkyMaterial.new()
	cielo_mat.sky_top_color = _c("cielo_arriba")
	cielo_mat.sky_horizon_color = _c("cielo_horizonte")
	cielo_mat.ground_bottom_color = _c("cielo_arriba").darkened(0.4)
	cielo_mat.ground_horizon_color = _c("cielo_horizonte")
	cielo_mat.sun_angle_max = 0.0
	cielo_mat.sky_energy_multiplier = 0.9
	var cielo := Sky.new()
	cielo.sky_material = cielo_mat
	cielo.radiance_size = Sky.RADIANCE_SIZE_64
	entorno = Environment.new()
	entorno.background_mode = Environment.BG_SKY
	entorno.sky = cielo
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	entorno.ambient_light_energy = _ambiente_base
	entorno.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.tonemap_exposure = 1.0
	entorno.fog_enabled = true
	entorno.fog_light_color = _c("niebla")
	entorno.fog_light_energy = 0.9
	entorno.fog_density = 0.014
	entorno.fog_sky_affect = 0.5
	# Niebla por altura: más densa a ras de suelo.
	entorno.fog_height = 3.0
	entorno.fog_height_density = 0.06
	entorno.glow_enabled = bool(Ajustes.g("glow", true))
	entorno.glow_intensity = 0.9
	entorno.glow_strength = 1.05
	entorno.glow_bloom = 0.08
	entorno.glow_hdr_threshold = 0.95
	entorno.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	entorno.adjustment_enabled = true
	entorno.adjustment_contrast = 1.08
	entorno.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = entorno
	add_child(we)

	sol = DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-58, 35, 0)
	sol.light_color = Color(0.78, 0.84, 0.95)
	sol.light_energy = _sol_energia_base
	sol.shadow_enabled = bool(Ajustes.g("sombras", true))
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sol.directional_shadow_max_distance = 30.0
	add_child(sol)

	# Luz global usada para destellos (rayo nivel 3 ilumina todo el escenario).
	_luz_global = OmniLight3D.new()
	_luz_global.position = Vector3(0, 25, 0)
	_luz_global.omni_range = 120.0
	_luz_global.omni_attenuation = 0.3
	_luz_global.light_energy = 0.0
	_luz_global.shadow_enabled = false
	add_child(_luz_global)


func _suelo() -> void:
	# Placas de metal mojado: poco rugoso y algo metálico para reflejar la sonda.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _c("suelo")
	mat.roughness = 0.34
	mat.metallic = 0.3
	mat.metallic_specular = 0.45
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(180, 180)
	pm.material = mat
	suelo.mesh = pm
	suelo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(suelo)
	# Losas metálicas con juntas (líneas) para dar escala.
	var juntas := MultiMesh.new()
	juntas.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	bm.material = Materiales.solido(_c("suelo").darkened(0.35), 0.6, 0.2)
	juntas.mesh = bm
	var lineas: Array = []
	var lim := 60
	for i in range(-lim, lim + 1, 4):
		lineas.append(Transform3D(Basis.from_scale(Vector3(lim * 2.0, 0.01, 0.06)), Vector3(0, 0.003, i)))
		lineas.append(Transform3D(Basis.from_scale(Vector3(0.06, 0.01, lim * 2.0)), Vector3(i, 0.003, 0)))
	_llenar(juntas, lineas)
	_mmi(juntas, false)


func _charcos() -> void:
	var mat := Shaders.material("charco")
	mat.set_shader_parameter("color", _c("charco"))
	mat.set_shader_parameter("fuerza", 1.0 if Ajustes.g("ondas_charcos", true) else 0.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.01
	cm.radial_segments = 20
	cm.rings = 1
	cm.cap_bottom = false
	cm.material = mat
	mm.mesh = cm
	var ts: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = mapa.semilla + 5
	for ch in mapa.charcos:
		var c: Vector2 = ch["centro"]
		var r := float(ch["radio"])
		ts.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(r, 1, r * rng.randf_range(0.7, 1.0))), Vector3(c.x, 0.012, c.y)))
	_llenar(mm, ts)
	_mmi(mm, false)


func _torres() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = mapa.semilla + 11
	var cuerpos: Array = []
	var cuerpos_osc: Array = []
	var bandas: Array = []
	var ventanas: Array = []
	var tuberias: Array = []
	var pasarelas: Array = []
	var barandas: Array = []
	var cajas: Array = []
	var lamparas: Array = []
	for o in mapa.obstaculos:
		var c: Vector2 = o["centro"]
		var m: Vector2 = o["medio"]
		var alto := float(o["alto"])
		if o["tipo"] == "caja":
			cajas.append(Transform3D(Basis.from_scale(Vector3(m.x * 2, alto, m.y * 2)), Vector3(c.x, alto * 0.5, c.y)))
			continue
		var lista := cuerpos if rng.randf() < 0.6 else cuerpos_osc
		lista.append(Transform3D(Basis.from_scale(Vector3(m.x * 2, alto, m.y * 2)), Vector3(c.x, alto * 0.5, c.y)))
		# Remate superior más estrecho (estilo industrial)
		var remate_alto := rng.randf_range(2.0, 6.0)
		lista.append(Transform3D(Basis.from_scale(Vector3(m.x * 1.2, remate_alto, m.y * 1.2)), Vector3(c.x, alto + remate_alto * 0.5, c.y)))
		# Bandas horizontales
		var y := 3.0
		while y < alto:
			bandas.append(Transform3D(Basis.from_scale(Vector3(m.x * 2 + 0.3, 0.35, m.y * 2 + 0.3)), Vector3(c.x, y, c.y)))
			y += rng.randf_range(3.0, 6.0)
		# Ventanas encendidas al azar en las cuatro caras
		for cara in 4:
			var eje := Vector2(1, 0) if cara < 2 else Vector2(0, 1)
			var signo := 1.0 if cara % 2 == 0 else -1.0
			var ancho_cara := m.y if cara < 2 else m.x
			var fila := 2.0
			while fila < alto - 1.0:
				var col := -ancho_cara + 0.8
				while col < ancho_cara - 0.6:
					if rng.randf() < 0.18:
						var px := c.x + (eje.x * (m.x + 0.03) * signo) + (0.0 if cara < 2 else col)
						var pz := c.y + (eje.y * (m.y + 0.03) * signo) + (col if cara < 2 else 0.0)
						var esc := Vector3(0.05, 0.7, 0.5) if cara < 2 else Vector3(0.5, 0.7, 0.05)
						ventanas.append(Transform3D(Basis.from_scale(esc), Vector3(px, fila, pz)))
					col += 1.1
				fila += 1.6
		# Tuberías verticales pegadas a la torre
		for i in rng.randi_range(1, 3):
			var lado := rng.randi() % 4
			var off := rng.randf_range(-0.8, 0.8)
			var p := Vector3(c.x, alto * 0.5, c.y)
			match lado:
				0: p += Vector3(m.x + 0.25, 0, off * m.y)
				1: p += Vector3(-m.x - 0.25, 0, off * m.y)
				2: p += Vector3(off * m.x, 0, m.y + 0.25)
				_: p += Vector3(off * m.x, 0, -m.y - 0.25)
			var r := rng.randf_range(0.15, 0.35)
			tuberias.append(Transform3D(Basis.from_scale(Vector3(r, alto, r)), p))
			# Anillos de luz cálida en las tuberías.
			var yl := rng.randf_range(2.5, 6.0)
			while yl < alto - 2.0:
				lamparas.append(Transform3D(Basis.from_scale(Vector3(r * 2.3, 0.12, r * 2.3)), Vector3(p.x, yl, p.z)))
				yl += rng.randf_range(6.0, 12.0)
	# Pasarelas y tuberías horizontales entre torres
	for pa in mapa.pasarelas:
		var a: Dictionary = mapa.obstaculos[int(pa["a"])]
		var b: Dictionary = mapa.obstaculos[int(pa["b"])]
		var ca := Vector3((a["centro"] as Vector2).x, float(pa["altura"]), (a["centro"] as Vector2).y)
		var cb := Vector3((b["centro"] as Vector2).x, float(pa["altura"]), (b["centro"] as Vector2).y)
		var medio := (ca + cb) * 0.5
		var largo := ca.distance_to(cb)
		var yaw := atan2(cb.x - ca.x, cb.z - ca.z)
		var base := Basis.from_euler(Vector3(0, yaw, 0))
		pasarelas.append(Transform3D(base.scaled_local(Vector3(1.6, 0.25, largo)), medio))
		for s in [-1.0, 1.0]:
			barandas.append(Transform3D(base.scaled_local(Vector3(0.06, 0.06, largo)), medio + base.x * 0.78 * s + Vector3(0, 0.9, 0)))
			var n_postes := int(largo / 2.0)
			for k in n_postes:
				var t := (float(k) + 0.5) / n_postes - 0.5
				barandas.append(Transform3D(base.scaled_local(Vector3(0.05, 0.9, 0.05)), medio + base.z * largo * t + base.x * 0.78 * s + Vector3(0, 0.45, 0)))
		if rng.randf() < 0.6:
			var tb := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
			tb = base * tb
			var r2 := rng.randf_range(0.25, 0.5)
			tuberias.append(Transform3D(tb.scaled_local(Vector3(r2, largo, r2)), medio + Vector3(0, rng.randf_range(-3.0, -1.2), 0) + base.x * rng.randf_range(-0.5, 0.5)))

	var metal := Materiales.solido(_c("torre"), 0.3, 0.7)
	var metal_osc := Materiales.solido(_c("torre_oscura"), 0.35, 0.65)
	var mat_banda := Materiales.solido(_c("torre").lightened(0.12), 0.25, 0.85)
	var mat_ventana := Materiales.emisivo(_c("ventana"), 2.4)
	var mat_tuberia := Materiales.solido(_c("tuberia"), 0.3, 0.75)
	var mat_pasarela := Materiales.solido(_c("pasarela"), 0.5, 0.6)
	var mat_caja := Materiales.solido(Color(0.35, 0.22, 0.18), 0.6, 0.5)
	_mmi(_mm_caja(cuerpos, metal), true)
	_mmi(_mm_caja(cuerpos_osc, metal_osc), true)
	_mmi(_mm_caja(bandas, mat_banda), false)
	_mmi(_mm_caja(ventanas, mat_ventana), false)
	_mmi(_mm_caja(pasarelas, mat_pasarela), true)
	_mmi(_mm_caja(barandas, mat_banda), false)
	_mmi(_mm_caja(cajas, mat_caja), true)
	_mmi(_mm_caja(lamparas, Materiales.emisivo(Color(1.0, 0.62, 0.28), 3.0)), false)
	var mm_t := MultiMesh.new()
	mm_t.transform_format = MultiMesh.TRANSFORM_3D
	var cil := CylinderMesh.new()
	cil.top_radius = 1.0
	cil.bottom_radius = 1.0
	cil.height = 1.0
	cil.radial_segments = 8
	cil.rings = 1
	cil.material = mat_tuberia
	mm_t.mesh = cil
	_llenar(mm_t, tuberias)
	_mmi(mm_t, true)


func _campo_entrenamiento() -> void:
	# Plataforma de piedra del campo con borde y postes con faroles.
	var radio := float(Datos.escenario["campo_entrenamiento"]["radio"])
	var piedra := Materiales.solido(Color(0.3, 0.31, 0.32), 0.45, 0.1)
	var plataforma := Materiales.disco(radio, piedra, 24)
	plataforma.position = Vector3(0, 0.006, 0)
	add_child(plataforma)
	var borde := MultiMesh.new()
	borde.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	bm.material = Materiales.solido(Color(0.22, 0.23, 0.25), 0.5, 0.3)
	borde.mesh = bm
	var ts: Array = []
	var n := 40
	for i in n:
		var a := TAU * i / n
		var p := Vector3(cos(a), 0, sin(a)) * radio
		ts.append(Transform3D(Basis.from_euler(Vector3(0, -a, 0)).scaled_local(Vector3(0.4, 0.18, 2.4)), p + Vector3(0, 0.09, 0)))
	_llenar(borde, ts)
	_mmi(borde, false)
	# Faroles: solo 3 luces reales para cuidar el rendimiento en móvil.
	for i in 3:
		var a2 := TAU * i / 3.0 + 0.5
		var p2 := Vector3(cos(a2), 0, sin(a2)) * (radio + 1.5)
		var poste := Materiales.cilindro(0.08, 0.1, 4.0, Materiales.solido(Color(0.2, 0.2, 0.22), 0.4, 0.8), 6)
		poste.position = p2 + Vector3(0, 2.0, 0)
		add_child(poste)
		var farol := Materiales.caja(Vector3(0.4, 0.5, 0.4), Materiales.emisivo(_c("ventana"), 2.5))
		farol.position = p2 + Vector3(0, 4.1, 0)
		add_child(farol)
		var luz := OmniLight3D.new()
		luz.light_color = _c("ventana")
		luz.light_energy = 1.2
		luz.omni_range = 11.0
		luz.position = p2 + Vector3(0, 3.8, 0)
		add_child(luz)


func _fondo_lejano() -> void:
	# Siluetas lejanas de torres para que el horizonte se vea como una ciudad (la niebla las difumina).
	var rng := RandomNumberGenerator.new()
	rng.seed = mapa.semilla + 99
	var ts: Array = []
	for i in 46:
		var a := TAU * i / 46.0 + rng.randf() * 0.1
		var r := rng.randf_range(58.0, 80.0)
		var alto := rng.randf_range(25.0, 70.0)
		var ancho := rng.randf_range(5.0, 11.0)
		ts.append(Transform3D(Basis.from_scale(Vector3(ancho, alto, ancho)), Vector3(cos(a) * r, alto * 0.5, sin(a) * r)))
	_mmi(_mm_caja(ts, Materiales.solido(_c("torre_oscura").darkened(0.2), 0.6, 0.5)), false)


## Nubes en movimiento, bancos de niebla por capas, sonda de reflejos, luces cálidas y relámpagos.
func _atmosfera() -> void:
	if Ajustes.g("nubes", true):
		_nubes_mat = Shaders.material("nubes")
		var nubes := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(560, 560)
		pm.subdivide_width = 0
		pm.material = _nubes_mat
		nubes.mesh = pm
		nubes.position = Vector3(0, 75, 0)
		nubes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(nubes)
	# Capas de niebla: anillos de bancos verticales a distintas distancias.
	var capas := int(Ajustes.g("capas_niebla", 2))
	for capa in capas:
		var radio := 24.0 + capa * 16.0
		var n := 10 + capa * 4
		for i in n:
			var a := TAU * (float(i) + 0.5 * capa) / n
			var mat := Shaders.material("niebla")
			mat.set_shader_parameter("color", _c("niebla").lightened(0.05 * capa))
			mat.set_shader_parameter("opacidad", 0.28 + capa * 0.08)
			mat.set_shader_parameter("velocidad", 0.015 + capa * 0.008)
			mat.set_shader_parameter("semilla", float(i * 7 + capa * 31))
			var q := QuadMesh.new()
			q.size = Vector2(radio * TAU / n * 1.6, 9.0 + capa * 5.0)
			q.material = mat
			var mi := MeshInstance3D.new()
			mi.mesh = q
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			mi.position = Vector3(cos(a) * radio, q.size.y * 0.42, sin(a) * radio)
			mi.rotation.y = -a + PI * 0.5
	if Ajustes.g("sonda_reflejos", true):
		var sonda := ReflectionProbe.new()
		sonda.size = Vector3(80, 40, 80)
		sonda.position = Vector3(0, 6, 0)
		sonda.origin_offset = Vector3(0, -4, 0)
		sonda.box_projection = true
		sonda.update_mode = ReflectionProbe.UPDATE_ONCE
		sonda.intensity = 1.0
		sonda.max_distance = 90.0
		sonda.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		add_child(sonda)
	# Luces cálidas al pie de las torres más cercanas al campo.
	var cercanas: Array = []
	for o in mapa.obstaculos:
		if o["tipo"] == "torre":
			cercanas.append(o)
	cercanas.sort_custom(func(x, y): return (x["centro"] as Vector2).length() < (y["centro"] as Vector2).length())
	for i in mini(int(Ajustes.g("luces_ventanas", 3)), cercanas.size()):
		var o: Dictionary = cercanas[i]
		var c: Vector2 = o["centro"]
		var hacia := -c.normalized()
		var p := Vector2(c.x, c.y) + hacia * ((o["medio"] as Vector2).length() + 0.6)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.3)
		l.light_energy = 2.2
		l.omni_range = 9.0
		l.position = Vector3(p.x, 3.2, p.y)
		add_child(l)
		var farol := Materiales.caja(Vector3(0.5, 0.35, 0.5), Materiales.emisivo(Color(1.0, 0.65, 0.3), 3.5))
		farol.position = l.position + Vector3(0, 0.3, 0)
		add_child(farol)
	_rayo_cielo = Rayos.new()
	_rayo_cielo.color = Color(0.7, 0.8, 1.0)
	_rayo_cielo.intensidad = 4.0
	add_child(_rayo_cielo)


func _mm_caja(ts: Array, mat: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	bm.material = mat
	mm.mesh = bm
	_llenar(mm, ts)
	return mm


func _llenar(mm: MultiMesh, ts: Array) -> void:
	mm.instance_count = ts.size()
	for i in ts.size():
		mm.set_instance_transform(i, ts[i])


func _mmi(mm: MultiMesh, sombras: bool) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombras else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Destello que ilumina todo el escenario (relámpago del rayo nivel 3, explosiones grandes).
func destello(color: Color, energia: float, duracion: float) -> void:
	if energia < _destello_energia * (_destello_t / maxf(_destello_dur, 0.001)):
		return
	_destello_color = color
	_destello_energia = energia
	_destello_dur = duracion
	_destello_t = duracion


func _relampago_cielo() -> void:
	var a := randf() * TAU
	var d := randf_range(55.0, 95.0)
	var arriba := Vector3(cos(a) * d, 72.0, sin(a) * d)
	var abajo := arriba + Vector3(randf_range(-12, 12), -randf_range(45.0, 65.0), randf_range(-12, 12))
	_rayo_cielo.limpiar()
	_rayo_cielo.agregar_rayo(arriba, abajo, 0.45, 3, 0.18, 6)
	_relampago = 1.0
	destello(Color(0.75, 0.82, 1.0), 4.0, 0.35)
	if sonidos != null:
		var retraso := d / 60.0
		var tw := create_tween()
		tw.tween_interval(retraso)
		tw.tween_callback(sonidos.tocar.bind("trueno", -4.0, randf_range(0.8, 1.1)))


func _process(delta: float) -> void:
	# Relámpagos ocasionales en el cielo.
	if Ajustes.g("relampagos", true) and _rayo_cielo != null:
		_t_relampago -= delta
		if _t_relampago <= 0.0:
			var conf: Dictionary = Datos.graficos.get("relampago", {})
			_t_relampago = randf_range(float(conf.get("intervalo_min", 9.0)), float(conf.get("intervalo_max", 20.0)))
			_relampago_cielo()
		if _relampago > 0.0:
			_relampago = maxf(_relampago - delta * 2.5, 0.0)
			# Parpadeo doble típico del relámpago.
			var parp := _relampago * (0.6 + 0.4 * sin(_relampago * 40.0))
			if _nubes_mat != null:
				_nubes_mat.set_shader_parameter("relampago", parp)
			if camara != null:
				_rayo_cielo.dibujar(camara.global_position)
			_rayo_cielo.visible = _relampago > 0.45
	if _destello_t > 0.0:
		_destello_t = maxf(_destello_t - delta, 0.0)
		var k := _destello_t / maxf(_destello_dur, 0.001)
		var parpadeo := 0.75 + randf() * 0.25
		_luz_global.light_color = _destello_color
		_luz_global.light_energy = _destello_energia * 0.5 * k * parpadeo
		sol.light_energy = _sol_energia_base + _destello_energia * 0.2 * k
		entorno.ambient_light_energy = _ambiente_base + _destello_energia * 0.12 * k
		# La niebla toma el color del destello: todo el escenario se tiñe.
		var mezcla := clampf(_destello_energia * 0.1 * k * parpadeo, 0.0, 0.55)
		entorno.fog_light_color = _c("niebla").lerp(_destello_color, mezcla)
		entorno.fog_light_energy = 0.9 + mezcla * 0.8
	elif _luz_global.light_energy != 0.0:
		_luz_global.light_energy = 0.0
		sol.light_energy = _sol_energia_base
		entorno.ambient_light_energy = _ambiente_base
		entorno.fog_light_color = _c("niebla")
		entorno.fog_light_energy = 0.9
