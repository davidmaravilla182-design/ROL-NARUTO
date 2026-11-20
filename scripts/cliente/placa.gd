class_name Placa
extends Node3D
## Nombre y barra de vida sobre un personaje (siempre mirando a la cámara).

var _nombre: Label3D
var prefijo := ""   # «ALIADO · » para los compañeros de equipo en red
var _fondo: MeshInstance3D
var _barra: MeshInstance3D
const ANCHO := 0.9


func construir(texto: String, color: Color) -> void:
	position = Vector3(0, 2.25, 0)
	_nombre = Label3D.new()
	_nombre.text = texto
	_nombre.font_size = 40
	_nombre.pixel_size = 0.006
	_nombre.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nombre.no_depth_test = true
	_nombre.modulate = color
	_nombre.outline_size = 10
	_nombre.outline_modulate = Color(0, 0, 0, 0.9)
	_nombre.position = Vector3(0, 0.16, 0)
	_nombre.font = Estilo.fuente_ui()
	add_child(_nombre)
	_fondo = _quad(Color(0.05, 0.05, 0.07, 0.85), Vector2(ANCHO + 0.04, 0.11))
	_barra = _quad(Color(0.9, 0.2, 0.2), Vector2(ANCHO, 0.07))
	_barra.position.z = 0.001


func _quad(c: Color, tam: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = tam
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.render_priority = 2
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func poner_color(c: Color) -> void:
	_nombre.modulate = c


func actualizar(texto: String, frac: float) -> void:
	texto = prefijo + texto
	if _nombre.text != texto:
		_nombre.text = texto
	frac = clampf(frac, 0.0, 1.0)
	# La barra se encoge hacia la izquierda (en espacio de pantalla, por el billboard).
	_barra.scale = Vector3(maxf(frac, 0.001), 1, 1)
	(_barra.material_override as StandardMaterial3D).albedo_color = Color(0.25, 0.85, 0.35).lerp(Color(0.9, 0.2, 0.2), 1.0 - frac)
	visible = frac > 0.0
