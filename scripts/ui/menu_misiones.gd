extends Control
## Misiones, pergaminos y cosméticos: los capítulos de la historia (cumplidos, el siguiente y los bloqueados),
## los eventos que aparecen solos, los pergaminos aprendidos (qué jutsu enseña cada uno) y los cosméticos
## ganados (se equipan aquí y cambian el aspecto del personaje).

const ESCENA_MENU := "res://escenas/menu.tscn"
const ESCENA_JUEGO := "res://escenas/juego.tscn"

var _pj: Dictionary = {}
var _contenido: VBoxContainer
var _pestana := "historia"
var _botones: Dictionary = {}
var _sonidos: Sonidos


func _ready() -> void:
	Datos.cargar()
	Ajustes.cargar()
	Perfil.cargar()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Estilo.tema()
	_sonidos = Sonidos.new()
	add_child(_sonidos)
	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.07, 0.08, 0.11)
	add_child(fondo)
	_pj = Perfil.personaje()
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 16)
	add_child(margen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margen.add_child(col)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 10)
	col.add_child(cab)
	var t := _label(Datos.texto("mis_titulo"), 30, Estilo.PAPEL, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(t)
	for p in [["historia", Datos.texto("mis_historia")], ["pergaminos", Datos.texto("mis_pergaminos")], ["cosmeticos", Datos.texto("mis_cosmeticos")]]:
		var b := _boton(str(p[1]), func():
			_pestana = str(p[0])
			_sonidos.tocar("papel", -10.0, 1.2)
			_llenar())
		b.toggle_mode = true
		_botones[p[0]] = b
		cab.add_child(b)
	cab.add_child(_label(Datos.texto("ficha_ryo", [int(_pj.get("ryo", 0))]), 22, Color(0.95, 0.85, 0.5)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 8)
	scroll.add_child(_contenido)
	col.add_child(_boton(Datos.texto("ficha_volver"), func(): get_tree().change_scene_to_file(ESCENA_MENU)))
	_llenar()


func _llenar() -> void:
	for b in _botones.keys():
		(_botones[b] as Button).set_pressed_no_signal(b == _pestana)
	for h in _contenido.get_children():
		h.queue_free()
	match _pestana:
		"historia":
			var mis: Dictionary = _pj.get("misiones", {})
			var sig := int(mis.get("capitulo", 0))
			var caps: Array = Misiones.conf().get("capitulos", [])
			for i in caps.size():
				var c: Dictionary = caps[i]
				var estado := "hecho" if i < sig else ("siguiente" if i == sig else "bloqueado")
				_contenido.add_child(_tarjeta_capitulo(i, c, estado))
			_contenido.add_child(_label(Datos.texto("mis_eventos"), 18, Color(0.75, 0.82, 0.92)))
		"pergaminos":
			var perg: Array = _pj.get("pergaminos", [])
			if perg.is_empty():
				_contenido.add_child(_label(Datos.texto("mis_sin_pergaminos"), 20, Color(0.75, 0.82, 0.92)))
			for p in perg:
				var j := Datos.jutsu(str(p))
				_contenido.add_child(_fila(str(j.get("nombre", p)), Datos.texto("mis_pergamino_desc", [Datos.texto("clase_" + str(j.get("clase", "ninjutsu"))), Repertorio.texto_requisito(str(p))]), Color(0.95, 0.75, 1.0)))
		"cosmeticos":
			var cos: Array = _pj.get("cosmeticos", [])
			if cos.is_empty():
				_contenido.add_child(_label(Datos.texto("mis_sin_cosmeticos"), 20, Color(0.75, 0.82, 0.92)))
			for c in cos:
				var cd: Dictionary = Misiones.conf().get("cosmeticos", {}).get(str(c), {})
				var fila := _fila(str(cd.get("nombre", c)), str(cd.get("tipo", "")), Color(0.7, 1.0, 0.8))
				var id_c := str(c)
				var eq := _boton(Datos.texto("mis_equipar"), func():
					if Perfil.equipar_cosmetico(id_c):
						Perfil.guardar()
						_pj = Perfil.personaje()
						_sonidos.tocar("campana", -12.0, 1.4))
				fila.add_child(eq)
				_contenido.add_child(fila)
	# Entrada animada.
	var k := 0
	for h in _contenido.get_children():
		(h as Control).modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.04 * k)
		tw.tween_property(h, "modulate:a", 1.0, 0.25)
		k += 1


func _tarjeta_capitulo(i: int, c: Dictionary, estado: String) -> Control:
	var col := {"hecho": Color(0.55, 0.85, 0.55), "siguiente": Color(1.0, 0.82, 0.45), "bloqueado": Color(0.5, 0.52, 0.58)}[estado] as Color
	var fila := _fila(Datos.texto("mis_capitulo", [i + 1, str(c["titulo"])]), str(c.get("resumen", "")), col)
	var rec: Dictionary = c.get("recompensa", {})
	var extra := Datos.texto("mis_recompensa", [int(rec.get("xp", 0)), int(rec.get("ryo", 0))])
	fila.add_child(_label(extra, 16, Color(0.9, 0.85, 0.6)))
	if estado == "siguiente" or estado == "hecho":
		var id := str(c["id"])
		var b := _boton(Datos.texto("mis_jugar") if estado == "siguiente" else Datos.texto("mis_repetir"), func():
			Sesion.mision_pendiente = id
			Sesion.modo = "offline"
			get_tree().change_scene_to_file(ESCENA_JUEGO))
		fila.add_child(b)
	else:
		fila.add_child(_label(Datos.texto("mis_bloqueado"), 18, col))
	return fila


func _fila(titulo: String, sub: String, color: Color) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(_label(titulo, 24, color, true))
	var s := _label(sub, 17, Color(0.8, 0.84, 0.9))
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(s)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(caja)
	fila.add_child(panel)
	return fila


func _label(t: String, tam: int, c: Color, titulo := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", c)
	if titulo:
		l.add_theme_font_override("font", Estilo.fuente_titulo())
	return l


func _boton(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b


## Prueba de humo: recorrer las pestañas.
func prueba_humo(cuadro: int) -> void:
	match cuadro:
		3:
			_pestana = "pergaminos"
			_llenar()
		5:
			_pestana = "cosmeticos"
			_llenar()
