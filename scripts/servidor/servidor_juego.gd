class_name ServidorJuego
extends Node
## Servidor autoritativo. Contiene TODA la lógica: movimiento, daño, chakra,
## estamina, recargas, naturalezas, clima e IA. Recibe comandos y emite estado.
## No dibuja nada: puede correr en un proceso dedicado sin pantalla.

signal estado_generado(peer_id: int, estado: Dictionary)

var mapa: Mapa
var clima := "lluvia"
var entidades: Array[EntidadServidor] = []
var proyectiles: Array = []        # [Dictionary]
var zonas: Array = []              # zonas de daño en el suelo: suelo ardiente, llamas negras...
var eventos: Array = []
var tick := 0
var dt_tick := 1.0 / 30.0
var rng := RandomNumberGenerator.new()
var auto_procesar := true          # en pruebas se llama a paso() manualmente

var _acumulado := 0.0
var _siguiente_id := 1
var _peers: Dictionary = {}        # peer_id -> id de entidad


func _init() -> void:
	Datos.cargar()
	dt_tick = 1.0 / Datos.sim("ticks_por_segundo")
	rng.seed = 4242


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Rompe la referencia circular entidad <-> IA.
		for e in entidades:
			e.ia = null


func iniciar(p_mapa: Mapa = null) -> void:
	mapa = p_mapa if p_mapa != null else Mapa.generar()
	var aldea := Datos.aldea("lluvia")
	clima = str(aldea.get("clima", "lluvia"))


## Crea el enemigo y los muñecos del campo de entrenamiento.
func poblar_entrenamiento() -> void:
	var e := _crear_entidad("ninja_lluvia", Vector3(mapa.inicio_enemigo.x, 0, mapa.inicio_enemigo.y))
	e.equipo = 2
	e.ia = IaEnemigo.new(e)
	e.yaw = PI
	for p in mapa.munecos:
		var m := _crear_entidad("muneco", Vector3(p.x, 0, p.y))
		m.equipo = 3
		m.yaw = 0.0


func agregar_jugador(peer_id: int, plantilla := "jugador_uchiha") -> int:
	var j := _crear_entidad(plantilla, Vector3(mapa.inicio_jugador.x, 0, mapa.inicio_jugador.y))
	j.peer_id = peer_id
	j.equipo = 1
	j.yaw = PI
	# Varios jugadores en red: separarlos un poco.
	j.inicio.x += float(_peers.size()) * 2.0
	j.pos = j.inicio
	_peers[peer_id] = j.id
	return j.id


func quitar_jugador(peer_id: int) -> void:
	var eid := int(_peers.get(peer_id, -1))
	_peers.erase(peer_id)
	for e in entidades:
		if e.id == eid:
			entidades.erase(e)
			break


func _crear_entidad(plantilla: String, p: Vector3) -> EntidadServidor:
	var e := EntidadServidor.new()
	e.inicio = p
	e.configurar(plantilla, _siguiente_id)
	_siguiente_id += 1
	entidades.append(e)
	return e


func nuevo_id() -> int:
	_siguiente_id += 1
	return _siguiente_id - 1


func entidad(eid: int) -> EntidadServidor:
	for e in entidades:
		if e.id == eid:
			return e
	return null


func entidad_de_peer(peer_id: int) -> EntidadServidor:
	return entidad(int(_peers.get(peer_id, -1)))


# ---------------------------------------------------------------- comandos

## Punto de entrada único de los comandos de cliente (local o red).
func recibir_comando(peer_id: int, cmd_crudo: Variant) -> void:
	var cmd := Protocolo.sanear_comando(cmd_crudo)
	if cmd.is_empty():
		return
	if cmd["t"] == Protocolo.C_REAPARECER:
		reaparecer_todo()
		return
	var e := entidad_de_peer(peer_id)
	if e == null:
		return
	aplicar_comando(e, cmd)


## Aplica un comando a una entidad. La IA usa exactamente esta misma vía.
func aplicar_comando(e: EntidadServidor, cmd: Dictionary) -> void:
	match str(cmd.get("t", "")):
		Protocolo.C_ENTRADA:
			e.entrada_mov = cmd["mov"]
			e.entrada_mira = float(cmd["mira"])
		Protocolo.C_NIVEL:
			e.nivel_poder = int(cmd["valor"])
			_evento({"tipo": "nivel", "entidad": e.id, "nivel": e.nivel_poder})
		Protocolo.C_REPERTORIO:
			aplicar_repertorio(e, cmd)
		Protocolo.C_ACCION:
			# Dirección y objetivo del disparo viajan en el comando (igual offline y en red).
			e.apuntado = {
				"dir": cmd.get("dir", Vector2.ZERO),
				"objetivo": int(cmd.get("objetivo", -1)),
				"exacto": bool(cmd.get("exacto", false)),
			}
			_accion(e, str(cmd["id"]))


## Repertorio enviado por el cliente: se valida con las mismas reglas que el menú.
## En modo offline la maestría guardada viene del cliente; en red debería venir de la base de datos del servidor.
func aplicar_repertorio(e: EntidadServidor, cmd: Dictionary) -> void:
	if e.tipo != "jugador":
		return
	e.maestria = (cmd.get("maestria", {}) as Dictionary).duplicate()
	var rep := {"activos": cmd.get("activos", []), "modo": cmd.get("modo", ""), "niveles_max": cmd.get("niveles_max", {})}
	var v := Repertorio.validar(rep, Repertorio.ficha(e.plantilla_id, e.maestria), bool(cmd.get("prueba", false)))
	if not v["ok"]:
		rep = Repertorio.repertorio_por_defecto(e.plantilla_id)
		_evento({"tipo": "mensaje", "entidad": e.id, "clave": "rep_invalido_servidor", "args": [str(v["errores"][0]) if not v["errores"].is_empty() else ""]})
	e.aplicar_repertorio(rep)
	# El cliente reconstruye sus botones con lo que el servidor aceptó de verdad.
	_evento({"tipo": "repertorio", "entidad": e.id, "jutsus": e.jutsus, "modo": e.modo,
		"activos": (rep.get("activos", []) as Array).duplicate(), "niveles_max": (rep.get("niveles_max", {}) as Dictionary).duplicate()})


## Nivel efectivo de una técnica para una entidad (maestría, máximo elegido y depuración).
func nivel_de(e: EntidadServidor, id: String) -> int:
	return Repertorio.nivel_efectivo(id, float(e.maestria.get(id, 0.0)), int(e.repertorio.get("niveles_max", {}).get(id, 3)), e.nivel_poder)


## Experiencia de maestría (solo jugadores). Avisa al subir de nivel.
func ganar_xp(e: EntidadServidor, id: String, cantidad: float) -> void:
	if e.tipo != "jugador" or id in Repertorio.MODOS_BASE or not Datos.jutsus.has(id) or Datos.jutsu(id).get("interno", false):
		return
	var antes := float(e.maestria.get(id, 0.0))
	var ahora := antes + cantidad
	e.maestria[id] = ahora
	var n0 := Repertorio.nivel_desbloqueado(antes)
	var n1 := Repertorio.nivel_desbloqueado(ahora)
	_evento({"tipo": "maestria", "entidad": e.id, "jutsu": id, "xp": ahora, "nivel": n1, "subio": n1 > n0})


func reaparecer_todo() -> void:
	proyectiles.clear()
	zonas.clear()
	for e in entidades:
		e.reiniciar()
		if e.ia != null:
			e.ia.reiniciar()
		if e.tipo == "enemigo":
			e.yaw = PI
	_evento({"tipo": "reaparecer"})


func _puede_actuar(e: EntidadServidor) -> bool:
	return e.estado == "libre"


func _mensaje(e: EntidadServidor, clave: String) -> void:
	_evento({"tipo": "mensaje", "entidad": e.id, "clave": clave})


func _accion(e: EntidadServidor, id: String) -> void:
	if id == "modo":
		id = e.modo
	if not e.vivo() or id == "" or not (id in e.jutsus):
		return
	if id == e.modo:
		Tecnicas.alternar_modo(self, e)
		return
	match id:
		"golpe":
			_accion_golpe(e)
		"saltar":
			if _puede_actuar(e) and e.en_suelo:
				var j := Datos.jutsu("saltar")
				if e.estamina < float(j["costo_estamina"]):
					_mensaje(e, "msg_sin_estamina")
					return
				e.estamina -= float(j["costo_estamina"])
				e.vel_y = float(j["fuerza"])
				e.en_suelo = false
				_evento({"tipo": "salto", "entidad": e.id})
		"esquivar":
			_accion_esquivar(e)
		_:
			if Datos.jutsu(id).get("implementado", true) or Datos.jutsu(id).get("interno", false):
				_accion_jutsu(e, id)


func _accion_golpe(e: EntidadServidor) -> void:
	var j := Datos.jutsu("golpe")
	var pasos: Array = j["pasos"]
	var paso := 0
	if e.estado == "golpe":
		# Encadenar: se guarda la intención para cuando termine el golpe actual.
		e.accion["encadenar"] = true
		return
	if not _puede_actuar(e) or not e.en_suelo:
		return
	if e.combo_ventana > 0.0:
		paso = (e.combo_paso + 1) % pasos.size()
	if e.estamina < float(j["costo_estamina"]):
		_mensaje(e, "msg_sin_estamina")
		return
	_iniciar_golpe(e, paso)


func _iniciar_golpe(e: EntidadServidor, paso: int) -> void:
	var j := Datos.jutsu("golpe")
	var p: Dictionary = j["pasos"][paso]
	e.estamina -= float(j["costo_estamina"])
	e.combo_paso = paso
	e.combo_ventana = 0.0
	var dir_cmd: Vector2 = e.apuntado.get("dir", Vector2.ZERO)
	var yaw_base := atan2(dir_cmd.x, dir_cmd.y) if dir_cmd.length() > 0.1 else e.yaw
	var obj := _objetivo_fijado(e, 3.5)
	if obj == null:
		obj = _buscar_objetivo(e, yaw_base, 70.0, 3.5)
	e.yaw = _yaw_hacia(e.pos, obj.pos) if obj != null else yaw_base
	e.poner_estado("golpe", float(p["duracion"]), {"jutsu": "golpe", "paso": paso, "golpeado": false, "encadenar": false})
	_evento({"tipo": "golpe", "entidad": e.id, "paso": paso})
	if e.tipo == "enemigo":
		_evento({"tipo": "aviso", "subtipo": "melee", "entidad": e.id, "desde": e.pos, "hacia": e.pos + e.adelante() * float(p["alcance"]), "duracion": float(p["impacto"])})


func _accion_esquivar(e: EntidadServidor) -> void:
	var j := Datos.jutsu("esquivar")
	if not (_puede_actuar(e) or e.estado == "golpe") or not e.en_suelo:
		return
	if e.recarga("esquivar") > 0.0:
		return
	if e.estamina < float(j["costo_estamina"]):
		_mensaje(e, "msg_sin_estamina")
		return
	e.estamina -= float(j["costo_estamina"])
	var dir := Vector3(e.entrada_mov.x, 0, e.entrada_mov.y)
	if dir.length() < 0.2:
		# Salto lateral a la derecha de donde mira.
		var f := e.adelante()
		dir = Vector3(-f.z, 0, f.x) * -1.0
	dir = dir.normalized()
	var dur := float(j["duracion"])
	e.empuje = dir * (float(j["distancia"]) / dur)
	e.invulnerable_t = float(j["invulnerable"])
	e.recargas["esquivar"] = float(j["recarga"])
	e.poner_estado("esquiva", dur, {"jutsu": "esquivar", "dir": dir})
	_evento({"tipo": "esquiva", "entidad": e.id, "dir": dir})


func _accion_jutsu(e: EntidadServidor, id: String) -> void:
	var j := Datos.jutsu(id)
	# Susanoo activo: volver a pulsarlo lo deshace.
	if id == "susanoo" and e.efectos.has("susanoo"):
		e.efectos.erase("susanoo")
		_evento({"tipo": "susanoo", "entidad": e.id, "activo": false})
		return
	if not _puede_actuar(e):
		return
	if e.efectos.has("vulnerable"):
		_mensaje(e, "msg_bloqueado_jutsu")
		return
	if e.recarga(id) > 0.0:
		_mensaje(e, "msg_recarga")
		return
	var req_modo: Array = j.get("requiere_modo_activo", [])
	# Si el ojo que pide está en la ranura de modo pero apagado, se enciende solo.
	if not req_modo.is_empty() and not e.modo_activo and e.modo in req_modo:
		Tecnicas.alternar_modo(self, e)
	if not req_modo.is_empty() and not (e.modo_activo and e.modo in req_modo):
		_evento({"tipo": "mensaje", "entidad": e.id, "clave": "msg_requiere_modo", "args": [Datos.jutsu(str(req_modo[0])).get("nombre", "")]})
		return
	if str(j.get("clima", "")) == "tormenta" and not Datos.reglas.get("clima", {}).get(clima, {}).get("tormenta", false):
		_mensaje(e, "msg_sin_tormenta")
		return
	var nivel := nivel_de(e, id)
	var costo := Combate.costo_chakra(id, nivel, e.attrs)
	if e.chakra < costo:
		_mensaje(e, "msg_sin_chakra")
		return
	e.chakra -= costo
	e.recargas[id] = float(j["recarga"])
	ganar_xp(e, id, float(Datos.reglas["maestria"]["xp_uso"]))
	var t := Combate.tiempo_sellos(id, e.attrs)
	var dir_cmd: Vector2 = e.apuntado.get("dir", Vector2.ZERO)
	if dir_cmd.length() > 0.1:
		e.yaw = atan2(dir_cmd.x, dir_cmd.y)
	elif e.tipo == "jugador":
		e.yaw = e.entrada_mira
	e.poner_estado("sellos", t, {"jutsu": id, "nivel": nivel, "yaw_apuntado": e.yaw,
		"objetivo": int(e.apuntado.get("objetivo", -1)), "exacto": bool(e.apuntado.get("exacto", false))})
	_evento({"tipo": "sellos", "entidad": e.id, "jutsu": id, "nivel": nivel, "duracion": t, "sellos": j.get("sellos", [])})
	if e.tipo == "enemigo":
		var obj := _jugador_mas_cercano(e.pos)
		var hacia: Vector3 = obj.pos if obj != null else e.pos + e.adelante() * 10.0
		_evento({"tipo": "aviso", "subtipo": "jutsu", "entidad": e.id, "desde": e.pos, "hacia": hacia, "duracion": t})


# ---------------------------------------------------------------- simulación

func _process(delta: float) -> void:
	if not auto_procesar:
		return
	# Tiempo real: la pausa de impacto / cámara lenta del cliente (Engine.time_scale) no frena el servidor.
	var real := delta / Engine.time_scale if Engine.time_scale > 0.001 else delta
	_acumulado += minf(real, 0.25)
	while _acumulado >= dt_tick:
		_acumulado -= dt_tick
		paso(dt_tick)
		publicar_estado()


## Avanza la simulación un tick fijo.
func paso(dt: float) -> void:
	tick += 1
	for e in entidades:
		_actualizar_recursos(e, dt)
		Tecnicas.actualizar_entidad(self, e, dt)
	Tecnicas.actualizar_zonas(self, dt)
	for e in entidades:
		if e.ia != null and e.vivo():
			e.ia.pensar(self, dt)
	for e in entidades:
		_actualizar_estado(e, dt)
		_mover(e, dt)
	_actualizar_proyectiles(dt)


func _actualizar_recursos(e: EntidadServidor, dt: float) -> void:
	for k in e.recargas.keys():
		e.recargas[k] = maxf(float(e.recargas[k]) - dt, 0.0)
	e.invulnerable_t = maxf(e.invulnerable_t - dt, 0.0)
	e.combo_ventana = maxf(e.combo_ventana - dt, 0.0)
	if not e.vivo() or e.tipo == "muneco":
		return
	# El chakra se regenera si no hay un modo ocular ni un Susanoo consumiéndolo.
	var gastando := (e.modo_activo and e.modo in Tecnicas.OJOS) or e.efectos.has("susanoo")
	if not gastando:
		e.chakra = minf(e.chakra + float(e.stats["regen_chakra"]) * dt, float(e.stats["chakra_max"]))
	if e.estado == "libre":
		e.estamina = minf(e.estamina + float(e.stats["regen_estamina"]) * dt, float(e.stats["estamina_max"]))


func _actualizar_estado(e: EntidadServidor, dt: float) -> void:
	if e.estado == "libre" or e.estado == "muerto":
		return
	e.estado_t -= dt
	match e.estado:
		"golpe":
			var p: Dictionary = Datos.jutsu("golpe")["pasos"][int(e.accion["paso"])]
			if not e.accion["golpeado"] and e.estado_total - e.estado_t >= float(p["impacto"]):
				e.accion["golpeado"] = true
				_resolver_golpe(e, int(e.accion["paso"]))
			if e.estado_t <= 0.0:
				var encadenar: bool = e.accion.get("encadenar", false)
				e.poner_estado("libre", 0.0)
				e.combo_ventana = float(Datos.jutsu("golpe")["ventana_combo"])
				if encadenar:
					_accion_golpe(e)
		"sellos":
			if e.estado_t <= 0.0:
				_ejecutar_jutsu(e)
		"chidori_carga":
			if e.estado_t <= 0.0:
				_iniciar_embiste(e)
		"chidori_embiste":
			_actualizar_embiste(e, dt)
		"kirin":
			Tecnicas.tick_kirin(self, e, dt)
		"rafaga":
			e.accion["siguiente"] = float(e.accion["siguiente"]) - dt
			if float(e.accion["siguiente"]) <= 0.0 and int(e.accion["quedan"]) > 0:
				_disparar_proyectil(e, str(e.accion["jutsu"]), int(e.accion["nivel"]))
				e.accion["quedan"] = int(e.accion["quedan"]) - 1
				e.accion["siguiente"] = float(e.accion["intervalo"])
			if int(e.accion["quedan"]) <= 0 and e.estado_t <= 0.0:
				e.poner_estado("libre", 0.0)
		_:
			if e.estado_t <= 0.0:
				e.poner_estado("libre", 0.0)
				e.empuje = Vector3.ZERO


func _ejecutar_jutsu(e: EntidadServidor) -> void:
	var id := str(e.accion["jutsu"])
	var nivel := int(e.accion["nivel"])
	var nd := Datos.nivel_jutsu(id, nivel)
	var mecanica := str(Datos.jutsu(id).get("mecanica", Datos.jutsu(id).get("tipo", "")))
	if id == "bala_agua":
		mecanica = "rafaga"
	match mecanica:
		"proyectil":
			_disparar_proyectil(e, id, nivel)
			e.poner_estado("lanzar", 0.35, {"jutsu": id, "nivel": nivel})
		"kirin":
			Tecnicas.preparar_kirin(self, e, nivel)
		"amaterasu":
			Tecnicas.lanzar_amaterasu(self, e, nivel)
		"susanoo":
			Tecnicas.alternar_susanoo(self, e, nivel)
		"shinra":
			Tecnicas.shinra(self, e, nivel)
		"rafaga":
			var n := int(nd.get("rafaga", 1))
			var intervalo := float(nd.get("intervalo_rafaga", 0.2))
			e.poner_estado("rafaga", intervalo * n, {"jutsu": id, "nivel": nivel, "quedan": n, "siguiente": 0.0, "intervalo": intervalo,
				"yaw_apuntado": e.accion.get("yaw_apuntado", e.yaw), "objetivo": -1, "exacto": false})
		"embiste":
			# Carga en la mano (estado "chidori_carga", compartido por embiste de rayo y esfera) y luego embiste.
			e.poner_estado("chidori_carga", float(nd["carga"]), {"jutsu": id, "nivel": nivel, "yaw_apuntado": e.accion.get("yaw_apuntado", e.yaw),
				"objetivo": e.accion.get("objetivo", -1), "exacto": e.accion.get("exacto", false)})
			_evento({"tipo": "chidori_carga", "entidad": e.id, "jutsu": id, "nivel": nivel, "duracion": float(nd["carga"])})
		_:
			e.poner_estado("libre", 0.0)


func _disparar_proyectil(e: EntidadServidor, id: String, nivel: int) -> void:
	var nd := Datos.nivel_jutsu(id, nivel)
	var j := Datos.jutsu(id)
	var escala := Combate.escala_tamano(id, e.attrs, clima)
	var obj := _resolver_objetivo(e, float(j.get("alcance", 25.0)))
	if obj == null:
		e.yaw = float(e.accion.get("yaw_apuntado", e.yaw))
	var radio := float(nd["radio"]) * escala
	# Los proyectiles grandes salen más altos y por delante para no tocar el suelo ni al lanzador.
	var origen := e.pos + Vector3(0, 1.4 + radio * 0.5, 0) + e.adelante() * (0.8 + radio)
	var dir := e.adelante()
	if obj != null:
		e.yaw = _yaw_hacia(e.pos, obj.pos)
		origen = e.pos + Vector3(0, 1.4 + radio * 0.5, 0) + e.adelante() * (0.8 + radio)
		dir = (obj.centro() - origen)
		if radio > 0.8:
			dir.y = 0.0   # las bolas grandes vuelan horizontales
		dir = dir.normalized()
	var p := {
		"id": _siguiente_id,
		"jutsu": id,
		"nivel": nivel,
		"dueno": e.id,
		"objetivo": obj.id if obj != null else -1,
		"pos": origen,
		"dir": dir,
		"velocidad": float(nd["velocidad"]),
		"radio": radio,
		"radio_explosion": float(nd["radio_explosion"]) * escala,
		"recorrido": 0.0,
		"alcance": float(j.get("alcance", 25.0)),
		"escala": escala,
	}
	_siguiente_id += 1
	proyectiles.append(p)
	_evento({"tipo": "lanzar", "entidad": e.id, "jutsu": id, "nivel": nivel, "proyectil": p["id"], "pos": origen, "dir": dir, "radio": p["radio"]})


func _iniciar_embiste(e: EntidadServidor) -> void:
	var nivel := int(e.accion["nivel"])
	var jid := str(e.accion.get("jutsu", "chidori"))
	var nd := Datos.nivel_jutsu(jid, nivel)
	var yaw_base := float(e.accion.get("yaw_apuntado", e.yaw))
	e.yaw = yaw_base
	var obj := _resolver_objetivo(e, float(nd["distancia"]) + 2.0)
	e.yaw = _yaw_hacia(e.pos, obj.pos) if obj != null else yaw_base
	var dir := e.adelante()
	var dur := float(nd["distancia"]) / float(nd["velocidad"])
	e.poner_estado("chidori_embiste", dur, {"jutsu": jid, "nivel": nivel, "dir": dir, "golpeo": false})
	e.empuje = dir * float(nd["velocidad"])
	_evento({"tipo": "chidori_embiste", "entidad": e.id, "jutsu": jid, "nivel": nivel, "desde": e.pos, "dir": dir, "duracion": dur})


func _actualizar_embiste(e: EntidadServidor, _dt: float) -> void:
	var nivel := int(e.accion["nivel"])
	var jid := str(e.accion.get("jutsu", "chidori"))
	var nd := Datos.nivel_jutsu(jid, nivel)
	var nat := str(Datos.jutsu(jid).get("naturaleza", ""))
	if not e.accion["golpeo"]:
		for o in entidades:
			if o == e or not o.vivo():
				continue
			if o.centro().distance_to(e.centro() + e.adelante() * 0.5) <= float(nd["radio_golpe"]) + Datos.sim("radio_cuerpo"):
				e.accion["golpeo"] = true
				var dano := Combate.dano_jutsu(jid, nivel, e.attrs, o.naturaleza_principal(), clima)
				_aplicar_dano(o, dano, e, {"jutsu": jid, "naturaleza": nat, "derriba": true, "dir": e.adelante(), "empuje": float(nd.get("empuje", 9.0)), "nivel": nivel})
				if jid == "chidori":
					_cadena_rayo(e, o, dano, nivel)
					_descarga(e, o, dano, nivel, nd)
				elif int(nd.get("clones", 0)) > 0:
					_clones_rasengan(e, o, dano, nivel, nd)
				# Termina el embiste al impactar, con un breve retroceso (embiste de rayo te deja expuesto).
				e.empuje = -e.adelante() * 3.0
				e.poner_estado("recuperacion", 0.55 if jid == "chidori" else 0.3, {"jutsu": jid, "nivel": nivel})
				return
	if e.estado_t <= 0.0:
		e.empuje = Vector3.ZERO
		e.poner_estado("recuperacion", 0.25, {"jutsu": jid, "nivel": nivel})


## embiste de rayo N2: descarga a los cercanos; N3: descarga por todo el cuerpo en área.
func _descarga(e: EntidadServidor, primero: EntidadServidor, dano: float, nivel: int, nd: Dictionary) -> void:
	var radio := maxf(float(nd.get("descarga_radio", 0.0)), float(nd.get("area_radio", 0.0)))
	if radio <= 0.0:
		return
	var puntos: Array = []
	var factor := 0.6 if nd.has("area_radio") else 0.4
	for o in entidades:
		if o == e or o == primero or not o.vivo():
			continue
		if o.pos.distance_to(e.pos) <= radio:
			_aplicar_dano(o, dano * factor, e, {"jutsu": "chidori", "naturaleza": "rayo", "derriba": nd.has("area_radio"), "dir": (o.pos - e.pos).normalized(), "empuje": 5.0, "nivel": nivel, "cadena": true})
			puntos.append(o.centro())
	_evento({"tipo": "descarga", "entidad": e.id, "nivel": nivel, "pos": e.centro(), "radio": radio, "puntos": puntos})


## Rasengan N3: los clones golpean a otros enemigos cercanos con su propio Rasengan gigante.
func _clones_rasengan(e: EntidadServidor, primero: EntidadServidor, dano: float, nivel: int, nd: Dictionary) -> void:
	var puntos: Array = []
	var quedan := int(nd.get("clones", 0))
	for o in entidades:
		if quedan <= 0:
			break
		if o == e or o == primero or not o.vivo() or o.equipo == e.equipo:
			continue
		if o.pos.distance_to(primero.pos) <= float(nd.get("clones_radio", 8.0)):
			_aplicar_dano(o, dano, e, {"jutsu": "rasengan", "naturaleza": "", "derriba": true, "dir": (o.pos - primero.pos).normalized(), "empuje": float(nd.get("empuje", 14.0)), "nivel": nivel})
			puntos.append(o.pos)
			quedan -= 1
	_evento({"tipo": "clones", "entidad": e.id, "nivel": nivel, "puntos": puntos, "desde": e.pos})


## La lluvia hace que el rayo salte a enemigos parados sobre charcos.
func _cadena_rayo(atacante: EntidadServidor, primero: EntidadServidor, dano: float, nivel: int) -> void:
	var mod := Combate.modificador_clima("rayo", clima)
	if not mod["cadena"]:
		return
	var saltos := int(Datos.nivel_jutsu("chidori", nivel).get("cadena_saltos", 1))
	var radio := float(mod["cadena_radio"])
	var factor := float(mod["cadena_factor"])
	var golpeados := [primero]
	var actual := primero
	var puntos: Array = [primero.centro()]
	for i in saltos:
		var mejor: EntidadServidor = null
		var mejor_d := INF
		for o in entidades:
			if o == atacante or o in golpeados or not o.vivo() or not o.en_charco:
				continue
			var d := o.pos.distance_to(actual.pos)
			if d <= radio and d < mejor_d:
				mejor = o
				mejor_d = d
		if mejor == null:
			break
		var dano_cadena := dano * factor
		_aplicar_dano(mejor, dano_cadena, atacante, {"jutsu": "chidori", "naturaleza": "rayo", "derriba": false, "dir": (mejor.pos - actual.pos).normalized(), "empuje": 2.0, "cadena": true, "nivel": nivel})
		golpeados.append(mejor)
		puntos.append(mejor.centro())
		actual = mejor
	if puntos.size() > 1:
		_evento({"tipo": "cadena", "entidad": atacante.id, "puntos": puntos, "nivel": nivel, "saltos": puntos.size() - 1})


func _resolver_golpe(e: EntidadServidor, paso: int) -> void:
	if paso == 2 and Tecnicas.golpe_definitivo(self, e):
		return
	var p: Dictionary = Datos.jutsu("golpe")["pasos"][paso]
	var alcance := float(p["alcance"])
	var medio_ang := deg_to_rad(float(p["angulo"]) * 0.5)
	var f := e.adelante()
	for o in entidades:
		if o == e or not o.vivo():
			continue
		var d := o.pos - e.pos
		d.y = 0
		if d.length() > alcance + Datos.sim("radio_entidad"):
			continue
		if d.length() > 0.3 and f.angle_to(d.normalized()) > medio_ang:
			continue
		var dano := Combate.dano_taijutsu(paso, e.attrs) * Tecnicas.multiplicador_taijutsu(e)
		_aplicar_dano(o, dano, e, {"jutsu": "golpe", "naturaleza": "", "derriba": bool(p["derriba"]), "dir": f, "empuje": float(p["empuje"]), "paso": paso})


func _actualizar_proyectiles(dt: float) -> void:
	var quitar: Array = []
	for p in proyectiles:
		var vel := float(p["velocidad"])
		# modo ocular: los proyectiles que van hacia quien lo tiene activo avanzan más lento.
		var obj := entidad(int(p["objetivo"]))
		if obj != null:
			vel *= Tecnicas.ralentizacion(obj)
		var paso_v: Vector3 = p["dir"] * vel * dt
		p["pos"] = p["pos"] + paso_v
		p["recorrido"] = float(p["recorrido"]) + paso_v.length()
		var pos: Vector3 = p["pos"]
		var radio := float(p["radio"])
		var impacto: EntidadServidor = null
		for e in entidades:
			if e.id == int(p["dueno"]) or not e.vivo():
				continue
			if e.centro().distance_to(pos) <= radio + Datos.sim("radio_cuerpo"):
				impacto = e
				break
		var choca := impacto != null
		if not choca and pos.y - radio * 0.25 <= 0.0:
			choca = true
		if not choca and mapa.punto_bloqueado(Vector2(pos.x, pos.z), radio * 0.6, pos.y, true):
			choca = true
		if not choca and float(p["recorrido"]) >= float(p["alcance"]):
			choca = true
		if choca:
			_explotar(p, impacto)
			quitar.append(p)
	for p in quitar:
		proyectiles.erase(p)


func _explotar(p: Dictionary, directo: EntidadServidor) -> void:
	var id := str(p["jutsu"])
	var nivel := int(p["nivel"])
	var dueno := entidad(int(p["dueno"]))
	var attrs: Dictionary = dueno.attrs if dueno != null else {}
	var pos: Vector3 = p["pos"]
	var r := float(p["radio_explosion"])
	var nat := str(Datos.jutsu(id).get("naturaleza", ""))
	for e in entidades:
		if not e.vivo() or (dueno != null and e.id == dueno.id):
			continue
		var d := e.centro().distance_to(pos)
		if e != directo and d > r + Datos.sim("radio_cuerpo"):
			continue
		var caida := 1.0 if e == directo else clampf(1.0 - d / (r + 0.6) * 0.5, 0.5, 1.0)
		var dano := Combate.dano_jutsu(id, nivel, attrs, e.naturaleza_principal(), clima) * caida
		var dir := (e.pos - pos)
		dir.y = 0
		_aplicar_dano(e, dano, dueno, {"jutsu": id, "naturaleza": nat, "derriba": id == "bola_fuego" and nivel >= 2, "dir": dir.normalized() if dir.length() > 0.01 else p["dir"], "empuje": (1.5 + nivel * 1.5) if id == "bola_fuego" else 0.8, "nivel": nivel})
	var suelo := Vector3(pos.x, 0, pos.z)
	var nd := Datos.nivel_jutsu(id, nivel)
	if float(nd.get("suelo_ardiente", 0.0)) > 0.0:
		# Bola de Fuego N2/N3: el suelo queda ardiendo (la lluvia lo acorta).
		var mod := Combate.modificador_clima(nat, clima)
		Tecnicas.crear_zona(self, suelo, r * 0.7, float(nd["suelo_ardiente"]) * float(mod["tamano"]), float(nd.get("suelo_dps", 6.0)) * float(mod["dano"]), id, nivel, dueno.id if dueno != null else -1, nat)
	_evento({"tipo": "explosion", "jutsu": id, "nivel": nivel, "pos": pos, "suelo": suelo, "radio": r, "proyectil": p["id"], "escala": p["escala"]})


func _aplicar_dano(o: EntidadServidor, cantidad: float, atacante: EntidadServidor, info: Dictionary) -> void:
	if not o.vivo():
		return
	if o.invulnerable_t > 0.0:
		_evento({"tipo": "esquivado", "entidad": o.id})
		return
	cantidad *= Tecnicas.multiplicador_recibido(o)
	o.vida = maxf(o.vida - cantidad, 0.0)
	var jid := str(info.get("jutsu", ""))
	if atacante != null and atacante != o and not info.get("dot", false) and not info.get("cadena", false):
		ganar_xp(atacante, jid, float(Datos.reglas["maestria"]["xp_impacto"]))
	# Armadura de llamas negras: quien la golpea cuerpo a cuerpo se enciende.
	if jid == "golpe" and atacante != null and o.efectos.has("armadura_negra"):
		Tecnicas.encender(self, atacante, o, int(o.efectos["armadura_negra"]["nivel"]), 4.0)
	var mult := 1.0
	if str(info.get("naturaleza", "")) != "":
		mult = Combate.multiplicador_naturaleza(str(info["naturaleza"]), o.naturaleza_principal())
	_evento({
		"tipo": "impacto", "entidad": o.id, "atacante": atacante.id if atacante != null else -1,
		"cantidad": cantidad, "pos": o.centro(), "jutsu": str(info.get("jutsu", "")),
		"naturaleza_mult": mult, "cadena": bool(info.get("cadena", false)), "nivel": int(info.get("nivel", 1)),
	})
	var dir: Vector3 = info.get("dir", Vector3.ZERO)
	if info.get("dot", false) and o.vida > 0.0:
		return   # el daño continuo no interrumpe ni derriba
	if o.vida <= 0.0:
		Tecnicas.apagar_modo(self, o)
		o.sharingan = false
		o.poner_estado("muerto", 0.0)
		o.empuje = dir * 4.0
		_evento({"tipo": "derrota", "entidad": o.id, "tipo_entidad": o.tipo})
		return
	if o.tipo == "muneco":
		o.poner_estado("golpeado", 0.25)
		return
	# El embiste del embiste de rayo no se interrumpe (superarmadura).
	if o.estado == "chidori_embiste":
		return
	if info.get("derriba", false):
		o.poner_estado("caido", Datos.reglas["estados"]["caido_duracion"])
		o.empuje = dir * float(info.get("empuje", 4.0))
	else:
		o.poner_estado("golpeado", Datos.reglas["estados"]["golpeado_duracion"])
		o.empuje = dir * float(info.get("empuje", 1.0))
	if atacante != null and atacante.tipo != "muneco":
		o.yaw = _yaw_hacia(o.pos, atacante.pos)


func _mover(e: EntidadServidor, dt: float) -> void:
	if e.tipo == "muneco":
		e.en_charco = mapa.en_charco(e.pos2())
		return
	var horiz := Vector3.ZERO
	var puede_moverse := e.estado == "libre"
	if puede_moverse and e.entrada_mov.length() > 0.05:
		var v := Vector3(e.entrada_mov.x, 0, e.entrada_mov.y)
		horiz = v * float(e.stats["velocidad"]) * Tecnicas.multiplicador_velocidad(e)
		var objetivo_yaw := atan2(v.x, v.z)
		e.yaw = lerp_angle(e.yaw, objetivo_yaw, minf(1.0, dt * 14.0))
	horiz += e.empuje
	if e.estado != "esquiva" and e.estado != "chidori_embiste":
		e.empuje = e.empuje.move_toward(Vector3.ZERO, dt * 18.0)
	# Gravedad y salto.
	e.vel_y -= Datos.sim("gravedad") * dt
	var nueva := e.pos + horiz * dt
	nueva.y = e.pos.y + e.vel_y * dt
	if nueva.y <= 0.0:
		nueva.y = 0.0
		e.vel_y = 0.0
		e.en_suelo = true
	else:
		e.en_suelo = false
	var p2 := mapa.resolver_colision(Vector2(nueva.x, nueva.z), Datos.sim("radio_entidad"), nueva.y)
	if e.estado == "chidori_embiste" and p2.distance_to(Vector2(nueva.x, nueva.z)) > 0.05:
		# Chocó contra una pared: termina el embiste.
		e.empuje = Vector3.ZERO
		e.poner_estado("recuperacion", 0.3, e.accion)
	# Colisión simple entre personajes vivos.
	for o in entidades:
		if o == e or not o.vivo():
			continue
		var d := p2 - o.pos2()
		var minimo := Datos.sim("radio_entidad") * 2.0
		if d.length() < minimo and d.length() > 0.001:
			p2 = o.pos2() + d.normalized() * minimo
	e.pos = Vector3(p2.x, nueva.y, p2.y)
	e.en_charco = e.en_suelo and mapa.en_charco(p2)


# ---------------------------------------------------------------- utilidades

func _yaw_hacia(desde: Vector3, hacia: Vector3) -> float:
	var d := hacia - desde
	return atan2(d.x, d.z)


## Objetivo fijado (lock-on) enviado por el cliente, si sigue siendo válido.
func _objetivo_fijado(e: EntidadServidor, rango: float) -> EntidadServidor:
	var oid := int(e.accion["objetivo"]) if e.accion.has("objetivo") else int(e.apuntado.get("objetivo", -1))
	if oid < 0:
		return null
	var o := entidad(oid)
	if o == null or o == e or not o.vivo() or o.equipo == e.equipo:
		return null
	if o.pos.distance_to(e.pos) > rango:
		return null
	return o


## Decide a quién apunta un jutsu: objetivo fijado válido > dirección exacta (arrastre) > asistencia en cono.
func _resolver_objetivo(e: EntidadServidor, rango: float) -> EntidadServidor:
	var obj := _objetivo_fijado(e, rango + 2.0)
	if obj != null:
		return obj
	if bool(e.accion.get("exacto", false)):
		return null
	var yaw_base := float(e.accion.get("yaw_apuntado", e.yaw))
	# La ceguera progresiva (Mangekyō) reduce la asistencia de puntería.
	return _buscar_objetivo(e, yaw_base, Combate.precision_grados(e.attrs) * (1.0 - e.ceguera * 0.7), rango)


## Objetivo vivo más conveniente dentro de un cono (asistencia de puntería).
func _buscar_objetivo(e: EntidadServidor, yaw_base: float, angulo_grados: float, rango: float) -> EntidadServidor:
	var f := Vector3(sin(yaw_base), 0, cos(yaw_base))
	var mejor: EntidadServidor = null
	var mejor_puntaje := INF
	for o in entidades:
		if o == e or not o.vivo() or o.equipo == e.equipo:
			continue
		var d := o.pos - e.pos
		d.y = 0
		var dist := d.length()
		if dist > rango or dist < 0.01:
			continue
		var ang := rad_to_deg(f.angle_to(d / dist))
		if ang > angulo_grados:
			continue
		# Prioriza enemigos reales sobre muñecos, y luego cercanía/ángulo.
		var puntaje := dist + ang * 0.15 + (6.0 if o.tipo == "muneco" else 0.0)
		if puntaje < mejor_puntaje:
			mejor_puntaje = puntaje
			mejor = o
	return mejor


func _jugador_mas_cercano(p: Vector3) -> EntidadServidor:
	var mejor: EntidadServidor = null
	var md := INF
	for o in entidades:
		if o.tipo == "jugador" and o.vivo():
			var d := o.pos.distance_to(p)
			if d < md:
				md = d
				mejor = o
	return mejor


func _evento(ev: Dictionary) -> void:
	ev["tick"] = tick
	eventos.append(ev)


## Construye la instantánea y la entrega a cada peer conectado.
func publicar_estado() -> void:
	var ents: Array = []
	for e in entidades:
		ents.append(e.a_estado())
	var proys: Array = []
	for p in proyectiles:
		proys.append({"id": p["id"], "jutsu": p["jutsu"], "pos": p["pos"], "dir": p["dir"], "radio": p["radio"], "nivel": p["nivel"], "dueno": p["dueno"]})
	var zs: Array = []
	for z in zonas:
		zs.append({"id": z["id"], "pos": z["pos"], "radio": z["radio"], "jutsu": z["jutsu"], "nivel": z["nivel"], "t": z["t"], "total": z["total"]})
	var base := {"tick": tick, "clima": clima, "entidades": ents, "proyectiles": proys, "zonas": zs, "eventos": eventos}
	for peer in _peers.keys():
		var est := base.duplicate()
		est["tu_entidad"] = _peers[peer]
		estado_generado.emit(int(peer), est)
	eventos = []
