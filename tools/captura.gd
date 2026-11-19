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
	print("captura ", nombre, " t=", snappedf(t, 0.01))
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
				"salva":
					espera = 0.35 + float(nd.get("intervalo", 0.0)) * float(nd.get("cantidad", 1)) * 0.6
			var activos := ["", "", "", ""] if es_modo else [id, "", "", ""]
			guion.append([t0, func():
				juego.transporte.enviar({"t": Protocolo.C_REPERTORIO, "activos": activos, "modo": modo, "prueba": true})
				juego.hud.construir({"activos": activos, "modo": modo, "niveles_max": {}})
				_nivel(n)])
			guion.append([t0 + 0.1, func(): _listo(Vector3(0, 0, 10)); _rival(Vector3(0, 0, 4.0)); _seguir(); _cam(0.75, 9.5, -0.3, 1.6)])
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
