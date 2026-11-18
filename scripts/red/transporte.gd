class_name Transporte
extends Node
## Interfaz común entre cliente y servidor. El cliente SOLO conoce esta clase:
##   - enviar(cmd)            -> manda un comando al servidor
##   - señal estado_recibido  <- llega una instantánea del servidor
## Implementaciones: TransporteLocal (mismo proceso) y TransporteENet (red).

signal estado_recibido(estado: Dictionary)
signal conectado(id_entidad: int)
signal desconectado()


func enviar(_cmd: Dictionary) -> void:
	push_error("Transporte.enviar no implementado")
