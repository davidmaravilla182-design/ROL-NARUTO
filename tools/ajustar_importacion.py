"""Ajusta los .import de las texturas 3D: compresión VRAM, mipmaps y mapa de normales.
Godot en modo headless no detecta solo que una textura es 3D, por eso se fija aquí.
Uso: python3 tools/ajustar_importacion.py  (luego: godot --headless --path . --import)"""
import glob, os, re
raiz = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
cambiados = 0
for f in glob.glob(os.path.join(raiz, "assets", "texturas", "*.png.import")):
    s = open(f).read()
    normal = "_normal.png" in f
    nuevo = re.sub(r"compress/mode=\d", "compress/mode=2", s)
    nuevo = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=true", nuevo)
    nuevo = re.sub(r"compress/normal_map=\d", "compress/normal_map=%d" % (1 if normal else 2), nuevo)
    nuevo = re.sub(r"detect_3d/compress_to=\d", "detect_3d/compress_to=0", nuevo)
    if nuevo != s:
        open(f, "w").write(nuevo)
        cambiados += 1
print("import ajustados:", cambiados)
