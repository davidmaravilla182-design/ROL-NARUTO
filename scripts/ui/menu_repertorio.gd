extends Control
## Menú del repertorio: pestañas por categoría, filtro "solo disponibles", tarjetas con estado,
## detalle de los 3 niveles con vista previa animada, ranuras (4 activos + 1 modo) con arrastrar
## y soltar, 3 repertorios guardados y "Modo prueba: desbloquear todo".

const ESCENA_MENU := "res://escenas/menu.tscn"
const ESCENA_JUEGO := "res://escenas/juego.tscn"
const TAM_TARJETA := Vector2(214, 140)

var _categoria := ""   # "" = todas
var _solo_disponibles := false
var _rol := ""          # "" = todos; ataque, defensa, control, apoyo
var _roles_fila: HBoxContainer
var _grid: GridContainer
var _tabs: HBoxContainer
var _ranuras: Array = []       # [Ranura x4]
var _ranura_modo: Control
var _puntos: Label
var _errores: Label
var _botones_rep: Array = []
var _detalle: Control
var _entrenar: Button


func _ready() -> void:
	Datos.cargar()
	Ajustes.cargar()
	Perfil.cargar()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Estilo.tema()
	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.07, 0.08, 0.11)
	add_child(fondo)
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 14)
	add_child(margen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margen.add_child(col)

	# --- barra superior
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 10)
	col.add_child(barra)
	var titulo := Label.new()
	titulo.text = Datos.texto("rep_titulo")
	titulo.add_theme_font_override("font", Estilo.fuente_titulo())
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.add_theme_color_override("font_color", Estilo.PAPEL)
	barra.add_child(titulo)
	for i in Perfil.repertorios.size():
		var b := _boton(Datos.texto("rep_slot", [i + 1]), func(): _elegir_rep(i))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(64, 50)
		barra.add_child(b)
		_botones_rep.append(b)
	_puntos = Label.new()
	_puntos.add_theme_font_size_override("font_size", 24)
	_puntos.custom_minimum_size = Vector2(150, 0)
	barra.add_child(_puntos)
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(espacio)
	barra.add_child(_boton(Datos.texto("rep_volver"), func():
		Perfil.guardar()
		get_tree().change_scene_to_file(ESCENA_MENU)))
	_entrenar = _boton(Datos.texto("rep_entrenar"), func():
		Perfil.guardar()
		get_tree().change_scene_to_file(ESCENA_JUEGO))
	barra.add_child(_entrenar)

	# --- pestañas + filtro
	var fila_tabs := HBoxContainer.new()
	fila_tabs.add_theme_constant_override("separation", 6)
	col.add_child(fila_tabs)
	var scroll_tabs := ScrollContainer.new()
	scroll_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_tabs.custom_minimum_size = Vector2(0, 56)
	scroll_tabs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fila_tabs.add_child(scroll_tabs)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	scroll_tabs.add_child(_tabs)
	_crear_tab("", Datos.texto("rep_cat_todas"), Estilo.ACERO_BORDE)
	var cats := Repertorio.categorias()
	for k in cats.keys():
		_crear_tab(k, str(cats[k]["nombre"]), Datos.color(str(cats[k]["color"])))

	# --- filtro por uso: ataque, defensa, control, apoyo
	_roles_fila = HBoxContainer.new()
	_roles_fila.add_theme_constant_override("separation", 6)
	col.add_child(_roles_fila)
	var roles := Repertorio.roles()
	_crear_rol("", Datos.texto("rep_rol_todos"), Estilo.ACERO_BORDE)
	for k in roles.keys():
		_crear_rol(k, str(roles[k]["nombre"]), Datos.color(str(roles[k]["color"])))

	# --- cuerpo: tarjetas a la izquierda, ranuras a la derecha
	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 12)
	col.add_child(cuerpo)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuerpo.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	# Columnas según el ancho disponible (pantallas de celular más alargadas muestran más tarjetas).
	scroll.resized.connect(func(): _grid.columns = maxi(2, int((scroll.size.x - 12) / (TAM_TARJETA.x + 8))))
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)

	var scroll_lado := ScrollContainer.new()
	scroll_lado.custom_minimum_size = Vector2(312, 0)
	scroll_lado.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuerpo.add_child(scroll_lado)
	var lado := VBoxContainer.new()
	lado.custom_minimum_size = Vector2(300, 0)
	lado.add_theme_constant_override("separation", 5)
	scroll_lado.add_child(lado)
	for i in int(Repertorio.conf().get("ranuras_activas", 4)):
		var rn := Ranura.new()
		rn.configurar(self, i)
		lado.add_child(rn)
		_ranuras.append(rn)
	_ranura_modo = Ranura.new()
	_ranura_modo.configurar(self, -1)
	lado.add_child(_ranura_modo)
	_errores = Label.new()
	_errores.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_errores.custom_minimum_size = Vector2(300, 0)
	_errores.add_theme_font_size_override("font_size", 16)
	lado.add_child(_errores)
	var filtro := CheckButton.new()
	filtro.text = Datos.texto("rep_solo_disponibles")
	filtro.focus_mode = Control.FOCUS_NONE
	filtro.add_theme_font_size_override("font_size", 18)
	filtro.toggled.connect(func(v):
		_solo_disponibles = v
		_refrescar())
	lado.add_child(filtro)
	var prueba := CheckButton.new()
	prueba.text = Datos.texto("rep_modo_prueba")
	prueba.button_pressed = Perfil.modo_prueba
	prueba.focus_mode = Control.FOCUS_NONE
	prueba.add_theme_font_size_override("font_size", 18)
	prueba.toggled.connect(func(v):
		Perfil.modo_prueba = v
		_refrescar())
	lado.add_child(prueba)

	_refrescar()


func _boton(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 21)
	b.custom_minimum_size = Vector2(110, 50)
	b.pressed.connect(cb)
	return b


func _crear_tab(id: String, nombre: String, color: Color) -> void:
	var b := Button.new()
	b.text = nombre
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", color.lightened(0.3))
	b.set_meta("cat", id)
	b.pressed.connect(func():
		_categoria = id
		_refrescar())
	_tabs.add_child(b)


func _crear_rol(id: String, nombre: String, color: Color) -> void:
	var b := Button.new()
	b.text = nombre
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(120, 40)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", color.lightened(0.25))
	b.set_meta("rol", id)
	b.pressed.connect(func():
		_rol = id
		_refrescar())
	_roles_fila.add_child(b)


func _elegir_rep(i: int) -> void:
	Perfil.activo = i
	Perfil.guardar()
	_refrescar()


func rep() -> Dictionary:
	return Perfil.repertorio()


## Estado de una tarjeta: {disponible, motivo, proximamente}.
func estado(id: String) -> Dictionary:
	if not Repertorio.implementado(id):
		return {"disponible": false, "motivo": Datos.texto("rep_proximamente"), "proximamente": true}
	if Perfil.modo_prueba:
		return {"disponible": true, "motivo": "", "proximamente": false}
	var r := Repertorio.requisitos(id, Perfil.ficha(), str(rep()["modo"]) if not Repertorio.es_modo(id) else id)
	if not r["ok"]:
		return {"disponible": false, "motivo": str(r["motivos"][0]), "proximamente": false}
	var inc := Repertorio.incompatible(id, rep())
	if inc != "":
		return {"disponible": false, "motivo": inc, "proximamente": false}
	return {"disponible": true, "motivo": "", "proximamente": false}


func _refrescar() -> void:
	for i in _botones_rep.size():
		(_botones_rep[i] as Button).set_pressed_no_signal(i == Perfil.activo)
	for b in _tabs.get_children():
		(b as Button).set_pressed_no_signal(str(b.get_meta("cat")) == _categoria)
	for b in _roles_fila.get_children():
		(b as Button).set_pressed_no_signal(str(b.get_meta("rol")) == _rol)
	for h in _grid.get_children():
		h.queue_free()
	for id in Repertorio.catalogo():
		if _categoria != "" and str(Datos.jutsu(id).get("categoria", "")) != _categoria:
			continue
		if _rol != "" and str(Datos.jutsu(id).get("rol", "")) != _rol:
			continue
		var est := estado(id)
		if _solo_disponibles and not est["disponible"]:
			continue
		var t := Tarjeta.new()
		t.configurar(self, id, est)
		_grid.add_child(t)
	for rn in _ranuras:
		rn.queue_redraw()
	_ranura_modo.queue_redraw()
	var v := Repertorio.validar(rep(), Perfil.ficha(), Perfil.modo_prueba)
	var tope := int(Repertorio.conf().get("tope_puntos", 12))
	_puntos.text = Datos.texto("rep_puntos_hud", [v["puntos"], tope])
	_puntos.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if int(v["puntos"]) > tope and not Perfil.modo_prueba else Estilo.TEXTO)
	_errores.text = "\n".join(v["errores"]) if not v["ok"] else Datos.texto("rep_arrastra")
	_errores.add_theme_color_override("font_color", Color(1, 0.5, 0.45) if not v["ok"] else Color(0.7, 0.75, 0.82))
	_entrenar.disabled = not v["ok"]


## Equipa `id` en la ranura `i` (-1 = modo). Si ya estaba en otra ranura, se mueve.
func equipar(id: String, i: int) -> bool:
	var r := rep()
	if Repertorio.es_modo(id) != (i == -1):
		return false
	var nuevo: Dictionary = r.duplicate(true)
	var activos: Array = nuevo["activos"]
	for k in activos.size():
		if str(activos[k]) == id:
			activos[k] = ""
	var aviso := ""
	if i == -1:
		nuevo["modo"] = id
	else:
		activos[i] = id
		# Si el jutsu pide un ojo como MODO y no está, se equipa ese ojo automáticamente.
		var req_modo: Array = Datos.jutsu(id).get("requisitos", {}).get("modo", [])
		if not req_modo.is_empty() and not (str(nuevo["modo"]) in req_modo):
			var elegido := str(req_modo[0])
			for m in req_modo:
				if Perfil.modo_prueba or Repertorio.requisitos(str(m), Perfil.ficha(), str(m))["ok"]:
					elegido = str(m)
					break
			nuevo["modo"] = elegido
			aviso = Datos.texto("rep_modo_auto", [Datos.jutsu(elegido).get("nombre", elegido), Datos.jutsu(id).get("nombre", id)])
	var tope := int(Repertorio.conf().get("tope_puntos", 12))
	if not Perfil.modo_prueba and Repertorio.puntos_usados(nuevo) > tope:
		_refrescar()
		_errores.text = Datos.texto("rep_sin_puntos")
		_errores.add_theme_color_override("font_color", Color(1, 0.5, 0.45))
		return false
	r["activos"] = nuevo["activos"]
	r["modo"] = nuevo["modo"]
	Perfil.guardar()
	Ajustes.vibrar(15)
	_refrescar()
	if aviso != "":
		_errores.text = aviso
		_errores.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	return true


## Equipa en la primera ranura libre del tipo correcto.
func equipar_libre(id: String) -> void:
	if Repertorio.es_modo(id):
		equipar(id, -1)
		return
	var activos: Array = rep()["activos"]
	for k in activos.size():
		if str(activos[k]) == "" or str(activos[k]) == id:
			equipar(id, k)
			return
	_errores.text = Datos.texto("rep_lleno")


func quitar(i: int) -> void:
	var r := rep()
	if i == -1:
		r["modo"] = ""
	else:
		r["activos"][i] = ""
	Perfil.guardar()
	_refrescar()


## Cicla el nivel máximo a usar en combate: el más alto → N1 → N2 → N3 → el más alto.
func ciclar_nivel(i: int) -> void:
	var id := str(rep()["modo"]) if i == -1 else str(rep()["activos"][i])
	if id == "":
		return
	var niveles: Dictionary = rep().get("niveles_max", {})
	var actual := int(niveles.get(id, 0))
	actual = (actual + 1) % 4
	if actual == 0:
		niveles.erase(id)
	else:
		niveles[id] = actual
	rep()["niveles_max"] = niveles
	Perfil.guardar()
	_refrescar()


func abrir_detalle(id: String) -> void:
	if _detalle != null and is_instance_valid(_detalle):
		_detalle.queue_free()
	_detalle = Detalle.new()
	add_child(_detalle)
	_detalle.configurar(self, id, estado(id))


# ======================================================================= tarjeta

class Tarjeta extends Control:
	var menu
	var id := ""
	var est: Dictionary = {}

	func configurar(p_menu, p_id: String, p_est: Dictionary) -> void:
		menu = p_menu
		id = p_id
		est = p_est
		custom_minimum_size = TAM_TARJETA
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			menu.abrir_detalle(id)
			accept_event()

	func _get_drag_data(_p: Vector2) -> Variant:
		if not est["disponible"]:
			return null
		var vista := Control.new()
		var icono := TextureRect.new()
		vista.add_child(icono)
		var lbl := Label.new()
		lbl.text = str(Datos.jutsu(id).get("nombre", id))
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.position = Vector2(-40, -20)
		vista.add_child(lbl)
		set_drag_preview(vista)
		return {"jutsu": id}

	func _draw() -> void:
		var j := Datos.jutsu(id)
		var cat := str(j.get("categoria", ""))
		var col := Datos.color(str(Repertorio.categorias().get(cat, {}).get("color", "#888888")))
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.12, 0.13, 0.17, 0.97))
		draw_rect(Rect2(Vector2.ZERO, Vector2(8, size.y)), col)
		var equipado: bool = id in Repertorio.equipados(menu.rep())
		draw_rect(r, Color(1.0, 0.85, 0.35) if equipado else Color(col.r, col.g, col.b, 0.55), false, 3.0 if equipado else 1.5)
		Iconos.dibujar_icono(self, str(j.get("icono", "")), Vector2(46, 58), 28.0, false, int(j.get("patron", 1)), id)
		# Nombre (hasta 2 líneas)
		var f := Estilo.fuente_ui()
		var nombre := str(j.get("nombre", id))
		var ancho := size.x - 84 - 40
		var tam := 19
		for palabra in nombre.split(" "):
			while tam > 13 and f.get_string_size(palabra, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > ancho:
				tam -= 1
		draw_multiline_string(f, Vector2(84, 30), nombre, HORIZONTAL_ALIGNMENT_LEFT, ancho, tam, 2, Color.WHITE)
		# Puntos (círculo arriba a la derecha)
		var pc := Vector2(size.x - 20, 22)
		draw_circle(pc, 15, Color(0.05, 0.05, 0.08))
		draw_arc(pc, 15, 0, TAU, 20, col, 2.0, true)
		Estilo.texto(self, pc + Vector2(-15, 7), str(int(j.get("puntos", 0))), 19, Color.WHITE, 30, HORIZONTAL_ALIGNMENT_CENTER)
		# Uso (ataque / defensa / control / apoyo) bajo los puntos
		var rol: Dictionary = Repertorio.roles().get(str(j.get("rol", "")), {})
		if not rol.is_empty():
			var rc := Datos.color(str(rol["color"]))
			var caja := Rect2(Vector2(size.x - 74, 86), Vector2(66, 20))
			draw_rect(caja, Color(rc.r, rc.g, rc.b, 0.22))
			draw_rect(caja, rc, false, 1.0)
			Estilo.texto(self, caja.position + Vector2(0, 15), str(rol["nombre"]), 13, rc.lightened(0.3), caja.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		# Modo
		if str(j.get("ranura", "")) == "modo":
			Estilo.texto(self, Vector2(84, 74), Datos.texto("rep_ranura_modo"), 15, Color(1.0, 0.8, 0.4))
		# Nivel de maestría ●○○
		var nivel := Repertorio.nivel_desbloqueado(Perfil.xp(id))
		for k in 3:
			var p := Vector2(92 + k * 18, 96)
			draw_circle(p, 6, Color(0, 0, 0, 0.7))
			draw_circle(p, 4.5, Color(1.0, 0.85, 0.3) if k < nivel else Color(0.3, 0.3, 0.34))
		# Requisito
		Estilo.texto(self, Vector2(12, size.y - 12), Repertorio.texto_requisito(id), 14, Color(0.72, 0.76, 0.84), size.x - 20, HORIZONTAL_ALIGNMENT_LEFT, null, 3)
		if est["proximamente"]:
			draw_rect(r, Color(0, 0, 0, 0.45))
			var banda := PackedVector2Array([Vector2(size.x - 120, size.y), Vector2(size.x - 70, size.y), Vector2(size.x, size.y - 70), Vector2(size.x, size.y - 120)])
			draw_colored_polygon(banda, Color(0.75, 0.55, 0.1, 0.95))
			Estilo.texto(self, Vector2(10, size.y * 0.55), Datos.texto("rep_proximamente"), 17, Color(1.0, 0.85, 0.4), size.x - 20, HORIZONTAL_ALIGNMENT_CENTER, Estilo.fuente_titulo(), 5)
		elif not est["disponible"]:
			draw_rect(r, Color(0, 0, 0, 0.55))
			# Candado
			var lc := Vector2(size.x - 24, size.y - 44)
			draw_arc(lc + Vector2(0, -8), 8, PI, TAU, 10, Color(0.9, 0.9, 0.95), 3.0, true)
			draw_rect(Rect2(lc + Vector2(-10, -8), Vector2(20, 16)), Color(0.9, 0.9, 0.95))
			draw_multiline_string(Estilo.fuente_ui(), Vector2(12, size.y - 50), str(est["motivo"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 50, 15, 2, Color(1.0, 0.6, 0.5))


# ======================================================================= ranura

class Ranura extends Control:
	var menu
	var indice := 0   # -1 = modo

	func configurar(p_menu, i: int) -> void:
		menu = p_menu
		indice = i
		custom_minimum_size = Vector2(300, 64)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _id() -> String:
		var r: Dictionary = menu.rep()
		return str(r["modo"]) if indice == -1 else str(r["activos"][indice])

	func _can_drop_data(_p: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.has("jutsu") and Repertorio.es_modo(str(data["jutsu"])) == (indice == -1)

	func _drop_data(_p: Vector2, data: Variant) -> void:
		menu.equipar(str(data["jutsu"]), indice)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _id() == "":
				return
			if ev.position.x > size.x - 44:
				menu.quitar(indice)      # ✕
			elif ev.position.x > size.x - 140:
				menu.ciclar_nivel(indice)  # nivel máximo a usar
			else:
				menu.abrir_detalle(_id())
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var id := _id()
		Estilo.dibujar_marco(self, r, 0.92, false)
		if indice == -1:
			Estilo.texto(self, Vector2(10, 18), Datos.texto("rep_ranura_modo"), 15, Color(1.0, 0.8, 0.4))
		if id == "":
			Estilo.texto(self, Vector2(0, size.y * 0.62), Datos.texto("rep_ranura_vacia"), 20, Color(0.55, 0.58, 0.65), size.x, HORIZONTAL_ALIGNMENT_CENTER)
			return
		var j := Datos.jutsu(id)
		Iconos.dibujar_icono(self, str(j.get("icono", "")), Vector2(40, size.y * 0.55), 24.0, false, int(j.get("patron", 1)), id)
		draw_multiline_string(Estilo.fuente_ui(), Vector2(74, 28), str(j.get("nombre", id)), HORIZONTAL_ALIGNMENT_LEFT, size.x - 214, 17, 1, Color.WHITE)
		var nivel := Repertorio.nivel_desbloqueado(Perfil.xp(id))
		for k in 3:
			draw_circle(Vector2(82 + k * 16, size.y - 15), 5, Color(1.0, 0.85, 0.3) if k < nivel else Color(0.3, 0.3, 0.34))
		var nmax := int(menu.rep().get("niveles_max", {}).get(id, 0))
		var txt := Datos.texto("rep_nivel_auto") if nmax == 0 else Datos.texto("rep_nivel_max", [nmax])
		draw_rect(Rect2(Vector2(size.x - 138, 16), Vector2(90, size.y - 32)), Color(0.15, 0.17, 0.22))
		draw_multiline_string(Estilo.fuente_ui(), Vector2(size.x - 134, 38), txt, HORIZONTAL_ALIGNMENT_CENTER, 82, 14, 2, Color(0.85, 0.9, 1.0))
		Iconos.cancelar(self, Vector2(size.x - 22, size.y * 0.5), 16)


# ======================================================================= detalle

class Detalle extends Control:
	var menu
	var id := ""

	func configurar(p_menu, p_id: String, est: Dictionary) -> void:
		menu = p_menu
		id = p_id
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var velo := ColorRect.new()
		velo.color = Color(0, 0, 0, 0.7)
		velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(velo)
		var j := Datos.jutsu(id)
		var panel := PanelContainer.new()
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.1, 0.11, 0.15, 0.98)
		estilo.border_color = Datos.color(str(Repertorio.categorias().get(str(j.get("categoria", "")), {}).get("color", "#888888")))
		estilo.set_border_width_all(3)
		estilo.set_content_margin_all(18)
		panel.add_theme_stylebox_override("panel", estilo)
		add_child(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(scroll)
		var caja := VBoxContainer.new()
		caja.add_theme_constant_override("separation", 8)
		caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(caja)
		var cab := Label.new()
		cab.text = "%s  ·  %s  ·  %s  ·  %d pts" % [j.get("nombre", id), Repertorio.categorias().get(str(j.get("categoria", "")), {}).get("nombre", ""),
			Repertorio.roles().get(str(j.get("rol", "")), {}).get("nombre", ""), int(j.get("puntos", 0))]
		cab.add_theme_font_override("font", Estilo.fuente_titulo())
		cab.add_theme_font_size_override("font_size", 28)
		caja.add_child(cab)
		var req := Label.new()
		req.text = Repertorio.texto_requisito(id) + ("" if est["disponible"] else "   —   " + str(est["motivo"]))
		req.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9) if est["disponible"] else Color(1.0, 0.6, 0.5))
		req.add_theme_font_size_override("font_size", 19)
		caja.add_child(req)
		var niveles := HBoxContainer.new()
		niveles.add_theme_constant_override("separation", 14)
		caja.add_child(niveles)
		var attrs: Dictionary = Datos.personaje(Perfil.PLANTILLA).get("atributos", {})
		for n in 3:
			var colu := VBoxContainer.new()
			colu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			niveles.add_child(colu)
			var vp := VistaPrevia.new()
			vp.custom_minimum_size = Vector2(0, 130)
			vp.configurar(id, n + 1)
			colu.add_child(vp)
			var d := Label.new()
			var nd: Dictionary = j["niveles"][n]
			d.text = "N%d · %s\n%s" % [n + 1, nd.get("descripcion", ""), Datos.texto("rep_costo", [int(round(Combate.costo_chakra(id, n + 1, attrs)))])]
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(300, 0)
			d.add_theme_font_size_override("font_size", 17)
			colu.add_child(d)
		var ventaja := Label.new()
		ventaja.text = "%s: %s" % [Datos.texto("rep_ventaja"), j.get("ventaja", "")]
		ventaja.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
		ventaja.add_theme_font_size_override("font_size", 19)
		ventaja.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caja.add_child(ventaja)
		var desv := Label.new()
		desv.text = "⚠ %s: %s" % [Datos.texto("rep_desventaja"), j.get("desventaja", "")]
		desv.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
		desv.add_theme_font_size_override("font_size", 19)
		desv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caja.add_child(desv)
		var xp := Perfil.xp(id)
		var umbrales := Repertorio.xp_niveles()
		var nv := Repertorio.nivel_desbloqueado(xp)
		var ml := Label.new()
		ml.text = Datos.texto("rep_maestria_max", [int(xp)]) if nv >= 3 else Datos.texto("rep_maestria", [int(xp), int(umbrales[nv])])
		ml.add_theme_font_size_override("font_size", 18)
		caja.add_child(ml)
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 12)
		caja.add_child(fila)
		if est["disponible"]:
			var eq := Button.new()
			eq.text = Datos.texto("rep_equipar")
			eq.custom_minimum_size = Vector2(200, 58)
			eq.focus_mode = Control.FOCUS_NONE
			eq.pressed.connect(func():
				menu.equipar_libre(id)
				queue_free())
			fila.add_child(eq)
		var cerrar := Button.new()
		cerrar.text = Datos.texto("rep_cerrar")
		cerrar.custom_minimum_size = Vector2(160, 58)
		cerrar.focus_mode = Control.FOCUS_NONE
		cerrar.pressed.connect(queue_free)
		fila.add_child(cerrar)
