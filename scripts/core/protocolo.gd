class_name Protocolo
extends RefCounted
## Interfaz de comandos (cliente -> servidor) y estado (servidor -> cliente).
## Todo mensaje es un Dictionary con tipos que Godot serializa por red
## (int, float, String, Vector2, Vector3, Array, Dictionary).
##
## COMANDOS (cliente -> servidor):
##   {"t": "entrada", "mov": Vector2, "mira": float}   # movimiento en el plano XZ del mundo y yaw de la cámara
##   {"t": "accion", "id": String}                     # golpe, bola_fuego, chidori, sharingan, esquivar, saltar
##   {"t": "nivel", "valor": int}                      # depuración: nivel de poder 1..3
##   {"t": "reaparecer"}                               # depuración: reinicia enemigo, muñecos y jugador
##
## ESTADO (servidor -> cliente), una instantánea por tick:
##   {"tick": int, "clima": String, "tu_entidad": int,
##    "entidades": [ {id, tipo, plantilla, pos, yaw, vida, vida_max, chakra, chakra_max,
##                    estamina, estamina_max, estado, estado_t, estado_total, jutsu, nivel,
##                    sharingan, recargas, en_suelo, en_charco} ],
##    "proyectiles": [ {id, jutsu, pos, dir, radio, nivel, dueno} ],
##    "eventos": [ {tipo: String, ...} ] }
##
## EVENTOS: sellos, lanzar, chidori_carga, chidori_embiste, impacto, explosion,
##          cadena, aviso, esquiva, derrota, salto, golpe, sharingan, nivel, reaparecer, mensaje

const C_ENTRADA := "entrada"
const C_ACCION := "accion"
const C_NIVEL := "nivel"
const C_REAPARECER := "reaparecer"

const ACCIONES := ["golpe", "bola_fuego", "chidori", "sharingan", "esquivar", "saltar"]


## Valida y normaliza un comando que llega de un cliente (posible red no confiable).
static func sanear_comando(cmd: Variant) -> Dictionary:
	if typeof(cmd) != TYPE_DICTIONARY:
		return {}
	var c: Dictionary = cmd
	match str(c.get("t", "")):
		C_ENTRADA:
			var mov: Variant = c.get("mov", Vector2.ZERO)
			if typeof(mov) != TYPE_VECTOR2:
				mov = Vector2.ZERO
			var v: Vector2 = mov
			if v.length() > 1.0:
				v = v.normalized()
			if not v.is_finite():
				v = Vector2.ZERO
			var mira := float(c.get("mira", 0.0))
			if not is_finite(mira):
				mira = 0.0
			return {"t": C_ENTRADA, "mov": v, "mira": mira}
		C_ACCION:
			var id := str(c.get("id", ""))
			if id in ACCIONES:
				return {"t": C_ACCION, "id": id}
		C_NIVEL:
			return {"t": C_NIVEL, "valor": clampi(int(c.get("valor", 1)), 1, 3)}
		C_REAPARECER:
			return {"t": C_REAPARECER}
	return {}
