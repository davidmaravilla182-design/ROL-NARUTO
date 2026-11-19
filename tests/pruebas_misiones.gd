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
	s.free()
