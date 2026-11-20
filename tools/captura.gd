extends SceneTree
## Herramienta de desarrollo: ejecuta el juego con pantalla virtual y guarda capturas.
## Uso: xvfb-run -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 -s res://tools/captura.gd -- <carpeta_salida>
## El guion se mide en segundos de juego para no depender de los fps.

var salida := "user://capturas"
var juego: Node = null
var menu: Node = null
var t := 0.0
var paso := 0
var guion: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	DirAccess.make_dir_recursive_absolute(salida)
	if OS.get_environment("CALIDAD") != "":
		Ajustes.cargar()
		Ajustes.calidad = OS.get_environment("CALIDAD")
	menu = (load("res://escenas/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	if OS.get_environment("GUION") == "tecnicas":
		_guion_tecnicas()
		return
	if OS.get_environment("GUION") == "modelos":
		# Jutsus con modelo 3D (Meshy) en sus tres niveles.
		_guion_tecnicas([
			["kirin", "sharingan", "kirin", 1.75, 1.9, 16.0, -14.0],
		])
		return
	if OS.get_environment("GUION") == "rendimiento":
		_guion_rendimiento()
		return
	if OS.get_environment("GUION") == "comparar":
		_guion_comparar()
		return
	if OS.get_environment("GUION") == "jefe":
		_guion_jefe()
		return
	if OS.get_environment("GUION") == "locomocion":
		_guion_locomocion()
		return
	if OS.get_environment("GUION") == "kirin":
		_guion_kirin()
		return
	if OS.get_environment("GUION") == "combate":
		_guion_combate()
		return
	if OS.get_environment("GUION") == "todos":
		_guion_todos(OS.get_environment("FILTRO"))
		return
	guion = [
		[0.85, func(): _guardar("00_menu"); menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
		[0.7, func(): _enemigo(false)],
		[1.5, func(): _guardar("01_inicio")],
		[1.52, func(): _libre(Vector3(22, 5.5, -20.0), Vector3(-6, -2.0, -28.0))],
		[2.0, func(): _guardar("01b_canal")],
		[2.01, func(): _libre(Vector3(4, 2.5, 12), Vector3(-4, 30, -62))],
		[2.25, func(): _guardar("01e_hito")],
		[2.3, func(): _libre(Vector3(14, 16, 22), Vector3(-4, 2, -10))],
		[2.6, func(): _guardar("01c_panoramica")],
		[2.62, func(): _seguir(); _listo(Vector3(18, 0, 6)); _cam(-1.2, 7.0, -0.12, 1.8)],
		[3.1, func(): _guardar("01d_calle")],
		[3.12, func(): _listo(Vector3(0, 0, 10)); _ver_enemigo()],
		[3.28, func(): _guardar("01f_enemigo"); _seguir()],
		[3.3, func(): _cam(PI, 2.6, -0.1, 1.3)],
		[3.9, func(): _guardar("02_personaje_frente")],
		[4.0, func(): _cam(0.0, 2.6, -0.1, 1.3)],
		[4.6, func(): _guardar("03_personaje_espalda")],
		[4.7, func(): _cam(0.0, 6.2, -0.32, 1.6); _accion("bola_fuego")],
		[4.95, func(): _guardar("04_sellos")],
		[5.45, func(): _guardar("05_bola_fuego_n1")],
		[6.7, func(): _nivel(3); _listo(Vector3(0, 0, 10))],
		[6.8, func(): _accion("bola_fuego")],
		[7.6, func(): _guardar("06_bola_fuego_n3")],
		[8.0, func(): _guardar("07_bola_fuego_n3_b")],
		[8.7, func(): _guardar("08_explosion_n3")],
		[10.7, func(): _listo(Vector3(-4, 0, 6))],
		[10.8, func(): _accion("chidori")],
		[11.1, func(): _guardar("09_chidori_carga_n3")],
		[11.65, func(): _guardar("10_chidori_carga_n3_b")],
		[11.95, func(): _guardar("11_chidori_embiste")],
		[12.3, func(): _guardar("12_chidori_impacto")],
		[13.7, func(): _nivel(1); _listo(Vector3(-4, 0, 6))],
		[13.8, func(): _accion("chidori")],
		[14.3, func(): _guardar("13_chidori_carga_n1")],
		[15.7, func(): _listo(Vector3(0, 0, 4)); _accion("sharingan"); _enemigo(true)],
		[17.7, func(): _guardar("14_sharingan_aviso")],
		[18.2, func(): _guardar("15_sharingan_b")],
		[18.7, func(): _guardar("16_sharingan_c")],
		[19.3, func(): _enemigo(false); _listo(Vector3(0, 0, 8)); juego._ciclar_objetivo()],
		[20.1, func(): _guardar("17_objetivo_fijado")],
		[20.2, func(): juego._on_apuntar("bola_fuego", Vector2(70, -90), false)],
		[20.6, func(): _guardar("18_apuntado_bola")],
		[20.7, func(): juego._on_apuntar("chidori", Vector2(-80, -60), false); juego.hud._on_apuntando("chidori", Vector2(-80, -60), false)],
		[21.1, func(): _guardar("19_apuntado_rayo")],
		[21.2, func(): juego.hud.cancelar.emit("chidori"); juego.hud._on_cancelado("chidori"); juego.hud.abrir_ajustes()],
		[21.7, func(): _guardar("20_ajustes")],
		[21.8, func(): quit(0)],
	]


func _guardar(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
	print("captura ", nombre, " t=", snappedf(t, 0.01), " ms=", Time.get_ticks_msec())
	if OS.get_environment("GUION") == "combate":
		for e in juego.servidor.entidades:
			if e.tipo == "jugador" or (e.tipo == "enemigo" and e.pos.y > -10):
				var vis = juego._visuales.get(e.id, {}).get("nodo", null)
				print("   ", e.tipo, " ", e.id, " srv=", e.pos.snappedf(0.1), " ", e.estado, " vida=", int(e.vida), " vis=", (vis.global_position.snappedf(0.1) if vis != null else "—"), " visible=", (vis.visible if vis != null else false))


func _cam(yaw: float, dist: float, pitch: float, alt: float) -> void:
	juego.camara.yaw = yaw
	juego.camara.distancia = dist
	juego.camara.pitch = pitch
	juego.camara.altura = alt


## Cámara fija (deja de seguir al jugador) para vistas del escenario.
func _libre(pos: Vector3, mirar: Vector3) -> void:
	juego.camara.libre = true
	juego.camara.global_position = pos
	juego.camara.look_at(mirar, Vector3.UP)


## Cámara fija frente al enemigo, esté donde esté.
func _ver_enemigo() -> void:
	for e in juego.servidor.entidades:
		if e.tipo == "enemigo":
			var f: Vector3 = e.adelante()
			_libre(e.pos + f * 2.8 + Vector3(0.5, 1.5, 0), e.pos + Vector3(0, 1.15, 0))


func _seguir() -> void:
	juego.camara.libre = false


func _accion(id: String) -> void:
	juego._on_accion(id)


func _nivel(n: int) -> void:
	juego.transporte.enviar({"t": "nivel", "valor": n})


func _listo(pos: Vector3) -> void:
	var j = juego.servidor.entidad_de_peer(1)
	juego.servidor.zonas.clear()
	juego.servidor.criaturas.clear()
	juego.servidor.diferidos.clear()
	juego.servidor.proyectiles.clear()
	j.reiniciar()
	j.pos = pos
	j.yaw = PI
	for e in juego.servidor.entidades:
		if e.tipo == "muneco":
			e.reiniciar()


func _enemigo(activo: bool) -> void:
	for e in juego.servidor.entidades:
		if e.tipo == "enemigo":
			e.ia = IaEnemigo.new(e) if activo else null
			if activo:
				e.ia.t_reaccion = 0.0


func _process(d: float) -> bool:
	t += d
	# Un paso por fotograma como máximo: así cada captura ve el resultado del paso anterior ya dibujado.
	if paso < guion.size() and t >= float(guion[paso][0]):
		(guion[paso][1] as Callable).call()
		paso += 1
	return false


## Guion alternativo (GUION=tecnicas): los 6 jutsus del primer bloque en N1, N2 y N3, dos capturas cada uno.
func _guion_tecnicas(casos_propios: Array = []) -> void:
	var casos := casos_propios if not casos_propios.is_empty() else [
		# [jutsu, modo, acción, t captura a, t captura b, distancia cámara]
		["kirin", "sharingan", "kirin", 1.85, 2.25, 9.0],
		["rasengan", "", "rasengan", 0.45, 0.85, 6.5],
		["amaterasu", "mangekyo", "amaterasu", 0.6, 1.8, 7.5],
		["susanoo", "mangekyo", "susanoo", 0.9, 1.9, 8.0],
		["shinra_tensei", "rinnegan", "shinra_tensei", 0.45, 0.8, 11.0],
		["ocho_puertas", "ocho_puertas", "golpe", 0.5, 1.1, 6.0],
	]
	guion = [[0.85, func(): menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
		[0.9, func(): _enemigo(false)]]
	var t0 := 1.6
	for c in casos:
		for n in [1, 2, 3]:
			var activos := [c[0], "", "", ""] if c[0] != "ocho_puertas" else ["", "", "", ""]
			guion.append([t0, func():
				juego.transporte.enviar({"t": Protocolo.C_REPERTORIO, "activos": activos, "modo": c[1], "prueba": true})
				juego.hud.construir({"activos": activos, "modo": c[1], "niveles_max": {}})
				_nivel(n)])
			var z_rival: float = c[6] if c.size() > 6 else 4.5
			guion.append([t0 + 0.1, func(): _listo(Vector3(0, 0, 10)); _rival(Vector3(0, 0, z_rival)); _seguir(); _cam(0.7, c[5], -0.22, 1.6)])
			if c[1] != "":
				guion.append([t0 + 0.2, func(): _accion("modo")])
			guion.append([t0 + 0.35, func(): _accion(c[2])])
			if c[0] == "ocho_puertas":
				guion.append([t0 + 0.6, func(): _accion("golpe")])
				guion.append([t0 + 0.85, func(): _accion("golpe")])
			guion.append([t0 + 0.35 + c[3], func(): _guardar("%s_n%d_a" % [c[0], n])])
			guion.append([t0 + 0.35 + c[4], func(): _guardar("%s_n%d_b" % [c[0], n])])
			guion.append([t0 + 3.0, func(): _accion("modo") if c[1] != "" else null])
			t0 += 3.4
	guion.append([t0, func(): quit(0)])


## Medida de rendimiento: jugador en el puente con los guardias encima, Susanoo N3 y luego Golem N3.
func _guion_rendimiento() -> void:
	guion = [[0.85, func(): menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
		[1.4, func():
			juego.transporte.enviar({"t": Protocolo.C_REPERTORIO, "activos": ["susanoo", "golem_tierra", "", ""], "modo": "mangekyo", "prueba": true})
			juego.hud.construir({"activos": ["susanoo", "golem_tierra", "", ""], "modo": "mangekyo", "niveles_max": {}})
			_nivel(3)],
		[1.5, func(): _listo(Vector3(0, 0, 84)); _seguir(); _cam(0.4, 9.0, -0.25, 1.6)],
		[1.55, func(): juego.servidor.entidad_de_peer(1).invulnerable_t = 999.0],
		[3.0, func(): _foto_medida("r0_puente_con_guardias")],
		[3.1, func(): _accion("modo")],
		[3.4, func(): _accion("susanoo")],
		[4.6, func(): _foto_medida("r1_guardias_y_susanoo_n3")],
		[6.0, func(): _accion("golem_tierra")],
		[7.6, func(): _foto_medida("r2_guardias_susanoo_y_golem_n3")],
		[7.8, func():
			var f := FileAccess.open(salida.path_join("medidas.txt"), FileAccess.WRITE)
			f.store_string("\n".join(_medidas))
			quit(0)]]


## Guion GUION=combate: combo de 5 golpes, lanzador + combo aéreo + remate, shunshin y choque.
## Úsese con --fixed-fps 30 para que cada captura caiga en el mismo instante de juego.
func _guion_combate() -> void:
	var g := [[0.85, func(): menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
		[1.4, func(): _enemigo(false)],
		[1.5, func(): _listo(Vector3(0, 0, 12)); _rival1(Vector3(0, 0, 8.6)); _seguir(); _cam(0.75, 5.0, -0.15, 1.4)]]
	var t0 := 2.2
	# Combo de 5: cada golpe se pulsa al terminar el anterior; dos capturas por golpe.
	var dur := [0.36, 0.36, 0.4, 0.55, 0.55]
	for i in 5:
		var k := i
		g.append([t0, func(): _accion("golpe")])
		g.append([t0 + dur[k] * 0.35, func(): _guardar("c%d_a" % k)])
		g.append([t0 + dur[k] * 0.7, func(): _guardar("c%d_b" % k)])
		t0 += dur[k] + 0.05
	g.append([t0 + 0.4, func(): _guardar("c5_tras_final")])
	t0 += 1.6
	# Lanzador y combo aéreo.
	g.append([t0, func(): _listo(Vector3(0, 0, 12)); _rival1(Vector3(0, 0, 10.4))])
	for i in 3:
		g.append([t0 + 0.1 + i * 0.45, func(): _accion("golpe")])
	t0 += 0.1 + 3 * 0.45
	g.append([t0, func(): juego._on_accion("saltar")])
	g.append([t0 + 0.25, func(): _guardar("l0_lanzador")])
	g.append([t0 + 0.5, func(): juego._on_accion("saltar")])
	g.append([t0 + 0.75, func(): _guardar("l1_persecucion"); _accion("golpe")])
	g.append([t0 + 0.95, func(): _guardar("l2_aereo")])
	g.append([t0 + 1.2, func(): _accion("golpe")])
	g.append([t0 + 1.65, func(): _accion("golpe")])
	g.append([t0 + 1.9, func(): _guardar("l3_remate")])
	g.append([t0 + 2.3, func(): _guardar("l4_estrellar")])
	t0 += 3.2
	# Shunshin hacia el rival fijado.
	g.append([t0, func(): _listo(Vector3(0, 0, 16)); _rival1(Vector3(0, 0, 8.0)); juego._ciclar_objetivo()])
	g.append([t0 + 0.3, func(): _accion("esquivar")])
	g.append([t0 + 0.4, func(): _guardar("s0_shunshin")])
	g.append([t0 + 0.7, func(): _guardar("s1_shunshin_b")])
	t0 += 1.5
	# Choque: los dos golpean a la vez.
	g.append([t0, func(): _listo(Vector3(0, 0, 10)); _rival1(Vector3(0, 0, 8.8))])
	g.append([t0 + 0.1, func():
		var r = null
		for e in juego.servidor.entidades:
			if e.tipo == "enemigo" and e.pos.distance_to(Vector3(0, 0, 8.8)) < 0.5:
				r = e
		if r != null:
			juego.servidor._iniciar_golpe(r, 0)
		_accion("golpe")])
	g.append([t0 + 0.3, func(): _guardar("x0_choque")])
	g.append([t0 + 0.6, func(): quit(0)])
	guion = g


## Guion GUION=jefe: el capítulo 6 con el Tres Colas en sus 4 fases y la ventana de sellado.
func _guion_jefe() -> void:
	var g := [[0.85, func(): menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
		[1.4, func():
			_enemigo(false)
			var j = juego.servidor.entidad_de_peer(1)
			j.personaje = {"misiones": {"capitulo": 5}}
			j.attrs["sellos"] = 3
			j.invulnerable_t = 9999.0
			juego.servidor.misiones.empezar_capitulo(j, "cap6")]]
	var jefe := func():
		for e in juego.servidor.entidades:
			if e.tipo == "jefe" and not e.falsa:
				return e
		return null
	g.append([3.0, func(): _guardar("jefe_0_escena")])
	g.append([10.6, func():
		var b = jefe.call()
		var j = juego.servidor.entidad_de_peer(1)
		j.pos = b.pos + Vector3(4, 0.5, -20)
		j.chakra = 999.0
		_seguir(); _cam(PI, 12.0, -0.12, 3.0)])
	g.append([11.4, func(): _guardar("jefe_1_aparece")])
	g.append([12.6, func(): _guardar("jefe_2_balas")])
	g.append([13.0, func(): var b = jefe.call(); b.vida = float(b.stats["vida_max"]) * 0.6; b.datos_jefe["t_rodar"] = 0.2])
	g.append([13.9, func(): _guardar("jefe_3_rodar_aviso")])
	g.append([15.2, func(): _guardar("jefe_4_rodando")])
	g.append([17.0, func(): var b = jefe.call(); b.vida = float(b.stats["vida_max"]) * 0.4])
	g.append([18.5, func(): _guardar("jefe_5_niebla_copias")])
	g.append([19.0, func(): var b = jefe.call(); b.vida = float(b.stats["vida_max"]) * 0.15; b.datos_jefe["t_bomba"] = 0.2])
	g.append([20.4, func(): _guardar("jefe_6_bomba_carga")])
	g.append([22.3, func(): _guardar("jefe_7_bomba")])
	g.append([23.0, func():
		var b = jefe.call()
		juego.servidor._aplicar_dano(b, 99999.0, juego.servidor.entidad_de_peer(1), {"jutsu": "golpe", "dir": Vector3.FORWARD})])
	g.append([24.0, func(): _guardar("jefe_8_sellado_ui")])
	g.append([24.5, func(): quit(0)])
	guion = g


## Guion GUION=locomocion: caminar, correr, saltar, correr por una pared y sobre el agua (cámara fija lateral),
## y un guardia que patrulla, ataca y cae. Cuadros cada 0,1–0,15 s. Úsese con --fixed-fps 30.
func _guion_locomocion() -> void:
	var g := [[0.85, func(): menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
		[1.4, func(): _enemigo(false); _rival1(Vector3(300, -50, 300))]]
	var t0 := 1.6
	# Caminar (joystick a medias) y correr, de lado.
	for caso in [["caminar", 0.45], ["correr", 1.0]]:
		g.append([t0, func():
			_listo(Vector3(-6, 0, 6)); juego.camara.libre = true; juego.camara.yaw = -PI * 0.5
			juego.camara.global_position = Vector3(0, 1.4, 11.5); juego.camara.look_at(Vector3(0, 1.0, 6), Vector3.UP)
			juego._mov_prueba = Vector2(0, -float(caso[1]))])
		for k in 6:
			g.append([t0 + 0.6 + k * 0.12, func(): _guardar("loc_%s_%d" % [caso[0], k])])
		g.append([t0 + 1.4, func(): juego._mov_prueba = Vector2.ZERO])
		t0 += 1.6
	# Salto corriendo.
	g.append([t0, func():
		_listo(Vector3(-7, 0, 6)); juego.camara.global_position = Vector3(0, 1.8, 13.0); juego.camara.look_at(Vector3(0, 1.6, 6), Vector3.UP)
		juego._mov_prueba = Vector2(0, -1)])
	g.append([t0 + 0.4, func(): juego._on_accion("saltar")])
	for k in 7:
		g.append([t0 + 0.45 + k * 0.12, func(): _guardar("loc_saltar_%d" % k)])
	g.append([t0 + 1.4, func(): juego._mov_prueba = Vector2.ZERO])
	t0 += 1.6
	# Pared: empuja contra la casa de la plaza y sube corriendo.
	g.append([t0, func():
		var o := _obstaculo_cerca(Vector2(26, 13))
		var c: Vector2 = o["centro"]
		var md: Vector2 = o["medio"]
		_listo(Vector3(c.x - md.x - 2.5, 0, c.y))
		juego.camara.libre = true; juego.camara.yaw = -PI * 0.5   # adelante = +X (hacia la pared)
		juego.camara.global_position = Vector3(c.x - md.x - 9.0, 4.0, c.y + 9.0); juego.camara.look_at(Vector3(c.x - md.x, 4.5, c.y), Vector3.UP)
		juego._mov_prueba = Vector2(0, -1)])
	for k in 8:
		g.append([t0 + 0.4 + k * 0.2, func(): _guardar("loc_pared_%d" % k)])
	g.append([t0 + 2.2, func(): juego._mov_prueba = Vector2.ZERO])
	t0 += 2.4
	# Agua del canal con chakra.
	g.append([t0, func():
		_listo(Vector3(30.0, 0, -18.0))
		juego.camara.libre = true; juego.camara.yaw = 0.0   # adelante = -Z (cruza el canal)
		juego.camara.global_position = Vector3(36.0, 2.2, -22.0); juego.camara.look_at(Vector3(30.0, 0.8, -23.0), Vector3.UP)
		juego._mov_prueba = Vector2(0, -0.8)])
	for k in 6:
		g.append([t0 + 0.4 + k * 0.15, func(): _guardar("loc_agua_%d" % k)])
	g.append([t0 + 1.4, func(): juego._mov_prueba = Vector2.ZERO])
	t0 += 1.6
	# Guardia: se acerca (patrulla/persecución), ataca y cae derrotado.
	g.append([t0, func():
		_listo(Vector3(0, 0, 10)); juego.servidor.entidad_de_peer(1).invulnerable_t = 999.0
		juego.camara.libre = true; juego.camara.global_position = Vector3(7, 2.2, 5); juego.camara.look_at(Vector3(0, 1.0, 5), Vector3.UP)
		for e in juego.servidor.entidades:
			if e.tipo == "enemigo" and e.plantilla_id == "guardia_lluvia":
				e.reiniciar(); e.oculto = false; e.pos = Vector3(0, 0, -2); e.ia = IaEnemigo.new(e); e.ia.t_reaccion = 0.0
				break])
	for k in 10:
		g.append([t0 + 0.3 + k * 0.2, func(): _guardar("npc_guardia_%d" % k)])
	g.append([t0 + 2.4, func():
		for e in juego.servidor.entidades:
			if e.tipo == "enemigo" and e.plantilla_id == "guardia_lluvia" and e.pos.distance_to(Vector3(0, 0, 8)) < 8.0:
				juego.servidor._aplicar_dano(e, 9999.0, juego.servidor.entidad_de_peer(1), {"jutsu": "golpe", "derriba": true, "dir": Vector3(0, 0, -1), "empuje": 6.0})])
	for k in 5:
		g.append([t0 + 2.5 + k * 0.2, func(): _guardar("npc_muerte_%d" % k)])
	g.append([t0 + 3.8, func(): quit(0)])
	guion = g


func _obstaculo_cerca(p: Vector2) -> Dictionary:
	var mejor: Dictionary = {}
	var md := INF
	for o in juego.servidor.mapa.obstaculos:
		var d := (o["centro"] as Vector2).distance_to(p)
		if d < md and float(o.get("alto", 0.0)) > 4.0:
			md = d
			mejor = o
	return mejor


## Guion GUION=kirin: tormenta, dragón de rayo e impacto en N1, N2 y N3 (secuencia de 6 cuadros por nivel).
func _guion_kirin() -> void:
	var g := [[0.85, func(): menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
		[0.9, func(): _enemigo(false)]]
	var t0 := 1.6
	for n in [1, 2, 3]:
		var carga: float = [1.1, 1.3, 1.5][n - 1]
		g.append([t0, func():
			juego.transporte.enviar({"t": Protocolo.C_REPERTORIO, "activos": ["kirin", "", "", ""], "modo": "sharingan", "prueba": true})
			juego.hud.construir({"activos": ["kirin", "", "", ""], "modo": "sharingan", "niveles_max": {}})
			_nivel(n)])
		g.append([t0 + 0.1, func(): _listo(Vector3(0, 0, 10)); _rival1(Vector3(0, 0, -6)); _seguir(); _cam(0.55, 15.0, 0.25, 2.5)])
		g.append([t0 + 0.2, func(): _accion("modo")])
		g.append([t0 + 0.35, func(): _accion("kirin")])
		var base := t0 + 0.35 + 0.77   # sellos ≈ 0,77 s hasta el evento kirin_invocar
		var marcas := [[0.3, "a_nubes"], [carga * 0.6, "b_remolino"], [carga - 0.35, "c_dragon"], [carga - 0.12, "d_dragon_baja"], [carga + 0.04, "e_impacto"], [carga + 0.6, "f_crater"]]
		for m in marcas:
			g.append([base + float(m[0]), func(): _guardar("kirin_n%d_%s" % [n, m[1]])])
		t0 = base + carga + 2.2
	g.append([t0, func(): quit(0)])
	guion = g


## Un solo enemigo quieto (con vida de sobra) en `pos`; el resto, lejos y quietos.
func _rival1(pos: Vector3) -> void:
	var primero := true
	var orden: Array = juego.servidor.entidades.filter(func(x): return x.tipo == "enemigo" and x.plantilla_id == "ninja_lluvia")
	orden.append_array(juego.servidor.entidades.filter(func(x): return x.tipo == "enemigo" and x.plantilla_id != "ninja_lluvia"))
	for e in orden:
		if e.tipo == "enemigo":
			e.reiniciar()
			e.oculto = false
			e.entrada_mov = Vector2.ZERO
			e.ia = null
			e.yaw = 0.0
			e.pos = pos if primero else Vector3(300, -50, 300)
			if primero:
				e.vida = 9999.0
				print("RIVAL ", e.id, " ", e.plantilla_id, " ", e.pos)
			primero = false


## Enemigo quieto y con vida completa en `pos`, mirando al jugador.
func _rival(pos: Vector3) -> void:
	for e in juego.servidor.entidades:
		if e.tipo == "enemigo":
			e.reiniciar()
			e.pos = pos
			e.yaw = 0.0
			e.ia = null


## Guion GUION=todos: cada jutsu genérico en N1, N2 y N3 (una captura en su momento más vistoso).
## FILTRO=prefijo opcional para capturar solo algunos.
func _guion_todos(filtro: String) -> void:
	guion = [[0.85, func(): menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
		[0.9, func(): _enemigo(false)]]
	var t0 := 1.6
	for id in Repertorio.catalogo():
		var j := Datos.jutsu(id)
		if str(j.get("mecanica", "")) not in ["generica", "modo_sabio"]:
			continue
		if filtro != "" and not Array(filtro.split(",")).any(func(f): return id.begins_with(f)):
			continue
		var req: Array = j.get("requiere_modo_activo", [])
		var modo := str(req[0]) if not req.is_empty() else ""
		var es_modo := Repertorio.es_modo(id)
		if es_modo:
			modo = id
		for n in [1, 2, 3]:
			var nd := Datos.nivel_jutsu(id, n)
			var espera := 0.55
			match str(nd.get("mecanica", "")):
				"area":
					espera = float(nd.get("retardo", 0.0)) + 0.3 + float(nd.get("intervalo", 0.3)) * minf(float(nd.get("golpes", 1)) - 1.0, 2.0)
				"aura":
					espera = 0.7
				"invocar":
					espera = 1.6
				"teleport":
					espera = 0.25
				"tai":
					espera = 0.55
				"salva":
					espera = 0.35 + float(nd.get("intervalo", 0.0)) * float(nd.get("cantidad", 1)) * 0.6
			var activos := ["", "", "", ""] if es_modo else [id, "", "", ""]
			guion.append([t0, func():
				juego.transporte.enviar({"t": Protocolo.C_REPERTORIO, "activos": activos, "modo": modo, "prueba": true})
				juego.hud.construir({"activos": activos, "modo": modo, "niveles_max": {}})
				_nivel(n)])
			guion.append([t0 + 0.1, func():
				_listo(Vector3(0, 0, 10)); _rival1(Vector3(0, 0, 4.0)); _seguir(); _cam(0.75, 9.5, -0.3, 1.6)
				var jj = juego.servidor.entidad_de_peer(1)
				jj.estamina = 999.0
				if int(j.get("requiere_puertas", 0)) > 0:
					jj.efectos["puertas"] = {"t": 99.0, "nivel": 3}
				if str(j.get("requiere_aura", "")) != "":
					jj.efectos["aura"] = {"t": 99.0, "jutsu": str(j["requiere_aura"]), "nivel": 1}])
			if modo != "":
				guion.append([t0 + 0.2, func(): _accion("modo")])
			if not es_modo:
				guion.append([t0 + 0.35, func(): _accion(id)])
			else:
				guion.append([t0 + 0.6, func(): _accion("golpe")])
			guion.append([t0 + 0.35 + float(j.get("tiempo_sellos", 0.5)) + espera, func(): _guardar("%s_n%d" % [id, n])])
			guion.append([t0 + 3.2, func():
				if modo != "":
					_accion("modo")])
			t0 += 3.5
	guion.append([t0, func(): quit(0)])


## Guion GUION=comparar: mismos puntos de cámara antes/después de cambiar modelos, con medidas
## (llamadas de dibujo, primitivas, objetos y memoria de video) guardadas en medidas.txt.
var _medidas: Array = []


func _medir(nombre: String) -> void:
	var vp := root.get_viewport().get_viewport_rid()
	var tipo := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var linea := "%s: llamadas=%d primitivas=%d objetos=%d mem_video=%.1fMB mem_texturas=%.1fMB mem_buffers=%.1fMB mem_estatica=%.1fMB" % [nombre,
		RenderingServer.viewport_get_render_info(vp, tipo, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp, tipo, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp, tipo, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]
	_medidas.append(linea)
	print("MEDIDA ", linea)


func _foto_medida(nombre: String) -> void:
	_guardar(nombre)
	_medir(nombre)


func _guion_comparar() -> void:
	Perfil.cargar()
	Perfil.elegir(-1)   # personaje de práctica: el mismo en antes y después
	guion = [
		[0.85, func(): menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
		[0.9, func(): _enemigo(false)],
		[1.6, func(): _libre(Vector3(4, 3.0, 16), Vector3(-4, 40, -66))],
		[2.0, func(): _foto_medida("c1_torre_desde_campo")],
		[2.05, func(): _libre(Vector3(34, 14, -16), Vector3(-4, 36, -68))],
		[2.4, func(): _foto_medida("c2_torre_cerca")],
		[2.45, func(): _libre(Vector3(14, 16, 22), Vector3(-4, 2, -10))],
		[2.8, func(): _foto_medida("c3_panoramica")],
		[2.85, func(): _seguir(); _listo(Vector3(0, 0, 10)); _cam(0.0, 6.0, -0.15, 1.6)],
		[3.4, func(): _foto_medida("c4_juego")],
		[3.45, func(): _cam(PI, 2.4, -0.08, 1.3)],
		[3.9, func(): _foto_medida("c5_ninja_frente")],
		[3.95, func(): _cam(0.0, 2.4, -0.08, 1.3)],
		[4.4, func(): _foto_medida("c6_ninja_espalda")],
		[4.45, func(): _cam(PI * 0.5, 2.4, -0.08, 1.3)],
		[4.9, func(): _foto_medida("c7_ninja_lado")],
		[4.95, func(): _libre(Vector3(-10, 1.7, 8), Vector3(-21, 0.4, -6))],
		[5.3, func(): _foto_medida("c8_plaza_suelo")],
		[5.35, func(): _libre(Vector3(12, 1.6, -8), Vector3(18, 0.2, -18))],
		[5.7, func(): _foto_medida("c9_plaza_canal")],
		[5.8, func():
			var f := FileAccess.open(salida.path_join("medidas.txt"), FileAccess.WRITE)
			f.store_string("\n".join(_medidas))
			quit(0)],
	]
