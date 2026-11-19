class_name Taijutsu
extends RefCounted
## Técnicas de taijutsu con secuencia (mecánica "tai" en data/jutsus.json):
##  - loto:        lanza al rival, salta, lo atrapa en el aire y caen en barrena (golpe enorme al suelo)
##  - loto_oculto: lanza al rival, ráfaga de golpes en el aire y remate contra el suelo
##  - liger:       atrapa, salta y estrella al rival contra el suelo
##  - lariat:      embestida en línea con el brazo cubierto de rayo
##  - entrada:     patada voladora desde lejos que interrumpe el ataque del rival
## La cinemática la fija el servidor cuadro a cuadro (atacante y rival), así es igual para todos los clientes.

const INTERRUMPIBLES := ["sellos", "chidori_carga", "chidori_embiste", "golpe", "lanzar", "rafaga", "kirin", "tai"]


static func ejecutar(s: ServidorJuego, e: EntidadServidor, id: String, nivel: int, nd: Dictionary) -> void:
	var sec := str(nd.get("secuencia", ""))
	var alcance := float(Datos.jutsu(id).get("alcance", 4.0))
	var obj := s._resolver_objetivo(e, alcance + 1.0)
	if float(nd.get("costo_vida_pct", 0.0)) > 0.0:
		e.vida = maxf(e.vida - float(e.stats["vida_max"]) * float(nd["costo_vida_pct"]), 1.0)
	match sec:
		"lariat":
			var dir := e.adelante()
			if obj != null:
				dir = obj.pos - e.pos
				dir.y = 0.0
				dir = dir.normalized()
				e.yaw = atan2(dir.x, dir.z)
			var dur := float(nd.get("distancia", 10.0)) / maxf(float(nd.get("velocidad", 30.0)), 1.0)
			e.poner_estado("tai", dur, {"jutsu": id, "nivel": nivel, "sec": sec, "dir": dir, "golpeados": []})
		"entrada":
			if obj == null:
				e.poner_estado("libre", 0.0)
				return
			e.yaw = s._yaw_hacia(e.pos, obj.pos)
			e.poner_estado("tai", 0.38, {"jutsu": id, "nivel": nivel, "sec": sec, "objetivo": obj.id, "desde": e.pos, "golpeado": false})
		_:
			# Lotos y Liger Bomb: hay que tener al rival a mano (avance rápido de hasta el alcance).
			if obj == null or obj.pos.distance_to(e.pos) > alcance + 3.0:
				e.poner_estado("libre", 0.0)
				s._mensaje(e, "msg_sin_objetivo")
				return
			if obj.pos.distance_to(e.pos) > 1.6:
				Genericas._acercar(s, e, obj, id, nivel, 1.2)   # paso rápido hasta el rival
			var dur2 := {"loto": 1.05, "loto_oculto": 0.5 + int(nd.get("golpes", 4)) * 0.09 + 0.45, "liger": 0.75}.get(sec, 1.0) as float
			e.yaw = s._yaw_hacia(e.pos, obj.pos)
			var suelo := e.pos.y
			obj.poner_estado("atrapado_tai", dur2 + 0.3, {"jutsu": id, "nivel": nivel})
			obj.empuje = Vector3.ZERO
			e.poner_estado("tai", dur2, {"jutsu": id, "nivel": nivel, "sec": sec, "objetivo": obj.id, "suelo": suelo,
				"base": Vector3(e.pos.x, suelo, e.pos.z), "frente": e.adelante(), "golpes_hechos": 0, "impacto": false})
	s._evento({"tipo": "tai", "fase": "inicio", "entidad": e.id, "jutsu": id, "nivel": nivel, "sec": sec,
		"objetivo": obj.id if obj != null else -1, "pos": e.pos})


## Cuadro a cuadro del estado "tai" del atacante.
static func actualizar(s: ServidorJuego, e: EntidadServidor, dt: float) -> void:
	var a: Dictionary = e.accion
	var id := str(a["jutsu"])
	var nivel := int(a["nivel"])
	var nd := Datos.nivel_jutsu(id, nivel)
	var sec := str(a["sec"])
	var t := e.estado_total - e.estado_t
	match sec:
		"lariat":
			var dir: Vector3 = a["dir"]
			var vel := float(nd.get("velocidad", 30.0))
			var dest := e.pos + dir * vel * dt
			var p2 := s.mapa.resolver_colision(Vector2(dest.x, dest.z), Datos.sim("radio_entidad"), e.pos.y)
			e.pos = Vector3(p2.x, e.pos.y, p2.y)
			var golpeados: Array = a["golpeados"]
			for o in s.entidades:
				if o == e or not o.vivo() or o.equipo == e.equipo or o.id in golpeados:
					continue
				if o.pos.distance_to(e.pos) <= 1.6:
					golpeados.append(o.id)
					_golpear(s, e, o, id, nivel, nd, float(nd["dano"]), dir, true)
					s._evento({"tipo": "tai", "fase": "impacto", "entidad": e.id, "jutsu": id, "nivel": nivel, "sec": sec, "pos": o.centro()})
					if not bool(nd.get("perfora", false)):
						e.poner_estado("recuperacion", 0.3)
						return
			if e.estado_t <= 0.0:
				e.poner_estado("recuperacion", 0.25)
		"entrada":
			var o := s.entidad(int(a["objetivo"]))
			var desde: Vector3 = a["desde"]
			var u := clampf(t / 0.38, 0.0, 1.0)
			if o != null and o.vivo():
				var hasta := o.pos - (o.pos - desde).normalized() * 0.9
				e.pos = desde.lerp(hasta, u) + Vector3(0, sin(u * PI) * 1.6, 0)
				e.yaw = s._yaw_hacia(e.pos, o.pos)
				if u >= 1.0 and not bool(a["golpeado"]):
					a["golpeado"] = true
					# Interrumpe lo que estuviera haciendo (sellos, carga, golpe...).
					if o.estado in INTERRUMPIBLES:
						o.poner_estado("aturdido", float(nd.get("interrumpe", 0.6)))
						s._evento({"tipo": "interrumpido", "entidad": o.id, "atacante": e.id, "pos": o.centro()})
					_golpear(s, e, o, id, nivel, nd, float(nd["dano"]), e.adelante(), bool(nd.get("derriba", false)))
					s._evento({"tipo": "tai", "fase": "impacto", "entidad": e.id, "jutsu": id, "nivel": nivel, "sec": sec, "pos": o.centro()})
			if e.estado_t <= 0.0:
				e.pos.y = s.mapa.altura_suelo(Vector2(e.pos.x, e.pos.z), e.pos.y + 0.5)
				e.poner_estado("recuperacion", 0.2)
		_:
			_aereo(s, e, a, id, nivel, nd, sec, t)


## Lotos y Liger Bomb: subir con el rival, (golpes en el aire), caer en barrena y estrellarlo.
static func _aereo(s: ServidorJuego, e: EntidadServidor, a: Dictionary, id: String, nivel: int, nd: Dictionary, sec: String, t: float) -> void:
	var o := s.entidad(int(a["objetivo"]))
	if o == null or not o.vivo():
		e.pos.y = float(a["suelo"])
		e.poner_estado("libre", 0.0)
		return
	var base: Vector3 = a["base"]
	var frente: Vector3 = a["frente"]
	var alto := float(nd.get("altura", 6.0))
	var subida := {"loto": 0.5, "loto_oculto": 0.45, "liger": 0.42}.get(sec, 0.5) as float
	var golpes := int(nd.get("golpes", 0))
	var aire := golpes * 0.09 if sec == "loto_oculto" else (0.12 if sec == "loto" else 0.0)
	var caida := e.estado_total - subida - aire
	var y := 0.0
	if t < subida:
		y = alto * sin(t / subida * PI * 0.5)
	elif t < subida + aire:
		y = alto
		# Ráfaga en el aire (Loto Oculto).
		var k := int((t - subida) / 0.09)
		if sec == "loto_oculto" and k > int(a["golpes_hechos"]) - 1 and int(a["golpes_hechos"]) < golpes:
			a["golpes_hechos"] = int(a["golpes_hechos"]) + 1
			_golpear(s, e, o, id, nivel, nd, float(nd["dano"]), frente, false, true)
			s._evento({"tipo": "tai", "fase": "aire", "entidad": e.id, "jutsu": id, "nivel": nivel, "sec": sec, "pos": o.centro()})
	else:
		var u := clampf((t - subida - aire) / maxf(caida, 0.05), 0.0, 1.0)
		y = alto * (1.0 - u * u)
	var suelo := float(a["suelo"])
	e.pos = Vector3(base.x, suelo + y, base.z)
	o.pos = e.pos + frente * 0.7 + Vector3(0, 0.3, 0)
	o.vel_y = 0.0
	o.en_suelo = false
	e.vel_y = 0.0
	if e.estado_t <= 0.0 and not bool(a["impacto"]):
		a["impacto"] = true
		e.pos.y = suelo
		o.pos.y = suelo
		o.en_suelo = true
		var dano := float(nd.get("remate", nd["dano"])) if sec == "loto_oculto" else float(nd["dano"])
		o.poner_estado("libre", 0.0)
		_golpear(s, e, o, id, nivel, nd, dano, frente, true)
		# El impacto alcanza también a los de alrededor.
		var radio := float(nd.get("radio_impacto", 2.0))
		for x in s.entidades:
			if x != e and x != o and x.vivo() and x.equipo != e.equipo and x.pos.distance_to(o.pos) <= radio:
				_golpear(s, e, x, id, nivel, nd, dano * 0.4, (x.pos - o.pos).normalized(), true)
		s._evento({"tipo": "estrellar", "entidad": o.id, "pos": Vector3(o.pos.x, suelo, o.pos.z)})
		s._evento({"tipo": "tai", "fase": "impacto", "entidad": e.id, "jutsu": id, "nivel": nivel, "sec": sec, "pos": o.centro(),
			"radio": radio})
		e.poner_estado("recuperacion", 0.35)


static func _golpear(s: ServidorJuego, e: EntidadServidor, o: EntidadServidor, id: String, nivel: int, nd: Dictionary, base: float,
		dir: Vector3, derriba: bool, ligero := false) -> void:
	var dano := base * Atributos.mult_dano_taijutsu(e.attrs) * Tecnicas.multiplicador_taijutsu(e)
	s._aplicar_dano(o, dano, e, {"jutsu": id, "naturaleza": "", "derriba": derriba and not ligero, "dir": dir,
		"empuje": 0.5 if ligero else float(nd.get("empuje", 8.0)), "nivel": nivel, "fuerte": not ligero})
	s.entrenar(e, "taijutsu", "taijutsu_golpe")


## Romper genjutsu: libera de cualquier genjutsu (control de un jutsu genjutsu, ceguera, miedo, niebla del rebelde),
## da inmunidad un rato y en N3 devuelve el genjutsu a quien lo lanzó.
static func romper(s: ServidorJuego, e: EntidadServidor, id: String, nivel: int, nd: Dictionary) -> void:
	var fuente := -1
	var habia := false
	for k in ["ciego", "miedo", "genjutsu_npc", "control"]:
		if e.efectos.has(k):
			var ef: Dictionary = e.efectos[k]
			if k == "control" and str(Datos.jutsu(str(ef.get("jutsu", ""))).get("clase", "")) != "genjutsu":
				continue
			fuente = int(ef.get("fuente", fuente))
			e.efectos.erase(k)
			habia = true
	if e.estado in ["atrapado", "aturdido", "dormido"] and str(Datos.jutsu(str(e.accion.get("jutsu", ""))).get("clase", "")) == "genjutsu":
		habia = true
	e.poner_estado("libre", 0.0)
	e.efectos["inmune_genjutsu"] = {"t": float(nd.get("inmune", 2.0)), "nivel": nivel}
	if float(nd.get("devuelve", 0.0)) > 0.0 and fuente >= 0:
		var f := s.entidad(fuente)
		if f != null and f.vivo():
			Genericas._controlar(s, f, "aturdido", float(nd["devuelve"]), id, nivel)
	s.entrenar(e, "genjutsu", "genjutsu_resistido", 2.0 if habia else 0.5)
	s._evento({"tipo": "genjutsu_roto", "entidad": e.id, "nivel": nivel, "habia": habia, "pos": e.centro()})
