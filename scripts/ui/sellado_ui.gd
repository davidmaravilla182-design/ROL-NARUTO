class_name SelladoUi
extends Control
## Minijuego de sellado del bijuu: arriba la secuencia de sellos que hay que formar; abajo los 10 sellos.
## Hay que tocarlos en orden antes de que se acabe el tiempo. Un error reinicia la secuencia.
## Al completarla se manda al servidor (que comprueba Sellos 3+ y la secuencia).

signal enviado(sellos: Array)

var secuencia: Array = []
var tiempo := 14.0
var sonidos: Sonidos
var _ids: Array = []
var _hechos := 0
var _t := 0.0
var _fallo_t := 0.0
var _rects: Array = []


func iniciar(sec: Array, segundos: float) -> void:
	secuencia = sec
	tiempo = segundos
	_ids = (Datos.mundo.get("sellos", {}) as Dictionary).keys()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	if sonidos != null:
		sonidos.tocar("tambor", -2.0, 0.8)


func _process(d: float) -> void:
	_t += d
	_fallo_t = maxf(_fallo_t - d, 0.0)
	if _t >= tiempo:
		queue_free()
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	var p := Vector2.INF
	if ev is InputEventMouseButton and ev.pressed:
		p = ev.position
	elif ev is InputEventScreenTouch and ev.pressed:
		p = ev.position
	if p == Vector2.INF:
		return
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(p):
			_tocar(i)
			return


func _tocar(i: int) -> void:
	if _hechos >= secuencia.size():
		return
	if i == int(secuencia[_hechos]):
		_hechos += 1
		if sonidos != null:
			sonidos.tocar("papel", -6.0, 1.0 + _hechos * 0.1)
		if _hechos >= secuencia.size():
			enviado.emit(secuencia.duplicate())
			if sonidos != null:
				sonidos.tocar("campana", -2.0, 1.0)
			var tw := create_tween()
			tw.tween_interval(0.6)
			tw.tween_property(self, "modulate:a", 0.0, 0.3)
			tw.tween_callback(queue_free)
	else:
		_hechos = 0
		_fallo_t = 0.4
		if sonidos != null:
			sonidos.tocar("golpe", -4.0, 0.6)


func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.0, 0.08, 0.55))
	Estilo.texto(self, Vector2(0, 80), Datos.texto("sellado_titulo"), 40, Color(0.85, 0.75, 1.0), sz.x, HORIZONTAL_ALIGNMENT_CENTER, Estilo.fuente_titulo(), 10)
	# Tiempo.
	var frac := clampf(1.0 - _t / tiempo, 0.0, 1.0)
	draw_rect(Rect2(Vector2(sz.x * 0.2, 100), Vector2(sz.x * 0.6, 10)), Color(0.1, 0.1, 0.15, 0.8))
	draw_rect(Rect2(Vector2(sz.x * 0.2, 100), Vector2(sz.x * 0.6 * frac, 10)), Color(0.75, 0.4, 1.0) if frac > 0.25 else Color(1.0, 0.3, 0.3))
	# Secuencia pedida.
	var n := secuencia.size()
	var tam := 70.0
	var x0 := (sz.x - n * (tam + 14.0)) * 0.5
	for i in n:
		var id := str(_ids[int(secuencia[i])]) if int(secuencia[i]) < _ids.size() else "?"
		var dat: Dictionary = Datos.mundo.get("sellos", {}).get(id, {})
		var c := Vector2(x0 + i * (tam + 14.0) + tam * 0.5, 170)
		var hecho := i < _hechos
		var col := Datos.color(str(dat.get("color", "#cccccc")))
		var rombo := PackedVector2Array([c + Vector2(0, -tam * 0.5), c + Vector2(tam * 0.5, 0), c + Vector2(0, tam * 0.5), c + Vector2(-tam * 0.5, 0)])
		draw_colored_polygon(rombo, col if hecho else col.darkened(0.6))
		Estilo.texto(self, Vector2(c.x - 50, c.y + 50), str(dat.get("nombre", id)), 17, Color(1, 1, 1, 0.9), 100, HORIZONTAL_ALIGNMENT_CENTER)
	# Botones de sellos (dos filas).
	_rects.clear()
	var cols := 5
	var bw := 150.0
	var bh := 74.0
	var bx := (sz.x - cols * (bw + 12.0)) * 0.5
	for i in _ids.size():
		var r := Rect2(Vector2(bx + (i % cols) * (bw + 12.0), sz.y - 210 + int(i / cols) * (bh + 12.0)), Vector2(bw, bh))
		_rects.append(r)
		var dat2: Dictionary = Datos.mundo.get("sellos", {}).get(str(_ids[i]), {})
		Estilo.dibujar_marco(self, r, 0.9, false)
		draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(10, r.size.y - 12)), Datos.color(str(dat2.get("color", "#cccccc"))))
		Estilo.texto(self, r.position + Vector2(24, 46), str(dat2.get("nombre", _ids[i])), 22, Color.WHITE, bw - 30)
	if _fallo_t > 0.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 0, 0, 0.18 * _fallo_t / 0.4))
