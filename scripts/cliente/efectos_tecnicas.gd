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
			# El cielo se oscurece y retumba: nubes de tormenta giran sobre el objetivo; luego cae el dragón de rayo.
			if efectos.escenario != null:
				efectos.escenario.destello(Color(0.5, 0.6, 1.0), 1.5 + nivel, 0.6)
			var carga := float(ev.get("carga", 0.35))
			var obj_k := int(ev.get("objetivo", -1))
			var seguir := func() -> Vector3:
				var pp: Vector3 = pos_entidad.call(obj_k) if obj_k >= 0 else Vector3.ZERO
				return pp if pp != Vector3.ZERO else (ev["punto"] as Vector3)
			tormenta(ev["punto"], nivel, carga, seguir)
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
			var sz := _susanoo_de(int(ev["entidad"]))
			if sz != null and sz.has_meta("espada"):
				tajo_espada(sz.get_meta("espada"))
		"susanoo_alza":
			var sz2 := _susanoo_de(int(ev["entidad"]))
			if sz2 != null and sz2.has_meta("espada"):
				alzar_espada(sz2.get_meta("espada"), float(ev.get("tiempo", 0.3)))
		"susanoo_tensa":
			var sz3 := _susanoo_de(int(ev["entidad"]))
			if sz3 != null and sz3.has_meta("arco"):
				tensar_arco(sz3.get_meta("arco"), float(ev.get("tiempo", 0.35)))
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

const ALTURA_TORMENTA := 24.0
const VUELO_DRAGON := 0.6


## Tormenta en remolino sobre el objetivo durante la carga; al final, el dragón de rayo baja en espiral.
func tormenta(punto: Vector3, nivel: int, carga: float, objetivo: Callable) -> void:
	var raiz := Node3D.new()
	add_child(raiz)
	raiz.global_position = Vector3(punto.x, punto.y + ALTURA_TORMENTA, punto.z)
	var radio := 12.0 + nivel * 3.0
	# Dos anillos de nubes (ancho arriba, embudo más abajo) que giran y se cierran.
	for capa in 2:
		var p := efectos.particulas({"cantidad": 60 if capa == 0 else 30, "vida": carga + 1.2, "explosividad": 1.0, "una_vez": true,
			"vel_min": 0.0, "vel_max": 0.3, "tam_min": 11.0 - capa * 4.0, "tam_max": 17.0 - capa * 5.0, "escala_inicio": 0.5, "escala_fin": 0.9,
			"color": Color(0.09, 0.1, 0.14, 0.92), "color_fin": Color(0.08, 0.09, 0.12, 0.0), "aditivo": false, "local": true})
		var pm := p.process_material as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = radio * (1.0 if capa == 0 else 0.45)
		pm.emission_ring_inner_radius = radio * (0.35 if capa == 0 else 0.1)
		pm.emission_ring_height = 2.5
		p.position.y = -capa * 4.0
		# Nubes de tormenta sin niebla (si no, a esa altura se aclaran y no se leen contra el cielo).
		var mq := (p.draw_pass_1 as QuadMesh).material.duplicate() as StandardMaterial3D
		mq.disable_fog = true
		(p.draw_pass_1 as QuadMesh).material = mq
		raiz.add_child(p)
		p.emitting = true
	var brillo := efectos.particulas({"cantidad": 8, "vida": carga + 0.8, "explosividad": 1.0, "una_vez": true, "radio": radio * 0.3,
		"vel_min": 0.0, "vel_max": 0.1, "tam_min": radio * 0.8, "tam_max": radio * 1.2, "escala_inicio": 0.2, "escala_fin": 1.0,
		"color": Color(0.35, 0.5, 0.95, 0.35), "local": true})
	brillo.position.y = -2.5
	raiz.add_child(brillo)
	brillo.emitting = true
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.6, 0.75, 1.0)
	luz.light_energy = 0.0
	luz.omni_range = radio * 3.0
	luz.position.y = -3.0
	raiz.add_child(luz)
	var tw := raiz.create_tween()
	tw.set_parallel(true)
	tw.tween_property(raiz, "rotation:y", TAU * (1.2 + nivel * 0.3), carga + 1.0).set_ease(Tween.EASE_IN)
	tw.tween_property(raiz, "scale", Vector3(0.6, 1.0, 0.6), carga).set_ease(Tween.EASE_IN)
	tw.chain().tween_property(raiz, "scale", Vector3(1.4, 1.0, 1.4), 1.0)
	tw.chain().tween_callback(raiz.queue_free)
	# Relámpagos dentro de las nubes (cada vez más seguidos) y la luz que parpadea.
	var n_rel := 4 + nivel * 2
	for k in n_rel:
		var t_k := carga * pow(float(k) / n_rel, 0.7)
		var tr := raiz.create_tween()
		tr.tween_interval(t_k)
		tr.tween_callback(func():
			var c := raiz.global_position
			var a := c + Vector3(randf_range(-radio, radio), randf_range(-1, 1), randf_range(-radio, radio)) * 0.6
			var b := c + Vector3(randf_range(-radio, radio), randf_range(-3, 0), randf_range(-radio, radio)) * 0.6
			efectos.rayos_fugaces([[a, b]], 0.12, 0.15, 1)
			luz.light_energy = 3.0 + nivel
			var tl := luz.create_tween()
			tl.tween_property(luz, "light_energy", 0.3, 0.12))
	if sonidos != null:
		var ts := raiz.create_tween()
		ts.tween_interval(carga * 0.5)
		ts.tween_callback(func(): sonidos.tocar("trueno", -10.0, 0.8))
	# El dragón sale de la tormenta un poco antes del golpe y baja en espiral hasta el objetivo.
	var td := create_tween()
	td.tween_interval(maxf(carga - VUELO_DRAGON, 0.0))
	td.tween_callback(func(): _dragon_rayo(raiz.global_position, nivel, objetivo))


func _dragon_rayo(desde: Vector3, nivel: int, objetivo: Callable) -> void:
	# Cuerpo sólido y brillante (se lee bien la cabeza); el halo lo ponen la luz, las chispas y los rayos.
	var mk := Materiales.emisivo(Color(0.62, 0.86, 1.0), 2.6)
	var escala: float = [2.4, 3.2, 4.2][nivel - 1]
	var dragon: Node3D = DragonVivo.crear("kirin", mk)
	if dragon == null:
		dragon = Kit.modelo_jutsu("kirin", mk)
		if dragon == null:
			return
		dragon.scale = Vector3.ONE * escala
	else:
		(dragon as DragonVivo).amplitud = 0.4
		(dragon as DragonVivo).frecuencia = 10.0
		(dragon as DragonVivo).anticipar(escala, 0.25)
	add_child(dragon)
	dragon.global_position = desde
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.6, 0.85, 1.0)
	luz.light_energy = 5.0
	luz.omni_range = 18.0
	dragon.add_child(luz)
	var chispas := efectos.particulas({"cantidad": 60, "vida": 0.3, "radio": 1.0, "vel_min": 1.0, "vel_max": 4.0, "tam_min": 0.1, "tam_max": 0.25,
		"estirado": true, "tam_quad": Vector2(0.05, 0.6), "color": Color(0.8, 0.95, 1.0)})
	dragon.add_child(chispas)
	chispas.emitting = true
	var a0 := randf() * TAU
	var r0 := 7.0
	var anterior := desde
	var vuelo := func(t: float) -> void:
		if not is_instance_valid(dragon):
			return
		var meta: Vector3 = objetivo.call()
		var u := 1.0 - t
		var a := a0 + t * PI * 1.6
		var p := meta + Vector3(cos(a) * r0 * u, ALTURA_TORMENTA * pow(u, 1.4) + 1.0, sin(a) * r0 * u)
		if p.distance_to(anterior) > 0.01:
			dragon.look_at_from_position(p, p + (p - anterior), Vector3.UP, true)   # la cabeza (+Z del modelo) hacia donde va
		anterior = p
		# Rayos que recorren el cuerpo (entre huesos) cada pocos cuadros.
		if dragon is DragonVivo and randf() < 0.45:
			var sk := (dragon as DragonVivo).esqueleto
			var pares: Array = []
			for i in range(0, sk.get_bone_count() - 1, 2):
				pares.append([sk.global_transform * sk.get_bone_global_pose(i).origin, sk.global_transform * sk.get_bone_global_pose(i + 2 if i + 2 < sk.get_bone_count() else i + 1).origin])
			efectos.rayos_fugaces(pares, 0.1 + nivel * 0.04, 0.08, 1)
	var tw := create_tween()
	tw.tween_method(vuelo, 0.0, 1.0, VUELO_DRAGON).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		if is_instance_valid(dragon):
			if dragon is DragonVivo:
				(dragon as DragonVivo).desvanecer(Color(0.7, 0.9, 1.0), efectos, 0.3)
			else:
				dragon.queue_free())


func kirin(pos: Vector3, nivel: int, radio: float, bestia: bool) -> void:
	var nd := Datos.nivel_jutsu("kirin", nivel)
	var arriba := pos + Vector3(randf_range(-3, 3), ALTURA_TORMENTA, randf_range(-3, 3))
	var pares: Array = [[arriba, pos]]
	if bestia:
		for k in 3:
			pares.append([arriba + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), pos + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))])
	efectos.rayos_fugaces(pares, 0.4 if bestia else 0.26, 0.5, 3)
	# Impacto: chispas, polvo y piedras.
	efectos.rafaga(pos + Vector3(0, 0.5, 0), {"cantidad": int(nd.get("particulas", 120)), "vida": 0.6, "radio": radio * 0.3, "vel_min": 8.0, "vel_max": 18.0,
		"frenado": 10.0, "tam_min": 0.06, "tam_max": 0.14, "color": Efectos.COLOR_RAYO_NUCLEO, "estirado": true, "tam_quad": Vector2(0.4, 3.0)})
	efectos.rafaga(Vector3(pos.x, 0.3, pos.z), {"cantidad": 40, "vida": 1.2, "radio": radio * 0.6, "direccion": Vector3.UP, "dispersion": 50.0,
		"vel_min": 2.0, "vel_max": 6.0, "gravedad": Vector3(0, -6, 0), "tam_min": 0.4, "tam_max": 0.9, "color": Color(0.7, 0.75, 0.85, 0.5), "aditivo": false})
	efectos.rafaga(Vector3(pos.x, 0.3, pos.z), {"cantidad": 24, "vida": 1.0, "radio": radio * 0.3, "direccion": Vector3.UP, "dispersion": 45.0,
		"vel_min": 5.0, "vel_max": 10.0, "gravedad": Vector3(0, -20, 0), "tam_min": 0.12, "tam_max": 0.28, "color": Color(0.25, 0.25, 0.28, 1.0), "aditivo": false})
	efectos.luz_temporal(pos + Vector3(0, 3, 0), Efectos.COLOR_RAYO, float(nd.get("luz", 6.0)), float(nd.get("luz_rango", 40.0)), 0.6)
	if efectos.escenario != null:
		efectos.escenario.destello(Color(0.75, 0.85, 1.0), 3.0 + nivel * 1.5, 0.45)
	efectos.sacudir_desde(pos, float(nd.get("sacudida", 0.8)))
	# Cráter con grietas y chispas que siguen saltando un rato.
	efectos.marca_suelo(pos, float(nd.get("marca", 3.0)) * 1.2, Color(0.03, 0.035, 0.06, 0.95), true)
	_chispas_residuales(pos, radio, 2.0 + nivel * 0.5)
	if sonidos != null:
		sonidos.tocar("trueno", 2.0, 1.4)
		sonidos.tocar("explosion", -2.0, 1.3)


## Chispas eléctricas que siguen saltando en el cráter y pequeños arcos al azar.
func _chispas_residuales(pos: Vector3, radio: float, segundos: float) -> void:
	var p := efectos.particulas({"cantidad": 40, "vida": 0.35, "radio": radio * 0.5, "direccion": Vector3.UP, "dispersion": 70.0,
		"vel_min": 1.5, "vel_max": 4.0, "gravedad": Vector3(0, -8, 0), "tam_min": 0.05, "tam_max": 0.12, "estirado": true,
		"tam_quad": Vector2(0.03, 0.35), "color": Color(0.75, 0.9, 1.0)})
	add_child(p)
	p.global_position = Vector3(pos.x, pos.y + 0.15, pos.z)
	p.emitting = true
	var tw := p.create_tween()
	for k in int(segundos / 0.25):
		tw.tween_interval(0.25)
		tw.tween_callback(func():
			if randf() < 0.6:
				var a := randf() * TAU
				var c := Vector3(pos.x, pos.y + 0.1, pos.z)
				efectos.rayos_fugaces([[c + Vector3(cos(a), 0, sin(a)) * radio * 0.2, c + Vector3(cos(a + 0.8), 0.3, sin(a + 0.8)) * radio * 0.6]], 0.04, 0.1, 1))
	tw.tween_callback(func(): p.emitting = false)
	tw.tween_interval(0.5)
	tw.tween_callback(p.queue_free)


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
	# Se forma por capas: esqueleto → guerrero → armadura completa (modelos de Meshy con el chakra translúcido).
	if ResourceLoader.exists("res://assets/modelos/jutsu_susanoo_%d.glb" % nivel):
		_formar_capas(raiz, nivel)
		var luz_m := OmniLight3D.new()
		luz_m.light_color = COLOR_ESPECTRAL
		luz_m.light_energy = 1.5 + nivel
		luz_m.omni_range = 4.0 * esc
		luz_m.position = Vector3(0, 1.5 * esc, 0)
		raiz.add_child(luz_m)
		var alto: float = [2.8, 5.2, 9.0][nivel - 1]
		if nivel >= 2:
			raiz.set_meta("arco", _crear_arco(Vector3(-0.33 * alto, 0.5 * alto, 0.2 * alto), 0.32 * alto))
			raiz.add_child(raiz.get_meta("arco"))
		if nivel >= 3:
			raiz.set_meta("espada", _crear_espada(Vector3(0.29 * alto, 0.42 * alto, 0.13 * alto), 0.62 * alto))
			raiz.add_child(raiz.get_meta("espada"))
		raiz.set_meta("capas", true)
		return raiz
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


## Capas del Susanoo: cada forma aparece (escala con rebote y brillo) y la anterior se desvanece dentro de ella.
func _formar_capas(raiz: Node3D, nivel: int) -> void:
	var intensidad := 1.2 + nivel * 0.3
	var capas: Array = []
	for k in range(1, nivel + 1):
		var mk := Shaders.material("espectral").duplicate() as ShaderMaterial   # uno por capa (se apagan por separado)
		mk.set_shader_parameter("color", COLOR_ESPECTRAL)
		mk.set_shader_parameter("intensidad", 0.0)
		var m := Kit.modelo_jutsu("susanoo_%d" % k, mk)
		if m == null:
			continue
		m.position = Vector3(0, 0, -0.25 * k)
		m.visible = false
		raiz.add_child(m)
		capas.append([m, mk])
	var llamas := efectos.particulas({"cantidad": 60, "vida": 0.8, "radio": 1.2 + nivel * 0.6, "direccion": Vector3.UP, "dispersion": 15.0,
		"vel_min": 2.0, "vel_max": 5.0 + nivel, "tam_min": 0.3, "tam_max": 0.7, "color": Color(0.65, 0.4, 1.0, 0.6), "local": true})
	raiz.add_child(llamas)
	llamas.emitting = true
	var tw := raiz.create_tween()
	for i in capas.size():
		var m: MeshInstance3D = capas[i][0]
		var mk: ShaderMaterial = capas[i][1]
		var ultima := i == capas.size() - 1
		tw.tween_callback(func():
			m.visible = true
			m.scale = Vector3.ONE * 0.85
			var t2 := m.create_tween()
			t2.set_parallel(true)
			t2.tween_property(m, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t2.tween_method(func(v: float): mk.set_shader_parameter("intensidad", v), 0.0, intensidad * (1.0 if ultima else 1.5), 0.25))
		if not ultima:
			tw.tween_interval(0.32)
			tw.tween_callback(func():
				var t3 := m.create_tween()
				t3.tween_method(func(v: float): mk.set_shader_parameter("intensidad", v), intensidad * 1.5, 0.0, 0.3)
				t3.tween_callback(func(): m.visible = false))
	tw.tween_interval(0.5)
	tw.tween_callback(func(): llamas.emitting = false)


## Arco de chakra (oculto hasta que dispara): palas en arco, cuerda y flecha.
func _crear_arco(pos: Vector3, r: float) -> Node3D:
	var arco := Node3D.new()
	arco.position = pos
	var mat := Materiales.emisivo(Color(0.72, 0.5, 1.0), 3.0)
	var n := 9
	var puntos: Array = []
	for i in n + 1:
		var a := deg_to_rad(lerpf(-70.0, 70.0, float(i) / n))
		puntos.append(Vector3(0, r * sin(a), r * cos(a) * 0.45))
	for i in n:
		var a: Vector3 = puntos[i]
		var b: Vector3 = puntos[i + 1]
		var seg := Materiales.caja(Vector3(r * 0.05, a.distance_to(b) * 1.05, r * 0.07), mat)
		seg.position = (a + b) * 0.5
		seg.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		arco.add_child(seg)
	var cuerda := Node3D.new()   # pivote en el centro de la cuerda (se tensa hacia atrás)
	cuerda.position = Vector3(0, 0, (puntos[0] as Vector3).z)
	cuerda.name = "cuerda"
	arco.add_child(cuerda)
	var alto_c := (puntos[n] as Vector3).y - (puntos[0] as Vector3).y
	for lado in [-1.0, 1.0]:
		var hilo := Materiales.caja(Vector3(r * 0.015, alto_c * 0.5, r * 0.015), Materiales.emisivo(Color(0.9, 0.85, 1.0), 3.0))
		hilo.position = Vector3(0, lado * alto_c * 0.25, 0)
		hilo.name = "hilo%d" % (0 if lado < 0 else 1)
		cuerda.add_child(hilo)
	var flecha := Materiales.caja(Vector3(r * 0.04, r * 0.04, r * 1.3), Materiales.emisivo(Color(0.85, 0.7, 1.0), 4.0))
	flecha.position = Vector3(0, 0, r * 0.65)
	flecha.name = "flecha"
	cuerda.add_child(flecha)
	arco.scale = Vector3.ONE * 0.01
	arco.visible = false
	arco.set_meta("r", r)
	return arco


## Tensa el arco durante «tiempo» y suelta la flecha (justo cuando el servidor la dispara).
func tensar_arco(arco: Node3D, tiempo: float) -> void:
	var r := float(arco.get_meta("r", 1.0))
	var cuerda: Node3D = arco.get_node("cuerda")
	var flecha: Node3D = cuerda.get_node("flecha")
	var z0 := cuerda.position.z
	arco.visible = true
	flecha.visible = true
	var tw := arco.create_tween()
	tw.tween_property(arco, "scale", Vector3.ONE, minf(0.12, tiempo * 0.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cuerda, "position:z", z0 - r * 0.55, maxf(tiempo - 0.12, 0.05)).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): flecha.visible = false)
	tw.tween_property(cuerda, "position:z", z0 + r * 0.12, 0.05)
	tw.tween_property(cuerda, "position:z", z0, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_property(arco, "scale", Vector3.ONE * 0.01, 0.2)
	tw.tween_callback(func(): arco.visible = false)


## Espada de chakra: hoja con guarda; pivote en la empuñadura (la hoja va por +Y).
func _crear_espada(pos: Vector3, largo: float) -> Node3D:
	var piv := Node3D.new()
	piv.position = pos
	var hoja := Materiales.caja(Vector3(largo * 0.1, largo, largo * 0.045), Materiales.emisivo(Color(0.78, 0.6, 1.0), 3.5))
	hoja.position = Vector3(0, largo * 0.55, 0)
	piv.add_child(hoja)
	var filo := Materiales.caja(Vector3(largo * 0.015, largo * 0.98, largo * 0.02), Materiales.emisivo(Color(1, 0.95, 1.0), 5.0))
	filo.position = Vector3(largo * 0.05, largo * 0.55, 0)
	piv.add_child(filo)
	# Estela en la punta (solo emite durante el tajo).
	var estela := efectos.particulas({"cantidad": 60, "vida": 0.25, "radio": largo * 0.08, "vel_min": 0.0, "vel_max": 0.2,
		"tam_min": largo * 0.08, "tam_max": largo * 0.14, "escala_inicio": 1.0, "color": Color(0.85, 0.7, 1.0, 0.8), "color_fin": Color(0.5, 0.3, 1.0, 0.0)})
	estela.position = Vector3(0, largo * 0.85, 0)
	estela.name = "estela"
	estela.emitting = false
	piv.add_child(estela)
	var guarda := Materiales.caja(Vector3(largo * 0.18, largo * 0.03, largo * 0.06), Materiales.emisivo(Color(0.55, 0.35, 0.9), 2.5))
	guarda.position = Vector3(0, largo * 0.04, 0)
	piv.add_child(guarda)
	piv.visible = false
	piv.scale = Vector3.ONE * 0.01
	return piv


## Alza la espada sobre el hombro (anticipación) durante «tiempo».
func alzar_espada(esp: Node3D, tiempo: float) -> void:
	esp.visible = true
	esp.rotation_degrees = Vector3(10, 0, -10)
	var tw := esp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(esp, "scale", Vector3.ONE, minf(0.12, tiempo * 0.5)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(esp, "rotation_degrees", Vector3(-35, 0, 35), tiempo).set_ease(Tween.EASE_OUT)


## Tajo: barre de arriba-derecha hacia abajo-izquierda en un instante y se desvanece.
func tajo_espada(esp: Node3D) -> void:
	esp.visible = true
	esp.scale = Vector3.ONE
	var estela: GPUParticles3D = esp.get_node_or_null("estela")
	if estela != null:
		estela.emitting = true
	var tw := esp.create_tween()
	tw.tween_property(esp, "rotation_degrees", Vector3(95, 0, -70), 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): if estela != null: estela.emitting = false)
	tw.tween_interval(0.25)
	tw.tween_property(esp, "scale", Vector3.ONE * 0.01, 0.25)
	tw.tween_callback(func(): esp.visible = false)


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


## El Susanoo se apaga: el chakra pierde brillo y se deshace en partículas moradas.
func _desvanecer_susanoo(n: Node3D) -> void:
	efectos.rafaga(n.global_position + Vector3(0, 2.0 * n.scale.y, 0), {"cantidad": 70, "vida": 0.9, "radio": 1.5, "direccion": Vector3.UP,
		"dispersion": 60.0, "vel_min": 1.0, "vel_max": 4.0, "tam_min": 0.2, "tam_max": 0.5, "color": Color(0.65, 0.4, 1.0, 0.7)})
	var tw := n.create_tween()
	tw.set_parallel(true)
	for c in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).visible and (c as MeshInstance3D).material_override is ShaderMaterial:
			var mk: ShaderMaterial = (c as MeshInstance3D).material_override
			var v0 := float(mk.get_shader_parameter("intensidad"))
			tw.tween_method(func(v: float): mk.set_shader_parameter("intensidad", v), v0, 0.0, 0.45)
		elif c is OmniLight3D:
			tw.tween_property(c, "light_energy", 0.0, 0.45)
	tw.tween_property(n, "scale", n.scale * Vector3(1.08, 1.12, 1.08), 0.45)
	tw.chain().tween_callback(n.queue_free)


func _susanoo_de(eid: int) -> Node3D:
	var clave := "%d:susanoo" % eid
	if _adjuntos.has(clave) and is_instance_valid(_adjuntos[clave]):
		return _adjuntos[clave]
	return null


func _sync(eid: int, efecto: String, nodo: Node3D, activo: bool, crear: Callable) -> void:
	var clave := "%d:%s" % [eid, efecto]
	var existe := _adjuntos.has(clave) and is_instance_valid(_adjuntos[clave])
	if activo and not existe:
		var n: Node3D = crear.call()
		nodo.add_child(n)
		_adjuntos[clave] = n
		if efecto == "susanoo" and not n.has_meta("capas"):
			n.scale *= 0.2
			var tw := n.create_tween()
			tw.tween_property(n, "scale", n.scale * 5.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	elif not activo and existe:
		var viejo: Node3D = _adjuntos[clave]
		_adjuntos.erase(clave)
		if efecto == "susanoo":
			_desvanecer_susanoo(viejo)
		else:
			viejo.queue_free()


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
