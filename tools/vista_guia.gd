extends SceneTree
## Capturas de la guía de la historia: prólogo, minimapa con «Siguiente» y mapa completo con un solo punto.
var _juego: Node
var _f := 0
var _ph: Node


func _initialize() -> void:
	Sesion.modo = "offline"
	_juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate()
	root.add_child(_juego)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_juego.mostrar_historia()   # como en el celular: casi al empezar, antes de que el HUD termine
	if _f == 40:
		# Un toque en medio de la pantalla debe avanzar el prólogo.
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = Vector2(640, 500)
		root.push_input(ev)
		var ev2 := ev.duplicate()
		ev2.pressed = false
		root.push_input(ev2)
	if _f == 75:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/guia_prologo.png")
		for c in _juego.get_children():
			if c is CanvasLayer:
				for h in c.get_children():
					if h is PantallaHistoria:
						print("GUIA: prólogo en la línea ", h._i, " letras ", int(h._letras))
						h.queue_free()
	if _f == 110:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/guia_minimapa.png")
		_juego.hud.abrir_mapa()
	if _f == 130:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/guia_mapa.png")
	return _f > 132
