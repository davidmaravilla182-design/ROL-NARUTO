extends SceneTree
## Captura de los NPC con modelo propio animados (líder rebelde e intruso): docs/capturas/v09/npc_*.png
const ANIMS := ["quieto", "correr", "m/m_patada_giro", "m/m_guardia"]
var _t := 0
var _pvs: Array = []


func _initialize() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.3, 0.32, 0.38)
	we.environment.ambient_light_color = Color(0.75, 0.75, 0.85)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 25, 0)
	raiz.add_child(sol)
	var cam := Camera3D.new()
	raiz.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.3, 7.5), Vector3(0, 1.0, 0), Vector3.UP)
	var i := 0
	for plantilla in ["lider_rebelde", "intruso"]:
		for a in ANIMS:
			var pv := PersonajeVisual.new()
			raiz.add_child(pv)
			pv.construir(plantilla)
			pv.position = Vector3(-4.2 + (i % 4) * 2.8 * 1.0, 0, -(i / 4) * 0.0)
			pv.position.x = -4.2 + (i % 4) * 2.8
			pv.position.y = 0.0 if i < 4 else -2.3
			pv.rotation.y = 0.5
			pv.reproducir(a)
			_pvs.append(pv)
			i += 1
	cam.fov = 40.0
	cam.look_at_from_position(Vector3(0, -0.1, 12.5), Vector3(0, -0.2, 0), Vector3.UP)


func _process(_d: float) -> bool:
	_t += 1
	if _t == 14:
		root.get_viewport().get_texture().get_image().save_png("res://docs/capturas/v09/npc_animados.png")
	return _t > 15
