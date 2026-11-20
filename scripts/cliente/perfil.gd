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
	_migrar_puntos()
	_usar_progreso(_progreso_activo())


## v0.9: el tope de puntos depende del rango (14 al crear). Los personajes creados antes conservan sus puntos.
static func _migrar_puntos() -> void:
	for p in personajes:
		var pj: Dictionary = p
		if not pj.has("puntos_legado"):
			var total := Creacion.total_puntos(pj.get("atributos", {}))
			pj["puntos_legado"] = total if total > 14 else 0
			for k in ["xp_total", "xp_rango"]:
				if not pj.has(k):
					pj[k] = 0.0
			if not pj.has("entreno"):
				pj["entreno"] = {}


## Experiencia de combate y misiones que llega del servidor (cuenta para el rango y los puntos de atributo).
static func sumar_xp(cantidad: float) -> void:
	cargar()
	if indice < 0:
		return
	var pj: Dictionary = personajes[indice]
	pj["xp_total"] = float(pj.get("xp_total", 0.0)) + cantidad
	pj["xp_rango"] = float(pj.get("xp_rango", 0.0)) + cantidad


## Resultado de una misión que manda el servidor: experiencia ya llegó aparte (evento "xp"); aquí ryō, pergaminos,
## cosméticos, capítulo de la historia, pruebas de ascenso y punto de atributo. Devuelve el rango nuevo si asciende.
static func aplicar_mision(ev: Dictionary) -> String:
	cargar()
	if indice < 0 or not bool(ev.get("exito", false)):
		return ""
	var pj: Dictionary = personajes[indice]
	var rec: Dictionary = ev.get("recompensa", {})
	pj["ryo"] = int(pj.get("ryo", 0)) + int(rec.get("ryo", 0))
	var perg: Array = pj.get("pergaminos", [])
	for p in rec.get("pergaminos", []):
		if not (str(p) in perg):
			perg.append(str(p))
	pj["pergaminos"] = perg
	var cos: Array = pj.get("cosmeticos", [])
	for c in rec.get("cosmeticos", []):
		if not (str(c) in cos):
			cos.append(str(c))
	pj["cosmeticos"] = cos
	var mis: Dictionary = pj.get("misiones", {"capitulo": 0, "completadas": [], "pruebas": {}})
	if str(ev.get("tipo_mision", "")) == "capitulo":
		var i := Misiones.indice_capitulo(str(ev["id"]))
		mis["capitulo"] = maxi(int(mis.get("capitulo", 0)), i + 1)
		var comp: Array = mis.get("completadas", [])
		if not (str(ev["id"]) in comp):
			comp.append(str(ev["id"]))
		mis["completadas"] = comp
	if str(ev.get("prueba", "")) != "":
		var pr: Dictionary = mis.get("pruebas", {})
		pr[str(ev["prueba"])] = true
		mis["pruebas"] = pr
	pj["misiones"] = mis
	if int(rec.get("punto_atributo", 0)) > 0:
		pj["puntos_bonus_rango"] = mini(int(pj.get("puntos_bonus_rango", 0)) + 1, 2)
	return intentar_ascenso()


## Asciende si ya tiene la experiencia y superó la prueba de su rango. Devuelve el rango nuevo o "".
static func intentar_ascenso() -> String:
	if indice < 0:
		return ""
	var pj: Dictionary = personajes[indice]
	var a := Creacion.ascenso(pj)
	var pr: Dictionary = pj.get("misiones", {}).get("pruebas", {})
	if str(a["siguiente"]) != "" and bool(a["listo_xp"]) and bool(pr.get(str(a["prueba"]), false)):
		if Creacion.ascender(pj):
			return str(pj["rango"])
	return ""


## Equipa un cosmético ganado (cambia el aspecto del personaje).
static func equipar_cosmetico(id: String) -> bool:
	cargar()
	if indice < 0:
		return false
	var pj: Dictionary = personajes[indice]
	if not (id in (pj.get("cosmeticos", []) as Array)):
		return false
	var cd: Dictionary = Misiones.conf().get("cosmeticos", {}).get(id, {})
	if cd.is_empty():
		return false
	var asp: Dictionary = pj.get("aspecto", {})
	asp[str(cd["tipo"])] = cd["valor"]
	pj["aspecto"] = asp
	return true


## Barra de entrenamiento de un atributo (0-1).
static func poner_entreno(atributo: String, valor: float) -> void:
	cargar()
	if indice < 0:
		return
	var pj: Dictionary = personajes[indice]
	var ent: Dictionary = pj.get("entreno", {})
	ent[atributo] = clampf(valor, 0.0, 1.0)
	pj["entreno"] = ent


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
		var lug: Variant = _practica.get("lugares")
		_practica = prog
		if lug != null:
			_practica["lugares"] = lug   # lo descubierto en la práctica (puntos de misión, distritos, prólogo)
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


# ------------------------------------------------------------------ guía de la historia
# Lo que el jugador ya descubrió a pie (en el personaje, o en la práctica si no hay personaje):
#   lugares.distritos  distritos por los que ya pasó (el «Viaje rápido» del mapa solo lleva a esos)
#   lugares.misiones   capítulos cuyo punto de misión ya alcanzó (solo entonces se pueden empezar desde el menú)
#   lugares.prologo    ya vio el prólogo de la historia

static func _lugares() -> Dictionary:
	cargar()
	var dueno: Dictionary = personajes[indice] if indice >= 0 else _practica
	if typeof(dueno.get("lugares")) != TYPE_DICTIONARY:
		dueno["lugares"] = {"distritos": [], "misiones": [], "prologo": false}
	return dueno["lugares"]


## Índice del capítulo que toca (= número de capítulos completados).
static func capitulo_indice() -> int:
	var pj := personaje()
	return int(pj.get("misiones", {}).get("capitulo", 0)) if not pj.is_empty() else 0


## Capítulo siguiente de la historia ({} si ya terminó todos).
static func capitulo_siguiente() -> Dictionary:
	var caps: Array = Misiones.conf().get("capitulos", [])
	var i := capitulo_indice()
	return caps[i] if i < caps.size() else {}


static func mision_visitada(id: String) -> bool:
	return str(id) in (_lugares().get("misiones", []) as Array)


## Marca el punto de misión como alcanzado; devuelve true si es la primera vez.
static func marcar_mision_visitada(id: String) -> bool:
	var l := _lugares()
	var arr: Array = l.get("misiones", [])
	if str(id) in arr:
		return false
	arr.append(str(id))
	l["misiones"] = arr
	guardar()
	return true


static func distrito_visitado(id: String) -> bool:
	return str(id) in (_lugares().get("distritos", []) as Array)


static func marcar_distrito(id: String) -> bool:
	if id == "":
		return false
	var l := _lugares()
	var arr: Array = l.get("distritos", [])
	if id in arr:
		return false
	arr.append(id)
	l["distritos"] = arr
	guardar()
	return true


static func prologo_visto() -> bool:
	return bool(_lugares().get("prologo", false))


static func marcar_prologo() -> void:
	_lugares()["prologo"] = true
	guardar()
