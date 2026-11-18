class_name MenuAjustes
extends Control
## Menú de ajustes: tamaño y transparencia de botones, sensibilidad de cámara,
## calidad gráfica (baja/media/alta), vibración y FPS. Se guarda en user://ajustes.cfg.

signal cerrado()
signal cambiado()                  # cambios que se aplican al instante
signal reinicio_pedido()           # la calidad gráfica se aplica reconstruyendo la escena

var _panel: Control
var _calidad_inicial := ""
var _aviso: Label
var _botones_calidad: Dictionary = {}
var _botones_fps: Dictionary = {}


func construir() -> void:
	Ajustes.cargar()
	_calidad_inicial = Ajustes.calidad
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Estilo.tema()
	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.03, 0.05, 0.72)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	_panel = Control.new()
	_panel.draw.connect(func(): Estilo.dibujar_marco(_panel, Rect2(Vector2.ZERO, _panel.size), 0.97))
	add_child(_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	caja.position = Vector2(36, 22)
	_panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = Datos.texto("ajustes_titulo")
	titulo.add_theme_font_override("font", Estilo.fuente_titulo())
	titulo.add_theme_font_size_override("font_size", 40)
	titulo.add_theme_color_override("font_color", Estilo.PAPEL)
	caja.add_child(titulo)

	caja.add_child(_fila_slider("ajustes_tamano", 0.7, 1.35, Ajustes.tamano_botones, func(v): Ajustes.tamano_botones = v; cambiado.emit()))
	caja.add_child(_fila_slider("ajustes_opacidad", 0.3, 1.0, Ajustes.opacidad_botones, func(v): Ajustes.opacidad_botones = v; cambiado.emit()))
	caja.add_child(_fila_slider("ajustes_sensibilidad", 0.4, 2.5, Ajustes.sensibilidad, func(v): Ajustes.sensibilidad = v; cambiado.emit()))

	var fila_cal := HBoxContainer.new()
	fila_cal.add_theme_constant_override("separation", 12)
	fila_cal.add_child(_etiqueta("ajustes_calidad"))
	for q in ["baja", "media", "alta"]:
		var b := Button.new()
		b.text = Datos.texto("calidad_" + q)
		b.toggle_mode = true
		b.button_pressed = Ajustes.calidad == q
		b.custom_minimum_size = Vector2(130, 58)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_elegir_calidad.bind(q))
		_botones_calidad[q] = b
		fila_cal.add_child(b)
	caja.add_child(fila_cal)

	# Límite de FPS: 30 ahorra batería y calor; 60 es más fluido. Por defecto sigue a la calidad.
	var fila_fps := HBoxContainer.new()
	fila_fps.add_theme_constant_override("separation", 12)
	fila_fps.add_child(_etiqueta("ajustes_limite_fps"))
	for f in [30, 60]:
		var bf := Button.new()
		bf.text = str(f)
		bf.toggle_mode = true
		bf.custom_minimum_size = Vector2(110, 58)
		bf.focus_mode = Control.FOCUS_NONE
		bf.pressed.connect(_elegir_fps.bind(f))
		_botones_fps[f] = bf
		fila_fps.add_child(bf)
	caja.add_child(fila_fps)
	_marcar_fps()

	var fila_ch := HBoxContainer.new()
	fila_ch.add_theme_constant_override("separation", 30)
	fila_ch.add_child(_casilla("ajustes_vibracion", Ajustes.vibracion, func(v): Ajustes.vibracion = v; cambiado.emit()))
	fila_ch.add_child(_casilla("ajustes_fps", Ajustes.mostrar_fps, func(v): Ajustes.mostrar_fps = v; cambiado.emit()))
	caja.add_child(fila_ch)
	caja.add_child(_casilla("ajustes_simular_red", Ajustes.simular_red, func(v): Ajustes.simular_red = v; cambiado.emit()))

	_aviso = Label.new()
	_aviso.text = Datos.texto("ajustes_aviso_calidad")
	_aviso.add_theme_font_size_override("font_size", 21)
	_aviso.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	_aviso.visible = false
	caja.add_child(_aviso)

	var fila_b := HBoxContainer.new()
	fila_b.add_theme_constant_override("separation", 16)
	var cerrar := Button.new()
	cerrar.text = Datos.texto("ajustes_cerrar")
	cerrar.custom_minimum_size = Vector2(200, 62)
	cerrar.focus_mode = Control.FOCUS_NONE
	cerrar.pressed.connect(_cerrar)
	fila_b.add_child(cerrar)
	caja.add_child(fila_b)

	get_viewport().size_changed.connect(_ajustar)
	caja.resized.connect(_ajustar)
	_ajustar()


func _ajustar() -> void:
	if _panel == null:
		return
	var caja: Control = _panel.get_child(0)
	var t := get_viewport_rect().size
	var tam := caja.get_combined_minimum_size() + Vector2(72, 48)
	tam.x = maxf(tam.x, 640)
	_panel.size = tam
	_panel.position = (t - tam) * 0.5
	_panel.queue_redraw()


func _etiqueta(clave: String) -> Label:
	var l := Label.new()
	l.text = Datos.texto(clave)
	l.custom_minimum_size = Vector2(230, 0)
	l.add_theme_font_size_override("font_size", 26)
	return l


func _fila_slider(clave: String, minimo: float, maximo: float, valor: float, cb: Callable) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	fila.add_child(_etiqueta(clave))
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = 0.05
	s.value = valor
	s.custom_minimum_size = Vector2(300, 48)
	s.focus_mode = Control.FOCUS_NONE
	var val := Label.new()
	val.text = "%d %%" % int(round(valor * 100))
	val.custom_minimum_size = Vector2(90, 0)
	s.value_changed.connect(func(v):
		val.text = "%d %%" % int(round(v * 100))
		cb.call(v))
	fila.add_child(s)
	fila.add_child(val)
	return fila


func _casilla(clave: String, valor: bool, cb: Callable) -> Control:
	var b := CheckButton.new()
	b.text = Datos.texto(clave)
	b.button_pressed = valor
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.toggled.connect(func(v): cb.call(v))
	return b


func _elegir_fps(f: int) -> void:
	Ajustes.limite_fps = f
	Ajustes.aplicar_fps()
	_marcar_fps()
	cambiado.emit()


func _marcar_fps() -> void:
	for k in _botones_fps.keys():
		(_botones_fps[k] as Button).set_pressed_no_signal(k == Ajustes.fps_limite())


func _elegir_calidad(q: String) -> void:
	Ajustes.calidad = q
	for k in _botones_calidad.keys():
		(_botones_calidad[k] as Button).set_pressed_no_signal(k == q)
	_marcar_fps()
	_aviso.visible = q != _calidad_inicial


func _cerrar() -> void:
	Ajustes.guardar()
	if Ajustes.calidad != _calidad_inicial:
		reinicio_pedido.emit()
	cerrado.emit()
	queue_free()
