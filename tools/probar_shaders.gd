extends SceneTree
## Compila todos los shaders con un renderizador real (usar con xvfb-run) y muestra errores.
func _initialize() -> void:
	for k in ["toon", "contorno", "fuego", "calor", "charco", "nubes", "niebla", "ojo", "indicador"]:
		var mi := MeshInstance3D.new()
		mi.mesh = SphereMesh.new()
		mi.material_override = Shaders.material(k)
		root.add_child(mi)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 4)
	root.add_child(cam)
	await process_frame
	await process_frame
	print("SHADERS: listo")
	quit(0)
