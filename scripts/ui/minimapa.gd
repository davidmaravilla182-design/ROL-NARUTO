class_name Minimapa
extends Control
## Minimapa de la esquina: plano alrededor del jugador (norte arriba), otros jugadores, enemigo,
## misiones (ámbar) y aldeanos (lila), con el nombre del distrito debajo.

var mapa: Mapa
var tex: ImageTexture
var yo := Vector2.ZERO
var yaw := 0.0
var otros: Array = []        # [{pos: Vector2, color: Color}]
var radio_m := 60.0          # metros visibles desde el centro hasta el borde
var _nombre := ""
var guia := ""               # «Siguiente: … (123 m)» bajo el nombre del distrito


func configurar(m: Mapa) -> void:
	mapa = m
	tex = Plano.textura(m)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(170, 196)
	size = custom_minimum_size


func actualizar(p: Vector2, y: float, lista: Array) -> void:
	yo = p
	yaw = y
	otros = lista
	var id := mapa.distrito_en(p)
	var d := mapa.distrito(id)
	_nombre = str(d.get("nombre", "Afueras")) if id != "" else "Afueras"
	queue_redraw()


func _draw() -> void:
	if tex == null:
		return
	var lado := 170.0
	var marco := Rect2(Vector2.ZERO, Vector2(lado, lado))
	draw_rect(marco, Color(0.04, 0.05, 0.08, 0.8))
	var uv := Plano.a_uv(yo)
	var r_uv := radio_m / Plano.metros
	var region := Rect2((uv - Vector2(r_uv, r_uv)) * Plano.TAM, Vector2(r_uv, r_uv) * 2.0 * Plano.TAM)
	draw_texture_rect_region(tex, marco, region, Color(1, 1, 1, 0.92))
	var esc := lado / (radio_m * 2.0)
	var centro := Vector2(lado, lado) * 0.5
	var t_ms := Time.get_ticks_msec()
	for pt in mapa.puntos:
		var d: Vector2 = ((pt["centro"] as Vector2) - yo) * esc
		if pt["tipo"] == "mision":
			# Solo el punto de la misión que toca; si queda fuera, se pega al borde señalando hacia dónde ir.
			if str(pt["distrito"]) != Puntos.distrito_guia or Puntos.distrito_guia == "":
				continue
			var dentro := absf(d.x) < lado * 0.5 - 6 and absf(d.y) < lado * 0.5 - 6
			var pos_g := centro + (d if dentro else d.limit_length(lado * 0.5 - 8))
			var pulso := 6.0 + sin(t_ms / 200.0) * 1.5
			draw_circle(pos_g, pulso + 2.0, Color(0.15, 0.08, 0.0, 0.8))
			draw_circle(pos_g, pulso, Color(1.0, 0.8, 0.25))
			continue
		if absf(d.x) < lado * 0.5 - 4 and absf(d.y) < lado * 0.5 - 4:
			draw_circle(centro + d, 4.0, Color(0.75, 0.55, 1.0))
	for o in otros:
		var d2: Vector2 = ((o["pos"] as Vector2) - yo) * esc
		d2 = d2.limit_length(lado * 0.5 - 5)
		draw_circle(centro + d2, 5.0, o["color"])
	# Flecha del jugador (yaw 0 mira a +Z, que en el plano es hacia abajo).
	var f := Vector2(sin(yaw), cos(yaw))
	var lat := Vector2(f.y, -f.x)
	draw_colored_polygon(PackedVector2Array([centro + f * 10.0, centro - f * 6.0 + lat * 6.0, centro - f * 3.0, centro - f * 6.0 - lat * 6.0]), Color(1, 1, 1))
	draw_rect(marco, Color(0.8, 0.82, 0.9, 0.7), false, 2.0)
	var fuente := ThemeDB.fallback_font
	draw_string_outline(fuente, Vector2(-20, lado + 20), _nombre, HORIZONTAL_ALIGNMENT_CENTER, lado + 40, 13, 5, Color(0, 0, 0, 0.9))
	draw_string(fuente, Vector2(-20, lado + 20), _nombre, HORIZONTAL_ALIGNMENT_CENTER, lado + 40, 13, Color(0.95, 0.9, 0.75))
	if guia != "":
		draw_string_outline(fuente, Vector2(-30, lado + 38), guia, HORIZONTAL_ALIGNMENT_CENTER, lado + 60, 13, 5, Color(0, 0, 0, 0.9))
		draw_string(fuente, Vector2(-30, lado + 38), guia, HORIZONTAL_ALIGNMENT_CENTER, lado + 60, 13, Color(1.0, 0.82, 0.35))
