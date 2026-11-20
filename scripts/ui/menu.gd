extends Control
## Pantalla de inicio: título, aviso legal de proyecto de fans y botón para entrenar.

const ESCENA_JUEGO := "res://escenas/juego.tscn"
const ESCENA_PERSONAJE := "res://escenas/personaje.tscn"
const ESCENA_RED := "res://escenas/red.tscn"

var _gotas: Array = []
var _rng := RandomNumberGenerator.new()
var _camara_fondo: Camera3D
var _t_fondo := 0.0
var _fondo_3d := false


func _ready() -> void:
	Datos.cargar()
	Ajustes.cargar()
	Registro.iniciar()
	Registro.nota("MENU")
	Engine.time_scale = 1.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Estilo.tema()
	_rng.randomize()
	for i in 110:
		_gotas.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.6, 1.4)))

	_crear_fondo_3d()
	if not Registro.cierre_anterior.is_empty():
		_aviso_cierre.call_deferred()

	var juego: Dictionary = Datos.mundo["juego"]
	var aldea := Datos.aldea("lluvia")

	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 18)
	add_child(caja)

	var titulo := _label(str(juego["titulo"]), 84, Color(0.97, 0.95, 0.9))
	titulo.add_theme_font_override("font", Estilo.fuente_titulo())
	titulo.add_theme_color_override("font_outline_color", Color(0.45, 0.03, 0.06))
	titulo.add_theme_constant_override("outline_size", 18)
	caja.add_child(titulo)
	caja.add_child(_label(str(juego["subtitulo"]), 30, Color(0.8, 0.85, 0.95)))
	caja.add_child(_label(Datos.texto("menu_ubicacion", [aldea.get("nombre_largo", ""), aldea.get("sector", "")]), 26, Color(0.6, 0.75, 0.9)))

	var espacio := Control.new()
	espacio.custom_minimum_size = Vector2(0, 20)
	caja.add_child(espacio)

	Perfil.cargar()
	var boton := _boton_menu("BotonEntrenar", Datos.texto("menu_entrenar_offline"), 34, Vector2(400, 88), func(): _jugar("offline"))
	boton.add_theme_font_override("font", Estilo.fuente_titulo())
	var crear_red := _boton_menu("BotonCrearRed", Datos.texto("menu_crear_red"), 24, Vector2(290, 88), func(): _jugar("anfitrion"))
	var unirse := _boton_menu("BotonUnirse", Datos.texto("menu_unirse_red"), 24, Vector2(290, 88), func(): _jugar("cliente"))
	var personaje := _boton_menu("BotonPersonaje", Datos.texto("pj_activo", [Perfil.nombre_activo()]), 22, Vector2(300, 66),
		func(): get_tree().change_scene_to_file(ESCENA_PERSONAJE))
	var repertorio := _boton_menu("BotonRepertorio", Datos.texto("menu_repertorio"), 22, Vector2(220, 66),
		func(): get_tree().change_scene_to_file("res://escenas/repertorio.tscn"))
	var misiones_b := _boton_menu("BotonMisiones", Datos.texto("menu_misiones"), 22, Vector2(170, 66),
		func(): get_tree().change_scene_to_file("res://escenas/misiones.tscn"))
	var ficha := _boton_menu("BotonFicha", Datos.texto("menu_ficha"), 22, Vector2(160, 66),
		func(): get_tree().change_scene_to_file("res://escenas/ficha.tscn"))
	var ajustes := _boton_menu("BotonAjustes", Datos.texto("menu_ajustes"), 22, Vector2(180, 66), func():
		var m := MenuAjustes.new()
		add_child(m)
		m.construir())
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	fila.add_child(boton)
	fila.add_child(crear_red)
	fila.add_child(unirse)
	var fila2 := HBoxContainer.new()
	fila2.add_theme_constant_override("separation", 14)
	fila2.add_child(personaje)
	fila2.add_child(misiones_b)
	fila2.add_child(ficha)
	fila2.add_child(repertorio)
	fila2.add_child(ajustes)
	var centro_b := CenterContainer.new()
	centro_b.add_child(fila2)
	var centro := CenterContainer.new()
	centro.add_child(fila)
	caja.add_child(centro)
	caja.add_child(centro_b)

	var espacio2 := Control.new()
	espacio2.custom_minimum_size = Vector2(0, 26)
	caja.add_child(espacio2)

	var aviso := _label(Datos.texto("menu_aviso"), 24, Color(0.25, 0.16, 0.1))
	aviso.add_theme_constant_override("outline_size", 0)
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.custom_minimum_size = Vector2(880, 0)
	# Aviso legal sobre un pergamino.
	var pergamino := PanelContainer.new()
	var estilo_p := StyleBoxFlat.new()
	estilo_p.bg_color = Color(Estilo.PAPEL.r, Estilo.PAPEL.g, Estilo.PAPEL.b, 0.93)
	estilo_p.border_color = Color(0.3, 0.2, 0.14)
	estilo_p.border_width_left = 12
	estilo_p.border_width_right = 12
	estilo_p.border_width_top = 5
	estilo_p.border_width_bottom = 5
	estilo_p.set_content_margin_all(14)
	pergamino.add_theme_stylebox_override("panel", estilo_p)
	pergamino.add_child(aviso)
	var centro2 := CenterContainer.new()
	centro2.add_child(pergamino)
	caja.add_child(centro2)
	caja.add_child(_label(Datos.texto("menu_pie", [juego["version"]]), 20, Color(0.65, 0.7, 0.78)))


## Fondo en vivo: la aldea en 3D con lluvia y una cámara que la recorre despacio.
func _crear_fondo_3d() -> void:
	if not ResourceLoader.exists("res://assets/modelos/edificio.glb"):
		return
	var contenedor := SubViewportContainer.new()
	contenedor.set_anchors_preset(Control.PRESET_FULL_RECT)
	contenedor.stretch = true
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contenedor)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = float(Ajustes.g("escala_3d", 1.0))
	contenedor.add_child(vp)
	var esc := Escenario.new()
	vp.add_child(esc)
	esc.construir(Mapa.generar())
	_camara_fondo = Camera3D.new()
	_camara_fondo.fov = 62.0
	_camara_fondo.far = 300.0
	vp.add_child(_camara_fondo)
	_camara_fondo.current = true
	esc.camara = _camara_fondo
	var lluvia := Lluvia.new()
	vp.add_child(lluvia)
	lluvia.construir()
	lluvia.objetivo = _camara_fondo
	# Velo oscuro para que el texto se lea sobre la escena.
	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.color = Color(0.02, 0.02, 0.05, 0.38)
	add_child(velo)
	_fondo_3d = true
	_mover_camara(0.0)


func _mover_camara(t: float) -> void:
	# Recorrido lento por encima de la plaza mirando hacia la torre monumental.
	var pos := Vector3(sin(t * 0.06) * 9.0, 5.5 + sin(t * 0.09) * 1.2, 13.0 + cos(t * 0.045) * 2.0)
	_camara_fondo.global_position = pos
	_camara_fondo.look_at(Vector3(-4.0 + sin(t * 0.04) * 6.0, 16.0, -45.0), Vector3.UP)


func _label(t: String, tam: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _boton_menu(nombre: String, texto: String, tam: int, minimo: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.name = nombre
	b.text = texto
	b.add_theme_font_size_override("font_size", tam)
	b.custom_minimum_size = minimo
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


## Entrenar, crear o unirse. Si aún no hay personaje creado, primero se crea.
func _jugar(modo: String) -> void:
	Sesion.modo = modo
	var destino := ESCENA_RED if modo == "cliente" else ESCENA_JUEGO
	if Perfil.personajes.is_empty():
		Sesion.tras_personaje = destino
		get_tree().change_scene_to_file(ESCENA_PERSONAJE)
		return
	get_tree().change_scene_to_file(destino)


func _entrenar() -> void:
	_jugar("offline")


func _process(delta: float) -> void:
	if _fondo_3d:
		_t_fondo += delta
		_mover_camara(_t_fondo)
		return
	for i in _gotas.size():
		var g: Vector3 = _gotas[i]
		g.y += delta * 0.9 * g.z
		g.x += delta * 0.05 * g.z
		if g.y > 1.05:
			g.y = -0.05
			g.x = _rng.randf()
		_gotas[i] = g
	queue_redraw()


func _draw() -> void:
	if _fondo_3d:
		return
	var t := get_viewport_rect().size
	# Cielo gris con degradado y siluetas de torres.
	var pasos := 12
	for i in pasos:
		var c := Color(0.2, 0.23, 0.27).lerp(Color(0.42, 0.46, 0.52), float(i) / pasos)
		draw_rect(Rect2(0, t.y * i / pasos, t.x, t.y / pasos + 1), c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := 0.0
	while x < t.x:
		var w := rng.randf_range(50, 120)
		var h := rng.randf_range(t.y * 0.25, t.y * 0.75)
		draw_rect(Rect2(x, t.y - h, w, h), Color(0.12, 0.13, 0.16, 0.9))
		var vy := t.y - h + 20
		while vy < t.y - 10:
			if rng.randf() < 0.3:
				draw_rect(Rect2(x + rng.randf_range(6, w - 16), vy, 8, 12), Color(1.0, 0.8, 0.45, 0.6))
			vy += 26
		x += w + rng.randf_range(4, 30)
	draw_rect(Rect2(0, 0, t.x, t.y), Color(0, 0, 0, 0.35))
	for g in _gotas:
		var p := Vector2(g.x * t.x, g.y * t.y)
		draw_line(p, p + Vector2(4, 26) * g.z, Color(0.75, 0.82, 0.95, 0.35), 2.0)


## La partida anterior se cerró de golpe: muestra sus últimos pasos para mandarlos en una captura.
func _aviso_cierre() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(900, 0)
	panel.position -= Vector2(450, 330)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	panel.add_child(caja)
	caja.add_child(_label(Datos.texto("registro_titulo"), 30, Color(1.0, 0.8, 0.45)))
	caja.add_child(_label(Datos.texto("registro_pide"), 20, Color(0.85, 0.88, 0.95)))
	var txt := Label.new()
	txt.text = "\n".join(Registro.cierre_anterior)
	txt.add_theme_font_size_override("font_size", 12)
	txt.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8))
	txt.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	caja.add_child(txt)
	var b := Button.new()
	b.text = Datos.texto("registro_cerrar")
	b.custom_minimum_size = Vector2(220, 60)
	b.pressed.connect(func():
		Registro.cierre_anterior = PackedStringArray()
		panel.queue_free())
	caja.add_child(b)
	add_child(panel)
