class_name Protocolo
extends RefCounted
## Interfaz de comandos (cliente -> servidor) y estado (servidor -> cliente).
## Todo mensaje es un Dictionary con tipos que Godot serializa por red
## (int, float, String, Vector2, Vector3, Array, Dictionary).
##
## COMANDOS (cliente -> servidor):
##   {"t": "entrada", "mov": Vector2, "mira": float}   # movimiento en el plano XZ del mundo y yaw de la cámara
##   {"t": "accion", "id": String,                     # golpe, bola_fuego, chidori, sharingan, esquivar, saltar
##    "dir": Vector2, "objetivo": int, "exacto": bool}  # opcional: dirección XZ del disparo, objetivo fijado
##                                                     # (-1 = ninguno) y si la dirección es manual (sin asistencia)
##   {"t": "nivel", "valor": int}                      # depuración: nivel forzado 1..3 (0 = automático por maestría)
##   {"t": "repertorio", "activos": [id x4], "modo": id, "niveles_max": {id: 1..3},
##    "maestria": {id: xp}, "prueba": bool}             # repertorio elegido en el menú (el servidor lo valida)
##   {"t": "reaparecer"}                               # depuración: reinicia enemigo, muñecos y jugador
##   {"t": "personaje", "datos": {...}}                # personaje creado (Creacion.validar en el servidor)
##   (entrada lleva además "seq": número creciente para la predicción del cliente)
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
const C_REPERTORIO := "repertorio"
const C_PERSONAJE := "personaje"

## Acciones siempre disponibles; el resto son ids de jutsus de /data/jutsus.json.
const ACCIONES := ["golpe", "esquivar", "saltar", "modo"]


static func accion_valida(id: String) -> bool:
	if id in ACCIONES:
		return true
	Datos.cargar()
	return not id.begins_with("_") and Datos.jutsus.has(id)


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
			return {"t": C_ENTRADA, "mov": v, "mira": mira, "seq": maxi(int(c.get("seq", 0)), 0)}
		C_ACCION:
			var id := str(c.get("id", ""))
			if accion_valida(id):
				var r := {"t": C_ACCION, "id": id, "dir": Vector2.ZERO, "objetivo": -1, "exacto": false}
				var d: Variant = c.get("dir", Vector2.ZERO)
				if typeof(d) == TYPE_VECTOR2 and (d as Vector2).is_finite() and (d as Vector2).length() > 0.01:
					r["dir"] = (d as Vector2).normalized()
					r["exacto"] = bool(c.get("exacto", false))
				var o: Variant = c.get("objetivo", -1)
				if typeof(o) == TYPE_INT or typeof(o) == TYPE_FLOAT:
					r["objetivo"] = int(o)
				return r
		C_NIVEL:
			return {"t": C_NIVEL, "valor": clampi(int(c.get("valor", 0)), 0, 3)}
		C_REPERTORIO:
			var activos: Array = []
			var va: Variant = c.get("activos", [])
			if typeof(va) == TYPE_ARRAY:
				for a in (va as Array).slice(0, 4):
					activos.append(str(a) if (str(a) == "" or accion_valida(str(a))) else "")
			var niveles := {}
			var vn: Variant = c.get("niveles_max", {})
			if typeof(vn) == TYPE_DICTIONARY:
				for k in (vn as Dictionary).keys():
					if accion_valida(str(k)):
						niveles[str(k)] = clampi(int(vn[k]), 1, 3)
			var maestria := {}
			var vm: Variant = c.get("maestria", {})
			if typeof(vm) == TYPE_DICTIONARY:
				for k in (vm as Dictionary).keys():
					var xp := float(vm[k]) if (typeof(vm[k]) == TYPE_FLOAT or typeof(vm[k]) == TYPE_INT) else 0.0
					if accion_valida(str(k)) and is_finite(xp):
						maestria[str(k)] = clampf(xp, 0.0, 100000.0)
			var modo := str(c.get("modo", ""))
			return {"t": C_REPERTORIO, "activos": activos, "modo": modo if (modo == "" or accion_valida(modo)) else "",
				"niveles_max": niveles, "maestria": maestria, "prueba": bool(c.get("prueba", false))}
		C_REAPARECER:
			return {"t": C_REAPARECER}
		C_PERSONAJE:
			# El contenido lo valida Creacion.validar en el servidor; aquí solo se limita el tamaño.
			var dp: Variant = c.get("datos", {})
			if typeof(dp) == TYPE_DICTIONARY and JSON.stringify(dp).length() < 4000:
				return {"t": C_PERSONAJE, "datos": (dp as Dictionary).duplicate(true)}
	return {}
