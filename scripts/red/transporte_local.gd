class_name TransporteLocal
extends Transporte
## Modo offline: servidor y cliente en el mismo proceso.
## Copia profunda en ambos sentidos para que nadie comparta referencias,
## igual que si los datos viajaran por la red.

const PEER_LOCAL := 1

var servidor: ServidorJuego


func iniciar(p_servidor: ServidorJuego, plantilla := "jugador_uchiha") -> void:
	servidor = p_servidor
	servidor.estado_generado.connect(_on_estado)
	var id := servidor.agregar_jugador(PEER_LOCAL, plantilla)
	conectado.emit.call_deferred(id)


func enviar(cmd: Dictionary) -> void:
	if servidor != null:
		servidor.recibir_comando(PEER_LOCAL, cmd.duplicate(true))


func _on_estado(peer_id: int, estado: Dictionary) -> void:
	if peer_id == PEER_LOCAL:
		estado_recibido.emit(estado.duplicate(true))
