class_name MapaCompleto
extends Control
## Mapa completo de la aldea (desde el botón «Mapa»): plano con los nombres de los distritos,
## jugadores, misiones y aldeanos, y a la derecha el «Viaje rápido» (solo para pruebas).

signal viajar(id: String)
signal cerrar

var mapa: Mapa
var tex: ImageTexture
var yo := Vector2.ZERO
var otros: Array = []
var _lienzo: Control


func configurar(m: Mapa) -> void:
	mapa = m
	tex = Plano.textura(m)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.03, 0.05, 0.97)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	_lienzo = Control.new()
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.draw.connect(_dibujar)
	add_child(_lienzo)
	var col := VBoxContainer.new()
	col.name = "Viaje"
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var t := Label.new()
	t.text = Datos.texto("viaje_titulo")
	t.add_theme_font_size_override("font_size", 22)
	col.add_child(t)
	# Solo a los distritos que ya pisaste (hay que descubrirlos caminando).
	for d in m.distritos:
		var b := Button.new()
		var id: String = d["id"]
		var conocido := Perfil.distrito_visitado(id)
		b.text = str(d["nombre"]) if conocido else Datos.texto("viaje_sin_descubrir")
		b.disabled = not conocido
		b.add_theme_font_size_override("font_size", 19)
		b.custom_minimum_size = Vector2(300, 46)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): viajar.emit(id))
		col.add_child(b)
	var cerrar_b := Button.new()
	cerrar_b.text = "Cerrar mapa"
	cerrar_b.add_theme_font_size_override("font_size", 21)
	cerrar_b.custom_minimum_size = Vector2(300, 54)
	cerrar_b.focus_mode = Control.FOCUS_NONE
	cerrar_b.pressed.connect(func(): cerrar.emit())
	col.add_child(cerrar_b)
	resized.connect(_ordenar)
	_ordenar()


func _ordenar() -> void:
	var t := size if size.x > 0 else get_viewport_rect().size
	var lado := minf(t.y - 40.0, t.x - 360.0)
	_lienzo.position = Vector2(20, (t.y - lado) * 0.5)
	_lienzo.size = Vector2(lado, lado)
	var col: Control = get_node("Viaje")
	col.position = Vector2(lado + 44, 84)
	col.size = Vector2(t.x - lado - 64, t.y - 60)


func actualizar(p: Vector2, lista: Array) -> void:
	yo = p
	otros = lista
	_lienzo.queue_redraw()


func _a_lienzo(p: Vector2) -> Vector2:
	return Plano.a_uv(p) * _lienzo.size.x


func _dibujar() -> void:
	if tex == null:
		return
	var lado := _lienzo.size.x
	_lienzo.draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(lado, lado)), false)
	var fuente := ThemeDB.fallback_font
	for d in mapa.distritos:
		var r: Rect2 = d["rect"]
		var a := _a_lienzo(r.position)
		var b := _a_lienzo(r.end)
		_lienzo.draw_rect(Rect2(a, b - a), Color(1.0, 0.85, 0.45, 0.35), false, 1.5)
		var c := _a_lienzo(d["centro"])
		_lienzo.draw_string_outline(fuente, c - Vector2(90, 0), str(d["corto"]), HORIZONTAL_ALIGNMENT_CENTER, 180, 17, 5, Color(0, 0, 0, 0.95))
		_lienzo.draw_string(fuente, c - Vector2(90, 0), str(d["corto"]), HORIZONTAL_ALIGNMENT_CENTER, 180, 17, Color(1.0, 0.92, 0.7))
	for pt in mapa.puntos:
		if pt["tipo"] == "mision":
			if str(pt["distrito"]) == Puntos.distrito_guia and Puntos.distrito_guia != "":
				var pg := _a_lienzo(pt["centro"])
				_lienzo.draw_circle(pg, 10.0, Color(0.15, 0.08, 0.0, 0.85))
				_lienzo.draw_circle(pg, 8.0, Color(1.0, 0.8, 0.25))
				_lienzo.draw_string_outline(fuente, pg + Vector2(-80, -14), Datos.texto("guia_mapa"), HORIZONTAL_ALIGNMENT_CENTER, 160, 15, 5, Color(0, 0, 0, 0.95))
				_lienzo.draw_string(fuente, pg + Vector2(-80, -14), Datos.texto("guia_mapa"), HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(1.0, 0.85, 0.4))
			continue
		_lienzo.draw_circle(_a_lienzo(pt["centro"]), 4.0, Color(0.75, 0.55, 1.0))
	for o in otros:
		_lienzo.draw_circle(_a_lienzo(o["pos"]), 5.0, o["color"])
	_lienzo.draw_circle(_a_lienzo(yo), 7.0, Color(1, 1, 1))
	_lienzo.draw_circle(_a_lienzo(yo), 4.0, Color(0.2, 0.6, 1.0))
