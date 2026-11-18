class_name Ajustes
extends RefCounted
## Preferencias del jugador (solo cliente). Se guardan en user://ajustes.cfg.

const RUTA := "user://ajustes.cfg"

static var tamano_botones := 1.0
static var opacidad_botones := 0.9
static var sensibilidad := 1.0
static var calidad := ""
static var vibracion := true
static var mostrar_fps := false          # panel de diagnóstico
static var limite_fps := 0               # 0 = según la calidad (alta 60, media/baja 30); 30 o 60 = elegido
static var simular_red := false          # latencia y pérdida artificiales (data/red.json → simulador)
static var _cargado := false


static func cargar() -> void:
	if _cargado:
		return
	_cargado = true
	Datos.cargar()
	calidad = str(Datos.graficos.get("por_defecto", "alta"))
	var cf := ConfigFile.new()
	if cf.load(RUTA) != OK:
		return
	tamano_botones = clampf(float(cf.get_value("interfaz", "tamano_botones", tamano_botones)), 0.7, 1.35)
	opacidad_botones = clampf(float(cf.get_value("interfaz", "opacidad_botones", opacidad_botones)), 0.3, 1.0)
	sensibilidad = clampf(float(cf.get_value("control", "sensibilidad", sensibilidad)), 0.4, 2.5)
	var c := str(cf.get_value("graficos", "calidad", calidad))
	if Datos.graficos.get("calidades", {}).has(c):
		calidad = c
	vibracion = bool(cf.get_value("control", "vibracion", vibracion))
	mostrar_fps = bool(cf.get_value("graficos", "mostrar_fps", mostrar_fps))
	limite_fps = int(cf.get_value("graficos", "limite_fps", limite_fps))
	if not (limite_fps in [0, 30, 60]):
		limite_fps = 0
	simular_red = bool(cf.get_value("red", "simular", simular_red))


static func guardar() -> void:
	var cf := ConfigFile.new()
	cf.set_value("interfaz", "tamano_botones", tamano_botones)
	cf.set_value("interfaz", "opacidad_botones", opacidad_botones)
	cf.set_value("control", "sensibilidad", sensibilidad)
	cf.set_value("control", "vibracion", vibracion)
	cf.set_value("graficos", "calidad", calidad)
	cf.set_value("graficos", "mostrar_fps", mostrar_fps)
	cf.set_value("graficos", "limite_fps", limite_fps)
	cf.set_value("red", "simular", simular_red)
	cf.save(RUTA)


## Valor del preajuste de calidad activo.
static func g(clave: String, por_defecto: Variant = null) -> Variant:
	cargar()
	return Datos.graficos.get("calidades", {}).get(calidad, {}).get(clave, por_defecto)


static func vibrar(ms := 25) -> void:
	if vibracion and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## FPS máximos efectivos: el elegido por el jugador o el de la calidad (media/baja = 30 a propósito).
static func fps_limite() -> int:
	cargar()
	return limite_fps if limite_fps > 0 else int(g("fps_objetivo", 60))


static func aplicar_fps() -> void:
	Engine.max_fps = fps_limite()
