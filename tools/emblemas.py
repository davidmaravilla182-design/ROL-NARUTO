"""Emblemas de clan para la calcomanía de la espalda del ninja (assets/texturas/emblema_<clan>.png).
Dibujados por código (sin recursos externos) a 1024 px y reducidos a 256 para suavizar bordes.
Uso: python3 tools/emblemas.py
"""
import json
import math
import os

from PIL import Image, ImageDraw

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
T = 1024
C = T // 2


def lienzo():
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def abanico():
    """Abanico: parte superior roja redondeada, franja inferior blanca y mango."""
    im, d = lienzo()
    d.ellipse((140, 80, T - 140, 780), fill=(200, 16, 46, 255), outline=(20, 20, 24, 255), width=22)
    d.rectangle((120, 430, T - 120, 800), fill=(0, 0, 0, 0))
    d.chord((140, 80, T - 140, 780), 180, 360, fill=(200, 16, 46, 255), outline=(20, 20, 24, 255), width=22)
    d.rectangle((160, 420, T - 160, 600), fill=(242, 242, 242, 255), outline=(20, 20, 24, 255), width=22)
    d.rounded_rectangle((C - 42, 600, C + 42, 960), 30, fill=(235, 235, 235, 255), outline=(20, 20, 24, 255), width=18)
    return im


def ojo_venas():
    """Anillo blanco con venas radiales (linaje de ojos blancos)."""
    im, d = lienzo()
    d.ellipse((120, 120, T - 120, T - 120), fill=(40, 44, 70, 255), outline=(235, 238, 250, 255), width=40)
    for k in range(12):
        a = 2 * math.pi * k / 12
        d.line((C + math.cos(a) * 170, C + math.sin(a) * 170, C + math.cos(a) * 340, C + math.sin(a) * 340), fill=(220, 225, 245, 255), width=26)
    d.ellipse((C - 130, C - 130, C + 130, C + 130), fill=(235, 238, 250, 255))
    return im


def flor_papel():
    """Flor de papel de cinco pétalos (origami)."""
    im, d = lienzo()
    for k in range(5):
        a = 2 * math.pi * k / 5 - math.pi / 2
        cx, cy = C + math.cos(a) * 230, C + math.sin(a) * 230
        pts = [(C, C), (cx + math.cos(a + 1.2) * 170, cy + math.sin(a + 1.2) * 170), (C + math.cos(a) * 470, C + math.sin(a) * 470),
               (cx + math.cos(a - 1.2) * 170, cy + math.sin(a - 1.2) * 170)]
        d.polygon(pts, fill=(238, 236, 228, 255) if k % 2 == 0 else (150, 180, 230, 255), outline=(30, 34, 50, 255), width=14)
    d.ellipse((C - 70, C - 70, C + 70, C + 70), fill=(240, 200, 90, 255), outline=(30, 34, 50, 255), width=14)
    return im


def hoja():
    """Hoja con nervaduras (linaje de la madera)."""
    im, d = lienzo()
    d.ellipse((260, 90, T - 260, T - 160), fill=(80, 150, 70, 255), outline=(20, 40, 20, 255), width=22)
    d.line((C, 140, C, T - 90), fill=(30, 60, 25, 255), width=26)
    for k in range(4):
        y = 300 + k * 130
        d.line((C, y, C - 170, y - 110), fill=(30, 60, 25, 255), width=18)
        d.line((C, y, C + 170, y - 110), fill=(30, 60, 25, 255), width=18)
    return im


def copo():
    """Copo de nieve de seis brazos (linaje del hielo)."""
    im, d = lienzo()
    col = (190, 235, 255, 255)
    for k in range(6):
        a = math.pi * k / 3
        x2, y2 = C + math.cos(a) * 440, C + math.sin(a) * 440
        d.line((C, C, x2, y2), fill=col, width=44)
        for r in (220, 330):
            bx, by = C + math.cos(a) * r, C + math.sin(a) * r
            for s in (-1, 1):
                d.line((bx, by, bx + math.cos(a + s * 0.8) * 110, by + math.sin(a + s * 0.8) * 110), fill=col, width=32)
    d.ellipse((C - 70, C - 70, C + 70, C + 70), fill=col)
    return im


def volcan():
    """Volcán con llama (linaje de la lava)."""
    im, d = lienzo()
    d.polygon([(110, 930), (380, 470), (T - 380, 470), (T - 110, 930)], fill=(60, 40, 36, 255), outline=(20, 12, 10, 255), width=20)
    d.polygon([(C, 90), (C - 210, 470), (C - 70, 400), (C, 520), (C + 70, 400), (C + 210, 470)], fill=(255, 110, 30, 255), outline=(120, 30, 0, 255), width=18)
    d.polygon([(C, 260), (C - 90, 470), (C, 430), (C + 90, 470)], fill=(255, 220, 90, 255))
    return im


def ave():
    """Ave de arcilla con las alas abiertas."""
    im, d = lienzo()
    col = (238, 228, 205, 255)
    d.polygon([(C, 380), (90, 260), (180, 470), (C - 60, 520), (C, 760), (C + 60, 520), (T - 180, 470), (T - 90, 260)], fill=col, outline=(70, 55, 40, 255), width=18)
    d.ellipse((C - 70, 300, C + 70, 440), fill=col, outline=(70, 55, 40, 255), width=16)
    d.polygon([(C - 30, 760), (C, 900), (C + 30, 760)], fill=col, outline=(70, 55, 40, 255), width=14)
    return im


def calabaza():
    """Calabaza de arena (linaje de la arena)."""
    im, d = lienzo()
    col = (214, 176, 110, 255)
    borde = (90, 60, 30, 255)
    d.ellipse((260, 420, T - 260, T - 80), fill=col, outline=borde, width=22)
    d.ellipse((340, 170, T - 340, 520), fill=col, outline=borde, width=22)
    d.rectangle((C - 60, 90, C + 60, 190), fill=(150, 40, 40, 255), outline=borde, width=16)
    d.rectangle((300, 470, T - 300, 520), fill=(150, 40, 40, 255))
    return im


def lineas_aldea():
    """Símbolo de la aldea: cuatro líneas verticales dentro de un círculo."""
    im, d = lienzo()
    d.ellipse((120, 120, T - 120, T - 120), outline=(225, 230, 240, 255), width=48)
    for k in range(4):
        x = C + (k - 1.5) * 130
        d.rounded_rectangle((x - 30, 260, x + 30, T - 260), 20, fill=(225, 230, 240, 255))
    return im


DIBUJOS = {"uchiha": abanico, "hyuga": ojo_venas, "papel": flor_papel, "madera": hoja, "hielo": copo,
           "lava": volcan, "arcilla": ave, "arena": calabaza, "sin_clan": lineas_aldea}


def main():
    clanes = json.load(open(os.path.join(RAIZ, "data", "creacion.json"), encoding="utf-8"))["clanes"]
    for clan in clanes:
        f = DIBUJOS.get(clan, lineas_aldea)
        f().resize((256, 256), Image.LANCZOS).save(os.path.join(RAIZ, "assets", "texturas", "emblema_%s.png" % clan))
        print("emblema", clan)


if __name__ == "__main__":
    main()
