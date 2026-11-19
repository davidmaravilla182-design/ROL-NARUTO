class_name Sectores
extends Node3D
## Carga y descarga de sectores (distritos) según la posición de la cámara.
## Cada distrito tiene un nodo raíz con lo caro de dibujar o procesar (luces, partículas, cascadas,
## aldeanos, marcadores): fuera del radio activo se oculta y deja de procesarse (no gasta GPU ni CPU).
## Los edificios ya usan distancias de dibujo por celda (Trazado), así que aquí solo vive lo dinámico.

var mapa: Mapa
var raices: Dictionary = {}     # id de distrito -> Node3D
var activos: Dictionary = {}    # id -> bool
var camara: Camera3D
var distrito_actual := ""
var _t := 0.0
var margen := 70.0              # metros fuera del rectángulo del distrito en los que sigue activo


func configurar(m: Mapa) -> void:
	mapa = m
	margen = {"baja": 35.0, "media": 55.0}.get(Ajustes.calidad, 70.0)
	for d in m.distritos:
		var r := Node3D.new()
		r.name = "distrito_" + str(d["id"])
		add_child(r)
		raices[d["id"]] = r
		activos[d["id"]] = true
	var general := Node3D.new()
	general.name = "general"
	add_child(general)
	raices[""] = general


## Pone un nodo en el sector del distrito al que pertenece el punto (x, z).
func agregar(nodo: Node, p: Vector2) -> void:
	var id := mapa.distrito_en(p) if mapa != null else ""
	var raiz: Node3D = raices.get(id, raices.get("", self))
	raiz.add_child(nodo)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or camara == null or mapa == null:
		return
	_t = 0.25
	var c := Vector2(camara.global_position.x, camara.global_position.z)
	distrito_actual = mapa.distrito_en(c)
	for d in mapa.distritos:
		var r: Rect2 = d["rect"]
		var cerca := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
		var activo := cerca.distance_to(c) <= margen
		if activo != activos[d["id"]]:
			activos[d["id"]] = activo
			var raiz: Node3D = raices[d["id"]]
			raiz.visible = activo
			raiz.process_mode = Node.PROCESS_MODE_INHERIT if activo else Node.PROCESS_MODE_DISABLED


func cuantos_activos() -> int:
	var n := 0
	for k in activos.keys():
		if activos[k]:
			n += 1
	return n
