extends Control
## Pantalla de inicio: título, aviso legal de proyecto de fans y botón para entrenar.

const ESCENA_JUEGO := "res://escenas/juego.tscn"

var _gotas: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Datos.cargar()
	Ajustes.cargar()
	Engine.time_scale = 1.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Estilo.tema()
	_rng.randomize()
	for i in 110:
		_gotas.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.6, 1.4)))

	var juego: Dictionary = Datos.mundo["juego"]
	var aldea := Datos.aldea("lluvia")

	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 18)
	add_child(caja)

	var titulo := _label(str(juego["titulo"]), 84, Color(0.97, 0.95, 0.9))
	titulo.add_theme_font_override("font", Estilo.fuente_titulo())
	titulo.add_theme_color_override("font_outline_color", Color(0.45, 0.03, 0.06))
	titulo.add_theme_constant_override("outline_size", 18)
	caja.add_child(titulo)
	caja.add_child(_label(str(juego["subtitulo"]), 30, Color(0.8, 0.85, 0.95)))
	caja.add_child(_label(Datos.texto("menu_ubicacion", [aldea.get("nombre_largo", ""), aldea.get("sector", "")]), 26, Color(0.6, 0.75, 0.9)))

	var espacio := Control.new()
	espacio.custom_minimum_size = Vector2(0, 20)
	caja.add_child(espacio)

	var boton := Button.new()
	boton.name = "BotonEntrenar"
	boton.text = Datos.texto("menu_entrenar")
	boton.add_theme_font_size_override("font_size", 38)
	boton.custom_minimum_size = Vector2(460, 96)
	boton.focus_mode = Control.FOCUS_NONE
	boton.add_theme_font_override("font", Estilo.fuente_titulo())
	boton.pressed.connect(_entrenar)
	var ajustes := Button.new()
	ajustes.name = "BotonAjustes"
	ajustes.text = Datos.texto("menu_ajustes")
	ajustes.add_theme_font_size_override("font_size", 30)
	ajustes.custom_minimum_size = Vector2(260, 96)
	ajustes.focus_mode = Control.FOCUS_NONE
	ajustes.pressed.connect(func():
		var m := MenuAjustes.new()
		add_child(m)
		m.construir())
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 24)
	fila.add_child(boton)
	fila.add_child(ajustes)
	var centro := CenterContainer.new()
	centro.add_child(fila)
	caja.add_child(centro)

	var espacio2 := Control.new()
	espacio2.custom_minimum_size = Vector2(0, 26)
	caja.add_child(espacio2)

	var aviso := _label(Datos.texto("menu_aviso"), 24, Color(0.25, 0.16, 0.1))
	aviso.add_theme_constant_override("outline_size", 0)
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.custom_minimum_size = Vector2(880, 0)
	# Aviso legal sobre un pergamino.
	var pergamino := PanelContainer.new()
	var estilo_p := StyleBoxFlat.new()
	estilo_p.bg_color = Color(Estilo.PAPEL.r, Estilo.PAPEL.g, Estilo.PAPEL.b, 0.93)
	estilo_p.border_color = Color(0.3, 0.2, 0.14)
	estilo_p.border_width_left = 12
	estilo_p.border_width_right = 12
	estilo_p.border_width_top = 5
	estilo_p.border_width_bottom = 5
	estilo_p.set_content_margin_all(14)
	pergamino.add_theme_stylebox_override("panel", estilo_p)
	pergamino.add_child(aviso)
	var centro2 := CenterContainer.new()
	centro2.add_child(pergamino)
	caja.add_child(centro2)
	caja.add_child(_label(Datos.texto("menu_pie", [juego["version"]]), 20, Color(0.65, 0.7, 0.78)))


func _label(t: String, tam: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _entrenar() -> void:
	get_tree().change_scene_to_file(ESCENA_JUEGO)


func _process(delta: float) -> void:
	for i in _gotas.size():
		var g: Vector3 = _gotas[i]
		g.y += delta * 0.9 * g.z
		g.x += delta * 0.05 * g.z
		if g.y > 1.05:
			g.y = -0.05
			g.x = _rng.randf()
		_gotas[i] = g
	queue_redraw()


func _draw() -> void:
	var t := get_viewport_rect().size
	# Cielo gris con degradado y siluetas de torres.
	var pasos := 12
	for i in pasos:
		var c := Color(0.2, 0.23, 0.27).lerp(Color(0.42, 0.46, 0.52), float(i) / pasos)
		draw_rect(Rect2(0, t.y * i / pasos, t.x, t.y / pasos + 1), c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := 0.0
	while x < t.x:
		var w := rng.randf_range(50, 120)
		var h := rng.randf_range(t.y * 0.25, t.y * 0.75)
		draw_rect(Rect2(x, t.y - h, w, h), Color(0.12, 0.13, 0.16, 0.9))
		var vy := t.y - h + 20
		while vy < t.y - 10:
			if rng.randf() < 0.3:
				draw_rect(Rect2(x + rng.randf_range(6, w - 16), vy, 8, 12), Color(1.0, 0.8, 0.45, 0.6))
			vy += 26
		x += w + rng.randf_range(4, 30)
	draw_rect(Rect2(0, 0, t.x, t.y), Color(0, 0, 0, 0.35))
	for g in _gotas:
		var p := Vector2(g.x * t.x, g.y * t.y)
		draw_line(p, p + Vector2(4, 26) * g.z, Color(0.75, 0.82, 0.95, 0.35), 2.0)
