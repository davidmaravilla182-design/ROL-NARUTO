class_name Rayos
extends MeshInstance3D
## Rayos ramificados generados por código y dibujados como cintas que miran a la cámara
## en un único ImmediateMesh (una sola llamada de dibujo por sistema de rayos).
## Uso: rayos.limpiar(); rayos.agregar_rayo(a, b, grosor, ramas); rayos.dibujar(camara)

var _segmentos: Array = []   # [a, b, grosor, brillo]
var _im: ImmediateMesh
var color := Color(0.75, 0.9, 1.0)
var intensidad := 2.0


func _init() -> void:
	_im = ImmediateMesh.new()
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	material_override = m
	top_level = true


func limpiar() -> void:
	_segmentos.clear()


## Agrega un rayo de a hasta b con desplazamiento del punto medio y ramas secundarias.
func agregar_rayo(a: Vector3, b: Vector3, grosor: float, ramas := 2, desvio := 0.25, profundidad := 4) -> void:
	_subdividir(a, b, grosor, desvio * a.distance_to(b), profundidad, ramas, 1.0)


func _subdividir(a: Vector3, b: Vector3, grosor: float, desvio: float, prof: int, ramas: int, brillo: float) -> void:
	if prof <= 0 or a.distance_to(b) < 0.05:
		_segmentos.append([a, b, grosor, brillo])
		return
	var medio := (a + b) * 0.5 + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * desvio
	_subdividir(a, medio, grosor, desvio * 0.55, prof - 1, ramas, brillo)
	_subdividir(medio, b, grosor, desvio * 0.55, prof - 1, ramas, brillo)
	if ramas > 0 and randf() < 0.55:
		var dir := (b - a)
		var fin := medio + dir.rotated(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(), randf_range(-0.9, 0.9)) * randf_range(0.3, 0.6)
		_subdividir(medio, fin, grosor * 0.55, desvio * 0.5, prof - 2, ramas - 1, brillo * 0.7)


## Reconstruye la malla con cintas orientadas hacia la cámara.
func dibujar(cam_pos: Vector3) -> void:
	_im.clear_surfaces()
	if _segmentos.is_empty():
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in _segmentos:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var g: float = s[2]
		var br: float = s[3]
		var eje := b - a
		var vista := ((a + b) * 0.5 - cam_pos).normalized()
		var lado := eje.cross(vista).normalized() * g
		if not lado.is_finite():
			continue
		# Núcleo blanco y halo de color: dos cintas.
		for capa in 2:
			var ancho := lado * (2.6 if capa == 0 else 0.8)
			var c := Color(color.r, color.g, color.b, 0.35 * br) if capa == 0 else Color(1, 1, 1, br)
			c = Color(c.r * intensidad, c.g * intensidad, c.b * intensidad, c.a)
			for v in [a - ancho, a + ancho, b + ancho, a - ancho, b + ancho, b - ancho]:
				_im.surface_set_color(c)
				_im.surface_add_vertex(v)
	_im.surface_end()
