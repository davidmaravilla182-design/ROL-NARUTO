"""NPC con nombre a partir de una imagen de GPT convertida con Meshy (referencias/modelos-ia/meshy/<nombre>/modelo.glb).

Reutiliza el proceso del ninja del jugador (tools/blender/ninja_ia.py): escala a 1,82 m, esqueleto con los 17 huesos
del juego en las articulaciones medidas, pesos por distancia y brazos bajados como reposo. Así el NPC usa todas las
animaciones del juego (caminar, correr, golpes, jutsus, reacciones y las de Meshy retargeteadas).
Sin zonas de color ni cabello aparte: la textura se usa tal cual.
Lo que va a la espalda (arma) se pega al pecho para que no se mueva con la cabeza ni con los brazos.

Salida: assets/modelos/npc_<nombre>.glb y assets/texturas/npc_<nombre>_color.png
Uso: /tmp/claude-0/venvbpy/v/bin/python -I tools/blender/npc_ia.py <nombre>
"""
import bpy, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ninja_ia as N


def espalda_al_pecho(ob, arm):
    P = np.array([tuple(v.co) for v in ob.data.vertices])
    H = N.ALTO
    # Superficie de la espalda: lo más atrás del torso a la altura del pecho, cerca del centro.
    banda = P[(np.abs(P[:, 2] - 0.7 * H) < 0.02 * H) & (np.abs(P[:, 0]) < 0.08)]
    y_espalda = np.percentile(banda[:, 1], 70)
    cabeza = (P[:, 2] > 0.83 * H) & (np.abs(P[:, 0]) < 0.11)
    detras = (P[:, 1] > y_espalda + 0.025) & (P[:, 2] > 0.55 * H) & ~cabeza
    N.log("espalda en y=%.3f" % y_espalda)
    grupos = {g.name: g for g in ob.vertex_groups}
    idx = np.nonzero(detras)[0].tolist()
    for g in grupos.values():
        g.remove(idx)
    grupos["Pecho"].add(idx, 1.0, "REPLACE")
    N.log("espalda → Pecho: %d vértices" % len(idx))


def corregir_manos(j):
    """La punta de la mano sigue al antebrazo (la detección de ninja_ia puede caer en la capa o el muslo)."""
    for lado in ("I", "D"):
        m, c = np.array(j["Mano" + lado]), np.array(j["Antebrazo" + lado])
        d = (m - c) / np.linalg.norm(m - c)
        j["punta_mano" + lado] = m + d * 0.1
    return j


def brazos_fuera_del_cuerpo(ob, arm):
    """Quita los pesos de brazo a lo que está pegado al cuerpo (capa, muslos, bolsas): esos vértices toman el
    hueso del cuerpo o de la pierna más cercano."""
    H = N.ALTO
    bones = arm.data.bones
    def seg(n):
        return np.array(bones[n].head_local), np.array(bones[n].tail_local)
    brazos = [n for n in bones.keys() if n.startswith(("Brazo", "Antebrazo", "Mano"))]
    resto = [n for n in bones.keys() if n not in brazos]
    def dist(p, a, b):
        ab = b - a
        t = np.clip(np.dot(p - a, ab) / max(np.dot(ab, ab), 1e-9), 0, 1)
        return np.linalg.norm(p - (a + ab * t))
    gi = {g.index: g.name for g in ob.vertex_groups}
    grupos = {g.name: g for g in ob.vertex_groups}
    cambiados = 0
    for v in ob.data.vertices:
        p = np.array(tuple(v.co))
        lado = "I" if p[0] > 0 else "D"
        c, m = np.array(bones["Antebrazo" + lado].head_local), np.array(bones["Mano" + lado].head_local)
        if p[2] >= c[2]:
            continue
        # x del antebrazo a esta altura (entre codo y muñeca, o la muñeca más abajo)
        t = np.clip((c[2] - p[2]) / max(c[2] - m[2], 1e-6), 0, 1)
        x_brazo = abs(c[0] + (m[0] - c[0]) * t)
        if abs(p[0]) > x_brazo - 0.07:
            continue
        tiene = [gi[g.group] for g in v.groups if gi[g.group] in brazos and g.weight > 0.0]
        if not tiene:
            continue
        for n in tiene:
            grupos[n].remove([v.index])
        cand = [(dist(p, *seg(n)), n) for n in resto if not (n[-1] in "ID" and n[-1] != lado and abs(p[0]) > 0.02)]
        if not any(gi[g.group] in resto and g.weight > 0 for g in v.groups):
            grupos[min(cand)[1]].add([v.index], 1.0, "REPLACE")
        cambiados += 1
    N.log("pesos de brazo quitados del cuerpo: %d vértices" % cambiados)


def main():
    nombre = sys.argv[-1]
    ob = N.importar(os.path.join(N.REF, "meshy", nombre, "modelo.glb"))
    img, _px = N.textura(ob)
    j = corregir_manos(N.articulaciones(ob))
    arm = N.armadura(j)
    N.pesos(ob, arm)
    brazos_fuera_del_cuerpo(ob, arm)
    espalda_al_pecho(ob, arm)
    ob.parent = arm
    mod = ob.modifiers.new("arm", "ARMATURE")
    mod.object = arm
    N.bajar_brazos(ob, arm, j)
    ob.data.materials[0].name = "npc_" + nombre
    if img is not None:
        if img.size[0] > 1024:
            img.scale(1024, 1024)
        # Textura aparte (la incrustada en JPEG no la importa Godot): assets/texturas/npc_<nombre>_color.png
        img.filepath_raw = os.path.join(N.RAIZ, "assets", "texturas", "npc_%s_color.png" % nombre)
        img.file_format = "PNG"
        img.save()
    N.activo(arm, ob)
    ruta = os.path.join(N.RAIZ, "assets", "modelos", "npc_%s.glb" % nombre)
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", use_selection=True, export_skins=True, export_yup=True,
                              export_animations=False, export_def_bones=False, export_image_format="NONE")
    N.log("listo: %d triángulos → %s" % (sum(len(p.vertices) - 2 for p in ob.data.polygons), ruta))


if __name__ == "__main__":
    main()
