extends SceneTree
## Captura del pájaro de papel llegando y aleteando: docs/capturas/v09/pajaro_*.png
var _t := 0
var _pj: PajaroPapel
var _vp: Node3D


func _initialize() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.32, 0.34, 0.4)
	we.environment.ambient_light_color = Color(0.7, 0.7, 0.8)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-45, 30, 0)
	raiz.add_child(sol)
	var jugador := Node3D.new()
	raiz.add_child(jugador)
	var marca := Materiales.cilindro(0.3, 0.3, 1.8, Materiales.solido(Color(0.2, 0.2, 0.25)), 10)
	marca.position.y = 0.9
	jugador.add_child(marca)
	var cam := Camera3D.new()
	raiz.add_child(cam)
	cam.look_at_from_position(Vector3(1.5, 3.0, 4.5), Vector3(0.8, 2.0, 0), Vector3.UP)
	_pj = PajaroPapel.new()
	raiz.add_child(_pj)
	_pj.construir(jugador, 3.0)


func _process(_d: float) -> bool:
	_t += 1
	for f in [18, 40, 46, 52, 110]:
		if _t == f:
			root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/pajaro_%d.png" % f)
	return _t > 112
