"""Construcción de geometría por código con UVs a escala de mundo.

Cada pieza se crea directamente con su tamaño real, se le calculan UVs (proyección por cara
para cajas/cilindros, barrido para tuberías) y luego se coloca. Los materiales llevan el nombre
de la textura (concreto, lamina, tuberia, techo, suelo, rejilla) o de un material especial
(ventana, luz, oscuro, cable) que Godot sustituye por su shader.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

# Metros que cubre una repetición de cada textura (densidad de texel coherente).
TILE = {"concreto": 6.0, "lamina": 4.0, "tuberia": 3.0, "techo": 3.0, "suelo": 4.0, "rejilla": 1.5,
        "ventana": 1.0, "luz": 1.0, "oscuro": 2.0, "cable": 1.0, "agua": 4.0}


def material(nombre):
    m = bpy.data.materials.get(nombre)
    if m is None:
        m = bpy.data.materials.new(nombre)
        colores = {"concreto": (0.4, 0.4, 0.42, 1), "lamina": (0.4, 0.38, 0.45, 1), "tuberia": (0.4, 0.1, 0.12, 1),
                   "techo": (0.35, 0.27, 0.36, 1), "suelo": (0.25, 0.25, 0.28, 1), "rejilla": (0.2, 0.2, 0.2, 1),
                   "ventana": (1.0, 0.75, 0.4, 1), "luz": (1.0, 0.8, 0.5, 1), "oscuro": (0.05, 0.05, 0.06, 1),
                   "cable": (0.03, 0.03, 0.03, 1)}
        m.diffuse_color = colores.get(nombre, (0.5, 0.5, 0.5, 1))
    return m


def _objeto(nombre, bm, mat):
    me = bpy.data.meshes.new(nombre)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nombre, me)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(material(mat))
    return ob


def uv_caja(ob, tile=None):
    """UV por proyección de la cara dominante, en metros / tile (coordenadas locales)."""
    me = ob.data
    nombre_mat = me.materials[0].name if me.materials else "concreto"
    t = tile or TILE.get(nombre_mat, 4.0)
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    for poly in me.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                u, v = co.y * (1 if n.x > 0 else -1), co.z
            elif ax == 1:
                u, v = co.x * (-1 if n.y > 0 else 1), co.z
            else:
                u, v = co.x, co.y
            uv[li].uv = (u / t, v / t)


def caja(tam, mat, pos=(0, 0, 0), rot=(0, 0, 0), bisel=0.0, tile=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(tam), verts=bm.verts)
    ob = _objeto("caja", bm, mat)
    if bisel > 0:
        _bisel(ob, bisel)
    uv_caja(ob, tile)
    _colocar(ob, pos, rot)
    return ob


def cilindro(r, h, mat, pos=(0, 0, 0), rot=(0, 0, 0), seg=16, r2=None, tapas=True, bisel=0.0, tile=None, uv_cil=True):
    """Cilindro (o cono si r2) a lo largo de Z, base en z=0. UV cilíndrica: U = perímetro, V = altura."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=tapas, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
    bmesh.ops.translate(bm, vec=Vector((0, 0, h / 2)), verts=bm.verts)
    ob = _objeto("cil", bm, mat)
    if bisel > 0:
        _bisel(ob, bisel)
    if uv_cil:
        _uv_cilindro(ob, r, tile)
    else:
        uv_caja(ob, tile)
    _suavizar(ob)
    _colocar(ob, pos, rot)
    return ob


def _uv_cilindro(ob, r, tile=None):
    me = ob.data
    t = tile or TILE.get(me.materials[0].name, 4.0)
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    perim = 2 * math.pi * max(r, 0.01)
    rep_u = max(1, round(perim / t))   # repeticiones enteras alrededor: sin costura
    for poly in me.polygons:
        tapa = abs(poly.normal.z) > 0.9
        angs = []
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            angs.append(math.atan2(co.y, co.x))
        # Evitar el salto de -pi a pi dentro de una misma cara.
        if max(angs) - min(angs) > math.pi:
            angs = [a + 2 * math.pi if a < 0 else a for a in angs]
        for k, li in enumerate(poly.loop_indices):
            co = me.vertices[me.loops[li].vertex_index].co
            if tapa:
                uv[li].uv = (co.x / t, co.y / t)
            else:
                uv[li].uv = (angs[k] / (2 * math.pi) * rep_u, co.z / t)


def tubo(puntos, r, mat, seg=12, radio_codo=None, bridas=(), tile=None):
    """Tubería barrida a lo largo de una polilínea con codos redondeados.
    bridas: distancias a lo largo del tubo donde poner anillos (en metros; negativo = desde el final)."""
    pts = [Vector(p) for p in puntos]
    rc = radio_codo if radio_codo is not None else r * 2.2
    camino = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, b, c = pts[i - 1], pts[i], pts[i + 1]
        d1 = (b - a).normalized()
        d2 = (c - b).normalized()
        ang = d1.angle(d2)
        if ang < 1e-3:
            camino.append(b)
            continue
        off = min(rc * math.tan(ang / 2), (b - a).length * 0.45, (c - b).length * 0.45)
        p0 = b - d1 * off
        p1 = b + d2 * off
        n = max(4, int(ang / (math.pi / 12)))
        for k in range(n + 1):
            t = k / n
            # Bézier cuadrática p0 -> b -> p1 (aproxima el arco del codo)
            camino.append(p0 * (1 - t) ** 2 + b * 2 * t * (1 - t) + p1 * t * t)
    camino.append(pts[-1])
    # Marcos por transporte paralelo para que el tubo no se retuerza.
    tang = []
    for i in range(len(camino)):
        if i == 0:
            d = camino[1] - camino[0]
        elif i == len(camino) - 1:
            d = camino[-1] - camino[-2]
        else:
            d = camino[i + 1] - camino[i - 1]
        tang.append(d.normalized())
    ref = Vector((0, 0, 1)) if abs(tang[0].z) < 0.9 else Vector((1, 0, 0))
    nrm = tang[0].cross(ref).normalized()
    marcos = []
    for i, t in enumerate(tang):
        if i > 0:
            nrm = (nrm - t * nrm.dot(t)).normalized()
        marcos.append((nrm.copy(), t.cross(nrm).normalized()))
    t_len = tile or TILE.get(mat, 3.0)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    anillos = []
    largo = 0.0
    largos = []
    for i, c in enumerate(camino):
        if i > 0:
            largo += (c - camino[i - 1]).length
        largos.append(largo)
        n1, n2 = marcos[i]
        anillos.append([bm.verts.new(c + (n1 * math.cos(2 * math.pi * k / seg) + n2 * math.sin(2 * math.pi * k / seg)) * r) for k in range(seg)])
    for i in range(len(anillos) - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            f = bm.faces.new((anillos[i][k], anillos[i][k2], anillos[i + 1][k2], anillos[i + 1][k]))
            for lp, (uu, vv) in zip(f.loops, ((k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1))):
                lp[uvl].uv = (uu / seg, largos[vv] / t_len)
    for anillo in (anillos[0], anillos[-1]):
        bm.faces.new(anillo if anillo is anillos[-1] else list(reversed(anillo)))
    bm.normal_update()
    ob = _objeto("tubo", bm, mat)
    _suavizar(ob)
    objs = [ob]
    for dist in bridas:
        d = dist if dist >= 0 else largo + dist
        # punto y tangente a esa distancia
        for i in range(1, len(camino)):
            if largos[i] >= d:
                t = (d - largos[i - 1]) / max(largos[i] - largos[i - 1], 1e-6)
                p = camino[i - 1].lerp(camino[i], t)
                eje = (camino[i] - camino[i - 1]).normalized()
                objs.append(_anillo(p, eje, r * 1.28, r * 0.35, mat))
                break
    return unir(objs, "tubo")


def _anillo(p, eje, r, ancho, mat):
    ob = cilindro(r, ancho, mat, seg=14, bisel=min(0.02, r * 0.1))
    rot = Vector((0, 0, 1)).rotation_difference(eje).to_matrix().to_4x4()
    ob.matrix_world = Matrix.Translation(p) @ rot @ Matrix.Translation((0, 0, -ancho / 2))
    _aplicar(ob)
    return ob


def _bisel(ob, ancho):
    mod = ob.modifiers.new("bisel", "BEVEL")
    mod.width = ancho
    mod.segments = 1
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=mod.name)


def _suavizar(ob, angulo=40):
    for p in ob.data.polygons:
        p.use_smooth = True
    try:
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angulo))
    except Exception:
        pass


def _colocar(ob, pos, rot):
    ob.location = pos
    ob.rotation_euler = rot
    _aplicar(ob)


def _aplicar(ob):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def unir(objs, nombre):
    objs = [o for o in objs if o is not None]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = nombre
    ob.data.name = nombre
    return ob


def exportar(ob, ruta):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    # Pesos de normales para superficies biseladas bien sombreadas.
    try:
        mod = ob.modifiers.new("wn", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    except Exception:
        pass
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", use_selection=True, export_apply=True,
                              export_tangents=True, export_yup=True, export_animations=False)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    return tris


def limpiar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)
