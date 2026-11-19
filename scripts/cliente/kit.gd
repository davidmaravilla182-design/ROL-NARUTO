class_name Kit
extends RefCounted
## Piezas modulares de la aldea modeladas en Blender (assets/modelos/*.glb).
## Al cargar una pieza se reemplazan sus materiales (por nombre) con los shaders del juego:
## texturas horneadas con cel shading, ventanas y faroles emisivos.

static var _mallas: Dictionary = {}
static var _mats: Dictionary = {}

const COLOR_VENTANA := Color(1.0, 0.68, 0.32)


## Modelos de Meshy con huecos (ventanas rotas, paredes destrozadas): doble cara con interior oscuro.
const DOBLE_CARA := ["casa_chica", "edificio_mediano", "taller_industrial", "torre_vivienda_a", "torre_vivienda_b",
	"puerta_aldea", "academia", "entrada_mercado", "puesto_mercado", "carreta", "tanque_agua"]
const ESCALABLES := {"losa": "suelo", "columna": "concreto", "escalera": "rejilla"}


static func material_para(nombre: String) -> Material:
	var clave := nombre + "_" + str(Materiales.grosor_contorno)
	if _mats.has(clave):
		return _mats[clave]
	var c := Materiales.grosor_contorno
	var m: Material
	match nombre:
		"concreto": m = Shaders.toon_tex("concreto", Color(0.92, 0.93, 0.98), Vector2.ONE, false, 0.25, 0.0, 0.55, c)
		"lamina": m = Shaders.toon_tex("lamina", Color(1, 1, 1), Vector2.ONE, false, 0.25, 0.45, 0.5, c)
		"tuberia": m = Shaders.toon_tex("tuberia", Color(1, 1, 1), Vector2.ONE, false, 0.25, 0.35, 0.45, c)
		"techo": m = Shaders.toon_tex("techo", Color(1, 1, 1), Vector2.ONE, false, 0.25, 0.4, 0.6, c)
		"suelo": m = Shaders.toon_tex("suelo", Color(1, 1, 1), Vector2.ONE, false, 0.25, 0.3, 0.7, c)
		"rejilla": m = Shaders.toon_tex("rejilla", Color(1, 1, 1), Vector2.ONE, false, 0.25, 0.4, 0.4, 0.0)
		"piedra": m = Shaders.toon_tex("concreto", Color(1.15, 1.12, 1.1), Vector2.ONE, false, 0.25, 0.0, 0.45, c)
		"lengua": m = Materiales.solido(Color(0.55, 0.22, 0.28), 0.35)
		# Edificio generado con Meshy: su propia textura con el cel shading y la lluvia del kit.
		"edificio_ia": m = Shaders.toon_tex("edificio_ia", Color(0.86, 0.85, 0.9), Vector2.ONE, false, 0.25, 0.1, 0.5, c, true)
		"madera": m = Shaders.toon_tex("madera", Color.WHITE, Vector2.ONE, false, 0.25, 0.0, 0.4, c)
		"paja": m = Materiales.solido(Color(0.74, 0.62, 0.36), 0.95)
		"cuerda": m = Materiales.solido(Color(0.58, 0.5, 0.38), 0.95)
		"diana": m = Materiales.solido(Color(0.72, 0.1, 0.1), 0.8)
		"ventana": m = Materiales.emisivo(COLOR_VENTANA, 1.6)
		"luz": m = Materiales.emisivo(Color(1.0, 0.78, 0.45), 2.2)
		"oscuro": m = Materiales.solido(Color(0.06, 0.06, 0.08), 0.4)
		"cable": m = Materiales.solido(Color(0.03, 0.03, 0.04), 0.6)
		_:
			# Modelos de Meshy procesados en Blender: material con el nombre de la pieza y su textura.
			if ResourceLoader.exists("res://assets/texturas/%s_color.png" % nombre):
				m = Shaders.toon_tex(nombre, Color(0.9, 0.89, 0.93), Vector2.ONE, false, 0.25, 0.1, 0.5, c, nombre.trim_suffix("_lejos") in DOBLE_CARA)
			else:
				m = Materiales.solido(Color(0.5, 0.5, 0.5))
	_mats[clave] = m
	return m


## Malla de la pieza con los materiales del juego aplicados (cacheada).
static func malla(nombre: String) -> Mesh:
	var clave := nombre + "_" + str(Materiales.grosor_contorno)
	if _mallas.has(clave):
		return _mallas[clave]
	var ruta := "res://assets/modelos/%s.glb" % nombre
	if not ResourceLoader.exists(ruta):
		push_error("Kit: no existe " + ruta)
		return BoxMesh.new()
	var escena: Node = (load(ruta) as PackedScene).instantiate()
	var mi := _buscar_malla(escena)
	var original: Mesh = mi.mesh if mi != null else BoxMesh.new()
	var m: Mesh = original.duplicate()
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i)
		var nombre_mat := ""
		if mat != null:
			nombre_mat = mat.resource_name
		if nombre_mat == "" and m is ArrayMesh:
			nombre_mat = (m as ArrayMesh).surface_get_name(i)
		m.surface_set_material(i, material_para(nombre_mat.get_slice(".", 0)))
	escena.free()
	_mallas[clave] = m
	return m


static func _buscar_malla(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for h in n.get_children():
		var r := _buscar_malla(h)
		if r != null:
			return r
	return null


static func instancia(nombre: String, t := Transform3D.IDENTITY, sombras := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla(nombre)
	mi.transform = t
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombras else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Modelo 3D de un jutsu (Meshy, procesado en Blender) si existe: assets/modelos/jutsu_<nombre>.glb.
static func modelo_jutsu(nombre: String, material: Material = null) -> MeshInstance3D:
	if not ResourceLoader.exists("res://assets/modelos/jutsu_%s.glb" % nombre):
		return null
	var mi := instancia("jutsu_" + nombre, Transform3D.IDENTITY, material == null)
	if material != null:
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Muchas copias de una pieza en una sola llamada de dibujo.
## tintes (opcional): un Color por copia para variar el color (lo lee el shader toon_tex).
static func multimalla(nombre: String, transformaciones: Array, sombras := true, tintes: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = not tintes.is_empty()
	mm.mesh = malla(nombre)
	mm.instance_count = transformaciones.size()
	for i in transformaciones.size():
		mm.set_instance_transform(i, transformaciones[i])
		if not tintes.is_empty():
			var t: Color = tintes[i % tintes.size()]
			mm.set_instance_custom_data(i, Color(t.r, t.g, t.b, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	# Piezas que se escalan a cualquier tamaño (losas, columnas, escaleras): textura en coordenadas de mundo.
	if nombre in ESCALABLES:
		mmi.material_override = Shaders.toon_tex(ESCALABLES[nombre], Color(0.9, 0.9, 0.95), Vector2.ONE, true, 0.5, 0.35, 0.6)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombras else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
