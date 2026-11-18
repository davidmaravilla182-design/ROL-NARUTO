class_name Barra
extends Control
## Barra de recurso (vida, chakra, estamina) dibujada por código, con valor numérico.

var etiqueta := ""
var color := Color.RED
var valor := 1.0
var maximo := 1.0
var _mostrado := 1.0
var _retraso := 1.0


func configurar(p_etiqueta: String, p_color: Color, tam: Vector2) -> void:
	etiqueta = p_etiqueta
	color = p_color
	custom_minimum_size = tam
	size = tam
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func fijar(v: float, m: float) -> void:
	valor = v
	maximo = maxf(m, 0.001)


func _process(delta: float) -> void:
	var frac := clampf(valor / maximo, 0.0, 1.0)
	var antes := _mostrado
	_mostrado = move_toward(_mostrado, frac, delta * 3.0)
	if _retraso < frac:
		_retraso = frac
	else:
		_retraso = move_toward(_retraso, frac, delta * 0.6)
	if antes != _mostrado or absf(_retraso - frac) > 0.001:
		queue_redraw()
	elif Engine.get_process_frames() % 10 == 0:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(Vector2(2, 2), Vector2((size.x - 4) * _retraso, size.y - 4)), Color(1, 1, 1, 0.35))
	draw_rect(Rect2(Vector2(2, 2), Vector2((size.x - 4) * _mostrado, size.y - 4)), color)
	draw_rect(Rect2(Vector2(2, 2), Vector2((size.x - 4) * _mostrado, (size.y - 4) * 0.35)), Color(1, 1, 1, 0.18))
	draw_rect(r, Color(1, 1, 1, 0.6), false, 2.0)
	var f := get_theme_default_font()
	var fs := int(size.y * 0.72)
	var txt := "%s  %d / %d" % [etiqueta, int(ceil(valor)), int(round(maximo))]
	draw_string_outline(f, Vector2(10, size.y * 0.5 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.9))
	draw_string(f, Vector2(10, size.y * 0.5 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
