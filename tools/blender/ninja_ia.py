"""Ninja del jugador a partir del modelo generado por IA (referencias/modelos-ia/ninja-meshy.glb).

- Escala a 1,82 m, pies en z=0, mirando a -Y (= +Z en Godot).
- Esqueleto con los 17 huesos del juego (PersonajeVisual.HUESOS) colocados en las articulaciones
  medidas sobre la malla (brazos en pose A).
- Pesos por distancia a los huesos (cada lado solo toma pesos de sus extremidades).
- Los brazos se bajan y esa postura queda como reposo: las animaciones del juego suponen brazos abajo.
- Zonas de color por vértice (COLOR_0: R piel, G pelo, B chaleco, A ropa [0,5 camisa, 1 pantalón])
  para recolorear la textura desde la personalización.
- El cabello se separa en su propia malla (PELO) para poder cambiar de peinado.
- Parche ajustado a la espalda (EMBLEMA, UV 0..1) para la calcomanía del clan.

Salida: assets/modelos/ninja_ia.glb y data/graficos.json -> "ninja_ia" (colores originales de cada zona,
posición del nudo de la banda y de los ojos respecto al hueso de la cabeza).
Uso: /tmp/claude-0/venvbpy/v/bin/python tools/blender/ninja_ia.py
"""
import bpy, bmesh, mathutils, math, os, json, colorsys
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REF = os.path.join(RAIZ, "referencias", "modelos-ia")
ALTO = 1.82

# Mismos nombres y jerarquía que PersonajeVisual.HUESOS.
JERARQUIA = [("Caderas", ""), ("Columna", "Caderas"), ("Pecho", "Columna"), ("Cuello", "Pecho"), ("Cabeza", "Cuello"),
             ("BrazoI", "Pecho"), ("AntebrazoI", "BrazoI"), ("ManoI", "AntebrazoI"),
             ("BrazoD", "Pecho"), ("AntebrazoD", "BrazoD"), ("ManoD", "AntebrazoD"),
             ("PiernaI", "Caderas"), ("RodillaI", "PiernaI"), ("PieI", "RodillaI"),
             ("PiernaD", "Caderas"), ("RodillaD", "PiernaD"), ("PieD", "RodillaD")]


def log(*a):
    print("[ninja_ia]", *a, flush=True)


def activo(o, *otros):
    bpy.ops.object.select_all(action="DESELECT")
    for x in otros:
        x.select_set(True)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def importar(ruta=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=ruta or os.path.join(REF, "ninja-meshy.glb"))
    o = [x for x in bpy.data.objects if x.type == "MESH"][0]
    o.name = "NINJA"
    activo(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    m = o.data
    P = np.array([tuple(v.co) for v in m.vertices])
    z0, z1 = P[:, 2].min(), P[:, 2].max()
    esc = ALTO / (z1 - z0)
    cx, cy = (P[:, 0].min() + P[:, 0].max()) / 2, (P[:, 1].min() + P[:, 1].max()) / 2
    for v in m.vertices:
        v.co = Vector(((v.co.x - cx) * esc, (v.co.y - cy) * esc, (v.co.z - z0) * esc))
    m.update()
    return o


def textura(o):
    for n in o.data.materials[0].node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image is not None:
            img = n.image
            a = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
            img.pixels.foreach_get(a)
            return img, a.reshape(img.size[1], img.size[0], 4)
    return None, None


def color_vertices(o, px):
    """Color medio de la textura en cada vértice (sRGB, 0..1)."""
    m = o.data
    uv = m.uv_layers.active.data
    h, w = px.shape[:2]
    col = np.zeros((len(m.vertices), 3))
    cnt = np.zeros(len(m.vertices))
    for li, l in enumerate(m.loops):
        u, v = uv[li].uv
        x = min(max(int(u % 1.0 * w), 0), w - 1)
        y = min(max(int(v % 1.0 * h), 0), h - 1)
        col[l.vertex_index] += px[y, x, :3]
        cnt[l.vertex_index] += 1
    return col / np.maximum(cnt, 1)[:, None]


# ------------------------------------------------------------------ articulaciones
def articulaciones(o):
    P = np.array([tuple(v.co) for v in o.data.vertices])
    H = ALTO
    j = {}
    # Torso: ancho a la altura de los hombros.
    banda = P[np.abs(P[:, 2] - 0.76 * H) < 0.01 * H]
    torso_x = np.percentile(np.abs(banda[:, 0]), 92)
    for lado, s in (("I", 1), ("D", -1)):
        # Brazo en pose A: vértices separados del torso entre el 42 % y el 66 % de la altura.
        brazo = P[(P[:, 0] * s > 0.125 * H) & (P[:, 2] > 0.40 * H) & (P[:, 2] < 0.66 * H)]
        zmin = brazo[:, 2].min()
        muneca = brazo[(brazo[:, 2] > zmin + 0.065 * H) & (brazo[:, 2] < zmin + 0.085 * H)].mean(axis=0)
        punta = brazo[brazo[:, 2] < zmin + 0.01 * H].mean(axis=0)
        hombro = np.array([s * torso_x * 0.78, P[:, 1].mean() * 0 + np.median(banda[:, 1]), 0.785 * H])
        codo = hombro + (muneca - hombro) * 0.52
        codo[1] += 0.015   # el codo un poco atrás
        j["Brazo" + lado] = hombro
        j["Antebrazo" + lado] = codo
        j["Mano" + lado] = muneca
        j["punta_mano" + lado] = punta
        # Pierna: centro de los vértices de ese lado a la altura de la rodilla y del tobillo.
        rod = P[(P[:, 0] * s > 0.0) & (np.abs(P[:, 2] - 0.27 * H) < 0.012 * H)]
        tob = P[(P[:, 0] * s > 0.0) & (np.abs(P[:, 2] - 0.055 * H) < 0.01 * H)]
        rx = rod[:, 0].mean()
        j["Pierna" + lado] = np.array([rx * 0.95, rod[:, 1].mean(), 0.51 * H])
        j["Rodilla" + lado] = np.array([rx, rod[:, 1].mean() - 0.01, 0.275 * H])
        j["Pie" + lado] = np.array([tob[:, 0].mean(), tob[:, 1].mean() + 0.01, 0.055 * H])
    y_col = np.median(P[np.abs(P[:, 2] - 0.6 * H) < 0.02 * H][:, 1])
    j["Caderas"] = np.array([0.0, y_col, 0.53 * H])
    j["Columna"] = np.array([0.0, y_col, 0.585 * H])
    j["Pecho"] = np.array([0.0, y_col, 0.68 * H])
    cuello = P[np.abs(P[:, 2] - 0.835 * H) < 0.01 * H]
    j["Cuello"] = np.array([0.0, np.median(cuello[:, 1]), 0.825 * H])
    j["Cabeza"] = np.array([0.0, np.median(cuello[:, 1]), 0.86 * H])
    for k in sorted(j):
        log("articulación %-12s %s" % (k, np.round(j[k], 3).tolist()))
    return j


def armadura(j):
    arm = bpy.data.armatures.new("Esqueleto")
    ob = bpy.data.objects.new("Esqueleto", arm)
    bpy.context.scene.collection.objects.link(ob)
    activo(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    hijos = {}
    for n, p in JERARQUIA:
        if p:
            hijos.setdefault(p, []).append(n)
    for n, p in JERARQUIA:
        b = arm.edit_bones.new(n)
        b.head = Vector(j[n])
        if n.startswith("Mano"):
            b.tail = Vector(j["punta_mano" + n[-1]])
        elif n.startswith("Pie"):
            b.tail = Vector(j[n]) + Vector((0, -0.14, -0.04))
        elif n == "Cabeza":
            b.tail = Vector(j[n]) + Vector((0, 0, 0.24))
        elif n in ("Caderas", "Columna", "Pecho", "Cuello"):
            b.tail = Vector(j[{"Caderas": "Columna", "Columna": "Pecho", "Pecho": "Cuello", "Cuello": "Cabeza"}[n]])
        else:
            b.tail = Vector(j[hijos[n][0]])
        b.roll = 0.0
    for n, p in JERARQUIA:
        if p:
            arm.edit_bones[n].parent = arm.edit_bones[p]
            arm.edit_bones[n].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def pesos(ob, arm):
    """Pesos por distancia a los segmentos de hueso, mezcla suave entre los 2-3 más cercanos."""
    segs = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones}
    grupos = {n: ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n) for n in segs}

    def dist(p, a, b):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        return (p - (a + ab * t)).length

    for v in ob.data.vertices:
        p = v.co
        lado = "I" if p.x > 0 else "D"
        cand = []
        for n, (a, b) in segs.items():
            if n[-1] in "ID" and n[-1] != lado and abs(p.x) > 0.02:
                continue
            # Por encima de la cintura las piernas no influyen (la chaqueta no se estira con ellas).
            if n.startswith(("Pierna", "Rodilla", "Pie")) and p.z > 0.56 * ALTO:
                continue
            cand.append((dist(p, a, b), n))
        cand.sort()
        cand = cand[:3]
        base = cand[0][0]
        ws = [(math.exp(-((d - base) / 0.03) ** 2) if d - base < 0.09 else 0.0, n) for d, n in cand]
        tot = sum(w for w, _ in ws) or 1.0
        for w, n in ws:
            if w / tot > 0.02:
                grupos[n].add([v.index], w / tot, "REPLACE")


def bajar_brazos(ob, arm, j):
    """Gira los brazos hasta que cuelguen rectos y deja esa postura como reposo."""
    activo(arm)
    bpy.ops.object.mode_set(mode="POSE")
    for lado in ("I", "D"):
        pb = arm.pose.bones["Brazo" + lado]
        d = Vector(j["Mano" + lado]) - Vector(j["Brazo" + lado])
        ang = math.atan2(abs(d.x), -d.z)          # apertura respecto a la vertical
        s = 1 if lado == "I" else -1
        pb.rotation_mode = "XYZ"
        # Eje Z del hueso ≈ eje Y del mundo (frente); el signo cierra el brazo hacia el cuerpo.
        mat = mathutils.Matrix.Rotation(s * ang, 4, "Y")
        local = pb.bone.matrix_local.to_3x3().inverted() @ mat.to_3x3() @ pb.bone.matrix_local.to_3x3()
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = local.to_quaternion()
        log("brazo %s: apertura %.1f° → vertical" % (lado, math.degrees(ang)))
    bpy.ops.object.mode_set(mode="OBJECT")
    # Hornea la pose en la malla y en el reposo del esqueleto.
    activo(ob)
    bpy.ops.object.modifier_apply(modifier="arm")
    activo(arm)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    mod = ob.modifiers.new("arm", "ARMATURE")
    mod.object = arm
    for lado in ("I", "D"):
        h = arm.data.bones["Brazo" + lado].head_local
        m = arm.data.bones["Mano" + lado].head_local
        log("brazo %s en reposo: hombro x=%.3f, muñeca x=%.3f z=%.3f" % (lado, h.x, m.x, m.z))
        assert abs(m.x - h.x) < 0.04, "el brazo no quedó vertical"


# ------------------------------------------------------------------ zonas de color
def zonas(ob, col):
    P = np.array([tuple(v.co) for v in ob.data.vertices])
    H = ALTO
    hsv = np.array([colorsys.rgb_to_hsv(*c) for c in col])
    h, s, v = hsv[:, 0], hsv[:, 1], hsv[:, 2]
    piel = (h < 0.11) & (s > 0.18) & (s < 0.7) & (v > 0.42)
    cabeza = P[:, 2] > 0.86 * H
    pelo = cabeza & (v < 0.22) & ~piel
    blanco = (v > 0.72) & (s < 0.16)                   # vendas, placa de la banda: sin recolorear
    chaleco = (P[:, 2] > 0.5 * H) & (P[:, 2] < 0.86 * H) & (v >= 0.2) & (v < 0.55) & (s < 0.25) & ~blanco & ~piel
    ropa = ~piel & ~pelo & ~blanco & ~chaleco & (v < 0.32) & ~cabeza
    camisa = ropa & (P[:, 2] >= 0.5 * H)
    pantalon = ropa & (P[:, 2] < 0.5 * H)
    datos = np.zeros((len(P), 4), dtype=np.float32)
    datos[:, 0] = piel
    datos[:, 1] = pelo
    datos[:, 2] = chaleco
    datos[:, 3] = np.where(pantalon, 1.0, np.where(camisa, 0.5, 0.0))
    attr = ob.data.color_attributes.new("zona", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", datos.ravel())
    ob.data.color_attributes.active_color = attr
    medias = {}
    for nombre, mask in (("piel", piel), ("pelo", pelo), ("chaleco", chaleco), ("camisa", camisa), ("pantalon", pantalon)):
        medias[nombre] = [round(float(x), 3) for x in col[mask].mean(axis=0)] if mask.any() else [0.5, 0.5, 0.5]
        log("zona %-9s %5d vértices, color medio %s" % (nombre, int(mask.sum()), medias[nombre]))
    return pelo, medias


def separar_pelo(ob, pelo_v):
    """Las caras cuyo vértices son todos de pelo pasan a la malla PELO (misma textura y esqueleto)."""
    activo(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(ob.data)
    for f in bm.faces:
        f.select = all(pelo_v[v.index] for v in f.verts)
    bmesh.update_edit_mesh(ob.data)
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    nuevo = [o for o in bpy.context.selected_objects if o != ob][0]
    nuevo.name = "PELO"
    log("pelo separado: %d caras" % len(nuevo.data.polygons))
    return nuevo


# ------------------------------------------------------------------ emblema de la espalda
def parche_emblema(ob, arm):
    """Rejilla proyectada sobre la espalda (rayos desde atrás, +Y), con UV 0..1 y los pesos del cuerpo."""
    bvh = BVHTree.FromObject(ob, bpy.context.evaluated_depsgraph_get())
    H = ALTO
    n = 10
    ancho, alto, zc = 0.11 * H, 0.11 * H, 0.70 * H
    verts, uvs, idx = [], [], {}
    for i in range(n + 1):
        for k in range(n + 1):
            x = -ancho / 2 + ancho * i / n
            z = zc - alto / 2 + alto * k / n
            loc, nor, fi, d = bvh.ray_cast(Vector((x, 1.0, z)), Vector((0, -1, 0)))
            if loc is None:
                loc, nor = Vector((x, 0.1, z)), Vector((0, 1, 0))
            idx[(i, k)] = len(verts)
            verts.append(loc + nor * 0.006)
            uvs.append((1.0 - i / n, k / n))   # vista desde atrás: x invertida
    caras = [(idx[(i, k)], idx[(i + 1, k)], idx[(i + 1, k + 1)], idx[(i, k + 1)]) for i in range(n) for k in range(n)]
    me = bpy.data.meshes.new("emblema")
    me.from_pydata([tuple(v) for v in verts], [], caras)
    uv = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        for li in p.loop_indices:
            uv.data[li].uv = uvs[me.loops[li].vertex_index]
    me.materials.append(bpy.data.materials.new("emblema"))
    pa = bpy.data.objects.new("EMBLEMA", me)
    bpy.context.scene.collection.objects.link(pa)
    for g in ("Pecho", "Columna"):
        pa.vertex_groups.new(name=g)
    for v in me.vertices:
        w = min(max((v.co.z - 0.62 * H) / (0.1 * H), 0.0), 1.0)
        pa.vertex_groups["Pecho"].add([v.index], w, "REPLACE")
        pa.vertex_groups["Columna"].add([v.index], 1.0 - w, "REPLACE")
    pa.parent = arm
    mod = pa.modifiers.new("arm", "ARMATURE")
    mod.object = arm
    return pa


def medidas_cabeza(ob, arm):
    """Nudo de la banda (atrás de la cabeza, a la altura de la placa) y ojos, relativos al hueso Cabeza (en Godot)."""
    P = np.array([tuple(v.co) for v in ob.data.vertices])
    H = ALTO
    cab = Vector(arm.data.bones["Cabeza"].head_local)
    zb = 0.925 * H
    banda = P[np.abs(P[:, 2] - zb) < 0.008 * H]
    atras = banda[:, 1].max()
    frente = banda[:, 1].min()
    nudo = Vector((0.0, atras + 0.012, zb)) - cab
    ze = 0.905 * H
    cara = P[(np.abs(P[:, 2] - ze) < 0.006 * H) & (np.abs(P[:, 0]) < 0.04 * H)]
    yf = cara[:, 1].min()
    ojo = Vector((0.034 * H / 1.0 * 0.55, yf - 0.004, ze)) - cab

    def g(v):
        return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]
    return {"nudo": g(nudo), "ojo": g(ojo), "profundidad_cabeza": round(float(atras - frente), 4)}


def main():
    ob = importar()
    img, px = textura(ob)
    col = color_vertices(ob, px)
    j = articulaciones(ob)
    arm = armadura(j)
    pesos(ob, arm)
    ob.parent = arm
    mod = ob.modifiers.new("arm", "ARMATURE")
    mod.object = arm
    bajar_brazos(ob, arm, j)
    pelo_v, medias = zonas(ob, col)
    pelo = separar_pelo(ob, pelo_v)
    pa = parche_emblema(ob, arm)
    med = medidas_cabeza(ob, arm)
    for o in (ob, pelo):
        o.data.materials[0].name = "ninja"
    # Textura a 1024 px para el celular (a la distancia de la cámara de juego no se nota la diferencia).
    if img is not None and img.size[0] > 1024:
        img.scale(1024, 1024)
    activo(arm, ob, pelo, pa)
    ruta = os.path.join(RAIZ, "assets", "modelos", "ninja_ia.glb")
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", use_selection=True, export_skins=True, export_yup=True,
                              export_animations=False, export_def_bones=False, export_image_format="AUTO",
                              export_vertex_color="ACTIVE", export_all_vertex_colors=True)
    tris = sum(len(p.vertices) - 2 for o in (ob, pelo) for p in o.data.polygons)
    g = json.load(open(os.path.join(RAIZ, "data", "graficos.json"), encoding="utf-8"))
    g["ninja_ia"] = {"_nota": "Generado por tools/blender/ninja_ia.py: colores originales de cada zona (sRGB) y medidas de la cabeza (m, relativas al hueso Cabeza).",
                     "zonas": medias, "triangulos": tris, **med}
    json.dump(g, open(os.path.join(RAIZ, "data", "graficos.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    log("listo: %d triángulos → %s" % (tris, ruta), med)


if __name__ == "__main__":
    main()
