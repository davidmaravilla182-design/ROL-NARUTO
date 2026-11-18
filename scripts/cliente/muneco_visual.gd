class_name MunecoVisual
extends Node3D
## Muñeco de práctica de madera (poste, travesaño y cabeza de paja), hecho por código.

var _cuerpo: Node3D
var _sacudida := 0.0
var _caido := false
var _angulo_caida := 0.0


func construir() -> void:
	if ResourceLoader.exists("res://assets/modelos/muneco_cuerpo.glb"):
		# Modelo de Blender: base fija y cuerpo que se sacude (pivote en el suelo).
		add_child(Kit.instancia("muneco"))
		_cuerpo = Node3D.new()
		add_child(_cuerpo)
		_cuerpo.add_child(Kit.instancia("muneco_cuerpo"))
		return
	var madera := Materiales.solido(Color(0.42, 0.29, 0.18), 0.9)
	var madera_osc := Materiales.solido(Color(0.3, 0.2, 0.12), 0.9)
	var paja := Materiales.solido(Color(0.72, 0.62, 0.38), 1.0)
	var cuerda := Materiales.solido(Color(0.65, 0.58, 0.45), 1.0)
	var base := Materiales.cilindro(0.3, 0.36, 0.12, madera_osc, 8)
	base.position = Vector3(0, 0.06, 0)
	add_child(base)
	_cuerpo = Node3D.new()
	add_child(_cuerpo)
	var poste := Materiales.cilindro(0.13, 0.15, 1.5, madera, 8)
	poste.position = Vector3(0, 0.8, 0)
	_cuerpo.add_child(poste)
	var travesano := Materiales.cilindro(0.06, 0.06, 1.1, madera, 6)
	travesano.position = Vector3(0, 1.25, 0)
	travesano.rotation_degrees = Vector3(0, 0, 90)
	_cuerpo.add_child(travesano)
	var torso := Materiales.cilindro(0.2, 0.22, 0.55, paja, 8)
	torso.position = Vector3(0, 1.05, 0)
	_cuerpo.add_child(torso)
	for y in [0.88, 1.2]:
		var aro := Materiales.cilindro(0.225, 0.225, 0.04, cuerda, 8)
		aro.position = Vector3(0, y, 0)
		_cuerpo.add_child(aro)
	var cabeza := Materiales.esfera(0.17, paja, 8)
	cabeza.position = Vector3(0, 1.68, 0)
	_cuerpo.add_child(cabeza)
	var diana := Materiales.cilindro(0.08, 0.08, 0.02, Materiales.solido(Color(0.7, 0.12, 0.1), 0.8), 8)
	diana.rotation_degrees = Vector3(90, 0, 0)
	diana.position = Vector3(0, 1.05, 0.21)
	_cuerpo.add_child(diana)
	Materiales.fusionar(_cuerpo)
	Materiales.fusionar(self)


func golpeado() -> void:
	_sacudida = 1.0


func poner_caido(caido: bool) -> void:
	_caido = caido


func _process(delta: float) -> void:
	_sacudida = maxf(_sacudida - delta * 3.0, 0.0)
	var objetivo := -80.0 if _caido else 0.0
	_angulo_caida = move_toward(_angulo_caida, objetivo, delta * 240.0)
	_cuerpo.rotation_degrees = Vector3(_angulo_caida + sin(Time.get_ticks_msec() * 0.04) * 12.0 * _sacudida, 0, cos(Time.get_ticks_msec() * 0.05) * 8.0 * _sacudida)
