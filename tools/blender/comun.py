"""Utilidades compartidas para los scripts de Blender (bpy) del proyecto.

Se ejecutan con el Python que tiene bpy instalado, por ejemplo:
    /tmp/claude-0/venvbpy/v/bin/python -I tools/blender/texturas.py
"""
import math
import os
import bpy

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIR_TEX = os.path.join(RAIZ, "assets", "texturas")
DIR_MOD = os.path.join(RAIZ, "assets", "modelos")


def escena_vacia():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    esc = bpy.context.scene
    esc.render.engine = "CYCLES"
    esc.cycles.device = "CPU"
    esc.cycles.samples = 1
    esc.cycles.use_denoising = False
    return esc


class Grafo:
    """Constructor compacto de árboles de nodos de material."""

    def __init__(self, mat):
        mat.use_nodes = True
        self.nt = mat.node_tree
        self.n = self.nt.nodes
        self.l = self.nt.links
        for nd in list(self.n):
            self.n.remove(nd)
        self.salida = self.n.new("ShaderNodeOutputMaterial")
        self.emision = self.n.new("ShaderNodeEmission")
        self.l.new(self.emision.outputs[0], self.salida.inputs["Surface"])
        uv = self.n.new("ShaderNodeTexCoord")
        sep = self.n.new("ShaderNodeSeparateXYZ")
        self.l.new(uv.outputs["UV"], sep.inputs[0])
        self.u = sep.outputs[0]
        self.v = sep.outputs[1]

    def _entrada(self, sock, valor):
        if isinstance(valor, (int, float)):
            sock.default_value = valor
        elif isinstance(valor, tuple):
            sock.default_value = valor
        else:
            self.l.new(valor, sock)

    def m(self, op, a, b=0.0, c=None):
        nd = self.n.new("ShaderNodeMath")
        nd.operation = op
        self._entrada(nd.inputs[0], a)
        self._entrada(nd.inputs[1], b)
        if c is not None:
            self._entrada(nd.inputs[2], c)
        return nd.outputs[0]

    def vec(self, x, y, z):
        nd = self.n.new("ShaderNodeCombineXYZ")
        self._entrada(nd.inputs[0], x)
        self._entrada(nd.inputs[1], y)
        self._entrada(nd.inputs[2], z)
        return nd.outputs[0]

    def toro(self, ru, rv, fu=1, fv=1, du=0.0, dv=0.0):
        """Coordenadas 4D sobre un toro: cualquier ruido 4D evaluado aquí es periódico en U y V.
        ru/rv controlan la frecuencia del ruido en cada eje; fu/fv repiten el patrón n veces."""
        au = self.m("MULTIPLY", self.m("ADD", self.u, du), 2 * math.pi * fu)
        av = self.m("MULTIPLY", self.m("ADD", self.v, dv), 2 * math.pi * fv)
        p = self.vec(self.m("MULTIPLY", self.m("COSINE", au), ru), self.m("MULTIPLY", self.m("SINE", au), ru),
                     self.m("MULTIPLY", self.m("COSINE", av), rv))
        w = self.m("MULTIPLY", self.m("SINE", av), rv)
        return p, w

    def ruido(self, p, w, escala=1.0, detalle=4.0, rugosidad=0.5, distorsion=0.0):
        nd = self.n.new("ShaderNodeTexNoise")
        nd.noise_dimensions = "4D"
        self.l.new(p, nd.inputs["Vector"])
        self.l.new(w, nd.inputs["W"])
        nd.inputs["Scale"].default_value = escala
        nd.inputs["Detail"].default_value = detalle
        nd.inputs["Roughness"].default_value = rugosidad
        nd.inputs["Distortion"].default_value = distorsion
        return nd.outputs["Fac"]

    def voronoi(self, p, w, escala=1.0, salida="Distance", rasgo="F1"):
        nd = self.n.new("ShaderNodeTexVoronoi")
        nd.voronoi_dimensions = "4D"
        nd.feature = rasgo
        self.l.new(p, nd.inputs["Vector"])
        self.l.new(w, nd.inputs["W"])
        nd.inputs["Scale"].default_value = escala
        return nd.outputs[salida]

    def rampa(self, fac, paradas):
        nd = self.n.new("ShaderNodeValToRGB")
        cr = nd.color_ramp
        while len(cr.elements) > 1:
            cr.elements.remove(cr.elements[-1])
        cr.elements[0].position = paradas[0][0]
        cr.elements[0].color = paradas[0][1]
        for pos, col in paradas[1:]:
            e = cr.elements.new(pos)
            e.color = col
        self._entrada(nd.inputs[0], fac)
        return nd.outputs[0]

    def mezcla(self, fac, a, b, modo="MIX"):
        nd = self.n.new("ShaderNodeMix")
        nd.data_type = "RGBA"
        nd.blend_type = modo
        self._entrada(nd.inputs[0], fac)
        self._entrada(nd.inputs[6], a)
        self._entrada(nd.inputs[7], b)
        return nd.outputs[2]

    def gris(self, fac):
        """Convierte un escalar en color (para hornear canales en escala de grises)."""
        return self.vec(fac, fac, fac)

    def lineas(self, coord, repeticiones, grosor):
        """1 cerca de las líneas periódicas (juntas), 0 lejos. Periódico en [0,1]."""
        f = self.m("FRACT", self.m("MULTIPLY", coord, repeticiones))
        d = self.m("MINIMUM", f, self.m("SUBTRACT", 1.0, f))
        return self.m("SUBTRACT", 1.0, self.m("SMOOTHSTEP" if False else "GREATER_THAN", d, grosor))

    def suave(self, a, b, x):
        nd = self.n.new("ShaderNodeMapRange")
        nd.interpolation_type = "SMOOTHSTEP"
        self._entrada(nd.inputs["Value"], x)
        nd.inputs["From Min"].default_value = a
        nd.inputs["From Max"].default_value = b
        return nd.outputs["Result"]

    def emitir(self, color):
        self.l.new(color, self.emision.inputs["Color"])


def plano_para_hornear(tam):
    bpy.ops.mesh.primitive_plane_add(size=2)
    ob = bpy.context.active_object
    img = bpy.data.images.new("bake", tam, tam, alpha=False, float_buffer=True)
    return ob, img


def hornear(ob, mat, img):
    """Hornea la emisión del material a la imagen (canal por canal)."""
    nt = mat.node_tree
    tex = nt.nodes.get("__bake__")
    if tex is None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.name = "__bake__"
    tex.image = img
    for nd in nt.nodes:
        nd.select = False
    tex.select = True
    nt.nodes.active = tex
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.bake(type="EMIT", margin=0)
