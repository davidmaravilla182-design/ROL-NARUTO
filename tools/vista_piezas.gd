extends SceneTree
## Herramienta de desarrollo: fotografía combinaciones del ninja por piezas (peinado × prenda), de frente y de espaldas.
## Uso: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 -s res://tools/vista_piezas.gd -- <salida.png> [espalda] [anim]

var t := 0.0
var salida := "/tmp/piezas.png"
var figuras: Array = []
var anim := ""


func _initialize() -> void:
	Datos.cargar()
	Ajustes.cargar()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var espalda := "espalda" in args
	for a in args:
		if a.begins_with("anim="):
			anim = a.substr(5)
	var esc := Escenario.new()
	esc.mapa = Mapa.generar()
	esc._colores = Datos.escenario.get("colores", {})
	esc._entorno()
	root.add_child(esc)
	esc.entorno.fog_density = 0.0
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	pm.material = Shaders.toon_tex("suelo", Color(0.95, 0.95, 1.0), Vector2(10, 10), false)
	suelo.mesh = pm
	root.add_child(suelo)
	var combos := [["puntas", "chaleco", "#c8a24a", "#56644e", "papel"], ["corto", "impermeable", "#1a1f2e", "#4a5164", "lava"],
		["largo", "ligera", "#b23a2a", "#6b2f2f", "hielo"], ["coleta", "capa", "#6b3c8f", "#3a3550", "arena"],
		["corto", "chaleco", "#3b2a1e", "#2f4a5e", "sin_clan"], ["puntas", "capa", "#e8e2d6", "#2a2d36", "madera"]]
	var x := -6.25
	if "npcs" in args:
		for pl in ["guardia_lluvia", "ninja_agua", "rebelde", "comerciante", "instructor", "ninja_lluvia"]:
			var pn := PersonajeVisual.new()
			root.add_child(pn)
			pn.construir(pl)
			pn.position = Vector3(x, 0, 0)
			pn.rotation.y = PI if espalda else 0.0
			figuras.append(pn)
			x += 2.5
		combos = []
	for cb in combos:
		var pv := PersonajeVisual.new()
		root.add_child(pv)
		var a := {"peinado": cb[0], "ropa": cb[1], "pelo": cb[2], "color_prenda": cb[3], "piel": "#f1cfae", "ojos": "#202020",
			"camisa": "#1a1d26", "pantalon": "#171a22", "banda": "#2a2f45", "emblema_espalda": true, "escala": [1.0, 1.0]}
		pv.construir_aspecto(a, "lluvia", cb[4], true)
		pv.position = Vector3(x, 0, 0)
		pv.rotation.y = PI if espalda else 0.0
		figuras.append(pv)
		x += 2.5
	var cam := Camera3D.new()
	cam.fov = 40
	cam.position = Vector3(0, 1.3, 11.5)
	root.add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0))
	for a in args:
		if a.begins_with("cerca="):
			# Primer plano de tres figuras (desde la indicada), a la altura del torso y la cabeza.
			var i0 := int(a.substr(6))
			var cx := -6.25 + 2.5 * (i0 + 1)
			cam.position = Vector3(cx, 1.45, 4.6 if not espalda else -4.6) if false else Vector3(cx, 1.45, 4.6)
			cam.look_at(Vector3(cx, 1.25, 0))
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, 25, 0)
	luz.light_energy = 0.55
	root.add_child(luz)
	var omni := OmniLight3D.new()
	omni.position = Vector3(0, 3, 5)
	omni.omni_range = 20
	omni.light_energy = 0.6
	omni.light_color = Color(1.0, 0.8, 0.6)
	root.add_child(omni)


func _process(d: float) -> bool:
	t += d
	if anim != "" and t < 0.2:
		for pv in figuras:
			pv.reproducir(anim, 0.0)
	if t > 1.6:
		root.get_viewport().get_texture().get_image().save_png(salida)
		print("PIEZAS CAPTURA ", salida)
		quit(0)
	return false
