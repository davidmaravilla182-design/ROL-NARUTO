"""Animaciones de la biblioteca de Meshy → datos para el esqueleto de 17 huesos del juego.

Lee los GLB animados de Meshy (rig humanoide de 24 huesos) y, cuadro a cuadro, guarda en ejes de Godot
(Y arriba, frente +Z):
- la orientación (rotación respecto al reposo, en el espacio del modelo) de Caderas, Columna, Pecho, Cuello y Cabeza;
- la dirección de cada hueso de las extremidades (del hueso hacia su hijo);
- la altura de la cadera respecto al reposo (el desplazamiento horizontal se descarta: lo mueve el servidor).
El juego (Animaciones.crear_libreria_meshy) convierte eso en rotaciones locales para cualquier esqueleto de 17 huesos:
los brazos y piernas se alinean por dirección, así no importa que el reposo de Meshy sea pose A y el nuestro brazos abajo.

Salida: data/animaciones_meshy.json
Uso: /tmp/claude-0/venvbpy/v/bin/python -I tools/blender/retarget_meshy.py
"""
import bpy, os, json
from mathutils import Matrix, Vector

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
D = os.path.join(RAIZ, "referencias", "modelos-ia", "meshy", "animaciones")

# Nuestros huesos de orientación ← hueso de Meshy
ORIENT = {"Caderas": "Hips", "Columna": "Spine01", "Pecho": "Spine", "Cuello": "neck", "Cabeza": "Head"}
# Nuestros huesos por dirección ← (hueso de Meshy, hijo de Meshy o None para usar su eje Y)
DIREC = {"BrazoI": ("LeftArm", "LeftForeArm"), "AntebrazoI": ("LeftForeArm", "LeftHand"), "ManoI": ("LeftHand", None),
         "BrazoD": ("RightArm", "RightForeArm"), "AntebrazoD": ("RightForeArm", "RightHand"), "ManoD": ("RightHand", None),
         "PiernaI": ("LeftUpLeg", "LeftLeg"), "RodillaI": ("LeftLeg", "LeftFoot"), "PieI": ("LeftFoot", "LeftToeBase"),
         "PiernaD": ("RightUpLeg", "RightLeg"), "RodillaD": ("RightLeg", "RightFoot"), "PieD": ("RightFoot", "RightToeBase")}
# Nombre en el juego ← acción de Meshy
NOMBRES = {
    "Left_Jab_from_Guard": "m_jab_izq", "Right_Jab_from_Guard": "m_jab_der", "Left_Hook_from_Guard": "m_gancho",
    "Right_Uppercut_from_Guard": "m_uppercut", "Roundhouse_Kick": "m_patada_giro", "Lunge_Roundhouse_Kick": "m_patada_giro_avance",
    "Lunge_Spin_Kick": "m_patada_espiral", "Spartan_Kick": "m_patada_frontal", "High_Kick": "m_patada_alta", "Leg_Sweep": "m_barrido",
    "Flying_Fist_Kick": "m_patada_voladora", "Charged_Ground_Slam": "m_golpe_suelo", "Combat_Stance": "m_guardia",
    "Stand_Dodge": "m_esquiva", "BeHit_FlyUp": "m_lanzado", "Face_Punch_Reaction": "m_golpeado_cara", "Knock_Down": "m_derribado",
    "dying_backwards": "m_muerte", "Charged_Spell_Cast": "m_lanzar_jutsu", "Hit_Reaction": "m_golpeado",
    "Walking": "m_caminar", "Running": "m_correr",
}
# Bucles (el resto se reproduce una vez)
BUCLES = {"m_guardia", "m_caminar", "m_correr"}

C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))   # Blender (Z arriba, frente -Y) → Godot (Y arriba, frente +Z)


def a_godot_v(v):
    return C @ v


def a_godot_q(m3):
    return (C @ m3 @ C.transposed()).to_quaternion()


def r(x, n=4):
    return round(float(x), n)


def procesar(arm, accion, datos):
    nombre = NOMBRES.get(accion.name.split("|")[-1], None)
    if nombre is None:
        nombre = NOMBRES.get(accion.name, None)
    if nombre is None or nombre in datos:
        return
    arm.animation_data.action = accion
    escena = bpy.context.scene
    fps = escena.render.fps / escena.render.fps_base
    f0, f1 = int(accion.frame_range[0]), int(round(accion.frame_range[1]))
    # Reposo (en espacio de la armadura).
    rest = {b.name: b.matrix_local.copy() for b in arm.data.bones}
    cad_rest_z = rest["Hips"].translation.z
    alto = rest["Head"].translation.z   # para escalar la altura de la cadera al tamaño del juego (≈1,57 m la cabeza)
    escala_alt = 1.565 / max(alto, 1e-6)
    cuadros = []
    for f in range(f0, f1 + 1):
        escena.frame_set(f)
        pb = {b.name: b.matrix.copy() for b in arm.pose.bones}
        q = {}
        for nuestro, suyo in ORIENT.items():
            delta = pb[suyo].to_3x3() @ rest[suyo].to_3x3().inverted()
            g = a_godot_q(delta)
            q[nuestro] = [r(g.x), r(g.y), r(g.z), r(g.w)]
        d = {}
        for nuestro, (suyo, hijo) in DIREC.items():
            if hijo is not None:
                v = pb[hijo].translation - pb[suyo].translation
            else:
                v = pb[suyo].to_3x3() @ Vector((0, 1, 0))
            g = a_godot_v(v.normalized())
            d[nuestro] = [r(g.x, 3), r(g.y, 3), r(g.z, 3)]
        cad_y = (pb["Hips"].translation.z - cad_rest_z) * escala_alt
        cuadros.append({"q": q, "d": d, "y": r(cad_y, 3)})
    datos[nombre] = {"fps": r(fps, 2), "bucle": nombre in BUCLES, "duracion": r((f1 - f0) / fps, 3), "cuadros": cuadros}
    print("[retarget] %-22s ← %-28s %3d cuadros %.2f s" % (nombre, accion.name, len(cuadros), (f1 - f0) / fps), flush=True)


def main():
    datos = {}
    for archivo in ["anim_a.glb", "anim_b.glb", "rig_cuerpo_walking.glb", "rig_cuerpo_running.glb"]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(D, archivo))
        arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
        if arm.animation_data is None:
            arm.animation_data_create()
        for accion in list(bpy.data.actions):
            nombre_accion = accion.name
            if "walking" in nombre_accion.lower() and "m_caminar" not in datos:
                accion.name = "Walking"
            elif "running" in nombre_accion.lower() and "m_correr" not in datos:
                accion.name = "Running"
            procesar(arm, accion, datos)
    ruta = os.path.join(RAIZ, "data", "animaciones_meshy.json")
    json.dump({"_nota": "Generado por tools/blender/retarget_meshy.py desde la biblioteca de animaciones de Meshy. "
                         "q: orientación respecto al reposo (espacio del modelo, ejes de Godot); d: dirección de cada hueso; "
                         "y: altura de la cadera respecto al reposo (m).", "animaciones": datos},
              open(ruta, "w", encoding="utf-8"), separators=(",", ":"))
    print("[retarget] listo:", len(datos), "animaciones →", ruta, os.path.getsize(ruta) // 1024, "KB")


main()
