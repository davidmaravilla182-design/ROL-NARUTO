class_name DragonVivo
extends Node3D
## Modelo de jutsu con cadena de huesos (tools/blender/cadena_jutsu.py): ondula como una serpiente con una onda que
## viaja de la cabeza (S0) a la cola, entra con anticipación (se encoge y se estira) y se desvanece en partículas.

var esqueleto: Skeleton3D
var malla: MeshInstance3D
var amplitud := 0.32          # radianes por hueso (la onda se suma a lo largo de la cadena)
var frecuencia := 6.0          # rad/s
var longitud_onda := 0.9       # desfase entre huesos (rad)
var amplitud_vertical := 0.12
var _t := 0.0
var _ejes: Array = []          # [eje lateral, eje vertical] en el espacio local de cada hueso
var _reposo: Array = []
var _muriendo := false


static func crear(nombre: String, material: Material) -> DragonVivo:
	var ruta := "res://assets/modelos/jutsu_%s_cadena.glb" % nombre
	if not ResourceLoader.exists(ruta):
		return null
	var escena := (load(ruta) as PackedScene).instantiate()
	var d := DragonVivo.new()
	d.add_child(escena)
	d.esqueleto = d._buscar(escena, "Skeleton3D") as Skeleton3D
	d.malla = d._buscar(escena, "MeshInstance3D") as MeshInstance3D
	if d.esqueleto == null or d.malla == null:
		d.free()
		return null
	if material != null:
		d.malla.material_override = material
	d.malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d._preparar()
	return d


func _buscar(n: Node, clase: String) -> Node:
	if n.is_class(clase):
		return n
	for c in n.get_children():
		var r := _buscar(c, clase)
		if r != null:
			return r
	return null


func _preparar() -> void:
	for i in esqueleto.get_bone_count():
		var g := esqueleto.get_bone_global_rest(i)
		var dir := (esqueleto.get_bone_global_rest(i).basis * Vector3.UP).normalized()   # el hueso apunta por su +Y
		# Cuerpo horizontal: ondula de lado (giro sobre la vertical). Cuerpo erguido: se mece hacia los lados.
		var lateral := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.7 else Vector3.BACK
		var vertical := dir.cross(lateral).normalized()
		var inv := g.basis.inverse()
		_ejes.append([(inv * lateral).normalized(), (inv * vertical).normalized()])
		_reposo.append(esqueleto.get_bone_pose_rotation(i))


## Entrada con anticipación: aparece encogido, se estira de golpe un poco más de su tamaño y se asienta.
func anticipar(escala_final: float, segundos := 0.35) -> void:
	scale = Vector3.ONE * escala_final * 0.35
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * escala_final * 1.12, segundos * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE * escala_final, segundos * 0.3)


## Desvanecido: se agita más, se vuelve transparente y suelta partículas del color dado.
func desvanecer(color: Color, efectos: Efectos = null, segundos := 0.45) -> void:
	if _muriendo:
		return
	_muriendo = true
	amplitud *= 1.6
	frecuencia *= 1.8
	if efectos != null:
		efectos.rafaga(global_position, {"cantidad": 50, "vida": 0.7, "radio": 1.2 * scale.x, "vel_min": 1.5, "vel_max": 5.0,
			"tam_min": 0.12, "tam_max": 0.3, "frenado": 2.0, "color": Color(color.r, color.g, color.b, 0.8)})
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(malla, "transparency", 1.0, segundos)
	tw.tween_property(self, "scale", scale * 1.15, segundos)
	tw.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	if esqueleto == null:
		return
	_t += delta
	var n := esqueleto.get_bone_count()
	for i in n:
		# Más amplitud hacia la cola; la cabeza apenas se mueve (mira al objetivo).
		var peso := lerpf(0.25, 1.0, float(i) / maxf(n - 1, 1))
		var fase := _t * frecuencia - float(i) * longitud_onda
		var ejes: Array = _ejes[i]
		var q := Quaternion(ejes[0], sin(fase) * amplitud * peso) * Quaternion(ejes[1], cos(fase * 0.7) * amplitud_vertical * peso)
		esqueleto.set_bone_pose_rotation(i, _reposo[i] * q)
