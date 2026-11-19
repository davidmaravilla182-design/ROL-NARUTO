"""Procesa un modelo de Meshy (lote de tools/meshy_lote.py) para el juego.

- Escala real (alto en metros), base en z=0, centrado en XY; giro opcional (grados) para que el frente mire a -Y (= +Z en Godot).
- LOD0: la malla de Meshy; LOD lejano por colapso (mismas UV).
- Textura base reducida (1024 px edificios / 512 objetos) → assets/texturas/<nombre>_color.png (+ normal plana 4x4).
- Material con el nombre de la pieza (Kit le pone el shader toon_tex con lluvia).
Salida: assets/modelos/<nombre>.glb y <nombre>_lejos.glb; huella [ancho, fondo, alto] en data/escenario.json.

Uso: /tmp/claude-0/venvbpy/v/bin/python -I tools/blender/pieza_ia.py <nombre> <alto_m> <px> <tris_lejos> [giro] [nombre_salida]
"""
import bpy, mathutils, os, sys, json, math
import numpy as np

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def log(*a):
    print("[pieza_ia]", *a, flush=True)


def activo(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def exportar(o, ruta):
    activo(o)
    bpy.ops.export_scene.gltf(filepath=ruta, use_selection=True, export_format="GLB", export_image_format="NONE", export_apply=True)


def main():
    a = sys.argv[1:]
    nombre, alto, px, lejos_tris = a[0], float(a[1]), int(a[2]), int(a[3])
    giro = float(a[4]) if len(a) > 4 else 0.0
    entrada = os.path.join(RAIZ, "referencias", "modelos-ia", "meshy", nombre, "modelo.glb")
    if len(a) > 5:
        nombre = a[5]   # nombre de salida distinto (evita chocar con piezas del kit)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=entrada)
    mallas = [x for x in bpy.data.objects if x.type == "MESH"]
    activo(mallas[0])
    for m in mallas:
        m.select_set(True)
    if len(mallas) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = nombre
    o.rotation_euler[2] += math.radians(giro)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    P = np.array([tuple(v.co) for v in o.data.vertices])
    mn, mx = P.min(axis=0), P.max(axis=0)
    esc = alto / (mx[2] - mn[2])
    c = mathutils.Vector(((mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2]))
    for v in o.data.vertices:
        v.co = (v.co - c) * esc
    o.data.update()
    ancho, fondo = (mx[0] - mn[0]) * esc, (mx[1] - mn[1]) * esc
    log("%s: %.2f × %.2f × %.2f m, %d triángulos" % (nombre, ancho, fondo, alto, tris(o)))
    img = None
    for n in o.data.materials[0].node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image is not None and img is None:
            img = n.image
    img.scale(px, px)
    img.filepath_raw = os.path.join(RAIZ, "assets", "texturas", nombre + "_color.png")
    img.file_format = "PNG"
    img.save()
    plano = bpy.data.images.new(nombre + "_normal", 4, 4, alpha=False)
    plano.pixels.foreach_set(np.tile([0.5, 0.5, 1.0, 1.0], 16).astype(np.float32))
    plano.filepath_raw = os.path.join(RAIZ, "assets", "texturas", nombre + "_normal.png")
    plano.file_format = "PNG"
    plano.save()
    while len(o.data.materials) > 1:
        o.data.materials.pop()
    o.data.materials[0].name = nombre
    exportar(o, os.path.join(RAIZ, "assets", "modelos", nombre + ".glb"))
    lejos = o.copy()
    lejos.data = o.data.copy()
    lejos.name = nombre + "_lejos"
    bpy.context.scene.collection.objects.link(lejos)
    md = lejos.modifiers.new("col", "DECIMATE")
    md.decimate_type = "COLLAPSE"
    md.ratio = min(1.0, lejos_tris / max(tris(o), 1))
    activo(lejos)
    bpy.ops.object.modifier_apply(modifier="col")
    log("LOD lejano: %d triángulos" % tris(lejos))
    exportar(lejos, os.path.join(RAIZ, "assets", "modelos", nombre + "_lejos.glb"))
    ruta = os.path.join(RAIZ, "data", "escenario.json")
    e = json.load(open(ruta, encoding="utf-8"))
    e["trazado"]["huellas"][nombre] = [round(ancho, 2), round(fondo, 2), round(alto, 2)]
    e["trazado"].setdefault("triangulos", {})[nombre] = [tris(o), tris(lejos)]
    json.dump(e, open(ruta, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    log("listo")


main()
