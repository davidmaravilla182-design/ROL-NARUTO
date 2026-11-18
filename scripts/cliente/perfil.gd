class_name Perfil
extends RefCounted
## Datos del jugador en este dispositivo (modo offline):
##   - hasta 3 personajes creados (user://personajes.json), cuál está activo;
##   - por personaje: maestría por jutsu, 3 repertorios guardados y cuál se usa;
##   - "Modo prueba: desbloquear todo" (global).
## Si todavía no hay personajes se usa la plantilla de práctica de /data/personajes.json.
## En red, el servidor recibe el personaje y la maestría y los valida con las mismas reglas.

const RUTA := "user://personajes.json"
const RUTA_ANTIGUA := "user://perfil.json"
const PLANTILLA := "jugador_uchiha"

static var personajes: Array = []        # [{pj..., "progreso": {maestria, repertorios, activo}}]
static var indice := -1                  # personaje activo (-1 = plantilla de práctica)
static var maestria: Dictionary = {}
static var repertorios: Array = []
static var activo := 0
static var modo_prueba := false
static var _practica: Dictionary = {}    # progreso de la plantilla de práctica
static var _cargado := false


static func cargar() -> void:
	if _cargado:
		return
	_cargado = true
	Datos.cargar()
	personajes = []
	indice = -1
	_practica = {}
	if FileAccess.file_exists(RUTA):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
		if typeof(d) == TYPE_DICTIONARY:
			var dd: Dictionary = d
			for p in dd.get("personajes", []):
				if typeof(p) == TYPE_DICTIONARY:
					personajes.append(p)
			indice = clampi(int(dd.get("activo", -1)), -1, personajes.size() - 1)
			modo_prueba = bool(dd.get("modo_prueba", false))
			if typeof(dd.get("practica")) == TYPE_DICTIONARY:
				_practica = dd["practica"]
	elif FileAccess.file_exists(RUTA_ANTIGUA):
		# Migración del perfil de la versión anterior (sin personajes).
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_ANTIGUA))
		if typeof(v) == TYPE_DICTIONARY:
			_practica = v
			modo_prueba = bool((v as Dictionary).get("modo_prueba", false))
	_usar_progreso(_progreso_activo())


static func recargar() -> void:
	_cargado = false
	cargar()


static func _progreso_activo() -> Dictionary:
	if indice >= 0:
		return (personajes[indice] as Dictionary).get("progreso", {})
	return _practica


static func _usar_progreso(p: Dictionary) -> void:
	var n := int(Repertorio.conf().get("repertorios_guardados", 3))
	maestria = (p.get("maestria", {}) as Dictionary).duplicate() if typeof(p.get("maestria")) == TYPE_DICTIONARY else {}
	repertorios = []
	var por_defecto := repertorio_por_defecto()
	for i in n:
		repertorios.append(por_defecto.duplicate(true))
	if typeof(p.get("repertorios")) == TYPE_ARRAY:
		var lista: Array = p["repertorios"]
		for i in mini(lista.size(), n):
			if typeof(lista[i]) == TYPE_DICTIONARY:
				repertorios[i] = _normalizar(lista[i])
	activo = clampi(int(p.get("activo", 0)), 0, n - 1)


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
	cargar()
	var prog := {"maestria": maestria, "repertorios": repertorios, "activo": activo}
	if indice >= 0:
		(personajes[indice] as Dictionary)["progreso"] = prog
	else:
		_practica = prog
	var f := FileAccess.open(RUTA, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"personajes": personajes, "activo": indice, "modo_prueba": modo_prueba, "practica": _practica}))


# ------------------------------------------------------------------ personajes

## Personaje activo (vacío si se usa la plantilla de práctica).
static func personaje() -> Dictionary:
	cargar()
	if indice >= 0:
		return personajes[indice]
	return {}


static func nombre_activo() -> String:
	var pj := personaje()
	return str(pj.get("nombre", "")) if not pj.is_empty() else str(Datos.personaje(PLANTILLA).get("nombre", ""))


static func max_personajes() -> int:
	return int(Creacion.conf().get("max_personajes", 3))


static func puede_crear() -> bool:
	cargar()
	return personajes.size() < max_personajes()


## Guarda un personaje nuevo (ya validado) y lo deja activo.
static func agregar(pj: Dictionary) -> void:
	cargar()
	guardar()
	var nuevo := pj.duplicate(true)
	nuevo["id"] = "%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	var rep := Creacion.repertorio_inicial(nuevo)
	nuevo["progreso"] = {"maestria": {}, "repertorios": [rep, rep.duplicate(true), rep.duplicate(true)], "activo": 0}
	personajes.append(nuevo)
	indice = personajes.size() - 1
	_usar_progreso(nuevo["progreso"])
	guardar()


static func elegir(i: int) -> void:
	cargar()
	guardar()
	indice = clampi(i, -1, personajes.size() - 1)
	_usar_progreso(_progreso_activo())
	guardar()


static func borrar(i: int) -> void:
	cargar()
	if i < 0 or i >= personajes.size():
		return
	guardar()
	personajes.remove_at(i)
	if indice == i:
		indice = personajes.size() - 1
	elif indice > i:
		indice -= 1
	_usar_progreso(_progreso_activo())
	guardar()


# ------------------------------------------------------------------ repertorio

static func repertorio_por_defecto() -> Dictionary:
	var pj := personaje()
	if pj.is_empty():
		return Repertorio.repertorio_por_defecto(PLANTILLA)
	return Creacion.repertorio_inicial(pj)


static func repertorio() -> Dictionary:
	cargar()
	var r: Dictionary = repertorios[activo]
	while (r["activos"] as Array).size() < int(Repertorio.conf().get("ranuras_activas", 4)):
		(r["activos"] as Array).append("")
	return r


static func ficha() -> Dictionary:
	cargar()
	var pj := personaje()
	if pj.is_empty():
		return Repertorio.ficha(PLANTILLA, maestria)
	return Creacion.ficha(pj, maestria)


static func atributos() -> Dictionary:
	var pj := personaje()
	if pj.is_empty():
		return Datos.personaje(PLANTILLA).get("atributos", {})
	return pj.get("atributos", {})


static func xp(id: String) -> float:
	cargar()
	return float(maestria.get(id, 0.0))


## Comando con el personaje activo (si hay uno creado).
static func comando_personaje() -> Dictionary:
	var pj := personaje().duplicate(true)
	pj.erase("progreso")
	return {"t": Protocolo.C_PERSONAJE, "datos": pj}


## Comando para el servidor con el repertorio activo y la maestría guardada.
static func comando() -> Dictionary:
	var r := repertorio()
	return {"t": Protocolo.C_REPERTORIO, "activos": r["activos"], "modo": r["modo"], "niveles_max": r.get("niveles_max", {}),
		"maestria": maestria.duplicate(), "prueba": modo_prueba}
