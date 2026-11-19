# Prueba de arte con modelos 3D generados por IA

Comparación: `comparacion_antes_despues.png` (mismas cámaras; arriba antes, abajo después).
Capturas con `GUION=comparar` en `tools/captura.gd` (OpenGL, calidad alta, 1280×720).

## Torre
- **Geometría**: Meshy (499.534 triángulos) reducida a **29.963** (LOD0), **9.728** (LOD1, remallado por vóxeles 0,35 m)
  y **2.990** (LOD2, vóxeles 0,9 m). Rangos de visibilidad: 0–130 m, 130–260 m, más de 260 m.
  Se conservan el rostro, la lengua con su barandal, las agujas y las tuberías.
- **Color**: TRELLIS alineado sobre Meshy con escala por eje y ajuste fino (distancia media 0,54 % de la altura).
  El horneado a textura UV **no sirvió**: la malla reducida de Meshy se despliega en ~9.000 islas que cubren el 12–15 %
  del atlas (textura "polvo"). Se transfirió el color **por vértice** (punto más cercano de TRELLIS) y el shader suma
  detalle triplanar de metal/concreto, metal mojado y chorreaduras de lluvia.
- **Ojos**: discos con anillos concéntricos morados y brillo leve (posición detectada por color en TRELLIS y
  ajustada con un rayo sobre Meshy). **Ventanas**: 126 quads ámbar emisivos colocados por raycast en paredes planas.
- **Lengua**: plataforma con colisión en el servidor (`Mapa.plataformas`: se puede caer encima y los proyectiles
  chocan). La torre está detrás del canal, fuera del área jugable, como la torre anterior.
- Reproducible: `tools/blender/torre_ia.py` (~40 s).

## Ninja
- Meshy (15.621 triángulos, textura reducida de 2048 a 1024 px para el celular).
- **Esqueleto**: los 17 huesos del juego colocados en las articulaciones medidas sobre la malla; pesos por distancia
  a los huesos; los brazos (pose A, 22,6° de apertura) se bajan y esa postura queda como reposo, así funcionan
  todas las animaciones existentes sin tocarlas.
- **Emblema**: parche ajustado a la espalda por raycast con su propia textura por clan (`tools/emblemas.py`:
  abanico rojo y blanco, anillo con venas, flor de papel, hoja, copo, volcán, ave, calabaza y el símbolo de la aldea).
- **Nudo de la banda**: pieza aparte en la nuca; las puntas se mecen y se van hacia atrás al correr.
- **Personalización** (ver abajo).
- Reproducible: `tools/blender/ninja_ia.py` (~10 s).

### Personalización con el modelo IA
| Opción | ¿Funciona? | Cómo |
|---|---|---|
| Color de piel, cabello, chaleco, camisa y pantalón | Sí | Zonas por vértice (piel/pelo/chaleco/ropa) + recoloreo en el shader que conserva pliegues y brillos |
| Peinado "puntas" | Sí | Es el cabello del modelo (malla aparte) |
| Otros peinados (corto, largo, coleta, melena) | Sí, con matices | Se oculta el cabello del modelo y se pone el peinado del juego reescalado; "corto" se ve como casco |
| Complexión | Sí | Escala del cuerpo (igual que antes) |
| Ropa ligera / chaleco | Sí | Colores de la ropa |
| Sigilo (máscara) | Sí | Pieza del juego en la cara |
| Impermeable | Parcial | La capa del cuerpo anterior no encaja en este esqueleto (sus poses de enlace son de otro reposo); se recolorea el chaleco y la camisa como abrigo |
| Color de ojos | Solo en modo ocular | Los ojos están pintados en la textura; los ojos del juego (Sharingan y demás) aparecen al activar un modo |

**Por qué hay límites**: el modelo IA es una sola malla con una sola textura; la ropa, el cabello y los ojos están
"pintados" y fundidos en ella, no son piezas separadas. Se puede recolorear por zonas, pero no cambiar de prenda.
**Propuesta**: pedir a la IA (o modelar en Blender) piezas separadas sobre el mismo cuerpo base en pose A
(cuerpo sin ropa, 3–4 chalecos/abrigos, 4–5 cabellos), riggearlas con este mismo script y combinarlas en el juego,
o generar el ninja con la ropa en una textura y las zonas en una máscara de color plano para recolorear exacto.

## Medidas (calidad alta, OpenGL, 1280×720)
| Cámara | Llamadas antes → después | Triángulos antes → después |
|---|---|---|
| Torre desde el campo | 290 → 260 | 60,6k → 78,8k |
| Torre cerca | 89 → 77 | 41,6k → 61,4k |
| Panorámica | 322 → 236 | 63,2k → 87,9k |
| Juego (detrás del jugador) | 363 → 278 | 67,5k → 111,1k |
| Ninja de frente | 164 → 85 | 41,1k → 64,9k |
| Ninja de espalda | 258 → 173 | 60,4k → 104,1k |
| Ninja de lado | 290 → 211 | 51,1k → 74,9k |

Memoria de video: 301,4 MB → 308,0 MB (+6,6 MB; con la textura del ninja en 2048 px eran +18,6 MB).
Memoria de buffers: 9,7 → 11,9 MB. APK: +4,2 MB de modelos (torre 2,3 MB, ninja 1,9 MB).

Lectura: **menos llamadas de dibujo** (el personaje anterior eran decenas de piezas; el nuevo son 3 mallas) y
**más triángulos** (~+20k por la torre, ~+31k por el ninja con su contorno). En móvil las llamadas de dibujo suelen
pesar más que los triángulos a este nivel, así que el costo neto es moderado.

## Recomendación
**Sí, adoptarlo para piezas únicas y personajes; no para todo el mundo.**
- **Hitos y piezas únicas** (torres, estatuas, puertas): ganan muchísimo en forma y lectura; con este flujo
  (Meshy para la forma + TRELLIS para el color + reducción + LOD) salen en minutos y caben en el presupuesto.
- **Personajes**: la forma y la textura son mucho mejores, pero para personalizar hay que pedir piezas separadas
  (ver propuesta). Para enemigos y PNJ sin personalización, se puede usar ya.
- **Piezas repetidas del escenario** (edificios, tuberías, barandales): mantener el kit procedural de Blender.
  Se repiten cientos de veces con MultiMesh (una llamada por tipo) y comparten texturas tileables; un modelo IA por
  pieza rompería ese ahorro, y las IA no dan piezas modulares que encajen entre sí.
- **Mejoras para la siguiente tanda**: pedir a Meshy la textura además de la forma (evita la transferencia),
  geometría ya reducida (~30k), y para personajes la pose A con ropa y cabello separados.
