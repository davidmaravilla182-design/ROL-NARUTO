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
var ui_mision: UiMision
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
	hud.configurar_mapa(mapa)
	hud.construir(Perfil.repertorio())
	ui_mision = UiMision.new()
	ui_mision.sonidos = sonidos
	hud.add_child(ui_mision)
	var attrs_pj: Dictionary = Perfil.atributos().duplicate()
	var ent_pj: Dictionary = Perfil.personaje().get("entreno", {})
	var bonus := {}
	for k in ent_pj.keys():
		bonus[k] = float(ent_pj[k]) * float(Datos.reglas.get("entrenamiento", {}).get("bonus_max", 0.5))
	attrs_pj["_entreno"] = bonus
	hud.atributos_jugador = attrs_pj
	hud.viajar_pedido.connect(func(id): transporte.enviar({"t": Protocolo.C_VIAJAR, "distrito": id}))
	hud.interactuar_pedido.connect(_interactuar)
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
	servidor.poblar_aldea()
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
		transporte.enviar(Perfil.comando())
		if Sesion.mision_pendiente != "":
			transporte.enviar({"t": Protocolo.C_MISION, "accion": "empezar", "id": Sesion.mision_pendiente})
			Sesion.mision_pendiente = "")
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
	elif id == "esquivar" and objetivo_fijado >= 0 and _vivo(objetivo_fijado):
		# Con un objetivo fijado, esquivar es el shunshin: aparece detrás de él.
		cmd["objetivo"] = objetivo_fijado
	transporte.enviar(cmd)


func _alcance(id: String) -> float:
	if id == "golpe":
		return float(Datos.jutsu("golpe").get("acercar", 3.5))
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
	_buscar_interaccion(delta)
	_actualizar_red(delta)


## Orientación de la figura: giro normal en el suelo; corriendo por una pared, de pie sobre ella
## (los pies en la pared, el cuerpo perpendicular y la cabeza hacia arriba) con una inclinación leve hacia adelante.
func _orientar(n: Node3D, v: Dictionary, yaw: float, k: float, delta: float, desplazar: bool) -> void:
	v["yaw_vis"] = lerp_angle(float(v.get("yaw_vis", yaw)), yaw, k)
	var pared: Vector3 = v.get("pared", Vector3.ZERO)
	var meta := 1.0 if pared != Vector3.ZERO else 0.0
	var t := move_toward(float(v.get("en_pared", 0.0)), meta, delta * 7.0)
	v["en_pared"] = t
	var normal := Basis(Vector3.UP, float(v["yaw_vis"]))
	if t <= 0.001:
		n.basis = normal
		v.erase("pared_vis")
		return
	if pared != Vector3.ZERO:
		v["pared_vis"] = pared
	var pn: Vector3 = v.get("pared_vis", Vector3.FORWARD)
	# y = normal de la pared (el cuerpo sale de ella), z = arriba (hacia donde corre), x = y × z.
	var en_pared := Basis(pn.cross(Vector3.UP).normalized(), pn, Vector3.UP).orthonormalized()
	en_pared = en_pared * Basis(Vector3.RIGHT, deg_to_rad(12.0))   # inclinación leve hacia adelante
	n.basis = Basis(normal.get_rotation_quaternion().slerp(en_pared.get_rotation_quaternion(), t))
	if desplazar:
		n.position -= pn * 0.42 * t   # los pies tocan la pared (en el resto, ya va en "destino")


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
				_orientar(n, v, float(p[1]), k, delta, true)
				continue
		var kp := k
		var dist_v := n.position.distance_to(v["destino"])
		if dist_v > float(Datos.red["prediccion"].get("teletransporte", 3.0)):
			kp = 1.0   # shunshin, sustitución, reaparecer: salto instantáneo (sin deslizarse)
		elif prediccion != null and id == mi_id:
			kp = minf(1.0, delta * float(Datos.red["prediccion"].get("suavizado", 12.0)))
		n.position = n.position.lerp(v["destino"], kp)
		_orientar(n, v, float(v["yaw"]), k, delta, false)
	# Corriendo por una pared, la cámara se aparta de ella y mira un poco hacia arriba (acompaña el giro).
	if _visuales.has(mi_id) and (_visuales[mi_id].get("pared", Vector3.ZERO) as Vector3) != Vector3.ZERO and not camara.libre:
		var pn: Vector3 = _visuales[mi_id]["pared"]
		camara.yaw = lerp_angle(camara.yaw, atan2(pn.x, pn.z), minf(1.0, delta * 3.0))
		camara.pitch = lerpf(camara.pitch, 0.12, minf(1.0, delta * 3.0))
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
			if (a[1] as Vector3).distance_to(b[1]) > 3.0:
				return [b[1], b[2]] if u > 0.0 else [a[1], a[2]]   # teletransporte: sin interpolar
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
	var enemigos: Array = []
	var jefe_e: Dictionary = {}
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
			enemigos.append(e)
		elif e["tipo"] == "jefe" and not bool(e.get("falsa", false)):
			jefe_e = e
	for id in _visuales.keys():
		if not vistos.has(id):
			(_visuales[id]["nodo"] as Node).queue_free()
			_visuales.erase(id)
	_actualizar_proyectiles(est["proyectiles"])
	tecnicas.sincronizar_zonas(est.get("zonas", []))
	genericas.sincronizar_criaturas(est.get("criaturas", []))
	for ev in est["eventos"]:
		_procesar_evento(ev)
	# La barra del enemigo solo aparece con uno vivo y cerca (el más cercano).
	if not yo.is_empty():
		var mejor := 40.0
		for en in enemigos:
			var dd := (en["pos"] as Vector3).distance_to(yo["pos"])
			if float(en["vida"]) > 0.0 and dd < mejor:
				mejor = dd
				enemigo = en
	_modo_jefe(jefe_e)
	if not yo.is_empty():
		hud.actualizar(yo, enemigo)
		_actualizar_mapa(yo, est["entidades"])
		if _visuales.has(mi_id) and camara.objetivo == null:
			camara.objetivo = _visuales[mi_id]["nodo"]
		_comprobar_fin(yo, enemigos[0] if not enemigos.is_empty() else {})


## Con un jefe en pantalla: barra enorme, música de jefe y cámara más abierta.
var _jefe_activo := false


func _modo_jefe(jefe_e: Dictionary) -> void:
	var activo := not jefe_e.is_empty()
	hud.barra_jefe(jefe_e)
	if activo != _jefe_activo:
		_jefe_activo = activo
		sonidos.bucle("musica_jefe", "musica_jefe", activo, -9.0)
	var dist_obj := 11.0 if activo else 6.2
	camara.distancia = lerpf(camara.distancia, dist_obj, 0.05)


func _crear_visual(e: Dictionary) -> void:
	var nodo: Node3D
	if e["tipo"] == "jefe":
		var jv := JefeVisual.new()
		add_child(jv)
		jv.construir()
		jv.falsa = bool(e.get("falsa", false))
		# Genjutsu 3+: las copias de la niebla se ven falsas (parpadean).
		jv.translucida = jv.falsa and Atributos.v(hud.atributos_jugador, "genjutsu") >= 3.0
		nodo = jv
		nodo.name = "Entidad_%d" % int(e["id"])
		nodo.position = e["pos"]
		nodo.rotation.y = float(e["yaw"])
		_visuales[int(e["id"])] = {"nodo": nodo, "tipo": e["tipo"], "destino": e["pos"], "yaw": e["yaw"], "estado": "", "carga": null, "vel": 0.0, "paso": -1}
		return
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
		if int(e["id"]) == mi_id:
			# Retrato del HUD con el mismo modelo y la misma personalización.
			var clan_r := str(asp.get("clan", Datos.personaje(str(e["plantilla"])).get("clan", "")))
			hud.configurar_retrato(asp, clan_r, str(_info.get(mi_id, {}).get("nombre", e.get("nombre", ""))), str(e["plantilla"]))
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
	var pw: Vector2 = e.get("pared", Vector2.ZERO)
	v["pared"] = Vector3(pw.x, 0, pw.y) if bool(e.get("escalando", false)) and pw != Vector2.ZERO else Vector3.ZERO
	v["agua"] = int(e.get("agua", 0))
	v["destino"] = nuevo - (v["pared"] as Vector3) * 0.42
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
		# Chakra en los pies: corriendo por una pared o caminando sobre el agua (pasos con chispas y ondas).
		var con_chakra := (v["pared"] as Vector3) != Vector3.ZERO or int(v["agua"]) == 1
		if v["nodo"] is PersonajeVisual:
			(v["nodo"] as PersonajeVisual).chakra_pies(con_chakra)
		if con_chakra and (float(v["vel"]) > 0.5 or (v["pared"] as Vector3) != Vector3.ZERO):
			v["t_chakra"] = float(v.get("t_chakra", 0.0)) - 1.0 / 30.0
			if float(v["t_chakra"]) <= 0.0:
				v["t_chakra"] = 0.2
				var normal: Vector3 = v["pared"] if (v["pared"] as Vector3) != Vector3.ZERO else Vector3.UP
				efectos.paso_chakra(nuevo - (v["pared"] as Vector3) * 0.4, normal)
		elif int(v["agua"]) == 2 and float(v["vel"]) > 0.3:
			v["t_chakra"] = float(v.get("t_chakra", 0.0)) - 1.0 / 30.0
			if float(v["t_chakra"]) <= 0.0:
				v["t_chakra"] = 0.45
				efectos.chapoteo(nuevo, 0.9, float(mapa.canal.get("nivel_agua", 0.0)))
	if v["tipo"] == "muneco":
		var mu: MunecoVisual = v["nodo"]
		mu.poner_caido(estado == "muerto")
		return
	if v["tipo"] == "jefe":
		var jv: JefeVisual = v["nodo"]
		jv.rodando = estado == "jefe_rodar" and float(e.get("estado_total", 0.0)) - float(e.get("estado_t", 0.0)) > 1.4
		jv.aturdido = estado == "aturdido"
		return
	var pv: PersonajeVisual = v["nodo"]
	var modo := str(e.get("modo", ""))
	pv.poner_ojos(int(Datos.jutsu(modo).get("patron", 0)) if bool(e.get("modo_activo", false)) and modo in Tecnicas.OJOS else 0)
	tecnicas.sincronizar(int(e["id"]), pv, e)
	genericas.sincronizar(int(e["id"]), pv, e)
	match estado:
		"muerto":
			pv.reproducir_primera(["muerte", "caer"], 0.08)
		"caido":
			pv.reproducir_primera(["derribado", "caer"], 0.08)
		"lanzado":
			pv.reproducir_primera(["lanzado", "caer"], 0.06)
		"golpeado":
			if cambio:
				pv.reproducir_forzado(pv._resolver_nombre("golpeado_cara" if randf() < 0.5 else "golpeado"))
		"golpe":
			var paso := int(e["paso"])
			if cambio or paso != int(v["paso"]):
				var pg := Combate.paso_golpe(paso)
				var seg: Array = pg.get("segmento", [])
				if seg.size() < 2 or not pv.reproducir_segmento("m/" + str(pg.get("anim", "")), float(seg[0]), float(seg[1]), float(pg["duracion"]) * float(v.get("f", 1.0))):
					pv.reproducir_forzado("golpe%d" % (mini(paso, 2) + 1))
				efectos.golpe_estela(pv, pg, int(e["id"]) == mi_id)
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
		"bloqueo":
			pv.reproducir("guardia", 0.06)
		"tai":
			var sec := str(v.get("tai_sec", ""))
			pv.reproducir_primera(["m/m_patada_voladora"] if sec == "entrada" else (["chidori_embiste"] if sec == "lariat" else ["m/m_patada_espiral", "saltar"]), 0.05)
		"atrapado_tai":
			pv.reproducir_primera(["lanzado", "caer"], 0.05)
		"dormido":
			pv.reproducir_primera(["derribado", "caer"], 0.1)
		_:
			if bool(e.get("escalando", false)):
				pv.reproducir("correr", 0.1, 1.5)   # corre por la pared más rápido que en el suelo
			elif not bool(e["en_suelo"]):
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
				if c is DragonVivo:
					(c as DragonVivo).desvanecer(n.get_meta("dragon_color", Color(0.6, 0.8, 1.0)), efectos)
				elif c is GPUParticles3D:
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
		"xp":
			if id == mi_id:
				Perfil.sumar_xp(float(ev["cantidad"]))
				var asc2 := Perfil.intentar_ascenso()
				if asc2 != "":
					ui_mision.anuncio(Datos.texto("msg_ascenso", [Datos.texto("rango_" + asc2)]))
				Perfil.guardar()
				hud.mensaje(Datos.texto("msg_xp", [int(ev["cantidad"])]), 1.2)
		"entreno":
			if id == mi_id:
				Perfil.poner_entreno(str(ev["atributo"]), float(ev["valor"]))
				if bool(ev.get("lleno", false)):
					hud.mensaje(Datos.texto("msg_entreno_lleno", [Datos.texto("attr_" + str(ev["atributo"])) if str(ev["atributo"]) != "control" else Datos.texto("attr_control")]), 2.5)
					Perfil.guardar()
		"golpe":
			if _visuales.has(id):
				_visuales[id]["f"] = float(ev.get("f", 1.0))
			if bool(ev.get("avance", false)):
				efectos.estela_avance(_pos_entidad(id), _visuales[id]["nodo"] if _visuales.has(id) else null)
		"shunshin":
			efectos.shunshin(ev["desde"], ev["hasta"])
			if id == mi_id:
				camara.sacudir(0.12)
		"tai":
			_evento_tai(ev)
		"mision":
			_evento_mision(ev)
		"jefe":
			_evento_jefe(ev)
		"escena":
			ui_mision.escena(ev.get("lineas", []), bool(ev.get("pajaro", false)), float(ev.get("duracion", 4.0)))
		"anuncio":
			ui_mision.anuncio(str(ev.get("titulo", "")))
		"emboscada_aviso":
			if id == mi_id:
				hud.marca_minimapa(ev["pos"], float(ev.get("duracion", 6.0)), Color(1.0, 0.3, 0.3))
				hud.mensaje(Datos.texto("msg_emboscada"), 2.0)
		"aparece":
			efectos.humo(ev["pos"])
		"rendicion":
			efectos.numero(ev["pos"] + Vector3(0, 0.6, 0), 0.0, Color.WHITE, 1.0)
			hud.mensaje(Datos.texto("msg_rendicion"), 1.5)
		"interrumpido":
			efectos.choque(ev["pos"])
			efectos.onda_golpe(ev["pos"], Vector3.ZERO)
			if int(ev.get("atacante", -1)) == mi_id or id == mi_id:
				hud.mensaje(Datos.texto("msg_interrumpido"), 1.2)
		"genjutsu_roto":
			efectos.rafaga(ev["pos"], {"cantidad": 40, "vida": 0.6, "radio": 0.6, "vel_min": 3.0, "vel_max": 7.0, "tam_min": 0.1, "tam_max": 0.25,
				"color": Color(0.85, 0.7, 1.0)})
			if id == mi_id:
				hud.quitar_genjutsu()
				hud.mensaje(Datos.texto("msg_genjutsu_roto"), 1.2)
				sonidos.tocar("trueno", -14.0, 2.2)
		"resistido":
			if id == mi_id:
				hud.mensaje(Datos.texto("msg_resistido"), 0.8)
		"control":
			if id == mi_id and str(ev.get("estado", "")) in ["ciego", "miedo"]:
				hud.velo_genjutsu(str(ev["estado"]), float(ev.get("duracion", 3.0)))
		"bloqueado":
			efectos.choque(ev["pos"])
			sonidos.tocar("golpe", -6.0, 2.4)
			if int(ev.get("atacante", -1)) == mi_id:
				hud.mensaje(Datos.texto("msg_bloqueado"), 0.8)
		"guardia_rota":
			efectos.onda_golpe(ev["pos"], Vector3.ZERO)
			efectos.choque(ev["pos"])
			sonidos.tocar("explosion", -10.0, 1.8)
			if int(ev.get("atacante", -1)) == mi_id:
				hud.mensaje(Datos.texto("msg_guardia_rota"), 1.2)
				hud.lineas_velocidad(0.3)
				pausa_impacto(0.1)
		"choque":
			efectos.choque(ev["pos"])
			sonidos.tocar("golpe", 0.0, 1.9)
			pausa_impacto(float(ev.get("pausa", 0.12)))
			camara.sacudir(0.35)
		"kirin":
			# El dragón de rayo toca el suelo: destello blanco a pantalla completa para quien lo ve de cerca.
			if _pos_entidad(mi_id).distance_to(ev["pos"]) < 45.0:
				hud.destello_pantalla(0.45 + int(ev.get("nivel", 1)) * 0.12, 0.75 + int(ev.get("nivel", 1)) * 0.08)
		"estrellar":
			efectos.estrellar(ev["pos"])
			sonidos.tocar("explosion", -8.0, 1.5)
			efectos.sacudir_desde(ev["pos"], 0.6)
		"derrota":
			efectos.polvo(_pos_entidad(id), 24)
		"sharingan":
			if id == mi_id:
				hud.mensaje(Datos.texto("msg_sharingan_on" if ev["activo"] else "msg_sharingan_off"), 1.2)
		"nivel":
			if id == mi_id:
				hud.poner_nivel(int(ev["nivel"]))
		"genjutsu":
			# Genjutsu del rebelde: al objetivo se le nubla la pantalla; todos ven el destello morado del lanzador.
			var lanz := _pos_entidad(int(ev["entidad"]))
			efectos.rafaga(lanz + Vector3(0, 1.5, 0), {"cantidad": 30, "vida": 0.8, "radio": 0.5, "vel_min": 1.0, "vel_max": 3.0,
				"tam_min": 0.1, "tam_max": 0.25, "color": Color(0.7, 0.3, 1.0, 0.9)})
			if int(ev["objetivo"]) == mi_id:
				hud.genjutsu(float(ev.get("duracion", 3.0)))
				sonidos.tocar("trueno", -12.0, 1.6)
		"humo":
			efectos.humo(ev["pos"])
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
			var fuerte := cant > 10.0 or bool(ev.get("fuerte", false))
			efectos.golpe_fisico(pos, fuerte)
			sonidos.tocar("golpe", -2.0 if fuerte else -6.0, 0.8 if fuerte else 1.1)
			if involucra_me:
				# Hitstop: breve en cada golpe, largo en los fuertes; líneas de velocidad de anime en los fuertes.
				pausa_impacto(float(imp.get("pausa_golpe_fuerte", 0.07)) * (1.6 if fuerte else 0.45))
				if fuerte:
					hud.lineas_velocidad(0.35)
					camara.sacudir(0.35)
			if fuerte:
				efectos.onda_golpe(pos, ev.get("dir", Vector3.ZERO))
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


## Técnicas de taijutsu con secuencia: polvo y líneas al empezar, golpes en el aire, impacto enorme.
func _evento_tai(ev: Dictionary) -> void:
	var id := int(ev.get("entidad", -1))
	var propio := id == mi_id or int(ev.get("objetivo", -1)) == mi_id
	var sec := str(ev.get("sec", ""))
	match str(ev.get("fase", "")):
		"inicio":
			if _visuales.has(id):
				_visuales[id]["tai_sec"] = sec
			efectos.polvo(_pos_entidad(id), 20)
			if propio:
				hud.lineas_velocidad(0.5)
			if sec == "lariat":
				efectos.impacto_rayo(_pos_entidad(id) + Vector3(0, 1.2, 0), 1)
		"aire":
			efectos.golpe_fisico(ev["pos"], false)
			sonidos.tocar("golpe", -6.0, 1.3)
		"impacto":
			efectos.golpe_fisico(ev["pos"], true)
			efectos.onda_golpe(ev["pos"], Vector3.ZERO)
			sonidos.tocar("golpe", 0.0, 0.7)
			efectos.sacudir_desde(ev["pos"], float(Datos.nivel_jutsu(str(ev["jutsu"]), int(ev["nivel"])).get("sacudida", 0.6)))
			if propio:
				pausa_impacto(0.12)
				hud.lineas_velocidad(0.45)
			if sec in ["loto", "loto_oculto", "liger"]:
				efectos.estrellar(Vector3(ev["pos"].x, 0.0, ev["pos"].z))


## El Tres Colas: aparición, ataques telegrafiados, niebla, bomba y sellado.
var _sellado_ui: SelladoUi
var _niebla_antes := -1.0


func _evento_jefe(ev: Dictionary) -> void:
	var pos: Vector3 = ev.get("pos", Vector3.ZERO)
	match str(ev.get("accion", "")):
		"aparece":
			var ar: Vector3 = ev.get("arena", Vector3.ZERO)
			mapa.arena_lago = ar   # el cliente también deja caminar sobre el lago (predicción)
			efectos.chapoteo(pos, 6.0, mapa.nivel_agua())
			genericas._salpicadura(pos, 12.0, 3)
			efectos.sacudir_desde(pos, 1.2)
			sonidos.tocar("trueno", 0.0, 0.6)
			ui_mision.anuncio(str(ev.get("nombre", "")))
		"rugido":
			sonidos.tocar("trueno", -10.0, 0.5)
		"fase":
			ui_mision.anuncio(Datos.texto("jefe_fase", [int(ev["fase"])]))
			efectos.sacudir_desde(pos, 0.8)
		"rodar_aviso":
			efectos.aviso(ev["desde"], ev["hasta"], float(ev["duracion"]), false)
			sonidos.tocar("tambor", -2.0, 0.7)
		"rodar":
			efectos.sacudir_desde(_pos_entidad(int(ev["entidad"])), 0.6)
		"aturdido":
			genericas._salpicadura(pos, 6.0, 2)
		"niebla":
			if efectos.escenario != null and efectos.escenario.entorno != null:
				_niebla_antes = efectos.escenario.entorno.fog_density
				create_tween().tween_property(efectos.escenario.entorno, "fog_density", 0.05, 1.5)
			sonidos.tocar("trueno", -8.0, 1.6)
		"niebla_fin":
			if efectos.escenario != null and efectos.escenario.entorno != null and _niebla_antes >= 0.0:
				create_tween().tween_property(efectos.escenario.entorno, "fog_density", _niebla_antes, 1.5)
		"copia_disipada":
			efectos.humo(pos)
		"bomba_carga":
			genericas.bomba_bijuu_carga(_pos_entidad(int(ev["entidad"])), ev["punto"], float(ev["duracion"]), float(ev["radio"]))
			sonidos.tocar("chidori", -12.0, 0.4)
		"bomba":
			genericas.bomba_bijuu(pos, float(ev["radio"]))
			hud.destello_pantalla(0.5, 0.8)
			sonidos.tocar("explosion", 2.0, 0.5)
		"vencido":
			if int(ev.get("para", -1)) == mi_id:
				if bool(ev.get("puede_sellar", false)):
					_sellado_ui = SelladoUi.new()
					_sellado_ui.sonidos = sonidos
					hud.add_child(_sellado_ui)
					_sellado_ui.iniciar(ev["secuencia"], float(ev["duracion"]))
					_sellado_ui.enviado.connect(func(sec): transporte.enviar({"t": Protocolo.C_MISION, "accion": "sellar", "id": "", "sellos": sec}))
				else:
					hud.mensaje(Datos.texto("msg_vencido_sin_sellos"), 4.0)
		"sellado":
			mapa.arena_lago = Vector3.ZERO
			tecnicas.golpe_definitivo(pos, 8.0)
			hud.mensaje(Datos.texto("msg_jefe_sellado"), 3.0)
			var jv: Node3D = _visuales.get(int(ev["entidad"]), {}).get("nodo", null)
			if jv != null:
				create_tween().tween_property(jv, "scale", Vector3.ONE * 0.05, 1.2).set_ease(Tween.EASE_IN)
		"sellado_fallido":
			hud.mensaje(Datos.texto("msg_sellado_fallido"), 1.5)
		"huye":
			mapa.arena_lago = Vector3.ZERO
			hud.mensaje(Datos.texto("msg_jefe_huye"), 3.0)
			genericas._salpicadura(pos, 12.0, 3)
			var jv2: Node3D = _visuales.get(int(ev["entidad"]), {}).get("nodo", null)
			if jv2 != null:
				create_tween().tween_property(jv2, "position:y", jv2.position.y - 14.0, 2.5)


func _evento_mision(ev: Dictionary) -> void:
	match str(ev.get("accion", "")):
		"inicio":
			ui_mision.mision_inicio(str(ev.get("titulo", "")))
		"objetivo":
			ui_mision.objetivo(str(ev.get("objetivo", "")), str(ev.get("contador", "")), float(ev.get("limite", 0.0)), float(ev.get("t", 0.0)))
		"fin":
			ui_mision.mision_fin()
			mapa.arena_lago = Vector3.ZERO
			var asc := Perfil.aplicar_mision(ev)
			Perfil.guardar()
			# El servidor ve el progreso nuevo (capítulo, pergaminos) en el personaje.
			transporte.enviar(Perfil.comando_personaje())
			var extra := ""
			if asc != "":
				extra = Datos.texto("msg_ascenso", [Datos.texto("rango_" + asc)])
			elif bool(ev.get("sellado", false)):
				extra = Datos.texto("msg_sellado_ok")
			ui_mision.recompensa(str(ev.get("titulo", "")), ev.get("recompensa", {}), bool(ev.get("exito", false)), extra)


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


## Minimapa y mapa completo: yo, los demás jugadores (azul) y los enemigos (rojo).
func _actualizar_mapa(yo: Dictionary, entidades: Array) -> void:
	var otros: Array = []
	for e in entidades:
		if int(e["id"]) == mi_id or e["tipo"] == "muneco" or float(e["vida"]) <= 0.0:
			continue
		var p: Vector3 = e["pos"]
		otros.append({"pos": Vector2(p.x, p.z), "color": Color(0.35, 0.7, 1.0) if e["tipo"] == "jugador" else Color(1.0, 0.3, 0.3)})
	var mp: Vector3 = yo["pos"]
	hud.actualizar_mapa(Vector2(mp.x, mp.z), float(yo["yaw"]), otros)


var _t_interaccion := 0.0
var _cercano: Dictionary = {}


## Busca el aldeano o punto de misión más cercano (a menos de 2,8 m) para el botón «Interactuar».
func _buscar_interaccion(delta: float) -> void:
	_t_interaccion -= delta
	if _t_interaccion > 0.0 or not _visuales.has(mi_id):
		return
	_t_interaccion = 0.15
	var yo: Vector3 = (_visuales[mi_id]["nodo"] as Node3D).global_position
	_cercano = {}
	var mejor := 2.8
	for p in Puntos.lista:
		if not is_instance_valid(p["nodo"]):
			continue   # de una partida anterior (la lista es estática)
		var n: Node3D = p["nodo"]
		if not n.is_visible_in_tree():
			continue
		var d := Vector2(n.global_position.x - yo.x, n.global_position.z - yo.z).length()
		if d < mejor:
			mejor = d
			_cercano = p
	hud.mostrar_interactuar(not _cercano.is_empty())


func _interactuar() -> void:
	if _cercano.is_empty():
		return
	var n: Node3D = _cercano["nodo"]
	if n is Aldeano:
		# Se detiene y mira al jugador mientras habla.
		var yo: Vector3 = (_visuales[mi_id]["nodo"] as Node3D).global_position
		(n as Aldeano)._pausa = 5.0
		n.rotation.y = atan2(yo.x - n.global_position.x, yo.z - n.global_position.z)
	var d := mapa.distrito(str(_cercano["distrito"]))
	# Puntos de misión: empiezan el capítulo de la historia de ese distrito (si toca) o el duelo con el instructor.
	if str(_cercano["tipo"]) in ["mision", "npc_mision"]:
		var cap := _capitulo_del_distrito(str(_cercano["distrito"]))
		if not cap.is_empty():
			transporte.enviar({"t": Protocolo.C_MISION, "accion": "empezar", "id": str(cap["id"])})
			return
		if str(_cercano["tipo"]) == "npc_mision" and str(_cercano["distrito"]) == "academia":
			transporte.enviar({"t": Protocolo.C_MISION, "accion": "evento", "id": "duelo_instructor"})
			return
	hud.dialogo(Puntos.texto(_cercano, str(d.get("nombre", ""))))


## Capítulo siguiente de la historia si se da en ese distrito.
func _capitulo_del_distrito(distrito: String) -> Dictionary:
	var pj := Perfil.personaje()
	var sig := int(pj.get("misiones", {}).get("capitulo", 0)) if not pj.is_empty() else 0
	var caps: Array = Misiones.conf().get("capitulos", [])
	if sig < caps.size() and str(caps[sig].get("distrito", "")) == distrito:
		return caps[sig]
	return {}
