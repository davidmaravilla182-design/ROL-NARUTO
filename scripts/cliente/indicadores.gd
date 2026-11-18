class_name Indicadores
extends Node3D
## Indicadores visuales del cliente:
## - Apuntado en el suelo mientras se mantiene un jutsu: franja (bola de fuego) o flecha de embiste (embiste de rayo).
## - Marca del objetivo fijado: anillo rojo giratorio en el suelo y rombo flotante sobre la cabeza.

var _franja: MeshInstance3D
var _franja_mat: ShaderMaterial
var _punta: MeshInstance3D
var _punta_mat: StandardMaterial3D
var _anillo: MeshInstance3D
var _rombo: MeshInstance3D
var _marca: Node3D
var objetivo: Node3D = null
var _t := 0.0


func _ready() -> void:
	_franja = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.orientation = PlaneMesh.FACE_Y
	q.center_offset = Vector3(0, 0, -0.5)   # crece hacia -Z local (luego se orienta)
	_franja_mat = Shaders.material("indicador")
	q.material = _franja_mat
	_franja.mesh = q
	_franja.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_franja.visible = false
	add_child(_franja)
	_punta = MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.0
	cil.bottom_radius = 0.9
	cil.height = 1.3
	cil.radial_segments = 3
	cil.rings = 1
	_punta_mat = StandardMaterial3D.new()
	_punta_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_punta_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_punta_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_punta_mat.disable_fog = true
	cil.material = _punta_mat
	_punta.mesh = cil
	_punta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_punta.visible = false
	add_child(_punta)

	_marca = Node3D.new()
	_marca.visible = false
	add_child(_marca)
	_anillo = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.75
	tor.outer_radius = 0.9
	tor.rings = 24
	tor.ring_segments = 4
	_anillo.mesh = tor
	_anillo.material_override = Materiales.emisivo(Color(1.0, 0.15, 0.12), 2.5)
	_anillo.scale = Vector3(1, 0.15, 1)
	_anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marca.add_child(_anillo)
	_rombo = MeshInstance3D.new()
	var oct := CylinderMesh.new()
	oct.top_radius = 0.0
	oct.bottom_radius = 0.16
	oct.height = 0.3
	oct.radial_segments = 4
	oct.rings = 1
	_rombo.mesh = oct
	_rombo.material_override = Materiales.emisivo(Color(1.0, 0.2, 0.15), 3.0)
	_rombo.rotation_degrees = Vector3(180, 0, 0)
	_rombo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marca.add_child(_rombo)


## Muestra el indicador de apuntado desde `origen` en la dirección `dir` (plano XZ).
func mostrar_apuntado(origen: Vector3, dir: Vector3, largo: float, ancho: float, color: Color, flecha: bool, cancelar: bool) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var yaw := atan2(dir.x, dir.z)
	var largo_franja := largo - (1.2 if flecha else 0.0)
	_franja.visible = true
	_franja.global_position = Vector3(origen.x, 0.05, origen.z)
	_franja.rotation = Vector3(0, yaw + PI, 0)
	_franja.scale = Vector3(ancho, 1, largo_franja)
	_franja_mat.set_shader_parameter("color", color)
	_franja_mat.set_shader_parameter("largo", largo_franja)
	_franja_mat.set_shader_parameter("cancelar", 1.0 if cancelar else 0.0)
	_punta.visible = flecha
	if flecha:
		_punta_mat.albedo_color = Color(color.r, color.g, color.b, 0.25 if cancelar else 0.85)
		_punta.global_position = Vector3(origen.x, 0.06, origen.z) + dir * (largo - 0.6)
		_punta.rotation = Vector3(PI * 0.5, yaw, 0)
		_punta.scale = Vector3(ancho * 0.9, 1, 0.08)


func ocultar_apuntado() -> void:
	_franja.visible = false
	_punta.visible = false


func _process(delta: float) -> void:
	_t += delta
	if objetivo != null and is_instance_valid(objetivo):
		_marca.visible = true
		var p := objetivo.global_position
		_marca.global_position = Vector3(p.x, 0.04, p.z)
		_anillo.rotation.y = _t * 2.0
		var pulso := 1.0 + sin(_t * 6.0) * 0.06
		_anillo.scale = Vector3(pulso, 0.15, pulso)
		_rombo.position = Vector3(0, 2.35 + sin(_t * 3.0) * 0.08, 0)
		_rombo.rotation.y = _t * 3.0
	else:
		_marca.visible = false
