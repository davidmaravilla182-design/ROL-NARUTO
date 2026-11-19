class_name PersonajeVisual
extends Node3D
## Humanoide low-poly hecho por código: Skeleton3D con huesos, piezas rígidas
## fijadas con BoneAttachment3D, ropa (Vestimenta) y animaciones (Animaciones).
## Solo dibuja: su estado lo decide el servidor.

# Proporciones estilizadas (anime): piernas largas, cintura estrecha, cabeza algo mayor.
const HUESOS := [
	["Caderas", "", Vector3(0, 1.0, 0)],
	["Columna", "Caderas", Vector3(0, 0.1, 0)],
	["Pecho", "Columna", Vector3(0, 0.18, 0)],
	["Cuello", "Pecho", Vector3(0, 0.25, 0)],
	["Cabeza", "Cuello", Vector3(0, 0.07, 0)],
	["BrazoI", "Pecho", Vector3(0.2, 0.2, 0)],
	["AntebrazoI", "BrazoI", Vector3(0, -0.27, 0)],
	["ManoI", "AntebrazoI", Vector3(0, -0.24, 0)],
	["BrazoD", "Pecho", Vector3(-0.2, 0.2, 0)],
	["AntebrazoD", "BrazoD", Vector3(0, -0.27, 0)],
	["ManoD", "AntebrazoD", Vector3(0, -0.24, 0)],
	["PiernaI", "Caderas", Vector3(0.095, -0.04, 0)],
	["RodillaI", "PiernaI", Vector3(0, -0.45, 0)],
	["PieI", "RodillaI", Vector3(0, -0.46, 0)],
	["PiernaD", "Caderas", Vector3(-0.095, -0.04, 0)],
	["RodillaD", "PiernaD", Vector3(0, -0.45, 0)],
	["PieD", "RodillaD", Vector3(0, -0.46, 0)],
]

var esqueleto: Skeleton3D
var anim: AnimationPlayer
var _adjuntos: Dictionary = {}
var _ojos: Array[MeshInstance3D] = []
var _mat_ojos_normal: Material
var _luz_ojos: OmniLight3D
var anim_actual := ""
var cuerpo_continuo := false   # true si se usa la malla deformable de Blender (assets/modelos/cuerpo.glb)
const RUTA_CUERPO := "res://assets/modelos/cuerpo.glb"
const RUTA_NINJA := "res://assets/modelos/ninja_ia.glb"
var sharingan := false
var modelo_ia := false          # true: ninja del modelo generado por IA (tools/blender/ninja_ia.py)
var _mat_ninja: ShaderMaterial
var _malla_pelo: MeshInstance3D


func construir(plantilla_id: String) -> void:
	var d := Datos.personaje(plantilla_id)
	construir_aspecto(d.get("aspecto", {}), str(d.get("aldea", "")), str(d.get("clan", "")), str(d.get("tipo", "")) == "jugador")


## Construye el personaje a partir de un aspecto (plantilla o personaje creado: Creacion.aspecto_visual).
func construir_aspecto(aspecto: Dictionary, aldea_id := "lluvia", clan_id := "", usar_ia := true) -> void:
	var aldea := Datos.aldea(aldea_id)
	var clan: Dictionary = Datos.mundo.get("clanes", {}).get(clan_id, {})
	# Complexión: ancho y alto del cuerpo entero.
	var esc: Array = aspecto.get("escala", [1.0, 1.0])
	scale = Vector3(float(esc[0]), float(esc[1]), float(esc[0]))

	var contorno_previo := Materiales.grosor_contorno
	Materiales.grosor_contorno = 0.011 if Ajustes.g("contorno_personajes", true) else 0.0
	modelo_ia = usar_ia and ResourceLoader.exists(RUTA_NINJA) and Datos.graficos.has("ninja_ia")
	cuerpo_continuo = modelo_ia or ResourceLoader.exists(RUTA_CUERPO)
	if modelo_ia:
		_cargar_ninja(aspecto, clan_id)
	elif cuerpo_continuo:
		_cargar_cuerpo(aspecto)
	else:
		esqueleto = Skeleton3D.new()
		esqueleto.name = "Esqueleto"
		add_child(esqueleto)
		for h in HUESOS:
			var idx := esqueleto.add_bone(h[0])
			if h[1] != "":
				esqueleto.set_bone_parent(idx, esqueleto.find_bone(h[1]))
			esqueleto.set_bone_rest(idx, Transform3D(Basis(), h[2]))
		esqueleto.reset_bone_poses()
	for h in HUESOS:
		var ba := BoneAttachment3D.new()
		ba.name = "Hueso_" + h[0]
		ba.bone_name = h[0]
		esqueleto.add_child(ba)
		# Marco intermedio: deshace la orientación de reposo del hueso para que las piezas
		# hechas por código usen siempre los ejes del modelo (Y arriba, frente +Z).
		var marco := Node3D.new()
		marco.name = "Marco"
		var idx2 := esqueleto.find_bone(h[0])
		marco.basis = _rest_global(idx2).basis.inverse() if cuerpo_continuo else Basis()
		ba.add_child(marco)
		_adjuntos[h[0]] = marco

	if modelo_ia:
		_detalles_ninja(aspecto)
		Vestimenta.vestir_ia(self, aspecto)
	else:
		_construir_cuerpo(aspecto)
		Vestimenta.vestir(self, aspecto, aldea, clan)
	Materiales.grosor_contorno = contorno_previo
	# Une las piezas de cada hueso (los ojos quedan aparte: su material cambia con el modo ocular, pero es compartido).
	for n in _adjuntos.keys():
		Materiales.fusionar(_adjuntos[n])

	anim = AnimationPlayer.new()
	anim.name = "Animador"
	add_child(anim)
	var nombres: Array = []
	for h in HUESOS:
		nombres.append(h[0])
	var ruta_esq := String(get_path_to(esqueleto))
	if cuerpo_continuo:
		var rests := {}
		for n in nombres:
			var i := esqueleto.find_bone(n)
			var padre := esqueleto.get_bone_parent(i)
			rests[n] = {
				"global": _rest_global(i).basis.get_rotation_quaternion(),
				"padre": _rest_global(padre).basis.get_rotation_quaternion() if padre >= 0 else Quaternion.IDENTITY,
			}
		var pos_cad := esqueleto.get_bone_rest(esqueleto.find_bone("Caderas")).origin
		anim.add_animation_library("", Animaciones.crear_libreria(ruta_esq, nombres, pos_cad, rests))
	else:
		anim.add_animation_library("", Animaciones.crear_libreria(ruta_esq, nombres, HUESOS[0][2]))
	reproducir("quieto")


func hueso(nombre: String) -> Node3D:
	return _adjuntos[nombre]


## Transformación de reposo de un hueso en el espacio del esqueleto.
func _rest_global(i: int) -> Transform3D:
	if i < 0:
		return Transform3D.IDENTITY
	var t := esqueleto.get_bone_rest(i)
	var p := esqueleto.get_bone_parent(i)
	while p >= 0:
		t = esqueleto.get_bone_rest(p) * t
		p = esqueleto.get_bone_parent(p)
	return t


## Cuerpo continuo de Blender: se queda con su Skeleton3D y cambia los materiales por zona.
func _cargar_cuerpo(a: Dictionary) -> void:
	var escena: Node3D = (load(RUTA_CUERPO) as PackedScene).instantiate()
	escena.name = "Cuerpo"
	add_child(escena)
	esqueleto = _buscar(escena, "Skeleton3D")
	var colores := {"piel": Datos.color(str(a.get("piel", "#e8c4a0"))), "camisa": Datos.color(str(a.get("camisa", "#1d2333"))),
		"pantalon": Datos.color(str(a.get("pantalon", "#252a3a"))), "chaleco": Datos.color(str(a.get("chaleco", "#3d4a3a"))),
		"capa": Datos.color(str(a.get("capa_color", "#434a5c")))}
	var con_capa := bool(a.get("capa", false))
	var mallas: Array = []
	_buscar_todos(escena, mallas)
	for mi in mallas:
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			var m: Material = (mi as MeshInstance3D).mesh.surface_get_material(i)
			var nombre := m.resource_name if m != null else ""
			var base_n := nombre.get_slice(".", 0)
			# Impermeable o chaleco según la plantilla (el impermeable reemplaza al chaleco).
			if (base_n == "capa" and not con_capa) or (base_n == "chaleco" and con_capa):
				(mi as MeshInstance3D).visible = false
			var col: Color = colores.get(base_n, Color(0.5, 0.5, 0.5))
			(mi as MeshInstance3D).set_surface_override_material(i, Materiales.solido(col, 0.75 if nombre == "piel" else 0.9))


## Ninja de los modelos IA: malla con textura recoloreada por zonas, cabello aparte y calcomanía del clan.
func _cargar_ninja(a: Dictionary, clan_id: String) -> void:
	var escena: Node3D = (load(RUTA_NINJA) as PackedScene).instantiate()
	escena.name = "Cuerpo"
	add_child(escena)
	esqueleto = _buscar(escena, "Skeleton3D")
	var conf: Dictionary = Datos.graficos["ninja_ia"]
	var z: Dictionary = conf["zonas"]
	var mallas: Array = []
	_buscar_todos(escena, mallas)
	var tex: Texture2D = null
	for mi in mallas:
		var m: Material = (mi as MeshInstance3D).mesh.surface_get_material(0)
		if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
			tex = (m as BaseMaterial3D).albedo_texture
	_mat_ninja = ShaderMaterial.new()
	_mat_ninja.shader = Shaders.shader("ninja_ia")
	_mat_ninja.set_shader_parameter("tex", tex)
	for k in ["piel", "pelo", "chaleco", "camisa", "pantalon"]:
		var o: Array = z[k]
		_mat_ninja.set_shader_parameter("o_" + k, Color(o[0], o[1], o[2]))
	recolorear(a)
	if Materiales.grosor_contorno > 0.0:
		_mat_ninja.next_pass = Shaders.material_contorno(Materiales.grosor_contorno * 0.8)
	for mi in mallas:
		var n := String((mi as MeshInstance3D).name)
		if n.begins_with("EMBLEMA"):
			var ruta := "res://assets/texturas/emblema_%s.png" % clan_id
			if not ResourceLoader.exists(ruta):
				(mi as MeshInstance3D).visible = false
				continue
			var me := StandardMaterial3D.new()
			me.albedo_texture = load(ruta)
			me.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			me.alpha_scissor_threshold = 0.4
			me.roughness = 0.8
			me.cull_mode = BaseMaterial3D.CULL_DISABLED
			(mi as MeshInstance3D).material_override = me
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif n.begins_with("PELO"):
			_malla_pelo = mi
			var mp: ShaderMaterial = _mat_ninja.duplicate()
			mp.set_shader_parameter("zona_pelo_forzada", 1.0)
			(mi as MeshInstance3D).material_override = mp
			# El cabello del modelo es el peinado "puntas"; los demás peinados son piezas del juego.
			mi.visible = str(a.get("peinado", "puntas")) == "puntas"
		else:
			(mi as MeshInstance3D).material_override = _mat_ninja


## Colores de la personalización sobre las zonas de la textura del modelo IA.
func recolorear(a: Dictionary) -> void:
	if _mat_ninja == null:
		return
	var z: Dictionary = Datos.graficos["ninja_ia"]["zonas"]
	var origen := func(k): return Color(z[k][0], z[k][1], z[k][2])
	_mat_ninja.set_shader_parameter("c_piel", Datos.color(str(a["piel"])) if a.has("piel") else origen.call("piel"))
	_mat_ninja.set_shader_parameter("c_pelo", Datos.color(str(a["pelo"])) if a.has("pelo") else origen.call("pelo"))
	_mat_ninja.set_shader_parameter("c_chaleco", Datos.color(str(a["chaleco"])) if a.has("chaleco") else origen.call("chaleco"))
	_mat_ninja.set_shader_parameter("c_camisa", Datos.color(str(a["camisa"])) if a.has("camisa") else origen.call("camisa"))
	if bool(a.get("capa", false)):
		# Impermeable: el modelo IA no tiene capa propia; chaleco y camisa toman el color del impermeable.
		var cc := Datos.color(str(a.get("capa_color", "#4a5164")))
		_mat_ninja.set_shader_parameter("c_chaleco", cc)
		_mat_ninja.set_shader_parameter("c_camisa", cc.darkened(0.15))
	_mat_ninja.set_shader_parameter("c_pantalon", Datos.color(str(a["pantalon"])) if a.has("pantalon") else origen.call("pantalon"))
	if _malla_pelo != null:
		var mp: ShaderMaterial = _malla_pelo.material_override
		for k in ["c_piel", "c_pelo", "c_chaleco", "c_camisa", "c_pantalon"]:
			mp.set_shader_parameter(k, _mat_ninja.get_shader_parameter(k))


## Ojos (solo visibles en modo ocular: la textura ya trae los ojos), peinado alternativo y nudo de la banda.
func _detalles_ninja(a: Dictionary) -> void:
	var conf: Dictionary = Datos.graficos["ninja_ia"]
	_mat_ojos_normal = Shaders.material("ojo")
	_mat_ojos_normal.set_shader_parameter("iris_normal", Datos.color(str(a.get("ojos", "#1a1a1a"))))
	var o: Array = conf["ojo"]
	for lado in [-1.0, 1.0]:
		var ojo := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.034, 0.022)
		ojo.mesh = q
		ojo.material_override = _mat_ojos_normal
		ojo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ojo.rotation_degrees = Vector3(0, 12 * lado, 0)
		ojo.visible = false
		_pieza("Cabeza", ojo, Vector3(float(o[0]) * lado, float(o[1]), float(o[2]) + 0.004))
		_ojos.append(ojo)
	_luz_ojos = OmniLight3D.new()
	_luz_ojos.light_color = Color(1, 0.1, 0.1)
	_luz_ojos.omni_range = 0.35
	_luz_ojos.light_energy = 0.0
	_luz_ojos.position = Vector3(0, float(o[1]), float(o[2]) + 0.1)
	hueso("Cabeza").add_child(_luz_ojos)
	if str(a.get("peinado", "puntas")) != "puntas":
		# Peinado del juego, ajustado al tamaño de la cabeza del modelo IA.
		var cont := Node3D.new()
		cont.position = Vector3(0, -0.03, 0.015)
		cont.scale = Vector3.ONE * 0.72
		hueso("Cabeza").add_child(cont)
		var antes: Node3D = _adjuntos["Cabeza"]
		_adjuntos["Cabeza"] = cont
		_pelo(a, Materiales.solido(Datos.color(str(a.get("pelo", "#141418"))), 0.45))
		_adjuntos["Cabeza"] = antes
	var nudo := NudoBanda.new()
	var n: Array = conf["nudo"]
	nudo.position = Vector3(float(n[0]), float(n[1]), float(n[2]))
	hueso("Cabeza").add_child(nudo)
	nudo.construir(Datos.color(str(a.get("banda", "#3a3f52"))).lightened(0.05))


func _buscar_todos(n: Node, lista: Array) -> void:
	if n is MeshInstance3D:
		lista.append(n)
	for h in n.get_children():
		_buscar_todos(h, lista)


func _buscar(n: Node, clase: String) -> Node:
	if n.is_class(clase):
		return n
	for h in n.get_children():
		var r := _buscar(h, clase)
		if r != null:
			return r
	return null


func _construir_cuerpo(a: Dictionary) -> void:
	var piel := Materiales.solido(Datos.color(str(a.get("piel", "#e8c4a0"))), 0.7)
	var camisa := Materiales.solido(Datos.color(str(a.get("camisa", "#1d2333"))), 0.9)
	var pantalon := Materiales.solido(Datos.color(str(a.get("pantalon", "#252a3a"))), 0.9)
	var pelo := Materiales.solido(Datos.color(str(a.get("pelo", "#141418"))), 0.45)
	var oscuro := Materiales.solido(Color(0.08, 0.06, 0.07), 0.6)

	if not cuerpo_continuo:
		_pieza("Caderas", Materiales.caja(Vector3(0.28, 0.15, 0.17), pantalon), Vector3(0, -0.01, 0))
		_pieza("Columna", Materiales.caja(Vector3(0.25, 0.2, 0.16), camisa), Vector3(0, 0.1, 0))
		var pecho := Materiales.caja(Vector3(0.34, 0.25, 0.19), camisa)
		_pieza("Pecho", pecho, Vector3(0, 0.12, 0))
		_pieza("Cuello", Materiales.cilindro(0.045, 0.05, 0.1, piel, 6), Vector3(0, 0.03, 0))

	# Cabeza: algo mayor y con mentón afilado (estilo anime).
	var craneo := Materiales.esfera(0.125, piel, 10)
	craneo.scale = Vector3(0.96, 1.08, 1.0)
	_pieza("Cabeza", craneo, Vector3(0, 0.15, 0))
	var menton := Materiales.cilindro(0.09, 0.03, 0.1, piel, 6)
	menton.rotation_degrees = Vector3(180, 0, 0)
	menton.scale = Vector3(1.0, 1.0, 0.85)
	_pieza("Cabeza", menton, Vector3(0, 0.06, 0.02))
	var nariz := Materiales.caja(Vector3(0.018, 0.035, 0.025), piel)
	_pieza("Cabeza", nariz, Vector3(0, 0.12, 0.122))
	var boca := Materiales.caja(Vector3(0.04, 0.006, 0.01), oscuro)
	_pieza("Cabeza", boca, Vector3(0, 0.075, 0.112))

	# Ojos con shader: iris oscuro que se vuelve rojo con tomoe al activar el modo ocular.
	_mat_ojos_normal = Shaders.material("ojo")
	_mat_ojos_normal.set_shader_parameter("iris_normal", Datos.color(str(a.get("ojos", "#1a1a1a"))))
	for lado in [-1.0, 1.0]:
		var ojo := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.052, 0.034)
		ojo.mesh = q
		ojo.material_override = _mat_ojos_normal
		ojo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ojo.rotation_degrees = Vector3(0, 14 * lado, 0)
		_pieza("Cabeza", ojo, Vector3(0.045 * lado, 0.142, 0.118))
		_ojos.append(ojo)
		var ceja := Materiales.caja(Vector3(0.05, 0.011, 0.012), pelo)
		ceja.rotation_degrees = Vector3(0, 14 * lado, -12 * lado)
		_pieza("Cabeza", ceja, Vector3(0.047 * lado, 0.168, 0.12))
		var oreja := Materiales.caja(Vector3(0.018, 0.05, 0.035), piel)
		_pieza("Cabeza", oreja, Vector3(0.12 * lado, 0.13, 0.0))
	_luz_ojos = OmniLight3D.new()
	_luz_ojos.light_color = Color(1, 0.1, 0.1)
	_luz_ojos.omni_range = 0.35
	_luz_ojos.light_energy = 0.0
	_luz_ojos.position = Vector3(0, 0.14, 0.22)
	hueso("Cabeza").add_child(_luz_ojos)
	_pelo(a, pelo)

	# Brazos y piernas más finos y largos (solo sin cuerpo continuo).
	for lado in ([] if cuerpo_continuo else ["I", "D"]):
		_pieza("Brazo" + lado, Materiales.capsula(0.052, 0.3, camisa), Vector3(0, -0.13, 0))
		_pieza("Antebrazo" + lado, Materiales.capsula(0.043, 0.26, piel), Vector3(0, -0.12, 0))
		_pieza("Mano" + lado, Materiales.caja(Vector3(0.06, 0.085, 0.04), piel), Vector3(0, -0.05, 0.005))
		_pieza("Pierna" + lado, Materiales.capsula(0.072, 0.48, pantalon), Vector3(0, -0.22, 0))
		_pieza("Rodilla" + lado, Materiales.capsula(0.056, 0.46, pantalon), Vector3(0, -0.22, 0))
		_pieza("Pie" + lado, Materiales.caja(Vector3(0.08, 0.05, 0.2), piel), Vector3(0, -0.025, 0.04))


func _pelo(a: Dictionary, mat: Material) -> void:
	var casco := Materiales.esfera(0.135, mat, 8)
	casco.scale = Vector3(1.0, 0.92, 1.08)
	_pieza("Cabeza", casco, Vector3(0, 0.19, -0.025))
	# Cada pico: [punto de la base, dirección hacia donde apunta, largo, grosor].
	var picos: Array = []
	if str(a.get("peinado", "")) == "puntas":
		# Corona de picos hacia atrás y arriba, en abanico.
		for i in 7:
			var t := float(i) / 6.0
			var lado := lerpf(-1.0, 1.0, t)
			var largo := 0.2 + 0.07 * (1.0 - absf(lado))
			picos.append([Vector3(lado * 0.085, 0.25 - absf(lado) * 0.05, -0.06), Vector3(lado * 0.55, 0.55, -1.0), largo, 0.05])
		# Segunda fila, más baja, hacia atrás.
		for i in 5:
			var t2 := float(i) / 4.0
			var lado2 := lerpf(-1.0, 1.0, t2)
			picos.append([Vector3(lado2 * 0.09, 0.15, -0.1), Vector3(lado2 * 0.6, 0.1, -1.0), 0.17, 0.045])
		# Flequillo sobre la frente y mechones a los lados de la cara.
		for x in [-0.075, -0.03, 0.015, 0.06]:
			picos.append([Vector3(x, 0.24, 0.08), Vector3(x * 3.0, -1.0, 0.45), 0.13, 0.03])
		for lado3 in [-1.0, 1.0]:
			picos.append([Vector3(0.105 * lado3, 0.19, 0.05), Vector3(0.15 * lado3, -1.0, 0.1), 0.15, 0.03])
	elif str(a.get("peinado", "")) == "largo":
		# Pelo lacio que cae por la espalda y a los lados, con flequillo.
		for i in 7:
			var t4 := float(i) / 6.0
			var x4 := lerpf(-0.1, 0.1, t4)
			picos.append([Vector3(x4, 0.2, -0.11), Vector3(x4 * 0.6, -1.0, -0.35), 0.42, 0.055])
		for lado4 in [-1.0, 1.0]:
			picos.append([Vector3(0.115 * lado4, 0.2, 0.02), Vector3(0.1 * lado4, -1.0, -0.05), 0.3, 0.045])
		for x5 in [-0.06, -0.02, 0.02, 0.06]:
			picos.append([Vector3(x5, 0.25, 0.09), Vector3(x5 * 2.0, -1.0, 0.5), 0.1, 0.03])
	elif str(a.get("peinado", "")) == "coleta":
		# Recogido atrás con una coleta larga.
		var nudo := Materiales.esfera(0.045, mat, 6)
		_pieza("Cabeza", nudo, Vector3(0, 0.25, -0.14))
		picos.append([Vector3(0, 0.24, -0.16), Vector3(0, -0.6, -1.0), 0.38, 0.06])
		picos.append([Vector3(0, 0.22, -0.17), Vector3(0.15, -1.0, -0.6), 0.3, 0.045])
		for x6 in [-0.07, 0.0, 0.07]:
			picos.append([Vector3(x6, 0.25, 0.08), Vector3(x6 * 3.0, -1.0, 0.45), 0.1, 0.03])
	elif str(a.get("peinado", "")) == "melena":
		# Melena abultada hasta el cuello.
		for i in 10:
			var a7 := lerpf(-2.4, 2.4, float(i) / 9.0)
			var base7 := Vector3(sin(a7) * 0.12, 0.2, cos(a7) * 0.12 - 0.02)
			picos.append([base7, Vector3(sin(a7) * 0.7, -1.0, cos(a7) * 0.3 - 0.4), 0.24, 0.06])
		for x8 in [-0.07, -0.025, 0.025, 0.07]:
			picos.append([Vector3(x8, 0.25, 0.085), Vector3(x8 * 2.5, -1.0, 0.5), 0.12, 0.032])
	else:
		for i in 6:
			var t3 := float(i) / 5.0
			picos.append([Vector3(lerpf(-0.08, 0.08, t3), 0.25, -0.03), Vector3(lerpf(-0.4, 0.4, t3), 1.0, -0.6), 0.08, 0.04])
	for p in picos:
		var dir: Vector3 = (p[1] as Vector3).normalized()
		var largo_p: float = p[2]
		var cono := Materiales.cilindro(0.0, p[3], largo_p, mat, 4)
		# Orientar el eje +Y del cono hacia "dir" y apoyar la base en el cráneo.
		var eje := Vector3.UP.cross(dir)
		if eje.length() > 0.001:
			cono.basis = Basis(eje.normalized(), Vector3.UP.angle_to(dir))
		_pieza("Cabeza", cono, (p[0] as Vector3) + dir * largo_p * 0.45)


func _pieza(nombre_hueso: String, mi: Node3D, pos: Vector3) -> void:
	mi.position = pos
	hueso(nombre_hueso).add_child(mi)


func reproducir(nombre: String, mezcla := 0.12, velocidad := 1.0) -> void:
	if nombre == anim_actual and anim.is_playing():
		return
	if not anim.has_animation(nombre):
		return
	anim_actual = nombre
	anim.play(nombre, mezcla, velocidad)


## Reinicia una animación aunque sea la misma (golpes encadenados).
func reproducir_forzado(nombre: String, mezcla := 0.05) -> void:
	anim_actual = ""
	anim.stop()
	reproducir(nombre, mezcla)


## Ojos según el modo ocular activo (0 = normales).
func poner_ojos(patron: int) -> void:
	(_mat_ojos_normal as ShaderMaterial).set_shader_parameter("patron", float(maxi(patron, 1)))
	poner_sharingan(patron > 0)


func poner_sharingan(activo: bool) -> void:
	if activo == sharingan:
		return
	sharingan = activo
	(_mat_ojos_normal as ShaderMaterial).set_shader_parameter("activo", 1.0 if activo else 0.0)
	if modelo_ia:
		for o in _ojos:
			o.visible = activo
	_luz_ojos.light_energy = 0.8 if activo else 0.0


## Posición global de la mano derecha (para el rayo).
func mano_derecha() -> Node3D:
	return hueso("ManoD")
