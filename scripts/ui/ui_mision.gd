class_name UiMision
extends Control
## Interfaz de misiones dentro de la partida:
##  - panel de objetivo (arriba, centro): título, objetivo, contador y barra de tiempo;
##  - escena: cuadro de diálogo en pergamino con quien habla y el texto que se escribe solo;
##    si es un pájaro de papel, el pájaro entra volando y se despliega;
##  - recompensa: cofre que se abre y los objetos entran uno a uno (XP, ryō, pergaminos, cosméticos);
##  - letrero de anuncio (eventos dinámicos).

signal escena_saltada

var sonidos: Sonidos
var _panel: Control
var _titulo := ""
var _objetivo := ""
var _contador := ""
var _limite := 0.0
var _t := 0.0
var _activo := false
var _escena: Control
var _lineas: Array = []
var _linea_i := 0
var _letras := 0.0
var _escena_t := 0.0
var _pajaro := false
var _recompensa: Control
var _anuncio: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_dibujar_panel)
	add_child(_panel)
	_panel.visible = false
	_anuncio = Label.new()
	_anuncio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anuncio.add_theme_font_override("font", Estilo.fuente_titulo())
	_anuncio.add_theme_font_size_override("font_size", 40)
	_anuncio.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_anuncio.add_theme_color_override("font_outline_color", Color(0.25, 0.02, 0.04))
	_anuncio.add_theme_constant_override("outline_size", 12)
	_anuncio.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_anuncio.offset_top = 236.0
	_anuncio.offset_bottom = 296.0
	_anuncio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anuncio.modulate.a = 0.0
	add_child(_anuncio)


# ------------------------------------------------------------------ objetivo

func mision_inicio(titulo: String) -> void:
	_titulo = titulo
	_objetivo = ""
	_activo = true
	_panel.visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.4)
	anuncio(titulo)


func objetivo(texto: String, contador: String, limite: float, t: float) -> void:
	if texto != _objetivo and texto != "":
		_objetivo = texto
		if sonidos != null:
			sonidos.tocar("papel", -10.0, 1.1)
	_contador = contador
	_limite = limite
	_t = t
	_panel.queue_redraw()


func mision_fin() -> void:
	_activo = false
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _panel.visible = false)


func _dibujar_panel() -> void:
	var ancho := 560.0
	var r := Rect2(Vector2((size.x - ancho) * 0.5, 140), Vector2(ancho, 84))
	Estilo.dibujar_pergamino(_panel, r, 0.92)
	Estilo.texto(_panel, r.position + Vector2(18, 28), _titulo, 22, Color(0.3, 0.08, 0.06), ancho - 36, HORIZONTAL_ALIGNMENT_LEFT, Estilo.fuente_titulo(), 0)
	Estilo.texto(_panel, r.position + Vector2(18, 54), _objetivo, 17, Color(0.18, 0.13, 0.1), ancho - 150, HORIZONTAL_ALIGNMENT_LEFT, null, 0)
	Estilo.texto(_panel, r.position + Vector2(18, 54), _contador, 17, Color(0.45, 0.1, 0.08), ancho - 36, HORIZONTAL_ALIGNMENT_RIGHT, null, 0)
	if _limite > 0.0:
		var frac := clampf(1.0 - _t / _limite, 0.0, 1.0)
		var barra := Rect2(r.position + Vector2(18, 64), Vector2(ancho - 36, 8))
		_panel.draw_rect(barra, Color(0.2, 0.15, 0.1, 0.4))
		_panel.draw_rect(Rect2(barra.position, Vector2(barra.size.x * frac, barra.size.y)), Color(0.75, 0.15, 0.1) if frac < 0.25 else Color(0.35, 0.25, 0.15))


func _process(delta: float) -> void:
	if _activo and _limite > 0.0:
		_t += delta
		_panel.queue_redraw()
	if _escena != null and is_instance_valid(_escena):
		_escena_t += delta
		_letras += delta * 45.0
		_escena.queue_redraw()


# ------------------------------------------------------------------ escena

func escena(lineas: Array, pajaro: bool, duracion: float) -> void:
	cerrar_escena()
	_lineas = lineas
	_linea_i = 0
	_letras = 0.0
	_escena_t = 0.0
	_pajaro = pajaro
	_escena = Control.new()
	_escena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_escena.mouse_filter = Control.MOUSE_FILTER_STOP
	_escena.draw.connect(_dibujar_escena)
	_escena.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			_avanzar_linea())
	add_child(_escena)
	_escena.modulate.a = 0.0
	create_tween().tween_property(_escena, "modulate:a", 1.0, 0.3)
	if sonidos != null:
		sonidos.tocar("papel", -6.0, 0.9)
	# Cada línea dura lo que reparte el servidor.
	var por_linea := maxf(duracion - 1.0, 1.0) / maxf(float(lineas.size()), 1.0)
	var tw := _escena.create_tween()
	for i in lineas.size() - 1:
		tw.tween_interval(por_linea)
		tw.tween_callback(_avanzar_linea)
	tw.tween_interval(por_linea + 0.6)
	tw.tween_callback(cerrar_escena)


func _avanzar_linea() -> void:
	if _escena == null:
		return
	if _letras < str((_lineas[_linea_i] as Array)[1]).length():
		_letras = 9999.0   # primero completa el texto
		return
	if _linea_i < _lineas.size() - 1:
		_linea_i += 1
		_letras = 0.0
		if sonidos != null:
			sonidos.tocar("papel", -12.0, 1.3)


func cerrar_escena() -> void:
	if _escena != null and is_instance_valid(_escena):
		var e := _escena
		var tw := create_tween()
		tw.tween_property(e, "modulate:a", 0.0, 0.25)
		tw.tween_callback(e.queue_free)
	_escena = null


func _dibujar_escena() -> void:
	var sz := _escena.size
	_escena.draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x, 70)), Color(0, 0, 0, 0.75))
	_escena.draw_rect(Rect2(Vector2(0, sz.y - 70), Vector2(sz.x, 70)), Color(0, 0, 0, 0.75))
	if _lineas.is_empty():
		return
	var l: Array = _lineas[_linea_i]
	var quien := str(l[0])
	var texto := str(l[1])
	var r := Rect2(Vector2(sz.x * 0.12, sz.y - 250), Vector2(sz.x * 0.76, 170))
	Estilo.dibujar_pergamino(_escena, r, 0.96)
	Estilo.texto(_escena, r.position + Vector2(28, 40), quien, 26, Color(0.45, 0.08, 0.06), r.size.x - 56, HORIZONTAL_ALIGNMENT_LEFT, Estilo.fuente_titulo(), 0)
	var visible_t := texto.left(int(_letras))
	var f := Estilo.fuente_ui()
	_escena.draw_multiline_string(f, r.position + Vector2(28, 80), visible_t, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, 22, -1, Color(0.15, 0.1, 0.08))
	if _pajaro:
		# Pájaro de papel: entra volando y aletea junto al pergamino.
		var u := clampf(_escena_t / 0.7, 0.0, 1.0)
		var c := Vector2(lerpf(sz.x + 80, r.end.x - 40, 1.0 - pow(1.0 - u, 3.0)), r.position.y - 30 + sin(_escena_t * 6.0) * 6.0)
		var ala := sin(_escena_t * 14.0) * 18.0
		var col := Color(0.92, 0.88, 0.98)
		_escena.draw_colored_polygon(PackedVector2Array([c + Vector2(-34, 0), c + Vector2(30, -4), c + Vector2(0, 8)]), col)
		_escena.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -2), c + Vector2(10, -2), c + Vector2(-2, -30 - ala)]), col.darkened(0.08))
		_escena.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(10, 0), c + Vector2(6, -22 + ala)]), col.darkened(0.18))
		_escena.draw_rect(Rect2(c + Vector2(-8, -1), Vector2(14, 5)), Color(0.6, 0.12, 0.12))


# ------------------------------------------------------------------ recompensa

func recompensa(titulo: String, rec: Dictionary, exito: bool, extra := "") -> void:
	if _recompensa != null and is_instance_valid(_recompensa):
		_recompensa.queue_free()
	_recompensa = PantallaRecompensa.new()
	_recompensa.sonidos = sonidos
	add_child(_recompensa)
	_recompensa.mostrar(titulo, rec, exito, extra)


func anuncio(t: String) -> void:
	_anuncio.text = t
	_anuncio.pivot_offset = _anuncio.size * 0.5
	_anuncio.scale = Vector2(1.4, 1.4)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_anuncio, "modulate:a", 1.0, 0.2)
	tw.tween_property(_anuncio, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.2)
	tw.chain().tween_property(_anuncio, "modulate:a", 0.0, 0.5)
	if sonidos != null:
		sonidos.tocar("tambor", -4.0, 1.0)
