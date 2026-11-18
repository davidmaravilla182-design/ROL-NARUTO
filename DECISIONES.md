# Decisiones tomadas

Registro de decisiones tomadas de forma autónoma durante el desarrollo del demo v0.1.

## Tecnología
- **Godot 4.7.2-stable** (la última estable 4.x disponible al empezar). Fijada en `project.godot` (features `4.7`), en el workflow (`GODOT_VERSION: 4.7.2`) y en las plantillas de exportación.
- **Renderizador Mobile**, con `rendering_device/fallback_to_opengl3=true`: si un teléfono no soporta Vulkan, Godot cae solo a Compatibility. No hizo falta cambiar a Compatibility.
- **APK solo arm64-v8a** para que pese menos; cubre prácticamente todos los Android de gama media actuales.
- Exportación **sin Gradle** (plantilla precompilada de Godot): más rápida y sin descargar el SDK completo en CI.

## Arte y animación
- No se pudieron descargar los modelos CC0 de Quaternius ni de Kenney: el entorno de desarrollo no tiene acceso a esos sitios. Según lo indicado, se creó un **humanoide low-poly por código**: `Skeleton3D` con 17 huesos, piezas rígidas fijadas con `BoneAttachment3D` y **14 animaciones generadas por código** (quieto, guardia, correr, saltar, esquivar, golpe 1/2/3, sellos, carga y embiste del rayo, lanzar, recibir golpe, caer).
- La ropa (banda con placa y 4 líneas, chaleco, vendas, sandalias abiertas, abanico del clan) también es geometría por código fijada a los huesos. Colores en `data/personajes.json`.
- Los sellos de manos se muestran como iconos de color con la inicial y el nombre del animal (no hay fuente con kanji incluida).
- **Sin audio**: no se incluyó ningún sonido para no arriesgar licencias. Queda pendiente añadir efectos CC0.

## Combate y balance
- La **reserva** y el **control** de chakra no son atributos aparte: se derivan de los 8 atributos con pesos en `reglas.json` (reserva = estamina + ninjutsu; control = sellos, inteligencia y genjutsu).
- El Uchiha de prueba: ninjutsu 5, velocidad 5, sellos 5, genjutsu 3, inteligencia 3, estamina 2, taijutsu 2, fuerza 1 (total 26).
- La naturaleza del defensor es la **primera** de su lista. Así el Uchiha (fuego) recibe +25 % del agua, y su fuego hace −25 % al ninja de agua. Bajo la lluvia el fuego queda muy débil contra él (×0.45): es intencional, el escenario premia el rayo.
- **Cadena de rayo**: sale del objetivo golpeado y salta a otros personajes vivos **que estén sobre un charco** a ≤ 7 m, con 50 % del daño; saltos por nivel 1/2/4. Los 3 muñecos están sobre charcos para poder verlo.
- **Asistencia de puntería**: la Bola de Fuego y el Chidori buscan al enemigo dentro de un cono que crece con el control de chakra (en móvil apuntar a mano sería frustrante). Prioriza al ninja enemigo sobre los muñecos.
- **Sharingan**: además del efecto visual, en el servidor los proyectiles que van hacia quien lo tiene activo avanzan al 50 % de velocidad (se ven y son más lentos). Los avisos de ataque los manda el servidor para todos y el cliente solo los dibuja si tu Sharingan está activo.
- El **embiste del Chidori** no se puede interrumpir con golpes (superarmadura); la carga sí.
- La IA espera 2.5 s al empezar y dispara ráfagas de 2 balas cada ~2.6 s. Una prueba automática verifica que **derrota a un jugador que no hace nada** en menos de 60 s.
- La bola de fuego grande (radio > 0.8 m) sale más alta y vuela horizontal para no chocar con el suelo al salir.

## Mundo
- El sector de Amegakure se genera con una **semilla** (`escenario.json`): 22 torres de metal con bandas, ventanas iluminadas y tuberías, pasarelas en altura entre torres cercanas, cajas, charcos, siluetas de torres lejanas, cielo gris, niebla y lluvia. El mismo generador (`Mapa`) lo usa el servidor para las colisiones.
- La física es propia del servidor (círculos contra cajas en el plano XZ + gravedad), sin el motor de física de Godot: es determinista y fácil de llevar a un servidor dedicado.

## Interfaz
- Resolución base 1280×720 con `stretch=canvas_items` y `aspect=expand`: en un teléfono de 6" los textos de 22–24 px base se ven a ~33–36 px reales.
- Orientación **horizontal con sensor** (gira entre las dos horizontales).
- Los botones de acción y el joystick usan eventos táctiles directos (multitáctil real). Se mantiene `emulate_mouse_from_touch` para que los botones normales (menú, depuración) funcionen con el dedo.

## Compilación y repositorio
- El workflow se dispara en push a `main` **y también a las ramas `claude/**`**, más `workflow_dispatch`. El desarrollo se hizo en la rama `claude/naruto-android-demo-9hzg4k` (no tenía permiso para escribir en `main`), y así el APK se compila y publica igual. Al fusionar a `main` seguirá funcionando.
- La keystore de debug se genera en el workflow y se **guarda en la caché de Actions** para que los APK sucesivos tengan la misma firma y se puedan instalar encima. Si la caché expira (7 días sin uso) se genera otra y habrá que desinstalar la versión anterior.
- El release `demo-latest` se borra y se vuelve a crear en cada compilación, con el APK en un enlace fijo.
- `tools/verificar.sh` (importar + pruebas + humo) corre en el hook de pre-commit (`.githooks/pre-commit`) y también en CI antes de exportar.
