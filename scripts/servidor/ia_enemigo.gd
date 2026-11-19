class_name IaEnemigo
extends RefCounted
## IA simple del ninja enemigo. Corre en el servidor y actúa enviando los
## MISMOS comandos que un jugador (entrada / accion), así no tiene ventajas ocultas.
##
## Comportamiento: se acerca hasta su distancia preferida, rodea lateralmente,
## dispara ráfagas de balas de agua, golpea si lo tienes encima, esquiva a veces
## tus jutsus y huye cuando le queda poca vida.
## Perfiles (data/personajes.json → ia.perfil): "agresivo" (cuerpo a cuerpo con kunai, se pega),
## "distancia" (jutsus de agua y mantiene la distancia), "rebelde" (genjutsu que nubla y bombas de humo).
## Los NPC de la aldea solo atacan dentro de su radio de detección ("aggro") y si no, vuelven a su puesto.

var e: EntidadServidor
var conf: Dictionary
var rng := RandomNumberGenerator.new()
var lado := 1.0
var t_lado := 0.0
var t_reaccion := 0.0
var amenazas_vistas: Dictionary = {}
var anuncio_huida := false
var perfil := ""
var t_genjutsu := 0.0
var t_humo := 0.0


func _init(entidad: EntidadServidor) -> void:
	e = entidad
	conf = Datos.personaje(e.plantilla_id).get("ia", {})
	perfil = str(conf.get("perfil", ""))
	rng.seed = 777 + e.id
	reiniciar()


func reiniciar() -> void:
	lado = 1.0
	t_lado = float(conf.get("cambio_lateral", 2.5))
	t_reaccion = 2.5
	amenazas_vistas.clear()
	anuncio_huida = false
	t_genjutsu = float(conf.get("genjutsu_recarga", 10.0)) * 0.4
	t_humo = 2.0


func pensar(s: ServidorJuego, dt: float) -> void:
	t_lado -= dt
	t_reaccion -= dt
	if t_lado <= 0.0:
		t_lado = float(conf.get("cambio_lateral", 2.5)) * rng.randf_range(0.6, 1.4)
		lado = -lado
	t_genjutsu -= dt
	t_humo -= dt
	var objetivo := s._jugador_mas_cercano(e.pos)
	# Radio de detección: fuera de él, el NPC vuelve a su puesto y espera.
	if objetivo != null and conf.has("aggro") and objetivo.pos.distance_to(e.pos) > float(conf["aggro"]):
		objetivo = null
	if objetivo == null:
		var a_casa := e.inicio - e.pos
		a_casa.y = 0.0
		var m := Vector2(a_casa.x, a_casa.z).normalized() * 0.6 if a_casa.length() > 1.5 else Vector2.ZERO
		s.aplicar_comando(e, {"t": "entrada", "mov": m, "mira": e.yaw})
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
	if perfil == "agresivo":
		mov = dir + lateral * 0.25 if dist > float(conf.get("rango_melee", 2.2)) * 0.8 else lateral * 0.3
	elif perfil == "distancia" and dist < float(conf.get("distancia_minima", 7.0)):
		mov = -dir + lateral * 0.4   # mantiene la distancia
	elif huyendo:
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

	# Combos: el NPC encadena golpes hasta su máximo (agresivo: los 5 con la patada final).
	if e.estado == "golpe" and e.combo_pos < int(conf.get("combo_max", 3)) - 1 and e.combo_paso < 10 and dist < float(conf.get("rango_melee", 2.2)) + 1.5:
		s.aplicar_comando(e, {"t": "accion", "id": "golpe"})
	# Sustitución: si el jugador está a punto de golpearlo de frente, a veces deja un tronco.
	if _golpe_inminente(objetivo) and e.recarga("sustitucion") <= 0.0 and e.sustitucion_t <= 0.0:
		var r := rng.randf()
		if r < float(conf.get("prob_sustitucion", 0.0)):
			s.aplicar_comando(e, {"t": "accion", "id": "esquivar"})
			return
		# Guardia: el agresivo levanta los brazos y para el golpe (Fuerza 3+ se la rompe).
		if r < float(conf.get("prob_sustitucion", 0.0)) + float(conf.get("prob_bloqueo", 0.0)) and e.estado == "libre":
			s.bloquear(e)
			return
	if e.estado != "libre" or t_reaccion > 0.0:
		return
	# Mirar al objetivo antes de actuar.
	e.yaw = atan2(dir.x, dir.z)
	if perfil == "rebelde":
		if t_genjutsu <= 0.0 and dist <= float(conf.get("genjutsu_rango", 14.0)):
			t_genjutsu = float(conf.get("genjutsu_recarga", 12.0)) * rng.randf_range(0.8, 1.2)
			s.npc_genjutsu(e, objetivo, float(conf.get("genjutsu_duracion", 3.5)))
			t_reaccion = 0.6
			return
		if t_humo <= 0.0 and (dist < 3.0 or e.vida < float(e.stats["vida_max"]) * 0.5):
			t_humo = float(conf.get("humo_recarga", 9.0)) * rng.randf_range(0.8, 1.2)
			s.npc_humo(e, objetivo.pos)
			t_reaccion = 0.4
			return
	if perfil == "distancia" and dist <= 15.0 and e.recarga("dragon_agua") <= 0.0 and rng.randf() < 0.25:
		s.aplicar_comando(e, {"t": "accion", "id": "dragon_agua", "objetivo": objetivo.id})
		t_reaccion = 1.2
		return
	# Shunshin: a media distancia aparece de golpe junto al jugador (con estela de humo) y ataca.
	if dist > 4.0 and dist < 11.0 and not huyendo and e.recarga("shunshin") <= 0.0 and rng.randf() < float(conf.get("prob_shunshin", 0.0)) * dt * 3.0:
		s.aplicar_comando(e, {"t": "accion", "id": "esquivar", "objetivo": objetivo.id})
		t_reaccion = 0.25
		return
	if dist <= float(conf.get("rango_melee", 2.2)) and not huyendo:
		s.aplicar_comando(e, {"t": "accion", "id": "golpe"})
		t_reaccion = 0.15
	elif dist <= float(conf.get("rango_disparo", 17.0)) and e.recarga("bala_agua") <= 0.0:
		if not huyendo or rng.randf() < 0.5:
			s.aplicar_comando(e, {"t": "accion", "id": "bala_agua"})
			t_reaccion = float(conf.get("pausa_reaccion", 0.35)) + rng.randf() * 0.4


## ¿El jugador está a punto de conectar un golpe contra mí? (para la sustitución con tronco)
func _golpe_inminente(o: EntidadServidor) -> bool:
	if o == null or o.estado != "golpe" or o.accion.get("golpeado", true):
		return false
	if o.pos.distance_to(e.pos) > 3.2 or o.adelante().dot((e.pos - o.pos).normalized()) < 0.5:
		return false
	return o.estado_total - o.estado_t > 0.03


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
