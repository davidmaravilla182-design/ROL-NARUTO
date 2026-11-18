class_name Retrato
extends Control
## Retrato del personaje (dibujado por código) con barras de vida, chakra y estamina
## animadas: la barra baja suave y deja una estela clara del daño recibido.

var nombre := ""
var aspecto: Dictionary = {}
var sharingan := false
var _val := {"vida": [1.0, 1.0, 1.0, 1.0], "chakra": [1.0, 1.0, 1.0, 1.0], "estamina": [1.0, 1.0, 1.0, 1.0]}  # [valor, max, mostrado, estela]
var _sacudida := 0.0
const COLORES := {"vida": [Color(0.86, 0.16, 0.18), Color(1.0, 0.45, 0.35)], "chakra": [Color(0.18, 0.45, 1.0), Color(0.5, 0.8, 1.0)], "estamina": [Color(0.25, 0.75, 0.32), Color(0.6, 1.0, 0.55)]}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(470, 132)
	size = custom_minimum_size


func fijar(clave: String, valor: float, maximo: float) -> void:
	var v: Array = _val[clave]
	if clave == "vida" and valor < float(v[0]) - 0.5:
		_sacudida = 1.0
	v[0] = valor
	v[1] = maxf(maximo, 0.001)


func _process(delta: float) -> void:
	for k in _val.keys():
		var v: Array = _val[k]
		var frac := clampf(float(v[0]) / float(v[1]), 0.0, 1.0)
		v[2] = lerpf(float(v[2]), frac, minf(1.0, delta * 9.0))
		if float(v[3]) < frac:
			v[3] = frac
		else:
			v[3] = move_toward(float(v[3]), frac, delta * 0.45)
	_sacudida = move_toward(_sacudida, 0.0, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var off := Vector2(sin(Time.get_ticks_msec() * 0.08) * 4.0 * _sacudida, 0)
	var retrato_r := Rect2(Vector2(0, 0) + off, Vector2(120, 120))
	Estilo.dibujar_marco(self, Rect2(Vector2(0, 0) + off, Vector2(size.x, 124)), 0.82, false)
	_dibujar_cara(retrato_r.grow(-10))
	var x0 := 128.0
	Estilo.texto(self, Vector2(x0, 30) + off, nombre, 22, Estilo.PAPEL, -1, HORIZONTAL_ALIGNMENT_LEFT, Estilo.fuente_titulo(), 5)
	var filas := [["vida", 42.0, 26.0], ["chakra", 72.0, 22.0], ["estamina", 98.0, 14.0]]
	for f in filas:
		_barra(f[0], Rect2(Vector2(x0, f[1]) + off, Vector2(size.x - x0 - 14, f[2])))


func _barra(clave: String, r: Rect2) -> void:
	var v: Array = _val[clave]
	var cols: Array = COLORES[clave]
	# Ranura biselada
	var sesgo := r.size.y * 0.5
	var fondo := PackedVector2Array([r.position + Vector2(sesgo, 0), r.position + Vector2(r.size.x, 0), r.position + Vector2(r.size.x - sesgo, r.size.y), r.position + Vector2(0, r.size.y)])
	draw_colored_polygon(fondo, Color(0.03, 0.03, 0.05, 0.9))
	var est: float = v[3]
	var mos: float = v[2]
	_relleno(r, sesgo, est, Color(1, 0.95, 0.85, 0.55))
	_relleno(r, sesgo, mos, cols[0])
	# Brillo superior y degradado
	_relleno(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.4)), sesgo * 0.4, mos, Color(cols[1].r, cols[1].g, cols[1].b, 0.45))
	var cerrado := fondo.duplicate()
	cerrado.append(fondo[0])
	draw_polyline(cerrado, Color(0.7, 0.75, 0.82, 0.8), 1.5, true)
	if r.size.y >= 20:
		var txt := "%d / %d" % [mini(int(ceil(float(v[0]))), int(round(float(v[1])))), int(round(float(v[1])))]
		Estilo.texto(self, Vector2(r.position.x, r.position.y + r.size.y * 0.8), txt, int(r.size.y * 0.8), Color.WHITE, r.size.x - 12, HORIZONTAL_ALIGNMENT_RIGHT, Estilo.fuente_ui(), 4)


func _relleno(r: Rect2, sesgo: float, frac: float, col: Color) -> void:
	if frac <= 0.001:
		return
	var ancho := (r.size.x - sesgo) * frac
	var pts := PackedVector2Array([r.position + Vector2(sesgo, 0), r.position + Vector2(sesgo + ancho, 0), r.position + Vector2(ancho, r.size.y), r.position + Vector2(0, r.size.y)])
	draw_colored_polygon(pts, col)


## Cara estilizada: fondo rojo con el abanico, pelo en picos, banda con placa y ojos.
func _dibujar_cara(r: Rect2) -> void:
	var c := r.get_center() + Vector2(0, 6)
	var s := r.size.x / 100.0
	draw_rect(r, Color(0.35, 0.05, 0.08))
	for i in 5:
		draw_rect(Rect2(r.position + Vector2(0, i * r.size.y / 5.0), Vector2(r.size.x, r.size.y / 10.0)), Color(0, 0, 0, 0.12))
	var piel := Datos.color(str(aspecto.get("piel", "#f1cfae")))
	var pelo := Datos.color(str(aspecto.get("pelo", "#1a1f2e")))
	# cuello y hombros
	draw_rect(Rect2(c + Vector2(-38, 30) * s, Vector2(76, 30) * s), Datos.color(str(aspecto.get("camisa", "#1a2140"))))
	draw_rect(Rect2(c + Vector2(-9, 18) * s, Vector2(18, 16) * s), piel.darkened(0.15))
	# picos de pelo detrás
	var picos := PackedVector2Array()
	var pts_pelo := [Vector2(-34, 4), Vector2(-48, -16), Vector2(-30, -22), Vector2(-40, -44), Vector2(-14, -36), Vector2(-10, -58), Vector2(8, -40), Vector2(26, -56), Vector2(28, -32), Vector2(50, -36), Vector2(36, -12), Vector2(46, 4), Vector2(30, 0)]
	for p in pts_pelo:
		picos.append(c + p * s)
	draw_colored_polygon(picos, pelo)
	# cara
	var cara := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		var rr := Vector2(27, 31) * s
		var p2 := Vector2(cos(a) * rr.x, sin(a) * rr.y)
		if p2.y > 0:
			p2.x *= 1.0 - p2.y / rr.y * 0.35
		cara.append(c + p2)
	draw_colored_polygon(cara, piel)
	# flequillo
	var fleq := PackedVector2Array([c + Vector2(-30, -10) * s, c + Vector2(-22, -30) * s, c + Vector2(22, -32) * s, c + Vector2(32, -8) * s, c + Vector2(18, -14) * s, c + Vector2(10, 2) * s, c + Vector2(2, -14) * s, c + Vector2(-8, 4) * s, c + Vector2(-14, -12) * s])
	draw_colored_polygon(fleq, pelo)
	# banda con placa y símbolo
	draw_rect(Rect2(c + Vector2(-29, -20) * s, Vector2(58, 9) * s), Datos.color(str(aspecto.get("banda", "#26304f"))))
	var placa := Rect2(c + Vector2(-14, -21) * s, Vector2(28, 11) * s)
	draw_rect(placa, Color(0.78, 0.8, 0.85))
	for i in 4:
		draw_line(placa.position + Vector2((7 + i * 5) * s, 2.5 * s), placa.position + Vector2((7 + i * 5) * s, 8.5 * s), Color(0.15, 0.16, 0.2), 1.5)
	# ojos
	for lado in [-1.0, 1.0]:
		var ojo := c + Vector2(11 * lado, -2) * s
		draw_colored_polygon(PackedVector2Array([ojo + Vector2(-7, 0) * s, ojo + Vector2(0, -3.5) * s, ojo + Vector2(7, 0) * s, ojo + Vector2(0, 2.5) * s]), Color(0.97, 0.97, 0.97))
		draw_circle(ojo, 2.6 * s, Color(0.85, 0.05, 0.08) if sharingan else Color(0.08, 0.06, 0.06))
		if sharingan:
			draw_circle(ojo, 0.9 * s, Color(0.05, 0, 0))
		draw_line(ojo + Vector2(-8, -6 - lado * 0) * s, ojo + Vector2(7, -7 + lado * 1.5) * s, pelo, 2.5 * s)
	draw_line(c + Vector2(-5, 17) * s, c + Vector2(4, 17) * s, Color(0.4, 0.2, 0.2), 1.5 * s)
	draw_rect(r, Estilo.ACERO_BORDE, false, 2.0)
