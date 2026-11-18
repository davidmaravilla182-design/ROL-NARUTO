extends SceneTree
## Captura de una partida local vista desde el invitado: el anfitrión corre en un SubViewport aparte
## (no se ve) y el invitado se conecta por localhost. Uso:
## xvfb-run godot --path . --resolution 1280x720 -s res://tools/captura_red.gd -- <carpeta>
var f := 0
var host: Node
var cli: Node
var dir := "user://"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		dir = a[0]


func _foto(n: String) -> void:
	root.get_texture().get_image().save_png(dir.path_join(n + ".png"))


func _process(_d: float) -> bool:
	f += 1
	match f:
		2:
			Ajustes.cargar()
			Ajustes.mostrar_fps = true
			Ajustes.simular_red = OS.get_environment("SIMULAR") != ""
			var vp := SubViewport.new()
			vp.own_world_3d = true
			vp.size = Vector2i(64, 64)
			root.add_child(vp)
			Sesion.modo = "anfitrion"
			host = load("res://escenas/juego.tscn").instantiate()
			host.name = "JuegoAnfitrion"
			vp.add_child(host)
		30:
			Sesion.modo = "cliente"
			Sesion.direccion = "127.0.0.1"
			cli = load("res://escenas/juego.tscn").instantiate()
			cli.name = "JuegoInvitado"
			root.add_child(cli)
		60:
			cli._mov_prueba = Vector2(0.3, -1.0)
		80:
			cli._mov_prueba = Vector2.ZERO
			# El jugador del anfitrión se acerca para verse con su nombre encima.
			var j = host.servidor.entidad_de_peer(1)
			var yo = host.servidor.entidad(cli.mi_id)
			j.pos = yo.pos + Vector3(1.8, 0, -3.0)
			j.yaw = PI
			cli.camara.yaw = 0.35
		110:
			_foto("red_invitado")
		112:
			cli._on_accion("bola_fuego")
		150:
			_foto("red_invitado_jutsu")
		152:
			quit(0)
	return false
