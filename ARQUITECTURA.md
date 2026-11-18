# Arquitectura

Godot **4.7.2-stable**, GDScript, renderizador **Mobile** (con caída automática a Compatibility/OpenGL si el teléfono no tiene Vulkan). Todo el mundo, el personaje, las animaciones y la interfaz se generan **por código**: las escenas `.tscn` solo tienen un nodo raíz con su script.

## Principio: servidor autoritativo + cliente tonto

```
 ┌──────────── CLIENTE (cliente_juego.gd) ────────────┐        ┌──────── SERVIDOR (servidor_juego.gd) ────────┐
 │ Entrada táctil/teclado ──► comandos                │        │ recibir_comando(peer, cmd)                    │
 │                              │                     │        │   └► Protocolo.sanear_comando (valida todo)   │
 │                              ▼                     │        │ paso(dt) a 30 ticks/s:                        │
 │                     Transporte.enviar(cmd) ────────┼──────► │   recursos, IA, estados, movimiento,          │
 │                                                    │        │   proyectiles, daño, naturalezas, lluvia      │
 │ Dibuja estado ◄── señal estado_recibido(estado) ◄──┼─────── │ publicar_estado() → instantánea + eventos     │
 └────────────────────────────────────────────────────┘        └───────────────────────────────────────────────┘
```

- **Servidor** (`scripts/servidor/`): toda la lógica. Vida, chakra, estamina, recargas, combo, sellos, ventajas de naturaleza, efecto de la lluvia, cadena de rayo en charcos, asistencia de puntería según el control de chakra, modo ocular (ralentiza proyectiles que van hacia ti) e IA enemiga. No crea nodos visuales; puede correr en un proceso sin pantalla.
- **IA** (`ia_enemigo.gd`): corre en el servidor y actúa enviando **los mismos comandos** que un jugador (`entrada`, `accion`) por `aplicar_comando`.
- **Cliente** (`scripts/cliente/`, `scripts/ui/`): lee la entrada, manda comandos y dibuja la última instantánea (interpolando posiciones). Los efectos visuales se disparan con los **eventos** que trae cada instantánea. El cliente nunca calcula daño.
- **Núcleo compartido** (`scripts/core/`): `Datos` (carga JSON), `Combate` (matemática pura), `Mapa` (generación determinista con semilla: el servidor lo usa para colisiones y charcos, el cliente para dibujar), `Protocolo` (formato de mensajes).

## Transporte (lo que permite pasar a online)

`scripts/red/transporte.gd` define la interfaz única que conoce el cliente:

| Miembro | Uso |
|---|---|
| `enviar(cmd: Dictionary)` | cliente → servidor |
| señal `estado_recibido(estado)` | servidor → cliente |
| señal `conectado(id_entidad)` | el servidor asignó una entidad al jugador |

- `TransporteLocal` (modo offline actual): servidor y cliente en el mismo proceso; copia profunda de cada mensaje, igual que si viajara por red.
- `TransporteENet` (preparado): misma interfaz sobre `ENetMultiplayerPeer` + RPC. Las entradas viajan `unreliable_ordered` y las acciones `reliable`. El servidor ya admite varios peers (`agregar_jugador(peer_id)`, `quitar_jugador`) y envía a cada uno su instantánea con `tu_entidad`.

Para jugar en red bastará con crear `TransporteENet` en lugar de `TransporteLocal` en `cliente_juego.gd` (o en un ejecutable de servidor dedicado), sin tocar el combate. Pendiente para ese paso: mandar los eventos por un canal fiable (hoy van dentro de la instantánea), predicción local del movimiento y compresión de instantáneas.

## Protocolo

Todos los mensajes son `Dictionary` con tipos serializables por Godot (int, float, String, Vector2/3, Array, Dictionary). Detalle completo en `scripts/core/protocolo.gd`.

Comandos: `entrada {mov, mira}`, `accion {id, dir, objetivo, exacto}`, `nivel {valor}`, `reaparecer`.

**Apuntado (v0.2)**: la dirección del disparo viaja dentro del comando `accion`, igual offline y en red:
- `dir` (Vector2 en el plano XZ del mundo), `objetivo` (id de entidad fijada o `-1`) y `exacto` (true si el jugador arrastró la dirección a mano).
- El servidor decide: objetivo fijado válido (vivo, rival, a rango) → dirección exacta (arrastre, sin asistencia) → asistencia en cono alrededor de `dir` según el control de chakra.
- El cliente calcula el auto-apuntado del toque rápido (enemigo más cercano frente a la cámara) solo para *proponer* `dir`/`objetivo`; el servidor lo valida. Cancelar un apuntado no envía nada, por eso no gasta chakra.
- Pausa de impacto y cámara lenta son **solo visuales** (`Engine.time_scale` en el cliente); el servidor avanza con tiempo real, así que en red no afectan a otros jugadores.
Estado: `{tick, clima, tu_entidad, entidades[], proyectiles[], eventos[]}`.
Eventos: `sellos, lanzar, chidori_carga, chidori_embiste, impacto, explosion, cadena, aviso, esquiva, salto, golpe, derrota, sharingan, nivel, reaparecer, mensaje`.

## Datos de diseño (`/data`)

| Archivo | Contenido |
|---|---|
| `reglas.json` | Tope de atributos (0–5, máx. 26), fórmulas (reserva/control, regeneración, escalados), clima, duración de estados. |
| `mundo.json` | Título, aldeas, clanes, naturalezas y ciclo de ventajas, sellos de manos. |
| `jutsus.json` | Costos, daño, alcance, tiempo de sellos, recargas y los **3 niveles** de cada técnica (incluye partículas, luz, sacudida y marcas que usa el cliente). |
| `personajes.json` | Plantillas: Uchiha de prueba, ninja de la Lluvia (con parámetros de IA) y muñeco. Aspecto/colores de la ropa. |
| `escenario.json` | Semilla y parámetros del sector procedural, colores y cantidad de lluvia. |
| `textos.json` | Todos los textos de la interfaz en español. |
| `graficos.json` | Preajustes de calidad (baja/media/alta), pausa de impacto, cámara lenta y frecuencia de relámpagos. |

Los nombres de la serie solo existen en `/data` (una prueba automática lo vigila). En el código solo hay **identificadores** internos estables (`bola_fuego`, `chidori`, `sharingan`, `lluvia`...).

### Fórmulas principales

- Reserva = 0.5·estamina + 0.5·ninjutsu. Control = 0.4·sellos + 0.3·inteligencia + 0.3·genjutsu.
- Costo = base_nivel · (1 + 0.08·reserva) · (1 − 0.07·control) → más reserva cuesta más, más control ahorra.
- Daño ninjutsu = base_nivel · (1 + 0.08·ninjutsu) · (1 + 0.05·reserva) · naturaleza (×1.25 / ×0.75) · clima.
- Tamaño = radio_nivel · (1 + 0.06·reserva) · clima (fuego ×0.75 bajo lluvia).
- Puntería asistida = 10° + 6°·control. Tiempo de sellos = base · (1 − 0.09·sellos).

## Carpetas

```
data/               datos de diseño (JSON)
escenas/            menu.tscn y juego.tscn (solo nodo raíz + script)
scripts/core/       Datos, Combate, Mapa, Protocolo
scripts/servidor/   ServidorJuego, EntidadServidor, IaEnemigo
scripts/red/        Transporte, TransporteLocal, TransporteENet
scripts/cliente/    escena de juego, personaje, vestimenta, animaciones, escenario, lluvia, efectos, cámara,
                    shaders (toon, contorno, fuego, calor, charcos, nubes, niebla, ojos, indicadores),
                    rayos ramificados, sonidos sintetizados, indicadores de apuntado, ajustes
scripts/ui/         menú, HUD, estilo (fuentes y marcos), iconos, botón de jutsu, retrato, ajustes, joystick
assets/fuentes/     Shojumaru y Rajdhani (licencia SIL OFL)
tests/              pruebas.gd (matemática y servidor) y humo.gd (carga menú y partida)
tools/              verificar.sh (pre-commit/CI) y captura.gd (capturas con pantalla virtual)
.github/workflows/  compilación del APK y publicación en el release demo-latest
```

## Gráficos (v0.2)

- **Cel shading**: `Shaders.TOON` reemplaza a todos los materiales sólidos (`Materiales.solido`): 3 bandas de luz con sombra fría, luz de contorno (rim) y brillo duro en metales. El **contorno negro** es una segunda pasada (`next_pass`) con casco invertido inflado en espacio mundo, con grosor que se adapta a la distancia.
- **Fuego**: esfera con shader de ruido fbm animado (núcleo blanco-amarillo, cuerpo naranja, borde rojo y superficie que ondula), esfera de **distorsión de calor** que refracta la pantalla (solo calidad alta), humo y brasas.
- **Rayo**: `Rayos` genera rayos ramificados por subdivisión del punto medio y los dibuja como cintas orientadas a la cámara en un solo `ImmediateMesh`.
- **Atmósfera**: suelo PBR mojado + `ReflectionProbe` (sin SSR), charcos con ondas procedurales, nubes en un plano alto con ruido, bancos de niebla en anillos + niebla por altura, relámpagos en el cielo con destello y trueno retardado según la distancia.
- **Sonido**: `Sonidos` sintetiza por código los efectos (rayo con trinos, fuego, explosión, golpe, trueno, chapoteo, lluvia).

## Rendimiento móvil

- Escenario con **MultiMesh** (torres, ventanas, tuberías, pasarelas, charcos): pocas llamadas de dibujo.
- Lluvia: 2 sistemas GPU (≈1400 gotas + 220 salpicaduras) que siguen a la cámara.
- Solo 3 luces fijas; las demás son temporales (efectos). Sombras solo de la luz direccional, a 30 m.
- Simulación a 30 ticks/s; el cliente interpola.
- Calidad **baja/media** (`data/graficos.json`): sin contorno del escenario, sin distorsión de calor, menos gotas y partículas, escala 3D 0.7–0.85, sombras opcionales, menos luces y capas de niebla; tope de 30 fps.
