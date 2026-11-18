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
	menu = (load("res://escenas/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	guion = [
		[0.5, func(): _guardar("00_menu"); menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
		[0.7, func(): _enemigo(false)],
		[1.5, func(): _guardar("01_inicio")],
		[1.6, func(): _cam(PI, 2.6, -0.1, 1.3)],
		[2.2, func(): _guardar("02_personaje_frente")],
		[2.3, func(): _cam(0.0, 2.6, -0.1, 1.3)],
		[2.9, func(): _guardar("03_personaje_espalda")],
		[3.0, func(): _cam(0.0, 6.2, -0.32, 1.6); _accion("bola_fuego")],
		[3.25, func(): _guardar("04_sellos")],
		[3.75, func(): _guardar("05_bola_fuego_n1")],
		[5.0, func(): _nivel(3); _listo(Vector3(0, 0, 10))],
		[5.1, func(): _accion("bola_fuego")],
		[5.9, func(): _guardar("06_bola_fuego_n3")],
		[6.3, func(): _guardar("07_bola_fuego_n3_b")],
		[7.0, func(): _guardar("08_explosion_n3")],
		[9.0, func(): _listo(Vector3(-4, 0, 6))],
		[9.1, func(): _accion("chidori")],
		[9.4, func(): _guardar("09_chidori_carga_n3")],
		[9.95, func(): _guardar("10_chidori_carga_n3_b")],
		[10.25, func(): _guardar("11_chidori_embiste")],
		[10.6, func(): _guardar("12_chidori_impacto")],
		[12.0, func(): _nivel(1); _listo(Vector3(-4, 0, 6))],
		[12.1, func(): _accion("chidori")],
		[12.6, func(): _guardar("13_chidori_carga_n1")],
		[14.0, func(): _listo(Vector3(0, 0, 4)); _accion("sharingan"); _enemigo(true)],
		[16.0, func(): _guardar("14_sharingan_aviso")],
		[16.5, func(): _guardar("15_sharingan_b")],
		[17.0, func(): _guardar("16_sharingan_c")],
		[17.5, func(): quit(0)],
	]


func _guardar(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
	print("captura ", nombre, " t=", snappedf(t, 0.01))


func _cam(yaw: float, dist: float, pitch: float, alt: float) -> void:
	juego.camara.yaw = yaw
	juego.camara.distancia = dist
	juego.camara.pitch = pitch
	juego.camara.altura = alt


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
