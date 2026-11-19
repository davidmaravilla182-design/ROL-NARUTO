extends SceneTree
## Herramienta de desarrollo: recorre los distritos de la aldea, guarda capturas (a pie y aéreas) y mide
## llamadas de dibujo, primitivas y objetos visibles en cada uno (medidas.txt).
## Uso: xvfb-run -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 -s res://tools/captura_distritos.gd -- <carpeta> [ids...]

var salida := "user://capturas"
var juego: Node = null
var menu: Node = null
var t := 0.0
var paso := 0
var guion: Array = []
var _medidas: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	DirAccess.make_dir_recursive_absolute(salida)
	if OS.get_environment("CALIDAD") != "":
		Ajustes.cargar()
		Ajustes.calidad = OS.get_environment("CALIDAD")
	Perfil.cargar()
	Perfil.elegir(-1)
	menu = (load("res://escenas/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	var ids: Array = args.slice(1)
	var m := Mapa.generar()
	guion = [[0.6, func(): menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
		[0.7, func(): _enemigo(false)]]
	var tt := 1.4
	var k := 0
	for d in m.distritos:
		if not ids.is_empty() and not (d["id"] in ids):
			continue
		k += 1
		var id: String = d["id"]
		var etq := "d%d_%s" % [k, id]
		var pie := _lugar_a_pie(m, d)
		var c: Vector2 = d["centro"]
		var r: Rect2 = d["rect"]
		guion.append([tt, func(): _ir(pie)])
		guion.append([tt + 1.0, func(): _foto_medida(etq + "_a_pie")])
		guion.append([tt + 1.05, func(): _libre(Vector3(c.x + r.size.x * 0.35, 38.0, c.y + r.size.y * 0.45), Vector3(c.x, 0, c.y))])
		guion.append([tt + 1.6, func(): _foto_medida(etq + "_aereo")])
		guion.append([tt + 1.65, func(): _libre(Vector3(pie.x + 6, 2.2, pie.z + 9), Vector3(pie.x - 6, 4.5, pie.z - 14))])
		guion.append([tt + 2.2, func(): _foto_medida(etq + "_calle")])
		guion.append([tt + 2.25, func(): _seguir()])
		tt += 2.6
	guion.append([tt, func(): _seguir(); _ir(Vector3(0, 0, 10)); juego.hud.abrir_mapa()])
	guion.append([tt + 0.5, func(): _guardar("e0_mapa_completo"); juego.hud.abrir_mapa()])
	tt += 0.6
	guion.append([tt, func(): _libre(Vector3(0, 6, 160), Vector3(0, 30, -80)); _ir(Vector3(0, 0, 150))])
	guion.append([tt + 0.8, func(): _foto_medida("e1_llegada_puente")])
	guion.append([tt + 0.85, func(): _libre(Vector3(150, 62, 150), Vector3(0, 10, -80))])
	guion.append([tt + 1.6, func(): _foto_medida("e2_aldea_completa")])
	guion.append([tt + 1.7, func(): _guardar_medidas(); quit(0)])


## Un lugar libre a pie del distrito: el primer aldeano (siempre está en un hueco libre).
func _lugar_a_pie(m: Mapa, d: Dictionary) -> Vector3:
	for pt in m.puntos:
		if pt["distrito"] == d["id"] and pt["tipo"] == "aldeano":
			var c: Vector2 = pt["centro"]
			return Vector3(c.x + 2.0, 0, c.y + 2.0)
	var c2: Vector2 = d["centro"]
	return Vector3(c2.x, 0, c2.y)


func _ir(pos: Vector3) -> void:
	var j = juego.servidor.entidad_de_peer(1)
	j.reiniciar()
	j.pos = pos
	j.yaw = PI
	juego.camara.libre = false


func _guardar(nombre: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(salida.path_join(nombre + ".png"))
	print("CAPTURA ", nombre)


func _libre(pos: Vector3, mirar: Vector3) -> void:
	juego.camara.libre = true
	juego.camara.global_position = pos
	juego.camara.look_at(mirar, Vector3.UP)


func _seguir() -> void:
	juego.camara.libre = false


func _enemigo(activo: bool) -> void:
	for e in juego.servidor.entidades:
		if e.tipo == "enemigo":
			e.ia = IaEnemigo.new(e) if activo else null


func _medir(nombre: String) -> void:
	var vp := root.get_viewport().get_viewport_rid()
	var tipo := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var sect: Sectores = juego.escenario.sectores
	var linea := "%s: llamadas=%d primitivas=%d objetos=%d sectores_activos=%d mem_video=%.1fMB" % [nombre,
		RenderingServer.viewport_get_render_info(vp, tipo, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp, tipo, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp, tipo, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		sect.cuantos_activos(), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]
	_medidas.append(linea)
	print("MEDIDA ", linea)


func _foto_medida(nombre: String) -> void:
	_guardar(nombre)
	_medir(nombre)


func _guardar_medidas() -> void:
	var f := FileAccess.open(salida.path_join("medidas.txt"), FileAccess.WRITE)
	for l in _medidas:
		f.store_line(l)


func _process(d: float) -> bool:
	t += d
	while paso < guion.size() and t >= float(guion[paso][0]):
		(guion[paso][1] as Callable).call()
		paso += 1
	return false
