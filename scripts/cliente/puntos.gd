class_name Puntos
extends RefCounted
## Puntos marcados de cada distrito: misiones (columna de luz ámbar con rombo que gira) y
## aldeanos (figura sencilla con sombrero de paja y marcador lila). Viven en el sector de su distrito.


## Puntos con los que se puede interactuar: [{nodo, tipo, distrito, nombre}] (el cliente busca el más cercano).
static var lista: Array = []
static var _dialogos: Dictionary = {}


static func construir(e: Escenario, m: Mapa) -> void:
	lista.clear()
	var k := 0
	for pt in m.puntos:
		var c: Vector2 = pt["centro"]
		var n := mision(c) if pt["tipo"] == "mision" else aldeano(c, int(c.x * 13.0 + c.y * 7.0))
		e.sectores.agregar(n, c)
		n.global_position = Vector3(c.x, 0, c.y)
		if n is Aldeano:
			# Ruta corta de ida y vuelta por un tramo libre (se prueba en 8 direcciones).
			var al: Aldeano = n
			al.a = n.global_position
			al.b = al.a
			for i in 8:
				var ang := float((k * 3 + i) % 8) * TAU / 8.0
				var dir := Vector2.from_angle(ang)
				var largo := 6.0 + float(k % 3) * 2.0
				var libre := true
				for paso in range(1, int(largo) + 1):
					if m.punto_bloqueado(c + dir * float(paso), 0.5) or m.en_canal(c + dir * float(paso)):
						libre = false
						break
				if libre:
					al.b = al.a + Vector3(dir.x, 0, dir.y) * largo
					break
		lista.append({"nodo": n, "tipo": pt["tipo"], "distrito": pt["distrito"]})
		k += 1


static func dialogos() -> Dictionary:
	if _dialogos.is_empty():
		_dialogos = Datos.leer_json("dialogos.json")
	return _dialogos


## Texto al interactuar: un aldeano dice una frase de su distrito (o una común); una misión dice cuál será.
static func texto(p: Dictionary, nombre_distrito: String) -> String:
	var d := dialogos()
	if p["tipo"] == "mision":
		return "Misión: próximamente\n«%s» · %s" % [str(d.get("misiones", {}).get(p["distrito"], "")), nombre_distrito]
	var frases: Array = (d.get("distritos", {}).get(p["distrito"], []) as Array).duplicate()
	if randf() < 0.35:
		frases = d.get("comunes", [])
	return "Aldeano: «%s»" % str(frases[randi() % frases.size()]) if not frases.is_empty() else "…"


static func mision(_c: Vector2) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "mision"
	var col := Color(1.0, 0.72, 0.3)
	var haz := Materiales.cilindro(0.35, 0.35, 9.0, Materiales.emisivo(col, 1.4), 10)
	haz.position = Vector3(0, 4.5, 0)
	haz.transparency = 0.55
	haz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(haz)
	var rombo := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.9, 0.9, 0.9)
	pm.material = Materiales.emisivo(col, 3.0)
	rombo.mesh = pm
	rombo.position = Vector3(0, 3.0, 0)
	rombo.rotation_degrees = Vector3(180, 0, 0)
	rombo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(rombo)
	var tw := rombo.create_tween().set_loops()
	tw.tween_property(rombo, "rotation_degrees:y", 360.0, 3.0).from(0.0)
	var luz := OmniLight3D.new()
	luz.light_color = col
	luz.light_energy = 1.4
	luz.omni_range = 7.0
	luz.position = Vector3(0, 2.5, 0)
	raiz.add_child(luz)
	return raiz


static func aldeano(_c: Vector2, semilla: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var raiz := Aldeano.new()
	raiz.name = "aldeano"
	var cuerpo_n := Node3D.new()
	raiz.add_child(cuerpo_n)
	raiz.cuerpo = cuerpo_n
	var tela := Materiales.solido(Color.from_hsv(rng.randf_range(0.55, 0.8), 0.25, rng.randf_range(0.25, 0.45)), 0.8)
	var piel := Materiales.solido(Color(0.86, 0.7, 0.58), 0.7)
	var cuerpo := Materiales.cilindro(0.22, 0.32, 1.1, tela, 10)
	cuerpo.position = Vector3(0, 0.55, 0)
	cuerpo_n.add_child(cuerpo)
	var cabeza := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.17
	esf.height = 0.34
	esf.material = piel
	cabeza.mesh = esf
	cabeza.position = Vector3(0, 1.3, 0)
	cuerpo_n.add_child(cabeza)
	var sombrero := Materiales.cilindro(0.02, 0.42, 0.18, Materiales.solido(Color(0.7, 0.58, 0.34), 0.95), 12)
	sombrero.position = Vector3(0, 1.48, 0)
	cuerpo_n.add_child(sombrero)
	var marca := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.3, 0.35, 0.3)
	pm.material = Materiales.emisivo(Color(0.75, 0.55, 1.0), 2.4)
	marca.mesh = pm
	marca.rotation_degrees = Vector3(180, 0, 0)
	marca.position = Vector3(0, 2.0, 0)
	marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(marca)
	var tw := marca.create_tween().set_loops()
	tw.tween_property(marca, "position:y", 2.2, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(marca, "position:y", 2.0, 0.8).set_trans(Tween.TRANS_SINE)
	return raiz
