class_name Aldeano
extends Node3D
## Aldeano que camina una ruta corta de ida y vuelta (con pausas) por su distrito.
## Solo se mueve mientras su sector está activo (el sector desactiva el procesamiento).

var a := Vector3.ZERO
var b := Vector3.ZERO
var velocidad := 1.1
var _t := 0.0
var _pausa := 0.0
var _ida := true
var cuerpo: Node3D


func _process(delta: float) -> void:
	if a == b:
		return
	if _pausa > 0.0:
		_pausa -= delta
		return
	var meta := b if _ida else a
	var d := meta - global_position
	d.y = 0.0
	if d.length() < 0.1:
		_ida = not _ida
		_pausa = randf_range(1.5, 4.0)
		return
	var paso := d.normalized() * minf(velocidad * delta, d.length())
	global_position += paso
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, delta * 6.0))
	# Balanceo al caminar.
	_t += delta * 7.0
	if cuerpo != null:
		cuerpo.position.y = absf(sin(_t)) * 0.05
		cuerpo.rotation.z = sin(_t) * 0.05
