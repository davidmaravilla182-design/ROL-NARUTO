class_name Atributos
extends RefCounted
## Efectos reales de los 8 atributos (0-5), en un solo sitio: el servidor los aplica, la ficha los muestra
## y las pruebas los comprueban. Los números viven en data/reglas.json → efectos_atributos.
## El entrenamiento por uso suma una bonificación (hasta +0,5) guardada en attrs["_entreno"][atributo].

const LISTA := ["ninjutsu", "taijutsu", "genjutsu", "inteligencia", "fuerza", "velocidad", "estamina", "sellos"]


static func ef(atributo: String, clave: String, defecto := 0.0) -> float:
	Datos.cargar()
	return float(Datos.reglas.get("efectos_atributos", {}).get(atributo, {}).get(clave, defecto))


## Valor efectivo: puntos + bonificación de entrenamiento.
static func v(attrs: Dictionary, a: String) -> float:
	var base := float(attrs.get(a, 0))
	var ent: Variant = attrs.get("_entreno", {})
	if typeof(ent) == TYPE_DICTIONARY:
		base += float((ent as Dictionary).get(a, 0.0))
	return base


# ------------------------------------------------------------------ ninjutsu

static func mult_dano_ninjutsu(attrs: Dictionary) -> float:
	return 1.0 + v(attrs, "ninjutsu") * ef("ninjutsu", "dano")


static func mult_tamano_ninjutsu(attrs: Dictionary) -> float:
	return 1.0 + v(attrs, "ninjutsu") * ef("ninjutsu", "tamano")


static func mult_alcance(attrs: Dictionary) -> float:
	return 1.0 + v(attrs, "ninjutsu") * ef("ninjutsu", "alcance")


# ------------------------------------------------------------------ taijutsu

## Golpes del combo: 2 + Taijutsu (1 → 3 golpes, 5 → 7).
static func combo_largo(attrs: Dictionary) -> int:
	var n := int(ef("taijutsu", "combo_base", 2.0)) + int(floor(v(attrs, "taijutsu")))
	return clampi(n, int(ef("taijutsu", "combo_min", 2.0)), int(ef("taijutsu", "combo_max", 7.0)))


## Pasos del combo (índices en golpe.pasos) para un largo dado. El último siempre es la patada final (índice 6).
static func secuencia_combo(largo: int) -> Array:
	match clampi(largo, 2, 7):
		2: return [0, 6]
		3: return [0, 1, 6]
		4: return [0, 1, 2, 6]
		5: return [0, 1, 2, 5, 6]
		6: return [0, 1, 2, 3, 5, 6]
	return [0, 1, 2, 3, 4, 5, 6]


static func mult_dano_taijutsu(attrs: Dictionary) -> float:
	return 1.0 + v(attrs, "taijutsu") * ef("taijutsu", "dano") + v(attrs, "fuerza") * ef("fuerza", "dano")


# ------------------------------------------------------------------ genjutsu

## Duración de un genjutsu: más larga con el Genjutsu del lanzador, más corta con el del objetivo.
static func mult_duracion_genjutsu(lanzador: Dictionary, objetivo: Dictionary) -> float:
	var mas := 1.0 + v(lanzador, "genjutsu") * ef("genjutsu", "duracion")
	return mas * (1.0 - resistencia_genjutsu(objetivo))


static func resistencia_genjutsu(attrs: Dictionary) -> float:
	return minf(v(attrs, "genjutsu") * ef("genjutsu", "resistencia"), ef("genjutsu", "resistencia_max", 0.6))


static func mult_potencia_genjutsu(attrs: Dictionary) -> float:
	return 1.0 + v(attrs, "genjutsu") * ef("genjutsu", "potencia")


# ------------------------------------------------------------------ inteligencia

static func mult_recarga(attrs: Dictionary) -> float:
	return maxf(1.0 - v(attrs, "inteligencia") * ef("inteligencia", "recarga"), 0.5)


static func mult_maestria(attrs: Dictionary) -> float:
	return 1.0 + v(attrs, "inteligencia") * ef("inteligencia", "maestria")


static func ve_vida(attrs: Dictionary) -> bool:
	return v(attrs, "inteligencia") >= ef("inteligencia", "ver_vida", 1.0)


static func ve_debilidad(attrs: Dictionary) -> bool:
	return v(attrs, "inteligencia") >= ef("inteligencia", "ver_debilidad", 3.0)


static func ve_emboscadas(attrs: Dictionary) -> bool:
	return v(attrs, "inteligencia") >= ef("inteligencia", "ver_emboscadas", 4.0)


# ------------------------------------------------------------------ fuerza

static func mult_empuje(attrs: Dictionary) -> float:
	return 1.0 + v(attrs, "fuerza") * ef("fuerza", "empuje")


static func rompe_guardia(attrs: Dictionary) -> bool:
	return v(attrs, "fuerza") >= ef("fuerza", "rompe_guardia", 3.0)


# ------------------------------------------------------------------ velocidad

static func mult_movimiento(attrs: Dictionary) -> float:
	return 1.0 + v(attrs, "velocidad") * ef("velocidad", "movimiento")


## Factor de duración de los golpes (menos de 1 = golpes más rápidos).
static func factor_ataque(attrs: Dictionary) -> float:
	return 1.0 / (1.0 + v(attrs, "velocidad") * ef("velocidad", "ataque"))


static func ventana_extra(attrs: Dictionary) -> float:
	return v(attrs, "velocidad") * ef("velocidad", "ventana")


static func shunshin_extra(attrs: Dictionary) -> float:
	return v(attrs, "velocidad") * ef("velocidad", "shunshin")


# ------------------------------------------------------------------ estamina

static func mult_regen_estamina(attrs: Dictionary) -> float:
	return 1.0 + v(attrs, "estamina") * ef("estamina", "regen")


## Costo de caminar por paredes y agua (menos con más Estamina).
static func mult_costo_movil(attrs: Dictionary) -> float:
	return maxf(1.0 - v(attrs, "estamina") * ef("estamina", "ahorro_movil"), 0.4)


# ------------------------------------------------------------------ sellos

static func factor_sellos(attrs: Dictionary) -> float:
	var s := v(attrs, "sellos")
	if s >= 5.0:
		return ef("sellos", "minimo", 0.15)   # casi sin sellos
	var f := 1.0 - s * ef("sellos", "reduccion")
	if s >= ef("sellos", "una_mano", 4.0):
		f *= ef("sellos", "una_mano_factor", 0.5)
	return maxf(f, ef("sellos", "minimo", 0.15))


static func una_mano(attrs: Dictionary) -> bool:
	return v(attrs, "sellos") >= ef("sellos", "una_mano", 4.0)


static func puede_sellar_bijuu(attrs: Dictionary) -> bool:
	return v(attrs, "sellos") >= ef("sellos", "sellar_bijuu", 3.0)


# ------------------------------------------------------------------ ficha

static func _pct(x: float) -> String:
	return "%+d %%" % int(round(x * 100.0))


## Líneas con el efecto actual de un atributo (para la ficha del personaje).
static func efectos_texto(a: String, attrs: Dictionary) -> Array:
	match a:
		"ninjutsu":
			return [Datos.texto("ef_dano_ninjutsu", [_pct(mult_dano_ninjutsu(attrs) - 1.0)]),
				Datos.texto("ef_tamano_alcance", [_pct(mult_tamano_ninjutsu(attrs) - 1.0), _pct(mult_alcance(attrs) - 1.0)])]
		"taijutsu":
			return [Datos.texto("ef_combo", [combo_largo(attrs)]),
				Datos.texto("ef_dano_taijutsu", [_pct(v(attrs, "taijutsu") * ef("taijutsu", "dano"))])]
		"genjutsu":
			return [Datos.texto("ef_genjutsu_dur", [_pct(v(attrs, "genjutsu") * ef("genjutsu", "duracion"))]),
				Datos.texto("ef_genjutsu_res", [int(round(resistencia_genjutsu(attrs) * 100.0))])]
		"inteligencia":
			var vis: Array = []
			if ve_vida(attrs):
				vis.append(Datos.texto("ef_ve_vida"))
			if ve_debilidad(attrs):
				vis.append(Datos.texto("ef_ve_debilidad"))
			if ve_emboscadas(attrs):
				vis.append(Datos.texto("ef_ve_emboscadas"))
			return [Datos.texto("ef_recarga", [_pct(mult_recarga(attrs) - 1.0), _pct(mult_maestria(attrs) - 1.0)]),
				", ".join(vis) if not vis.is_empty() else Datos.texto("ef_ve_nada")]
		"fuerza":
			return [Datos.texto("ef_fuerza", [_pct(v(attrs, "fuerza") * ef("fuerza", "dano")), _pct(mult_empuje(attrs) - 1.0)]),
				Datos.texto("ef_rompe_guardia") if rompe_guardia(attrs) else Datos.texto("ef_rompe_guardia_no", [int(ef("fuerza", "rompe_guardia", 3.0))])]
		"velocidad":
			return [Datos.texto("ef_velocidad", [_pct(mult_movimiento(attrs) - 1.0), _pct(1.0 / factor_ataque(attrs) - 1.0)]),
				Datos.texto("ef_esquiva", ["%.2f" % ventana_extra(attrs), "%.1f" % shunshin_extra(attrs)])]
		"estamina":
			return [Datos.texto("ef_estamina", [int(v(attrs, "estamina") * ef("estamina", "vida")), int(v(attrs, "estamina") * ef("estamina", "estamina"))]),
				Datos.texto("ef_estamina_movil", [_pct(mult_costo_movil(attrs) - 1.0), _pct(mult_regen_estamina(attrs) - 1.0)])]
		"sellos":
			var t := Datos.texto("ef_sellos", [_pct(factor_sellos(attrs) - 1.0)])
			if v(attrs, "sellos") >= 5.0:
				t += " · " + Datos.texto("ef_sin_sellos")
			elif una_mano(attrs):
				t += " · " + Datos.texto("ef_una_mano")
			return [t, Datos.texto("ef_sellado", ["Sí" if puede_sellar_bijuu(attrs) else "No"])]
	return []
