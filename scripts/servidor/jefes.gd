class_name Jefes
extends RefCounted
## Jefes (bijuu). El Tres Colas emerge del lago (DISENO.md §4) y pelea en 4 fases según su vida:
##  1 (100-70 %) balas de agua en abanico y olas que barren la orilla (hay que caminar sobre el agua)
##  2 (70-45 %)  se enrolla y rueda en línea recta (línea marcada); al terminar queda aturdido
##  3 (45-20 %)  niebla de alucinaciones: copias falsas (Genjutsu 3+ las ve; Romper genjutsu las disipa)
##  4 (20-0 %)   bomba con cola de bestia: carga 3 s y estalla; esquivar a tiempo o caer
## Al llegar a 0 queda vencido: ventana de sellado (Sellos 3+, secuencia de sellos). Si nadie lo sella, huye.
## Los datos viven en data/personajes.json → tres_colas.jefe.

static var activos: Array = []   # entidades jefe en juego (una por servidor en la práctica)


static func conf(e: EntidadServidor) -> Dictionary:
	return Datos.personaje(e.plantilla_id).get("jefe", {})


static func crear(s: ServidorJuego, id: String, pos: Vector3) -> EntidadServidor:
	var e := s._crear_entidad(id, pos)
	e.equipo = 2
	e.de_mision = true
	var c := conf(e)
	e.radio_golpe = float(c.get("radio_golpe", 6.0))
	e.datos_jefe = {"fase": 1, "t_balas": 2.0, "t_ola": 5.0, "t_rodar": 3.0, "t_bomba": 4.0, "copias": [], "estado": "pelea",
		"lago": Vector3(pos.x, 0, pos.z), "radio_lago": 46.0}
	e.pos.y = s.mapa.nivel_agua()
	e.yaw = PI   # mira hacia la aldea (norte)
	activos.append(e)
	# Durante la pelea el lago alrededor se puede pisar con chakra (y el servidor y el cliente lo saben).
	s.mapa.arena_lago = Vector3(pos.x, pos.z, 46.0)
	s._evento({"tipo": "jefe", "accion": "aparece", "entidad": e.id, "pos": e.pos, "nombre": str(Datos.personaje(id).get("nombre", id)),
		"arena": s.mapa.arena_lago})
	return e


static func derrotado(e: EntidadServidor) -> bool:
	return e == null or not e.vivo() or str(e.datos_jefe.get("estado", "")) in ["sellado", "huyo"]


static func sellado(e: EntidadServidor) -> bool:
	return e != null and str(e.datos_jefe.get("estado", "")) == "sellado"


static func actualizar(s: ServidorJuego, dt: float) -> void:
	for e in activos.duplicate():
		if not (e in s.entidades):
			# Quitado (fin de la misión): se van también sus copias y el lago vuelve a ser intransitable.
			for id in e.datos_jefe.get("copias", []):
				var f := s.entidad(int(id))
				if f != null:
					s.entidades.erase(f)
			e.datos_jefe["copias"] = []
			activos.erase(e)
			if s.mapa != null:
				s.mapa.arena_lago = Vector3.ZERO
			continue
		_pensar(s, e, dt)


static func _pensar(s: ServidorJuego, e: EntidadServidor, dt: float) -> void:
	var d: Dictionary = e.datos_jefe
	var c := conf(e)
	e.empuje = Vector3.ZERO
	match str(d["estado"]):
		"vencido":
			d["t_sellado"] = float(d["t_sellado"]) - dt
			if float(d["t_sellado"]) <= 0.0:
				d["estado"] = "huyo"
				s._evento({"tipo": "jefe", "accion": "huye", "entidad": e.id, "pos": e.pos})
			return
		"sellado", "huyo":
			return
	# Fase según la vida.
	var frac := e.vida / maxf(float(e.stats["vida_max"]), 1.0)
	var umbrales: Array = c.get("fases", [0.7, 0.45, 0.2])
	var fase := 1
	for u in umbrales:
		if frac <= float(u):
			fase += 1
	if fase != int(d["fase"]):
		_cambiar_fase(s, e, int(d["fase"]), fase)
		d["fase"] = fase
	var obj := s._jugador_mas_cercano(e.pos)
	if obj == null:
		return
	if e.estado == "jefe_rodar":
		_rodar(s, e, dt)
		return
	if e.estado == "aturdido" or e.estado == "jefe_bomba":
		if e.estado == "jefe_bomba":
			_bomba(s, e, dt)
		return
	e.yaw = lerp_angle(e.yaw, s._yaw_hacia(e.pos, obj.pos), minf(1.0, dt * 1.5))
	d["t_balas"] = float(d["t_balas"]) - dt
	d["t_ola"] = float(d["t_ola"]) - dt
	d["t_rodar"] = float(d["t_rodar"]) - dt
	d["t_bomba"] = float(d["t_bomba"]) - dt
	if float(d["t_balas"]) <= 0.0:
		d["t_balas"] = float(c.get("cada_balas", 2.4)) * (0.8 if fase >= 3 else 1.0)
		e.accion = {"objetivo": obj.id}
		e.apuntado = {"objetivo": obj.id}
		e.yaw = s._yaw_hacia(e.pos, obj.pos)
		Genericas.salva(s, e, "bala_bijuu", 1, Datos.nivel_jutsu("bala_bijuu", 1))
		s._evento({"tipo": "jefe", "accion": "rugido", "entidad": e.id, "pos": e.pos})
	if fase == 1 and float(d["t_ola"]) <= 0.0:
		d["t_ola"] = float(c.get("cada_ola", 7.0))
		e.apuntado = {"objetivo": obj.id}
		Genericas.area(s, e, "ola_bijuu", 1, Datos.nivel_jutsu("ola_bijuu", 1))
	if fase == 2 and float(d["t_rodar"]) <= 0.0:
		d["t_rodar"] = float(c.get("cada_rodar", 8.0))
		_empezar_rodar(s, e, obj)
	if fase >= 4 and float(d["t_bomba"]) <= 0.0:
		d["t_bomba"] = float(c.get("cada_bomba", 9.0))
		var carga := float(c.get("carga_bomba", 3.0))
		e.poner_estado("jefe_bomba", carga, {"objetivo": obj.id, "punto": obj.pos, "fijado": false})
		s._evento({"tipo": "jefe", "accion": "bomba_carga", "entidad": e.id, "pos": e.pos, "punto": obj.pos, "duracion": carga,
			"radio": float(Datos.nivel_jutsu("bomba_bijuu", 1)["radio"])})


static func _cambiar_fase(s: ServidorJuego, e: EntidadServidor, antes: int, fase: int) -> void:
	var d: Dictionary = e.datos_jefe
	s._evento({"tipo": "jefe", "accion": "fase", "entidad": e.id, "fase": fase, "pos": e.pos})
	if antes == 3:
		_quitar_copias(s, e)
	if fase == 3:
		# Niebla de alucinaciones: copias falsas alrededor (no hacen daño ni se pueden herir).
		var n := int(conf(e).get("copias", 3))
		for i in n:
			var a := TAU * float(i + 1) / float(n + 1)
			var p: Vector3 = d["lago"] + Vector3(cos(a), 0, sin(a)) * 18.0
			var f := s._crear_entidad(e.plantilla_id, p)
			f.equipo = 2
			f.falsa = true
			f.de_mision = true
			f.radio_golpe = e.radio_golpe
			f.pos.y = e.pos.y
			f.invulnerable_t = 9999.0
			(d["copias"] as Array).append(f.id)
		s._evento({"tipo": "jefe", "accion": "niebla", "entidad": e.id, "pos": e.pos, "duracion": 999.0})


static func _quitar_copias(s: ServidorJuego, e: EntidadServidor) -> void:
	var d: Dictionary = e.datos_jefe
	for id in d["copias"]:
		var f := s.entidad(int(id))
		if f != null:
			s.entidades.erase(f)
			s._evento({"tipo": "jefe", "accion": "copia_disipada", "entidad": int(id), "pos": f.pos})
	d["copias"] = []
	s._evento({"tipo": "jefe", "accion": "niebla_fin", "entidad": e.id})


## Romper genjutsu durante la niebla: disipa las copias (lo llama Taijutsu.romper).
static func romper_niebla(s: ServidorJuego, quien: EntidadServidor) -> void:
	for e in activos:
		if not (e.datos_jefe.get("copias", []) as Array).is_empty():
			_quitar_copias(s, e)
			s._evento({"tipo": "mensaje", "entidad": quien.id, "clave": "msg_niebla_rota"})


static func _empezar_rodar(s: ServidorJuego, e: EntidadServidor, obj: EntidadServidor) -> void:
	var dir := obj.pos - e.pos
	dir.y = 0.0
	dir = dir.normalized()
	var largo := e.pos.distance_to(obj.pos) + 14.0
	var hasta := e.pos + dir * largo
	# Telegrafía: línea en el suelo 1,4 s antes de rodar.
	e.poner_estado("jefe_rodar", 1.4 + largo / float(conf(e).get("rodar_velocidad", 26.0)), {"dir": dir, "hasta": hasta, "aviso": 1.4, "golpeados": []})
	s._evento({"tipo": "jefe", "accion": "rodar_aviso", "entidad": e.id, "desde": e.pos, "hasta": hasta, "duracion": 1.4,
		"radio": float(Datos.nivel_jutsu("rodar_bijuu", 1)["radio"])})


static func _rodar(s: ServidorJuego, e: EntidadServidor, dt: float) -> void:
	var a: Dictionary = e.accion
	if float(a["aviso"]) > 0.0:
		a["aviso"] = float(a["aviso"]) - dt
		if float(a["aviso"]) <= 0.0:
			s._evento({"tipo": "jefe", "accion": "rodar", "entidad": e.id})
		return
	var dir: Vector3 = a["dir"]
	e.pos += dir * float(conf(e).get("rodar_velocidad", 26.0)) * dt
	e.pos.y = maxf(s.mapa.altura_suelo(Vector2(e.pos.x, e.pos.z), e.pos.y + 2.0), s.mapa.nivel_agua())
	var nd := Datos.nivel_jutsu("rodar_bijuu", 1)
	var golpeados: Array = a["golpeados"]
	for o in s.entidades:
		if o.tipo == "jugador" and o.vivo() and not (o.id in golpeados) and Vector2(o.pos.x - e.pos.x, o.pos.z - e.pos.z).length() <= float(nd["radio"]):
			golpeados.append(o.id)
			s._aplicar_dano(o, float(nd["dano"]), e, {"jutsu": "rodar_bijuu", "derriba": true, "dir": dir, "empuje": float(nd["empuje"])})
	if e.estado_t <= 0.0 or e.pos.distance_to(a["hasta"]) < 1.0:
		e.poner_estado("aturdido", float(conf(e).get("aturdido_tras_rodar", 3.0)))
		s._evento({"tipo": "jefe", "accion": "aturdido", "entidad": e.id, "pos": e.pos})


static func _bomba(s: ServidorJuego, e: EntidadServidor, dt: float) -> void:
	var a: Dictionary = e.accion
	var obj := s.entidad(int(a["objetivo"]))
	# Sigue al objetivo hasta 1 s antes de disparar; luego el punto queda fijo (ventana para esquivar).
	if e.estado_t > 1.0 and obj != null and obj.vivo():
		a["punto"] = obj.pos
	elif not bool(a["fijado"]):
		a["fijado"] = true
		s._evento({"tipo": "jefe", "accion": "bomba_fija", "entidad": e.id, "punto": a["punto"]})
	if e.estado_t <= 0.05:
		var nd := Datos.nivel_jutsu("bomba_bijuu", 1)
		var p: Vector3 = a["punto"]
		for o in s.entidades:
			if o.tipo == "jugador" and o.vivo() and Vector2(o.pos.x - p.x, o.pos.z - p.z).length() <= float(nd["radio"]):
				var dir := o.pos - p
				dir.y = 0.0
				# Esquivar en el instante justo (invulnerable) salva; si no, casi te mata.
				s._aplicar_dano(o, float(nd["dano"]), e, {"jutsu": "bomba_bijuu", "derriba": true, "dir": dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD,
					"empuje": float(nd["empuje"])})
		s._evento({"tipo": "jefe", "accion": "bomba", "entidad": e.id, "pos": p, "radio": float(nd["radio"])})
		e.poner_estado("libre", 0.0)


## Vida a 0: no muere; queda vencido y se abre la ventana de sellado.
static func al_morir(s: ServidorJuego, e: EntidadServidor) -> bool:
	if not (e in activos) or e.falsa:
		return false
	e.vida = 1.0
	e.poner_estado("aturdido", 999.0)
	_quitar_copias(s, e)
	var c := conf(e)
	e.datos_jefe["estado"] = "vencido"
	e.datos_jefe["t_sellado"] = float(c.get("ventana_sellado", 14.0))
	var n := int(c.get("sellos_secuencia", 5))
	var sec: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = e.id * 31 + s.tick
	for i in n:
		sec.append(rng.randi_range(0, maxi((Datos.mundo.get("sellos", {}) as Dictionary).size() - 1, 0)))
	e.datos_jefe["secuencia"] = sec
	for j in s.entidades:
		if j.tipo == "jugador":
			s._evento({"tipo": "jefe", "accion": "vencido", "entidad": e.id, "para": j.id, "puede_sellar": Atributos.puede_sellar_bijuu(j.attrs),
				"secuencia": sec, "duracion": float(e.datos_jefe["t_sellado"]), "pos": e.pos})
	return true


## Secuencia de sellos que manda el jugador; si coincide (y tiene Sellos 3+), queda sellado.
static func intento_sellado(s: ServidorJuego, j: EntidadServidor, sellos: Array) -> void:
	for e in activos:
		if str(e.datos_jefe.get("estado", "")) != "vencido":
			continue
		if not Atributos.puede_sellar_bijuu(j.attrs):
			s._mensaje(j, "msg_sin_sellado")
			return
		var ok := sellos.size() == (e.datos_jefe["secuencia"] as Array).size()
		if ok:
			for i in sellos.size():
				ok = ok and int(sellos[i]) == int(e.datos_jefe["secuencia"][i])
		if ok:
			e.datos_jefe["estado"] = "sellado"
			s.entrenar(j, "sellos", "sellos_jutsu", 10.0)
			s._evento({"tipo": "jefe", "accion": "sellado", "entidad": e.id, "por": j.id, "pos": e.pos})
		else:
			s._evento({"tipo": "jefe", "accion": "sellado_fallido", "entidad": e.id, "por": j.id})
