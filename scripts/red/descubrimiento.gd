class_name Descubrimiento
extends Node
## Descubrimiento de partidas en el mismo Wi-Fi por difusión UDP (data/red.json → puerto_descubrimiento).
##   anfitrión: anunciar(info) → manda {firma, nombre, jugadores, max, puerto} cada segundo a 255.255.255.255
##   cliente:   escuchar()      → señal partidas_cambiaron con {ip: {nombre, jugadores, max, puerto, visto}}

signal partidas_cambiaron(partidas: Dictionary)

var partidas: Dictionary = {}
var info: Dictionary = {}
var destino := "255.255.255.255"   # en la prueba automática: 127.0.0.1
var puerto := -1                   # -1 = el de data/red.json
var _udp: PacketPeerUDP
var _anunciando := false
var _t := 0.0
var _conf: Dictionary = {}


func _ready() -> void:
	Datos.cargar()
	_conf = Datos.red


func anunciar(p_info: Dictionary) -> Error:
	_ready()
	info = p_info
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	var err := _udp.set_dest_address(destino, (puerto if puerto > 0 else int(_conf.get("puerto_descubrimiento", 7778))))
	_anunciando = err == OK
	return err


func escuchar() -> Error:
	_ready()
	_udp = PacketPeerUDP.new()
	_anunciando = false
	return _udp.bind((puerto if puerto > 0 else int(_conf.get("puerto_descubrimiento", 7778))))


func detener() -> void:
	if _udp != null:
		_udp.close()
	_udp = null


func _exit_tree() -> void:
	detener()


func _process(delta: float) -> void:
	if _udp == null:
		return
	if _anunciando:
		_t -= delta
		if _t <= 0.0:
			_t = float(_conf.get("intervalo_anuncio", 1.0))
			var d := info.duplicate()
			d["firma"] = str(_conf.get("firma", ""))
			_udp.put_packet(JSON.stringify(d).to_utf8_buffer())
		return
	var cambio := false
	while _udp.get_available_packet_count() > 0:
		var datos := _udp.get_packet().get_string_from_utf8()
		var ip := _udp.get_packet_ip()
		var v: Variant = JSON.parse_string(datos)
		if typeof(v) != TYPE_DICTIONARY or str((v as Dictionary).get("firma", "")) != str(_conf.get("firma", "")):
			continue
		var p: Dictionary = v
		p["visto"] = Time.get_ticks_msec()
		cambio = cambio or not partidas.has(ip)
		partidas[ip] = p
	for ip in partidas.keys():
		if Time.get_ticks_msec() - int(partidas[ip]["visto"]) > 3500:
			partidas.erase(ip)
			cambio = true
	if cambio:
		partidas_cambiaron.emit(partidas)
