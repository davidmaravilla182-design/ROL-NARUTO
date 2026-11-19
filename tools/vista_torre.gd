extends SceneTree
## Fotografía la torre de los modelos IA con la iluminación del juego (niebla baja) desde 3 ángulos.
## Uso: xvfb-run -a godot --path . --resolution 1280x720 -s res://tools/vista_torre.gd -- <carpeta>
var t := 0.0
var dir := "user://"
var cam: Camera3D
var paso := 0


func _initialize() -> void:
	Datos.cargar()
	Ajustes.cargar()
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		dir = a[0]
	var esc := Escenario.new()
	esc.mapa = Mapa.generar()
	esc._colores = Datos.escenario.get("colores", {})
	esc._entorno()
	root.add_child(esc)
	esc.entorno.fog_density = float(OS.get_environment("NIEBLA")) if OS.get_environment("NIEBLA") != "" else 0.003
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	pm.material = Shaders.toon_tex("suelo", Color(0.95, 0.95, 1.0), Vector2(60, 60), false, 0.25, 0.25, 0.75)
	suelo.mesh = pm
	root.add_child(suelo)
	root.add_child(TorreIA.crear(Vector2.ZERO, 0.0))
	cam = Camera3D.new()
	cam.far = 600
	root.add_child(cam)
	cam.current = true


func _process(d: float) -> bool:
	t += d
	var tomas := [[Vector3(0, 30, 95), "frente"], [Vector3(70, 34, 65), "tres_cuartos"], [Vector3(12, 40, 42), "rostro"], [Vector3(0, 30, 200), "lejos_lod1"], [Vector3(0, 40, 330), "lejos_lod2"]]
	if paso < tomas.size():
		if t > 0.4 * (paso + 1):
			cam.look_at_from_position(tomas[paso][0], Vector3(0, 36 if paso != 2 else 46, 0))
		if t > 0.4 * (paso + 1) + 0.3:
			root.get_texture().get_image().save_png(dir.path_join("torre_%s.png" % tomas[paso][1]))
			paso += 1
	else:
		quit(0)
	return false
