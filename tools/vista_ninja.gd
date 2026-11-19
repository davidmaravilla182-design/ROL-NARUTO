extends SceneTree
## Primer plano del ninja (modelo IA) con varias personalizaciones, de frente y de espalda.
## Uso: xvfb-run -a godot --path . --resolution 1280x720 -s res://tools/vista_ninja.gd -- <carpeta>
var t := 0.0
var dir := "user://"
var cam: Camera3D
var paso := 0
var figuras: Array = []


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
	esc.entorno.fog_density = 0.002
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	pm.material = Shaders.toon_tex("suelo", Color(0.95, 0.95, 1.0), Vector2(10, 10), false, 0.25, 0.25, 0.75)
	suelo.mesh = pm
	root.add_child(suelo)
	var casos := [
		["uchiha", {"peinado": "puntas", "ropa": "chaleco", "pelo": "#1a1f2e", "piel": "#f1cfae"}],
		["hyuga", {"peinado": "largo", "ropa": "ligera", "pelo": "#3b2a1e", "piel": "#e2b48c"}],
		["arena", {"peinado": "corto", "ropa": "chaleco", "pelo": "#b23a2a", "piel": "#c99470"}],
		["hielo", {"peinado": "coleta", "ropa": "impermeable", "pelo": "#e8e2d6", "piel": "#f6dcc4"}],
		["lava", {"peinado": "melena", "ropa": "sigilo", "pelo": "#c8a24a", "piel": "#7e5038"}],
	]
	for i in casos.size():
		var pj := Creacion.nuevo()
		pj["clan"] = casos[i][0]
		for k in casos[i][1].keys():
			pj["aspecto"][k] = casos[i][1][k]
		var asp := Creacion.aspecto_visual(pj)
		var pv := PersonajeVisual.new()
		root.add_child(pv)
		pv.construir_aspecto(asp, "lluvia", str(pj["clan"]))
		pv.position = Vector3((i - 2) * 1.1, 0, 0)
		pv.reproducir("quieto")
		figuras.append(pv)
	cam = Camera3D.new()
	cam.fov = 38
	root.add_child(cam)
	cam.current = true


func _process(d: float) -> bool:
	t += d
	var tomas := [[Vector3(0, 1.2, 7.2), Vector3(0, 0.95, 0), "frente"], [Vector3(0, 1.2, -7.2), Vector3(0, 0.95, 0), "espalda"],
		[Vector3(-2.2, 1.55, -1.3), Vector3(-2.2, 1.35, 0), "espalda_cerca"], [Vector3(-2.2, 1.6, 1.0), Vector3(-2.2, 1.55, 0), "cara_cerca"]]
	if paso < tomas.size():
		if t > 0.5 * (paso + 1):
			cam.look_at_from_position(tomas[paso][0], tomas[paso][1])
		if t > 0.5 * (paso + 1) + 0.3:
			root.get_texture().get_image().save_png(dir.path_join("ninja_%s.png" % tomas[paso][2]))
			paso += 1
	else:
		quit(0)
	return false
