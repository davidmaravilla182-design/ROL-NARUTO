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
	guion = [
		[0.5, func(): _guardar("00_menu"); menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
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
		[3.12, func(): _listo(Vector3(0, 0, 10)); _libre(Vector3(0.7, 1.55, -14.6), Vector3(0, 1.2, -12))],
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


func _seguir() -> void:
	juego.camara.libre = false


func _accion(id: String) -> void:
	juego._on_accion(id)


func _nivel(n: int) -> void:
	juego.transporte.enviar({"t": "nivel", "valor": n})


func _listo(pos: Vector3) -> void:
	var j = juego.servidor.entidad_de_peer(1)
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
	while paso < guion.size() and t >= float(guion[paso][0]):
		(guion[paso][1] as Callable).call()
		paso += 1
	return false
