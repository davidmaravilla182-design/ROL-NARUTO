class_name EfectosGenericos
extends Node3D
## Visuales de los jutsus genéricos (todo por código, sin recursos externos).
## Cada "forma" (data/jutsus.json, por nivel) tiene su aspecto: dragones con cuerpo que serpentea,
## tiburones, agujas, balas de aire, shuriken de viento, aves y arañas de arcilla, olas, terremotos,
## tornados, raíces, bosques, domos de hielo, ataúdes de arena, golems, clones, criaturas, auras…
## El tamaño crece con el nivel; N3 añade cámara lenta, sacudida fuerte, destello y marcas en el suelo.

var efectos: Efectos
var sonidos: Sonidos
var _adjuntos: Dictionary = {}     # "eid:clave" -> Node3D
var _criaturas: Dictionary = {}    # id -> Node3D (Criatura)
var _zonas: Dictionary = {}        # id -> Node3D
var _areas: Dictionary = {}        # "jutsu:entidad" -> Node3D que sigue al área (tornado, bombardeo, chibaku)


static func color_de(ev: Dictionary) -> Color:
	var c := str(ev.get("color", ""))
	if c == "" and ev.has("jutsu"):
		c = str(Datos.jutsu(str(ev["jutsu"])).get("color", "#ffffff"))
	return Color.html(c) if c != "" else Color.WHITE


static func _nd(ev: Dictionary) -> Dictionary:
	return Datos.nivel_jutsu(str(ev.get("jutsu", "")), int(ev.get("nivel", 1)))


func _brillo(c: Color, energia := 1.6) -> StandardMaterial3D:
	return Materiales.emisivo(c, energia)


func _toon(c: Color) -> Material:
	return Shaders.toon(c, true, 0.02)


func _sonar(nombre: String, vol := -6.0, tono := 1.0) -> void:
	if sonidos != null:
		sonidos.tocar(nombre, vol, tono)


func _temporal(n: Node3D, segundos: float, desvanecer := 0.4) -> void:
	var tw := create_tween()
	tw.tween_interval(maxf(segundos - desvanecer, 0.0))
	tw.tween_property(n, "scale", n.scale * 0.01, desvanecer).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


## Clase auxiliar: el nodo mira hacia donde se mueve (proyectiles guiados).
class Movil extends Node3D:
	var _prev := Vector3.INF
	func _process(_d: float) -> void:
		var p := global_position
		if _prev != Vector3.INF and p.distance_to(_prev) > 0.01:
			var v := p - _prev
			if absf(v.normalized().dot(Vector3.UP)) < 0.98:
				look_at(p + v, Vector3.UP)
		_prev = p


## Cuerpo que serpentea detrás de la cabeza (dragones): los segmentos siguen el rastro.
class Cuerpo extends Node3D:
	var segmentos: Array = []
	var rastro: Array = []
	var separacion := 0.5
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		var cabeza := (get_parent() as Node3D).global_position
		var ondula := Vector3(sin(t * 7.0), cos(t * 5.0), 0) * separacion * 0.25
		if rastro.is_empty() or cabeza.distance_to(rastro[0]) > separacion * 0.35:
			rastro.push_front(cabeza + ondula)
			if rastro.size() > segmentos.size() * 3 + 4:
				rastro.pop_back()
		for i in segmentos.size():
			var idx := mini((i + 1) * 3, rastro.size() - 1)
			if idx >= 0:
				(segmentos[i] as Node3D).global_position = rastro[idx]


## Giro continuo (shuriken de viento, aspas, vórtices).
class Giro extends Node3D:
	var velocidad := Vector3(0, 8, 0)
	func _process(d: float) -> void:
		rotation += velocidad * d


## Aleteo de alas (aves de arcilla, alas de papel).
class Aleteo extends Node3D:
	var izq: Node3D
	var der: Node3D
	var t := 0.0
	var amplitud := 0.7
	var rapidez := 14.0
	func _process(d: float) -> void:
		t += d
		var a := sin(t * rapidez) * amplitud
		if izq != null:
			izq.rotation.z = a
		if der != null:
			der.rotation.z = -a


## Criatura invocada: se desliza hacia la posición del servidor y "respira".
class Criatura extends Node3D:
	var destino := Vector3.ZERO
	var yaw_destino := 0.0
	var t := 0.0
	var salta := false
	var cuerpo: Node3D
	var anim: PersonajeVisual
	var golem: GolemVivo
	func _process(d: float) -> void:
		t += d
		var antes := global_position
		global_position = global_position.lerp(destino, minf(1.0, d * 10.0))
		rotation.y = lerp_angle(rotation.y, yaw_destino, minf(1.0, d * 10.0))
		var vel := antes.distance_to(global_position) / maxf(d, 0.001)
		if cuerpo != null:
			cuerpo.position.y = (absf(sin(t * 6.0)) * 0.6 if salta and vel > 0.3 else sin(t * 2.0) * 0.04)
		if anim != null:
			anim.reproducir("correr" if vel > 0.5 else "guardia", 0.15)
		if golem != null and is_instance_valid(golem):
			golem.moverse(vel)


# ============================================================================ proyectiles

func crear_proyectil(datos: Dictionary) -> Node3D:
	var forma := str(datos.get("forma", "bola"))
	var radio := float(datos["radio"])
	var nivel := int(datos["nivel"])
	var c := color_de(datos)
	var nd := Datos.nivel_jutsu(str(datos["jutsu"]), nivel)
	var nodo := Movil.new()
	add_child(nodo)
	nodo.global_position = datos["pos"]
	var fuego := c.r > 0.9 and c.g < 0.6 and c.b < 0.3
	match forma:
		"bola", "lava":
			var b := efectos.esfera_fuego(radio, 1.1 + nivel * 0.1)
			if forma == "lava":
				var m: ShaderMaterial = b.material_override
				m.set_shader_parameter("color_nucleo", Color(1.0, 0.75, 0.2))
				m.set_shader_parameter("color_medio", Color(0.75, 0.15, 0.02))
				m.set_shader_parameter("color_borde", Color(0.12, 0.03, 0.02))
			nodo.add_child(b)
			_estela(nodo, radio, c, 14 + nivel * 6, true)
			_luz(nodo, c, 1.5, radio * 6.0)
		"dragon":
			_dragon(nodo, radio, c, int(nd.get("segmentos", 8)), fuego)
		"tigre":
			_tigre(nodo, radio)
		"aguja", "hielo":
			var largo := radio * (9.0 if forma == "aguja" else 6.0)
			var a := Materiales.cilindro(radio * 0.15, radio * 0.6, largo, _brillo(c, 2.5 if forma == "aguja" else 1.2), 4)
			a.rotation.x = PI / 2
			nodo.add_child(a)
			_estela(nodo, radio * 0.4, c, 8, true)
		"lanza":
			var largo2 := 2.2 + nivel * 0.8
			var l := Materiales.cilindro(radio * 0.12, radio * 0.45, largo2, _brillo(Efectos.COLOR_RAYO_NUCLEO, 3.0), 6)
			l.rotation.x = PI / 2
			l.position.z = largo2 * 0.3
			nodo.add_child(l)
			var halo := Materiales.cilindro(radio * 0.5, radio * 0.9, largo2, Materiales.transparente(Color(c.r, c.g, c.b, 0.3), true), 6)
			halo.rotation.x = PI / 2
			halo.position.z = largo2 * 0.3
			nodo.add_child(halo)
			_estela(nodo, radio, Efectos.COLOR_RAYO, 20, true)
			_luz(nodo, Efectos.COLOR_RAYO, 2.5, 6.0)
			_sonar("chidori", -10.0, 1.4)
		"tiburon":
			var cuerpo := Materiales.esfera(radio, Materiales.transparente(Color(c.r, c.g, c.b, 0.75), false), 12)
			cuerpo.scale = Vector3(0.75, 0.7, 1.9)
			nodo.add_child(cuerpo)
			var aleta := Materiales.caja(Vector3(radio * 0.12, radio * 0.9, radio * 0.7), _brillo(c.lightened(0.3), 0.6))
			aleta.position = Vector3(0, radio * 0.75, radio * 0.2)
			aleta.rotation.x = -0.5
			nodo.add_child(aleta)
			var cola := Materiales.caja(Vector3(radio * 0.12, radio * 1.1, radio * 0.5), _brillo(c.lightened(0.2), 0.6))
			cola.position = Vector3(0, 0, radio * 1.8)
			nodo.add_child(cola)
			for lado in [-1, 1]:
				var ojo := Materiales.esfera(radio * 0.09, _brillo(Color(1, 1, 0.8), 2.0), 6)
				ojo.position = Vector3(lado * radio * 0.4, radio * 0.2, -radio * 1.2)
				nodo.add_child(ojo)
			_espuma(nodo, radio, 18 + nivel * 10)
		"bala":
			var s := Materiales.esfera(radio, Materiales.transparente(Color(0.85, 1.0, 0.95, 0.28), true), 12)
			nodo.add_child(s)
			var anillo := Materiales.disco(radio * 1.4, Materiales.transparente(Color(1, 1, 1, 0.18), true), 20)
			anillo.rotation.x = PI / 2
			nodo.add_child(anillo)
			_estela(nodo, radio * 0.6, Color(0.9, 1.0, 0.95, 0.5), 16, true, true)
		"rasenshuriken":
			var nucleo := Materiales.esfera(radio * 0.55, _brillo(Color(0.45, 0.8, 1.0), 2.5), 14)
			nodo.add_child(nucleo)
			var g := Giro.new()
			g.velocidad = Vector3(0, 22, 0)
			nodo.add_child(g)
			var disco := Materiales.disco(radio * 2.2, Materiales.transparente(Color(0.85, 0.95, 1.0, 0.35), true), 24)
			g.add_child(disco)
			for k in 4:
				var aspa := Materiales.caja(Vector3(radio * 2.6, radio * 0.06, radio * 0.45), Materiales.transparente(Color(1, 1, 1, 0.75), true))
				aspa.rotation.y = TAU * k / 4.0
				aspa.position = Vector3(cos(TAU * k / 4.0), 0, -sin(TAU * k / 4.0)) * radio * 1.2
				g.add_child(aspa)
			_estela(nodo, radio, Color(0.8, 0.95, 1.0, 0.5), 30, true, true)
			_luz(nodo, Color(0.6, 0.85, 1.0), 2.5, 8.0)
		"kunai":
			var k2 := Materiales.cilindro(0.01, 0.05, 0.4, _toon(Color(0.2, 0.2, 0.24)), 4)
			k2.rotation.x = PI / 2
			nodo.add_child(k2)
			var papel := Materiales.caja(Vector3(0.12, 0.01, 0.3), _brillo(Color(1.0, 0.95, 0.8), 0.6))
			papel.position.z = 0.25
			nodo.add_child(papel)
			_estela(nodo, 0.05, Color(1.0, 0.7, 0.3), 10, true)
		"papel":
			var g2 := Giro.new()
			g2.velocidad = Vector3(9, 12, 3)
			nodo.add_child(g2)
			g2.add_child(Materiales.caja(Vector3(radio * 1.6, 0.01, radio * 1.6), _brillo(Color(0.98, 0.96, 0.9), 0.5)))
		"lodo":
			nodo.add_child(Materiales.esfera(radio, _toon(Color(0.35, 0.24, 0.14)), 10))
			_estela(nodo, radio, Color(0.3, 0.2, 0.1, 0.7), 10, false)
		"arana":
			nodo.add_child(Materiales.esfera(radio * 0.6, _toon(Color(0.95, 0.92, 0.85)), 8))
			for k in 8:
				var pata := Materiales.caja(Vector3(radio * 1.4, 0.02, 0.02), _toon(Color(0.9, 0.86, 0.78)))
				pata.rotation.y = -0.6 + (k % 4) * 0.4
				pata.position = Vector3(radio * 0.6 * (1 if k < 4 else -1), -radio * 0.2, (k % 4 - 1.5) * radio * 0.3)
				nodo.add_child(pata)
		"ave":
			var al := Aleteo.new()
			nodo.add_child(al)
			var b2 := Materiales.esfera(radio * 0.5, _toon(Color(0.96, 0.94, 0.88)), 8)
			b2.scale = Vector3(0.8, 0.7, 1.8)
			al.add_child(b2)
			for lado in [-1, 1]:
				var pivote := Node3D.new()
				al.add_child(pivote)
				var ala := Materiales.caja(Vector3(radio * 1.8, 0.03, radio * 0.7), _toon(Color(0.95, 0.93, 0.86)))
				ala.position.x = lado * radio * 0.9
				pivote.add_child(ala)
				if lado < 0:
					al.izq = pivote
				else:
					al.der = pivote
			_estela(nodo, radio * 0.3, Color(1, 1, 0.9, 0.4), 8, false)
		_:
			nodo.add_child(Materiales.esfera(radio, _brillo(c), 10))
	return nodo


func _luz(padre: Node3D, c: Color, energia: float, rango: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energia
	l.omni_range = rango
	padre.add_child(l)


func _estela(padre: Node3D, radio: float, c: Color, cantidad: int, aditivo: bool, estirada := false) -> void:
	var cfg := {"cantidad": cantidad, "vida": 0.45, "radio": radio * 0.6, "vel_min": 0.1, "vel_max": 0.8,
		"tam_min": maxf(radio * 0.5, 0.06), "tam_max": maxf(radio * 1.0, 0.12), "color": Color(c.r, c.g, c.b, 0.5), "aditivo": aditivo}
	if estirada:
		cfg["estirado"] = true
		cfg["tam_quad"] = Vector2(0.15, 1.2)
	var p := efectos.particulas(cfg)
	padre.add_child(p)
	p.emitting = true


func _espuma(padre: Node3D, radio: float, cantidad: int) -> void:
	var p := efectos.particulas({"cantidad": cantidad, "vida": 0.6, "radio": radio, "vel_min": 0.5, "vel_max": 2.0,
		"gravedad": Vector3(0, -6, 0), "tam_min": 0.06, "tam_max": 0.16, "color": Color(0.8, 0.9, 1.0, 0.8)})
	padre.add_child(p)
	p.emitting = true


func _dragon(nodo: Node3D, radio: float, c: Color, n: int, fuego: bool) -> void:
	var madera := c.g > c.r and c.g > c.b
	var tierra := c.r > c.b and c.g > 0.3 and not fuego and c.r < 0.8 and not madera
	var mat: Material
	if fuego:
		mat = null
	elif tierra or madera:
		mat = _toon(c)
	else:
		mat = Materiales.transparente(Color(c.r, c.g, c.b, 0.8), false)
	# Dragones de agua y de madera: modelo de Meshy (agua que fluye / madera con su textura) y el cuerpo detrás.
	var modelo: Node3D = null
	var mat_modelo: Material = null
	if not fuego and not tierra:
		# Con cadena de huesos (ondula como serpiente); si falta, el modelo estático.
		if not madera:
			var ma := Shaders.material("agua_cuerpo")
			ma.set_shader_parameter("color", Color(c.r, c.g, c.b).darkened(0.2))
			mat_modelo = ma
		modelo = DragonVivo.crear("dragon_madera" if madera else "dragon_agua", mat_modelo if not madera else Kit.material_para("jutsu_dragon_madera"))
		if modelo == null:
			modelo = Kit.modelo_jutsu("dragon_madera") if madera else Kit.modelo_jutsu("dragon_agua", mat_modelo)
	if modelo != null:
		var esc_m := radio * (2.0 if not madera else 0.9)
		nodo.add_child(modelo)
		# El nodo avanza hacia su -Z (Movil); los modelos miran a +Z: se giran para ir de frente.
		if madera:
			modelo.rotation.y = PI
			modelo.position = Vector3(0, -radio * 1.2, -radio * 0.6)
		else:
			# El de agua es una serpiente erguida: se tumba hacia delante para avanzar con la cabeza por delante.
			modelo.rotation.x = -PI * 0.5
			modelo.position = Vector3(0, radio * 0.2, esc_m * 2.0)
		if modelo is DragonVivo:
			(modelo as DragonVivo).anticipar(esc_m)
			nodo.set_meta("dragon_color", c)
		else:
			modelo.scale = Vector3.ONE * esc_m
		if madera:
			_raices_surgen(nodo.global_position, radio)
		else:
			_espuma(nodo, radio, 50)
			_sonar("chapoteo", -6.0, 0.6)
		if modelo is DragonVivo:
			return   # el propio modelo ondula: sin bolas de cola
		var cuerpo_m := Cuerpo.new()
		cuerpo_m.separacion = radio * 1.0
		nodo.add_child(cuerpo_m)
		for i in mini(n, 5):
			var r_m := radio * lerpf(0.55, 0.2, float(i) / 4.0)
			var seg_m: MeshInstance3D = Materiales.esfera(r_m, mat if madera else mat_modelo, 8)
			seg_m.top_level = true
			cuerpo_m.add_child(seg_m)
			seg_m.global_position = nodo.global_position
			cuerpo_m.segmentos.append(seg_m)
		return
	var cabeza: MeshInstance3D
	if fuego:
		cabeza = efectos.esfera_fuego(radio, 1.4)
	else:
		cabeza = Materiales.esfera(radio, mat, 12)
	cabeza.scale = Vector3(0.85, 0.8, 1.5)
	nodo.add_child(cabeza)
	# Mandíbula, cuernos y ojos.
	var mand := Materiales.caja(Vector3(radio * 1.1, radio * 0.25, radio * 1.1), mat if mat != null else _brillo(c, 2.0))
	mand.position = Vector3(0, -radio * 0.55, -radio * 0.7)
	mand.rotation.x = 0.3
	nodo.add_child(mand)
	for lado in [-1, 1]:
		var cuerno := Materiales.cilindro(0.0, radio * 0.15, radio * 1.2, _toon(Color(0.9, 0.85, 0.7)) if not fuego else _brillo(Color(1, 0.8, 0.3), 2.0), 5)
		cuerno.position = Vector3(lado * radio * 0.45, radio * 0.75, radio * 0.4)
		cuerno.rotation.x = 1.0
		nodo.add_child(cuerno)
		var ojo := Materiales.esfera(radio * 0.14, _brillo(Color(1.0, 0.95, 0.4), 3.0), 6)
		ojo.position = Vector3(lado * radio * 0.42, radio * 0.3, -radio * 0.85)
		nodo.add_child(ojo)
	var cuerpo := Cuerpo.new()
	cuerpo.separacion = radio * 1.1
	nodo.add_child(cuerpo)
	for i in n:
		var r := radio * lerpf(0.85, 0.3, float(i) / maxf(n - 1, 1))
		var seg: MeshInstance3D = efectos.esfera_fuego(r, 1.1) if fuego else Materiales.esfera(r, mat, 10)
		seg.top_level = true
		cuerpo.add_child(seg)
		seg.global_position = nodo.global_position
		cuerpo.segmentos.append(seg)
	if fuego:
		_luz(nodo, Efectos.COLOR_FUEGO, 3.0, radio * 8.0)
		_estela(nodo, radio, Color(1.0, 0.5, 0.1), 30, true)
		_sonar("fuego", -4.0, 0.7)
	elif tierra:
		_estela(nodo, radio, Color(0.35, 0.25, 0.15, 0.8), 20, false)
	elif madera:
		_estela(nodo, radio, Color(0.4, 0.6, 0.25, 0.8), 16, false)
	else:
		_espuma(nodo, radio, 40)
		_sonar("chapoteo", -6.0, 0.6)


## El dragón de madera surge del suelo: raíces que brotan y se retuercen donde nace.
func _raices_surgen(pos: Vector3, radio: float) -> void:
	var raiz := Node3D.new()
	add_child(raiz)
	raiz.global_position = Vector3(pos.x, 0, pos.z)
	for k in 7:
		var a := TAU * k / 7.0 + randf() * 0.4
		var tronco := Materiales.cilindro(0.06, 0.22 + radio * 0.05, 1.6 + randf() * 1.2 + radio, _toon(Color(0.38, 0.26, 0.15)), 6)
		tronco.position = Vector3(cos(a), 0, sin(a)) * (0.6 + radio * 0.6)
		tronco.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
		tronco.scale = Vector3(1, 0.01, 1)
		raiz.add_child(tronco)
		var tw := tronco.create_tween()
		tw.tween_property(tronco, "scale", Vector3.ONE, 0.35 + randf() * 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	efectos.polvo(pos, 24)
	var fin := raiz.create_tween()
	fin.tween_interval(1.6)
	fin.tween_property(raiz, "scale", Vector3(1, 0.01, 1), 0.5)
	fin.tween_callback(raiz.queue_free)


# ============================================================================ explosión

func explosion(ev: Dictionary) -> void:
	var nivel := int(ev["nivel"])
	var pos: Vector3 = ev["pos"]
	var r := float(ev["radio"])
	var c := color_de(ev)
	var nd := _nd(ev)
	var forma := str(ev.get("forma", ""))
	match forma:
		"bola", "lava", "kunai", "arana", "ave":
			_bola_expansiva(pos, r, c, forma == "lava")
			_sonar("explosion", -8.0 + nivel * 2.0, 1.2)
		"dragon", "tiburon":
			var agua := c.b > c.r
			if agua:
				_salpicadura(pos, r, nivel)
			elif c.r > 0.9 and c.g < 0.6:
				_bola_expansiva(pos, r, c, false)
				_sonar("explosion", -6.0 + nivel * 2.0, 0.9)
			else:
				_rocas(pos, r, c, 10 + nivel * 6)
				efectos.polvo(pos, 16 + nivel * 8)
		"tigre":
			_onda_aire(pos, r, Color(1.0, 0.95, 0.8), true)
			_anillo_suelo(pos, r, Color(1.0, 0.9, 0.7), 0.5)
			efectos.polvo(pos, 50)
			_sonar("explosion", 0.0, 0.8)
		"bala", "rasenshuriken":
			_onda_aire(pos, r, Color(0.85, 1.0, 1.0), forma == "rasenshuriken")
			if forma == "rasenshuriken":
				_sonar("explosion", -4.0, 1.5)
		"aguja", "lanza":
			efectos.impacto_rayo(pos, nivel)
		"hielo":
			_esquirlas(pos, r, Color(0.8, 0.95, 1.0), 16)
		"lodo":
			_rocas(pos, r, Color(0.35, 0.24, 0.14), 8)
		"papel":
			efectos.rafaga(pos, {"cantidad": 10, "vida": 0.6, "radio": 0.2, "vel_min": 1.0, "vel_max": 3.0, "gravedad": Vector3(0, -2, 0),
				"tam_min": 0.08, "tam_max": 0.14, "color": Color(1, 1, 0.95, 0.9), "aditivo": false})
		_:
			efectos.rafaga(pos, {"cantidad": 24, "vida": 0.5, "radio": 0.3, "vel_min": 2.0, "vel_max": 6.0, "tam_min": 0.1, "tam_max": 0.25,
				"color": c})
	_extras_nivel(ev, pos, r, c, nd)


## Sacudida, marca en el suelo y destello del escenario según el nivel.
func _extras_nivel(ev: Dictionary, pos: Vector3, r: float, c: Color, nd: Dictionary) -> void:
	var nivel := int(ev.get("nivel", 1))
	efectos.sacudir_desde(pos, float(nd.get("sacudida", 0.1 * nivel)))
	if float(nd.get("marca", 0.0)) > 0.0:
		efectos.marca_suelo(Vector3(pos.x, 0, pos.z), float(nd["marca"]), Color(0.05, 0.04, 0.04, 0.85), nivel >= 3)
	efectos.luz_temporal(pos + Vector3(0, 1, 0), c, 2.0 + nivel * 1.5, r * 3.0 + 3.0, 0.3 + nivel * 0.15)
	if nivel >= 3 and efectos.escenario != null:
		efectos.escenario.destello(c, 1.5, 0.6)


func _bola_expansiva(pos: Vector3, r: float, c: Color, lava: bool) -> void:
	var bola := efectos.esfera_fuego(r * 0.4, 1.2)
	add_child(bola)
	bola.global_position = pos
	var m: ShaderMaterial = bola.material_override
	if lava:
		m.set_shader_parameter("color_medio", Color(0.7, 0.12, 0.02))
		m.set_shader_parameter("color_borde", Color(0.1, 0.03, 0.02))
	elif not (c.r > 0.9 and c.g < 0.7):
		m.set_shader_parameter("color_nucleo", Color(1.0, 0.95, 0.8))
		m.set_shader_parameter("color_medio", Color(1.0, 0.6, 0.25))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bola, "scale", Vector3.ONE * 2.3, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_method(func(v): m.set_shader_parameter("opacidad", v), 1.0, 0.0, 0.6).set_delay(0.1)
	tw.chain().tween_callback(bola.queue_free)
	efectos.rafaga(pos, {"cantidad": 30, "vida": 1.4, "radio": r * 0.4, "vel_min": 0.4, "vel_max": r * 0.7, "gravedad": Vector3(0, 2, 0),
		"tam_min": r * 0.4, "tam_max": r * 0.9, "color": Color(0.1, 0.09, 0.09, 0.5), "aditivo": false, "explosividad": 0.6})
	efectos.rafaga(pos, {"cantidad": 30, "vida": 1.0, "radio": r * 0.2, "vel_min": 3.0, "vel_max": 8.0, "gravedad": Vector3(0, -9, 0),
		"tam_min": 0.05, "tam_max": 0.1, "color": Color(1, 0.75, 0.3)})


func _salpicadura(pos: Vector3, r: float, nivel: int) -> void:
	efectos.chapoteo(Vector3(pos.x, 0, pos.z), 1.0 + nivel)
	efectos.rafaga(pos, {"cantidad": 40 + nivel * 30, "vida": 1.0, "radio": r * 0.5, "direccion": Vector3.UP, "dispersion": 60.0,
		"vel_min": 3.0, "vel_max": 6.0 + r * 2.0, "gravedad": Vector3(0, -12, 0), "tam_min": 0.15, "tam_max": 0.4,
		"color": Color(0.6, 0.8, 1.0, 0.7), "aditivo": false})
	_sonar("chapoteo", -2.0, 0.6)


func _onda_aire(pos: Vector3, r: float, c: Color, cortes: bool) -> void:
	var s := Materiales.esfera(1.0, Materiales.transparente(Color(c.r, c.g, c.b, 0.16), true), 16)
	add_child(s)
	s.global_position = pos
	s.scale = Vector3.ONE * 0.3
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * r, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector3.ONE * r * 1.1, 0.5 if cortes else 0.1)
	tw.tween_callback(s.queue_free)
	if cortes:
		efectos.rafaga(pos, {"cantidad": 120, "vida": 0.8, "radio": r * 0.6, "vel_min": 4.0, "vel_max": 10.0, "frenado": 6.0,
			"tam_min": 0.05, "tam_max": 0.1, "color": Color(1, 1, 1, 0.9), "estirado": true, "tam_quad": Vector2(0.1, 2.2)})


func _rocas(pos: Vector3, r: float, c: Color, n: int) -> void:
	for i in n:
		var roca := Materiales.caja(Vector3.ONE * randf_range(0.15, 0.35) * maxf(r * 0.4, 0.6), _toon(c.darkened(randf() * 0.3)))
		add_child(roca)
		roca.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3))
		var dest := roca.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * r * randf_range(0.5, 1.2)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(roca, "global_position", dest + Vector3(0, -0.1, 0), 0.6).set_ease(Tween.EASE_OUT)
		tw.tween_property(roca, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 0.6)
		tw.chain().tween_interval(1.0)
		tw.chain().tween_callback(roca.queue_free)


func _esquirlas(pos: Vector3, r: float, c: Color, n: int) -> void:
	efectos.rafaga(pos, {"cantidad": n * 3, "vida": 0.7, "radio": 0.2, "vel_min": 3.0, "vel_max": 7.0, "gravedad": Vector3(0, -12, 0),
		"tam_min": 0.05, "tam_max": 0.15, "color": c})


# ============================================================================ eventos

func evento(ev: Dictionary, mi_id: int, pos_entidad: Callable, visual_de: Callable, lenta: Callable) -> void:
	var tipo := str(ev["tipo"])
	var propio := int(ev.get("entidad", -1)) == mi_id
	var nivel := int(ev.get("nivel", 1))
	var nd := _nd(ev) if ev.has("jutsu") else {}
	if propio and nivel >= 3 and bool(nd.get("lenta", false)) and tipo in ["area_inicio", "invocar", "aura"] \
			or (propio and tipo == "lanzar" and nivel >= 3 and bool(nd.get("lenta", false)) and int(ev.get("indice", 0)) == 0) \
			or (propio and tipo == "teletransporte" and bool(ev.get("ultimo", false)) and nivel >= 3 and bool(nd.get("lenta", false))):
		lenta.call(0.3, 0.55)
	match tipo:
		"lanzar":
			if ev.has("forma"):
				var c := color_de(ev)
				efectos.rafaga(ev["pos"], {"cantidad": 10 + nivel * 6, "vida": 0.3, "radio": 0.2, "vel_min": 1.0, "vel_max": 3.0,
					"tam_min": 0.08, "tam_max": 0.2, "color": c})
				if int(ev.get("indice", 0)) == 0:
					efectos.sacudir_desde(ev["pos"], float(nd.get("sacudida", 0.1)) * 0.3)
		"area_inicio":
			area_inicio(ev, pos_entidad)
		"area_golpe":
			area_golpe(ev)
		"control":
			control(ev, visual_de)
		"aura":
			var p: Vector3 = pos_entidad.call(int(ev["entidad"]))
			efectos.rafaga(p + Vector3(0, 1, 0), {"cantidad": 30 + nivel * 20, "vida": 0.6, "radio": 0.5, "vel_min": 1.5, "vel_max": 4.0,
				"tam_min": 0.15, "tam_max": 0.4, "color": color_de(ev)})
			efectos.sacudir_desde(p, float(nd.get("sacudida", 0.1)))
			if float(nd.get("marca", 0.0)) > 0.0:
				efectos.marca_suelo(p, float(nd["marca"]), Color(0.06, 0.05, 0.04, 0.8), true)
		"invocar":
			for q in ev["puntos"]:
				var pq: Vector3 = q
				efectos.rafaga(pq + Vector3(0, 1, 0), {"cantidad": 30, "vida": 0.9, "radio": 0.6 * float(ev["escala"]), "vel_min": 1.0,
					"vel_max": 3.0, "tam_min": 0.5, "tam_max": 1.0 * float(ev["escala"]), "color": Color(0.92, 0.93, 0.95, 0.6), "aditivo": false})
			var p0: Vector3 = ev["puntos"][0]
			if float(ev.get("onda", 0.0)) > 0.0:
				_anillo_suelo(p0, float(ev["onda"]), Color(0.9, 0.85, 0.7), 0.6)
				efectos.polvo(p0, 30)
			_extras_nivel(ev, p0, float(ev["escala"]) * 2.0, color_de(ev), nd)
			_sonar("golpe", -2.0, 0.5)
		"criatura_prepara":
			var cp: Node3D = _criaturas.get(int(ev["criatura"]))
			if cp != null and is_instance_valid(cp) and cp is Criatura and (cp as Criatura).golem != null:
				(cp as Criatura).golem.preparar_golpe(float(ev.get("anticipo", 0.45)))
		"criatura_golpe":
			var cr: Node3D = _criaturas.get(int(ev["criatura"]))
			if cr != null and is_instance_valid(cr):
				var tw := create_tween()
				tw.tween_property(cr, "scale", cr.scale * Vector3(1.1, 0.9, 1.1), 0.08)
				tw.tween_property(cr, "scale", cr.scale, 0.15)
			efectos.golpe_fisico(ev["pos"], float(ev["escala"]) >= 1.4)
			if float(ev["escala"]) >= 2.0:
				efectos.polvo(Vector3(Vector3(ev["pos"]).x, 0, Vector3(ev["pos"]).z), 14)
				efectos.sacudir_desde(ev["pos"], 0.3)
		"criatura_fin":
			efectos.rafaga(Vector3(ev["pos"]) + Vector3(0, 1, 0), {"cantidad": 24, "vida": 0.8, "radio": 0.5 * float(ev["escala"]),
				"vel_min": 1.0, "vel_max": 2.5, "tam_min": 0.5, "tam_max": 0.9 * float(ev["escala"]), "color": Color(0.92, 0.93, 0.95, 0.6),
				"aditivo": false})
		"teletransporte":
			teletransporte(ev)
		"repelido":
			var c2 := Color(0.85, 0.95, 1.0)
			match str(ev.get("forma", "")):
				"arena":
					c2 = Color(0.85, 0.7, 0.4)
				"muro", "cupula", "fortaleza":
					c2 = Color(0.6, 0.45, 0.3)
				"kamui":
					c2 = Color(0.6, 0.4, 1.0)
			efectos.rafaga(ev["pos"], {"cantidad": 30, "vida": 0.5, "radio": 0.3, "vel_min": 2.0, "vel_max": 6.0, "tam_min": 0.1,
				"tam_max": 0.25, "color": c2, "aditivo": str(ev.get("forma", "")) != "arena"})
			_sonar("golpe", -8.0, 1.6)
		"tragado":
			_salpicadura(ev["pos"], 1.0, 1)
		"sustitucion":
			# Un tronco queda donde estabas, con una nube de humo.
			var desde: Vector3 = ev["desde"]
			var tronco := Materiales.cilindro(0.28, 0.32, 1.6, _toon(Color(0.45, 0.32, 0.2)), 8)
			add_child(tronco)
			tronco.global_position = desde + Vector3(0, 0.8, 0)
			tronco.rotation.z = 0.25
			for pp in [desde, Vector3(ev["hasta"])]:
				efectos.rafaga(Vector3(pp) + Vector3(0, 1, 0), {"cantidad": 30, "vida": 0.8, "radio": 0.6, "vel_min": 1.0, "vel_max": 2.5,
					"tam_min": 0.5, "tam_max": 0.9, "color": Color(0.92, 0.93, 0.95, 0.6), "aditivo": false})
			if float(ev.get("explota", 0.0)) > 0.0:
				var tw12 := create_tween()
				tw12.tween_interval(0.25)
				tw12.tween_callback(func():
					_bola_expansiva(desde + Vector3(0, 0.8, 0), float(ev["explota"]), Color(1.0, 0.5, 0.15), false)
					_extras_nivel(ev, desde, float(ev["explota"]), Color(1.0, 0.5, 0.15), _nd(ev))
					tronco.queue_free())
			else:
				_temporal(tronco, 1.5)
			_sonar("golpe", -4.0, 1.4)


func _anillo_suelo(pos: Vector3, radio: float, c: Color, dur: float) -> void:
	var d := Materiales.disco(1.0, Materiales.transparente(Color(c.r, c.g, c.b, 0.45), true), 32)
	add_child(d)
	d.global_position = Vector3(pos.x, 0.06, pos.z)
	d.scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(d, "scale", Vector3.ONE * radio, dur).set_ease(Tween.EASE_OUT)
	tw.tween_callback(d.queue_free)


# ============================================================================ áreas

func area_inicio(ev: Dictionary, _pos_entidad: Callable) -> void:
	var forma := str(ev.get("forma", ""))
	var pos: Vector3 = ev["pos"]
	var r := float(ev["radio"])
	var nivel := int(ev["nivel"])
	var c := color_de(ev)
	var dur := float(ev.get("duracion", 0.0)) + float(ev.get("retardo", 0.0))
	var yaw := float(ev.get("yaw", 0.0))
	var origen: Vector3 = ev.get("origen", pos)
	var clave := "%s:%d" % [str(ev["jutsu"]), int(ev.get("entidad", -1))]
	match forma:
		"ola":
			var ola := Materiales.caja(Vector3(r * 1.6, 1.0, 0.8), Materiales.transparente(Color(0.35, 0.6, 1.0, 0.6), false))
			add_child(ola)
			ola.global_position = Vector3(origen.x, 0, origen.z) + Vector3(sin(yaw), 0, cos(yaw)) * 1.0
			ola.rotation.y = yaw
			ola.scale = Vector3(0.4, 0.2, 1.0)
			var dest := Vector3(origen.x, 0, origen.z) + Vector3(sin(yaw), 0, cos(yaw)) * (float(_nd(ev).get("distancia", 3.0)) + r)
			var alto := 1.6 + nivel * 1.4
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(ola, "global_position", dest + Vector3(0, alto * 0.5, 0), 0.6)
			tw.tween_property(ola, "scale", Vector3(1.0, alto, 1.0), 0.35)
			tw.chain().tween_property(ola, "scale", Vector3(1.1, 0.05, 1.5), 0.4)
			tw.chain().tween_callback(ola.queue_free)
			_espuma_ola(ola, r)
			_sonar("chapoteo", 0.0, 0.5)
		"inundacion":
			var agua := Materiales.cilindro(1.0, 1.0, 1.0, Materiales.transparente(Color(0.3, 0.55, 1.0, 0.45), false), 32)
			add_child(agua)
			agua.global_position = Vector3(pos.x, 0, pos.z)
			agua.scale = Vector3(0.5, 4.0, 0.5)
			var tw2 := create_tween()
			tw2.tween_property(agua, "scale", Vector3(r, 2.5, r), 0.7).set_ease(Tween.EASE_OUT)
			tw2.tween_property(agua, "scale", Vector3(r, 0.1, r), 0.8)
			tw2.tween_callback(agua.queue_free)
			_salpicadura(pos, r * 0.3, 3)
		"terremoto":
			for i in 14 + nivel * 4:
				var a := randf() * TAU
				var d := randf_range(1.5, r)
				var p := Vector3(pos.x, 0, pos.z) + Vector3(cos(a), 0, sin(a)) * d
				var pico := Materiales.cilindro(0.0, randf_range(0.4, 0.9), randf_range(1.0, 2.5), _toon(Color(0.42, 0.32, 0.22)), 5)
				add_child(pico)
				pico.global_position = p + Vector3(0, -2.0, 0)
				pico.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
				var tw3 := create_tween()
				tw3.tween_interval(float(ev.get("retardo", 0.0)) + d * 0.04)
				tw3.tween_property(pico, "global_position", p + Vector3(0, 0.5, 0), 0.15).set_ease(Tween.EASE_OUT)
				tw3.tween_interval(2.0)
				tw3.tween_property(pico, "global_position", p + Vector3(0, -2.0, 0), 0.6)
				tw3.tween_callback(pico.queue_free)
			_sonar("trueno", -4.0, 0.5)
		"rafaga", "cortante":
			var dir := Vector3(sin(yaw), 0, cos(yaw))
			efectos.rafaga(origen + Vector3(0, 1.2, 0) + dir, {"cantidad": 80 + nivel * 40, "vida": 0.5, "radio": 0.6, "direccion": dir,
				"dispersion": 25.0, "vel_min": 12.0, "vel_max": 22.0, "tam_min": 0.06, "tam_max": 0.12, "color": Color(0.9, 1.0, 0.95, 0.7),
				"estirado": true, "tam_quad": Vector2(0.12, 2.5)})
			if forma == "cortante":
				for k in 3:
					var media := Materiales.cilindro(1.2, 1.2, 0.05, Materiales.transparente(Color(1, 1, 1, 0.55), true), 16)
					add_child(media)
					media.global_position = origen + Vector3(0, 0.8 + k * 0.5, 0)
					media.rotation.y = yaw
					media.scale = Vector3(1.0, 1.0, 0.25)
					var tw4 := create_tween()
					tw4.tween_interval(k * 0.06)
					tw4.tween_property(media, "global_position", origen + dir * (r + 2.0) + Vector3(0, 0.8 + k * 0.5, 0), 0.35)
					tw4.tween_callback(media.queue_free)
		"tornado":
			var t := Giro.new()
			t.velocidad = Vector3(0, 9, 0)
			add_child(t)
			t.global_position = Vector3(pos.x, 0, pos.z)
			for k in 7:
				var aro := Materiales.cilindro(r * (0.3 + k * 0.12), r * (0.25 + k * 0.12), 0.6, Materiales.transparente(Color(0.85, 1.0, 0.95, 0.22), true), 16)
				aro.position.y = 0.4 + k * 0.9
				t.add_child(aro)
			var p2 := efectos.particulas({"cantidad": 80, "vida": 1.0, "radio": r * 0.7, "direccion": Vector3.UP, "dispersion": 20.0,
				"vel_min": 3.0, "vel_max": 8.0, "tam_min": 0.1, "tam_max": 0.25, "color": Color(0.8, 0.9, 0.85, 0.6), "aditivo": false, "local": true})
			t.add_child(p2)
			p2.emitting = true
			_areas[clave] = t
			_temporal(t, dur + 0.5)
		"sellos", "papel_explosivo":
			var n := 16 if forma == "sellos" else 40
			for i in n:
				var a2 := TAU * i / n + randf() * 0.3
				var hoja := Materiales.caja(Vector3(0.18, 0.4, 0.01), _brillo(Color(0.98, 0.93, 0.78), 0.5))
				add_child(hoja)
				var dest2 := Vector3(pos.x, 0, pos.z) + Vector3(cos(a2), 0, sin(a2)) * randf_range(0.5, r) + Vector3(0, randf_range(0.3, 2.5), 0)
				hoja.global_position = origen + Vector3(0, 1.2, 0)
				hoja.rotation = Vector3(randf(), randf() * TAU, randf())
				var tw5 := create_tween()
				tw5.tween_property(hoja, "global_position", dest2, 0.4 + randf() * 0.3).set_ease(Tween.EASE_OUT)
				tw5.tween_interval(maxf(dur - 0.6, 0.2))
				tw5.tween_callback(hoja.queue_free)
		"raices", "bosque":
			var n2 := 6 if forma == "raices" else 14 + nivel * 2
			for i in n2:
				var a3 := TAU * i / n2 + randf() * 0.4
				var d2 := r * (0.6 if forma == "raices" else randf_range(0.2, 1.0))
				var base := Vector3(pos.x, 0, pos.z) + Vector3(cos(a3), 0, sin(a3)) * d2
				var arbol := Node3D.new()
				add_child(arbol)
				arbol.global_position = base
				var alto2 := 1.6 if forma == "raices" else randf_range(3.0, 5.5)
				var tronco := Materiales.cilindro(0.12 if forma == "raices" else 0.3, 0.25 if forma == "raices" else 0.45, alto2, _toon(Color(0.36, 0.25, 0.14)), 6)
				tronco.position.y = alto2 * 0.5
				if forma == "raices":
					tronco.rotation.z = 0.5
					arbol.rotation.y = -a3
				arbol.add_child(tronco)
				if forma == "bosque":
					var copa := Materiales.esfera(randf_range(1.0, 1.6), _toon(Color(0.22, 0.42, 0.18)), 8)
					copa.position.y = alto2
					arbol.add_child(copa)
				arbol.scale = Vector3(1, 0.01, 1)
				var tw6 := create_tween()
				tw6.tween_property(arbol, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				tw6.tween_interval(3.0 + nivel)
				tw6.tween_property(arbol, "scale", Vector3(1, 0.01, 1), 0.5)
				tw6.tween_callback(arbol.queue_free)
			efectos.polvo(pos, 20)
		"domo_hielo":
			for i in 12:
				var a4 := TAU * i / 12.0
				var espejo := Materiales.caja(Vector3(1.4, 2.2, 0.08), Materiales.transparente(Color(0.75, 0.92, 1.0, 0.3), true))
				add_child(espejo)
				espejo.global_position = Vector3(pos.x, 1.2, pos.z) + Vector3(cos(a4), 0, sin(a4)) * r
				espejo.look_at(Vector3(pos.x, 1.2, pos.z), Vector3.UP)
				espejo.scale = Vector3(1, 0.01, 1)
				var tw7 := create_tween()
				tw7.tween_property(espejo, "scale", Vector3.ONE, 0.3)
				tw7.tween_interval(dur + 0.5)
				tw7.tween_property(espejo, "scale", Vector3(1, 0.01, 1), 0.3)
				tw7.tween_callback(espejo.queue_free)
		"rio_lava":
			var dir2 := Vector3(sin(yaw), 0, cos(yaw))
			for i in 8:
				var b := efectos.esfera_fuego(0.6 + i * 0.1, 1.3)
				add_child(b)
				b.global_position = origen + dir2 * (1.0 + i * 1.2) + Vector3(0, 0.3, 0)
				b.scale = Vector3(1.6, 0.6, 1.6)
				_temporal(b, 1.4)
			_sonar("fuego", -2.0, 0.6)
		"bombardeo":
			# Dragón de arcilla que vuela en círculos sobre el objetivo.
			var pivote := Giro.new()
			pivote.velocidad = Vector3(0, 1.6, 0)
			add_child(pivote)
			pivote.global_position = Vector3(pos.x, 7.0, pos.z)
			var dr := Movil.new()
			pivote.add_child(dr)
			dr.position = Vector3(r + 2.0, 0, 0)
			_dragon(dr, 0.8, Color(0.94, 0.9, 0.82), 8, false)
			_areas[clave] = pivote
			_temporal(pivote, dur + 0.6)
		"ataud", "funeral":
			var arena := Materiales.cilindro(r * 0.7, r * 1.1, 1.0, _toon(Color(0.82, 0.68, 0.42)), 12)
			add_child(arena)
			arena.global_position = Vector3(pos.x, 0, pos.z)
			arena.scale = Vector3(1, 0.05, 1)
			var alto3 := 2.6 if forma == "ataud" else 6.0
			var tw8 := create_tween()
			tw8.tween_property(arena, "scale", Vector3(1, alto3, 1), float(ev.get("retardo", 0.3)) + 0.1).set_ease(Tween.EASE_OUT)
			tw8.tween_property(arena, "scale", Vector3(0.6, alto3 * 1.1, 0.6), 0.15)
			tw8.tween_property(arena, "scale", Vector3(1.6, 0.05, 1.6), 0.35)
			tw8.tween_callback(arena.queue_free)
			efectos.rafaga(pos + Vector3(0, 0.5, 0), {"cantidad": 60, "vida": 1.2, "radio": r, "direccion": Vector3.UP, "dispersion": 30.0,
				"vel_min": 1.0, "vel_max": 4.0, "tam_min": 0.2, "tam_max": 0.5, "color": Color(0.85, 0.7, 0.45, 0.7), "aditivo": false})
		"remolino":
			# Patada giratoria: anillo de viento y hojas que giran a ras del suelo.
			var giro := Giro.new()
			giro.velocidad = Vector3(0, 14, 0)
			add_child(giro)
			giro.global_position = Vector3(pos.x, 0.5, pos.z)
			var tor := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = r * 0.85
			tm.outer_radius = r
			tm.rings = 28
			tm.ring_segments = 4
			tor.mesh = tm
			tor.material_override = Materiales.transparente(Color(0.85, 1.0, 0.85, 0.45), true)
			giro.add_child(tor)
			var hojas := efectos.particulas({"cantidad": 30, "vida": 0.6, "radio": r * 0.9, "vel_min": 2.0, "vel_max": 4.0, "tam_min": 0.08,
				"tam_max": 0.16, "color": Color(0.45, 0.85, 0.35), "aditivo": false, "local": true})
			giro.add_child(hojas)
			hojas.emitting = true
			_temporal(giro, maxf(dur, 0.5) + 0.3, 0.25)
			efectos.polvo(pos, 20 + nivel * 8)
		"pavo_real":
			# Abanico de golpes en llamas frente al usuario.
			var f := Vector3(sin(yaw), 0, cos(yaw))
			for k in 5:
				var a := yaw + deg_to_rad(lerpf(-50.0, 50.0, k / 4.0))
				var dir := Vector3(sin(a), 0.15, cos(a))
				efectos.rafaga(origen + Vector3(0, 1.2, 0) + f * 0.8, {"cantidad": 18 + nivel * 6, "vida": maxf(dur, 0.6), "radio": 0.2,
					"direccion": dir, "dispersion": 6.0, "vel_min": 6.0, "vel_max": 12.0, "tam_min": 0.25, "tam_max": 0.5, "frenado": 4.0,
					"color": Color(1.0, 0.55, 0.15, 0.9), "color_fin": Color(1.0, 0.2, 0.05, 0.0), "estirado": true, "tam_quad": Vector2(0.18, 1.2), "explosividad": 0.1})
			efectos.luz_temporal(origen + Vector3(0, 1.5, 0) + f * 2.0, Color(1.0, 0.55, 0.2), 5.0, 12.0, maxf(dur, 0.6))
			_sonar("fuego", -4.0, 1.2)
		"atadura", "plumas", "oscuridad", "infierno":
			_genjutsu_inicio(forma, pos, r, nivel)
		"genjutsu":
			var anillo := Giro.new()
			anillo.velocidad = Vector3(0, 0, 6)
			add_child(anillo)
			anillo.global_position = Vector3(pos.x, 2.6, pos.z)
			for k in 3:
				var tomoe := Materiales.esfera(0.16, _brillo(Color(0.05, 0.0, 0.0), 0.2), 6)
				tomoe.position = Vector3(cos(TAU * k / 3.0), sin(TAU * k / 3.0), 0) * 0.5
				anillo.add_child(tomoe)
			var fondo := Materiales.disco(0.75, Materiales.transparente(Color(0.8, 0.0, 0.05, 0.6), true), 20)
			anillo.add_child(fondo)
			_temporal(anillo, 1.2)
			efectos.luz_temporal(pos + Vector3(0, 1.5, 0), Color(1, 0.05, 0.1), 4.0, 6.0, 0.6)
		"chibaku":
			var nucleo := Materiales.esfera(0.5, _brillo(Color(0.1, 0.05, 0.15), 0.5), 14)
			add_child(nucleo)
			nucleo.global_position = Vector3(pos.x, 3.0 + r * 0.3, pos.z)
			var tw9 := create_tween()
			tw9.tween_property(nucleo, "scale", Vector3.ONE * (1.0 + r * 0.35), dur).set_ease(Tween.EASE_IN)
			tw9.tween_interval(1.2)
			tw9.tween_property(nucleo, "scale", Vector3.ONE * 0.01, 0.4)
			tw9.tween_callback(nucleo.queue_free)
			for i in 20 + nivel * 15:
				var roca := Materiales.caja(Vector3.ONE * randf_range(0.2, 0.6), _toon(Color(0.4, 0.36, 0.32)))
				add_child(roca)
				var a5 := randf() * TAU
				roca.global_position = Vector3(pos.x, 0, pos.z) + Vector3(cos(a5), 0, sin(a5)) * randf_range(r, r * 2.0)
				var tw10 := create_tween()
				tw10.tween_interval(randf() * dur)
				tw10.tween_property(roca, "global_position", nucleo.global_position + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (0.4 + r * 0.25), 0.7).set_ease(Tween.EASE_IN)
				tw10.tween_interval(dur + 0.5)
				tw10.tween_callback(roca.queue_free)
			efectos.luz_temporal(nucleo.global_position, Color(0.5, 0.4, 1.0), 3.0, r * 3.0, dur)
		"puno_celestial":
			# Puño gigante de chakra que cae del cielo sobre el punto.
			var puno := Node3D.new()
			add_child(puno)
			puno.global_position = Vector3(pos.x, 14.0, pos.z)
			var mat := Materiales.transparente(Color(1.0, 0.45, 0.6, 0.55), true)
			var palma := Materiales.caja(Vector3(2.4, 2.0, 2.0), mat)
			puno.add_child(palma)
			for k in 4:
				var dedo := Materiales.caja(Vector3(0.55, 0.7, 0.9), mat)
				dedo.position = Vector3(-0.85 + k * 0.57, -1.25, 0.4)
				puno.add_child(dedo)
			var antebrazo := Materiales.cilindro(0.9, 1.1, 4.0, Materiales.transparente(Color(1.0, 0.45, 0.6, 0.3), true), 10)
			antebrazo.position.y = 3.0
			puno.add_child(antebrazo)
			var p6 := efectos.particulas({"cantidad": 60, "vida": 0.5, "radio": 1.4, "vel_min": 0.5, "vel_max": 2.0, "tam_min": 0.2,
				"tam_max": 0.5, "color": Color(1.0, 0.5, 0.65, 0.6), "local": true})
			puno.add_child(p6)
			p6.emitting = true
			var tw11 := create_tween()
			tw11.tween_property(puno, "global_position", Vector3(pos.x, 1.6, pos.z), maxf(float(ev.get("retardo", 0.6)), 0.2)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw11.tween_property(puno, "scale", Vector3(1.3, 0.6, 1.3), 0.08)
			tw11.tween_interval(0.25)
			tw11.tween_property(puno, "scale", Vector3.ONE * 0.01, 0.3)
			tw11.tween_callback(puno.queue_free)
			_anillo_suelo(pos, r, Color(1.0, 0.5, 0.65), maxf(float(ev.get("retardo", 0.6)), 0.2))
		"onda", "grietas", "crater", "palmas", "burbuja":
			pass
		_:
			pass



func _espuma_ola(padre: Node3D, r: float) -> void:
	var p := efectos.particulas({"cantidad": 60, "vida": 0.7, "radio": r * 0.6, "direccion": Vector3.UP, "dispersion": 40.0,
		"vel_min": 2.0, "vel_max": 5.0, "gravedad": Vector3(0, -10, 0), "tam_min": 0.15, "tam_max": 0.35, "color": Color(0.85, 0.93, 1.0, 0.8),
		"aditivo": false})
	padre.add_child(p)
	p.position.y = 0.5
	p.emitting = true


func area_golpe(ev: Dictionary) -> void:
	var forma := str(ev.get("forma", ""))
	var pos: Vector3 = ev["pos"]
	var r := float(ev["radio"])
	var nivel := int(ev["nivel"])
	var c := color_de(ev)
	var nd := _nd(ev)
	var clave := "%s:" % str(ev["jutsu"])
	# Las áreas que siguen al objetivo (tornado, bombardeo) se desplazan con él.
	for k in _areas.keys():
		if str(k).begins_with(clave) and is_instance_valid(_areas[k]):
			var n: Node3D = _areas[k]
			var alto := n.global_position.y
			create_tween().tween_property(n, "global_position", Vector3(pos.x, alto, pos.z), 0.25)
	match forma:
		"burbuja":
			_salpicadura(pos, r * 0.5, nivel)
		"ola", "inundacion":
			efectos.chapoteo(pos, 1.5)
		"puno_celestial":
			# Cráter: rocas que saltan en anillo, polvo y onda.
			_rocas(pos, r, Color(0.45, 0.36, 0.27), 26)
			for i in 10:
				var a := TAU * i / 10.0
				var pico := Materiales.cilindro(0.0, 0.7, 2.2, _toon(Color(0.42, 0.33, 0.24)), 5)
				add_child(pico)
				pico.global_position = Vector3(pos.x, 0.5, pos.z) + Vector3(cos(a), 0, sin(a)) * r * 0.7
				pico.rotation = Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7)
				_temporal(pico, 3.0, 0.6)
			efectos.polvo(pos, 60)
			_onda_aire(pos + Vector3(0, 0.5, 0), r, Color(1.0, 0.75, 0.8), false)
			_sonar("explosion", 0.0, 0.6)
		"terremoto", "grietas", "crater":
			_rocas(pos, r * 0.6, Color(0.42, 0.33, 0.24), 8 + nivel * 4)
			efectos.polvo(pos, 24 + nivel * 10)
			_anillo_suelo(pos, r, Color(0.7, 0.6, 0.45), 0.4)
			_sonar("golpe", -2.0, 0.4)
		"rafaga", "cortante", "tornado":
			efectos.rafaga(pos + Vector3(0, 1, 0), {"cantidad": 20, "vida": 0.4, "radio": r * 0.5, "vel_min": 3.0, "vel_max": 7.0,
				"tam_min": 0.05, "tam_max": 0.1, "color": Color(0.9, 1, 0.95, 0.7), "estirado": true, "tam_quad": Vector2(0.1, 1.5)})
		"sellos", "papel_explosivo", "bombardeo":
			var p := Vector3(pos.x, 0.8, pos.z) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * r * 0.5
			_bola_expansiva(p, minf(r * 0.6, 4.0), Color(1.0, 0.5, 0.15), false)
			_sonar("explosion", -6.0, 1.1)
		"raices", "bosque":
			efectos.polvo(pos, 10)
		"domo_hielo":
			_esquirlas(pos + Vector3(0, 1.2, 0), 1.0, Color(0.85, 0.95, 1.0), 12)
		"ataud", "funeral":
			_rocas(pos, r * 0.5, Color(0.82, 0.68, 0.42), 10)
			_sonar("golpe", 0.0, 0.5)
		"genjutsu", "atadura", "plumas", "oscuridad", "infierno":
			pass
		"remolino":
			efectos.golpe_fisico(pos + Vector3(0, 0.8, 0), true)
			_anillo_suelo(pos, r, Color(0.85, 1.0, 0.85), 0.3)
		"pavo_real":
			var yaw_g := float(ev.get("yaw", 0.0)) + randf_range(-0.8, 0.8)
			var origen_g: Vector3 = ev.get("origen", pos)
			var pg := origen_g + Vector3(sin(yaw_g), 0, cos(yaw_g)) * randf_range(1.5, r + 1.5) + Vector3(0, randf_range(0.6, 1.8), 0)
			var bola := efectos.esfera_fuego(0.35, 1.6)
			add_child(bola)
			bola.global_position = pg
			_temporal(bola, 0.12, 0.08)
			efectos.golpe_fisico(pg, bool(ev.get("ultimo", false)))
			if bool(ev.get("ultimo", false)):
				_bola_expansiva(pos + Vector3(0, 1.0, 0), r * 0.6, Color(1.0, 0.5, 0.15), false)
		"chibaku":
			_rocas(pos, r * 0.3, Color(0.4, 0.36, 0.32), 4)
		"palmas":
			var golpe := Materiales.caja(Vector3(0.35, 0.45, 0.05), Materiales.transparente(Color(0.9, 0.95, 1.0, 0.7), true))
			add_child(golpe)
			golpe.global_position = pos + Vector3(randf_range(-0.6, 0.6), randf_range(0.6, 1.6), randf_range(-0.6, 0.6))
			golpe.rotation.y = float(ev.get("yaw", 0.0))
			_temporal(golpe, 0.15, 0.1)
			efectos.golpe_fisico(golpe.global_position, bool(ev.get("ultimo", false)))
		"onda":
			_onda_aire(pos + Vector3(0, 1, 0), r, Color(0.85, 0.95, 1.0), false)
			_anillo_suelo(pos, r, Color(0.9, 0.95, 1.0), 0.4)
		_:
			efectos.rafaga(pos + Vector3(0, 0.8, 0), {"cantidad": 30, "vida": 0.5, "radio": r * 0.4, "vel_min": 2.0, "vel_max": 5.0,
				"tam_min": 0.1, "tam_max": 0.3, "color": c})
	if bool(ev.get("ultimo", true)):
		_extras_nivel(ev, pos, r, c, nd)
	else:
		efectos.sacudir_desde(pos, float(nd.get("sacudida", 0.1)) * 0.3)


## Genjutsu del repertorio: lo que se ve al lanzarlo sobre el objetivo.
func _genjutsu_inicio(forma: String, pos: Vector3, r: float, nivel: int) -> void:
	match forma:
		"atadura":
			_anillo_suelo(pos, r, Color(0.65, 0.4, 1.0), 0.6)
			efectos.rafaga(pos + Vector3(0, 0.3, 0), {"cantidad": 24, "vida": 0.8, "radio": r * 0.5, "direccion": Vector3.UP, "dispersion": 25.0,
				"vel_min": 1.0, "vel_max": 3.0, "tam_min": 0.1, "tam_max": 0.25, "color": Color(0.7, 0.45, 1.0, 0.8)})
		"plumas":
			efectos.rafaga(pos + Vector3(0, 4.0, 0), {"cantidad": 30 + nivel * 15, "vida": 2.2, "radio": r, "direccion": Vector3.DOWN, "dispersion": 30.0,
				"vel_min": 0.5, "vel_max": 1.2, "gravedad": Vector3(0, -0.6, 0), "tam_min": 0.12, "tam_max": 0.22, "color": Color(1, 1, 1, 0.95),
				"aditivo": false, "explosividad": 0.2})
		"oscuridad":
			var esfera := Materiales.esfera(0.4, Materiales.transparente(Color(0.04, 0.0, 0.08, 0.8), false), 16)
			add_child(esfera)
			esfera.global_position = pos + Vector3(0, 1.4, 0)
			var tw := esfera.create_tween()
			tw.tween_property(esfera, "scale", Vector3.ONE * (r * 1.6), 0.35).set_ease(Tween.EASE_OUT)
			tw.tween_property(esfera, "transparency", 1.0, 0.6)
			tw.tween_callback(esfera.queue_free)
		"infierno":
			efectos.rafaga(pos + Vector3(0, 0.5, 0), {"cantidad": 50, "vida": 0.9, "radio": r * 0.6, "direccion": Vector3.UP, "dispersion": 25.0,
				"vel_min": 2.0, "vel_max": 5.0, "tam_min": 0.25, "tam_max": 0.6, "color": Color(0.9, 0.08, 0.1, 0.85), "color_fin": Color(0.1, 0.0, 0.0, 0.0)})
			efectos.luz_temporal(pos + Vector3(0, 1.5, 0), Color(1.0, 0.1, 0.1), 5.0, 8.0, 0.6)
	_sonar("trueno", -16.0, 1.8)


## Tigre de aire comprimido: cabeza translúcida con orejas, rodeada de viento.
func _tigre(nodo: Node3D, radio: float) -> void:
	var mat := Materiales.transparente(Color(1.0, 0.92, 0.7, 0.45), true)
	var cab := Materiales.esfera(radio, mat, 14)
	cab.scale = Vector3(1.0, 0.85, 1.25)
	nodo.add_child(cab)
	for lado in [-1.0, 1.0]:
		var oreja := Materiales.cilindro(0.0, radio * 0.3, radio * 0.55, mat, 5)
		oreja.position = Vector3(lado * radio * 0.55, radio * 0.75, radio * 0.1)
		nodo.add_child(oreja)
		var ojo := Materiales.esfera(radio * 0.1, _brillo(Color(1.0, 0.85, 0.3), 3.0), 6)
		ojo.position = Vector3(lado * radio * 0.35, radio * 0.2, -radio * 1.0)
		nodo.add_child(ojo)
	var fauces := Materiales.caja(Vector3(radio * 1.1, radio * 0.2, radio * 0.5), mat)
	fauces.position = Vector3(0, -radio * 0.35, -radio * 1.0)
	nodo.add_child(fauces)
	_estela(nodo, radio, Color(1.0, 0.95, 0.8), 40, true, true)
	_luz(nodo, Color(1.0, 0.85, 0.5), 2.5, radio * 6.0)
	_sonar("explosion", -10.0, 2.0)


# ============================================================================ control (atrapado / aturdido)

func control(ev: Dictionary, visual_de: Callable) -> void:
	var nodo: Node3D = visual_de.call(int(ev["entidad"]))
	if nodo == null:
		return
	var dur := float(ev["duracion"])
	var forma := str(ev.get("forma", ""))
	var n := Node3D.new()
	nodo.add_child(n)
	match forma:
		"burbuja":
			var b := Materiales.esfera(1.2, Materiales.transparente(Color(0.35, 0.6, 1.0, 0.45), false), 16)
			b.position.y = 1.0
			n.add_child(b)
			_espuma(n, 1.0, 12)
		"raices", "bosque":
			for i in 5:
				var raiz := Materiales.cilindro(0.06, 0.14, 1.6, _toon(Color(0.36, 0.25, 0.14)), 5)
				raiz.position = Vector3(cos(TAU * i / 5.0) * 0.4, 0.7, sin(TAU * i / 5.0) * 0.4)
				raiz.rotation = Vector3(0.3 * cos(TAU * i / 5.0), 0, -0.3 * sin(TAU * i / 5.0))
				n.add_child(raiz)
		"atadura":
			# Raíces ilusorias: moradas y translúcidas, suben enroscándose.
			for i in 6:
				var rz := Materiales.cilindro(0.04, 0.12, 1.9, Materiales.transparente(Color(0.6, 0.35, 0.9, 0.75), true), 5)
				rz.position = Vector3(cos(TAU * i / 6.0) * 0.38, 0.8, sin(TAU * i / 6.0) * 0.38)
				rz.rotation = Vector3(0.35 * cos(TAU * i / 6.0), 0, -0.35 * sin(TAU * i / 6.0))
				rz.scale = Vector3(1, 0.05, 1)
				n.add_child(rz)
				var trz := rz.create_tween()
				trz.tween_property(rz, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"plumas":
			# Dormido: «Z» que suben.
			var z := Label3D.new()
			z.text = "Z z z"
			z.font_size = 64
			z.outline_size = 10
			z.modulate = Color(0.85, 0.85, 1.0)
			z.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			z.position = Vector3(0.3, 2.2, 0)
			n.add_child(z)
			var tz := z.create_tween().set_loops()
			tz.tween_property(z, "position:y", 2.6, 1.0)
			tz.tween_property(z, "position:y", 2.2, 0.0)
		"oscuridad":
			var nube := Materiales.esfera(0.55, Materiales.transparente(Color(0.03, 0.0, 0.06, 0.85), false), 12)
			nube.position = Vector3(0, 1.65, 0)
			n.add_child(nube)
		"infierno":
			var aura_r := efectos.particulas({"cantidad": 30, "vida": 0.7, "radio": 0.5, "direccion": Vector3.UP, "dispersion": 20.0,
				"vel_min": 1.0, "vel_max": 2.5, "tam_min": 0.2, "tam_max": 0.45, "color": Color(0.85, 0.05, 0.1, 0.7), "local": true})
			aura_r.position.y = 1.0
			n.add_child(aura_r)
			aura_r.emitting = true
		"domo_hielo":
			var h := Materiales.cilindro(0.6, 0.7, 2.0, Materiales.transparente(Color(0.8, 0.95, 1.0, 0.45), true), 6)
			h.position.y = 1.0
			n.add_child(h)
		"ataud", "funeral":
			var a := Materiales.cilindro(0.55, 0.65, 2.0, _toon(Color(0.82, 0.68, 0.42)), 10)
			a.position.y = 1.0
			n.add_child(a)
		"chibaku":
			for i in 8:
				var roca := Materiales.caja(Vector3.ONE * 0.35, _toon(Color(0.4, 0.36, 0.32)))
				roca.position = Vector3(cos(TAU * i / 8.0) * 0.5, 0.4 + (i % 3) * 0.6, sin(TAU * i / 8.0) * 0.5)
				n.add_child(roca)
		_:
			# Aturdido: chispas girando sobre la cabeza (genjutsu en rojo).
			var g := Giro.new()
			g.velocidad = Vector3(0, 5, 0)
			g.position.y = 2.2
			n.add_child(g)
			var col := Color(1.0, 0.1, 0.15) if forma == "genjutsu" else Color(1.0, 0.9, 0.4)
			for k in 3:
				var e := Materiales.esfera(0.08, _brillo(col, 2.5), 6)
				e.position = Vector3(cos(TAU * k / 3.0), 0, sin(TAU * k / 3.0)) * 0.35
				g.add_child(e)
	n.scale = Vector3(1, 0.1, 1)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(maxf(dur - 0.4, 0.1))
	tw.tween_property(n, "scale", Vector3(1, 0.01, 1), 0.2)
	tw.tween_callback(n.queue_free)


# ============================================================================ teletransporte

func teletransporte(ev: Dictionary) -> void:
	var desde: Vector3 = ev["desde"]
	var hasta: Vector3 = ev["hasta"]
	var c := color_de(ev)
	var forma := str(ev.get("forma", ""))
	var nivel := int(ev["nivel"])
	for p in [desde, hasta]:
		var pp: Vector3 = p
		efectos.rafaga(pp + Vector3(0, 1.0, 0), {"cantidad": 20 + nivel * 10, "vida": 0.4, "radio": 0.4, "vel_min": 2.0, "vel_max": 5.0,
			"tam_min": 0.08, "tam_max": 0.2, "color": c})
	if forma == "paso" or forma == "salto":
		efectos.polvo(desde, 10 if forma == "paso" else 24)
		return
	# Estela entre los dos puntos.
	var medio := (desde + hasta) * 0.5 + Vector3(0, 1.0, 0)
	var largo := desde.distance_to(hasta)
	if largo > 0.3:
		var raya := Materiales.caja(Vector3(0.08, 0.08, largo), _brillo(c, 3.0))
		add_child(raya)
		raya.global_position = medio
		raya.look_at(hasta + Vector3(0, 1.0, 0), Vector3.UP)
		var tw := create_tween()
		tw.tween_property(raya, "scale", Vector3(0.01, 0.01, 1.0), 0.3)
		tw.tween_callback(raya.queue_free)
	match forma:
		"hiraishin":
			# Kunai de marca clavado donde aparece.
			var kunai := Materiales.cilindro(0.01, 0.05, 0.5, _toon(Color(0.2, 0.2, 0.24)), 4)
			add_child(kunai)
			kunai.global_position = Vector3(hasta.x + 0.5, 0.25, hasta.z)
			_temporal(kunai, 2.0)
			efectos.luz_temporal(hasta + Vector3(0, 1, 0), Color(1.0, 0.85, 0.3), 3.0, 6.0, 0.3)
		"manto_rayo":
			efectos.rayos_fugaces([[desde + Vector3(0, 1, 0), hasta + Vector3(0, 1, 0)]], 0.06, 0.3, 3)
			_sonar("chidori", -8.0, 1.6)
		"espejos":
			for p2 in [desde, hasta]:
				var esp := Materiales.caja(Vector3(1.2, 2.2, 0.08), Materiales.transparente(Color(0.75, 0.92, 1.0, 0.3), true))
				add_child(esp)
				esp.global_position = Vector3(p2) + Vector3(0, 1.1, 0)
				esp.rotation.y = randf() * TAU
				_temporal(esp, 1.0)
	if bool(ev.get("ultimo", false)):
		var nd := _nd(ev)
		if float(nd.get("radio_golpe", 0.0)) > 0.0:
			_extras_nivel(ev, hasta, float(nd["radio_golpe"]), c, nd)


# ============================================================================ auras (sincronizadas)

func sincronizar(eid: int, nodo: Node3D, e: Dictionary) -> void:
	var efs: Dictionary = e.get("efectos", {})
	var forma := ""
	var nivel := 1
	if efs.has("aura"):
		forma = str(efs["aura"].get("forma", ""))
		nivel = int(efs["aura"].get("nivel", 1))
	var sabio := str(e.get("modo", "")) == "modo_sabio" and bool(e.get("modo_activo", false))
	var deseado := {}
	if forma != "":
		deseado["aura:%s:%d" % [forma, nivel]] = [forma, nivel, str(efs["aura"].get("jutsu", ""))]
	if sabio:
		deseado["aura:sabio:%d" % int(e.get("niveles", {}).get("modo_sabio", 1))] = ["sabio", 1, "modo_sabio"]
	for clave in _adjuntos.keys():
		if str(clave).begins_with("%d:" % eid):
			var corta := str(clave).substr(str(clave).find(":") + 1)
			if not deseado.has(corta) or not is_instance_valid(_adjuntos[clave]):
				if is_instance_valid(_adjuntos[clave]):
					(_adjuntos[clave] as Node).queue_free()
				_adjuntos.erase(clave)
	for corta in deseado.keys():
		var clave2 := "%d:%s" % [eid, corta]
		if _adjuntos.has(clave2):
			continue
		var d: Array = deseado[corta]
		var n := crear_aura(str(d[0]), int(d[1]), str(d[2]))
		nodo.add_child(n)
		_adjuntos[clave2] = n
		n.scale = Vector3.ONE * 0.2
		create_tween().tween_property(n, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func crear_aura(forma: String, nivel: int, jutsu: String) -> Node3D:
	var n := Node3D.new()
	var c := Color.html(str(Datos.jutsu(jutsu).get("color", "#ffffff")))
	match forma:
		"manto_rayo":
			var p := efectos.particulas({"cantidad": 60 + nivel * 30, "vida": 0.25, "radio": 0.6, "vel_min": 1.0, "vel_max": 3.0,
				"tam_min": 0.04, "tam_max": 0.08, "color": Efectos.COLOR_RAYO_NUCLEO, "estirado": true, "tam_quad": Vector2(0.15, 1.0), "local": true})
			p.position.y = 1.0
			n.add_child(p)
			p.emitting = true
			var halo := Materiales.capsula(0.55, 2.0, Materiales.transparente(Color(0.55, 0.85, 1.0, 0.18), true))
			halo.position.y = 1.0
			n.add_child(halo)
			_luz_local(n, Efectos.COLOR_RAYO, 2.0, 5.0)
		"muro", "cupula", "fortaleza":
			var tierra := _toon(Color(0.5, 0.38, 0.26))
			if forma == "muro":
				var m := Materiales.caja(Vector3(3.2, 2.6, 0.5), tierra)
				m.position = Vector3(0, 1.3, 1.6)
				n.add_child(m)
			else:
				var cup := Materiales.esfera(2.6 if forma == "cupula" else 3.0, tierra, 14)
				cup.scale = Vector3(1, 0.8, 1)
				cup.position.y = -0.2
				n.add_child(cup)
				cup.transparency = 0.45
				if forma == "fortaleza":
					for k in 10:
						var pico := Materiales.cilindro(0.0, 0.35, 1.6, tierra, 5)
						var a := TAU * k / 10.0
						pico.position = Vector3(cos(a), 0, sin(a)) * 3.2 + Vector3(0, 0.6, 0)
						pico.rotation = Vector3(sin(a) * 0.8, 0, -cos(a) * 0.8)
						n.add_child(pico)
		"sustitucion":
			var hum := efectos.particulas({"cantidad": 16, "vida": 1.0, "radio": 0.5, "direccion": Vector3.UP, "dispersion": 30.0,
				"vel_min": 0.1, "vel_max": 0.5, "tam_min": 0.2, "tam_max": 0.4, "color": Color(0.9, 0.9, 0.85, 0.25), "aditivo": false, "local": true})
			hum.position.y = 1.0
			n.add_child(hum)
			hum.emitting = true
		"muro_agua":
			var cort := Materiales.caja(Vector3(3.4, 2.8, 0.25), Materiales.transparente(Color(0.35, 0.65, 1.0, 0.45), false))
			cort.position = Vector3(0, 1.4, 1.5)
			n.add_child(cort)
			var cae := efectos.particulas({"cantidad": 80, "vida": 0.6, "radio": 1.5, "direccion": Vector3.DOWN, "dispersion": 10.0,
				"vel_min": 3.0, "vel_max": 5.0, "tam_min": 0.08, "tam_max": 0.18, "color": Color(0.75, 0.88, 1.0, 0.7), "aditivo": false, "local": true})
			cae.position = Vector3(0, 2.8, 1.5)
			n.add_child(cae)
			cae.emitting = true
		"remolino_agua":
			var rem := Giro.new()
			rem.velocidad = Vector3(0, 7, 0)
			n.add_child(rem)
			for k in 4:
				var anillo := Materiales.cilindro(2.2 + k * 0.25, 2.0 + k * 0.25, 0.7, Materiales.transparente(Color(0.35, 0.65, 1.0, 0.25), false), 20)
				anillo.position.y = 0.4 + k * 0.7
				rem.add_child(anillo)
			var gotas := efectos.particulas({"cantidad": 90, "vida": 0.7, "radio": 2.4, "vel_min": 1.0, "vel_max": 3.0, "tam_min": 0.08,
				"tam_max": 0.16, "color": Color(0.75, 0.88, 1.0, 0.8), "aditivo": false, "local": true})
			gotas.position.y = 1.2
			rem.add_child(gotas)
			gotas.emitting = true
		"barrera_viento":
			var bv := Giro.new()
			bv.velocidad = Vector3(0, 11, 0)
			n.add_child(bv)
			var cap := Materiales.esfera(2.8 if nivel <= 1 else 3.4, Materiales.transparente(Color(0.8, 1.0, 0.9, 0.12), true), 16)
			cap.scale = Vector3(1, 0.8, 1)
			bv.add_child(cap)
			var rayas := efectos.particulas({"cantidad": 100, "vida": 0.4, "radio": 2.6, "vel_min": 4.0, "vel_max": 8.0, "tam_min": 0.05,
				"tam_max": 0.1, "color": Color(0.9, 1.0, 0.95, 0.8), "estirado": true, "tam_quad": Vector2(0.08, 1.4), "local": true})
			rayas.position.y = 1.0
			bv.add_child(rayas)
			rayas.emitting = true
		"alas":
			var al := Aleteo.new()
			al.amplitud = 0.3
			al.rapidez = 4.0
			al.position = Vector3(0, 1.4, -0.25)
			n.add_child(al)
			for lado in [-1, 1]:
				var piv := Node3D.new()
				al.add_child(piv)
				var ala := Materiales.caja(Vector3(1.8, 0.03, 0.8), _brillo(Color(0.98, 0.96, 0.9), 0.4))
				ala.position.x = lado * 0.95
				piv.add_child(ala)
				if lado < 0:
					al.izq = piv
				else:
					al.der = piv
		"sello_regeneracion", "cura":
			var p2 := efectos.particulas({"cantidad": 30 + nivel * 10, "vida": 1.0, "radio": 0.5, "direccion": Vector3.UP, "dispersion": 15.0,
				"vel_min": 0.5, "vel_max": 1.5, "tam_min": 0.06, "tam_max": 0.14, "color": Color(0.45, 1.0, 0.6, 0.8), "local": true})
			p2.position.y = 0.6
			n.add_child(p2)
			p2.emitting = true
			_luz_local(n, Color(0.4, 1.0, 0.55), 1.2, 3.0)
			if forma == "sello_regeneracion":
				var rombo := Materiales.caja(Vector3(0.1, 0.1, 0.02), _brillo(Color(0.75, 0.3, 1.0), 3.0))
				rombo.position = Vector3(0, 1.72, 0.17)
				rombo.rotation.z = PI / 4
				n.add_child(rombo)
		"arena":
			var g := Giro.new()
			g.velocidad = Vector3(0, 3, 0)
			n.add_child(g)
			var p3 := efectos.particulas({"cantidad": 80, "vida": 0.8, "radio": 1.6, "vel_min": 0.2, "vel_max": 0.8, "tam_min": 0.08,
				"tam_max": 0.18, "color": Color(0.85, 0.7, 0.45, 0.8), "aditivo": false, "local": true})
			p3.position.y = 1.0
			g.add_child(p3)
			p3.emitting = true
			var concha := Materiales.esfera(1.9, Materiales.transparente(Color(0.85, 0.7, 0.45, 0.15), false), 14)
			concha.position.y = 1.0
			n.add_child(concha)
		"kamui":
			var v := Giro.new()
			v.velocidad = Vector3(0, 0, 10)
			v.position = Vector3(0, 1.0, 0)
			n.add_child(v)
			for k in 3:
				var brazo := Materiales.caja(Vector3(1.6, 0.06, 0.02), Materiales.transparente(Color(0.55, 0.4, 1.0, 0.5), true))
				brazo.rotation.z = TAU * k / 3.0
				v.add_child(brazo)
			var velo := Materiales.capsula(0.6, 2.0, Materiales.transparente(Color(0.4, 0.3, 0.9, 0.25), true))
			velo.position.y = 1.0
			n.add_child(velo)
		"rotacion":
			var r := Giro.new()
			r.velocidad = Vector3(0, 14, 0)
			n.add_child(r)
			var radio := 2.6 if nivel <= 1 else 4.0
			var cupula := Materiales.esfera(radio, Materiales.transparente(Color(0.85, 0.95, 1.0, 0.25), true), 16)
			cupula.scale = Vector3(1, 0.75, 1)
			r.add_child(cupula)
			var p4 := efectos.particulas({"cantidad": 80, "vida": 0.5, "radio": radio * 0.9, "vel_min": 3.0, "vel_max": 6.0,
				"tam_min": 0.05, "tam_max": 0.1, "color": Color(0.9, 0.97, 1.0, 0.8), "estirado": true, "tam_quad": Vector2(0.1, 1.2), "local": true})
			p4.position.y = 0.8
			r.add_child(p4)
			p4.emitting = true
		"sabio":
			var halo2 := Materiales.capsula(0.6, 2.1, Materiales.transparente(Color(1.0, 0.55, 0.15, 0.16), true))
			halo2.position.y = 1.0
			n.add_child(halo2)
			_luz_local(n, Color(1.0, 0.6, 0.2), 1.5, 4.0)
			var p5 := efectos.particulas({"cantidad": 70, "vida": 1.2, "radio": 0.7, "direccion": Vector3.UP, "dispersion": 20.0,
				"vel_min": 0.6, "vel_max": 1.8, "tam_min": 0.12, "tam_max": 0.3, "color": Color(1.0, 0.6, 0.2, 0.7), "local": true})
			p5.position.y = 0.8
			n.add_child(p5)
			p5.emitting = true
			for lado in [-1, 1]:
				var pig := Materiales.caja(Vector3(0.05, 0.03, 0.01), _brillo(Color(1.0, 0.45, 0.1), 2.0))
				pig.position = Vector3(lado * 0.07, 1.66, 0.17)
				n.add_child(pig)
		_:
			var p6 := efectos.particulas({"cantidad": 40, "vida": 0.6, "radio": 0.6, "vel_min": 0.5, "vel_max": 1.5, "tam_min": 0.1,
				"tam_max": 0.2, "color": Color(c.r, c.g, c.b, 0.6), "local": true})
			p6.position.y = 1.0
			n.add_child(p6)
			p6.emitting = true
	return n


func _luz_local(padre: Node3D, c: Color, energia: float, rango: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energia
	l.omni_range = rango
	l.position.y = 1.0
	padre.add_child(l)


# ============================================================================ criaturas

func sincronizar_criaturas(lista: Array) -> void:
	var vistos := {}
	for c in lista:
		var id := int(c["id"])
		vistos[id] = true
		var n: Criatura = _criaturas.get(id)
		if n == null or not is_instance_valid(n):
			n = crear_criatura(c)
			_criaturas[id] = n
		n.destino = c["pos"]
		n.yaw_destino = float(c["yaw"])
	for id in _criaturas.keys():
		if not vistos.has(id):
			var n2: Node3D = _criaturas[id]
			if is_instance_valid(n2) and n2 is Criatura and (n2 as Criatura).golem != null and is_instance_valid((n2 as Criatura).golem):
				# El gólem no se encoge: se derrumba en rocas y se hunde.
				var g: GolemVivo = (n2 as Criatura).golem
				var tr := g.global_transform
				g.get_parent().remove_child(g)
				add_child(g)
				g.global_transform = tr
				g.derrumbar()
				n2.queue_free()
			elif is_instance_valid(n2):
				var tw := create_tween()
				tw.tween_property(n2, "scale", Vector3.ONE * 0.01, 0.2)
				tw.tween_callback(n2.queue_free)
			_criaturas.erase(id)


func crear_criatura(c: Dictionary) -> Criatura:
	var forma := str(c["forma"])
	var esc := float(c["escala"])
	var n := Criatura.new()
	add_child(n)
	n.global_position = c["pos"]
	n.destino = c["pos"]
	n.rotation.y = float(c["yaw"])
	var cuerpo := Node3D.new()
	n.add_child(cuerpo)
	n.cuerpo = cuerpo
	match forma:
		"golem", "golem_lava":
			var lava := forma == "golem_lava"
			var vivo_g: GolemVivo = null if lava else GolemVivo.crear(efectos)
			if vivo_g != null:
				# Gólem con esqueleto: sube del suelo entre polvo y piedras y se golpea el pecho.
				cuerpo.add_child(vivo_g)
				n.golem = vivo_g
				vivo_g.position.y = -2.8
				var tw_v := vivo_g.create_tween()
				tw_v.tween_property(vivo_g, "position:y", 0.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				vivo_g.surgir()
				efectos.polvo(n.global_position, 40)
				efectos.rafaga(n.global_position + Vector3(0, 0.3, 0), {"cantidad": 24, "vida": 0.9, "radio": 0.8, "direccion": Vector3.UP, "dispersion": 40.0,
					"vel_min": 3.0, "vel_max": 7.0, "gravedad": Vector3(0, -14, 0), "tam_min": 0.12, "tam_max": 0.28, "color": Color(0.45, 0.38, 0.3), "aditivo": false})
				efectos.marca_suelo(n.global_position, 1.6 * esc, Color(0.12, 0.1, 0.08, 0.8), true)
				n.scale = Vector3.ONE * esc
				return n
			var modelo_g: MeshInstance3D = null if lava else Kit.modelo_jutsu("golem")
			if modelo_g != null:
				# Golem de roca de Meshy: se levanta del suelo (sube desde abajo) entre polvo y piedras.
				cuerpo.add_child(modelo_g)
				modelo_g.position.y = -2.8
				var tw_g := modelo_g.create_tween()
				tw_g.tween_property(modelo_g, "position:y", 0.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				efectos.polvo(n.global_position, 40)
				efectos.rafaga(n.global_position + Vector3(0, 0.3, 0), {"cantidad": 24, "vida": 0.9, "radio": 0.8, "direccion": Vector3.UP, "dispersion": 40.0,
					"vel_min": 3.0, "vel_max": 7.0, "gravedad": Vector3(0, -14, 0), "tam_min": 0.12, "tam_max": 0.28, "color": Color(0.45, 0.38, 0.3), "aditivo": false})
				for lado in [-1, 1]:
					var ojo_g := Materiales.esfera(0.07, _brillo(Color(1.0, 0.65, 0.2), 3.0), 6)
					ojo_g.position = Vector3(lado * 0.16, 2.25, 0.4)
					modelo_g.add_child(ojo_g)
				n.scale = Vector3.ONE * esc
				return n
			var mat := _toon(Color(0.42, 0.3, 0.2) if not lava else Color(0.18, 0.08, 0.06))
			var torso := Materiales.caja(Vector3(1.2, 1.1, 0.8), mat)
			torso.position.y = 1.5
			cuerpo.add_child(torso)
			var cabeza := Materiales.caja(Vector3(0.6, 0.5, 0.55), mat)
			cabeza.position.y = 2.35
			cuerpo.add_child(cabeza)
			for lado in [-1, 1]:
				var brazo := Materiales.caja(Vector3(0.45, 1.2, 0.45), mat)
				brazo.position = Vector3(lado * 0.85, 1.35, 0.05)
				cuerpo.add_child(brazo)
				var pierna := Materiales.caja(Vector3(0.45, 0.95, 0.5), mat)
				pierna.position = Vector3(lado * 0.35, 0.48, 0)
				cuerpo.add_child(pierna)
				var ojo := Materiales.esfera(0.06, _brillo(Color(1.0, 0.7, 0.2) if lava else Color(0.9, 0.95, 0.6), 3.0), 6)
				ojo.position = Vector3(lado * 0.14, 2.4, 0.28)
				cuerpo.add_child(ojo)
			if lava:
				var grietas := Materiales.caja(Vector3(1.22, 0.08, 0.82), _brillo(Color(1.0, 0.45, 0.08), 3.0))
				grietas.position.y = 1.6
				cuerpo.add_child(grietas)
				var fuego := efectos.particulas({"cantidad": 40, "vida": 0.8, "radio": 0.7, "direccion": Vector3.UP, "dispersion": 20.0,
					"vel_min": 0.5, "vel_max": 2.0, "tam_min": 0.2, "tam_max": 0.45, "color": Color(1.0, 0.45, 0.1, 0.5), "local": true})
				fuego.position.y = 1.8
				cuerpo.add_child(fuego)
				fuego.emitting = true
				_luz_local(cuerpo, Efectos.COLOR_FUEGO, 2.0, 6.0)
		"clon":
			# Los primeros clones son copias del personaje; el resto, siluetas ligeras para el celular.
			if _contar_clones() < 3:
				var pv := PersonajeVisual.new()
				cuerpo.add_child(pv)
				pv.construir("jugador_uchiha")
				n.anim = pv
			else:
				var sil := Materiales.capsula(0.3, 1.7, _toon(Color(0.16, 0.18, 0.24)))
				sil.position.y = 0.85
				cuerpo.add_child(sil)
				var banda := Materiales.caja(Vector3(0.5, 0.08, 0.45), _toon(Color(0.7, 0.72, 0.78)))
				banda.position.y = 1.55
				cuerpo.add_child(banda)
		"criatura":
			n.salta = true
			var piel := _toon(Color(0.86, 0.52, 0.22))
			var b := Materiales.esfera(0.9, piel, 14)
			b.scale = Vector3(1.2, 0.85, 1.1)
			b.position.y = 0.85
			cuerpo.add_child(b)
			var panza := Materiales.esfera(0.75, _toon(Color(0.95, 0.85, 0.6)), 12)
			panza.scale = Vector3(1.1, 0.7, 0.6)
			panza.position = Vector3(0, 0.7, 0.45)
			cuerpo.add_child(panza)
			for lado in [-1, 1]:
				var ojo := Materiales.esfera(0.24, _toon(Color(1, 0.95, 0.6)), 10)
				ojo.position = Vector3(lado * 0.45, 1.55, 0.35)
				cuerpo.add_child(ojo)
				var pupila := Materiales.caja(Vector3(0.25, 0.06, 0.02), _toon(Color(0.05, 0.05, 0.05)))
				pupila.position = Vector3(lado * 0.45, 1.55, 0.59)
				cuerpo.add_child(pupila)
				var pata := Materiales.esfera(0.35, piel, 8)
				pata.scale = Vector3(1.0, 0.5, 1.4)
				pata.position = Vector3(lado * 0.75, 0.2, 0.3)
				cuerpo.add_child(pata)
			# Chaleco y pipa: detalle de carácter.
			var chaleco := Materiales.caja(Vector3(1.9, 0.5, 1.4), _toon(Color(0.25, 0.2, 0.35)))
			chaleco.position.y = 1.15
			cuerpo.add_child(chaleco)
		_:
			cuerpo.add_child(Materiales.esfera(0.6, _toon(Color.WHITE), 8))
	n.scale = Vector3.ONE * esc * 0.2
	create_tween().tween_property(n, "scale", Vector3.ONE * esc, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return n


func _contar_clones() -> int:
	var k := 0
	for id in _criaturas.keys():
		var n: Criatura = _criaturas[id]
		if is_instance_valid(n) and n.anim != null:
			k += 1
	return k


# ============================================================================ zonas

## Zonas genéricas en el suelo (lago, lava, cortes de viento). Devuelve null si la forma no es suya.
func crear_zona(z: Dictionary) -> Node3D:
	var forma := str(z.get("forma", ""))
	var r := float(z["radio"])
	var n := Node3D.new()
	match forma:
		"lago":
			var d := Materiales.disco(r, Materiales.transparente(Color(0.3, 0.5, 0.85, 0.45), false), 32)
			d.position.y = 0.04
			n.add_child(d)
			var ondas := efectos.particulas({"cantidad": int(r * 6), "vida": 1.2, "radio": r * 0.8, "vel_min": 0.0, "vel_max": 0.1,
				"tam_min": 0.3, "tam_max": 0.7, "color": Color(0.8, 0.9, 1.0, 0.3), "local": true})
			ondas.position.y = 0.08
			n.add_child(ondas)
			ondas.emitting = true
		"lava":
			var d2 := Materiales.disco(r, _brillo(Color(1.0, 0.35, 0.05), 1.6), 24)
			d2.position.y = 0.05
			n.add_child(d2)
			var costra := Materiales.disco(r * 1.1, _toon(Color(0.12, 0.05, 0.03)), 24)
			costra.position.y = 0.03
			n.add_child(costra)
			var f := efectos.particulas({"cantidad": int(r * 12), "vida": 0.8, "radio": r * 0.7, "direccion": Vector3.UP, "dispersion": 15.0,
				"vel_min": 0.5, "vel_max": 1.8, "tam_min": 0.2, "tam_max": 0.5, "color": Color(1.0, 0.45, 0.1, 0.4)})
			f.position.y = 0.2
			n.add_child(f)
			f.emitting = true
			_luz_local(n, Efectos.COLOR_FUEGO, 1.5, r * 2.5)
		"corte":
			var g := Giro.new()
			g.velocidad = Vector3(0, 16, 0)
			n.add_child(g)
			var esfera := Materiales.esfera(r, Materiales.transparente(Color(0.85, 0.95, 1.0, 0.07), true), 16)
			esfera.scale = Vector3(1, 0.55, 1)
			g.add_child(esfera)
			var p := efectos.particulas({"cantidad": 80, "vida": 0.4, "radio": r * 0.8, "vel_min": 4.0, "vel_max": 9.0, "tam_min": 0.04,
				"tam_max": 0.08, "color": Color(1, 1, 1, 0.9), "estirado": true, "tam_quad": Vector2(0.08, 1.6), "local": true})
			g.add_child(p)
			p.emitting = true
		_:
			n.free()
			return null
	return n
