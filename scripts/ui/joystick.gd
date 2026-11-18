class_name JoystickVirtual
extends Control
## Joystick virtual flotante: aparece donde se toca dentro de su zona (mitad izquierda).

var vector := Vector2.ZERO
var radio_base := 95.0
var radio_pomo := 42.0
var _indice := -1
var _centro := Vector2.ZERO
var _pomo := Vector2.ZERO
var _reposo := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func colocar_reposo(p: Vector2) -> void:
	_reposo = p
	if _indice < 0:
		_centro = p
		_pomo = p
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var t: InputEventScreenTouch = ev
		if t.pressed and _indice < 0:
			_indice = t.index
			_centro = t.position
			_pomo = t.position
			vector = Vector2.ZERO
			accept_event()
		elif not t.pressed and t.index == _indice:
			_soltar()
			accept_event()
		queue_redraw()
	elif ev is InputEventScreenDrag:
		var d: InputEventScreenDrag = ev
		if d.index == _indice:
			var off := d.position - _centro
			if off.length() > radio_base:
				off = off.normalized() * radio_base
			_pomo = _centro + off
			vector = off / radio_base
			if vector.length() < 0.12:
				vector = Vector2.ZERO
			accept_event()
			queue_redraw()


func _soltar() -> void:
	_indice = -1
	vector = Vector2.ZERO
	_centro = _reposo
	_pomo = _reposo


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_soltar()
		queue_redraw()


func _draw() -> void:
	var activo := _indice >= 0
	draw_circle(_centro, radio_base, Color(1, 1, 1, 0.10 if not activo else 0.16))
	draw_arc(_centro, radio_base, 0, TAU, 40, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(_pomo, radio_pomo, Color(1, 1, 1, 0.35 if not activo else 0.6))
	draw_arc(_pomo, radio_pomo, 0, TAU, 28, Color(1, 1, 1, 0.7), 2.0, true)
