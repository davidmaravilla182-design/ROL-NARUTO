"""Ninja por piezas: cuerpo base de Meshy + 4 peinados de Meshy + 4 prendas hechas aquí, todo sobre el
esqueleto de 17 huesos del juego (mismo armado que tools/blender/ninja_ia.py).

- Cuerpo (referencias/modelos-ia/meshy/cuerpo_base/modelo.glb): ropa interior negra, vendas, sandalias, calvo.
  Zonas de color por vértice (R piel, A ropa: 0,5 camisa / 1 pantalón) para recolorear; placa de la banda repintada
  con las cuatro líneas de la aldea.
- Peinados (referencias/modelos-ia/meshy/pelo_*/modelo.glb): escalados a la cabeza, reducidos y pegados al hueso Cabeza.
- Prendas: se copian las caras del cuerpo de la zona que cubren (con sus mismos pesos, así se deforman igual que el
  cuerpo y no lo atraviesan) y se inflan unos centímetros; el impermeable lleva faldón y la capa es una lámina en la
  espalda con capucha caída, con pesos por altura.
- Un parche de emblema por prenda (y uno para el cuerpo), proyectado sobre la espalda de esa pieza.

Salida: assets/modelos/ninja_piezas.glb y data/graficos.json -> "ninja_piezas".
Uso: /tmp/claude-0/venvbpy/v/bin/python -I tools/blender/ninja_piezas.py
"""
import bpy, bmesh, math, os, sys, json
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ninja_ia as N  # noqa: E402

RAIZ = N.RAIZ
M = os.path.join(RAIZ, "referencias", "modelos-ia", "meshy")
H = N.ALTO
PEINADOS = ["puntas", "corto", "largo", "coleta"]
BRAZOS = ("BrazoI", "BrazoD", "AntebrazoI", "AntebrazoD", "ManoI", "ManoD")


def log(*a):
    print("[ninja_piezas]", *a, flush=True)


def peso(ob, v, grupos):
    tot = 0.0
    for g in v.groups:
        if ob.vertex_groups[g.group].name in grupos:
            tot += g.weight
    return tot


# ------------------------------------------------------------------ cuerpo
def zonas_cuerpo(ob, col):
    import colorsys
    P = np.array([tuple(v.co) for v in ob.data.vertices])
    hsv = np.array([colorsys.rgb_to_hsv(*c) for c in col])
    h, s, v = hsv[:, 0], hsv[:, 1], hsv[:, 2]
    piel = (h < 0.11) & (s > 0.15) & (s < 0.7) & (v > 0.4)
    ropa = ~piel & (v < 0.3) & (P[:, 2] < 0.84 * H) & (P[:, 2] > 0.09 * H)
    camisa = ropa & (P[:, 2] >= 0.5 * H)
    pantalon = ropa & (P[:, 2] < 0.5 * H)
    datos = np.zeros((len(P), 4), dtype=np.float32)
    datos[:, 0] = piel
    datos[:, 3] = np.where(pantalon, 1.0, np.where(camisa, 0.5, 0.0))
    attr = ob.data.color_attributes.new("zona", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", datos.ravel())
    ob.data.color_attributes.active_color = attr
    medias = {}
    for nombre, mask in (("piel", piel), ("camisa", camisa), ("pantalon", pantalon)):
        medias[nombre] = [round(float(x), 3) for x in col[mask].mean(axis=0)] if mask.any() else [0.5, 0.5, 0.5]
        log("zona %-9s %5d vértices" % (nombre, int(mask.sum())))
    medias["pelo"] = [0.1, 0.1, 0.12]
    medias["chaleco"] = [0.3, 0.35, 0.3]
    return medias


def repintar_placa(ob, img):
    """La placa de metal de la banda (frente, a la altura de la frente, gris claro) con las cuatro líneas de la aldea."""
    if img is None:
        return
    w, hh = img.size
    px = np.empty(w * hh * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(hh, w, 4)
    me = ob.data
    uv = me.uv_layers.active.data
    us, vs = [], []
    for li, l in enumerate(me.loops):
        co = me.vertices[l.vertex_index].co
        if abs(co.z - 0.925 * H) < 0.012 * H and abs(co.x) < 0.03 * H and co.y < CABEZA["frente_y"] + 0.012:
            u, v = uv[li].uv
            x, y = int(u % 1 * w), int(v % 1 * hh)
            c = px[min(y, hh - 1), min(x, w - 1), :3]
            if c.mean() > 0.45 and c.max() - c.min() < 0.12:
                us.append(u % 1)
                vs.append(v % 1)
    if len(us) < 6:
        log("placa no encontrada en la textura")
        return
    u0, u1 = np.percentile(us, 5), np.percentile(us, 95)
    v0, v1 = np.percentile(vs, 5), np.percentile(vs, 95)
    if u1 - u0 > 0.12 or v1 - v0 > 0.12:
        log("placa: región UV demasiado grande (%.2f × %.2f), no se repinta" % (u1 - u0, v1 - v0))
        return
    x0, x1, y0, y1 = int(u0 * w), int(u1 * w), int(v0 * hh), int(v1 * hh)
    metal = np.median(px[y0:y1, x0:x1, :3].reshape(-1, 3), axis=0)
    px[y0:y1, x0:x1, :3] = metal
    for k in range(4):
        cx = x0 + (x1 - x0) * (0.2 + 0.2 * k)
        a = max(1, int((x1 - x0) * 0.035))
        px[y0 + (y1 - y0) // 6: y1 - (y1 - y0) // 6, int(cx - a): int(cx + a), :3] = metal * 0.25
    img.pixels.foreach_set(px.ravel())
    img.update()
    log("placa repintada: uv %.3f-%.3f × %.3f-%.3f" % (u0, u1, v0, v1))


# ------------------------------------------------------------------ peinados
def cabeza_caja(ob):
    P = np.array([tuple(v.co) for v in ob.data.vertices])
    c = P[P[:, 2] > 0.875 * H]
    return c.min(axis=0), c.max(axis=0)


def peinado(nombre, arm, caja):
    ruta = os.path.join(M, "pelo_" + nombre, "modelo.glb")
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ruta)
    nuevos = [o for o in bpy.data.objects if o not in antes and o.type == "MESH"]
    for o in bpy.data.objects:
        if o not in antes and o.type != "MESH":
            bpy.data.objects.remove(o)
    N.activo(nuevos[0], *nuevos[1:])
    if len(nuevos) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = "PELO_" + nombre
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    P = np.array([tuple(v.co) for v in o.data.vertices])
    mn, mx = P.min(axis=0), P.max(axis=0)
    cmn, cmx = caja
    ancho_cabeza = cmx[0] - cmn[0]
    # Escala por el ancho de la parte alta (solo pelo; el busto del maniquí es más ancho).
    alto = mx[2] - mn[2]
    copa = P[P[:, 2] > mx[2] - alto * 0.22]
    ancho_copa = copa[:, 0].max() - copa[:, 0].min()
    esc = ancho_cabeza * {"puntas": 1.55, "corto": 1.28, "largo": 1.2, "coleta": 1.2}.get(nombre, 1.25) / ancho_copa
    centro_xy = Vector(((copa[:, 0].max() + copa[:, 0].min()) / 2, (copa[:, 1].max() + copa[:, 1].min()) / 2, mx[2]))
    destino = Vector(((cmn[0] + cmx[0]) / 2, (cmn[1] + cmx[1]) / 2 + 0.008, cmx[2] + {"puntas": 0.15, "corto": 0.035}.get(nombre, 0.025)))
    for v in o.data.vertices:
        v.co = (v.co - centro_xy) * esc + destino
    o.data.update()
    recortar_maniqui(o, nombre)
    # Reducido a ~2.500 triángulos para el celular.
    t = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if t > 2600:
        md = o.modifiers.new("dec", "DECIMATE")
        md.ratio = 2500 / t
        bpy.ops.object.modifier_apply(modifier="dec")
    o.data.materials.clear()
    o.data.materials.append(bpy.data.materials.new("pelo"))
    g = o.vertex_groups.new(name="Cabeza")
    g.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
    o.parent = arm
    mod = o.modifiers.new("arm", "ARMATURE")
    mod.object = arm
    log("peinado %s: escala %.3f, %d triángulos" % (nombre, esc, sum(len(p.vertices) - 2 for p in o.data.polygons)))
    return o


CUERPO_BVH = None
CABEZA = {}


def recortar_maniqui(o, nombre):
    """Quita la cara, el cráneo y el busto del maniquí que Meshy pone debajo del pelo: todo lo que queda dentro del
    cuerpo o pegado a él (cara y hombros), y lo que cae por debajo de la barbilla salvo mechones de atrás/lados."""
    bvh = CUERPO_BVH
    zb = CABEZA["barbilla"]
    zc = CABEZA["ceja"]
    yc = CABEZA["centro_y"]
    quitar = set()
    for v in o.data.vertices:
        loc, nor, fi, d = bvh.find_nearest(v.co)
        if loc is None:
            continue
        dentro = (v.co - loc).dot(nor) < 0.0
        if v.co.z > zc + 0.01:
            continue   # coronilla: el pelo se queda aunque toque el cráneo (lo de dentro no se ve)
        # Cara del maniquí: todo lo que está delante del plano de la cara, entre la barbilla y la ceja.
        cara = v.co.z < zc + 0.01 and v.co.y < CABEZA["frente_y"] + 0.045 and abs(v.co.x) < CABEZA["ancho"] * 0.42
        hombros = v.co.z < zb and d < 0.045
        if dentro or d < 0.012 or cara or hombros:
            quitar.add(v.index)
        # Debajo de la barbilla solo quedan mechones largos detrás o a los lados (largo y coleta).
        if v.co.z < zb - 0.02 and (nombre in ("puntas", "corto") or v.co.y < yc - 0.03):
            quitar.add(v.index)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.verts.ensure_lookup_table()
    malas = [f for f in bm.faces if any(v.index in quitar for v in f.verts)]
    bmesh.ops.delete(bm, geom=malas, context="FACES")
    sueltos = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=sueltos, context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    log("peinado %s: recortadas %d de %d vértices del maniquí" % (nombre, len(quitar), len(o.data.vertices) + len(quitar)))


# ------------------------------------------------------------------ prendas
def copiar_caras(cuerpo, nombre, cond, inflar, suavizar=4):
    """Copia las caras del cuerpo que cumplen cond(v) en todos sus vértices; las infla 'inflar' m por la normal."""
    o = cuerpo.copy()
    o.data = cuerpo.data.copy()
    o.name = nombre
    bpy.context.scene.collection.objects.link(o)
    for m in list(o.modifiers):
        if m.type != "ARMATURE":
            o.modifiers.remove(m)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    dl = bm.verts.layers.deform.active
    nombres = {i: g.name for i, g in enumerate(o.vertex_groups)}

    def pesos_v(v):
        return {nombres[k]: w for k, w in v[dl].items()} if dl else {}
    malas = [f for f in bm.faces if not all(cond(v.co, pesos_v(v)) for v in f.verts)]
    bmesh.ops.delete(bm, geom=malas, context="FACES")
    for v in bm.verts:
        v.co += v.normal * inflar
    # Tela lisa: se suavizan los relieves del cuerpo (músculos) sin mover los bordes.
    interiores = [v for v in bm.verts if not v.is_boundary]
    for _ in range(suavizar):
        bmesh.ops.smooth_vert(bm, verts=interiores, factor=0.6, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(o.data)
    bm.free()
    while o.data.color_attributes:
        o.data.color_attributes.remove(o.data.color_attributes[0])
    o.data.materials.clear()
    o.data.materials.append(bpy.data.materials.new("prenda"))
    sol = o.modifiers.new("grueso", "SOLIDIFY")
    sol.thickness = 0.008
    sol.offset = 1.0
    N.activo(o)
    bpy.ops.object.modifier_move_to_index(modifier="grueso", index=0)
    bpy.ops.object.modifier_apply(modifier="grueso")
    return o


def brazo(p):
    return sum(p.get(b, 0.0) for b in BRAZOS)


def faldon(cuerpo, arm, nombre, z_arriba, z_abajo, holgura, abierto_frente=False):
    """Faldón cónico (impermeable) con pesos: caderas en el centro, cada pierna a su lado."""
    P = np.array([tuple(v.co) for v in cuerpo.data.vertices])
    banda = P[np.abs(P[:, 2] - z_arriba) < 0.01 * H]
    rx = np.percentile(np.abs(banda[:, 0]), 96) * holgura
    ry = np.percentile(np.abs(banda[:, 1] - banda[:, 1].mean()), 96) * holgura * 1.1
    cy = banda[:, 1].mean()
    n, filas = 28, 7
    verts, caras = [], []
    for f in range(filas + 1):
        t = f / filas
        z = z_arriba + (z_abajo - z_arriba) * t
        k = 1.0 + 0.35 * t
        for i in range(n):
            a = 2 * math.pi * i / n
            verts.append((math.sin(a) * rx * k, cy + math.cos(a) * ry * k, z))
    for f in range(filas):
        for i in range(n):
            if abierto_frente and i in (n // 2 - 1, n // 2):
                continue   # abertura al frente (a = π mira a -Y)
            a, b = f * n + i, f * n + (i + 1) % n
            caras.append((a, b, b + n, a + n))
    me = bpy.data.meshes.new(nombre)
    me.from_pydata(verts, [], caras)
    o = bpy.data.objects.new(nombre, me)
    bpy.context.scene.collection.objects.link(o)
    for g in ("Caderas", "PiernaI", "PiernaD", "RodillaI", "RodillaD"):
        o.vertex_groups.new(name=g)
    for v in me.vertices:
        t = (z_arriba - v.co.z) / (z_arriba - z_abajo)
        lado = "I" if v.co.x > 0 else "D"
        piernas = min(1.0, abs(v.co.x) / rx) * 0.75 * t
        o.vertex_groups["Caderas"].add([v.index], 1.0 - piernas, "REPLACE")
        o.vertex_groups["Pierna" + lado].add([v.index], piernas * (1.0 - 0.4 * t), "REPLACE")
        o.vertex_groups["Rodilla" + lado].add([v.index], piernas * 0.4 * t, "REPLACE")
    me.materials.append(bpy.data.materials.new("prenda"))
    sol = o.modifiers.new("grueso", "SOLIDIFY")
    sol.thickness = 0.008
    N.activo(o)
    bpy.ops.object.modifier_apply(modifier="grueso")
    return o


def capa(cuerpo, arm):
    """Capa: lámina detrás de la espalda (de los hombros a las corvas) que sigue el contorno, y capucha caída."""
    bvh = BVHTree.FromObject(cuerpo, bpy.context.evaluated_depsgraph_get())
    P = np.array([tuple(v.co) for v in cuerpo.data.vertices])
    hombros = P[np.abs(P[:, 2] - 0.79 * H) < 0.01 * H]
    ancho0 = np.percentile(np.abs(hombros[:, 0]), 95) * 1.05
    nx, nz = 12, 12
    z0, z1 = 0.80 * H, 0.26 * H
    verts, idx = [], {}
    for k in range(nz + 1):
        t = k / nz
        z = z0 + (z1 - z0) * t
        ancho = ancho0 * (1.0 + 0.45 * t)
        for i in range(nx + 1):
            x = -ancho + 2 * ancho * i / nx
            loc, nor, fi, d = bvh.ray_cast(Vector((x * 0.85, 1.0, z)), Vector((0, -1, 0)))
            y = (loc.y if loc is not None else 0.12) + 0.04 + 0.12 * t
            # Los bordes de la capa se curvan hacia adelante (envuelve los hombros arriba).
            borde = abs(x) / ancho
            y -= (borde ** 3) * (0.1 if t < 0.25 else 0.04)
            idx[(i, k)] = len(verts)
            verts.append((x, y, z))
    caras = [(idx[(i, k)], idx[(i, k + 1)], idx[(i + 1, k + 1)], idx[(i + 1, k)]) for k in range(nz) for i in range(nx)]
    # Capucha caída: casquete detrás del cuello.
    base = len(verts)
    cab_min, cab_max = cabeza_caja(cuerpo)
    cy = cab_max[1] + 0.02
    r = (cab_max[0] - cab_min[0]) * 0.62
    anillos, seg = 5, 14
    for a in range(anillos + 1):
        fi = math.pi * 0.5 * a / anillos
        for s in range(seg + 1):
            th = math.pi * s / seg
            verts.append((math.cos(th) * r * math.cos(fi), cy + math.sin(fi) * r * 0.55, 0.79 * H + math.sin(th) * r * 0.55 * math.cos(fi) * 0.6))
    for a in range(anillos):
        for s in range(seg):
            p0 = base + a * (seg + 1) + s
            caras.append((p0, p0 + 1, p0 + seg + 2, p0 + seg + 1))
    me = bpy.data.meshes.new("PRENDA_capa")
    me.from_pydata(verts, [], caras)
    o = bpy.data.objects.new("PRENDA_capa", me)
    bpy.context.scene.collection.objects.link(o)
    for g in ("Pecho", "Columna", "Caderas", "Cuello"):
        o.vertex_groups.new(name=g)
    for v in me.vertices:
        if v.index >= base:
            o.vertex_groups["Cuello"].add([v.index], 0.5, "REPLACE")
            o.vertex_groups["Pecho"].add([v.index], 0.5, "REPLACE")
            continue
        t = (z0 - v.co.z) / (z0 - z1)
        o.vertex_groups["Pecho"].add([v.index], max(0.0, 1.0 - t * 2.0), "REPLACE")
        o.vertex_groups["Columna"].add([v.index], max(0.0, 1.0 - abs(t - 0.5) * 2.0), "REPLACE")
        o.vertex_groups["Caderas"].add([v.index], max(0.0, t * 2.0 - 1.0), "REPLACE")
    me.materials.append(bpy.data.materials.new("prenda"))
    sol = o.modifiers.new("grueso", "SOLIDIFY")
    sol.thickness = 0.01
    N.activo(o)
    bpy.ops.object.modifier_apply(modifier="grueso")
    return o


def unir_prenda(nombre, partes, arm):
    N.activo(partes[0], *partes[1:])
    if len(partes) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = "PRENDA_" + nombre
    t = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if t > 3600:
        md = o.modifiers.new("dec", "DECIMATE")
        md.ratio = 3500 / t
        bpy.ops.object.modifier_move_to_index(modifier="dec", index=0)
        bpy.ops.object.modifier_apply(modifier="dec")
    o.parent = arm
    if not any(m.type == "ARMATURE" for m in o.modifiers):
        mod = o.modifiers.new("arm", "ARMATURE")
        mod.object = arm
    return o


def prendas(cuerpo, arm):
    res = {}
    torso = lambda co, p: 0.5 * H < co.z < 0.81 * H and brazo(p) < 0.3   # noqa: E731
    # Chaleco táctico: torso inflado + cuello alto + bolsillos al frente.
    chal = copiar_caras(cuerpo, "chaleco", torso, 0.03)
    extras = []
    for x in (-0.07, 0.07):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, -0.13, 0.68 * H))
        b = bpy.context.active_object
        b.scale = (0.07, 0.035, 0.09)
        bpy.ops.object.transform_apply(scale=True)
        extras.append(b)
    for b in extras:
        g = b.vertex_groups.new(name="Pecho")
        g.add([v.index for v in b.data.vertices], 1.0, "REPLACE")
        b.data.materials.append(bpy.data.materials.get("prenda") or bpy.data.materials.new("prenda"))
    cuello = copiar_caras(cuerpo, "cuello_chal", lambda co, p: 0.785 * H < co.z < 0.84 * H and brazo(p) < 0.2, 0.025)
    res["chaleco"] = unir_prenda("chaleco", [chal, cuello] + extras, arm)
    # Impermeable: torso y mangas hasta la muñeca + faldón hasta las rodillas, abierto al frente.
    imp = copiar_caras(cuerpo, "impermeable", lambda co, p: (0.47 * H < co.z < 0.83 * H) and p.get("ManoI", 0) + p.get("ManoD", 0) < 0.3, 0.025, suavizar=12)
    fal = faldon(cuerpo, arm, "faldon", 0.5 * H, 0.27 * H, 1.18, abierto_frente=True)
    res["impermeable"] = unir_prenda("impermeable", [imp, fal], arm)
    # Ropa ligera: camiseta holgada de manga corta + faja en la cintura.
    lig = copiar_caras(cuerpo, "ligera", lambda co, p: 0.49 * H < co.z < 0.82 * H and p.get("AntebrazoI", 0) + p.get("AntebrazoD", 0) + p.get("ManoI", 0) + p.get("ManoD", 0) < 0.3, 0.02)
    faja = copiar_caras(cuerpo, "faja", lambda co, p: 0.47 * H < co.z < 0.53 * H and brazo(p) < 0.2, 0.032)
    res["ligera"] = unir_prenda("ligera", [lig, faja], arm)
    # Capa con capucha.
    res["capa"] = unir_prenda("capa", [capa(cuerpo, arm)], arm)
    for k, o in res.items():
        log("prenda %-11s %5d triángulos" % (k, sum(len(p.vertices) - 2 for p in o.data.polygons)))
    return res


def parche(sobre, arm, nombre):
    """Parche del emblema proyectado sobre la espalda de 'sobre' (cuerpo o prenda), con pesos del pecho y la columna."""
    dg = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(sobre, dg)
    n = 10
    ancho, alto, zc = 0.11 * H, 0.11 * H, 0.70 * H
    verts, uvs, idx = [], [], {}
    for i in range(n + 1):
        for k in range(n + 1):
            x = -ancho / 2 + ancho * i / n
            z = zc - alto / 2 + alto * k / n
            loc, nor, fi, d = bvh.ray_cast(Vector((x, 1.0, z)), Vector((0, -1, 0)))
            if loc is None:
                loc, nor = Vector((x, 0.12, z)), Vector((0, 1, 0))
            idx[(i, k)] = len(verts)
            verts.append(loc + nor * 0.006)
            uvs.append((1.0 - i / n, k / n))
    caras = [(idx[(i, k)], idx[(i + 1, k)], idx[(i + 1, k + 1)], idx[(i, k + 1)]) for i in range(n) for k in range(n)]
    me = bpy.data.meshes.new(nombre)
    me.from_pydata([tuple(v) for v in verts], [], caras)
    uv = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        for li in p.loop_indices:
            uv.data[li].uv = uvs[me.loops[li].vertex_index]
    me.materials.append(bpy.data.materials.get("emblema") or bpy.data.materials.new("emblema"))
    pa = bpy.data.objects.new(nombre, me)
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


def main():
    ob = N.importar(os.path.join(M, "cuerpo_base", "modelo.glb"))
    ob.name = "CUERPO"
    img, px = N.textura(ob)
    col = N.color_vertices(ob, px)
    j = N.articulaciones(ob)
    arm = N.armadura(j)
    N.pesos(ob, arm)
    ob.parent = arm
    mod = ob.modifiers.new("arm", "ARMATURE")
    mod.object = arm
    N.bajar_brazos(ob, arm, j)
    medias = zonas_cuerpo(ob, col)
    P0 = np.array([tuple(v.co) for v in ob.data.vertices])
    cab0 = P0[P0[:, 2] > 0.84 * H]
    CABEZA["frente_y"] = float(cab0[:, 1].min())
    repintar_placa(ob, img)
    med = N.medidas_cabeza(ob, arm)
    ob.data.materials[0].name = "ninja"
    if img is not None and img.size[0] > 1024:
        img.scale(1024, 1024)
    if img is not None:
        # El GLB con JPEG incrustado no carga en Godot: se guarda como PNG y el material apunta a la copia.
        ruta_png = os.path.join("/tmp", "cuerpo_base_tex.png")
        img.filepath_raw = ruta_png
        img.file_format = "PNG"
        img.save()
        png = bpy.data.images.load(ruta_png)
        for n in ob.data.materials[0].node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image == img:
                n.image = png
    caja = cabeza_caja(ob)
    global CUERPO_BVH
    CUERPO_BVH = BVHTree.FromObject(ob, bpy.context.evaluated_depsgraph_get())
    P = np.array([tuple(v.co) for v in ob.data.vertices])
    cab = P[P[:, 2] > 0.84 * H]
    CABEZA.update({"barbilla": 0.855 * H, "ceja": 0.935 * H, "centro_y": float(np.median(cab[:, 1])),
                   "ancho": float(cab[:, 0].max() - cab[:, 0].min())})
    pelos = [peinado(p, arm, caja) for p in PEINADOS if os.path.exists(os.path.join(M, "pelo_" + p, "modelo.glb"))]
    pr = prendas(ob, arm)
    parches = [parche(ob, arm, "EMBLEMA_base")] + [parche(o, arm, "EMBLEMA_" + k) for k, o in pr.items()]
    todo = [ob] + pelos + list(pr.values()) + parches
    N.activo(arm, *todo)
    ruta = os.path.join(RAIZ, "assets", "modelos", "ninja_piezas.glb")
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", use_selection=True, export_skins=True, export_yup=True,
                              export_animations=False, export_def_bones=False, export_image_format="AUTO",
                              export_vertex_color="ACTIVE", export_all_vertex_colors=True)
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in todo}
    g = json.load(open(os.path.join(RAIZ, "data", "graficos.json"), encoding="utf-8"))
    g["ninja_piezas"] = {"_nota": "Generado por tools/blender/ninja_piezas.py: zonas del cuerpo base, medidas de la cabeza y triángulos por pieza.",
                         "zonas": medias, "triangulos": tris, **med}
    json.dump(g, open(os.path.join(RAIZ, "data", "graficos.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    log("listo →", ruta, tris)


if __name__ == "__main__":
    main()
