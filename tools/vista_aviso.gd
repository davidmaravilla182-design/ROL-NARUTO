extends SceneTree
## Captura de los avisos de área en el suelo: uno enemigo (rojo) y uno propio (azul) junto al jugador.
var _juego: Node
var _f := 0


func _initialize() -> void:
	Sesion.modo = "offline"
	Perfil.marcar_prologo()
	_juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate()
	root.add_child(_juego)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 10:
		var j: EntidadServidor = _juego.servidor.entidad_de_peer(1)
		j.pos = Vector3(0, 0, 84)
		_juego.camara.yaw = PI   # mirando hacia +Z (los guardias del puente)
	if _f == 30:
		var yo: Vector3 = _juego._pos_entidad(_juego.mi_id)
		_juego.efectos.aviso_suelo(yo + Vector3(-3.5, 0, -6), 4.0, 2.0, true)
		_juego.efectos.aviso_suelo(yo + Vector3(4.5, 0, -5), 3.0, 2.0, false)
	if _f == 60:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/aviso_suelo.png")
	return _f > 62
