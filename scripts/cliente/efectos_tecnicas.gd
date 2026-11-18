class_name EfectosTecnicas
extends Node3D
## Visuales del repertorio (primer bloque): bestia de rayo del cielo, esfera giratoria en la mano,
## llamas negras, figura espectral protectora, onda de repulsión, aura de las puertas, zonas en el
## suelo, clones y descargas. Cada nivel escala tamaño, partículas, luz, sacudida y marcas.

const COLOR_ESFERA := Color(0.45, 0.75, 1.0)
const COLOR_ESPECTRAL := Color(0.6, 0.35, 1.0)
const COLOR_PUERTAS := [Color(0.35, 1.0, 0.5), Color(0.3, 0.9, 1.0), Color(1.0, 0.25, 0.2)]

var efectos: Efectos
var genericas: EfectosGenericos
var sonidos: Sonidos
var _adjuntos: Dictionary = {}   # "idEntidad:efecto" -> Node3D
var _zonas: Dictionary = {}      # id zona -> Node3D


func _camara() -> CamaraTercera:
	return efectos.camara


# ------------------------------------------------------------------ fuego negro

func fuego_negro(radio: float) -> MeshInstance3D:
	var mi := efectos.esfera_fuego(radio, 1.0)
	var m: ShaderMaterial = mi.material_override
	m.set_shader_parameter("color_nucleo", Color(0.25, 0.05, 0.3))
	m.set_shader_parameter("color_medio", Color(0.02, 0.0, 0.03))
	m.set_shader_parameter("color_borde", Color(0.35, 0.05, 0.4))
	m.set_shader_parameter("intensidad", 1.0)
	m.set_shader_parameter("desplazamiento", 0.35)
	return mi


func _llamas_negras(nodo: Node3D, alto: float, ancho: float, cantidad: int) -> void:
	var p := efectos.particulas({"cantidad": cantidad, "vida": 0.8, "radio": ancho, "direccion": Vector3.UP, "dispersion": 18.0,
		"vel_min": 1.0, "vel_max": 2.5, "gravedad": Vector3(0, 1.5, 0), "tam_min": 0.25, "tam_max": 0.5,
		"color": Color(0.05, 0.0, 0.08, 0.9), "color_fin": Color(0.25, 0.05, 0.3, 0.0), "aditivo": false, "local": true})
	p.position = Vector3(0, alto * 0.3, 0)
	nodo.add_child(p)
	p.emitting = true


# ------------------------------------------------------------------ eventos

func evento(ev: Dictionary, mi_id: int, pos_entidad: Callable, visual_de: Callable, lenta: Callable) -> void:
	var tipo := str(ev["tipo"])
	var nivel := int(ev.get("nivel", 1))
	var propio := int(ev.get("entidad", -1)) == mi_id
	match tipo:
		"kirin_invocar":
			# El cielo se oscurece y retumba antes de la caída.
			if efectos.escenario != null:
				efectos.escenario.destello(Color(0.5, 0.6, 1.0), 1.5 + nivel, 0.6)
			if sonidos != null:
				sonidos.tocar("trueno", -6.0 + nivel * 2.0, 1.2)
			if propio and nivel >= 3:
				lenta.call(0.35, 0.6)
		"kirin":
			kirin(ev["pos"], nivel, float(ev["radio"]), bool(ev.get("bestia", false)))
		"chidori_embiste":
			if str(ev.get("jutsu", "")) == "rasengan":
				efectos.polvo(ev["desde"], 8 + nivel * 8)
		"amaterasu":
			amaterasu(ev["pos"], nivel)
			if propio and nivel >= 3:
				lenta.call(0.3, 0.45)
		"ardiendo":
			pass
		"susanoo":
			if bool(ev.get("activo", false)):
				efectos.sacudir_desde(pos_entidad.call(int(ev["entidad"])), float(Datos.nivel_jutsu("susanoo", nivel).get("sacudida", 0.5)))
				if propio and nivel >= 3:
					lenta.call(0.3, 0.5)
		"susanoo_espada":
			espada(ev["pos"], float(ev["radio"]), nivel)
		"shinra":
			shinra(ev["pos"], float(ev["radio"]), nivel, float(ev.get("crater", 0.0)))
			if propio and nivel >= 3:
				lenta.call(0.25, 0.6)
		"golpe_definitivo":
			golpe_definitivo(ev["pos"], float(ev["radio"]))
			if propio:
				lenta.call(0.2, 0.7)
		"descarga":
			var pares: Array = []
			for p in ev["puntos"]:
				pares.append([ev["pos"], p])
			if not pares.is_empty():
				efectos.rayos_fugaces(pares, 0.05, 0.3, 2)
			efectos.rafaga(ev["pos"], {"cantidad": 60 + nivel * 40, "vida": 0.4, "radio": 0.4, "vel_min": 6.0, "vel_max": float(ev["radio"]) * 4.0,
				"frenado": 8.0, "tam_min": 0.04, "tam_max": 0.08, "color": Efectos.COLOR_RAYO_NUCLEO, "estirado": true, "tam_quad": Vector2(0.3, 2.5)})
			efectos.luz_temporal(ev["pos"], Efectos.COLOR_RAYO, 6.0, float(ev["radio"]) * 3.0, 0.5)
		"clones":
			clones(ev["desde"], ev["puntos"], visual_de.call(int(ev["entidad"])))
		"modo":
			if bool(ev.get("activo", false)) and str(ev.get("modo", "")) == "ocho_puertas":
				var p: Vector3 = pos_entidad.call(int(ev["entidad"]))
				efectos.rafaga(p + Vector3(0, 1, 0), {"cantidad": 40 + nivel * 40, "vida": 0.8, "radio": 0.4, "vel_min": 2.0, "vel_max": 6.0,
					"tam_min": 0.3, "tam_max": 0.7, "color": COLOR_PUERTAS[nivel - 1], "aditivo": true})
				efectos.sacudir_desde(p, 0.3 * nivel)
				if propio and nivel >= 3:
					lenta.call(0.3, 0.5)


# ------------------------------------------------------------------ Kirin

func kirin(pos: Vector3, nivel: int, radio: float, bestia: bool) -> void:
	var nd := Datos.nivel_jutsu("kirin", nivel)
	var arriba := pos + Vector3(randf_range(-3, 3), 70.0, randf_range(-3, 3))
	var pares: Array = [[arriba, pos]]
	if bestia:
		# La bestia: varios rayos gruesos entrelazados y una cabeza que cae.
		for k in 3:
			pares.append([arriba + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), pos + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))])
		var cabeza := Materiales.esfera(1.4 if nivel < 3 else 1.1, Materiales.emisivo(Color(0.75, 0.9, 1.0), 4.0), 10)
		add_child(cabeza)
		cabeza.global_position = arriba
		cabeza.scale = Vector3(1.0, 0.7, 1.6)
		var tw := create_tween()
		tw.tween_property(cabeza, "global_position", pos + Vector3(0, 1.0, 0), 0.22).set_ease(Tween.EASE_IN)
		tw.tween_callback(cabeza.queue_free)
	efectos.rayos_fugaces(pares, 0.35 if bestia else 0.22, 0.5, 3)
	efectos.rafaga(pos + Vector3(0, 0.5, 0), {"cantidad": int(nd.get("particulas", 120)), "vida": 0.6, "radio": radio * 0.3, "vel_min": 8.0, "vel_max": 18.0,
		"frenado": 10.0, "tam_min": 0.06, "tam_max": 0.14, "color": Efectos.COLOR_RAYO_NUCLEO, "estirado": true, "tam_quad": Vector2(0.4, 3.0)})
	efectos.rafaga(Vector3(pos.x, 0.3, pos.z), {"cantidad": 40, "vida": 1.2, "radio": radio * 0.6, "direccion": Vector3.UP, "dispersion": 50.0,
		"vel_min": 2.0, "vel_max": 6.0, "gravedad": Vector3(0, -6, 0), "tam_min": 0.4, "tam_max": 0.9, "color": Color(0.7, 0.75, 0.85, 0.5), "aditivo": false})
	efectos.luz_temporal(pos + Vector3(0, 3, 0), Efectos.COLOR_RAYO, float(nd.get("luz", 6.0)), float(nd.get("luz_rango", 40.0)), 0.6)
	if efectos.escenario != null:
		efectos.escenario.destello(Color(0.75, 0.85, 1.0), 3.0 + nivel * 1.5, 0.45)
	efectos.sacudir_desde(pos, float(nd.get("sacudida", 0.8)))
	efectos.marca_suelo(pos, float(nd.get("marca", 3.0)), Color(0.04, 0.05, 0.1, 0.9), true)
	if sonidos != null:
		sonidos.tocar("trueno", 2.0, 1.4)
		sonidos.tocar("explosion", -2.0, 1.3)


# ------------------------------------------------------------------ esfera giratoria (Rasengan)

func crear_esfera_mano(pv: PersonajeVisual, nivel: int) -> Node3D:
	var nd := Datos.nivel_jutsu("rasengan", nivel)
	var r := float(nd.get("esfera", 0.2))
	var nodo := Node3D.new()
	pv.mano_derecha().add_child(nodo)
	nodo.position = Vector3(0, -0.1 - r * 0.6, 0.06 + r * 0.3)
	var esfera := efectos.esfera_fuego(r, 1.4)
	var m: ShaderMaterial = esfera.material_override
	m.set_shader_parameter("color_nucleo", Color(0.95, 0.98, 1.0))
	m.set_shader_parameter("color_medio", Color(0.35, 0.65, 1.0))
	m.set_shader_parameter("color_borde", Color(0.1, 0.25, 0.8))
	m.set_shader_parameter("velocidad", 4.0)
	m.set_shader_parameter("desplazamiento", 0.1)
	nodo.add_child(esfera)
	var nucleo := Materiales.esfera(r * 0.45, Materiales.emisivo(Color(0.85, 0.95, 1.0), 3.0), 10)
	nodo.add_child(nucleo)
	var anillos := efectos.particulas({"cantidad": int(nd.get("particulas", 40)), "vida": 0.3, "radio": r * 1.1, "vel_min": 1.0, "vel_max": 3.0 + nivel,
		"tam_min": 0.02, "tam_max": 0.05, "color": Color(0.8, 0.92, 1.0), "local": true})
	nodo.add_child(anillos)
	anillos.emitting = true
	var luz := OmniLight3D.new()
	luz.light_color = COLOR_ESFERA
	luz.light_energy = float(nd.get("luz", 2.5))
	luz.omni_range = float(nd.get("luz_rango", 6.0))
	nodo.add_child(luz)
	var tw := nodo.create_tween().set_loops()
	tw.tween_property(esfera, "rotation:y", TAU, 0.25).from(0.0)
	return nodo


func impacto_esfera(pos: Vector3, nivel: int) -> void:
	var nd := Datos.nivel_jutsu("rasengan", nivel)
	var r := float(nd.get("esfera", 0.2)) * 6.0
	var onda := Materiales.esfera(0.5, Materiales.transparente(Color(0.5, 0.8, 1.0, 0.55), true), 16)
	add_child(onda)
	onda.global_position = pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(onda, "scale", Vector3.ONE * r, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(onda, "transparency", 1.0, 0.4)
	tw.chain().tween_callback(onda.queue_free)
	efectos.rafaga(pos, {"cantidad": int(nd.get("particulas", 40)), "vida": 0.5, "radio": 0.3, "vel_min": 5.0, "vel_max": 10.0 + nivel * 4.0,
		"frenado": 6.0, "tam_min": 0.05, "tam_max": 0.12, "color": Color(0.75, 0.9, 1.0)})
	efectos.polvo(pos, 20 + nivel * 10)
	efectos.luz_temporal(pos, COLOR_ESFERA, float(nd.get("luz", 2.5)) * 2.0, float(nd.get("luz_rango", 6.0)), 0.5)
	efectos.sacudir_desde(pos, float(nd.get("sacudida", 0.4)))
	efectos.marca_suelo(Vector3(pos.x, 0, pos.z), float(nd.get("marca", 1.5)), Color(0.05, 0.06, 0.1, 0.85), true)


func clones(desde: Vector3, puntos: Array, original: Node3D) -> void:
	# Clones que aparecen en una nube de humo, golpean y desaparecen.
	for p in puntos:
		var pos: Vector3 = p
		var pv := PersonajeVisual.new()
		add_child(pv)
		pv.construir("jugador_uchiha")
		pv.global_position = pos + (desde - pos).normalized() * 1.2
		pv.look_at(Vector3(pos.x, pv.global_position.y, pos.z), Vector3.UP)
		pv.rotate_y(PI)
		pv.reproducir("chidori_embiste", 0.0)
		efectos.rafaga(pv.global_position + Vector3(0, 1, 0), {"cantidad": 30, "vida": 0.7, "radio": 0.5, "vel_min": 1.0, "vel_max": 3.0,
			"tam_min": 0.5, "tam_max": 0.9, "color": Color(0.9, 0.92, 0.95, 0.6), "aditivo": false})
		impacto_esfera(pos + Vector3(0, 1.0, 0), 3)
		var tw := create_tween()
		tw.tween_interval(0.6)
		tw.tween_callback(func():
			efectos.rafaga(pv.global_position + Vector3(0, 1, 0), {"cantidad": 30, "vida": 0.7, "radio": 0.5, "vel_min": 1.0, "vel_max": 3.0,
				"tam_min": 0.5, "tam_max": 0.9, "color": Color(0.9, 0.92, 0.95, 0.6), "aditivo": false})
			pv.queue_free())


# ------------------------------------------------------------------ Amaterasu

func amaterasu(pos: Vector3, nivel: int) -> void:
	var nd := Datos.nivel_jutsu("amaterasu", nivel)
	efectos.rafaga(pos + Vector3(0, 1.0, 0), {"cantidad": int(nd.get("particulas", 50)), "vida": 0.9, "radio": 0.6, "vel_min": 1.0, "vel_max": 3.5,
		"gravedad": Vector3(0, 2, 0), "tam_min": 0.3, "tam_max": 0.7, "color": Color(0.03, 0.0, 0.05, 0.95), "color_fin": Color(0.3, 0.05, 0.35, 0.0), "aditivo": false})
	efectos.sacudir_desde(pos, float(nd.get("sacudida", 0.3)))
	efectos.marca_suelo(pos, float(nd.get("marca", 1.6)), Color(0.02, 0.0, 0.03, 0.95))


# ------------------------------------------------------------------ Susanoo

func crear_susanoo(nivel: int) -> Node3D:
	var raiz := Node3D.new()
	var mat := Shaders.material("espectral")
	mat.set_shader_parameter("color", COLOR_ESPECTRAL)
	mat.set_shader_parameter("intensidad", 1.2 + nivel * 0.3)
	var esc: float = [1.0, 1.8, 3.0][nivel - 1]
	# Costillas: arcos alrededor del torso.
	for k in 5:
		var t := TorusMesh.new()
		t.inner_radius = 0.42 + k * 0.03
		t.outer_radius = 0.5 + k * 0.03
		t.rings = 20
		t.ring_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = t
		mi.material_override = mat
		mi.position = Vector3(0, 0.95 + k * 0.17, -0.05)
		mi.scale = Vector3(1.15, 1.0, 0.8)
		raiz.add_child(mi)
	var columna := Materiales.cilindro(0.06, 0.06, 1.1, mat, 6)
	columna.position = Vector3(0, 0.9, -0.42)
	raiz.add_child(columna)
	if nivel >= 2:
		# Torso, cabeza con ojos, brazos y arco.
		var torso := Materiales.capsula(0.8, 2.4, mat)
		torso.position = Vector3(0, 1.6, -0.3)
		torso.scale = Vector3(1.25, 1.0, 0.75)
		raiz.add_child(torso)
		var cabeza := Materiales.esfera(0.55, mat, 12)
		cabeza.position = Vector3(0, 3.2, -0.2)
		raiz.add_child(cabeza)
		for lado in [-1.0, 1.0]:
			var ojo := Materiales.caja(Vector3(0.18, 0.05, 0.05), Materiales.emisivo(Color(1.0, 0.85, 0.3), 4.0))
			ojo.position = Vector3(0.2 * lado, 3.25, 0.32)
			raiz.add_child(ojo)
			var brazo := Materiales.capsula(0.22, 1.8, mat)
			brazo.position = Vector3(1.2 * lado, 2.0, 0.0)
			brazo.rotation_degrees = Vector3(-30, 0, 35 * lado)
			raiz.add_child(brazo)
		var arco := TorusMesh.new()
		arco.inner_radius = 1.0
		arco.outer_radius = 1.08
		var mi_a := MeshInstance3D.new()
		mi_a.mesh = arco
		mi_a.material_override = mat
		mi_a.position = Vector3(-1.6, 2.2, 0.6)
		mi_a.rotation_degrees = Vector3(0, 0, 90)
		mi_a.scale = Vector3(1.0, 1.0, 0.25)
		raiz.add_child(mi_a)
	if nivel >= 3:
		# Cuernos, armadura y espada.
		for lado in [-1.0, 1.0]:
			var cuerno := Materiales.cilindro(0.0, 0.12, 0.8, mat, 5)
			cuerno.position = Vector3(0.3 * lado, 3.75, -0.25)
			cuerno.rotation_degrees = Vector3(-20, 0, -25 * lado)
			raiz.add_child(cuerno)
		var hombros := Materiales.caja(Vector3(3.0, 0.4, 1.2), mat)
		hombros.position = Vector3(0, 2.75, -0.2)
		raiz.add_child(hombros)
		var espada := Materiales.caja(Vector3(0.12, 3.6, 0.35), Materiales.emisivo(Color(0.75, 0.55, 1.0), 3.0))
		espada.position = Vector3(1.9, 3.2, 0.9)
		espada.rotation_degrees = Vector3(30, 0, -15)
		raiz.add_child(espada)
	raiz.scale = Vector3.ONE * esc
	var luz := OmniLight3D.new()
	luz.light_color = COLOR_ESPECTRAL
	luz.light_energy = 1.5 + nivel
	luz.omni_range = 4.0 * esc
	luz.position = Vector3(0, 1.5, 0)
	raiz.add_child(luz)
	return raiz


func espada(pos: Vector3, radio: float, nivel: int) -> void:
	var arco := Materiales.disco(radio, Materiales.transparente(Color(0.7, 0.45, 1.0, 0.6), true), 24)
	add_child(arco)
	arco.global_position = Vector3(pos.x, 1.2, pos.z)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(arco, "rotation:y", PI, 0.3)
	tw.tween_property(arco, "transparency", 1.0, 0.35)
	tw.chain().tween_callback(arco.queue_free)
	efectos.sacudir_desde(pos, 0.6)
	efectos.marca_suelo(pos, radio * 0.8, Color(0.05, 0.03, 0.1, 0.8), true)


# ------------------------------------------------------------------ Shinra Tensei

func shinra(pos: Vector3, radio: float, nivel: int, crater: float) -> void:
	var nd := Datos.nivel_jutsu("shinra_tensei", nivel)
	var centro := pos + Vector3(0, 1.0, 0)
	# Esfera de distorsión que se expande y anillo en el suelo.
	var onda := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	onda.mesh = sm
	var mat := Shaders.material("calor")
	mat.set_shader_parameter("fuerza", 0.06)
	onda.material_override = mat
	add_child(onda)
	onda.global_position = centro
	onda.scale = Vector3.ONE * 0.5
	var anillo := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.92
	tor.outer_radius = 1.0
	tor.rings = 40
	tor.ring_segments = 4
	anillo.mesh = tor
	anillo.material_override = Materiales.transparente(Color(0.85, 0.8, 1.0, 0.7), true)
	add_child(anillo)
	anillo.global_position = Vector3(pos.x, 0.15, pos.z)
	anillo.scale = Vector3(0.5, 0.2, 0.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(onda, "scale", Vector3.ONE * radio, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(anillo, "scale", Vector3(radio, 0.2, radio), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(anillo, "transparency", 1.0, 0.6)
	tw.chain().tween_callback(func():
		onda.queue_free()
		anillo.queue_free())
	efectos.rafaga(Vector3(pos.x, 0.3, pos.z), {"cantidad": int(nd.get("particulas", 60)), "vida": 0.9, "radio": 0.5, "direccion": Vector3(1, 0.1, 0),
		"dispersion": 180.0, "vel_min": radio * 1.2, "vel_max": radio * 2.0, "frenado": radio, "tam_min": 0.5, "tam_max": 1.0,
		"color": Color(0.65, 0.65, 0.7, 0.5), "aditivo": false})
	efectos.sacudir_desde(pos, float(nd.get("sacudida", 0.5)))
	if efectos.escenario != null and nivel >= 2:
		efectos.escenario.destello(Color(0.85, 0.8, 1.0), 1.0 + nivel, 0.4)
	if crater > 0.0:
		efectos.marca_suelo(pos, crater, Color(0.03, 0.03, 0.04, 0.95), true)
		efectos.marca_suelo(pos, crater * 0.6, Color(0.0, 0.0, 0.0, 0.8), true)
	if sonidos != null:
		sonidos.tocar("explosion", -6.0 + nivel * 3.0, 0.6)


# ------------------------------------------------------------------ Ocho Puertas

func crear_aura_puertas(nivel: int) -> Node3D:
	var raiz := Node3D.new()
	var col: Color = COLOR_PUERTAS[clampi(nivel, 1, 3) - 1]
	var vapor := efectos.particulas({"cantidad": 30 + nivel * 30, "vida": 0.9, "radio": 0.35, "direccion": Vector3.UP, "dispersion": 25.0,
		"vel_min": 1.0, "vel_max": 2.5 + nivel, "gravedad": Vector3(0, 1, 0), "tam_min": 0.25, "tam_max": 0.5 + nivel * 0.15,
		"color": Color(col.r, col.g, col.b, 0.45), "aditivo": true})
	vapor.position = Vector3(0, 0.9, 0)
	raiz.add_child(vapor)
	vapor.emitting = true
	var luz := OmniLight3D.new()
	luz.light_color = col
	luz.light_energy = 1.0 + nivel * 0.8
	luz.omni_range = 2.5 + nivel
	luz.position = Vector3(0, 1.2, 0)
	raiz.add_child(luz)
	if nivel >= 3:
		var mat := Shaders.material("espectral")
		mat.set_shader_parameter("color", Color(1.0, 0.3, 0.25))
		var envoltura := Materiales.capsula(0.55, 2.1, mat)
		envoltura.position = Vector3(0, 1.0, 0)
		raiz.add_child(envoltura)
	return raiz


func golpe_definitivo(pos: Vector3, radio: float) -> void:
	efectos.rafaga(pos + Vector3(0, 1, 0), {"cantidad": 220, "vida": 1.0, "radio": 0.5, "vel_min": 10.0, "vel_max": 24.0, "frenado": 10.0,
		"tam_min": 0.4, "tam_max": 0.9, "color": Color(1.0, 0.35, 0.25, 0.7)})
	shinra(pos, radio * 1.4, 2, radio)
	efectos.luz_temporal(pos + Vector3(0, 2, 0), Color(1.0, 0.4, 0.3), 10.0, 30.0, 0.8)
	if efectos.escenario != null:
		efectos.escenario.destello(Color(1.0, 0.45, 0.35), 5.0, 0.6)


# ------------------------------------------------------------------ sincronización con el estado

## Crea o quita los efectos persistentes de una entidad según su estado del servidor.
func sincronizar(eid: int, nodo: Node3D, e: Dictionary) -> void:
	var efs: Dictionary = e.get("efectos", {})
	_sync(eid, "susanoo", nodo, efs.has("susanoo"), func(): return crear_susanoo(int(efs["susanoo"]["nivel"])))
	_sync(eid, "ardiendo", nodo, efs.has("ardiendo"), func():
		var n := Node3D.new()
		var f := fuego_negro(0.45)
		f.position = Vector3(0, 1.0, 0)
		f.scale = Vector3(1.0, 1.8, 1.0)
		n.add_child(f)
		_llamas_negras(n, 2.0, 0.4, 40)
		return n)
	_sync(eid, "armadura_negra", nodo, efs.has("armadura_negra"), func():
		var n := Node3D.new()
		var f := fuego_negro(0.8)
		f.position = Vector3(0, 1.0, 0)
		f.scale = Vector3(1.0, 1.6, 1.0)
		n.add_child(f)
		_llamas_negras(n, 2.2, 0.7, 80)
		return n)
	var puertas := efs.has("puertas")
	var clave := "puertas%d" % (int(efs["puertas"]["nivel"]) if puertas else 0)
	for n in [1, 2, 3]:
		if clave != "puertas%d" % n:
			_sync(eid, "puertas%d" % n, nodo, false, Callable())
	if puertas:
		var nv := int(efs["puertas"]["nivel"])
		_sync(eid, clave, nodo, true, func(): return crear_aura_puertas(nv))


func _sync(eid: int, efecto: String, nodo: Node3D, activo: bool, crear: Callable) -> void:
	var clave := "%d:%s" % [eid, efecto]
	var existe := _adjuntos.has(clave) and is_instance_valid(_adjuntos[clave])
	if activo and not existe:
		var n: Node3D = crear.call()
		nodo.add_child(n)
		_adjuntos[clave] = n
		if efecto == "susanoo":
			n.scale *= 0.2
			var tw := n.create_tween()
			tw.tween_property(n, "scale", n.scale * 5.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	elif not activo and existe:
		(_adjuntos[clave] as Node).queue_free()
		_adjuntos.erase(clave)


## Zonas del suelo (suelo ardiente, llamas negras) a partir de la instantánea.
func sincronizar_zonas(lista: Array) -> void:
	var vistos := {}
	for z in lista:
		var id := int(z["id"])
		vistos[id] = true
		if _zonas.has(id):
			continue
		if genericas != null and str(z.get("forma", "")) not in ["", "fuego"]:
			var ng := genericas.crear_zona(z)
			if ng != null:
				add_child(ng)
				ng.global_position = z["pos"]
				_zonas[id] = ng
				continue
		var n := Node3D.new()
		add_child(n)
		n.global_position = z["pos"]
		var r := float(z["radio"])
		var negra := str(z["jutsu"]) == "amaterasu"
		var cant := int(clampf(r * 18.0, 12, 90) * float(Ajustes.g("particulas", 1.0)))
		var p := efectos.particulas({"cantidad": cant, "vida": 0.9, "radio": r * 0.8, "direccion": Vector3.UP, "dispersion": 15.0,
			"vel_min": 0.8, "vel_max": 2.2, "gravedad": Vector3(0, 1.5, 0), "tam_min": 0.3, "tam_max": 0.7,
			"color": Color(0.03, 0.0, 0.05, 0.9) if negra else Color(1.0, 0.45, 0.1, 0.4), "color_fin": Color(0.3, 0.05, 0.35, 0.0) if negra else Color(0.5, 0.05, 0.0, 0.0),
			"aditivo": not negra})
		p.position = Vector3(0, 0.2, 0)
		n.add_child(p)
		p.emitting = true
		if not negra:
			var luz := OmniLight3D.new()
			luz.light_color = Efectos.COLOR_FUEGO
			luz.light_energy = 1.5
			luz.omni_range = r * 2.5
			luz.position = Vector3(0, 0.8, 0)
			n.add_child(luz)
		_zonas[id] = n
	for id in _zonas.keys():
		if not vistos.has(id):
			var n: Node3D = _zonas[id]
			for c in n.get_children():
				if c is GPUParticles3D:
					c.emitting = false
				elif c is OmniLight3D:
					c.visible = false
			var tw := create_tween()
			tw.tween_interval(1.0)
			tw.tween_callback(n.queue_free)
			_zonas.erase(id)
