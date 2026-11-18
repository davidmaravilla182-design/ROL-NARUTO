class_name PersonajeVisual
extends Node3D
## Humanoide low-poly hecho por código: Skeleton3D con huesos, piezas rígidas
## fijadas con BoneAttachment3D, ropa (Vestimenta) y animaciones (Animaciones).
## Solo dibuja: su estado lo decide el servidor.

const HUESOS := [
	["Caderas", "", Vector3(0, 0.95, 0)],
	["Columna", "Caderas", Vector3(0, 0.1, 0)],
	["Pecho", "Columna", Vector3(0, 0.2, 0)],
	["Cuello", "Pecho", Vector3(0, 0.27, 0)],
	["Cabeza", "Cuello", Vector3(0, 0.07, 0)],
	["BrazoI", "Pecho", Vector3(0.22, 0.22, 0)],
	["AntebrazoI", "BrazoI", Vector3(0, -0.27, 0)],
	["ManoI", "AntebrazoI", Vector3(0, -0.24, 0)],
	["BrazoD", "Pecho", Vector3(-0.22, 0.22, 0)],
	["AntebrazoD", "BrazoD", Vector3(0, -0.27, 0)],
	["ManoD", "AntebrazoD", Vector3(0, -0.24, 0)],
	["PiernaI", "Caderas", Vector3(0.1, -0.04, 0)],
	["RodillaI", "PiernaI", Vector3(0, -0.42, 0)],
	["PieI", "RodillaI", Vector3(0, -0.42, 0)],
	["PiernaD", "Caderas", Vector3(-0.1, -0.04, 0)],
	["RodillaD", "PiernaD", Vector3(0, -0.42, 0)],
	["PieD", "RodillaD", Vector3(0, -0.42, 0)],
]

var esqueleto: Skeleton3D
var anim: AnimationPlayer
var _adjuntos: Dictionary = {}
var _ojos: Array[MeshInstance3D] = []
var _mat_ojos_normal: Material
var _mat_ojos_sharingan: Material
var _luz_ojos: OmniLight3D
var anim_actual := ""
var sharingan := false


func construir(plantilla_id: String) -> void:
	var d := Datos.personaje(plantilla_id)
	var aspecto: Dictionary = d.get("aspecto", {})
	var aldea := Datos.aldea(str(d.get("aldea", "")))
	var clan: Dictionary = Datos.mundo.get("clanes", {}).get(str(d.get("clan", "")), {})

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
		_adjuntos[h[0]] = ba

	_construir_cuerpo(aspecto)
	Vestimenta.vestir(self, aspecto, aldea, clan)

	anim = AnimationPlayer.new()
	anim.name = "Animador"
	add_child(anim)
	var nombres: Array = []
	for h in HUESOS:
		nombres.append(h[0])
	anim.add_animation_library("", Animaciones.crear_libreria("Esqueleto", nombres, HUESOS[0][2]))
	reproducir("quieto")


func hueso(nombre: String) -> BoneAttachment3D:
	return _adjuntos[nombre]


func _construir_cuerpo(a: Dictionary) -> void:
	var piel := Materiales.solido(Datos.color(str(a.get("piel", "#e8c4a0"))), 0.7)
	var camisa := Materiales.solido(Datos.color(str(a.get("camisa", "#1d2333"))), 0.9)
	var pantalon := Materiales.solido(Datos.color(str(a.get("pantalon", "#252a3a"))), 0.9)
	var pelo := Materiales.solido(Datos.color(str(a.get("pelo", "#141418"))), 0.6)

	_pieza("Caderas", Materiales.caja(Vector3(0.31, 0.16, 0.19), pantalon), Vector3(0, -0.01, 0))
	_pieza("Columna", Materiales.caja(Vector3(0.29, 0.2, 0.18), camisa), Vector3(0, 0.1, 0))
	_pieza("Pecho", Materiales.caja(Vector3(0.36, 0.26, 0.2), camisa), Vector3(0, 0.12, 0))
	_pieza("Cuello", Materiales.cilindro(0.05, 0.055, 0.1, piel, 6), Vector3(0, 0.03, 0))

	# Cabeza low-poly
	var cabeza := Materiales.esfera(0.12, piel, 8)
	cabeza.scale = Vector3(1.0, 1.15, 1.05)
	_pieza("Cabeza", cabeza, Vector3(0, 0.13, 0))
	var nariz := Materiales.caja(Vector3(0.025, 0.04, 0.03), piel)
	_pieza("Cabeza", nariz, Vector3(0, 0.1, 0.125))
	_mat_ojos_normal = Materiales.solido(Datos.color(str(a.get("ojos", "#1a1a1a"))), 0.3)
	_mat_ojos_sharingan = Materiales.emisivo(Color(1.0, 0.05, 0.05), 4.0)
	for lado in [-1.0, 1.0]:
		var ojo := Materiales.caja(Vector3(0.038, 0.02, 0.012), _mat_ojos_normal)
		_pieza("Cabeza", ojo, Vector3(0.045 * lado, 0.135, 0.118))
		_ojos.append(ojo)
		var ceja := Materiales.caja(Vector3(0.045, 0.01, 0.01), pelo)
		ceja.rotation_degrees = Vector3(0, 0, -10 * lado)
		_pieza("Cabeza", ceja, Vector3(0.045 * lado, 0.158, 0.12))
		var oreja := Materiales.caja(Vector3(0.02, 0.05, 0.035), piel)
		_pieza("Cabeza", oreja, Vector3(0.122 * lado, 0.12, 0.0))
	_luz_ojos = OmniLight3D.new()
	_luz_ojos.light_color = Color(1, 0.1, 0.1)
	_luz_ojos.omni_range = 0.6
	_luz_ojos.light_energy = 0.0
	_luz_ojos.position = Vector3(0, 0.14, 0.2)
	hueso("Cabeza").add_child(_luz_ojos)
	_pelo(a, pelo)

	# Brazos y piernas
	for lado in ["I", "D"]:
		_pieza("Brazo" + lado, Materiales.capsula(0.058, 0.3, camisa), Vector3(0, -0.13, 0))
		_pieza("Antebrazo" + lado, Materiales.capsula(0.048, 0.27, piel), Vector3(0, -0.12, 0))
		_pieza("Mano" + lado, Materiales.caja(Vector3(0.065, 0.09, 0.045), piel), Vector3(0, -0.05, 0.005))
		_pieza("Pierna" + lado, Materiales.capsula(0.078, 0.46, pantalon), Vector3(0, -0.21, 0))
		_pieza("Rodilla" + lado, Materiales.capsula(0.062, 0.42, pantalon), Vector3(0, -0.2, 0))
		_pieza("Pie" + lado, Materiales.caja(Vector3(0.085, 0.05, 0.2), piel), Vector3(0, -0.025, 0.04))


func _pelo(a: Dictionary, mat: Material) -> void:
	var casco := Materiales.esfera(0.13, mat, 8)
	casco.scale = Vector3(1.02, 0.95, 1.08)
	_pieza("Cabeza", casco, Vector3(0, 0.17, -0.02))
	if str(a.get("peinado", "")) == "puntas":
		# Puntas hacia atrás y flequillo a los lados (estilo low-poly).
		var puntas := [
			[Vector3(0, 0.24, -0.08), Vector3(-120, 0, 0), 0.16],
			[Vector3(0.07, 0.2, -0.1), Vector3(-130, 0, -25), 0.14],
			[Vector3(-0.07, 0.2, -0.1), Vector3(-130, 0, 25), 0.14],
			[Vector3(0.04, 0.12, -0.12), Vector3(-150, 0, -15), 0.13],
			[Vector3(-0.04, 0.12, -0.12), Vector3(-150, 0, 15), 0.13],
			[Vector3(0, 0.27, 0.0), Vector3(-80, 0, 0), 0.1],
		]
		for p in puntas:
			var cono := Materiales.cilindro(0.0, 0.045, p[2], mat, 5)
			cono.rotation_degrees = p[1]
			_pieza("Cabeza", cono, p[0])
		for lado in [-1.0, 1.0]:
			var mechon := Materiales.cilindro(0.0, 0.03, 0.15, mat, 4)
			mechon.rotation_degrees = Vector3(170, 0, 8 * lado)
			_pieza("Cabeza", mechon, Vector3(0.095 * lado, 0.13, 0.08))


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


func poner_sharingan(activo: bool) -> void:
	if activo == sharingan:
		return
	sharingan = activo
	for o in _ojos:
		o.material_override = _mat_ojos_sharingan if activo else null
		o.scale = Vector3(1.0, 1.3, 1.0) if activo else Vector3.ONE
	_luz_ojos.light_energy = 1.5 if activo else 0.0


## Posición global de la mano derecha (para el rayo).
func mano_derecha() -> Node3D:
	return hueso("ManoD")
