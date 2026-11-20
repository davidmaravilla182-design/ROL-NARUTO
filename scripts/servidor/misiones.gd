class_name Misiones
extends RefCounted
## Motor de misiones del servidor (data/misiones.json): capítulos de la historia y eventos dinámicos.
## Una misión es una lista de fases; cada fase tiene un objetivo que el servidor comprueba cada cuadro:
##   escena    diálogo corto (pájaro de papel del líder de la torre); avanza solo o al saltarla
##   duelos    rivales uno tras otro; cada uno se rinde al llegar a su % de vida
##   oleadas   tandas de enemigos; la última suele traer un líder (minijefe)
##   perseguir el objetivo huye por una ruta (techos); hay que derribarlo antes de que llegue al final o se acabe el tiempo
##   defender  aguantar N segundos junto a la puerta mientras llegan oleadas; aparecen capitanes que hay que derrotar
##   jefe      el Tres Colas (Jefes)
## Solo hay una misión activa a la vez (la comparten todos los jugadores de la partida).

var s: ServidorJuego
var activa: Dictionary = {}
var _t_evento := 0.0
var _rng := RandomNumberGenerator.new()
var eventos_activos := false   # solo en la aldea (poblar_aldea); las pruebas de combate no los tienen


func _init(servidor: ServidorJuego) -> void:
	s = servidor
	_rng.seed = 9090
	var iv: Array = conf().get("eventos", {}).get("intervalo", [200, 320])
	_t_evento = _rng.randf_range(float(iv[0]), float(iv[1])) * 0.5


static func conf() -> Dictionary:
	Datos.cargar()
	if not Datos.mundo.has("_misiones"):
		Datos.mundo["_misiones"] = Datos.leer_json("misiones.json")
	return Datos.mundo["_misiones"]


static func capitulo(id: String) -> Dictionary:
	for c in conf().get("capitulos", []):
		if str(c["id"]) == id:
			return c
	return {}


static func indice_capitulo(id: String) -> int:
	var lista: Array = conf().get("capitulos", [])
	for i in lista.size():
		if str(lista[i]["id"]) == id:
			return i
	return -1


func hay_activa() -> bool:
	return not activa.is_empty()


# ------------------------------------------------------------------ inicio

## Empieza un capítulo si el jugador ya lo tiene desbloqueado (su progreso viaja en el personaje).
func empezar_capitulo(e: EntidadServidor, id: String) -> bool:
	if hay_activa():
		return false
	var c := capitulo(id)
	if c.is_empty():
		return false
	var progreso: Dictionary = e.personaje.get("misiones", {}) if typeof(e.personaje.get("misiones")) == TYPE_DICTIONARY else {}
	var siguiente := int(progreso.get("capitulo", 0))
	if indice_capitulo(id) > siguiente and not bool(progreso.get("todo", false)):
		s._mensaje(e, "msg_capitulo_bloqueado")
		return false
	_iniciar({"id": id, "tipo": "capitulo", "titulo": str(c["titulo"]), "fases": c["fases"], "recompensa": c.get("recompensa", {}),
		"prueba": str(c.get("prueba", "")), "dueno": e.id})
	return true


## Evento dinámico (emboscada, alarma, cazarrecompensas) o duelo con el instructor.
func empezar_evento(tipo: String, e: EntidadServidor = null) -> bool:
	if hay_activa():
		return false
	var ev: Dictionary = conf().get("eventos", {}).get(tipo, {})
	if ev.is_empty():
		return false
	var fases: Array = []
	var recompensa: Dictionary = (ev.get("recompensa", {}) as Dictionary).duplicate(true)
	var prueba := ""
	match tipo:
		"emboscada":
			var zonas: Array = ev["zonas"]
			var z: Array = zonas[_rng.randi() % zonas.size()]
			# Inteligencia 4+: se ve en el minimapa unos segundos antes de que salten.
			fases.append({"tipo": "aviso", "pos": z, "duracion": float(ev.get("aviso_previo", 6.0))})
			fases.append({"tipo": "oleadas", "pos": z, "oleadas": [ev["enemigos"]], "objetivo": "Derrota a la emboscada"})
		"alarma":
			var rutas: Array = ev["rutas"]
			var ruta: Array = rutas[_rng.randi() % rutas.size()]
			fases.append({"tipo": "perseguir", "plantilla": str(ev["plantilla"]), "inicio": ruta[0], "ruta": ruta.slice(1),
				"limite": float(ev.get("limite", 75)), "objetivo": "Encuentra y derriba al intruso"})
		"cazarrecompensas":
			var objs: Array = ev["objetivos"]
			var o: Dictionary = objs[_rng.randi() % objs.size()]
			fases.append({"tipo": "oleadas", "pos": o["pos"], "oleadas": [[{"plantilla": o["plantilla"], "n": 1, "jefe": true, "nombre": o["nombre"]}]],
				"objetivo": "Derrota a %s" % str(o["nombre"])})
			for k in ["pergaminos", "cosmeticos"]:
				if o.has(k):
					recompensa[k] = o[k]
		"duelo_instructor":
			var rival: Dictionary = (ev["rival"] as Dictionary).duplicate()
			# Si el jugador ya tiene la experiencia para ascender y su prueba es un duelo, este es el duelo de ascenso.
			if e != null and not e.personaje.is_empty():
				var asc := Creacion.ascenso(e.personaje)
				if bool(asc["listo_xp"]) and str(asc["prueba"]).begins_with("duelo"):
					prueba = str(asc["prueba"])
					rival["vida_extra"] = 2.0
					rival["rendicion"] = 0.15
			fases.append({"tipo": "duelos", "pos": ev["pos"], "rivales": [rival], "objetivo": "Vence al instructor"})
	_iniciar({"id": tipo, "tipo": "evento", "titulo": str(ev.get("titulo", tipo)), "fases": fases, "recompensa": recompensa,
		"prueba": prueba, "dueno": e.id if e != null else -1})
	s._evento({"tipo": "anuncio", "titulo": str(ev.get("titulo", tipo)), "para_todos": true})
	return true


func _iniciar(m: Dictionary) -> void:
	activa = m
	activa["fase"] = -1
	activa["ent"] = []
	s._evento({"tipo": "mision", "accion": "inicio", "id": m["id"], "titulo": m["titulo"], "tipo_mision": m["tipo"]})
	_siguiente_fase()


# ------------------------------------------------------------------ fases

func _siguiente_fase() -> void:
	_limpiar_entidades()
	activa["fase"] = int(activa["fase"]) + 1
	var fases: Array = activa["fases"]
	if int(activa["fase"]) >= fases.size():
		terminar(true)
		return
	var f: Dictionary = fases[int(activa["fase"])]
	activa["t"] = 0.0
	activa["datos"] = {}
	var d: Dictionary = activa["datos"]
	match str(f["tipo"]):
		"escena":
			var lineas: Array = f.get("lineas", [])
			d["duracion"] = 1.2 + lineas.size() * 3.4
			s._evento({"tipo": "escena", "lineas": lineas, "pajaro": bool(f.get("pajaro", false)), "duracion": d["duracion"]})
		"aviso":
			var p := _v3(f["pos"])
			for j in _jugadores():
				if Atributos.ve_emboscadas(j.attrs):
					s._evento({"tipo": "emboscada_aviso", "entidad": j.id, "pos": p, "duracion": float(f.get("duracion", 6.0))})
		"duelos":
			d["rival_i"] = 0
			_nuevo_rival(f)
		"oleadas":
			d["oleada"] = 0
			_llevar_jugadores(_v3(f["pos"]), 13.0)
			_nueva_oleada(f)
		"perseguir":
			_llevar_jugadores(_v3(f["inicio"]), 14.0)
			var e := _crear(str(f["plantilla"]), _v3(f["inicio"]), {})
			var ruta: Array = []
			for p in f["ruta"]:
				ruta.append(_v3(p))
			if e.ia != null:
				e.ia.ruta = ruta
				e.ia.ruta_i = 0
			d["presa"] = e.id
			d["limite"] = float(f.get("limite", 90.0))
		"defender":
			_llevar_jugadores(_v3(f["pos"]), 6.0)
			d["limite"] = float(f.get("duracion", 120.0))
			d["oleada_t"] = 0.0
			d["capitanes"] = false
		"jefe":
			var b := Jefes.crear(s, str(f["jefe"]), _v3(f["pos"]))
			_llevar_jugadores(_v3(f["pos"]), s.mapa.arena_lago.z + 5.0 if s.mapa.arena_lago.z > 0.0 else 25.0)
			activa["ent"].append(b.id)
			d["jefe"] = b.id
	_avisar_objetivo()


## Si el jugador está lejos de donde ocurre la fase (p. ej. empezó desde el menú en la plaza), el pájaro lo lleva:
## humo, y aparece a «distancia» metros de la zona, del lado por donde venía y mirándola.
func _llevar_jugadores(zona: Vector3, distancia: float) -> void:
	for j in _jugadores():
		if not j.vivo():
			continue
		var v: Vector3 = j.pos - zona
		v.y = 0.0
		if v.length() <= distancia + 15.0:
			continue
		var dir: Vector3 = v.normalized() if v.length() > 0.1 else Vector3(0, 0, 1)
		var p2 := s.mapa.resolver_colision(Vector2(zona.x + dir.x * distancia, zona.z + dir.z * distancia), Datos.sim("radio_entidad"), 0.0)
		s._evento({"tipo": "humo", "entidad": j.id, "pos": j.pos})
		j.pos = Vector3(p2.x, s.mapa.altura_suelo(p2, 0.0), p2.y)
		j.empuje = Vector3.ZERO
		j.vel_y = 0.0
		j.yaw = atan2(-dir.x, -dir.z)
		s._evento({"tipo": "humo", "entidad": j.id, "pos": j.pos})
		s._evento({"tipo": "mensaje", "entidad": j.id, "clave": "msg_mision_llevado"})


func _avisar_objetivo() -> void:
	var f: Dictionary = (activa["fases"] as Array)[int(activa["fase"])]
	var d: Dictionary = activa["datos"]
	s._evento({"tipo": "mision", "accion": "objetivo", "id": activa["id"], "titulo": activa["titulo"], "objetivo": str(f.get("objetivo", "")),
		"limite": float(d.get("limite", 0.0)), "t": float(activa.get("t", 0.0)), "contador": _contador(), "fase": str(f["tipo"]),
		"pos": f.get("pos", f.get("inicio", [])) })


func _contador() -> String:
	var f: Dictionary = (activa["fases"] as Array)[int(activa["fase"])]
	var d: Dictionary = activa["datos"]
	match str(f["tipo"]):
		"duelos":
			return "%d / %d" % [int(d.get("rival_i", 0)) + 1, (f["rivales"] as Array).size()]
		"oleadas":
			return "Oleada %d / %d · quedan %d enemigos" % [int(d.get("oleada", 0)) + 1, (f["oleadas"] as Array).size(), _vivos().size()]
		"defender":
			return "Quedan %d s" % int(maxf(float(d.get("limite", 0.0)) - float(activa.get("t", 0.0)), 0.0))
	return ""


func actualizar(dt: float) -> void:
	if not hay_activa():
		_eventos_dinamicos(dt)
		return
	activa["t"] = float(activa["t"]) + dt
	var f: Dictionary = (activa["fases"] as Array)[int(activa["fase"])]
	var d: Dictionary = activa["datos"]
	# Si caen todos los jugadores, la misión fracasa.
	var vivos_j := _jugadores().filter(func(j): return j.vivo())
	if vivos_j.is_empty() and str(f["tipo"]) != "escena":
		terminar(false)
		return
	match str(f["tipo"]):
		"escena":
			if float(activa["t"]) >= float(d["duracion"]):
				_siguiente_fase()
		"aviso":
			if float(activa["t"]) >= float(f.get("duracion", 6.0)):
				_siguiente_fase()
		"duelos":
			var r := s.entidad(int(d.get("rival", -1)))
			if r == null:
				return
			var rend := float(d.get("rendicion", 0.3))
			if not r.vivo() or r.vida <= float(r.stats["vida_max"]) * rend:
				# Se rinde: queda quieto y deja de pelear.
				r.ia = null
				r.invulnerable_t = 99.0
				s._evento({"tipo": "rendicion", "entidad": r.id, "pos": r.centro()})
				d["rival_i"] = int(d["rival_i"]) + 1
				if int(d["rival_i"]) >= (f["rivales"] as Array).size():
					_siguiente_fase()
				else:
					_respiro()
					_nuevo_rival(f)
					_avisar_objetivo()
		"oleadas":
			if _vivos().is_empty():
				d["oleada"] = int(d["oleada"]) + 1
				if int(d["oleada"]) >= (f["oleadas"] as Array).size():
					_siguiente_fase()
				else:
					_respiro()
					_nueva_oleada(f)
					_avisar_objetivo()
		"perseguir":
			var p := s.entidad(int(d["presa"]))
			if p == null or not p.vivo():
				_siguiente_fase()
				return
			var escapa := p.ia != null and int(p.ia.ruta_i) >= (p.ia.ruta as Array).size()
			if escapa or float(activa["t"]) >= float(d["limite"]):
				s._evento({"tipo": "anuncio", "titulo": "El intruso escapó", "para_todos": true})
				terminar(false)
		"defender":
			d["oleada_t"] = float(d["oleada_t"]) - dt
			# Los soldados dejan de llegar cuando aparecen los capitanes (el final es contra ellos).
			if d["oleada_t"] <= 0.0 and float(activa["t"]) < float(d["limite"]) - 10.0 and not bool(d["capitanes"]):
				d["oleada_t"] = float(f.get("oleada_cada", 18.0))
				for g in f.get("por_oleada", []):
					for i in int(g["n"]):
						_crear(str(g["plantilla"]), _v3(f["origen"]) + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-3, 3)), g)
			if not bool(d["capitanes"]) and float(activa["t"]) >= float(f.get("capitanes_en", 60.0)):
				d["capitanes"] = true
				s._evento({"tipo": "anuncio", "titulo": "¡Llegan los capitanes rebeldes!", "para_todos": true})
				_respiro()
				for g in f.get("capitanes", []):
					for i in int(g["n"]):
						var c := _crear(str(g["plantilla"]), _v3(f["origen"]) + Vector3(i * 4.0 - 2.0, 0, 0), g)
						d["cap_%d" % c.id] = true
			var quedan_cap := 0
			for k in d.keys():
				if str(k).begins_with("cap_"):
					var ce := s.entidad(int(str(k).substr(4)))
					if ce != null and ce.vivo():
						quedan_cap += 1
			if float(activa["t"]) >= float(d["limite"]) and bool(d["capitanes"]) and quedan_cap == 0:
				_siguiente_fase()
		"jefe":
			var b := s.entidad(int(d["jefe"]))
			if b == null or not b.vivo() or Jefes.derrotado(b):
				activa["sellado"] = Jefes.sellado(b)
				_siguiente_fase()
	# Contador del HUD cada medio segundo.
	d["aviso_t"] = float(d.get("aviso_t", 0.0)) - dt
	if float(d["aviso_t"]) <= 0.0 and hay_activa():
		d["aviso_t"] = 0.5
		_avisar_objetivo()


## Respiro entre oleadas y entre duelos: recupera parte de la vida y el chakra.
func _respiro(frac := -1.0) -> void:
	var rf := frac if frac >= 0.0 else float(Datos.reglas.get("ia_cuerpo_a_cuerpo", {}).get("respiro_oleada", 0.0))
	for j in _jugadores():
		if j.vivo() and rf > 0.0:
			j.vida = minf(j.vida + float(j.stats["vida_max"]) * rf, float(j.stats["vida_max"]))
			j.chakra = minf(j.chakra + float(j.stats["chakra_max"]) * rf, float(j.stats["chakra_max"]))
			s._evento({"tipo": "mensaje", "entidad": j.id, "clave": "msg_respiro"})


func terminar(exito: bool) -> void:
	if not hay_activa():
		return
	var recompensa: Dictionary = (activa.get("recompensa", {}) as Dictionary).duplicate(true) if exito else {}
	if exito and bool(activa.get("sellado", false)) and recompensa.has("sellado_extra"):
		var extra: Dictionary = recompensa["sellado_extra"]
		recompensa["ryo"] = int(recompensa.get("ryo", 0)) + int(extra.get("ryo", 0))
		recompensa["cosmeticos"] = (recompensa.get("cosmeticos", []) as Array) + (extra.get("cosmeticos", []) as Array)
	recompensa.erase("sellado_extra")
	if exito:
		for j in _jugadores():
			s.ganar_experiencia(j, float(recompensa.get("xp", 0)), "mision")
	s._evento({"tipo": "mision", "accion": "fin", "id": activa["id"], "tipo_mision": activa["tipo"], "titulo": activa["titulo"], "exito": exito,
		"recompensa": recompensa, "prueba": str(activa.get("prueba", "")) if exito else "", "sellado": bool(activa.get("sellado", false))})
	_limpiar_entidades()
	activa = {}


func abandonar() -> void:
	terminar(false)


# ------------------------------------------------------------------ utilidades

func _jugadores() -> Array:
	return s.entidades.filter(func(x): return x.tipo == "jugador")


func _vivos() -> Array:
	var r: Array = []
	for id in activa.get("ent", []):
		var e := s.entidad(int(id))
		if e != null and e.vivo() and e.tipo != "jefe":
			r.append(e)
	return r


func _v3(p: Variant) -> Vector3:
	var a: Array = p
	var v2 := Vector2(float(a[0]), float(a[1]))
	return Vector3(v2.x, s.mapa.altura_suelo(v2, 0.0), v2.y)


func _crear(plantilla: String, pos: Vector3, g: Dictionary) -> EntidadServidor:
	var p2 := s.mapa.resolver_colision(Vector2(pos.x, pos.z), Datos.sim("radio_entidad"), 0.0)
	var e := s._crear_entidad(plantilla, Vector3(p2.x, s.mapa.altura_suelo(p2, 0.0), p2.y))
	e.equipo = 2
	e.ia = IaEnemigo.new(e)
	e.ia.conf["aggro"] = maxf(float(e.ia.conf.get("aggro", 30.0)), 60.0)   # el que huye también pelea si lo acorralan
	e.ia.t_reaccion = 1.0
	e.de_mision = true
	if g.has("nombre"):
		e.nombre = str(g["nombre"])
	if float(g.get("vida_extra", 1.0)) != 1.0:
		e.stats["vida_max"] = float(e.stats["vida_max"]) * float(g["vida_extra"])
		e.vida = float(e.stats["vida_max"])
	if bool(g.get("jefe", false)):
		e.minijefe = true
	activa["ent"].append(e.id)
	s._evento({"tipo": "aparece", "entidad": e.id, "pos": e.pos, "minijefe": bool(g.get("jefe", false)), "nombre": e.nombre})
	return e


func _nuevo_rival(f: Dictionary) -> void:
	var d: Dictionary = activa["datos"]
	var rv: Dictionary = (f["rivales"] as Array)[int(d["rival_i"])]
	var centro := _v3(f["pos"])
	var r := _crear(str(rv["plantilla"]), centro + Vector3(0, 0, -5), rv)
	r.minijefe = true
	d["rival"] = r.id
	d["rendicion"] = float(rv.get("rendicion", 0.3))
	# El jugador (dueño) se coloca frente al rival.
	for j in _jugadores():
		if j.vivo():
			j.pos = centro + Vector3(0, 0, 5)
			j.yaw = PI


func _nueva_oleada(f: Dictionary) -> void:
	var d: Dictionary = activa["datos"]
	var ol: Array = (f["oleadas"] as Array)[int(d["oleada"])]
	var n_ol := (f["oleadas"] as Array).size()
	if n_ol > 1:
		var con_jefe := ol.any(func(g): return bool(g.get("jefe", false)))
		var titulo := "¡Oleada %d de %d!" % [int(d["oleada"]) + 1, n_ol]
		if con_jefe:
			titulo = "¡Última oleada: llega el líder!"
		s._evento({"tipo": "anuncio", "titulo": titulo, "para_todos": true})
	var centro := _v3(f["pos"])
	# Aparecen en abanico del lado opuesto al jugador y tardan unos segundos en atacar (tiempo para prepararse).
	var lejos_de := centro + Vector3(0, 0, 10)
	var js := _jugadores()
	if not js.is_empty():
		lejos_de = (js[0] as EntidadServidor).pos
	var hacia := centro - lejos_de
	hacia.y = 0.0
	var base := atan2(hacia.z, hacia.x) if hacia.length() > 0.1 else 0.0
	var total := 0
	for g in ol:
		total += int(g.get("n", 1))
	var gracia := float(Datos.reglas.get("ia_cuerpo_a_cuerpo", {}).get("gracia_oleada", 2.5))
	var k := 0
	for g in ol:
		for i in int(g.get("n", 1)):
			var a := base + (float(k) - (total - 1) * 0.5) * 0.45
			var e := _crear(str(g["plantilla"]), centro + Vector3(cos(a), 0, sin(a)) * 8.0, g)
			if e.ia != null:
				e.ia.t_reaccion = gracia + k * 0.4
			k += 1


func _limpiar_entidades() -> void:
	for id in activa.get("ent", []):
		var e := s.entidad(int(id))
		if e != null:
			e.ia = null   # rompe el ciclo entidad ↔ IA (si no, quedan en memoria)
			s.entidades.erase(e)
			s._evento({"tipo": "quitar", "entidad": int(id)})
	if hay_activa():
		activa["ent"] = []


func _eventos_dinamicos(dt: float) -> void:
	if not eventos_activos or _jugadores().is_empty():
		return
	_t_evento -= dt
	if _t_evento > 0.0:
		return
	var iv: Array = conf().get("eventos", {}).get("intervalo", [200, 320])
	_t_evento = _rng.randf_range(float(iv[0]), float(iv[1]))
	var tipos := ["emboscada", "alarma", "cazarrecompensas"]
	empezar_evento(tipos[_rng.randi() % tipos.size()], _jugadores()[0])
