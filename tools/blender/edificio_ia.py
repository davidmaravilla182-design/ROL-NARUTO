"""Edificio especial de la plaza a partir de un modelo de Meshy (Image to 3D, Smart Topology meshy-t2.5).

Entrada: el GLB descargado con tools/meshy.py (por defecto en la carpeta de la tarea; ruta como 1.er argumento).
- Escala real (ALTO m), base en z=0, centrado; el frente (puerta) mira a -Y (= +Z en Godot).
- LOD0: la malla de Meshy tal cual (~26k triángulos). LOD1 (~6k) por colapso, mismas UV.
- Textura base reducida a 1024 px → assets/texturas/edificio_ia_color.png (+ normal plana para el shader del kit).
- Material con nombre "edificio_ia" (el juego le pone su shader de cel shading con lluvia).
Salida: assets/modelos/edificio_ia.glb (LOD0) y edificio_ia_lejos.glb (LOD1); medidas en data/escenario.json -> trazado.huellas.

Uso: /tmp/claude-0/venvbpy/v/bin/python tools/blender/edificio_ia.py <modelo.glb>
"""
import bpy, mathutils, os, sys, json
import numpy as np

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ALTO = 8.5
LOD1 = 6000


def log(*a):
    print("[edificio_ia]", *a, flush=True)


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
    entrada = [a for a in sys.argv[1:] if a.endswith(".glb")]
    if not entrada:
        raise SystemExit("falta el GLB de Meshy")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=entrada[0])
    o = [x for x in bpy.data.objects if x.type == "MESH"][0]
    o.name = "edificio_ia"
    activo(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    P = np.array([tuple(v.co) for v in o.data.vertices])
    mn, mx = P.min(axis=0), P.max(axis=0)
    esc = ALTO / (mx[2] - mn[2])
    c = mathutils.Vector(((mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2]))
    for v in o.data.vertices:
        v.co = (v.co - c) * esc
    o.data.update()
    ancho, fondo = (mx[0] - mn[0]) * esc, (mx[1] - mn[1]) * esc
    log("medidas %.2f × %.2f × %.2f m, %d triángulos" % (ancho, fondo, ALTO, tris(o)))
    # Textura: la de Meshy, reducida a 1024 px.
    img = None
    for n in o.data.materials[0].node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image is not None:
            img = n.image
    img.scale(1024, 1024)
    img.filepath_raw = os.path.join(RAIZ, "assets", "texturas", "edificio_ia_color.png")
    img.file_format = "PNG"
    img.save()
    plano = bpy.data.images.new("edificio_ia_normal", 4, 4, alpha=False)
    plano.pixels.foreach_set(np.tile([0.5, 0.5, 1.0, 1.0], 16).astype(np.float32))
    plano.filepath_raw = os.path.join(RAIZ, "assets", "texturas", "edificio_ia_normal.png")
    plano.file_format = "PNG"
    plano.save()
    o.data.materials[0].name = "edificio_ia"
    exportar(o, os.path.join(RAIZ, "assets", "modelos", "edificio_ia.glb"))
    lejos = o.copy()
    lejos.data = o.data.copy()
    lejos.name = "edificio_ia_lejos"
    bpy.context.scene.collection.objects.link(lejos)
    md = lejos.modifiers.new("col", "DECIMATE")
    md.decimate_type = "COLLAPSE"
    md.ratio = LOD1 / tris(o)
    activo(lejos)
    bpy.ops.object.modifier_apply(modifier="col")
    log("LOD lejano: %d triángulos" % tris(lejos))
    exportar(lejos, os.path.join(RAIZ, "assets", "modelos", "edificio_ia_lejos.glb"))
    ruta = os.path.join(RAIZ, "data", "escenario.json")
    e = json.load(open(ruta, encoding="utf-8"))
    e["trazado"]["huellas"]["edificio_ia"] = [round(ancho, 2), round(fondo, 2), ALTO]
    json.dump(e, open(ruta, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    log("listo")


main()
