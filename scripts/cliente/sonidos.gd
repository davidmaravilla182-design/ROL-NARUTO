class_name Sonidos
extends Node
## Efectos de sonido SINTETIZADOS por código (sin archivos externos, sin audio del anime):
## chirrido eléctrico con "pájaros" para el rayo, fuego, explosión, golpe, trueno,
## chapoteo y lluvia de fondo. Se generan una vez y se cachean.

const FRECUENCIA := 22050

static var _cache: Dictionary = {}
var _reproductores: Array[AudioStreamPlayer] = []
var _bucles: Dictionary = {}


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_reproductores.append(p)
	var lluvia := AudioStreamPlayer.new()
	lluvia.stream = Sonidos.stream("lluvia")
	lluvia.volume_db = -14.0
	add_child(lluvia)
	lluvia.play()
	# Pregenera el resto de sonidos de a uno por fotograma para evitar tirones al usarlos.
	_pregenerar(["chidori", "fuego", "explosion", "golpe", "chapoteo", "agua", "trueno"])


func _pregenerar(lista: Array) -> void:
	if lista.is_empty() or not is_inside_tree():
		return
	Sonidos.stream(str(lista.pop_front()))
	get_tree().process_frame.connect(_pregenerar.bind(lista), CONNECT_ONE_SHOT)


func tocar(nombre: String, volumen_db := 0.0, tono := 1.0) -> void:
	for p in _reproductores:
		if not p.playing:
			p.stream = Sonidos.stream(nombre)
			p.volume_db = volumen_db
			p.pitch_scale = tono * randf_range(0.95, 1.05)
			p.play()
			return


## Sonido en bucle asociado a una clave (ej. el rayo cargado de una entidad).
func bucle(clave: String, nombre: String, activo: bool, volumen_db := 0.0) -> void:
	if activo and not _bucles.has(clave):
		var p := AudioStreamPlayer.new()
		p.stream = Sonidos.stream(nombre)
		p.volume_db = volumen_db
		add_child(p)
		p.play()
		_bucles[clave] = p
	elif not activo and _bucles.has(clave):
		(_bucles[clave] as Node).queue_free()
		_bucles.erase(clave)


static func stream(nombre: String) -> AudioStreamWAV:
	if _cache.has(nombre):
		return _cache[nombre]
	var datos := PackedFloat32Array()
	var bucle_on := false
	match nombre:
		"chidori":
			datos = _chidori(1.6)
			bucle_on = true
		"fuego":
			datos = _soplido(1.1)
		"explosion":
			datos = _explosion(1.6)
		"golpe":
			datos = _golpe(0.18)
		"trueno":
			datos = _trueno(3.5)
		"chapoteo":
			datos = _chapoteo(0.25)
		"lluvia":
			datos = _lluvia(3.0)
			bucle_on = true
		"agua":
			datos = _chapoteo(0.35)
		"papel":
			datos = _papel(0.35)
		"campana":
			datos = _campana(1.6)
		"monedas":
			datos = _monedas(0.7)
		"tambor":
			datos = _tambor(0.5)
		"musica_jefe":
			datos = _musica_jefe(8.0)
			bucle_on = true
		_:
			datos = _golpe(0.1)
	var s := _a_wav(datos, bucle_on)
	_cache[nombre] = s
	return s


static func _a_wav(muestras: PackedFloat32Array, bucle_on: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(muestras.size() * 2)
	for i in muestras.size():
		bytes.encode_s16(i * 2, int(clampf(muestras[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = FRECUENCIA
	w.stereo = false
	w.data = bytes
	if bucle_on:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = muestras.size()
	return w


## Chisporroteo eléctrico con muchos trinos agudos superpuestos (efecto "mil pájaros").
static func _chidori(seg: float) -> PackedFloat32Array:
	var n := int(seg * FRECUENCIA)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1001
	# Chisporroteo: impulsos aleatorios filtrados.
	var filtro := 0.0
	for i in n:
		var imp := 0.0
		if rng.randf() < 0.08:
			imp = rng.randf_range(-1, 1)
		filtro = filtro * 0.6 + imp * 0.4
		out[i] = filtro * 0.5 + rng.randf_range(-1, 1) * 0.06
	# Trinos: barridos rápidos de frecuencia aguda.
	var t_trino := 0
	while t_trino < n:
		var largo := int(rng.randf_range(0.025, 0.07) * FRECUENCIA)
		var f0 := rng.randf_range(2600, 4200)
		var f1 := f0 + rng.randf_range(600, 1800) * (1 if rng.randf() < 0.7 else -1)
		var fase := 0.0
		var amp := rng.randf_range(0.18, 0.35)
		for k in largo:
			var idx := (t_trino + k) % n
			var u := float(k) / largo
			var f := lerpf(f0, f1, u) + sin(u * 60.0) * 250.0
			fase += TAU * f / FRECUENCIA
			var env := sin(u * PI)
			out[idx] += sin(fase) * amp * env
		t_trino += int(rng.randf_range(0.008, 0.03) * FRECUENCIA)
	# Zumbido eléctrico de fondo (60 Hz + armónicos) y fundido en los bordes del bucle.
	for i in n:
		var t := float(i) / FRECUENCIA
		out[i] += (sin(TAU * 120.0 * t) * 0.06 + sin(TAU * 240.0 * t) * 0.04) * (0.7 + 0.3 * sin(t * 31.0))
		out[i] *= 0.75
	return out


static func _ruido_filtrado(n: int, corte: float, semilla: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var y := 0.0
	for i in n:
		y += (rng.randf_range(-1, 1) - y) * corte
		out[i] = y
	return out


static func _soplido(seg: float) -> PackedFloat32Array:
	var n := int(seg * FRECUENCIA)
	var out := _ruido_filtrado(n, 0.12, 7)
	for i in n:
		var u := float(i) / n
		out[i] *= 2.4 * pow(sin(u * PI), 0.7) * (1.0 - u * 0.4)
	return out


static func _explosion(seg: float) -> PackedFloat32Array:
	var n := int(seg * FRECUENCIA)
	var grave := _ruido_filtrado(n, 0.03, 11)
	var medio := _ruido_filtrado(n, 0.25, 12)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var u := float(i) / n
		var env := exp(-u * 4.5)
		out[i] = (grave[i] * 6.0 + medio[i] * 0.8 * exp(-u * 12.0)) * env
	return out


static func _golpe(seg: float) -> PackedFloat32Array:
	var n := int(seg * FRECUENCIA)
	var ruido := _ruido_filtrado(n, 0.3, 21)
	var out := PackedFloat32Array()
	out.resize(n)
	var fase := 0.0
	for i in n:
		var u := float(i) / n
		fase += TAU * lerpf(160.0, 60.0, u) / FRECUENCIA
		out[i] = (sin(fase) * 0.9 + ruido[i] * 0.8) * exp(-u * 7.0)
	return out


static func _trueno(seg: float) -> PackedFloat32Array:
	var n := int(seg * FRECUENCIA)
	var grave := _ruido_filtrado(n, 0.015, 31)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 32
	var mod := 1.0
	for i in n:
		var u := float(i) / n
		if i % 800 == 0:
			mod = rng.randf_range(0.5, 1.3)
		out[i] = grave[i] * 9.0 * mod * (1.0 - exp(-u * 30.0)) * exp(-u * 2.2)
	return out


static func _chapoteo(seg: float) -> PackedFloat32Array:
	var n := int(seg * FRECUENCIA)
	var ruido := _ruido_filtrado(n, 0.5, 41)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var u := float(i) / n
		out[i] = ruido[i] * 0.7 * exp(-u * 9.0)
	return out


static func _lluvia(seg: float) -> PackedFloat32Array:
	var n := int(seg * FRECUENCIA)
	var a := _ruido_filtrado(n, 0.55, 51)
	var b := _ruido_filtrado(n, 0.08, 52)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	for i in n:
		out[i] = a[i] * 0.25 + b[i] * 0.6
		if rng.randf() < 0.002:
			out[i] += rng.randf_range(-0.5, 0.5)
	# Fundido cruzado para que el bucle no haga clic.
	var f := int(0.1 * FRECUENCIA)
	for i in f:
		var u := float(i) / f
		out[i] = out[i] * u + out[n - f + i] * (1.0 - u)
	return out



## Papel que se despliega: ruido filtrado en ráfagas cortas.
static func _papel(seg: float) -> PackedFloat32Array:
	var n := int(seg * FRECUENCIA)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / FRECUENCIA
		var r := randf_range(-1.0, 1.0)
		prev = prev * 0.55 + r * 0.45
		var env := (0.5 + 0.5 * sin(t * 90.0)) * exp(-t * 6.0)
		out[i] = (r - prev) * env * 0.5
	return out


## Campana de templo (misión cumplida).
static func _campana(seg: float) -> PackedFloat32Array:
	var n := int(seg * FRECUENCIA)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / FRECUENCIA
		var env := exp(-t * 2.2)
		out[i] = (sin(TAU * 523.0 * t) * 0.5 + sin(TAU * 1046.0 * t * 1.003) * 0.25 + sin(TAU * 1567.0 * t) * 0.12) * env * 0.6
	return out


## Monedas (ryō): tintineos metálicos al azar.
static func _monedas(seg: float) -> PackedFloat32Array:
	var n := int(seg * FRECUENCIA)
	var out := PackedFloat32Array()
	out.resize(n)
	var golpes: Array = []
	for k in 7:
		golpes.append([randf() * seg * 0.8, randf_range(2600.0, 4200.0)])
	for i in n:
		var t := float(i) / FRECUENCIA
		var v := 0.0
		for g in golpes:
			var dt: float = t - float(g[0])
			if dt >= 0.0:
				v += sin(TAU * float(g[1]) * dt) * exp(-dt * 30.0)
		out[i] = v * 0.25
	return out


## Taiko grave (golpe de tambor).
static func _tambor(seg: float) -> PackedFloat32Array:
	var n := int(seg * FRECUENCIA)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / FRECUENCIA
		var f := 70.0 + 50.0 * exp(-t * 18.0)
		out[i] = sin(TAU * f * t) * exp(-t * 7.0) * 0.9 + randf_range(-1, 1) * exp(-t * 40.0) * 0.2
	return out


## Música de jefe en bucle (8 s): taikos a 120 ppm, bajo pedal grave y un motivo menor en flauta sintetizada.
static func _musica_jefe(seg: float) -> PackedFloat32Array:
	var n := int(seg * FRECUENCIA)
	var out := PackedFloat32Array()
	out.resize(n)
	var pulso := 0.5
	var notas := [220.0, 261.63, 246.94, 196.0, 220.0, 293.66, 261.63, 246.94]
	for i in n:
		var t := float(i) / FRECUENCIA
		var tp := fmod(t, pulso)
		var golpe := sin(TAU * (60.0 + 40.0 * exp(-tp * 20.0)) * tp) * exp(-tp * 9.0)
		if int(t / pulso) % 4 == 3:
			golpe *= 1.5
		var bajo := sin(TAU * 55.0 * t) * 0.18 + sin(TAU * 82.5 * t) * 0.08
		var nota: float = notas[int(t / 1.0) % notas.size()]
		var tn := fmod(t, 1.0)
		var flauta := (sin(TAU * nota * 2.0 * t) + 0.3 * sin(TAU * nota * 4.0 * t)) * minf(tn * 8.0, 1.0) * exp(-tn * 1.2) * 0.16
		out[i] = clampf(golpe * 0.55 + bajo + flauta, -1.0, 1.0)
	return out
