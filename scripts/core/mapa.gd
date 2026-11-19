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
var piezas: Array = []       # trazado: [{tipo, centro: Vector2, giro: float (grados)}]
var plataformas: Array = []  # suelos elevados: [{centro: Vector2, medio: Vector2, altura: float, grosor: float}] (lengua de la torre)
var arcos: Array = []        # [{centro: Vector2, giro: float}]
var tubos: Array = []        # [{centro: Vector2, giro: float, altura: float}]
var canal: Dictionary = {}   # {x_min, x_max, z_sur, z_norte, nivel_agua}
var puentes: Array = []      # posiciones X de los puentes sobre el canal
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

	if conf.has("trazado"):
		_trazado(conf["trazado"])

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


## Trazado fijo hecho con piezas del kit: cada pieza aporta su huella como obstáculo.
func _trazado(tz: Dictionary) -> void:
	var huellas: Dictionary = tz.get("huellas", {})
	for p in tz.get("piezas", []):
		var tipo := str(p["tipo"])
		var c := _v2(p["pos"])
		var giro := float(p.get("giro", 0.0))
		piezas.append({"tipo": tipo, "centro": c, "giro": giro})
		if tipo == "torre_ia":
			_plataforma_torre(c, giro)
		if huellas.has(tipo):
			var h: Array = huellas[tipo]
			var medio := Vector2(float(h[0]), float(h[1])) * 0.5
			var g := int(round(giro / 90.0)) % 2
			if absf(fmod(giro, 90.0)) > 1.0:
				medio = Vector2.ONE * maxf(medio.x, medio.y)
			elif g == 1:
				medio = Vector2(medio.y, medio.x)
			obstaculos.append({"centro": c, "medio": medio, "alto": float(h[2]), "tipo": tipo})
	for a in tz.get("arcos", []):
		arcos.append({"centro": _v2(a["pos"]), "giro": float(a.get("giro", 0.0))})
	for t in tz.get("tubos", []):
		var ct := _v2(t["pos"])
		var gt := float(t.get("giro", 0.0))
		tubos.append({"centro": ct, "giro": gt, "altura": float(t.get("altura", 0.6))})
		var medio_t := Vector2(6.0, 0.6) if int(round(gt / 90.0)) % 2 == 0 else Vector2(0.6, 6.0)
		obstaculos.append({"centro": ct, "medio": medio_t, "alto": float(t.get("altura", 0.6)) + 0.6, "tipo": "tubo"})
	canal = tz.get("canal", {})
	if not canal.is_empty():
		var cx := (float(canal["x_min"]) + float(canal["x_max"])) * 0.5
		var cz := (float(canal["z_sur"]) + float(canal["z_norte"])) * 0.5
		var medio_c := Vector2((float(canal["x_max"]) - float(canal["x_min"])) * 0.5, absf(float(canal["z_sur"]) - float(canal["z_norte"])) * 0.5)
		# El canal frena a los personajes (aunque salten) pero los proyectiles pasan por encima del agua.
		obstaculos.append({"centro": Vector2(cx, cz), "medio": medio_c, "alto": 50.0, "tipo": "canal", "solo_personajes": true})
	puentes = tz.get("puentes", [])


## La lengua de la torre es una plataforma: se puede caer encima y los proyectiles chocan con ella.
func _plataforma_torre(c: Vector2, giro: float) -> void:
	var t: Dictionary = Datos.escenario.get("torre_ia", {})
	if t.is_empty():
		return
	var mn: Array = t["lengua"]["min"]
	var mx: Array = t["lengua"]["max"]
	var g := deg_to_rad(giro)
	var centro_l := Vector2((float(mn[0]) + float(mx[0])) * 0.5, (float(mn[2]) + float(mx[2])) * 0.5).rotated(-g)
	var medio := Vector2(float(mx[0]) - float(mn[0]), float(mx[2]) - float(mn[2])) * 0.5
	if int(round(giro / 90.0)) % 2 == 1:
		medio = Vector2(medio.y, medio.x)
	plataformas.append({"centro": c + centro_l, "medio": medio, "altura": float(t["lengua"]["superficie"]), "grosor": 2.0})


## Altura del suelo bajo un punto: 0 o la superficie de una plataforma si se está encima (o cayendo sobre ella).
func altura_suelo(p: Vector2, y: float) -> float:
	var h := 0.0
	for pl in plataformas:
		var d: Vector2 = (p - pl["centro"]).abs()
		if d.x <= pl["medio"].x and d.y <= pl["medio"].y and y >= float(pl["altura"]) - 0.6:
			h = maxf(h, float(pl["altura"]))
	return h


## ¿El punto está dentro del volumen de una plataforma? (los proyectiles chocan con ella)
func dentro_plataforma(q: Vector3) -> bool:
	for pl in plataformas:
		var d: Vector2 = (Vector2(q.x, q.z) - pl["centro"]).abs()
		if d.x <= pl["medio"].x and d.y <= pl["medio"].y and q.y <= float(pl["altura"]) and q.y >= float(pl["altura"]) - float(pl["grosor"]):
			return true
	return false


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
func punto_bloqueado(p: Vector2, r := 0.0, altura := 0.0, proyectil := false) -> bool:
	for o in obstaculos:
		if altura > float(o["alto"]):
			continue
		if proyectil and o.get("solo_personajes", false):
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
