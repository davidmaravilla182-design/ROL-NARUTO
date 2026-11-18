class_name Creacion
extends RefCounted
## Reglas de la creación de personaje (data/creacion.json + reglas.json → rangos y progresión).
## Las usan el cliente (pantalla de creación, menú del repertorio) y el servidor (valida lo que le llega).
##
## Un personaje (pj) es un Dictionary serializable:
##   {nombre, aldea, clan, naturalezas[], atributos{8 + "_balance"}, rango,
##    aspecto{peinado, pelo, ojos, piel, complexion, ropa}, id}


static func conf() -> Dictionary:
	Datos.cargar()
	return Datos.creacion


static func clanes() -> Dictionary:
	return conf().get("clanes", {})


static func clan(id: String) -> Dictionary:
	return clanes().get(id, {})


static func rangos() -> Array:
	Datos.cargar()
	return Datos.reglas.get("rangos", [])


static func indice_rango(r: String) -> int:
	return rangos().find(r)


## Personaje nuevo con valores por defecto válidos.
static func nuevo() -> Dictionary:
	var c := conf()
	var attrs: Dictionary = (c.get("atributos_iniciales", {}) as Dictionary).duplicate()
	attrs["_balance"] = 0.0
	return {
		"id": "", "nombre": "", "aldea": "lluvia", "clan": "sin_clan", "naturalezas": ["agua"],
		"atributos": attrs, "rango": str(c.get("rango_inicial", "genin")),
		"aspecto": {"peinado": "puntas", "pelo": str(c["colores_pelo"][0]), "ojos": str(c["colores_ojos"][0]),
			"piel": str(c["tonos_piel"][1]), "complexion": "media", "ropa": "chaleco"},
	}


## Tope de puntos de atributo del personaje (el clan puede sumar).
static func tope_puntos(pj: Dictionary) -> int:
	return int(Datos.reglas["atributos"]["tope_total"]) + int(clan(str(pj.get("clan", ""))).get("puntos_extra", 0))


static func total_puntos(attrs: Dictionary) -> int:
	var t := 0
	for a in Datos.reglas["atributos"]["lista"]:
		t += int(attrs.get(a, 0))
	return t


## Naturalezas efectivas: las fijas del linaje, o la innata (+ la segunda desde Chūnin).
static func naturalezas(pj: Dictionary) -> Array:
	var cl := clan(str(pj.get("clan", "")))
	if cl.has("naturalezas_fijas"):
		return (cl["naturalezas_fijas"] as Array).duplicate()
	var elegidas: Array = pj.get("naturalezas", [])
	var n := 1
	var segunda := str(conf().get("naturalezas", {}).get("segunda_en_rango", "chunin"))
	if indice_rango(str(pj.get("rango", "genin"))) >= indice_rango(segunda):
		n = 2
	return elegidas.slice(0, n)


## ¿Puede elegir la segunda naturaleza ya? (Chūnin o más, y sin naturalezas fijas de linaje)
static func segunda_disponible(pj: Dictionary) -> bool:
	if clan(str(pj.get("clan", ""))).has("naturalezas_fijas"):
		return false
	var segunda := str(conf().get("naturalezas", {}).get("segunda_en_rango", "chunin"))
	return indice_rango(str(pj.get("rango", "genin"))) >= indice_rango(segunda)


## Linajes del clan, más los que se despiertan por rango (p. ej. Mangekyō en Jōnin).
static func linajes(pj: Dictionary) -> Array:
	var cl := clan(str(pj.get("clan", "")))
	var r: Array = (cl.get("linajes", []) as Array).duplicate()
	var por_rango: Dictionary = cl.get("linajes_por_rango", {})
	var mi := indice_rango(str(pj.get("rango", "genin")))
	for rg in por_rango.keys():
		if mi >= indice_rango(str(rg)):
			for l in por_rango[rg]:
				if not (l in r):
					r.append(l)
	return r


## Ficha para las reglas del repertorio (requisitos, validación).
static func ficha(pj: Dictionary, maestria: Dictionary = {}) -> Dictionary:
	return {"attrs": pj.get("atributos", {}), "naturalezas": naturalezas(pj), "linajes": linajes(pj), "contratos": [],
		"rango": str(pj.get("rango", "genin")), "maestria": maestria}


## Estadísticas con los modificadores del clan.
static func estadisticas(pj: Dictionary) -> Dictionary:
	var s := Combate.estadisticas(pj.get("atributos", {}))
	var mods: Dictionary = clan(str(pj.get("clan", ""))).get("modificadores", {})
	for k in mods.keys():
		if s.has(k):
			s[k] = float(s[k]) * float(mods[k])
	return s


## Aspecto completo para dibujar: preset de ropa + colores, peinado y complexión elegidos.
static func aspecto_visual(pj: Dictionary) -> Dictionary:
	var a: Dictionary = pj.get("aspecto", {})
	var c := conf()
	var ropa: Dictionary = c.get("ropas", {}).get(str(a.get("ropa", "chaleco")), {}).get("aspecto", {})
	var r: Dictionary = ropa.duplicate()
	r["piel"] = str(a.get("piel", "#f1cfae"))
	r["pelo"] = str(a.get("pelo", "#1a1f2e"))
	r["ojos"] = str(a.get("ojos", "#151212"))
	r["peinado"] = str(a.get("peinado", "puntas"))
	var comp: Dictionary = c.get("complexiones", {}).get(str(a.get("complexion", "media")), {})
	r["escala"] = [float(comp.get("ancho", 1.0)), float(comp.get("alto", 1.0))]
	return r


static func _color_valido(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING and Color.html_is_valid(str(v))


## Valida y sanea un personaje que llega del cliente. Devuelve {ok, errores, pj}.
static func validar(datos: Variant) -> Dictionary:
	var errores: Array = []
	if typeof(datos) != TYPE_DICTIONARY:
		return {"ok": false, "errores": ["Personaje no válido"], "pj": {}}
	var d: Dictionary = datos
	var c := conf()
	var pj := nuevo()
	var nombre := str(d.get("nombre", "")).strip_edges().left(int(c["nombre"]["max"]))
	if nombre.length() < int(c["nombre"]["min"]):
		errores.append("Nombre muy corto")
	pj["nombre"] = nombre
	pj["id"] = str(d.get("id", "")).left(40)
	var aldea := str(d.get("aldea", "lluvia"))
	if not bool(c["aldeas"].get(aldea, {}).get("disponible", false)):
		errores.append("Aldea no disponible")
	pj["aldea"] = aldea
	var cl := str(d.get("clan", "sin_clan"))
	if not clanes().has(cl):
		errores.append("Clan desconocido")
		cl = "sin_clan"
	pj["clan"] = cl
	var rango := str(d.get("rango", c.get("rango_inicial", "genin")))
	if indice_rango(rango) < 0:
		errores.append("Rango desconocido")
		rango = str(c.get("rango_inicial", "genin"))
	pj["rango"] = rango
	var nats: Array = []
	var opciones: Array = c["naturalezas"]["opciones"]
	if typeof(d.get("naturalezas")) == TYPE_ARRAY:
		for n in d["naturalezas"]:
			if str(n) in opciones and not (str(n) in nats):
				nats.append(str(n))
	if clan(cl).has("naturalezas_fijas"):
		nats = (clan(cl)["naturalezas_fijas"] as Array).duplicate()
	elif nats.is_empty():
		errores.append("Falta la naturaleza innata")
		nats = ["agua"]
	pj["naturalezas"] = nats.slice(0, 2)
	var attrs := {}
	var origen: Dictionary = d.get("atributos", {}) if typeof(d.get("atributos")) == TYPE_DICTIONARY else {}
	for a in Datos.reglas["atributos"]["lista"]:
		attrs[a] = clampi(int(origen.get(a, 0)), int(Datos.reglas["atributos"]["minimo"]), int(Datos.reglas["atributos"]["maximo"]))
	var bal: Dictionary = c.get("balance_chakra", {})
	attrs["_balance"] = clampf(float(origen.get("_balance", 0.0)), float(bal.get("min", -1.0)), float(bal.get("max", 1.0)))
	if total_puntos(attrs) > tope_puntos(pj):
		errores.append("Atributos: %d de %d puntos" % [total_puntos(attrs), tope_puntos(pj)])
	pj["atributos"] = attrs
	var a_in: Dictionary = d.get("aspecto", {}) if typeof(d.get("aspecto")) == TYPE_DICTIONARY else {}
	var asp: Dictionary = pj["aspecto"]
	if c["peinados"].has(str(a_in.get("peinado", ""))):
		asp["peinado"] = str(a_in["peinado"])
	for k in ["pelo", "ojos", "piel"]:
		if _color_valido(a_in.get(k)):
			asp[k] = str(a_in[k])
	if c["complexiones"].has(str(a_in.get("complexion", ""))):
		asp["complexion"] = str(a_in["complexion"])
	if c["ropas"].has(str(a_in.get("ropa", ""))):
		asp["ropa"] = str(a_in["ropa"])
	return {"ok": errores.is_empty(), "errores": errores, "pj": pj}


## Repertorio inicial: hasta 3 jutsus que el personaje ya puede usar (los más baratos primero).
static func repertorio_inicial(pj: Dictionary) -> Dictionary:
	var f := ficha(pj)
	var lista: Array = []
	var modo := ""
	for id in Repertorio.catalogo():
		if not Repertorio.implementado(id):
			continue
		var r := Repertorio.requisitos(id, f, id if Repertorio.es_modo(id) else "")
		if not r["ok"]:
			continue
		if Repertorio.es_modo(id):
			if modo == "":
				modo = id
		else:
			lista.append(id)
	lista.sort_custom(func(a, b): return Repertorio.puntos(a) < Repertorio.puntos(b))
	var activos: Array = []
	var puntos := Repertorio.puntos(modo) if modo != "" else 0
	for id in lista:
		if activos.size() >= 3:
			break
		if puntos + Repertorio.puntos(id) <= int(Repertorio.conf().get("tope_puntos", 12)):
			activos.append(id)
			puntos += Repertorio.puntos(id)
	while activos.size() < int(Repertorio.conf().get("ranuras_activas", 4)):
		activos.append("")
	return {"activos": activos, "modo": modo, "niveles_max": {}}


## En línea, los clanes raros se asignan por probabilidad según su rareza (en offline se eligen).
static func sortear_clan(rng: RandomNumberGenerator) -> String:
	var rarezas: Dictionary = conf().get("rarezas", {})
	var total := 0.0
	for k in rarezas.keys():
		total += float(rarezas[k].get("peso_online", 0))
	var tirada := rng.randf() * total
	var elegida := ""
	for k in rarezas.keys():
		tirada -= float(rarezas[k].get("peso_online", 0))
		if tirada <= 0.0:
			elegida = k
			break
	var candidatos: Array = []
	for id in clanes().keys():
		if str(clanes()[id].get("rareza", "")) == elegida:
			candidatos.append(id)
	if candidatos.is_empty():
		return "sin_clan"
	return str(candidatos[rng.randi() % candidatos.size()])


static func naturaleza_al_azar(rng: RandomNumberGenerator) -> String:
	var op: Array = conf()["naturalezas"]["opciones"]
	return str(op[rng.randi() % op.size()])
