class_name IaEnemigo
extends RefCounted
## IA simple del ninja enemigo. Corre en el servidor y actúa enviando los
## MISMOS comandos que un jugador (entrada / accion), así no tiene ventajas ocultas.
##
## Comportamiento: se acerca hasta su distancia preferida, rodea lateralmente,
## dispara ráfagas de balas de agua, golpea si lo tienes encima, esquiva a veces
## tus jutsus y huye cuando le queda poca vida.

var e: EntidadServidor
var conf: Dictionary
var rng := RandomNumberGenerator.new()
var lado := 1.0
var t_lado := 0.0
var t_reaccion := 0.0
var amenazas_vistas: Dictionary = {}
var anuncio_huida := false


func _init(entidad: EntidadServidor) -> void:
	e = entidad
	conf = Datos.personaje(e.plantilla_id).get("ia", {})
	rng.seed = 777 + e.id
	reiniciar()


func reiniciar() -> void:
	lado = 1.0
	t_lado = float(conf.get("cambio_lateral", 2.5))
	t_reaccion = 1.0
	amenazas_vistas.clear()
	anuncio_huida = false


func pensar(s: ServidorJuego, dt: float) -> void:
	t_lado -= dt
	t_reaccion -= dt
	if t_lado <= 0.0:
		t_lado = float(conf.get("cambio_lateral", 2.5)) * rng.randf_range(0.6, 1.4)
		lado = -lado
	var objetivo := s._jugador_mas_cercano(e.pos)
	if objetivo == null:
		s.aplicar_comando(e, {"t": "entrada", "mov": Vector2.ZERO, "mira": e.yaw})
		return

	var hacia := objetivo.pos - e.pos
	hacia.y = 0
	var dist := hacia.length()
	var dir := hacia / maxf(dist, 0.001)
	var lateral := Vector3(-dir.z, 0, dir.x) * lado
	var mov := Vector3.ZERO
	var huyendo := e.vida / float(e.stats["vida_max"]) < float(conf.get("umbral_huida", 0.25))

	if huyendo and not anuncio_huida:
		anuncio_huida = true
		s._evento({"tipo": "mensaje", "entidad": e.id, "clave": "enemigo_huye", "para_todos": true})

	# Esquivar amenazas (proyectiles o embiste de rayo que vienen hacia mí).
	if e.estado == "libre" and _amenaza(s):
		if rng.randf() < float(conf.get("prob_esquivar", 0.35)):
			var esc := lateral if rng.randf() < 0.5 else -lateral
			s.aplicar_comando(e, {"t": "entrada", "mov": Vector2(esc.x, esc.z), "mira": e.yaw})
			s.aplicar_comando(e, {"t": "accion", "id": "esquivar"})
			return

	var preferida := float(conf.get("distancia_preferida", 9.0))
	if huyendo:
		mov = -dir + lateral * 0.6
	elif dist > preferida + 2.0:
		mov = dir + lateral * 0.3
	elif dist < float(conf.get("rango_melee", 2.2)):
		mov = Vector3.ZERO
	elif dist < preferida - 3.0:
		mov = -dir * 0.8 + lateral * 0.5
	else:
		mov = lateral * 0.8

	if mov.length() > 1.0:
		mov = mov.normalized()
	s.aplicar_comando(e, {"t": "entrada", "mov": Vector2(mov.x, mov.z), "mira": atan2(dir.x, dir.z)})

	if e.estado != "libre" or t_reaccion > 0.0:
		return
	# Mirar al objetivo antes de actuar.
	e.yaw = atan2(dir.x, dir.z)
	if dist <= float(conf.get("rango_melee", 2.2)) and not huyendo:
		s.aplicar_comando(e, {"t": "accion", "id": "golpe"})
		t_reaccion = 0.15
	elif dist <= float(conf.get("rango_disparo", 17.0)) and e.recarga("bala_agua") <= 0.0:
		if not huyendo or rng.randf() < 0.5:
			s.aplicar_comando(e, {"t": "accion", "id": "bala_agua"})
			t_reaccion = float(conf.get("pausa_reaccion", 0.35)) + rng.randf() * 0.4


func _amenaza(s: ServidorJuego) -> bool:
	for p in s.proyectiles:
		if int(p["dueno"]) == e.id or amenazas_vistas.has(p["id"]):
			continue
		var pos: Vector3 = p["pos"]
		var a_mi := e.centro() - pos
		if a_mi.length() < 9.0 and (p["dir"] as Vector3).dot(a_mi.normalized()) > 0.8:
			amenazas_vistas[p["id"]] = true
			return true
	for o in s.entidades:
		if o.tipo != "jugador" or not o.vivo():
			continue
		var clave := "chidori_%d_%d" % [o.id, s.tick / 30]
		if o.estado == "chidori_carga" and o.pos.distance_to(e.pos) < 14.0 and o.estado_t < 0.25 and not amenazas_vistas.has(clave):
			amenazas_vistas[clave] = true
			return true
	return false
