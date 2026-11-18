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

var mi_id := -1
var _visuales: Dictionary = {}     # id entidad -> {nodo, tipo, destino, yaw, estado, carga}
var _proyectiles: Dictionary = {}  # id proyectil -> {nodo, destino}
var _estado: Dictionary = {}
var _ultimo_mov := Vector2.ZERO
var _t_envio := 0.0
var _mov_prueba := Vector2.ZERO
var _anuncio_fin := ""


func _ready() -> void:
	Datos.cargar()
	_registrar_teclas()
	mapa = Mapa.generar()

	escenario = Escenario.new()
	escenario.name = "Escenario"
	add_child(escenario)
	escenario.construir(mapa)

	camara = CamaraTercera.new()
	camara.name = "Camara"
	add_child(camara)

	efectos = Efectos.new()
	efectos.name = "Efectos"
	efectos.camara = camara
	efectos.escenario = escenario
	add_child(efectos)

	lluvia = Lluvia.new()
	lluvia.name = "Lluvia"
	add_child(lluvia)
	lluvia.construir()
	lluvia.objetivo = camara

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.construir()
	hud.accion.connect(_on_accion)
	hud.nivel_pedido.connect(func(n): transporte.enviar({"t": Protocolo.C_NIVEL, "valor": n}))
	hud.reaparecer_pedido.connect(func(): transporte.enviar({"t": Protocolo.C_REAPARECER}))
	hud.salir_pedido.connect(func(): get_tree().change_scene_to_file(ESCENA_MENU))
	hud.camara_arrastre.connect(func(r): camara.girar(r))

	# Modo offline: servidor autoritativo en el mismo proceso, misma interfaz que en red.
	servidor = ServidorJuego.new()
	servidor.name = "Servidor"
	add_child(servidor)
	servidor.iniciar(mapa)
	servidor.poblar_entrenamiento()
	var local := TransporteLocal.new()
	local.name = "Transporte"
	add_child(local)
	transporte = local
	transporte.conectado.connect(func(id): mi_id = id)
	transporte.estado_recibido.connect(_on_estado)
	local.iniciar(servidor)

	var aldea := Datos.aldea("lluvia")
	hud.mensaje(Datos.texto("msg_bienvenida", [aldea.get("nombre_largo", "")]), 3.0)


func _registrar_teclas() -> void:
	var teclas := {
		"mover_arriba": [KEY_W, KEY_UP], "mover_abajo": [KEY_S, KEY_DOWN],
		"mover_izq": [KEY_A, KEY_LEFT], "mover_der": [KEY_D, KEY_RIGHT],
		"golpe": [KEY_J], "bola_fuego": [KEY_K], "chidori": [KEY_L], "sharingan": [KEY_Q],
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


func _on_accion(id: String) -> void:
	transporte.enviar({"t": Protocolo.C_ACCION, "id": id})


# ------------------------------------------------------------ entrada

func _process(delta: float) -> void:
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
	_t_envio -= delta
	# Se envía al ritmo del servidor o en cuanto cambia la entrada.
	if _t_envio <= 0.0 or mov.distance_to(_ultimo_mov) > 0.05:
		_t_envio = 1.0 / 30.0
		_ultimo_mov = mov
		transporte.enviar({"t": Protocolo.C_ENTRADA, "mov": mov, "mira": mira})
	_interpolar(delta)


func _interpolar(delta: float) -> void:
	var k := minf(1.0, delta * 18.0)
	for id in _visuales.keys():
		var v: Dictionary = _visuales[id]
		var n: Node3D = v["nodo"]
		n.position = n.position.lerp(v["destino"], k)
		n.rotation.y = lerp_angle(n.rotation.y, float(v["yaw"]), k)
	for id in _proyectiles.keys():
		var p: Dictionary = _proyectiles[id]
		var pn: Node3D = p["nodo"]
		pn.global_position = pn.global_position.lerp(p["destino"], minf(1.0, delta * 25.0))
		if pn.has_meta("pulso"):
			var nucleo: Node3D = pn.get_meta("pulso")
			nucleo.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.08)


# ------------------------------------------------------------ estado del servidor

func _on_estado(est: Dictionary) -> void:
	_estado = est
	if est.has("tu_entidad"):
		mi_id = int(est["tu_entidad"])
	var vistos := {}
	var yo: Dictionary = {}
	var enemigo: Dictionary = {}
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
		pv.construir(str(e["plantilla"]))
		nodo = pv
	nodo.name = "Entidad_%d" % int(e["id"])
	nodo.position = e["pos"]
	nodo.rotation.y = float(e["yaw"])
	_visuales[int(e["id"])] = {"nodo": nodo, "tipo": e["tipo"], "destino": e["pos"], "yaw": e["yaw"], "estado": "", "carga": null, "vel": 0.0, "paso": -1}


func _actualizar_visual(v: Dictionary, e: Dictionary) -> void:
	var nuevo: Vector3 = e["pos"]
	var antes: Vector3 = v["destino"]
	var d := Vector2(nuevo.x - antes.x, nuevo.z - antes.z).length() * 30.0
	v["vel"] = lerpf(float(v["vel"]), d, 0.5)
	v["destino"] = nuevo
	v["yaw"] = float(e["yaw"])
	var estado := str(e["estado"])
	var cambio := estado != str(v["estado"])
	v["estado"] = estado
	if v["tipo"] == "muneco":
		var mu: MunecoVisual = v["nodo"]
		mu.poner_caido(estado == "muerto")
		return
	var pv: PersonajeVisual = v["nodo"]
	pv.poner_sharingan(bool(e["sharingan"]))
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
		"lanzar", "rafaga":
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
			var nodo := efectos.crear_proyectil(p)
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
			get_tree().create_timer(1.0).timeout.connect(n.queue_free)
			_proyectiles.erase(id)


func _pos_entidad(id: int) -> Vector3:
	if _visuales.has(id):
		return (_visuales[id]["nodo"] as Node3D).global_position
	return Vector3.ZERO


func _procesar_evento(ev: Dictionary) -> void:
	var id := int(ev.get("entidad", -1))
	match str(ev["tipo"]):
		"sellos":
			if id == mi_id:
				hud.mostrar_sellos(ev["sellos"], float(ev["duracion"]))
		"lanzar":
			if str(ev["jutsu"]) == "bola_fuego":
				var nd := Datos.nivel_jutsu("bola_fuego", int(ev["nivel"]))
				efectos.luz_temporal(ev["pos"], Efectos.COLOR_FUEGO, float(nd.get("luz", 3.0)) * 1.5, float(nd.get("luz_rango", 6.0)), 0.3)
				efectos.sacudir_desde(ev["pos"], float(nd.get("sacudida", 0.2)) * 0.4)
		"chidori_carga":
			if _visuales.has(id) and _visuales[id]["nodo"] is PersonajeVisual:
				var anterior = _visuales[id]["carga"]
				if anterior != null and is_instance_valid(anterior):
					anterior.queue_free()
				_visuales[id]["carga"] = efectos.crear_carga_rayo(_visuales[id]["nodo"], int(ev["nivel"]))
		"chidori_embiste":
			efectos.polvo(ev["desde"], 10 + int(ev["nivel"]) * 10)
		"impacto":
			_evento_impacto(ev)
		"explosion":
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
				hud.mensaje(Datos.texto(str(ev["clave"])), 1.5)


func _evento_impacto(ev: Dictionary) -> void:
	var pos: Vector3 = ev["pos"]
	var jutsu := str(ev["jutsu"])
	var cant := float(ev["cantidad"])
	var color := Color.WHITE
	match jutsu:
		"bola_fuego":
			color = Color(1.0, 0.6, 0.2)
		"chidori":
			color = Color(0.6, 0.9, 1.0)
			if not ev["cadena"]:
				efectos.impacto_rayo(pos, int(ev["nivel"]))
		"bala_agua":
			color = Color(0.5, 0.75, 1.0)
		_:
			efectos.golpe_fisico(pos, cant > 10.0)
	var extra := ""
	var mult := float(ev["naturaleza_mult"])
	if mult > 1.01:
		extra = " ▲"
	elif mult < 0.99:
		extra = " ▼"
	efectos.numero(pos, cant, color, extra)
	var objetivo := int(ev["entidad"])
	if _visuales.has(objetivo) and _visuales[objetivo]["nodo"] is MunecoVisual:
		(_visuales[objetivo]["nodo"] as MunecoVisual).golpeado()
	if objetivo == mi_id:
		camara.sacudir(0.25)
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
		150: _on_accion("bola_fuego")
		200: _on_accion("golpe")
		210: _on_accion("golpe")
		220: _on_accion("golpe")
		250: _on_accion("esquivar")
		270: _on_accion("saltar")
		300: transporte.enviar({"t": Protocolo.C_REAPARECER})
		320: transporte.enviar({"t": Protocolo.C_NIVEL, "valor": 2})
		325: _on_accion("chidori")
