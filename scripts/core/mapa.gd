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
var props: Array = []        # piezas del suelo de la plaza: [{tipo, centro: Vector2, giro}]
var plataformas: Array = []  # suelos elevados: [{centro: Vector2, medio: Vector2, altura: float, grosor: float}] (lengua de la torre)
var arcos: Array = []        # [{centro: Vector2, giro: float}]
var tubos: Array = []        # [{centro: Vector2, giro: float, altura: float}]
var muralla: Array = []      # tramos de la muralla (solo visual): [{centro: Vector2, giro: float, torre: bool}]
var canal: Dictionary = {}   # {x_min, x_max, z_sur, z_norte, nivel_agua}
var puentes: Array = []      # posiciones X de los puentes sobre el canal
var inicio_jugador := Vector2.ZERO
var inicio_enemigo := Vector2.ZERO
# Aldea completa: isla circular en un lago, muralla y zonas extra caminables (puerta, puente, orilla).
var centro_aldea := Vector2.ZERO
var radio_caminable := 0.0   # 0 = sin isla (mapas de prueba)
var zonas_extra: Array = []  # [Rect2] caminables fuera del círculo
var distritos: Array = []    # [{id, nombre, centro: Vector2, rect: Rect2}]
var puntos: Array = []       # puntos marcados: [{tipo: "mision"|"aldeano", distrito, centro: Vector2, texto}]
# Rejilla espacial de obstáculos (celdas de CELDA m): las consultas solo miran las celdas cercanas.
const CELDA := 8.0
var _rejilla: Dictionary = {}
var _indexados := -1


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

	var al: Dictionary = conf.get("aldea", {})
	if not al.is_empty():
		centro_aldea = _v2(al["centro"])
		radio_caminable = float(al["radio_caminable"])
		for z in al.get("zonas_extra", []):
			zonas_extra.append(Rect2(float(z[0]), float(z[1]), float(z[2]) - float(z[0]), float(z[3]) - float(z[1])))
		for d in al.get("distritos", []):
			var r: Array = d["rect"]
			var rect := Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
			distritos.append({"id": str(d["id"]), "nombre": str(d["nombre"]), "corto": str(d.get("corto", d["nombre"])), "centro": rect.get_center(), "rect": rect})
		for pt in al.get("puntos", []):
			puntos.append({"tipo": str(pt["tipo"]), "distrito": str(pt["distrito"]), "centro": _v2(pt["pos"]), "texto": str(pt.get("texto", ""))})
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

	if conf.has("trazado"):
		_props(conf["trazado"])

	# Charcos: algunos fijos (bajo los muñecos, para demostrar la cadena de rayo) y otros aleatorios.
	for ch in conf["charcos_fijos"]:
		charcos.append({"centro": Vector2(float(ch[0]), float(ch[1])), "radio": float(ch[2])})
	var n_ch := int(conf.get("charcos_aleatorios", 10))
	intentos = 0
	while charcos.size() < n_ch + conf["charcos_fijos"].size() and intentos < 400:
		intentos += 1
		var c3 := Vector2(rng.randf_range(-limite, limite), rng.randf_range(-limite, limite)) * 0.9
		if radio_caminable > 0.0:
			c3 = centro_aldea + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radio_caminable * 0.95
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
		var esc := float(p.get("escala", 1.0))
		piezas.append({"tipo": tipo, "centro": c, "giro": giro, "escala": esc, "tinte": p.get("tinte", [])})
		if tipo == "torre_ia":
			_plataforma_torre(c, giro)
		if huellas.has(tipo) and bool(p.get("colision", true)):
			var h: Array = huellas[tipo]
			var medio := Vector2(float(h[0]), float(h[1])) * 0.5 * esc
			var g := int(round(giro / 90.0)) % 2
			if absf(fmod(giro, 90.0)) > 1.0:
				medio = Vector2.ONE * maxf(medio.x, medio.y)
			elif g == 1:
				medio = Vector2(medio.y, medio.x)
			obstaculos.append({"centro": c, "medio": medio, "alto": float(h[2]) * esc, "tipo": tipo})
	for ox in tz.get("obstaculos_extra", []):
		obstaculos.append({"centro": _v2(ox["pos"]), "medio": _v2(ox["medio"]), "alto": float(ox["alto"]), "tipo": "muro"})
	for mu in tz.get("muralla", []):
		muralla.append({"centro": _v2(mu["pos"]), "giro": float(mu["giro"]), "torre": bool(mu.get("torre", false))})
	for a in tz.get("arcos", []):
		arcos.append({"centro": _v2(a["pos"]), "giro": float(a.get("giro", 0.0))})
	for t in tz.get("tubos", []):
		var ct := _v2(t["pos"])
		var gt := float(t.get("giro", 0.0))
		tubos.append({"centro": ct, "giro": gt, "altura": float(t.get("altura", 0.6))})
		# Solo las tuberías a ras del suelo estorban; las elevadas pasan por encima de las calles.
		if float(t.get("altura", 0.6)) < 2.0:
			var medio_t := Vector2(6.0, 0.6) if int(round(gt / 90.0)) % 2 == 0 else Vector2(0.6, 6.0)
			obstaculos.append({"centro": ct, "medio": medio_t, "alto": float(t.get("altura", 0.6)) + 0.6, "tipo": "tubo"})
	canal = tz.get("canal", {})
	if not canal.is_empty():
		var cx := (float(canal["x_min"]) + float(canal["x_max"])) * 0.5
		var cz := (float(canal["z_sur"]) + float(canal["z_norte"])) * 0.5
		var medio_c := Vector2((float(canal["x_max"]) - float(canal["x_min"])) * 0.5, absf(float(canal["z_sur"]) - float(canal["z_norte"])) * 0.5)
		# El canal frena a los personajes (aunque salten) pero los proyectiles pasan por encima del agua.
		# Se parte en tramos: los puentes dejan pasar.
		puentes = tz.get("puentes", [])
		var cortes: Array = [float(canal["x_min"])]
		var xs: Array = puentes.duplicate()
		xs.sort()
		for px in xs:
			cortes.append(float(px) - 1.6)
			cortes.append(float(px) + 1.6)
		cortes.append(float(canal["x_max"]))
		for k in range(0, cortes.size(), 2):
			var xa: float = cortes[k]
			var xb: float = cortes[k + 1]
			if xb - xa > 0.1:
				obstaculos.append({"centro": Vector2((xa + xb) * 0.5, cz), "medio": Vector2((xb - xa) * 0.5, medio_c.y), "alto": 50.0, "tipo": "canal", "solo_personajes": true})
	for pl in tz.get("plataformas", []):
		var c0 := _v2(pl["pos"])
		var md := _v2(pl["medio"])
		var dato := {"centro": c0, "medio": md, "altura": float(pl["altura"]), "grosor": float(pl.get("grosor", 0.4)), "tipo": str(pl.get("tipo", "pasarela"))}
		if pl.has("altura0"):
			# Rampa / escalera: la altura sube a lo largo del eje ("x" o "z") de altura0 a altura.
			dato["altura0"] = float(pl["altura0"])
			dato["eje"] = str(pl.get("eje", "z"))
		plataformas.append(dato)


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
	plataformas.append({"centro": c + centro_l, "medio": medio, "altura": float(t["lengua"]["superficie"]), "grosor": 2.0, "tipo": "lengua"})


## Altura del suelo bajo un punto: 0, la superficie de una plataforma/rampa o el techo de un obstáculo
## si se está encima (o cayendo sobre él). Así todos los techos y niveles son caminables.
func altura_suelo(p: Vector2, y: float) -> float:
	var h := 0.0
	for pl in plataformas:
		var d: Vector2 = (p - pl["centro"]).abs()
		if d.x <= pl["medio"].x and d.y <= pl["medio"].y:
			var sup := _superficie(pl, p)
			if y >= sup - 0.6:
				h = maxf(h, sup)
	for o in _cerca(p, 0.0):
		if o.get("solo_personajes", false) or o["tipo"] == "torre_ia":
			continue
		var d2: Vector2 = (p - o["centro"]).abs()
		var alto := float(o["alto"])
		if d2.x <= o["medio"].x and d2.y <= o["medio"].y and y >= alto - 0.6:
			h = maxf(h, alto)
	return h


func _superficie(pl: Dictionary, p: Vector2) -> float:
	if not pl.has("altura0"):
		return float(pl["altura"])
	var md: Vector2 = pl["medio"]
	var t := 0.0
	if pl["eje"] == "x":
		t = (p.x - (pl["centro"] as Vector2).x + md.x) / (2.0 * md.x)
	else:
		t = (p.y - (pl["centro"] as Vector2).y + md.y) / (2.0 * md.y)
	return lerpf(float(pl["altura0"]), float(pl["altura"]), clampf(t, 0.0, 1.0))


## Altura de la pared más alta que toca un círculo (para escalar con chakra); 0 si no toca ninguna.
func altura_pared(p: Vector2, r: float, y: float) -> float:
	var h := 0.0
	for o in _cerca(p, r):
		if o.get("solo_personajes", false):
			continue
		var alto := float(o["alto"])
		if alto <= y:
			continue
		var oc: Vector2 = o["centro"]
		var om: Vector2 = o["medio"]
		var cerca := Vector2(clampf(p.x, oc.x - om.x, oc.x + om.x), clampf(p.y, oc.y - om.y, oc.y + om.y))
		if cerca.distance_to(p) <= r:
			h = maxf(h, alto)
	return h


## Distrito en el que está un punto ("" si ninguno).
func distrito_en(p: Vector2) -> String:
	for d in distritos:
		if (d["rect"] as Rect2).has_point(p):
			return d["id"]
	return ""


func distrito(id: String) -> Dictionary:
	for d in distritos:
		if d["id"] == id:
			return d
	return {}


# ---------------------------------------------------------------- rejilla espacial

func _indexar() -> void:
	_rejilla.clear()
	for i in obstaculos.size():
		var o: Dictionary = obstaculos[i]
		var c: Vector2 = o["centro"]
		var m: Vector2 = o["medio"]
		var a := Vector2i(floori((c.x - m.x) / CELDA), floori((c.y - m.y) / CELDA))
		var b := Vector2i(floori((c.x + m.x) / CELDA), floori((c.y + m.y) / CELDA))
		if (b.x - a.x + 1) * (b.y - a.y + 1) > 400:
			_rejilla.get_or_add(Vector2i(1 << 20, 0), []).append(i)   # obstáculos enormes: siempre se revisan
			continue
		for x in range(a.x, b.x + 1):
			for z in range(a.y, b.y + 1):
				_rejilla.get_or_add(Vector2i(x, z), []).append(i)
	_indexados = obstaculos.size()


## Obstáculos cuyas celdas tocan el círculo (p, r). Se reindexa solo si cambió la lista.
func _cerca(p: Vector2, r: float) -> Array:
	if _indexados != obstaculos.size():
		_indexar()
	var a := Vector2i(floori((p.x - r) / CELDA), floori((p.y - r) / CELDA))
	var b := Vector2i(floori((p.x + r) / CELDA), floori((p.y + r) / CELDA))
	var vistos := {}
	var res: Array = []
	var celdas: Array = [Vector2i(1 << 20, 0)]
	for x in range(a.x, b.x + 1):
		for z in range(a.y, b.y + 1):
			celdas.append(Vector2i(x, z))
	for cl in celdas:
		var lista = _rejilla.get(cl)
		if lista == null:
			continue
		for i in lista:
			if not vistos.has(i):
				vistos[i] = true
				res.append(obstaculos[i])
	return res


## ¿El punto está dentro del volumen de una plataforma? (los proyectiles chocan con ella)
func dentro_plataforma(q: Vector3) -> bool:
	for pl in plataformas:
		var d: Vector2 = (Vector2(q.x, q.z) - pl["centro"]).abs()
		if d.x <= pl["medio"].x and d.y <= pl["medio"].y and q.y <= float(pl["altura"]) and q.y >= float(pl["altura"]) - float(pl["grosor"]):
			return true
	return false


## Piezas del suelo de la plaza (después de las cajas del campo, para no cambiar su colocación).
func _props(tz: Dictionary) -> void:
	var huellas: Dictionary = tz.get("huellas", {})
	for p in tz.get("props", []):
		var tipo_p := str(p["tipo"])
		var cp := _v2(p["pos"])
		var gp := float(p.get("giro", 0.0))
		var ep := float(p.get("escala", 1.0))
		var hp: Array = huellas.get(tipo_p, [])
		if not hp.is_empty():
			if _se_solapa(cp, Vector2(float(hp[0]), float(hp[1])) * 0.5 * ep, 0.1, true):
				continue
			var medio_p := Vector2(float(hp[0]), float(hp[1])) * 0.5 * ep
			if absf(fmod(gp, 90.0)) > 1.0:
				medio_p = Vector2.ONE * maxf(medio_p.x, medio_p.y) * 0.8
			elif int(round(gp / 90.0)) % 2 == 1:
				medio_p = Vector2(medio_p.y, medio_p.x)
			obstaculos.append({"centro": cp, "medio": medio_p, "alto": float(hp[2]) * ep, "tipo": "prop"})
		props.append({"tipo": tipo_p, "centro": cp, "giro": gp, "escala": ep, "tinte": p.get("tinte", [])})


func _se_solapa(c: Vector2, medio: Vector2, margen: float, salvo_props := false) -> bool:
	for o in _cerca(c, medio.length() + margen + 12.0):
		if salvo_props and o["tipo"] == "prop":
			continue
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
	for o in _cerca(p, r):
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
	for o in _cerca(p, r + 0.5):
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
	return dentro_de_la_aldea(q, r)


## Mantiene el punto en la isla (círculo bajo la muralla) o en una zona extra (puerta, puente, orilla).
func dentro_de_la_aldea(q: Vector2, r := 0.0) -> Vector2:
	if radio_caminable <= 0.0:
		return q
	var lim := radio_caminable - r
	if q.distance_to(centro_aldea) <= lim:
		return q
	var mejor := centro_aldea + (q - centro_aldea).limit_length(lim)
	var dmejor := mejor.distance_to(q)
	for z in zonas_extra:
		var rz: Rect2 = z
		if rz.has_point(q):
			return q
		var pz := Vector2(clampf(q.x, rz.position.x, rz.end.x), clampf(q.y, rz.position.y, rz.end.y))
		if pz.distance_to(q) < dmejor:
			mejor = pz
			dmejor = pz.distance_to(q)
	return mejor
