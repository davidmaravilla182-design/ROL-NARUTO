"""Lote de modelos de Meshy para el mapa de la aldea (Text to 3D con Smart Topology).

Cada modelo: fase 1 "preview" (malla, 5 créditos) + fase 2 "refine" (textura, 10 créditos) = 15.
El estado vive en referencias/modelos-ia/meshy/lote.json: una tarea creada NUNCA se vuelve a crear
(si una creación falla por red, se revisa a mano antes de reintentar). Si una tarea termina en FAILED
se reintenta una sola vez (campo "reintentos"); si vuelve a fallar, el modelo se hace en Blender.

Uso (en segundo plano):  python3 tools/meshy_lote.py [nombres...]   ·   python3 tools/meshy_lote.py --estado
"""
import json
import os
import sys
import time
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meshy  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CARPETA = os.path.join(RAIZ, "referencias", "modelos-ia", "meshy")
ESTADO = os.path.join(CARPETA, "lote.json" if os.environ.get("MESHY_LOTE", "mapa") == "mapa" else "lote_%s.json" % os.environ["MESHY_LOTE"])
MAX_CREDITOS = int(os.environ.get("MESHY_MAX", "350"))   # presupuesto de la noche (incluye reintentos)
LOTE = os.environ.get("MESHY_LOTE", "mapa")

ESTILO = ("stylized anime video game asset, rainy dark industrial ninja village, "
          "clean readable shapes, single object, no ground plane")
PALETA = ("stained weathered grey concrete with rain streaks, dark gunmetal riveted metal sheets, "
          "burgundy red rusty pipes, small lilac purple accents, warm amber lit windows and lamps, "
          "muted desaturated colors, hand painted texture, wet surfaces")

MODELOS = {
    # Edificios comunes (se repiten con MultiMesh)
    "casa_chica": (9000, "small two story narrow house, stacked concrete box with dark corrugated metal roof, "
                   "pipes running down the walls, small square windows, metal door with awning, water tank on roof"),
    "edificio_mediano": (9000, "five story apartment block, rectangular concrete tower with stacked metal balconies, "
                         "rows of small windows, pipes and ducts on the facade, rooftop with vents and a small chimney"),
    "taller_industrial": (9000, "industrial workshop warehouse building, wide low structure with sawtooth metal roof, "
                          "big rolling garage door, tall chimney stack, external tanks and thick pipes along the side"),
    "torre_vivienda_a": (9000, "tall cylindrical residential tower, stacked concrete rings with many small windows, "
                         "external pipes spiraling up, ring shaped metal walkway balconies, antenna on top"),
    "torre_vivienda_b": (9000, "tall cylindrical housing tower with a wider mushroom shaped top cap, iron bands, "
                         "vertical pipes, small round windows, metal stair platforms around the base"),
    # Objetos repetibles (1–2k triángulos)
    "barril": (1500, "metal oil barrel drum with ribs and dents, rusty"),
    "caja": (1200, "wooden shipping crate with metal corner brackets"),
    "tanque_agua": (2000, "small elevated water tank on four steel legs with a ladder"),
    "farol": (1500, "street lamp post with a hanging amber glass lantern, iron pole"),
    "carreta": (2000, "old wooden hand cart with two big wheels, loaded with boxes"),
    "sacos": (1500, "pile of burlap grain sacks stacked together"),
    "pila_tuberias": (1800, "stack of long metal pipes tied together on wooden beams"),
    "roca": (1000, "mossy grey boulder rock"),
    "banca": (1200, "simple public bench made of wooden planks on metal frame"),
    "puesto_mercado": (2000, "street food market stall with wooden counter and striped fabric awning, hanging paper lanterns"),
    # Edificios emblemáticos (únicos)
    "puerta_aldea": (10000, "massive fortified village main gate set in a thick high concrete wall, two heavy riveted "
                     "metal doors, guard towers on both sides, pipes and floodlights, imposing"),
    "academia": (10000, "ninja academy school building, three stories, concrete and dark metal, wide entrance with stairs, "
                 "rows of lit windows, flat roof with a big water tank and railings"),
    "entrada_mercado": (8000, "covered market street entrance archway, metal frame roof canopy with hanging lanterns "
                        "and cloth banners, two pillars, shop signs"),
}


# Lote v0.7: peinados y formas de jutsus. Solo malla (5 créditos): el color y los efectos los pone el shader del juego.
# Los que llevan textura (refine, +10) usan la paleta de cada uno.
ESTILO_PELO = "stylized anime game asset, hair piece only, single object, no head, no face, no body, hollow inside, clean shapes"
ESTILO_JUTSU = "stylized anime game asset, single creature, dramatic pose, clean readable silhouette, no base, no ground"
MODELOS_V07 = {
    "pelo_puntas": (12000, "anime ninja spiky hair wig with many sharp spikes pointing back and up, short bangs", None),
    "pelo_corto": (12000, "anime short messy hair wig with layered strands and side bangs, natural and not helmet shaped", None),
    "pelo_largo": (12000, "anime long straight hair wig falling to the middle of the back with long front bangs", None),
    "pelo_coleta": (12000, "anime hair wig tied in a high ponytail with loose front bangs", None),
    "susanoo_1": (6000, "giant spectral ribcage and spine skeleton torso with arms, ethereal chakra guardian", None),
    "susanoo_2": (8000, "giant spectral warrior torso with muscular arms holding a large bow, horned demon face, half body", None),
    "susanoo_3": (10000, "giant armored samurai spirit warrior with long nose tengu mask helmet, wings of armor plates, holding a long sword, full body", None),
    "kirin": (8000, "eastern dragon beast made of lightning diving down from the sky, open jaws, long serpentine body, horns", None),
    "dragon_agua": (8000, "eastern water dragon with big open jaws, long serpentine body rising up in an arc, fins, whiskers", None),
    "dragon_madera": (8000, "eastern dragon made of twisted tree trunks and wooden roots rising from the ground, bark texture, open jaws",
                      "twisted brown bark wood, light wood at the cracks, green moss, roots"),
    "golem_tierra": (8000, "giant rock golem made of stacked boulders and earth rising from the ground, heavy fists, glowing cracks",
                     "grey brown rock and earth, mossy stones, orange glowing cracks"),
}
if LOTE == "v07":
    MODELOS = {k: (v[0], v[1]) for k, v in MODELOS_V07.items()}


def cargar():
    if os.path.exists(ESTADO):
        return json.load(open(ESTADO))
    return {"modelos": {}, "creditos": 0}


def guardar(est):
    os.makedirs(CARPETA, exist_ok=True)
    tmp = ESTADO + ".tmp"
    json.dump(est, open(tmp, "w"), indent=1, ensure_ascii=False)
    os.replace(tmp, ESTADO)


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


def paso(est, nombre):
    """Avanza un modelo un paso. Devuelve True si ya terminó (bien o mal)."""
    polys, desc = MODELOS[nombre]
    m = est["modelos"].setdefault(nombre, {"fase": "nuevo", "reintentos": 0, "creditos": 0})
    if m["fase"] in ("listo", "fallido"):
        return True
    if m["fase"] == "nuevo":
        if est["creditos"] + (5 if LOTE == "v07" and MODELOS_V07[nombre][2] is None else 15) > MAX_CREDITOS:
            log(nombre, "sin presupuesto")
            return True
        m["fase"] = "creando_vista"   # marca antes de pedir: si se corta, no se recrea a ciegas
        guardar(est)
        estilo = ESTILO if LOTE == "mapa" else (ESTILO_PELO if nombre.startswith("pelo_") else ESTILO_JUTSU)
        m["vista"] = meshy.texto_a_3d_vista("%s, %s" % (desc, estilo), polys)
        m["fase"] = "vista"
        m["creditos"] += 5
        est["creditos"] += 5
        guardar(est)
        log(nombre, "vista creada", m["vista"])
        return False
    if m["fase"] == "vista":
        e = meshy.estado(m["vista"], "text-to-3d")
        if e["status"] == "SUCCEEDED" and LOTE == "v07" and MODELOS_V07[nombre][2] is None:
            # Solo malla: se descarga la vista previa (sin textura) y listo.
            meshy.bajar(e, os.path.join(CARPETA, nombre))
            m["fase"] = "listo"
            guardar(est)
            log(nombre, "LISTO (solo malla)")
            return True
        if e["status"] == "SUCCEEDED":
            m["fase"] = "creando_textura"
            guardar(est)
            tex = PALETA if LOTE == "mapa" else MODELOS_V07[nombre][2]
            m["textura"] = meshy.texto_a_3d_textura(m["vista"], "%s. %s" % (desc, tex))
            m["fase"] = "textura"
            m["creditos"] += 10
            est["creditos"] += 10
            guardar(est)
            log(nombre, "textura creada", m["textura"])
        elif e["status"] in ("FAILED", "CANCELED", "EXPIRED"):
            _fallo(est, m, nombre, e)
        return False
    if m["fase"] == "textura":
        e = meshy.estado(m["textura"], "text-to-3d")
        if e["status"] == "SUCCEEDED":
            meshy.bajar(e, os.path.join(CARPETA, nombre))
            m["fase"] = "listo"
            guardar(est)
            log(nombre, "LISTO")
            return True
        if e["status"] in ("FAILED", "CANCELED", "EXPIRED"):
            _fallo(est, m, nombre, e)
        return False
    # creando_*: una creación quedó a medias; revisar a mano (no recrear a ciegas).
    log(nombre, "estado dudoso:", m["fase"], "— revisar con meshy_list_tasks")
    return True


def _fallo(est, m, nombre, e):
    log(nombre, "FALLÓ", e.get("task_error"))
    if m["reintentos"] < 1:
        m["reintentos"] += 1
        m["fase"] = "nuevo"
    else:
        m["fase"] = "fallido"
    guardar(est)


def main():
    if "--estado" in sys.argv:
        est = cargar()
        for n, m in est["modelos"].items():
            print("%-18s %-10s %3d créditos" % (n, m["fase"], m["creditos"]))
        print("total", est["creditos"], "créditos")
        return
    nombres = [a for a in sys.argv[1:] if a in MODELOS] or list(MODELOS)
    est = cargar()
    pendientes = list(nombres)
    while pendientes:
        for n in list(pendientes):
            try:
                if paso(est, n):
                    pendientes.remove(n)
            except urllib.error.HTTPError as ex:
                # 4xx (p. ej. 429 por demasiadas tareas a la vez): la API rechazó la creación, no cobró: se vuelve atrás.
                m = est["modelos"].get(n, {})
                if 400 <= ex.code < 500 and m.get("fase", "").startswith("creando"):
                    m["fase"] = {"creando_vista": "nuevo", "creando_textura": "vista"}[m["fase"]]
                    guardar(est)
                    log(n, "rechazada (%d), se reintenta luego" % ex.code)
                else:
                    log(n, "error:", ex)
                    if m.get("fase", "").startswith("creando"):
                        pendientes.remove(n)
            except Exception as ex:  # red: el estado dudoso se revisa a mano (no se recrea a ciegas)
                log(n, "error:", ex)
                if est["modelos"].get(n, {}).get("fase", "").startswith("creando"):
                    pendientes.remove(n)
        if pendientes:
            time.sleep(15)
    log("lote terminado ·", est["creditos"], "créditos")


if __name__ == "__main__":
    main()
