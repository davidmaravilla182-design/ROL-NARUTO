class_name Trazado
extends RefCounted
## Construye el sector de la aldea con el kit de Blender a partir del trazado del Mapa
## (data/escenario.json → "trazado"): edificios, silos, tanques, canal con agua, muros,
## puentes, cascadas, vapor, arcos de tuberías, cables colgantes, faroles y horizonte.


static func construir(e: Escenario, m: Mapa) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = m.semilla + 77
	var calidad_alta := Ajustes.calidad == "alta"
	# Piezas principales agrupadas por tipo en MultiMesh: una llamada de dibujo por material y tipo.
	var por_tipo: Dictionary = {}
	for p in m.piezas:
		var c: Vector2 = p["centro"]
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(float(p["giro"]))), Vector3(c.x, 0, c.y))
		var tipo := str(p["tipo"])
		if tipo == "edificio_ia" and ResourceLoader.exists("res://assets/modelos/edificio_ia.glb"):
			_edificio_ia(e, t)
			continue
		if tipo == "torre_ia":
			if TorreIA.disponible():
				e.add_child(TorreIA.crear(c, float(p["giro"])))
				continue
			tipo = "torre_cabeza"   # sin el modelo IA, la torre procedural
		if not por_tipo.has(tipo):
			por_tipo[tipo] = []
		por_tipo[tipo].append(t)
	for tipo in por_tipo.keys():
		e.add_child(Kit.multimalla(tipo, por_tipo[tipo], Ajustes.calidad == "alta" or tipo == "edificio"))
	# Piezas del suelo de la plaza: una llamada de dibujo por tipo (MultiMesh).
	var props_t: Dictionary = {}
	for p in m.props:
		var cpr: Vector2 = p["centro"]
		props_t.get_or_add(str(p["tipo"]), []).append(Transform3D(Basis(Vector3.UP, deg_to_rad(float(p["giro"]))), Vector3(cpr.x, 0, cpr.y)))
	for tipo_p in props_t.keys():
		e.add_child(Kit.multimalla(tipo_p, props_t[tipo_p], calidad_alta and tipo_p != "rejilla_suelo"))
	var arcos_t: Array = []
	for a in m.arcos:
		var ca: Vector2 = a["centro"]
		arcos_t.append(Transform3D(Basis(Vector3.UP, deg_to_rad(float(a["giro"]))), Vector3(ca.x, 0.0, ca.y)))
	if not arcos_t.is_empty():
		e.add_child(Kit.multimalla("tubo_arco", arcos_t, true))
	for tb in m.tubos:
		var ct: Vector2 = tb["centro"]
		e.add_child(Kit.instancia("tubo_largo", Transform3D(Basis(Vector3.UP, deg_to_rad(float(tb["giro"]))), Vector3(ct.x, float(tb["altura"]), ct.y)), true))
	if not m.canal.is_empty():
		_canal(e, m, rng)
	_hito(e, m)
	_faroles_de_calle(e, m)
	_vapor(e, m, rng)
	_cables(e, m, rng)
	_horizonte(e, m, rng)


## El hito (torre con rostros) no debe perderse en la niebla: focos cálidos desde abajo
## y una luz fría sobre el rostro, como en la ilustración de referencia.
static func _hito(e: Escenario, m: Mapa) -> void:
	for p in m.piezas:
		if not (p["tipo"] in ["torre_cabeza", "torre_ia"]):
			continue
		var c: Vector2 = p["centro"]
		var f := frente(p) * -1.0   # el rostro mira a -Y de Blender = +Z de Godot rotado
		var base := Vector3(c.x, 0, c.y)
		for lado in [-1.0, 1.0]:
			var foco := SpotLight3D.new()
			foco.light_color = Color(1.0, 0.62, 0.35)
			foco.light_energy = 6.0
			foco.spot_range = 90.0
			foco.spot_angle = 22.0
			foco.spot_attenuation = 0.6
			var desde: Vector3 = base + f * -24.0 + Vector3(f.z, 0, -f.x) * lado * 14.0 + Vector3(0, 6, 0)
			e.add_child(foco)
			foco.global_position = desde
			foco.look_at(base + Vector3(0, 58, 0), Vector3.UP)
		var cara := OmniLight3D.new()
		cara.light_color = Color(0.72, 0.75, 1.0)
		cara.light_energy = 4.0
		cara.omni_range = 40.0
		cara.position = base + f * -26.0 + Vector3(0, 64, 0)
		e.add_child(cara)


## Edificio especial generado con Meshy: malla completa de cerca y versión liviana de lejos, farol en la puerta.
static func _edificio_ia(e: Escenario, t: Transform3D) -> void:
	var cerca := Kit.instancia("edificio_ia", t, true)
	cerca.visibility_range_end = 70.0
	e.add_child(cerca)
	var lejos := Kit.instancia("edificio_ia_lejos", t, false)
	lejos.visibility_range_begin = 70.0
	e.add_child(lejos)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.68, 0.35)
	luz.light_energy = 1.6
	luz.omni_range = 6.0
	e.add_child(luz)
	luz.global_position = t * Vector3(0.6, 2.6, 4.2)


## Frente de una pieza (hacia donde mira su fachada) en el plano XZ.
static func frente(p: Dictionary) -> Vector3:
	var g := deg_to_rad(float(p["giro"]))
	return Vector3(sin(g), 0, cos(g))


static func _canal(e: Escenario, m: Mapa, rng: RandomNumberGenerator) -> void:
	var cn := m.canal
	var x0 := float(cn["x_min"])
	var x1 := float(cn["x_max"])
	var zs := float(cn["z_sur"])
	var zn := float(cn["z_norte"])
	var agua_y := float(cn["nivel_agua"])
	# Agua
	var agua := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(x1 - x0, absf(zs - zn) + 1.0)
	var mat := Shaders.material("agua")
	mat.set_shader_parameter("fuerza", 1.0 if Ajustes.g("ondas_charcos", true) else 0.0)
	pm.material = mat
	agua.mesh = pm
	agua.position = Vector3((x0 + x1) * 0.5, agua_y, (zs + zn) * 0.5)
	agua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.add_child(agua)
	# Fondo oscuro bajo el suelo (el plano del suelo se recorta con el canal).
	var hueco := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(x1 - x0, 0.2, absf(zs - zn))
	bm.material = Materiales.solido(Color(0.02, 0.025, 0.03), 0.9)
	hueco.mesh = bm
	hueco.position = Vector3((x0 + x1) * 0.5, agua_y - 0.5, (zs + zn) * 0.5)
	e.add_child(hueco)
	# Muros a ambos lados: el sur mira al norte (-Z) y el norte mira al sur (+Z).
	var muros_s: Array = []
	var muros_n: Array = []
	var x := x0 + 4.0
	while x < x1:
		muros_s.append(Transform3D(Basis(Vector3.UP, PI), Vector3(x, 0, zs)))
		muros_n.append(Transform3D(Basis.IDENTITY, Vector3(x, 0, zn)))
		x += 8.0
	e.add_child(Kit.multimalla("muro_canal", muros_s, false))
	e.add_child(Kit.multimalla("muro_canal", muros_n, false))
	# Cascadas desde los desagües cercanos al campo (desagüe en x+2.0 del módulo, 0.55 hacia el agua, y=-1.4).
	var max_cascadas := 8 if Ajustes.calidad != "baja" else 4
	var cuenta := 0
	for t in muros_s:
		var base: Vector3 = (t as Transform3D).origin
		if absf(base.x) > 34.0 or cuenta >= max_cascadas:
			continue
		var salida := (t as Transform3D) * Vector3(2.0, -1.4, -0.58)
		_cascada(e, salida, Vector3(0, 0, -1), agua_y)
		cuenta += 1
	# Puentes de celosía que cruzan el canal.
	for px in m.puentes:
		var tp := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(float(px), 0.05, (zs + zn) * 0.5))
		e.add_child(Kit.instancia("pasarela", tp, true))
		# Luz cálida bajo cada puente: refleja en el agua.
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.65, 0.32)
		l.light_energy = 1.6
		l.omni_range = 9.0
		l.position = Vector3(float(px), 1.6, (zs + zn) * 0.5)
		e.add_child(l)


static func _cascada(e: Escenario, salida: Vector3, dir: Vector3, agua_y: float) -> void:
	var alto := salida.y - agua_y + 0.2
	var q := QuadMesh.new()
	q.size = Vector2(0.55, alto)
	q.material = Shaders.material("cascada")
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.add_child(mi)
	mi.position = salida + dir * 0.25 + Vector3(0, -alto * 0.5 + 0.1, 0)
	# Una segunda lámina cruzada para que tenga volumen desde cualquier ángulo.
	var mi2 := mi.duplicate()
	e.add_child(mi2)
	mi2.position = mi.position
	mi2.rotation.y = PI * 0.5
	# Espuma y salpicadura al chocar con el agua.
	var esp := GPUParticles3D.new()
	esp.amount = int(24 * float(Ajustes.g("particulas", 1.0))) + 4
	esp.lifetime = 0.9
	esp.position = Vector3(salida.x, agua_y + 0.05, salida.z) + dir * 0.3
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3.UP
	pm.spread = 50.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, -2.0, 0)
	pm.scale_min = 0.4
	pm.scale_max = 0.9
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.9, 1.0, 0.45))
	g.set_color(1, Color(0.85, 0.9, 1.0, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	esp.process_material = pm
	var qq := QuadMesh.new()
	qq.size = Vector2(0.8, 0.8)
	qq.material = Materiales.particula(Color.WHITE, false)
	esp.draw_pass_1 = qq
	esp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.add_child(esp)


## Luces cálidas en las puertas de los edificios más cercanos al campo (sus faroles ya son emisivos).
static func _faroles_de_calle(e: Escenario, m: Mapa) -> void:
	var edificios: Array = []
	for p in m.piezas:
		if p["tipo"] == "edificio":
			edificios.append(p)
	edificios.sort_custom(func(a, b): return (a["centro"] as Vector2).length() < (b["centro"] as Vector2).length())
	var n := mini(int(Ajustes.g("luces_ventanas", 3)) + 1, edificios.size())
	for i in n:
		var p: Dictionary = edificios[i]
		var c: Vector2 = p["centro"]
		var f := frente(p)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.3)
		l.light_energy = 2.4
		l.omni_range = 11.0
		l.position = Vector3(c.x, 2.6, c.y) + f * 5.0
		e.add_child(l)


## Columnas de vapor en las azoteas y coronas (GPU, pocas partículas grandes).
static func _vapor(e: Escenario, m: Mapa, rng: RandomNumberGenerator) -> void:
	if Ajustes.calidad == "baja":
		return
	var mult := float(Ajustes.g("particulas", 1.0))
	for p in m.piezas:
		var tipo := str(p["tipo"])
		if tipo != "edificio" and tipo != "silo":
			continue
		var c: Vector2 = p["centro"]
		var g := deg_to_rad(float(p["giro"]))
		var off := Vector3(1.5, 10.9, -1.0) if tipo == "edificio" else Vector3(2.2, 19.0, 0.0)
		var pos := Vector3(c.x, 0, c.y) + Basis(Vector3.UP, g) * off
		var vp := GPUParticles3D.new()
		vp.amount = int(14 * mult) + 4
		vp.lifetime = 4.0
		vp.preprocess = 3.0
		vp.position = pos
		vp.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 24, 16))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.4
		pm.direction = Vector3(0.25, 1, 0)
		pm.spread = 12.0
		pm.initial_velocity_min = 1.0
		pm.initial_velocity_max = 1.8
		pm.gravity = Vector3(0.3, 0.2, 0)
		pm.damping_min = 0.2
		pm.damping_max = 0.4
		pm.scale_min = 1.6
		pm.scale_max = 2.6
		var curva := Curve.new()
		curva.add_point(Vector2(0, 0.4))
		curva.add_point(Vector2(1, 2.2))
		var ct := CurveTexture.new()
		ct.curve = curva
		pm.scale_curve = ct
		var gr := Gradient.new()
		gr.set_color(0, Color(0.78, 0.8, 0.85, 0.0))
		gr.add_point(0.15, Color(0.78, 0.8, 0.85, 0.32))
		gr.set_color(gr.get_point_count() - 1, Color(0.7, 0.72, 0.78, 0.0))
		var gt := GradientTexture1D.new()
		gt.gradient = gr
		pm.color_ramp = gt
		vp.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		q.material = Materiales.particula(Color.WHITE, false)
		vp.draw_pass_1 = q
		vp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.add_child(vp)


## Cables eléctricos colgando entre azoteas (catenarias) en una sola malla.
static func _cables(e: Escenario, m: Mapa, rng: RandomNumberGenerator) -> void:
	var puntos: Array = []
	for p in m.piezas:
		var c: Vector2 = p["centro"]
		var alto := 10.6 if p["tipo"] == "edificio" else (6.0 if p["tipo"] == "tanque" else 17.0)
		if p["tipo"] == "silo_lejano" or p["tipo"] == "bloque_lejano":
			continue
		puntos.append(Vector3(c.x, alto, c.y))
	if puntos.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(Datos.escenario.get("trazado", {}).get("cables", 10))
	var hechos := 0
	var intentos := 0
	while hechos < n and intentos < 200:
		intentos += 1
		var a: Vector3 = puntos[rng.randi() % puntos.size()]
		var b: Vector3 = puntos[rng.randi() % puntos.size()]
		var d := Vector2(a.x - b.x, a.z - b.z).length()
		if d < 8.0 or d > 34.0:
			continue
		a += Vector3(rng.randf_range(-3, 3), rng.randf_range(-1.5, 0), rng.randf_range(-3, 3))
		b += Vector3(rng.randf_range(-3, 3), rng.randf_range(-1.5, 0), rng.randf_range(-3, 3))
		_catenaria(st, a, b, d * rng.randf_range(0.08, 0.16), 0.035)
		hechos += 1
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Materiales.solido(Color(0.04, 0.04, 0.05), 0.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.add_child(mi)


static func _catenaria(st: SurfaceTool, a: Vector3, b: Vector3, caida: float, r: float) -> void:
	var seg := 16
	var anillos: Array = []
	for i in seg + 1:
		var t := float(i) / seg
		var p := a.lerp(b, t) - Vector3(0, caida * 4.0 * t * (1.0 - t), 0)
		anillos.append(p)
	for i in seg:
		var p0: Vector3 = anillos[i]
		var p1: Vector3 = anillos[i + 1]
		var eje := (p1 - p0).normalized()
		var u := eje.cross(Vector3.UP).normalized() * r
		var v := eje.cross(u).normalized() * r
		var c0 := [p0 + u, p0 + v * 0.9 - u * 0.5, p0 - v * 0.9 - u * 0.5]
		var c1 := [p1 + u, p1 + v * 0.9 - u * 0.5, p1 - v * 0.9 - u * 0.5]
		for k in 3:
			var k2 := (k + 1) % 3
			for q in [c0[k], c1[k], c1[k2], c0[k], c1[k2], c0[k2]]:
				st.add_vertex(q)


## Horizonte: siluetas de torres y bloques entre la niebla (MultiMesh: 2 llamadas de dibujo).
static func _horizonte(e: Escenario, m: Mapa, rng: RandomNumberGenerator) -> void:
	var conf: Dictionary = Datos.escenario.get("trazado", {}).get("horizonte", {})
	var n := int(conf.get("cantidad", 30))
	if Ajustes.calidad == "baja":
		n = n / 2
	var silos: Array = []
	var bloques: Array = []
	for i in n:
		var a := TAU * (float(i) + rng.randf() * 0.6) / n
		var r := rng.randf_range(float(conf.get("radio_min", 55.0)), float(conf.get("radio_max", 95.0)))
		var esc := rng.randf_range(float(conf.get("escala_min", 1.0)), float(conf.get("escala_max", 2.2)))
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * esc), Vector3(cos(a) * r, -1.0, sin(a) * r))
		if rng.randf() < 0.55:
			silos.append(t)
		else:
			bloques.append(t)
	e.add_child(Kit.multimalla("silo_lejano", silos, false))
	e.add_child(Kit.multimalla("bloque_lejano", bloques, false))
