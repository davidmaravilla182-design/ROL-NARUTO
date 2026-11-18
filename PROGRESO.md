# PROGRESO — v0.5: creación de personaje y red local

> Si el contexto se resume: releer este archivo y DECISIONES.md.

## Hecho
- [x] Límite de FPS 30/60 en Ajustes y panel de diagnóstico (FPS, ms, draw calls, partículas, ping, pérdida, jugadores).
- [x] Datos de creación (`data/creacion.json`), rangos y progresión (`reglas.json`), reglas compartidas (`scripts/core/creacion.gd`).
- [x] Pantalla de personajes: lista de 3 (usar/borrar/crear) y creación en 6 pasos con vista 3D bajo la lluvia, radar y jutsus disponibles en vivo.
- [x] El servidor valida el personaje; repertorio y combate usan al personaje creado.
- [x] Red local: crear/unirse, listen server ENet, descubrimiento UDP + IP manual, 2–4 jugadores, predicción e interpolación,
      eventos fiables, instantáneas comprimidas, nombre y vida sobre cada jugador, simulador de mala conexión, permisos Android.
- [x] Pruebas: personaje (36), red local con servidor y 2 bots por localhost (18), humo con partida anfitrión + invitado reales.

## Siguiente (ideas)
- Misiones para subir de rango (la regla ya está en `reglas.json → progresion`).
- Servidor dedicado / en línea: maestría guardada en el servidor y clanes por probabilidad (`Creacion.sortear_clan`).
- Animaciones propias por jutsu y sonidos por forma.

---

# Historial: repertorio de 40 jutsus (v0.4)

> Si el contexto se resume: releer este archivo. Todo el diseño está en `data/jutsus.json`
> (categorías, 40 jutsus + modos oculares, 3 niveles cada uno, requisitos, ventaja/desventaja).

## Hecho
- [x] Datos: `data/jutsus.json` reemplaza la lista anterior; reglas de repertorio y maestría en `data/reglas.json`.
- [x] Reglas (servidor y cliente comparten `scripts/core/repertorio.gd`): 4 ranuras + 1 MODO, tope 12 puntos,
      requisitos (naturaleza, linaje, rango, atributos, control, contrato, dominio), incompatibles, 3 repertorios.
- [x] Maestría: XP por uso e impacto de cada jutsu; N2 a 100 XP, N3 a 300 XP; costo de chakra crece por nivel.
      En combate se usa el nivel más alto desbloqueado salvo que el jugador lo baje en el menú; selector de
      depuración Auto/N1/N2/N3 en el HUD.
- [x] Menú «Repertorio»: pestañas por categoría, filtro «solo disponibles», tarjetas (icono, color, puntos,
      requisito, ●○○), detalle con 3 niveles + vista previa animada + ventaja/desventaja, arrastrar a ranuras,
      R1/R2/R3, «Modo prueba: desbloquear todo». Los no implementados muestran «Próximamente».
- [x] Botones de combate generados desde el repertorio con toque/arrastre/cancelar.
- [x] Bloque 1 (3 niveles visibles): Kirin, Rasengan, Amaterasu, Susanoo, Shinra Tensei, Ocho Puertas
      (+ ya existían Bola de Fuego y Chidori, y los modos Sharingan, Mangekyō, Rinnegan, Byakugan).
- [x] Pruebas: 89 de combate + 88 de repertorio + humo (menú, repertorio y partida en 3 calidades).
- [x] Capturas por nivel del bloque 1: `GUION=tecnicas` con `tools/captura.gd`; menú con `tools/captura_menu.gd`.

## Bloques 2 a 7 (hechos): los 40 jutsus y el Modo Sabio
- [x] Mecánicas genéricas configuradas solo con datos (`scripts/servidor/genericas.gd`): salva, área, aura,
      invocación y teletransporte. Un jutsu puede cambiar de mecánica según el nivel (p. ej. Danza de Papel:
      shuriken → alas → tormenta explosiva).
- [x] Visuales por forma (`scripts/cliente/efectos_genericos.gd`): dragones que serpentean, tiburones, agujas, lanza,
      balas de aire, rasenshuriken, kunai, papel, lodo, arañas y aves de arcilla, olas, inundación, terremoto,
      tornado, raíces, bosque, domo de hielo, río de lava, bombardeo, ataúd y funeral de arena, genjutsu,
      esfera de gravedad, palmas, muro/cúpula/fortaleza, alas, auras de rayo/curación/arena/kamui/rotación/sabio,
      golems, clones, criatura invocada, teletransportes y zonas (lago, lava, cortes).
- [x] N3 de cada uno: más grande, cámara lenta para quien lo lanza, sacudida fuerte, destello y marcas en el suelo.
- [x] Prueba que lanza los 31 genéricos en N1/N2/N3 (93 usos) y comprueba su efecto; humo con varios en el cliente.
- [x] Capturas: `GUION=todos` (y `FILTRO=prefijo`) en `tools/captura.gd`.

## Ajustes v0.4.1
- [x] Límite de temblor de cámara, equilibrio de invocaciones y Dragón de Agua, clones más ligeros, Fuerza N3 nueva,
      usos (ataque/defensa/control/apoyo) y 3 defensas nuevas.

## Siguiente (ideas)
- Afinar balance con partidas reales; sonidos propios por forma; IA enemiga que use el repertorio.

---

# Historial: mejora radical de gráficos (v0.3)

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
- [x] C3 Nuevo trazado de la aldea con el kit (Mapa compartido: canal, muelles, plataforma de entrenamiento). Agua, cascadas, vapor, cables. (Vulkan)
- [x] C4 Torre-cabeza monumental + horizonte de agujas + gradación de color violeta/ámbar.
- [x] C5 Personaje: malla continua deformable (piel por pesos) desde Blender, ropa continua.
- [x] C6 Rendimiento: LOD/visibilidad, conteo de draw calls por calidad, ajustes baja/media. (Vulkan)
- [x] C7 Pulido: chaleco deformable, vendas, docs y versión 0.3 publicada.
- [x] C8 Menú de inicio con la aldea en 3D de fondo (cámara lenta que recorre el canal).
- [x] C9 Lluvia más densa (como las referencias) + muñecos de práctica modelados en Blender. (Vulkan)
- [x] C10 Revisión final: Vulkan (C9), calidad baja (C6), medición final, release v0.3 publicado por CI.
- [x] C11 (extra) Impermeable largo y respirador para el ninja de la Lluvia (malla deformable de Blender).

## Estado actual
- Ciclo en curso: ninguno — plan completado. Ideas siguientes en BITACORA_GRAFICOS.md (sección "Pendiente").
- Texturas: `tools/blender/texturas.py` (6 materiales, ~10 s). Tras hornear: `python3 tools/ajustar_importacion.py` y `godot --headless --path . --import`.
- Shader con texturas: `Shaders.toon_tex(nombre, tinte, escala_uv, triplanar, escala_mundo, metalico, humedad, contorno)`.
- Capturas: `/tmp/claude-0/cap.sh <carpeta> [mobile]` (si falta, recrear: xvfb-run + godot -s res://tools/captura.gd).
- Kit: `tools/blender/kit.py` (geometría en `geo.py`); piezas en assets/modelos. En Godot: `Kit.instancia/multimalla` reemplaza materiales por nombre.
- Trazado: data/escenario.json → "trazado" (piezas, arcos, tubos, canal, puentes, horizonte). `Mapa._trazado` da colisiones; `Trazado.construir` dibuja.
- Capturas con cámara libre: en tools/captura.gd usar `_libre(pos, mirar)` y `_seguir()`.
- Cuerpo: `tools/blender/personaje.py` → assets/modelos/cuerpo.glb. Animaciones corrigen el reposo de Blender (padre⁻¹·D·global); las piezas por código cuelgan de un nodo "Marco" que anula la rotación de reposo.
- IMPORTANTE: con lavapipe instalado, Godot usa Vulkan/Mobile por defecto. `cap.sh <carpeta>` fuerza OpenGL; `cap.sh <carpeta> mobile` usa Vulkan.
  Calidad de la captura: `CALIDAD=baja /tmp/claude-0/cap.sh carpeta`.
- Medir llamadas de dibujo: `/tmp/claude-0/medir.sh` (tools/medir.gd; salida a archivo porque Godot se cuelga al salir con Vulkan).
