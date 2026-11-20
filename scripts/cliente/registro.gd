class_name Registro
extends RefCounted
## Registro de la última partida (user://registro.txt) para diagnosticar cierres inesperados en el celular:
## cada paso importante y un latido cada 5 s (FPS, memoria, posición). Si la app se cierra de golpe, el archivo
## no termina en FIN/PAUSA/MENU y, al abrir de nuevo, el menú muestra las últimas líneas para mandarlas en captura.

const RUTA := "user://registro.txt"
const RUTA_ANTERIOR := "user://registro_anterior.txt"
const CIERRES_LIMPIOS := ["FIN", "PAUSA", "MENU"]
static var _f: FileAccess
static var _iniciado := false
static var cierre_anterior: PackedStringArray = []   # últimas líneas si la partida anterior se cerró de golpe


## Al arrancar la app (una vez): revisa cómo terminó la sesión anterior y empieza un archivo nuevo.
static func iniciar() -> void:
	if _iniciado:
		return
	_iniciado = true
	cierre_anterior = PackedStringArray()
	if FileAccess.file_exists(RUTA):
		var txt := FileAccess.get_file_as_string(RUTA)
		var lineas := txt.strip_edges().split("\n")
		if lineas.size() > 1:
			var ultima := lineas[lineas.size() - 1]
			var limpia := false
			for c in CIERRES_LIMPIOS:
				if ultima.contains("] " + c):
					limpia = true
			if not limpia:
				cierre_anterior = lineas.slice(maxi(lineas.size() - 14, 0))
		var g := FileAccess.open(RUTA_ANTERIOR, FileAccess.WRITE)
		if g != null:
			g.store_string(txt)
	_f = FileAccess.open(RUTA, FileAccess.WRITE)
	nota("INICIO versión %s · %s · %s" % [str(Datos.mundo.get("juego", {}).get("version", "?")), OS.get_name(), OS.get_model_name()])


static func nota(texto: String) -> void:
	if _f == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	_f.store_line("[%7.1f] %s" % [t, texto])
	_f.flush()   # en disco ya: si la app muere, la línea queda


static func latido(extra := "") -> void:
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var vmem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	nota("latido fps %d · memoria %.0f MB · video %.0f MB · nodos %d %s" % [Engine.get_frames_per_second(), mem, vmem,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), extra])
