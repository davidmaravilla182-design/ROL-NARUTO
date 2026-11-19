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
	probar_direccion_disparo()
	probar_servidor_chidori_cadena()
	probar_servidor_sharingan()
	probar_servidor_combo()
	probar_ia_puede_ganar()
	probar_jugador_puede_ganar()
	probar_textos_sin_codigo()
	probar_plataforma_lengua()
	probar_piezas_suelo()
	probar_aldea()
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


## La dirección del disparo llega en el comando y el servidor la respeta.
func probar_direccion_disparo() -> void:
	var c := Protocolo.sanear_comando({"t": "accion", "id": "bola_fuego", "dir": Vector2(3, 4), "objetivo": 7, "exacto": true})
	comprobar(cerca((c["dir"] as Vector2).length(), 1.0) and int(c["objetivo"]) == 7 and c["exacto"], "comando de jutsu lleva dirección normalizada, objetivo y modo exacto")
	comprobar((Protocolo.sanear_comando({"t": "accion", "id": "chidori", "dir": "x"})["dir"] as Vector2) == Vector2.ZERO, "dirección inválida se ignora")

	# 1) Arrastre exacto hacia +X (lejos de los muñecos): sin asistencia, sale hacia +X.
	var s := nuevo_servidor(false)
	var j := s.entidad_de_peer(1)
	j.pos = Vector3(0, 0, 6)
	s.recibir_comando(1, {"t": "accion", "id": "bola_fuego", "dir": Vector2(1, 0), "exacto": true})
	var evs := correr(s, 1.0)
	var dir_lanz := Vector3.ZERO
	for e in evs:
		if e["tipo"] == "lanzar":
			dir_lanz = e["dir"]
	comprobar(dir_lanz.dot(Vector3(1, 0, 0)) > 0.98, "arrastre exacto: la bola sale en la dirección del dedo (%s)" % str(dir_lanz))
	comprobar(absf(j.yaw - PI * 0.5) < 0.05, "el lanzador gira hacia la dirección del disparo")
	s.free()

	# 2) Toque con objetivo fijado: aunque la dirección apunte a otro lado, va al objetivo.
	s = nuevo_servidor(false)
	j = s.entidad_de_peer(1)
	j.pos = Vector3(0, 0, 6)
	var m: EntidadServidor = null
	for e in s.entidades:
		if e.tipo == "muneco" and e.pos.x > 1.0:
			m = e
	s.recibir_comando(1, {"t": "accion", "id": "bola_fuego", "dir": Vector2(-1, 0), "objetivo": m.id})
	evs = correr(s, 1.0)
	for e in evs:
		if e["tipo"] == "lanzar":
			dir_lanz = e["dir"]
	var esperado := (m.pos - j.pos)
	esperado.y = 0
	var plano := Vector3(dir_lanz.x, 0, dir_lanz.z).normalized()
	comprobar(plano.dot(esperado.normalized()) > 0.97, "objetivo fijado: la bola va al muñeco elegido")
	s.free()

	# 3) Toque sin objetivo: asistencia en cono alrededor de la dirección enviada.
	s = nuevo_servidor(false)
	j = s.entidad_de_peer(1)
	j.pos = Vector3(0, 0, 6)
	s.recibir_comando(1, {"t": "accion", "id": "bola_fuego", "dir": Vector2(0.15, -1).normalized()})
	evs = correr(s, 3.0)
	comprobar(contar(evs, "impacto") >= 1, "toque rápido: la asistencia corrige pequeños errores y acierta")
	s.free()

	# 4) Chidori con dirección exacta: el embiste sigue esa dirección.
	s = nuevo_servidor(false)
	j = s.entidad_de_peer(1)
	j.pos = Vector3(0, 0, 10)
	s.recibir_comando(1, {"t": "accion", "id": "chidori", "dir": Vector2(-1, 0), "exacto": true})
	evs = correr(s, 2.0)
	var dir_emb := Vector3.ZERO
	for e in evs:
		if e["tipo"] == "chidori_embiste":
			dir_emb = e["dir"]
	comprobar(dir_emb.dot(Vector3(-1, 0, 0)) > 0.98, "chidori: el embiste sigue la flecha arrastrada")
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


func probar_jugador_puede_ganar() -> void:
	# Un jugador que usa el rayo (ventaja con la lluvia) y esquiva debe poder ganar.
	var s := nuevo_servidor(true)
	var j := s.entidad_de_peer(1)
	s.recibir_comando(1, {"t": "nivel", "valor": 2})
	# Sin muñecos de práctica en medio: el bot no sabe rodearlos y el embiste se gasta en ellos.
	s.entidades = s.entidades.filter(func(x): return x.tipo != "muneco")
	var enemigo: EntidadServidor = null
	for e in s.entidades:
		if e.tipo == "enemigo":
			enemigo = e
	var gano := false
	for i in int(90.0 / s.dt_tick):
		var d := enemigo.pos - j.pos
		var mira := atan2(d.x, d.z)
		var mov := Vector2.ZERO
		if d.length() > 9.0:
			mov = Vector2(d.x, d.z).normalized()
		s.recibir_comando(1, {"t": "entrada", "mov": mov, "mira": mira})
		if j.recarga("chidori") <= 0.0 and d.length() < 14.0:
			s.recibir_comando(1, {"t": "accion", "id": "chidori"})
		elif d.length() < 2.5:
			s.recibir_comando(1, {"t": "accion", "id": "golpe"})
		for p in s.proyectiles:
			if int(p["dueno"]) == enemigo.id and (p["pos"] as Vector3).distance_to(j.centro()) < 4.0:
				s.recibir_comando(1, {"t": "accion", "id": "esquivar"})
		s.paso(s.dt_tick)
		s.eventos = []
		if not enemigo.vivo():
			gano = true
			break
		if not j.vivo():
			break
	comprobar(gano, "un jugador que usa bien el rayo puede ganar (vida restante %d)" % int(j.vida))
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


## La lengua de la torre (modelo IA) es una plataforma: se cae encima y los proyectiles chocan con ella.
func probar_plataforma_lengua() -> void:
	var m := Mapa.generar()
	var lenguas := m.plataformas.filter(func(x): return x.get("tipo", "") == "lengua")
	comprobar(lenguas.size() == 1, "la lengua de la torre es una plataforma del mapa")
	if lenguas.is_empty():
		return
	var pl: Dictionary = lenguas[0]
	var c: Vector2 = pl["centro"]
	var h := float(pl["altura"])
	comprobar(h > 20.0, "la plataforma está en lo alto de la torre (%.1f m)" % h)
	var s := ServidorJuego.new()
	s.auto_procesar = false
	s.iniciar(m)
	s.agregar_jugador(1)
	var j := s.entidad_de_peer(1)
	j.pos = Vector3(c.x, h + 3.0, c.y)
	for i in 60:
		s.paso(s.dt_tick)
	comprobar(absf(j.pos.y - h) < 0.05 and j.en_suelo, "un personaje cae sobre la lengua y se queda parado (y=%.2f)" % j.pos.y)
	comprobar(m.dentro_plataforma(Vector3(c.x, h - 0.5, c.y)) and not m.dentro_plataforma(Vector3(c.x, h + 1.0, c.y)), "los proyectiles chocan con la lengua")
	s.free()


## Piezas del suelo de la plaza (kit de Blender): cajas, barriles y tuberías chocan; las rejillas no.
func probar_piezas_suelo() -> void:
	var m := Mapa.generar()
	var tipos := {}
	for p in m.props:
		tipos[p["tipo"]] = int(tipos.get(p["tipo"], 0)) + 1
	comprobar(tipos.size() >= 5 and m.props.size() >= 30, "la plaza tiene piezas de suelo de 5 tipos (%s)" % str(tipos))
	var barril: Vector2 = Vector2.ZERO
	var rejilla: Vector2 = Vector2.ZERO
	for p in m.props:
		if p["tipo"] == "barril":
			barril = p["centro"]
		if p["tipo"] == "rejilla_suelo":
			rejilla = p["centro"]
	comprobar(m.punto_bloqueado(barril, 0.3), "un barril bloquea el paso")
	comprobar(not m.punto_bloqueado(rejilla + Vector2(0.5, 0.5), 0.1), "sobre una rejilla se puede caminar")


## Mapa completo: isla con muralla, distritos, puentes del canal, techos caminables, escaleras y escalada con chakra.
func probar_aldea() -> void:
	var m := Mapa.generar()
	comprobar(m.distritos.size() == 8, "la aldea tiene 8 distritos (%d)" % m.distritos.size())
	comprobar(m.distrito_en(m.inicio_jugador) == "plaza", "se aparece en la plaza")
	var ids := {}
	for pt in m.puntos:
		ids[pt["distrito"]] = true
	comprobar(ids.size() == 8, "cada distrito tiene puntos de misión y aldeanos")
	# Límite: la isla y el puente; el lago no.
	var lago := m.resolver_colision(Vector2(160, 60), 0.45)
	comprobar(lago.distance_to(m.centro_aldea) <= m.radio_caminable + 0.01, "no se puede caminar sobre el lago")
	var puente := m.resolver_colision(Vector2(0, 120), 0.45)
	comprobar(puente.distance_to(Vector2(0, 120)) < 0.01, "se puede caminar por el puente de la puerta")
	# El canal se cruza por los puentes y no por el agua.
	var cz := (float(m.canal["z_sur"]) + float(m.canal["z_norte"])) * 0.5
	comprobar(not m.punto_bloqueado(Vector2(0.0, cz), 0.45), "el puente central cruza el canal")
	comprobar(m.en_canal(Vector2(7.5, cz)) and not m.en_canal(Vector2(0.0, cz)), "el agua del canal se distingue de los puentes")
	# Techos caminables y escaleras.
	var casa: Dictionary = {}
	for o in m.obstaculos:
		if o["tipo"] == "casa_chica":
			casa = o
			break
	comprobar(not casa.is_empty() and absf(m.altura_suelo(casa["centro"], float(casa["alto"]) + 0.2) - float(casa["alto"])) < 0.01, "el techo de una casa es suelo")
	var esc := m.plataformas.filter(func(x): return x.has("altura0"))
	comprobar(esc.size() >= 4, "hay escaleras entre niveles (%d)" % esc.size())
	# Escalada con chakra: un jugador que empuja contra una pared sube y termina en el techo.
	var s := ServidorJuego.new()
	s.auto_procesar = false
	s.iniciar(m)
	s.agregar_jugador(1)
	var j := s.entidad_de_peer(1)
	var c: Vector2 = casa["centro"]
	var md: Vector2 = casa["medio"]
	j.pos = Vector3(c.x + md.x + 0.6, 0.0, c.y)
	var chakra0 := j.chakra
	var subio := false
	for i in 150:
		# Empuja hacia la pared hasta pasar el borde del techo; luego se suelta el control.
		j.entrada_mov = Vector2(-1, 0) if j.pos.x > c.x + md.x - 1.0 else Vector2.ZERO
		s.paso(s.dt_tick)
		if j.escalando:
			subio = true
			chakra0 = minf(chakra0, j.chakra + 0.5)
	comprobar(subio and chakra0 < j.stats["chakra_max"], "empujar contra la pared escala gastando chakra")
	comprobar(absf(j.pos.y - float(casa["alto"])) < 0.1 and j.en_suelo, "tras escalar se queda parado en el techo (y=%.2f de %.2f)" % [j.pos.y, float(casa["alto"])])
	# Sin chakra no se escala.
	j.pos = Vector3(c.x + md.x + 0.6, 0.0, c.y)
	j.vel_y = 0.0
	j.chakra = 0.0
	for i in 20:
		j.entrada_mov = Vector2(-1, 0)
		s.paso(s.dt_tick)
	comprobar(j.pos.y < 0.5, "sin chakra no se escala")
	# Al escalar, el servidor manda la normal de la pared (para dibujarlo de pie sobre ella).
	j.chakra = 100.0
	j.pos = Vector3(c.x + md.x + 0.6, 0.0, c.y)
	var normal_ok := false
	for i in 30:
		j.entrada_mov = Vector2(-1, 0)
		s.paso(s.dt_tick)
		if j.escalando and j.pared.dot(Vector2(1, 0)) > 0.9:
			normal_ok = true
	comprobar(normal_ok, "corriendo por la pared, la normal apunta hacia afuera")
	# Salto desde la pared: sale despedido hacia atrás.
	j.chakra = 100.0
	s.recibir_comando(1, {"t": "accion", "id": "saltar"})
	var x0 := j.pos.x
	for i in 10:
		j.entrada_mov = Vector2.ZERO
		s.paso(s.dt_tick)
	comprobar(j.pos.x > x0 + 1.0 and not j.escalando, "el salto desde la pared impulsa hacia atrás (%.1f m)" % (j.pos.x - x0))
	# La torre del líder no se escala.
	var torre: Dictionary = {}
	for o in m.obstaculos:
		if o["tipo"] == "torre_ia":
			torre = o
	j.chakra = 100.0
	j.vel_y = 0.0
	j.pos = Vector3((torre["centro"] as Vector2).x - (torre["medio"] as Vector2).x - 0.6, 0.0, (torre["centro"] as Vector2).y)
	for i in 40:
		j.entrada_mov = Vector2(1, 0)
		s.paso(s.dt_tick)
	comprobar(j.pos.y < 0.5 and not j.escalando, "la torre del líder no se puede escalar")
	# Agua: con chakra se camina encima; sin chakra se nada (más hundido y más lento).
	j.pos = Vector3(30.0, 0.0, -21.5)
	j.vel_y = 0.0
	j.chakra = 100.0
	for i in 22:
		j.entrada_mov = Vector2(0, -1)
		s.paso(s.dt_tick)
	comprobar(j.agua == 1 and absf(j.pos.y - float(m.canal["nivel_agua"])) < 0.05, "con chakra se camina sobre el agua del canal (y=%.2f)" % j.pos.y)
	var ch0 := j.chakra
	for i in 15:
		j.entrada_mov = Vector2.ZERO
		s.paso(s.dt_tick)
	comprobar(j.chakra < ch0, "caminar sobre el agua gasta chakra")
	j.chakra = 0.0
	for i in 10:
		s.paso(s.dt_tick)
		j.chakra = 0.0
	comprobar(j.agua == 2 and j.pos.y < float(m.canal["nivel_agua"]) - 0.5, "sin chakra se hunde y nada (y=%.2f)" % j.pos.y)
	var z0 := j.pos.z
	for i in 10:
		j.entrada_mov = Vector2(0, 1)
		j.chakra = 0.0
		s.paso(s.dt_tick)
	comprobar(j.pos.z - z0 < float(j.stats["velocidad"]) * 0.2, "nadando se avanza despacio (%.1f m en 1/3 s)" % (j.pos.z - z0))
	# Recorridos a pie: de la plaza a la puerta y por el puente hasta la orilla; y de la plaza a la torre.
	j.chakra = 0.0
	j.pos = Vector3(0, 0, 30)
	for i in 30 * 30:
		j.entrada_mov = Vector2(0, 1)
		j.chakra = 0.0
		s.paso(s.dt_tick)
	comprobar(j.pos.z > 150.0, "se sale por la puerta y el puente hasta la orilla (z=%.1f)" % j.pos.z)
	j.pos = Vector3(0, 0, 0)
	for i in 30 * 12:
		j.entrada_mov = Vector2(0, -1)
		j.chakra = 0.0
		s.paso(s.dt_tick)
	comprobar(j.pos.z < -55.0, "de la plaza se cruza el canal hasta la explanada de la torre (z=%.1f)" % j.pos.z)
	s.free()
