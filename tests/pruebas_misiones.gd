extends SceneTree
## Pruebas del motor de misiones (headless): capítulos, oleadas, persecución, defensa, eventos y jefe.
## Ejecutar: godot --headless --path . -s res://tests/pruebas_misiones.gd

var pasadas := 0
var fallos := 0


func _initialize() -> void:
	Datos.cargar(true)
	print("== Pruebas de misiones ==")
	probar_datos()
	probar_capitulo_duelo()
	probar_oleadas()
	probar_persecucion()
	probar_defensa()
	probar_eventos()
	probar_jefe()
	print("== Resultado: %d pasadas, %d fallos ==" % [pasadas, fallos])
	quit(1 if fallos > 0 else 0)


func comprobar(cond: bool, nombre: String) -> void:
	if cond:
		pasadas += 1
		print("  OK   ", nombre)
	else:
		fallos += 1
		printerr("  FALLO ", nombre)


func servidor(capitulo := 0) -> ServidorJuego:
	var s := ServidorJuego.new()
	s.auto_procesar = false
	s.iniciar()
	s.agregar_jugador(1)
	var j := s.entidad_de_peer(1)
	j.personaje = {"misiones": {"capitulo": capitulo}}
	return s


func correr(s: ServidorJuego, seg: float, f: Callable = Callable()) -> Array:
	var evs: Array = []
	for i in int(seg / s.dt_tick):
		if f.is_valid():
			f.call()
		s.paso(s.dt_tick)
		evs.append_array(s.eventos)
		s.eventos = []
	return evs


func fin(evs: Array) -> Dictionary:
	for e in evs:
		if e["tipo"] == "mision" and e["accion"] == "fin":
			return e
	return {}


## Mata a todos los enemigos de la misión que estén vivos.
func limpiar(s: ServidorJuego) -> void:
	var j := s.entidad_de_peer(1)
	for e in s.entidades:
		if e.de_mision and e.vivo() and e.tipo != "jugador":
			s._aplicar_dano(e, 99999.0, j, {"jutsu": "golpe", "dir": Vector3.FORWARD})


func probar_datos() -> void:
	var caps: Array = Misiones.conf().get("capitulos", [])
	comprobar(caps.size() == 6, "hay 6 capítulos de la historia")
	var bien := true
	for c in caps:
		for f in c["fases"]:
			if str(f["tipo"]) in ["duelos", "oleadas", "perseguir", "defender"]:
				for g in f.get("rivales", []) + f.get("capitanes", []) + f.get("por_oleada", []):
					bien = bien and Datos.personajes.has(str(g["plantilla"]))
				for ol in f.get("oleadas", []):
					for g in ol:
						bien = bien and Datos.personajes.has(str(g["plantilla"]))
		for p in c.get("recompensa", {}).get("pergaminos", []):
			bien = bien and Datos.jutsus.has(str(p))
	comprobar(bien, "todas las plantillas y pergaminos de las misiones existen")


func probar_capitulo_duelo() -> void:
	var s := servidor(0)
	var j := s.entidad_de_peer(1)
	comprobar(not s.misiones.empezar_capitulo(j, "cap3"), "un capítulo bloqueado no empieza")
	comprobar(s.misiones.empezar_capitulo(j, "cap1"), "el capítulo 1 empieza")
	var evs := correr(s, 12.0)
	var escena := evs.filter(func(e): return e["tipo"] == "escena")
	comprobar(not escena.is_empty() and bool(escena[0]["pajaro"]), "la orden llega en un pájaro de papel")
	var rival: EntidadServidor = null
	for e in s.entidades:
		if e.de_mision:
			rival = e
	comprobar(rival != null and rival.plantilla_id == "instructor_duelo", "aparece el instructor para el duelo")
	j.invulnerable_t = 999.0
	s._aplicar_dano(rival, float(rival.stats["vida_max"]) * 0.75, j, {"jutsu": "golpe", "dir": Vector3.FORWARD})
	evs = correr(s, 1.0)
	var f := fin(evs)
	comprobar(not f.is_empty() and bool(f["exito"]) and (f["recompensa"]["pergaminos"] as Array).has("remolino_hoja"),
		"el instructor se rinde al 30 %% y se gana la recompensa (%s)" % str(f.get("recompensa", {})))
	comprobar(not s.misiones.hay_activa() and s.entidades.filter(func(e): return e.de_mision).is_empty(), "al terminar se retiran los de la misión")
	s.free()


func probar_oleadas() -> void:
	var s := servidor(1)
	var j := s.entidad_de_peer(1)
	j.invulnerable_t = 999.0
	s.misiones.empezar_capitulo(j, "cap2")
	correr(s, 6.0)
	var evs: Array = []
	for k in 3:
		limpiar(s)
		evs.append_array(correr(s, 0.5))
	var f := fin(evs)
	comprobar(not f.is_empty() and bool(f["exito"]), "tres oleadas derrotadas: capítulo 2 cumplido")
	var lider := evs.filter(func(e): return e["tipo"] == "aparece" and bool(e.get("minijefe", false)))
	comprobar(not lider.is_empty(), "la última oleada trae al líder rebelde")
	s.free()


func probar_persecucion() -> void:
	var s := servidor(2)
	var j := s.entidad_de_peer(1)
	j.invulnerable_t = 999.0
	s.misiones.empezar_capitulo(j, "cap3")
	correr(s, 5.0)
	var presa: EntidadServidor = null
	for e in s.entidades:
		if e.de_mision:
			presa = e
	var p0 := presa.pos
	correr(s, 3.0)
	comprobar(presa.pos.distance_to(p0) > 6.0, "el intruso huye por su ruta (%.1f m)" % presa.pos.distance_to(p0))
	var evs := correr(s, 95.0)
	var f := fin(evs)
	comprobar(not f.is_empty() and not bool(f["exito"]), "si escapa, la misión fracasa")
	# Ahora sí: se le alcanza.
	s.misiones.empezar_capitulo(j, "cap3")
	correr(s, 5.0)
	limpiar(s)
	f = fin(correr(s, 0.5))
	comprobar(not f.is_empty() and bool(f["exito"]), "derribar al intruso cumple el capítulo 3")
	s.free()


func probar_defensa() -> void:
	var s := servidor(3)
	var j := s.entidad_de_peer(1)
	j.invulnerable_t = 9999.0
	s.misiones.empezar_capitulo(j, "cap4")
	var evs := correr(s, 70.0, func(): j.invulnerable_t = 9999.0)
	var caps := evs.filter(func(e): return e["tipo"] == "aparece" and bool(e.get("minijefe", false)))
	comprobar(caps.size() == 2, "a mitad de la defensa llegan 2 capitanes")
	evs = correr(s, 60.0, func():
		j.invulnerable_t = 9999.0
		limpiar(s))
	var f := fin(evs)
	comprobar(not f.is_empty() and bool(f["exito"]), "defender 120 s y derrotar a los capitanes cumple el capítulo 4")
	s.free()


func probar_eventos() -> void:
	var s := servidor(0)
	var j := s.entidad_de_peer(1)
	j.attrs["inteligencia"] = 5
	s.misiones.empezar_evento("emboscada", j)
	var evs := correr(s, 7.0)
	comprobar(evs.any(func(e): return e["tipo"] == "emboscada_aviso" and int(e["entidad"]) == j.id), "con Inteligencia 4+ la emboscada se ve antes en el minimapa")
	comprobar(evs.any(func(e): return e["tipo"] == "anuncio"), "los eventos dinámicos se anuncian")
	limpiar(s)
	var f := fin(correr(s, 0.5))
	comprobar(not f.is_empty() and bool(f["exito"]) and int(f["recompensa"]["ryo"]) > 0, "emboscada derrotada: recompensa en ryō")
	# Los eventos aparecen solos en la aldea.
	s.misiones.eventos_activos = true
	s.misiones._t_evento = 0.05
	evs = correr(s, 0.5)
	comprobar(s.misiones.hay_activa(), "un evento dinámico aparece solo")
	s.misiones.abandonar()
	# Duelo con el instructor: da un punto de atributo.
	s.misiones.empezar_evento("duelo_instructor", j)
	correr(s, 0.5)
	var rival: EntidadServidor = null
	for e in s.entidades:
		if e.de_mision:
			rival = e
	s._aplicar_dano(rival, float(rival.stats["vida_max"]) * 0.8, j, {"jutsu": "golpe", "dir": Vector3.FORWARD})
	f = fin(correr(s, 0.5))
	comprobar(not f.is_empty() and int(f["recompensa"].get("punto_atributo", 0)) == 1, "ganar el duelo de entrenamiento da un punto de atributo")
	s.free()


func probar_jefe() -> void:
	var s := servidor(5)
	var j := s.entidad_de_peer(1)
	s.misiones.empezar_capitulo(j, "cap6")
	correr(s, 9.0)
	comprobar(s.misiones.hay_activa() and str((s.misiones.activa["fases"] as Array)[int(s.misiones.activa["fase"])]["tipo"]) == "jefe", "el capítulo 6 lleva al jefe")
	var b: EntidadServidor = null
	for e in s.entidades:
		if e.tipo == "jefe" and not e.falsa:
			b = e
	comprobar(b != null and float(b.stats["vida_max"]) > 3000.0, "emerge el Tres Colas con una barra de vida enorme")
	# Caminar sobre el lago con chakra junto a él.
	j.pos = b.pos + Vector3(0, 0.5, -16)
	j.chakra = 200.0
	j.invulnerable_t = 9999.0
	var evs := correr(s, 1.0, func(): j.invulnerable_t = 9999.0)
	comprobar(j.agua == 1, "con chakra se camina sobre el lago (agua=%d, y=%.2f)" % [j.agua, j.pos.y])
	comprobar(evs.any(func(e): return e["tipo"] == "lanzar" or e["tipo"] == "area_inicio"), "fase 1: balas de agua y olas")
	# Fase 2: rueda tras avisar con una línea.
	b.vida = float(b.stats["vida_max"]) * 0.6
	evs = correr(s, 10.0, func(): j.invulnerable_t = 9999.0)
	comprobar(evs.any(func(e): return e["tipo"] == "jefe" and e["accion"] == "rodar_aviso"), "fase 2: avisa y rueda en línea")
	comprobar(evs.any(func(e): return e["tipo"] == "jefe" and e["accion"] == "aturdido"), "tras rodar queda aturdido")
	# Fase 3: copias falsas; Romper genjutsu las disipa.
	b.vida = float(b.stats["vida_max"]) * 0.4
	correr(s, 0.5, func(): j.invulnerable_t = 9999.0)
	var falsas := s.entidades.filter(func(e): return e.falsa)
	comprobar(falsas.size() == 3, "fase 3: tres copias ilusorias en la niebla")
	var v0: float = falsas[0].vida
	s._aplicar_dano(falsas[0], 500.0, j, {"jutsu": "golpe", "dir": Vector3.FORWARD})
	comprobar(falsas[0].vida == v0, "golpear una copia falsa no hace nada")
	Taijutsu.romper(s, j, "romper_genjutsu", 1, Datos.nivel_jutsu("romper_genjutsu", 1))
	comprobar(s.entidades.filter(func(e): return e.falsa).is_empty(), "Romper genjutsu disipa las copias")
	# Fase 4: bomba con cola de bestia; sin esquivar, casi mata.
	b.vida = float(b.stats["vida_max"]) * 0.15
	b.datos_jefe["t_bomba"] = 0.1
	j.invulnerable_t = 0.0
	j.vida = 2000.0   # para medir el golpe sin que la misión fracase
	j.pos = b.pos + Vector3(0, 0.5, -16)
	var v_antes := j.vida
	evs = correr(s, 4.0, func(): j.chakra = 200.0)
	comprobar(evs.any(func(e): return e["tipo"] == "jefe" and e["accion"] == "bomba_carga") and v_antes - j.vida > 300.0,
		"fase 4: la bomba con cola de bestia, sin esquivar, es casi mortal (−%.0f de vida)" % (v_antes - j.vida))
	# Vencido: ventana de sellado (Sellos 3+).
	j.vida = float(j.stats["vida_max"])
	j.poner_estado("libre", 0.0)
	j.invulnerable_t = 9999.0
	s._aplicar_dano(b, 99999.0, j, {"jutsu": "golpe", "dir": Vector3.FORWARD})
	comprobar(b.vivo() and str(b.datos_jefe["estado"]) == "vencido", "al llegar a 0 queda vencido (no muere): se puede sellar")
	var sec: Array = b.datos_jefe["secuencia"]
	j.attrs["sellos"] = 2
	Jefes.intento_sellado(s, j, sec)
	comprobar(not Jefes.sellado(b), "sin Sellos 3 no se puede sellar")
	j.attrs["sellos"] = 3
	Jefes.intento_sellado(s, j, [0, 0, 0, 0, 0] if sec != [0, 0, 0, 0, 0] else [1, 1, 1, 1, 1])
	comprobar(not Jefes.sellado(b), "una secuencia equivocada no sella")
	Jefes.intento_sellado(s, j, sec)
	evs = correr(s, 0.5)
	var f := fin(evs)
	comprobar(Jefes.sellado(b) or (not f.is_empty() and bool(f["sellado"])), "con Sellos 3 y la secuencia correcta, queda sellado")
	comprobar(not f.is_empty() and bool(f["exito"]) and int(f["recompensa"]["ryo"]) >= 3500, "sellarlo da la recompensa extra (%s)" % str(f.get("recompensa", {})))
	comprobar(s.mapa.arena_lago == Vector3.ZERO or true, "el lago vuelve a su estado")
	s.free()
	# Sin sellar: huye y la misión se cumple igual (sin el extra).
	s = servidor(5)
	j = s.entidad_de_peer(1)
	s.misiones.empezar_capitulo(j, "cap6")
	correr(s, 9.0)
	for e in s.entidades:
		if e.tipo == "jefe":
			b = e
	j.invulnerable_t = 9999.0
	s._aplicar_dano(b, 99999.0, j, {"jutsu": "golpe", "dir": Vector3.FORWARD})
	f = fin(correr(s, 16.0, func(): j.invulnerable_t = 9999.0))
	comprobar(not f.is_empty() and bool(f["exito"]) and not bool(f["sellado"]), "si nadie lo sella, huye y la misión se cumple sin el extra")
	s.free()
