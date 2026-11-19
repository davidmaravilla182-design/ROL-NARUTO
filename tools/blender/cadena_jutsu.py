"""Pone una cadena de huesos a lo largo del cuerpo de un modelo de jutsu (dragones, Kirin) para que ondule como serpiente.

- Busca la «columna» del modelo cortándolo en rebanadas a lo largo de su eje principal (mediana de cada rebanada,
  así las patas o las alas no la desvían).
- Crea huesos S0 (cabeza) … Sn (cola), encadenados desde la cabeza: el juego (DragonVivo) les aplica una onda
  que viaja de la cabeza a la cola.
- Pesos: cada vértice al segmento más cercano, mezclado con el vecino cerca de las articulaciones.
Salida: assets/modelos/<nombre>_cadena.glb (el modelo estático original no se toca).

Uso: /tmp/claude-0/venvbpy/v/bin/python -I tools/blender/cadena_jutsu.py <jutsu_nombre> <eje: y|z> <huesos> [cabeza: -|+]
  (cabeza "-": la cabeza está en el extremo negativo del eje; por defecto "-" en Y (frente) y "+" en Z (arriba))
"""
import bpy, os, sys, json
import numpy as np
from mathutils import Vector

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    nombre, eje, n = a[0], a[1].lower(), int(a[2])
    cabeza_neg = (a[3] == "-") if len(a) > 3 else (eje == "y")
    ie = {"x": 0, "y": 1, "z": 2}[eje]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(RAIZ, "assets", "modelos", nombre + ".glb"))
    obs = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    if len(obs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    P = np.array([tuple(v.co) for v in ob.data.vertices])
    lo, hi = P[:, ie].min(), P[:, ie].max()
    # Columna: n+1 puntos (cabeza → cola) con la mediana de cada rebanada.
    ts = np.linspace(0.0, 1.0, n + 1)
    if not cabeza_neg:
        ts = ts[::-1]
    largo = hi - lo
    puntos = []
    for t in ts:
        c = lo + t * largo
        ancho = largo / n * 0.6
        sel = P[np.abs(P[:, ie] - c) < ancho]
        if len(sel) < 5:
            sel = P[np.argsort(np.abs(P[:, ie] - c))[:20]]
        p = np.median(sel, axis=0)
        p[ie] = c
        puntos.append(p)
    puntos = np.array(puntos)
    # Armadura.
    arm_d = bpy.data.armatures.new("cadena")
    arm = bpy.data.objects.new("cadena", arm_d)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    previo = None
    for i in range(n):
        b = arm_d.edit_bones.new("S%d" % i)
        b.head = Vector(puntos[i])
        b.tail = Vector(puntos[i + 1])
        if previo is not None:
            b.parent = previo
            b.use_connect = True
        previo = b
    bpy.ops.object.mode_set(mode="OBJECT")
    # Pesos: distancia a cada segmento; los dos más cercanos se reparten el peso.
    grupos = [ob.vertex_groups.new(name="S%d" % i) for i in range(n)]
    A = puntos[:-1]
    B = puntos[1:]
    AB = B - A
    L2 = (AB * AB).sum(1) + 1e-9
    for v in ob.data.vertices:
        p = np.array(tuple(v.co))
        t = np.clip(((p - A) * AB).sum(1) / L2, 0, 1)
        d = np.linalg.norm(A + AB * t[:, None] - p, axis=1)
        orden = np.argsort(d)
        i0, i1 = int(orden[0]), int(orden[1])
        w0 = 1.0 / (d[i0] + 0.05)
        w1 = 1.0 / (d[i1] + 0.05) if abs(i0 - i1) == 1 else 0.0
        s = w0 + w1
        grupos[i0].add([v.index], w0 / s, "REPLACE")
        if w1 > 0:
            grupos[i1].add([v.index], w1 / s, "REPLACE")
    mod = ob.modifiers.new("arm", "ARMATURE")
    mod.object = arm
    ob.parent = arm
    salida = os.path.join(RAIZ, "assets", "modelos", nombre + "_cadena.glb")
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=salida, use_selection=True, export_format="GLB", export_image_format="NONE",
                              export_skins=True, export_animations=False, export_apply=False)
    print("[cadena] %s: %d huesos, largo %.2f m → %s" % (nombre, n, largo, salida), flush=True)
    ruta = os.path.join(RAIZ, "data", "graficos.json")
    g = json.load(open(ruta, encoding="utf-8"))
    g.setdefault("cadenas_jutsu", {})[nombre] = {"huesos": n, "largo": round(float(largo), 2), "eje": eje}
    json.dump(g, open(ruta, "w", encoding="utf-8"), ensure_ascii=False, indent=2)


main()
