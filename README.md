# Sombras de la Lluvia — demo de fans (v0.3)

> **Proyecto de fans sin fines de lucro. Sin relación con Masashi Kishimoto, Shueisha ni Bandai Namco.**
> Sin anuncios, sin compras y sin música ni audio del anime.

Demo jugable para Android hecho con **Godot 4.7.2**. Controlas a un ninja del clan Uchiha (naturalezas de **fuego** y **rayo**) que entrena y pelea en un sector de **Amegakure**, la Aldea Oculta de la Lluvia: torres de metal, tuberías, pasarelas, charcos, niebla y lluvia constante.

En el campo de entrenamiento hay **3 muñecos de práctica** y un **ninja de la Lluvia** con naturaleza de agua que se acerca, dispara balas de agua, esquiva a veces y huye cuando le queda poca vida. Si juegas mal, te gana.

La lluvia cambia el combate:
- 🔥 **Fuego**: hace **40 % menos daño** y sale más pequeño.
- ⚡ **Rayo**: hace **30 % más daño** y **salta en cadena** a los enemigos que estén parados sobre charcos (los muñecos están sobre charcos para que lo pruebes).

## Descargar e instalar el APK en Android

1. Desde el navegador de tu celular abre este enlace directo:
   **https://github.com/davidmaravilla182-design/ROL-NARUTO/releases/download/demo-latest/sombras-de-la-lluvia-demo.apk**
   (también está en la sección *Releases* del repositorio, como «demo-latest»).
2. Si el repositorio es privado, primero inicia sesión en GitHub en el navegador.
3. Cuando termine la descarga, toca el archivo `.apk`.
4. Android te pedirá permiso para **instalar apps de origen desconocido**:
   - Toca **Configuración** en el aviso.
   - Activa **Permitir de esta fuente** para la app con la que descargaste (Chrome, Archivos, etc.).
   - Vuelve atrás y toca **Instalar**.
   - (En algunos teléfonos: *Ajustes → Seguridad → Fuentes desconocidas* o *Ajustes → Apps → Acceso especial → Instalar apps desconocidas*.)
5. Si Play Protect muestra un aviso, toca **Más detalles → Instalar de todas formas**. Es normal: el APK está firmado con una clave de depuración, no de tienda.
6. Si al actualizar dice «la app no se instaló» o «conflicto con un paquete existente», **desinstala la versión anterior** y vuelve a instalar.

Requisitos: Android de 64 bits (arm64), Android 7 o superior. Meta: 30 fps o más en gama media.

Cada vez que se hace push, GitHub Actions compila un APK nuevo y reemplaza el release `demo-latest`.

## Novedades de la v0.3 (gráficos)

- **Nueva aldea** modelada en Blender por código: edificios de concreto con toldos y faroles, silos con balcones y agujas, tanques de agua, arcos de tuberías granate, un **canal** con agua animada, cascadas desde los desagües, puentes de celosía, vapor, cables colgantes y un horizonte de torres entre la niebla.
- **Torre monumental con rostro** al fondo (banda en la frente, ojos de anillos, boca abierta con lengua), iluminada con focos.
- **Texturas procedurales** horneadas en Blender (concreto manchado, lámina con remaches y óxido, tuberías pintadas, placas de suelo, techos corrugados, rejillas) con mapas de normales y humedad: el suelo se ve mojado y las paredes tienen chorreaduras.
- **Personaje con cuerpo continuo** (piel deformable, sin piezas sueltas) y **chaleco** que se dobla con el cuerpo.
- Paleta como las referencias: violetas fríos, tuberías granate y luz ámbar.
- **Rendimiento**: las llamadas de dibujo bajaron de 238 a 99 en calidad alta (67 en baja).

## Novedades de la v0.4: repertorio de 40 jutsus

- Botón **Repertorio** en la pantalla de inicio. Pestañas por tipo (Fuego, Rayo, Agua, Tierra, Viento, Sin naturaleza, Kekkei genkai, Ojos, Cuerpo) y filtro **Solo disponibles**.
- Cada tarjeta muestra icono, color del tipo, **puntos**, requisito y el nivel de maestría (●○○). Tócala para ver los **3 niveles** con su vista previa animada, la ventaja y la desventaja.
- **Arrastra** tarjetas a las 4 ranuras y a la ranura **MODO** (Sharingan, Mangekyō, Rinnegan, Byakugan, Ocho Puertas…). Tope: **12 puntos**. El taijutsu básico siempre está.
- Si no cumples un requisito (naturaleza, linaje, rango, atributos) la tarjeta sale bloqueada con el motivo. Hay incompatibles: Ocho Puertas o Modo Sabio no van con ojos; Rinnegan y Mangekyō no van juntos.
- **3 repertorios guardados** (R1, R2, R3). En cada ranura puedes tocar «Usar» para limitar el nivel (el más alto / N1 / N2 / N3).
- **Maestría**: usar y acertar un jutsu le da experiencia; a 100 XP se desbloquea N2 y a 300 XP el N3 (más grande, cámara lenta, sacudida y marcas en el escenario). Cada nivel cuesta más chakra.
- Interruptor **Modo prueba: desbloquear todo** para probar todo sin requisitos.
- **Los 40 jutsus y los 6 modos funcionan en sus 3 niveles.** El personaje de prueba solo cumple los requisitos de fuego, rayo y sus ojos; para usar los de agua, tierra, viento, kekkei genkai, Byakugan o Rinnegan activa **«Modo prueba: desbloquear todo»** en el menú.

## Novedades de la v0.2

- **Apuntado táctil**: toque rápido = auto-apuntado; mantener y arrastrar = indicador en el suelo y disparo al soltar; zona de **Cancelar** para no gastar chakra.
- **Fijar objetivo** (botón de mira): la cámara sigue al enemigo y un toque cambia de objetivo.
- **Interfaz nueva**: botones en arco con iconos propios, recarga en barrido circular, costo de chakra, vibración, retrato con barras animadas y menú de **Ajustes**.
- **Gráficos**: cel shading estilo anime con contorno negro, ojos que cambian al Sharingan, charcos con ondas, metal mojado con reflejos, nubes en movimiento, niebla por capas, relámpagos con trueno, bola de fuego con fuego animado y distorsión de calor, Chidori con rayos ramificados y sonido de pájaros, pausa de impacto y cámara lenta en nivel 3.

## Controles (pantalla horizontal)

| Control | Acción |
|---|---|
| **Joystick** (mitad izquierda) | Moverse. Aparece donde pones el dedo. |
| **Arrastrar** en la mitad derecha | Girar la cámara (tercera persona). |
| **Puño** (botón grande) | Combo de taijutsu de 3 golpes (púlsalo seguido; el tercero derriba). |
| **Llama** — Bola de Fuego | **Toque**: apunta solo al enemigo más cercano frente a la cámara (o hacia donde mira la cámara). **Mantener y arrastrar**: aparece una franja en el suelo que sigue tu dedo; suelta para lanzar. |
| **Rayo** — Chidori | Igual: toque = auto-apuntado; mantener y arrastrar = flecha de embiste en el suelo. Carga chispas y embiste en línea recta. |
| **Cancelar** | Mientras apuntas aparece un círculo con una ✕. Si sueltas el dedo encima, se cancela y **no gasta chakra**. |
| **Ojo** — Sharingan | Ojos rojos con tomoe, ves los avisos de ataques enemigos y sus proyectiles van más lentos. Gasta chakra cada segundo. |
| **Mira** — Fijar objetivo | Fija al enemigo más cercano: la cámara lo sigue y queda marcado con un anillo rojo. Cada toque cambia al siguiente objetivo cercano; después del último, se libera. Los jutsus van al objetivo fijado. |
| **Flechas** — Esquivar | Salto lateral rápido (hacia donde apuntas el joystick). Eres invulnerable un instante. |
| **Flecha arriba** — Saltar | Salto. |

Cada botón muestra un **barrido oscuro con los segundos** de recarga y una placa con el **costo de chakra**. Si no te alcanza el chakra, el botón se pone gris y la placa roja. Al tocarlo, el botón se encoge, brilla y el celular vibra un poco.

Arriba a la izquierda está tu **retrato** con las barras de **Vida**, **Chakra** (se regenera lento) y **Estamina**. El enemigo tiene su barra arriba a la derecha. Los números de daño tienen el color de la naturaleza (naranja fuego, celeste rayo, azul agua, blanco golpe) y son **más grandes con «!»** cuando hay ventaja de naturaleza.

### Ajustes

Botón **Ajustes** (arriba a la derecha o en la pantalla de inicio):
- **Tamaño de botones** y **Opacidad de botones**.
- **Sensibilidad de cámara**.
- **Calidad gráfica**: **Alta** (por defecto), Media o Baja. Media y Baja quitan efectos caros (contornos del escenario, distorsión de calor, nubes, niebla, menos partículas, menor resolución 3D) para ir a 30 fps en gama media. Al cerrar el menú se reinicia el entrenamiento con la calidad nueva.
- **Vibración** sí/no y **Mostrar FPS**.

Con teclado (PC): WASD mover, J golpe, K/L/U/I las 4 ranuras del repertorio, Q activar/desactivar el MODO, Shift esquivar, Espacio saltar.

## Niveles de poder (depuración)

Arriba a la derecha está el botón de nivel. Cada toque lo cambia: **Auto → 1 → 2 → 3 → Auto**. «Auto» usa el nivel que tengas desbloqueado por maestría; 1/2/3 lo fuerzan para probar. Afecta a todos los jutsus:

- **Nivel 1**: técnica pequeña y barata.
- **Nivel 2**: más grande, más partículas, humo, más luz, sacudida de cámara y marcas en el suelo.
- **Nivel 3**: la Bola de Fuego es **enorme** (deja un anillo de llamas y quemaduras) y el Chidori **ilumina todo el escenario**, agrieta el suelo y salta por más charcos. Cuesta mucho chakra.

Otros botones de depuración:
- **Reaparecer**: revive al enemigo, a los muñecos y a ti con todo lleno.
- **Ajustes**: abre el menú de ajustes.
- **Menú**: vuelve a la pantalla de inicio.

## Para desarrolladores

- Arquitectura (servidor/cliente, protocolo, carpetas): [ARQUITECTURA.md](ARQUITECTURA.md)
- Decisiones tomadas durante el desarrollo: [DECISIONES.md](DECISIONES.md)
- Licencias y créditos: [assets/LICENCIAS.md](assets/LICENCIAS.md)
- Todos los datos de diseño (nombres, jutsus, atributos, textos) están en [`/data`](data). Cambiar esos JSON renombra o rebalancea el juego sin tocar código.
- Verificación local (headless): `tools/verificar.sh` (importa el proyecto, corre 89 pruebas de combate, 81 del repertorio y una prueba de humo). Hook de pre-commit: `git config core.hooksPath .githooks`.
