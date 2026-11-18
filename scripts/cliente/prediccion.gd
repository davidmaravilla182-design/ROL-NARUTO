class_name Prediccion
extends RefCounted
## Predicción del movimiento propio en red: el cliente mueve a su personaje al instante con la misma
## regla que el servidor y, al llegar cada instantánea, parte de la posición del servidor y vuelve a
## aplicar las entradas que el servidor todavía no procesó (reconciliación). Solo predice cuando el
## personaje está libre (sin jutsu, golpe ni empuje); en lo demás manda el servidor.

var pos := Vector3.ZERO
var activa := false
var seq := 0
var entradas: Array = []      # [{seq, mov, dt}]
var mapa: Mapa
var _vel := 6.0
var _libre := false


func registrar(mov: Vector2, dt: float) -> int:
	seq += 1
	entradas.append({"seq": seq, "mov": mov, "dt": dt})
	if entradas.size() > 120:
		entradas.pop_front()
	if activa and _libre:
		pos = _paso(pos, mov, dt)
	return seq


func _paso(p: Vector3, mov: Vector2, dt: float) -> Vector3:
	var n := p + Vector3(mov.x, 0, mov.y) * _vel * dt
	if mapa != null:
		var r := mapa.resolver_colision(Vector2(n.x, n.z), Datos.sim("radio_entidad"), p.y)
		n = Vector3(r.x, p.y, r.y)
	return n


## Instantánea del servidor para mi personaje.
func reconciliar(e: Dictionary) -> void:
	var sp: Vector3 = e["pos"]
	var ultima := int(e.get("ultima_entrada", 0))
	while not entradas.is_empty() and int(entradas[0]["seq"]) <= ultima:
		entradas.pop_front()
	_vel = float(e.get("vel_mov", _vel))
	_libre = str(e.get("estado", "")) == "libre" and not bool(e.get("empuje", false)) and bool(e.get("en_suelo", true))
	if not _libre:
		activa = false
		pos = sp
		return
	var p := sp
	for en in entradas:
		p = _paso(p, en["mov"], float(en["dt"]))
	pos = p
	activa = true
