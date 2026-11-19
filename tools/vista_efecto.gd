extends SceneTree
## Herramienta de calidad: reproduce un efecto de jutsu aislado (sin HUD ni partida) con cámara fija y guarda una
## secuencia de cuadros en instantes exactos. Úsese con --fixed-fps 30 para que los tiempos sean deterministas.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 --fixed-fps 30 --rendering-method mobile \
##        -s res://tools/vista_efecto.gd -- <carpeta> <caso> [<caso> ...]
## Casos: kirin1..3, dragon_agua, dragon_madera, golem1..3, susanoo1..3

var salida := "/tmp"
var casos: Array = []
var escenario: Escenario
var camara: CamaraTercera
var efectos: Efectos
var tecnicas: EfectosTecnicas
var genericas: EfectosGenericos
var sonidos: Sonidos
var t := 0.0
var guion: Array = []
var paso := 0
var _limpiar: Array = []


func _initialize() -> void:
	Datos.cargar()
	Ajustes.cargar()
	var args := OS.get_cmdline_user_args()
	salida = args[0]
	casos = args.slice(1)
	DirAccess.make_dir_recursive_absolute(salida)
	escenario = Escenario.new()
	escenario.mapa = Mapa.generar()
	escenario._colores = Datos.escenario.get("colores", {})
	escenario._entorno()
	root.add_child(escenario)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	pm.material = Shaders.toon_tex("suelo", Color(0.8, 0.82, 0.88), Vector2(30, 30), false)
	suelo.mesh = pm
	root.add_child(suelo)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40, 30, 0)
	luz.light_energy = 0.5
	root.add_child(luz)
	sonidos = Sonidos.new()
	root.add_child(sonidos)
	camara = CamaraTercera.new()
	root.add_child(camara)
	camara.libre = true
	efectos = Efectos.new()
	efectos.camara = camara
	efectos.escenario = escenario
	efectos.sonidos = sonidos
	root.add_child(efectos)
	tecnicas = EfectosTecnicas.new()
	tecnicas.efectos = efectos
	tecnicas.sonidos = sonidos
	root.add_child(tecnicas)
	genericas = EfectosGenericos.new()
	genericas.efectos = efectos
	genericas.sonidos = sonidos
	root.add_child(genericas)
	var t0 := 0.3
	for c in casos:
		t0 = _caso(str(c), t0)
	guion.append([t0 + 0.2, func(): quit(0)])


func _cam(pos: Vector3, mirar: Vector3) -> void:
	camara.global_position = pos
	camara.look_at(mirar, Vector3.UP)


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
	print("CUADRO ", nombre, " t=", snappedf(t, 0.01))


func _caso(c: String, t0: float) -> float:
	var punto := Vector3(0, 0, 0)
	if c.begins_with("kirin"):
		var n := int(c.substr(5))
		var nd := Datos.nivel_jutsu("kirin", n)
		var carga := float(nd.get("carga", 1.2))
		guion.append([t0, func():
			_cam(Vector3(22, 5, 30), Vector3(0, 12, 0))
			tecnicas.tormenta(punto, n, carga, func() -> Vector3: return punto)])
		var marcas := [0.3, carga * 0.6, carga - 0.45, carga - 0.3, carga - 0.15, carga + 0.03, carga + 0.25, carga + 0.9]
		for i in marcas.size():
			var k := i
			guion.append([t0 + float(marcas[i]), func(): _foto("%s_%d" % [c, k])])
		guion.append([t0 + carga, func(): tecnicas.kirin(punto, n, float(nd.get("radio", 3.0)), bool(nd.get("bestia", false)))])
		guion.sort_custom(func(a, b): return a[0] < b[0])
		return t0 + carga + 2.5
	return t0


func _process(d: float) -> bool:
	t += d
	while paso < guion.size() and t >= float(guion[paso][0]):
		(guion[paso][1] as Callable).call()
		paso += 1
		if paso < guion.size() and float(guion[paso][0]) > t:
			break
	return false
