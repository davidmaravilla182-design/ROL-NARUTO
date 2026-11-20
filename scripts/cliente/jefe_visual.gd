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
		# Modelo de Meshy (desde la imagen de GPT) con su textura y el toon del juego; el frente mira a +Z.
		var esc := float(Datos.graficos.get("tres_colas_escala", 1.8))
		var m := Kit.instancia("tres_colas")
		m.scale = Vector3.ONE * esc
		_cuerpo.add_child(m)
		# Meshy no reconstruyó las colas (en la imagen van enroscadas detrás): colas propias que se mecen.
		_crear_colas(Vector3(0, 2.4 * esc, -4.6 * esc), esc * 0.9, Materiales.solido(Color(0.46, 0.3, 0.31), 0.9), Materiales.solido(Color(0.9, 0.58, 0.56), 0.8))
		_ojo = MeshInstance3D.new()   # brillo del ojo rojo encima del modelo
		var os2 := SphereMesh.new()
		os2.radius = 0.45
		os2.height = 0.9
		_ojo.mesh = os2
		_ojo.material_override = Materiales.emisivo(Color(1.0, 0.15, 0.1), 3.5)
		# Posición del ojo en el modelo (data/graficos.json → tres_colas_ojo, medida en Blender).
		var po: Array = Datos.graficos.get("tres_colas_ojo", [0.0, -50.0, 0.0])
		_ojo.position = Vector3(float(po[0]), float(po[1]), float(po[2])) * esc
		_cuerpo.add_child(_ojo)
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.2, 0.15)
		luz.light_energy = 2.0
		luz.omni_range = 8.0
		_ojo.add_child(luz)
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
	_crear_colas(Vector3(0, 2.0, -7.5), 1.0, piel, coral)


func _crear_colas(base: Vector3, esc: float, mat: Material, punta: Material) -> void:
	for c in 3:
		var raiz := Node3D.new()
		raiz.position = base + Vector3((c - 1) * 2.6 * esc, 0, 0)
		raiz.rotation.x = 0.5   # suben un poco hacia atrás
		_cuerpo.add_child(raiz)
		var segs: Array = []
		var padre: Node3D = raiz
		var n := 9
		for i in n:
			var r := lerpf(1.15, 0.45, float(i) / (n - 1)) * esc
			var nodo := Node3D.new()
			nodo.position = Vector3(0, 0, -r * 1.25) if i > 0 else Vector3.ZERO
			padre.add_child(nodo)
			# Segmentos solapados (cola continua, con anillos como de crustáceo).
			var seg := Materiales.esfera(r, mat, 10)
			seg.scale = Vector3(1.0, 0.92, 1.5)
			nodo.add_child(seg)
			if i == n - 1:
				# Aleta en la punta (como en la imagen): dos hojas de coral.
				for lado in [-1.0, 1.0]:
					var aleta := Materiales.cilindro(0.0, r * 0.9, r * 3.2, punta, 4)
					aleta.position = Vector3(lado * r * 0.6, r * 0.9, -r * 0.6)
					aleta.rotation = Vector3(-0.9, 0, lado * 0.5)
					aleta.scale = Vector3(1, 1, 0.25)
					nodo.add_child(aleta)
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
			# Se enroscan hacia arriba (como en la imagen) y se mecen con una onda que va hacia la punta.
			(segs[i] as Node3D).rotation = Vector3(0.22 + sin(_t * 1.6 + i * 0.5 + c) * 0.08, sin(_t * 1.1 - i * 0.6 + c * 2.0) * 0.18, 0)
	if _ojo != null:
		var m := _ojo.material_override as StandardMaterial3D
		if m != null:
			m.emission_energy_multiplier = 1.0 if aturdido else 3.5 + sin(_t * 4.0) * 0.8
	if falsa:
		_cuerpo.visible = not translucida or int(_t * 6.0) % 2 == 0
