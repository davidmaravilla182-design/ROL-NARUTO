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
var ruta: Array = []    # perfil "huir": puntos que recorre (techos); al llegar al último, escapa
var ruta_i := 0
# Ritmo del cuerpo a cuerpo (data/reglas.json → ia_cuerpo_a_cuerpo; cada NPC puede sobrescribirlo en su "ia"):
# tras un combo descansa (hueco para el jugador), no siempre lo termina y tras recibir un golpe tarda en responder.
var _estado_antes := "libre"
var _accion_leida: Dictionary = {}   # el golpe del jugador que ya evaluó (una decisión por golpe, no por tick)


func _init(entidad: EntidadServidor) -> void:
	e = entidad
	conf = (Datos.personaje(e.plantilla_id).get("ia", {}) as Dictionary).duplicate()   # copia: las misiones lo ajustan por entidad
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


func _ritmo(clave: String, defecto: Variant) -> Variant:
	if conf.has(clave):
		return conf[clave]
	return (Datos.reglas.get("ia_cuerpo_a_cuerpo", {}) as Dictionary).get(clave, defecto)


func pensar(s: ServidorJuego, dt: float) -> void:
	# Transiciones de estado: fin del combo propio → descanso; fin de una reacción a golpe → pausa antes de responder.
	if e.estado != _estado_antes:
		if e.estado == "libre" and _estado_antes == "golpe":
			var dc: Array = _ritmo("descanso_combo", [0.9, 1.5])
			t_reaccion = maxf(t_reaccion, rng.randf_range(float(dc[0]), float(dc[1])))
		elif e.estado == "libre" and _estado_antes in ["golpeado", "derribado", "aturdido", "lanzado", "bloqueo"]:
			t_reaccion = maxf(t_reaccion, float(_ritmo("pausa_tras_golpeado", 0.5)) + rng.randf() * 0.3)
		_estado_antes = e.estado
	t_lado -= dt
	t_reaccion -= dt
	if t_lado <= 0.0:
		t_lado = float(conf.get("cambio_lateral", 2.5)) * rng.randf_range(0.6, 1.4)
		lado = -lado
	t_genjutsu -= dt
	t_humo -= dt
	var objetivo := s._jugador_mas_cercano(e.pos)
	# Intruso: corre por su ruta (sube por las paredes al toparse con ellas); si lo alcanzan, se defiende.
	if perfil == "huir" and not ruta.is_empty():
		if ruta_i < ruta.size():
			var meta: Vector3 = ruta[ruta_i]
			var v := meta - e.pos
			v.y = 0.0
			if v.length() < 3.0:
				ruta_i += 1
			var mv := Vector2(v.x, v.z).normalized()
			s.aplicar_comando(e, {"t": "entrada", "mov": mv, "mira": atan2(mv.x, mv.y)})
			if objetivo != null and objetivo.pos.distance_to(e.pos) < 2.5 and e.estado == "libre" and rng.randf() < 0.05:
				s.aplicar_comando(e, {"t": "accion", "id": "esquivar"})
		return
	# Oscuridad: ciego, pierde de vista al jugador y tantea a ciegas.
	if e.efectos.has("ciego"):
		var giro := Vector2(sin(t_lado * 3.0), cos(t_lado * 2.0)) * 0.25
		s.aplicar_comando(e, {"t": "entrada", "mov": giro, "mira": e.yaw + 0.05})
		return
	# Visión del Infierno: huye de quien se lo lanzó.
	if e.efectos.has("miedo"):
		var fuente := s.entidad(int(e.efectos["miedo"].get("fuente", -1)))
		var de: Vector3 = fuente.pos if fuente != null else (objetivo.pos if objetivo != null else e.pos)
		var lejos := e.pos - de
		lejos.y = 0.0
		var m2 := Vector2(lejos.x, lejos.z).normalized() if lejos.length() > 0.1 else Vector2(1, 0)
		s.aplicar_comando(e, {"t": "entrada", "mov": m2, "mira": atan2(m2.x, m2.y)})
		return
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
	# Cada paso se decide una vez (prob_seguir_combo): a veces corta el combo y deja el hueco.
	if e.estado == "golpe" and e.combo_pos < int(conf.get("combo_max", 3)) - 1 and e.combo_paso < 10 and dist < float(conf.get("rango_melee", 2.2)) + 1.5:
		if not e.accion.has("_ia_seguir"):
			e.accion["_ia_seguir"] = rng.randf() < float(_ritmo("prob_seguir_combo", 0.6))
		if e.accion["_ia_seguir"]:
			s.aplicar_comando(e, {"t": "accion", "id": "golpe"})
	# Sustitución: si el jugador está a punto de golpearlo de frente, a veces deja un tronco.
	# Se decide UNA vez por golpe del jugador (antes se volvía a sortear en cada tick y casi siempre lo paraba).
	if _golpe_inminente(objetivo) and not is_same(objetivo.accion, _accion_leida) and e.recarga("sustitucion") <= 0.0 and e.sustitucion_t <= 0.0:
		_accion_leida = objetivo.accion
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
