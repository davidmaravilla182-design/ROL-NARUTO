# PROGRESO — mejora radical de gráficos (v0.3)

> Si el contexto se resume: releer este archivo y BITACORA_GRAFICOS.md antes de seguir.
> Regla: cada ciclo = cambio → verificación headless (tools/verificar.sh) → captura OpenGL →
> comparar con referencias/amegakure → commit + push → revisar CI. Vulkan/Mobile cada 3 ciclos.

## Restricciones (del usuario)
- Sin red a Poly Haven / ambientCG: texturas 100 % procedurales (bake en Blender o shaders).
- Capturas: OpenGL cada ciclo; Vulkan/Mobile cada 3 ciclos (cortar el proceso tras guardar).
- Blender y exportaciones en segundo plano.
- Mantener servidor/cliente y datos en /data. Las pruebas deben seguir pasando.
- No terminar el turno mientras queden ciclos.

## Entorno
- Blender (bpy 5.3) en /tmp/claude-0/venvbpy/v (pip install bpy). Si el contenedor se recicla: recrear con
  `python3 -m venv /tmp/claude-0/venvbpy/v && /tmp/claude-0/venvbpy/v/bin/pip install bpy`.
- Godot 4.7.2 en /usr/local/bin/godot (si falta: descargar de GitHub releases 4.7.2-stable).
- Scripts de Blender: tools/blender/*.py → salida en assets/modelos/*.glb y assets/texturas/*.png (se versionan).

## Lectura de las referencias (objetivo visual)
- Paleta: grises azulados fríos, tuberías granate/vino, acentos violeta en torres, luz ámbar cálida en faroles y ventanas.
- Formas: torres cilíndricas con anillos y agujas góticas, edificios de concreto con toldos de lámina, tuberías gruesas con bridas,
  pasarelas de celosía, barandales de tubo, rejillas en el suelo, cables colgando, tanques de agua, vapor, cascadas desde muros,
  canales de agua con ondas, torre-cabeza monumental como hito.
- Atmósfera: lluvia densa, niebla por capas que engulle la distancia, cielo de tormenta, suelo mojado con reflejos ámbar.

## Ciclos
- [x] C0 Preparación: referencias, plan, pipeline Blender (bake de texturas tileables por toro 4D).
- [x] C1 Texturas procedurales (concreto manchado, lámina pintada/óxido, tubería granate, placas de suelo, lámina de techo) + shader toon con texturas.
- [x] C2 Kit modular en Blender: silo con anillos y agujas, edificio con toldos, tubería+brida+codo, barandal, pasarela de celosía, farol, tanque.
- [ ] C3 Nuevo trazado de la aldea con el kit (Mapa compartido: canal, muelles, plataforma de entrenamiento). Agua, cascadas, vapor, cables. (Vulkan)
- [ ] C4 Torre-cabeza monumental + horizonte de agujas + gradación de color violeta/ámbar.
- [ ] C5 Personaje: malla continua deformable (piel por pesos) desde Blender, ropa continua.
- [ ] C6 Rendimiento: LOD/visibilidad, conteo de draw calls por calidad, ajustes baja/media. (Vulkan)
- [ ] C7 Pulido de efectos y enemigo/muñecos con el nuevo estilo; docs; release.

## Estado actual
- Ciclo en curso: C3 (trazado con el kit) — falta: revisión Vulkan, cascadas visibles, vista desde el juego
- Texturas: `tools/blender/texturas.py` (6 materiales, ~10 s). Tras hornear: `python3 tools/ajustar_importacion.py` y `godot --headless --path . --import`.
- Shader con texturas: `Shaders.toon_tex(nombre, tinte, escala_uv, triplanar, escala_mundo, metalico, humedad, contorno)`.
- Capturas: `/tmp/claude-0/cap.sh <carpeta> [mobile]` (si falta, recrear: xvfb-run + godot -s res://tools/captura.gd).
- Kit: `tools/blender/kit.py` (geometría en `geo.py`); piezas en assets/modelos. En Godot: `Kit.instancia/multimalla` reemplaza materiales por nombre.
- Trazado: data/escenario.json → "trazado" (piezas, arcos, tubos, canal, puentes, horizonte). `Mapa._trazado` da colisiones; `Trazado.construir` dibuja.
- Capturas con cámara libre: en tools/captura.gd usar `_libre(pos, mirar)` y `_seguir()`.
