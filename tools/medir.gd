extends SceneTree
## Mide llamadas de dibujo, primitivas y objetos visibles de la partida en cada calidad.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 -s res://tools/medir.gd
var calidades := ["alta", "media", "baja"]
var i := 0
var t := 0.0
var juego: Node
var muestras: Array = []

func _initialize() -> void:
	_cargar()

func _cargar() -> void:
	if juego != null:
		juego.queue_free()
	Ajustes.cargar()
	Ajustes.calidad = calidades[i]
	juego = (load("res://escenas/juego.tscn") as PackedScene).instantiate()
	root.add_child(juego)
	t = 0.0
	muestras = []

func _process(d: float) -> bool:
	t += d
	if t > 2.0:
		var vp := root.get_viewport().get_viewport_rid()
		muestras.append([
			RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
			RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
			RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		])
	if t > 3.0:
		var m: Array = muestras[muestras.size() - 1]
		print("MEDIDA %s: llamadas=%d primitivas=%d objetos=%d llamadas_sombra=%d" % [calidades[i], m[0], m[1], m[2], m[3]])
		i += 1
		if i >= calidades.size():
			quit(0)
		else:
			_cargar()
	return false
