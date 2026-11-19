class_name GolemVivo
extends Node3D
## Gólem de tierra con esqueleto (tools/blender/golem_animado.py): sale del suelo golpeándose el pecho, camina con
## peso (polvo y temblor en cada pisada), prepara el puñetazo antes del golpe del servidor y se derrumba en rocas.

var anim: AnimationPlayer
var malla: MeshInstance3D
var efectos: Efectos
var _conf: Dictionary = {}
var _estado := "surgir"
var _t_paso := 0.0
var _muriendo := false


static func crear(ef: Efectos) -> GolemVivo:
	var ruta := "res://assets/modelos/jutsu_golem_animado.glb"
	if not ResourceLoader.exists(ruta):
		return null
	var escena := (load(ruta) as PackedScene).instantiate()
	var g := GolemVivo.new()
	g.add_child(escena)
	g.efectos = ef
	g.anim = g._buscar(escena, "AnimationPlayer") as AnimationPlayer
	g.malla = g._buscar(escena, "MeshInstance3D") as MeshInstance3D
	if g.anim == null:
		g.free()
		return null
	g._conf = Datos.graficos.get("golem_animado", {})
	if g.malla != null:
		g.malla.material_override = Kit.material_para("jutsu_golem_animado")
	return g


func _buscar(n: Node, clase: String) -> Node:
	if n.is_class(clase):
		return n
	for c in n.get_children():
		var r := _buscar(c, clase)
		if r != null:
			return r
	return null


func _nombre(a: String) -> String:
	for n in anim.get_animation_list():
		if n == a or n.ends_with("/" + a) or n.begins_with(a):
			return n
	return ""


## Sale del suelo y se golpea el pecho (rápido: la parte buena de la animación).
func surgir() -> void:
	var n := _nombre("surgir")
	if n != "":
		anim.play(n, 0.0, 1.8)
	_estado = "surgir"
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(func(): if _estado == "surgir": _estado = "quieto")


## Velocidad horizontal actual (m/s): camina con la cadencia ajustada; si no se mueve, se queda plantado.
func moverse(vel: float) -> void:
	if _muriendo or _estado in ["surgir", "golpe"]:
		return
	var n := _nombre("caminar")
	if n == "":
		return
	if vel > 0.4:
		if anim.current_animation != n:
			anim.play(n, 0.25)
		anim.speed_scale = clampf(vel / 2.2, 0.6, 1.6)
		_estado = "caminar"
		# Pisadas con peso: polvo y un pequeño temblor dos veces por ciclo.
		_t_paso -= get_process_delta_time() * anim.speed_scale
		if _t_paso <= 0.0:
			_t_paso = float(_conf.get("duraciones", {}).get("caminar", 1.0)) * 0.5
			if efectos != null:
				efectos.polvo(global_position, 8)
				efectos.sacudir_desde(global_position, 0.08 * scale.x)
	elif _estado == "caminar":
		anim.speed_scale = 1.0
		anim.pause()
		_estado = "quieto"


## Prepara el puñetazo: el tramo de la animación hasta el impacto dura exactamente lo que falta para el golpe.
func preparar_golpe(anticipo: float) -> void:
	if _muriendo:
		return
	var n := _nombre("golpe")
	if n == "":
		return
	var impacto := float(_conf.get("golpe_impacto", 1.6))
	var desde := maxf(impacto - 0.9, 0.0)
	anim.speed_scale = 1.0
	anim.play_section(n, desde, impacto + 0.5, 0.15, (impacto - desde) / maxf(anticipo, 0.1))
	_estado = "golpe"
	var tw := create_tween()
	tw.tween_interval(anticipo + 0.35)
	tw.tween_callback(func(): if _estado == "golpe": _estado = "quieto")


## Se derrumba: cae, se parte en rocas y se hunde en el suelo.
func derrumbar() -> void:
	if _muriendo:
		return
	_muriendo = true
	var n := _nombre("derrumbe")
	if n != "":
		anim.speed_scale = 1.0
		anim.play(n, 0.15, 1.6)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(func():
		if efectos != null:
			efectos.rafaga(global_position + Vector3(0, 0.6 * scale.x, 0), {"cantidad": 30, "vida": 1.1, "radio": 0.8 * scale.x,
				"direccion": Vector3.UP, "dispersion": 70.0, "vel_min": 2.0, "vel_max": 5.0, "gravedad": Vector3(0, -14, 0),
				"tam_min": 0.15 * scale.x, "tam_max": 0.35 * scale.x, "color": Color(0.42, 0.35, 0.28), "aditivo": false})
			efectos.polvo(global_position, 30)
			efectos.sacudir_desde(global_position, 0.25))
	tw.tween_property(self, "position:y", position.y - 2.6 * scale.x, 0.9).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
