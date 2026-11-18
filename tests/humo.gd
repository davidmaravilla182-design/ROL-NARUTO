extends SceneTree
## Prueba de humo: carga el menú y la partida en las tres calidades gráficas,
## simula unos segundos con comandos reales (toque, arrastre, cancelar, fijar objetivo,
## pausa de impacto, ajustes) y termina. Cualquier error de script hace fallar la verificación.
## Ejecutar: godot --headless --path . -s res://tests/humo.gd

var pasos := [
	["res://escenas/menu.tscn", ""],
	["res://escenas/repertorio.tscn", ""],
	["res://escenas/personaje.tscn", ""],
	["res://escenas/juego.tscn", "alta"],
	["res://escenas/juego.tscn", "media"],
	["res://escenas/juego.tscn", "baja"],
	["red", ""],
	["res://escenas/red.tscn", ""],
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
	if ruta == "red":
		_cargar_red(i)
		return
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


## Partida local real: un juego anfitrión y otro invitado en el mismo proceso, por localhost.
var _invitado: Node = null


func _cargar_red(i: int) -> void:
	Ajustes.cargar()
	Ajustes.calidad = "baja"
	Sesion.modo = "anfitrion"
	_actual = (load("res://escenas/juego.tscn") as PackedScene).instantiate()
	_actual.name = "JuegoAnfitrion"
	root.add_child(_actual)
	print("HUMO: partida local creada (anfitrión)")
	_indice = i
	_frames = 0


func _paso_red() -> void:
	if _frames == 20:
		Sesion.modo = "cliente"
		Sesion.direccion = "127.0.0.1"
		_invitado = (load("res://escenas/juego.tscn") as PackedScene).instantiate()
		_invitado.name = "JuegoInvitado"
		root.add_child(_invitado)
		print("HUMO: invitado conectándose por localhost")
	if _invitado != null and _frames == 90:
		_invitado._on_accion("golpe")
		_invitado._mov_prueba = Vector2(0.5, -1.0)
	if _frames == 170:
		var jugadores := 0
		for e in _actual.servidor.entidades:
			if e.tipo == "jugador":
				jugadores += 1
		if _invitado.mi_id < 0 or jugadores != 2 or (_invitado._visuales as Dictionary).size() < 3:
			printerr("HUMO: la partida local no se conectó (mi_id=%d, jugadores=%d)" % [_invitado.mi_id, jugadores])
			quit(1)
			return
		print("HUMO: partida local con 2 jugadores conectada")
		_invitado.queue_free()
		_invitado = null
		Sesion.modo = "offline"


func _process(_delta: float) -> bool:
	_frames += 1
	if pasos[_indice][0] == "red":
		_paso_red()
		if _frames >= 180:
			_cargar(_indice + 1)
		return false
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
	if _indice == 2 and _actual != null:
		# Creación de personaje: recorrer los pasos y elegir opciones.
		match _frames:
			3:
				if _actual.modo != "crear":
					_actual._empezar_creacion()
			5:
				_actual.pj["nombre"] = "Humo"
				for p in 6:
					_actual.paso = p
					_actual._mostrar_paso()
			8:
				_actual.pj["clan"] = "lava"
				_actual.pj["aspecto"]["peinado"] = "melena"
				_actual._cambio(true)
	if _actual != null and _actual.has_method("prueba_humo"):
		_actual.prueba_humo(_frames)
	var limite := 30 if _indice <= 2 else (700 if _indice == 3 else 90)
	if _frames >= limite:
		_cargar(_indice + 1)
	return false
