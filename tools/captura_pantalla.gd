extends SceneTree
## Captura una escena de interfaz (para revisar pantallas nuevas). Uso:
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 -s res://tools/captura_pantalla.gd -- <escena.tscn> <salida.png> [segundos]
var t := 0.0
var salida := ""
var espera := 1.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	salida = a[1]
	if a.size() > 2:
		espera = float(a[2])
	root.add_child((load(a[0]) as PackedScene).instantiate())


func _process(d: float) -> bool:
	t += d
	if t >= espera:
		root.get_viewport().get_texture().get_image().save_png(salida)
		print("PANTALLA ", salida)
		quit(0)
	return false
