extends SceneTree
## Pruebas del repertorio de 40 jutsus: datos, reglas del menú, maestría y las mecánicas
## del primer bloque en el servidor. Ejecutar: godot --headless --path . -s res://tests/pruebas_repertorio.gd

var fallos := 0
var pasadas := 0


func _initialize() -> void:
	Datos.cargar(true)
	print("== Pruebas del repertorio ==")
	probar_datos()
	probar_requisitos()
	probar_validacion()
	probar_maestria()
	probar_servidor_repertorio()
	probar_kirin()
	probar_rasengan()
	probar_amaterasu()
	probar_susanoo()
	probar_sincronia_repertorio()
	probar_shinra()
	probar_ocho_puertas()
	probar_bola_fuego_suelo()
	print("== Resultado: %d pasadas, %d fallos ==" % [pasadas, fallos])
	quit(1 if fallos > 0 else 0)


func comprobar(cond: bool, nombre: String) -> void:
	if cond:
		pasadas += 1
		print("  OK   ", nombre)
	else:
		fallos += 1
		printerr("  FALLO ", nombre)


# ------------------------------------------------------------------ datos

func probar_datos() -> void:
	var cat := Repertorio.catalogo()
	var lista40: Array = []
	for id in cat:
		if not (id in ["sharingan", "mangekyo", "rinnegan", "byakugan"]):
			lista40.append(id)
	comprobar(lista40.size() == 40, "hay exactamente 40 jutsus en el repertorio (%d)" % lista40.size())
	var cats := Repertorio.categorias()
	var bien_niveles := true
	var bien_costos := true
	var bien_puntos := true
	var bien_textos := true
	var bien_cat := true
	for id in cat:
		var j := Datos.jutsu(id)
		var n: Array = j.get("niveles", [])
		if n.size() != 3:
			bien_niveles = false
			printerr("    %s tiene %d niveles" % [id, n.size()])
		elif not (float(n[0]["costo"]) < float(n[1]["costo"]) and float(n[1]["costo"]) < float(n[2]["costo"])):
			bien_costos = false
			printerr("    %s: el costo no sube por nivel" % id)
		var p := int(j.get("puntos", 0))
		if p < 1 or p > 5:
			bien_puntos = false
		for t in ["nombre", "ventaja", "desventaja"]:
			if str(j.get(t, "")) == "":
				bien_textos = false
		for nv in n:
			if str(nv.get("descripcion", "")) == "":
				bien_textos = false
		if not cats.has(str(j.get("categoria", ""))):
			bien_cat = false
	comprobar(bien_niveles, "cada jutsu tiene 3 niveles")
	comprobar(bien_costos, "cada nivel cuesta más chakra que el anterior")
	comprobar(bien_puntos, "cada jutsu cuesta de 1 a 5 puntos")
	comprobar(bien_textos, "nombre, ventaja, desventaja y descripción de los 3 niveles presentes")
	comprobar(bien_cat, "todas las categorías existen")
	for id in ["kirin", "rasengan", "amaterasu", "susanoo", "shinra_tensei", "ocho_puertas"]:
		comprobar(Repertorio.implementado(id), "primer bloque implementado: %s" % id)
	comprobar(not Repertorio.implementado("fenix"), "los demás aparecen como próximamente (fenix)")
	comprobar(Repertorio.es_modo("ocho_puertas") and Repertorio.es_modo("modo_sabio") and Repertorio.es_modo("byakugan"), "Ocho Puertas, Modo Sabio y los ojos van en la ranura de modo")


# ------------------------------------------------------------------ reglas

func ficha() -> Dictionary:
	return Repertorio.ficha("jugador_uchiha")


func probar_requisitos() -> void:
	var f := ficha()
	comprobar(Repertorio.requisitos("bola_fuego", f)["ok"], "bola de fuego: el clan tiene naturaleza fuego")
	var r := Repertorio.requisitos("dragon_agua", f)
	comprobar(not r["ok"] and str(r["motivos"][0]).contains("Agua"), "sin naturaleza agua: bloqueado con motivo (%s)" % str(r["motivos"]))
	comprobar(not Repertorio.requisitos("kirin", f, "")["ok"], "kirin bloqueado sin el modo ocular equipado")
	comprobar(Repertorio.requisitos("kirin", f, "sharingan")["ok"], "kirin disponible con el modo ocular y rango jōnin")
	comprobar(not Repertorio.requisitos("ocho_puertas", f)["ok"], "ocho puertas bloqueado: taijutsu 2 y ninjutsu 5")
	comprobar(not Repertorio.requisitos("shinra_tensei", f, "rinnegan")["ok"] or not Repertorio.requisitos("rinnegan", f)["ok"], "sin linaje del rinnegan no se puede")
	comprobar(not Repertorio.requisitos("lanza_chidori", f)["ok"], "lanza requiere dominar el embiste de rayo a N2")
	var f2 := Repertorio.ficha("jugador_uchiha", {"chidori": 150.0})
	comprobar(Repertorio.requisitos("lanza_chidori", f2)["ok"], "con maestría N2 del embiste de rayo se desbloquea la lanza")
	comprobar(Repertorio.requisitos("rasengan", f)["ok"], "rasengan: control de chakra alto (3.8)")
	comprobar(not Repertorio.requisitos("curacion", f)["ok"], "curación exige control 5")
	comprobar(Repertorio.texto_requisito("madera").contains("Tierra"), "texto corto del requisito para la tarjeta")


func probar_validacion() -> void:
	var f := ficha()
	var defecto := Repertorio.repertorio_por_defecto("jugador_uchiha")
	var v := Repertorio.validar(defecto, f)
	comprobar(v["ok"], "el repertorio por defecto es válido (%d puntos) %s" % [v["puntos"], str(v["errores"])])
	var caro := {"activos": ["kirin", "chidori", "rasengan", "bola_fuego"], "modo": "sharingan"}
	v = Repertorio.validar(caro, f)
	comprobar(not v["ok"] and int(v["puntos"]) > 12, "superar 12 puntos se rechaza (%d)" % v["puntos"])
	comprobar(Repertorio.validar(caro, f, true)["ok"], "modo prueba ignora puntos y requisitos")
	var inc := {"activos": ["amaterasu", "", "", ""], "modo": "ocho_puertas"}
	v = Repertorio.validar(inc, f, false)
	var hay_inc := false
	for e in v["errores"]:
		if str(e).contains("Ocho Puertas"):
			hay_inc = true
	comprobar(hay_inc, "Ocho Puertas no se combina con técnicas oculares")
	comprobar(Repertorio.incompatible("rinnegan", {"activos": ["amaterasu"], "modo": "rinnegan"}) != "", "rinnegan y mangekyō no van juntos")
	comprobar(not Repertorio.validar({"activos": ["sharingan"], "modo": ""}, f, true)["ok"], "un modo no va en una ranura activa")
	comprobar(not Repertorio.validar({"activos": ["chidori", "chidori"], "modo": ""}, f, true)["ok"], "no se repiten jutsus")
	comprobar(not Repertorio.validar({"activos": ["chidori"], "modo": "chidori"}, f, true)["ok"], "un activo no va en la ranura de modo")


func probar_maestria() -> void:
	comprobar(Repertorio.nivel_desbloqueado(0) == 1, "sin experiencia: N1")
	comprobar(Repertorio.nivel_desbloqueado(100) == 2 and Repertorio.nivel_desbloqueado(299) == 2, "100 XP: N2")
	comprobar(Repertorio.nivel_desbloqueado(300) == 3 and Repertorio.nivel_desbloqueado(99999) == 3, "300 XP: N3 (tope)")
	comprobar(Repertorio.nivel_efectivo("chidori", 350, 3, 0) == 3, "en combate se usa el nivel más alto desbloqueado")
	comprobar(Repertorio.nivel_efectivo("chidori", 350, 1, 0) == 1, "el jugador puede bajar el nivel en el menú")
	comprobar(Repertorio.nivel_efectivo("chidori", 0, 3, 3) == 3, "la depuración fuerza el nivel aunque no esté desbloqueado")
	comprobar(Repertorio.nivel_efectivo("chidori", 0, 1, 0) == 1, "sin maestría ni depuración: N1")


# ------------------------------------------------------------------ servidor

func servidor(activos: Array, modo: String, con_enemigo := false, prueba := true, maestria := {}) -> ServidorJuego:
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
	s.recibir_comando(1, {"t": "repertorio", "activos": activos, "modo": modo, "prueba": prueba, "maestria": maestria})
	return s


func correr(s: ServidorJuego, seg: float) -> Array:
	var evs: Array = []
	for i in int(seg / s.dt_tick):
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


func muneco_central(s: ServidorJuego) -> EntidadServidor:
	for e in s.entidades:
		if e.tipo == "muneco" and absf(e.pos.x) < 0.5:
			return e
	return null


func probar_servidor_repertorio() -> void:
	var s := servidor(["kirin", "chidori", "rasengan", "bola_fuego"], "sharingan", false, false)
	var j := s.entidad_de_peer(1)
	comprobar(not ("rasengan" in j.jutsus and "kirin" in j.jutsus and "bola_fuego" in j.jutsus and "chidori" in j.jutsus), "el servidor rechaza un repertorio que supera los puntos")
	s.free()
	s = servidor(["kirin", "chidori", "rasengan", "bola_fuego"], "sharingan", false, true)
	j = s.entidad_de_peer(1)
	comprobar("rasengan" in j.jutsus and j.modo == "sharingan", "con modo prueba el servidor acepta el repertorio")
	s.recibir_comando(1, {"t": "accion", "id": "fenix"})
	comprobar(j.estado == "libre", "una técnica no equipada no hace nada")
	# Maestría: usar y acertar da experiencia en ESE jutsu.
	j.pos = Vector3(0, 0, -1.5)
	s.recibir_comando(1, {"t": "accion", "id": "rasengan", "dir": Vector2(0, -1)})
	var evs := correr(s, 2.0)
	comprobar(float(j.maestria.get("rasengan", 0.0)) >= 25.0, "usar y acertar el rasengan da experiencia (%.0f XP)" % float(j.maestria.get("rasengan", 0.0)))
	comprobar(float(j.maestria.get("kirin", 0.0)) == 0.0, "la experiencia es solo de ese jutsu")
	j.maestria["rasengan"] = 95.0
	j.recargas.clear()
	j.chakra = 200.0
	j.pos = Vector3(0, 0, -1.5)
	s.recibir_comando(1, {"t": "accion", "id": "rasengan", "dir": Vector2(0, -1)})
	evs = correr(s, 2.0)
	var subio := false
	for e in evs:
		if e["tipo"] == "maestria" and e["jutsu"] == "rasengan" and e["subio"]:
			subio = true
	comprobar(subio and s.nivel_de(j, "rasengan") == 2, "al llegar a 100 XP se desbloquea N2 (evento de maestría)")
	s.free()


func probar_kirin() -> void:
	var s := servidor(["kirin", "", "", ""], "sharingan")
	var j := s.entidad_de_peer(1)
	j.pos = Vector3(0, 0, 4)
	var antes := j.chakra
	s.recibir_comando(1, {"t": "accion", "id": "kirin", "dir": Vector2(0, -1)})
	comprobar(antes - j.chakra >= float(j.stats["chakra_max"]) * 0.44, "kirin gasta casi la mitad del chakra en N1 (%.0f)" % (antes - j.chakra))
	var evs := correr(s, 3.5)
	comprobar(contar(evs, "kirin") == 1 and contar(evs, "impacto") >= 1, "kirin N1: un rayo del cielo que impacta")
	s.free()
	s = servidor(["kirin", "", "", ""], "sharingan")
	j = s.entidad_de_peer(1)
	j.pos = Vector3(0, 0, 4)
	s.recibir_comando(1, {"t": "nivel", "valor": 3})
	s.recibir_comando(1, {"t": "accion", "id": "kirin", "dir": Vector2(0, -1)})
	evs = correr(s, 4.5)
	comprobar(contar(evs, "kirin") == 5, "kirin N3: tormenta de 5 rayos (%d)" % contar(evs, "kirin"))
	s.clima = "seco"
	j.recargas.clear()
	j.chakra = 300.0
	evs = correr(s, 0.1)
	s.recibir_comando(1, {"t": "accion", "id": "kirin"})
	evs = correr(s, 0.1)
	comprobar(j.estado == "libre", "sin tormenta no se puede usar kirin")
	s.free()


func probar_rasengan() -> void:
	for nivel in [1, 3]:
		var s := servidor(["rasengan", "", "", ""], "", true)
		var j := s.entidad_de_peer(1)
		s.recibir_comando(1, {"t": "nivel", "valor": nivel})
		var m := muneco_central(s)
		var en: EntidadServidor = null
		for e in s.entidades:
			if e.tipo == "enemigo":
				en = e
				e.ia = null
				e.pos = m.pos + Vector3(3.0, 0, 0)
		j.pos = m.pos + Vector3(0, 0, 2.2)
		s.recibir_comando(1, {"t": "accion", "id": "rasengan", "objetivo": m.id})
		var evs := correr(s, 2.0)
		var golpeados := {}
		for e in evs:
			if e["tipo"] == "impacto" and e["jutsu"] == "rasengan":
				golpeados[e["entidad"]] = true
		if nivel == 1:
			comprobar(golpeados.size() == 1, "rasengan N1: golpea a un objetivo")
		else:
			comprobar(golpeados.size() >= 2 and contar(evs, "clones") == 1, "rasengan N3: los clones golpean a otros cercanos (%d)" % golpeados.size())
		s.free()


func probar_amaterasu() -> void:
	var s := servidor(["amaterasu", "", "", ""], "sharingan")
	var j := s.entidad_de_peer(1)
	var m := muneco_central(s)
	j.pos = m.pos + Vector3(0, 0, 6)
	s.recibir_comando(1, {"t": "accion", "id": "amaterasu", "objetivo": m.id})
	correr(s, 0.5)
	comprobar(j.estado == "libre" and not m.efectos.has("ardiendo"), "amaterasu exige el mangekyō (con otro ojo no sale)")
	s.free()
	s = servidor(["amaterasu", "", "", ""], "mangekyo")
	j = s.entidad_de_peer(1)
	m = muneco_central(s)
	j.pos = m.pos + Vector3(0, 0, 6)
	s.recibir_comando(1, {"t": "accion", "id": "modo"})
	comprobar(j.modo_activo, "el botón de modo activa el mangekyō")
	j.recargas.clear()
	s.recibir_comando(1, {"t": "accion", "id": "amaterasu", "objetivo": m.id})
	correr(s, 1.0)
	comprobar(m.efectos.has("ardiendo"), "amaterasu enciende al objetivo")
	var vida := m.vida
	correr(s, 3.0)
	comprobar(m.vida < vida, "la llama negra quema con el tiempo (la lluvia no la apaga) (%.0f → %.0f)" % [vida, m.vida])
	comprobar(j.ceguera > 0.0, "ceguera progresiva tras usarla")
	s.free()
	s = servidor(["amaterasu", "", "", ""], "mangekyo")
	j = s.entidad_de_peer(1)
	m = muneco_central(s)
	s.recibir_comando(1, {"t": "nivel", "valor": 2})
	s.recibir_comando(1, {"t": "accion", "id": "modo"})
	j.pos = m.pos + Vector3(0, 0, 6)
	s.recibir_comando(1, {"t": "accion", "id": "amaterasu", "objetivo": m.id})
	correr(s, 4.0)
	var ardiendo := 0
	for e in s.entidades:
		if e.tipo == "muneco" and e.efectos.has("ardiendo"):
			ardiendo += 1
	comprobar(ardiendo >= 2, "amaterasu N2 se propaga a los cercanos (%d ardiendo)" % ardiendo)
	s.free()


func probar_susanoo() -> void:
	var s := servidor(["susanoo", "", "", ""], "mangekyo")
	var j := s.entidad_de_peer(1)
	s.recibir_comando(1, {"t": "accion", "id": "modo"})
	s.recibir_comando(1, {"t": "accion", "id": "susanoo"})
	correr(s, 0.6)
	comprobar(j.efectos.has("susanoo"), "susanoo se activa")
	var chakra := j.chakra
	var vida := j.vida
	correr(s, 1.0)
	comprobar(j.chakra < chakra and j.vida < vida, "susanoo drena chakra y vida cada segundo")
	var antes := j.vida
	s._aplicar_dano(j, 40.0, null, {"jutsu": "prueba"})
	comprobar(absf((antes - j.vida) - 20.0) < 0.6, "susanoo N1 reduce el daño a la mitad (%.1f)" % (antes - j.vida))
	s.free()
	s = servidor(["susanoo", "", "", ""], "mangekyo")
	j = s.entidad_de_peer(1)
	s.recibir_comando(1, {"t": "nivel", "valor": 2})
	s.recibir_comando(1, {"t": "accion", "id": "modo"})
	s.recibir_comando(1, {"t": "accion", "id": "susanoo"})
	var evs := correr(s, 4.0)
	comprobar(contar(evs, "lanzar") >= 1, "susanoo N2 dispara flechas solo")
	s.free()


func probar_shinra() -> void:
	var s := servidor(["shinra_tensei", "bola_fuego", "", ""], "rinnegan")
	var j := s.entidad_de_peer(1)
	var m := muneco_central(s)
	j.pos = m.pos + Vector3(0, 0, 2.5)
	s.recibir_comando(1, {"t": "accion", "id": "modo"})
	var vida := m.vida
	s.recibir_comando(1, {"t": "accion", "id": "shinra_tensei"})
	var evs := correr(s, 1.0)
	comprobar(contar(evs, "shinra") == 1 and m.vida < vida, "shinra tensei empuja y daña alrededor")
	comprobar(j.efectos.has("vulnerable"), "quedas vulnerable después")
	s.recibir_comando(1, {"t": "accion", "id": "bola_fuego"})
	correr(s, 0.1)
	comprobar(j.estado == "libre" and j.recarga("bola_fuego") == 0.0, "vulnerable: no puedes usar jutsus")
	correr(s, 5.0)
	comprobar(not j.efectos.has("vulnerable"), "la vulnerabilidad dura 5 s")
	s.free()


func probar_ocho_puertas() -> void:
	var s := servidor(["", "", "", ""], "ocho_puertas")
	var j := s.entidad_de_peer(1)
	var vida := j.vida
	s.recibir_comando(1, {"t": "accion", "id": "modo"})
	comprobar(j.modo_activo and j.vida < vida, "abrir las puertas cuesta vida")
	var v2 := j.vida
	correr(s, 2.0)
	comprobar(j.vida < v2, "cada segundo con las puertas abiertas quita vida")
	comprobar(Tecnicas.multiplicador_velocidad(j) > 1.0 and Tecnicas.multiplicador_taijutsu(j) > 1.0, "puertas: más velocidad y taijutsu")
	s.free()
	s = servidor(["", "", "", ""], "ocho_puertas")
	j = s.entidad_de_peer(1)
	s.recibir_comando(1, {"t": "nivel", "valor": 3})
	s.recibir_comando(1, {"t": "accion", "id": "modo"})
	var m := muneco_central(s)
	j.pos = m.pos + Vector3(0, 0, 1.5)
	j.yaw = PI
	var evs: Array = []
	for i in 3:
		s.recibir_comando(1, {"t": "accion", "id": "golpe"})
		evs.append_array(correr(s, 0.5))
	comprobar(contar(evs, "golpe_definitivo") == 1, "N3: el tercer golpe es el golpe definitivo")
	comprobar(j.vida <= float(j.stats["vida_max"]) * 0.06 and not j.modo_activo, "la octava puerta te deja casi muerto")
	s.free()


func probar_bola_fuego_suelo() -> void:
	var s := servidor(["bola_fuego", "", "", ""], "")
	var j := s.entidad_de_peer(1)
	s.recibir_comando(1, {"t": "nivel", "valor": 2})
	j.pos = Vector3(0, 0, 6)
	s.recibir_comando(1, {"t": "accion", "id": "bola_fuego", "dir": Vector2(0, -1)})
	correr(s, 2.5)
	comprobar(s.zonas.size() >= 1, "bola de fuego N2 deja el suelo ardiendo")
	s.free()


## Lo que el jugador ve en sus botones debe ser lo que el servidor aceptó, y el ojo requerido se enciende solo.
func probar_sincronia_repertorio() -> void:
	var s := ServidorJuego.new()
	s.auto_procesar = false
	s.iniciar()
	s.agregar_jugador(1)
	s.eventos = []
	s.recibir_comando(1, {"t": "repertorio", "activos": ["rasengan", "susanoo", "bola_fuego", ""], "modo": "sharingan", "prueba": false, "maestria": {}})
	var ev_rep := {}
	var ev_msg := {}
	for e in s.eventos:
		if e["tipo"] == "repertorio":
			ev_rep = e
		if e["tipo"] == "mensaje" and e["clave"] == "rep_invalido_servidor":
			ev_msg = e
	comprobar(not ev_rep.is_empty() and ev_rep.has("activos") and not ("susanoo" in ev_rep["activos"]), "el servidor devuelve el repertorio aceptado (por defecto si no es válido)")
	comprobar(not ev_msg.is_empty() and str(ev_msg["args"][0]) != "", "el aviso de repertorio no válido explica el motivo")
	s.free()
	s = servidor(["susanoo", "rasengan", "", ""], "mangekyo", false, false)
	var j := s.entidad_de_peer(1)
	comprobar("susanoo" in j.jutsus, "repertorio válido aceptado sin modo prueba")
	s.recibir_comando(1, {"t": "accion", "id": "susanoo"})
	comprobar(j.modo_activo and j.estado == "sellos", "el Susanoo enciende solo el Mangekyō equipado y se lanza")
	correr(s, 1.0)
	j.recargas.clear()
	j.chakra = 200.0
	s.eventos = []
	s.recibir_comando(1, {"t": "accion", "id": "rasengan"})
	correr(s, 0.15)
	comprobar(j.estado == "chidori_carga", "el Rasengan se lanza con el repertorio del menú")
	s.free()
