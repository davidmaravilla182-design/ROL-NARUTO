"""Gólem de tierra con esqueleto y animaciones (rig y biblioteca de animaciones de Meshy) → assets/modelos/jutsu_golem_animado.glb

Acciones exportadas (nombres en el juego):
  surgir   ← Chest_Pound_Taunt   (se golpea el pecho al salir del suelo)
  caminar  ← walking (del rig)   (en el sitio: el desplazamiento lo pone el servidor)
  golpe    ← Punch_Forward_with_Both_Fists
  derrumbe ← Dead
Además guarda en data/graficos.json → golem_animado: altura, y el instante del impacto del golpe (máximo avance de
los puños) para sincronizar la anticipación con el golpe del servidor.

Uso: /tmp/claude-0/venvbpy/v/bin/python -I tools/blender/golem_animado.py
"""
import bpy, os, json
import numpy as np
from mathutils import Vector

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
D = os.path.join(RAIZ, "referencias", "modelos-ia", "meshy", "animaciones")
ALTO = 2.6
NOMBRES = {"Chest_Pound_Taunt": "surgir", "Punch_Forward_with_Both_Fists": "golpe", "Dead": "derrumbe"}


def curvas(a):
    """F-curves de una acción (acciones por capas de Blender 4.4+ o el formato antiguo)."""
    if hasattr(a, "fcurves") and len(getattr(a, "fcurves", [])) > 0:
        return list(a.fcurves)
    res = []
    for capa in getattr(a, "layers", []):
        for tira in capa.strips:
            for bolsa in tira.channelbags:
                res.extend(bolsa.fcurves)
    return res


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(D, "anim_golem.glb"))
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o)
    malla = [o for o in bpy.data.objects if o.type == "MESH"][0]
    acciones = {}
    for a in list(bpy.data.actions):
        if a.name in NOMBRES:
            a.name = NOMBRES[a.name]
            acciones[a.name] = a
        else:
            bpy.data.actions.remove(a)
    # Caminar: del GLB del rig (mismos huesos).
    antes = set(bpy.data.actions.keys())
    antes_obs = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=os.path.join(D, "rig_golem_walking.glb"))
    for o in list(bpy.data.objects):
        if o.name not in antes_obs:
            bpy.data.objects.remove(o)
    for a in list(bpy.data.actions):
        if a.name not in antes:
            if "walking" in a.name.lower():
                a.name = "caminar"
                acciones["caminar"] = a
            else:
                bpy.data.actions.remove(a)
    # Caminar en el sitio: sin desplazamiento horizontal de la cadera.
    for fc in curvas(acciones["caminar"]):
        if "Hips" in fc.data_path and fc.data_path.endswith("location") and fc.array_index in (0, 2):
            for k in fc.keyframe_points:
                k.co.y = fc.keyframe_points[0].co.y
                k.handle_left.y = k.co.y
                k.handle_right.y = k.co.y
    # Escala: el gólem mide ALTO metros (como el modelo estático anterior).
    bpy.context.view_layer.update()
    P = np.array([tuple(malla.matrix_world @ v.co) for v in malla.data.vertices])
    alto = P[:, 2].max() - P[:, 2].min()
    f = ALTO / alto
    arm.scale = arm.scale * f
    bpy.context.view_layer.update()
    # Instante del impacto del golpe: máximo avance de las manos (hacia -Y, el frente).
    escena = bpy.context.scene
    fps = escena.render.fps / escena.render.fps_base
    arm.animation_data.action = acciones["golpe"]
    f0, f1 = int(acciones["golpe"].frame_range[0]), int(acciones["golpe"].frame_range[1])
    mejor, t_imp = 1e9, 0.0
    for fr in range(f0, f1 + 1):
        escena.frame_set(fr)
        y = sum((arm.matrix_world @ arm.pose.bones[b].head).y for b in ("LeftHand", "RightHand")) / 2
        if y < mejor:
            mejor, t_imp = y, (fr - f0) / fps
    # Textura aparte (1024 px) para el sombreado toon del juego (Kit.material_para("jutsu_golem_animado")).
    img = None
    for m in malla.data.materials:
        if m is not None and m.node_tree is not None:
            for nd in m.node_tree.nodes:
                if nd.type == "TEX_IMAGE" and nd.image is not None and img is None:
                    img = nd.image
    if img is not None:
        img.scale(1024, 1024)
        img.filepath_raw = os.path.join(RAIZ, "assets", "texturas", "jutsu_golem_animado_color.png")
        img.file_format = "PNG"
        img.save()
        plano = bpy.data.images.new("golem_normal", 4, 4, alpha=False)
        plano.pixels.foreach_set(np.tile([0.5, 0.5, 1.0, 1.0], 16).astype(np.float32))
        plano.filepath_raw = os.path.join(RAIZ, "assets", "texturas", "jutsu_golem_animado_normal.png")
        plano.file_format = "PNG"
        plano.save()
    malla.data.materials[0].name = "jutsu_golem_animado"
    # Todas las acciones como pistas NLA (el exportador las saca como animaciones separadas).
    arm.animation_data.action = None
    for nombre, a in acciones.items():
        pista = arm.animation_data.nla_tracks.new()
        pista.name = nombre
        pista.strips.new(nombre, int(a.frame_range[0]), a)
    duraciones = {n: round((a.frame_range[1] - a.frame_range[0]) / fps, 3) for n, a in acciones.items()}
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    malla.select_set(True)
    salida = os.path.join(RAIZ, "assets", "modelos", "jutsu_golem_animado.glb")
    bpy.ops.export_scene.gltf(filepath=salida, use_selection=True, export_format="GLB", export_skins=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_image_format="NONE")
    ruta = os.path.join(RAIZ, "data", "graficos.json")
    g = json.load(open(ruta, encoding="utf-8"))
    g["golem_animado"] = {"_nota": "Generado por tools/blender/golem_animado.py", "altura": ALTO,
                          "golpe_impacto": round(t_imp, 3), "duraciones": duraciones}
    json.dump(g, open(ruta, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print("[golem] escala %.3f, impacto del golpe %.2f s, acciones %s → %s (%d KB)" % (
        f, t_imp, duraciones, salida, os.path.getsize(salida) // 1024), flush=True)


main()
