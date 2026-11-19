extends SceneTree
## Herramienta de calidad: tira de cuadros de una o varias animaciones del ninja por piezas (vista lateral 3/4),
## muestreadas con seek (deterministas, sin depender de los fps). Guarda una tira PNG por animación.
## Uso: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 --rendering-method mobile \
##        -s res://tools/secuencia_anim.gd -- <carpeta> <anim> [<anim> ...]   (anim: "m/m_jab_izq", "correr", …)

var salida := "/tmp"
var anims: Array = []
var pv: PersonajeVisual
var cam: Camera3D
var _i := 0
var _k := 0
var _cuadros := 8
var _imgs: Array = []
var _esperar := 3


func _initialize() -> void:
	Datos.cargar()
	Ajustes.cargar()
	var args := OS.get_cmdline_user_args()
	salida = args[0]
	anims = args.slice(1)
	DirAccess.make_dir_recursive_absolute(salida)
	var esc := Escenario.new()
	esc.mapa = Mapa.generar()
	esc._colores = Datos.escenario.get("colores", {})
	esc._entorno()
	root.add_child(esc)
	esc.entorno.fog_density = 0.0
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	pm.material = Shaders.toon_tex("suelo", Color(0.95, 0.95, 1.0), Vector2(10, 10), false)
	suelo.mesh = pm
	root.add_child(suelo)
	pv = PersonajeVisual.new()
	root.add_child(pv)
	pv.construir_aspecto({"peinado": "coleta", "ropa": "chaleco", "pelo": "#1a1f2e", "color_prenda": "#56644e", "piel": "#f1cfae",
		"camisa": "#1a1d26", "pantalon": "#171a22", "escala": [1.0, 1.0]}, "lluvia", "sin_clan", true)
	cam = Camera3D.new()
	cam.fov = 45
	root.add_child(cam)
	cam.look_at_from_position(Vector3(3.2, 1.4, 2.6), Vector3(0, 0.95, 0))
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40, 30, 0)
	luz.light_energy = 0.7
	root.add_child(luz)


func _process(_d: float) -> bool:
	if _esperar > 0:
		_esperar -= 1
		return false
	if _i >= anims.size():
		quit(0)
		return false
	var nombre: String = anims[_i]
	if not pv.anim.has_animation(nombre):
		print("NO EXISTE ", nombre)
		_i += 1
		return false
	var a := pv.anim.get_animation(nombre)
	if _k == 0:
		pv.anim.play(nombre, 0.0)
		pv.anim.pause()
	if _k > 0:
		_imgs.append(root.get_viewport().get_texture().get_image())
	if _k < _cuadros:
		pv.anim.seek(a.length * float(_k) / float(_cuadros - 1), true)
		_k += 1
		_esperar = 1
		return false
	# Tira: los cuadros uno al lado del otro, recortados alrededor del personaje.
	var w := 400
	var h := 560
	var tira := Image.create(w * _imgs.size(), h, false, Image.FORMAT_RGBA8)
	for j in _imgs.size():
		var im: Image = _imgs[j]
		im.convert(Image.FORMAT_RGBA8)
		tira.blit_rect(im, Rect2i(600, 170, w, h), Vector2i(j * w, 0))
	var archivo := salida.path_join(nombre.replace("/", "_") + ".png")
	tira.save_png(archivo)
	print("SECUENCIA ", archivo)
	_imgs.clear()
	_k = 0
	_i += 1
	return false
