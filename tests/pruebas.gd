extends SceneTree
## Pruebas automáticas headless de la matemática del combate y del servidor.
## Ejecutar: godot --headless --path . -s res://tests/pruebas.gd
## Termina con código 0 si todo pasa y 1 si algo falla.

var fallos := 0
var pasadas := 0


func _initialize() -> void:
	Datos.cargar(true)
	print("== Pruebas de combate ==")
	probar_datos()
	probar_atributos()
	probar_naturalezas()
	probar_lluvia()
	probar_costos_chakra()
	probar_escalado_niveles()
	probar_mapa()
	probar_protocolo()
	probar_servidor_bola_fuego()
	probar_servidor_chidori_cadena()
	probar_servidor_sharingan()
	probar_servidor_combo()
	probar_ia_puede_ganar()
	probar_textos_sin_codigo()
	print("== Resultado: %d pasadas, %d fallos ==" % [pasadas, fallos])
	quit(1 if fallos > 0 else 0)


func comprobar(cond: bool, nombre: String) -> void:
	if cond:
		pasadas += 1
		print("  OK   ", nombre)
	else:
		fallos += 1
		printerr("  FALLO ", nombre)


func cerca(a: float, b: float, tol := 0.001) -> bool:
	return absf(a - b) <= tol


func attrs_jugador() -> Dictionary:
	return Datos.personaje("jugador_uchiha")["atributos"]


# ------------------------------------------------------------------

func probar_datos() -> void:
	var todos := {"reglas": Datos.reglas, "mundo": Datos.mundo, "jutsus": Datos.jutsus, "personajes": Datos.personajes, "escenario": Datos.escenario, "textos": Datos.textos}
	for clave in todos.keys():
		comprobar(not (todos[clave] as Dictionary).is_empty(), "datos/%s.json cargado" % clave)


func probar_atributos() -> void:
	var a := attrs_jugador()
	var r := Combate.validar_atributos(a)
	comprobar(r["ok"], "atributos del Uchiha válidos (total %d)" % r["total"])
	comprobar(int(r["total"]) <= 26, "tope total de 26 respetado")
	comprobar(int(a["ninjutsu"]) >= 4 and int(a["velocidad"]) >= 4 and int(a["sellos"]) >= 4, "Uchiha alto en ninjutsu, velocidad y sellos")
	comprobar(int(a["taijutsu"]) <= 2 and int(a["fuerza"]) <= 2, "Uchiha bajo en taijutsu y fuerza")
	var excedido := a.duplicate()
	excedido["fuerza"] = int(excedido["fuerza"]) + 1  # total 27
	comprobar(not Combate.validar_atributos(excedido)["ok"], "27 puntos se rechaza")
	var fuera := a.duplicate()
	fuera["ninjutsu"] = 6
	comprobar(not Combate.validar_atributos(fuera)["ok"], "atributo 6 se rechaza")
	var negativo := a.duplicate()
	negativo["genjutsu"] = -1
	comprobar(not Combate.validar_atributos(negativo)["ok"], "atributo negativo se rechaza")
	var desconocido := a.duplicate()
	desconocido["suerte"] = 1
	comprobar(not Combate.validar_atributos(desconocido)["ok"], "atributo desconocido se rechaza")
	for id in Datos.personajes.keys():
		if id.begins_with("_"):
			continue
		comprobar(Combate.validar_atributos(Datos.personaje(id)["atributos"])["ok"], "plantilla %s respeta el tope" % id)


func probar_naturalezas() -> void:
	var ventajas := [["fuego", "viento"], ["viento", "rayo"], ["rayo", "tierra"], ["tierra", "agua"], ["agua", "fuego"]]
	for par in ventajas:
		comprobar(cerca(Combate.multiplicador_naturaleza(par[0], par[1]), 1.25), "%s > %s da +25 %%" % par)
		comprobar(cerca(Combate.multiplicador_naturaleza(par[1], par[0]), 0.75), "%s contra %s da -25 %%" % [par[1], par[0]])
	comprobar(cerca(Combate.multiplicador_naturaleza("fuego", "rayo"), 1.0), "fuego contra rayo es neutral")
	comprobar(cerca(Combate.multiplicador_naturaleza("fuego", "fuego"), 1.0), "misma naturaleza es neutral")
	comprobar(cerca(Combate.multiplicador_naturaleza("rayo", ""), 1.0), "sin naturaleza es neutral")


func probar_lluvia() -> void:
	var a := attrs_jugador()
	var seco := Combate.dano_jutsu("bola_fuego", 1, a, "", "")
	var lluvia := Combate.dano_jutsu("bola_fuego", 1, a, "", "lluvia")
	comprobar(cerca(lluvia / seco, 0.6), "lluvia: fuego hace 40 % menos daño")
	var t_seco := Combate.escala_tamano("bola_fuego", a, "")
	var t_lluvia := Combate.escala_tamano("bola_fuego", a, "lluvia")
	comprobar(t_lluvia < t_seco, "lluvia: la bola de fuego es más pequeña")
	var r_seco := Combate.dano_jutsu("chidori", 1, a, "", "")
	var r_lluvia := Combate.dano_jutsu("chidori", 1, a, "", "lluvia")
	comprobar(cerca(r_lluvia / r_seco, 1.3), "lluvia: rayo hace 30 % más daño")
	comprobar(Combate.modificador_clima("rayo", "lluvia")["cadena"] == true, "lluvia: rayo salta en cadena")
	comprobar(Combate.modificador_clima("fuego", "lluvia")["cadena"] == false, "lluvia: fuego no salta")
	# Combinado: fuego contra agua bajo la lluvia = 0.75 * 0.6
	var combinado := Combate.dano_jutsu("bola_fuego", 1, a, "agua", "lluvia")
	comprobar(cerca(combinado / seco, 0.45), "fuego vs agua bajo lluvia = 0.75 × 0.6")


func probar_costos_chakra() -> void:
	var a := attrs_jugador()
	var base := float(Datos.nivel_jutsu("bola_fuego", 1)["costo"])
	var r := Combate.reserva(a)
	var c := Combate.control(a)
	var esperado := base * (1.0 + r * Datos.formula("costo_por_reserva")) * (1.0 - c * Datos.formula("ahorro_por_control"))
	comprobar(cerca(Combate.costo_chakra("bola_fuego", 1, a), esperado), "costo de Bola de Fuego nv1 = %.2f" % esperado)
	var mas_reserva := a.duplicate()
	mas_reserva["estamina"] = 5
	comprobar(Combate.costo_chakra("bola_fuego", 1, mas_reserva) > Combate.costo_chakra("bola_fuego", 1, a), "más reserva cuesta más chakra")
	comprobar(Combate.escala_tamano("bola_fuego", mas_reserva, "") > Combate.escala_tamano("bola_fuego", a, ""), "más reserva da jutsus más grandes")
	var menos_control := a.duplicate()
	menos_control["sellos"] = 0
	menos_control["inteligencia"] = 0
	comprobar(Combate.costo_chakra("bola_fuego", 1, menos_control) > Combate.costo_chakra("bola_fuego", 1, a), "más control ahorra chakra")
	comprobar(Combate.precision_grados(a) > Combate.precision_grados(menos_control), "más control da más precisión")
	comprobar(Combate.tiempo_sellos("bola_fuego", a) < Combate.tiempo_sellos("bola_fuego", menos_control), "más sellos = sellos más rápidos")
	var st := Combate.estadisticas(a)
	comprobar(float(st["regen_chakra"]) > 0.0 and float(st["regen_chakra"]) < 5.0, "el chakra se regenera lento (%.2f/s)" % st["regen_chakra"])
	comprobar(Combate.costo_por_segundo("sharingan", a) > 0.0, "Sharingan gasta chakra por segundo")


func probar_escalado_niveles() -> void:
	var a := attrs_jugador()
	for id in ["bola_fuego", "chidori"]:
		var d1 := Combate.dano_jutsu(id, 1, a, "", "lluvia")
		var d2 := Combate.dano_jutsu(id, 2, a, "", "lluvia")
		var d3 := Combate.dano_jutsu(id, 3, a, "", "lluvia")
		comprobar(d1 < d2 and d2 < d3, "%s: daño crece por nivel (%.1f, %.1f, %.1f)" % [id, d1, d2, d3])
		var c1 := Combate.costo_chakra(id, 1, a)
		var c3 := Combate.costo_chakra(id, 3, a)
		comprobar(c1 < Combate.costo_chakra(id, 2, a) and Combate.costo_chakra(id, 2, a) < c3, "%s: costo crece por nivel" % id)
		var n1 := Datos.nivel_jutsu(id, 1)
		var n3 := Datos.nivel_jutsu(id, 3)
		comprobar(float(n3["luz_rango"]) >= float(n1["luz_rango"]) * 3.0, "%s: nivel 3 ilumina mucho más" % id)
		comprobar(int(n3["particulas"]) >= int(n1["particulas"]) * 4, "%s: nivel 3 tiene muchas más partículas" % id)
	comprobar(float(Datos.nivel_jutsu("bola_fuego", 3)["radio"]) >= 4.0 * float(Datos.nivel_jutsu("bola_fuego", 1)["radio"]), "bola de fuego nv3 es enorme")
	comprobar(Datos.nivel_jutsu("bola_fuego", 9) == Datos.nivel_jutsu("bola_fuego", 3), "nivel fuera de rango se limita a 3")


func probar_mapa() -> void:
	var m1 := Mapa.generar()
	var m2 := Mapa.generar()
	comprobar(m1.obstaculos.size() > 10, "el mapa genera torres (%d obstáculos)" % m1.obstaculos.size())
	comprobar(m1.obstaculos.size() == m2.obstaculos.size() and m1.charcos.size() == m2.charcos.size(), "el mapa es determinista")
	comprobar(m1.munecos.size() == 3, "hay 3 muñecos de práctica")
	var todos_en_charco := true
	for p in m1.munecos:
		if not m1.en_charco(p):
			todos_en_charco = false
	comprobar(todos_en_charco, "los muñecos están sobre charcos")
	var fuera := m1.resolver_colision(Vector2(500, 500), 0.45)
	comprobar(absf(fuera.x) <= m1.limite and absf(fuera.y) <= m1.limite, "límite del mapa respetado")


func probar_protocolo() -> void:
	comprobar(Protocolo.sanear_comando("basura").is_empty(), "comando inválido se descarta")
	comprobar(Protocolo.sanear_comando({"t": "accion", "id": "hackear"}).is_empty(), "acción desconocida se descarta")
	var c := Protocolo.sanear_comando({"t": "entrada", "mov": Vector2(10, 0), "mira": 1.0})
	comprobar(cerca((c["mov"] as Vector2).length(), 1.0), "movimiento se normaliza")
	comprobar(int(Protocolo.sanear_comando({"t": "nivel", "valor": 99})["valor"]) == 3, "nivel se limita a 3")


# ------------------------------------------------------------------ servidor

func nuevo_servidor(con_enemigo := true) -> ServidorJuego:
	var s := ServidorJuego.new()
	s.auto_procesar = false
	s.iniciar()
	if con_enemigo:
		s.poblar_entrenamiento()
	else:
		for p in s.mapa.munecos:
			var m := s._crear_entidad("muneco", Vector3(p.x, 0, p.y))
			m.equipo = 3
	s.agregar_jugador(1)
	return s


func correr(s: ServidorJuego, segundos: float) -> Array:
	var evs: Array = []
	var n := int(segundos / s.dt_tick)
	for i in n:
		s.paso(s.dt_tick)
		evs.append_array(s.eventos)
		s.eventos = []
	return evs


func contar(evs: Array, tipo: String) -> int:
	var n := 0
	for e in evs:
		if e["tipo"] == tipo:
			n += 1
	return n


func probar_servidor_bola_fuego() -> void:
	var s := nuevo_servidor(false)
	var j := s.entidad_de_peer(1)
	j.pos = Vector3(0, 0, 6)
	var mira := atan2(0.0 - 0.0, -2.0 - 6.0)
	s.recibir_comando(1, {"t": "entrada", "mov": Vector2.ZERO, "mira": mira})
	var chakra_antes := j.chakra
	s.recibir_comando(1, {"t": "accion", "id": "bola_fuego"})
	var costo := Combate.costo_chakra("bola_fuego", 1, j.attrs)
	comprobar(cerca(chakra_antes - j.chakra, costo, 0.01), "servidor descuenta el chakra de la Bola de Fuego")
	comprobar(j.recarga("bola_fuego") > 0.0, "Bola de Fuego entra en recarga")
	var evs := correr(s, 3.0)
	comprobar(contar(evs, "lanzar") == 1, "se lanza la bola de fuego tras los sellos")
	comprobar(contar(evs, "explosion") == 1, "la bola de fuego explota")
	comprobar(contar(evs, "impacto") >= 1, "la bola de fuego impacta a un muñeco")
	s.free()


func probar_servidor_chidori_cadena() -> void:
	var s := nuevo_servidor(false)
	var j := s.entidad_de_peer(1)
	j.pos = Vector3(-4, 0, 4)
	s.recibir_comando(1, {"t": "nivel", "valor": 3})
	s.recibir_comando(1, {"t": "entrada", "mov": Vector2.ZERO, "mira": 0.0 + PI})
	correr(s, 0.1)
	s.recibir_comando(1, {"t": "accion", "id": "chidori"})
	var evs := correr(s, 3.0)
	comprobar(contar(evs, "chidori_carga") == 1, "Chidori carga antes del embiste")
	comprobar(contar(evs, "chidori_embiste") == 1, "Chidori embiste en línea recta")
	var cadenas := 0
	for e in evs:
		if e["tipo"] == "cadena":
			cadenas = int(e["saltos"])
	comprobar(cadenas >= 1, "el rayo salta en cadena por los charcos (%d saltos)" % cadenas)
	var impactos_cadena := 0
	for e in evs:
		if e["tipo"] == "impacto" and e["cadena"]:
			impactos_cadena += 1
	comprobar(impactos_cadena == cadenas, "cada salto de la cadena hace daño")
	s.free()


func probar_servidor_sharingan() -> void:
	var s := nuevo_servidor(false)
	var j := s.entidad_de_peer(1)
	s.recibir_comando(1, {"t": "accion", "id": "sharingan"})
	comprobar(j.sharingan, "Sharingan se activa")
	var antes := j.chakra
	correr(s, 2.0)
	comprobar(j.chakra < antes, "Sharingan consume chakra cada segundo")
	j.chakra = 0.5
	correr(s, 1.0)
	comprobar(not j.sharingan, "Sharingan se apaga sin chakra")
	s.free()


func probar_servidor_combo() -> void:
	var s := nuevo_servidor(false)
	var j := s.entidad_de_peer(1)
	var m: EntidadServidor = null
	for e in s.entidades:
		if e.tipo == "muneco":
			m = e
			break
	j.pos = m.pos + Vector3(0, 0, 1.5)
	j.yaw = PI
	var evs: Array = []
	for i in 3:
		s.recibir_comando(1, {"t": "accion", "id": "golpe"})
		evs.append_array(correr(s, 0.5))
	var pasos: Array = []
	for e in evs:
		if e["tipo"] == "golpe":
			pasos.append(int(e["paso"]))
	comprobar(pasos == [0, 1, 2], "combo de taijutsu de 3 golpes (%s)" % str(pasos))
	comprobar(contar(evs, "impacto") == 3, "los 3 golpes conectan")
	s.free()


func probar_ia_puede_ganar() -> void:
	var s := nuevo_servidor(true)
	var j := s.entidad_de_peer(1)
	var evs := correr(s, 60.0)
	comprobar(contar(evs, "aviso") > 0, "el enemigo telegrafía sus ataques (para el Sharingan)")
	comprobar(contar(evs, "lanzar") > 0, "el enemigo dispara proyectiles de agua")
	comprobar(not j.vivo(), "el enemigo derrota a un jugador que no hace nada")
	s.free()


func probar_textos_sin_codigo() -> void:
	# Los nombres de la serie deben vivir en /data, no en scripts.
	var prohibidos := ["Amegakure", "Uchiha", "Chidori", "Sharingan", "Konoha"]
	var limpio := true
	var dir := DirAccess.open("res://scripts")
	var pendientes := ["res://scripts"]
	while not pendientes.is_empty():
		var ruta: String = pendientes.pop_back()
		var d := DirAccess.open(ruta)
		if d == null:
			continue
		for sub in d.get_directories():
			pendientes.append(ruta + "/" + sub)
		for f in d.get_files():
			if not f.ends_with(".gd"):
				continue
			var txt := FileAccess.get_file_as_string(ruta + "/" + f)
			for p in prohibidos:
				if txt.contains(p):
					limpio = false
					printerr("    '%s' aparece en %s/%s" % [p, ruta, f])
	comprobar(dir != null and limpio, "sin nombres de la serie escritos en el código")
