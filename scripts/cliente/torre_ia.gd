class_name TorreIA
extends RefCounted
## Torre monumental hecha con los modelos generados por IA (tools/blender/torre_ia.py):
## 3 LODs con rangos de visibilidad, ventanas ámbar emisivas y ojos con anillos concéntricos.
## Las medidas (ojos, lengua) vienen de data/escenario.json → "torre_ia".

const RUTA := "res://assets/modelos/torre_ia.glb"
const RANGOS := [[0.0, 130.0], [130.0, 260.0], [260.0, 0.0]]


static func disponible() -> bool:
	return ResourceLoader.exists(RUTA) and not Datos.escenario.get("torre_ia", {}).is_empty()


static func crear(centro: Vector2, giro: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "TorreIA"
	raiz.position = Vector3(centro.x, 0, centro.y)
	raiz.rotation.y = deg_to_rad(giro)
	var escena: Node = (load(RUTA) as PackedScene).instantiate()
	var mat := Shaders.material("torre_ia")
	mat.set_shader_parameter("tex_detalle", load("res://assets/texturas/lamina_color.png"))
	mat.set_shader_parameter("tex_normal", load("res://assets/texturas/concreto_normal.png"))
	mat.set_shader_parameter("chorreo", 1.0 if Ajustes.g("chorreo", true) else 0.0)
	var ventana := Materiales.emisivo(Kit.COLOR_VENTANA, 2.4)
	ventana.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in _mallas(escena):
		var n := String(mi.name)
		var copia := MeshInstance3D.new()
		copia.mesh = mi.mesh
		copia.name = n
		if n.begins_with("VENTANAS"):
			copia.material_override = ventana
			copia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			copia.material_override = mat
			var i := int(n.substr(3, 1)) if n.begins_with("LOD") else 0
			copia.visibility_range_begin = RANGOS[i][0]
			copia.visibility_range_end = RANGOS[i][1]
			# Solo el LOD0 proyecta sombra (el resto está lejos).
			copia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i == 0 and Ajustes.calidad == "alta" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(copia)
	escena.free()
	_ojos(raiz)
	return raiz


static func _mallas(n: Node) -> Array:
	var r: Array = []
	if n is MeshInstance3D:
		r.append(n)
	for h in n.get_children():
		r.append_array(_mallas(h))
	return r


## Ojos: discos con el shader de anillos, apenas delante de las cuencas y mirando hacia fuera.
static func _ojos(raiz: Node3D) -> void:
	var mat := Shaders.material("ojo_torre")
	for o in Datos.escenario["torre_ia"].get("ojos", []):
		var c := Vector3(o["centro"][0], o["centro"][1], o["centro"][2])
		var nrm := Vector3(o["normal"][0], 0.0, o["normal"][2]).normalized()
		var disco := MeshInstance3D.new()
		var q := QuadMesh.new()
		var r := float(o["radio"]) * 1.25
		q.size = Vector2(r * 2.0, r * 1.5)
		disco.mesh = q
		disco.material_override = mat
		disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(disco)
		disco.transform = Transform3D(Basis.looking_at(-nrm, Vector3.UP), c + nrm * 0.35)
		var luz := OmniLight3D.new()
		luz.light_color = Color(0.65, 0.45, 1.0)
		luz.light_energy = 0.6
		luz.omni_range = 4.0
		luz.position = c + nrm * 1.5
		raiz.add_child(luz)
