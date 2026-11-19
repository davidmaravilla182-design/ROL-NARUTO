"""Texturas CC0 de Poly Haven (polyhaven.com) para suelos, muros y metal, en el formato del shader toon_tex:
<n>_color.png (RGB = color ajustado a la paleta de la aldea, A = rugosidad) y <n>_normal.png (normal OpenGL).
Uso: python3 tools/texturas_polyhaven.py   (descarga 1K JPG a una carpeta temporal y escribe assets/texturas/)
"""
import json
import os
import tempfile
import urllib.request

from PIL import Image, ImageEnhance

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
API = "https://api.polyhaven.com/files/"
# nombre en el juego: (recurso de Poly Haven, tinte RGB multiplicador, brillo, saturación)
TEXTURAS = {
    "suelo": ("concrete_floor_02", (0.78, 0.8, 0.9), 0.8, 0.55),
    "concreto": ("concrete_wall_008", (0.88, 0.88, 0.95), 0.95, 0.5),
    "lamina": ("corrugated_iron", (0.8, 0.78, 0.9), 0.9, 0.6),
    "techo": ("rusty_metal_02", (0.95, 0.72, 0.75), 0.85, 0.9),
}


UA = {"User-Agent": "herramienta-texturas/1.0"}


def bajar(url, destino=None):
    datos = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read()
    if destino:
        open(destino, "wb").write(datos)
    return datos


def main():
    tmp = tempfile.mkdtemp(prefix="polyhaven_")
    for nombre, (recurso, tinte, brillo, sat) in TEXTURAS.items():
        d = json.loads(bajar(API + recurso))
        rutas = {}
        for k in ("Diffuse", "nor_gl", "Rough"):
            rutas[k] = os.path.join(tmp, "%s_%s.jpg" % (recurso, k))
            bajar(d[k]["1k"]["jpg"]["url"], rutas[k])
        col = Image.open(rutas["Diffuse"]).convert("RGB")
        col = ImageEnhance.Color(col).enhance(sat)
        col = ImageEnhance.Brightness(col).enhance(brillo)
        r, g, b = col.split()
        r = r.point(lambda v: int(v * tinte[0]))
        g = g.point(lambda v: int(v * tinte[1]))
        b = b.point(lambda v: int(v * tinte[2]))
        rug = Image.open(rutas["Rough"]).convert("L").resize(col.size)
        Image.merge("RGBA", (r, g, b, rug)).save(os.path.join(RAIZ, "assets", "texturas", nombre + "_color.png"))
        Image.open(rutas["nor_gl"]).convert("RGB").save(os.path.join(RAIZ, "assets", "texturas", nombre + "_normal.png"))
        print(nombre, "←", recurso)


if __name__ == "__main__":
    main()
