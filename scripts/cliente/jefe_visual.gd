class_name JefeVisual
extends Node3D
## El Tres Colas en el cliente. Si existe assets/modelos/tres_colas.glb (pedido a GPT → Meshy) se usa ese modelo;
## mientras tanto, un marcador procedural: caparazón abombado con púas de coral, cabeza con un gran ojo rojo,
## patas y tres colas que se mecen. Respira, se balancea en el agua, rueda (fase 2) y se aturde.

const ESCALA := 1.0
var _cuerpo: Node3D
var _colas: Array = []
var _ojo: MeshInstance3D
var _t := 0.0
var rodando := false
var aturdido := false
var falsa := false
var translucida := false


func construir() -> void:
	_cuerpo = Node3D.new()
	add_child(_cuerpo)
	if ResourceLoader.exists("res://assets/modelos/tres_colas.glb"):
		var m := (load("res://assets/modelos/tres_colas.glb") as PackedScene).instantiate()
		m.scale = Vector3.ONE * 1.0
		_cuerpo.add_child(m)
		return
	var gris := _mat(Color(0.28, 0.31, 0.34))
	var piel := _mat(Color(0.33, 0.47, 0.47))
	var coral := _mat(Color(0.92, 0.62, 0.6))
	# Caparazón.
	var concha := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 7.0
	sm.height = 9.0
	sm.radial_segments = 28
	sm.rings = 14
	concha.mesh = sm
	concha.material_override = gris
	concha.scale = Vector3(1.0, 0.75, 1.15)
	concha.position.y = 3.0
	_cuerpo.add_child(concha)
	# Púas de coral sobre el caparazón (anillos).
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for anillo in 4:
		var n := 8 + anillo * 4
		var lat := 0.25 + anillo * 0.2
		for k in n:
			var a := TAU * k / n + rng.randf() * 0.2
			var dir := Vector3(cos(a) * cos(lat), sin(lat), sin(a) * cos(lat))
			var pua := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.45 + rng.randf() * 0.3
			cm.height = 2.0 + rng.randf() * 1.6
			cm.radial_segments = 5
			pua.mesh = cm
			pua.material_override = coral
			pua.position = Vector3(dir.x * 7.0, dir.y * 5.4 + 3.0, dir.z * 8.0)
			pua.look_at_from_position(pua.position, pua.position + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
			pua.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
			_cuerpo.add_child(pua)
	# Cabeza con un gran ojo (frente = +Z).
	var cabeza := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 2.6
	cs.height = 4.4
	cabeza.mesh = cs
	cabeza.material_override = piel
	cabeza.position = Vector3(0, 2.2, 8.6)
	cabeza.scale = Vector3(1.2, 0.9, 1.3)
	_cuerpo.add_child(cabeza)
	_ojo = MeshInstance3D.new()
	var os_ := SphereMesh.new()
	os_.radius = 0.75
	os_.height = 1.5
	_ojo.mesh = os_
	_ojo.material_override = Materiales.emisivo(Color(1.0, 0.15, 0.1), 3.5)
	_ojo.position = Vector3(-1.1, 3.0, 10.9)
	_cuerpo.add_child(_ojo)
	var cicatriz := Materiales.caja(Vector3(1.4, 0.16, 0.16), _mat(Color(0.15, 0.15, 0.17)))
	cicatriz.position = Vector3(1.1, 3.0, 11.1)
	cicatriz.rotation.z = 0.4
	_cuerpo.add_child(cicatriz)
	# Patas.
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			var pata := Materiales.cilindro(1.0, 1.3, 3.4, piel, 8)
			pata.position = Vector3(lx * 5.2, 0.4, lz * 4.6)
			_cuerpo.add_child(pata)
	# Tres colas (cadenas de segmentos que se mecen).
	for c in 3:
		var raiz := Node3D.new()
		raiz.position = Vector3((c - 1) * 2.6, 2.0, -7.5)
		_cuerpo.add_child(raiz)
		var segs: Array = []
		var padre: Node3D = raiz
		for i in 7:
			var nodo := Node3D.new()
			nodo.position = Vector3(0, 0, -1.6) if i > 0 else Vector3.ZERO
			padre.add_child(nodo)
			var seg := Materiales.esfera(1.1 - i * 0.12, piel if i < 5 else coral, 8)
			seg.scale = Vector3(1, 0.8, 1.3)
			nodo.add_child(seg)
			segs.append(nodo)
			padre = nodo
		_colas.append(segs)


func _mat(c: Color) -> Material:
	return Materiales.solido(c, 0.6)


func _process(d: float) -> void:
	if _cuerpo == null:
		return
	_t += d
	# Respira y se mece en el agua.
	_cuerpo.position.y = sin(_t * 0.9) * 0.35
	_cuerpo.rotation.z = sin(_t * 0.6) * 0.03
	if rodando:
		_cuerpo.rotation.x += d * 9.0
	else:
		_cuerpo.rotation.x = lerp_angle(_cuerpo.rotation.x, 0.0, minf(1.0, d * 4.0))
	for c in _colas.size():
		var segs: Array = _colas[c]
		for i in segs.size():
			(segs[i] as Node3D).rotation = Vector3(sin(_t * 1.6 + i * 0.5 + c) * 0.12, sin(_t * 1.1 - i * 0.6 + c * 2.0) * 0.25, 0)
	if _ojo != null:
		var m := _ojo.material_override as StandardMaterial3D
		if m != null:
			m.emission_energy_multiplier = 1.0 if aturdido else 3.5 + sin(_t * 4.0) * 0.8
	if falsa:
		_cuerpo.visible = not translucida or int(_t * 6.0) % 2 == 0
