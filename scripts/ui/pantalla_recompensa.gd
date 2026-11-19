class_name PantallaRecompensa
extends Control
## Pantalla de recompensa: un cofre de papel y metal se abre con un destello y los premios entran uno a uno
## (experiencia, ryō, pergaminos que enseñan jutsus y cosméticos). Si existe la imagen/modelo del cofre
## (pedido a GPT: cofre_recompensa.png) se podrá usar; mientras tanto el cofre se dibuja.

var sonidos: Sonidos
var _items: Array = []      # [{icono, texto, color}]
var _t := 0.0
var _titulo := ""
var _exito := true
var _extra := ""


func mostrar(titulo: String, rec: Dictionary, exito: bool, extra := "") -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_titulo = titulo
	_exito = exito
	_extra = extra
	_items.clear()
	if exito:
		if int(rec.get("xp", 0)) > 0:
			_items.append({"icono": "xp", "texto": Datos.texto("rec_xp", [int(rec["xp"])]), "color": Color(0.6, 0.85, 1.0)})
		if int(rec.get("ryo", 0)) > 0:
			_items.append({"icono": "ryo", "texto": Datos.texto("rec_ryo", [int(rec["ryo"])]), "color": Color(1.0, 0.85, 0.4)})
		for p in rec.get("pergaminos", []):
			_items.append({"icono": "pergamino", "texto": Datos.texto("rec_pergamino", [Datos.jutsu(str(p)).get("nombre", p)]), "color": Color(0.95, 0.75, 1.0)})
		for c in rec.get("cosmeticos", []):
			var cd: Dictionary = Misiones.conf().get("cosmeticos", {}).get(str(c), {})
			_items.append({"icono": "cosmetico", "texto": Datos.texto("rec_cosmetico", [cd.get("nombre", c)]), "color": Color(0.7, 1.0, 0.8)})
		if int(rec.get("punto_atributo", 0)) > 0:
			_items.append({"icono": "punto", "texto": Datos.texto("rec_punto"), "color": Color(1.0, 0.6, 0.5)})
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	if sonidos != null:
		sonidos.tocar("campana" if exito else "tambor", -4.0, 1.0)
	gui_input.connect(func(ev):
		if _t > 1.0 and ((ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)):
			cerrar())
	var tw := create_tween()
	tw.tween_interval(9.0)
	tw.tween_callback(cerrar)


func cerrar() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	var antes := _t
	_t += delta
	# Sonido de cada premio al entrar.
	for i in _items.size():
		var ti := 0.9 + i * 0.35
		if antes < ti and _t >= ti and sonidos != null:
			sonidos.tocar("monedas" if str(_items[i]["icono"]) == "ryo" else "papel", -8.0, 1.0 + i * 0.05)
	queue_redraw()


func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.02, 0.05, 0.72))
	var c := Vector2(sz.x * 0.5, sz.y * 0.36)
	Estilo.texto(self, Vector2(0, 110), Datos.texto("rec_cumplida") if _exito else Datos.texto("rec_fallida"), 48,
		Color(1.0, 0.85, 0.45) if _exito else Color(0.85, 0.4, 0.4), sz.x, HORIZONTAL_ALIGNMENT_CENTER, Estilo.fuente_titulo(), 10)
	Estilo.texto(self, Vector2(0, 150), _titulo, 26, Estilo.PAPEL, sz.x, HORIZONTAL_ALIGNMENT_CENTER, Estilo.fuente_titulo(), 6)
	if not _exito:
		return
	# Cofre: se sacude, la tapa se abre y sale un destello.
	var abre := clampf((_t - 0.4) / 0.4, 0.0, 1.0)
	var temblor := sin(_t * 40.0) * 3.0 * (1.0 - clampf(_t / 0.4, 0.0, 1.0))
	var base := Rect2(c + Vector2(-70 + temblor, 0), Vector2(140, 70))
	draw_rect(base, Color(0.22, 0.24, 0.28))
	draw_rect(Rect2(base.position + Vector2(0, 28), Vector2(140, 10)), Color(0.48, 0.12, 0.14))
	draw_rect(base, Color(0.6, 0.62, 0.68), false, 3.0)
	var tapa_y := -26.0 - abre * 34.0
	var tapa := PackedVector2Array([c + Vector2(-74 + temblor, 0), c + Vector2(74 + temblor, 0), c + Vector2(62, tapa_y), c + Vector2(-62, tapa_y)])
	draw_colored_polygon(tapa, Color(0.26, 0.28, 0.33))
	draw_rect(Rect2(c + Vector2(-10, tapa_y * 0.5 - 8), Vector2(20, 22)), Color(1.0, 0.75, 0.3))
	if abre > 0.0:
		var brillo := clampf(1.0 - (_t - 0.8) / 0.8, 0.0, 1.0)
		for k in 12:
			var a := TAU * k / 12.0 + _t * 0.6
			draw_line(c, c + Vector2(cos(a), sin(a) - 0.6) * (120.0 + 60.0 * abre), Color(1.0, 0.9, 0.6, 0.35 * brillo), 6.0)
	# Premios uno a uno.
	for i in _items.size():
		var ti := 0.9 + i * 0.35
		var u := clampf((_t - ti) / 0.3, 0.0, 1.0)
		if u <= 0.0:
			continue
		var it: Dictionary = _items[i]
		var y := sz.y * 0.52 + i * 46.0
		var x := lerpf(sz.x * 0.5 + 120.0, sz.x * 0.5 - 220.0, 1.0 - pow(1.0 - u, 3.0))
		var fila := Rect2(Vector2(x, y), Vector2(440, 40))
		Estilo.dibujar_marco(self, fila, 0.85 * u, false)
		draw_circle(fila.position + Vector2(24, 20), 12, it["color"])
		Estilo.texto(self, fila.position + Vector2(48, 28), str(it["texto"]), 20, Color(1, 1, 1, u), 380)
	if _extra != "":
		Estilo.texto(self, Vector2(0, sz.y - 70), _extra, 24, Color(1.0, 0.8, 0.4), sz.x, HORIZONTAL_ALIGNMENT_CENTER, Estilo.fuente_titulo(), 6)
