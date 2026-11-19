class_name Vestimenta
extends RefCounted
## Piezas de ropa ninja hechas por código y fijadas a los huesos del esqueleto:
## banda con placa y símbolo de la aldea, chaleco, vendas, sandalias abiertas
## y emblema del clan en la espalda. Colores y opciones vienen de /data.


static func vestir(pv: PersonajeVisual, aspecto: Dictionary, aldea: Dictionary, clan: Dictionary) -> void:
	var c_banda := Datos.color(str(aspecto.get("banda", "#2b3550")))
	var c_chaleco := Datos.color(str(aspecto.get("chaleco", "#3d4a3a")))
	var c_vendas := Datos.color(str(aspecto.get("vendas", "#ddd6c4")))
	var c_sandalia := Datos.color(str(aspecto.get("sandalias", "#2a2a30")))
	var c_piel := Datos.color(str(aspecto.get("piel", "#e8c4a0")))
	var metal := Materiales.solido(Color(0.78, 0.8, 0.84), 0.25, 0.9)
	var grabado := Materiales.solido(Color(0.18, 0.19, 0.22), 0.5, 0.6)

	# --- Banda en la frente con placa metálica y el símbolo de la aldea (líneas verticales).
	var cabeza := pv.hueso("Cabeza")
	var banda := Materiales.cilindro(0.127, 0.127, 0.055, Materiales.solido(c_banda, 0.9), 10)
	banda.position = Vector3(0, 0.19, 0.0)
	cabeza.add_child(banda)
	var placa := Materiales.caja(Vector3(0.13, 0.055, 0.012), metal)
	placa.position = Vector3(0, 0.19, 0.127)
	cabeza.add_child(placa)
	var lineas := int(aldea.get("simbolo_lineas", 4))
	for i in lineas:
		var l := Materiales.caja(Vector3(0.007, 0.036, 0.004), grabado)
		var x := (float(i) - (lineas - 1) * 0.5) * 0.02
		l.position = Vector3(x, 0.19, 0.134)
		cabeza.add_child(l)
	for lado in [-1.0, 1.0]:
		var cola := Materiales.caja(Vector3(0.025, 0.11, 0.012), Materiales.solido(c_banda, 0.9))
		cola.position = Vector3(0.025 * lado, 0.15, -0.13)
		cola.rotation_degrees = Vector3(-20, 0, 12 * lado)
		cabeza.add_child(cola)

	# --- Chaleco ninja con cuello alto y bolsillos.
	var m_chaleco := Materiales.solido(c_chaleco, 0.85)
	var pecho := pv.hueso("Pecho")
	# Con cuerpo continuo el chaleco es una malla deformable de Blender; aquí solo van bolsillos y detalles.
	if not pv.cuerpo_continuo:
		var torso := Materiales.caja(Vector3(0.39, 0.27, 0.23), m_chaleco)
		torso.position = Vector3(0, 0.12, 0)
		pecho.add_child(torso)
		var cuello := Materiales.cilindro(0.1, 0.12, 0.08, m_chaleco, 8)
		cuello.position = Vector3(0, 0.27, -0.01)
		pecho.add_child(cuello)
	for lado in [-1.0, 1.0]:
		var bolsillo := Materiales.caja(Vector3(0.09, 0.07, 0.03), Materiales.solido(c_chaleco.darkened(0.15), 0.85))
		bolsillo.position = Vector3(0.085 * lado, 0.04, 0.122)
		pecho.add_child(bolsillo)
		if not pv.cuerpo_continuo:
			var hombrera := Materiales.caja(Vector3(0.09, 0.05, 0.2), m_chaleco)
			hombrera.position = Vector3(0.16 * lado, 0.25, 0)
			pecho.add_child(hombrera)
	var columna := pv.hueso("Columna")
	if not pv.cuerpo_continuo:
		var abdomen := Materiales.caja(Vector3(0.33, 0.2, 0.21), m_chaleco)
		abdomen.position = Vector3(0, 0.1, 0)
		columna.add_child(abdomen)
	var cinturon := Materiales.cilindro(0.15, 0.15, 0.045, Materiales.solido(Color(0.15, 0.14, 0.13), 0.7), 12) if pv.cuerpo_continuo else Materiales.caja(Vector3(0.34, 0.045, 0.22), Materiales.solido(Color(0.15, 0.14, 0.13), 0.7))
	if pv.cuerpo_continuo:
		cinturon.scale = Vector3(1.0, 1.0, 0.76)
	cinturon.position = Vector3(0, 0.0, 0)
	columna.add_child(cinturon)

	# --- Emblema del clan en la espalda (abanico rojo y blanco).
	if aspecto.get("emblema_espalda", false) and clan.get("emblema") != null:
		var em: Dictionary = clan["emblema"]
		var abanico := crear_abanico(Datos.color(str(em["color_superior"])), Datos.color(str(em["color_inferior"])))
		abanico.position = Vector3(0, 0.13, -0.122 if not pv.cuerpo_continuo else -0.128)
		abanico.rotation_degrees = Vector3(0, 180, 0)
		pecho.add_child(abanico)

	# --- Vendas en antebrazos y espinillas (anillos superpuestos).
	var m_vendas := Materiales.solido(c_vendas, 0.95)
	var m_vendas2 := Materiales.solido(c_vendas.darkened(0.1), 0.95)
	for h in ["AntebrazoI", "AntebrazoD"]:
		for i in 4:
			var r_v := 0.047 if pv.cuerpo_continuo else 0.054
			var anillo := Materiales.cilindro(r_v, r_v - 0.002, 0.045, m_vendas if i % 2 == 0 else m_vendas2, 8)
			anillo.position = Vector3(0, -0.06 - i * 0.04, 0)
			anillo.rotation_degrees = Vector3(0, 0, 4 if i % 2 == 0 else -4)
			pv.hueso(h).add_child(anillo)
	for h in ["RodillaI", "RodillaD"]:
		for i in 4:
			var r_p := 0.06 if pv.cuerpo_continuo else 0.066
			var anillo := Materiales.cilindro(r_p, r_p - 0.004, 0.05, m_vendas if i % 2 == 0 else m_vendas2, 8)
			anillo.position = Vector3(0, -0.2 - i * 0.045, 0)
			anillo.rotation_degrees = Vector3(4 if i % 2 == 0 else -4, 0, 0)
			pv.hueso(h).add_child(anillo)

	# --- Sandalias abiertas: suela, tiras y dedos visibles.
	var m_sandalia := Materiales.solido(c_sandalia, 0.8)
	for h in ["PieI", "PieD"]:
		var pie := pv.hueso(h)
		var suela := Materiales.caja(Vector3(0.1, 0.025, 0.25), m_sandalia)
		suela.position = Vector3(0, -0.058, 0.05)
		pie.add_child(suela)
		var talon := Materiales.caja(Vector3(0.1, 0.06, 0.02), m_sandalia)
		talon.position = Vector3(0, -0.03, -0.065)
		pie.add_child(talon)
		for z in [0.03, 0.1]:
			var tira := Materiales.caja(Vector3(0.095, 0.018, 0.022), m_sandalia)
			tira.position = Vector3(0, -0.012, z)
			pie.add_child(tira)
		var dedos := Materiales.caja(Vector3(0.08, 0.03, 0.05), Materiales.solido(c_piel, 0.7))
		dedos.position = Vector3(0, -0.032, 0.15)
		pie.add_child(dedos)

	# --- Máscara (ninja enemigo).
	if aspecto.get("mascara", false):
		var mascara := Materiales.caja(Vector3(0.2, 0.09, 0.05), Materiales.solido(Color(0.25, 0.27, 0.3), 0.5, 0.4))
		mascara.position = Vector3(0, 0.06, 0.105)
		cabeza.add_child(mascara)
		for lado in [-1.0, 1.0]:
			var filtro := Materiales.cilindro(0.025, 0.025, 0.04, metal, 8)
			filtro.position = Vector3(0.06 * lado, 0.05, 0.135)
			filtro.rotation_degrees = Vector3(90, 0, 0)
			cabeza.add_child(filtro)


## Con el ninja del modelo IA la ropa ya viene en la malla: solo se añade la máscara (ropa de sigilo).
## El impermeable se resuelve recoloreando chaleco y camisa (PersonajeVisual.recolorear).
static func vestir_ia(pv: PersonajeVisual, aspecto: Dictionary) -> void:
	for acc in aspecto.get("accesorios", []):
		_accesorio(pv, str(acc))
	if aspecto.get("mascara", false):
		var cabeza := pv.hueso("Cabeza")
		var mascara := Materiales.caja(Vector3(0.15, 0.07, 0.05), Materiales.solido(Color(0.25, 0.27, 0.3), 0.5, 0.4))
		mascara.position = Vector3(0, 0.03, 0.085)
		cabeza.add_child(mascara)
		var metal := Materiales.solido(Color(0.78, 0.8, 0.84), 0.25, 0.9)
		for lado in [-1.0, 1.0]:
			var filtro := Materiales.cilindro(0.02, 0.02, 0.035, metal, 8)
			filtro.position = Vector3(0.045 * lado, 0.025, 0.112)
			filtro.rotation_degrees = Vector3(90, 0, 0)
			cabeza.add_child(filtro)


## Accesorios de los NPC (piezas hechas por código, pegadas a los huesos).
static func _accesorio(pv: PersonajeVisual, id: String) -> void:
	match id:
		"kunai":
			var mano := pv.hueso("ManoD")
			var hoja := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.05, 0.2, 0.012)
			pm.material = Materiales.solido(Color(0.75, 0.78, 0.82), 0.25, 0.9)
			hoja.mesh = pm
			hoja.position = Vector3(0, -0.2, 0.03)
			hoja.rotation_degrees = Vector3(180, 0, 0)
			mano.add_child(hoja)
			var mango := Materiales.cilindro(0.012, 0.012, 0.09, Materiales.solido(Color(0.12, 0.12, 0.14), 0.8), 6)
			mango.position = Vector3(0, -0.07, 0.03)
			mano.add_child(mango)
			var anillo := Materiales.cilindro(0.022, 0.022, 0.008, Materiales.solido(Color(0.6, 0.6, 0.65), 0.3, 0.8), 8)
			anillo.position = Vector3(0, -0.01, 0.03)
			anillo.rotation_degrees = Vector3(90, 0, 0)
			mano.add_child(anillo)
		"respirador":
			pass   # lo pone «mascara» (respirador con filtros)
		"mascara_rebelde":
			# Máscara blanca agrietada que cubre la cara, con rendijas para los ojos.
			var cabeza := pv.hueso("Cabeza")
			var m := Materiales.esfera(0.105, Materiales.solido(Color(0.88, 0.86, 0.82), 0.6), 12)
			m.scale = Vector3(0.95, 1.15, 0.45)
			m.position = Vector3(0, 0.07, 0.08)
			cabeza.add_child(m)
			for lado in [-1.0, 1.0]:
				var ojo := Materiales.caja(Vector3(0.04, 0.012, 0.01), Materiales.solido(Color(0.05, 0.05, 0.06), 0.9))
				ojo.position = Vector3(0.035 * lado, 0.1, 0.128)
				cabeza.add_child(ojo)
			var grieta := Materiales.caja(Vector3(0.005, 0.07, 0.006), Materiales.solido(Color(0.25, 0.22, 0.2), 0.9))
			grieta.position = Vector3(0.02, 0.06, 0.13)
			grieta.rotation_degrees = Vector3(0, 0, 20)
			cabeza.add_child(grieta)
		"banda_tachada":
			# Raya horizontal sobre la placa de la banda (desertores).
			var raya := Materiales.caja(Vector3(0.1, 0.007, 0.006), Materiales.solido(Color(0.1, 0.08, 0.08), 0.9))
			raya.position = Vector3(0, 0.155, 0.112)
			pv.hueso("Cabeza").add_child(raya)
		"delantal":
			var d := Materiales.caja(Vector3(0.36, 0.5, 0.012), Materiales.solido(Color(0.82, 0.78, 0.68), 0.95))
			d.position = Vector3(0, -0.12, 0.14)
			pv.hueso("Caderas").add_child(d)
			var pecho := Materiales.caja(Vector3(0.24, 0.2, 0.012), Materiales.solido(Color(0.82, 0.78, 0.68), 0.95))
			pecho.position = Vector3(0, 0.05, 0.15)
			pv.hueso("Pecho").add_child(pecho)
		"sombrero_paja":
			# Sombrero cónico de paja para la lluvia.
			var sombrero := Materiales.cilindro(0.015, 0.33, 0.16, Materiales.solido(Color(0.74, 0.62, 0.36), 0.95), 16)
			sombrero.position = Vector3(0, 0.27, 0.0)
			pv.hueso("Cabeza").add_child(sombrero)
		"pergamino":
			# Pergamino grande cruzado en la espalda.
			var rollo := Materiales.cilindro(0.06, 0.06, 0.62, Materiales.solido(Color(0.86, 0.8, 0.66), 0.9), 12)
			rollo.position = Vector3(0, 0.0, -0.17)
			rollo.rotation_degrees = Vector3(0, 0, 70)
			pv.hueso("Pecho").add_child(rollo)
			for lado in [-1.0, 1.0]:
				var tapa := Materiales.cilindro(0.065, 0.065, 0.05, Materiales.solido(Color(0.55, 0.12, 0.1), 0.7), 12)
				tapa.position = Vector3(cos(deg_to_rad(-20)) * 0.3 * lado, sin(deg_to_rad(70)) * 0.3 * lado * 0.36, -0.17)
				tapa.rotation_degrees = Vector3(0, 0, 70)
				pv.hueso("Pecho").add_child(tapa)
		"chaleco_rango":
			# Hombreras del chaleco de rango alto.
			for lado in ["I", "D"]:
				var h := Materiales.esfera(0.075, Materiales.solido(Color(0.32, 0.38, 0.3), 0.7), 10)
				h.scale = Vector3(1.0, 0.6, 1.1)
				h.position = Vector3(0, 0.04, 0)
				pv.hueso("Brazo" + lado).add_child(h)


## Abanico del clan: parte superior roja redondeada, franja inferior blanca y mango.
static func crear_abanico(rojo: Color, blanco: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 0.085
	var centro := Vector2(0, 0.03)
	var corte := centro.y - r * 0.45   # línea que separa rojo (arriba) y blanco (abajo)
	var tc := asin((corte - centro.y) / r)   # ángulo de los extremos de la cuerda (negativo)
	var lados := 14
	var poli_rojo: Array[Vector2] = []
	for i in lados + 1:
		var a := lerpf(tc, PI - tc, float(i) / lados)
		poli_rojo.append(centro + Vector2(cos(a), sin(a)) * r)
	var poli_blanco: Array[Vector2] = []
	for i in 7:
		var a2 := lerpf(PI - tc, TAU + tc, float(i) / 6.0)
		poli_blanco.append(centro + Vector2(cos(a2), sin(a2)) * r)
	_abanico_poligono(st, poli_rojo, rojo)
	_abanico_poligono(st, poli_blanco, blanco)
	# Mango
	var m := [Vector2(-0.012, centro.y - r + 0.005), Vector2(0.012, centro.y - r + 0.005), Vector2(0.012, centro.y - r - 0.08), Vector2(-0.012, centro.y - r - 0.08)]
	var mango: Array[Vector2] = []
	for v in m:
		mango.append(v)
	_abanico_poligono(st, mango, blanco.darkened(0.08))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.7
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	return mi


static func _abanico_poligono(st: SurfaceTool, poli: Array[Vector2], c: Color) -> void:
	for i in range(1, poli.size() - 1):
		for v in [poli[0], poli[i], poli[i + 1]]:
			st.set_color(c)
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(Vector3(v.x, v.y, 0))
