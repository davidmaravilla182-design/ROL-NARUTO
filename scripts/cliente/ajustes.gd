class_name Ajustes
extends RefCounted
## Preferencias del jugador (solo cliente). Se guardan en user://ajustes.cfg.

const RUTA := "user://ajustes.cfg"

static var tamano_botones := 1.0
static var opacidad_botones := 0.9
static var sensibilidad := 1.0
static var calidad := ""
static var vibracion := true
static var mostrar_fps := false
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


static func guardar() -> void:
	var cf := ConfigFile.new()
	cf.set_value("interfaz", "tamano_botones", tamano_botones)
	cf.set_value("interfaz", "opacidad_botones", opacidad_botones)
	cf.set_value("control", "sensibilidad", sensibilidad)
	cf.set_value("control", "vibracion", vibracion)
	cf.set_value("graficos", "calidad", calidad)
	cf.set_value("graficos", "mostrar_fps", mostrar_fps)
	cf.save(RUTA)


## Valor del preajuste de calidad activo.
static func g(clave: String, por_defecto: Variant = null) -> Variant:
	cargar()
	return Datos.graficos.get("calidades", {}).get(calidad, {}).get(clave, por_defecto)


static func vibrar(ms := 25) -> void:
	if vibracion and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
