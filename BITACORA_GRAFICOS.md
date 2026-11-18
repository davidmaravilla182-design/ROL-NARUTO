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
