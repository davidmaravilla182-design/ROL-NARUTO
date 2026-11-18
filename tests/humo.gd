extends SceneTree
## Prueba de humo: carga el menú y la partida, simula unos segundos con
## comandos reales y termina. Cualquier error de script hace fallar la verificación.
## Ejecutar: godot --headless --path . -s res://tests/humo.gd

var escenas := ["res://escenas/menu.tscn", "res://escenas/juego.tscn"]
var _frames := 0
var _fase := 0
var _actual: Node = null


func _initialize() -> void:
	_cargar(0)


func _cargar(i: int) -> void:
	if _actual != null:
		_actual.queue_free()
		_actual = null
	if i >= escenas.size():
		print("HUMO: correcto")
		quit(0)
		return
	if not ResourceLoader.exists(escenas[i]):
		print("HUMO: se omite %s (no existe)" % escenas[i])
		_cargar(i + 1)
		return
	var ps: PackedScene = load(escenas[i])
	if ps == null:
		printerr("HUMO: no se pudo cargar ", escenas[i])
		quit(1)
		return
	_actual = ps.instantiate()
	root.add_child(_actual)
	print("HUMO: escena cargada ", escenas[i])
	_fase = i
	_frames = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _fase == 1 and _actual != null and _actual.has_method("prueba_humo"):
		_actual.prueba_humo(_frames)
	var limite := 30 if _fase == 0 else 400
	if _frames >= limite:
		_cargar(_fase + 1)
	return false
