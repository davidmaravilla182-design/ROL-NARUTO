extends SceneTree
## Pruebas de la creación de personaje: validación, clanes y linajes, naturalezas por rango,
## equilibrio reserva/control, sorteo de rareza para el modo en línea y uso del personaje en el servidor.
## Ejecutar: godot --headless --path . -s res://tests/pruebas_personaje.gd

var fallos := 0
var pasadas := 0


func _initialize() -> void:
	Datos.cargar(true)
	print("== Pruebas de personaje ==")
	probar_validacion()
	probar_clanes()
	probar_balance()
	probar_sorteo()
	probar_servidor()
	print("== Resultado: %d pasadas, %d fallos ==" % [pasadas, fallos])
	quit(1 if fallos > 0 else 0)


func comprobar(cond: bool, nombre: String) -> void:
	if cond:
		pasadas += 1
		print("  OK   ", nombre)
	else:
		fallos += 1
		printerr("  FALLO ", nombre)


func pj_base() -> Dictionary:
	var pj := Creacion.nuevo()
	pj["nombre"] = "Kaito"
	return pj


func probar_validacion() -> void:
	var v := Creacion.validar(Creacion.nuevo())
	comprobar(not v["ok"], "sin nombre no es válido")
	v = Creacion.validar(pj_base())
	comprobar(v["ok"], "el personaje por defecto con nombre es válido %s" % str(v["errores"]))
	var pj := pj_base()
	pj["atributos"]["ninjutsu"] = 5
	pj["atributos"]["sellos"] = 5
	pj["atributos"]["velocidad"] = 5
	pj["atributos"]["estamina"] = 5
	comprobar(not Creacion.validar(pj)["ok"], "más de 26 puntos no es válido (sin clan permite 27)")
	pj["rango"] = "elite"
	pj["atributos"]["estamina"] = 2
	pj["atributos"]["fuerza"] = 3
	pj["atributos"]["genjutsu"] = 3
	comprobar(Creacion.total_puntos(pj["atributos"]) == 27 and Creacion.validar(pj)["ok"], "27 puntos sin clan es válido en Élite (+1 de ventaja)")
	pj["clan"] = "uchiha"
	comprobar(not Creacion.validar(pj)["ok"], "27 puntos con un clan no es válido")
	# v0.9: tope por rango (14 Genin, 18 Chūnin, 22 Jōnin, 26 Élite) + hasta 2 ganados con experiencia.
	var g := pj_base()
	g["clan"] = "uchiha"
	comprobar(Creacion.tope_puntos(g) == 14, "un Genin nuevo tiene 14 puntos (%d)" % Creacion.tope_puntos(g))
	comprobar(Creacion.total_puntos(Creacion.nuevo()["atributos"]) == 14, "la creación empieza con los 14 puntos repartidos")
	g["xp_rango"] = 850.0
	comprobar(Creacion.tope_puntos(g) == 16, "con 850 XP de rango gana 2 puntos (%d)" % Creacion.tope_puntos(g))
	g["xp_rango"] = 5000.0
	comprobar(Creacion.tope_puntos(g) == 16, "antes de ascender no se ganan más de 2")
	g["rango"] = "chunin"
	g["xp_rango"] = 0.0
	comprobar(Creacion.tope_puntos(g) == 18, "Chūnin: 18 puntos")
	g["rango"] = "elite"
	g["xp_rango"] = 9999.0
	comprobar(Creacion.tope_puntos(g) == 26, "Élite: 26 puntos como máximo (nunca 40)")
	g["rango"] = "genin"
	g["xp_rango"] = 0.0
	g["puntos_legado"] = 20
	comprobar(Creacion.tope_puntos(g) == 20, "los personajes antiguos conservan sus puntos")
	var asc := pj_base()
	asc["xp_rango"] = 100.0
	comprobar(not Creacion.ascender(asc), "sin experiencia suficiente no se asciende")
	asc["xp_rango"] = 700.0
	comprobar(Creacion.ascender(asc) and str(asc["rango"]) == "chunin" and float(asc["xp_rango"]) == 0.0, "con 600 XP y la prueba superada se asciende a Chūnin")
	# Efectos de los atributos.
	var a0 := {"taijutsu": 1}
	var a5 := {"taijutsu": 5, "inteligencia": 5, "sellos": 5, "velocidad": 5, "genjutsu": 5, "estamina": 5}
	comprobar(Atributos.combo_largo(a0) == 3 and Atributos.combo_largo(a5) == 7, "combo de 3 golpes con Taijutsu 1 y de 7 con 5")
	comprobar(Atributos.secuencia_combo(7).size() == 7 and int(Atributos.secuencia_combo(3)[-1]) == 6, "el combo siempre acaba en la patada final")
	comprobar(Atributos.mult_recarga(a5) < Atributos.mult_recarga({}) , "Inteligencia acorta las recargas")
	comprobar(Atributos.ve_debilidad(a5) and not Atributos.ve_debilidad({"inteligencia": 2}), "con Inteligencia 3+ se ve la debilidad del rival")
	comprobar(Atributos.factor_sellos(a5) <= 0.16 and Atributos.una_mano({"sellos": 4}), "Sellos 4: una mano; Sellos 5: casi sin sellos")
	comprobar(Atributos.mult_duracion_genjutsu({"genjutsu": 5}, {}) > Atributos.mult_duracion_genjutsu({}, {"genjutsu": 5}) * 2.0, "Genjutsu alarga los tuyos y acorta los del enemigo")
	comprobar(Atributos.mult_costo_movil(a5) < 1.0 and Atributos.factor_ataque(a5) < 1.0, "Estamina abarata paredes/agua; Velocidad acorta los golpes")
	var ent := {"taijutsu": 2, "_entreno": {"taijutsu": 0.5}}
	comprobar(is_equal_approx(Atributos.v(ent, "taijutsu"), 2.5), "el entrenamiento suma hasta +0,5")
	for a in Atributos.LISTA:
		comprobar(Atributos.efectos_texto(a, a5).size() == 2, "la ficha describe el efecto de %s" % a)
	pj = pj_base()
	pj["atributos"]["ninjutsu"] = 9
	comprobar(int(Creacion.validar(pj)["pj"]["atributos"]["ninjutsu"]) == 5, "atributos fuera de rango se recortan a 5")
	pj = pj_base()
	pj["aldea"] = "hoja"
	comprobar(not Creacion.validar(pj)["ok"], "las aldeas 'Próximamente' no se pueden elegir")
	pj = pj_base()
	pj["aspecto"]["pelo"] = "no-es-color"
	pj["aspecto"]["peinado"] = "inventado"
	var a: Dictionary = Creacion.validar(pj)["pj"]["aspecto"]
	comprobar(Color.html_is_valid(str(a["pelo"])) and Creacion.conf()["peinados"].has(str(a["peinado"])), "aspecto saneado (color y peinado válidos)")


func probar_clanes() -> void:
	for id in Creacion.clanes().keys():
		var c: Dictionary = Creacion.clan(id)
		comprobar(c.has("ventaja") and c.has("desventaja") and Creacion.conf()["rarezas"].has(str(c.get("rareza", ""))), "clan %s con ventaja, desventaja y rareza" % id)
	var pj := pj_base()
	pj["clan"] = "lava"
	pj["naturalezas"] = ["viento"]
	comprobar(Creacion.naturalezas(Creacion.validar(pj)["pj"]) == ["fuego", "tierra"], "los linajes de kekkei genkai traen sus dos naturalezas")
	pj = pj_base()
	pj["naturalezas"] = ["fuego", "rayo"]
	comprobar(Creacion.naturalezas(pj) == ["fuego"], "en Genin solo cuenta la naturaleza innata")
	pj["rango"] = "chunin"
	comprobar(Creacion.naturalezas(pj) == ["fuego", "rayo"], "la segunda naturaleza se desbloquea en Chūnin")
	pj = pj_base()
	pj["clan"] = "uchiha"
	comprobar(Creacion.linajes(pj) == ["sharingan"], "Uchiha Genin: Sharingan")
	pj["rango"] = "jonin"
	comprobar("mangekyo" in Creacion.linajes(pj), "Uchiha Jōnin: despierta el Mangekyō")
	pj = pj_base()
	pj["clan"] = "hyuga"
	var f := Creacion.ficha(pj)
	comprobar(Repertorio.requisitos("byakugan", f, "byakugan")["ok"], "Hyūga puede equipar Byakugan")
	comprobar(not Repertorio.requisitos("sharingan", f, "sharingan")["ok"], "Hyūga no puede equipar Sharingan")
	pj = pj_base()
	pj["atributos"]["ninjutsu"] = 4
	pj["atributos"]["taijutsu"] = 5
	var r := Repertorio.requisitos("ocho_puertas", Creacion.ficha(pj), "ocho_puertas")
	comprobar(not r["ok"] and str(r["motivos"][0]).contains("Ninjutsu"), "Ocho Puertas bloqueada con motivo de ninjutsu: %s" % str(r["motivos"]))
	var s_base := Creacion.estadisticas(pj_base())
	pj = pj_base()
	pj["clan"] = "uchiha"
	var s_u := Creacion.estadisticas(pj)
	comprobar(float(s_u["chakra_max"]) > float(s_base["chakra_max"]) and float(s_u["vida_max"]) < float(s_base["vida_max"]), "modificadores del clan (Uchiha: +chakra, −vida)")


func probar_balance() -> void:
	var a := pj_base()["atributos"] as Dictionary
	var r0 := Combate.reserva(a)
	var c0 := Combate.control(a)
	a["_balance"] = 1.0
	comprobar(Combate.reserva(a) > r0 and Combate.control(a) < c0, "más reserva: jutsus más grandes; menos control")
	a["_balance"] = -1.0
	comprobar(Combate.reserva(a) < r0 and Combate.control(a) > c0, "más control: más eficiente")
	comprobar(Combate.validar_atributos(a)["ok"], "el deslizador no cuenta como atributo con puntos")
	a["_balance"] = 1.0
	var caro := Combate.costo_chakra("bola_fuego", 1, a)
	a["_balance"] = -1.0
	comprobar(Combate.costo_chakra("bola_fuego", 1, a) < caro, "con más control los jutsus cuestan menos chakra")


func probar_sorteo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var cuenta := {}
	for i in 4000:
		var rz := str(Creacion.clan(Creacion.sortear_clan(rng))["rareza"])
		cuenta[rz] = int(cuenta.get(rz, 0)) + 1
	var leg := float(cuenta.get("legendario", 0)) / 4000.0
	var com := float(cuenta.get("comun", 0)) / 4000.0
	comprobar(leg > 0.02 and leg < 0.09 and com > 0.6, "en línea los clanes se sortean por rareza (común %.0f %%, legendario %.1f %%)" % [com * 100, leg * 100])


func probar_servidor() -> void:
	var s := ServidorJuego.new()
	s.auto_procesar = false
	s.iniciar()
	s.agregar_jugador(1)
	var j := s.entidad_de_peer(1)
	var pj := pj_base()
	pj["clan"] = "hielo"
	pj["nombre"] = "Yuki"
	s.recibir_comando(1, {"t": "personaje", "datos": pj})
	comprobar(j.nombre == "Yuki" and j.naturalezas == ["agua", "viento"], "el servidor usa el personaje creado")
	comprobar(not j.aspecto.is_empty() and j.aspecto.has("peinado"), "el servidor guarda el aspecto para los demás jugadores")
	s.recibir_comando(1, {"t": "repertorio", "activos": ["hielo", "", "", ""], "modo": "", "prueba": false})
	comprobar("hielo" in j.jutsus, "un linaje del Hielo puede equipar Hielo")
	s.recibir_comando(1, {"t": "repertorio", "activos": ["bola_fuego", "", "", ""], "modo": "", "prueba": false})
	comprobar(not ("bola_fuego" in j.jutsus), "sin naturaleza fuego el servidor rechaza la Bola de Fuego")
	var malo := pj_base()
	malo["atributos"]["ninjutsu"] = 5
	malo["atributos"]["taijutsu"] = 5
	malo["atributos"]["sellos"] = 5
	malo["atributos"]["velocidad"] = 5
	s.recibir_comando(1, {"t": "personaje", "datos": malo})
	comprobar(j.nombre == "Yuki", "un personaje con atributos de más se rechaza")
	s.free()
