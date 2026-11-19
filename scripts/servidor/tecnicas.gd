class_name Tecnicas
extends RefCounted
## Mecánicas de servidor del repertorio (autoritativas): modos (oculares y Ocho Puertas),
## efectos de estado (ardiendo, susanoo, vulnerable, armadura negra, puertas), zonas de daño
## en el suelo y los jutsus del primer bloque (Kirin, Amaterasu, Susanoo, Shinra Tensei).
## El embiste (embiste de rayo, esfera) y los proyectiles siguen en ServidorJuego.

const OJOS := ["sharingan", "mangekyo", "rinnegan", "byakugan"]


# ------------------------------------------------------------------ modos

static func alternar_modo(s: ServidorJuego, e: EntidadServidor) -> void:
	var id := e.modo
	if id == "" or not e.vivo() or e.recarga(id) > 0.0:
		return
	var j := Datos.jutsu(id)
	var nivel := s.nivel_de(e, id)
	var nd := Datos.nivel_jutsu(id, nivel)
	if e.modo_activo:
		apagar_modo(s, e)
	else:
		var costo := Combate.costo_chakra(id, nivel, e.attrs)
		if e.chakra < costo:
			s._mensaje(e, "msg_sin_chakra")
			return
		if j.get("mecanica", "") == "ocho_puertas":
			var costo_vida := float(e.stats["vida_max"]) * float(nd.get("costo_vida_pct", 0.1))
			if e.vida <= costo_vida + 1.0:
				s._mensaje(e, "msg_sin_vida")
				return
			e.vida -= costo_vida
			e.efectos["puertas"] = {"t": INF, "nivel": nivel}
		e.chakra -= costo
		e.modo_activo = true
		e.modo_nivel = nivel
		s.ganar_xp(e, id, float(Datos.reglas["maestria"]["xp_uso"]))
		s._evento({"tipo": "modo", "entidad": e.id, "modo": id, "activo": true, "nivel": nivel})
	e.sharingan = e.modo_activo and (e.modo == "sharingan" or e.modo == "mangekyo")
	e.recargas[id] = float(j.get("recarga", 1.0)) * Atributos.mult_recarga(e.attrs)


static func apagar_modo(s: ServidorJuego, e: EntidadServidor) -> void:
	if not e.modo_activo:
		return
	e.modo_activo = false
	e.sharingan = false
	e.efectos.erase("puertas")
	s._evento({"tipo": "modo", "entidad": e.id, "modo": e.modo, "activo": false})


## Ralentización de proyectiles hacia `e` según su modo ocular (1.0 = ninguna).
static func ralentizacion(e: EntidadServidor) -> float:
	if not e.modo_activo or not (e.modo in OJOS):
		return 1.0
	return float(Datos.nivel_jutsu(e.modo, e.modo_nivel).get("ralentiza_proyectiles", 1.0))


static func multiplicador_velocidad(e: EntidadServidor) -> float:
	var m := Genericas.mult_velocidad(e)
	if e.efectos.has("puertas"):
		m *= float(Datos.nivel_jutsu("ocho_puertas", int(e.efectos["puertas"]["nivel"])).get("vel_mult", 1.0))
	return m


static func multiplicador_taijutsu(e: EntidadServidor) -> float:
	if e.efectos.has("puertas"):
		return float(Datos.nivel_jutsu("ocho_puertas", int(e.efectos["puertas"]["nivel"])).get("taijutsu_mult", 1.0))
	return 1.0


## Multiplicador del daño recibido por `o` (Susanoo reduce, vulnerable aumenta).
static func multiplicador_recibido(o: EntidadServidor) -> float:
	var m := 1.0
	if o.efectos.has("susanoo"):
		m *= 1.0 - float(Datos.nivel_jutsu("susanoo", int(o.efectos["susanoo"]["nivel"])).get("reduccion", 0.5))
	if o.efectos.has("vulnerable"):
		m *= float(Datos.reglas["estados"].get("vulnerable_dano", 1.3))
	return m * Genericas.mult_recibido(o)


# ------------------------------------------------------------------ actualización por tick

static func actualizar_entidad(s: ServidorJuego, e: EntidadServidor, dt: float) -> void:
	if not e.vivo():
		e.efectos.clear()
		return
	# Modos: gasto por segundo y maestría por tiempo activo.
	if e.modo_activo:
		var nd := Datos.nivel_jutsu(e.modo, e.modo_nivel)
		if e.modo in OJOS:
			e.chakra -= float(nd.get("costo_por_segundo", 3.0)) * maxf(1.0 - Combate.control(e.attrs) * Datos.formula("ahorro_por_control"), 0.1) * dt
			if e.chakra <= 0.0:
				e.chakra = 0.0
				apagar_modo(s, e)
		elif e.modo == "modo_sabio":
			e.chakra -= float(nd.get("costo_por_segundo", 2.0)) * dt
			if e.chakra <= 0.0:
				e.chakra = 0.0
				apagar_modo(s, e)
		elif e.modo == "ocho_puertas":
			e.vida = maxf(e.vida - float(nd.get("drena_vida", 2.0)) * dt, 1.0)
		e.xp_modo_acum += float(Datos.reglas["maestria"]["xp_modo_por_segundo"]) * dt
		if e.xp_modo_acum >= 5.0:
			s.ganar_xp(e, e.modo, e.xp_modo_acum)
			e.xp_modo_acum = 0.0
	for k in e.efectos.keys():
		var ef: Dictionary = e.efectos[k]
		ef["t"] = float(ef["t"]) - dt
		match k:
			"ardiendo":
				ef["acum"] = float(ef.get("acum", 0.0)) + dt
				if float(ef["acum"]) >= 0.5:
					ef["acum"] = 0.0
					var fuente := s.entidad(int(ef.get("fuente", -1)))
					s._aplicar_dano(e, float(ef["dps"]) * 0.5, fuente, {"jutsu": "amaterasu", "naturaleza": "", "dot": true, "nivel": int(ef["nivel"])})
					# N2+: las llamas se propagan a lo que tocan.
					var radio := float(Datos.nivel_jutsu("amaterasu", int(ef["nivel"])).get("propaga_radio", 0.0))
					if radio > 0.0:
						for o in s.entidades:
							if o != e and o.vivo() and not o.efectos.has("ardiendo") and (fuente == null or o != fuente) \
									and o.pos.distance_to(e.pos) <= radio:
								encender(s, o, fuente, int(ef["nivel"]), float(ef["t"]) * 0.8)
			"susanoo":
				_tick_susanoo(s, e, ef, dt)
			"armadura_negra":
				var nd2 := Datos.nivel_jutsu("amaterasu", int(ef["nivel"]))
				for o in s.entidades:
					if o != e and o.vivo() and o.equipo != e.equipo and not o.efectos.has("ardiendo") \
							and o.pos.distance_to(e.pos) <= float(nd2.get("armadura_radio", 2.4)):
						encender(s, o, e, int(ef["nivel"]), float(nd2.get("duracion", 5.0)))
		if float(ef["t"]) <= 0.0 and e.efectos.has(k):
			e.efectos.erase(k)
			s._evento({"tipo": "fin_efecto", "entidad": e.id, "efecto": k})


static func actualizar_zonas(s: ServidorJuego, dt: float) -> void:
	var quitar: Array = []
	for z in s.zonas:
		z["t"] = float(z["t"]) - dt
		z["acum"] = float(z.get("acum", 0.0)) + dt
		if float(z["acum"]) >= 0.5:
			z["acum"] = 0.0
			var dueno := s.entidad(int(z["dueno"]))
			for o in s.entidades:
				if not o.vivo() or (dueno != null and o == dueno):
					continue
				if Vector2(o.pos.x, o.pos.z).distance_to(Vector2(z["pos"].x, z["pos"].z)) <= float(z["radio"]):
					if z["jutsu"] == "amaterasu":
						if not o.efectos.has("ardiendo"):
							encender(s, o, dueno, int(z["nivel"]), float(Datos.nivel_jutsu("amaterasu", int(z["nivel"])).get("duracion", 5.0)))
					else:
						s._aplicar_dano(o, float(z["dps"]) * 0.5, dueno, {"jutsu": z["jutsu"], "naturaleza": z.get("naturaleza", ""), "dot": true, "nivel": int(z["nivel"])})
		if float(z["t"]) <= 0.0:
			quitar.append(z)
	for z in quitar:
		s.zonas.erase(z)


static func crear_zona(s: ServidorJuego, pos: Vector3, radio: float, duracion: float, dps: float, jutsu: String, nivel: int, dueno: int, naturaleza := "") -> void:
	s.zonas.append({"id": s.nuevo_id(), "pos": Vector3(pos.x, 0, pos.z), "radio": radio, "t": duracion, "total": duracion, "dps": dps,
		"jutsu": jutsu, "nivel": nivel, "dueno": dueno, "naturaleza": naturaleza})


# ------------------------------------------------------------------ Kirin

static func preparar_kirin(s: ServidorJuego, e: EntidadServidor, nivel: int) -> void:
	var nd := Datos.nivel_jutsu("kirin", nivel)
	var j := Datos.jutsu("kirin")
	var obj := s._resolver_objetivo(e, float(j.get("alcance", 30.0)))
	var punto := e.pos + Vector3(sin(float(e.accion.get("yaw_apuntado", e.yaw))), 0, cos(float(e.accion.get("yaw_apuntado", e.yaw)))) * 12.0
	if obj != null:
		punto = obj.pos
		e.yaw = s._yaw_hacia(e.pos, obj.pos)
	var golpes := int(nd.get("golpes", 1))
	var intervalo := float(nd.get("intervalo", 0.0))
	var carga := float(nd.get("carga", 0.35))
	e.poner_estado("kirin", carga + golpes * intervalo + 0.5, {"jutsu": "kirin", "nivel": nivel, "punto": punto,
		"objetivo": obj.id if obj != null else -1, "quedan": golpes, "siguiente": carga, "intervalo": maxf(intervalo, 0.01)})
	s._evento({"tipo": "kirin_invocar", "entidad": e.id, "nivel": nivel, "punto": punto, "carga": carga,
		"objetivo": obj.id if obj != null else -1})


static func tick_kirin(s: ServidorJuego, e: EntidadServidor, dt: float) -> void:
	e.accion["siguiente"] = float(e.accion["siguiente"]) - dt
	if int(e.accion["quedan"]) > 0 and float(e.accion["siguiente"]) <= 0.0:
		var nivel := int(e.accion["nivel"])
		var nd := Datos.nivel_jutsu("kirin", nivel)
		var punto: Vector3 = e.accion["punto"]
		var obj := s.entidad(int(e.accion.get("objetivo", -1)))
		if obj != null and obj.vivo():
			punto = obj.pos   # la tormenta sigue al objetivo
		var disp := float(nd.get("dispersion", 0.0))
		if disp > 0.0 and int(e.accion["quedan"]) < int(nd.get("golpes", 1)):
			punto += Vector3(s.rng.randf_range(-disp, disp), 0, s.rng.randf_range(-disp, disp))
		golpe_kirin(s, e, punto, nivel)
		e.accion["quedan"] = int(e.accion["quedan"]) - 1
		e.accion["siguiente"] = float(e.accion["intervalo"])
	if e.estado_t <= 0.0:
		e.poner_estado("libre", 0.0)


static func golpe_kirin(s: ServidorJuego, e: EntidadServidor, punto: Vector3, nivel: int) -> void:
	var nd := Datos.nivel_jutsu("kirin", nivel)
	var radio := float(nd.get("radio", 3.0))
	for o in s.entidades:
		if o == e or not o.vivo():
			continue
		var d := Vector2(o.pos.x - punto.x, o.pos.z - punto.z).length()
		if d > radio + Datos.sim("radio_cuerpo"):
			continue
		var caida := clampf(1.2 - d / radio * 0.5, 0.6, 1.0)
		var dano := Combate.dano_jutsu("kirin", nivel, e.attrs, o.naturaleza_principal(), s.clima) * caida
		var dir := (o.pos - punto)
		dir.y = 0
		s._aplicar_dano(o, dano, e, {"jutsu": "kirin", "naturaleza": "rayo", "derriba": true, "dir": dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD, "empuje": 6.0, "nivel": nivel})
	s._evento({"tipo": "kirin", "entidad": e.id, "nivel": nivel, "pos": Vector3(punto.x, 0, punto.z), "radio": radio, "bestia": bool(nd.get("bestia", false))})


# ------------------------------------------------------------------ Amaterasu

static func lanzar_amaterasu(s: ServidorJuego, e: EntidadServidor, nivel: int) -> void:
	var nd := Datos.nivel_jutsu("amaterasu", nivel)
	var j := Datos.jutsu("amaterasu")
	var obj := s._resolver_objetivo(e, float(j.get("alcance", 22.0)))
	var punto: Vector3
	if obj != null:
		e.yaw = s._yaw_hacia(e.pos, obj.pos)
		encender(s, obj, e, nivel, float(nd.get("duracion", 5.0)))
		punto = obj.pos
	else:
		var yaw := float(e.accion.get("yaw_apuntado", e.yaw))
		punto = e.pos + Vector3(sin(yaw), 0, cos(yaw)) * 9.0
	crear_zona(s, punto, float(nd.get("zona_radio", 1.4)), float(nd.get("duracion", 5.0)), float(nd.get("dano", 8.0)), "amaterasu", nivel, e.id)
	if float(nd.get("armadura", 0.0)) > 0.0:
		e.efectos["armadura_negra"] = {"t": float(nd["armadura"]), "nivel": nivel}
	e.ceguera = minf(e.ceguera + float(nd.get("ceguera", 0.1)), 1.0)
	s._evento({"tipo": "amaterasu", "entidad": e.id, "nivel": nivel, "pos": punto, "objetivo": obj.id if obj != null else -1, "ceguera": e.ceguera})
	e.poner_estado("lanzar", 0.3, {"jutsu": "amaterasu", "nivel": nivel})


static func encender(s: ServidorJuego, o: EntidadServidor, fuente: EntidadServidor, nivel: int, duracion: float) -> void:
	if not o.vivo():
		return
	var nd := Datos.nivel_jutsu("amaterasu", nivel)
	var dps := float(nd.get("dano", 8.0))
	if fuente != null:
		dps *= 1.0 + float(fuente.attrs.get("ninjutsu", 0)) * Datos.formula("dano_por_ninjutsu")
	o.efectos["ardiendo"] = {"t": duracion, "nivel": nivel, "dps": dps, "fuente": fuente.id if fuente != null else -1}
	s._evento({"tipo": "ardiendo", "entidad": o.id, "nivel": nivel})


# ------------------------------------------------------------------ Susanoo

static func alternar_susanoo(s: ServidorJuego, e: EntidadServidor, nivel: int) -> void:
	var nd := Datos.nivel_jutsu("susanoo", nivel)
	e.efectos["susanoo"] = {"t": float(nd.get("duracion", 8.0)), "nivel": nivel, "flecha": 0.6, "espada": 1.0}
	s._evento({"tipo": "susanoo", "entidad": e.id, "nivel": nivel, "activo": true})
	e.poner_estado("lanzar", 0.4, {"jutsu": "susanoo", "nivel": nivel})


static func _tick_susanoo(s: ServidorJuego, e: EntidadServidor, ef: Dictionary, dt: float) -> void:
	var nivel := int(ef["nivel"])
	var nd := Datos.nivel_jutsu("susanoo", nivel)
	e.chakra -= float(nd.get("drena_chakra", 3.0)) * dt
	e.vida = maxf(e.vida - float(nd.get("drena_vida", 1.0)) * dt, 1.0)
	if e.chakra <= 0.0 or (e.modo != "mangekyo" or not e.modo_activo):
		e.chakra = maxf(e.chakra, 0.0)
		ef["t"] = 0.0
		return
	if float(nd.get("flecha_cada", 0.0)) > 0.0:
		ef["flecha"] = float(ef["flecha"]) - dt
		# Anticipación: tensa el arco un instante antes de disparar.
		if float(ef["flecha"]) <= 0.35 and not ef.get("tensado", false) and s._buscar_objetivo(e, e.yaw, 180.0, 28.0) != null:
			ef["tensado"] = true
			s._evento({"tipo": "susanoo_tensa", "entidad": e.id, "nivel": nivel, "tiempo": maxf(float(ef["flecha"]), 0.05)})
		if float(ef["flecha"]) <= 0.0:
			ef["tensado"] = false
			var obj := s._buscar_objetivo(e, e.yaw, 180.0, 28.0)
			if obj != null:
				ef["flecha"] = float(nd["flecha_cada"])
				var antes := e.yaw
				e.yaw = s._yaw_hacia(e.pos, obj.pos)
				e.accion["objetivo"] = obj.id
				s._disparar_proyectil(e, "flecha_susanoo", nivel)
				e.yaw = antes
	if float(nd.get("espada_cada", 0.0)) > 0.0:
		ef["espada"] = float(ef["espada"]) - dt
		var radio_a := float(nd.get("espada_radio", 4.5))
		# Anticipación: alza la espada si hay alguien a su alcance.
		if float(ef["espada"]) <= 0.3 and not ef.get("alzada", false):
			for o in s.entidades:
				if o != e and o.vivo() and o.equipo != e.equipo and o.pos.distance_to(e.pos) <= radio_a + 0.6:
					ef["alzada"] = true
					s._evento({"tipo": "susanoo_alza", "entidad": e.id, "nivel": nivel, "tiempo": maxf(float(ef["espada"]), 0.05)})
					break
		if float(ef["espada"]) <= 0.0:
			ef["alzada"] = false
			var radio := float(nd.get("espada_radio", 4.5))
			var hubo := false
			for o in s.entidades:
				if o != e and o.vivo() and o.equipo != e.equipo and o.pos.distance_to(e.pos) <= radio + 0.6:
					hubo = true
					var d := o.pos - e.pos
					d.y = 0
					s._aplicar_dano(o, Combate.dano_jutsu("susanoo", nivel, e.attrs, o.naturaleza_principal(), s.clima), e,
						{"jutsu": "susanoo", "naturaleza": "", "derriba": true, "dir": d.normalized() if d.length() > 0.01 else e.adelante(), "empuje": 8.0, "nivel": nivel})
			if hubo:
				ef["espada"] = float(nd["espada_cada"])
				s._evento({"tipo": "susanoo_espada", "entidad": e.id, "nivel": nivel, "pos": e.pos, "radio": radio})


# ------------------------------------------------------------------ Shinra Tensei

static func shinra(s: ServidorJuego, e: EntidadServidor, nivel: int) -> void:
	var nd := Datos.nivel_jutsu("shinra_tensei", nivel)
	var radio := float(nd.get("radio", 5.0))
	for o in s.entidades:
		if o == e or not o.vivo():
			continue
		var d := o.pos - e.pos
		d.y = 0
		if d.length() > radio + Datos.sim("radio_cuerpo"):
			continue
		var dir := d.normalized() if d.length() > 0.01 else e.adelante()
		var caida := clampf(1.2 - d.length() / radio * 0.6, 0.6, 1.0)
		s._aplicar_dano(o, Combate.dano_jutsu("shinra_tensei", nivel, e.attrs, o.naturaleza_principal(), s.clima) * caida, e,
			{"jutsu": "shinra_tensei", "naturaleza": "", "derriba": true, "dir": dir, "empuje": float(nd.get("empuje", 10.0)) * caida, "nivel": nivel})
	# También repele proyectiles.
	var quitar: Array = []
	for p in s.proyectiles:
		if int(p["dueno"]) != e.id and (p["pos"] as Vector3).distance_to(e.centro()) <= radio:
			quitar.append(p)
	for p in quitar:
		s.proyectiles.erase(p)
		s._evento({"tipo": "explosion", "jutsu": p["jutsu"], "nivel": p["nivel"], "pos": p["pos"], "suelo": Vector3(p["pos"].x, 0, p["pos"].z), "radio": 0.5, "proyectil": p["id"], "escala": 1.0})
	e.efectos["vulnerable"] = {"t": float(Datos.jutsu("shinra_tensei").get("vulnerable", 5.0)), "nivel": nivel}
	s._evento({"tipo": "shinra", "entidad": e.id, "nivel": nivel, "pos": e.pos, "radio": radio, "crater": float(nd.get("crater", 0.0))})
	e.poner_estado("lanzar", 0.45, {"jutsu": "shinra_tensei", "nivel": nivel})


# ------------------------------------------------------------------ Ocho Puertas: golpe definitivo

## Devuelve true si el golpe se convirtió en el golpe definitivo (N3).
static func golpe_definitivo(s: ServidorJuego, e: EntidadServidor) -> bool:
	if not e.efectos.has("puertas"):
		return false
	var nivel := int(e.efectos["puertas"]["nivel"])
	var nd := Datos.nivel_jutsu("ocho_puertas", nivel)
	if not nd.get("golpe_definitivo", false):
		return false
	var radio := float(nd.get("definitivo_radio", 5.0))
	for o in s.entidades:
		if o == e or not o.vivo() or o.pos.distance_to(e.pos) > radio + 0.6:
			continue
		var d := o.pos - e.pos
		d.y = 0
		s._aplicar_dano(o, float(nd.get("dano", 200.0)) * (1.0 + float(e.attrs.get("taijutsu", 0)) * 0.1), e,
			{"jutsu": "ocho_puertas", "naturaleza": "", "derriba": true, "dir": d.normalized() if d.length() > 0.01 else e.adelante(), "empuje": 22.0, "nivel": nivel})
	e.vida = maxf(float(e.stats["vida_max"]) * 0.05, 1.0)
	s._evento({"tipo": "golpe_definitivo", "entidad": e.id, "nivel": nivel, "pos": e.pos, "radio": radio})
	apagar_modo(s, e)
	e.recargas["ocho_puertas"] = 10.0
	return true
