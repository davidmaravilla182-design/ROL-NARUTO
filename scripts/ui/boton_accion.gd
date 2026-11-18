class_name BotonAccion
extends Control
## Botón táctil circular con texto, tiempo de recarga visible (sector oscuro y
## segundos) y estado desactivado/activo. Admite multitáctil.

signal pulsado(id: String)

var id := ""
var texto := ""
var color := Color(0.3, 0.3, 0.35)
var radio := 56.0
var recarga := 0.0
var recarga_total := 1.0
var deshabilitado := false
var activo := false
var fuente_tam := 22
var _pulsado_t := 0.0


func configurar(p_id: String, p_texto: String, p_color: Color, p_radio: float) -> void:
	id = p_id
	texto = p_texto
	color = p_color
	radio = p_radio
	custom_minimum_size = Vector2(radio * 2, radio * 2)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	fuente_tam = 24 if radio >= 60 else 21


func centrar_en(p: Vector2) -> void:
	position = p - Vector2(radio, radio)


func _has_point(p: Vector2) -> bool:
	return p.distance_to(Vector2(radio, radio)) <= radio * 1.08


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch and ev.pressed:
		_pulsado_t = 0.15
		pulsado.emit(id)
		accept_event()
		queue_redraw()
	elif ev is InputEventScreenTouch:
		accept_event()


func actualizar(p_recarga: float, p_total: float, p_deshabilitado: bool, p_activo: bool) -> void:
	if absf(p_recarga - recarga) > 0.01 or p_deshabilitado != deshabilitado or p_activo != activo:
		recarga = p_recarga
		recarga_total = maxf(p_total, 0.01)
		deshabilitado = p_deshabilitado
		activo = p_activo
		queue_redraw()


func _process(delta: float) -> void:
	if _pulsado_t > 0.0:
		_pulsado_t -= delta
		queue_redraw()


func _draw() -> void:
	var c := Vector2(radio, radio)
	var r := radio * (0.92 if _pulsado_t > 0.0 else 1.0)
	var base := color
	if deshabilitado:
		base = base.darkened(0.55)
	draw_circle(c, r, Color(base.r, base.g, base.b, 0.78))
	if activo:
		draw_arc(c, r + 4, 0, TAU, 40, Color(1.0, 0.2, 0.2, 0.95), 6.0, true)
	draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.75), 3.0, true)
	if recarga > 0.0:
		var frac := clampf(recarga / recarga_total, 0.0, 1.0)
		var puntos := PackedVector2Array([c])
		var pasos := 32
		for i in pasos + 1:
			var a := -PI * 0.5 + TAU * frac * float(i) / pasos
			puntos.append(c + Vector2(cos(a), sin(a)) * r)
		if puntos.size() >= 3:
			draw_colored_polygon(puntos, Color(0, 0, 0, 0.6))
	var fuente := get_theme_default_font()
	var lineas := texto.split("\n")
	var alto_linea := fuente_tam + 2
	var y0 := c.y - (lineas.size() - 1) * alto_linea * 0.5 + fuente_tam * 0.35
	if recarga > 0.0:
		var t := "%.1f" % recarga
		draw_string_outline(fuente, Vector2(0, c.y + 14), t, HORIZONTAL_ALIGNMENT_CENTER, radio * 2, 40, 6, Color(0, 0, 0, 0.9))
		draw_string(fuente, Vector2(0, c.y + 14), t, HORIZONTAL_ALIGNMENT_CENTER, radio * 2, 40, Color.WHITE)
		return
	for i in lineas.size():
		var pos := Vector2(0, y0 + i * alto_linea)
		# Reduce la letra si la palabra no cabe en el círculo.
		var tam := fuente_tam
		while tam > 14 and fuente.get_string_size(lineas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > radio * 1.8:
			tam -= 1
		draw_string_outline(fuente, pos, lineas[i], HORIZONTAL_ALIGNMENT_CENTER, radio * 2, tam, 5, Color(0, 0, 0, 0.85))
		draw_string(fuente, pos, lineas[i], HORIZONTAL_ALIGNMENT_CENTER, radio * 2, tam, Color.WHITE if not deshabilitado else Color(1, 1, 1, 0.5))
