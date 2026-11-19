class_name Plano
extends RefCounted
## Plano de la aldea visto desde arriba (para el minimapa y el mapa completo), dibujado una sola vez
## a partir del Mapa: lago, isla, canal, edificios, plataformas, muralla y puente.

const TAM := 512
static var _cache: ImageTexture
static var origen := Vector2.ZERO    # esquina superior izquierda del plano en metros (x, z)
static var metros := 1.0             # lado del plano en metros


static func textura(m: Mapa) -> ImageTexture:
	if _cache != null:
		return _cache
	var c := m.centro_aldea
	var r := maxf(m.radio_caminable, 60.0)
	# Cuadrado que incluye la isla y el puente con el embarcadero.
	metros = (r + 110.0) * 2.0
	origen = Vector2(c.x - metros * 0.5, c.y - metros * 0.5 + 60.0)
	var img := Image.create(TAM, TAM, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.11, 0.16))
	var isla := Color(0.25, 0.26, 0.3)
	var radio_px := (r + 4.0) / metros * TAM
	var cpx := a_pixel(c)
	for y in TAM:
		for x in TAM:
			var d := Vector2(x, y).distance_to(cpx)
			if d < radio_px:
				img.set_pixel(x, y, isla)
			elif d < radio_px + 3.0:
				img.set_pixel(x, y, Color(0.5, 0.5, 0.55))   # muralla
	for z in m.zonas_extra:
		_rect(img, z, Color(0.32, 0.32, 0.36))
	if not m.canal.is_empty():
		var cn := m.canal
		_rect(img, Rect2(float(cn["x_min"]), float(cn["z_norte"]), float(cn["x_max"]) - float(cn["x_min"]), float(cn["z_sur"]) - float(cn["z_norte"])), Color(0.16, 0.3, 0.45))
		for px in m.puentes:
			_rect(img, Rect2(float(px) - 1.5, float(cn["z_norte"]), 3.0, float(cn["z_sur"]) - float(cn["z_norte"])), Color(0.4, 0.38, 0.42))
	for o in m.obstaculos:
		var oc: Vector2 = o["centro"]
		var om: Vector2 = o["medio"]
		var col := Color(0.55, 0.52, 0.58)
		match str(o["tipo"]):
			"canal":
				continue
			"prop", "caja":
				col = Color(0.42, 0.42, 0.46)
			"torre_ia":
				col = Color(0.75, 0.55, 0.6)
			"casa_chica", "edificio", "edificio_ia", "plaza_a", "plaza_b", "plaza_c":
				col = Color(0.6, 0.5, 0.48)
			"torre_vivienda_a", "torre_vivienda_b":
				col = Color(0.62, 0.55, 0.72)
			"taller_industrial", "chimenea", "silo", "tanque", "tanque_agua":
				col = Color(0.55, 0.42, 0.38)
		_rect(img, Rect2(oc - om, om * 2.0), col)
	for pl in m.plataformas:
		var pc: Vector2 = pl["centro"]
		var pm: Vector2 = pl["medio"]
		_rect(img, Rect2(pc - pm, pm * 2.0), Color(0.72, 0.6, 0.35, 0.9))
	_cache = ImageTexture.create_from_image(img)
	return _cache


static func a_pixel(p: Vector2) -> Vector2:
	return (p - origen) / metros * TAM


## Posición normalizada (0..1) en el plano.
static func a_uv(p: Vector2) -> Vector2:
	return (p - origen) / metros


static func _rect(img: Image, r: Rect2, col: Color) -> void:
	var a := a_pixel(r.position)
	var b := a_pixel(r.end)
	var ri := Rect2i(Vector2i(floori(a.x), floori(a.y)), Vector2i(maxi(1, ceili(b.x - a.x)), maxi(1, ceili(b.y - a.y))))
	ri = ri.intersection(Rect2i(0, 0, TAM, TAM))
	if ri.size.x > 0 and ri.size.y > 0:
		img.fill_rect(ri, col)
