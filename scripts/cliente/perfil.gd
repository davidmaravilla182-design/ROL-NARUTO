class_name Perfil
extends RefCounted
## Progreso del jugador en este dispositivo (modo offline): maestría por jutsu,
## 3 repertorios guardados, cuál está activo y el modo prueba. Se guarda en user://perfil.json.
## En red, la maestría debería vivir en el servidor; aquí el servidor la recibe y la valida.

const RUTA := "user://perfil.json"
const PLANTILLA := "jugador_uchiha"

static var maestria: Dictionary = {}
static var repertorios: Array = []
static var activo := 0
static var modo_prueba := false
static var _cargado := false


static func cargar() -> void:
	if _cargado:
		return
	_cargado = true
	Datos.cargar()
	var n := int(Repertorio.conf().get("repertorios_guardados", 3))
	repertorios = []
	for i in n:
		repertorios.append(Repertorio.repertorio_por_defecto(PLANTILLA))
	if not FileAccess.file_exists(RUTA):
		return
	var txt := FileAccess.get_file_as_string(RUTA)
	var d: Variant = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		return
	var dd: Dictionary = d
	if typeof(dd.get("maestria")) == TYPE_DICTIONARY:
		maestria = dd["maestria"]
	if typeof(dd.get("repertorios")) == TYPE_ARRAY:
		var lista: Array = dd["repertorios"]
		for i in mini(lista.size(), n):
			if typeof(lista[i]) == TYPE_DICTIONARY:
				repertorios[i] = _normalizar(lista[i])
	activo = clampi(int(dd.get("activo", 0)), 0, n - 1)
	modo_prueba = bool(dd.get("modo_prueba", false))


static func _normalizar(r: Dictionary) -> Dictionary:
	var act: Array = []
	for a in r.get("activos", []):
		act.append(str(a) if Datos.jutsus.has(str(a)) else "")
	while act.size() < int(Repertorio.conf().get("ranuras_activas", 4)):
		act.append("")
	var modo := str(r.get("modo", ""))
	var niveles := {}
	for k in (r.get("niveles_max", {}) as Dictionary).keys():
		niveles[str(k)] = clampi(int(r["niveles_max"][k]), 1, 3)
	return {"activos": act.slice(0, int(Repertorio.conf().get("ranuras_activas", 4))), "modo": modo if Datos.jutsus.has(modo) else "", "niveles_max": niveles}


static func guardar() -> void:
	var f := FileAccess.open(RUTA, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"maestria": maestria, "repertorios": repertorios, "activo": activo, "modo_prueba": modo_prueba}))


static func repertorio() -> Dictionary:
	cargar()
	var r: Dictionary = repertorios[activo]
	while (r["activos"] as Array).size() < int(Repertorio.conf().get("ranuras_activas", 4)):
		(r["activos"] as Array).append("")
	return r


static func ficha() -> Dictionary:
	cargar()
	return Repertorio.ficha(PLANTILLA, maestria)


static func xp(id: String) -> float:
	cargar()
	return float(maestria.get(id, 0.0))


## Comando para el servidor con el repertorio activo y la maestría guardada.
static func comando() -> Dictionary:
	var r := repertorio()
	return {"t": Protocolo.C_REPERTORIO, "activos": r["activos"], "modo": r["modo"], "niveles_max": r.get("niveles_max", {}),
		"maestria": maestria.duplicate(), "prueba": modo_prueba}
