extends SceneTree
## Prueba de humo: carga el menú y la partida en las tres calidades gráficas,
## simula unos segundos con comandos reales (toque, arrastre, cancelar, fijar objetivo,
## pausa de impacto, ajustes) y termina. Cualquier error de script hace fallar la verificación.
## Ejecutar: godot --headless --path . -s res://tests/humo.gd

var pasos := [
	["res://escenas/menu.tscn", ""],
	["res://escenas/repertorio.tscn", ""],
	["res://escenas/juego.tscn", "alta"],
	["res://escenas/juego.tscn", "media"],
	["res://escenas/juego.tscn", "baja"],
]
var _frames := 0
var _indice := 0
var _actual: Node = null


func _initialize() -> void:
	_cargar(0)


func _cargar(i: int) -> void:
	if _actual != null:
		_actual.queue_free()
		_actual = null
	if i >= pasos.size():
		Engine.time_scale = 1.0
		print("HUMO: correcto")
		quit(0)
		return
	var ruta: String = pasos[i][0]
	if pasos[i][1] != "":
		Ajustes.cargar()
		Ajustes.calidad = pasos[i][1]
	var ps: PackedScene = load(ruta)
	if ps == null:
		printerr("HUMO: no se pudo cargar ", ruta)
		quit(1)
		return
	_actual = ps.instantiate()
	root.add_child(_actual)
	print("HUMO: escena cargada ", ruta, " ", pasos[i][1])
	_indice = i
	_frames = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _indice == 1 and _actual != null:
		# Menú del repertorio: abrir detalle, equipar, ciclar nivel, quitar y cambiar de repertorio.
		match _frames:
			3: _actual.abrir_detalle("kirin")
			6: _actual.equipar("rasengan", 3)
			8: _actual.ciclar_nivel(0)
			10: _actual.quitar(3)
			12: _actual._elegir_rep(1)
			14: _actual._elegir_rep(0)
			16: _actual.equipar("byakugan", -1)
			18: _actual.equipar("sharingan", -1)
	if _actual != null and _actual.has_method("prueba_humo"):
		_actual.prueba_humo(_frames)
	var limite := 30 if _indice <= 1 else (640 if _indice == 2 else 90)
	if _frames >= limite:
		_cargar(_indice + 1)
	return false
