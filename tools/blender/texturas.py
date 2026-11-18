"""Hornea (bake) las texturas procedurales sin costuras del escenario con Blender/Cycles.

Cada material se construye con nodos de ruido/voronoi 4D evaluados sobre un toro (periódicos en U y V),
se hornean los canales color, rugosidad y altura, y con numpy se genera el mapa de normales.
Salida: assets/texturas/<nombre>_color.png (RGB = albedo sRGB, A = rugosidad) y <nombre>_normal.png.

Uso: /tmp/claude-0/venvbpy/v/bin/python -I tools/blender/texturas.py [nombre ...]
"""
import os
import sys
import time

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import comun  # noqa: E402
from comun import Grafo  # noqa: E402


def L(r, g, b, a=1.0):
    """Color sRGB → lineal (los nodos de Blender trabajan en lineal)."""
    return (r ** 2.2, g ** 2.2, b ** 2.2, a)


def cerca_linea(g, coord, rep, grosor):
    """1 sobre juntas periódicas (rep por unidad), 0 fuera; borde suave."""
    f = g.m("FRACT", g.m("MULTIPLY", coord, rep))
    d = g.m("MINIMUM", f, g.m("SUBTRACT", 1.0, f))
    return g.m("SUBTRACT", 1.0, g.suave(grosor * 0.5, grosor, d))


def puntos(g, rep_u, rep_v, radio):
    """Remaches: 1 dentro de círculos en una rejilla periódica."""
    fu = g.m("SUBTRACT", g.m("FRACT", g.m("MULTIPLY", g.u, rep_u)), 0.5)
    fv = g.m("SUBTRACT", g.m("FRACT", g.m("MULTIPLY", g.v, rep_v)), 0.5)
    d = g.m("SQRT", g.m("ADD", g.m("MULTIPLY", fu, fu), g.m("MULTIPLY", fv, fv)))
    return g.m("SUBTRACT", 1.0, g.suave(radio * 0.6, radio, d))


# ------------------------------------------------------------------ materiales

def concreto(g):
    p, w = g.toro(1.0, 1.0)
    grande = g.ruido(p, w, 2.2, 6, 0.55)
    p2, w2 = g.toro(1.0, 1.0, du=0.37)
    grano = g.ruido(p2, w2, 38, 3, 0.6)
    pv, wv = g.toro(3.2, 0.35)              # rápido en U, lento en V → chorreaduras verticales
    chorro = g.suave(0.47, 0.68, g.ruido(pv, wv, 3.5, 4, 0.6))
    p4, w4 = g.toro(1.0, 1.0, du=0.71)
    manchas = g.suave(0.52, 0.66, g.ruido(p4, w4, 1.6, 3, 0.5))
    juntas = g.m("MAXIMUM", cerca_linea(g, g.v, 3, 0.012), cerca_linea(g, g.u, 2, 0.01))
    agujeros = puntos(g, 6, 6, 0.035)        # agujeros del encofrado
    base = g.rampa(g.m("ADD", grande, g.m("MULTIPLY", grano, 0.25)), [
        (0.3, L(0.30, 0.31, 0.34)), (0.55, L(0.42, 0.43, 0.46)), (0.8, L(0.52, 0.52, 0.54))])
    col = g.mezcla(g.m("MULTIPLY", chorro, 0.85), base, L(0.2, 0.21, 0.24), "MULTIPLY")
    col = g.mezcla(g.m("MULTIPLY", manchas, 0.5), col, L(0.22, 0.24, 0.22), "MIX")
    col = g.mezcla(g.m("MULTIPLY", g.m("MAXIMUM", juntas, agujeros), 0.6), col, L(0.1, 0.1, 0.12), "MIX")
    rug = g.m("SUBTRACT", 0.85, g.m("ADD", g.m("MULTIPLY", chorro, 0.35), g.m("MULTIPLY", manchas, 0.15)))
    alt = g.m("SUBTRACT", g.m("ADD", g.m("MULTIPLY", grano, 0.35), g.m("MULTIPLY", grande, 0.3)),
              g.m("MULTIPLY", g.m("MAXIMUM", juntas, agujeros), 0.6))
    return col, rug, alt


def lamina(g):
    """Paneles de metal pintado gris violáceo con remaches, óxido y chorreaduras."""
    p, w = g.toro(1.0, 1.0)
    grande = g.ruido(p, w, 2.0, 5, 0.5)
    juntas = g.m("MAXIMUM", cerca_linea(g, g.u, 2, 0.008), cerca_linea(g, g.v, 2, 0.008))
    remaches = g.m("MULTIPLY", puntos(g, 24, 24, 0.17),
                   g.m("MAXIMUM", cerca_linea(g, g.u, 2, 0.03), cerca_linea(g, g.v, 2, 0.03)))
    p2, w2 = g.toro(1.0, 1.0, du=0.5)
    oxido = g.suave(0.55, 0.63, g.m("ADD", g.ruido(p2, w2, 2.2, 8, 0.65), g.m("MULTIPLY", juntas, 0.12)))
    pv, wv = g.toro(3.5, 0.4, du=0.2)
    chorro = g.m("MULTIPLY", g.suave(0.5, 0.68, g.ruido(pv, wv, 3.0, 4, 0.6)), 0.7)
    base = g.rampa(grande, [(0.3, L(0.33, 0.32, 0.39)), (0.7, L(0.42, 0.4, 0.47))])
    col = g.mezcla(chorro, base, L(0.38, 0.24, 0.17), "MIX")
    col = g.mezcla(oxido, col, L(0.36, 0.19, 0.1), "MIX")
    col = g.mezcla(g.m("MULTIPLY", juntas, 0.8), col, L(0.08, 0.08, 0.1), "MIX")
    col = g.mezcla(g.m("MULTIPLY", remaches, 0.5), col, L(0.55, 0.53, 0.58), "MIX")
    rug = g.m("ADD", 0.42, g.m("MULTIPLY", oxido, 0.45))
    alt = g.m("ADD", g.m("SUBTRACT", g.m("MULTIPLY", remaches, 0.8), g.m("MULTIPLY", juntas, 0.7)), g.m("MULTIPLY", oxido, 0.25))
    return col, rug, alt


def tuberia(g):
    """Pintura granate brillante con desconchones, óxido y bandas de mantenimiento."""
    p, w = g.toro(1.0, 1.0)
    grande = g.ruido(p, w, 2.5, 5, 0.5)
    p2, w2 = g.toro(1.0, 1.0, du=0.3)
    desconchon = g.suave(0.6, 0.63, g.ruido(p2, w2, 4.0, 8, 0.7))
    p3, w3 = g.toro(1.0, 1.0, dv=0.6)
    oxido = g.suave(0.55, 0.65, g.ruido(p3, w3, 2.5, 6, 0.6))
    banda = cerca_linea(g, g.v, 2, 0.03)
    base = g.rampa(grande, [(0.3, L(0.36, 0.1, 0.13)), (0.75, L(0.47, 0.15, 0.18))])
    col = g.mezcla(oxido, base, L(0.38, 0.2, 0.11))
    col = g.mezcla(desconchon, col, L(0.2, 0.2, 0.22))
    col = g.mezcla(g.m("MULTIPLY", banda, 0.9), col, L(0.22, 0.22, 0.24))
    rug = g.m("ADD", 0.3, g.m("MULTIPLY", g.m("MAXIMUM", oxido, desconchon), 0.5))
    alt = g.m("SUBTRACT", g.m("MULTIPLY", oxido, 0.3), g.m("MULTIPLY", desconchon, 0.4))
    return col, rug, alt


def suelo(g):
    """Placas de metal del suelo con dibujo de rombos, juntas oxidadas y zonas encharcadas."""
    juntas = g.m("MAXIMUM", cerca_linea(g, g.u, 4, 0.006), cerca_linea(g, g.v, 4, 0.006))
    k = 3.14159 * 2 * 12
    a = g.m("SINE", g.m("MULTIPLY", g.m("ADD", g.u, g.v), k))
    b = g.m("SINE", g.m("MULTIPLY", g.m("SUBTRACT", g.u, g.v), k))
    rombos = g.suave(0.55, 0.85, g.m("MULTIPLY", a, b))
    p, w = g.toro(1.0, 1.0)
    grande = g.ruido(p, w, 2.0, 5, 0.5)
    p2, w2 = g.toro(1.0, 1.0, du=0.4)
    charco = g.suave(0.55, 0.65, g.ruido(p2, w2, 1.5, 3, 0.5))
    p3, w3 = g.toro(1.0, 1.0, dv=0.3)
    oxido = g.suave(0.55, 0.66, g.m("ADD", g.ruido(p3, w3, 3.0, 6, 0.6), g.m("MULTIPLY", juntas, 0.3)))
    base = g.rampa(grande, [(0.3, L(0.2, 0.21, 0.24)), (0.75, L(0.3, 0.3, 0.33))])
    col = g.mezcla(g.m("MULTIPLY", rombos, 0.18), base, L(0.36, 0.36, 0.4))
    col = g.mezcla(oxido, col, L(0.3, 0.18, 0.11))
    col = g.mezcla(g.m("MULTIPLY", charco, 0.5), col, L(0.1, 0.11, 0.13))
    col = g.mezcla(g.m("MULTIPLY", juntas, 0.9), col, L(0.05, 0.05, 0.06))
    rug = g.m("SUBTRACT", g.m("ADD", 0.5, g.m("MULTIPLY", oxido, 0.35)), g.m("MULTIPLY", charco, 0.42))
    alt = g.m("SUBTRACT", g.m("MULTIPLY", rombos, 0.15), g.m("MULTIPLY", juntas, 0.9))
    return col, rug, alt


def techo(g):
    """Lámina corrugada violácea de los toldos, con óxido y chorreaduras siguiendo la pendiente (V)."""
    onda = g.m("MULTIPLY", g.m("ADD", g.m("SINE", g.m("MULTIPLY", g.u, 3.14159 * 2 * 14)), 1.0), 0.5)
    pv, wv = g.toro(3.0, 0.4)
    chorro = g.suave(0.48, 0.66, g.ruido(pv, wv, 3.0, 5, 0.6))
    p, w = g.toro(1.0, 1.0)
    oxido = g.suave(0.55, 0.65, g.ruido(p, w, 2.5, 7, 0.65))
    base = g.rampa(onda, [(0.0, L(0.24, 0.18, 0.26)), (1.0, L(0.42, 0.33, 0.44))])
    col = g.mezcla(g.m("MULTIPLY", chorro, 0.7), base, L(0.32, 0.18, 0.12))
    col = g.mezcla(oxido, col, L(0.38, 0.2, 0.1))
    rug = g.m("ADD", 0.38, g.m("MULTIPLY", oxido, 0.5))
    alt = g.m("ADD", g.m("MULTIPLY", onda, 1.0), g.m("MULTIPLY", oxido, 0.15))
    return col, rug, alt


def rejilla(g):
    """Rejilla de desagüe: barras de metal con huecos oscuros."""
    fu = g.m("FRACT", g.m("MULTIPLY", g.u, 10))
    hueco = g.m("MULTIPLY", g.suave(0.12, 0.18, fu), g.suave(0.88, 0.82, fu))
    marco = g.m("MAXIMUM", cerca_linea(g, g.u, 1, 0.06), cerca_linea(g, g.v, 1, 0.06))
    hueco = g.m("MULTIPLY", hueco, g.m("SUBTRACT", 1.0, marco))
    p, w = g.toro(1.0, 1.0)
    oxido = g.suave(0.55, 0.75, g.ruido(p, w, 3.0, 6, 0.6))
    metal = g.mezcla(oxido, L(0.3, 0.3, 0.33), L(0.32, 0.2, 0.12))
    col = g.mezcla(hueco, metal, L(0.02, 0.02, 0.03))
    rug = g.m("ADD", 0.35, g.m("MULTIPLY", oxido, 0.4))
    alt = g.m("SUBTRACT", 1.0, hueco)
    return col, rug, alt


MATERIALES = {
    "concreto": (concreto, 1024, 3.0),
    "lamina": (lamina, 1024, 2.5),
    "tuberia": (tuberia, 512, 2.0),
    "suelo": (suelo, 1024, 3.5),
    "techo": (techo, 512, 4.0),
    "rejilla": (rejilla, 256, 6.0),
}


# ------------------------------------------------------------------ horneado y guardado

def a_srgb(x):
    x = np.clip(x, 0.0, 1.0)
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(x, 1 / 2.4) - 0.055)


def normales(alt, fuerza):
    """Mapa de normales (convención OpenGL, Y+) desde la altura, con bordes periódicos."""
    dx = (np.roll(alt, -1, axis=1) - np.roll(alt, 1, axis=1)) * 0.5
    dy = (np.roll(alt, -1, axis=0) - np.roll(alt, 1, axis=0)) * 0.5
    n = np.dstack([-dx * fuerza, -dy * fuerza, np.ones_like(alt)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def guardar(nombre, rgba):
    alto, ancho = rgba.shape[:2]
    img = bpy.data.images.new(nombre, ancho, alto, alpha=True)
    img.colorspace_settings.name = "Non-Color"   # ya convertimos a sRGB a mano
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    ruta = os.path.join(comun.DIR_TEX, nombre + ".png")
    img.filepath_raw = ruta
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return ruta


def hornear_material(nombre):
    fn, tam, fuerza = MATERIALES[nombre]
    t0 = time.time()
    comun.escena_vacia()
    ob, img = comun.plano_para_hornear(tam)
    mat = bpy.data.materials.new(nombre)
    ob.data.materials.append(mat)
    g = Grafo(mat)
    col, rug, alt = fn(g)
    canales = {}
    for canal, sock in (("color", col), ("rug", g.gris(rug)), ("alt", g.gris(alt))):
        g.emitir(sock)
        comun.hornear(ob, mat, img)
        px = np.empty(tam * tam * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        canales[canal] = px.reshape(tam, tam, 4)
    color = a_srgb(canales["color"][:, :, :3])
    rugosidad = np.clip(canales["rug"][:, :, 0], 0.0, 1.0)
    altura = canales["alt"][:, :, 0]
    rgba = np.dstack([color, rugosidad])
    guardar(nombre + "_color", rgba)
    n = normales(altura, fuerza)
    guardar(nombre + "_normal", np.dstack([n, np.ones_like(altura)]))
    print("TEXTURA %s %dpx en %.1fs (alt %.2f..%.2f)" % (nombre, tam, time.time() - t0, altura.min(), altura.max()), flush=True)


def main():
    os.makedirs(comun.DIR_TEX, exist_ok=True)
    pedidos = [a for a in sys.argv[1:] if a in MATERIALES] or list(MATERIALES)
    for n in pedidos:
        hornear_material(n)
    print("TEXTURAS LISTAS", flush=True)


if __name__ == "__main__":
    main()
