extends Control
## Unirse a una partida local: lista las partidas que se anuncian en el mismo Wi-Fi
## y permite escribir la IP que muestra el anfitrión.

const ESCENA_JUEGO := "res://escenas/juego.tscn"
const ESCENA_MENU := "res://escenas/menu.tscn"
const RUTA_IP := "user://ultima_ip.txt"

var _lista: VBoxContainer
var _ip: LineEdit
var _aviso: Label
var _desc: Descubrimiento


func _ready() -> void:
	Datos.cargar()
	Ajustes.cargar()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Estilo.tema()
	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.06, 0.07, 0.1)
	add_child(fondo)
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 24)
	add_child(margen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margen.add_child(col)
	var t := Label.new()
	t.text = Datos.texto("red_titulo")
	t.add_theme_font_override("font", Estilo.fuente_titulo())
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", Estilo.PAPEL)
	col.add_child(t)
	var buscando := Label.new()
	buscando.text = Datos.texto("red_buscando")
	buscando.add_theme_font_size_override("font_size", 20)
	col.add_child(buscando)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 8)
	scroll.add_child(_lista)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	col.add_child(fila)
	var l := Label.new()
	l.text = Datos.texto("red_ip")
	l.add_theme_font_size_override("font_size", 22)
	fila.add_child(l)
	_ip = LineEdit.new()
	_ip.custom_minimum_size = Vector2(320, 58)
	_ip.add_theme_font_size_override("font_size", 26)
	_ip.placeholder_text = "192.168.1.20"
	_ip.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	if FileAccess.file_exists(RUTA_IP):
		_ip.text = FileAccess.get_file_as_string(RUTA_IP).strip_edges()
	fila.add_child(_ip)
	fila.add_child(_boton(Datos.texto("red_conectar"), func(): conectar(_ip.text)))
	_aviso = Label.new()
	_aviso.add_theme_font_size_override("font_size", 18)
	_aviso.add_theme_color_override("font_color", Color(1.0, 0.65, 0.5))
	col.add_child(_aviso)
	col.add_child(_boton(Datos.texto("red_volver"), func(): get_tree().change_scene_to_file(ESCENA_MENU)))
	_desc = Descubrimiento.new()
	add_child(_desc)
	_desc.escuchar()
	_desc.partidas_cambiaron.connect(_mostrar)
	_mostrar({})


func _boton(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(180, 58)
	b.pressed.connect(cb)
	return b


func _mostrar(partidas: Dictionary) -> void:
	for h in _lista.get_children():
		h.queue_free()
	if partidas.is_empty():
		var n := Label.new()
		n.text = Datos.texto("red_ninguna")
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.add_theme_font_size_override("font_size", 18)
		n.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		_lista.add_child(n)
		return
	for ip in partidas.keys():
		var p: Dictionary = partidas[ip]
		var b := _boton(Datos.texto("red_partida", [p.get("nombre", "?"), int(p.get("jugadores", 1)), int(p.get("max", 4)), ip]), func(): conectar(str(ip)))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_lista.add_child(b)


func conectar(ip: String) -> void:
	ip = ip.strip_edges()
	if not ip.is_valid_ip_address():
		_aviso.text = Datos.texto("red_ip_invalida")
		return
	var f := FileAccess.open(RUTA_IP, FileAccess.WRITE)
	if f != null:
		f.store_string(ip)
	Sesion.modo = "cliente"
	Sesion.direccion = ip
	get_tree().change_scene_to_file(ESCENA_JUEGO)
