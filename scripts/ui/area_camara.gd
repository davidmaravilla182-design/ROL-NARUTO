class_name AreaCamara
extends Control
## Zona de la mitad derecha: arrastrar el dedo gira la cámara.

signal arrastre(relativo: Vector2)

var _indice := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var t: InputEventScreenTouch = ev
		if t.pressed and _indice < 0:
			_indice = t.index
		elif not t.pressed and t.index == _indice:
			_indice = -1
		accept_event()
	elif ev is InputEventScreenDrag:
		var d: InputEventScreenDrag = ev
		if d.index == _indice:
			arrastre.emit(d.relative)
			accept_event()
