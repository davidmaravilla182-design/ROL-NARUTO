class_name EntidadServidor
extends RefCounted
## Estado autoritativo de un personaje (jugador, enemigo o muñeco) en el servidor.

var id := 0
var peer_id := 0
var plantilla_id := ""
var tipo := ""          # jugador / enemigo / muneco
var equipo := 0
var nombre := ""
var attrs: Dictionary = {}
var stats: Dictionary = {}
var naturalezas: Array = []
var jutsus: Array = []

var pos := Vector3.ZERO
var inicio := Vector3.ZERO
var yaw := 0.0
var vel_y := 0.0
var empuje := Vector3.ZERO    # velocidad externa (esquiva, retroceso) que decae
var en_suelo := true
var en_charco := false

var vida := 100.0
var chakra := 100.0
var estamina := 100.0

var estado := "libre"
var estado_t := 0.0
var estado_total := 0.0
var accion: Dictionary = {}   # datos de la acción en curso (jutsu, nivel, dirección...)
var recargas: Dictionary = {}
var sharingan := false
var nivel_poder := 1
var combo_paso := 0
var combo_ventana := 0.0
var invulnerable_t := 0.0

var entrada_mov := Vector2.ZERO
var entrada_mira := 0.0

var ia: RefCounted = null


func configurar(plantilla: String, p_id: int) -> void:
	id = p_id
	plantilla_id = plantilla
	var d := Datos.personaje(plantilla)
	tipo = str(d.get("tipo", "muneco"))
	nombre = str(d.get("nombre", plantilla))
	attrs = d.get("atributos", {}).duplicate()
	naturalezas = d.get("naturalezas", []).duplicate()
	jutsus = d.get("jutsus", []).duplicate()
	stats = Combate.estadisticas(attrs)
	if d.has("vida_fija"):
		stats["vida_max"] = float(d["vida_fija"])
	reiniciar()


func reiniciar() -> void:
	pos = inicio
	vel_y = 0.0
	empuje = Vector3.ZERO
	vida = stats["vida_max"]
	chakra = stats["chakra_max"]
	estamina = stats["estamina_max"]
	estado = "libre"
	estado_t = 0.0
	estado_total = 0.0
	accion = {}
	recargas = {}
	sharingan = false
	combo_paso = 0
	combo_ventana = 0.0
	invulnerable_t = 0.0


func vivo() -> bool:
	return estado != "muerto"


func naturaleza_principal() -> String:
	return str(naturalezas[0]) if naturalezas.size() > 0 else ""


func adelante() -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


func pos2() -> Vector2:
	return Vector2(pos.x, pos.z)


func centro() -> Vector3:
	return pos + Vector3(0, Datos.sim("altura_golpe"), 0)


func poner_estado(nombre_estado: String, duracion: float, datos: Dictionary = {}) -> void:
	estado = nombre_estado
	estado_t = duracion
	estado_total = duracion
	accion = datos


func recarga(jutsu_id: String) -> float:
	return float(recargas.get(jutsu_id, 0.0))


func a_estado() -> Dictionary:
	var r := {}
	for k in recargas.keys():
		if float(recargas[k]) > 0.0:
			r[k] = snappedf(float(recargas[k]), 0.01)
	return {
		"id": id,
		"tipo": tipo,
		"plantilla": plantilla_id,
		"pos": pos,
		"yaw": yaw,
		"vida": vida,
		"vida_max": float(stats["vida_max"]),
		"chakra": chakra,
		"chakra_max": float(stats["chakra_max"]),
		"estamina": estamina,
		"estamina_max": float(stats["estamina_max"]),
		"estado": estado,
		"estado_t": estado_t,
		"estado_total": estado_total,
		"jutsu": str(accion.get("jutsu", "")),
		"paso": int(accion.get("paso", 0)),
		"nivel": nivel_poder,
		"sharingan": sharingan,
		"recargas": r,
		"en_suelo": en_suelo,
		"en_charco": en_charco,
	}
