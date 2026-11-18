class_name BotonJutsu
extends Control
## Botón táctil circular de acción con icono propio.
## - Toque rápido: emite `tocado` (auto-apuntado).
## - Mantener y arrastrar (solo jutsus apuntables): emite `apuntando` mientras se arrastra
##   y `soltado` al levantar el dedo, o `cancelado` si se soltó sobre la zona de cancelar.
## Muestra recarga con barrido circular y segundos, costo de chakra y estado sin recurso.

signal tocado(id: String)
signal apuntando(id: String, arrastre: Vector2, sobre_cancelar: bool)
signal soltado(id: String, arrastre: Vector2)
signal cancelado(id: String)

const UMBRAL_ARRASTRE := 26.0

var id := ""
var color := Color(0.3, 0.3, 0.35)
var radio := 56.0
var apuntable := false
var costo := 0.0
var recarga := 0.0
var recarga_total := 1.0
var deshabilitado := false
var activo := false
var es_cancelar: Callable   # (pos_global: Vector2) -> bool, la da el HUD
var opacidad := 0.9

var _indice := -1
var _inicio := Vector2.ZERO
var _arrastre := Vector2.ZERO
var _apuntando := false
var _sobre_cancelar := false
var _pulso := 0.0     # animación de presión (escala + brillo)
var _brillo_listo := 0.0


func configurar(p_id: String, p_color: Color, p_radio: float, p_apuntable: bool) -> void:
	id = p_id
	color = p_color
	apuntable = p_apuntable
	fijar_radio(p_radio)
	mouse_filter = Control.MOUSE_FILTER_STOP


func fijar_radio(r: float) -> void:
	radio = r
	custom_minimum_size = Vector2(radio * 2, radio * 2)
	size = custom_minimum_size
	pivot_offset = size * 0.5


func centrar_en(p: Vector2) -> void:
	position = p - Vector2(radio, radio)


func _has_point(p: Vector2) -> bool:
	return p.distance_to(Vector2(radio, radio)) <= radio * 1.1


func presionado() -> bool:
	return _indice >= 0


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var t: InputEventScreenTouch = ev
		if t.pressed and _indice < 0:
			_indice = t.index
			_inicio = t.position
			_arrastre = Vector2.ZERO
			_apuntando = false
			_pulso = 1.0
			Ajustes.vibrar(18)
			if not apuntable:
				tocado.emit(id)
			accept_event()
		elif not t.pressed and t.index == _indice:
			_soltar()
			accept_event()
		queue_redraw()
	elif ev is InputEventScreenDrag:
		var d: InputEventScreenDrag = ev
		if d.index != _indice or not apuntable:
			return
		_arrastre = d.position - _inicio
		if not _apuntando and _arrastre.length() > UMBRAL_ARRASTRE:
			_apuntando = true
			Ajustes.vibrar(12)
		if _apuntando:
			var antes := _sobre_cancelar
			_sobre_cancelar = es_cancelar.is_valid() and es_cancelar.call(get_global_transform() * d.position)
			if _sobre_cancelar and not antes:
				Ajustes.vibrar(30)
			apuntando.emit(id, _arrastre, _sobre_cancelar)
		accept_event()
		queue_redraw()


func _soltar() -> void:
	var era := _indice
	_indice = -1
	if era < 0 or not apuntable:
		return
	if _apuntando:
		if _sobre_cancelar:
			cancelado.emit(id)
		else:
			soltado.emit(id, _arrastre)
	else:
		tocado.emit(id)
	_apuntando = false
	_sobre_cancelar = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _indice >= 0:
		_indice = -1
		if _apuntando:
			cancelado.emit(id)
		_apuntando = false


func actualizar(p_recarga: float, p_total: float, p_deshabilitado: bool, p_activo: bool, p_costo: float) -> void:
	if p_recarga <= 0.0 and recarga > 0.0:
		_brillo_listo = 1.0   # destello al quedar listo
	recarga = p_recarga
	recarga_total = maxf(p_total, 0.01)
	deshabilitado = p_deshabilitado
	activo = p_activo
	costo = p_costo


func _process(delta: float) -> void:
	_pulso = move_toward(_pulso, 0.0, delta * 4.0)
	_brillo_listo = move_toward(_brillo_listo, 0.0, delta * 2.5)
	var esc := 1.0 - 0.1 * sin(_pulso * PI) + (0.04 if _indice >= 0 else 0.0)
	scale = Vector2(esc, esc)
	modulate.a = opacidad
	queue_redraw()


func _draw() -> void:
	var c := Vector2(radio, radio)
	var r := radio
	var base := color if not deshabilitado else Color(0.32, 0.33, 0.36)
	# Halo de brillo al presionar o al quedar listo.
	var halo := maxf(_pulso, _brillo_listo)
	if halo > 0.0 or activo:
		var col_h := Color(1.0, 0.85, 0.5) if not activo else Color(1.0, 0.15, 0.15)
		for i in 4:
			draw_circle(c, r + 4 + i * 3, Color(col_h.r, col_h.g, col_h.b, (0.12 if activo else 0.18 * halo) * (1.0 - i / 4.0)))
	# Aro exterior de metal.
	draw_circle(c, r, Color(0.08, 0.09, 0.11, 0.95))
	draw_arc(c, r - 2, 0, TAU, 48, Estilo.ACERO_BORDE, 3.0, true)
	draw_arc(c, r - 6, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.25), 2.0, true)
	# Disco interior con degradado radial.
	var ri := r - 8
	for i in 6:
		var u := float(i) / 6.0
		draw_circle(c - Vector2(0, ri * 0.08 * u), ri * (1.0 - u * 0.5), base.darkened(0.45 - u * 0.5))
	draw_arc(c, ri, 0, TAU, 48, base.lightened(0.35), 2.0, true)
	# Icono
	Iconos.dibujar(self, id, c, ri * 0.62, activo)
	if deshabilitado:
		draw_circle(c, ri, Color(0.2, 0.2, 0.22, 0.55))
	# Recarga: barrido circular oscuro + segundos.
	if recarga > 0.0:
		var frac := clampf(recarga / recarga_total, 0.0, 1.0)
		var puntos := PackedVector2Array([c])
		var pasos := 36
		for i in pasos + 1:
			var a := -PI * 0.5 + TAU * frac * float(i) / pasos
			puntos.append(c + Vector2(cos(a), sin(a)) * ri)
		draw_colored_polygon(puntos, Color(0, 0, 0, 0.62))
		var a_fin := -PI * 0.5 + TAU * frac
		draw_line(c, c + Vector2(cos(a_fin), sin(a_fin)) * ri, Color(1, 1, 1, 0.7), 2.0)
		var t := ("%.1f" % recarga) if recarga < 10.0 else str(int(recarga))
		Estilo.texto(self, Vector2(0, c.y + r * 0.22), t, int(r * 0.62), Color.WHITE, r * 2, HORIZONTAL_ALIGNMENT_CENTER, Estilo.fuente_ui(), 7)
	# Costo de chakra (placa inferior).
	if costo > 0.0:
		var txt := str(int(ceil(costo)))
		var ancho := r * 0.9
		var placa := Rect2(c + Vector2(-ancho * 0.5, r * 0.62), Vector2(ancho, r * 0.38))
		draw_rect(placa, Color(0.05, 0.12, 0.3, 0.92) if not deshabilitado else Color(0.35, 0.05, 0.05, 0.95))
		draw_rect(placa, Color(0.5, 0.7, 1.0, 0.8) if not deshabilitado else Color(1, 0.4, 0.4, 0.9), false, 1.5)
		Estilo.texto(self, Vector2(placa.position.x, placa.position.y + placa.size.y * 0.82), txt, int(r * 0.34), Color(0.8, 0.9, 1.0), placa.size.x, HORIZONTAL_ALIGNMENT_CENTER, Estilo.fuente_ui(), 4)
	# Dirección de arrastre mientras se apunta.
	if _apuntando:
		var d := _arrastre.limit_length(r * 1.6)
		draw_line(c, c + d, Color(1, 0.3, 0.25, 0.9) if _sobre_cancelar else Color(1, 0.85, 0.4, 0.9), 5.0, true)
		draw_circle(c + d, 9.0, Color(1, 1, 1, 0.9))
