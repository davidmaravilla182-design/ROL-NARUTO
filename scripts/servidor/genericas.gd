class_name Genericas
extends RefCounted
## Mecánicas genéricas del repertorio, configuradas solo con datos (data/jutsus.json, por nivel):
##  - salva:    uno o varios proyectiles (abanico, intervalo, teledirigidos, perforantes, rastreros, que tragan jutsus)
##  - area:     golpe en un área (propia, al frente en cono, o sobre el objetivo), con retardo, varios golpes,
##              atrapar, aturdir, atraer, quitar chakra y dejar una zona en el suelo
##  - aura:     efecto sobre uno mismo (velocidad, daño, reducción, curación, intangible, repeler, daño por contacto, planear)
##  - invocar:  criaturas aliadas temporales que persiguen y golpean (golem, clones, criatura, golem de lava)
##  - teleport: desplazamiento instantáneo detrás del objetivo, en cadena, con golpe al llegar
## Un jutsu puede cambiar de mecánica según el nivel ("mecanica" dentro de cada nivel).


## Mecánica efectiva de un jutsu en un nivel.
static func mecanica(id: String, nivel: int) -> String:
	return str(Datos.nivel_jutsu(id, nivel).get("mecanica", ""))


static func ejecutar(s: ServidorJuego, e: EntidadServidor, id: String, nivel: int) -> void:
	var nd := Datos.nivel_jutsu(id, nivel)
	match str(nd.get("mecanica", "")):
		"salva":
			salva(s, e, id, nivel, nd)
			e.poner_estado("lanzar", 0.35, {"jutsu": id, "nivel": nivel})
		"area":
			area(s, e, id, nivel, nd)
			e.poner_estado("lanzar", 0.3, {"jutsu": id, "nivel": nivel})
		"aura":
			aura(s, e, id, nivel, nd)
			e.poner_estado("libre", 0.0)
		"invocar":
			invocar(s, e, id, nivel, nd)
			e.poner_estado("lanzar", 0.4, {"jutsu": id, "nivel": nivel})
		"teleport":
			teletransporte(s, e, id, nivel, nd)
		_:
			e.poner_estado("libre", 0.0)


static func _color(id: String) -> String:
	return str(Datos.jutsu(id).get("color", "#ffffff"))


static func _enemigos(s: ServidorJuego, e: EntidadServidor) -> Array:
	var lista: Array = []
	for o in s.entidades:
		if o != e and o.vivo() and o.equipo != e.equipo:
			lista.append(o)
	return lista


## Punto objetivo: el rival resuelto (fijado / asistencia) o un punto al frente.
static func _punto_objetivo(s: ServidorJuego, e: EntidadServidor, alcance: float) -> Dictionary:
	var obj := s._resolver_objetivo(e, alcance)
	if obj != null:
		e.yaw = s._yaw_hacia(e.pos, obj.pos)
		return {"pos": Vector3(obj.pos.x, 0, obj.pos.z), "objetivo": obj}
	e.yaw = float(e.accion.get("yaw_apuntado", e.yaw))
	var p := e.pos + e.adelante() * minf(alcance * 0.5, 8.0)
	return {"pos": Vector3(p.x, 0, p.z), "objetivo": null}


# ======================================================================== salva

static func salva(s: ServidorJuego, e: EntidadServidor, id: String, nivel: int, nd: Dictionary) -> void:
	var j := Datos.jutsu(id)
	var alcance := float(j.get("alcance", 22.0))
	var escala := Combate.escala_tamano(id, e.attrs, s.clima)
	var res := _punto_objetivo(s, e, alcance)
	var obj: EntidadServidor = res["objetivo"]
	var n := int(nd.get("cantidad", 1))
	var abanico := deg_to_rad(float(nd.get("abanico", 0.0)))
	var radio := float(nd.get("radio", 0.4)) * escala
	var rastrero := bool(nd.get("rastrero", false))
	# Objetivos distintos (la lanza que se ramifica): reparte entre los rivales más cercanos.
	var rivales: Array = []
	if bool(nd.get("objetivos_distintos", false)):
		rivales = _enemigos(s, e)
		rivales.sort_custom(func(a, b): return a.pos.distance_to(e.pos) < b.pos.distance_to(e.pos))
	for i in n:
		var t := 0.0 if n == 1 else float(i) / float(n - 1) - 0.5
		var yaw := e.yaw + t * abanico
		var dir := Vector3(sin(yaw), 0, cos(yaw))
		var alto := radio if rastrero else 1.3 + radio * 0.5
		var origen := e.pos + Vector3(0, alto, 0) + dir * (0.7 + radio)
		var mi_obj := obj
		if not rivales.is_empty():
			mi_obj = rivales[i % rivales.size()]
		if mi_obj != null and n == 1 and not rastrero:
			var hacia := mi_obj.centro() - origen
			if radio > 0.8:
				hacia.y = 0.0
			dir = hacia.normalized()
		var p := {
			"id": s.nuevo_id(), "jutsu": id, "nivel": nivel, "dueno": e.id, "equipo": e.equipo,
			"objetivo": mi_obj.id if mi_obj != null else -1,
			"pos": origen, "dir": dir, "velocidad": float(nd.get("velocidad", 18.0)), "radio": radio,
			"radio_explosion": float(nd.get("radio_explosion", 1.0)) * escala, "recorrido": 0.0, "alcance": alcance,
			"escala": escala, "generico": true, "forma": str(nd.get("forma", "bola")), "color": _color(id),
			"espera": float(nd.get("intervalo", 0.0)) * i, "teledirigido": float(nd.get("teledirigido", 0.0)),
			"perfora": bool(nd.get("perfora", false)), "rastrero": rastrero, "traga": bool(nd.get("traga", false)),
			"golpeados": [],
		}
		s.proyectiles.append(p)
		s._evento({"tipo": "lanzar", "entidad": e.id, "jutsu": id, "nivel": nivel, "proyectil": p["id"], "pos": origen, "dir": dir,
			"radio": radio, "forma": p["forma"], "indice": i})


## Avance especial de los proyectiles genéricos (espera, guiado, rastreros). Devuelve false si aún no se mueve.
static func mover_proyectil(s: ServidorJuego, p: Dictionary, dt: float) -> bool:
	if float(p.get("espera", 0.0)) > 0.0:
		p["espera"] = float(p["espera"]) - dt
		var dueno := s.entidad(int(p["dueno"]))
		if dueno != null:
			p["pos"] = dueno.pos + Vector3(0, 1.3, 0) + Vector3(p["dir"]) * 0.8
		return false
	var giro := float(p.get("teledirigido", 0.0))
	if giro > 0.0:
		var obj := s.entidad(int(p["objetivo"]))
		if obj == null or not obj.vivo():
			obj = _rival_cercano(s, p)
			if obj != null:
				p["objetivo"] = obj.id
		if obj != null:
			var deseada: Vector3 = (obj.centro() - Vector3(p["pos"])).normalized()
			if bool(p.get("rastrero", false)):
				deseada.y = 0.0
				deseada = deseada.normalized()
			var dir: Vector3 = p["dir"]
			p["dir"] = dir.slerp(deseada, clampf(giro * dt, 0.0, 1.0)).normalized()
	return true


static func _rival_cercano(s: ServidorJuego, p: Dictionary) -> EntidadServidor:
	var mejor: EntidadServidor = null
	var md := 18.0
	for o in s.entidades:
		if o.id == int(p["dueno"]) or not o.vivo() or o.equipo == int(p.get("equipo", -99)):
			continue
		var d := o.pos.distance_to(p["pos"])
		if d < md:
			md = d
			mejor = o
	return mejor


## Tiburón gigante: se traga los proyectiles rivales que toca.
static func tragar(s: ServidorJuego, p: Dictionary) -> void:
	for q in s.proyectiles.duplicate():
		if q == p or int(q["dueno"]) == int(p["dueno"]):
			continue
		if Vector3(q["pos"]).distance_to(p["pos"]) <= float(p["radio"]) + float(q["radio"]):
			s.proyectiles.erase(q)
			s._evento({"tipo": "tragado", "pos": q["pos"], "proyectil": q["id"]})


## Impacto de un proyectil genérico (o un golpe perforante, con `final` = false).
static func impacto_proyectil(s: ServidorJuego, p: Dictionary, directo: EntidadServidor, final := true) -> void:
	var id := str(p["jutsu"])
	var nivel := int(p["nivel"])
	var nd := Datos.nivel_jutsu(id, nivel)
	var dueno := s.entidad(int(p["dueno"]))
	var pos: Vector3 = p["pos"]
	var r := float(p["radio_explosion"]) if final else float(p["radio"])
	for o in s.entidades:
		if not o.vivo() or (dueno != null and (o == dueno or o.equipo == dueno.equipo)):
			continue
		if o.id in p["golpeados"]:
			continue
		var d := o.centro().distance_to(pos)
		if o != directo and d > r + Datos.sim("radio_cuerpo"):
			continue
		p["golpeados"].append(o.id)
		var caida := 1.0 if o == directo else clampf(1.0 - d / (r + 0.6) * 0.5, 0.5, 1.0)
		var dir: Vector3 = o.pos - pos
		dir.y = 0
		golpear(s, dueno, o, id, nivel, nd, caida, dir.normalized() if dir.length() > 0.01 else Vector3(p["dir"]))
	if final:
		var suelo := Vector3(pos.x, 0, pos.z)
		_zona(s, dueno, id, nivel, nd, suelo)
		s._evento({"tipo": "explosion", "jutsu": id, "nivel": nivel, "pos": pos, "suelo": suelo, "radio": r, "proyectil": p["id"],
			"escala": p["escala"], "forma": p["forma"], "color": p["color"]})


# ======================================================================== daño común

## Aplica daño y efectos de control de un jutsu genérico a `o`.
static func golpear(s: ServidorJuego, atacante: EntidadServidor, o: EntidadServidor, id: String, nivel: int, nd: Dictionary,
		factor := 1.0, dir := Vector3.ZERO) -> void:
	var attrs: Dictionary = atacante.attrs if atacante != null else {}
	var dano := Combate.dano_jutsu(id, nivel, attrs, o.naturaleza_principal(), s.clima) * factor
	var nat := str(Datos.jutsu(id).get("naturaleza", ""))
	if dano > 0.0:
		s._aplicar_dano(o, dano, atacante, {"jutsu": id, "naturaleza": nat, "derriba": bool(nd.get("derriba", false)), "dir": dir,
			"empuje": float(nd.get("empuje", 1.0)), "nivel": nivel})
	elif float(nd.get("empuje", 0.0)) > 0.0 and o.tipo != "muneco" and o.vivo():
		o.empuje = dir * float(nd["empuje"])
	if not o.vivo() or o.invulnerable_t > 0.0 or intangible(o) or bool(_nd_aura(o).get("inmune_control", false)):
		return
	if float(nd.get("sin_chakra", 0.0)) > 0.0:
		o.chakra = maxf(o.chakra - float(o.stats["chakra_max"]) * float(nd["sin_chakra"]), 0.0)
	if float(nd.get("atrapa", 0.0)) > 0.0:
		_controlar(s, o, "atrapado", float(nd["atrapa"]), id, nivel)
	elif float(nd.get("aturde", 0.0)) > 0.0:
		_controlar(s, o, "aturdido", float(nd["aturde"]), id, nivel)


static func _controlar(s: ServidorJuego, o: EntidadServidor, estado: String, t: float, id: String, nivel: int) -> void:
	if o.tipo != "muneco":
		Tecnicas.apagar_modo(s, o)
		o.poner_estado(estado, t, {"jutsu": id, "nivel": nivel})
		o.empuje = Vector3.ZERO
	o.efectos["control"] = {"t": t, "jutsu": id, "nivel": nivel, "tipo": estado}
	s._evento({"tipo": "control", "entidad": o.id, "estado": estado, "duracion": t, "jutsu": id, "nivel": nivel,
		"forma": str(Datos.nivel_jutsu(id, nivel).get("forma", ""))})


static func _zona(s: ServidorJuego, dueno: EntidadServidor, id: String, nivel: int, nd: Dictionary, pos: Vector3) -> void:
	if float(nd.get("zona_radio", 0.0)) <= 0.0:
		return
	var nat := str(Datos.jutsu(id).get("naturaleza", ""))
	var dur := float(nd.get("zona_duracion", 3.0))
	if str(nd.get("zona_forma", "")) == "fuego" or str(nd.get("zona_forma", "")) == "lava":
		dur *= float(Combate.modificador_clima("fuego", s.clima)["tamano"])
	Tecnicas.crear_zona(s, pos, float(nd["zona_radio"]), dur, float(nd.get("zona_dps", 0.0)), id, nivel, dueno.id if dueno != null else -1, nat)
	s.zonas[-1]["forma"] = str(nd.get("zona_forma", ""))


# ======================================================================== área

static func area(s: ServidorJuego, e: EntidadServidor, id: String, nivel: int, nd: Dictionary) -> void:
	var alcance := float(Datos.jutsu(id).get("alcance", 15.0))
	var centro := str(nd.get("centro", "propio"))
	var pos := Vector3(e.pos.x, 0, e.pos.z)
	var obj: EntidadServidor = null
	match centro:
		"objetivo":
			var res := _punto_objetivo(s, e, alcance)
			pos = res["pos"]
			obj = res["objetivo"]
			if bool(nd.get("acerca", false)) and obj != null and obj.pos.distance_to(e.pos) > 2.0:
				_acercar(s, e, obj, id, nivel, 1.8)
		"frente":
			var res2 := _punto_objetivo(s, e, maxf(alcance, float(nd.get("distancia", 3.0)) + float(nd.get("radio", 3.0))) + 4.0)
			var cerca: EntidadServidor = res2["objetivo"]
			# Golpes cuerpo a cuerpo: paso rápido hasta quedar frente al rival.
			if bool(nd.get("acerca", false)) and cerca != null and cerca.pos.distance_to(e.pos) > 1.6:
				_acercar(s, e, cerca, id, nivel, 1.2)
			var p := e.pos + e.adelante() * float(nd.get("distancia", 3.0))
			pos = Vector3(p.x, 0, p.z)
	var golpes := int(nd.get("golpes", 1))
	var retardo := float(nd.get("retardo", 0.0))
	var intervalo := float(nd.get("intervalo", 0.3))
	s.diferidos.append({"tipo": "area", "t": retardo, "quedan": golpes, "intervalo": intervalo, "pos": pos, "dueno": e.id,
		"jutsu": id, "nivel": nivel, "sigue": obj.id if (obj != null and bool(nd.get("sigue", false))) else -1,
		"origen": Vector3(e.pos.x, 0, e.pos.z), "yaw": e.yaw})
	s._evento({"tipo": "area_inicio", "entidad": e.id, "jutsu": id, "nivel": nivel, "pos": pos, "radio": float(nd.get("radio", 3.0)),
		"retardo": retardo, "duracion": retardo + intervalo * maxf(golpes - 1, 0), "forma": str(nd.get("forma", "")), "yaw": e.yaw,
		"color": _color(id), "origen": e.pos})
	# Algunas áreas dejan además un aura (p. ej. el sello de regeneración tras el puño gigante).
	if bool(nd.get("aura", false)):
		aura(s, e, id, nivel, nd)


## Paso rápido / salto hasta quedar frente al rival.
static func _acercar(s: ServidorJuego, e: EntidadServidor, o: EntidadServidor, id: String, nivel: int, dist: float) -> void:
	var desde := e.pos
	var v := e.pos - o.pos
	v.y = 0
	var dest := o.pos + v.normalized() * dist
	var p3 := s.mapa.resolver_colision(Vector2(dest.x, dest.z), Datos.sim("radio_entidad"), 0.0)
	e.pos = Vector3(p3.x, e.pos.y, p3.y)
	e.yaw = s._yaw_hacia(e.pos, o.pos)
	s._evento({"tipo": "teletransporte", "entidad": e.id, "jutsu": id, "nivel": nivel, "desde": desde, "hasta": e.pos,
		"forma": "salto" if dist > 1.5 else "paso", "color": _color(id), "ultimo": true})


static func _golpe_area(s: ServidorJuego, d: Dictionary) -> void:
	var id := str(d["jutsu"])
	var nivel := int(d["nivel"])
	var nd := Datos.nivel_jutsu(id, nivel)
	var dueno := s.entidad(int(d["dueno"]))
	var seguido := s.entidad(int(d["sigue"]))
	if seguido != null and seguido.vivo():
		d["pos"] = Vector3(seguido.pos.x, 0, seguido.pos.z)
	var pos: Vector3 = d["pos"]
	var radio := float(nd.get("radio", 3.0))
	var cono := float(nd.get("cono", 0.0))
	var frente := Vector3(sin(float(d["yaw"])), 0, cos(float(d["yaw"])))
	for o in s.entidades:
		if not o.vivo() or (dueno != null and (o == dueno or o.equipo == dueno.equipo)):
			continue
		var plano := Vector3(o.pos.x, 0, o.pos.z)
		var dentro := plano.distance_to(pos) <= radio + Datos.sim("radio_cuerpo")
		if cono > 0.0:
			# Ataques frontales: cono desde el lanzador hasta distancia + radio.
			var desde: Vector3 = d["origen"]
			var v := plano - desde
			dentro = v.length() <= float(nd.get("distancia", 3.0)) + radio and v.length() > 0.01 \
				and rad_to_deg(frente.angle_to(v.normalized())) <= cono * 0.5
		if not dentro:
			continue
		var dir := plano - pos
		if cono > 0.0:
			dir = frente
		elif float(nd.get("atrae", 0.0)) > 0.0:
			dir = -dir
		golpear(s, dueno, o, id, nivel, nd, 1.0, dir.normalized() if dir.length() > 0.01 else frente)
		if float(nd.get("atrae", 0.0)) > 0.0 and o.tipo != "muneco" and o.vivo():
			o.empuje = (pos - plano).normalized() * float(nd["atrae"]) if (pos - plano).length() > 0.5 else Vector3.ZERO
	if int(d["quedan"]) <= 1:
		_zona(s, dueno, id, nivel, nd, pos)
	s._evento({"tipo": "area_golpe", "jutsu": id, "nivel": nivel, "pos": pos, "radio": radio, "forma": str(nd.get("forma", "")),
		"color": _color(id), "ultimo": int(d["quedan"]) <= 1, "yaw": d["yaw"], "origen": d["origen"]})


# ======================================================================== aura

static func aura(s: ServidorJuego, e: EntidadServidor, id: String, nivel: int, nd: Dictionary) -> void:
	# Volver a pulsar un aura activa la deshace (salvo las de un solo uso corto).
	if e.efectos.has("aura") and str(e.efectos["aura"]["jutsu"]) == id and float(nd.get("duracion", 5.0)) > 5.0:
		e.efectos.erase("aura")
		s._evento({"tipo": "fin_efecto", "entidad": e.id, "efecto": "aura"})
		return
	var forma := str(nd.get("aura_forma", nd.get("forma", "")))
	e.efectos["aura"] = {"t": float(nd.get("duracion", 5.0)), "jutsu": id, "nivel": nivel, "forma": forma, "acum": 0.0}
	s._evento({"tipo": "aura", "entidad": e.id, "jutsu": id, "nivel": nivel, "forma": forma, "color": _color(id),
		"duracion": float(nd.get("duracion", 5.0))})


static func _nd_aura(e: EntidadServidor) -> Dictionary:
	if not e.efectos.has("aura"):
		return {}
	var a: Dictionary = e.efectos["aura"]
	return Datos.nivel_jutsu(str(a["jutsu"]), int(a["nivel"]))


static func _nd_sabio(e: EntidadServidor) -> Dictionary:
	if e.modo == "modo_sabio" and e.modo_activo:
		return Datos.nivel_jutsu("modo_sabio", e.modo_nivel)
	return {}


static func intangible(e: EntidadServidor) -> bool:
	return bool(_nd_aura(e).get("intangible", false))


static func planea(e: EntidadServidor) -> bool:
	return bool(_nd_aura(e).get("planea", false))


static func mult_velocidad(e: EntidadServidor) -> float:
	return float(_nd_aura(e).get("vel_mult", 1.0)) * float(_nd_sabio(e).get("vel_mult", 1.0))


static func mult_dano_saliente(e: EntidadServidor) -> float:
	if e == null:
		return 1.0
	return float(_nd_aura(e).get("dano_mult", 1.0)) * float(_nd_sabio(e).get("dano_mult", 1.0))


static func mult_recibido(e: EntidadServidor) -> float:
	return (1.0 - clampf(float(_nd_aura(e).get("reduccion", 0.0)), 0.0, 1.0)) * (1.0 - float(_nd_sabio(e).get("reduccion", 0.0)))


## ¿Algún escudo (muro, arena, rotación, kamui N3) repele este proyectil?
static func repelido(s: ServidorJuego, p: Dictionary) -> bool:
	for o in s.entidades:
		if not o.vivo() or o.id == int(p["dueno"]):
			continue
		var r := float(_nd_aura(o).get("repele_radio", 0.0))
		if r > 0.0 and o.centro().distance_to(p["pos"]) <= r + float(p["radio"]):
			if p.has("equipo") and int(p["equipo"]) == o.equipo:
				continue
			s._evento({"tipo": "repelido", "entidad": o.id, "pos": p["pos"], "proyectil": p["id"], "forma": str(o.efectos["aura"]["forma"])})
			if bool(_nd_aura(o).get("refleja", false)):
				# Lo devuelve: el proyectil cambia de dueño y vuelve hacia quien lo lanzó.
				var lanzador := s.entidad(int(p["dueno"]))
				p["dir"] = (lanzador.centro() - Vector3(p["pos"])).normalized() if lanzador != null else -Vector3(p["dir"])
				p["objetivo"] = lanzador.id if lanzador != null else -1
				p["dueno"] = o.id
				p["equipo"] = o.equipo
				if p.has("golpeados"):
					p["golpeados"] = []
				p["recorrido"] = 0.0
				return false
			return true
	return false


static func actualizar_entidad(s: ServidorJuego, e: EntidadServidor, dt: float) -> void:
	if not e.efectos.has("aura"):
		return
	var a: Dictionary = e.efectos["aura"]
	var nd := _nd_aura(e)
	var cura := float(nd.get("cura_ps", 0.0))
	if cura > 0.0:
		e.vida = minf(e.vida + cura * dt, float(e.stats["vida_max"]))
		var r_aliados := float(nd.get("cura_aliados_radio", 0.0))
		if r_aliados > 0.0:
			for o in s.entidades:
				if o != e and o.vivo() and o.equipo == e.equipo and o.tipo != "muneco" and o.pos.distance_to(e.pos) <= r_aliados:
					o.vida = minf(o.vida + cura * dt, float(o.stats["vida_max"]))
	if float(nd.get("contacto_dps", 0.0)) > 0.0:
		a["acum"] = float(a.get("acum", 0.0)) + dt
		if float(a["acum"]) >= 0.5:
			a["acum"] = 0.0
			for o in s.entidades:
				if o != e and o.vivo() and o.equipo != e.equipo and o.pos.distance_to(e.pos) <= float(nd["contacto_radio"]):
					var dir: Vector3 = o.pos - e.pos
					dir.y = 0
					s._aplicar_dano(o, float(nd["contacto_dps"]) * 0.5 * mult_dano_saliente(e), e, {"jutsu": str(a["jutsu"]), "dot": true,
						"nivel": int(a["nivel"])})
					if o.tipo != "muneco":
						o.empuje = dir.normalized() * 5.0


# ======================================================================== invocar

static func invocar(s: ServidorJuego, e: EntidadServidor, id: String, nivel: int, nd: Dictionary) -> void:
	var n := int(nd.get("cantidad", 1))
	var escala := float(nd.get("escala", 1.0))
	var puntos: Array = []
	for i in n:
		var a := e.yaw + PI + TAU * float(i) / float(n) if n > 1 else e.yaw
		var dist := 1.6 + escala * 0.8 + (0.0 if n <= 6 else float(i % 3) * 1.1)
		var p := e.pos + Vector3(sin(a), 0, cos(a)) * dist
		var p2 := s.mapa.resolver_colision(Vector2(p.x, p.z), 0.4 * escala, 0.0)
		var pos := Vector3(p2.x, 0, p2.y)
		puntos.append(pos)
		s.criaturas.append({"id": s.nuevo_id(), "jutsu": id, "nivel": nivel, "dueno": e.id, "equipo": e.equipo, "pos": pos, "yaw": e.yaw,
			"t": float(nd.get("duracion", 10.0)), "total": float(nd.get("duracion", 10.0)), "forma": str(nd.get("forma", "")),
			"escala": escala, "acum": randf() * 0.5, "golpe": 0})
	var onda := float(nd.get("onda_radio", 0.0))
	if onda > 0.0:
		var centro: Vector3 = puntos[0]
		for o in _enemigos(s, e):
			if o.pos.distance_to(centro) <= onda:
				var dir: Vector3 = o.pos - centro
				dir.y = 0
				golpear(s, e, o, id, nivel, {"empuje": 8.0, "derriba": true, "aturde": float(nd.get("aturde", 0.0))}, 0.6, dir.normalized())
	s._evento({"tipo": "invocar", "entidad": e.id, "jutsu": id, "nivel": nivel, "puntos": puntos, "forma": str(nd.get("forma", "")),
		"escala": escala, "onda": onda, "color": _color(id)})


static func actualizar_criaturas(s: ServidorJuego, dt: float) -> void:
	var quitar: Array = []
	for c in s.criaturas:
		c["t"] = float(c["t"]) - dt
		var dueno := s.entidad(int(c["dueno"]))
		if float(c["t"]) <= 0.0 or dueno == null or not dueno.vivo():
			quitar.append(c)
			continue
		var nd := Datos.nivel_jutsu(str(c["jutsu"]), int(c["nivel"]))
		var pos: Vector3 = c["pos"]
		var alcance := float(nd.get("alcance_golpe", 1.6))
		var obj: EntidadServidor = null
		var md := 25.0
		for o in s.entidades:
			if o.vivo() and o.equipo != int(c["equipo"]) and o.pos.distance_to(pos) < md:
				md = o.pos.distance_to(pos)
				obj = o
		if obj == null:
			# Sin rivales: vuelve junto a su dueño.
			var hacia := dueno.pos - pos
			hacia.y = 0
			if hacia.length() > 3.0:
				_avanzar(s, c, hacia.normalized(), float(nd.get("velocidad", 4.0)), dt)
			continue
		var v := obj.pos - pos
		v.y = 0
		c["yaw"] = atan2(v.x, v.z)
		if v.length() > alcance + 0.4:
			_avanzar(s, c, v.normalized(), float(nd.get("velocidad", 4.0)), dt)
		c["acum"] = float(c["acum"]) + dt
		if float(c["acum"]) >= float(nd.get("intervalo_golpe", 1.2)) and v.length() <= alcance + Datos.sim("radio_cuerpo") + 0.5:
			c["acum"] = 0.0
			c["golpe"] = int(c["golpe"]) + 1
			golpear(s, dueno, obj, str(c["jutsu"]), int(c["nivel"]), {"empuje": 3.0 + float(c["escala"]) * 2.0,
				"derriba": float(c["escala"]) >= 2.0}, 1.0, v.normalized())
			s._evento({"tipo": "criatura_golpe", "criatura": c["id"], "jutsu": c["jutsu"], "nivel": c["nivel"], "pos": obj.centro(),
				"escala": c["escala"], "forma": c["forma"]})
	for c in quitar:
		s.criaturas.erase(c)
		s._evento({"tipo": "criatura_fin", "criatura": c["id"], "pos": c["pos"], "forma": c["forma"], "escala": c["escala"]})


static func _avanzar(s: ServidorJuego, c: Dictionary, dir: Vector3, vel: float, dt: float) -> void:
	var p: Vector3 = c["pos"] + dir * vel * dt
	var p2 := s.mapa.resolver_colision(Vector2(p.x, p.z), 0.35 * float(c["escala"]), 0.0)
	c["pos"] = Vector3(p2.x, 0, p2.y)


# ======================================================================== teletransporte

static func teletransporte(s: ServidorJuego, e: EntidadServidor, id: String, nivel: int, nd: Dictionary) -> void:
	var cadena := int(nd.get("cadena", 1))
	var distancia := float(nd.get("distancia", 10.0))
	var rivales := _enemigos(s, e).filter(func(o): return o.pos.distance_to(e.pos) <= distancia + 4.0)
	var fijado := s._resolver_objetivo(e, distancia + 4.0)
	rivales.sort_custom(func(a, b): return a.pos.distance_to(e.pos) < b.pos.distance_to(e.pos))
	if fijado != null:
		rivales.erase(fijado)
		rivales.push_front(fijado)
	var saltos: Array = []
	if rivales.is_empty():
		var yaw := float(e.accion.get("yaw_apuntado", e.yaw))
		saltos.append({"pos": e.pos + Vector3(sin(yaw), 0, cos(yaw)) * distancia * 0.6, "objetivo": -1})
	else:
		for i in cadena:
			var o: EntidadServidor = rivales[i % rivales.size()]
			saltos.append({"pos": Vector3.ZERO, "objetivo": o.id})
	var intervalo := 0.18
	e.poner_estado("teleport", intervalo * saltos.size() + 0.15, {"jutsu": id, "nivel": nivel})
	e.invulnerable_t = maxf(e.invulnerable_t, intervalo * saltos.size() + 0.1)
	for i in saltos.size():
		s.diferidos.append({"tipo": "salto", "t": intervalo * i, "quedan": 1, "intervalo": 0.0, "dueno": e.id, "jutsu": id, "nivel": nivel,
			"destino": saltos[i]["pos"], "objetivo": saltos[i]["objetivo"], "ultimo": i == saltos.size() - 1})
	if bool(nd.get("aura", false)):
		aura(s, e, id, nivel, nd)


static func _salto(s: ServidorJuego, d: Dictionary) -> void:
	var e := s.entidad(int(d["dueno"]))
	if e == null or not e.vivo():
		return
	var id := str(d["jutsu"])
	var nivel := int(d["nivel"])
	var nd := Datos.nivel_jutsu(id, nivel)
	var desde := e.pos
	var destino: Vector3 = d["destino"]
	var o := s.entidad(int(d["objetivo"]))
	if o != null and o.vivo():
		var v: Vector3 = o.pos - e.pos
		v.y = 0
		var lado := v.normalized() if v.length() > 0.1 else o.adelante()
		destino = o.pos + lado * 1.3   # detrás del objetivo, mirando hacia él
	var p2 := s.mapa.resolver_colision(Vector2(destino.x, destino.z), Datos.sim("radio_entidad"), 0.0)
	e.pos = Vector3(p2.x, 0, p2.y)
	e.empuje = Vector3.ZERO
	if o != null:
		e.yaw = s._yaw_hacia(e.pos, o.pos)
	s._evento({"tipo": "teletransporte", "entidad": e.id, "jutsu": id, "nivel": nivel, "desde": desde, "hasta": e.pos,
		"forma": str(nd.get("forma", "")), "color": _color(id), "ultimo": bool(d["ultimo"])})
	var r := float(nd.get("radio_golpe", 0.0))
	if r > 0.0:
		for x in _enemigos(s, e):
			if x.pos.distance_to(e.pos) <= r + Datos.sim("radio_cuerpo"):
				var dir: Vector3 = x.pos - e.pos
				dir.y = 0
				golpear(s, e, x, id, nivel, {"empuje": 6.0, "derriba": bool(d["ultimo"])}, 1.0, dir.normalized())


# ======================================================================== diferidos

static func actualizar_diferidos(s: ServidorJuego, dt: float) -> void:
	var quitar: Array = []
	for d in s.diferidos:
		d["t"] = float(d["t"]) - dt
		if float(d["t"]) > 0.0:
			continue
		match str(d["tipo"]):
			"area":
				_golpe_area(s, d)
			"salto":
				_salto(s, d)
		d["quedan"] = int(d["quedan"]) - 1
		if int(d["quedan"]) <= 0:
			quitar.append(d)
		else:
			d["t"] = float(d["intervalo"])
	for d in quitar:
		s.diferidos.erase(d)


## Sustitución: si `o` la tiene activa, anula este golpe, lo mueve (detrás del atacante en N2+) y en N3 deja un estallido.
static func sustituir(s: ServidorJuego, o: EntidadServidor, atacante: EntidadServidor, info: Dictionary) -> bool:
	var nd := _nd_aura(o)
	if not bool(nd.get("sustituye", false)) or info.get("dot", false):
		return false
	var a: Dictionary = o.efectos["aura"]
	var id := str(a["jutsu"])
	var nivel := int(a["nivel"])
	o.efectos.erase("aura")
	var desde := o.pos
	var dest := o.pos - o.adelante() * 4.0
	if bool(nd.get("detras", false)) and atacante != null and atacante != o:
		var v := atacante.pos - o.pos
		v.y = 0
		dest = atacante.pos + v.normalized() * 1.4
	var p2 := s.mapa.resolver_colision(Vector2(dest.x, dest.z), Datos.sim("radio_entidad"), 0.0)
	o.pos = Vector3(p2.x, 0, p2.y)
	o.empuje = Vector3.ZERO
	o.invulnerable_t = maxf(o.invulnerable_t, 0.4)
	if atacante != null and atacante != o:
		o.yaw = s._yaw_hacia(o.pos, atacante.pos)
	if o.estado != "libre" and o.estado != "muerto":
		o.poner_estado("libre", 0.0)
	s._evento({"tipo": "sustitucion", "entidad": o.id, "jutsu": id, "nivel": nivel, "desde": desde, "hasta": o.pos,
		"explota": float(nd.get("explota_radio", 0.0))})
	var r := float(nd.get("explota_radio", 0.0))
	if r > 0.0:
		for x in _enemigos(s, o):
			if x.pos.distance_to(desde) <= r:
				var dir: Vector3 = x.pos - desde
				dir.y = 0
				golpear(s, o, x, id, nivel, {"empuje": 8.0, "derriba": true}, 1.0, dir.normalized())
	return true
