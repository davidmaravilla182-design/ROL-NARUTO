class_name PantallaHistoria
extends Control
## Prólogo / contexto de la historia: pantalla oscura con lluvia, quién habla y el texto que se escribe solo.
## Tocar avanza (primero completa la línea); «Saltar» lo cierra. Emite «terminado» al acabar.

signal terminado

var sonidos: Sonidos
var _titulo := ""
var _lineas: Array = []
var _i := 0
var _letras := 0.0
var _t := 0.0
var _gotas: Array = []


func mostrar(titulo: String, lineas: Array) -> void:
	_titulo = titulo
	_lineas = lineas
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 90:
		_gotas.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.4)))
	var saltar := Button.new()
	saltar.text = Datos.texto("historia_saltar")
	saltar.add_theme_font_size_override("font_size", 22)
	saltar.custom_minimum_size = Vector2(170, 56)
	saltar.focus_mode = Control.FOCUS_NONE
	saltar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	saltar.position += Vector2(-190, 24)
	saltar.pressed.connect(_cerrar)
	add_child(saltar)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)
	gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			_avanzar())
	if sonidos != null:
		sonidos.tocar("papel", -6.0, 0.9)


func _avanzar() -> void:
	if _lineas.is_empty():
		return
	if _letras < str((_lineas[_i] as Array)[1]).length():
		_letras = 9999.0
		return
	if _i < _lineas.size() - 1:
		_i += 1
		_letras = 0.0
		if sonidos != null:
			sonidos.tocar("papel", -12.0, 1.2)
	else:
		_cerrar()


func _cerrar() -> void:
	if not is_inside_tree() or mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		terminado.emit()
		queue_free())


func _process(d: float) -> void:
	_t += d
	_letras += d * 38.0
	queue_redraw()


func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.025, 0.05, 0.94))
	for g in _gotas:
		var x: float = g.x * sz.x
		var y := fmod(g.y * sz.y + _t * 520.0 * g.z, sz.y + 40.0) - 20.0
		draw_line(Vector2(x, y), Vector2(x - 3, y + 18 * g.z), Color(0.6, 0.7, 0.9, 0.25), 1.5)
	Estilo.texto(self, Vector2(0, sz.y * 0.18), _titulo, 52, Color(1.0, 0.85, 0.45), sz.x, HORIZONTAL_ALIGNMENT_CENTER, Estilo.fuente_titulo(), 10)
	if _lineas.is_empty():
		return
	var l: Array = _lineas[_i]
	var ancho := minf(sz.x * 0.72, 1100.0)
	var x0 := (sz.x - ancho) * 0.5
	Estilo.texto(self, Vector2(x0, sz.y * 0.42), str(l[0]), 28, Color(0.95, 0.6, 0.5), ancho, HORIZONTAL_ALIGNMENT_LEFT, Estilo.fuente_titulo(), 6)
	draw_multiline_string(Estilo.fuente_ui(), Vector2(x0, sz.y * 0.42 + 48), str(l[1]).left(int(_letras)), HORIZONTAL_ALIGNMENT_LEFT, ancho, 30, -1, Color(0.92, 0.93, 0.97))
	# Avance: puntos y «toca para continuar».
	for k in _lineas.size():
		draw_circle(Vector2(sz.x * 0.5 + (k - (_lineas.size() - 1) * 0.5) * 22.0, sz.y * 0.82), 5.0, Color(1.0, 0.85, 0.45) if k == _i else Color(0.4, 0.42, 0.5))
	if int(_t * 2.0) % 2 == 0:
		Estilo.texto(self, Vector2(0, sz.y * 0.9), Datos.texto("historia_toca"), 20, Color(0.75, 0.8, 0.9), sz.x, HORIZONTAL_ALIGNMENT_CENTER, null, 4)
