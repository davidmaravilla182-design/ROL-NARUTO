extends SceneTree
## Captura del pergamino ganado en el suelo: cae, flota y vuela al jugador al acercarse (docs/capturas/v09/pergamino_*.png).
var _t := 0
var _jugador: Node3D


func _initialize() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.2, 0.22, 0.28)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.5, 0.5, 0.6)
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 30, 0)
	sol.light_energy = 0.6
	raiz.add_child(sol)
	var suelo := Materiales.caja(Vector3(12, 0.1, 12), Materiales.solido(Color(0.3, 0.31, 0.34)))
	suelo.position.y = -0.05
	raiz.add_child(suelo)
	_jugador = PersonajeVisual.new()
	raiz.add_child(_jugador)
	_jugador.construir("intruso")
	var cam := Camera3D.new()
	raiz.add_child(cam)
	cam.look_at_from_position(Vector3(3.2, 2.4, 5.0), Vector3(0, 0.8, 1.6), Vector3.UP)
	var p := PergaminoSuelo.new()
	raiz.add_child(p)
	p.construir(_jugador, Vector3(0, 0, 2.2), "Remolino de la Hoja")
	p.recogido.connect(func(n): print("RECOGIDO ", n))


func _process(_d: float) -> bool:
	_t += 1
	if _t > 60:
		_jugador.position.z = minf(2.0, (_t - 60) * 0.08)
	for f in [12, 55, 82, 88]:
		if _t == f:
			root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/pergamino_%d.png" % f)
	return _t > 95
