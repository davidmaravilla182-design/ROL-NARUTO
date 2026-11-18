class_name TransporteENet
extends Transporte
## Red local sobre ENet con la MISMA interfaz que TransporteLocal (enviar / estado_recibido / conectado).
##
## Un mismo nodo, llamado "Red", cumple los dos papeles (las RPC necesitan la misma ruta en ambos lados):
##   - anfitrión: crear_servidor(servidor). El servidor con autoridad recibe comandos de los demás
##     y les manda instantáneas. El jugador del anfitrión NO pasa por aquí: usa TransporteLocal.
##   - cliente:   unirse(ip). Solo manda comandos y recibe el estado.
## Cada nodo "Red" usa su propia MultiplayerAPI en su rama del árbol: así varias instancias pueden
## convivir en un mismo proceso (prueba automática con un servidor y 2 bots).
##
## Estado: sin garantía de entrega y ordenado (lo viejo se descarta). Eventos: fiables, aparte,
## y se reinyectan en la siguiente instantánea para que el cliente los procese igual que offline.

signal rechazado(motivo: String)

var servidor: ServidorJuego = null
var es_servidor := false
var simular := false               # latencia y pérdida artificiales (solo cliente)
var conf: Dictionary = {}

# --- estadísticas (cliente)
var ping_ms := 0.0
var perdida := 0.0                 # fracción de instantáneas perdidas en la ventana reciente
var conectado_ok := false

var _api: SceneMultiplayer
var _eventos_pendientes: Dictionary = {}   # servidor: peer -> [eventos sin enviar]
var _seq_peer: Dictionary = {}             # servidor: peer -> nº de instantánea
var _cuenta_tick := 0
var _eventos_cliente: Array = []           # cliente: eventos fiables aún no inyectados
var _ultimo_seq := -1
var _ventana: Array = []                   # cliente: 1 = llegó, 0 = perdida (últimas 100)
var _t_ping := 0.0
var _cola_salida: Array = []               # simulador: [t, cmd, fiable]
var _cola_entrada: Array = []              # simulador: [t, tipo, datos]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_asegurar_api()


## MultiplayerAPI propia de esta rama del árbol (se crea al entrar o al primer uso).
func _asegurar_api() -> void:
	if _api != null:
		return
	Datos.cargar()
	conf = Datos.red
	_rng.randomize()
	_api = SceneMultiplayer.new()
	get_tree().set_multiplayer(_api, get_parent().get_path())


func _exit_tree() -> void:
	cerrar()


func cerrar() -> void:
	if _api != null and _api.multiplayer_peer != null:
		_api.multiplayer_peer.close()
		_api.multiplayer_peer = null
	if is_inside_tree() and get_parent() != null:
		get_tree().set_multiplayer(null, get_parent().get_path())


# ======================================================================== anfitrión

func crear_servidor(p_servidor: ServidorJuego, puerto := -1, max_jugadores := -1) -> Error:
	_asegurar_api()
	servidor = p_servidor
	es_servidor = true
	if puerto < 0:
		puerto = int(conf.get("puerto", 7777))
	if max_jugadores < 0:
		max_jugadores = int(conf.get("max_jugadores", 4))
	var peer := ENetMultiplayerPeer.new()
	# Los remotos son todos menos el anfitrión; un hueco extra para poder avisar "partida llena".
	var err := peer.create_server(puerto, max_jugadores)
	if err != OK:
		return err
	_api.multiplayer_peer = peer
	_api.peer_connected.connect(_on_peer_conectado)
	_api.peer_disconnected.connect(_on_peer_desconectado)
	servidor.estado_generado.connect(_on_estado_servidor)
	return OK


func jugadores_remotos() -> int:
	return _api.get_peers().size() if _api.multiplayer_peer != null else 0


func _on_peer_conectado(peer_id: int) -> void:
	var total := 0
	for e in servidor.entidades:
		if e.tipo == "jugador":
			total += 1
	if total >= int(conf.get("max_jugadores", 4)):
		_rpc_rechazo.rpc_id(peer_id, "llena")
		# Se desconecta un poco después para que el aviso llegue.
		get_tree().create_timer(0.5).timeout.connect(func():
			if _api.multiplayer_peer != null and peer_id in _api.get_peers():
				(_api.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(peer_id))
		return
	var id := servidor.agregar_jugador(peer_id)
	_eventos_pendientes[peer_id] = []
	_seq_peer[peer_id] = 0
	_rpc_bienvenida.rpc_id(peer_id, id)


func _on_peer_desconectado(peer_id: int) -> void:
	servidor.quitar_jugador(peer_id)
	_eventos_pendientes.erase(peer_id)
	_seq_peer.erase(peer_id)


func _on_estado_servidor(peer_id: int, estado: Dictionary) -> void:
	if not _eventos_pendientes.has(peer_id):
		return   # el jugador local del anfitrión (TransporteLocal)
	if _api.multiplayer_peer == null or not (peer_id in _api.get_peers()):
		return   # se está desconectando
	var evs: Array = estado.get("eventos", [])
	if not evs.is_empty():
		(_eventos_pendientes[peer_id] as Array).append_array(evs)
	if peer_id == _primer_peer():
		_cuenta_tick += 1
	# 30 ticks/s en el servidor → ~20 instantáneas/s por la red (2 de cada 3 ticks).
	var cada := 30.0 / maxf(float(conf.get("estado_por_segundo", 20)), 1.0)
	if fmod(float(int(estado.get("tick", 0))), cada) >= 1.0 and cada > 1.0:
		return
	var pend: Array = _eventos_pendientes[peer_id]
	if not pend.is_empty():
		_rpc_eventos.rpc_id(peer_id, pend.duplicate())
		_eventos_pendientes[peer_id] = []
	var est := estado.duplicate()
	est["eventos"] = []
	est["n"] = int(_seq_peer[peer_id])
	_seq_peer[peer_id] = int(_seq_peer[peer_id]) + 1
	# Las recargas y niveles solo le importan a su dueño: se quitan de los demás para ahorrar bytes.
	var mia := int(est.get("tu_entidad", -1))
	var ents: Array = []
	for e in est.get("entidades", []):
		if int(e["id"]) != mia and e.has("recargas"):
			var c: Dictionary = (e as Dictionary).duplicate()
			c.erase("recargas")
			c.erase("niveles")
			ents.append(c)
		else:
			ents.append(e)
	est["entidades"] = ents
	# Comprimido: cabe en un solo paquete (sin fragmentar) y se pierde menos.
	var crudo := var_to_bytes(est)
	_rpc_estado.rpc_id(peer_id, crudo.compress(FileAccess.COMPRESSION_ZSTD), crudo.size())


func _primer_peer() -> int:
	var lista := _eventos_pendientes.keys()
	return int(lista[0]) if not lista.is_empty() else -1


# ======================================================================== cliente

func unirse(direccion: String, puerto := -1) -> Error:
	_asegurar_api()
	es_servidor = false
	if puerto < 0:
		puerto = int(conf.get("puerto", 7777))
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(direccion, puerto)
	if err != OK:
		return err
	_api.multiplayer_peer = peer
	_api.server_disconnected.connect(func():
		conectado_ok = false
		desconectado.emit())
	_api.connection_failed.connect(func():
		conectado_ok = false
		rechazado.emit("sin_respuesta"))
	return OK


func enviar(cmd: Dictionary) -> void:
	if es_servidor or _api.multiplayer_peer == null:
		return
	var fiable := str(cmd.get("t", "")) != Protocolo.C_ENTRADA
	if simular:
		var sim: Dictionary = conf.get("simulador", {})
		if not fiable and _rng.randf() < float(sim.get("perdida", 0.0)):
			return
		_cola_salida.append([_ahora() + _retraso_simulado(), cmd.duplicate(true), fiable])
		return
	_mandar(cmd, fiable)


func _mandar(cmd: Dictionary, fiable: bool) -> void:
	if _api.multiplayer_peer == null or _api.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if fiable:
		_rpc_comando.rpc_id(1, cmd)
	else:
		_rpc_comando_rapido.rpc_id(1, cmd)


func _ahora() -> float:
	return Time.get_ticks_msec() / 1000.0


func _retraso_simulado() -> float:
	var sim: Dictionary = conf.get("simulador", {})
	var ida := float(sim.get("latencia_ms", 120)) * 0.5 / 1000.0
	return maxf(ida + _rng.randf_range(-1.0, 1.0) * float(sim.get("variacion_ms", 40)) / 1000.0, 0.0)


func _process(delta: float) -> void:
	if es_servidor or _api == null or _api.multiplayer_peer == null:
		return
	var ahora := _ahora()
	while not _cola_salida.is_empty() and float(_cola_salida[0][0]) <= ahora:
		var s: Array = _cola_salida.pop_front()
		_mandar(s[1], s[2])
	# Entrada retrasada por el simulador (ordenada por tiempo de llegada).
	_cola_entrada.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	while not _cola_entrada.is_empty() and float(_cola_entrada[0][0]) <= ahora:
		var e: Array = _cola_entrada.pop_front()
		match str(e[1]):
			"estado":
				_recibir_estado(e[2])
			"eventos":
				_eventos_cliente.append_array(e[2])
			"pong":
				ping_ms = (Time.get_ticks_msec() - int(e[2])) * 1.0
	if conectado_ok:
		_t_ping -= delta
		if _t_ping <= 0.0:
			_t_ping = float(conf.get("ping_intervalo", 1.0))
			var t := Time.get_ticks_msec()
			if simular:
				_cola_salida.append([ahora + _retraso_simulado(), {"_ping": t}, true])
			else:
				_rpc_ping.rpc_id(1, t)


func _recibir_estado(estado: Dictionary) -> void:
	var n := int(estado.get("n", -1))
	if n <= _ultimo_seq:
		return   # llegó tarde: ya hay uno más nuevo
	if _ultimo_seq >= 0:
		for i in mini(n - _ultimo_seq - 1, 50):
			_ventana.append(0)
	_ventana.append(1)
	while _ventana.size() > 100:
		_ventana.pop_front()
	_ultimo_seq = n
	var perdidos := 0
	for x in _ventana:
		perdidos += 1 - int(x)
	perdida = float(perdidos) / maxf(float(_ventana.size()), 1.0)
	estado["eventos"] = _eventos_cliente
	_eventos_cliente = []
	estado_recibido.emit(estado)


# ======================================================================== RPC

@rpc("any_peer", "call_remote", "reliable")
func _rpc_comando(cmd: Dictionary) -> void:
	if not es_servidor:
		return
	if cmd.has("_ping"):
		_rpc_pong.rpc_id(_api.get_remote_sender_id(), int(cmd["_ping"]))
		return
	servidor.recibir_comando(_api.get_remote_sender_id(), cmd)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_comando_rapido(cmd: Dictionary) -> void:
	if es_servidor:
		servidor.recibir_comando(_api.get_remote_sender_id(), cmd)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_ping(t: int) -> void:
	if es_servidor:
		_rpc_pong.rpc_id(_api.get_remote_sender_id(), t)


@rpc("authority", "call_remote", "unreliable")
func _rpc_pong(t: int) -> void:
	if simular:
		_cola_entrada.append([_ahora() + _retraso_simulado(), "pong", t])
	else:
		ping_ms = (Time.get_ticks_msec() - t) * 1.0


@rpc("authority", "call_remote", "reliable")
func _rpc_bienvenida(id_entidad: int) -> void:
	conectado_ok = true
	conectado.emit(id_entidad)


@rpc("authority", "call_remote", "reliable")
func _rpc_rechazo(motivo: String) -> void:
	rechazado.emit(motivo)


@rpc("authority", "call_remote", "reliable")
func _rpc_eventos(evs: Array) -> void:
	if simular:
		_cola_entrada.append([_ahora() + _retraso_simulado(), "eventos", evs])
	else:
		_eventos_cliente.append_array(evs)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_estado(comprimido: PackedByteArray, tam: int) -> void:
	var v: Variant = bytes_to_var(comprimido.decompress(tam, FileAccess.COMPRESSION_ZSTD))
	if typeof(v) != TYPE_DICTIONARY:
		return
	var estado: Dictionary = v
	if simular:
		var sim: Dictionary = conf.get("simulador", {})
		if _rng.randf() < float(sim.get("perdida", 0.0)):
			return
		_cola_entrada.append([_ahora() + _retraso_simulado(), "estado", estado])
		return
	_recibir_estado(estado)


## IPs locales de este dispositivo (para que el anfitrión las muestre).
static func ips_locales() -> Array:
	var r: Array = []
	for ip in IP.get_local_addresses():
		var s := str(ip)
		if s.contains(":") or s.begins_with("127.") or s.begins_with("169.254"):
			continue
		if s.begins_with("192.168.") or s.begins_with("10.") or s.begins_with("172."):
			r.append(s)
	return r
