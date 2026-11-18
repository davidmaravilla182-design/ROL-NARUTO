class_name VistaPrevia
extends Control
## Vista previa animada de un jutsu en un nivel, dibujada por código.
## Cada nivel es más grande, con más partículas; N3 añade destello, rayos radiales y sacudida.

var id := ""
var nivel := 1
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func configurar(p_id: String, p_nivel: int) -> void:
	id = p_id
	nivel = p_nivel
	_rng.seed = hash(p_id) + p_nivel
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var j := Datos.jutsu(id)
	var cat := str(j.get("categoria", ""))
	var col := Datos.color(str(Repertorio.categorias().get(cat, {}).get("color", "#888888")))
	draw_rect(r, Color(0.05, 0.06, 0.09, 0.95))
	var c := r.get_center()
	var esc: float = [0.55, 0.8, 1.05][nivel - 1]
	var ciclo := fmod(_t, 2.0) / 2.0
	var sacudida := Vector2.ZERO
	if nivel == 3:
		sacudida = Vector2(sin(_t * 60.0), cos(_t * 47.0)) * 2.5 * (1.0 - ciclo)
		draw_rect(r, Color(col.r, col.g, col.b, 0.18 * (1.0 - ciclo)))
	var meca := str(j.get("mecanica", ""))
	var icono := str(j.get("icono", ""))
	var pos := c + sacudida
	match meca if meca != "" else icono:
		"proyectil":
			pos = Vector2(lerpf(r.position.x + 20, r.end.x - 20, ciclo), c.y) + sacudida
			for k in 4 + nivel * 4:
				var u := float(k) / (4 + nivel * 4)
				draw_circle(pos - Vector2(u * 60.0 * esc, sin(_t * 9.0 + k) * 6.0), (1.0 - u) * 9.0 * esc, Color(col.r, col.g, col.b, 0.5 * (1.0 - u)))
		"embiste":
			var x := lerpf(r.position.x + 20, r.end.x - 20, clampf(ciclo * 1.6 - 0.3, 0.0, 1.0))
			pos = Vector2(x, c.y) + sacudida
			draw_line(Vector2(r.position.x + 10, c.y), pos, Color(col.r, col.g, col.b, 0.5), 3.0 * esc)
		"kirin":
			for k in [1, 1, 5][nivel - 1]:
				var x2: float = c.x + (k - 2) * 18.0 if nivel == 3 else c.x
				var pts := PackedVector2Array()
				for i in 7:
					pts.append(Vector2(x2 + _rng.randf_range(-8, 8) * (1.0 if i > 0 else 0.0), r.position.y + (r.size.y - 10) * i / 6.0))
				if fmod(_t * 3.0 + k * 0.3, 1.0) < 0.5:
					draw_polyline(pts, Color(0.85, 0.95, 1.0), 2.0 + nivel, true)
		"shinra", "ondas":
			for k in nivel + 1:
				var u2: float = fmod(ciclo + k / float(nivel + 1), 1.0)
				draw_arc(c, u2 * r.size.y * 0.5 * esc * 1.6, 0, TAU, 32, Color(col.r, col.g, col.b, 1.0 - u2), 2.0 + nivel, true)
		"susanoo":
			var h := r.size.y * 0.25 * esc * 1.6
			draw_arc(c + Vector2(0, h * 0.2), h, PI, TAU, 24, Color(0.6, 0.4, 1.0, 0.6), 3.0, true)
			if nivel >= 2:
				draw_circle(c - Vector2(0, h * 0.9), h * 0.3, Color(0.6, 0.4, 1.0, 0.45))
			if nivel >= 3:
				draw_line(c + Vector2(h, -h), c + Vector2(h * 1.3, h * 0.6), Color(0.85, 0.7, 1.0), 4.0)
	# Partículas alrededor según el nivel.
	var n: int = [6, 14, 28][nivel - 1]
	for k in n:
		var a: float = _t * (1.0 + nivel * 0.4) + TAU * k / n
		var rr := (22.0 + 10.0 * sin(_t * 3.0 + k)) * esc
		draw_circle(pos + Vector2(cos(a), sin(a)) * rr, 1.5 + nivel * 0.6, Color(col.r, col.g, col.b, 0.8))
	if nivel == 3:
		for k in 8:
			var a2: float = TAU * k / 8.0 + _t * 0.5
			draw_line(pos + Vector2(cos(a2), sin(a2)) * 26.0 * esc, pos + Vector2(cos(a2), sin(a2)) * 48.0 * esc, Color(1, 1, 1, 0.5 * (1.0 - ciclo)), 2.0)
	Iconos.dibujar_icono(self, icono, pos, 22.0 * esc * (1.0 + 0.06 * sin(_t * 8.0)), true, int(j.get("patron", 1)), id)
	draw_rect(r, Color(col.r, col.g, col.b, 0.8), false, 2.0)
	Estilo.texto(self, r.position + Vector2(6, 20), "N%d" % nivel, 18, Color.WHITE)
