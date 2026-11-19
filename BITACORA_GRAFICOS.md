# Bitácora de gráficos

Cada entrada: qué se hizo, cómo se verificó, capturas comparadas, problemas y siguiente paso.

## C0 — preparación
- 8 imágenes de referencia copiadas a referencias/amegakure/ (con .gdignore: no entran al APK).
- Pipeline Blender listo: bpy 5.3 en venv; `tools/blender/comun.py` (constructor de nodos, coordenadas de toro 4D para ruido sin costuras, bake EMIT).

## C1 — texturas procedurales + shader con texturas
- 6 texturas horneadas en Cycles: concreto (encofrado, chorreaduras, manchas), lámina (paneles, remaches, óxido), tubería granate
  (desconchones, óxido, bandas), suelo (placas, rombos, juntas oxidadas, charcos), techo corrugado violáceo, rejilla.
  Color+rugosidad en un PNG (A = rugosidad) y normales calculadas con numpy desde la altura (bordes periódicos).
- Verificado con hoja de contacto 2×2: sin costuras. 1ª versión: óxido/chorreaduras casi invisibles → umbrales bajados.
- Godot headless no marca las texturas como 3D: `tools/ajustar_importacion.py` fuerza VRAM (ETC2/ASTC + S3TC), mipmaps y normal map.
- Nuevo shader `TOON_TEX`: bandas suaves de ilustración, rim, brillo según rugosidad, humedad (caras hacia arriba
  más oscuras y brillantes) y chorreaduras animadas en paredes; modo triplanar para piezas escaladas.
- Captura: el suelo y las torres ya tienen material. Problemas vistos: moiré en los rombos del suelo (corregido: patrón
  más grueso); escena demasiado clara/lavada frente a las referencias (oscuras, violetas, luz ámbar) → ciclo de atmósfera.

## C2 — kit modular en Blender
- `geo.py`: cajas/cilindros con UV a escala de mundo (texel coherente por material), tuberías barridas por polilínea con codos
  (marcos por transporte paralelo, UV U=perímetro, V=longitud), bridas, biseles y normales ponderadas.
- `kit.py`: silo (balcones con barandal, ventanas en rendija, tuberías, corona con agujas), edificio (3 pisos, ventanas,
  toldos, faroles, aires acondicionados, tuberías por la esquina), farol, barandal, pasarela de celosía, tubo largo, arco
  de tubería en U, tanque elevado, muro de canal con desagüe, toldo, y siluetas lejanas (silo_lejano 316 tris, bloque_lejano 180).
- Silo bajado de 16.5k a 10.8k triángulos (barandales circulares con menos segmentos).
- Godot: `Kit` carga el GLB y cambia los materiales por nombre (concreto/lamina/tuberia/techo/suelo/rejilla → toon_tex;
  ventana/luz → emisivos). `tools/vista_kit.gd` fotografía las piezas.

## C3 — nueva aldea con el kit
- Trazado en datos (escenario.json): 17 piezas alrededor de la plaza, canal al norte (muros, agua, 2 puentes), arcos de
  tubería sobre las calles, tubos junto al canal, 34 siluetas en el horizonte, 14 cables colgantes.
- Mapa compartido: las huellas de las piezas son colisiones; el canal frena a los personajes pero no a los proyectiles.
- Nuevos shaders: agua del canal (corriente + anillos de lluvia, muy reflectante) y cascada (franjas de ruido que bajan + espuma).
- Vapor en azoteas y silos, cables catenaria en una sola malla, luces cálidas en puertas y bajo los puentes.
- Gradación: cielo/niebla violáceos y oscuros, sol tenue, ventanas ámbar, glow con umbral 0.8 (atmósfera en escenario.json).
- Capturas: la calle con toldos y faroles ya se parece a las referencias. Corregido: contorno negro en el escenario
  (se veía como boceto; ahora solo personajes), bancos de niebla con aspecto de rectángulos, agua demasiado profunda.
- Vulkan/Mobile (ciclo 3): calle y canal se ven igual que en OpenGL; sin errores de shader.

## C4 — hito y horizonte
- `torre_cabeza` (10.4k tris, ~80 m): fuste con anillos, tuberías granate por la fachada, ventanas, cabeza de piedra con
  banda y placa de la aldea, ojos de anillos concéntricos, nariz, boca abierta con lengua, caras secundarias a los lados y corona de agujas.
- Situada al fondo, detrás del canal, mirando a la plaza; focos cálidos desde abajo y luz fría sobre el rostro.
- Errores encontrados: rostro demasiado pequeño (no se leía) → rasgos ×1.75; giro invertido; el filtro de errores de
  `cap.sh` escondía errores que empezaban por "C" (Compile Error) → corregido, y ahora se ven todos.
- Captura 01e_hito: horizonte de agujas, ventanas ámbar y vapor — composición cercana a las referencias 2 y 6.

## C5 — personaje con malla continua + arreglos de efectos
- `personaje.py`: cuerpo con modificador Skin + Subsurf (954 vértices, 1.9k tris), sin cortes entre piezas; materiales por
  zona (piel/camisa/pantalón); esqueleto con los mismos 17 huesos del juego; pesos por distancia a los segmentos de hueso
  con mezcla gaussiana entre los 3 más cercanos (y sin cruzar de lado en extremidades).
- Godot: se usa el Skeleton3D del GLB. Como los huesos de Blender tienen orientación de reposo, cada clave de rotación
  se transforma a padre_rest⁻¹ · D · hueso_rest (D = rotación en ejes del modelo, la misma de antes). Las piezas por código
  (cabeza, pelo, ropa) cuelgan de un nodo "Marco" con la rotación de reposo invertida, así no hubo que tocarlas.
  Si falta cuerpo.glb se usa el cuerpo por piezas de antes.
- Verificado en capturas: correr, sellos, carga y embiste del rayo deforman bien hombros, codos y rodillas.
- Efectos: el destello del rayo nv3 lavaba la escena (niebla cian) → mezcla de niebla máx. 0.3; faroles con menos emisión;
  el fuego se veía como un disco blanco: (1) demasiadas partículas aditivas (320) → máx. 90-100 y menos alfa;
  (2) la esfera de distorsión de calor tapaba la bola (A/B con y sin ella) → ahora solo un anillo y se dibuja detrás.
  El shader de fuego tiene más contraste (zonas rojas oscuras). Resultado: bola nv3 enorme con textura de fuego.

## C6 — rendimiento
- Descubrimiento: desde que se instaló lavapipe, las capturas "OpenGL" en realidad usaban Vulkan/Mobile (el renderizador
  del teléfono). Las capturas de C3-C5 ya representaban al celular. `cap.sh` ahora fuerza OpenGL en el modo rápido.
  Comparación lado a lado: ambos se ven equivalentes; Mobile tiene algo más de niebla.
- Medición (tools/medir.gd, llamadas de dibujo visibles / primitivas / llamadas de sombra):
  - Antes: alta 238 / 75k / 169 · media 234 / 73k / 171 · baja 206 / 68k / 0
  - Piezas del trazado agrupadas por tipo en MultiMesh: alta 233 / 63k / 165 (poco efecto).
  - Causa real: cada personaje eran ~70 mallas sueltas (picos de pelo, anillos de vendas, ropa). `Materiales.fusionar`
    une las mallas de cada hueso en una sola (una superficie por material); igual con los muñecos.
  - Después: alta 99 / 63k / 35 · media 95 / 61k / 35 · baja 67 / 56k / 0. Llamadas ÷2.4, sombras ÷4.7.
- Calidad baja verificada en captura: sin glow ni sombras, se sigue viendo bien.
- Ojos del modo ocular: la luz roja iluminaba el emblema de la espalda → rango 0.35 m.

## C7 — pulido del personaje
- Chaleco como malla deformable de Blender (cáscara con Skin alrededor del torso, cuello alto y hombreras), pesada al
  mismo esqueleto. Se quitan las cajas rígidas del chaleco; quedan bolsillos, cinturón (ahora ovalado) y el emblema.
- 1ª versión: chaleco con forma de saco hasta la cadera → radios menores y base más alta; emblema hundido → más atrás.
- Vendas ajustadas al nuevo grosor de antebrazos y espinillas (antes flotaban como puños).

## C8 — menú con la aldea en vivo
- La pantalla de inicio muestra la aldea en 3D (SubViewport con su propio mundo, lluvia y relámpagos) con una cámara que
  recorre la plaza mirando la torre monumental, y un velo oscuro para leer el texto.
- 1ª versión: la cámara atravesaba un edificio → recorrido limitado al espacio abierto de la plaza.

## C9 — lluvia densa y muñecos
- Lluvia: gotas 2600/1500/800 (alta/media/baja), más largas, algo más opacas e inclinadas por el viento, como las referencias.
- Textura de madera horneada (vetas deformadas por ruido, nudos, zonas mojadas). Muñecos de práctica modelados en Blender:
  base con patas, poste, travesaño con puños de paja, torso de paja atado con cuerdas, cabeza y diana. Base y cuerpo por
  separado para que el cuerpo se siga sacudiendo y cayendo con los golpes.

## C10–C11 — cierre
- Vulkan/Mobile (C9): menú 3D, plaza, explosión y rayo nv3 iguales a OpenGL; el rayo nv3 tiñe todo de cian (es lo pedido:
  "iluminar todo el escenario").
- Impermeable del ninja de la Lluvia: tercera malla deformable en cuerpo.glb (cuello alto, mangas, falda a la rodilla);
  se muestra u oculta según `aspecto.capa` en personajes.json (reemplaza al chaleco).
- Herramienta de capturas: ahora ejecuta un paso por fotograma (antes, un fotograma lento hacía que la captura se tomara
  antes de mover la cámara). Cámara del enemigo relativa a su posición real.
- Medición final (Vulkan): alta 101 llamadas / 67k primitivas / 37 de sombra · media 97 / 65k / 37 · baja 69 / 59k / 0.

## Pendiente / ideas
- Medir FPS reales en el S26 Ultra y en un gama media (calidades alta y media).
- El impermeable atraviesa un poco las piernas al correr (falda pesada a las piernas por distancia).
- Manos simples (manoplas); los dedos para los sellos serían el siguiente salto del personaje.
- Reflejos del agua: solo sonda estática + brillos; un reflejo planar del canal sería más fiel pero caro en móvil.
- Contorno del rostro de la torre poco legible desde la plaza en calidad baja (sin glow).


## M1 — mapa completo de la aldea (v0.6, noche)
- Isla en un lago con muralla, puente y 8 distritos generados por `tools/aldea.py`; 18 modelos de Meshy (Text to 3D,
  Smart Topology) procesados con `tools/blender/pieza_ia.py` (textura 1024/512 px, LOD lejano 160–2500 triángulos);
  piezas tipo Lego nuevas en `kit.py` (escalera, losa, columna, muro_aldea, torreta, chimenea, desagüe); texturas CC0
  de Poly Haven para suelo/concreto/lámina/techo.
- Atmósfera en todo el mapa: lluvia y capas de niebla que siguen a la cámara, charcos con ondas (170), vapor de
  chimeneas/talleres/azoteas, goteo de toldos y pasarelas, cascadas del canal, relámpagos alrededor de la cámara.
- Medido con `tools/captura_distritos.gd` (xvfb, renderizador móvil, 1280×720, calidad alta). **Los FPS de este entorno
  son de software (llvmpipe, 1–3 fps) y no sirven para el teléfono**: los FPS reales del S26 Ultra hay que leerlos en el
  panel de diagnóstico del juego (Ajustes → mostrar FPS). Lo comparable son llamadas de dibujo y primitivas:

| Vista | Llamadas | Primitivas | Sectores activos | Captura |
|---|---|---|---|---|
| d1_plaza_a_pie | 300 | 357k | 5 | ![](referencias/capturas-mapa/d1_plaza_a_pie.jpg) |
| d1_plaza_aereo | 332 | 358k | 5 | ![](referencias/capturas-mapa/d1_plaza_aereo.jpg) |
| d1_plaza_calle | 308 | 331k | 5 | ![](referencias/capturas-mapa/d1_plaza_calle.jpg) |
| d2_canal_a_pie | 173 | 270k | 4 | ![](referencias/capturas-mapa/d2_canal_a_pie.jpg) |
| d2_canal_aereo | 316 | 280k | 1 | ![](referencias/capturas-mapa/d2_canal_aereo.jpg) |
| d2_canal_calle | 133 | 181k | 5 | ![](referencias/capturas-mapa/d2_canal_calle.jpg) |
| d3_mercado_a_pie | 128 | 239k | 4 | ![](referencias/capturas-mapa/d3_mercado_a_pie.jpg) |
| d3_mercado_aereo | 187 | 251k | 3 | ![](referencias/capturas-mapa/d3_mercado_aereo.jpg) |
| d3_mercado_calle | 92 | 157k | 5 | ![](referencias/capturas-mapa/d3_mercado_calle.jpg) |
| d4_residencial_a_pie | 125 | 225k | 5 | ![](referencias/capturas-mapa/d4_residencial_a_pie.jpg) |
| d4_residencial_aereo | 106 | 171k | 5 | ![](referencias/capturas-mapa/d4_residencial_aereo.jpg) |
| d4_residencial_calle | 82 | 187k | 4 | ![](referencias/capturas-mapa/d4_residencial_calle.jpg) |
| d5_industrial_a_pie | 90 | 195k | 4 | ![](referencias/capturas-mapa/d5_industrial_a_pie.jpg) |
| d5_industrial_aereo | 154 | 190k | 2 | ![](referencias/capturas-mapa/d5_industrial_aereo.jpg) |
| d5_industrial_calle | 113 | 163k | 5 | ![](referencias/capturas-mapa/d5_industrial_calle.jpg) |
| d6_academia_a_pie | 89 | 195k | 4 | ![](referencias/capturas-mapa/d6_academia_a_pie.jpg) |
| d6_academia_aereo | 136 | 249k | 5 | ![](referencias/capturas-mapa/d6_academia_aereo.jpg) |
| d6_academia_calle | 118 | 194k | 6 | ![](referencias/capturas-mapa/d6_academia_calle.jpg) |
| d7_puerta_a_pie | 166 | 214k | 4 | ![](referencias/capturas-mapa/d7_puerta_a_pie.jpg) |
| d7_puerta_aereo | 251 | 246k | 1 | ![](referencias/capturas-mapa/d7_puerta_aereo.jpg) |
| d7_puerta_calle | 59 | 115k | 5 | ![](referencias/capturas-mapa/d7_puerta_calle.jpg) |
| d8_torre_a_pie | 164 | 242k | 7 | ![](referencias/capturas-mapa/d8_torre_a_pie.jpg) |
| d8_torre_aereo | 210 | 268k | 6 | ![](referencias/capturas-mapa/d8_torre_aereo.jpg) |
| d8_torre_calle | 51 | 118k | 7 | ![](referencias/capturas-mapa/d8_torre_calle.jpg) |
| e1_llegada_puente | 260 | 285k | 1 | ![](referencias/capturas-mapa/e1_llegada_puente.jpg) |
| e2_aldea_completa | 213 | 211k | 0 | ![](referencias/capturas-mapa/e2_aldea_completa.jpg) |

- Lo más pesado es la plaza (≈300 llamadas, ≈360k primitivas en alta): muchos tipos de objetos distintos en pocas
  celdas y la torre cerca. En calidad media/baja las distancias de dibujo bajan a 80/60 m (edificios) y 55/38 m (objetos).
- Siguiente: medir en el S26 Ultra; si la plaza no llega a 60 en alta, juntar los objetos pequeños en menos MultiMesh
  (celdas de 96 m para objetos) y bajar el LOD cercano de las casas.


## M2 — correcciones tras probar el mapa en el teléfono (v0.6.1)
Capturas en `referencias/capturas-correcciones/<vista>_antes.jpg` y `_despues.jpg` (guion `tools/captura_correcciones.gd`).

| Punto | Antes | Después |
|---|---|---|
| 1. Correr por paredes | ![](referencias/capturas-correcciones/p1_pared_antes.jpg) | ![](referencias/capturas-correcciones/p1_pared_seguir_despues.jpg) |
| 2. Canal y caminar sobre el agua | ![](referencias/capturas-correcciones/p2_canal_antes.jpg) | ![](referencias/capturas-correcciones/p2_canal_despues.jpg) |
| 2. Canal de lejos | ![](referencias/capturas-correcciones/p2_canal_lejos_antes.jpg) | ![](referencias/capturas-correcciones/p2_canal_lejos_despues.jpg) |
| 3. Torre no escalable | ![](referencias/capturas-correcciones/p3_torre_antes.jpg) | ![](referencias/capturas-correcciones/p3_torre_despues.jpg) |
| 4. Edificio con huecos | ![](referencias/capturas-correcciones/p4_casa_antes.jpg) | ![](referencias/capturas-correcciones/p4_casa_despues.jpg) |
| 6. Industrial (tinacos) | ![](referencias/capturas-correcciones/p6_industrial_antes.jpg) | ![](referencias/capturas-correcciones/p6_industrial_despues.jpg) |
| 7. Interactuar | — | ![](referencias/capturas-correcciones/p7_interactuar_despues.jpg) |
| 8. Barra del enemigo lejos | ![](referencias/capturas-correcciones/p8_lejos_del_enemigo_antes.jpg) | ![](referencias/capturas-correcciones/p8_lejos_del_enemigo_despues.jpg) |

- **El agua del canal nunca se había visto**: el acantilado de la isla era un cilindro con tapa y la tapa superior,
  2 cm bajo el suelo, cubría el canal. Sin tapas, el agua se ve; además se dibuja sin la niebla por altura (bajo el
  suelo es muy densa y la blanqueaba) y con poco reflejo especular (a ángulos rasantes reflejaba el cielo gris).
  Nuevo shader: azul profundo, vetas de corriente, espuma junto a los muros, brillo azul tenue en ángulos rasantes.
- Pared: el servidor manda la normal de la pared; la figura gira para quedar de pie y perpendicular sobre ella (12°
  hacia adelante), corre al 150 % de velocidad de animación, brillo azul en los pies, chispas y gotas en cada paso,
  la cámara se aparta de la pared y mira hacia arriba. Impulso al techo al llegar al borde, salto hacia atrás y
  resbalón sin chakra (servidor).
- Doble cara con interior casi negro en los modelos de Meshy con huecos (shader `toon_tex_doble`).
- Las capturas en este entorno van a ~4 fps (render por software); el guion espera varios cuadros por toma.


## M3 — personaje por piezas, NPCs y jutsus con modelo 3D (v0.7)

### Personaje por piezas
Cuerpo base de Meshy (imagen a imagen desde `ninja-frente.png` → imagen a 3D, 16,8k triángulos, textura 1024),
4 peinados de Meshy (solo malla; Meshy los genera sobre un maniquí con cara y busto, que se recorta en Blender usando
el cuerpo como referencia) y 4 prendas hechas en Blender copiando las caras del cuerpo con sus mismos pesos (se
deforman igual que el cuerpo) e infladas 2–3 cm, suavizadas y reducidas a ~3.500 triángulos.

| Frente | Espalda (emblema del clan en cada prenda) |
|---|---|
| ![](referencias/capturas-personajes/combinaciones_frente.jpg) | ![](referencias/capturas-personajes/combinaciones_espalda.jpg) |
| ![](referencias/capturas-personajes/combinaciones_cerca_1.jpg) | ![](referencias/capturas-personajes/combinaciones_cerca_2.jpg) |

### NPCs (guardia, ninja de agua, rebelde, comerciante, instructor y el ninja del campo)
| Frente | Espalda |
|---|---|
| ![](referencias/capturas-personajes/npcs_cerca_1.jpg) | ![](referencias/capturas-personajes/npcs_espalda.jpg) |
| ![](referencias/capturas-personajes/npcs_cerca_2.jpg) | ![](referencias/capturas-personajes/npcs_frente.jpg) |

### Jutsus con modelo (N1 | N2 | N3)
| Jutsu | N1 | N2 | N3 |
|---|---|---|---|
| Susanoo (costillas / torso con arco / armadura con espada, shader espectral morado) | ![](referencias/capturas-jutsus/susanoo_n1_b.jpg) | ![](referencias/capturas-jutsus/susanoo_n2_b.jpg) | ![](referencias/capturas-jutsus/susanoo_n3_b.jpg) |
| Kirin (bestia de rayo que cae; shader espectral azul + rayos) | ![](referencias/capturas-jutsus/kirin_n1_b.jpg) | ![](referencias/capturas-jutsus/kirin_n2_b.jpg) | ![](referencias/capturas-jutsus/kirin_n3_b.jpg) |
| Gran Dragón de Agua (1 / 2 / 3 dragones, shader de agua que fluye) | ![](referencias/capturas-jutsus/dragon_agua_n1_a.jpg) | ![](referencias/capturas-jutsus/dragon_agua_n2_a.jpg) | ![](referencias/capturas-jutsus/dragon_agua_n3_a.jpg) |
| Madera (raíces / bosque / dragón de madera que surge entre raíces) | ![](referencias/capturas-jutsus/madera_n1_a.jpg) | ![](referencias/capturas-jutsus/madera_n2_a.jpg) | ![](referencias/capturas-jutsus/madera_n3_a.jpg) |
| Golem de Tierra (se levanta del suelo; escala 0,8 / 1,4 / 2,6) | ![](referencias/capturas-jutsus/golem_tierra_n1_b.jpg) | ![](referencias/capturas-jutsus/golem_tierra_n2_b.jpg) | ![](referencias/capturas-jutsus/golem_tierra_n3_b.jpg) |

- Meshy da la forma (Text to 3D, solo malla 5 créditos; madera y golem con textura, 15) y el juego pone el
  material: espectral (Susanoo, Kirin), agua translúcida con flujo, espuma y ondulación (dragón de agua), textura
  de Meshy con el toon del kit (madera, golem). En N3 hay cámara lenta (ya existía para los cinco).
- El Kirin cae en 0,55 s: en las capturas de este entorno (~4 fps) se ve poco; en el teléfono se ve la caída entera.
- El dragón de madera de Meshy salió con alas (más «occidental» que oriental); se dejó porque se lee bien como
  dragón de madera y las raíces que brotan lo anclan al suelo.

### Rendimiento con NPCs y jutsu N3 (calidad alta, 1280×720)
| Vista | Llamadas | Primitivas | Captura |
|---|---|---|---|
| Puente con dos guardias | 270 | 484k | ![](referencias/capturas-jutsus/r0_puente_con_guardias.jpg) |
| Guardias + Susanoo N3 | 95 | 239k | ![](referencias/capturas-jutsus/r1_guardias_y_susanoo_n3.jpg) |
| Guardias + Golem N3 | 122 | 261k | ![](referencias/capturas-jutsus/r2_guardias_susanoo_y_golem_n3.jpg) |

Estimación: en el S26 Ultra la plaza va a 60 FPS con 558–635 llamadas (medido por el usuario); estas escenas están
por debajo de eso, así que se espera 60 en alta. Cada ninja por piezas cuesta ~4 llamadas y ~24k triángulos
(cuerpo 16,8k + prenda 3,5k + pelo 2,5k); los modelos de jutsus, 6–9k.

## M4 — ronda de calidad premium (v0.8)

Revisión cuadro a cuadro con herramientas nuevas: `tools/secuencia_anim.gd` (tiras de una animación con `seek`),
`tools/vista_efecto.gd` (efectos aislados con cámara fija, `--fixed-fps 30`) y guiones de `tools/captura.gd`
(`GUION=combate`, `kirin`, `locomocion`).

### Combate (combo de 5, lanzador + aéreos + remate, shunshin, choque)
![](docs/capturas/v08/combate_despues.jpg)

### Kirin: tormenta en remolino → dragón de rayo en espiral → destello → cráter con chispas (N2)
| Antes (rayo y destello, sin tormenta ni dragón visible) | Después |
|---|---|
| ![](docs/capturas/v08/kirin_antes_en_partida.jpg) | ![](docs/capturas/v08/kirin_despues.jpg) |

### Poderes con movimiento
| Dragones (agua / madera) con cadena de huesos | Gólem: surgir, caminar, golpe, derrumbe | Susanoo N3 por capas + espada |
|---|---|---|
| ![](docs/capturas/v08/dragones_despues.jpg) | ![](docs/capturas/v08/golem_despues.jpg) | ![](docs/capturas/v08/susanoo_n3_despues.jpg) |

### Plaza con edificios de Meshy
| Conceptos (imagen a imagen desde el edificio que gustó) | Antes / después (a pie, calle, aérea) |
|---|---|
| ![](docs/capturas/v08/plaza_variantes_concepto.jpg) | ![](docs/capturas/v08/plaza_antes_despues.jpg) |

### Locomoción y NPC (pared, agua, correr, guardia que ataca y cae)
![](docs/capturas/v08/locomocion_y_npc.jpg)

### Animaciones (antes de corregir: caer, correr viejo, caminar/correr/derribado/esquiva/golpeado/guardia/lanzado/muerte de Meshy, saltar)
![](docs/capturas/v08/animaciones_antes.jpg)
Lanzado y derribado, antes / después del tope de cadera:
![](docs/capturas/v08/lanzado_derribado_antes_despues.jpg)

### Problemas encontrados y corregidos
1. **Peinados con calva** (la coleta cubría el 88 %): búsqueda de colocación + gorro de cuero cabelludo → 96–100 %.
2. **Correr rígido** (animación propia): sustituida por la de Meshy retargeteada; golpes con tramos de animación real.
3. **Doble altura en «lanzado»** (la animación de Meshy ya sube 3 m y el servidor también lanza): tope de cadera.
4. **Dragones de espaldas**: el nodo avanza por −Z y los modelos miran a +Z; girados. El de agua (erguido) se tumba.
5. **Bolas de cola** sueltas detrás de los dragones: quitadas (el modelo ondula solo).
6. **Kirin invisible**: el sombreador espectral dejaba el dragón casi transparente → cuerpo emisivo sólido.
7. **Nubes de tormenta lavadas por la niebla** a 24 m de altura → material sin niebla y con brillo azul interior.
8. **Destellos apilados** en el Kirin N3 (varios rayos): uno por ráfaga.
9. **Shunshin que se deslizaba** (la interpolación unía las dos posiciones) → salto instantáneo a más de 3 m.
10. **Anillo de onda demasiado grueso y opaco** en los golpes fuertes → más fino y breve.
11. **Susanoo que aparecía de golpe** → capas que se encienden una tras otra; al apagarse, se deshace en partículas.
12. **Espada del Susanoo casi invisible de canto** → hoja más gruesa y estela en la punta.
13. **Gólem que «encoge» al terminar** → se derrumba en rocas y se hunde.
14. **Rival que seguía corriendo** en las capturas (entrada de IA sin limpiar) — solo en la herramienta.

### Rendimiento (calidad alta, 1280×720, renderizador móvil)
| Vista | Llamadas | Primitivas | v0.7 |
|---|---|---|---|
| Puente con guardias | 231 | 438k | 270 / 484k |
| Guardias + Susanoo N3 | 114 | 248k | 95 / 239k |
| Guardias + Susanoo N3 + gólem N3 | 134 | 259k | 122 / 261k |
| Plaza a pie / aérea | 237 / 342 | 520k / 571k | 236 / 341 · 497k / 521k |

![](docs/capturas/v08/rendimiento_guardias_susanoo_golem_n3.jpg)

Estimación: todas por debajo de las 558–635 llamadas que el usuario midió a 60 FPS en la plaza del S26 Ultra; con 3
enemigos y un jutsu N3 se espera 60 FPS en alta. Lo nuevo que más cuesta: los 3 edificios de la plaza (9k triángulos
cada uno con LOD de 900) y la tormenta del Kirin (≈100 partículas grandes durante 2 s).

### Pendiente
- El puñetazo del gólem estira la malla del brazo (pesos del rig automático de Meshy).
- El dragón de agua se lee poco de lejos (serpiente translúcida y fina).
- Las capturas de este entorno van a ~2–4 fps reales: los tiempos se fijan con `--fixed-fps`, pero conviene ver
  los efectos en el teléfono.
