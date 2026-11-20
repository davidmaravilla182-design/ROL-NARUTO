extends SceneTree
## Reproduce el recorrido puerta → puente → explanada y la pelea con el Tres Colas en el cliente real,
## con capturas (docs/capturas/v09/puente_*.png) y registro de la posición del jugador.
var _juego: Node
var _f := 0
const PUNTOS := [Vector3(0, 0, 64), Vector3(0, 0, 90), Vector3(0, 0, 115), Vector3(0, 0, 140), Vector3(0, 0, 160), Vector3(10, 0, 168)]


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
	var k := (_f - 30) / 40
	if _f >= 30 and (_f - 30) % 40 == 0 and k < PUNTOS.size():
		j.pos = PUNTOS[k]
		j.yaw = 0.0
	if _f >= 30 and (_f - 30) % 40 == 30 and k < PUNTOS.size():
		var vis := 0
		for id in _juego._visuales:
			var n: Node3D = _juego._visuales[id]["nodo"]
			if n.is_visible_in_tree():
				vis += 1
		print("PUENTE punto %d jugador %s visuales %d/%d cam %s" % [k, str(j.pos.snapped(Vector3.ONE * 0.1)), vis, _juego._visuales.size(), str(_juego.camara.global_position.snapped(Vector3.ONE * 0.1))])
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/puente_%d.png" % k)
	var fin_paseo := 30 + PUNTOS.size() * 40
	if _f == fin_paseo:
		j.pos = Vector3(0, 0, -20)   # desde la plaza: la misión lo lleva a la explanada y gira la cámara
		j.personaje["misiones"] = {"capitulo": 5}
		s.misiones.empezar_capitulo(j, "cap6")
	if _f > fin_paseo and _f % 30 == 0:
		var a := _f * 0.03
		_juego._mov_prueba = Vector2(sin(a), -cos(a * 0.7))
		print("JEFE f=%d jugador %s agua %d estado %s vida %d" % [_f, str(j.pos.snapped(Vector3.ONE * 0.1)), j.agua, j.estado, int(j.vida)])
	if _f == fin_paseo + 200:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/puente_llegada.png")
	if _f == fin_paseo + 300:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/puente_jefe.png")
	return _f > fin_paseo + 900
