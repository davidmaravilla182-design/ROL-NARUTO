extends SceneTree
## Capturas del menú del repertorio (tarjetas, filtro, detalle). Uso:
## godot --path . --resolution 1280x720 -s res://tools/captura_menu.gd -- <carpeta>
var f := 0
var m
var dir := "user://"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		dir = a[0]
	m = load("res://escenas/repertorio.tscn").instantiate()
	root.add_child(m)


func _foto(n: String) -> void:
	root.get_texture().get_image().save_png(dir.path_join(n + ".png"))


func _process(_d: float) -> bool:
	f += 1
	match f:
		20: _foto("rep_todas")
		22:
			Perfil.modo_prueba = true
			m._categoria = "ojos"
			m._refrescar()
		40: _foto("rep_ojos_prueba")
		42:
			Perfil.modo_prueba = false
			m._categoria = ""
			m._solo_disponibles = true
			m._refrescar()
		60: _foto("rep_disponibles")
		62: m.abrir_detalle("kirin")
		90: _foto("rep_detalle_kirin")
		92:
			m._detalle.queue_free()
			m.abrir_detalle("amaterasu")
		120: _foto("rep_detalle_amaterasu")
		122: quit(0)
	return false
