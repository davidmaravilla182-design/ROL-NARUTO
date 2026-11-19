class_name Repertorio
extends RefCounted
## Reglas del repertorio de jutsus (compartidas por el menú y el servidor):
## requisitos (naturaleza, linaje, rango, atributos, dominio, modo), puntos, incompatibles
## y maestría (experiencia por jutsu → nivel desbloqueado → nivel efectivo en combate).
##
## Un repertorio es: {"activos": [id, id, id, id], "modo": id, "niveles_max": {id: 1..3}}
## Una ficha de personaje es: {attrs, naturalezas, linajes, contratos, rango, maestria: {id: xp}}

const MODOS_BASE := ["golpe", "esquivar", "saltar"]


## Ids del menú (sin técnicas internas), en el orden del JSON.
static func catalogo() -> Array:
	Datos.cargar()
	var r: Array = []
	for k in Datos.jutsus.keys():
		if str(k).begins_with("_"):
			continue
		if Datos.jutsus[k].get("interno", false):
			continue
		r.append(k)
	return r


static func categorias() -> Dictionary:
	Datos.cargar()
	return Datos.jutsus.get("_categorias", {})


## Usos: ataque, defensa, control, apoyo ({id: {nombre, color}}).
static func roles() -> Dictionary:
	return Datos.jutsus.get("_roles", {})


static func es_modo(id: String) -> bool:
	return str(Datos.jutsu(id).get("ranura", "")) == "modo"


static func implementado(id: String) -> bool:
	return bool(Datos.jutsu(id).get("implementado", false))


static func puntos(id: String) -> int:
	return int(Datos.jutsu(id).get("puntos", 0))


static func conf() -> Dictionary:
	Datos.cargar()
	return Datos.reglas.get("repertorio", {})


## Ficha de un personaje a partir de su plantilla (más la maestría guardada).
static func ficha(plantilla: String, maestria: Dictionary = {}) -> Dictionary:
	var d := Datos.personaje(plantilla)
	return {
		"attrs": d.get("atributos", {}), "naturalezas": d.get("naturalezas", []), "linajes": d.get("linajes", []),
		"contratos": d.get("contratos", []), "rango": str(d.get("rango", "genin")), "maestria": maestria,
	}


static func repertorio_por_defecto(plantilla: String) -> Dictionary:
	var r: Dictionary = Datos.personaje(plantilla).get("repertorio", {"activos": [], "modo": ""})
	return {"activos": (r.get("activos", []) as Array).duplicate(), "modo": str(r.get("modo", "")), "niveles_max": {}}


static func _rango_indice(r: String) -> int:
	return (Datos.reglas.get("rangos", []) as Array).find(r)


# ------------------------------------------------------------------ maestría

static func xp_niveles() -> Array:
	Datos.cargar()
	return Datos.reglas.get("maestria", {}).get("xp_niveles", [0, 100, 300])


static func nivel_desbloqueado(xp: float) -> int:
	var umbrales := xp_niveles()
	var n := 1
	for i in umbrales.size():
		if xp >= float(umbrales[i]):
			n = i + 1
	return clampi(n, 1, 3)


## Nivel que se usa en combate: el forzado por depuración, o el más alto desbloqueado
## limitado por el máximo que eligió el jugador en el menú.
static func nivel_efectivo(id: String, xp: float, nivel_max: int = 3, forzado: int = 0) -> int:
	var total := (Datos.jutsu(id).get("niveles", []) as Array).size()
	if total == 0:
		return 1
	if forzado > 0:
		return clampi(forzado, 1, total)
	return clampi(mini(nivel_desbloqueado(xp), nivel_max if nivel_max > 0 else 3), 1, total)


# ------------------------------------------------------------------ requisitos

## {ok: bool, motivos: [String]}. `modo` es el modo equipado en el repertorio que se está armando.
static func requisitos(id: String, ficha_pj: Dictionary, modo: String = "") -> Dictionary:
	var j := Datos.jutsu(id)
	var req: Dictionary = j.get("requisitos", {})
	var motivos: Array = []
	var nat_pj: Array = ficha_pj.get("naturalezas", [])
	for n in req.get("naturalezas", []):
		if not (n in nat_pj):
			motivos.append(Datos.texto("req_naturaleza", [Datos.nombre_naturaleza(str(n))]))
	if req.has("linaje") and not (str(req["linaje"]) in (ficha_pj.get("linajes", []) as Array)):
		motivos.append(Datos.texto("req_linaje", [Datos.texto("linaje_" + str(req["linaje"]))]))
	if req.get("contrato", false) and (ficha_pj.get("contratos", []) as Array).is_empty():
		motivos.append(Datos.texto("req_contrato"))
	# Un pergamino enseña el jutsu: ya no hace falta el rango (los atributos y naturalezas siguen valiendo).
	var aprendido := id in (ficha_pj.get("pergaminos", []) as Array)
	if req.has("rango") and not aprendido and _rango_indice(str(ficha_pj.get("rango", "genin"))) < _rango_indice(str(req["rango"])):
		motivos.append(Datos.texto("req_rango", [Datos.texto("rango_" + str(req["rango"]))]))
	var attrs: Dictionary = ficha_pj.get("attrs", {})
	for a in req.get("atributos_min", {}).keys():
		if int(attrs.get(a, 0)) < int(req["atributos_min"][a]):
			motivos.append(Datos.texto("req_atributo_min", [Datos.texto("attr_" + a), int(req["atributos_min"][a])]))
	for a in req.get("atributos_max", {}).keys():
		if int(attrs.get(a, 0)) > int(req["atributos_max"][a]):
			motivos.append(Datos.texto("req_atributo_max", [Datos.texto("attr_" + a), int(req["atributos_max"][a])]))
	if req.has("control_min") and Combate.control(attrs) < float(req["control_min"]):
		motivos.append(Datos.texto("req_control", [req["control_min"]]))
	if req.has("reserva_min") and Combate.reserva(attrs) < float(req["reserva_min"]):
		motivos.append(Datos.texto("req_reserva", [req["reserva_min"]]))
	var maestria: Dictionary = ficha_pj.get("maestria", {})
	for d in req.get("dominio", {}).keys():
		if nivel_desbloqueado(float(maestria.get(d, 0.0))) < int(req["dominio"][d]):
			motivos.append(Datos.texto("req_dominio", [Datos.jutsu(d).get("nombre", d), int(req["dominio"][d])]))
	if req.has("modo") and not (modo in (req["modo"] as Array)):
		var nombres: Array = []
		for m in req["modo"]:
			nombres.append(str(Datos.jutsu(m).get("nombre", m)))
		motivos.append(Datos.texto("req_modo", [" / ".join(nombres)]))
	return {"ok": motivos.is_empty(), "motivos": motivos}


## Texto corto del requisito para la tarjeta.
static func texto_requisito(id: String) -> String:
	var req: Dictionary = Datos.jutsu(id).get("requisitos", {})
	var partes: Array = []
	for n in req.get("naturalezas", []):
		partes.append(Datos.nombre_naturaleza(str(n)))
	if req.has("linaje"):
		partes.append(Datos.texto("linaje_" + str(req["linaje"])))
	if req.has("modo"):
		for m in req["modo"]:
			partes.append(str(Datos.jutsu(m).get("nombre", m)))
	if req.has("rango"):
		partes.append(Datos.texto("rango_" + str(req["rango"])))
	for a in req.get("atributos_min", {}).keys():
		partes.append("%s %d" % [Datos.texto("attr_" + a), int(req["atributos_min"][a])])
	for a in req.get("atributos_max", {}).keys():
		partes.append("%s ≤%d" % [Datos.texto("attr_" + a), int(req["atributos_max"][a])])
	if req.has("control_min"):
		partes.append(Datos.texto("req_corto_control"))
	if req.has("reserva_min"):
		partes.append(Datos.texto("req_corto_reserva"))
	if req.get("contrato", false):
		partes.append(Datos.texto("req_corto_contrato"))
	for d in req.get("dominio", {}).keys():
		partes.append("%s N%d" % [Datos.jutsu(d).get("nombre", d), int(req["dominio"][d])])
	return " · ".join(partes) if not partes.is_empty() else Datos.texto("req_ninguno")


# ------------------------------------------------------------------ validación del repertorio

static func _coincide(id: String, sel: Dictionary) -> bool:
	if sel.has("ids") and id in (sel["ids"] as Array):
		return true
	if sel.has("categoria") and str(Datos.jutsu(id).get("categoria", "")) == str(sel["categoria"]):
		return true
	return false


static func equipados(rep: Dictionary) -> Array:
	var r: Array = []
	for a in rep.get("activos", []):
		if str(a) != "":
			r.append(str(a))
	if str(rep.get("modo", "")) != "":
		r.append(str(rep["modo"]))
	return r


static func puntos_usados(rep: Dictionary) -> int:
	var s := 0
	for id in equipados(rep):
		s += puntos(id)
	return s


## Incompatibilidades de `id` con el resto de lo equipado. Devuelve el motivo o "".
static func incompatible(id: String, rep: Dictionary) -> String:
	for regla in conf().get("incompatibles", []):
		var a: Dictionary = regla["a"]
		var b: Dictionary = regla["b"]
		for otro in equipados(rep):
			if otro == id:
				continue
			if (_coincide(id, a) and _coincide(otro, b)) or (_coincide(id, b) and _coincide(otro, a)):
				return str(regla.get("motivo", ""))
	return ""


## Valida un repertorio completo. Con `prueba` (modo prueba) se ignoran requisitos, puntos y maestría.
static func validar(rep: Dictionary, ficha_pj: Dictionary, prueba := false) -> Dictionary:
	var errores: Array = []
	var activos: Array = rep.get("activos", [])
	var modo := str(rep.get("modo", ""))
	var c := conf()
	if activos.size() > int(c.get("ranuras_activas", 4)):
		errores.append(Datos.texto("rep_demasiados"))
	var vistos := {}
	for a in activos:
		var id := str(a)
		if id == "":
			continue
		if not (id in catalogo()):
			errores.append(Datos.texto("rep_desconocido", [id]))
			continue
		if es_modo(id):
			errores.append(Datos.texto("rep_modo_en_activo", [Datos.jutsu(id).get("nombre", id)]))
		if vistos.has(id):
			errores.append(Datos.texto("rep_repetido", [Datos.jutsu(id).get("nombre", id)]))
		vistos[id] = true
	if modo != "" and (not (modo in catalogo()) or not es_modo(modo)):
		errores.append(Datos.texto("rep_modo_invalido"))
	var pts := puntos_usados(rep)
	if not prueba:
		if pts > int(c.get("tope_puntos", 12)):
			errores.append(Datos.texto("rep_puntos", [pts, int(c.get("tope_puntos", 12))]))
		for id in equipados(rep):
			if not (id in catalogo()):
				continue
			var r := requisitos(id, ficha_pj, modo)
			if not r["ok"]:
				errores.append("%s: %s" % [Datos.jutsu(id).get("nombre", id), ", ".join(r["motivos"])])
			var inc := incompatible(id, rep)
			if inc != "":
				errores.append(inc)
	return {"ok": errores.is_empty(), "errores": errores, "puntos": pts}
