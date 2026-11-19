extends Control
## Ficha del personaje: rango y experiencia (con lo que falta para ascender), puntos de atributo por repartir,
## los 8 atributos con su efecto actual y su barra de entrenamiento, y Reserva/Control de chakra.
## Los puntos nuevos se reparten con «+» (y se pueden quitar antes de guardar).

const ESCENA_MENU := "res://escenas/menu.tscn"

var _pj: Dictionary = {}
var _attrs: Dictionary = {}
var _base: Dictionary = {}      # atributos al abrir (no se puede bajar de aquí)
var _filas: Dictionary = {}     # atributo -> {puntos: Label, ef1: Label, ef2: Label, barra: ProgressBar, mas, menos}
var _puntos: Label
var _derivados: Label
var _guardar: Button
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
	if _pj.is_empty():
		_pj = {"nombre": Perfil.nombre_activo(), "rango": str(Datos.personaje(Perfil.PLANTILLA).get("rango", "genin")),
			"atributos": Datos.personaje(Perfil.PLANTILLA).get("atributos", {}).duplicate()}
		_pj["puntos_legado"] = Creacion.total_puntos(_pj["atributos"])   # plantilla de práctica: sin tope de rango
	_attrs = (_pj.get("atributos", {}) as Dictionary).duplicate()
	_base = _attrs.duplicate()
	_construir()
	_refrescar()
	_animar_entrada()


func _construir() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 16)
	add_child(margen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margen.add_child(col)
	# --- cabecera: nombre, rango, experiencia
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 16)
	col.add_child(cab)
	var titulo := _label(Datos.texto("ficha_titulo", [str(_pj.get("nombre", ""))]), 30, Estilo.PAPEL, true)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(titulo)
	cab.add_child(_label(Datos.texto("rango_" + str(_pj.get("rango", "genin"))), 26, Color(1.0, 0.82, 0.45), true))
	cab.add_child(_label(Datos.texto("ficha_ryo", [int(_pj.get("ryo", 0))]), 22, Color(0.95, 0.85, 0.5)))
	var asc := Creacion.ascenso(_pj)
	var xp_caja := VBoxContainer.new()
	col.add_child(xp_caja)
	if str(asc["siguiente"]) != "":
		var barra_xp := ProgressBar.new()
		barra_xp.custom_minimum_size = Vector2(0, 16)
		barra_xp.show_percentage = false
		barra_xp.max_value = maxf(float(asc["xp_necesaria"]), 1.0)
		barra_xp.value = minf(float(asc["xp"]), barra_xp.max_value)
		xp_caja.add_child(barra_xp)
		var falta := Datos.texto("ficha_ascenso", [Datos.texto("rango_" + str(asc["siguiente"])), int(asc["xp"]), int(asc["xp_necesaria"]),
			Datos.texto("prueba_" + str(asc["prueba"]))])
		if bool(asc["listo_xp"]):
			falta = Datos.texto("ficha_ascenso_listo", [Datos.texto("prueba_" + str(asc["prueba"]))])
		xp_caja.add_child(_label(falta, 18, Color(0.75, 0.82, 0.92)))
	else:
		xp_caja.add_child(_label(Datos.texto("ficha_rango_max"), 18, Color(0.75, 0.82, 0.92)))
	_puntos = _label("", 22, Estilo.TEXTO, true)
	col.add_child(_puntos)
	# --- atributos (dos columnas)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	for a in Atributos.LISTA:
		grid.add_child(_fila(a))
	_derivados = _label("", 18, Color(0.7, 0.85, 1.0))
	col.add_child(_derivados)
	# --- botones
	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 12)
	col.add_child(pie)
	var volver := _boton(Datos.texto("ficha_volver"), func(): get_tree().change_scene_to_file(ESCENA_MENU))
	pie.add_child(volver)
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(esp)
	_guardar = _boton(Datos.texto("ficha_guardar"), _guardar_cambios)
	pie.add_child(_guardar)


func _fila(a: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 92)
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	panel.add_child(caja)
	var izq := VBoxContainer.new()
	izq.custom_minimum_size = Vector2(170, 0)
	caja.add_child(izq)
	izq.add_child(_label(Datos.texto("attr_" + a), 22, Estilo.PAPEL, true))
	var pts := _label("", 24, Color(1.0, 0.82, 0.45))
	izq.add_child(pts)
	var barra := ProgressBar.new()
	barra.custom_minimum_size = Vector2(150, 8)
	barra.show_percentage = false
	barra.max_value = 1.0
	barra.tooltip_text = Datos.texto("ficha_entreno")
	izq.add_child(barra)
	var med := VBoxContainer.new()
	med.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(med)
	var ef1 := _label("", 17, Estilo.TEXTO)
	var ef2 := _label("", 15, Color(0.72, 0.78, 0.86))
	ef1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ef2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	med.add_child(ef1)
	med.add_child(ef2)
	var menos := _boton("−", func(): _cambiar(a, -1))
	var mas := _boton("+", func(): _cambiar(a, 1))
	menos.custom_minimum_size = Vector2(52, 52)
	mas.custom_minimum_size = Vector2(52, 52)
	caja.add_child(menos)
	caja.add_child(mas)
	_filas[a] = {"puntos": pts, "ef1": ef1, "ef2": ef2, "barra": barra, "mas": mas, "menos": menos, "panel": panel}
	return panel


func _cambiar(a: String, d: int) -> void:
	var nuevo := int(_attrs.get(a, 0)) + d
	if nuevo < int(_base.get(a, 0)) or nuevo > 5:
		return
	if d > 0 and Creacion.total_puntos(_attrs) >= Creacion.tope_puntos(_pj):
		return
	_attrs[a] = nuevo
	_sonidos.tocar("golpe", -14.0, 2.6 if d > 0 else 1.8)
	var p: Control = _filas[a]["panel"]
	p.pivot_offset = p.size * 0.5
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2(1.03, 1.03), 0.06)
	tw.tween_property(p, "scale", Vector2.ONE, 0.1)
	_refrescar()


func _refrescar() -> void:
	var tope := Creacion.tope_puntos(_pj)
	var usados := Creacion.total_puntos(_attrs)
	_puntos.text = Datos.texto("ficha_puntos", [usados, tope, maxi(tope - usados, 0)])
	var ent: Dictionary = _pj.get("entreno", {})
	var con_entreno := _attrs.duplicate()
	var bonus := {}
	for k in ent.keys():
		bonus[k] = float(ent[k]) * float(Datos.reglas.get("entrenamiento", {}).get("bonus_max", 0.5))
	con_entreno["_entreno"] = bonus
	for a in Atributos.LISTA:
		var f: Dictionary = _filas[a]
		var n := int(_attrs.get(a, 0))
		var extra := float(bonus.get(a, 0.0))
		(f["puntos"] as Label).text = "●".repeat(n) + "○".repeat(5 - n) + ("  +%.1f" % extra if extra >= 0.05 else "")
		var lineas := Atributos.efectos_texto(a, con_entreno)
		(f["ef1"] as Label).text = str(lineas[0]) if lineas.size() > 0 else ""
		(f["ef2"] as Label).text = str(lineas[1]) if lineas.size() > 1 else ""
		(f["barra"] as ProgressBar).value = float(ent.get(a, 0.0))
		(f["mas"] as Button).disabled = n >= 5 or usados >= tope
		(f["menos"] as Button).disabled = n <= int(_base.get(a, 0))
	var st := Combate.estadisticas(con_entreno)
	_derivados.text = Datos.texto("ficha_derivados", [int(st["vida_max"]), int(st["chakra_max"]), int(st["estamina_max"]),
		"%.1f" % float(st["reserva"]), "%.1f" % float(st["control"]), int(round(float(ent.get("control", 0.0)) * 100.0))])
	_guardar.disabled = _attrs == _base


func _guardar_cambios() -> void:
	if Perfil.indice < 0:
		return
	(Perfil.personajes[Perfil.indice] as Dictionary)["atributos"] = _attrs.duplicate()
	Perfil.guardar()
	_base = _attrs.duplicate()
	_sonidos.tocar("trueno", -18.0, 2.0)
	_refrescar()


func _animar_entrada() -> void:
	var i := 0
	for a in Atributos.LISTA:
		var p: Control = _filas[a]["panel"]
		p.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.04 * i)
		tw.tween_property(p, "modulate:a", 1.0, 0.25)
		i += 1


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
	b.custom_minimum_size = Vector2(160, 56)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b


## Prueba de humo: sube y baja un atributo.
func prueba_humo(cuadro: int) -> void:
	match cuadro:
		3: _cambiar("ninjutsu", 1)
		5: _cambiar("ninjutsu", -1)
