"""Cuerpo humanoide continuo (piel deformable) con esqueleto, para los personajes.

- Malla: grafo de vértices con modificador Skin (radios por articulación) + subdivisión: un cuerpo
  orgánico sin cortes entre piezas. Materiales por zona: piel, camisa, pantalon.
- Esqueleto: los mismos huesos (nombres y articulaciones) que usa el juego (PersonajeVisual.HUESOS).
- Pesos: calculados a mano por distancia a cada hueso (mezcla suave en codos, rodillas y hombros).

Uso: /tmp/claude-0/venvbpy/v/bin/python -I tools/blender/personaje.py
Salida: assets/modelos/cuerpo.glb
"""
import math
import os
import sys

import bpy
import bmesh  # noqa: E402  (bmesh se registra al importar bpy)
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import comun  # noqa: E402
import geo  # noqa: E402

# Huesos en coordenadas del juego (Godot: Y arriba, frente +Z, izquierda +X), relativos al padre.
HUESOS = [
    ("Caderas", "", (0, 1.0, 0)),
    ("Columna", "Caderas", (0, 0.1, 0)),
    ("Pecho", "Columna", (0, 0.18, 0)),
    ("Cuello", "Pecho", (0, 0.25, 0)),
    ("Cabeza", "Cuello", (0, 0.07, 0)),
    ("BrazoI", "Pecho", (0.2, 0.2, 0)),
    ("AntebrazoI", "BrazoI", (0, -0.27, 0)),
    ("ManoI", "AntebrazoI", (0, -0.24, 0)),
    ("BrazoD", "Pecho", (-0.2, 0.2, 0)),
    ("AntebrazoD", "BrazoD", (0, -0.27, 0)),
    ("ManoD", "AntebrazoD", (0, -0.24, 0)),
    ("PiernaI", "Caderas", (0.095, -0.04, 0)),
    ("RodillaI", "PiernaI", (0, -0.45, 0)),
    ("PieI", "RodillaI", (0, -0.46, 0)),
    ("PiernaD", "Caderas", (-0.095, -0.04, 0)),
    ("RodillaD", "PiernaD", (0, -0.45, 0)),
    ("PieD", "RodillaD", (0, -0.46, 0)),
]
# Punta de los huesos hoja (relativa a su cabeza).
PUNTAS = {"Cabeza": (0, 0.25, 0), "ManoI": (0, -0.12, 0), "ManoD": (0, -0.12, 0), "PieI": (0, -0.03, 0.15), "PieD": (0, -0.03, 0.15)}


def g2b(v):
    """Godot (x, y, z) → Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


def globales():
    pos = {}
    for n, padre, off in HUESOS:
        base = pos[padre] if padre else Vector((0, 0, 0))
        pos[n] = base + Vector(off)
    return pos


def armadura(pos):
    arm = bpy.data.armatures.new("Esqueleto")
    ob = bpy.data.objects.new("Esqueleto", arm)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    hijos = {}
    for n, padre, _ in HUESOS:
        if padre:
            hijos.setdefault(padre, []).append(n)
    for n, padre, _ in HUESOS:
        b = arm.edit_bones.new(n)
        b.head = g2b(pos[n])
        if n in PUNTAS:
            b.tail = g2b(pos[n] + Vector(PUNTAS[n]))
        else:
            # Punta hacia el primer hijo de la cadena (para columna: hacia arriba).
            h = hijos[n][0]
            b.tail = g2b(pos[h]) if (pos[h] - pos[n]).length > 0.02 else g2b(pos[n] + Vector((0, 0.08, 0)))
            if n == "Caderas":
                b.tail = g2b(pos["Columna"])
            if n == "Pecho":
                b.tail = g2b(pos["Cuello"])
        b.roll = 0.0
    for n, padre, _ in HUESOS:
        if padre:
            arm.edit_bones[n].parent = arm.edit_bones[padre]
            arm.edit_bones[n].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def cuerpo(pos):
    """Grafo de la piel (Godot coords) → Skin + Subsurf."""
    P = lambda *v: Vector(v)
    nodos = {}
    aristas = []
    radios = {}

    def nodo(nombre, p, rx, ry=None):
        nodos[nombre] = p
        radios[nombre] = (rx, ry if ry is not None else rx)

    def arista(a, b):
        aristas.append((a, b))

    nodo("pelvis", P(0, 0.97, 0), 0.135, 0.095)
    nodo("cintura", P(0, 1.1, 0), 0.115, 0.085)
    nodo("torax", P(0, 1.28, 0.005), 0.15, 0.095)
    nodo("pecho_alto", P(0, 1.43, 0.0), 0.16, 0.09)
    nodo("cuello_b", P(0, 1.52, 0), 0.055, 0.05)
    nodo("cuello_a", P(0, 1.62, 0.005), 0.047, 0.045)
    for nombre in ("pelvis", "cintura", "torax", "pecho_alto", "cuello_b", "cuello_a"):
        pass
    arista("pelvis", "cintura"); arista("cintura", "torax"); arista("torax", "pecho_alto")
    arista("pecho_alto", "cuello_b"); arista("cuello_b", "cuello_a")
    for s, L in ((1, "I"), (-1, "D")):
        x = 0.2 * s
        nodo("clav" + L, P(0.1 * s, 1.465, -0.005), 0.065, 0.055)
        nodo("hombro" + L, P(x, 1.47, 0), 0.06, 0.058)
        nodo("biceps" + L, P(x, 1.34, 0.0), 0.05, 0.052)
        nodo("codo" + L, P(x, 1.21, 0), 0.041, 0.043)
        nodo("anteb" + L, P(x, 1.1, 0.005), 0.042, 0.04)
        nodo("muneca" + L, P(x, 0.98, 0.005), 0.03, 0.026)
        nodo("mano" + L, P(x, 0.9, 0.012), 0.038, 0.02)
        nodo("dedos" + L, P(x, 0.83, 0.015), 0.032, 0.017)
        for a, b in (("pecho_alto", "clav"), ("clav", "hombro"), ("hombro", "biceps"), ("biceps", "codo"), ("codo", "anteb"),
                     ("anteb", "muneca"), ("muneca", "mano"), ("mano", "dedos")):
            arista(a if a == "pecho_alto" else a + L, b + L)
        xl = 0.095 * s
        nodo("cadera" + L, P(xl, 0.93, 0), 0.085, 0.085)
        nodo("muslo" + L, P(xl, 0.73, 0.005), 0.072, 0.074)
        nodo("rodilla" + L, P(xl, 0.51, 0.01), 0.054, 0.056)
        nodo("pantorrilla" + L, P(xl, 0.35, -0.005), 0.055, 0.06)
        nodo("tobillo" + L, P(xl, 0.09, 0), 0.036, 0.04)
        nodo("pie" + L, P(xl, 0.045, 0.08), 0.045, 0.03)
        nodo("punta" + L, P(xl, 0.035, 0.16), 0.04, 0.022)
        for a, b in (("pelvis", "cadera"), ("cadera", "muslo"), ("muslo", "rodilla"), ("rodilla", "pantorrilla"),
                     ("pantorrilla", "tobillo"), ("tobillo", "pie"), ("pie", "punta")):
            arista(a if a == "pelvis" else a + L, b + L)
    bm = bmesh.new()
    vs = {}
    for n, p in nodos.items():
        vs[n] = bm.verts.new(g2b(p))
    for a, b in aristas:
        bm.edges.new((vs[a], vs[b]))
    me = bpy.data.meshes.new("cuerpo")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("cuerpo", me)
    bpy.context.collection.objects.link(ob)
    mod = ob.modifiers.new("piel", "SKIN")
    mod.use_smooth_shade = True
    mod.branch_smoothing = 0.6
    nombres = list(nodos.keys())
    sv = me.skin_vertices[0].data
    for i, n in enumerate(nombres):
        rx, ry = radios[n]
        sv[i].radius = (rx, ry)
        sv[i].use_root = (n == "pelvis")
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier="piel")
    bpy.ops.object.modifier_apply(modifier="sub")
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def materiales_por_zona(ob):
    for n in ("piel", "camisa", "pantalon"):
        ob.data.materials.append(geo.material(n))
    me = ob.data
    for p in me.polygons:
        c = p.center   # Blender: x, y = -z_godot, z = y_godot
        y = c.z
        x = abs(c.x)
        if y > 1.53:
            idx = 0                 # cuello
        elif x > 0.14 and y > 0.8:  # brazos
            idx = 0 if y < 1.27 else 1
        elif y > 0.955:
            idx = 1                 # torso
        elif y < 0.13:
            idx = 0                 # pies (se cubren con sandalias)
        else:
            idx = 2                 # piernas
        p.material_index = idx


def pesos(ob, arm, pos):
    """Pesos por distancia a los segmentos de hueso, con mezcla suave entre las 2-3 más cercanas."""
    segs = {}
    for b in arm.data.bones:
        segs[b.name] = (b.head_local.copy(), b.tail_local.copy())
    grupos = {n: ob.vertex_groups.new(name=n) for n in segs}

    def dist(p, a, b):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        return (p - (a + ab * t)).length

    for v in ob.data.vertices:
        p = v.co
        lado = "I" if p.x > 0 else "D"
        cand = []
        for n, (a, b) in segs.items():
            # Las extremidades solo influyen en su lado; el torso no toma pesos de las piernas por encima de la pelvis.
            if n[-1] in "ID" and n[-1] != lado and abs(p.x) > 0.02:
                continue
            d = dist(p, a, b)
            cand.append((d, n))
        cand.sort()
        cand = cand[:3]
        base = cand[0][0]
        ws = []
        for d, n in cand:
            w = math.exp(-((d - base) / 0.03) ** 2) if d - base < 0.09 else 0.0
            ws.append((w, n))
        tot = sum(w for w, _ in ws) or 1.0
        for w, n in ws:
            if w / tot > 0.02:
                grupos[n].add([v.index], w / tot, "REPLACE")


def main():
    comun.escena_vacia()
    geo.limpiar()
    pos = globales()
    arm = armadura(pos)
    ob = cuerpo(pos)
    materiales_por_zona(ob)
    pesos(ob, arm, pos)
    ob.parent = arm
    mod = ob.modifiers.new("arm", "ARMATURE")
    mod.object = arm
    for o in bpy.context.selected_objects:
        o.select_set(False)
    arm.select_set(True)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = arm
    ruta = os.path.join(comun.DIR_MOD, "cuerpo.glb")
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", use_selection=True, export_skins=True,
                              export_yup=True, export_animations=False, export_def_bones=False)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("CUERPO %d vértices, %d triángulos → %s" % (len(ob.data.vertices), tris, ruta), flush=True)


if __name__ == "__main__":
    main()
