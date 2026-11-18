extends SceneTree
## Herramienta de desarrollo: fotografía las piezas del kit con la iluminación del juego.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 -s res://tools/vista_kit.gd -- <salida.png> [pieza ...]

var t := 0.0
var salida := "/tmp/kit.png"


func _initialize() -> void:
	Datos.cargar()
	Ajustes.cargar()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var piezas: Array = args.slice(1) if args.size() > 1 else ["silo", "edificio", "tanque", "tubo_arco", "pasarela", "muro_canal", "barandal", "farol", "toldo", "tubo_largo"]
	var esc := Escenario.new()
	esc.mapa = Mapa.generar()
	esc._colores = Datos.escenario.get("colores", {})
	esc._entorno()
	root.add_child(esc)
	esc.entorno.fog_density = 0.004
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	pm.material = Shaders.toon_tex("suelo", Color(0.95, 0.95, 1.0), Vector2(50, 50), false, 0.25, 0.25, 0.75)
	suelo.mesh = pm
	root.add_child(suelo)
	var x := 0.0
	var anchos := {"torre_cabeza": 34.0, "silo": 11.0, "edificio": 11.0, "tanque": 5.0, "tubo_arco": 10.0, "pasarela": 14.0, "muro_canal": 10.0, "barandal": 3.0, "farol": 1.5, "toldo": 4.0, "tubo_largo": 14.0}
	var total := 0.0
	for p in piezas:
		total += float(anchos.get(p, 8.0))
	x = -total * 0.5
	for p in piezas:
		var w := float(anchos.get(p, 8.0))
		var mi := Kit.instancia(p)
		mi.position = Vector3(x + w * 0.5, 2.5 if p == "pasarela" else (1.5 if p == "tubo_largo" else 0.0), 0)
		root.add_child(mi)
		x += w
	# Encuadre según la caja que envuelve todas las piezas.
	var caja := AABB()
	var primera := true
	for n in root.get_children():
		if n is MeshInstance3D and n != suelo:
			var b: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
			caja = b if primera else caja.merge(b)
			primera = false
	var cam := Camera3D.new()
	cam.fov = 55
	cam.far = 1000
	var lejos := maxf(caja.size.x * 0.85, caja.size.y * 1.05)
	var centro := caja.get_center()
	cam.position = centro + Vector3(lejos * 0.25, lejos * 0.12, lejos)
	root.add_child(cam)
	cam.look_at(centro)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.7, 0.4)
	luz.omni_range = 30
	luz.light_energy = 2.0
	luz.position = Vector3(0, 6, 8)
	root.add_child(luz)


func _process(d: float) -> bool:
	t += d
	if t > 1.5:
		root.get_viewport().get_texture().get_image().save_png(salida)
		print("KIT CAPTURA ", salida)
		quit(0)
	return false
