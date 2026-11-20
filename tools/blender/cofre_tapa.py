"""Separa la tapa del cofre de recompensas (assets/modelos/cofre_recompensa.glb, ya procesado por pieza_ia.py)
para que se abra: assets/modelos/cofre_base.glb y cofre_tapa.glb (origen de la tapa en la bisagra, atrás arriba).
Las caras cuyo centro está por encima del corte (fracción de la altura, medida en las vistas) van a la tapa.
Uso: /tmp/claude-0/venvbpy/v/bin/python -I tools/blender/cofre_tapa.py [corte=0.46]
"""
import bpy, bmesh, os, sys, json
from mathutils import Vector

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
corte = float(sys.argv[-1]) if sys.argv[-1].replace(".", "").isdigit() else 0.46
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(RAIZ, "assets", "modelos", "cofre_recompensa.glb"))
o = [x for x in bpy.data.objects if x.type == "MESH"][0]
bpy.context.view_layer.objects.active = o
o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
zs = [v.co.z for v in o.data.vertices]
ys = [v.co.y for v in o.data.vertices]
z0, z1 = min(zs), max(zs)
zc = z0 + (z1 - z0) * corte
bpy.ops.object.mode_set(mode="EDIT")
bm = bmesh.from_edit_mesh(o.data)
for f in bm.faces:
    f.select = f.calc_center_median().z > zc
bmesh.update_edit_mesh(o.data)
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.object.mode_set(mode="OBJECT")
tapa = [x for x in bpy.context.selected_objects if x != o][0]
# Bisagra: atrás (+Y en Blender = -Z en Godot) a la altura del corte.
bisagra = Vector((0.0, max(ys), zc))
for v in tapa.data.vertices:
    v.co -= bisagra
tapa.location = (0, 0, 0)
for ob, nombre in ((o, "cofre_base"), (tapa, "cofre_tapa")):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=os.path.join(RAIZ, "assets", "modelos", nombre + ".glb"), use_selection=True,
                              export_format="GLB", export_image_format="NONE", export_apply=True)
    print("[cofre]", nombre, len(ob.data.polygons), "caras")
g = json.load(open(os.path.join(RAIZ, "data", "graficos.json"), encoding="utf-8"))
g["cofre_bisagra"] = [0.0, round(zc, 4), round(-max(ys), 4)]   # en Godot (x, y, z)
json.dump(g, open(os.path.join(RAIZ, "data", "graficos.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("[cofre] bisagra", g["cofre_bisagra"])
