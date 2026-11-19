class_name Jefes
extends RefCounted
## Jefes (bijuu). Ver DISENO.md §4. Se completa en el paso 4.

static func crear(s: ServidorJuego, id: String, pos: Vector3) -> EntidadServidor:
	var e := s._crear_entidad("ninja_lluvia", pos)
	e.equipo = 2
	return e


static func actualizar(_s: ServidorJuego, _dt: float) -> void:
	pass


static func derrotado(e: EntidadServidor) -> bool:
	return e == null or not e.vivo()


static func sellado(_e: EntidadServidor) -> bool:
	return false


static func intento_sellado(_s: ServidorJuego, _e: EntidadServidor, _sellos: Array) -> void:
	pass
