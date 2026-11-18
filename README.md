# Sombras de la Lluvia — demo de fans (v0.1)

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

## Controles (pantalla horizontal)

| Control | Acción |
|---|---|
| **Joystick** (mitad izquierda) | Moverse. Aparece donde pones el dedo. |
| **Arrastrar** en la mitad derecha | Girar la cámara (tercera persona). |
| **Golpe** | Combo de taijutsu de 3 golpes (púlsalo seguido; el tercero derriba). |
| **Bola de Fuego** | Sellos de manos (aparecen como iconos en pantalla) y luego una esfera de fuego. |
| **Chidori** | Cargas chispas en la mano y luego embistes rápido en línea recta. |
| **Sharingan** | Modo activable: ojos rojos, ves el aviso de los ataques enemigos antes de que lleguen y los proyectiles enemigos van más lentos. Gasta chakra cada segundo. Vuelve a tocar para apagarlo. |
| **Esquivar** | Salto lateral rápido (hacia donde apuntas el joystick; si no lo tocas, hacia la derecha). Eres invulnerable un instante. |
| **Saltar** | Salto. |

Cada botón muestra un sector oscuro y los **segundos de recarga** que faltan. Si un botón se ve apagado es que no tienes chakra o estamina suficientes.

Arriba a la izquierda están tus barras de **Vida**, **Chakra** (se regenera lento) y **Estamina**. Arriba al centro, la vida del enemigo. Los números flotantes muestran el daño: ▲ = ventaja de naturaleza, ▼ = desventaja.

Con teclado (PC): WASD mover, J golpe, K bola de fuego, L chidori, Q sharingan, Shift esquivar, Espacio saltar.

## Niveles de poder (depuración)

Arriba a la derecha está el botón **«Nivel 1»**. Cada toque lo cambia: **1 → 2 → 3 → 1**. Afecta a la Bola de Fuego y al Chidori:

- **Nivel 1**: técnica pequeña y barata.
- **Nivel 2**: más grande, más partículas, humo, más luz, sacudida de cámara y marcas en el suelo.
- **Nivel 3**: la Bola de Fuego es **enorme** (deja un anillo de llamas y quemaduras) y el Chidori **ilumina todo el escenario**, agrieta el suelo y salta por más charcos. Cuesta mucho chakra.

Otros botones de depuración:
- **Reaparecer**: revive al enemigo, a los muñecos y a ti con todo lleno.
- **Menú**: vuelve a la pantalla de inicio.

## Para desarrolladores

- Arquitectura (servidor/cliente, protocolo, carpetas): [ARQUITECTURA.md](ARQUITECTURA.md)
- Decisiones tomadas durante el desarrollo: [DECISIONES.md](DECISIONES.md)
- Licencias y créditos: [assets/LICENCIAS.md](assets/LICENCIAS.md)
- Todos los datos de diseño (nombres, jutsus, atributos, textos) están en [`/data`](data). Cambiar esos JSON renombra o rebalancea el juego sin tocar código.
- Verificación local (headless): `tools/verificar.sh` (importa el proyecto, corre 82 pruebas de combate y una prueba de humo). Hook de pre-commit: `git config core.hooksPath .githooks`.
