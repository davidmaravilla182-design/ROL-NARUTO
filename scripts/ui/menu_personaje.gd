extends Control
## Personajes: lista de hasta 3 personajes guardados (usar / borrar / crear) y la creación
## por pasos: nombre, apariencia, aldea, clan o linaje, naturaleza y atributos.
## Vista previa 3D del personaje girando bajo la lluvia y panel en vivo con los jutsus que
## quedan disponibles o bloqueados (y por qué) con cada decisión. Todo sale de /data.

const ESCENA_MENU := "res://escenas/menu.tscn"
const PASOS := ["nombre", "apariencia", "aldea", "clan", "naturaleza", "atributos"]

var pj: Dictionary = {}
var paso := 0
var modo := "lista"            # lista | crear
var destino_al_crear := ""     # escena a la que ir tras crear (si se llegó desde "Entrenar")

var _contenido: VBoxContainer
var _scroll: ScrollContainer
var _titulo: Label
var _pasos_fila: HBoxContainer
var _botones: HBoxContainer
var _jutsus: RichTextLabel
var _vp: SubViewport
var _pivote: Node3D
var _pv: PersonajeVisual
var _radar: Radar
var _aviso: Label
var _rng := RandomNumberGenerator.new()
var _borrar_pendiente := -1


func _ready() -> void:
	Datos.cargar()
	Ajustes.cargar()
	Perfil.cargar()
	_rng.randomize()
	destino_al_crear = Sesion.tras_personaje
	Sesion.tras_personaje = ""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Estilo.tema()
	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.06, 0.07, 0.1)
	add_child(fondo)
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 14)
	add_child(margen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margen.add_child(col)

	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 12)
	col.add_child(cab)
	_titulo = Label.new()
	_titulo.add_theme_font_override("font", Estilo.fuente_titulo())
	_titulo.add_theme_font_size_override("font_size", 28)
	_titulo.add_theme_color_override("font_color", Estilo.PAPEL)
	cab.add_child(_titulo)
	_pasos_fila = HBoxContainer.new()
	_pasos_fila.add_theme_constant_override("separation", 4)
	_pasos_fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(_pasos_fila)

	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 12)
	col.add_child(cuerpo)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuerpo.add_child(_scroll)
	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 10)
	_scroll.add_child(_contenido)
	cuerpo.add_child(_crear_vista())
	_jutsus = RichTextLabel.new()
	_jutsus.bbcode_enabled = true
	_jutsus.custom_minimum_size = Vector2(320, 0)
	_jutsus.scroll_active = true
	_jutsus.add_theme_font_size_override("normal_font_size", 15)
	_jutsus.add_theme_font_size_override("bold_font_size", 17)
	cuerpo.add_child(_jutsus)

	_aviso = Label.new()
	_aviso.add_theme_font_size_override("font_size", 17)
	_aviso.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	col.add_child(_aviso)
	_botones = HBoxContainer.new()
	_botones.add_theme_constant_override("separation", 12)
	col.add_child(_botones)

	if Perfil.personajes.is_empty():
		_empezar_creacion()
	else:
		_mostrar_lista()


# ======================================================================== vista 3D

func _crear_vista() -> Control:
	var cont := SubViewportContainer.new()
	cont.custom_minimum_size = Vector2(330, 0)
	cont.stretch = true
	cont.mouse_filter = Control.MOUSE_FILTER_PASS
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X if Ajustes.calidad == "alta" else Viewport.MSAA_DISABLED
	cont.add_child(_vp)
	var mundo := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.1, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.65)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.22, 0.32)
	env.fog_density = 0.04
	mundo.environment = env
	_vp.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, 30, 0)
	sol.light_energy = 1.1
	sol.light_color = Color(0.85, 0.88, 1.0)
	_vp.add_child(sol)
	var calida := OmniLight3D.new()
	calida.position = Vector3(-1.6, 2.2, 1.4)
	calida.light_color = Color(1.0, 0.7, 0.4)
	calida.light_energy = 1.4
	calida.omni_range = 6.0
	_vp.add_child(calida)
	var suelo := Materiales.disco(3.2, Materiales.solido(Color(0.12, 0.13, 0.17), 0.15, 0.3), 32)
	_vp.add_child(suelo)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.transform = Transform3D(Basis(), Vector3(0, 1.25, 3.3)).looking_at(Vector3(0, 1.0, 0), Vector3.UP)
	_vp.add_child(cam)
	cam.current = true
	var lluvia := Lluvia.new()
	_vp.add_child(lluvia)
	lluvia.construir()
	lluvia.objetivo = cam
	_pivote = Node3D.new()
	_vp.add_child(_pivote)
	# Arrastrar sobre la vista gira al personaje.
	cont.gui_input.connect(func(ev):
		if ev is InputEventScreenDrag or (ev is InputEventMouseMotion and ev.button_mask != 0):
			_pivote.rotation.y += ev.relative.x * 0.01)
	return cont


func _process(delta: float) -> void:
	if _pivote != null:
		_pivote.rotation.y += delta * 0.5


func _actualizar_vista() -> void:
	if _pv != null and is_instance_valid(_pv):
		_pv.queue_free()
	_pv = PersonajeVisual.new()
	_pivote.add_child(_pv)
	var datos := pj if modo == "crear" else Perfil.personaje()
	if datos.is_empty():
		_pv.construir(Perfil.PLANTILLA)
	else:
		_pv.construir_aspecto(Creacion.aspecto_visual(datos), str(datos.get("aldea", "lluvia")), str(datos.get("clan", "")))
	_pv.reproducir("quieto")


# ======================================================================== lista de personajes

func _mostrar_lista() -> void:
	modo = "lista"
	_titulo.text = Datos.texto("pj_titulo")
	_limpiar()
	for h in _pasos_fila.get_children():
		h.queue_free()
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	_contenido.add_child(fila)
	for i in Perfil.max_personajes():
		if i < Perfil.personajes.size():
			fila.add_child(_tarjeta_personaje(i))
		else:
			var nuevo := _boton(Datos.texto("pj_nuevo"), _empezar_creacion)
			nuevo.custom_minimum_size = Vector2(220, 200)
			fila.add_child(nuevo)
	var practica := _boton(Datos.texto("pj_practica") if Perfil.indice >= 0 else Datos.texto("pj_practica_activo"), func():
		Perfil.elegir(-1)
		_mostrar_lista())
	practica.disabled = Perfil.indice < 0
	_contenido.add_child(practica)
	_limpiar_botones()
	_botones.add_child(_boton(Datos.texto("pj_volver"), func(): get_tree().change_scene_to_file(ESCENA_MENU)))
	_aviso.text = ""
	_actualizar_vista()
	_actualizar_jutsus(Perfil.personaje())


func _tarjeta_personaje(i: int) -> Control:
	var p: Dictionary = Perfil.personajes[i]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 200)
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0.12, 0.13, 0.18)
	est.border_color = Color(1.0, 0.85, 0.35) if i == Perfil.indice else Estilo.ACERO_BORDE
	est.set_border_width_all(3 if i == Perfil.indice else 1)
	est.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", est)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var n := Label.new()
	n.text = str(p.get("nombre", ""))
	n.add_theme_font_override("font", Estilo.fuente_titulo())
	n.add_theme_font_size_override("font_size", 24)
	v.add_child(n)
	var cl := Creacion.clan(str(p.get("clan", "")))
	var nats: Array = []
	for x in Creacion.naturalezas(p):
		nats.append(Datos.nombre_naturaleza(str(x)))
	var d := Label.new()
	d.text = "%s\n%s\n%s" % [cl.get("nombre", ""), Datos.texto("rango_" + str(p.get("rango", "genin"))), ", ".join(nats)]
	d.add_theme_font_size_override("font_size", 16)
	v.add_child(d)
	var usar := _boton(Datos.texto("pj_en_uso") if i == Perfil.indice else Datos.texto("pj_usar"), func():
		Perfil.elegir(i)
		_mostrar_lista())
	usar.disabled = i == Perfil.indice
	v.add_child(usar)
	var borrar := _boton(Datos.texto("pj_borrar_seguro") if _borrar_pendiente == i else Datos.texto("pj_borrar"), func():
		if _borrar_pendiente == i:
			_borrar_pendiente = -1
			Perfil.borrar(i)
		else:
			_borrar_pendiente = i
		_mostrar_lista())
	borrar.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	v.add_child(borrar)
	return panel


# ======================================================================== creación

func _empezar_creacion() -> void:
	if not Perfil.puede_crear():
		_aviso.text = Datos.texto("rep_lleno")
		return
	pj = Creacion.nuevo()
	paso = 0
	modo = "crear"
	_titulo.text = Datos.texto("pj_crear")
	_mostrar_paso()
	_actualizar_vista()


func _mostrar_paso() -> void:
	_limpiar()
	for h in _pasos_fila.get_children():
		h.queue_free()
	for i in PASOS.size():
		var b := Button.new()
		b.text = "%d %s" % [i + 1, Datos.texto("pj_paso_" + PASOS[i])]
		b.toggle_mode = true
		b.button_pressed = i == paso
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size = Vector2(0, 40)
		b.disabled = i > paso and not _paso_valido(paso)
		b.pressed.connect(func():
			if i <= paso or _paso_valido(paso):
				paso = i
				_mostrar_paso())
		_pasos_fila.add_child(b)
	match PASOS[paso]:
		"nombre":
			_paso_nombre()
		"apariencia":
			_paso_apariencia()
		"aldea":
			_paso_aldea()
		"clan":
			_paso_clan()
		"naturaleza":
			_paso_naturaleza()
		"atributos":
			_paso_atributos()
	_limpiar_botones()
	_botones.add_child(_boton(Datos.texto("pj_cancelar"), func():
		if Perfil.personajes.is_empty():
			get_tree().change_scene_to_file(ESCENA_MENU)
		else:
			_mostrar_lista()))
	if paso > 0:
		_botones.add_child(_boton(Datos.texto("pj_atras"), func():
			paso -= 1
			_mostrar_paso()))
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_botones.add_child(espacio)
	if paso < PASOS.size() - 1:
		_botones.add_child(_boton(Datos.texto("pj_siguiente"), func():
			if _paso_valido(paso):
				paso += 1
				_mostrar_paso()
			else:
				_refrescar_aviso()))
	else:
		var fin := _boton(Datos.texto("pj_terminar"), _terminar)
		fin.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		_botones.add_child(fin)
	_refrescar_aviso()
	_actualizar_jutsus(pj)


func _paso_valido(i: int) -> bool:
	match PASOS[i]:
		"nombre":
			return str(pj.get("nombre", "")).strip_edges().length() >= int(Creacion.conf()["nombre"]["min"])
		"atributos":
			return Creacion.total_puntos(pj["atributos"]) <= Creacion.tope_puntos(pj)
	return true


func _refrescar_aviso() -> void:
	if modo != "crear":
		return
	_aviso.text = ""
	if not _paso_valido(0):
		_aviso.text = Datos.texto("pj_nombre_corto", [int(Creacion.conf()["nombre"]["min"])])
	elif PASOS[paso] == "atributos":
		var v := Creacion.validar(pj)
		if not v["ok"]:
			_aviso.text = str(v["errores"][0])


func _terminar() -> void:
	var v := Creacion.validar(pj)
	if not v["ok"]:
		_aviso.text = str(v["errores"][0])
		return
	Perfil.agregar(v["pj"])
	if destino_al_crear != "":
		get_tree().change_scene_to_file(destino_al_crear)
		return
	_mostrar_lista()


func _cambio(visual := false) -> void:
	if visual:
		_actualizar_vista()
	_actualizar_jutsus(pj)
	_refrescar_aviso()


# ------------------------------------------------------------------ pasos

func _paso_nombre() -> void:
	_contenido.add_child(_texto(Datos.texto("pj_nombre_ayuda"), 24))
	var campo := LineEdit.new()
	campo.text = str(pj.get("nombre", ""))
	campo.max_length = int(Creacion.conf()["nombre"]["max"])
	campo.custom_minimum_size = Vector2(380, 60)
	campo.add_theme_font_size_override("font_size", 28)
	campo.placeholder_text = "Kaito"
	campo.text_changed.connect(func(t):
		pj["nombre"] = t
		_refrescar_aviso()
		_marcar_pasos())
	_contenido.add_child(campo)
	_contenido.add_child(_boton(Datos.texto("pj_nombre_azar"), func():
		var lista: Array = Creacion.conf().get("nombres_sugeridos", ["Kaito"])
		pj["nombre"] = str(lista[_rng.randi() % lista.size()])
		campo.text = pj["nombre"]
		_refrescar_aviso()
		_marcar_pasos()))
	_contenido.add_child(_texto(Datos.texto("pj_rango_inicial", [Datos.texto("rango_" + str(pj["rango"]))]), 18))


func _marcar_pasos() -> void:
	for i in _pasos_fila.get_child_count():
		(_pasos_fila.get_child(i) as Button).disabled = i > paso and not _paso_valido(paso)


func _paso_apariencia() -> void:
	var c := Creacion.conf()
	var a: Dictionary = pj["aspecto"]
	_contenido.add_child(_texto(Datos.texto("pj_peinado"), 20))
	_contenido.add_child(_opciones(c["peinados"], str(a["peinado"]), func(k): a["peinado"] = k; _cambio(true)))
	_contenido.add_child(_texto(Datos.texto("pj_pelo"), 20))
	_contenido.add_child(_colores(c["colores_pelo"], str(a["pelo"]), func(k): a["pelo"] = k; _cambio(true)))
	_contenido.add_child(_texto(Datos.texto("pj_ojos"), 20))
	_contenido.add_child(_colores(c["colores_ojos"], str(a["ojos"]), func(k): a["ojos"] = k; _cambio(true)))
	_contenido.add_child(_texto(Datos.texto("pj_piel"), 20))
	_contenido.add_child(_colores(c["tonos_piel"], str(a["piel"]), func(k): a["piel"] = k; _cambio(true)))
	var comp := {}
	for k in c["complexiones"].keys():
		comp[k] = c["complexiones"][k]["nombre"]
	_contenido.add_child(_texto(Datos.texto("pj_complexion"), 20))
	_contenido.add_child(_opciones(comp, str(a["complexion"]), func(k): a["complexion"] = k; _cambio(true)))
	var ropas := {}
	for k in c["ropas"].keys():
		ropas[k] = c["ropas"][k]["nombre"]
	_contenido.add_child(_texto(Datos.texto("pj_ropa"), 20))
	_contenido.add_child(_opciones(ropas, str(a["ropa"]), func(k): a["ropa"] = k; _cambio(true)))


func _paso_aldea() -> void:
	var aldeas: Dictionary = Creacion.conf()["aldeas"]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_contenido.add_child(grid)
	for k in aldeas.keys():
		var disp := bool(aldeas[k].get("disponible", false))
		var t := _tarjeta(str(aldeas[k]["nombre"]), "" if disp else Datos.texto("pj_proximamente"), "", Color(0.4, 0.6, 0.9),
			str(pj["aldea"]) == k, func():
				if disp:
					pj["aldea"] = k
					_mostrar_paso(), disp)
		grid.add_child(t)


func _paso_clan() -> void:
	_contenido.add_child(_texto(Datos.texto("pj_offline_libre"), 16))
	var rarezas: Dictionary = Creacion.conf()["rarezas"]
	for k in Creacion.clanes().keys():
		var cl: Dictionary = Creacion.clan(k)
		var rz: Dictionary = rarezas.get(str(cl.get("rareza", "")), {})
		var cuerpo := "%s: %s\n%s: %s" % [Datos.texto("pj_ventaja"), cl.get("ventaja", ""), Datos.texto("pj_desventaja"), cl.get("desventaja", "")]
		_contenido.add_child(_tarjeta(str(cl["nombre"]), Datos.texto("pj_rareza", [rz.get("nombre", "")]), cuerpo,
			Datos.color(str(rz.get("color", "#ffffff"))), str(pj["clan"]) == k, func():
				pj["clan"] = k
				var sug := str(cl.get("naturaleza_sugerida", ""))
				if sug != "" and not cl.has("naturalezas_fijas"):
					pj["naturalezas"] = [sug]
				_cambio(true)
				_mostrar_paso()))


func _paso_naturaleza() -> void:
	var cl := Creacion.clan(str(pj["clan"]))
	if cl.has("naturalezas_fijas"):
		var nombres: Array = []
		for n in cl["naturalezas_fijas"]:
			nombres.append(Datos.nombre_naturaleza(str(n)))
		_contenido.add_child(_texto(Datos.texto("pj_naturalezas_fijas", [", ".join(nombres)]), 22))
		return
	_contenido.add_child(_texto(Datos.texto("pj_naturaleza_ayuda"), 20))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_contenido.add_child(fila)
	var actual := str((pj["naturalezas"] as Array)[0]) if not (pj["naturalezas"] as Array).is_empty() else ""
	for n in Creacion.conf()["naturalezas"]["opciones"]:
		var b := Button.new()
		b.text = Datos.nombre_naturaleza(str(n))
		b.toggle_mode = true
		b.button_pressed = str(n) == actual
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(110, 60)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", Datos.color(str(Datos.mundo["naturalezas"]["datos"].get(n, {}).get("color", "#ffffff"))))
		b.pressed.connect(func():
			pj["naturalezas"] = [str(n)]
			_cambio()
			_mostrar_paso())
		fila.add_child(b)
	_contenido.add_child(_boton(Datos.texto("pj_destino"), func():
		var n2 := Creacion.naturaleza_al_azar(_rng)
		pj["naturalezas"] = [n2]
		_cambio()
		_mostrar_paso()
		_aviso.text = Datos.texto("pj_destino_eligio", [Datos.nombre_naturaleza(n2)])))


func _paso_atributos() -> void:
	var attrs: Dictionary = pj["atributos"]
	var puntos := Label.new()
	puntos.add_theme_font_size_override("font_size", 22)
	_contenido.add_child(puntos)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	_contenido.add_child(fila)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 2)
	fila.add_child(lista)
	_radar = Radar.new()
	_radar.custom_minimum_size = Vector2(230, 230)
	fila.add_child(_radar)
	var derivados := Label.new()
	derivados.add_theme_font_size_override("font_size", 17)
	derivados.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var etiquetas := {}
	var refrescar := func():
		puntos.text = Datos.texto("pj_puntos", [Creacion.total_puntos(attrs), Creacion.tope_puntos(pj)])
		puntos.add_theme_color_override("font_color", Color(1, 0.5, 0.45) if Creacion.total_puntos(attrs) > Creacion.tope_puntos(pj) else Estilo.TEXTO)
		for k in etiquetas.keys():
			(etiquetas[k] as Label).text = "●".repeat(int(attrs[k])) + "○".repeat(5 - int(attrs[k]))
		_radar.valores = attrs
		_radar.queue_redraw()
		var s := Creacion.estadisticas(pj)
		derivados.text = Datos.texto("pj_derivados", [int(s["vida_max"]), int(s["chakra_max"]), "%.1f" % float(s["reserva"]), "%.1f" % float(s["control"])])
		_cambio()
	for k in Datos.reglas["atributos"]["lista"]:
		var f := HBoxContainer.new()
		f.add_theme_constant_override("separation", 6)
		var nom := Label.new()
		nom.text = Datos.texto("attr_" + k)
		nom.custom_minimum_size = Vector2(120, 0)
		nom.add_theme_font_size_override("font_size", 18)
		f.add_child(nom)
		var menos := _boton("−", func():
			attrs[k] = maxi(int(attrs[k]) - 1, 0)
			refrescar.call())
		menos.custom_minimum_size = Vector2(48, 42)
		f.add_child(menos)
		var pips := Label.new()
		pips.add_theme_font_size_override("font_size", 20)
		pips.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		pips.custom_minimum_size = Vector2(110, 0)
		etiquetas[k] = pips
		f.add_child(pips)
		var mas := _boton("+", func():
			if int(attrs[k]) < 5 and Creacion.total_puntos(attrs) < Creacion.tope_puntos(pj):
				attrs[k] = int(attrs[k]) + 1
			refrescar.call())
		mas.custom_minimum_size = Vector2(48, 42)
		f.add_child(mas)
		lista.add_child(f)
	_contenido.add_child(_texto(Datos.texto("pj_balance"), 20))
	var fila_b := HBoxContainer.new()
	fila_b.add_theme_constant_override("separation", 8)
	var lc := _texto(Datos.texto("pj_control"), 17)
	lc.autowrap_mode = TextServer.AUTOWRAP_OFF
	fila_b.add_child(lc)
	var sl := HSlider.new()
	sl.min_value = float(Creacion.conf()["balance_chakra"]["min"])
	sl.max_value = float(Creacion.conf()["balance_chakra"]["max"])
	sl.step = 0.1
	sl.value = float(attrs.get("_balance", 0.0))
	sl.custom_minimum_size = Vector2(300, 44)
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v):
		attrs["_balance"] = v
		refrescar.call())
	fila_b.add_child(sl)
	var lr := _texto(Datos.texto("pj_reserva"), 17)
	lr.autowrap_mode = TextServer.AUTOWRAP_OFF
	fila_b.add_child(lr)
	_contenido.add_child(fila_b)
	_contenido.add_child(_texto(Datos.texto("pj_balance_ayuda"), 15))
	_contenido.add_child(derivados)
	refrescar.call()


# ======================================================================== panel de jutsus en vivo

func _actualizar_jutsus(datos: Dictionary) -> void:
	var f: Dictionary = Perfil.ficha() if datos.is_empty() else Creacion.ficha(datos)
	var libres: Array = []
	var bloqueados: Array = []
	for id in Repertorio.catalogo():
		var r := _disponible(id, f)
		var nombre := str(Datos.jutsu(id).get("nombre", id))
		if r["ok"]:
			libres.append("[color=#7fe08a]✔[/color] " + nombre)
		else:
			bloqueados.append("[color=#ff8a7a]✖ %s[/color] [color=#9aa3b5]— %s[/color]" % [nombre, str(r["motivos"][0])])
	var t := "[b]%s[/b]\n" % Datos.texto("pj_jutsus_titulo", [libres.size(), bloqueados.size()])
	t += "\n".join(libres) + "\n\n" + "\n".join(bloqueados)
	_jutsus.text = t


## Disponibilidad con el mejor modo posible (los jutsus de ojos piden su ojo como MODO).
func _disponible(id: String, f: Dictionary) -> Dictionary:
	if Repertorio.es_modo(id):
		return Repertorio.requisitos(id, f, id)
	var req: Dictionary = Datos.jutsu(id).get("requisitos", {})
	if req.has("modo"):
		for m in req["modo"]:
			var rm := Repertorio.requisitos(str(m), f, str(m))
			if rm["ok"]:
				return Repertorio.requisitos(id, f, str(m))
		return Repertorio.requisitos(str(req["modo"][0]), f, str(req["modo"][0]))
	return Repertorio.requisitos(id, f, "")


# ======================================================================== utilidades de interfaz

func _limpiar() -> void:
	for h in _contenido.get_children():
		h.queue_free()
	_scroll.scroll_vertical = 0


func _limpiar_botones() -> void:
	for h in _botones.get_children():
		h.queue_free()


func _boton(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(150, 52)
	b.pressed.connect(cb)
	b.pressed.connect(func(): Ajustes.vibrar(12))
	return b


func _texto(t: String, tam: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _opciones(dic: Dictionary, actual: String, cb: Callable) -> Control:
	var fila := HFlowContainer.new()
	fila.add_theme_constant_override("h_separation", 6)
	fila.add_theme_constant_override("v_separation", 6)
	for k in dic.keys():
		var b := Button.new()
		b.text = str(dic[k])
		b.toggle_mode = true
		b.button_pressed = k == actual
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(100, 48)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func():
			for o in fila.get_children():
				(o as Button).set_pressed_no_signal(o == b)
			cb.call(k))
		fila.add_child(b)
	return fila


func _colores(lista: Array, actual: String, cb: Callable) -> Control:
	var fila := HFlowContainer.new()
	fila.add_theme_constant_override("h_separation", 6)
	fila.add_theme_constant_override("v_separation", 6)
	for c in lista:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 48)
		var col := Color.html(str(c))
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col
			sb.set_corner_radius_all(6)
			var marcado := str(c) == actual
			sb.border_color = Color(1, 0.9, 0.4) if marcado else Color(0, 0, 0, 0.6)
			sb.set_border_width_all(4 if marcado else 2)
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(func():
			cb.call(str(c))
			_mostrar_paso())
		fila.add_child(b)
	return fila


func _tarjeta(titulo: String, sub: String, cuerpo: String, color: Color, elegida: bool, cb: Callable, activa := true) -> Control:
	var panel := PanelContainer.new()
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0.13, 0.14, 0.19) if activa else Color(0.09, 0.09, 0.12)
	est.border_color = Color(1.0, 0.85, 0.35) if elegida else Color(color.r, color.g, color.b, 0.6)
	est.set_border_width_all(3 if elegida else 1)
	est.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", est)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var t := Label.new()
	t.text = titulo
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color.WHITE if activa else Color(0.55, 0.57, 0.62))
	v.add_child(t)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.add_theme_font_size_override("font_size", 16)
		s.add_theme_color_override("font_color", color.lightened(0.2) if activa else Color(0.85, 0.65, 0.3))
		v.add_child(s)
	if cuerpo != "":
		var c := Label.new()
		c.text = cuerpo
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_theme_font_size_override("font_size", 15)
		v.add_child(c)
	for n in v.get_children():
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			Ajustes.vibrar(12)
			cb.call())
	return panel


# ======================================================================== radar

## Gráfica de radar octagonal de los 8 atributos (0-5), redibujada en vivo.
class Radar extends Control:
	var valores: Dictionary = {}

	func _draw() -> void:
		var lista: Array = Datos.reglas["atributos"]["lista"]
		var n := lista.size()
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 28.0
		for anillo in [1, 2, 3, 4, 5]:
			var pts := PackedVector2Array()
			for i in n + 1:
				var a := -PI / 2 + TAU * float(i % n) / n
				pts.append(c + Vector2(cos(a), sin(a)) * r * anillo / 5.0)
			draw_polyline(pts, Color(0.5, 0.55, 0.65, 0.35 if anillo < 5 else 0.7), 1.0, true)
		var poli := PackedVector2Array()
		for i in n:
			var a2 := -PI / 2 + TAU * float(i) / n
			var dir := Vector2(cos(a2), sin(a2))
			draw_line(c, c + dir * r, Color(0.5, 0.55, 0.65, 0.4), 1.0)
			poli.append(c + dir * r * float(valores.get(lista[i], 0)) / 5.0)
			var etiqueta := Datos.texto("attr_" + str(lista[i])).left(4)
			draw_string(Estilo.fuente_ui(), c + dir * (r + 16) - Vector2(18, -5), etiqueta, HORIZONTAL_ALIGNMENT_CENTER, 36, 13, Color(0.85, 0.88, 0.95))
		if poli.size() >= 3 and not Geometry2D.triangulate_polygon(poli).is_empty():
			draw_colored_polygon(poli, Color(1.0, 0.55, 0.2, 0.35))
		var cerrado := poli.duplicate()
		if not poli.is_empty():
			cerrado.append(poli[0])
			draw_polyline(cerrado, Color(1.0, 0.7, 0.3), 2.0, true)
			for p in poli:
				draw_circle(p, 3.5, Color(1.0, 0.85, 0.4))
