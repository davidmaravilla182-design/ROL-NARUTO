extends SceneTree
## Prueba de jugabilidad de las misiones: un «jugador promedio» automático (personaje recién creado, Genin con 14
## puntos, sus jutsus iniciales, reacciones lentas) juega cada capítulo varias veces. Cada capítulo debe poder
## ganarse la mayoría de las veces. Ejecutar: godot --headless --path . -s res://tests/jugabilidad.gd
## Con INFORME=1 solo imprime la tabla (no falla).

const INTENTOS := 3
var pasadas := 0
var fallos := 0


func _initialize() -> void:
	Datos.cargar(true)
	print("== Jugabilidad de las misiones (jugador promedio) ==")
	var caps: Array = Misiones.conf().get("capitulos", [])
	for i in caps.size():
		var c: Dictionary = caps[i]
		var ganadas := 0
		var notas: Array = []
		for k in INTENTOS:
			var r := jugar(i, str(c["id"]), 100 + k * 17)
			if r["gano"]:
				ganadas += 1
			notas.append("%s %ds vida %d%%%s" % ["gana" if r["gano"] else "pierde(" + str(r["motivo"]) + ")", int(r["t"]), int(r["vida"] * 100), "" if r["gano"] else " (enemigos %.1f)" % r["resto"]])
			if k == 0 and OS.get_environment("INFORME") == "1":
				print("     daño recibido (vida máx %d): %s  %s" % [r["vida_max"], str(r["dano"]), str(r["stats"])])
		var ok := ganadas * 2 > INTENTOS   # mayoría
		var linea := "%s %-36s %d/%d  %s" % [c["id"], str(c["titulo"]).left(36), ganadas, INTENTOS, ", ".join(notas)]
		if OS.get_environment("INFORME") == "1":
			print("  ", linea)
		else:
			comprobar(ok, linea)
	# Arena: un jugador promedio debe superar al menos 3 rondas.
	var notas_a: Array = []
	var buenas := 0
	for k in INTENTOS:
		var r := jugar(0, "arena", 500 + k * 11)
		notas_a.append("%d rondas (%s %ds vida %d%% %s)" % [int(r.get("rondas", 0)), r["motivo"], int(r["t"]), int(r["vida"] * 100), str(r["dano"])])
		if int(r.get("rondas", 0)) >= 3:
			buenas += 1
	if OS.get_environment("INFORME") == "1":
		print("  arena (≥3 rondas)                  %d/%d  %s" % [buenas, INTENTOS, ", ".join(notas_a)])
	else:
		comprobar(buenas * 2 > INTENTOS, "arena: el jugador promedio supera 3 rondas (%s)" % ", ".join(notas_a))
	var eventos: Dictionary = Misiones.conf().get("eventos", {})
	for tipo in eventos.keys():
		if typeof(eventos[tipo]) != TYPE_DICTIONARY:
			continue
		var ganadas := 0
		var notas: Array = []
		for k in INTENTOS:
			var r := jugar(1, "evento:" + str(tipo), 300 + k * 13)
			if r["gano"]:
				ganadas += 1
			notas.append("%s %ds vida %d%%" % ["gana" if r["gano"] else "pierde(" + str(r["motivo"]) + ")", int(r["t"]), int(r["vida"] * 100)])
		var linea := "evento %-28s %d/%d  %s" % [tipo, ganadas, INTENTOS, ", ".join(notas)]
		if OS.get_environment("INFORME") == "1":
			print("  ", linea)
		else:
			comprobar(ganadas * 2 > INTENTOS, linea)
	print("== Resultado: %d pasadas, %d fallos ==" % [pasadas, fallos])
	quit(1 if fallos > 0 else 0)


func comprobar(cond: bool, nombre: String) -> void:
	if cond:
		pasadas += 1
		print("  OK   ", nombre)
	else:
		fallos += 1
		printerr("  FALLO ", nombre)


func jugar(indice: int, id: String, semilla: int) -> Dictionary:
	seed(semilla)
	var s := ServidorJuego.new()
	s.auto_procesar = false
	s.iniciar(Mapa.generar(Mapa.conf_arena()) if id == "arena" else null)
	s.agregar_jugador(1)
	var j := s.entidad_de_peer(1)
	var pj := Creacion.nuevo()
	pj["nombre"] = "Prueba"
	pj["misiones"] = {"capitulo": indice}
	if indice >= 4:
		pj["rango"] = "chunin" if indice < 5 else "jonin"   # el examen se hace siendo Genin avanzado; el jefe, ya ascendido
	s.recibir_comando(1, {"t": Protocolo.C_PERSONAJE, "datos": pj})
	j.personaje["misiones"] = {"capitulo": indice}
	if id == "arena":
		s.misiones.empezar_arena(j)
	elif id.begins_with("evento:"):
		s.misiones.empezar_evento(id.substr(7), j)
	else:
		s.misiones.empezar_capitulo(j, id)
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var t := 0.0
	var decision := 0.0
	var mov := Vector2.ZERO
	var leido: Dictionary = {}
	var t_jutsu := 2.0
	var resultado := {}
	var dano := {}
	var stats := {"golpes_j": 0, "impactos_j": 0, "atacando_2": 0.0, "ticks": 0, "golpes_npc": 0, "aturdido_j": 0.0}
	var limite := 400.0
	while t < limite:
		decision -= s.dt_tick
		t_jutsu -= s.dt_tick
		var obj := _objetivo(s, j)
		if decision <= 0.0 and j.vivo():
			decision = 0.2   # reacciona 5 veces por segundo
			mov = Vector2.ZERO
			if obj != null:
				var d := obj.pos - j.pos
				d.y = 0.0
				var dist := d.length()
				var mira := atan2(d.x, d.z)
				if dist > 2.0:
					mov = Vector2(d.x, d.z).normalized()
				s.recibir_comando(1, {"t": "entrada", "mov": mov, "mira": mira})
				# Esquiva a veces un golpe que viene (no siempre: es un jugador promedio).
				if obj.estado == "golpe" and dist < 3.0 and not is_same(obj.accion, leido):
					leido = obj.accion
					if rng.randf() < 0.3:
						s.recibir_comando(1, {"t": "accion", "id": "esquivar"})
				# Persecución: usa el impulso (shunshin) hacia el objetivo cuando está lejos.
				if dist > 7.0 and dist < 14.0 and j.recarga("esquivar") <= 0.0 and rng.randf() < 0.3:
					s.recibir_comando(1, {"t": "accion", "id": "esquivar", "objetivo": obj.id})
				elif dist < 2.4:
					s.recibir_comando(1, {"t": "accion", "id": "golpe"})
				elif t_jutsu <= 0.0 and dist < 14.0:
					# Un jutsu de su repertorio cada pocos segundos.
					for jid in j.repertorio.get("activos", []):
						if str(jid) != "" and j.recarga(str(jid)) <= 0.0:
							s.recibir_comando(1, {"t": "accion", "id": str(jid), "objetivo": obj.id, "dir": Vector3(d.x, 0, d.z).normalized()})
							break
					t_jutsu = 4.0
			else:
				s.recibir_comando(1, {"t": "entrada", "mov": Vector2.ZERO, "mira": j.yaw})
		elif j.vivo() and obj != null and mov != Vector2.ZERO:
			pass
		s.paso(s.dt_tick)
		t += s.dt_tick
		if OS.get_environment("TRAZA") != "" and int(t * 30) % 150 == 0:
			for e in s.entidades:
				if e.tipo == "jefe" or e.plantilla_id == "tres_colas":
					print("     t=%d jefe id %d vida %.0f/%.0f falsa %s oculto %s estado %s jefe %s fase %s | jugador estado %s" % [int(t), e.id, e.vida, float(e.stats["vida_max"]), e.falsa, e.oculto, e.estado, str(e.datos_jefe.get("estado", "")), str(e.datos_jefe.get("fase", "")), j.estado])
				if e.plantilla_id == "intruso":
					print("     t=%d intruso %s estado %s ruta %d acorr %.1f | jugador %s estado %s" % [int(t), str(e.pos.snapped(Vector3.ONE * 0.1)), e.estado, e.ia.ruta_i, e.ia.t_acorralado, str(j.pos.snapped(Vector3.ONE * 0.1)), j.estado])
		var at := 0
		for e in s.entidades:
			if e.de_mision and e.vivo() and e.estado == "golpe" and e.pos.distance_to(j.pos) < 3.0:
				at += 1
		if at >= 2:
			stats["atacando_2"] += s.dt_tick
		if j.estado != "libre" and j.estado != "golpe":
			stats["e_" + j.estado] = float(stats.get("e_" + j.estado, 0.0)) + s.dt_tick
		for ev in s.eventos:
			if ev["tipo"] == "mision" and ev["accion"] == "fin":
				resultado = ev
			if ev["tipo"] == "golpe" and int(ev["entidad"]) == j.id:
				stats["golpes_j"] += 1
			if ev["tipo"] == "impacto" and int(ev["atacante"]) == j.id:
				stats["impactos_j"] += 1
				stats["dano_j"] = int(stats.get("dano_j", 0)) + int(float(ev["cantidad"]))
				var oe := s.entidad(int(ev["entidad"]))
				if oe != null:
					stats["a_" + oe.plantilla_id] = int(stats.get("a_" + oe.plantilla_id, 0)) + int(float(ev["cantidad"]))
			if ev["tipo"] in ["bloqueado", "sustitucion", "esquivado", "humo", "genjutsu_npc"]:
				stats[ev["tipo"]] = int(stats.get(ev["tipo"], 0)) + 1
			if ev["tipo"] == "aparece":
				stats["aparecen"] = int(stats.get("aparecen", 0)) + 1
			if ev["tipo"] == "impacto" and int(ev["entidad"]) == j.id:
				var kk := str(ev.get("jutsu", ""))
				dano[kk] = int(dano.get(kk, 0)) + int(float(ev["cantidad"]))
		s.eventos = []
		if not resultado.is_empty():
			break
		if not j.vivo():
			resultado = {"exito": false, "motivo": "muerto"}
			if id == "arena" and s.misiones.hay_activa():
				resultado["recompensa"] = {"ronda": maxi(int(s.misiones.activa["datos"].get("ronda", 1)) - 1, 0)}
			break
	if OS.get_environment("TRAZA") != "":
		for e in s.entidades:
			if e.de_mision:
				print("     fin: ", e.plantilla_id, " vida ", e.vida, " pos ", e.pos, " estado ", e.estado, " oculto ", e.oculto, " ruta_i ", e.ia.ruta_i if e.ia != null else -1, " jugador ", j.pos)
	var resto := 0.0
	for e in s.entidades:
		if (e.de_mision or e.tipo == "jefe") and e.vivo() and not e.falsa:
			resto += e.vida / float(e.stats["vida_max"])
	var r := {"rondas": int(resultado.get("recompensa", {}).get("ronda", 0)), "resto": resto, "gano": bool(resultado.get("exito", false)), "t": t, "vida": j.vida / float(j.stats["vida_max"]),
		"motivo": str(resultado.get("motivo", "tiempo" if resultado.is_empty() else "falló")), "dano": dano, "stats": stats, "vida_max": int(j.stats["vida_max"])}
	s.free()
	return r


func _objetivo(s: ServidorJuego, j: EntidadServidor) -> EntidadServidor:
	var mejor: EntidadServidor = null
	for e in s.entidades:
		if e == j or not e.vivo() or e.oculto or e.equipo == j.equipo or e.tipo == "muneco" or e.falsa:
			continue
		if not (e.de_mision or e.tipo == "jefe"):
			continue
		if mejor == null or e.pos.distance_to(j.pos) < mejor.pos.distance_to(j.pos):
			mejor = e
	return mejor
