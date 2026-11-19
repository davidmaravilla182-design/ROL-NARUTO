# PROGRESO — Ronda de calidad premium (v0.8)

> Meshy: saldo inicial 749, tope 250 (preguntar si una operación pasa de 40 o si el saldo bajaría de 150).

- [ ] 1. Peinados que cubran todo el cuero cabelludo (coleta y revisión de los demás); Kirin con nubes que se
        arremolinan, dragón de relámpagos con cabeza visible, destello blanco, trueno, cráter y chispas.
- [ ] 2. Poderes con movimiento: dragones con cadena de huesos que ondulan; golem con esqueleto y animaciones
        (levantarse, caminar, golpear, desmoronarse); Susanoo que se forma por capas con espada y arco animados;
        anticipación, impacto y desvanecimiento en todos.
- [ ] 3. Combate como en la serie: combos de 4–5 golpes con desplazamientos, patada giratoria y remate que lanza;
        combos aéreos; shunshin tras el enemigo; sustitución con tronco; choques; pausa de impacto, sacudida, líneas
        de velocidad, estelas y retroceso. Animaciones de la biblioteca de Meshy retargeteadas al esqueleto de 17 huesos.
        Enemigos con estos movimientos según su tipo.
- [ ] 4. Plaza con modelos de Meshy (casa de la plaza + 2–3 edificios nuevos del mismo estilo).
- [ ] 5. Pruebas de calidad con secuencias de cuadros (caminar, correr, saltar, pared, agua, combos, jutsus ×3,
        NPCs), revisión cuadro a cuadro, correcciones, antes/después en la bitácora; 60 FPS estimados con 3 enemigos
        y un jutsu N3.
- [ ] Cierre: APK, workflow, reporte.

---

# PROGRESO — Personaje por piezas, 5 NPCs y jutsus con modelo 3D (v0.7, noche)

> Meshy: presupuesto 450 créditos; preguntar solo si una operación pasa de 40. Commit y push tras cada avance verificado.

- [x] 1. Personaje por piezas: cuerpo base (pose A, ropa interior ninja negra, vendas, sandalias, sin chaleco ni pelo),
        4 peinados (puntas, corto, largo, coleta) y 4 prendas (chaleco, impermeable, ropa ligera, capa con capucha)
        sobre el esqueleto de 17 huesos; colores por pieza; emblema del clan en la espalda de cualquier prenda;
        creación con vista previa, retrato del HUD y red.
- [x] 2. Cinco NPCs con piezas + piezas propias: guardia de la lluvia (kunai, agresivo), ninja de agua (distancia),
        remanente rebelde (fuerte, genjutsu que nubla, bombas de humo, raro); comerciante y instructor (misiones).
        Enemigos en zonas de combate fuera de la plaza; los de misiones en su distrito con Interactuar.
- [x] 3. Jutsus con modelo 3D (Meshy da la forma, los efectos van en shaders): Susanoo (3 niveles), Kirin, Gran Dragón
        de Agua, Dragón de Madera, Golem de Tierra; 3 niveles (nivel 3 enorme con cámara lenta).
  Hecho (1): cuerpo base de Meshy (imagen a imagen desde ninja-frente.png + imagen a 3D, 16,8k triángulos), 4 peinados
  de Meshy (solo malla, recortado el maniquí que traen debajo) y 4 prendas hechas en Blender copiando las caras del
  cuerpo con sus pesos (se deforman igual que él) e infladas 2–3 cm; impermeable con faldón y capa con capucha.
  Emblema del clan en la espalda de cada prenda. Colores por pieza (prenda, interior, pelo, piel) en la creación,
  vista previa, retrato y red (el aspecto viaja completo). `tools/blender/ninja_piezas.py`, `tools/vista_piezas.gd`.
  Hecho (2): guardia (kunai, agresivo), ninja de agua (mantiene la distancia, dragón de agua), rebelde (genjutsu que
  nubla la pantalla y bombas de humo; aparece cada 90–180 s en una de 3 zonas, 2,2× vida), comerciante e instructor
  (dicen la misión que darán). Enemigos con radio de detección y regreso a su puesto; reaparecen a los 30 s.
- [x] Cierre: capturas en BITACORA_GRAFICOS.md (M3), medida con NPCs y jutsu N3, APK.

  Meshy esta tarea: cuerpo base 21 (imagen a imagen 6 + imagen a 3D 15); peinados 40 (dos tandas: la primera a
  3.000 polígonos quedaba pobre tras recortar el maniquí); Susanoo ×3, Kirin y Dragón de Agua 25 (solo malla);
  Dragón de Madera 15 y Golem 15 (con textura). Total 116 de 450.

### Pendiente / siguiente
- Las misiones solo se anuncian (comerciante e instructor dicen cuál darán): falta su lógica.
- El impermeable aún se ve algo acolchado; la capa no tiene física de tela (sigue al cuerpo por pesos).
- Peinados por piezas sin física (rígidos al hueso de la cabeza); la coleta no se balancea.
- El dragón de madera tiene alas (Meshy); un dragón oriental sin alas necesitaría otra generación (15 créditos).

---

# PROGRESO — Correcciones tras probar el mapa en el teléfono (v0.6.1)

- [x] 1. Correr por paredes como en el anime (de pie y perpendicular, brillo de chakra en los pies, salpicaduras,
        cámara que acompaña, más rápido, impulso al techo, salto hacia atrás, resbalar sin chakra).
- [x] 2. Agua: canal claramente visible (más oscuro y azulado, reflejos, corriente, espuma, bordes) y caminar sobre
        el agua gastando chakra (ondas y brillo); sin chakra se hunde y nada despacio a la orilla.
- [x] 3. Torre del líder no escalable (acceso por la terraza) y colisiones que coincidan con los modelos.
- [x] 4. Huecos del modelo destrozado: interior oscuro (doble cara).
- [x] 5. La casa de la plaza (primer modelo de Meshy) como edificio común repetido con variaciones.
- [x] 6. Limpieza: escalera sin destino, estructura de tablas, cuadrícula de tinacos, orientación de modelos.
- [x] 7. NPCs: botón Interactuar, aldeanos que caminan y hablan según el distrito, misiones «próximamente».
- [x] 8. Barra del enemigo oculta si está derrotado o lejos.
- [x] Cierre: pruebas, capturas antes/después en BITACORA_GRAFICOS.md (M2), APK.

Notas: el canal ya no es obstáculo (se camina sobre él con 2 de chakra/s; sin chakra se nada al 40 %). La torre del
líder está en `no_escalables`. Colisiones ajustadas por tipo (`ajuste_colision`: torres redondas 0,8, tinacos 0,7,
faroles 0,35…). El edificio de la plaza (Meshy, imagen a 3D) es ahora el edificio común más repetido (73 copias)
con tinte, giro y escala. Tinacos: fuera de las cuadrículas, 48 sobre techos al azar. Escaleras: una por pasarela,
a su misma altura, hechas de tramos de 1 m con pilares (la «estructura de tablas» era una escalera de 12 m escalada
de una sola pieza). Arreglos de fondo: un bucle viejo consumía números aleatorios por cada par de obstáculos y movía
las cajas del campo con cualquier cambio del mapa; la prueba de balance quita los muñecos (el bot no los rodea).

---

# PROGRESO — Noche del mapa completo de Amegakure (v0.6)

> Si el contexto se resume: releer PROGRESO.md, DECISIONES.md y BITACORA_GRAFICOS.md antes de seguir.
> Cada distrito: pruebas headless → capturas → commit + push. Cada 2 distritos: APK en demo-latest + workflow.
> Meshy: presupuesto 350 créditos esta noche; preguntar solo si una operación pasa de 30. Lote en `tools/meshy_lote.py`
> (estado en `referencias/modelos-ia/meshy/lote.json`: NO recrear tareas ya creadas).

## Tareas de esta noche (en orden)
- [x] 0. Base: mapa grande (lago, isla, muralla), sectores con carga por distancia, suelos elevados/rampas, techos caminables,
        caminar por paredes con chakra, minimapa, mapa completo, viaje rápido, puntos de misión y aldeanos.
- [x] 0b. Lote Meshy (18 modelos, ~270 créditos) en segundo plano + procesado en Blender (1024/512 px, LOD lejano).
- [x] 1. Plaza y campo de entrenamiento (ampliado y lleno de objetos).
- [x] 2. Distrito del canal (más puentes, cascadas de desagües).            → APK
- [x] 3. Mercado (calle techada, puestos, luz cálida).
- [x] 4. Zona residencial (torres apiladas, pasarelas).                      → APK
- [x] 5. Distrito industrial (tuberías, chimeneas con vapor, tanques).
- [x] 6. Academia ninja (edificio + patio de prácticas).                     → APK
- [x] 7. Puerta principal y muralla (puente sobre el lago).
- [x] 8. Torre del rostro al centro (sede del líder), integrada.             → APK
- [x] 9. Red local en el mapa nuevo (bots en distintos distritos), FPS/draw calls por distrito.
- [x] 10. Cierre: BITACORA_GRAFICOS.md (capturas y FPS), PROGRESO.md, APK final, reporte.

## Registro
- **Base lista**: isla (radio caminable 146 m) en un lago de 600 m, muralla de 74 tramos + torres, puente de 80 m
  y embarcadero; 8 distritos con rectángulos y nombres; trazado generado por `tools/aldea.py` (345 edificios,
  ~400 objetos, 12 plataformas/escaleras, 24 puntos de misión/aldeanos). Rejilla espacial de obstáculos (celdas de 8 m).
  Techos caminables + escaleras/rampas + **caminar por paredes con chakra** (4 chakra/s, 6,5 m/s; prueba automática).
  Cliente: MultiMesh por tipo y celda de 48 m con LOD cercano/lejano, oclusores de caja, sectores por distrito
  (luces, partículas, cascadas, goteo, aldeanos) que se activan por distancia; minimapa, mapa completo y viaje rápido.
- **Distritos 1 y 2**: plaza con 6 faroles, 6 bancas, ~25 objetos más, mirador con escalera a 5 m; canal de 192 m
  hasta la muralla con 8 puentes, cascadas cada dos módulos en ambos muros, pasarela elevada de 80 m con escaleras.
  Texturas CC0 de Poly Haven (suelo, concreto, lámina, techo). Niebla 0,0055 y cámara con plano lejano a 700 m
  para que la torre se vea desde todo el mapa. Prueba de red: bots en distritos distintos se ven (182 m).
- **Distritos 3 y 4**: mercado con calle techada de 83 m (techo caminable a 5,5 m con escalera), 18 puestos de
  Meshy a ambos lados, 56 farolillos de papel y 5 luces cálidas, entrada emblemática (arco sin colisión central);
  residencial con 6 torres cilíndricas de Meshy, 4 pasarelas a 10–14 m y escalera de 12 m.
  Industrial: 28 tramos de tubería elevada sobre sus calles con pórticos.
- **Distritos 5 y 6**: industrial con 4 talleres, 6 chimeneas con vapor denso, 46 tanques, silos, ~70 objetos y
  tuberías elevadas; academia de Meshy (escala 1,25) con patio de prácticas (4 muñecos, faroles, bancas).
  Escalada: solo paredes de más de 2 m y tras empujar 0,15 s (en combate no se trepa a las cajas sin querer).
  Calles reservadas libres de objetos; pruebas de recorrido: plaza → puerta → puente → orilla y plaza → torre.
- **Distritos 7 y 8**: puerta de Meshy con vano libre (colisión solo en los cuerpos laterales), 2 torres de guardia,
  puente con 18 faroles; torre del líder con terraza de acceso a 2,5 m, escalinata y 2 torres de guardia.
- **Cierre**: capturas de los 8 distritos en `referencias/capturas-mapa/` y tabla de llamadas/primitivas en
  BITACORA_GRAFICOS.md (M1). Pruebas: 110 + 88 + 36 + 23 (red, con bots en distritos distintos) + humo.

### Pendiente / siguiente
- Medir FPS reales en el S26 Ultra por distrito (panel de diagnóstico) y ajustar distancias de dibujo si hace falta.
- Revisar en el teléfono la orientación de algunos modelos de Meshy (frente de casas y talleres).
- Misiones y aldeanos son marcadores: falta su lógica (diálogo, objetivos).
- La muralla no se puede escalar (el borde es un círculo); los sectores ocultan pero no liberan memoria.
- **Meshy**: 18 modelos (Text to 3D, Smart Topology meshy-t2.5, 15 créditos c/u = 270). Saldo 1135 → 865.

---

# Historial: v0.5 creación de personaje y red local

> Si el contexto se resume: releer este archivo y DECISIONES.md.

## Hecho
- [x] Límite de FPS 30/60 en Ajustes y panel de diagnóstico (FPS, ms, draw calls, partículas, ping, pérdida, jugadores).
- [x] Datos de creación (`data/creacion.json`), rangos y progresión (`reglas.json`), reglas compartidas (`scripts/core/creacion.gd`).
- [x] Pantalla de personajes: lista de 3 (usar/borrar/crear) y creación en 6 pasos con vista 3D bajo la lluvia, radar y jutsus disponibles en vivo.
- [x] El servidor valida el personaje; repertorio y combate usan al personaje creado.
- [x] Red local: crear/unirse, listen server ENet, descubrimiento UDP + IP manual, 2–4 jugadores, predicción e interpolación,
      eventos fiables, instantáneas comprimidas, nombre y vida sobre cada jugador, simulador de mala conexión, permisos Android.
- [x] Pruebas: personaje (36), red local con servidor y 2 bots por localhost (18), humo con partida anfitrión + invitado reales.

## Prueba de arte con modelos IA
- [x] Torre IA (Meshy + color de TRELLIS, 30k + LOD 9,7k y 3k, ojos con anillos, ventanas ámbar, lengua plataforma).
- [x] Ninja IA con esqueleto del juego, zonas de color, emblema por clan y nudo de banda.
- [x] Comparación antes/después y medidas: `referencias/modelos-ia/INFORME.md`.

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
