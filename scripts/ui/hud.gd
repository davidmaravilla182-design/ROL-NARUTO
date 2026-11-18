class_name Hud
extends CanvasLayer
## Interfaz del juego: barras, botones táctiles con recarga, joystick, cámara,
## sellos de manos, mensajes y botones de depuración. Todo texto viene de /data/textos.json.

signal accion(id: String)
signal nivel_pedido(nivel: int)
signal reaparecer_pedido()
signal salir_pedido()
signal camara_arrastre(relativo: Vector2)

const BOTONES := [
	# id, clave de texto, color, radio, desplazamiento desde el centro del botón principal
	["golpe", "boton_golpe", Color(0.55, 0.42, 0.3), 74.0, Vector2(0, 0)],
	["bola_fuego", "boton_bola_fuego", Color(0.85, 0.35, 0.1), 58.0, Vector2(-40, -185)],
	["chidori", "boton_chidori", Color(0.2, 0.5, 0.9), 58.0, Vector2(-180, -115)],
	["esquivar", "boton_esquivar", Color(0.3, 0.55, 0.45), 52.0, Vector2(-200, 45)],
	["saltar", "boton_saltar", Color(0.4, 0.4, 0.5), 48.0, Vector2(70, -150)],
	["sharingan", "boton_sharingan", Color(0.6, 0.08, 0.1), 50.0, Vector2(-150, -265)],
]

var raiz: Control
var joystick: JoystickVirtual
var area_camara: AreaCamara
var botones: Dictionary = {}
var barra_vida: Barra
var barra_chakra: Barra
var barra_estamina: Barra
var barra_enemigo: Barra
var _nombre_enemigo: Label
var _boton_nivel: Button
var _mensaje: Label
var _mensaje_t := 0.0
var _banner: Label
var _banner_sub: Label
var _overlay: ColorRect
var _overlay_mat: ShaderMaterial
var _overlay_val := 0.0
var _sellos_panel: Control
var _sellos: Array = []
var _sellos_t := 0.0
var _sellos_dur := 1.0
var _clima: Label
var nivel := 1
var sharingan_activo := false


func construir() -> void:
	layer = 10
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = crear_tema()
	add_child(raiz)

	# Viñeta roja del modo ocular.
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float intensidad = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float v = smoothstep(0.32, 0.78, length(uv * vec2(1.3, 1.0)));
	COLOR = vec4(0.75, 0.0, 0.04, v * 0.45 * intensidad);
}"""
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = sh
	_overlay.material = _overlay_mat
	raiz.add_child(_overlay)

	area_camara = AreaCamara.new()
	area_camara.arrastre.connect(func(r): camara_arrastre.emit(r))
	raiz.add_child(area_camara)
	joystick = JoystickVirtual.new()
	raiz.add_child(joystick)

	for b in BOTONES:
		var bt := BotonAccion.new()
		bt.configurar(b[0], Datos.texto(b[1]), b[2], b[3])
		bt.set_meta("desplazamiento", b[4])
		bt.pulsado.connect(func(i): accion.emit(i))
		raiz.add_child(bt)
		botones[b[0]] = bt

	barra_vida = _barra(Datos.texto("hud_vida"), Color(0.8, 0.15, 0.15), Vector2(24, 18))
	barra_chakra = _barra(Datos.texto("hud_chakra"), Color(0.2, 0.45, 0.95), Vector2(24, 56))
	barra_estamina = _barra(Datos.texto("hud_estamina"), Color(0.25, 0.75, 0.3), Vector2(24, 94))
	barra_estamina.size.y = 26
	barra_enemigo = _barra("", Color(0.75, 0.2, 0.15), Vector2.ZERO)
	_nombre_enemigo = _etiqueta("", 22, HORIZONTAL_ALIGNMENT_CENTER)

	_clima = _etiqueta(Datos.texto("hud_lluvia"), 18, HORIZONTAL_ALIGNMENT_LEFT)
	_clima.modulate = Color(0.75, 0.85, 1.0, 0.9)

	# Depuración: nivel de poder, reaparecer y volver al menú.
	_boton_nivel = _boton_texto(Datos.texto("hud_nivel", [nivel]), func(): _ciclar_nivel())
	_boton_texto(Datos.texto("hud_reaparecer"), func(): reaparecer_pedido.emit()).name = "BotonReaparecer"
	_boton_texto(Datos.texto("hud_salir"), func(): salir_pedido.emit()).name = "BotonSalir"

	_sellos_panel = Control.new()
	_sellos_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sellos_panel.draw.connect(_dibujar_sellos)
	raiz.add_child(_sellos_panel)

	_mensaje = _etiqueta("", 30, HORIZONTAL_ALIGNMENT_CENTER)
	_banner = _etiqueta("", 52, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_sub = _etiqueta("", 26, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.visible = false
	_banner_sub.visible = false

	get_viewport().size_changed.connect(_reordenar)
	_reordenar()


static func crear_tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.12, 0.16, 0.8)
	normal.border_color = Color(1, 1, 1, 0.5)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(12)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.2, 0.26, 0.9)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.5, 0.1, 0.1, 0.9)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "Label", 6)
	return t


func _barra(txt: String, c: Color, pos: Vector2) -> Barra:
	var b := Barra.new()
	b.configurar(txt, c, Vector2(380, 32))
	b.position = pos
	raiz.add_child(b)
	return b


func _etiqueta(txt: String, tam: int, alin: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = alin
	l.add_theme_font_size_override("font_size", tam)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(l)
	return l


func _boton_texto(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(130, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	b.set_meta("depuracion", true)
	raiz.add_child(b)
	return b


func _reordenar() -> void:
	var t := raiz.get_viewport_rect().size
	area_camara.position = Vector2(t.x * 0.5, 0)
	area_camara.size = Vector2(t.x * 0.5, t.y)
	joystick.position = Vector2(0, t.y * 0.3)
	joystick.size = Vector2(t.x * 0.45, t.y * 0.7)
	joystick.colocar_reposo(Vector2(170, joystick.size.y - 150))
	var principal := Vector2(t.x - 120, t.y - 115)
	for id in botones.keys():
		var b: BotonAccion = botones[id]
		b.centrar_en(principal + (b.get_meta("desplazamiento") as Vector2))
	barra_enemigo.size = Vector2(minf(360, t.x * 0.28), 30)
	barra_enemigo.position = Vector2(minf((t.x - barra_enemigo.size.x) * 0.5, t.x - 3 * 138 - 30 - barra_enemigo.size.x), 44)
	_nombre_enemigo.position = Vector2(barra_enemigo.position.x, 8)
	_nombre_enemigo.size = Vector2(barra_enemigo.size.x, 32)
	_clima.position = Vector2(26, 128)
	# Botones de depuración arriba a la derecha.
	var x := t.x - 16
	var deps: Array = []
	for n in raiz.get_children():
		if n is Button and n.has_meta("depuracion"):
			deps.append(n)
	deps.reverse()
	for b in deps:
		x -= 138
		b.position = Vector2(x, 14)
		b.size = Vector2(130, 56)
	_sellos_panel.position = Vector2(t.x * 0.5 - 300, t.y * 0.66)
	_sellos_panel.size = Vector2(600, 90)
	_mensaje.position = Vector2(0, t.y * 0.22)
	_mensaje.size = Vector2(t.x, 40)
	_banner.position = Vector2(0, t.y * 0.36)
	_banner.size = Vector2(t.x, 70)
	_banner_sub.position = Vector2(0, t.y * 0.36 + 72)
	_banner_sub.size = Vector2(t.x, 40)


func _ciclar_nivel() -> void:
	nivel = nivel % 3 + 1
	_boton_nivel.text = Datos.texto("hud_nivel", [nivel])
	nivel_pedido.emit(nivel)
	mensaje(Datos.texto("msg_nivel", [nivel]))


func poner_nivel(n: int) -> void:
	nivel = n
	_boton_nivel.text = Datos.texto("hud_nivel", [nivel])


## Refresca barras y botones con la instantánea del servidor.
func actualizar(j: Dictionary, enemigo: Dictionary) -> void:
	barra_vida.fijar(j["vida"], j["vida_max"])
	barra_chakra.fijar(j["chakra"], j["chakra_max"])
	barra_estamina.fijar(j["estamina"], j["estamina_max"])
	sharingan_activo = bool(j["sharingan"])
	var rec: Dictionary = j["recargas"]
	var attrs: Dictionary = Datos.personaje(str(j["plantilla"])).get("atributos", {})
	for id in botones.keys():
		var b: BotonAccion = botones[id]
		var total := float(Datos.jutsu(id).get("recarga", 1.0))
		var sin_recurso := false
		if id in ["bola_fuego", "chidori"]:
			sin_recurso = float(j["chakra"]) < Combate.costo_chakra(id, int(j["nivel"]), attrs)
		elif id == "sharingan":
			sin_recurso = not sharingan_activo and float(j["chakra"]) < Combate.costo_chakra(id, 1, attrs)
		elif id == "esquivar":
			sin_recurso = float(j["estamina"]) < float(Datos.jutsu(id).get("costo_estamina", 0))
		b.actualizar(float(rec.get(id, 0.0)), total, sin_recurso, id == "sharingan" and sharingan_activo)
	if enemigo.is_empty():
		barra_enemigo.visible = false
		_nombre_enemigo.visible = false
	else:
		barra_enemigo.visible = true
		_nombre_enemigo.visible = true
		_nombre_enemigo.text = str(Datos.personaje(str(enemigo["plantilla"])).get("nombre", ""))
		barra_enemigo.fijar(enemigo["vida"], enemigo["vida_max"])


func mostrar_sellos(lista: Array, duracion: float) -> void:
	_sellos = lista
	_sellos_dur = maxf(duracion, 0.05)
	_sellos_t = 0.0
	_sellos_panel.queue_redraw()


func mensaje(txt: String, segundos := 1.8) -> void:
	_mensaje.text = txt
	_mensaje_t = segundos
	_mensaje.modulate.a = 1.0


func banner(txt: String, sub := "") -> void:
	_banner.text = txt
	_banner_sub.text = sub
	_banner.visible = txt != ""
	_banner_sub.visible = sub != ""


func _process(delta: float) -> void:
	if _mensaje_t > 0.0:
		_mensaje_t -= delta
		_mensaje.modulate.a = clampf(_mensaje_t / 0.5, 0.0, 1.0)
	var objetivo := 1.0 if sharingan_activo else 0.0
	if absf(_overlay_val - objetivo) > 0.001:
		_overlay_val = move_toward(_overlay_val, objetivo, delta * 3.0)
		_overlay_mat.set_shader_parameter("intensidad", _overlay_val)
	_overlay.visible = _overlay_val > 0.001
	if not _sellos.is_empty():
		_sellos_t += delta
		_sellos_panel.queue_redraw()
		if _sellos_t > _sellos_dur + 0.5:
			_sellos = []
			_sellos_panel.queue_redraw()


## Iconos de los sellos de manos: se iluminan uno por uno durante la secuencia.
func _dibujar_sellos() -> void:
	if _sellos.is_empty():
		return
	var n := _sellos.size()
	var tam := 74.0
	var sep := 12.0
	var ancho := n * tam + (n - 1) * sep
	var x0 := (_sellos_panel.size.x - ancho) * 0.5
	var f := raiz.get_theme_default_font()
	var progreso := _sellos_t / _sellos_dur * n
	var alfa := clampf(1.0 - (_sellos_t - _sellos_dur) / 0.5, 0.0, 1.0)
	for i in n:
		var id := str(_sellos[i])
		var datos: Dictionary = Datos.mundo.get("sellos", {}).get(id, {})
		var col := Datos.color(str(datos.get("color", "#cccccc")))
		var hecho := progreso >= float(i)
		var r := Rect2(Vector2(x0 + i * (tam + sep), 0), Vector2(tam, tam))
		var fondo := col if hecho else col.darkened(0.7)
		fondo.a = 0.9 * alfa
		_sellos_panel.draw_rect(r, fondo)
		_sellos_panel.draw_rect(r, Color(1, 1, 1, (0.9 if hecho else 0.3) * alfa), false, 3.0)
		# Glifo: inicial grande del sello
		var nombre := str(datos.get("nombre", id))
		_sellos_panel.draw_string_outline(f, Vector2(r.position.x, r.position.y + 50), nombre.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, tam, 44, 6, Color(0, 0, 0, alfa))
		_sellos_panel.draw_string(f, Vector2(r.position.x, r.position.y + 50), nombre.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, tam, 44, Color(1, 1, 1, alfa))
		_sellos_panel.draw_string_outline(f, Vector2(r.position.x - 10, r.position.y + tam + 22), nombre, HORIZONTAL_ALIGNMENT_CENTER, tam + 20, 18, 5, Color(0, 0, 0, alfa))
		_sellos_panel.draw_string(f, Vector2(r.position.x - 10, r.position.y + tam + 22), nombre, HORIZONTAL_ALIGNMENT_CENTER, tam + 20, 18, Color(1, 1, 1, alfa))
