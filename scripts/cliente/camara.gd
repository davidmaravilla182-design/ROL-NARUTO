class_name CamaraTercera
extends Camera3D
## Cámara en tercera persona que orbita alrededor del objetivo.
## El arrastre en la mitad derecha de la pantalla cambia yaw/pitch.

var objetivo: Node3D
var libre := false   # true: la cámara no sigue a nadie (vistas de depuración/capturas)
var yaw := 0.0         # cámara en +Z mirando hacia -Z (detrás del jugador)
var pitch := -0.32
var distancia := 6.2
var altura := 1.6
var sensibilidad := 0.0055
var _trauma := 0.0
var _foco := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	fov = 68.0
	near = 0.1
	far = 220.0
	current = true


func girar(delta_pantalla: Vector2) -> void:
	yaw -= delta_pantalla.x * sensibilidad
	pitch = clampf(pitch - delta_pantalla.y * sensibilidad, -1.15, 0.35)


## Sacudida de cámara (0..1+). Se acumula y decae.
func sacudir(fuerza: float, maximo := 1.4) -> void:
	_trauma = clampf(_trauma + fuerza, 0.0, maxf(maximo, _trauma))


## Dirección "adelante" de la cámara en el plano XZ.
func adelante_plano() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw)) * -1.0


func _process(delta: float) -> void:
	if objetivo == null or libre:
		return
	_t += delta
	var meta := objetivo.global_position + Vector3(0, altura, 0)
	_foco = _foco.lerp(meta, minf(1.0, delta * 10.0)) if _foco != Vector3.ZERO else meta
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	var pos := _foco + dir * distancia
	pos.y = maxf(pos.y, 0.4)
	global_position = pos
	look_at(_foco, Vector3.UP)
	if _trauma > 0.0:
		var s := _trauma * _trauma
		rotation.x += sin(_t * 47.0) * 0.035 * s
		rotation.y += sin(_t * 39.0 + 1.3) * 0.035 * s
		rotation.z += sin(_t * 53.0 + 2.1) * 0.03 * s
		global_position += Vector3(sin(_t * 31.0), sin(_t * 43.0), 0) * 0.08 * s
		_trauma = maxf(_trauma - delta * 1.6, 0.0)
