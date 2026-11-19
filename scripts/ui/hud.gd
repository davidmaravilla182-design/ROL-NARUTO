class_name Hud
extends CanvasLayer
## Interfaz del juego: retrato con barras, botones en arco alrededor del golpe
## (toque = auto-apuntado, mantener y arrastrar = apuntado manual), zona de cancelar,
## fijar objetivo, joystick, cámara, sellos, mensajes, ajustes y depuración.
## Todo texto viene de /data/textos.json.

signal accion(id: String)
signal apuntar(id: String, arrastre: Vector2, cancelar: bool)
signal soltar(id: String, arrastre: Vector2)
signal cancelar(id: String)
signal fijar_pedido()
signal nivel_pedido(nivel: int)
signal reaparecer_pedido()
signal salir_pedido()
signal reinicio_pedido()
signal camara_arrastre(relativo: Vector2)
signal viajar_pedido(id: String)
signal interactuar_pedido()

# id, color, radio base, ángulo en el arco (grados, 180 = izquierda, 270 = arriba), anillo (0 centro, 1 interior, 2 exterior), apuntable
# Botones fijos: id, color, radio base, ángulo en el arco (180 = izquierda, 270 = arriba), anillo (0 centro, 1 interior, 2 exterior)
const BOTONES := [
	["golpe", Color(0.62, 0.42, 0.26), 80.0, 0.0, 0],
	["esquivar", Color(0.22, 0.52, 0.44), 48.0, 174.0, 1],
	["saltar", Color(0.38, 0.4, 0.52), 44.0, 292.0, 1],
	["fijar", Color(0.3, 0.32, 0.38), 40.0, 287.0, 2],
]
# Ranuras del repertorio: 4 jutsus activos y el modo.
const RANURAS := [[56.0, 211.0, 1], [56.0, 251.0, 1], [50.0, 198.0, 2], [50.0, 226.0, 2]]
const RANURA_MODO := [48.0, 256.0, 2]

var minimapa: Minimapa
var _boton_interactuar: Button
var _dialogo: Label
var _dialogo_txt: Label
var _dialogo_t := 0.0
var atributos_jugador: Dictionary = {}   # atributos del personaje (Inteligencia: qué se ve del rival)
var _lineas: Control
var _lineas_t := 0.0
var _lineas_total := 0.3
var _genjutsu: ColorRect
var _genjutsu_t := 0.0
var _genjutsu_total := 1.0
var mapa_completo: MapaCompleto
var _mapa: Mapa
var raiz: Control
var joystick: JoystickVirtual
var area_camara: AreaCamara
var botones: Dictionary = {}
var retrato: Retrato
var _enemigo_panel: Control
var _enemigo := {"nombre": "", "vida": 1.0, "max": 1.0, "mostrado": 1.0, "visible": false}
var _boton_nivel: Button
var _mensaje: Label
var _mensaje_t := 0.0
var _banner: Control
var _banner_txt := ""
var _banner_sub := ""
var _banner_t := 0.0
var _retrato_conf: Array = []
const BANNER_DURACION := 4.0
var _overlay: ColorRect
var _overlay_mat: ShaderMaterial
var _overlay_val := 0.0
var _sellos_panel: Control
var _sellos: Array = []
var _sellos_t := 0.0
var _sellos_dur := 1.0
var _cancelar_zona: Control
var _cancelar_activo := false
var _cancelar_sobre := false
var _fps: Label
var diag_red: Dictionary = {}
var _info_red: Label    # {ping, perdida, jugadores, simulado} lo rellena el cliente en red
var _diag_t := 0.0
var _clima: Label
var _margen := Rect2()     # márgenes del área segura: position = (izq, arriba), size = (der, abajo)
var nivel := 1
var sharingan_activo := false
var fijado := false
var modo_id := ""


static func color_de(id: String) -> Color:
	var cat := str(Datos.jutsu(id).get("categoria", ""))
	var c := Datos.color(str(Repertorio.categorias().get(cat, {}).get("color", "#808080")))
	return c.darkened(0.35)


func _crear_boton(id: String, color: Color, radio: float, angulo: float, anillo: int, apuntable: bool) -> void:
	var bt := BotonJutsu.new()
	bt.configurar(id, color, radio, apuntable)
	bt.set_meta("radio_base", radio)
	bt.set_meta("angulo", angulo)
	bt.set_meta("anillo", anillo)
	bt.es_cancelar = _sobre_cancelar
	bt.tocado.connect(_on_tocado)
	bt.apuntando.connect(_on_apuntando)
	bt.soltado.connect(_on_soltado)
	bt.cancelado.connect(_on_cancelado)
	raiz.add_child(bt)
	botones[id] = bt


func construir(rep: Dictionary = {}) -> void:
	layer = 10
	Ajustes.cargar()
	# Reconstruible: al cambiar de repertorio se descarta la interfaz anterior entera.
	if raiz != null and is_instance_valid(raiz):
		raiz.free()
	botones.clear()
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = Estilo.tema()
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
	float v = smoothstep(0.3, 0.8, length(uv * vec2(1.3, 1.0)));
	float lineas = 0.85 + 0.15 * sin(UV.y * 900.0 + TIME * 4.0);
	COLOR = vec4(0.7, 0.0, 0.04, v * 0.5 * intensidad * lineas);
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

	_cancelar_zona = Control.new()
	_cancelar_zona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cancelar_zona.draw.connect(_dibujar_cancelar)
	_cancelar_zona.visible = false
	raiz.add_child(_cancelar_zona)

	for b in BOTONES:
		_crear_boton(b[0], b[1], b[2], b[3], b[4], false)
	# Botones generados según el repertorio elegido en el menú.
	var activos: Array = rep.get("activos", [])
	for i in RANURAS.size():
		var id := str(activos[i]) if i < activos.size() else ""
		if id == "":
			continue
		var r: Array = RANURAS[i]
		_crear_boton(id, color_de(id), r[0], r[1], r[2], bool(Datos.jutsu(id).get("apuntable", false)))
	var modo := str(rep.get("modo", ""))
	if modo != "":
		_crear_boton(modo, color_de(modo), RANURA_MODO[0], RANURA_MODO[1], RANURA_MODO[2], false)
		modo_id = modo

	retrato = Retrato.new()
	raiz.add_child(retrato)
	if not _retrato_conf.is_empty():
		retrato.callv("configurar", _retrato_conf)

	_enemigo_panel = Control.new()
	_enemigo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemigo_panel.draw.connect(_dibujar_enemigo)
	raiz.add_child(_enemigo_panel)

	_clima = _etiqueta(Datos.texto("hud_lluvia"), 20, HORIZONTAL_ALIGNMENT_LEFT)
	_clima.modulate = Color(0.75, 0.85, 1.0, 0.9)

	# Botones pequeños arriba a la derecha: nivel (depuración), reaparecer, ajustes y menú.
	nivel = 0
	_boton_nivel = _boton_texto(Datos.texto("hud_nivel_auto"), func(): _ciclar_nivel())
	_boton_texto(Datos.texto("hud_reaparecer"), func(): reaparecer_pedido.emit())
	if _mapa != null and _mapa.radio_caminable > 0.0:
		_boton_texto(Datos.texto("hud_mapa"), func(): abrir_mapa())
	_boton_texto(Datos.texto("hud_ajustes"), func(): abrir_ajustes())
	_boton_texto(Datos.texto("hud_salir"), func(): salir_pedido.emit())

	_sellos_panel = Control.new()
	_sellos_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sellos_panel.draw.connect(_dibujar_sellos)
	raiz.add_child(_sellos_panel)

	_mensaje = _etiqueta("", 34, HORIZONTAL_ALIGNMENT_CENTER)
	_mensaje.add_theme_font_override("font", Estilo.fuente_titulo())
	_banner = Control.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.draw.connect(_dibujar_banner)
	_banner.visible = false
	raiz.add_child(_banner)

	_info_red = _etiqueta("", 19, HORIZONTAL_ALIGNMENT_CENTER)
	_info_red.add_theme_constant_override("outline_size", 6)
	_info_red.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info_red.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_fps = _etiqueta("", 18, HORIZONTAL_ALIGNMENT_LEFT)
	_fps.modulate = Color(0.7, 1.0, 0.7)
	_fps.add_theme_constant_override("outline_size", 5)
	_fps.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))

	# Genjutsu: la pantalla se nubla y gira en morado unos segundos.
	_genjutsu = ColorRect.new()
	_genjutsu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_genjutsu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shg := Shader.new()
	shg.code = """shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform float intensidad = 0.0;
void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	float r = length(c);
	float ang = intensidad * 0.9 * sin(TIME * 1.7) * (1.0 - r);
	vec2 uv = vec2(cos(ang) * c.x - sin(ang) * c.y, sin(ang) * c.x + cos(ang) * c.y) + 0.5;
	uv += vec2(sin(TIME * 3.0 + SCREEN_UV.y * 12.0), cos(TIME * 2.3 + SCREEN_UV.x * 10.0)) * 0.006 * intensidad;
	vec3 borroso = textureLod(pantalla, uv, 3.5 * intensidad).rgb;
	float vin = smoothstep(0.25, 0.75, r);
	vec3 tinte = mix(borroso, vec3(0.35, 0.1, 0.5), 0.25 * intensidad + vin * 0.45 * intensidad);
	COLOR = vec4(tinte, intensidad);
}"""
	var mg := ShaderMaterial.new()
	mg.shader = shg
	_genjutsu.material = mg
	_genjutsu.visible = false
	raiz.add_child(_genjutsu)
	# Interactuar con aldeanos y puntos de misión (aparece solo cuando hay uno cerca).
	_boton_interactuar = Button.new()
	_boton_interactuar.text = "Interactuar"
	_boton_interactuar.add_theme_font_size_override("font_size", 26)
	_boton_interactuar.custom_minimum_size = Vector2(220, 70)
	_boton_interactuar.focus_mode = Control.FOCUS_NONE
	_boton_interactuar.visible = false
	_boton_interactuar.pressed.connect(func(): interactuar_pedido.emit(); Ajustes.vibrar(15))
	raiz.add_child(_boton_interactuar)
	# Globo de diálogo: una etiqueta de tamaño fijo con fondo (no crece con el texto).
	_dialogo_txt = Label.new()
	_dialogo = _dialogo_txt
	_dialogo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogo.visible = false
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.04, 0.05, 0.09, 0.85)
	fondo.border_color = Color(0.85, 0.7, 0.45, 0.8)
	fondo.set_border_width_all(2)
	fondo.set_corner_radius_all(10)
	fondo.set_content_margin_all(14)
	_dialogo_txt.add_theme_stylebox_override("normal", fondo)
	_dialogo_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogo_txt.add_theme_font_size_override("font_size", 24)
	_dialogo_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogo_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogo_txt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	_dialogo_txt.add_theme_constant_override("outline_size", 6)
	_dialogo_txt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	raiz.add_child(_dialogo)
	if _mapa != null and _mapa.radio_caminable > 0.0:
		minimapa = Minimapa.new()
		raiz.add_child(minimapa)
		minimapa.configurar(_mapa)
	if not get_viewport().size_changed.is_connected(_reordenar):
		get_viewport().size_changed.connect(_reordenar)
	aplicar_ajustes()


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
	b.custom_minimum_size = Vector2(126, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	b.pressed.connect(func(): Ajustes.vibrar(15))
	b.set_meta("superior", true)
	raiz.add_child(b)
	return b


## Aplica tamaño/transparencia de botones y recalcula el diseño.
func aplicar_ajustes() -> void:
	for id in botones.keys():
		var b: BotonJutsu = botones[id]
		b.fijar_radio(float(b.get_meta("radio_base")) * Ajustes.tamano_botones)
		b.opacidad = Ajustes.opacidad_botones
	_fps.visible = Ajustes.mostrar_fps
	_reordenar()


## Márgenes de la zona segura (cámara perforada, bordes curvos) en coordenadas de la interfaz.
func _calcular_margenes() -> void:
	var t := raiz.get_viewport_rect().size
	var minimo := 18.0
	var izq := minimo
	var der := minimo
	var arr := minimo
	var aba := minimo
	if DisplayServer.get_name() != "headless":
		var seguro := Rect2(DisplayServer.get_display_safe_area())
		var ventana := Vector2(DisplayServer.window_get_size())
		if seguro.size.x > 0 and ventana.x > 0:
			var esc := t / ventana
			izq = maxf(minimo, seguro.position.x * esc.x)
			arr = maxf(minimo, seguro.position.y * esc.y)
			der = maxf(minimo, (ventana.x - seguro.end.x) * esc.x)
			aba = maxf(minimo, (ventana.y - seguro.end.y) * esc.y)
	# Bordes curvos: un poco más de aire a los lados.
	_margen = Rect2(Vector2(izq + 6, arr), Vector2(der + 6, aba))


func _reordenar() -> void:
	_calcular_margenes()
	var t := raiz.get_viewport_rect().size
	var izq := _margen.position.x
	var arr := _margen.position.y
	var der := _margen.size.x
	var aba := _margen.size.y
	area_camara.position = Vector2(t.x * 0.45, 0)
	area_camara.size = Vector2(t.x * 0.55, t.y)
	joystick.position = Vector2(0, t.y * 0.3)
	joystick.size = Vector2(t.x * 0.45, t.y * 0.7)
	joystick.colocar_reposo(Vector2(izq + 150, joystick.size.y - aba - 130))
	# Arco de botones alrededor del golpe (esquina inferior derecha).
	var s := Ajustes.tamano_botones
	var g: BotonJutsu = botones["golpe"]
	var centro := Vector2(t.x - der - g.radio - 18 * s, t.y - aba - g.radio - 14 * s)
	for id in botones.keys():
		var b: BotonJutsu = botones[id]
		var anillo := int(b.get_meta("anillo"))
		if anillo == 0:
			b.centrar_en(centro)
			continue
		var r := (g.radio + b.radio + 38 * s) if anillo == 1 else (g.radio + 215 * s)
		var a := deg_to_rad(float(b.get_meta("angulo")))
		var p := centro + Vector2(cos(a), sin(a)) * r
		p.x = minf(p.x, t.x - der - b.radio - 4)
		b.centrar_en(p)
	# Zona de cancelar: a la izquierda del arco.
	var rc := 58.0 * s
	_cancelar_zona.size = Vector2(rc * 2, rc * 2)
	_cancelar_zona.position = centro + Vector2(-g.radio - 330 * s, -g.radio - 150 * s) - Vector2(rc, rc)
	_cancelar_zona.set_meta("radio", rc)
	retrato.position = Vector2(izq, arr)
	var ancho_e := minf(380, t.x * 0.28)
	_enemigo_panel.size = Vector2(ancho_e, 64)
	_enemigo_panel.position = Vector2((t.x - ancho_e) * 0.5, arr)
	_clima.position = Vector2(izq + 4, arr + 130)
	_fps.position = Vector2(izq + 4, arr + 156)
	if minimapa != null:
		minimapa.position = Vector2(izq + 4, arr + 186)
	if _boton_interactuar != null:
		_boton_interactuar.position = Vector2(t.x * 0.5 - 110, t.y - aba - 190)
		_boton_interactuar.size = Vector2(220, 70)
		_dialogo.position = Vector2(t.x * 0.5 - 340, t.y - aba - 330)
		_dialogo.size = Vector2(680, 120)
	var x := t.x - der
	var sup: Array = []
	for n in raiz.get_children():
		if n is Button and n.has_meta("superior"):
			sup.append(n)
	sup.reverse()
	for b in sup:
		x -= 134
		b.position = Vector2(x, arr)
		b.size = Vector2(126, 54)
	# Si el panel enemigo choca con el retrato o los botones, va debajo de los botones superiores.
	var libre_izq := retrato.position.x + retrato.size.x + 10
	if _enemigo_panel.position.x < libre_izq or _enemigo_panel.position.x + ancho_e > x - 8:
		_enemigo_panel.position = Vector2(t.x - der - ancho_e, arr + 64)
	_sellos_panel.position = Vector2(t.x * 0.5 - 320, t.y * 0.64)
	_sellos_panel.size = Vector2(640, 110)
	_mensaje.position = Vector2(0, t.y * 0.24)
	_mensaje.size = Vector2(t.x, 50)
	# En la franja libre bajo la barra superior: no tapa al personaje ni al retrato.
	_banner.size = Vector2(440, 78)
	_banner.position = Vector2(t.x * 0.5 - 220, maxf(arr + 140.0, t.y * 0.2))


func _sobre_cancelar(pos_global: Vector2) -> bool:
	var c := _cancelar_zona.position + _cancelar_zona.size * 0.5
	return pos_global.distance_to(c) <= float(_cancelar_zona.get_meta("radio", 58.0)) * 1.25


func _on_tocado(id: String) -> void:
	if id == "fijar":
		fijar_pedido.emit()
	else:
		accion.emit(id)


func _on_apuntando(id: String, arrastre: Vector2, sobre: bool) -> void:
	_cancelar_activo = true
	_cancelar_sobre = sobre
	_cancelar_zona.visible = true
	_cancelar_zona.queue_redraw()
	apuntar.emit(id, arrastre, sobre)


func _on_soltado(id: String, arrastre: Vector2) -> void:
	_cancelar_zona.visible = false
	soltar.emit(id, arrastre)


func _on_cancelado(id: String) -> void:
	_cancelar_zona.visible = false
	cancelar.emit(id)
	mensaje(Datos.texto("msg_cancelado"), 0.8)


func _dibujar_cancelar() -> void:
	var r := float(_cancelar_zona.get_meta("radio", 58.0))
	var c := Vector2(r, r)
	var col := Color(0.85, 0.1, 0.12, 0.9) if _cancelar_sobre else Color(0.2, 0.22, 0.26, 0.8)
	_cancelar_zona.draw_circle(c, r * (1.12 if _cancelar_sobre else 1.0), col)
	_cancelar_zona.draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.8), 3.0, true)
	Iconos.cancelar(_cancelar_zona, c - Vector2(0, 8), r * 0.5)
	Estilo.texto(_cancelar_zona, Vector2(0, c.y + r * 0.72), Datos.texto("hud_cancelar"), 18, Color.WHITE, r * 2, HORIZONTAL_ALIGNMENT_CENTER)


## Depuración: Auto (maestría) → N1 → N2 → N3 → Auto.
func _ciclar_nivel() -> void:
	nivel = (nivel + 1) % 4
	poner_nivel(nivel)
	nivel_pedido.emit(nivel)
	mensaje(Datos.texto("msg_nivel", [nivel]) if nivel > 0 else Datos.texto("hud_nivel_auto"))


func poner_nivel(n: int) -> void:
	nivel = n
	_boton_nivel.text = Datos.texto("hud_nivel", [nivel]) if nivel > 0 else Datos.texto("hud_nivel_auto")


func abrir_ajustes() -> void:
	var m := MenuAjustes.new()
	raiz.add_child(m)
	m.construir()
	m.cambiado.connect(aplicar_ajustes)
	m.reinicio_pedido.connect(func(): reinicio_pedido.emit())


## Refresca barras y botones con la instantánea del servidor.
func actualizar(j: Dictionary, enemigo: Dictionary) -> void:
	retrato.fijar("vida", j["vida"], j["vida_max"])
	retrato.fijar("chakra", j["chakra"], j["chakra_max"])
	retrato.fijar("estamina", j["estamina"], j["estamina_max"])
	var modo_activo := bool(j.get("modo_activo", false))
	sharingan_activo = modo_activo and str(j.get("modo", "")) in Tecnicas.OJOS
	retrato.sharingan = sharingan_activo
	var rec: Dictionary = j["recargas"]
	var niveles: Dictionary = j.get("niveles", {})
	var efectos: Dictionary = j.get("efectos", {})
	var attrs: Dictionary = atributos_jugador if not atributos_jugador.is_empty() else Datos.personaje(str(j["plantilla"])).get("atributos", {})
	for id in botones.keys():
		var b: BotonJutsu = botones[id]
		if id == "fijar":
			b.actualizar(0.0, 1.0, false, fijado, 0.0)
			continue
		var total := float(Datos.jutsu(id).get("recarga", 1.0))
		var sin_recurso := false
		var costo := 0.0
		var activo := false
		if id == "esquivar":
			sin_recurso = float(j["estamina"]) < float(Datos.jutsu(id).get("costo_estamina", 0))
		elif niveles.has(id):
			var es_modo: bool = id == modo_id
			activo = (es_modo and modo_activo) or (id == "susanoo" and efectos.has("susanoo"))
			if not activo:
				costo = Combate.costo_chakra(id, int(niveles[id]), attrs)
				sin_recurso = float(j["chakra"]) < costo
			b.nivel = int(niveles[id])
		b.actualizar(float(rec.get(id, 0.0)), total, sin_recurso, activo, costo)
	if enemigo.is_empty():
		_enemigo["visible"] = false
	else:
		_enemigo["visible"] = true
		_enemigo["nombre"] = str(Datos.personaje(str(enemigo["plantilla"])).get("nombre", ""))
		_enemigo["vida"] = float(enemigo["vida"])
		_enemigo["max"] = float(enemigo["vida_max"])
		# Inteligencia 3+: la debilidad elemental del rival.
		var nat_e := ""
		var nats: Array = Datos.personaje(str(enemigo["plantilla"])).get("naturalezas", [])
		if not nats.is_empty():
			nat_e = str(nats[0])
		var debil := ""
		if nat_e != "" and Atributos.ve_debilidad(atributos_jugador):
			for n in ["fuego", "viento", "rayo", "tierra", "agua"]:
				if Combate.multiplicador_naturaleza(n, nat_e) > 1.01:
					debil = Datos.nombre_naturaleza(n)
		_enemigo["debil"] = debil


func _dibujar_enemigo() -> void:
	if not _enemigo["visible"]:
		return
	var r := Rect2(Vector2.ZERO, _enemigo_panel.size)
	Estilo.dibujar_marco(_enemigo_panel, r, 0.8, false)
	Estilo.texto(_enemigo_panel, Vector2(14, 26), str(_enemigo["nombre"]), 20, Estilo.PAPEL, r.size.x - 28, HORIZONTAL_ALIGNMENT_LEFT, Estilo.fuente_titulo(), 5)
	var barra := Rect2(Vector2(14, 34), Vector2(r.size.x - 28, 18))
	_enemigo_panel.draw_rect(barra, Color(0.02, 0.02, 0.03, 0.9))
	var frac := clampf(float(_enemigo["vida"]) / maxf(float(_enemigo["max"]), 1.0), 0.0, 1.0)
	_enemigo_panel.draw_rect(Rect2(barra.position, Vector2(barra.size.x * float(_enemigo["mostrado"]), barra.size.y)), Color(1, 0.9, 0.8, 0.5))
	_enemigo_panel.draw_rect(Rect2(barra.position, Vector2(barra.size.x * frac, barra.size.y)), Color(0.82, 0.16, 0.14))
	_enemigo_panel.draw_rect(Rect2(barra.position, Vector2(barra.size.x * frac, barra.size.y * 0.4)), Color(1, 0.6, 0.5, 0.35))
	_enemigo_panel.draw_rect(barra, Estilo.ACERO_BORDE, false, 1.5)
	# Inteligencia 1+: la vida en números; 3+: su debilidad.
	if Atributos.ve_vida(atributos_jugador):
		Estilo.texto(_enemigo_panel, Vector2(barra.position.x, barra.position.y + 15), "%d / %d" % [mini(int(ceil(float(_enemigo["vida"]))), int(round(float(_enemigo["max"])))), int(round(float(_enemigo["max"])))], 17, Color.WHITE, barra.size.x - 6, HORIZONTAL_ALIGNMENT_RIGHT)
	if str(_enemigo.get("debil", "")) != "":
		Estilo.texto(_enemigo_panel, Vector2(14, barra.end.y + 18), Datos.texto("hud_debil", [_enemigo["debil"]]), 15, Color(1.0, 0.85, 0.4), r.size.x - 28, HORIZONTAL_ALIGNMENT_LEFT)


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
	_banner_txt = txt
	_banner_sub = sub
	_banner.visible = txt != ""
	_banner.modulate.a = 1.0
	_banner_t = BANNER_DURACION if txt != "" else 0.0
	_banner.queue_redraw()


func _dibujar_banner() -> void:
	var r := Rect2(Vector2.ZERO, _banner.size)
	Estilo.dibujar_pergamino(_banner, r, 0.95)
	Estilo.texto(_banner, Vector2(0, 40), _banner_txt, 30, Color(0.55, 0.06, 0.08), r.size.x, HORIZONTAL_ALIGNMENT_CENTER, Estilo.fuente_titulo(), 0)
	Estilo.texto(_banner, Vector2(0, 64), _banner_sub, 16, Color(0.2, 0.15, 0.12), r.size.x, HORIZONTAL_ALIGNMENT_CENTER, Estilo.fuente_ui(), 0)


func _process(delta: float) -> void:
	if _lineas_t > 0.0 and _lineas != null:
		# En tiempo real: el hitstop no las congela.
		_lineas_t -= delta / maxf(Engine.time_scale, 0.05)
		_lineas.visible = _lineas_t > 0.0
		_lineas.queue_redraw()
	if _genjutsu_t > 0.0 and _genjutsu != null:
		_genjutsu_t -= delta
		var k := clampf(minf(_genjutsu_t, _genjutsu_total - _genjutsu_t) / 0.5, 0.0, 1.0)
		(_genjutsu.material as ShaderMaterial).set_shader_parameter("intensidad", k)
		_genjutsu.visible = _genjutsu_t > 0.0
	if _dialogo_t > 0.0:
		_dialogo_t -= delta
		if _dialogo_t <= 0.0 and _dialogo != null:
			_dialogo.visible = false
	# El letrero se desvanece solo (en tiempo real: la cámara lenta no lo alarga).
	if _banner_t > 0.0:
		_banner_t -= delta / maxf(Engine.time_scale, 0.05)
		_banner.modulate.a = clampf(_banner_t / 0.6, 0.0, 1.0)
		if _banner_t <= 0.0:
			_banner.visible = false
	if _mensaje_t > 0.0:
		_mensaje_t -= delta
		_mensaje.modulate.a = clampf(_mensaje_t / 0.5, 0.0, 1.0)
	var objetivo := 1.0 if sharingan_activo else 0.0
	if absf(_overlay_val - objetivo) > 0.001:
		_overlay_val = move_toward(_overlay_val, objetivo, delta * 3.0)
		_overlay_mat.set_shader_parameter("intensidad", _overlay_val)
	_overlay.visible = _overlay_val > 0.001
	if _enemigo["visible"]:
		var frac := clampf(float(_enemigo["vida"]) / maxf(float(_enemigo["max"]), 1.0), 0.0, 1.0)
		_enemigo["mostrado"] = maxf(frac, move_toward(float(_enemigo["mostrado"]), frac, delta * 0.5))
	_enemigo_panel.queue_redraw()
	if _fps.visible:
		_diag_t -= delta / maxf(Engine.time_scale, 0.05)
		if _diag_t <= 0.0:
			_diag_t = 0.25
			_fps.text = texto_diagnostico()
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
	var tam := 72.0
	var sep := 14.0
	var ancho := n * tam + (n - 1) * sep
	var x0 := (_sellos_panel.size.x - ancho) * 0.5
	var progreso := _sellos_t / _sellos_dur * n
	var alfa := clampf(1.0 - (_sellos_t - _sellos_dur) / 0.5, 0.0, 1.0)
	for i in n:
		var id := str(_sellos[i])
		var datos: Dictionary = Datos.mundo.get("sellos", {}).get(id, {})
		var col := Datos.color(str(datos.get("color", "#cccccc")))
		var hecho := progreso >= float(i)
		var actual := hecho and progreso < float(i + 1)
		var c := Vector2(x0 + i * (tam + sep) + tam * 0.5, tam * 0.5)
		var r := tam * 0.5 * (1.15 if actual else 1.0)
		# Placa de rombo metálico.
		var rombo := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		var fondo := col if hecho else col.darkened(0.75)
		_sellos_panel.draw_colored_polygon(rombo, Color(fondo.r, fondo.g, fondo.b, 0.92 * alfa))
		var cerrado := rombo.duplicate()
		cerrado.append(rombo[0])
		_sellos_panel.draw_polyline(cerrado, Color(1, 1, 1, (0.95 if hecho else 0.3) * alfa), 3.0, true)
		var nombre := str(datos.get("nombre", id))
		Estilo.texto(_sellos_panel, Vector2(c.x - tam * 0.5, c.y + 15), nombre.substr(0, 1), 38, Color(1, 1, 1, alfa), tam, HORIZONTAL_ALIGNMENT_CENTER, Estilo.fuente_titulo(), 6)
		Estilo.texto(_sellos_panel, Vector2(c.x - tam * 0.5 - 10, tam + 26), nombre, 19, Color(1, 1, 1, alfa), tam + 20, HORIZONTAL_ALIGNMENT_CENTER)


## Panel de diagnóstico: FPS, tiempo de fotograma, draw calls, partículas y, en red, ping, pérdida y jugadores.
func texto_diagnostico() -> String:
	var fps := Engine.get_frames_per_second()
	var ms := 1000.0 / maxf(fps, 1.0)
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var parts := 0
	for p in get_tree().get_nodes_in_group("particulas"):
		var gp := p as GPUParticles3D
		if gp != null and gp.emitting and gp.is_visible_in_tree():
			parts += gp.amount
	var t := Datos.texto("diag_linea", [fps, Ajustes.fps_limite(), "%.1f" % ms, dc, parts])
	if not diag_red.is_empty():
		t += "\n" + Datos.texto("diag_red", [int(diag_red.get("ping", 0)), "%.0f" % (float(diag_red.get("perdida", 0.0)) * 100.0),
			int(diag_red.get("jugadores", 1))])
		if diag_red.get("simulado", false):
			t += "  " + Datos.texto("diag_simulado")
	return t


## Texto fijo de la red (IP del anfitrión, "Conectando…"); vacío lo oculta.
func poner_info_red(t: String) -> void:
	if _info_red == null:
		return
	_info_red.text = t
	_info_red.visible = t != ""
	var vp := get_viewport().get_visible_rect().size
	_info_red.size = Vector2(vp.x, 30)
	_info_red.position = Vector2(0, vp.y - 40)


## Retrato 3D del jugador (se conserva si la interfaz se reconstruye al cambiar de repertorio).
func configurar_retrato(asp: Dictionary, clan: String, nombre: String, plantilla: String) -> void:
	_retrato_conf = [asp, clan, nombre, plantilla]
	retrato.configurar(asp, clan, nombre, plantilla)


## Mapa de la aldea completa: minimapa en la esquina y botón «Mapa» (se llama antes de construir).
func configurar_mapa(m: Mapa) -> void:
	_mapa = m


## Posiciones para el minimapa y el mapa completo (cada snapshot).
var _marcas: Array = []   # [{pos: Vector2, color, hasta (ms)}] — emboscadas vistas antes de tiempo (Inteligencia 4)


func marca_minimapa(pos: Vector3, segundos: float, color: Color) -> void:
	_marcas.append({"pos": Vector2(pos.x, pos.z), "color": color, "hasta": Time.get_ticks_msec() + int(segundos * 1000.0)})


func actualizar_mapa(yo: Vector2, yaw: float, otros: Array) -> void:
	var ahora := Time.get_ticks_msec()
	_marcas = _marcas.filter(func(m): return int(m["hasta"]) > ahora)
	if not _marcas.is_empty():
		otros = otros.duplicate()
		for m in _marcas:
			otros.append({"pos": m["pos"], "color": m["color"] if (ahora / 250) % 2 == 0 else Color(1, 1, 1)})
	if minimapa != null:
		minimapa.actualizar(yo, yaw, otros)
	if mapa_completo != null and is_instance_valid(mapa_completo):
		mapa_completo.actualizar(yo, otros)


func abrir_mapa() -> void:
	if _mapa == null:
		return
	if mapa_completo != null and is_instance_valid(mapa_completo):
		mapa_completo.queue_free()
		mapa_completo = null
		return
	mapa_completo = MapaCompleto.new()
	raiz.add_child(mapa_completo)
	mapa_completo.configurar(_mapa)
	mapa_completo.viajar.connect(func(id):
		viajar_pedido.emit(id)
		mapa_completo.queue_free()
		mapa_completo = null)
	mapa_completo.cerrar.connect(func():
		mapa_completo.queue_free()
		mapa_completo = null)


func mostrar_interactuar(visible_: bool) -> void:
	if _boton_interactuar != null:
		_boton_interactuar.visible = visible_


## Globo de diálogo abajo al centro durante unos segundos.
func dialogo(texto: String, segundos := 4.5) -> void:
	if _dialogo == null:
		return
	_dialogo_txt.text = texto
	_dialogo.visible = true
	_dialogo_t = segundos
	_reordenar()


## Genjutsu: nubla y hace girar la pantalla durante «segundos» (entra y sale suave).
## Destello blanco a pantalla completa (impacto del Kirin): aparece de golpe y se apaga.
var _destello_ms := 0


func destello_pantalla(segundos: float, intensidad := 0.95) -> void:
	# Uno solo por ráfaga (el Kirin de nivel 3 cae varias veces seguidas).
	if Time.get_ticks_msec() - _destello_ms < 1500:
		return
	_destello_ms = Time.get_ticks_msec()
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, intensidad)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var tw := create_tween()
	tw.tween_interval(segundos * 0.15)
	tw.tween_property(r, "color:a", 0.0, segundos * 0.85).set_ease(Tween.EASE_IN)
	tw.tween_callback(r.queue_free)


## Genjutsu sobre el jugador: «oscuridad» (pantalla casi negra) o «miedo» (rojo que late). Se quitan con quitar_genjutsu().
var _velo_gen: ColorRect


func velo_genjutsu(tipo: String, segundos: float) -> void:
	quitar_genjutsu()
	_velo_gen = ColorRect.new()
	_velo_gen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo_gen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_velo_gen)
	move_child(_velo_gen, 0)
	var tw := _velo_gen.create_tween()
	if tipo == "ciego":
		_velo_gen.color = Color(0.0, 0.0, 0.02, 0.0)
		tw.tween_property(_velo_gen, "color:a", 0.88, 0.3)
		tw.tween_interval(maxf(segundos - 0.8, 0.1))
		tw.tween_property(_velo_gen, "color:a", 0.0, 0.5)
	else:
		_velo_gen.color = Color(0.5, 0.0, 0.03, 0.0)
		var n := int(segundos / 0.6)
		for i in n:
			tw.tween_property(_velo_gen, "color:a", 0.45, 0.3)
			tw.tween_property(_velo_gen, "color:a", 0.15, 0.3)
		tw.tween_property(_velo_gen, "color:a", 0.0, 0.3)
	tw.tween_callback(quitar_genjutsu)


func quitar_genjutsu() -> void:
	if _velo_gen != null and is_instance_valid(_velo_gen):
		_velo_gen.queue_free()
	_velo_gen = null
	_genjutsu_t = 0.0


## Líneas de velocidad de anime (golpes fuertes): rayas radiales desde los bordes hacia el centro.
func lineas_velocidad(segundos: float) -> void:
	if _lineas == null:
		_lineas = Control.new()
		_lineas.set_anchors_preset(Control.PRESET_FULL_RECT)
		_lineas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lineas.draw.connect(_dibujar_lineas)
		add_child(_lineas)
		move_child(_lineas, 0)
	_lineas_total = segundos
	_lineas_t = segundos
	_lineas.visible = true


func _dibujar_lineas() -> void:
	var tam := _lineas.size
	var c := tam * 0.5
	var radio := tam.length() * 0.55
	var k := clampf(_lineas_t / maxf(_lineas_total, 0.01), 0.0, 1.0)
	for i in 46:
		var a := randf() * TAU
		var dirv := Vector2(cos(a), sin(a))
		var interior := radio * randf_range(0.42, 0.62)
		var col := Color(1, 1, 1, 0.55 * k) if i % 3 else Color(0.05, 0.05, 0.08, 0.45 * k)
		_lineas.draw_line(c + dirv * interior, c + dirv * radio, col, randf_range(1.5, 4.5))


func genjutsu(segundos: float) -> void:
	_genjutsu_total = segundos
	_genjutsu_t = segundos
	if _genjutsu != null:
		_genjutsu.visible = true
