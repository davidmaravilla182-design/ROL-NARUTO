"""Kit modular de la aldea de la lluvia, modelado por código en Blender y exportado a GLB.

Uso: /tmp/claude-0/venvbpy/v/bin/python -I tools/blender/kit.py [pieza ...]
Ejes (Blender): Z arriba, frente hacia -Y (en Godot queda hacia +Z). Unidades en metros.
"""
import math
import os
import random
import sys
import time

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import comun  # noqa: E402
import geo  # noqa: E402
from geo import caja, cilindro, tubo, unir  # noqa: E402


def polar(r, a, z):
    return (math.cos(a) * r, math.sin(a) * r, z)


def barandal_circular(r, z, postes=16, alto=1.0, mat="tuberia"):
    objs = []
    pts = [polar(r, 2 * math.pi * k / 32, z + alto) for k in range(33)]
    objs.append(tubo(pts, 0.035, mat, seg=5, radio_codo=0.01))
    pts2 = [polar(r, 2 * math.pi * k / 32, z + alto * 0.5) for k in range(33)]
    objs.append(tubo(pts2, 0.028, mat, seg=5, radio_codo=0.01))
    for k in range(postes):
        a = 2 * math.pi * k / postes
        objs.append(cilindro(0.035, alto, mat, pos=polar(r, a, z), seg=5, tapas=False))
    return objs


def agujas(objs, rng, centro, radio, n, alto_min, alto_max, z):
    """Agujas góticas: conos finos con anillos y pequeñas cruces."""
    for k in range(n):
        a = 2 * math.pi * k / n + rng.uniform(-0.1, 0.1)
        p = polar(radio, a, z) if radio > 0 else (0, 0, z)
        p = (p[0] + centro[0], p[1] + centro[1], p[2])
        h = rng.uniform(alto_min, alto_max)
        objs.append(cilindro(0.16, h * 0.35, "lamina", pos=p, seg=6, r2=0.12))
        objs.append(cilindro(0.12, h * 0.65, "lamina", pos=(p[0], p[1], p[2] + h * 0.35), seg=6, r2=0.0))
        objs.append(cilindro(0.22, 0.12, "lamina", pos=(p[0], p[1], p[2] + h * 0.33), seg=6))
        if rng.random() < 0.4:
            objs.append(caja((0.7, 0.05, 0.05), "lamina", pos=(p[0], p[1], p[2] + h * 0.6)))


# ------------------------------------------------------------------ piezas

def silo(rng):
    """Torre cilíndrica: cuerpo de concreto, sección violeta de lámina, balcones con barandal,
    ventanas en rendija, tuberías verticales y corona con agujas."""
    r, h = 4.0, 18.0
    o = [cilindro(r, h, "concreto", seg=28, tapas=False)]
    o.append(cilindro(r * 1.03, h * 0.32, "lamina", pos=(0, 0, h * 0.58), seg=28, tapas=False))
    for z in (h * 0.3, h * 0.9):
        o.append(cilindro(r + 0.9, 0.3, "suelo", pos=(0, 0, z), seg=28, bisel=0.04))
        o += barandal_circular(r + 0.8, z + 0.3)
    for fila, z in enumerate((3.0, 7.5, 12.0, 15.5)):
        n = 10
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * (fila % 2)) / n
            encendida = rng.random() < 0.55
            alto = 1.6 if fila != 2 else 2.4
            o.append(caja((0.12, 0.42, alto), "ventana" if encendida else "oscuro", pos=polar(r * 1.03 + 0.03, a, z), rot=(0, 0, a)))
            o.append(caja((0.1, 0.6, 0.12), "lamina", pos=polar(r * 1.03 + 0.06, a, z - alto / 2 - 0.05), rot=(0, 0, a)))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        rr = r + 0.55
        z1 = rng.uniform(h * 0.55, h * 0.85)
        o.append(tubo([polar(rr, a, -0.5), polar(rr, a, z1), polar(r - 0.3, a, z1)], 0.32, "tuberia", bridas=(1.0, 4.0, 8.0, -0.8)))
    # Corona
    o.append(cilindro(r + 0.25, 1.0, "lamina", pos=(0, 0, h), seg=28, bisel=0.05))
    o.append(cilindro(r * 0.85, 3.5, "techo", pos=(0, 0, h + 1.0), seg=20, r2=r * 0.25))
    agujas(o, rng, (0, 0), r + 0.1, 8, 3.0, 5.5, h + 1.0)
    agujas(o, rng, (0, 0), 0, 1, 8.0, 9.0, h + 4.4)
    return unir(o, "silo")


def edificio(rng):
    """Bloque de concreto de 3 pisos con ventanas, toldos de lámina, faroles, aires acondicionados y tuberías."""
    an, fo, al = 8.0, 7.0, 10.0
    o = [caja((an, fo, al), "concreto", pos=(0, 0, al / 2), bisel=0.06)]
    for piso in range(3):
        z = 0.4 + piso * 3.3
        o.append(caja((an + 0.25, fo + 0.25, 0.22), "lamina", pos=(0, 0, z + 3.0), bisel=0.03))
        for lado, (nx, ny, largo) in enumerate(((0, -1, an), (1, 0, fo), (-1, 0, fo))):
            n = int(largo // 2.4)
            for k in range(n):
                t = (k + 0.5) / n - 0.5
                if piso == 0 and lado == 0 and abs(t) < 0.15:
                    continue   # puerta
                encendida = rng.random() < 0.5
                ancho_v = rng.choice((1.2, 1.6, 2.0))
                if ny != 0:
                    p = (t * largo, ny * (fo / 2 + 0.01), z + 1.6)
                    tam = (ancho_v, 0.12, 0.85)
                    marco = (ancho_v + 0.2, 0.18, 0.12)
                else:
                    p = (nx * (an / 2 + 0.01), t * largo, z + 1.6)
                    tam = (0.12, ancho_v, 0.85)
                    marco = (0.18, ancho_v + 0.2, 0.12)
                o.append(caja(tam, "ventana" if encendida else "oscuro", pos=p))
                o.append(caja(marco, "lamina", pos=(p[0], p[1], p[2] - 0.48)))
                if rng.random() < 0.3 and piso > 0:
                    # aire acondicionado bajo la ventana
                    if ny != 0:
                        o.append(caja((0.9, 0.6, 0.6), "lamina", pos=(p[0] + 0.5, p[1] - 0.3, p[2] - 1.2), bisel=0.03))
                        o.append(cilindro(0.22, 0.04, "oscuro", pos=(p[0] + 0.5, p[1] - 0.61, p[2] - 1.2), rot=(math.pi / 2, 0, 0), seg=10))
    # Puerta, toldo y farol en el frente (-Y)
    o.append(caja((1.4, 0.2, 2.3), "oscuro", pos=(0, -fo / 2, 1.15)))
    o.append(caja((1.7, 0.1, 2.5), "lamina", pos=(0, -fo / 2 - 0.02, 1.25)))
    toldo = caja((3.6, 1.8, 0.06), "techo", pos=(0, -fo / 2 - 0.85, 2.95), rot=(math.radians(-14), 0, 0), tile=3.0)
    o.append(toldo)
    for sx in (-1.6, 1.6):
        o.append(tubo([(sx, -fo / 2, 2.5), (sx, -fo / 2 - 1.6, 2.75)], 0.04, "lamina", seg=6))
    for sx in (-1.3, 1.3):
        o += farol_pared((sx, -fo / 2, 2.2))
    # Toldos sobre ventanas de pisos altos
    for k in range(2):
        x = (-0.25 + 0.5 * k) * an
        o.append(caja((2.2, 1.1, 0.05), "techo", pos=(x, -fo / 2 - 0.5, 0.4 + 3.3 + 2.35), rot=(math.radians(-18), 0, 0)))
    # Tubería por la esquina que entra en la pared
    o.append(tubo([(an / 2 + 0.35, -fo / 2 + 0.6, 0), (an / 2 + 0.35, -fo / 2 + 0.6, al - 1.5), (an / 2 + 0.35, fo / 2 - 1.0, al - 1.5),
                   (an / 2 - 0.2, fo / 2 - 1.0, al - 1.5)], 0.22, "tuberia", bridas=(0.8, 3.5, 6.5)))
    o.append(tubo([(-an / 2 - 0.25, -1.0, 0), (-an / 2 - 0.25, -1.0, al + 0.6)], 0.12, "tuberia", bridas=(2.0, 5.0)))
    # Azotea: pretil, respiraderos, antena y una aguja
    for (sx, sy, tx, ty) in ((0, -fo / 2, an, 0.25), (0, fo / 2, an, 0.25), (-an / 2, 0, 0.25, fo), (an / 2, 0, 0.25, fo)):
        o.append(caja((tx, ty, 0.8), "concreto", pos=(sx, sy, al + 0.4)))
    o.append(cilindro(0.5, 0.9, "lamina", pos=(1.5, 1.0, al), seg=10))
    o.append(cilindro(0.65, 0.12, "lamina", pos=(1.5, 1.0, al + 0.95), seg=10))
    o.append(cilindro(0.05, 4.0, "lamina", pos=(-2.0, 1.5, al), seg=5))
    o.append(caja((1.2, 0.04, 0.04), "lamina", pos=(-2.0, 1.5, al + 3.2)))
    agujas(o, rng, (2.5, -2.0), 0, 1, 4.0, 5.0, al)
    return unir(o, "edificio")


def farol_pared(p):
    """Farol de pared: brazo, jaula de lámina y vidrio luminoso. p = punto en la pared (frente -Y)."""
    x, y, z = p
    o = [tubo([(x, y, z), (x, y - 0.35, z), (x, y - 0.35, z - 0.15)], 0.03, "lamina", seg=6, radio_codo=0.08)]
    o.append(cilindro(0.13, 0.32, "luz", pos=(x, y - 0.35, z - 0.5), seg=8))
    o.append(cilindro(0.18, 0.08, "lamina", pos=(x, y - 0.35, z - 0.18), seg=8, r2=0.1))
    o.append(cilindro(0.16, 0.05, "lamina", pos=(x, y - 0.35, z - 0.53), seg=8))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        o.append(cilindro(0.012, 0.34, "lamina", pos=(x + math.cos(a) * 0.14, y - 0.35 + math.sin(a) * 0.14, z - 0.52), seg=4))
    return o


def farol():
    return unir(farol_pared((0, 0, 0)), "farol")


def barandal():
    """Tramo de barandal de 2 m a lo largo de X (de x=0 a x=2)."""
    o = [tubo([(0, 0, 1.05), (2, 0, 1.05)], 0.035, "tuberia", seg=8),
         tubo([(0, 0, 0.55), (2, 0, 0.55)], 0.028, "tuberia", seg=8)]
    for x in (0.0, 2.0):
        o.append(cilindro(0.04, 1.08, "tuberia", pos=(x, 0, 0), seg=8))
    return unir(o, "barandal")


def pasarela():
    """Pasarela de celosía de 12 m a lo largo de X, centrada; piso de rejilla, barandales y lámparas."""
    largo, ancho = 12.0, 2.2
    o = [caja((largo, ancho, 0.12), "rejilla", pos=(0, 0, 0), tile=1.5)]
    for s in (-1, 1):
        y = s * (ancho / 2 + 0.1)
        o.append(caja((largo, 0.18, 0.22), "lamina", pos=(0, y, -0.15), bisel=0.02))
        o.append(caja((largo, 0.14, 0.14), "lamina", pos=(0, y, -1.3), bisel=0.02))
        n = 8
        for k in range(n + 1):
            x = -largo / 2 + largo * k / n
            o.append(caja((0.12, 0.12, 1.15), "lamina", pos=(x, y, -0.72)))
            if k < n:
                x2 = x + largo / n
                dx, dz = x2 - x, 1.15
                ang = math.atan2(dz, dx) * (1 if k % 2 == 0 else -1)
                o.append(caja((math.hypot(dx, dz), 0.08, 0.08), "lamina", pos=((x + x2) / 2, y, -0.72), rot=(0, ang, 0)))
        o.append(tubo([(-largo / 2, y * 0.95, 1.05), (largo / 2, y * 0.95, 1.05)], 0.035, "tuberia", seg=8))
        o.append(tubo([(-largo / 2, y * 0.95, 0.55), (largo / 2, y * 0.95, 0.55)], 0.028, "tuberia", seg=8))
        for k in range(7):
            x = -largo / 2 + largo * k / 6
            o.append(cilindro(0.035, 1.08, "tuberia", pos=(x, y * 0.95, 0.06), seg=6))
        for k in range(3):
            x = -largo / 2 + largo * (k + 0.5) / 3
            o.append(cilindro(0.09, 0.18, "luz", pos=(x, y * 0.95, 1.12), seg=8))
    for k in range(9):
        x = -largo / 2 + largo * k / 8
        o.append(caja((0.1, ancho + 0.3, 0.1), "lamina", pos=(x, 0, -1.3)))
    return unir(o, "pasarela")


def tubo_largo():
    """Tubería gruesa de 12 m a lo largo de X con bridas cada 3 m (altura 0 = eje)."""
    return tubo([(-6, 0, 0), (6, 0, 0)], 0.55, "tuberia", seg=16, bridas=(0.4, 3.0, 6.0, 9.0, -0.4))


def tubo_arco():
    """Tubería en U invertida (sube, cruza y baja) como las de las referencias. Ancho 8 m, alto 5 m."""
    return tubo([(-4, 0, 0), (-4, 0, 5), (4, 0, 5), (4, 0, 0)], 0.45, "tuberia", seg=16, radio_codo=1.2,
                bridas=(0.5, 2.5, 6.0, 9.0, 12.5, -0.5))


def tanque(rng):
    """Tanque de agua elevado sobre cuatro patas con escalera."""
    o = [cilindro(1.6, 2.6, "lamina", pos=(0, 0, 3.2), seg=18, bisel=0.03)]
    o.append(cilindro(1.7, 0.6, "techo", pos=(0, 0, 5.8), seg=18, r2=0.2))
    for z in (3.6, 4.6, 5.5):
        o.append(cilindro(1.63, 0.08, "lamina", pos=(0, 0, z), seg=18))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        p = polar(1.3, a, 0)
        o.append(caja((0.14, 0.14, 3.3), "lamina", pos=(p[0], p[1], 1.65)))
    for k in range(4):
        a1 = math.pi / 4 + k * math.pi / 2
        a2 = a1 + math.pi / 2
        p1 = polar(1.3, a1, 0.5)
        p2 = polar(1.3, a2, 2.8)
        o.append(tubo([p1, p2], 0.04, "lamina", seg=5))
    # Escalera
    o.append(caja((0.06, 0.06, 5.6), "lamina", pos=(1.75, -0.25, 2.8)))
    o.append(caja((0.06, 0.06, 5.6), "lamina", pos=(1.75, 0.25, 2.8)))
    for k in range(14):
        o.append(caja((0.05, 0.5, 0.05), "lamina", pos=(1.75, 0, 0.3 + k * 0.38)))
    return unir(o, "tanque")


def muro_canal():
    """Muro de canal de 8 m (X) que baja desde el suelo (z=0) hasta el agua (z=-3), con remate,
    barandal y un desagüe por donde cae agua. El desagüe está en (2.0, -0.55, -1.4)."""
    o = [caja((8, 0.8, 3.2), "concreto", pos=(0, 0.4, -1.6), bisel=0.04)]
    o.append(caja((8, 1.0, 0.25), "lamina", pos=(0, 0.45, 0.02), bisel=0.03))
    o.append(tubo([(2.0, 0.2, -1.4), (2.0, -0.55, -1.4)], 0.32, "tuberia", seg=14, bridas=(0.15, -0.1)))
    o.append(cilindro(0.26, 0.05, "oscuro", pos=(2.0, -0.58, -1.4), rot=(math.pi / 2, 0, 0), seg=14))
    for x in (-4.0, -2.0, 0.0, 2.0):
        o.append(cilindro(0.04, 1.08, "tuberia", pos=(x, 0.1, 0.1), seg=6))
    o.append(tubo([(-4, 0.1, 1.15), (4, 0.1, 1.15)], 0.035, "tuberia", seg=8))
    o.append(tubo([(-4, 0.1, 0.65), (4, 0.1, 0.65)], 0.028, "tuberia", seg=8))
    return unir(o, "muro_canal")


def toldo():
    """Toldo suelto de lámina con soportes (para balcones y pasillos)."""
    o = [caja((3.0, 1.6, 0.05), "techo", pos=(0, -0.75, 0), rot=(math.radians(-16), 0, 0))]
    for sx in (-1.4, 1.4):
        o.append(tubo([(sx, 0, -0.4), (sx, -1.45, -0.05)], 0.035, "lamina", seg=6))
    return unir(o, "toldo")


def silo_lejano(rng):
    """Silueta barata de torre para el horizonte (pocos triángulos, se ve entre la niebla)."""
    r, h = 4.0, 22.0
    o = [cilindro(r, h, "concreto", seg=10, tapas=False)]
    o.append(cilindro(r * 1.04, h * 0.3, "lamina", pos=(0, 0, h * 0.55), seg=10, tapas=False))
    o.append(cilindro(r + 0.6, 0.4, "lamina", pos=(0, 0, h * 0.85), seg=10))
    for k, z in enumerate((5.0, 10.0, 15.0)):
        for j in range(5):
            a = 2 * math.pi * (j + 0.5 * (k % 2)) / 5
            o.append(caja((0.1, 0.5, 1.6), "ventana" if rng.random() < 0.6 else "oscuro", pos=polar(r * 1.04 + 0.03, a, z), rot=(0, 0, a)))
    o.append(cilindro(r * 0.85, 4.0, "techo", pos=(0, 0, h), seg=10, r2=r * 0.2))
    for k in range(5):
        a = 2 * math.pi * k / 5
        p = polar(r, a, h)
        o.append(cilindro(0.18, rng.uniform(3, 6), "lamina", pos=p, seg=4, r2=0.0, tapas=False))
    o.append(cilindro(0.3, 11.0, "lamina", pos=(0, 0, h + 3.5), seg=4, r2=0.0, tapas=False))
    return unir(o, "silo_lejano")


def bloque_lejano(rng):
    """Bloque de edificios lejano con agujas y ventanas encendidas."""
    o = [caja((10, 10, 14), "concreto", pos=(0, 0, 7))]
    o.append(caja((7, 7, 6), "lamina", pos=(1, -1, 17)))
    for z in (3.0, 6.5, 10.0):
        for k in range(4):
            x = -3.75 + k * 2.5
            if rng.random() < 0.6:
                o.append(caja((1.4, 0.1, 0.9), "ventana", pos=(x, -5.02, z)))
            if rng.random() < 0.5:
                o.append(caja((0.1, 1.4, 0.9), "ventana", pos=(5.02, x, z)))
    for k in range(3):
        o.append(cilindro(0.2, rng.uniform(4, 8), "lamina", pos=(rng.uniform(-3, 3), rng.uniform(-3, 3), 20), seg=4, r2=0.0, tapas=False))
    return unir(o, "bloque_lejano")


def cara(o, rng, r, z, alto, escala=1.0, boca_abierta=True):
    """Rostro monumental en el frente (-Y) de un cilindro de radio r, centrado a altura z."""
    s = escala
    y = -r
    # Placa del rostro que sobresale del cilindro (piedra clara).
    o.append(cilindro(r * 0.62, alto, "piedra", pos=(0, y * 0.55, z - alto / 2), seg=16, tapas=True))
    # Banda de la frente con placa metálica y el símbolo de la aldea (4 líneas verticales).
    o.append(cilindro(r + 0.35, 3.2 * s, "lamina", pos=(0, 0, z + alto * 0.28), seg=28, tapas=False))
    o.append(caja((7.5 * s, 0.6, 3.6 * s), "lamina", pos=(0, y - 0.45, z + alto * 0.28 + 1.6 * s), bisel=0.15))
    for k in range(4):
        o.append(caja((0.32 * s, 0.4, 2.4 * s), "oscuro", pos=((-1.5 + k) * 1.1 * s, y - 0.8, z + alto * 0.28 + 1.6 * s)))
    # Ceño, ojos con anillos concéntricos, nariz y pómulos.
    zo = z + alto * 0.1
    o.append(caja((9.5 * s, 1.6, 1.0 * s), "piedra", pos=(0, y - 0.6, zo + 1.6 * s), rot=(0.25, 0, 0), bisel=0.2))
    for lado in (-1, 1):
        cx = lado * 2.6 * s
        o.append(cilindro(1.35 * s, 0.6, "piedra", pos=(cx, y - 0.4, zo), rot=(math.pi / 2, 0, 0), seg=18))
        for k, rr in enumerate((1.15, 0.85, 0.55, 0.25)):
            o.append(cilindro(rr * s, 0.62 + k * 0.05, "oscuro" if k % 2 == 0 else "lamina", pos=(cx, y - 0.45, zo), rot=(math.pi / 2, 0, 0), seg=18))
    o.append(caja((1.6 * s, 2.0, 4.0 * s), "piedra", pos=(0, y - 1.0, zo - 2.6 * s), rot=(-0.25, 0, 0), bisel=0.3))
    # Boca (hueco oscuro) y lengua que sale y cuelga (para sentarse encima, como en la referencia).
    zb = z - alto * 0.22
    if boca_abierta:
        o.append(cilindro(2.2 * s, 1.2, "oscuro", pos=(0, y - 0.3, zb), rot=(math.pi / 2, 0, 0), seg=18))
        o.append(caja((5.0 * s, 1.4, 0.8 * s), "piedra", pos=(0, y - 0.6, zb + 2.3 * s), bisel=0.2))
        lengua = tubo([(0, y + 0.5, zb - 0.4 * s), (0, y - 4 * s, zb - 1.2 * s), (0, y - 9 * s, zb - 1.6 * s), (0, y - 13 * s, zb - 0.4 * s)],
                      1.0 * s, "lengua", seg=14, radio_codo=4 * s)
        o.append(lengua)
    else:
        o.append(caja((4.0 * s, 1.2, 0.5 * s), "oscuro", pos=(0, y - 0.5, zb)))
    # Pómulos y mentón
    for lado in (-1, 1):
        o.append(caja((2.0 * s, 1.2, 3.0 * s), "piedra", pos=(lado * 3.6 * s, y - 0.3, zo - 2.8 * s), rot=(0, 0, lado * 0.25), bisel=0.3))
    o.append(caja((4.6 * s, 1.4, 2.0 * s), "piedra", pos=(0, y - 0.5, z - alto * 0.42), bisel=0.3))


def torre_cabeza(rng):
    """Torre monumental con rostros (el hito de la aldea): fuste de concreto con anillos, tuberías
    granate subiendo por la fachada, ventanas, una cabeza con banda en la frente y boca abierta con lengua,
    caras secundarias a los lados y corona de agujas. ~70 m de alto."""
    r = 9.0
    o = [cilindro(r, 46.0, "concreto", seg=32, tapas=False)]
    o.append(cilindro(r * 1.12, 6.0, "lamina", pos=(0, 0, 0), seg=32, tapas=False))
    for z in (8.0, 18.0, 30.0, 44.0):
        o.append(cilindro(r + 1.2, 0.8, "lamina", pos=(0, 0, z), seg=32, bisel=0.1))
    for fila, z in enumerate((11.0, 14.5, 21.5, 25.0, 34.0, 38.0)):
        n = 18
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * (fila % 2)) / n
            if abs(math.sin(a) + 1) < 0.35:   # no tapar el frente donde cae la lengua
                continue
            if rng.random() < 0.6:
                o.append(caja((0.15, 0.8, 1.8), "ventana" if rng.random() < 0.6 else "oscuro", pos=polar(r + 0.05, a, z), rot=(0, 0, a)))
    # Tuberías que suben por la fachada y se doblan hacia dentro
    for k in range(7):
        a = -math.pi / 2 + (k - 3) * 0.45 + rng.uniform(-0.05, 0.05)
        rr = r + 0.9
        z1 = rng.uniform(30, 50)
        o.append(tubo([polar(rr, a, -1), polar(rr, a, z1), polar(r - 0.5, a, z1)], rng.uniform(0.45, 0.8), "tuberia", seg=12, bridas=(4.0, 12.0, 22.0)))
    # Cabeza: alta y con rasgos grandes para que se lea a distancia entre la niebla.
    zc = 46.0
    o.append(cilindro(r * 1.08, 26.0, "piedra", pos=(0, 0, zc), seg=32, tapas=False))
    cara(o, rng, r * 1.08, zc + 13.0, 26.0, 1.75, True)
    # Caras secundarias más pequeñas a los lados (giradas), como en la referencia
    for lado in (-1, 1):
        sub = []
        cara(sub, rng, r * 1.02, 27.0, 13.0, 0.95, False)
        ob = unir(sub, "cara_lateral")
        ob.rotation_euler = (0, 0, lado * math.pi / 2)
        geo._aplicar(ob)
        o.append(ob)
    # Corona
    o.append(cilindro(r * 1.14, 1.5, "lamina", pos=(0, 0, zc + 26.0), seg=32, bisel=0.1))
    o.append(cilindro(r * 0.9, 6.0, "techo", pos=(0, 0, zc + 27.5), seg=24, r2=r * 0.3))
    agujas(o, rng, (0, 0), r * 1.05, 12, 5.0, 10.0, zc + 27.5)
    agujas(o, rng, (0, 0), 0, 1, 16.0, 18.0, zc + 33.0)
    return unir(o, "torre_cabeza")


# ------------------------------------------------------------------ piezas a nivel del suelo (plaza)
def caja_madera(rng):
    """Caja de madera de 1,1 m con tablas, travesaños en cruz y esquineros de metal."""
    t = 1.1
    o = [caja((t, t, t), "madera", pos=(0, 0, t / 2), bisel=0.02)]
    for cara_y in (-1, 1):
        y = cara_y * (t / 2 + 0.012)
        for z in (0.08, t - 0.08):
            o.append(caja((t, 0.03, 0.1), "madera", pos=(0, y, z)))
        d = math.hypot(t, t - 0.2)
        o.append(caja((d, 0.03, 0.09), "madera", pos=(0, y, t / 2), rot=(0, math.atan2(t - 0.2, t), 0)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(caja((0.06, 0.06, t + 0.01), "lamina", pos=(sx * t / 2, sy * t / 2, t / 2)))
    return unir(o, "caja_madera")


def caja_metal(rng):
    """Contenedor de lámina de 2,2 × 1,2 × 1,3 m con nervios y una puerta con cerrojo."""
    o = [caja((2.2, 1.2, 1.3), "lamina", pos=(0, 0, 0.65), bisel=0.03)]
    for x in (-0.8, -0.4, 0.0, 0.4, 0.8):
        for y in (-0.61, 0.61):
            o.append(caja((0.05, 0.03, 1.2), "lamina", pos=(x, y, 0.65)))
    o.append(caja((0.03, 1.0, 1.1), "oscuro", pos=(1.11, 0, 0.62)))
    o.append(cilindro(0.025, 1.0, "tuberia", pos=(1.14, 0.2, 0.12), seg=6))
    return unir(o, "caja_metal")


def barril(rng):
    """Barril de metal de 0,6 m de diámetro con aros y tapa con boca."""
    o = [cilindro(0.3, 0.9, "tuberia", seg=14, bisel=0.02)]
    for z in (0.12, 0.45, 0.78):
        o.append(cilindro(0.315, 0.04, "lamina", pos=(0, 0, z), seg=14))
    o.append(cilindro(0.05, 0.03, "oscuro", pos=(0.14, 0, 0.9), seg=8))
    return unir(o, "barril")


def rejilla_suelo(rng):
    """Rejilla de desagüe de 2 × 2 m casi a ras del suelo: marco, barras y fondo oscuro."""
    o = [caja((2.0, 2.0, 0.02), "oscuro", pos=(0, 0, 0.005))]
    for s in (-1, 1):
        o.append(caja((2.0, 0.08, 0.04), "lamina", pos=(0, s * 0.96, 0.02)))
        o.append(caja((0.08, 2.0, 0.04), "lamina", pos=(s * 0.96, 0, 0.02)))
    for k in range(9):
        o.append(caja((0.04, 1.84, 0.03), "lamina", pos=(-0.8 + k * 0.2, 0, 0.018)))
    return unir(o, "rejilla_suelo")


def tubo_suelo(rng):
    """Tubería de 6 m tendida a 0,35 m del suelo sobre soportes, con bridas, codo que entra al suelo y válvula."""
    o = [tubo([(-3.0, 0, 0.35), (2.3, 0, 0.35), (3.0, 0, 0.35), (3.0, 0, -0.3)], 0.22, "tuberia", seg=12, radio_codo=0.4, bridas=(1.5, 3.5))]
    for x in (-2.2, 0.0, 2.0):
        o.append(caja((0.12, 0.6, 0.14), "lamina", pos=(x, 0, 0.07)))
        o.append(caja((0.12, 0.08, 0.36), "lamina", pos=(x, 0.26, 0.18)))
        o.append(caja((0.12, 0.08, 0.36), "lamina", pos=(x, -0.26, 0.18)))
    o.append(cilindro(0.05, 0.35, "tuberia", pos=(-1.0, 0, 0.55), seg=8))
    o.append(cilindro(0.18, 0.04, "lamina", pos=(-1.0, 0, 0.9), seg=12))
    return unir(o, "tubo_suelo")


def muneco(rng):
    """Muñeco de práctica: poste de madera, travesaño, torso de paja atado con cuerdas, cabeza y diana.
    Se exporta en dos partes: la base (fija) y el cuerpo (que se sacude con los golpes), con el pivote en el suelo."""
    o = [cilindro(0.34, 0.14, "madera", seg=10, bisel=0.02)]
    for k in range(3):
        a = 2 * math.pi * k / 3
        o.append(caja((0.5, 0.09, 0.09), "madera", pos=polar(0.32, a, 0.12), rot=(0, 0.35, a), bisel=0.01))
    return unir(o, "muneco_base")


def muneco_cuerpo(rng):
    o = [cilindro(0.12, 1.55, "madera", pos=(0, 0, 0.1), seg=10, r2=0.1, bisel=0.01)]
    o.append(cilindro(0.055, 1.15, "madera", pos=(-0.575, 0, 1.25), rot=(0, math.pi / 2, 0), seg=8))
    for sx in (-0.56, 0.56):
        o.append(cilindro(0.075, 0.18, "paja", pos=(sx, 0, 1.25), rot=(0, math.pi / 2, 0), seg=8))
    # Torso de paja abultado
    o.append(cilindro(0.21, 0.6, "paja", pos=(0, 0, 0.78), seg=12, r2=0.23))
    for z in (0.84, 1.05, 1.3):
        o.append(cilindro(0.235, 0.035, "cuerda", pos=(0, 0, z), seg=12))
    o.append(cilindro(0.23, 0.06, "paja", pos=(0, 0, 1.38), seg=12, r2=0.12))
    # Cabeza de paja con cuerda al cuello
    cab = cilindro(0.16, 0.34, "paja", pos=(0, 0, 1.5), seg=12, r2=0.13)
    o.append(cab)
    o.append(cilindro(0.13, 0.04, "cuerda", pos=(0, 0, 1.5), seg=12))
    # Diana en el pecho (frente -Y)
    for k, (r, mat) in enumerate(((0.11, "diana"), (0.075, "paja"), (0.04, "diana"))):
        o.append(cilindro(r, 0.012, mat, pos=(0, -0.225 - k * 0.004, 1.02), rot=(math.pi / 2, 0, 0), seg=14))
    return unir(o, "muneco_cuerpo")


PIEZAS = {
    "muneco": muneco, "muneco_cuerpo": muneco_cuerpo,
    "torre_cabeza": torre_cabeza,
    "caja_madera": caja_madera, "caja_metal": caja_metal, "barril": barril, "rejilla_suelo": rejilla_suelo, "tubo_suelo": tubo_suelo,
    "silo_lejano": silo_lejano, "bloque_lejano": bloque_lejano,
    "silo": silo, "edificio": edificio, "farol": farol, "barandal": barandal, "pasarela": pasarela,
    "tubo_largo": tubo_largo, "tubo_arco": tubo_arco, "tanque": tanque, "muro_canal": muro_canal, "toldo": toldo,
}


def main():
    os.makedirs(comun.DIR_MOD, exist_ok=True)
    pedidas = [a for a in sys.argv[1:] if a in PIEZAS] or list(PIEZAS)
    for nombre in pedidas:
        t0 = time.time()
        comun.escena_vacia()
        geo.limpiar()
        rng = random.Random(hash(nombre) % 1000)
        fn = PIEZAS[nombre]
        ob = fn(rng) if fn.__code__.co_argcount == 1 else fn()
        tris = geo.exportar(ob, os.path.join(comun.DIR_MOD, nombre + ".glb"))
        print("PIEZA %s: %d triángulos, %.1fs" % (nombre, tris, time.time() - t0), flush=True)
    print("KIT LISTO", flush=True)


if __name__ == "__main__":
    main()
