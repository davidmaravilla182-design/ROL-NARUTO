class_name Animaciones
extends RefCounted
## Genera por código las animaciones del esqueleto humanoide (sin editor).
## Convenciones: el modelo mira a +Z, su izquierda es +X.
##   Brazo/pierna hacia delante = rotación X negativa. Rodilla doblada = X positiva.
##   Codo doblado = X negativa en el antebrazo. Inclinar torso adelante = X positiva.
## Ángulos en grados (X, Y, Z).

const GUARDIA := {
	"BrazoI": Vector3(-55, 0, 10), "AntebrazoI": Vector3(-95, 0, 0),
	"BrazoD": Vector3(-55, 0, -10), "AntebrazoD": Vector3(-95, 0, 0),
	"PiernaI": Vector3(-12, 0, 4), "RodillaI": Vector3(18, 0, 0),
	"PiernaD": Vector3(8, 0, -4), "RodillaD": Vector3(14, 0, 0),
	"Columna": Vector3(6, 0, 0),
}


static func _mezclar(base: Dictionary, extra: Dictionary) -> Dictionary:
	var r := base.duplicate()
	r.merge(extra, true)
	return r


## Definición de todas las animaciones: nombre -> {duracion, bucle, claves: [[t, pose, desplazamiento_caderas]]}
static func definiciones() -> Dictionary:
	var quieto_a := {"BrazoI": Vector3(0, 0, 9), "BrazoD": Vector3(0, 0, -9), "AntebrazoI": Vector3(-12, 0, 0), "AntebrazoD": Vector3(-12, 0, 0), "PiernaI": Vector3(0, 0, 3), "PiernaD": Vector3(0, 0, -3)}
	var quieto_b := _mezclar(quieto_a, {"Pecho": Vector3(-3, 0, 0), "Cabeza": Vector3(2, 0, 0), "BrazoI": Vector3(0, 0, 11), "BrazoD": Vector3(0, 0, -11)})

	# Carrera ninja: torso inclinado y brazos atrás.
	var correr_base := {"Columna": Vector3(18, 0, 0), "Pecho": Vector3(8, 0, 0), "Cabeza": Vector3(-15, 0, 0),
		"BrazoI": Vector3(55, 0, 14), "BrazoD": Vector3(55, 0, -14), "AntebrazoI": Vector3(-15, 0, 0), "AntebrazoD": Vector3(-15, 0, 0)}
	var paso_a := _mezclar(correr_base, {"PiernaI": Vector3(-50, 0, 0), "RodillaI": Vector3(25, 0, 0), "PiernaD": Vector3(35, 0, 0), "RodillaD": Vector3(70, 0, 0)})
	var medio_a := _mezclar(correr_base, {"PiernaI": Vector3(-5, 0, 0), "RodillaI": Vector3(15, 0, 0), "PiernaD": Vector3(-10, 0, 0), "RodillaD": Vector3(90, 0, 0)})
	var paso_b := _mezclar(correr_base, {"PiernaD": Vector3(-50, 0, 0), "RodillaD": Vector3(25, 0, 0), "PiernaI": Vector3(35, 0, 0), "RodillaI": Vector3(70, 0, 0)})
	var medio_b := _mezclar(correr_base, {"PiernaD": Vector3(-5, 0, 0), "RodillaD": Vector3(15, 0, 0), "PiernaI": Vector3(-10, 0, 0), "RodillaI": Vector3(90, 0, 0)})

	var salto := {"PiernaI": Vector3(-70, 0, 0), "RodillaI": Vector3(100, 0, 0), "PiernaD": Vector3(-35, 0, 0), "RodillaD": Vector3(80, 0, 0),
		"BrazoI": Vector3(-20, 0, 55), "BrazoD": Vector3(-20, 0, -55), "AntebrazoI": Vector3(-30, 0, 0), "AntebrazoD": Vector3(-30, 0, 0), "Columna": Vector3(10, 0, 0)}

	var esquiva := {"Caderas": Vector3(0, 0, -20), "Columna": Vector3(30, 0, 0), "PiernaI": Vector3(-60, 0, 10), "RodillaI": Vector3(110, 0, 0),
		"PiernaD": Vector3(-40, 0, -20), "RodillaD": Vector3(100, 0, 0), "BrazoI": Vector3(-30, 0, 50), "BrazoD": Vector3(-30, 0, -40), "Cabeza": Vector3(-20, 0, 0)}

	var golpe1 := _mezclar(GUARDIA, {"BrazoD": Vector3(-90, 0, 0), "AntebrazoD": Vector3(-5, 0, 0), "Pecho": Vector3(0, 28, 0), "Caderas": Vector3(0, 10, 0)})
	var golpe2 := _mezclar(GUARDIA, {"BrazoI": Vector3(-88, 0, -15), "AntebrazoI": Vector3(-25, 0, 0), "Pecho": Vector3(0, -32, 0), "Caderas": Vector3(0, -12, 0)})
	var patada_carga := _mezclar(GUARDIA, {"PiernaD": Vector3(-40, 0, 0), "RodillaD": Vector3(100, 0, 0), "Columna": Vector3(-8, 0, 0)})
	var patada := _mezclar(GUARDIA, {"PiernaD": Vector3(-105, 0, -10), "RodillaD": Vector3(0, 0, 0), "Columna": Vector3(-20, 0, 0), "Pecho": Vector3(0, 20, 0),
		"BrazoI": Vector3(-20, 0, 60), "BrazoD": Vector3(20, 0, -50), "PiernaI": Vector3(0, 0, 5), "RodillaI": Vector3(10, 0, 0)})

	var sello_a := {"BrazoI": Vector3(-62, 0, -28), "AntebrazoI": Vector3(-78, 0, 0), "ManoI": Vector3(0, -20, 0),
		"BrazoD": Vector3(-62, 0, 28), "AntebrazoD": Vector3(-78, 0, 0), "ManoD": Vector3(0, 20, 0),
		"PiernaI": Vector3(-8, 0, 6), "RodillaI": Vector3(14, 0, 0), "PiernaD": Vector3(4, 0, -6), "RodillaD": Vector3(10, 0, 0), "Cabeza": Vector3(8, 0, 0)}
	var sello_b := _mezclar(sello_a, {"BrazoI": Vector3(-72, 0, -24), "AntebrazoI": Vector3(-68, 0, 0), "ManoI": Vector3(30, 20, 0),
		"BrazoD": Vector3(-56, 0, 30), "AntebrazoD": Vector3(-85, 0, 0), "ManoD": Vector3(-25, -10, 0)})

	var carga_a := {"Columna": Vector3(22, -15, 0), "Pecho": Vector3(6, -10, 0), "Cabeza": Vector3(-18, 20, 0),
		"BrazoD": Vector3(25, 0, -25), "AntebrazoD": Vector3(-30, 0, 0), "ManoD": Vector3(-20, 0, 0),
		"BrazoI": Vector3(-25, 0, -35), "AntebrazoI": Vector3(-70, 0, 0),
		"PiernaI": Vector3(-45, 0, 8), "RodillaI": Vector3(70, 0, 0), "PiernaD": Vector3(20, 0, -12), "RodillaD": Vector3(50, 0, 0)}
	var carga_b := _mezclar(carga_a, {"BrazoD": Vector3(28, 0, -22), "Columna": Vector3(24, -13, 0)})

	var embiste := {"Columna": Vector3(35, 0, 0), "Pecho": Vector3(5, 20, 0), "Cabeza": Vector3(-30, 0, 0),
		"BrazoD": Vector3(-88, 0, -5), "AntebrazoD": Vector3(-5, 0, 0), "BrazoI": Vector3(50, 0, 20), "AntebrazoI": Vector3(-20, 0, 0),
		"PiernaI": Vector3(-60, 0, 0), "RodillaI": Vector3(40, 0, 0), "PiernaD": Vector3(40, 0, 0), "RodillaD": Vector3(60, 0, 0)}

	var lanzar_a := {"Columna": Vector3(-12, 0, 0), "Cabeza": Vector3(-10, 0, 0),
		"BrazoD": Vector3(-45, 0, 35), "AntebrazoD": Vector3(-130, 0, 0), "BrazoI": Vector3(-45, 0, -35), "AntebrazoI": Vector3(-130, 0, 0),
		"PiernaI": Vector3(-20, 0, 8), "RodillaI": Vector3(20, 0, 0), "PiernaD": Vector3(15, 0, -6), "RodillaD": Vector3(10, 0, 0)}
	var lanzar_b := _mezclar(lanzar_a, {"Columna": Vector3(18, 0, 0), "Cabeza": Vector3(5, 0, 0)})

	var golpeado := {"Columna": Vector3(-22, 0, 8), "Pecho": Vector3(-8, 0, 0), "Cabeza": Vector3(-20, 0, 0),
		"BrazoI": Vector3(-20, 0, 40), "BrazoD": Vector3(-15, 0, -45), "AntebrazoI": Vector3(-30, 0, 0), "AntebrazoD": Vector3(-30, 0, 0),
		"PiernaI": Vector3(-10, 0, 0), "RodillaI": Vector3(25, 0, 0)}

	var tendido := {"Caderas": Vector3(-88, 0, 0), "Cabeza": Vector3(10, 0, 0), "BrazoI": Vector3(10, 0, 70), "BrazoD": Vector3(10, 0, -75),
		"PiernaI": Vector3(-8, 0, 10), "RodillaI": Vector3(15, 0, 0), "PiernaD": Vector3(-25, 0, -8), "RodillaD": Vector3(40, 0, 0)}

	return {
		"quieto": {"duracion": 2.4, "bucle": true, "claves": [[0.0, quieto_a, Vector3.ZERO], [1.2, quieto_b, Vector3(0, -0.012, 0)], [2.4, quieto_a, Vector3.ZERO]]},
		"guardia": {"duracion": 1.0, "bucle": true, "claves": [[0.0, GUARDIA, Vector3(0, -0.05, 0)], [0.5, _mezclar(GUARDIA, {"Pecho": Vector3(-3, 0, 0)}), Vector3(0, -0.065, 0)], [1.0, GUARDIA, Vector3(0, -0.05, 0)]]},
		"correr": {"duracion": 0.56, "bucle": true, "claves": [
			[0.0, paso_a, Vector3(0, -0.02, 0)], [0.14, medio_a, Vector3(0, 0.03, 0)], [0.28, paso_b, Vector3(0, -0.02, 0)],
			[0.42, medio_b, Vector3(0, 0.03, 0)], [0.56, paso_a, Vector3(0, -0.02, 0)]]},
		"saltar": {"duracion": 0.4, "bucle": false, "claves": [[0.0, quieto_a, Vector3(0, -0.1, 0)], [0.18, salto, Vector3.ZERO], [0.4, salto, Vector3.ZERO]]},
		"esquivar": {"duracion": 0.3, "bucle": false, "claves": [[0.0, GUARDIA, Vector3.ZERO], [0.1, esquiva, Vector3(0, -0.32, 0)], [0.3, esquiva, Vector3(0, -0.2, 0)]]},
		"golpe1": {"duracion": 0.3, "bucle": false, "claves": [[0.0, GUARDIA, Vector3(0, -0.05, 0)], [0.1, golpe1, Vector3(0, -0.06, 0.06)], [0.3, GUARDIA, Vector3(0, -0.05, 0)]]},
		"golpe2": {"duracion": 0.3, "bucle": false, "claves": [[0.0, GUARDIA, Vector3(0, -0.05, 0)], [0.1, golpe2, Vector3(0, -0.06, 0.06)], [0.3, GUARDIA, Vector3(0, -0.05, 0)]]},
		"golpe3": {"duracion": 0.45, "bucle": false, "claves": [[0.0, GUARDIA, Vector3(0, -0.05, 0)], [0.1, patada_carga, Vector3(0, 0.02, 0)], [0.2, patada, Vector3(0, 0.04, 0)], [0.45, GUARDIA, Vector3(0, -0.05, 0)]]},
		"sellos": {"duracion": 0.32, "bucle": true, "claves": [[0.0, sello_a, Vector3(0, -0.04, 0)], [0.16, sello_b, Vector3(0, -0.05, 0)], [0.32, sello_a, Vector3(0, -0.04, 0)]]},
		"chidori_carga": {"duracion": 0.16, "bucle": true, "claves": [[0.0, carga_a, Vector3(0, -0.2, 0)], [0.08, carga_b, Vector3(0, -0.21, 0)], [0.16, carga_a, Vector3(0, -0.2, 0)]]},
		"chidori_embiste": {"duracion": 0.2, "bucle": true, "claves": [[0.0, embiste, Vector3(0, -0.15, 0)], [0.2, embiste, Vector3(0, -0.15, 0)]]},
		"lanzar": {"duracion": 0.35, "bucle": false, "claves": [[0.0, lanzar_a, Vector3.ZERO], [0.15, lanzar_b, Vector3(0, -0.03, 0.05)], [0.35, lanzar_b, Vector3(0, -0.03, 0.05)]]},
		"golpeado": {"duracion": 0.35, "bucle": false, "claves": [[0.0, GUARDIA, Vector3.ZERO], [0.08, golpeado, Vector3(0, -0.04, -0.08)], [0.35, GUARDIA, Vector3(0, -0.05, 0)]]},
		"caer": {"duracion": 0.55, "bucle": false, "claves": [[0.0, golpeado, Vector3.ZERO], [0.25, _mezclar(golpeado, {"Caderas": Vector3(-45, 0, 0)}), Vector3(0, -0.4, -0.3)], [0.55, tendido, Vector3(0, -0.8, -0.5)]]},
	}


## Construye la AnimationLibrary para un esqueleto en la ruta dada.
static func crear_libreria(ruta_esqueleto: String, huesos: Array, rest_caderas: Vector3) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var defs := definiciones()
	for nombre in defs.keys():
		var d: Dictionary = defs[nombre]
		var anim := Animation.new()
		anim.length = float(d["duracion"])
		anim.loop_mode = Animation.LOOP_LINEAR if d["bucle"] else Animation.LOOP_NONE
		var claves: Array = d["claves"]
		for hueso in huesos:
			var pista := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(pista, "%s:%s" % [ruta_esqueleto, hueso])
			for c in claves:
				var pose: Dictionary = c[1]
				var grados: Vector3 = pose.get(hueso, Vector3.ZERO)
				var q := Quaternion.from_euler(Vector3(deg_to_rad(grados.x), deg_to_rad(grados.y), deg_to_rad(grados.z)))
				anim.rotation_track_insert_key(pista, float(c[0]), q)
		var pista_pos := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pista_pos, "%s:Caderas" % ruta_esqueleto)
		for c in claves:
			anim.position_track_insert_key(pista_pos, float(c[0]), rest_caderas + (c[2] as Vector3))
		lib.add_animation(nombre, anim)
	return lib
