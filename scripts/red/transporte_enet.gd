class_name TransporteENet
extends Transporte
## Modo en red (preparado, aún no usado por el demo).
## Usa la MultiplayerAPI de Godot sobre ENet con la MISMA interfaz que TransporteLocal:
## el cliente envía comandos por RPC y el servidor responde con instantáneas.
##
## Uso previsto:
##   Servidor dedicado: var t = TransporteENet.new(); add_child(t); t.crear_servidor(servidor, 7777)
##   Cliente:           var t = TransporteENet.new(); add_child(t); t.unirse("ip", 7777)
## Nota: este nodo debe tener la misma ruta en servidor y cliente (p. ej. /root/Red).

var servidor: ServidorJuego = null
var plantilla_por_defecto := "jugador_uchiha"


func crear_servidor(p_servidor: ServidorJuego, puerto := 7777, max_clientes := 8) -> Error:
	servidor = p_servidor
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(puerto, max_clientes)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_conectado)
	multiplayer.peer_disconnected.connect(_on_peer_desconectado)
	servidor.estado_generado.connect(_on_estado_servidor)
	return OK


func unirse(direccion: String, puerto := 7777) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(direccion, puerto)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.server_disconnected.connect(func(): desconectado.emit())
	return OK


func enviar(cmd: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	# Las entradas continuas viajan sin garantía; las acciones, de forma fiable.
	if str(cmd.get("t", "")) == Protocolo.C_ENTRADA:
		_rpc_comando_rapido.rpc_id(1, cmd)
	else:
		_rpc_comando.rpc_id(1, cmd)


# ---- servidor

func _on_peer_conectado(peer_id: int) -> void:
	var id := servidor.agregar_jugador(peer_id, plantilla_por_defecto)
	_rpc_bienvenida.rpc_id(peer_id, id)


func _on_peer_desconectado(peer_id: int) -> void:
	servidor.quitar_jugador(peer_id)


func _on_estado_servidor(peer_id: int, estado: Dictionary) -> void:
	_rpc_estado.rpc_id(peer_id, estado)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_comando(cmd: Dictionary) -> void:
	if servidor != null:
		servidor.recibir_comando(multiplayer.get_remote_sender_id(), cmd)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_comando_rapido(cmd: Dictionary) -> void:
	if servidor != null:
		servidor.recibir_comando(multiplayer.get_remote_sender_id(), cmd)


# ---- cliente

@rpc("authority", "call_remote", "reliable")
func _rpc_bienvenida(id_entidad: int) -> void:
	conectado.emit(id_entidad)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_estado(estado: Dictionary) -> void:
	estado_recibido.emit(estado)
