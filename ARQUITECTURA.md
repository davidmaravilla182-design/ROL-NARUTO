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

Comandos: `entrada {mov, mira}`, `accion {id}`, `nivel {valor}`, `reaparecer`.
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
scripts/cliente/    escena de juego, personaje, vestimenta, animaciones, escenario, lluvia, efectos, cámara
scripts/ui/         menú, HUD, joystick, botones, barras
tests/              pruebas.gd (matemática y servidor) y humo.gd (carga menú y partida)
tools/              verificar.sh (pre-commit/CI) y captura.gd (capturas con pantalla virtual)
.github/workflows/  compilación del APK y publicación en el release demo-latest
```

## Rendimiento móvil

- Escenario con **MultiMesh** (torres, ventanas, tuberías, pasarelas, charcos): pocas llamadas de dibujo.
- Lluvia: 2 sistemas GPU (≈1400 gotas + 220 salpicaduras) que siguen a la cámara.
- Solo 3 luces fijas; las demás son temporales (efectos). Sombras solo de la luz direccional, a 30 m.
- Simulación a 30 ticks/s; el cliente interpola.
