extends SceneTree
## Herramienta de calidad: reproduce un efecto de jutsu aislado (sin HUD ni partida) con cámara fija y guarda una
## secuencia de cuadros en instantes exactos. Úsese con --fixed-fps 30 para que los tiempos sean deterministas.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 --fixed-fps 30 --rendering-method mobile \
##        -s res://tools/vista_efecto.gd -- <carpeta> <caso> [<caso> ...]
## Casos: kirin1..3, dragon_agua, dragon_madera, golem1..3, susanoo1..3

var salida := "/tmp"
var casos: Array = []
var escenario: Escenario
var camara: CamaraTercera
var efectos: Efectos
var tecnicas: EfectosTecnicas
var genericas: EfectosGenericos
var sonidos: Sonidos
var t := 0.0
var guion: Array = []
var paso := 0
var _limpiar: Array = []


func _initialize() -> void:
	Datos.cargar()
	Ajustes.cargar()
	var args := OS.get_cmdline_user_args()
	salida = args[0]
	casos = args.slice(1)
	DirAccess.make_dir_recursive_absolute(salida)
	escenario = Escenario.new()
	escenario.mapa = Mapa.generar()
	escenario._colores = Datos.escenario.get("colores", {})
	escenario._entorno()
	root.add_child(escenario)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	pm.material = Shaders.toon_tex("suelo", Color(0.8, 0.82, 0.88), Vector2(30, 30), false)
	suelo.mesh = pm
	root.add_child(suelo)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40, 30, 0)
	luz.light_energy = 0.5
	root.add_child(luz)
	sonidos = Sonidos.new()
	root.add_child(sonidos)
	camara = CamaraTercera.new()
	root.add_child(camara)
	camara.libre = true
	efectos = Efectos.new()
	efectos.camara = camara
	efectos.escenario = escenario
	efectos.sonidos = sonidos
	root.add_child(efectos)
	tecnicas = EfectosTecnicas.new()
	tecnicas.efectos = efectos
	tecnicas.sonidos = sonidos
	root.add_child(tecnicas)
	genericas = EfectosGenericos.new()
	genericas.efectos = efectos
	genericas.sonidos = sonidos
	root.add_child(genericas)
	var t0 := 0.3
	for c in casos:
		t0 = _caso(str(c), t0)
	guion.append([t0 + 0.2, func(): quit(0)])


func _cam(pos: Vector3, mirar: Vector3) -> void:
	camara.global_position = pos
	camara.look_at(mirar, Vector3.UP)


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
	print("CUADRO ", nombre, " t=", snappedf(t, 0.01))


func _caso(c: String, t0: float) -> float:
	var punto := Vector3(0, 0, 0)
	if c.begins_with("kirin"):
		var n := int(c.substr(5))
		var nd := Datos.nivel_jutsu("kirin", n)
		var carga := float(nd.get("carga", 1.2))
		guion.append([t0, func():
			_cam(Vector3(22, 5, 30), Vector3(0, 12, 0))
			tecnicas.tormenta(punto, n, carga, func() -> Vector3: return punto)])
		var marcas := [0.3, carga * 0.6, carga - 0.45, carga - 0.3, carga - 0.15, carga + 0.03, carga + 0.25, carga + 0.9]
		for i in marcas.size():
			var k := i
			guion.append([t0 + float(marcas[i]), func(): _foto("%s_%d" % [c, k])])
		guion.append([t0 + carga, func(): tecnicas.kirin(punto, n, float(nd.get("radio", 3.0)), bool(nd.get("bestia", false)))])
		guion.sort_custom(func(a, b): return a[0] < b[0])
		return t0 + carga + 2.5
	if c.begins_with("dragon_"):
		# Dragón como proyectil: aparece (anticipación), avanza ondulando y se desvanece al llegar.
		var jutsu := "dragon_agua" if c == "dragon_agua" else "madera"
		var nivel := 2 if c == "dragon_agua" else 3
		var radio := float(Datos.nivel_jutsu(jutsu, nivel).get("radio", 1.0))
		var datos := {"forma": "dragon", "radio": radio, "nivel": nivel, "jutsu": jutsu, "pos": Vector3(-10, 1.5, 0)}
		var nodo_ref: Array = []
		guion.append([t0, func():
			_cam(Vector3(2, 4.5, 15), Vector3(0, 2.0, 0))
			var nodo := genericas.crear_proyectil(datos)
			nodo_ref.append(nodo)
			var tw := nodo.create_tween()
			tw.tween_property(nodo, "global_position", Vector3(10, 1.5, 0), 1.6)])
		for i in 7:
			var k := i
			guion.append([t0 + 0.12 + i * 0.25, func(): _foto("%s_%d" % [c, k])])
		guion.append([t0 + 1.62, func():
			for ch in (nodo_ref[0] as Node3D).get_children():
				if ch is DragonVivo:
					(ch as DragonVivo).desvanecer(Color(0.5, 0.7, 1.0), efectos)])
		guion.append([t0 + 1.75, func(): _foto("%s_7" % c)])
		guion.append([t0 + 2.0, func(): _foto("%s_8" % c); (nodo_ref[0] as Node3D).queue_free()])
		guion.sort_custom(func(a, b): return a[0] < b[0])
		return t0 + 2.4
	if c.begins_with("susanoo"):
		var n := int(c.substr(7))
		var alto: float = [2.8, 5.2, 9.0][n - 1]
		var pv_ref: Array = []
		var on := {"efectos": {"susanoo": {"nivel": n}}}
		guion.append([t0, func():
			var pv := PersonajeVisual.new()
			root.add_child(pv)
			pv.construir("jugador_uchiha")
			pv.rotation.y = PI * 0.5
			pv_ref.append(pv)
			_cam(Vector3(alto * 0.4, alto * 0.55, alto * 1.35 + 3.0), Vector3(0, alto * 0.45, 0))
			tecnicas.sincronizar(77, pv, on)])
		for f in [0.1, 0.35, 0.65, 1.0]:
			var nom := "%s_forma_%02d" % [c, int(f * 100)]
			guion.append([t0 + f, func(): _foto(nom)])
		var ev_base := func(tipo: String, extra: Dictionary) -> void:
			var ev := {"tipo": tipo, "entidad": 77, "nivel": n}
			ev.merge(extra)
			tecnicas.evento(ev, -1, func(_i): return Vector3.ZERO, func(_i): return null, func(_a, _b): pass)
		if n >= 2:
			guion.append([t0 + 1.3, func(): ev_base.call("susanoo_tensa", {"tiempo": 0.35})])
			guion.append([t0 + 1.45, func(): _foto("%s_arco_tensa" % c)])
			guion.append([t0 + 1.7, func(): _foto("%s_arco_suelta" % c)])
		if n >= 3:
			guion.append([t0 + 2.2, func(): ev_base.call("susanoo_alza", {"tiempo": 0.3})])
			guion.append([t0 + 2.4, func(): _foto("%s_espada_alza" % c)])
			guion.append([t0 + 2.5, func(): ev_base.call("susanoo_espada", {"pos": Vector3.ZERO, "radio": 4.5})])
			guion.append([t0 + 2.56, func(): _foto("%s_espada_tajo" % c)])
		guion.append([t0 + 3.0, func(): tecnicas.sincronizar(77, pv_ref[0], {"efectos": {}})])
		guion.append([t0 + 3.2, func(): _foto("%s_fin" % c)])
		guion.append([t0 + 3.6, func(): (pv_ref[0] as Node).queue_free()])
		guion.sort_custom(func(a, b): return a[0] < b[0])
		return t0 + 3.8
	if c.begins_with("golem"):
		var n := int(c.substr(5))
		var esc: float = [0.8, 1.4, 2.6][n - 1]
		var cr := {"id": 900 + n, "forma": "golem", "escala": esc, "pos": Vector3(-4, 0, 0), "yaw": PI * 0.5}
		guion.append([t0, func():
			_cam(Vector3(1, 1.5 + esc, 3.5 + esc * 2.2), Vector3(-1, esc * 1.2, 0))
			genericas.sincronizar_criaturas([cr])])
		var fotos := [0.2, 0.5, 0.9, 1.4]
		for f in fotos:
			var nom := "%s_surgir_%d" % [c, int(f * 10)]
			guion.append([t0 + f, func(): _foto(nom)])
		# Camina hacia la derecha.
		for k in 12:
			var x := -4.0 + k * 0.3
			guion.append([t0 + 1.6 + k * 0.1, func():
				cr["pos"] = Vector3(x, 0, 0)
				genericas.sincronizar_criaturas([cr])])
		guion.append([t0 + 2.05, func(): _foto("%s_caminar_a" % c)])
		guion.append([t0 + 2.4, func(): _foto("%s_caminar_b" % c)])
		guion.append([t0 + 2.8, func(): genericas.evento({"tipo": "criatura_prepara", "criatura": 900 + n, "anticipo": 0.45, "forma": "golem"}, -1, func(_i): return Vector3.ZERO, func(_i): return null, func(_a, _b): pass)])
		guion.append([t0 + 2.95, func(): _foto("%s_golpe_a" % c)])
		guion.append([t0 + 3.2, func(): _foto("%s_golpe_b" % c)])
		guion.append([t0 + 3.25, func(): genericas.evento({"tipo": "criatura_golpe", "criatura": 900 + n, "jutsu": "golem_tierra", "nivel": n, "pos": Vector3(0, 1, 1.5), "escala": esc, "forma": "golem"}, -1, func(_i): return Vector3.ZERO, func(_i): return null, func(_a, _b): pass)])
		guion.append([t0 + 3.35, func(): _foto("%s_golpe_c" % c)])
		guion.append([t0 + 3.8, func(): genericas.sincronizar_criaturas([])])
		for f in [0.2, 0.7, 1.3, 1.9]:
			var nom2 := "%s_derrumbe_%d" % [c, int(f * 10)]
			guion.append([t0 + 3.8 + f, func(): _foto(nom2)])
		guion.sort_custom(func(a, b): return a[0] < b[0])
		return t0 + 6.0
	return t0


func _process(d: float) -> bool:
	t += d
	while paso < guion.size() and t >= float(guion[paso][0]):
		(guion[paso][1] as Callable).call()
		paso += 1
		if paso < guion.size() and float(guion[paso][0]) > t:
			break
	return false
