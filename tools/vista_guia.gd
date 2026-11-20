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
	if _f == 20:
		_juego.mostrar_historia()
	if _f == 75:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/guia_prologo.png")
		for h in _juego.hud.get_children():
			if h is PantallaHistoria:
				h.queue_free()
	if _f == 110:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/guia_minimapa.png")
		_juego.hud.abrir_mapa()
	if _f == 130:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/guia_mapa.png")
	return _f > 132
