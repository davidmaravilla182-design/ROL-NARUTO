class_name Estilo
extends RefCounted
## Identidad visual de la interfaz: tipografías (Shojumaru para títulos, Rajdhani
## para la interfaz), colores y marcos de "metal de la aldea de la lluvia" dibujados por código.

const ACERO := Color(0.13, 0.15, 0.19)
const ACERO_CLARO := Color(0.32, 0.36, 0.43)
const ACERO_BORDE := Color(0.55, 0.6, 0.68)
const ACENTO := Color(0.78, 0.12, 0.16)
const PAPEL := Color(0.93, 0.89, 0.8)
const TEXTO := Color(0.94, 0.95, 0.97)

static var _titulo: Font
static var _ui: Font
static var _tema: Theme


static func fuente_titulo() -> Font:
	if _titulo == null:
		_titulo = _cargar("res://assets/fuentes/Shojumaru-Regular.ttf")
	return _titulo


static func fuente_ui() -> Font:
	if _ui == null:
		_ui = _cargar("res://assets/fuentes/Rajdhani-Bold.ttf")
	return _ui


static func _cargar(ruta: String) -> Font:
	if ResourceLoader.exists(ruta):
		var f = load(ruta)
		if f is Font:
			return f
	return ThemeDB.fallback_font


static func _caja(fondo: Color, borde: Color, ancho_borde := 2, radio := 4, sesgo := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(ancho_borde)
	s.border_width_bottom = ancho_borde + 2
	s.set_corner_radius_all(radio)
	s.set_content_margin_all(12)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.skew = Vector2(sesgo, 0)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 3)
	s.anti_aliasing = true
	return s


static func tema() -> Theme:
	if _tema != null:
		return _tema
	var t := Theme.new()
	t.default_font = fuente_ui()
	t.default_font_size = 26
	t.set_stylebox("normal", "Button", _caja(Color(0.14, 0.16, 0.2, 0.92), ACERO_BORDE, 2, 3, 0.18))
	t.set_stylebox("hover", "Button", _caja(Color(0.2, 0.23, 0.28, 0.95), Color(0.75, 0.8, 0.86), 2, 3, 0.18))
	t.set_stylebox("pressed", "Button", _caja(Color(0.45, 0.07, 0.1, 0.95), Color(1.0, 0.45, 0.4), 2, 3, 0.18))
	t.set_stylebox("disabled", "Button", _caja(Color(0.1, 0.1, 0.12, 0.7), Color(0.3, 0.3, 0.33), 2, 3, 0.18))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var presionado := _caja(Color(0.55, 0.08, 0.12, 0.95), Color(1.0, 0.55, 0.5), 2, 3, 0.18)
	t.set_stylebox("hover_pressed", "Button", presionado)
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Button", 4)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "Label", 6)
	t.set_color("font_color", "Label", TEXTO)
	# Deslizadores de metal con ranura roja.
	var ranura := StyleBoxFlat.new()
	ranura.bg_color = Color(0.05, 0.06, 0.08)
	ranura.set_corner_radius_all(4)
	ranura.content_margin_top = 6
	ranura.content_margin_bottom = 6
	var lleno := ranura.duplicate()
	lleno.bg_color = ACENTO
	t.set_stylebox("slider", "HSlider", ranura)
	t.set_stylebox("grabber_area", "HSlider", lleno)
	t.set_stylebox("grabber_area_highlight", "HSlider", lleno)
	t.set_icon("grabber", "HSlider", _agarre(false))
	t.set_icon("grabber_highlight", "HSlider", _agarre(true))
	_tema = t
	return t


static func _agarre(resaltado: bool) -> Texture2D:
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 40:
		for x in 40:
			var d := Vector2(x - 19.5, y - 19.5).length()
			if d < 18.0:
				var c := ACERO_BORDE.lerp(Color.WHITE, 0.3 if resaltado else 0.0)
				if d > 14.0:
					c = Color(0.1, 0.1, 0.12)
				elif d < 5.0:
					c = ACENTO
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Marco de metal remachado con filo rojo y el símbolo de la aldea (líneas verticales).
static func dibujar_marco(ci: CanvasItem, r: Rect2, opacidad := 0.92, con_simbolo := true) -> void:
	var biselado := 10.0
	var pts := PackedVector2Array([
		r.position + Vector2(biselado, 0), r.position + Vector2(r.size.x, 0),
		r.position + Vector2(r.size.x, r.size.y - biselado), r.position + Vector2(r.size.x - biselado, r.size.y),
		r.position + Vector2(0, r.size.y), r.position + Vector2(0, biselado),
	])
	ci.draw_colored_polygon(pts, Color(ACERO.r, ACERO.g, ACERO.b, opacidad))
	# Brillo superior (metal)
	var alto_brillo := minf(r.size.y * 0.35, 18.0)
	ci.draw_rect(Rect2(r.position + Vector2(biselado, 2), Vector2(r.size.x - biselado - 2, alto_brillo)), Color(1, 1, 1, 0.05))
	var cerrado := pts.duplicate()
	cerrado.append(pts[0])
	ci.draw_polyline(cerrado, Color(ACERO_BORDE.r, ACERO_BORDE.g, ACERO_BORDE.b, 0.85), 2.0, true)
	# Filo rojo inferior
	ci.draw_line(r.position + Vector2(4, r.size.y - 3), r.position + Vector2(r.size.x - biselado - 2, r.size.y - 3), ACENTO, 3.0)
	# Remaches
	for p in [r.position + Vector2(biselado + 6, 7), r.position + Vector2(r.size.x - 8, 7), r.position + Vector2(7, r.size.y - 9)]:
		ci.draw_circle(p, 3.0, Color(0.6, 0.64, 0.7))
		ci.draw_circle(p + Vector2(-0.8, -0.8), 1.4, Color(0.9, 0.92, 0.95))
	if con_simbolo:
		var base := r.position + Vector2(r.size.x - 34, r.size.y - 16)
		for i in 4:
			ci.draw_line(base + Vector2(i * 6, -12), base + Vector2(i * 6, 0), Color(0.75, 0.8, 0.88, 0.5), 2.0)


## Panel tipo pergamino (para títulos y avisos grandes).
static func dibujar_pergamino(ci: CanvasItem, r: Rect2, opacidad := 0.95) -> void:
	ci.draw_rect(r, Color(PAPEL.r, PAPEL.g, PAPEL.b, opacidad))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), Color(0.55, 0.42, 0.28, opacidad))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 6), Vector2(r.size.x, 6)), Color(0.55, 0.42, 0.28, opacidad))
	for lado in [r.position.x - 10, r.position.x + r.size.x]:
		ci.draw_rect(Rect2(Vector2(lado, r.position.y - 6), Vector2(10, r.size.y + 12)), Color(0.3, 0.2, 0.14, opacidad))


## Texto con contorno usando la fuente de títulos.
static func texto(ci: CanvasItem, pos: Vector2, t: String, tam: int, color := TEXTO, ancho := -1.0, alin := HORIZONTAL_ALIGNMENT_LEFT, fuente: Font = null, contorno := 6) -> void:
	var f := fuente if fuente != null else fuente_ui()
	if contorno > 0:
		ci.draw_string_outline(f, pos, t, alin, ancho, tam, contorno, Color(0, 0, 0, 0.9 * color.a))
	ci.draw_string(f, pos, t, alin, ancho, tam, color)
