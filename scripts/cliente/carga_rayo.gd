class_name CargaRayo
extends Node3D
## Rayo cargado en la mano: núcleo brillante, rayos ramificados que se regeneran
## constantemente, chispas, luz parpadeante y el sonido de "mil pájaros".
## En nivel 3 ilumina todo el escenario.

var efectos: Efectos
var nivel := 1
var datos: Dictionary = {}
var embistiendo := false
var _luz: OmniLight3D
var _nucleo: MeshInstance3D
var _rayos: Rayos
var _t_rayos := 0.0
var _estela: GPUParticles3D
var _clave_sonido := ""


func construir() -> void:
	_nucleo = Materiales.esfera(0.05 + nivel * 0.045, Materiales.emisivo(Efectos.COLOR_RAYO_NUCLEO, 3.0 + nivel), 10)
	add_child(_nucleo)
	var halo := Materiales.esfera(0.14 + nivel * 0.11, Materiales.transparente(Color(0.35, 0.6, 1.0, 0.16), true), 12)
	add_child(halo)
	var chispas := efectos.particulas({
		"cantidad": int(datos.get("particulas", 50)), "vida": 0.18, "radio": 0.05 + nivel * 0.05, "vel_min": 3.0, "vel_max": 6.0 + nivel * 4.0,
		"tam_min": 0.025, "tam_max": 0.05 + nivel * 0.015, "color": Efectos.COLOR_RAYO_NUCLEO, "color_fin": Color(0.3, 0.6, 1.0, 0.0),
		"local": true, "estirado": true, "tam_quad": Vector2(0.3, 2.5),
	})
	add_child(chispas)
	chispas.emitting = true
	_luz = OmniLight3D.new()
	_luz.light_color = Efectos.COLOR_RAYO
	_luz.light_energy = float(datos.get("luz", 3.0))
	_luz.omni_range = float(datos.get("luz_rango", 8.0))
	_luz.omni_attenuation = 0.6 if nivel >= 3 else 1.0
	add_child(_luz)
	_estela = efectos.particulas({
		"cantidad": int(datos.get("particulas", 50)), "vida": 0.35, "radio": 0.15 * nivel, "vel_min": 0.0, "vel_max": 1.0,
		"tam_min": 0.12 * nivel, "tam_max": 0.25 * nivel, "color": Color(0.5, 0.8, 1.0, 0.6),
	})
	add_child(_estela)
	_estela.emitting = false
	_rayos = Rayos.new()
	_rayos.intensidad = 1.6 + nivel * 0.35
	add_child(_rayos)
	if efectos.sonidos != null:
		_clave_sonido = "rayo_%d" % get_instance_id()
		efectos.sonidos.bucle(_clave_sonido, "chidori", true, -6.0 + nivel * 3.0)


func _exit_tree() -> void:
	if efectos != null and efectos.sonidos != null and _clave_sonido != "":
		efectos.sonidos.bucle(_clave_sonido, "", false)


func _process(delta: float) -> void:
	var base := float(datos.get("luz", 3.0))
	_luz.light_energy = base * randf_range(0.55, 1.15)
	_nucleo.scale = Vector3.ONE * randf_range(0.8, 1.25)
	_estela.emitting = embistiendo
	if nivel >= 3 and efectos.escenario != null:
		efectos.escenario.destello(Efectos.COLOR_RAYO, 1.6 + randf() * 1.2, 0.12)
	if embistiendo and efectos.camara != null and nivel >= 2:
		efectos.camara.sacudir(delta * 0.6 * nivel)
	_t_rayos -= delta
	if _t_rayos <= 0.0 and efectos.camara != null:
		_t_rayos = 0.045
		_rayos.limpiar()
		var origen := global_position
		var n := 2 + nivel * 2
		var largo := 0.3 + nivel * 0.35
		for i in n:
			var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			_rayos.agregar_rayo(origen, origen + dir * largo * randf_range(0.5, 1.0), 0.012 + nivel * 0.007, 1 + nivel / 2, 0.3, 3)
		# En nivel 3, algunos rayos largos golpean el suelo.
		if nivel >= 3 and randf() < 0.5:
			var suelo := Vector3(origen.x + randf_range(-2.5, 2.5), 0.02, origen.z + randf_range(-2.5, 2.5))
			_rayos.agregar_rayo(origen, suelo, 0.02, 2, 0.25, 5)
		_rayos.dibujar(efectos.camara.global_position)
