extends SceneTree
## Capturas del modo Arena: campo abierto, muro del borde, aliados (aro azul, placa «ALIADO») y enemigos (aro rojo).
var _juego: Node
var _f := 0


func _initialize() -> void:
	Sesion.modo = "arena"
	_juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate()
	root.add_child(_juego)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 15:
		_juego.camara.yaw = 0.0   # mirando al centro de la arena (hacia -Z)
	if _f == 150:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/arena_1.png")
	if _f == 260:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/arena_2.png")
	return _f > 262
