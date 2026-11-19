class_name NudoBanda
extends Node3D
## Nudo de la banda en la nuca con dos puntas que cuelgan y se mecen: con un vaivén suave
## y hacia atrás cuando el personaje se mueve (inercia aproximada por la velocidad del nudo).

var _puntas: Array = []
var _prev := Vector3.INF
var _vel := Vector3.ZERO
var _t := 0.0


func construir(color: Color) -> void:
	var mat := Materiales.solido(color, 0.9)
	var nudo := Materiales.esfera(0.03, mat, 8)
	nudo.scale = Vector3(1.3, 0.9, 0.8)
	add_child(nudo)
	for lado in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(0.012 * lado, -0.005, -0.01)
		add_child(piv)
		var tira := Materiales.caja(Vector3(0.026, 0.14, 0.007), mat)
		tira.position = Vector3(0, -0.07, 0)
		piv.add_child(tira)
		piv.set_meta("lado", lado)
		_puntas.append(piv)
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	var p := global_position
	if _prev != Vector3.INF and delta > 0.0:
		_vel = _vel.lerp((p - _prev) / delta, minf(1.0, delta * 8.0))
	_prev = p
	# Velocidad en el espacio del personaje: hacia delante levanta las puntas hacia atrás.
	var local := global_transform.basis.inverse() * _vel
	var hacia_atras := clampf(local.z * 0.12, -0.2, 0.9)
	var lateral := clampf(-local.x * 0.1, -0.5, 0.5)
	for piv in _puntas:
		var lado: float = piv.get_meta("lado")
		var vaiven := sin(_t * 2.3 + lado) * 0.08 + sin(_t * 5.1) * 0.03
		piv.rotation = Vector3(0.25 + hacia_atras + vaiven, 0.0, lado * 0.22 + lateral)
