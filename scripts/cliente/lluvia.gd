class_name Lluvia
extends Node3D
## Lluvia constante optimizada para móvil: un solo sistema GPU de gotas
## y otro de salpicaduras, que siguen a la cámara.

var objetivo: Node3D


func construir() -> void:
	var conf: Dictionary = Datos.escenario.get("lluvia", {})
	var area := float(conf.get("area", 22.0))

	var gotas := GPUParticles3D.new()
	gotas.amount = int(Ajustes.g("gotas", conf.get("gotas", 1400)))
	gotas.lifetime = 0.75
	gotas.preprocess = 1.0
	gotas.local_coords = false
	gotas.position = Vector3(0, 14, 0)
	gotas.visibility_aabb = AABB(Vector3(-area - 5, -20, -area - 5), Vector3((area + 5) * 2, 30, (area + 5) * 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(area, 0.5, area)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 27.0
	pm.gravity = Vector3(0, -6, 0)
	gotas.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.95)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.85, 0.98, 0.26)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.disable_receive_shadows = true
	q.material = mat
	gotas.draw_pass_1 = q
	gotas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gotas)

	var salp := GPUParticles3D.new()
	salp.amount = int(Ajustes.g("salpicaduras", conf.get("salpicaduras", 220)))
	salp.lifetime = 0.28
	salp.local_coords = false
	salp.position = Vector3(0, 0.04, 0)
	salp.visibility_aabb = AABB(Vector3(-area, -1, -area), Vector3(area * 2, 2, area * 2))
	var pm2 := ParticleProcessMaterial.new()
	pm2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm2.emission_box_extents = Vector3(area * 0.8, 0.0, area * 0.8)
	pm2.gravity = Vector3.ZERO
	pm2.initial_velocity_min = 0.0
	pm2.initial_velocity_max = 0.0
	pm2.scale_min = 0.08
	pm2.scale_max = 0.18
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.2))
	curva.add_point(Vector2(1, 1))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm2.scale_curve = ct
	var g := Gradient.new()
	g.set_color(0, Color(0.8, 0.85, 0.95, 0.5))
	g.set_color(1, Color(0.8, 0.85, 0.95, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm2.color_ramp = gt
	salp.process_material = pm2
	var q2 := QuadMesh.new()
	q2.size = Vector2(1, 1)
	q2.orientation = PlaneMesh.FACE_Y
	var mat2 := StandardMaterial3D.new()
	mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat2.vertex_color_use_as_albedo = true
	mat2.albedo_texture = Materiales.textura_suave()
	q2.material = mat2
	salp.draw_pass_1 = q2
	salp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(salp)


func _process(_delta: float) -> void:
	if objetivo != null:
		var p := objetivo.global_position
		global_position = Vector3(p.x, 0, p.z)
