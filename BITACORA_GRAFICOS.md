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
