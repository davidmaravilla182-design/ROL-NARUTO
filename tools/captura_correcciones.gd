extends SceneTree
## Capturas antes/después de las correcciones v0.6.1: pared, agua, torre, casa destrozada, tinacos, escalera,
## barra del enemigo e interacción. Uso:
## xvfb-run -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 --rendering-method mobile -s res://tools/captura_correcciones.gd -- <carpeta>

var salida := "user://capturas"
var juego: Node = null
var menu: Node = null
var t := 0.0
var paso := 0
var guion: Array = []
var mov := Vector2.ZERO          # entrada que se envía cada cuadro (dirección XZ del mundo)
var casa: Dictionary = {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	DirAccess.make_dir_recursive_absolute(salida)
	Perfil.cargar()
	Perfil.elegir(-1)
	menu = (load("res://escenas/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	var m := Mapa.generar()
	# Una casa chica junto a una calle (pared de 9 m) para correr por la pared.
	for o in m.obstaculos:
		var oc: Vector2 = o["centro"]
		var om: Vector2 = o["medio"]
		if o["tipo"] in ["torre_vivienda_a", "torre_vivienda_b", "edificio_mediano"] \
				and not m.punto_bloqueado(oc + Vector2(om.x + 1.6, 0), 0.6) and not m.punto_bloqueado(oc + Vector2(om.x + 6.0, 0), 1.0) \
				and not m.punto_bloqueado(oc + Vector2(0, om.y + 6.0), 1.0):
			casa = o
			break
	var c: Vector2 = casa["centro"]
	var md: Vector2 = casa["medio"]
	var junto := Vector3(c.x + md.x + 1.6, 0, c.y)
	var cz := (float(m.canal["z_sur"]) + float(m.canal["z_norte"])) * 0.5
	guion = [
		[0.6, func(): menu.queue_free(); juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate(); root.add_child(juego)],
		[0.7, func(): _enemigo(false)],
		# 1. Pared
		[1.4, func(): _ir(junto); mov = Vector2(-1, 0)],
		[2.3, func(): _libre(junto + Vector3(7.0, 4.0, 6.0), junto + Vector3(-1, 5.0, 0))],
		[2.6, func(): _guardar("p1_pared")],
		[2.65, func(): _seguir()],
		[3.0, func(): _guardar("p1_pared_seguir"); _depurar()],
		[3.05, func(): mov = Vector2.ZERO],
		# 2. Agua del canal
		[3.40, func(): _ir(Vector3(-8, 0, -20)); mov = Vector2(0, -1)],
		[4.05, func(): mov = Vector2.ZERO],
		[3.90, func(): _libre(Vector3(-2, 3.0, -18), Vector3(-10, -1, -27))],
		[4.65, func(): _guardar("p2_canal"); var j = juego.servidor.entidad_de_peer(1); print("AGUA ", j.pos, " ", j.agua); _quien_en(Vector3(-8, -1.05, -27))],
		[4.7, func(): _libre(Vector3(-8, 3.5, -24), Vector3(-34, -1, -28))],
		[5.0, func(): _guardar("p2_canal_lejos")],
		[4.75, func(): _seguir(); _ir(Vector3(-8, 0, -20)); mov = Vector2(0, -1)],
		[5.25, func(): mov = Vector2.ZERO; _sin_chakra()],
		[5.40, func(): _sin_chakra()],
		[5.70, func(): _guardar("p2_nadando")],
		# 3. Torre: empujar contra ella
		[5.80, func(): _ir(Vector3(-18.5, 0, -72)); mov = Vector2(1, 0)],
		[7.00, func(): _guardar("p3_torre")],
		[7.05, func(): mov = Vector2.ZERO],
		# 4. Casa destrozada de cerca
		[7.20, func(): _ir(Vector3(c.x, 0, c.y + md.y + 6)); _libre(Vector3(c.x + 3, 4, c.y + md.y + 7), Vector3(c.x, 4.5, c.y))],
		[7.70, func(): _guardar("p4_casa")],
		# 6. Tinacos y escalera
		[7.80, func(): _libre(Vector3(87, 5, -66), Vector3(87, 6, -130))],
		[8.30, func(): _guardar("p6_industrial")],
		[8.35, func(): _libre(Vector3(-38, 7, -92), Vector3(-56, 7, -104))],
		[8.80, func(): _guardar("p6_escalera")],
		# 8 y 7. Barra del enemigo lejos e interacción
		[8.90, func(): _seguir(); _ir(Vector3(-60, 0, -4.5))],
		[9.60, func(): _guardar("p8_lejos_del_enemigo")],
		[9.65, func(): _ir_aldeano()],
		[10.20, func(): juego._interactuar(); print("DIALOGO ", juego._cercano.keys(), " ", juego.hud._dialogo_txt.text, " ", juego.hud._dialogo.visible, " ", juego.hud._dialogo.size); _guardar_tarde("p7_interactuar")],
		[12.5, func(): _quit()],
	]


func _ir_aldeano() -> void:
	for p in Puntos.lista:
		if p["tipo"] == "aldeano" and p["distrito"] == "mercado":
			var n: Node3D = p["nodo"]
			_ir(n.global_position + Vector3(1.2, 0, 1.2))
			return


func _guardar_tarde(nombre: String) -> void:
	await create_timer(1.0).timeout
	_guardar(nombre)


func _quien_en(p: Vector3) -> void:
	var pila: Array = [juego.escenario]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		for h in n.get_children():
			pila.append(h)
		if n is GeometryInstance3D and n.is_visible_in_tree():
			var gi: GeometryInstance3D = n
			var caja: AABB = gi.global_transform * gi.get_aabb()
			if caja.grow(0.05).has_point(p):
				var mat = gi.material_override
				if mat == null and gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
					mat = (gi as MeshInstance3D).mesh.surface_get_material(0)
				print("QUIEN ", gi.get_class(), " ", gi.name, " ", caja, " ", mat.shader.resource_path if mat is ShaderMaterial else mat)


func _depurar() -> void:
	var j = juego.servidor.entidad_de_peer(1)
	var v: Dictionary = juego._visuales[juego.mi_id]
	print("DEPURAR esc=", j.escalando, " pos=", j.pos, " pared=", j.pared, " contacto=", j.contacto_pared, " v_pared=", v.get("pared"), " en_pared=", v.get("en_pared"), " basis_y=", (v["nodo"] as Node3D).basis.y, " mov=", juego._mov_prueba, " entrada=", j.entrada_mov)


func _sin_chakra() -> void:
	var j = juego.servidor.entidad_de_peer(1)
	j.chakra = 0.0


func _ir(pos: Vector3) -> void:
	var j = juego.servidor.entidad_de_peer(1)
	j.reiniciar()
	j.pos = pos
	j.yaw = PI
	juego.camara.libre = false


func _guardar(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
	print("CAPTURA ", nombre)


func _libre(pos: Vector3, mirar: Vector3) -> void:
	juego.camara.libre = true
	juego.camara.global_position = pos
	juego.camara.look_at(mirar, Vector3.UP)


func _seguir() -> void:
	juego.camara.libre = false


func _enemigo(activo: bool) -> void:
	for e in juego.servidor.entidades:
		if e.tipo == "enemigo":
			e.ia = IaEnemigo.new(e) if activo else null


func _quit() -> void:
	quit(0)


func _process(d: float) -> bool:
	t += d
	if juego != null and juego.camara != null:
		# Entrada de prueba del cliente (en pantalla): se convierte la dirección del mundo según la cámara.
		var ad: Vector3 = juego.camara.adelante_plano()
		var der := Vector3(-ad.z, 0, ad.x)
		var m3 := Vector3(mov.x, 0, mov.y)
		juego._mov_prueba = Vector2(m3.dot(der), -m3.dot(ad)) if mov != Vector2.ZERO else Vector2.ZERO
	while paso < guion.size() and t >= float(guion[paso][0]):
		(guion[paso][1] as Callable).call()
		paso += 1
	return false
