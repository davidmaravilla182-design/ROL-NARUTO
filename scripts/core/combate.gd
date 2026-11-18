class_name Combate
extends RefCounted
## Matemática pura del combate. Sin estado ni nodos: fácil de probar en headless
## y la usa solo el servidor (autoridad).


## Comprueba rango 0-5 de cada atributo y el tope total (26).
static func validar_atributos(attrs: Dictionary) -> Dictionary:
	Datos.cargar()
	var conf: Dictionary = Datos.reglas["atributos"]
	var errores: Array = []
	var total := 0
	for nombre in conf["lista"]:
		if not attrs.has(nombre):
			errores.append("Falta el atributo %s" % nombre)
			continue
		var v := int(attrs[nombre])
		if v < int(conf["minimo"]) or v > int(conf["maximo"]):
			errores.append("%s fuera de rango (%d)" % [nombre, v])
		total += v
	for nombre in attrs.keys():
		if str(nombre).begins_with("_"):
			continue   # "_balance": deslizador reserva/control, no es un atributo con puntos
		if not (nombre in conf["lista"]):
			errores.append("Atributo desconocido %s" % nombre)
	if total > int(conf["tope_total"]):
		errores.append("Total %d supera el tope de %d" % [total, int(conf["tope_total"])])
	return {"ok": errores.is_empty(), "total": total, "errores": errores}


static func _ponderado(attrs: Dictionary, pesos: Dictionary) -> float:
	var s := 0.0
	for k in pesos.keys():
		s += float(attrs.get(k, 0)) * float(pesos[k])
	return s


## Reserva de chakra (0-5): cuánto chakra tiene y qué tan grandes salen sus jutsus.
static func reserva(attrs: Dictionary) -> float:
	Datos.cargar()
	return clampf(_ponderado(attrs, Datos.reglas["derivados"]["reserva"]) + _balance(attrs), 0.0, 5.0)


## Deslizador "Reserva vs. Control" (-1 control … +1 reserva) de la creación de personaje.
static func _balance(attrs: Dictionary) -> float:
	var b := float(attrs.get("_balance", 0.0))
	if b == 0.0:
		return 0.0
	return b * float(Datos.creacion.get("balance_chakra", {}).get("efecto", 1.0))


## Control de chakra (0-5): eficiencia (menos costo) y precisión.
static func control(attrs: Dictionary) -> float:
	Datos.cargar()
	return clampf(_ponderado(attrs, Datos.reglas["derivados"]["control"]) - _balance(attrs), 0.0, 5.0)


## Multiplicador por naturaleza del atacante contra la naturaleza del defensor.
static func multiplicador_naturaleza(atacante: String, defensor: String) -> float:
	Datos.cargar()
	var nat: Dictionary = Datos.mundo["naturalezas"]
	var ciclo: Array = nat["ciclo"]
	var ia := ciclo.find(atacante)
	var id := ciclo.find(defensor)
	if ia < 0 or id < 0 or ia == id:
		return 1.0
	if (ia + 1) % ciclo.size() == id:
		return float(nat["ventaja"])
	if (id + 1) % ciclo.size() == ia:
		return float(nat["desventaja"])
	return 1.0


## Modificadores del clima para una naturaleza: {dano, tamano, cadena, ...}.
static func modificador_clima(naturaleza: String, clima: String) -> Dictionary:
	Datos.cargar()
	var base := {"dano": 1.0, "tamano": 1.0, "cadena": false, "cadena_radio": 0.0, "cadena_factor": 0.0}
	var c: Dictionary = Datos.reglas.get("clima", {}).get(clima, {})
	if c.has(naturaleza):
		base.merge(c[naturaleza], true)
	return base


static func costo_chakra(jutsu_id: String, nivel: int, attrs: Dictionary) -> float:
	var j := Datos.jutsu(jutsu_id)
	var costo := 0.0
	if j.has("niveles"):
		var nd := Datos.nivel_jutsu(jutsu_id, nivel)
		costo = float(nd.get("costo", 0.0))
		# Técnicas que gastan una fracción de la reserva (Kirin): el mayor de los dos.
		if nd.has("costo_pct"):
			return maxf(costo, float(nd["costo_pct"]) * float(estadisticas(attrs)["chakra_max"]))
	else:
		costo = float(j.get("costo_activar", 0.0))
	var mult := (1.0 + reserva(attrs) * Datos.formula("costo_por_reserva")) \
		* (1.0 - control(attrs) * Datos.formula("ahorro_por_control"))
	return costo * maxf(mult, 0.1)


static func costo_por_segundo(jutsu_id: String, attrs: Dictionary, nivel := 1) -> float:
	var j := Datos.jutsu(jutsu_id)
	var base := float(Datos.nivel_jutsu(jutsu_id, nivel).get("costo_por_segundo", j.get("costo_por_segundo", 0.0)))
	return base * maxf(1.0 - control(attrs) * Datos.formula("ahorro_por_control"), 0.1)


static func tiempo_sellos(jutsu_id: String, attrs: Dictionary) -> float:
	var base := float(Datos.jutsu(jutsu_id).get("tiempo_sellos", 0.0))
	var red := 1.0 - float(attrs.get("sellos", 0)) * Datos.formula("sellos_reduccion_por_punto")
	return base * maxf(red, 0.2)


## Daño final de un ninjutsu (antes de defensa): nivel, atributos, naturaleza y clima.
static func dano_jutsu(jutsu_id: String, nivel: int, attrs: Dictionary, naturaleza_defensor: String, clima: String) -> float:
	var j := Datos.jutsu(jutsu_id)
	var base := float(Datos.nivel_jutsu(jutsu_id, nivel).get("dano", 0.0))
	var nat := str(j.get("naturaleza", ""))
	var d := base \
		* (1.0 + float(attrs.get("ninjutsu", 0)) * Datos.formula("dano_por_ninjutsu")) \
		* (1.0 + reserva(attrs) * Datos.formula("dano_por_reserva"))
	d *= multiplicador_naturaleza(nat, naturaleza_defensor)
	d *= float(modificador_clima(nat, clima)["dano"])
	return d


## Escala del tamaño visual/radio de un jutsu (reserva y clima).
static func escala_tamano(jutsu_id: String, attrs: Dictionary, clima: String) -> float:
	var nat := str(Datos.jutsu(jutsu_id).get("naturaleza", ""))
	return (1.0 + reserva(attrs) * Datos.formula("tamano_por_reserva")) * float(modificador_clima(nat, clima)["tamano"])


## Ángulo (grados) de asistencia de puntería: más control, más precisión.
static func precision_grados(attrs: Dictionary) -> float:
	return Datos.formula("precision_grados_base") + control(attrs) * Datos.formula("precision_grados_por_control")


static func dano_taijutsu(paso: int, attrs: Dictionary) -> float:
	var pasos: Array = Datos.jutsu("golpe")["pasos"]
	var p: Dictionary = pasos[clampi(paso, 0, pasos.size() - 1)]
	return float(p["dano"]) * (1.0 \
		+ float(attrs.get("taijutsu", 0)) * Datos.formula("taijutsu_dano_por_taijutsu") \
		+ float(attrs.get("fuerza", 0)) * Datos.formula("taijutsu_dano_por_fuerza"))


## Estadísticas derivadas de los atributos.
static func estadisticas(attrs: Dictionary) -> Dictionary:
	var r := reserva(attrs)
	var c := control(attrs)
	return {
		"vida_max": Datos.formula("vida_base") + float(attrs.get("estamina", 0)) * Datos.formula("vida_por_estamina") + float(attrs.get("fuerza", 0)) * Datos.formula("vida_por_fuerza"),
		"chakra_max": Datos.formula("chakra_base") + r * Datos.formula("chakra_por_reserva"),
		"estamina_max": Datos.formula("estamina_base") + float(attrs.get("estamina", 0)) * Datos.formula("estamina_por_estamina") + float(attrs.get("taijutsu", 0)) * Datos.formula("estamina_por_taijutsu"),
		"velocidad": Datos.formula("velocidad_base") * (1.0 + float(attrs.get("velocidad", 0)) * Datos.formula("velocidad_por_punto")),
		"regen_chakra": Datos.formula("regen_chakra_base") + c * Datos.formula("regen_chakra_por_control"),
		"regen_estamina": Datos.formula("regen_estamina"),
		"reserva": r,
		"control": c,
	}
