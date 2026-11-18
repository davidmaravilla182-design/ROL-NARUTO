class_name Iconos
extends RefCounted
## Iconos vectoriales dibujados por código: llama, rayo, ojo con tomoe, puño,
## esquiva, salto, fijar objetivo, ajustes y cancelar.


static func dibujar(ci: CanvasItem, id: String, c: Vector2, r: float, activo := false) -> void:
	match id:
		"golpe": puno(ci, c, r)
		"esquivar": esquiva(ci, c, r)
		"saltar": salto(ci, c, r)
		"fijar": mira(ci, c, r, activo)
		"ajustes": engranaje(ci, c, r)
		"cancelar": cancelar(ci, c, r)
		_:
			var j := Datos.jutsu(id)
			if j.is_empty():
				return
			dibujar_icono(ci, str(j.get("icono", "")), c, r, activo, int(j.get("patron", 1)), id)


## Dibuja un icono por tipo (los jutsus de /data indican el suyo en "icono").
static func dibujar_icono(ci: CanvasItem, icono: String, c: Vector2, r: float, activo := false, patron := 1, id := "") -> void:
	match icono:
		"llama": llama(ci, c, r)
		"llama_negra": llama(ci, c, r, true)
		"rayo": rayo(ci, c, r)
		"kirin": kirin(ci, c, r)
		"gota": gota(ci, c, r)
		"roca": roca(ci, c, r)
		"viento": remolino(ci, c, r)
		"espiral": espiral(ci, c, r)
		"ojo": ojo_patron(ci, c, r, activo, patron)
		"susanoo": susanoo(ci, c, r)
		"ondas": ondas(ci, c, r)
		"puerta": puerta(ci, c, r, activo)
		"puno": puno(ci, c, r)
		"clones": clones(ci, c, r)
		"pergamino", "papel": papel(ci, c, r)
		"kunai": kunai(ci, c, r)
		"cruz": cruz(ci, c, r)
		"hoja": hoja(ci, c, r)
		"cristal": cristal(ci, c, r)
		"ave": ave(ci, c, r)
		_:
			var f := Estilo.fuente_titulo()
			var nombre := str(Datos.jutsu(id).get("nombre", "?"))
			ci.draw_string_outline(f, c + Vector2(-r, r * 0.4), nombre.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r * 1.2), 5, Color.BLACK)
			ci.draw_string(f, c + Vector2(-r, r * 0.4), nombre.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r * 1.2), Color.WHITE)


## Rellena un polígono solo si es triangulable (a escalas muy pequeñas algunos contornos degeneran).
static func relleno(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		ci.draw_colored_polygon(pts, color)


static func _poligono(ci: CanvasItem, pts: PackedVector2Array, color: Color, borde := Color(0, 0, 0, 0.85), grosor := 3.0) -> void:
	Iconos.relleno(ci, pts, color)
	var cerrado := pts.duplicate()
	cerrado.append(pts[0])
	ci.draw_polyline(cerrado, borde, grosor, true)


## Llama de tres lenguas con interior amarillo (contorno fijo con leve vaivén).
const LLAMA := [Vector2(0.0, 0.95), Vector2(-0.45, 0.78), Vector2(-0.68, 0.38), Vector2(-0.62, -0.05), Vector2(-0.42, -0.35),
	Vector2(-0.48, -0.75), Vector2(-0.18, -0.42), Vector2(-0.08, -1.0), Vector2(0.18, -0.48), Vector2(0.42, -0.82),
	Vector2(0.45, -0.3), Vector2(0.66, 0.05), Vector2(0.66, 0.42), Vector2(0.44, 0.8)]


static func llama(ci: CanvasItem, c: Vector2, r: float, negra := false) -> void:
	var t := Time.get_ticks_msec() * 0.005
	for capa in 2:
		var esc := 1.0 if capa == 0 else 0.52
		var pts := PackedVector2Array()
		for i in LLAMA.size():
			var v: Vector2 = LLAMA[i]
			var vaiven := sin(t + i * 0.9) * 0.05 * maxf(-v.y, 0.0)
			pts.append(c + Vector2(v.x + vaiven, v.y) * r * esc + Vector2(0, r * 0.38 * (1.0 - esc)))
		var col := Color(1.0, 0.4, 0.06) if capa == 0 else Color(1.0, 0.9, 0.4)
		if negra:
			col = Color(0.05, 0.02, 0.08) if capa == 0 else Color(0.35, 0.1, 0.45)
		if capa == 0:
			_poligono(ci, pts, col, Color(0.3, 0.03, 0.0, 0.95), 3.0)
		else:
			Iconos.relleno(ci, pts, col)


## Rayo en zigzag.
static func rayo(ci: CanvasItem, c: Vector2, r: float) -> void:
	var p := [Vector2(0.15, -1.0), Vector2(-0.45, 0.1), Vector2(-0.02, 0.1), Vector2(-0.25, 1.0), Vector2(0.5, -0.25), Vector2(0.06, -0.25), Vector2(0.4, -1.0)]
	var pts := PackedVector2Array()
	for v in p:
		pts.append(c + v * r * 0.82)
	_poligono(ci, pts, Color(0.75, 0.92, 1.0), Color(0.05, 0.15, 0.35), 3.0)
	# chispas
	for i in 3:
		var a := TAU * i / 3.0 + Time.get_ticks_msec() * 0.003
		var q := c + Vector2(cos(a), sin(a)) * r * 0.75
		ci.draw_line(q, q + Vector2(cos(a), sin(a)) * r * 0.2, Color(0.8, 0.95, 1.0, 0.9), 2.0)


## Ojo rojo con anillo y tres tomoe (comas).
static func ojo_tomoe(ci: CanvasItem, c: Vector2, r: float, activo: bool) -> void:
	var giro := Time.get_ticks_msec() * (0.004 if activo else 0.0008)
	# Forma de ojo (almendra)
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r * 0.98, sin(a) * r * 0.58 * (1.0 - 0.25 * absf(cos(a)))))
	_poligono(ci, pts, Color(0.96, 0.95, 0.93), Color(0.08, 0.02, 0.02), 3.0)
	var ri := r * 0.5
	ci.draw_circle(c, ri, Color(0.85, 0.05, 0.08))
	ci.draw_arc(c, ri, 0, TAU, 32, Color(0.1, 0.0, 0.0), 2.5, true)
	ci.draw_arc(c, ri * 0.62, 0, TAU, 32, Color(0.15, 0.0, 0.0, 0.9), 1.5, true)
	for i in 3:
		var a2 := giro + TAU * i / 3.0
		var tp := c + Vector2(cos(a2), sin(a2)) * ri * 0.62
		ci.draw_circle(tp, ri * 0.17, Color(0.05, 0, 0))
		# cola de la coma
		var cola := PackedVector2Array()
		for k in 6:
			var u := float(k) / 5.0
			var ak := a2 + u * 0.9
			cola.append(c + Vector2(cos(ak), sin(ak)) * ri * (0.62 + 0.06 * (1.0 - u)))
		ci.draw_polyline(cola, Color(0.05, 0, 0), ri * 0.12 * 1.0, true)
	ci.draw_circle(c, ri * 0.16, Color(0.03, 0, 0))


## Puño cerrado de frente.
static func puno(ci: CanvasItem, c: Vector2, r: float) -> void:
	var piel := Color(0.98, 0.85, 0.7)
	var borde := Color(0.2, 0.1, 0.05)
	var cuerpo := Rect2(c + Vector2(-0.62, -0.35) * r, Vector2(1.18, 0.95) * r)
	ci.draw_rect(cuerpo, piel)
	# nudillos
	for i in 4:
		var x := -0.5 + i * 0.32
		ci.draw_circle(c + Vector2(x, -0.38) * r, r * 0.17, piel)
		ci.draw_arc(c + Vector2(x, -0.38) * r, r * 0.17, PI, TAU, 10, borde, 2.5, true)
	for i in 3:
		var x2 := -0.34 + i * 0.32
		ci.draw_line(c + Vector2(x2, -0.35) * r, c + Vector2(x2, 0.1) * r, borde, 2.5)
	# pulgar
	var pulgar := Rect2(c + Vector2(-0.62, 0.05) * r, Vector2(0.75, 0.3) * r)
	ci.draw_rect(pulgar, piel.darkened(0.08))
	ci.draw_rect(pulgar, borde, false, 2.5)
	ci.draw_rect(cuerpo, borde, false, 3.0)
	# vendas
	ci.draw_rect(Rect2(c + Vector2(-0.62, 0.6) * r, Vector2(1.18, 0.3) * r), Color(0.92, 0.9, 0.84))
	ci.draw_line(c + Vector2(-0.62, 0.75) * r, c + Vector2(0.56, 0.75) * r, Color(0.6, 0.58, 0.52), 2.0)
	# líneas de impacto
	for a in [-2.5, -2.0, -1.1]:
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(c + d * r * 0.95, c + d * r * 1.15, Color(1, 1, 1, 0.8), 3.0)


static func esquiva(ci: CanvasItem, c: Vector2, r: float) -> void:
	for k in 2:
		var off := Vector2(-0.25 + k * 0.45, 0) * r
		var pts := PackedVector2Array([c + off + Vector2(-0.25, -0.55) * r, c + off + Vector2(0.25, 0) * r, c + off + Vector2(-0.25, 0.55) * r])
		ci.draw_polyline(pts, Color(0.85, 1.0, 0.92, 0.6 + 0.4 * k), r * 0.16, true)
	for i in 3:
		var y := (-0.35 + i * 0.35) * r
		ci.draw_line(c + Vector2(-0.95 * r, y), c + Vector2(-0.6 * r, y), Color(1, 1, 1, 0.5), 2.0)


static func salto(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -0.75) * r, c + Vector2(0.55, -0.1) * r, c + Vector2(0.2, -0.1) * r,
		c + Vector2(0.2, 0.45) * r, c + Vector2(-0.2, 0.45) * r, c + Vector2(-0.2, -0.1) * r, c + Vector2(-0.55, -0.1) * r])
	_poligono(ci, pts, Color(0.9, 0.92, 1.0), Color(0.1, 0.1, 0.2), 3.0)
	ci.draw_arc(c + Vector2(0, 0.95) * r, r * 0.6, PI * 1.15, PI * 1.85, 12, Color(1, 1, 1, 0.6), 3.0, true)


static func mira(ci: CanvasItem, c: Vector2, r: float, activo: bool) -> void:
	var col := Color(1.0, 0.3, 0.25) if activo else Color(0.9, 0.92, 1.0)
	ci.draw_arc(c, r * 0.55, 0, TAU, 32, col, 3.5, true)
	ci.draw_circle(c, r * 0.1, col)
	for i in 4:
		var a := TAU * i / 4.0 + (Time.get_ticks_msec() * 0.002 if activo else 0.0)
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(c + d * r * 0.35, c + d * r * 0.85, col, 3.5)


static func engranaje(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	var dientes := 8
	for i in dientes * 4:
		var a := TAU * i / (dientes * 4.0)
		var fuera := (i % 4) < 2
		pts.append(c + Vector2(cos(a), sin(a)) * r * (0.85 if fuera else 0.65))
	_poligono(ci, pts, Color(0.75, 0.78, 0.84), Color(0.1, 0.1, 0.12), 2.0)
	ci.draw_circle(c, r * 0.28, Color(0.15, 0.16, 0.2))


static func cancelar(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_line(c + Vector2(-0.45, -0.45) * r, c + Vector2(0.45, 0.45) * r, Color.WHITE, r * 0.18)
	ci.draw_line(c + Vector2(0.45, -0.45) * r, c + Vector2(-0.45, 0.45) * r, Color.WHITE, r * 0.18)


static func kirin(ci: CanvasItem, c: Vector2, r: float) -> void:
	# Cabeza de bestia de rayo: rayo grueso que baja con ojos.
	rayo(ci, c + Vector2(0, r * 0.1), r * 0.95)
	for lado in [-1.0, 1.0]:
		ci.draw_line(c + Vector2(0.2 * lado, -0.7) * r, c + Vector2(0.55 * lado, -1.0) * r, Color(0.8, 0.95, 1.0), 3.0)
	ci.draw_arc(c, r * 0.95, PI * 1.1, PI * 1.9, 16, Color(0.6, 0.85, 1.0, 0.7), 2.0, true)


static func gota(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var rr := r * 0.62
		var p := Vector2(cos(a), sin(a)) * rr + Vector2(0, r * 0.2)
		if p.y < 0:
			p.x *= 1.0 + p.y / r * 1.1
		pts.append(c + p)
	pts.append(c + Vector2(0, -r * 0.95))
	_poligono(ci, pts, Color(0.4, 0.7, 1.0), Color(0.03, 0.12, 0.3), 3.0)
	ci.draw_arc(c + Vector2(-r * 0.15, r * 0.2), r * 0.32, PI * 0.9, PI * 1.4, 8, Color(1, 1, 1, 0.8), 3.0, true)


static func roca(ci: CanvasItem, c: Vector2, r: float) -> void:
	var p := [Vector2(-0.8, 0.6), Vector2(-0.6, -0.3), Vector2(-0.1, -0.75), Vector2(0.5, -0.5), Vector2(0.85, 0.2), Vector2(0.55, 0.7)]
	var pts := PackedVector2Array()
	for v in p:
		pts.append(c + v * r)
	_poligono(ci, pts, Color(0.62, 0.48, 0.3), Color(0.18, 0.1, 0.05), 3.0)
	ci.draw_line(c + Vector2(-0.1, -0.75) * r, c + Vector2(0.05, 0.2) * r, Color(0.3, 0.2, 0.1), 2.0)
	ci.draw_line(c + Vector2(0.05, 0.2) * r, c + Vector2(0.55, 0.7) * r, Color(0.3, 0.2, 0.1), 2.0)


static func remolino(ci: CanvasItem, c: Vector2, r: float) -> void:
	var t := Time.get_ticks_msec() * 0.004
	for k in 3:
		var pts := PackedVector2Array()
		for i in 20:
			var u := float(i) / 19.0
			var a := t + k * TAU / 3.0 + u * 3.5
			pts.append(c + Vector2(cos(a), sin(a) * 0.6) * r * (0.2 + u * 0.75) + Vector2(0, (0.5 - u) * r * 0.5))
		ci.draw_polyline(pts, Color(0.75, 1.0, 0.88, 0.9), 3.0, true)


static func espiral(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r * 0.8, Color(0.35, 0.6, 1.0, 0.5))
	var t := Time.get_ticks_msec() * 0.006
	for k in 4:
		var pts := PackedVector2Array()
		for i in 16:
			var u := float(i) / 15.0
			var a := t + k * TAU / 4.0 + u * 4.0
			pts.append(c + Vector2(cos(a), sin(a)) * r * (0.1 + u * 0.7))
		ci.draw_polyline(pts, Color(0.85, 0.95, 1.0), 2.5, true)
	ci.draw_arc(c, r * 0.8, 0, TAU, 32, Color(0.9, 0.97, 1.0), 2.0, true)


## Ojo según el modo: 1 tomoe, 2 caleidoscopio, 3 anillos concéntricos, 4 blanco con venas.
static func ojo_patron(ci: CanvasItem, c: Vector2, r: float, activo: bool, patron: int) -> void:
	if patron == 1:
		ojo_tomoe(ci, c, r, activo)
		return
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r * 0.98, sin(a) * r * 0.58 * (1.0 - 0.25 * absf(cos(a)))))
	_poligono(ci, pts, Color(0.96, 0.95, 0.93), Color(0.08, 0.02, 0.02), 3.0)
	var ri := r * 0.5
	var giro := Time.get_ticks_msec() * (0.003 if activo else 0.0006)
	match patron:
		2:
			ci.draw_circle(c, ri, Color(0.8, 0.04, 0.06))
			for k in 3:
				var a := giro + TAU * k / 3.0
				var aspa := PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * ri * 0.95, c + Vector2(cos(a + 0.9), sin(a + 0.9)) * ri * 0.45])
				Iconos.relleno(ci, aspa, Color(0.05, 0, 0))
			ci.draw_circle(c, ri * 0.18, Color(0.85, 0.05, 0.08))
		3:
			ci.draw_circle(c, ri, Color(0.62, 0.52, 0.85))
			for k in 4:
				ci.draw_arc(c, ri * (0.2 + k * 0.22), 0, TAU, 24, Color(0.15, 0.08, 0.25), 2.0, true)
			ci.draw_circle(c, ri * 0.12, Color(0.1, 0.05, 0.15))
		_:
			ci.draw_circle(c, ri, Color(0.9, 0.88, 0.95))
			for k in 6:
				var a2 := TAU * k / 6.0
				ci.draw_line(c + Vector2(cos(a2), sin(a2)) * ri, c + Vector2(cos(a2), sin(a2) * 0.7) * r * 0.95, Color(0.55, 0.5, 0.7, 0.8), 1.5)
			ci.draw_arc(c, ri, 0, TAU, 24, Color(0.6, 0.55, 0.75), 2.0, true)


static func susanoo(ci: CanvasItem, c: Vector2, r: float) -> void:
	var col := Color(0.62, 0.42, 1.0)
	ci.draw_circle(c + Vector2(0, -r * 0.55), r * 0.22, Color(col.r, col.g, col.b, 0.8))
	for k in 4:
		var y := -0.25 + k * 0.22
		ci.draw_arc(c + Vector2(0, y * r), r * (0.6 - k * 0.06), PI * 0.05, PI * 0.95, 14, col, 3.0, true)
	ci.draw_line(c + Vector2(0, -0.32) * r, c + Vector2(0, 0.6) * r, col, 3.0)
	ci.draw_circle(c + Vector2(-0.08, -0.57) * r, r * 0.04, Color(1, 0.9, 1))
	ci.draw_circle(c + Vector2(0.08, -0.57) * r, r * 0.04, Color(1, 0.9, 1))


static func ondas(ci: CanvasItem, c: Vector2, r: float) -> void:
	var t := fmod(Time.get_ticks_msec() * 0.001, 1.0)
	for k in 3:
		var u := fmod(t + k / 3.0, 1.0)
		ci.draw_arc(c, r * (0.2 + u * 0.8), 0, TAU, 32, Color(0.85, 0.8, 1.0, 1.0 - u), 3.0, true)
	ci.draw_circle(c, r * 0.16, Color(0.75, 0.65, 1.0))


static func puerta(ci: CanvasItem, c: Vector2, r: float, activo: bool) -> void:
	var col := Color(0.4, 1.0, 0.55) if not activo else Color(1.0, 0.35, 0.3)
	ci.draw_rect(Rect2(c + Vector2(-0.55, -0.75) * r, Vector2(1.1, 1.5) * r), Color(0.1, 0.12, 0.1))
	ci.draw_rect(Rect2(c + Vector2(-0.55, -0.75) * r, Vector2(1.1, 1.5) * r), col, false, 3.0)
	ci.draw_line(c + Vector2(0, -0.75) * r, c + Vector2(0, 0.75) * r, col, 2.5)
	var t := Time.get_ticks_msec() * 0.003
	for k in 3:
		var x := (-0.4 + k * 0.4) * r
		ci.draw_line(c + Vector2(x, -0.9 * r - 4.0 * sin(t + k)), c + Vector2(x + 3, -1.05 * r), Color(col.r, col.g, col.b, 0.6), 2.0)


static func clones(ci: CanvasItem, c: Vector2, r: float) -> void:
	for k in 3:
		var off := Vector2((k - 1) * 0.42, 0.05 * absi(k - 1)) * r
		var a: float = 0.5 + 0.25 * (1 - absi(k - 1))
		ci.draw_circle(c + off + Vector2(0, -0.35 * r), r * 0.2, Color(1, 0.85, 0.6, a))
		ci.draw_rect(Rect2(c + off + Vector2(-0.18, -0.12) * r, Vector2(0.36, 0.6) * r), Color(0.95, 0.5, 0.15, a))


static func papel(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-0.45, -0.75) * r, c + Vector2(0.45, -0.75) * r, c + Vector2(0.45, 0.75) * r, c + Vector2(-0.45, 0.75) * r])
	_poligono(ci, pts, Color(0.95, 0.9, 0.78), Color(0.3, 0.2, 0.1), 2.0)
	for k in 3:
		ci.draw_line(c + Vector2(-0.25, -0.4 + k * 0.35) * r, c + Vector2(0.25, -0.4 + k * 0.35) * r, Color(0.7, 0.1, 0.1), 2.5)


static func kunai(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -0.9) * r, c + Vector2(0.22, -0.2) * r, c + Vector2(0, -0.05) * r, c + Vector2(-0.22, -0.2) * r])
	_poligono(ci, pts, Color(0.75, 0.78, 0.82), Color(0.1, 0.1, 0.12), 2.0)
	ci.draw_line(c + Vector2(0, -0.05) * r, c + Vector2(0, 0.55) * r, Color(0.2, 0.2, 0.25), r * 0.12)
	ci.draw_arc(c + Vector2(0, 0.7) * r, r * 0.14, 0, TAU, 12, Color(0.75, 0.78, 0.82), 2.5, true)
	ci.draw_line(c + Vector2(0.3, 0.1) * r, c + Vector2(0.7, -0.4) * r, Color(1, 0.9, 0.3), 2.0)


static func cruz(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(-0.18, -0.65) * r, Vector2(0.36, 1.3) * r), Color(0.4, 1.0, 0.55))
	ci.draw_rect(Rect2(c + Vector2(-0.65, -0.18) * r, Vector2(1.3, 0.36) * r), Color(0.4, 1.0, 0.55))


static func hoja(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var u := float(i) / 19.0
		pts.append(c + Vector2(sin(u * PI) * 0.45 * (1 if i < 10 else 1), -0.85 + u * 1.6) * r)
	for i in range(19, -1, -1):
		var u2 := float(i) / 19.0
		pts.append(c + Vector2(-sin(u2 * PI) * 0.45, -0.85 + u2 * 1.6) * r)
	_poligono(ci, pts, Color(0.35, 0.75, 0.3), Color(0.08, 0.2, 0.05), 2.0)
	ci.draw_line(c + Vector2(0, -0.8) * r, c + Vector2(0, 0.8) * r, Color(0.15, 0.4, 0.1), 2.0)


static func cristal(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -0.9) * r, c + Vector2(0.5, -0.1) * r, c + Vector2(0.2, 0.8) * r, c + Vector2(-0.2, 0.8) * r, c + Vector2(-0.5, -0.1) * r])
	_poligono(ci, pts, Color(0.7, 0.9, 1.0, 0.9), Color(0.2, 0.35, 0.5), 2.0)
	ci.draw_line(c + Vector2(0, -0.9) * r, c + Vector2(0, 0.8) * r, Color(1, 1, 1, 0.7), 1.5)


static func ave(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-0.9, -0.2) * r, c + Vector2(-0.2, 0.0) * r, c + Vector2(0, 0.5) * r, c + Vector2(0.2, 0.0) * r, c + Vector2(0.9, -0.2) * r, c + Vector2(0, 0.15) * r])
	_poligono(ci, pts, Color(0.95, 0.92, 0.85), Color(0.3, 0.25, 0.2), 2.0)
