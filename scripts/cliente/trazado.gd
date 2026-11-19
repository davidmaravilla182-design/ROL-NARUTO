class_name Trazado
extends RefCounted
## Construye el sector de la aldea con el kit de Blender a partir del trazado del Mapa
## (data/escenario.json → "trazado"): edificios, silos, tanques, canal con agua, muros,
## puentes, cascadas, vapor, arcos de tuberías, cables colgantes, faroles y horizonte.


const CELDA := 48.0
## Tipos sin versión lejana: se dibujan hasta esta distancia (piezas del kit de Blender).
const KIT_GRANDES := ["edificio", "silo", "tanque", "chimenea", "torre_cabeza"]


static func construir(e: Escenario, m: Mapa) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = m.semilla + 77
	var sect: Sectores = e.sectores
	# Piezas y objetos agrupados por tipo y por celda de 48 m: cada grupo es un MultiMesh con distancia
	# de dibujo propia (LOD cercano/lejano). Así se dibuja solo lo que está cerca de la cámara.
	var grupos: Dictionary = {}
	for p in m.piezas + m.props:
		var tipo := str(p["tipo"])
		var c: Vector2 = p["centro"]
		if tipo == "torre_ia":
			if TorreIA.disponible():
				e.add_child(TorreIA.crear(c, float(p["giro"])))
				continue
			tipo = "torre_cabeza"   # sin el modelo IA, la torre procedural
		if not ResourceLoader.exists("res://assets/modelos/%s.glb" % tipo):
			continue
		var esc := float(p.get("escala", 1.0))
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(float(p["giro"]))).scaled(Vector3.ONE * esc), Vector3(c.x, float(p.get("y", 0.0)), c.y))
		var celda := Vector2i(floori(c.x / CELDA), floori(c.y / CELDA))
		var g: Dictionary = grupos.get_or_add("%s|%d|%d" % [tipo, celda.x, celda.y], {"tipo": tipo, "celda": celda, "ts": [], "tintes": []})
		g["ts"].append(t)
		var ti: Array = p.get("tinte", [])
		g["tintes"].append(Color(float(ti[0]), float(ti[1]), float(ti[2])) if ti.size() == 3 else Color.WHITE)
	var dist := _distancias()
	var huellas: Dictionary = Datos.escenario.get("trazado", {}).get("huellas", {})
	for clave in grupos.keys():
		var g: Dictionary = grupos[clave]
		var tipo: String = g["tipo"]
		var origen := Vector3((g["celda"].x + 0.5) * CELDA, 0, (g["celda"].y + 0.5) * CELDA)
		var locales: Array = []
		for t in g["ts"]:
			locales.append(Transform3D((t as Transform3D).basis, (t as Transform3D).origin - origen))
		var alto := float((huellas.get(tipo, [1, 1, 1]) as Array)[2])
		var grande := alto >= 5.0
		var con_lejos := ResourceLoader.exists("res://assets/modelos/%s_lejos.glb" % tipo)
		var cerca_hasta: float = dist["edificio"] if grande else dist["objeto"]
		# Cuanto más pesada la malla cercana, antes se cambia a la lejana (casas de 8k triángulos a ~60 m).
		var tris: Array = Datos.escenario.get("trazado", {}).get("triangulos", {}).get(tipo, [])
		if con_lejos and not tris.is_empty():
			cerca_hasta *= clampf(sqrt(3000.0 / maxf(float(tris[0]), 1.0)), 0.5, 1.0)
		if not con_lejos and grande:
			cerca_hasta = dist["lejos"] if tipo in KIT_GRANDES else dist["edificio"]
		var sombras := grande and Ajustes.calidad != "baja"
		var mmi := Kit.multimalla(tipo, locales, sombras, g["tintes"])
		mmi.position = origen
		mmi.visibility_range_end = cerca_hasta + CELDA * 0.5
		e.add_child(mmi)
		if con_lejos:
			var lejos := Kit.multimalla(tipo + "_lejos", locales, false, g["tintes"])
			lejos.position = origen
			lejos.visibility_range_begin = cerca_hasta + CELDA * 0.5
			lejos.visibility_range_end = (dist["lejos"] if grande else dist["objeto"] * 2.0) + CELDA * 0.5
			e.add_child(lejos)
		if grande and Ajustes.g("oclusion", true):
			_oclusores(e, g["ts"], huellas.get(tipo, []))
	_edificio_ia_luz(e, m)
	var arcos_t: Array = []
	for a in m.arcos:
		var ca: Vector2 = a["centro"]
		arcos_t.append(Transform3D(Basis(Vector3.UP, deg_to_rad(float(a["giro"]))), Vector3(ca.x, 0.0, ca.y)))
	if not arcos_t.is_empty():
		e.add_child(Kit.multimalla("tubo_arco", arcos_t, true))
	var tubos_t: Array = []
	var soportes: Array = []
	for tb in m.tubos:
		var ct: Vector2 = tb["centro"]
		var tr := Transform3D(Basis(Vector3.UP, deg_to_rad(float(tb["giro"]))), Vector3(ct.x, float(tb["altura"]), ct.y))
		tubos_t.append(tr)
		# Las elevadas cuelgan de un pórtico a un lado de la calle cada 12 m.
		if float(tb["altura"]) > 2.0:
			var lado := tr.basis * Vector3(0, 0, 2.6)
			soportes.append(Transform3D(Basis.from_scale(Vector3(0.7, float(tb["altura"]) + 0.4, 0.7)), Vector3(ct.x, 0, ct.y) + lado))
	if not tubos_t.is_empty():
		e.add_child(Kit.multimalla("tubo_largo", tubos_t, Ajustes.calidad == "alta"))
	if not soportes.is_empty():
		e.add_child(Kit.multimalla("columna", soportes, false))
	if not m.canal.is_empty():
		_canal(e, m, rng)
	_muralla(e, m)
	_plataformas(e, m)
	_hito(e, m)
	_faroles_de_calle(e, m)
	_vapor(e, m, rng)
	_goteo(e, m, rng)
	_cables(e, m, rng)
	_horizonte(e, m, rng)
	Puntos.construir(e, m)


## Distancias de dibujo según la calidad (metros).
static func _distancias() -> Dictionary:
	match Ajustes.calidad:
		"baja": return {"edificio": 60.0, "objeto": 38.0, "lejos": 240.0}
		"media": return {"edificio": 80.0, "objeto": 55.0, "lejos": 320.0}
		_: return {"edificio": 100.0, "objeto": 70.0, "lejos": 420.0}


## Oclusores de caja para los edificios grandes: lo que queda detrás no se dibuja.
static func _oclusores(e: Escenario, ts: Array, h: Array) -> void:
	if h.size() < 3 or float(h[0]) < 4.0 or float(h[1]) < 4.0:
		return
	for t in ts:
		var tr: Transform3D = t
		var oc := OccluderInstance3D.new()
		var bo := BoxOccluder3D.new()
		bo.size = Vector3(float(h[0]) * 0.8, float(h[2]) * 0.85, float(h[1]) * 0.8)
		oc.occluder = bo
		oc.transform = Transform3D(tr.basis, tr.origin + Vector3(0, float(h[2]) * 0.85 * 0.5 * tr.basis.get_scale().y, 0))
		e.add_child(oc)


## Calle techada (mercado): farolillos de papel colgando bajo el techo a ambos lados y luces cálidas
## repartidas a lo largo (pocas, para el móvil).
static func _farolillos(e: Escenario, c: Vector2, md: Vector2, h: float) -> void:
	var largo_x := md.x >= md.y
	var largo := (md.x if largo_x else md.y) * 2.0
	var ts: Array = []
	var colores: Array = []
	var n := int(largo / 3.0)
	for lado in [-1.0, 1.0]:
		for i in n:
			var a := -largo * 0.5 + (float(i) + 0.5) * largo / n
			var off := (md.y if largo_x else md.x) - 1.2
			var p := Vector3(c.x + a, h - 1.3 - 0.25 * float(i % 2), c.y + lado * off) if largo_x else Vector3(c.x + lado * off, h - 1.3, c.y + a)
			ts.append(Transform3D(Basis.from_scale(Vector3(0.42, 0.55, 0.42)), p))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var esf := SphereMesh.new()
	esf.radius = 0.5
	esf.height = 1.0
	esf.radial_segments = 10
	esf.rings = 5
	esf.material = Materiales.emisivo(Color(1.0, 0.42, 0.18), 2.6)
	mm.mesh = esf
	mm.instance_count = ts.size()
	for i in ts.size():
		mm.set_instance_transform(i, ts[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.sectores.agregar(mmi, c)
	var luces := {"baja": 2, "media": 3}.get(Ajustes.calidad, 5) as int
	for i in luces:
		var a2 := -largo * 0.5 + (float(i) + 0.5) * largo / luces
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.25)
		l.light_energy = 2.6
		l.omni_range = 12.0
		e.sectores.agregar(l, c)
		l.global_position = Vector3(c.x + a2, h - 2.0, c.y) if largo_x else Vector3(c.x, h - 2.0, c.y + a2)


## Farol en la puerta del edificio especial (Meshy, primer modelo).
static func _edificio_ia_luz(e: Escenario, m: Mapa) -> void:
	for p in m.piezas:
		# Solo el edificio original de la plaza lleva su farol con luz real (las copias usan los faroles del distrito).
		# Los edificios de Meshy de la plaza (el original y sus variantes) llevan la luz ámbar de sus faroles.
		var tipo := str(p["tipo"])
		if not (tipo == "edificio_ia" or tipo.begins_with("plaza_")) or (p["centro"] as Vector2).length() > 48.0:
			continue
		var c: Vector2 = p["centro"]
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(float(p["giro"]))), Vector3(c.x, 0, c.y))
		var fondo := float((Datos.escenario.get("trazado", {}).get("huellas", {}).get(tipo, [7, 7, 8]) as Array)[1])
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.68, 0.35)
		luz.light_energy = 1.6 if tipo != "plaza_b" else 2.2   # el puesto de fideos tiene una fila de faroles
		luz.omni_range = 6.0 if tipo != "plaza_b" else 8.0
		e.sectores.agregar(luz, c)
		luz.global_position = t * (Vector3(0.6, 2.6, 4.2) if tipo == "edificio_ia" else Vector3(0.0, 2.4, fondo * 0.5 + 0.8))


## Muralla de la aldea: tramos de concreto alrededor de la isla y torres de vigilancia con foco.
static func _muralla(e: Escenario, m: Mapa) -> void:
	if m.muralla.is_empty():
		return
	var grupos: Dictionary = {}
	var torres: Array = []
	for mu in m.muralla:
		var c: Vector2 = mu["centro"]
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(float(mu["giro"]))), Vector3(c.x, 0, c.y))
		var celda := Vector2i(floori(c.x / (CELDA * 2.0)), floori(c.y / (CELDA * 2.0)))
		grupos.get_or_add(celda, []).append(t)
		if mu["torre"]:
			torres.append(t)
	for celda in grupos.keys():
		var mmi := Kit.multimalla("muro_aldea", grupos[celda], Ajustes.calidad == "alta")
		e.add_child(mmi)
	if not torres.is_empty():
		e.add_child(Kit.multimalla("torreta", torres, Ajustes.calidad == "alta"))
		for t in torres:
			var foco := OmniLight3D.new()
			foco.light_color = Color(1.0, 0.7, 0.4)
			foco.light_energy = 2.0
			foco.omni_range = 14.0
			e.sectores.agregar(foco, Vector2(t.origin.x, t.origin.z))
			foco.global_position = t * Vector3(0, 18.6, -3.4)


## Plataformas, pasarelas, techos caminables, escaleras y el puente sobre el lago (piezas tipo Lego).
static func _plataformas(e: Escenario, m: Mapa) -> void:
	var losas: Array = []
	var columnas: Array = []
	var escaleras: Array = []
	var barandales: Array = []
	for pl in m.plataformas:
		var tipo := str(pl.get("tipo", "pasarela"))
		if tipo == "lengua":
			continue
		var c: Vector2 = pl["centro"]
		var md: Vector2 = pl["medio"]
		var h := float(pl["altura"])
		if pl.has("altura0"):
			var h0 := float(pl["altura0"])
			var bajo := minf(h0, h)
			var sube := absf(h - h0)
			var por_x: bool = pl["eje"] == "x"
			# La pieza sube hacia -Z (frente de Blender); se gira para que suba hacia el lado alto.
			var ang := 0.0
			if por_x:
				ang = -PI * 0.5 if h > h0 else PI * 0.5
			else:
				ang = PI if h > h0 else 0.0
			var ancho := (md.y if por_x else md.x)
			var largo := (md.x if por_x else md.y) * 2.0
			# Tramos de ~1 m de subida (6 peldaños cada uno): la escalera no se ve como tablas gigantes.
			var dir := (Vector3(1, 0, 0) if por_x else Vector3(0, 0, 1)) * (1.0 if h > h0 else -1.0)
			var tramos := maxi(1, ceili(sube))
			var lado := Vector3(0, 0, 1) if por_x else Vector3(1, 0, 0)
			for i in tramos:
				var centro := Vector3(c.x, 0, c.y) + dir * (-largo * 0.5 + (float(i) + 0.5) * largo / tramos)
				var base_y := bajo + float(i) * sube / tramos
				escaleras.append(Transform3D(Basis(Vector3.UP, ang).scaled_local(Vector3(ancho, sube / tramos, largo / tramos)), centro + Vector3(0, base_y, 0)))
				# Pilares bajo la escalera cada dos tramos cuando va alta.
				if base_y > 1.5 and i % 2 == 1:
					for sl in [-1.0, 1.0]:
						columnas.append(Transform3D(Basis.from_scale(Vector3(0.8, base_y, 0.8)), centro + lado * sl * (ancho - 0.15)))
			continue
		if tipo == "techo" and maxf(md.x, md.y) > 20.0:
			_farolillos(e, c, md, h)
		var grosor := 0.6 if tipo == "puente" else 0.35
		losas.append(Transform3D(Basis.from_scale(Vector3(md.x * 2.0, grosor, md.y * 2.0)), Vector3(c.x, h, c.y)))
		# Columnas en las esquinas y cada ~9 m a lo largo (el puente baja hasta el fondo del lago).
		var pie := -5.0 if tipo == "puente" else 0.0
		var alto_col := h - grosor - pie
		if alto_col > 0.5:
			var nx := maxi(1, int(md.x * 2.0 / 9.0))
			var nz := maxi(1, int(md.y * 2.0 / 9.0))
			for i in nx + 1:
				for k in nz + 1:
					if i != 0 and i != nx and k != 0 and k != nz:
						continue
					var px := c.x - md.x + 0.3 + (md.x * 2.0 - 0.6) * float(i) / nx
					var pz := c.y - md.y + 0.3 + (md.y * 2.0 - 0.6) * float(k) / nz
					columnas.append(Transform3D(Basis.from_scale(Vector3(1.4, alto_col, 1.4)), Vector3(px, pie, pz)))
		# Barandales en los lados largos.
		var largo_x := md.x >= md.y
		var n := int((md.x if largo_x else md.y) * 2.0 / 2.0)
		for lado in [-1.0, 1.0]:
			for i in n:
				var a := -(md.x if largo_x else md.y) + float(i) * 2.0
				if largo_x:
					barandales.append(Transform3D(Basis.IDENTITY, Vector3(c.x + a, h, c.y + lado * (md.y - 0.1))))
				else:
					barandales.append(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(c.x + lado * (md.x - 0.1), h, c.y + a)))
	if not losas.is_empty():
		e.add_child(Kit.multimalla("losa", losas, true))
	if not columnas.is_empty():
		e.add_child(Kit.multimalla("columna", columnas, Ajustes.calidad == "alta"))
	if not escaleras.is_empty():
		e.add_child(Kit.multimalla("escalera", escaleras, true))
	if not barandales.is_empty():
		e.add_child(Kit.multimalla("barandal", barandales, false))


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
	mat.set_shader_parameter("borde", Vector4(x0, zn, x1, zs))
	mat.set_shader_parameter("corriente", 0.6)
	mat.set_shader_parameter("flujo", Vector2(0.9, 0.0))
	mat.set_shader_parameter("color", Color(0.025, 0.09, 0.18))
	mat.set_shader_parameter("color_profundo", Color(0.008, 0.03, 0.08))
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
	# En el distrito del canal hay una cascada cada dos módulos y de ambos muros; cerca de la plaza, una por módulo.
	var cada: int = {"baja": 4, "media": 2}.get(Ajustes.calidad, 1)
	var k := 0
	for lista in [muros_s, muros_n]:
		for t in lista:
			k += 1
			var base: Vector3 = (t as Transform3D).origin
			var en_canal := base.x > 38.0
			if not en_canal and (absf(base.x) > 34.0 or lista == muros_n):
				continue
			if k % cada != 0 or (en_canal and k % 2 == 0):
				continue
			var salida := (t as Transform3D) * Vector3(2.0, -1.4, -0.58)
			var dir := (t as Transform3D).basis * Vector3(0, 0, -1)
			_cascada(e, salida, dir, agua_y)
	# Puentes de celosía que cruzan el canal.
	for px in m.puentes:
		var tp := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(float(px), 0.05, (zs + zn) * 0.5))
		e.add_child(Kit.instancia("pasarela", tp, true))
		# Luz cálida bajo cada puente: refleja en el agua.
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.65, 0.32)
		l.light_energy = 1.6
		l.omni_range = 9.0
		e.sectores.agregar(l, Vector2(float(px), (zs + zn) * 0.5))
		l.global_position = Vector3(float(px), 1.6, (zs + zn) * 0.5)


static func _cascada(e: Escenario, salida: Vector3, dir: Vector3, agua_y: float) -> void:
	var alto := salida.y - agua_y + 0.2
	var q := QuadMesh.new()
	q.size = Vector2(0.55, alto)
	q.material = Shaders.material("cascada")
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var raiz := Node3D.new()
	e.sectores.agregar(raiz, Vector2(salida.x, salida.z))
	raiz.add_child(mi)
	mi.position = salida + dir * 0.25 + Vector3(0, -alto * 0.5 + 0.1, 0)
	# Una segunda lámina cruzada para que tenga volumen desde cualquier ángulo.
	var mi2 := mi.duplicate()
	raiz.add_child(mi2)
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
	raiz.add_child(esp)


## Luces cálidas: en cada distrito, en las puertas de algunos edificios y en algunos faroles de calle
## (los faroles ya son emisivos; solo unos pocos llevan luz real para cuidar el móvil).
static func _faroles_de_calle(e: Escenario, m: Mapa) -> void:
	var por_distrito: Dictionary = {}
	var limite := int(Ajustes.g("luces_ventanas", 3)) + 2
	for p in m.piezas + m.props:
		var tipo := str(p["tipo"])
		if not (tipo in ["edificio", "farol_calle", "casa_chica", "puesto_mercado"]):
			continue
		var c: Vector2 = p["centro"]
		var id := m.distrito_en(c)
		var lista: Array = por_distrito.get_or_add(id, [])
		if lista.size() >= limite * (2 if id == "mercado" else 1):
			continue
		lista.append(p)
		var f := frente(p)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.3)
		var pos := Vector3(c.x, 2.6, c.y) + f * 5.0
		match tipo:
			"farol_calle":
				pos = Vector3(c.x, 3.6, c.y) + f * 0.4
				l.light_energy = 1.8
				l.omni_range = 9.0
			"puesto_mercado":
				pos = Vector3(c.x, 2.4, c.y) + f * 1.2
				l.light_color = Color(1.0, 0.55, 0.25)
				l.light_energy = 2.2
				l.omni_range = 8.0
			"casa_chica":
				pos = Vector3(c.x, 2.4, c.y) + f * 3.0
				l.light_energy = 1.6
				l.omni_range = 8.0
			_:
				l.light_energy = 2.4
				l.omni_range = 11.0
		e.sectores.agregar(l, c)
		l.global_position = pos


## Columnas de vapor en las azoteas y coronas (GPU, pocas partículas grandes).
static func _vapor(e: Escenario, m: Mapa, rng: RandomNumberGenerator) -> void:
	if Ajustes.calidad == "baja":
		return
	var mult := float(Ajustes.g("particulas", 1.0))
	for p in m.piezas:
		var tipo := str(p["tipo"])
		if not (tipo in ["edificio", "silo", "chimenea", "taller_industrial"]):
			continue
		var c: Vector2 = p["centro"]
		if tipo == "edificio" and rng.randf() < 0.6:
			continue   # no todas las azoteas echan vapor
		var g := deg_to_rad(float(p["giro"]))
		var esc := float(p.get("escala", 1.0))
		var off: Vector3 = {"edificio": Vector3(1.5, 10.9, -1.0), "silo": Vector3(2.2, 19.0, 0.0),
			"chimenea": Vector3(0, 20.2, 0), "taller_industrial": Vector3(0, 9.5, 0)}[tipo] * esc
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
		if tipo == "chimenea":
			vp.amount = int(vp.amount * 1.6)
			pm.scale_min = 2.4
			pm.scale_max = 3.6
			pm.initial_velocity_min = 2.0
			pm.initial_velocity_max = 3.2
		e.sectores.agregar(vp, c)
		vp.position = pos


## Agua que gotea de los toldos de los puestos y del techo del mercado y de las pasarelas
## (partículas finas que caen; solo cerca de la cámara porque viven en el sector del distrito).
static func _goteo(e: Escenario, m: Mapa, rng: RandomNumberGenerator) -> void:
	if Ajustes.calidad == "baja":
		return
	var bordes: Array = []   # [centro Vector3, extensión Vector3]
	for p in m.props:
		if p["tipo"] == "puesto_mercado":
			var c: Vector2 = p["centro"]
			var f := frente(p)
			bordes.append([Vector3(c.x, 3.0, c.y) + f * 1.4, Vector3(absf(f.z) * 1.8 + 0.1, 0.05, absf(f.x) * 1.8 + 0.1)])
	for pl in m.plataformas:
		if pl.has("altura0") or pl.get("tipo", "") == "lengua" or float(pl["altura"]) < 2.0:
			continue
		var c2: Vector2 = pl["centro"]
		var md: Vector2 = pl["medio"]
		var h := float(pl["altura"]) - 0.4
		for lado in [-1.0, 1.0]:
			if md.x >= md.y:
				bordes.append([Vector3(c2.x, h, c2.y + lado * md.y), Vector3(md.x, 0.05, 0.05)])
			else:
				bordes.append([Vector3(c2.x + lado * md.x, h, c2.y), Vector3(0.05, 0.05, md.y)])
	var mat := Materiales.particula(Color(0.75, 0.82, 0.95), false)
	for b in bordes:
		var centro: Vector3 = b[0]
		var ext: Vector3 = b[1]
		var gp := GPUParticles3D.new()
		gp.amount = clampi(int((ext.x + ext.z) * 3.0 * float(Ajustes.g("particulas", 1.0))), 4, 90)
		gp.lifetime = maxf(0.4, sqrt(2.0 * centro.y / 9.8))
		gp.visibility_aabb = AABB(Vector3(-ext.x - 1, -centro.y - 1, -ext.z - 1), Vector3(ext.x * 2 + 2, centro.y + 2, ext.z * 2 + 2))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = ext
		pm.direction = Vector3.DOWN
		pm.spread = 2.0
		pm.initial_velocity_min = 0.5
		pm.initial_velocity_max = 1.0
		pm.gravity = Vector3(0, -9.8, 0)
		pm.scale_min = 0.6
		pm.scale_max = 1.0
		gp.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.03, 0.22)
		q.material = mat
		gp.draw_pass_1 = q
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.sectores.agregar(gp, Vector2(centro.x, centro.z))
		gp.global_position = centro


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
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * esc), Vector3(m.centro_aldea.x + cos(a) * r, -1.0, m.centro_aldea.y + sin(a) * r))
		if rng.randf() < 0.55:
			silos.append(t)
		else:
			bloques.append(t)
	e.add_child(Kit.multimalla("silo_lejano", silos, false))
	e.add_child(Kit.multimalla("bloque_lejano", bloques, false))
