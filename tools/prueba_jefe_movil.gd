extends SceneTree
## Cliente real con el renderizador del celular: va directo a la explanada, empieza el capítulo 6, entra al lago
## y registra errores. Uso: xvfb-run godot --path . --rendering-method mobile --script tools/prueba_jefe_movil.gd
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
		j.pos = Vector3(0, 0, 165)
		j.personaje["misiones"] = {"capitulo": 5}
		s.misiones.empezar_capitulo(j, "cap6")
		print("MOVIL: capítulo 6 empezado")
	if _f > 5:
		_juego._mov_prueba = Vector2(0, -1)   # hacia el lago
	if _f % 10 == 0:
		print("MOVIL f=%d jugador %s agua %d estado %s fps %d" % [_f, str(j.pos.snapped(Vector3.ONE * 0.1)), j.agua, j.estado, Engine.get_frames_per_second()])
	if _f == 120:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/jefe_movil.png")
	return _f > 125
