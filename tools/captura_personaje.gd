extends SceneTree
## Capturas de la creación de personaje (cada paso) y de la lista. Uso:
## godot --path . --resolution 1280x720 -s res://tools/captura_personaje.gd -- <carpeta>
var f := 0
var m
var dir := "user://"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		dir = a[0]
	m = load("res://escenas/personaje.tscn").instantiate()
	root.add_child(m)


func _foto(n: String) -> void:
	root.get_texture().get_image().save_png(dir.path_join(n + ".png"))


func _process(_d: float) -> bool:
	f += 1
	if f == 10 and m.modo != "crear":
		m._empezar_creacion()
	match f:
		20:
			m.pj["nombre"] = "Kaito"
			m._mostrar_paso()
		30: _foto("pj_1_nombre")
		32:
			m.paso = 1
			m.pj["aspecto"]["peinado"] = "largo"
			m.pj["aspecto"]["pelo"] = "#b23a2a"
			m.pj["aspecto"]["ropa"] = "impermeable"
			m._mostrar_paso()
			m._actualizar_vista()
		50: _foto("pj_2_apariencia")
		52:
			m.paso = 2
			m._mostrar_paso()
		60: _foto("pj_3_aldea")
		62:
			m.paso = 3
			m.pj["clan"] = "uchiha"
			m._mostrar_paso()
		70: _foto("pj_4_clan")
		72:
			m.paso = 4
			m._mostrar_paso()
		80: _foto("pj_5_naturaleza")
		82:
			m.paso = 5
			m._mostrar_paso()
		95: _foto("pj_6_atributos")
		97:
			m.pj["aspecto"]["peinado"] = "coleta"
			m.pj["aspecto"]["complexion"] = "fornida"
			m.pj["aspecto"]["ropa"] = "sigilo"
			m._actualizar_vista()
		110: _foto("pj_7_otra_apariencia")
		112: m._terminar()
		125: _foto("pj_8_lista")
		127: quit(0)
	return false
