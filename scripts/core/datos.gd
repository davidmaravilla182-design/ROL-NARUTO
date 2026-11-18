class_name Datos
extends RefCounted
## Carga y expone los datos de diseño de /data (JSON).
## Es estático para que servidor, cliente y pruebas lo usen sin autoloads.

const RUTA := "res://data/"

static var reglas: Dictionary = {}
static var mundo: Dictionary = {}
static var jutsus: Dictionary = {}
static var personajes: Dictionary = {}
static var escenario: Dictionary = {}
static var textos: Dictionary = {}
static var graficos: Dictionary = {}
static var _cargado := false


static func cargar(forzar := false) -> void:
	if _cargado and not forzar:
		return
	reglas = leer_json("reglas.json")
	mundo = leer_json("mundo.json")
	jutsus = leer_json("jutsus.json")
	personajes = leer_json("personajes.json")
	escenario = leer_json("escenario.json")
	textos = leer_json("textos.json")
	graficos = leer_json("graficos.json")
	_cargado = true


static func leer_json(nombre: String) -> Dictionary:
	var ruta := RUTA + nombre
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		push_error("No se pudo abrir %s" % ruta)
		return {}
	var contenido := archivo.get_as_text()
	var json := JSON.new()
	var err := json.parse(contenido)
	if err != OK:
		push_error("JSON inválido en %s línea %d: %s" % [ruta, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("%s debe contener un objeto" % ruta)
		return {}
	return json.data


## Devuelve un texto de interfaz, reemplazando {0}, {1}...
static func texto(clave: String, args: Array = []) -> String:
	cargar()
	var t: String = str(textos.get(clave, clave))
	for i in args.size():
		t = t.replace("{%d}" % i, str(args[i]))
	return t


static func jutsu(id: String) -> Dictionary:
	cargar()
	return jutsus.get(id, {})


static func nivel_jutsu(id: String, nivel: int) -> Dictionary:
	var j := jutsu(id)
	var niveles: Array = j.get("niveles", [])
	if niveles.is_empty():
		return {}
	var idx := clampi(nivel, 1, niveles.size()) - 1
	return niveles[idx]


static func personaje(id: String) -> Dictionary:
	cargar()
	return personajes.get(id, {})


static func formula(clave: String) -> float:
	cargar()
	return float(reglas.get("formulas", {}).get(clave, 0.0))


static func sim(clave: String) -> float:
	cargar()
	return float(reglas.get("simulacion", {}).get(clave, 0.0))


static func aldea(id: String) -> Dictionary:
	cargar()
	return mundo.get("aldeas", {}).get(id, {})


static func nombre_naturaleza(id: String) -> String:
	cargar()
	return str(mundo.get("naturalezas", {}).get("datos", {}).get(id, {}).get("nombre", id))


static func color(hex: String, por_defecto := Color.MAGENTA) -> Color:
	if hex.is_empty():
		return por_defecto
	return Color.from_string(hex, por_defecto)
