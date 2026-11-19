extends SceneTree
## Prueba automática de red local (headless, un solo proceso, sockets reales por localhost):
##   - un anfitrión con el servidor con autoridad y su propio jugador (TransporteLocal),
##   - 2 clientes bot por ENet (uno con el simulador de mala conexión), cada uno con su personaje,
##   - se mueven, lanzan jutsus entre ellos y se comprueba que todos ven el mismo estado.
## También: descubrimiento por UDP, partida llena (5.º jugador rechazado) y predicción del cliente.
## Ejecutar: godot --headless --path . -s res://tests/red.gd

const PUERTO := 17777
const PUERTO_DESC := 17778

var fallos := 0
var pasadas := 0
var servidor: ServidorJuego
var red_srv: TransporteENet
var local: TransporteLocal
var bots: Array = []      # [{nodo, red, id, ultimo, eventos[], nombre}]
var _t0 := 0
var _fase := 0
var _desc_a: Descubrimiento
var _desc_b: Descubrimiento
var _extra: Array = []
var _rechazado := false
var _t_entrada := 0
var _prision_lanzada := false


var _preparado := false


func _initialize() -> void:
	Datos.cargar(true)
	print("== Prueba de red local ==")
	probar_prediccion()


## Se prepara en el primer fotograma: los nodos ya están dentro del árbol.
func _preparar() -> void:
	_preparado = true
	var raiz_s := Node.new()
	raiz_s.name = "Anfitrion"
	root.add_child(raiz_s)
	servidor = ServidorJuego.new()
	servidor.name = "Servidor"
	raiz_s.add_child(servidor)
	servidor.iniciar()
	servidor.poblar_entrenamiento()
	servidor.poblar_aldea()
	for e in servidor.entidades:
		if e.tipo == "enemigo":
			e.ia = null   # quieto: la prueba compara posiciones
	local = TransporteLocal.new()
	raiz_s.add_child(local)
	local.iniciar(servidor)
	var pj_a := Creacion.nuevo()
	pj_a["nombre"] = "Kaito_anfitrion"
	pj_a["aspecto"]["peinado"] = "coleta"
	local.enviar({"t": Protocolo.C_PERSONAJE, "datos": pj_a})
	red_srv = TransporteENet.new()
	red_srv.name = "Red"
	raiz_s.add_child(red_srv)
	var err := red_srv.crear_servidor(servidor, PUERTO, 4)
	comprobar(err == OK, "el anfitrión abre la partida en el puerto %d" % PUERTO)
	for i in 2:
		bots.append(_crear_bot("Bot%d" % (i + 1), i == 1))
	_desc_a = Descubrimiento.new()
	_desc_a.destino = "127.0.0.1"
	_desc_a.puerto = PUERTO_DESC
	raiz_s.add_child(_desc_a)
	_desc_b = Descubrimiento.new()
	_desc_b.puerto = PUERTO_DESC
	root.add_child(_desc_b)
	_desc_b.escuchar()
	_desc_a.anunciar({"nombre": "Anfitrión", "jugadores": 3, "max": 4, "puerto": PUERTO})
	_t0 = Time.get_ticks_msec()


func comprobar(cond: bool, nombre: String) -> void:
	if cond:
		pasadas += 1
		print("  OK   ", nombre)
	else:
		fallos += 1
		printerr("  FALLO ", nombre)


func _crear_bot(nombre: String, simular: bool) -> Dictionary:
	var n := Node.new()
	n.name = nombre
	root.add_child(n)
	var r := TransporteENet.new()
	r.name = "Red"
	n.add_child(r)
	r.simular = simular
	var b := {"nodo": n, "red": r, "id": -1, "ultimo": {}, "eventos": [], "nombre": nombre}
	r.conectado.connect(func(id):
		b["id"] = id
		var pj := Creacion.nuevo()
		pj["nombre"] = nombre
		pj["clan"] = "lava" if nombre == "Bot1" else "hielo"
		r.enviar({"t": Protocolo.C_PERSONAJE, "datos": pj})
		r.enviar({"t": Protocolo.C_REPERTORIO, "activos": ["bola_fuego", "lava", "hielo", "prision_agua"], "modo": "", "prueba": true}))
	r.estado_recibido.connect(func(est):
		if est.has("jugadores"):
			b["info"] = est["jugadores"]
		b["ultimo"] = est
		b["eventos"].append_array(est.get("eventos", [])))
	r.rechazado.connect(func(_m): _rechazado = true)
	r.unirse("127.0.0.1", PUERTO)
	return b


func _seg() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


func _process(_d: float) -> bool:
	if not _preparado:
		_preparar()
		return false
	var t := _seg()
	# Pasada la fase de movimiento, los bots mandan «quieto» a ritmo de tick como el cliente real (la entrada
	# viaja sin garantía: un solo «quieto» perdido dejaba al bot caminando).
	if _fase >= 2 and Time.get_ticks_msec() - _t_entrada >= 33:
		_t_entrada = Time.get_ticks_msec()
		for b in bots:
			(b["red"] as TransporteENet).enviar({"t": Protocolo.C_ENTRADA, "mov": Vector2.ZERO, "mira": 0.0, "seq": Engine.get_process_frames()})
	match _fase:
		0:
			# Esperar a que los dos bots estén conectados y configurados.
			if bots.all(func(b): return int(b["id"]) >= 0 and not (b["ultimo"] as Dictionary).is_empty()):
				comprobar(true, "los 2 clientes bot se conectan por localhost")
				_fase = 1
				_t0 = Time.get_ticks_msec()
			elif t > 8.0:
				comprobar(false, "los 2 clientes bot se conectan por localhost")
				_terminar()
		1:
			# Moverse en direcciones distintas durante 1,2 s, a 30 entradas por segundo como el cliente real.
			if Time.get_ticks_msec() - _t_entrada < 33:
				return false
			_t_entrada = Time.get_ticks_msec()
			for i in bots.size():
				var b: Dictionary = bots[i]
				# Direcciones libres: los jugadores aparecen en fila a 2 m (no caminar uno contra otro).
				var mov := Vector2(0, -1) if i == 0 else Vector2(1, 0)
				(b["red"] as TransporteENet).enviar({"t": Protocolo.C_ENTRADA, "mov": mov, "mira": 0.0, "seq": Engine.get_process_frames()})
			if t > 1.2:
				for b in bots:
					(b["red"] as TransporteENet).enviar({"t": Protocolo.C_ENTRADA, "mov": Vector2.ZERO, "mira": 0.0, "seq": Engine.get_process_frames()})
				_fase = 2
				_t0 = Time.get_ticks_msec()
		2:
			if t > 0.8:
				_comprobar_movimiento()
				# Bot1 lanza una bola de fuego a Bot2; Bot2 atrapa a Bot1 con la prisión de agua.
				var id1 := int(bots[0]["id"])
				var id2 := int(bots[1]["id"])
				var j1 := servidor.entidad(id1)
				var j2 := servidor.entidad(id2)
				# Zona libre de muñecos (están en x = -4, 0, 4 cerca de z = -3).
				j1.pos = Vector3(7, 0, 6)
				j2.pos = Vector3(7, 0, 0)
				j1.yaw = PI
				j2.yaw = 0.0
				j1.chakra = 999.0
				j2.chakra = 999.0
				bots[0]["eventos"] = []
				bots[1]["eventos"] = []
				(bots[0]["red"] as TransporteENet).enviar({"t": Protocolo.C_ACCION, "id": "bola_fuego", "objetivo": id2, "dir": Vector2(0, -1)})
				_fase = 3
				_t0 = Time.get_ticks_msec()
		3:
			if t > 1.5 and not _prision_lanzada:
				_prision_lanzada = true
				(bots[1]["red"] as TransporteENet).enviar({"t": Protocolo.C_ACCION, "id": "prision_agua", "objetivo": int(bots[0]["id"])})
			if t > 3.5:
				_comprobar_jutsus()
				_fase = 4
				_t0 = Time.get_ticks_msec()
		4:
			# Quieto un momento y comparar lo que ve cada uno con el servidor.
			if t > 1.5:
				_comprobar_mismo_estado()
				comprobar(_desc_b.partidas.has("127.0.0.1"), "descubrimiento: el cliente encuentra la partida anunciada por UDP")
				var r2: TransporteENet = bots[1]["red"]
				comprobar(r2.ping_ms > 0.0, "ping medido con el simulador de latencia (%.0f ms)" % r2.ping_ms)
				# Viaje rápido: cada bot va a un distrito distinto del mapa completo.
				(bots[0]["red"] as TransporteENet).enviar({"t": Protocolo.C_VIAJAR, "distrito": "academia"})
				(bots[1]["red"] as TransporteENet).enviar({"t": Protocolo.C_VIAJAR, "distrito": "mercado"})
				_fase = 6
				_t0 = Time.get_ticks_msec()
		6:
			if t > 2.5:
				_comprobar_distritos()
				# Llenar la partida: anfitrión + 2 bots + 1 más = 4; el quinto se rechaza.
				_extra.append(_crear_bot("Bot3", false))
				_fase = 5
				_t0 = Time.get_ticks_msec()
		5:
			if t > 1.5 and _extra.size() == 1:
				_extra.append(_crear_bot("Bot4", false))
			if t > 4.0:
				comprobar(int(_extra[0]["id"]) >= 0, "un tercer invitado entra (4 jugadores en total)")
				comprobar(_rechazado and int(_extra[1]["id"]) < 0, "el quinto jugador se rechaza: partida llena")
				_terminar()
	return false


func _comprobar_movimiento() -> void:
	var j1 := servidor.entidad(int(bots[0]["id"]))
	var j2 := servidor.entidad(int(bots[1]["id"]))
	comprobar(j1 != null and j1.pos.distance_to(j1.inicio) > 2.0, "el bot 1 se movió en el servidor (%.1f m)" % (j1.pos.distance_to(j1.inicio) if j1 else 0.0))
	comprobar(j2 != null and j2.pos.distance_to(j2.inicio) > 1.0, "el bot 2 (con mala conexión simulada) se movió (%.1f m)" % (j2.pos.distance_to(j2.inicio) if j2 else 0.0))
	comprobar(j1.nombre == "Bot1" and j1.naturalezas == ["fuego", "tierra"], "el servidor usa el personaje de cada bot")


func _comprobar_jutsus() -> void:

	var id1 := int(bots[0]["id"])
	var id2 := int(bots[1]["id"])
	var j2 := servidor.entidad(id2)
	comprobar(j2.vida < float(j2.stats["vida_max"]), "la bola de fuego de un jugador daña a otro jugador (%.0f / %.0f)" % [j2.vida, j2.stats["vida_max"]])
	for b in bots:
		var vio_impacto := false
		var vio_control := false
		for ev in b["eventos"]:
			if ev["tipo"] == "impacto" and int(ev["entidad"]) == id2 and str(ev["jutsu"]) == "bola_fuego":
				vio_impacto = true
			if ev["tipo"] == "control" and int(ev["entidad"]) == id1:
				vio_control = true
		comprobar(vio_impacto and vio_control, "%s ve el impacto y la prisión de agua (eventos fiables)" % b["nombre"])


## En distritos distintos (a más de 100 m) los bots se siguen viendo con la posición exacta del servidor.
func _comprobar_distritos() -> void:
	var j1 := servidor.entidad(int(bots[0]["id"]))
	var j2 := servidor.entidad(int(bots[1]["id"]))
	var d1 := servidor.mapa.distrito_en(j1.pos2())
	var d2 := servidor.mapa.distrito_en(j2.pos2())
	comprobar(d1 == "academia" and d2 == "mercado", "viaje rápido: Bot1 en %s y Bot2 en %s (%.0f m entre ellos)" % [d1, d2, j1.pos.distance_to(j2.pos)])
	for b in bots:
		var otro := j2 if b == bots[0] else j1
		var visto := false
		var detalle := "no está"
		for e in (b["ultimo"] as Dictionary).get("entidades", []):
			if int(e["id"]) == otro.id:
				detalle = "a %.2f m de su posición real" % (e["pos"] as Vector3).distance_to(otro.pos)
			# Margen de 0,3 m: el bot 2 simula mala conexión (latencia y pérdida) y su última instantánea puede ir un tick atrás.
			if int(e["id"]) == otro.id and (e["pos"] as Vector3).distance_to(otro.pos) < 0.3:
				visto = true
		comprobar(visto, "%s ve al otro jugador en su distrito (%s)%s" % [b["nombre"], servidor.mapa.distrito_en(otro.pos2()), "" if visto else " — " + detalle])


func _comprobar_mismo_estado() -> void:
	var ref := {}
	for e in servidor.entidades:
		if not e.oculto:
			ref[e.id] = e
	var nombres_ok := true
	for b in bots:
		var est: Dictionary = b["ultimo"]
		var max_err := 0.0
		var ids := {}
		for e in est.get("entidades", []):
			var se: EntidadServidor = ref.get(int(e["id"]))
			ids[int(e["id"])] = true
			if se == null:
				max_err = INF
				continue
			max_err = maxf(max_err, (e["pos"] as Vector3).distance_to(se.pos))
			max_err = maxf(max_err, absf(float(e["vida"]) - se.vida) * 0.01)
			if se.tipo == "jugador" and str(e.get("nombre", "")) != se.nombre:
				nombres_ok = false
		# Todos los jugadores y lo que está cerca (los enemigos lejanos no se envían: interés por distancia).
		var faltan := 0
		var yo: EntidadServidor = ref.get(int(b["id"]))
		for id in ref.keys():
			var se2: EntidadServidor = ref[id]
			if not ids.has(id) and (se2.tipo != "enemigo" or (yo != null and se2.pos.distance_to(yo.pos) <= ServidorJuego.RADIO_INTERES - 5.0)):
				faltan += 1
		comprobar(faltan == 0 and max_err < 0.05, "%s ve el mismo estado que el servidor (%d entidades, error %.3f)" % [b["nombre"], ids.size(), max_err])
	comprobar(nombres_ok, "todos ven el nombre de cada jugador")
	# Cada invitado recibe el aspecto (personalización) de los demás jugadores.
	for b in bots:
		var vistos := {}
		for inf in b.get("info", []):
			if not (inf.get("aspecto", {}) as Dictionary).is_empty():
				vistos[str(inf["nombre"])] = str(inf["aspecto"].get("peinado", ""))
		var otro := "Bot2" if b["nombre"] == "Bot1" else "Bot1"
		comprobar(vistos.has(otro) and vistos.has("Kaito_anfitrion"), "%s recibe la personalización del otro invitado y del anfitrión %s" % [b["nombre"], str(vistos)])


func probar_prediccion() -> void:
	var p := Prediccion.new()
	p.mapa = Mapa.generar()
	var e := {"pos": Vector3(0, 0, 10), "ultima_entrada": 0, "vel_mov": 6.0, "estado": "libre", "empuje": false, "en_suelo": true}
	p.reconciliar(e)
	for i in 6:
		p.registrar(Vector2(1, 0), 1.0 / 30.0)
	comprobar(p.activa and absf(p.pos.x - 1.2) < 0.01, "predicción: el cliente se mueve al instante (%.2f m)" % p.pos.x)
	# El servidor procesó 3 de las 6 entradas: la predicción reaplica las otras 3.
	e["pos"] = Vector3(0.6, 0, 10)
	e["ultima_entrada"] = 3
	p.reconciliar(e)
	comprobar(absf(p.pos.x - 1.2) < 0.01 and p.entradas.size() == 3, "reconciliación: parte del servidor y reaplica las entradas pendientes")
	e["estado"] = "golpeado"
	p.reconciliar(e)
	comprobar(not p.activa and p.pos == e["pos"], "sin predicción cuando el servidor controla (golpe, jutsu, empuje)")


func _terminar() -> void:
	for b in bots + _extra:
		(b["red"] as TransporteENet).cerrar()
	red_srv.cerrar()
	_desc_a.detener()
	_desc_b.detener()
	print("== Resultado: %d pasadas, %d fallos ==" % [pasadas, fallos])
	quit(1 if fallos > 0 else 0)
