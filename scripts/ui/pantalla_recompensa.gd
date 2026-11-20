class_name PantallaRecompensa
extends Control
## Pantalla de recompensa: un cofre de papel y metal se abre con un destello y los premios entran uno a uno
## (experiencia, ryō, pergaminos que enseñan jutsus y cosméticos). El cofre y el pergamino son modelos 3D
## (imágenes de GPT → Meshy: cofre_base/cofre_tapa y pergamino) en un visor propio; sin modelos, se dibujan.

signal cerrada

var sonidos: Sonidos
var _items: Array = []      # [{icono, texto, color}]
var _t := 0.0
var _titulo := ""
var _exito := true
var _extra := ""
var _visor: SubViewportContainer
var _tapa: Node3D
var _cofre: Node3D
var _pergamino: Node3D
var _luz_cofre: OmniLight3D
var _con_pergamino := false


func mostrar(titulo: String, rec: Dictionary, exito: bool, extra := "") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		_con_pergamino = not (rec.get("pergaminos", []) as Array).is_empty()
		if ResourceLoader.exists("res://assets/modelos/cofre_base.glb"):
			_crear_visor()
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


## Visor 3D (mundo propio, fondo transparente): cofre que tiembla y abre la tapa; si hay pergamino, sube girando.
func _crear_visor() -> void:
	_visor = SubViewportContainer.new()
	_visor.stretch = true
	_visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visor)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	_visor.add_child(vp)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_CLEAR_COLOR
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.75, 0.72, 0.8)
	we.environment.ambient_light_energy = 0.45
	vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 35, 0)
	sol.light_energy = 1.2
	vp.add_child(sol)
	var cam := Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.8, 1.05, 1.75), Vector3(0, 0.36, 0), Vector3.UP)
	_cofre = Node3D.new()
	_cofre.rotation.y = -0.35
	vp.add_child(_cofre)
	_cofre.add_child(Kit.instancia("cofre_base", Transform3D.IDENTITY, false))
	var b: Array = Datos.graficos.get("cofre_bisagra", [0.0, 0.28, -0.34])
	_tapa = Node3D.new()
	_tapa.position = Vector3(float(b[0]), float(b[1]), float(b[2]))
	_cofre.add_child(_tapa)
	_tapa.add_child(Kit.instancia("cofre_tapa", Transform3D.IDENTITY, false))
	_luz_cofre = OmniLight3D.new()
	_luz_cofre.light_color = Color(1.0, 0.75, 0.35)
	_luz_cofre.omni_range = 2.5
	_luz_cofre.light_energy = 0.0
	_luz_cofre.position = Vector3(0, 0.45, 0)
	_cofre.add_child(_luz_cofre)
	if _con_pergamino and ResourceLoader.exists("res://assets/modelos/pergamino.glb"):
		_pergamino = Node3D.new()
		_pergamino.visible = false
		_cofre.add_child(_pergamino)
		var pm := Kit.instancia("pergamino", Transform3D.IDENTITY, false)
		pm.scale = Vector3.ONE * 1.3
		_pergamino.add_child(pm)
		var lila := OmniLight3D.new()
		lila.light_color = Color(0.8, 0.6, 1.0)
		lila.omni_range = 1.2
		lila.light_energy = 1.5
		_pergamino.add_child(lila)


func _animar_visor() -> void:
	var sz := size
	var c := Vector2(sz.x * 0.5, sz.y * 0.36)
	_visor.position = c - Vector2(220, 95)
	_visor.size = Vector2(440, 265)
	var abre := clampf((_t - 0.4) / 0.4, 0.0, 1.0)
	var temblor := sin(_t * 40.0) * 0.06 * (1.0 - clampf(_t / 0.4, 0.0, 1.0))
	_cofre.rotation.z = temblor
	# La tapa salta un poco al abrir (sobrepasa y vuelve).
	var ang := -1.95 * abre + sin(abre * PI) * -0.25
	_tapa.rotation.x = ang
	_luz_cofre.light_energy = 3.0 * abre * clampf(1.6 - (_t - 0.8) * 0.5, 0.6, 1.6)
	_cofre.rotation.y = -0.35 + sin(_t * 0.6) * 0.08
	if _pergamino != null:
		var u := clampf((_t - 0.9) / 0.7, 0.0, 1.0)
		_pergamino.visible = u > 0.0
		_pergamino.position = Vector3(0, 0.3 + (1.0 - pow(1.0 - u, 3.0)) * 0.3 + sin(_t * 2.0) * 0.03 * u, 0.12 + 0.18 * u)
		_pergamino.rotation.y = _t * 1.6


var _cerrando := false


func cerrar() -> void:
	if _cerrando:
		return
	_cerrando = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		cerrada.emit()
		queue_free())


func _process(delta: float) -> void:
	var antes := _t
	_t += delta
	# Sonido de cada premio al entrar.
	for i in _items.size():
		var ti := 0.9 + i * 0.35
		if antes < ti and _t >= ti and sonidos != null:
			sonidos.tocar("monedas" if str(_items[i]["icono"]) == "ryo" else "papel", -8.0, 1.0 + i * 0.05)
	if _visor != null:
		_animar_visor()
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
	# Cofre (dibujado solo si no hay modelo 3D): se sacude, la tapa se abre y sale un destello.
	var abre := clampf((_t - 0.4) / 0.4, 0.0, 1.0)
	var temblor := sin(_t * 40.0) * 3.0 * (1.0 - clampf(_t / 0.4, 0.0, 1.0))
	if _visor == null:
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
		var y := sz.y * (0.6 if _visor != null else 0.52) + i * 46.0
		var x := lerpf(sz.x * 0.5 + 120.0, sz.x * 0.5 - 220.0, 1.0 - pow(1.0 - u, 3.0))
		var fila := Rect2(Vector2(x, y), Vector2(440, 40))
		Estilo.dibujar_marco(self, fila, 0.85 * u, false)
		draw_circle(fila.position + Vector2(24, 20), 12, it["color"])
		Estilo.texto(self, fila.position + Vector2(48, 28), str(it["texto"]), 20, Color(1, 1, 1, u), 380)
	if _extra != "":
		Estilo.texto(self, Vector2(0, sz.y - 70), _extra, 24, Color(1.0, 0.8, 0.4), sz.x, HORIZONTAL_ALIGNMENT_CENTER, Estilo.fuente_titulo(), 6)
