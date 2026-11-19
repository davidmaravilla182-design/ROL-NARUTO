"""Torre monumental a partir de los modelos generados por IA (referencias/modelos-ia/).

Geometría: Meshy (500k, mejor forma) reducida a ~30k triángulos + 2 LODs.
Color: el de TRELLIS (148k, con textura) transferido por proximidad a cada vértice de Meshy.
Ambos modelos salen de la misma imagen y, alineados con escala por eje, quedan a ~0,5 % de la
altura de distancia. Se intentó hornear a una textura UV, pero la malla de Meshy reducida se
despliega en ~9000 islas que cubren el 12 % del atlas (textura "polvo"): por eso color por vértice
+ detalle triplanar en el shader del juego (no necesita UV).

Salida:
  assets/modelos/torre_ia.glb            (objetos LOD0, LOD1, LOD2; material "torre_ia")
  (objeto VENTANAS: quads ámbar emisivos colocados por raycast sobre la fachada)
  data/escenario.json -> "torre_ia"      (medidas, ojos, lengua para la colisión)

Uso: /tmp/claude-0/venvbpy/v/bin/python tools/blender/torre_ia.py   (bpy 5.x, en segundo plano)
"""
import bpy, bmesh, mathutils, math, random, json, os, sys, time
import numpy as np
from mathutils.bvhtree import BVHTree

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REF = os.path.join(RAIZ, "referencias", "modelos-ia")
TEX = 2048
ALTO = float(os.environ.get("ALTO_TORRE", "74"))      # metros
OBJETIVO = int(os.environ.get("TRIS_TORRE", "30000"))
LODS = [10000, 3000]
T0 = time.time()


def log(*a):
    print("[torre_ia %5.0fs]" % (time.time() - T0), *a, flush=True)


def importar(f, nombre):
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(REF, f))
    o = [x for x in bpy.data.objects if x not in antes and x.type == "MESH"][0]
    o.name = nombre
    return o


def caja(o):
    bb = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
    mn = mathutils.Vector([min(v[i] for v in bb) for i in range(3)])
    mx = mathutils.Vector([max(v[i] for v in bb) for i in range(3)])
    return mn, mx


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def activo(o, *otros):
    bpy.ops.object.select_all(action="DESELECT")
    for x in otros:
        x.select_set(True)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def aplicar_mod(o, mod):
    activo(o)
    bpy.ops.object.modifier_apply(modifier=mod.name)


# ------------------------------------------------------------------ alineación
def alinear(tr, me):
    """Escala por eje de caja a caja y ajuste fino por coordenadas (distancia media al Meshy)."""
    bvh = BVHTree.FromObject(me, bpy.context.evaluated_depsgraph_get())
    mn_t, mx_t = caja(tr)
    mn_m, mx_m = caja(me)
    ct = (mn_t + mx_t) / 2
    cm = (mn_m + mx_m) / 2
    random.seed(2)
    muestra = random.sample([v.co.copy() for v in tr.data.vertices], 4000)

    def dist(x):
        d = 0.0
        for v in muestra:
            p = mathutils.Vector(((v.x - ct.x) * x[0] + cm.x + x[3], (v.y - ct.y) * x[1] + cm.y + x[4], (v.z - ct.z) * x[2] + cm.z + x[5]))
            d += bvh.find_nearest(p)[3]
        return d / len(muestra)

    x = [(mx_m[i] - mn_m[i]) / (mx_t[i] - mn_t[i]) for i in range(3)] + [0.0, 0.0, 0.0]
    mejor = dist(x)
    paso = [0.05, 0.05, 0.05, 0.02, 0.02, 0.02]
    for _ in range(6):
        for i in range(6):
            for sg in (1, -1):
                y = list(x)
                y[i] += sg * paso[i]
                d = dist(y)
                if d < mejor:
                    mejor, x = d, y
        paso = [p * 0.6 for p in paso]
    log("alineación TRELLIS→Meshy: distancia media %.4f (altura %.3f)" % (mejor, mx_m.z - mn_m.z), [round(v, 3) for v in x])
    m = tr.data
    for v in m.vertices:
        v.co = mathutils.Vector(((v.co.x - ct.x) * x[0] + cm.x + x[3], (v.co.y - ct.y) * x[1] + cm.y + x[4], (v.co.z - ct.z) * x[2] + cm.z + x[5]))
    m.update()
    return mejor


# ------------------------------------------------------------------ reducción
def limpiar(o):
    """Une vértices duplicados y quita caras degeneradas y sueltas (si no, el colapso se atasca)."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-6)
    sueltos = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=sueltos, context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    o.data.validate()
    o.data.update()


def reducir(o, objetivo):
    """Disuelve primero las zonas planas (el modelo es muy cuadrado) y colapsa hasta el objetivo."""
    limpiar(o)
    t0 = tris(o)
    md = o.modifiers.new("plano", "DECIMATE")
    md.decimate_type = "DISSOLVE"
    md.angle_limit = math.radians(1.0)
    aplicar_mod(o, md)
    tri = o.modifiers.new("tri", "TRIANGULATE")
    aplicar_mod(o, tri)
    t1 = tris(o)
    if t1 > objetivo:
        mc = o.modifiers.new("colapso", "DECIMATE")
        mc.decimate_type = "COLLAPSE"
        mc.ratio = objetivo / t1
        aplicar_mod(o, mc)
    log("reducción %s: %d → plano %d → %d triángulos" % (o.name, t0, t1, tris(o)))


def copia(o, nombre):
    n = o.copy()
    n.data = o.data.copy()
    n.name = nombre
    bpy.context.scene.collection.objects.link(n)
    return n


def colapsar(o, objetivo):
    limpiar(o)
    for _ in range(4):
        if tris(o) <= objetivo * 1.1:
            break
        mc = o.modifiers.new("colapso", "DECIMATE")
        mc.decimate_type = "COLLAPSE"
        mc.ratio = min(1.0, objetivo / max(tris(o), 1))
        aplicar_mod(o, mc)
        limpiar(o)
    log("LOD %s: %d triángulos" % (o.name, tris(o)))


# ------------------------------------------------------------------ color por vértice
def textura_trellis(tr):
    for n in tr.data.materials[0].node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image is not None and n.image.colorspace_settings.name != "Non-Color":
            return pixeles(n.image)
    return None


def pixeles(img):
    a = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(img.size[1], img.size[0], 4)


def transferir_color(bajo, tr, px):
    """Cada vértice toma el color de TRELLIS en el punto más cercano (UV baricéntricas) y se suaviza un poco.
    Se usa color por vértice porque la malla de Meshy reducida no admite un despliegue UV limpio
    (miles de islas diminutas): la textura horneada quedaría como polvo."""
    bvh = BVHTree.FromObject(tr, bpy.context.evaluated_depsgraph_get())
    m = tr.data
    uvl = m.uv_layers.active.data
    h, w = px.shape[:2]
    tri_uv = {}
    for p in m.polygons:
        tri_uv[p.index] = ([m.vertices[m.loops[li].vertex_index].co for li in p.loop_indices], [uvl[li].uv.copy() for li in p.loop_indices])
    bm = bajo.data
    col = np.zeros((len(bm.vertices), 3), dtype=np.float32)
    for v in bm.vertices:
        loc, nor, fi, d = bvh.find_nearest(v.co)
        if fi is None:
            continue
        vs, uvs = tri_uv[fi]
        b = mathutils.geometry.barycentric_transform(loc, vs[0], vs[1], vs[2], mathutils.Vector((1, 0, 0)), mathutils.Vector((0, 1, 0)), mathutils.Vector((0, 0, 1))) if len(vs) == 3 else None
        if b is None:
            uv = uvs[0]
        else:
            uv = uvs[0] * b.x + uvs[1] * b.y + uvs[2] * b.z
        x = min(max(int(uv.x % 1.0 * w), 0), w - 1)
        y = min(max(int(uv.y % 1.0 * h), 0), h - 1)
        col[v.index] = px[y, x, :3]
    # Suavizado de vecinos (2 pasadas) para quitar el ruido de vóxel de TRELLIS.
    vecinos = [[] for _ in bm.vertices]
    for e in bm.edges:
        a, b = e.vertices
        vecinos[a].append(b)
        vecinos[b].append(a)
    for _ in range(2):
        nuevo = col.copy()
        for i, vs in enumerate(vecinos):
            if vs:
                nuevo[i] = col[i] * 0.5 + col[vs].mean(axis=0) * 0.5
        col = nuevo
    attr = bm.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    datos = np.ones((len(bm.vertices), 4), dtype=np.float32)
    datos[:, :3] = col
    attr.data.foreach_set("color", datos.ravel())
    log("color transferido a %s (%d vértices, media %s)" % (bajo.name, len(bm.vertices), np.round(col.mean(axis=0), 3).tolist()))
    return col


def remallar(o, voxel, objetivo):
    """LOD lejano: remallado por vóxeles (une miles de piezas sueltas) y colapso hasta el objetivo."""
    mr = o.modifiers.new("vox", "REMESH")
    mr.mode = "VOXEL"
    mr.voxel_size = voxel
    aplicar_mod(o, mr)
    colapsar(o, objetivo)


# ------------------------------------------------------------------ análisis de TRELLIS (ojos)
def colores_vertices(tr):
    """Color de la textura de TRELLIS en cada vértice (por las UV de sus esquinas)."""
    img = None
    for n in tr.data.materials[0].node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image is not None:
            # La de color es la que no está en espacio no-color.
            if n.image.colorspace_settings.name != "Non-Color":
                img = n.image
    px = pixeles(img)
    h, w = px.shape[:2]
    m = tr.data
    uv = m.uv_layers.active.data
    col = np.zeros((len(m.vertices), 3), dtype=np.float32)
    cnt = np.zeros(len(m.vertices), dtype=np.float32)
    for li, l in enumerate(m.loops):
        u, v = uv[li].uv
        x = min(max(int(u % 1.0 * w), 0), w - 1)
        y = min(max(int(v % 1.0 * h), 0), h - 1)
        col[l.vertex_index] += px[y, x, :3]
        cnt[l.vertex_index] += 1
    return col / np.maximum(cnt, 1)[:, None]


def ojos(tr):
    col = colores_vertices(tr)
    azul = (col[:, 2] > col[:, 0] + 0.12) & (col[:, 2] > col[:, 1] + 0.04) & (col[:, 2] > 0.25)
    pos = np.array([tuple(v.co) for v in tr.data.vertices], dtype=np.float32)
    nor = np.array([tuple(v.normal) for v in tr.data.vertices], dtype=np.float32)
    sel = np.where(azul)[0]
    log("vértices azules (ojos): %d" % len(sel))
    res = []
    for lado in (-1, 1):
        idx = sel[(pos[sel, 0] * lado) > 0]
        if len(idx) < 5:
            continue
        p = pos[idx]
        # Solo la zona alta de la fachada (descarta reflejos azules sueltos).
        z_med = np.median(p[:, 2])
        idx = idx[np.abs(p[:, 2] - z_med) < 0.06]
        p = pos[idx]
        c = p.mean(axis=0)
        n = nor[idx].mean(axis=0)
        n /= max(np.linalg.norm(n), 1e-6)
        r = float(np.percentile(np.linalg.norm(p - c, axis=1), 85))
        res.append({"centro": c.tolist(), "normal": n.tolist(), "radio": r})
    return res


def caja_lengua(me):
    """La lengua es lo que sobresale hacia el frente (-Y) por delante de la fachada."""
    pos = np.array([tuple(v.co) for v in me.data.vertices], dtype=np.float32)
    y_min = pos[:, 1].min()
    fachada = np.percentile(pos[:, 1], 6)
    sel = pos[pos[:, 1] < fachada - (fachada - y_min) * 0.35]
    mn = sel.min(axis=0)
    mx = sel.max(axis=0)
    log("lengua: x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f (%d vértices)" % (mn[0], mx[0], mn[1], mx[1], mn[2], mx[2], len(sel)))
    return mn.tolist(), mx.tolist()


# ------------------------------------------------------------------ ventanas
def ventanas(me, tr, px, cara_x, cara_angulo, rng):
    """Ventanas ámbar por raycast sobre la fachada: filas cada ~4 m, evitando el rostro, la lengua,
    las tuberías (rojas en TRELLIS) y las superficies no verticales. Devuelve quads [(centro, normal)]."""
    bvh = BVHTree.FromObject(me, bpy.context.evaluated_depsgraph_get())
    bvh_t = BVHTree.FromObject(tr, bpy.context.evaluated_depsgraph_get())
    mn, mx = caja(me)
    c = (mn + mx) / 2
    alto = mx.z - mn.z
    res = []
    fila = 0
    z = mn.z + alto * 0.08
    while z < mn.z + alto * 0.86:
        n_ang = 64
        for k in range(n_ang):
            a = 2 * math.pi * (k + 0.5 * (fila % 2)) / n_ang
            d = mathutils.Vector((math.cos(a), math.sin(a), 0))
            # Sector del rostro (frente, -Y) entre el 40 % y el 82 % de la altura: sin ventanas.
            ang_cara = math.degrees(abs((a - cara_angulo + math.pi) % (2 * math.pi) - math.pi))
            frac = (z - mn.z) / alto
            if ang_cara < 55 and 0.38 < frac < 0.84:
                continue
            if rng.random() > 0.42:
                continue
            origen = mathutils.Vector((c.x, c.y, z)) + d * (mx.x - mn.x + mx.y - mn.y)
            loc, nor, fi, dist = bvh.ray_cast(origen, -d)
            if loc is None or abs(nor.z) > 0.25 or nor.dot(d) < 0.55:
                continue
            # Pared plana alrededor (descarta barandales, agujas y bordes): 4 rayos vecinos a la misma profundidad.
            lado = mathutils.Vector((-d.y, d.x, 0))
            plano = True
            for off in (lado * 0.012, -lado * 0.012, mathutils.Vector((0, 0, 0.008)), mathutils.Vector((0, 0, -0.008))):
                l2, n2, f2, d2 = bvh.ray_cast(origen + off, -d)
                if l2 is None or abs(d2 - dist) > 0.006:
                    plano = False
                    break
            if not plano:
                continue
            # Color de TRELLIS cerca: si es rojizo (tubería) u oscuro, no hay ventana.
            l2, n2, f2, d2 = bvh_t.find_nearest(loc)
            res.append((loc + nor * 0.002, nor.normalized()))
        fila += 1
        z += alto * 0.055
    log("ventanas colocadas: %d" % len(res))
    return res


def malla_ventanas(lista, ancho, alto_v):
    me = bpy.data.meshes.new("ventanas")
    verts = []
    caras = []
    for centro, n in lista:
        lado = mathutils.Vector((-n.y, n.x, 0)).normalized()
        arriba = mathutils.Vector((0, 0, 1))
        base = len(verts)
        for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            verts.append(centro + lado * sx * ancho * 0.5 + arriba * sz * alto_v * 0.5)
        caras.append((base, base + 1, base + 2, base + 3))
    me.from_pydata([tuple(v) for v in verts], [], caras)
    me.update()
    o = bpy.data.objects.new("VENTANAS", me)
    bpy.context.scene.collection.objects.link(o)
    mat = bpy.data.materials.new("ventana")
    o.data.materials.append(mat)
    return o


# ------------------------------------------------------------------ plataforma de la lengua
def plataforma_lengua(me, lengua):
    """Altura de la superficie de la lengua: rayos hacia abajo sobre su zona delantera."""
    bvh = BVHTree.FromObject(me, bpy.context.evaluated_depsgraph_get())
    mn, mx = lengua
    alturas = []
    for i in range(9):
        for j in range(5):
            x = mn[0] + (mx[0] - mn[0]) * (0.15 + 0.7 * i / 8)
            y = mn[1] + (mx[1] - mn[1]) * (0.05 + 0.5 * j / 4)   # mitad delantera (la que sobresale)
            loc, nor, fi, d = bvh.ray_cast(mathutils.Vector((x, y, mx[2] + 0.2)), mathutils.Vector((0, 0, -1)))
            if loc is not None and nor.z > 0.6:
                alturas.append(loc.z)
    h = float(np.median(alturas)) if alturas else mx[2]
    log("lengua: %d impactos, superficie a z=%.3f" % (len(alturas), h))
    return h


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(7)
    tr = importar("torre.glb", "trellis")
    me = importar("torre-meshy-sin-textura-500k.glb", "meshy_alto")
    dist = alinear(tr, me)
    px = textura_trellis(tr)
    info_ojos = ojos(tr)
    lengua = caja_lengua(me)
    h_lengua = plataforma_lengua(me, lengua)
    mn, mx = caja(me)
    alto_n = mx.z - mn.z
    esc = ALTO / alto_n
    # Rostro: hacia -Y; centro en x según los ojos.
    cara_x = sum(o["centro"][0] for o in info_ojos) / max(len(info_ojos), 1)
    lista_v = ventanas(me, tr, px, cara_x, -math.pi / 2, rng)
    # Ojos: ajustados con un rayo sobre la geometría de Meshy (los de TRELLIS quedan a ~0,5 % de distancia).
    bvh_me = BVHTree.FromObject(me, bpy.context.evaluated_depsgraph_get())
    for o in info_ojos:
        c = mathutils.Vector(o["centro"])
        n = mathutils.Vector(o["normal"])
        n.z = 0
        n.normalize()
        loc, nor, fi, d = bvh_me.ray_cast(c + n * 0.08, -n)
        if loc is not None:
            o["centro"] = list(loc)
            o["normal"] = list(nor.normalized())
    vent = malla_ventanas(lista_v, 1.3 / esc, 0.75 / esc)
    lod0 = copia(me, "LOD0")
    reducir(lod0, OBJETIVO)
    lod1 = copia(me, "LOD1")
    remallar(lod1, 0.35 / esc, LODS[0])
    lod2 = copia(me, "LOD2")
    remallar(lod2, 0.9 / esc, LODS[1])
    for o in (lod0, lod1, lod2):
        transferir_color(o, tr, px)
        o.data.materials.clear()
        mat = bpy.data.materials.new("torre_ia")
        o.data.materials.append(mat)
        # Sombreado: suave salvo aristas marcadas (> 40°).
        activo(o)
        bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
        for md in list(o.modifiers):
            aplicar_mod(o, md)
    centro = mathutils.Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    for o in (lod0, lod1, lod2, vent):
        for v in o.data.vertices:
            v.co = (v.co - centro) * esc
        o.data.update()
    for o in list(bpy.data.objects):
        if o not in (lod0, lod1, lod2, vent):
            bpy.data.objects.remove(o)
    activo(lod0, lod1, lod2, vent)
    bpy.ops.export_scene.gltf(filepath=os.path.join(RAIZ, "assets", "modelos", "torre_ia.glb"), use_selection=True,
                              export_format="GLB", export_image_format="NONE", export_apply=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=True)

    # Blender (x, y, z) -> Godot (x, z, -y); el rostro mira a -Y de Blender = +Z de Godot.
    def godot(p):
        q = (mathutils.Vector(p) - centro) * esc
        return [round(q.x, 3), round(q.z, 3), round(-q.y, 3)]

    gl_mn = godot(lengua[0])
    gl_mx = godot(lengua[1])
    datos = {
        "_nota": "Generado por tools/blender/torre_ia.py: torre de los modelos IA (coordenadas locales de Godot, metros).",
        "alto": ALTO,
        "ancho": round((mx.x - mn.x) * esc, 2),
        "fondo": round((mx.y - mn.y) * esc, 2),
        "triangulos": [tris(lod0), tris(lod1), tris(lod2)],
        "ventanas": len(lista_v),
        "distancia_alineacion": round(dist / alto_n, 4),
        "ojos": [{"centro": godot(o["centro"]), "normal": [round(o["normal"][0], 3), round(o["normal"][2], 3), round(-o["normal"][1], 3)],
                  "radio": round(o["radio"] * esc, 2)} for o in info_ojos],
        "lengua": {"min": [min(a, b) for a, b in zip(gl_mn, gl_mx)], "max": [max(a, b) for a, b in zip(gl_mn, gl_mx)],
                   "superficie": round((h_lengua - centro.z) * esc, 2)},
    }
    ruta = os.path.join(RAIZ, "data", "escenario.json")
    esc_json = json.load(open(ruta, encoding="utf-8"))
    esc_json["torre_ia"] = datos
    json.dump(esc_json, open(ruta, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    log("listo:", json.dumps(datos, ensure_ascii=False))


main()
