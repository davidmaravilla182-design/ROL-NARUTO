extends SceneTree
## Cliente real con el renderizador del celular: empieza el capítulo 6 desde la plaza (la misión lo lleva a la
## explanada), camina sobre el lago hacia el Tres Colas ~40 s y registra errores.
## Uso: xvfb-run godot --path . --rendering-method mobile --script tools/prueba_jefe_movil.gd
var _juego: Node
var _f := 0


func _initialize() -> void:
	Sesion.modo = "offline"
	_juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate()
	root.add_child(_juego)


func _process(_d: float) -> bool:
	_f += 1
	var s: ServidorJuego = _juego.servidor
	var j: EntidadServidor = s.entidad_de_peer(1) if s != null else null
	if j == null:
		return false
	if _f == 5:
		j.pos = Vector3(0, 0, 10)
		j.personaje["misiones"] = {"capitulo": 5}
		s.misiones.empezar_capitulo(j, "cap6")
		print("MOVIL: capítulo 6 empezado")
	if _f > 300:
		# Hacia el jefe, zigzagueando sobre el lago.
		_juego._mov_prueba = Vector2(sin(_f * 0.02) * 0.6, -1.0)
	if _f % 30 == 0:
		print("MOVIL f=%d jugador %s agua %d estado %s vida %d chakra %d" % [_f, str(j.pos.snapped(Vector3.ONE * 0.1)), j.agua, j.estado, int(j.vida), int(j.chakra)])
	if _f == 900:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/jefe_movil.png")
	return _f > 1500
