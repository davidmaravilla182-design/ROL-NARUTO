class_name Mapa
extends RefCounted
## Distribución del sector de la aldea generada a partir de una semilla.
## Servidor (colisiones, charcos) y cliente (dibujo) generan exactamente el mismo mapa.

var semilla := 0
var limite := 38.0
var obstaculos: Array = []   # [{centro: Vector2, medio: Vector2, alto: float, tipo: String}]
var charcos: Array = []      # [{centro: Vector2, radio: float}]
var pasarelas: Array = []    # [{a: int, b: int, altura: float}] (solo visual)
var munecos: Array = []      # [Vector2]
var inicio_jugador := Vector2.ZERO
var inicio_enemigo := Vector2.ZERO


static func generar(conf: Dictionary = {}) -> Mapa:
	Datos.cargar()
	if conf.is_empty():
		conf = Datos.escenario
	var m := Mapa.new()
	m._generar(conf)
	return m


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _generar(conf: Dictionary) -> void:
	semilla = int(conf.get("semilla", 1))
	limite = float(conf.get("limite_juego", 38.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla

	inicio_jugador = _v2(conf["inicio_jugador"])
	inicio_enemigo = _v2(conf["inicio_enemigo"])
	for p in conf["munecos"]:
		munecos.append(_v2(p))

	# Torres altas de metal alrededor del campo de entrenamiento.
	var t: Dictionary = conf["torres"]
	var intentos := 0
	while obstaculos.size() < int(t["cantidad"]) and intentos < 600:
		intentos += 1
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(float(t["radio_minimo"]), float(t["radio_maximo"]))
		var c := Vector2(cos(ang), sin(ang)) * rad
		var medio := Vector2(rng.randf_range(t["ancho"][0], t["ancho"][1]), rng.randf_range(t["ancho"][0], t["ancho"][1])) * 0.5
		if _se_solapa(c, medio, float(t["separacion"])):
			continue
		obstaculos.append({"centro": c, "medio": medio, "alto": rng.randf_range(t["alto"][0], t["alto"][1]), "tipo": "torre"})

	# Pasarelas entre torres cercanas (decorativas, en altura).
	var n_torres := obstaculos.size()
	for i in n_torres:
		for j in range(i + 1, n_torres):
			var a: Dictionary = obstaculos[i]
			var b: Dictionary = obstaculos[j]
			var d: float = (a["centro"] as Vector2).distance_to(b["centro"])
			if d < 15.0 and rng.randf() < 0.45:
				var alto_max: float = minf(a["alto"], b["alto"]) - 2.0
				if alto_max > 8.0:
					pasarelas.append({"a": i, "b": j, "altura": rng.randf_range(7.0, alto_max)})

	# Cajas/contenedores dentro del campo, lejos de muñecos e inicios.
	var cuantos := int(conf.get("obstaculos_campo", 4))
	intentos = 0
	var colocados := 0
	while colocados < cuantos and intentos < 300:
		intentos += 1
		var ang2 := rng.randf() * TAU
		var c2 := Vector2(cos(ang2), sin(ang2)) * rng.randf_range(10.0, 17.0)
		var medio2 := Vector2(rng.randf_range(0.7, 1.4), rng.randf_range(0.7, 1.4))
		if _se_solapa(c2, medio2, 2.0):
			continue
		if c2.distance_to(inicio_jugador) < 4.0 or c2.distance_to(inicio_enemigo) < 4.0:
			continue
		var lejos := true
		for mu in munecos:
			if c2.distance_to(mu) < 5.0:
				lejos = false
		if not lejos:
			continue
		obstaculos.append({"centro": c2, "medio": medio2, "alto": rng.randf_range(1.0, 2.2), "tipo": "caja"})
		colocados += 1

	# Charcos: algunos fijos (bajo los muñecos, para demostrar la cadena de rayo) y otros aleatorios.
	for ch in conf["charcos_fijos"]:
		charcos.append({"centro": Vector2(float(ch[0]), float(ch[1])), "radio": float(ch[2])})
	var n_ch := int(conf.get("charcos_aleatorios", 10))
	intentos = 0
	while charcos.size() < n_ch + conf["charcos_fijos"].size() and intentos < 400:
		intentos += 1
		var c3 := Vector2(rng.randf_range(-limite, limite), rng.randf_range(-limite, limite)) * 0.9
		var r3 := rng.randf_range(0.8, 2.6)
		if punto_bloqueado(c3, r3):
			continue
		charcos.append({"centro": c3, "radio": r3})


func _se_solapa(c: Vector2, medio: Vector2, margen: float) -> bool:
	for o in obstaculos:
		var oc: Vector2 = o["centro"]
		var om: Vector2 = o["medio"]
		if absf(c.x - oc.x) < medio.x + om.x + margen and absf(c.y - oc.y) < medio.y + om.y + margen:
			return true
	return false


## ¿Está el punto (x,z) sobre un charco?
func en_charco(p: Vector2) -> bool:
	for ch in charcos:
		if p.distance_to(ch["centro"]) <= float(ch["radio"]):
			return true
	return false


## ¿Un círculo de radio r en p toca algún obstáculo?
func punto_bloqueado(p: Vector2, r := 0.0, altura := 0.0) -> bool:
	for o in obstaculos:
		if altura > float(o["alto"]):
			continue
		var oc: Vector2 = o["centro"]
		var om: Vector2 = o["medio"]
		var cerca := Vector2(clampf(p.x, oc.x - om.x, oc.x + om.x), clampf(p.y, oc.y - om.y, oc.y + om.y))
		if cerca.distance_to(p) < r or (cerca == p):
			return true
	return false


## Empuja un círculo fuera de los obstáculos y lo mantiene dentro del límite.
func resolver_colision(p: Vector2, r: float, altura := 0.0) -> Vector2:
	var q := p
	for o in obstaculos:
		if altura > float(o["alto"]):
			continue
		var oc: Vector2 = o["centro"]
		var om: Vector2 = o["medio"]
		var cerca := Vector2(clampf(q.x, oc.x - om.x, oc.x + om.x), clampf(q.y, oc.y - om.y, oc.y + om.y))
		var d := q - cerca
		var dist := d.length()
		if dist < r:
			if dist > 0.0001:
				q = cerca + d / dist * r
			else:
				# Centro dentro de la caja: salir por el lado más cercano.
				var dx := om.x - absf(q.x - oc.x)
				var dz := om.y - absf(q.y - oc.y)
				if dx < dz:
					q.x = oc.x + signf(q.x - oc.x if q.x != oc.x else 1.0) * (om.x + r)
				else:
					q.y = oc.y + signf(q.y - oc.y if q.y != oc.y else 1.0) * (om.y + r)
	q.x = clampf(q.x, -limite, limite)
	q.y = clampf(q.y, -limite, limite)
	return q
