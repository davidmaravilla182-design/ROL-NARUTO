class_name CargaRayo
extends Node3D
## Rayo cargado en la mano: núcleo brillante, chispas, arcos eléctricos que
## cambian constantemente y una luz parpadeante. En nivel 3 ilumina todo el escenario.

var efectos: Efectos
var nivel := 1
var datos: Dictionary = {}
var embistiendo := false
var _luz: OmniLight3D
var _nucleo: MeshInstance3D
var _arcos: Array = []
var _t_arcos := 0.0
var _estela: GPUParticles3D
var _mat_arco: Material
var _t := 0.0


func construir() -> void:
	_mat_arco = Materiales.emisivo(Efectos.COLOR_RAYO_NUCLEO, 6.0)
	_nucleo = Materiales.esfera(0.06 + nivel * 0.05, Materiales.emisivo(Efectos.COLOR_RAYO_NUCLEO, 5.0 + nivel * 2.0), 8)
	add_child(_nucleo)
	var halo := Materiales.esfera(0.15 + nivel * 0.12, Materiales.transparente(Color(0.4, 0.7, 1.0, 0.35), true), 10)
	add_child(halo)
	var chispas := efectos.particulas({
		"cantidad": int(datos.get("particulas", 50)), "vida": 0.18, "radio": 0.05 + nivel * 0.05, "vel_min": 3.0, "vel_max": 6.0 + nivel * 4.0,
		"tam_min": 0.03, "tam_max": 0.06 + nivel * 0.02, "color": Efectos.COLOR_RAYO_NUCLEO, "color_fin": Color(0.3, 0.6, 1.0, 0.0),
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
		"tam_min": 0.15 * nivel, "tam_max": 0.3 * nivel, "color": Color(0.5, 0.8, 1.0, 0.8),
	})
	add_child(_estela)
	_estela.emitting = false


func _process(delta: float) -> void:
	_t += delta
	var base := float(datos.get("luz", 3.0))
	_luz.light_energy = base * randf_range(0.55, 1.15)
	_nucleo.scale = Vector3.ONE * randf_range(0.8, 1.25)
	_estela.emitting = embistiendo
	if nivel >= 3 and efectos.escenario != null:
		efectos.escenario.destello(Efectos.COLOR_RAYO, 2.5 + randf() * 2.0, 0.12)
	if embistiendo and efectos.camara != null and nivel >= 2:
		efectos.camara.sacudir(delta * 0.6 * nivel)
	_t_arcos -= delta
	if _t_arcos <= 0.0:
		_t_arcos = 0.05
		for a in _arcos:
			if is_instance_valid(a):
				a.queue_free()
		_arcos.clear()
		var n := 2 + nivel * 2
		var largo := 0.25 + nivel * 0.3
		for i in n:
			var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			var origen := global_position
			var segs := efectos.rayo_zigzag(self, origen, origen + dir * largo * randf_range(0.5, 1.0), 0.012 + nivel * 0.006, _mat_arco, 4, 0.08 * nivel)
			_arcos.append_array(segs)
