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
var personaje: Dictionary = {}    # personaje creado por el jugador (vacío = plantilla de /data/personajes.json)
var aspecto: Dictionary = {}      # aspecto visual para dibujarlo en todos los clientes
var ultima_entrada := 0           # número de la última entrada procesada (predicción del cliente)
var jutsus: Array = []

var pos := Vector3.ZERO
var inicio := Vector3.ZERO
var yaw := 0.0
var vel_y := 0.0
var empuje := Vector3.ZERO    # velocidad externa (esquiva, retroceso) que decae
var en_suelo := true
var escalando := false   # subiendo por una pared con chakra
var sustitucion_t := 0.0   # ventana de esquiva justa: si te golpean ahora, sustitución con tronco
var flotar_t := 0.0       # combo aéreo: casi sin gravedad
var lanzado_id := -1       # a quién lanzó al aire (para saltar tras él)
var lanzado_t := 0.0
var golpes_aereos := 0
var oculto := false        # NPC que todavía no aparece (el rebelde): no se envía ni se simula
var muerto_t := 0.0        # segundos desde que murió (reaparición de los NPC)
var pared := Vector2.ZERO   # normal de la pared por la que corre (hacia afuera)
var agua := 0              # 0 en tierra, 1 caminando sobre el agua con chakra, 2 nadando (sin chakra)
var contacto_pared := 0.0   # segundos empujando contra una pared alta (la escalada empieza tras un instante)
var en_charco := false

var vida := 100.0
var chakra := 100.0
var estamina := 100.0

var estado := "libre"
var estado_t := 0.0
var estado_total := 0.0
var accion: Dictionary = {}   # datos de la acción en curso (jutsu, nivel, dirección...)
var recargas: Dictionary = {}
var sharingan := false          # modo ocular que ralentiza proyectiles (ojo rojo) activo
var nivel_poder := 0             # depuración: nivel forzado 1..3 (0 = automático por maestría)
var modo := ""                   # modo equipado en la ranura de modo
var modo_activo := false
var modo_nivel := 1
var repertorio: Dictionary = {}  # {activos, modo, niveles_max}
var maestria: Dictionary = {}    # {jutsu: xp}
var efectos: Dictionary = {}     # estados temporales: ardiendo, susanoo, vulnerable, armadura_negra, puertas
var ceguera := 0.0
var xp_modo_acum := 0.0
var combo_paso := 0
var combo_pos := -1
var entreno: Dictionary = {}   # barras de entrenamiento 0-1 por atributo (y "control")
var xp_total := 0.0        # posición dentro de la secuencia del combo (Atributos.secuencia_combo)
var combo_ventana := 0.0
var invulnerable_t := 0.0

var entrada_mov := Vector2.ZERO
var entrada_mira := 0.0
var apuntado: Dictionary = {}   # último {dir, objetivo, exacto} recibido con una acción

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
	if tipo == "jugador":
		aplicar_repertorio(Repertorio.repertorio_por_defecto(plantilla))
	stats = Combate.estadisticas(attrs)
	if d.has("vida_fija"):
		stats["vida_max"] = float(d["vida_fija"])
	# NPCs más resistentes (el remanente rebelde es un reto).
	stats["vida_max"] = float(stats["vida_max"]) * float(d.get("ia", {}).get("vida_mult", 1.0))
	reiniciar()


func reiniciar() -> void:
	pos = inicio
	vel_y = 0.0
	empuje = Vector3.ZERO
	vida = stats["vida_max"]
	chakra = stats["chakra_max"]
	estamina = stats["estamina_max"]
	estado = "libre"
	muerto_t = 0.0
	estado_t = 0.0
	estado_total = 0.0
	accion = {}
	recargas = {}
	sharingan = false
	modo_activo = false
	efectos = {}
	ceguera = 0.0
	combo_paso = 0
	combo_pos = -1
	combo_ventana = 0.0
	invulnerable_t = 0.0
	apuntado = {}


## Configura la entidad a partir de un personaje creado (ya validado con Creacion.validar).
func configurar_personaje(pj: Dictionary) -> void:
	personaje = pj.duplicate(true)
	nombre = str(pj.get("nombre", nombre))
	attrs = (pj.get("atributos", {}) as Dictionary).duplicate()
	# Entrenamiento por uso y experiencia del personaje.
	entreno = (pj.get("entreno", {}) as Dictionary).duplicate()
	var ent := {}
	for k in entreno.keys():
		ent[k] = float(entreno[k]) * float(Datos.reglas.get("entrenamiento", {}).get("bonus_max", 0.5))
	attrs["_entreno"] = ent
	xp_total = float(pj.get("xp_total", 0.0))
	naturalezas = Creacion.naturalezas(pj)
	stats = Creacion.estadisticas(pj)
	aspecto = Creacion.aspecto_visual(pj)
	aspecto["clan"] = str(pj.get("clan", ""))
	aspecto["aldea"] = str(pj.get("aldea", "lluvia"))
	vida = stats["vida_max"]
	chakra = stats["chakra_max"]
	estamina = stats["estamina_max"]
	aplicar_repertorio(Creacion.repertorio_inicial(pj))


## Ficha para las reglas del repertorio: la del personaje creado o la de la plantilla.
func ficha() -> Dictionary:
	if personaje.is_empty():
		return Repertorio.ficha(plantilla_id, maestria)
	return Creacion.ficha(personaje, maestria)


## Repertorio por defecto según el personaje.
func repertorio_defecto() -> Dictionary:
	if personaje.is_empty():
		return Repertorio.repertorio_por_defecto(plantilla_id)
	return Creacion.repertorio_inicial(personaje)


## Equipa un repertorio ya validado: técnicas base + activos + modo.
func aplicar_repertorio(rep: Dictionary) -> void:
	repertorio = rep
	jutsus = Repertorio.MODOS_BASE.duplicate()
	for a in rep.get("activos", []):
		if str(a) != "":
			jutsus.append(str(a))
	modo = str(rep.get("modo", ""))
	if modo != "":
		jutsus.append(modo)
	modo_activo = false
	sharingan = false


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


func _efectos_estado() -> Dictionary:
	var r := {}
	for k in efectos.keys():
		r[k] = {"t": snappedf(minf(float(efectos[k]["t"]), 999.0), 0.01), "nivel": int(efectos[k].get("nivel", 1))}
		if efectos[k].has("forma"):
			r[k]["forma"] = efectos[k]["forma"]
			r[k]["jutsu"] = efectos[k].get("jutsu", "")
	return r


## Nivel efectivo de cada técnica equipada (para que el cliente muestre costos y efectos).
func _niveles_estado() -> Dictionary:
	var r := {}
	for j in jutsus:
		if j in Repertorio.MODOS_BASE:
			continue
		r[j] = Repertorio.nivel_efectivo(j, float(maestria.get(j, 0.0)), int(repertorio.get("niveles_max", {}).get(j, 3)), nivel_poder)
	return r


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
		"modo": modo,
		"modo_activo": modo_activo,
		"ceguera": ceguera,
		"efectos": _efectos_estado(),
		"niveles": _niveles_estado(),
		"nombre": nombre,
		"equipo": equipo,
		"ultima_entrada": ultima_entrada,
		"vel_mov": float(stats["velocidad"]) * Tecnicas.multiplicador_velocidad(self),
		"empuje": empuje.length() > 0.05,
		"recargas": r,
		"en_suelo": en_suelo,
		"escalando": escalando,
		"pared": pared,
		"agua": agua,
		"en_charco": en_charco,
	}
