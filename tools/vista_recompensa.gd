extends SceneTree
## Captura de la pantalla de recompensas con el cofre y el pergamino 3D: docs/capturas/v09/recompensa_*.png
var _t := 0


func _initialize() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.25, 0.27, 0.33)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fondo)
	var p := PantallaRecompensa.new()
	root.add_child(p)
	p.mostrar("Prueba de recompensas", {"xp": 300, "ryo": 1200, "pergaminos": ["remolino_hoja"], "cosmeticos": []}, true)


func _process(_d: float) -> bool:
	_t += 1
	for f in [8, 20, 40, 75]:
		if _t == f:
			root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/recompensa_%d.png" % f)
	return _t > 76
