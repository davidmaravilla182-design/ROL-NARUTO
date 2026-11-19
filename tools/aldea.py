"""Trazado de la aldea completa (isla en el lago, muralla, 8 distritos) → data/escenario.json.

El juego solo lee datos: este script coloca edificios, objetos, plataformas, escaleras, puentes, puntos de misión
y aldeanos de forma determinista (semilla fija) respetando calles reservadas y huellas de cada pieza.
Las piezas hechas a mano de la plaza original se conservan (PLAZA_BASE).

Uso: python3 tools/aldea.py
"""
import json
import math
import os
import random

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RUTA = os.path.join(RAIZ, "data", "escenario.json")

CENTRO = (0.0, -80.0)       # centro de la isla (la torre del rostro)
RADIO_MURO = 150.0
RADIO_CAMINABLE = 146.0
PUERTA_Z = CENTRO[1] + RADIO_MURO   # 70: la puerta mira al sur (+Z)

DISTRITOS = [
    {"id": "plaza", "nombre": "Plaza y campo de entrenamiento", "corto": "Plaza", "rect": [-38, -22, 38, 42]},
    {"id": "canal", "nombre": "Distrito del canal", "corto": "Canal", "rect": [38, -62, 150, 70]},
    {"id": "mercado", "nombre": "Mercado", "corto": "Mercado", "rect": [-150, -62, -38, 70]},
    {"id": "residencial", "nombre": "Zona residencial", "corto": "Residencial", "rect": [-150, -232, -38, -62]},
    {"id": "industrial", "nombre": "Distrito industrial", "corto": "Industrial", "rect": [38, -232, 150, -62]},
    {"id": "academia", "nombre": "Academia ninja", "corto": "Academia", "rect": [-38, -232, 38, -112]},
    {"id": "puerta", "nombre": "Puerta principal y muralla", "corto": "Puerta", "rect": [-38, 42, 38, 176]},
    {"id": "torre", "nombre": "Torre del líder", "corto": "Torre", "rect": [-38, -112, 38, -22]},
]

# Calles y espacios que deben quedar libres: [x0, z0, x1, z1]
RESERVAS = [
    [-6, -64, 6, 72],          # avenida principal: puerta → plaza → torre
    [-20, -20, 20, 22],        # campo de entrenamiento
    [-140, -9, -20, 0],        # calle del mercado (techada)
    [20, 1, 150, 9],           # avenida este (canal)
    [-150, -33, 150, -21],     # canal y sus muros
    [-60, -118, 60, -60],      # explanada de la torre
    [-24, -138, 24, -112],     # patio de la academia
    [-90, -150, -84, -60],     # calle residencial
    [-150, -110, -40, -104],   # calle residencial transversal
    [84, -200, 90, -60],       # calle industrial
    [40, -134, 150, -128],     # calle industrial transversal
]

# Piezas hechas a mano de la plaza original (sin el silo que tapaba la avenida a la puerta ni el de la salida este).
PLAZA_BASE = [
    {"tipo": "edificio", "pos": [26.0, -14.0], "giro": 270}, {"tipo": "edificio", "pos": [27.0, -3.0], "giro": 270},
    {"tipo": "edificio", "pos": [26.0, 13.0], "giro": 270},
    {"tipo": "edificio_ia", "pos": [-26.0, -13.0], "giro": 90}, {"tipo": "edificio", "pos": [-27.0, 4.0], "giro": 90},
    {"tipo": "silo", "pos": [-34.0, 16.0], "giro": 40}, {"tipo": "tanque", "pos": [-24.0, 15.0], "giro": 0},
    {"tipo": "edificio", "pos": [-12.0, 27.0], "giro": 180}, {"tipo": "edificio", "pos": [12.0, 26.0], "giro": 180},
    {"tipo": "tanque", "pos": [21.0, 23.0], "giro": 30},
    {"tipo": "edificio", "pos": [-30.0, -38.0], "giro": 0}, {"tipo": "edificio", "pos": [-12.0, -37.0], "giro": 0},
    {"tipo": "silo", "pos": [12.0, -42.0], "giro": 0}, {"tipo": "edificio", "pos": [26.0, -38.0], "giro": 0},
    {"tipo": "torre_ia", "pos": [0.0, -80.0], "giro": 0},
]

TINTES = {
    "gris": [[0.92, 0.92, 0.95], [0.82, 0.83, 0.88], [0.74, 0.75, 0.8], [0.88, 0.86, 0.9]],
    "lila": [[0.86, 0.8, 0.94], [0.78, 0.74, 0.86], [0.9, 0.86, 0.95]],
    "calido": [[1.0, 0.9, 0.8], [0.95, 0.85, 0.75], [0.9, 0.88, 0.86]],
    "oxido": [[0.9, 0.78, 0.72], [0.8, 0.72, 0.7], [0.86, 0.84, 0.82]],
}


class Trazado:
    def __init__(self, huellas):
        self.h = huellas
        self.ocupado = []    # [cx, cz, hx, hz]
        self.piezas = []
        self.props = []
        self.plataformas = []
        self.rng = random.Random(4242)

    def medio(self, tipo, giro, esc=1.0):
        w, d, _ = self.h[tipo]
        hx, hz = w * 0.5 * esc, d * 0.5 * esc
        g = int(round(giro / 90.0)) % 2
        if abs(math.fmod(giro, 90.0)) > 1.0:
            m = max(hx, hz)
            return m, m
        return (hz, hx) if g == 1 else (hx, hz)

    def libre(self, x, z, hx, hz, margen=1.0, reservas=True, radio=RADIO_CAMINABLE - 4):
        # Dentro de la isla (la esquina más lejana dentro del círculo).
        for sx in (-1, 1):
            for sz in (-1, 1):
                if math.hypot(x + sx * hx - CENTRO[0], z + sz * hz - CENTRO[1]) > radio:
                    return False
        if reservas:
            for r in RESERVAS:
                if x + hx > r[0] and x - hx < r[2] and z + hz > r[1] and z - hz < r[3]:
                    return False
        for o in self.ocupado:
            if abs(x - o[0]) < hx + o[2] + margen and abs(z - o[1]) < hz + o[3] + margen:
                return False
        return True

    def ocupar(self, x, z, hx, hz):
        self.ocupado.append([x, z, hx, hz])

    def pieza(self, tipo, x, z, giro=0, esc=1.0, tinte=None, margen=1.0, reservas=True, forzar=False, colision=True):
        hx, hz = self.medio(tipo, giro, esc) if tipo in self.h else (1.0, 1.0)
        if not forzar and not self.libre(x, z, hx, hz, margen, reservas):
            return False
        self.ocupar(x, z, hx, hz)
        p = {"tipo": tipo, "pos": [round(x, 2), round(z, 2)], "giro": giro}
        if abs(esc - 1.0) > 0.001:
            p["escala"] = round(esc, 3)
        if tinte:
            p["tinte"] = tinte
        if not colision:
            p["colision"] = False
        self.piezas.append(p)
        return True

    def prop(self, tipo, x, z, giro=None, esc=None, tinte=None, margen=0.3, reservas=False, forzar=False):
        giro = self.rng.choice([0, 90, 180, 270]) + self.rng.uniform(-12, 12) if giro is None else giro
        esc = self.rng.uniform(0.88, 1.12) if esc is None else esc
        hx, hz = self.medio(tipo, giro, esc) if tipo in self.h else (0.4, 0.4)
        if not forzar and not self.libre(x, z, hx, hz, margen, reservas):
            return False
        if tipo in self.h:
            self.ocupar(x, z, hx, hz)
        p = {"tipo": tipo, "pos": [round(x, 2), round(z, 2)], "giro": round(giro, 1)}
        if abs(esc - 1.0) > 0.001:
            p["escala"] = round(esc, 3)
        if tinte:
            p["tinte"] = tinte
        self.props.append(p)
        return True

    def plataforma(self, x, z, hx, hz, altura, tipo="pasarela", altura0=None, eje="z"):
        p = {"pos": [round(x, 2), round(z, 2)], "medio": [round(hx, 2), round(hz, 2)], "altura": round(altura, 2), "tipo": tipo}
        if altura0 is not None:
            p["altura0"] = round(altura0, 2)
            p["eje"] = eje
        self.plataformas.append(p)
        self.ocupar(x, z, hx, hz)

    def dispersar(self, rect, tipos, n, tintes="gris", reservas=True, intentos=40):
        """Objetos repartidos al azar en un rectángulo (grupos: a veces apilados de 2-4 juntos)."""
        x0, z0, x1, z1 = rect
        hechos = 0
        for _ in range(n * intentos):
            if hechos >= n:
                break
            tipo = self.rng.choice(tipos)
            x, z = self.rng.uniform(x0, x1), self.rng.uniform(z0, z1)
            if self.prop(tipo, x, z, tinte=self.rng.choice(TINTES[tintes]), reservas=reservas):
                hechos += 1
                # Grupito alrededor (variación de apilado/agrupado).
                if tipo in ("barril", "caja_ia", "sacos") and self.rng.random() < 0.6:
                    for k in range(self.rng.randint(1, 3)):
                        a = self.rng.uniform(0, math.tau)
                        r = self.rng.uniform(0.9, 1.6)
                        self.prop(tipo, x + math.cos(a) * r, z + math.sin(a) * r, tinte=self.rng.choice(TINTES[tintes]))
        return hechos

    def lotes(self, rect, tipos, paso, tintes, giro_fn, esc=(0.92, 1.1), prob=0.85, margen=2.0):
        """Edificios en cuadrícula con jitter; giro_fn(x, z) decide hacia dónde mira la fachada."""
        x0, z0, x1, z1 = rect
        z = z0 + paso * 0.5
        while z < z1:
            x = x0 + paso * 0.5
            while x < x1:
                if self.rng.random() < prob:
                    tipo = self.rng.choice(tipos)
                    jx, jz = self.rng.uniform(-paso * 0.15, paso * 0.15), self.rng.uniform(-paso * 0.15, paso * 0.15)
                    self.pieza(tipo, x + jx, z + jz, giro_fn(x, z), self.rng.uniform(*esc), self.rng.choice(TINTES[tintes]), margen)
                x += paso
            z += paso


def rellenar(t, rect, tipos, n, tintes, giro_fn, margen=1.2, esc=(0.9, 1.12)):
    """Relleno denso: intenta colocar n edificios al azar en los huecos que quedan."""
    x0, z0, x1, z1 = rect
    hechos = 0
    for _ in range(n * 30):
        if hechos >= n:
            break
        x, z = t.rng.uniform(x0, x1), t.rng.uniform(z0, z1)
        if t.pieza(t.rng.choice(tipos), x, z, giro_fn(x, z), t.rng.uniform(*esc), t.rng.choice(TINTES[tintes]), margen):
            hechos += 1
    return hechos


def hacia(cx, cz):
    """Giro (múltiplo de 90) para que la fachada mire hacia el punto (cx, cz)."""
    def f(x, z):
        dx, dz = cx - x, cz - z
        if abs(dx) > abs(dz):
            return 90 if dx > 0 else 270
        return 0 if dz > 0 else 180
    return f


def main():
    esc = json.load(open(RUTA, encoding="utf-8"))
    tz = esc["trazado"]
    t = Trazado(tz["huellas"])
    rng = t.rng
    extra = []
    # Objetos del suelo hechos a mano en la plaza (se guardan una vez y se conservan).
    if "props_base" not in tz:
        tz["props_base"] = tz["props"]
    for p in tz["props_base"]:
        t.props.append(p)
        if p["tipo"] in t.h:
            hx, hz = t.medio(p["tipo"], p.get("giro", 0))
            t.ocupar(p["pos"][0], p["pos"][1], hx, hz)
    # Huellas de las piezas del kit sin huella (para reservar sitio).
    t.h.setdefault("chimenea", [2.4, 2.4, 20.0])
    t.h.setdefault("muneco", [0.8, 0.8, 1.8])

    # ---------------------------------------------------------------- 8. torre del líder (centro) y plaza base
    for p in PLAZA_BASE:
        t.pieza(p["tipo"], p["pos"][0], p["pos"][1], p["giro"], forzar=True)
    # El campo de entrenamiento y la explanada de la torre quedan libres.
    puentes = [-15.0, 0.0, 15.0, 52.0, 78.0, 104.0, 128.0, -30.0]
    # ---------------------------------------------------------------- 1. plaza ampliada
    for x, z, g in [(-16, 34, 0), (16, 34, 0), (-34, -4, 90), (34, 0, 270), (-22, -18, 45), (22, -19, 315)]:
        t.prop("farol_calle", x, z, g, 1.0, forzar=True)
    for x, z, g in [(-9, 21, 0), (9, 21, 0), (-21, 6, 90), (21, -6, 270), (-10, -20, 180), (10, -20, 180)]:
        t.prop("banca", x, z, g, 1.0, forzar=True)
    t.dispersar([-36, -21, -21, 40], ["barril", "caja_ia", "sacos", "pila_tuberias", "carreta"], 10, "gris")
    t.dispersar([21, -21, 36, 40], ["barril", "caja_ia", "sacos", "pila_tuberias", "tanque_agua"], 10, "oxido")
    t.dispersar([-20, 22, 20, 40], ["barril", "caja_ia", "sacos", "roca"], 5, "gris")
    # Mirador con escalera junto a la plaza (verticalidad): escalera de 0 a 5 m y losa a 5 m.
    t.plataforma(-31.0, 27.5, 1.2, 4.0, 5.0, "escalera", 0.0, "z")
    t.plataforma(-31.0, 35.0, 4.0, 3.5, 5.0, "techo")
    # ---------------------------------------------------------------- 2. canal
    canal = {"x_min": -40.0, "x_max": 152.0, "z_sur": -23.0, "z_norte": -31.0, "nivel_agua": -1.1}
    t.lotes([40, -62, 146, -33], ["casa_chica", "edificio_mediano", "edificio", "casa_chica"], 17, "gris", hacia(90, -27), margen=2.5)
    t.lotes([40, -21, 146, 1], ["casa_chica", "edificio", "casa_chica", "edificio_mediano"], 15, "lila", hacia(90, -27), margen=2.5)
    t.lotes([40, 9, 140, 66], ["casa_chica", "edificio_mediano", "taller_industrial", "casa_chica"], 18, "gris", hacia(90, 5), margen=2.5)
    rellenar(t, [40, -62, 146, 66], ["casa_chica", "casa_chica", "edificio", "tanque_agua"], 40, "gris", hacia(90, -27))
    t.dispersar([40, -21, 146, 1], ["barril", "caja_ia", "pila_tuberias", "farol_calle", "banca"], 26, "gris")
    t.dispersar([40, 9, 140, 60], ["barril", "caja_ia", "sacos", "farol_calle", "carreta", "roca"], 22, "oxido")
    # Pasarela elevada sobre la orilla norte del canal con escaleras a ambos lados.
    t.plataforma(91.0, -35.5, 40.0, 1.6, 5.0, "pasarela")
    t.plataforma(48.0, -35.5, 3.0, 1.2, 5.0, "escalera", 0.0, "x")
    t.plataforma(134.0, -35.5, 3.0, 1.2, 0.0, "escalera", 5.0, "x")
    # ---------------------------------------------------------------- 3. mercado (calle techada)
    for x in range(-58, -136, -9):
        for lado, z, g in ((0, -11.6, 0), (1, 2.6, 180)):
            t.prop("puesto_mercado", x + rng.uniform(-1, 1), z, g, 1.0, TINTES["calido"][rng.randrange(3)], forzar=True)
    # La entrada es un arco: sin colisión propia, solo sus dos pilares.
    t.pieza("entrada_mercado", -44.0, -4.5, 270, 1.0, forzar=True, colision=False)
    extra.append({"pos": [-44.0, -10.6], "medio": [5.0, 0.9], "alto": 8.0})
    extra.append({"pos": [-44.0, 1.6], "medio": [5.0, 0.9], "alto": 8.0})
    # Techo de la calle: losa caminable a 5,5 m sobre columnas, con escalera al este.
    t.plataforma(-92.5, -4.5, 41.5, 5.5, 5.5, "techo")
    t.plataforma(-53.0, -14.5, 1.2, 4.5, 5.5, "escalera", 0.0, "z")
    t.lotes([-146, -60, -40, -16], ["casa_chica", "edificio", "edificio_mediano", "casa_chica"], 15, "calido", hacia(-90, -4.5), margen=2.0)
    t.lotes([-146, 6, -40, 68], ["casa_chica", "edificio", "casa_chica", "edificio_mediano"], 15, "calido", hacia(-90, -4.5), margen=2.0)
    rellenar(t, [-146, -60, -40, 68], ["casa_chica", "casa_chica", "edificio", "tanque_agua"], 40, "calido", hacia(-90, -4.5))
    t.dispersar([-136, -15, -40, 6], ["sacos", "caja_ia", "barril", "carreta", "farol_calle"], 30, "calido")
    t.dispersar([-146, -60, -40, 66], ["sacos", "caja_ia", "barril", "roca", "banca"], 20, "calido")
    # ---------------------------------------------------------------- 4. residencial (torres apiladas + pasarelas)
    torres = []
    for x, z in [(-58, -78), (-58, -126), (-104, -78), (-104, -126), (-70, -168), (-95, -168), (-130, -100), (-48, -205)]:
        tipo = "torre_vivienda_a" if (len(torres) % 2 == 0) else "torre_vivienda_b"
        if t.pieza(tipo, x, z, rng.choice([0, 90, 180, 270]), rng.uniform(0.95, 1.08), rng.choice(TINTES["lila"]), 3.0):
            torres.append((x, z))
    # Pasarelas entre torres vecinas a 10-14 m y escaleras desde el suelo.
    for (ax, az), (bx, bz) in [((-58, -78), (-58, -126)), ((-104, -78), (-104, -126)), ((-58, -126), (-104, -126)), ((-70, -168), (-95, -168))]:
        if (ax, az) in torres and (bx, bz) in torres:
            h = rng.choice([10.0, 12.0, 14.0])
            if abs(ax - bx) < 3:
                t.plataforma(ax, (az + bz) / 2, 1.3, abs(az - bz) / 2 - 6.5, h, "pasarela")
            else:
                t.plataforma((ax + bx) / 2, az, abs(ax - bx) / 2 - 6.5, 1.3, h, "pasarela")
    t.plataforma(-48.7, -102.0, 8.0, 1.2, 0.0, "escalera", 12.0, "x")
    t.lotes([-146, -232, -40, -64], ["casa_chica", "casa_chica", "edificio"], 13, "gris", hacia(-87, -107), margen=2.5, prob=0.7)
    rellenar(t, [-146, -232, -40, -64], ["casa_chica", "casa_chica", "edificio_mediano", "tanque_agua"], 45, "lila", hacia(-87, -107))
    t.dispersar([-146, -232, -40, -64], ["banca", "farol_calle", "barril", "sacos", "roca", "tanque_agua"], 34, "lila")
    # ---------------------------------------------------------------- 5. industrial (el más denso)
    for x, z in [(60, -90), (112, -90), (60, -160), (112, -160), (130, -110), (100, -200)]:
        t.pieza("taller_industrial", x, z, rng.choice([0, 90, 180, 270]), rng.uniform(0.95, 1.1), rng.choice(TINTES["oxido"]), 2.0)
    for x, z in [(76, -72), (126, -76), (72, -116), (104, -146), (74, -192), (124, -180), (96, -110)]:
        t.pieza("chimenea", x, z, 0, rng.uniform(0.9, 1.2), None, 1.5)
    for x, z in [(46, -70), (46, -150), (140, -140), (56, -200)]:
        t.pieza("silo", x, z, rng.uniform(0, 90), rng.uniform(0.85, 1.0), None, 2.0)
    t.lotes([40, -232, 146, -64], ["tanque", "tanque_agua", "casa_chica", "taller_industrial"], 12, "oxido", hacia(87, -131), margen=1.5, prob=0.8)
    rellenar(t, [40, -232, 146, -64], ["tanque", "tanque_agua", "casa_chica", "silo", "tanque"], 60, "oxido", hacia(87, -131), margen=0.8)
    t.dispersar([40, -232, 146, -64], ["pila_tuberias", "barril", "caja_ia", "tanque_agua", "roca"], 70, "oxido")
    # ---------------------------------------------------------------- 6. academia
    t.pieza("academia", 0.0, -152.0, 0, 1.25, forzar=True)
    for x in (-18, -10, 10, 18):
        t.prop("muneco", x, -124.0, 0, 1.0, forzar=True)
    for x in (-22, 22):
        for z in (-136, -126, -116):
            t.prop("farol_calle", x, z, 90 if x < 0 else 270, 1.0, forzar=True)
    for x in (-14, -6, 6, 14):
        t.prop("banca", x, -137.0, 0, 1.0, forzar=True)
    t.lotes([-36, -230, 36, -140], ["casa_chica", "edificio", "edificio_mediano"], 15, "gris", hacia(0, -125), margen=2.5)
    rellenar(t, [-36, -230, 36, -140], ["casa_chica", "edificio", "tanque_agua"], 18, "gris", hacia(0, -125))
    t.dispersar([-36, -230, 36, -112], ["barril", "caja_ia", "roca", "sacos"], 14, "gris")
    # ---------------------------------------------------------------- 7. puerta, muralla y puente
    # La puerta tiene un vano en el medio: colisión solo en los dos cuerpos laterales.
    t.pieza("puerta_aldea", 0.0, PUERTA_Z + 1.0, 0, 1.0, forzar=True, colision=False)
    extra.append({"pos": [-11.0, PUERTA_Z + 1.0], "medio": [6.0, 5.6], "alto": 18.0})
    extra.append({"pos": [11.0, PUERTA_Z + 1.0], "medio": [6.0, 5.6], "alto": 18.0})
    t.lotes([-36, 42, -8, 64], ["casa_chica", "casa_chica", "edificio"], 11, "gris", hacia(0, 52), margen=2.0)
    t.lotes([8, 42, 36, 64], ["casa_chica", "casa_chica", "edificio"], 11, "gris", hacia(0, 52), margen=2.0)
    for z in (46, 54, 62):
        t.prop("farol_calle", -7.0, z, 90, 1.0, forzar=True)
        t.prop("farol_calle", 7.0, z, 270, 1.0, forzar=True)
    rellenar(t, [-36, 40, 36, 66], ["casa_chica", "tanque_agua"], 10, "gris", hacia(0, 52), margen=1.0)
    t.dispersar([-36, 42, 36, 66], ["barril", "caja_ia", "sacos", "carreta"], 14, "gris")
    # Puente sobre el lago (losa caminable a ras del suelo) y embarcadero exterior.
    t.plataforma(0.0, 111.0, 3.4, 40.0, 0.0, "puente")
    for z in range(76, 150, 9):
        t.prop("farol_calle", -3.6, float(z), 90, 1.0, forzar=True, reservas=False)
        t.prop("farol_calle", 3.6, float(z) + 4.5, 270, 1.0, forzar=True, reservas=False)
    t.dispersar([-22, 153, 22, 172], ["caja_ia", "barril", "sacos", "carreta", "roca"], 12, "gris")
    # ---------------------------------------------------------------- 8. torre: sede del líder
    # Terraza de acceso al pie del rostro (2,5 m) con escalinata desde la avenida y dos torres de guardia.
    t.h.setdefault("torreta", [6.0, 6.0, 21.0])
    t.plataforma(0.0, -59.0, 12.0, 3.6, 2.5, "techo")
    t.plataforma(0.0, -51.0, 4.0, 4.4, 0.0, "escalera", 2.5, "z")
    for x in (-17.0, 17.0):
        t.pieza("torreta", x, -58.0, 0, 0.8, forzar=True)
    # ---------------------------------------------------------------- 7. puerta: torres de guardia junto al vano
    for x in (-24.0, 24.0):
        t.pieza("torreta", x, PUERTA_Z - 6.0, 0, 0.9, forzar=True)
    # ---------------------------------------------------------------- torre: explanada con faroles
    for x, z in [(-20, -62), (20, -62), (-26, -76), (26, -76)]:
        t.prop("farol_calle", x, z, 0, 1.2, forzar=True)
    rellenar(t, [-38, -112, 38, -33], ["casa_chica", "edificio", "tanque_agua"], 14, "lila", hacia(0, -80))
    t.dispersar([-38, -60, 38, -33], ["barril", "caja_ia", "pila_tuberias", "banca"], 12, "lila")

    # ---------------------------------------------------------------- puntos de misión y aldeanos
    puntos = []
    for d in DISTRITOS:
        x0, z0, x1, z1 = d["rect"]
        for tipo, n in (("mision", 1), ("aldeano", 2)):
            hechos = 0
            for _ in range(400):
                if hechos >= n:
                    break
                x = rng.uniform(x0 + 6, x1 - 6)
                z = rng.uniform(z0 + 6, z1 - 6)
                if t.libre(x, z, 1.0, 1.0, 1.5, reservas=False):
                    t.ocupar(x, z, 1.0, 1.0)
                    puntos.append({"tipo": tipo, "distrito": d["id"], "pos": [round(x, 1), round(z, 1)],
                                   "texto": ("Misión: " if tipo == "mision" else "Aldeano: ") + d["nombre"]})
                    hechos += 1

    # ---------------------------------------------------------------- muralla (solo visual: el borde caminable es el círculo)
    muro = []
    n = int(2 * math.pi * RADIO_MURO / 12.0)
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        x = CENTRO[0] + math.cos(a) * RADIO_MURO
        z = CENTRO[1] + math.sin(a) * RADIO_MURO
        if abs(x) < 20 and z > 0:       # hueco de la puerta
            continue
        if abs(z + 27) < 7 and x > 0:   # salida del canal al lago
            continue
        # El exterior (-Y de Blender = +Z de Godot con giro 0) mira hacia afuera.
        giro = math.degrees(math.atan2(math.cos(a), math.sin(a)))
        muro.append({"pos": [round(x, 2), round(z, 2)], "giro": round(giro, 2), "torre": k % 7 == 0})

    tz["piezas"] = t.piezas
    tz["props"] = t.props
    tz["plataformas"] = t.plataformas
    tz["puentes"] = puentes
    tz["canal"] = canal
    tz["muralla"] = muro
    tz["obstaculos_extra"] = extra
    tz["arcos"] = [{"pos": [27.0, 5.0], "giro": 90}, {"pos": [-27.0, -4.5], "giro": 90}, {"pos": [0.0, 26.5], "giro": 0},
                   {"pos": [0.0, 48.0], "giro": 0}, {"pos": [70.0, 5.0], "giro": 90}, {"pos": [-70.0, -4.5], "giro": 90}]
    tubos = [{"pos": [-22.0, -21.6], "altura": 0.6, "giro": 0}, {"pos": [22.5, -21.6], "altura": 0.6, "giro": 0}]
    # Distrito industrial: tuberías elevadas sobre sus dos calles (tramos de 12 m, a dos alturas).
    for z in range(-190, -64, 12):
        tubos.append({"pos": [87.0, float(z)], "altura": 6.2, "giro": 90})
        if z % 24 == 2:
            tubos.append({"pos": [85.2, float(z) + 6.0], "altura": 4.6, "giro": 90})
    for x in range(46, 146, 12):
        tubos.append({"pos": [float(x), -131.0], "altura": 5.4, "giro": 0})
    tz["tubos"] = tubos
    tz["horizonte"] = {"cantidad": 40, "radio_min": 250.0, "radio_max": 330.0, "escala_min": 1.6, "escala_max": 3.2}
    tz["cables"] = 40
    esc["aldea"] = {"_nota": "Generado por tools/aldea.py. Isla circular en el lago: se camina dentro de radio_caminable y en zonas_extra.",
                    "centro": list(CENTRO), "radio_muro": RADIO_MURO, "radio_caminable": RADIO_CAMINABLE,
                    "zonas_extra": [[-5.5, 60.0, 5.5, 80.0], [-3.4, 70.0, 3.4, 152.0], [-24.0, 150.0, 24.0, 174.0]],
                    "lago_radio": 600.0, "distritos": DISTRITOS, "puntos": puntos}
    esc["limite_juego"] = 400.0
    esc["charcos_aleatorios"] = 170
    json.dump(esc, open(RUTA, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    cuenta = {}
    for p in t.piezas + t.props:
        cuenta[p["tipo"]] = cuenta.get(p["tipo"], 0) + 1
    print("piezas", len(t.piezas), "objetos", len(t.props), "plataformas", len(t.plataformas), "puntos", len(puntos), "muralla", len(muro))
    print(cuenta)


if __name__ == "__main__":
    main()
