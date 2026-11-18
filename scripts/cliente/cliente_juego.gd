extends Node3D
## Escena de juego (cliente). Solo hace dos cosas:
##   1) Lee la entrada táctil/teclado y manda COMANDOS por el Transporte.
##   2) Dibuja el ESTADO que llega del servidor (personajes, proyectiles, eventos).
## En modo offline crea también el servidor en este mismo proceso.

const ESCENA_MENU := "res://escenas/menu.tscn"

var servidor: ServidorJuego
var transporte: Transporte
var mapa: Mapa
var escenario: Escenario
var camara: CamaraTercera
var efectos: Efectos
var lluvia: Lluvia
var hud: Hud
var sonidos: Sonidos
var indicadores: Indicadores
var tecnicas: EfectosTecnicas
var genericas: EfectosGenericos
var objetivo_fijado := -1
var _apuntado_activo := ""
var _t_pasos := 0.0
var _hitstop_hasta := 0
var _lento_hasta := 0

var mi_id := -1
var _visuales: Dictionary = {}     # id entidad -> {nodo, tipo, destino, yaw, estado, carga}
var _proyectiles: Dictionary = {}  # id proyectil -> {nodo, destino}
var _estado: Dictionary = {}
var _ultimo_mov := Vector2.ZERO
var _t_envio := 0.0
var _mov_prueba := Vector2.ZERO
var _anuncio_fin := ""
var red: TransporteENet = null       # anfitrión: servidor para los invitados; invitado: su transporte
var descubrimiento: Descubrimiento = null
var prediccion: Prediccion = null    # solo como invitado (el anfitrión no tiene latencia)
var _seq_envio := 0.0
var _t_diag := 0.0
var _t_espera := 0.0
var _info: Dictionary = {}         # id entidad -> {nombre, aspecto} (llega del servidor cada medio segundo)


func _ready() -> void:
	Datos.cargar()
	Ajustes.cargar()
	_registrar_teclas()
	mapa = Mapa.generar()
	Engine.time_scale = 1.0
	get_viewport().scaling_3d_scale = float(Ajustes.g("escala_3d", 1.0))
	Ajustes.aplicar_fps()

	sonidos = Sonidos.new()
	sonidos.name = "Sonidos"
	add_child(sonidos)

	escenario = Escenario.new()
	escenario.name = "Escenario"
	add_child(escenario)
	escenario.construir(mapa)

	camara = CamaraTercera.new()
	camara.name = "Camara"
	add_child(camara)
	escenario.camara = camara
	escenario.sonidos = sonidos

	efectos = Efectos.new()
	efectos.name = "Efectos"
	efectos.camara = camara
	efectos.escenario = escenario
	efectos.sonidos = sonidos
	add_child(efectos)

	tecnicas = EfectosTecnicas.new()
	tecnicas.name = "Tecnicas"
	tecnicas.efectos = efectos
	tecnicas.sonidos = sonidos
	add_child(tecnicas)

	genericas = EfectosGenericos.new()
	genericas.name = "Genericas"
	genericas.efectos = efectos
	genericas.sonidos = sonidos
	add_child(genericas)
	tecnicas.genericas = genericas

	indicadores = Indicadores.new()
	indicadores.name = "Indicadores"
	add_child(indicadores)

	lluvia = Lluvia.new()
	lluvia.name = "Lluvia"
	add_child(lluvia)
	lluvia.construir()
	lluvia.objetivo = camara

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	Perfil.cargar()
	hud.construir(Perfil.repertorio())
	hud.accion.connect(_on_accion)
	hud.apuntar.connect(_on_apuntar)
	hud.soltar.connect(_on_soltar)
	hud.cancelar.connect(func(_id): _apuntado_activo = ""; indicadores.ocultar_apuntado())
	hud.fijar_pedido.connect(_ciclar_objetivo)
	hud.reinicio_pedido.connect(func(): get_tree().reload_current_scene())
	hud.nivel_pedido.connect(func(n): transporte.enviar({"t": Protocolo.C_NIVEL, "valor": n}))
	hud.reaparecer_pedido.connect(func(): transporte.enviar({"t": Protocolo.C_REAPARECER}))
	hud.salir_pedido.connect(func(): get_tree().change_scene_to_file(ESCENA_MENU))
	hud.camara_arrastre.connect(func(r): camara.girar(r * Ajustes.sensibilidad))

	if Sesion.modo == "cliente":
		_iniciar_invitado()
		return
	# Offline y anfitrión: servidor autoritativo en este mismo proceso, misma interfaz que en red.
	servidor = ServidorJuego.new()
	servidor.name = "Servidor"
	add_child(servidor)
	servidor.iniciar(mapa)
	servidor.poblar_entrenamiento()
	var local := TransporteLocal.new()
	local.name = "Transporte"
	add_child(local)
	transporte = local
	_conectar_transporte()
	local.iniciar(servidor)
	if Sesion.modo == "anfitrion":
		_iniciar_anfitrion()

	var aldea := Datos.aldea("lluvia")
	hud.mensaje(Datos.texto("msg_bienvenida", [aldea.get("nombre_largo", "")]), 3.0)


func _conectar_transporte() -> void:
	transporte.conectado.connect(func(id):
		mi_id = id
		# Personaje creado y repertorio elegido en el menú (el servidor valida ambos con las mismas reglas).
		if red != null and not red.es_servidor:
			hud.poner_info_red("")
		if not Perfil.personaje().is_empty():
			transporte.enviar(Perfil.comando_personaje())
		transporte.enviar(Perfil.comando()))
	transporte.estado_recibido.connect(_on_estado)


## Partida local: este celular es el servidor con autoridad y además juega. Anuncia la partida en el Wi-Fi.
func _iniciar_anfitrion() -> void:
	red = TransporteENet.new()
	red.name = "Red"
	add_child(red)
	var err := red.crear_servidor(servidor)
	if err != OK:
		hud.mensaje(Datos.texto("red_error_crear", [err]), 5.0)
		return
	descubrimiento = Descubrimiento.new()
	descubrimiento.name = "Descubrimiento"
	add_child(descubrimiento)
	descubrimiento.anunciar({"nombre": Perfil.nombre_activo(), "jugadores": 1, "max": int(Datos.red.get("max_jugadores", 4)),
		"puerto": int(Datos.red.get("puerto", 7777))})
	var ips := TransporteENet.ips_locales()
	hud.poner_info_red(Datos.texto("red_anfitrion_info", [", ".join(ips) if not ips.is_empty() else "?", int(Datos.red.get("puerto", 7777))]))


## Invitado: se conecta a la IP del anfitrión. Solo manda comandos; predice su propio movimiento.
func _iniciar_invitado() -> void:
	red = TransporteENet.new()
	red.name = "Red"
	add_child(red)
	red.simular = Ajustes.simular_red
	transporte = red
	prediccion = Prediccion.new()
	prediccion.mapa = mapa
	_conectar_transporte()
	red.rechazado.connect(func(motivo): _salir_con_mensaje(Datos.texto("red_rechazo_" + str(motivo))))
	red.desconectado.connect(func(): _salir_con_mensaje(Datos.texto("red_desconectado")))
	var err := red.unirse(Sesion.direccion)
	if err != OK:
		_salir_con_mensaje(Datos.texto("red_rechazo_sin_respuesta"))
		return
	_t_espera = float(Datos.red.get("tiempo_espera_conexion", 8.0))
	hud.poner_info_red(Datos.texto("red_conectando", [Sesion.direccion]))


func _salir_con_mensaje(t: String) -> void:
	hud.banner(t, Datos.texto("red_volviendo"))
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(func(): get_tree().change_scene_to_file(ESCENA_MENU))


func _registrar_teclas() -> void:
	var teclas := {
		"mover_arriba": [KEY_W, KEY_UP], "mover_abajo": [KEY_S, KEY_DOWN],
		"mover_izq": [KEY_A, KEY_LEFT], "mover_der": [KEY_D, KEY_RIGHT],
		"golpe": [KEY_J], "ranura1": [KEY_K], "ranura2": [KEY_L], "ranura3": [KEY_U], "ranura4": [KEY_I], "modo": [KEY_Q],
		"esquivar": [KEY_SHIFT], "saltar": [KEY_SPACE],
	}
	for accion_n in teclas.keys():
		if InputMap.has_action(accion_n):
			continue
		InputMap.add_action(accion_n)
		for k in teclas[accion_n]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(accion_n, ev)


func _unhandled_input(ev: InputEvent) -> void:
	for a in Protocolo.ACCIONES:
		if ev.is_action_pressed(a, false, true):
			_on_accion(a)
	var activos: Array = Perfil.repertorio()["activos"]
	for i in 4:
		if ev.is_action_pressed("ranura%d" % (i + 1), false, true) and i < activos.size() and str(activos[i]) != "":
			_on_accion(str(activos[i]))


func _exit_tree() -> void:
	Perfil.guardar()


## Nivel efectivo que el servidor informa para una técnica del jugador local.
func _nivel_local(id: String) -> int:
	for e in _estado.get("entidades", []):
		if int(e["id"]) == mi_id:
			return int(e.get("niveles", {}).get(id, 1))
	return 1


## Toque rápido: auto-apuntado al objetivo fijado o al enemigo más cercano frente a la cámara;
## si no hay ninguno, hacia donde mira la cámara. La dirección viaja en el comando.
func _on_accion(id: String) -> void:
	var cmd := {"t": Protocolo.C_ACCION, "id": id}
	if id == "golpe" or bool(Datos.jutsu(id).get("apuntable", false)):
		var alcance := _alcance(id)
		var obj := _objetivo_auto(alcance)
		var dir := _dir_camara()
		if obj >= 0:
			var p := _pos_entidad(obj) - _pos_entidad(mi_id)
			dir = Vector2(p.x, p.z).normalized()
		cmd["dir"] = dir
		cmd["objetivo"] = obj
	transporte.enviar(cmd)


func _alcance(id: String) -> float:
	if id == "golpe":
		return 3.5
	var j := Datos.jutsu(id)
	if str(j.get("mecanica", "")) == "embiste":
		return float(Datos.nivel_jutsu(id, _nivel_local(id)).get("distancia", 6.0)) + 3.0
	return float(j.get("alcance", 20.0))


func _dir_camara() -> Vector2:
	var f := camara.adelante_plano()
	return Vector2(f.x, f.z).normalized()


## Arrastre en pantalla -> dirección en el suelo (relativa a la cámara).
func _dir_arrastre(arrastre: Vector2) -> Vector2:
	var adelante := camara.adelante_plano()
	var derecha := Vector3(-adelante.z, 0, adelante.x)
	var m := derecha * arrastre.x + adelante * (-arrastre.y)
	return Vector2(m.x, m.z).normalized()


## Objetivo para el auto-apuntado: el fijado si es válido; si no, el más cercano frente a la cámara.
func _objetivo_auto(alcance: float) -> int:
	if objetivo_fijado >= 0 and _vivo(objetivo_fijado):
		return objetivo_fijado
	var yo := _pos_entidad(mi_id)
	var f := camara.adelante_plano()
	var mejor := -1
	var mejor_p := INF
	for e in _estado.get("entidades", []):
		var eid := int(e["id"])
		if eid == mi_id or str(e["estado"]) == "muerto":
			continue
		var d: Vector3 = (e["pos"] as Vector3) - yo
		d.y = 0
		var dist := d.length()
		if dist > alcance or dist < 0.01:
			continue
		var ang := rad_to_deg(f.angle_to(d / dist))
		if ang > 65.0:
			continue
		var puntaje := dist + ang * 0.12 + (5.0 if e["tipo"] == "muneco" else 0.0)
		if puntaje < mejor_p:
			mejor_p = puntaje
			mejor = eid
	return mejor


func _vivo(eid: int) -> bool:
	for e in _estado.get("entidades", []):
		if int(e["id"]) == eid:
			return str(e["estado"]) != "muerto"
	return false


func _on_apuntar(id: String, arrastre: Vector2, cancelar: bool) -> void:
	_apuntado_activo = id
	var dir := _dir_arrastre(arrastre)
	var yo := _pos_entidad(mi_id)
	var nd := Datos.nivel_jutsu(id, _nivel_local(id))
	var color := Hud.color_de(id).lightened(0.45)
	if str(Datos.jutsu(id).get("mecanica", "")) == "embiste":
		# Flecha de embiste del largo real del nivel.
		indicadores.mostrar_apuntado(yo, Vector3(dir.x, 0, dir.y), float(nd.get("distancia", 8.0)), 1.1, color, true, cancelar)
	else:
		var ancho := maxf(float(nd.get("radio", 0.6)) * 2.0 * 0.9 + 0.4, 1.0)
		indicadores.mostrar_apuntado(yo, Vector3(dir.x, 0, dir.y), minf(_alcance(id), 22.0), ancho, color, false, cancelar)


## Soltar tras arrastrar: dispara en la dirección exacta del dedo (sin asistencia).
func _on_soltar(id: String, arrastre: Vector2) -> void:
	_apuntado_activo = ""
	indicadores.ocultar_apuntado()
	var dir := _dir_arrastre(arrastre)
	transporte.enviar({"t": Protocolo.C_ACCION, "id": id, "dir": dir, "objetivo": -1, "exacto": true})


## Fijar objetivo: el primer toque fija el más cercano; los siguientes rotan entre
## los objetivos cercanos y, tras el último, se libera.
func _ciclar_objetivo() -> void:
	var yo := _pos_entidad(mi_id)
	var lista: Array = []
	for e in _estado.get("entidades", []):
		if int(e["id"]) == mi_id or str(e["estado"]) == "muerto":
			continue
		var d := ((e["pos"] as Vector3) - yo).length()
		if d < 30.0:
			lista.append([d, int(e["id"]), e])
	lista.sort_custom(func(a, b): return a[0] < b[0])
	var ids: Array = []
	for x in lista:
		ids.append(x[1])
	if ids.is_empty():
		objetivo_fijado = -1
		hud.mensaje(Datos.texto("msg_sin_objetivo"), 1.0)
	elif objetivo_fijado < 0 or not (objetivo_fijado in ids):
		objetivo_fijado = ids[0]
	else:
		var i := ids.find(objetivo_fijado)
		objetivo_fijado = ids[i + 1] if i + 1 < ids.size() else -1
	hud.fijado = objetivo_fijado >= 0
	if objetivo_fijado >= 0:
		var plantilla := ""
		for x in lista:
			if x[1] == objetivo_fijado:
				plantilla = str(x[2]["plantilla"])
		hud.mensaje(Datos.texto("msg_fijado", [Datos.personaje(plantilla).get("nombre", "")]), 1.0)
	elif not ids.is_empty():
		hud.mensaje(Datos.texto("msg_sin_fijar"), 1.0)
	indicadores.objetivo = _visuales[objetivo_fijado]["nodo"] if _visuales.has(objetivo_fijado) else null


## Pausa de impacto (hitstop): congela un instante solo lo visual; el servidor sigue en tiempo real.
func pausa_impacto(segundos: float) -> void:
	_hitstop_hasta = Time.get_ticks_msec() + int(segundos * 1000.0)
	Engine.time_scale = 0.03


func camara_lenta(escala: float, segundos: float) -> void:
	# Sin encadenar cámaras lentas seguidas (varios N3 a la vez).
	var ahora := Time.get_ticks_msec()
	var minimo := int(float(Datos.graficos.get("limites", {}).get("lenta_minimo_entre", 1.2)) * 1000.0)
	if ahora < _lento_hasta + minimo and ahora >= _lento_hasta:
		return
	_lento_hasta = Time.get_ticks_msec() + int(segundos * 1000.0)
	if Time.get_ticks_msec() >= _hitstop_hasta:
		Engine.time_scale = escala
	set_meta("escala_lenta", escala)


func _actualizar_tiempo() -> void:
	var ahora := Time.get_ticks_msec()
	if ahora < _hitstop_hasta:
		Engine.time_scale = 0.03
	elif ahora < _lento_hasta:
		Engine.time_scale = float(get_meta("escala_lenta", 0.3))
	elif Engine.time_scale != 1.0:
		Engine.time_scale = 1.0


# ------------------------------------------------------------ entrada

func _process(delta: float) -> void:
	_actualizar_tiempo()
	_seguir_objetivo(delta)
	var j := hud.joystick.vector
	var teclado := Input.get_vector("mover_izq", "mover_der", "mover_arriba", "mover_abajo")
	if teclado.length() > 0.1:
		j = teclado
	if _mov_prueba != Vector2.ZERO:
		j = _mov_prueba
	var adelante := camara.adelante_plano()
	var derecha := Vector3(-adelante.z, 0, adelante.x)
	var mundo := derecha * j.x + adelante * (-j.y)
	var mov := Vector2(mundo.x, mundo.z)
	if mov.length() > 1.0:
		mov = mov.normalized()
	var mira := atan2(adelante.x, adelante.z)
	# Entrada a ritmo fijo (el del servidor), numerada para la predicción del invitado.
	var paso := 1.0 / 30.0
	_seq_envio += delta / maxf(Engine.time_scale, 0.05)
	var enviados := 0
	while _seq_envio >= paso and enviados < 4:
		_seq_envio -= paso
		enviados += 1
		var seq := prediccion.registrar(mov, paso) if prediccion != null else 0
		transporte.enviar({"t": Protocolo.C_ENTRADA, "mov": mov, "mira": mira, "seq": seq})
	_ultimo_mov = mov
	if prediccion != null and prediccion.activa and _visuales.has(mi_id):
		_visuales[mi_id]["destino"] = prediccion.pos
		if mov.length() > 0.1:
			_visuales[mi_id]["yaw"] = atan2(mov.x, mov.y)
	_interpolar(delta)
	_actualizar_red(delta)


## Con objetivo fijado, la cámara gira para mantener al enemigo delante.
func _seguir_objetivo(delta: float) -> void:
	if objetivo_fijado < 0:
		return
	if not _vivo(objetivo_fijado) or not _visuales.has(objetivo_fijado):
		objetivo_fijado = -1
		hud.fijado = false
		indicadores.objetivo = null
		return
	var d := _pos_entidad(objetivo_fijado) - _pos_entidad(mi_id)
	if Vector2(d.x, d.z).length() < 0.5:
		return
	var yaw_deseado := atan2(-d.x, -d.z)
	camara.yaw = lerp_angle(camara.yaw, yaw_deseado, minf(1.0, delta * 5.0))
	camara.pitch = lerpf(camara.pitch, -0.36, minf(1.0, delta * 2.0))


func _interpolar(delta: float) -> void:
	var k := minf(1.0, delta * 18.0)
	var ahora := Time.get_ticks_msec() / 1000.0
	var retraso := float(Datos.red.get("interpolacion_retraso", 0.1))
	for id in _visuales.keys():
		var v: Dictionary = _visuales[id]
		var n: Node3D = v["nodo"]
		if prediccion != null and id != mi_id and v.has("buf"):
			# Invitado: los demás se dibujan un poco en el pasado, interpolando entre dos instantáneas.
			var p := _muestra(v["buf"], ahora - retraso)
			if not p.is_empty():
				n.position = p[0]
				n.rotation.y = lerp_angle(n.rotation.y, float(p[1]), k)
				continue
		var kp := k
		if prediccion != null and id == mi_id:
			var dist := n.position.distance_to(v["destino"])
			if dist > float(Datos.red["prediccion"].get("teletransporte", 3.0)):
				kp = 1.0
			else:
				kp = minf(1.0, delta * float(Datos.red["prediccion"].get("suavizado", 12.0)))
		n.position = n.position.lerp(v["destino"], kp)
		n.rotation.y = lerp_angle(n.rotation.y, float(v["yaw"]), k)
	for id in _proyectiles.keys():
		var p: Dictionary = _proyectiles[id]
		var pn: Node3D = p["nodo"]
		pn.global_position = pn.global_position.lerp(p["destino"], minf(1.0, delta * 25.0))
		if pn.has_meta("pulso"):
			var nucleo: Node3D = pn.get_meta("pulso")
			nucleo.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.08)


## Posición y giro interpolados en el instante t a partir del búfer [[t, pos, yaw], ...].
func _muestra(buf: Array, t: float) -> Array:
	if buf.is_empty():
		return []
	if t <= float(buf[0][0]):
		return [buf[0][1], buf[0][2]]
	for i in range(buf.size() - 1):
		var a: Array = buf[i]
		var b: Array = buf[i + 1]
		if t >= float(a[0]) and t <= float(b[0]):
			var u := (t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			return [(a[1] as Vector3).lerp(b[1], u), lerp_angle(float(a[2]), float(b[2]), u)]
	var ult: Array = buf[buf.size() - 1]
	return [ult[1], ult[2]]


## Red: diagnóstico (ping, pérdida, jugadores), tiempo de espera de la conexión y anuncio del anfitrión.
func _actualizar_red(delta: float) -> void:
	if red == null:
		hud.diag_red = {}
		return
	if not red.es_servidor and not red.conectado_ok:
		_t_espera -= delta
		if _t_espera <= 0.0 and _t_espera > -1.0:
			_t_espera = -2.0
			_salir_con_mensaje(Datos.texto("red_rechazo_sin_respuesta"))
	_t_diag -= delta
	if _t_diag > 0.0:
		return
	_t_diag = 0.5
	var jugadores := 0
	for e in _estado.get("entidades", []):
		if e["tipo"] == "jugador":
			jugadores += 1
	if red.es_servidor:
		hud.diag_red = {"ping": 0, "perdida": 0.0, "jugadores": jugadores, "simulado": false}
		if descubrimiento != null:
			descubrimiento.info["jugadores"] = jugadores
	else:
		hud.diag_red = {"ping": red.ping_ms, "perdida": red.perdida, "jugadores": jugadores, "simulado": red.simular}


# ------------------------------------------------------------ estado del servidor

func _on_estado(est: Dictionary) -> void:
	_estado = est
	if est.has("tu_entidad"):
		mi_id = int(est["tu_entidad"])
	var vistos := {}
	var yo: Dictionary = {}
	var enemigo: Dictionary = {}
	if est.has("jugadores"):
		for inf in est["jugadores"]:
			var iid := int(inf["id"])
			var cambio_aspecto: bool = _info.has(iid) and JSON.stringify(_info[iid].get("aspecto", {})) != JSON.stringify(inf.get("aspecto", {}))
			var nuevo_info: bool = not _info.has(iid) and not (inf.get("aspecto", {}) as Dictionary).is_empty()
			_info[iid] = inf
			# Si cambió el aspecto (o recién lo conocemos), se reconstruye su figura.
			if (cambio_aspecto or nuevo_info) and _visuales.has(iid):
				(_visuales[iid]["nodo"] as Node).queue_free()
				_visuales.erase(iid)
				if iid == mi_id:
					camara.objetivo = null
	for e in est["entidades"]:
		var id := int(e["id"])
		vistos[id] = true
		if not _visuales.has(id):
			_crear_visual(e)
		_actualizar_visual(_visuales[id], e)
		if id == mi_id:
			yo = e
		elif e["tipo"] == "enemigo":
			enemigo = e
	for id in _visuales.keys():
		if not vistos.has(id):
			(_visuales[id]["nodo"] as Node).queue_free()
			_visuales.erase(id)
	_actualizar_proyectiles(est["proyectiles"])
	tecnicas.sincronizar_zonas(est.get("zonas", []))
	genericas.sincronizar_criaturas(est.get("criaturas", []))
	for ev in est["eventos"]:
		_procesar_evento(ev)
	if not yo.is_empty():
		hud.actualizar(yo, enemigo)
		if _visuales.has(mi_id) and camara.objetivo == null:
			camara.objetivo = _visuales[mi_id]["nodo"]
		_comprobar_fin(yo, enemigo)


func _crear_visual(e: Dictionary) -> void:
	var nodo: Node3D
	if e["tipo"] == "muneco":
		var m := MunecoVisual.new()
		add_child(m)
		m.construir()
		nodo = m
	else:
		var pv := PersonajeVisual.new()
		add_child(pv)
		var asp: Dictionary = _info.get(int(e["id"]), {}).get("aspecto", {})
		if asp.is_empty() and int(e["id"]) == mi_id and not Perfil.personaje().is_empty():
			asp = Creacion.aspecto_visual(Perfil.personaje())
			asp["clan"] = str(Perfil.personaje().get("clan", ""))
		if asp.is_empty():
			pv.construir(str(e["plantilla"]))
		else:
			pv.construir_aspecto(asp, str(asp.get("aldea", "lluvia")), str(asp.get("clan", "")))
		nodo = pv
	nodo.name = "Entidad_%d" % int(e["id"])
	nodo.position = e["pos"]
	nodo.rotation.y = float(e["yaw"])
	_visuales[int(e["id"])] = {"nodo": nodo, "tipo": e["tipo"], "destino": e["pos"], "yaw": e["yaw"], "estado": "", "carga": null, "vel": 0.0, "paso": -1}
	if red != null and e["tipo"] != "muneco":
		var placa := Placa.new()
		nodo.add_child(placa)
		var propio := int(e["id"]) == mi_id
		placa.construir(str(e.get("nombre", "")), Color(0.6, 1.0, 0.65) if propio else (Color(1.0, 0.85, 0.5) if e["tipo"] == "jugador" else Color(1.0, 0.55, 0.5)))
		_visuales[int(e["id"])]["placa"] = placa


func _actualizar_visual(v: Dictionary, e: Dictionary) -> void:
	var nuevo: Vector3 = e["pos"]
	var antes: Vector3 = v["destino"]
	var d := Vector2(nuevo.x - antes.x, nuevo.z - antes.z).length() * 30.0
	v["vel"] = lerpf(float(v["vel"]), d, 0.5)
	v["destino"] = nuevo
	v["yaw"] = float(e["yaw"])
	if prediccion != null:
		if int(e["id"]) == mi_id:
			prediccion.reconciliar(e)
			if prediccion.activa:
				v["destino"] = prediccion.pos
		elif v["tipo"] != "muneco":
			var buf: Array = v.get("buf", [])
			buf.append([Time.get_ticks_msec() / 1000.0, nuevo, float(e["yaw"])])
			while buf.size() > 12:
				buf.pop_front()
			v["buf"] = buf
	# Nombre y vida sobre los jugadores (y el enemigo) cuando hay más de un jugador.
	if v.has("placa"):
		var nom := str(_info.get(int(e["id"]), {}).get("nombre", e.get("nombre", "")))
		(v["placa"] as Placa).actualizar(nom, float(e["vida"]) / maxf(float(e["vida_max"]), 1.0))
	var estado := str(e["estado"])
	var cambio := estado != str(v["estado"])
	v["estado"] = estado
	# Salpicaduras al pisar charcos y al aterrizar en ellos.
	if v["tipo"] != "muneco":
		var en_suelo := bool(e["en_suelo"])
		if bool(e["en_charco"]) and en_suelo:
			if not bool(v.get("suelo", true)):
				efectos.chapoteo(nuevo, 1.6)
				sonidos.tocar("chapoteo", -4.0)
			elif float(v["vel"]) > 1.5:
				v["t_paso"] = float(v.get("t_paso", 0.0)) - 1.0 / 30.0
				if float(v["t_paso"]) <= 0.0:
					v["t_paso"] = 0.3
					efectos.chapoteo(nuevo, 0.7)
					if int(e["id"]) == mi_id:
						sonidos.tocar("chapoteo", -14.0, 1.3)
		v["suelo"] = en_suelo
	if v["tipo"] == "muneco":
		var mu: MunecoVisual = v["nodo"]
		mu.poner_caido(estado == "muerto")
		return
	var pv: PersonajeVisual = v["nodo"]
	var modo := str(e.get("modo", ""))
	pv.poner_ojos(int(Datos.jutsu(modo).get("patron", 0)) if bool(e.get("modo_activo", false)) and modo in Tecnicas.OJOS else 0)
	tecnicas.sincronizar(int(e["id"]), pv, e)
	genericas.sincronizar(int(e["id"]), pv, e)
	match estado:
		"muerto", "caido":
			pv.reproducir("caer", 0.08)
		"golpeado":
			if cambio:
				pv.reproducir_forzado("golpeado")
		"golpe":
			var paso := int(e["paso"])
			if cambio or paso != int(v["paso"]):
				pv.reproducir_forzado("golpe%d" % (paso + 1))
			v["paso"] = paso
		"sellos":
			pv.reproducir("sellos", 0.1)
		"chidori_carga":
			pv.reproducir("chidori_carga", 0.1)
		"chidori_embiste":
			pv.reproducir("chidori_embiste", 0.05)
		"lanzar", "rafaga", "kirin":
			pv.reproducir("lanzar", 0.08)
		"esquiva":
			pv.reproducir("esquivar", 0.05)
		_:
			if not bool(e["en_suelo"]):
				pv.reproducir("saltar", 0.1)
			elif float(v["vel"]) > 1.0:
				pv.reproducir("correr", 0.15)
			elif e["tipo"] == "enemigo":
				pv.reproducir("guardia", 0.2)
			else:
				pv.reproducir("quieto", 0.2)
	if estado != "golpe":
		v["paso"] = -1
	# El rayo de la mano dura mientras carga o embiste.
	var carga = v["carga"]
	if carga != null and is_instance_valid(carga):
		if estado == "chidori_embiste":
			if carga is CargaRayo:
				(carga as CargaRayo).embistiendo = true
		elif estado != "chidori_carga":
			(carga as Node).queue_free()
			v["carga"] = null


func _actualizar_proyectiles(lista: Array) -> void:
	var vistos := {}
	for p in lista:
		var id := int(p["id"])
		vistos[id] = true
		if not _proyectiles.has(id):
			var nodo: Node3D = genericas.crear_proyectil(p) if str(p.get("forma", "")) != "" else efectos.crear_proyectil(p)
			_proyectiles[id] = {"nodo": nodo, "destino": p["pos"]}
		else:
			_proyectiles[id]["destino"] = p["pos"]
	for id in _proyectiles.keys():
		if not vistos.has(id):
			var n: Node3D = _proyectiles[id]["nodo"]
			# Deja que las partículas se apaguen antes de borrar.
			for c in n.get_children():
				if c is GPUParticles3D:
					(c as GPUParticles3D).emitting = false
				elif c is MeshInstance3D or c is OmniLight3D:
					c.visible = false
			var tw := create_tween()
			tw.tween_interval(1.0)
			tw.tween_callback(n.queue_free)
			_proyectiles.erase(id)


func _pos_entidad(id: int) -> Vector3:
	if _visuales.has(id):
		return (_visuales[id]["nodo"] as Node3D).global_position
	return Vector3.ZERO


func _procesar_evento(ev: Dictionary) -> void:
	var id := int(ev.get("entidad", -1))
	tecnicas.evento(ev, mi_id, _pos_entidad, func(eid): return _visuales[eid]["nodo"] if _visuales.has(eid) else null, camara_lenta)
	genericas.evento(ev, mi_id, _pos_entidad, func(eid): return _visuales[eid]["nodo"] if _visuales.has(eid) else null, camara_lenta)
	match str(ev["tipo"]):
		"maestria":
			if id == mi_id:
				Perfil.maestria[str(ev["jutsu"])] = float(ev["xp"])
				if ev.get("subio", false):
					hud.mensaje(Datos.texto("msg_maestria", [Datos.jutsu(str(ev["jutsu"])).get("nombre", ""), int(ev["nivel"])]), 2.5)
					Perfil.guardar()
		"repertorio":
			if id == mi_id:
				hud.construir({"activos": ev.get("activos", []), "modo": ev.get("modo", ""), "niveles_max": ev.get("niveles_max", {})})
		"modo":
			if id == mi_id:
				hud.mensaje(("%s ✓" if ev["activo"] else "%s ✗") % Datos.jutsu(str(ev["modo"])).get("nombre", ""), 1.2)
		"sellos":
			if id == mi_id:
				hud.mostrar_sellos(ev["sellos"], float(ev["duracion"]))
		"lanzar":
			if str(ev["jutsu"]) == "bola_fuego":
				var nd := Datos.nivel_jutsu("bola_fuego", int(ev["nivel"]))
				efectos.luz_temporal(ev["pos"], Efectos.COLOR_FUEGO, float(nd.get("luz", 3.0)) * 1.5, float(nd.get("luz_rango", 6.0)), 0.3)
				efectos.sacudir_desde(ev["pos"], float(nd.get("sacudida", 0.2)) * 0.4)
				if id == mi_id and int(ev["nivel"]) >= 3:
					var imp: Dictionary = Datos.graficos.get("impacto", {})
					camara_lenta(float(imp.get("camara_lenta_escala", 0.3)), float(imp.get("camara_lenta_duracion", 0.45)))
		"chidori_carga":
			if _visuales.has(id) and _visuales[id]["nodo"] is PersonajeVisual:
				var anterior = _visuales[id]["carga"]
				if anterior != null and is_instance_valid(anterior):
					anterior.queue_free()
				if str(ev.get("jutsu", "chidori")) == "rasengan":
					_visuales[id]["carga"] = tecnicas.crear_esfera_mano(_visuales[id]["nodo"], int(ev["nivel"]))
				else:
					_visuales[id]["carga"] = efectos.crear_carga_rayo(_visuales[id]["nodo"], int(ev["nivel"]))
		"chidori_embiste":
			efectos.polvo(ev["desde"], 10 + int(ev["nivel"]) * 10)
			if id == mi_id and int(ev["nivel"]) >= 3:
				var imp2: Dictionary = Datos.graficos.get("impacto", {})
				camara_lenta(float(imp2.get("camara_lenta_escala", 0.3)), float(imp2.get("camara_lenta_duracion", 0.45)) * 0.7)
		"impacto":
			_evento_impacto(ev)
		"explosion":
			if ev.has("forma"):
				genericas.explosion(ev)
			else:
				efectos.explosion(ev)
		"cadena":
			efectos.cadena(ev["puntos"], int(ev["nivel"]))
			if id == mi_id:
				hud.mensaje(Datos.texto("msg_cadena", [ev["saltos"]]))
		"aviso":
			if _sharingan_local():
				efectos.aviso(ev["desde"], ev["hacia"], float(ev["duracion"]), str(ev.get("subtipo", "")) == "melee")
		"esquiva", "salto":
			efectos.polvo(_pos_entidad(id), 10)
		"derrota":
			efectos.polvo(_pos_entidad(id), 24)
		"sharingan":
			if id == mi_id:
				hud.mensaje(Datos.texto("msg_sharingan_on" if ev["activo"] else "msg_sharingan_off"), 1.2)
		"nivel":
			if id == mi_id:
				hud.poner_nivel(int(ev["nivel"]))
		"reaparecer":
			_anuncio_fin = ""
			hud.banner("")
			for v in _visuales.values():
				if v["carga"] != null and is_instance_valid(v["carga"]):
					v["carga"].queue_free()
				v["carga"] = null
		"mensaje":
			if id == mi_id or ev.get("para_todos", false):
				hud.mensaje(Datos.texto(str(ev["clave"]), ev.get("args", [])), 4.0 if str(ev["clave"]).begins_with("rep_") else 1.5)


const COLOR_NATURALEZA := {"fuego": Color(1.0, 0.55, 0.15), "rayo": Color(0.55, 0.88, 1.0), "agua": Color(0.4, 0.68, 1.0),
	"fuego_negro": Color(0.75, 0.45, 1.0), "": Color(1.0, 0.97, 0.9)}


func _evento_impacto(ev: Dictionary) -> void:
	var pos: Vector3 = ev["pos"]
	var jutsu := str(ev["jutsu"])
	var cant := float(ev["cantidad"])
	var nat := str(Datos.jutsu(jutsu).get("naturaleza", "")) if jutsu != "golpe" else ""
	var color: Color = COLOR_NATURALEZA.get(nat, Color.WHITE)
	if nat == "" and jutsu != "golpe" and Datos.jutsu(jutsu).has("color"):
		color = Color.html(str(Datos.jutsu(jutsu)["color"])).lightened(0.2)
	var imp: Dictionary = Datos.graficos.get("impacto", {})
	var involucra_me := int(ev["atacante"]) == mi_id or int(ev["entidad"]) == mi_id
	match jutsu:
		"chidori":
			if not ev["cadena"]:
				efectos.impacto_rayo(pos, int(ev["nivel"]))
				if involucra_me:
					pausa_impacto(float(imp.get("pausa_rayo", 0.09)))
		"bola_fuego":
			if involucra_me and int(ev["nivel"]) >= 2:
				pausa_impacto(float(imp.get("pausa_golpe_fuerte", 0.07)) * 0.7)
		"bala_agua", "kirin", "amaterasu", "susanoo", "shinra_tensei", "flecha_susanoo":
			pass
		"rasengan":
			tecnicas.impacto_esfera(pos, int(ev["nivel"]))
			if involucra_me:
				pausa_impacto(float(imp.get("pausa_golpe_fuerte", 0.07)))
		_:
			var fuerte := cant > 10.0
			efectos.golpe_fisico(pos, fuerte)
			sonidos.tocar("golpe", -2.0 if fuerte else -6.0, 0.8 if fuerte else 1.1)
			if fuerte and involucra_me:
				pausa_impacto(float(imp.get("pausa_golpe_fuerte", 0.07)))
	var mult := float(ev["naturaleza_mult"])
	efectos.numero(pos, cant, color, mult)
	var objetivo := int(ev["entidad"])
	if _visuales.has(objetivo) and _visuales[objetivo]["nodo"] is MunecoVisual:
		(_visuales[objetivo]["nodo"] as MunecoVisual).golpeado()
	if objetivo == mi_id:
		camara.sacudir(0.3)
		Ajustes.vibrar(40)
	if int(ev["atacante"]) == mi_id and mult > 1.01:
		hud.mensaje(Datos.texto("msg_ventaja"), 1.0)


func _sharingan_local() -> bool:
	for e in _estado.get("entidades", []):
		if int(e["id"]) == mi_id:
			return bool(e["sharingan"])
	return false


func _comprobar_fin(yo: Dictionary, enemigo: Dictionary) -> void:
	var fin := ""
	if str(yo["estado"]) == "muerto":
		fin = "derrota"
	elif not enemigo.is_empty() and str(enemigo["estado"]) == "muerto":
		fin = "victoria"
	if fin == _anuncio_fin:
		return
	_anuncio_fin = fin
	match fin:
		"derrota":
			hud.banner(Datos.texto("msg_derrotado"), Datos.texto("msg_reaparecer_hint"))
		"victoria":
			hud.banner(Datos.texto("msg_victoria"), Datos.texto("msg_reaparecer_hint"))
		_:
			hud.banner("")


## Usado por tests/humo.gd para ejercitar el cliente completo sin pantalla.
func prueba_humo(frame: int) -> void:
	match frame:
		5: _mov_prueba = Vector2(0.3, -1.0)
		40: _mov_prueba = Vector2.ZERO
		45: _on_accion("sharingan")
		50: _on_accion("bola_fuego")
		90: transporte.enviar({"t": Protocolo.C_NIVEL, "valor": 3})
		95: _on_accion("chidori")
		150: _on_accion("kirin")
		200: _on_accion("golpe")
		210: _on_accion("golpe")
		220: _on_accion("golpe")
		250: _on_accion("esquivar")
		270: _on_accion("saltar")
		300: transporte.enviar({"t": Protocolo.C_REAPARECER})
		320: transporte.enviar({"t": Protocolo.C_NIVEL, "valor": 2})
		325: _on_accion("chidori")
		340: _ciclar_objetivo()
		345: _on_apuntar("bola_fuego", Vector2(40, -80), false)
		350: _on_soltar("bola_fuego", Vector2(40, -80))
		360: _on_apuntar("chidori", Vector2(-60, -40), true)
		365: hud.cancelar.emit("chidori")
		370: _ciclar_objetivo()
		375: pausa_impacto(0.05)
		380: camara_lenta(0.3, 0.1)
		390: hud.abrir_ajustes()
		# Primer bloque del repertorio (modo prueba).
		400: transporte.enviar({"t": Protocolo.C_REPERTORIO, "activos": ["rasengan", "amaterasu", "susanoo", "kirin"], "modo": "mangekyo", "prueba": true})
		405: _on_accion("modo")
		410: _on_accion("rasengan")
		440: _on_accion("amaterasu")
		470: _on_accion("susanoo")
		520: transporte.enviar({"t": Protocolo.C_REPERTORIO, "activos": ["shinra_tensei", "", "", ""], "modo": "rinnegan", "prueba": true})
		525: _on_accion("modo")
		530: _on_accion("shinra_tensei")
		560: transporte.enviar({"t": Protocolo.C_REPERTORIO, "activos": ["", "", "", ""], "modo": "ocho_puertas", "prueba": true})
		565: _on_accion("modo")
		570: _on_accion("golpe")
		580: _on_accion("golpe")
		590: _on_accion("golpe")
		# Mecánicas genéricas (salva, área, invocación, aura, teletransporte) con sus visuales.
		594: transporte.enviar({"t": Protocolo.C_REPERTORIO, "activos": ["dragon_agua", "madera", "golem_tierra", "hiraishin"], "modo": "modo_sabio", "prueba": true})
		596: _on_accion("modo")
		598: _on_accion("dragon_agua")
		606: _on_accion("madera")
		614: _on_accion("golem_tierra")
		622: _on_accion("hiraishin")
		626: transporte.enviar({"t": Protocolo.C_REPERTORIO, "activos": ["muro_tierra", "rasenshuriken", "", ""], "modo": "", "prueba": true})
		628: _on_accion("muro_tierra")
		632: _on_accion("rasenshuriken")
