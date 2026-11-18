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


func construir(p_mapa: Mapa) -> void:
	mapa = p_mapa
	_colores = Datos.escenario.get("colores", {})
	_entorno()
	_suelo()
	_charcos()
	_torres()
	_campo_entrenamiento()
	_fondo_lejano()


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
	entorno.fog_density = 0.016
	entorno.fog_sky_affect = 0.6
	entorno.glow_enabled = true
	entorno.glow_intensity = 0.7
	entorno.glow_bloom = 0.05
	entorno.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = entorno
	add_child(we)

	sol = DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-58, 35, 0)
	sol.light_color = Color(0.78, 0.84, 0.95)
	sol.light_energy = _sol_energia_base
	sol.shadow_enabled = true
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _c("suelo")
	mat.roughness = 0.32
	mat.metallic = 0.15
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _c("charco")
	mat.roughness = 0.02
	mat.metallic = 0.7
	mat.metallic_specular = 1.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.01
	cm.radial_segments = 14
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

	var metal := Materiales.solido(_c("torre"), 0.45, 0.65)
	var metal_osc := Materiales.solido(_c("torre_oscura"), 0.5, 0.6)
	var mat_banda := Materiales.solido(_c("torre").lightened(0.1), 0.35, 0.8)
	var mat_ventana := Materiales.emisivo(_c("ventana"), 1.6)
	var mat_tuberia := Materiales.solido(_c("tuberia"), 0.4, 0.7)
	var mat_pasarela := Materiales.solido(_c("pasarela"), 0.5, 0.6)
	var mat_caja := Materiales.solido(Color(0.35, 0.22, 0.18), 0.6, 0.5)
	_mmi(_mm_caja(cuerpos, metal), true)
	_mmi(_mm_caja(cuerpos_osc, metal_osc), true)
	_mmi(_mm_caja(bandas, mat_banda), false)
	_mmi(_mm_caja(ventanas, mat_ventana), false)
	_mmi(_mm_caja(pasarelas, mat_pasarela), true)
	_mmi(_mm_caja(barandas, mat_banda), false)
	_mmi(_mm_caja(cajas, mat_caja), true)
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


func _process(delta: float) -> void:
	if _destello_t > 0.0:
		_destello_t = maxf(_destello_t - delta, 0.0)
		var k := _destello_t / maxf(_destello_dur, 0.001)
		var parpadeo := 0.75 + randf() * 0.25
		_luz_global.light_color = _destello_color
		_luz_global.light_energy = _destello_energia * k * parpadeo
		sol.light_energy = _sol_energia_base + _destello_energia * 0.4 * k
		entorno.ambient_light_energy = _ambiente_base + _destello_energia * 0.3 * k
		# La niebla toma el color del destello: todo el escenario se tiñe.
		var mezcla := clampf(_destello_energia * 0.12 * k * parpadeo, 0.0, 0.85)
		entorno.fog_light_color = _c("niebla").lerp(_destello_color, mezcla)
		entorno.fog_light_energy = 0.9 + mezcla * 1.5
	elif _luz_global.light_energy != 0.0:
		_luz_global.light_energy = 0.0
		sol.light_energy = _sol_energia_base
		entorno.ambient_light_energy = _ambiente_base
		entorno.fog_light_color = _c("niebla")
		entorno.fog_light_energy = 0.9
