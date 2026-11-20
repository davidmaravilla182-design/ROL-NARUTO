extends SceneTree
## Cámara contra una pared: jugador pegado a un edificio con la cámara del lado del edificio.
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
		var m: Mapa = _juego.mapa
		var mejor: Dictionary = {}
		for o in m.obstaculos:
			if float(o["alto"]) > 6.0 and (o["centro"] as Vector2).length() < 60.0 and not o.get("solo_personajes", false):
				if mejor.is_empty() or (o["centro"] as Vector2).length() < (mejor["centro"] as Vector2).length():
					mejor = o
		var c: Vector2 = mejor["centro"]
		var md: Vector2 = mejor["medio"]
		var j: EntidadServidor = _juego.servidor.entidad_de_peer(1)
		j.pos = Vector3(c.x, 0, c.y + md.y + 1.3)
		_juego.camara.yaw = PI   # la cámara queda hacia -Z, es decir, dentro del edificio
		print("PARED obstáculo ", c, " medio ", md, " alto ", mejor["alto"])
	if _f == 60:
		print("PARED distancia cámara-jugador %.2f (pedida %.1f)" % [_juego.camara.global_position.distance_to(_juego._pos_entidad(_juego.mi_id) + Vector3(0, 1.6, 0)), _juego.camara.distancia])
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/camara_pared.png")
	return _f > 62
