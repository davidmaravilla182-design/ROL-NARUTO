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
- `TransporteENet` (red local, v0.5): misma interfaz sobre `ENetMultiplayerPeer` + RPC. Un mismo nodo llamado `Red` hace de anfitrión (`crear_servidor`) o de invitado (`unirse`); cada uno usa su propia `SceneMultiplayer` en su rama del árbol, así varias instancias conviven en un proceso (prueba automática).

### Red local (listen server)
- **Anfitrión**: el celular que crea la partida corre el `ServidorJuego` con autoridad; su propio jugador entra por `TransporteLocal` (peer 1, sin latencia) y los invitados por `TransporteENet`. Máximo 4 jugadores (`data/red.json`); el quinto recibe «partida llena».
- **Invitados**: solo mandan comandos (`entrada` numerada a 30/s sin garantía; acciones, repertorio y personaje fiables).
- **Instantáneas**: ~20/s por invitado, comprimidas (ZSTD) y sin garantía; lo que llega tarde se descarta. Las recargas y niveles de los demás no viajan. Los **eventos** viajan aparte por un canal fiable y el cliente los reinyecta en la siguiente instantánea (el cliente los procesa igual que offline).
- **Predicción** (`scripts/cliente/prediccion.gd`): el invitado mueve a su personaje al instante con la misma regla y colisiones del servidor; en cada instantánea parte de la posición del servidor y reaplica las entradas que aún no se procesaron (`ultima_entrada`). Solo cuando está libre: en jutsus, golpes y empujes manda el servidor. La corrección se suaviza (de golpe si el error supera 3 m).
- **Interpolación**: los demás se dibujan 100 ms en el pasado, interpolando entre dos instantáneas.
- **Descubrimiento** (`scripts/red/descubrimiento.gd`): el anfitrión anuncia cada segundo por difusión UDP (puerto 7778) con una firma; los invitados escuchan y listan. También se puede escribir la IP que muestra el anfitrión.
- **Diagnóstico**: ping (ida y vuelta), pérdida (huecos en la numeración de instantáneas) y jugadores. **Simulador** de mala conexión en el invitado: retraso, variación y pérdida de paquetes sin garantía (`data/red.json → simulador`).
- **Equipos**: cada jugador está en su propio equipo (todos contra todos) y todos contra la IA.
- **Permisos Android**: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`.

### Personajes
- `data/creacion.json`: apariencia (peinados, colores, complexiones, ropas), aldeas, clanes con ventaja/desventaja/rareza/modificadores, naturalezas y deslizador reserva/control; `reglas.json`: rangos (Estudiante → Kage) y progresión.
- `scripts/core/creacion.gd` (compartido): `validar` (el servidor sanea lo que llega), `naturalezas` (innata + segunda en Chūnin, o las dos del linaje), `linajes` (más los que despiertan por rango), `ficha` (para los requisitos del repertorio), `estadisticas` (con modificadores del clan), `sortear_clan` (regla en línea por rareza).
- El cliente manda `{"t": "personaje", "datos": {...}}` al conectar; el servidor valida y configura la entidad. El nombre y el aspecto de cada jugador llegan a todos cada medio segundo (`jugadores[]`).
- `Perfil` guarda hasta 3 personajes en `user://personajes.json`, cada uno con su maestría y sus 3 repertorios.

## Protocolo

Todos los mensajes son `Dictionary` con tipos serializables por Godot (int, float, String, Vector2/3, Array, Dictionary). Detalle completo en `scripts/core/protocolo.gd`.

Comandos: `entrada {mov, mira, seq}`, `personaje {datos}`, `accion {id, dir, objetivo, exacto}`, `nivel {valor 0..3}` (0 = automático por maestría), `reaparecer`, `repertorio {activos[4], modo, niveles_max, maestria, prueba}`.

**Repertorio (v0.4)**: el cliente elige (menú) y el servidor valida con `Repertorio.validar` (puntos, requisitos, incompatibles); si no es válido, usa el repertorio por defecto y avisa con un `mensaje`. El servidor resuelve el nivel de cada uso con `Repertorio.nivel_efectivo` (maestría, tope elegido, nivel forzado de depuración), suma XP y emite `maestria`. Las mecánicas nuevas viven en `scripts/servidor/tecnicas.gd` (modos, Kirin, Amaterasu, Susanoo, Shinra Tensei, Ocho Puertas) y las zonas persistentes (fuego negro, cráter, lago, lava) viajan en la instantánea como `zonas[]`. Los otros 31 jutsus usan `scripts/servidor/genericas.gd`: cinco mecánicas configuradas con los campos de cada nivel en `data/jutsus.json` (`mecanica`, `forma`, `cantidad`, `radio`, `atrapa`, `duracion`…); las invocaciones viajan como `criaturas[]` y el cliente las dibuja con `scripts/cliente/efectos_genericos.gd` según su `forma`. Offline, la maestría se guarda en el perfil local (`user://perfil.json`); en red la guardaría el servidor.

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
scripts/core/       Datos, Combate, Mapa, Protocolo, Repertorio (reglas compartidas del repertorio)
scripts/servidor/   ServidorJuego, EntidadServidor, IaEnemigo, Tecnicas (primer bloque), Genericas (salva, área, aura, invocación, teletransporte)
scripts/red/        Transporte, TransporteLocal, TransporteENet (anfitrión e invitado), Descubrimiento (UDP)
scripts/cliente/    escena de juego, personaje, vestimenta, animaciones, escenario, lluvia, efectos, cámara,
                    shaders (toon, contorno, fuego, calor, charcos, nubes, niebla, ojos, indicadores),
                    rayos ramificados, sonidos sintetizados, indicadores de apuntado, ajustes
scripts/ui/         menú, menú del repertorio (tarjetas, ranuras, detalle, vista previa), HUD, estilo (fuentes y marcos), iconos, botón de jutsu, retrato, ajustes, joystick
assets/fuentes/     Shojumaru y Rajdhani (licencia SIL OFL)
tests/              pruebas.gd (matemática y servidor), pruebas_repertorio.gd (reglas, maestría, bloque 1) y humo.gd
tools/              verificar.sh (pre-commit/CI) y captura.gd (capturas con pantalla virtual)
.github/workflows/  compilación del APK y publicación en el release demo-latest
```

## Gráficos (v0.2)

- **Cel shading**: `Shaders.TOON` reemplaza a todos los materiales sólidos (`Materiales.solido`): 3 bandas de luz con sombra fría, luz de contorno (rim) y brillo duro en metales. El **contorno negro** es una segunda pasada (`next_pass`) con casco invertido inflado en espacio mundo, con grosor que se adapta a la distancia.
- **Fuego**: esfera con shader de ruido fbm animado (núcleo blanco-amarillo, cuerpo naranja, borde rojo y superficie que ondula), esfera de **distorsión de calor** que refracta la pantalla (solo calidad alta), humo y brasas.
- **Rayo**: `Rayos` genera rayos ramificados por subdivisión del punto medio y los dibuja como cintas orientadas a la cámara en un solo `ImmediateMesh`.
- **Atmósfera**: suelo PBR mojado + `ReflectionProbe` (sin SSR), charcos con ondas procedurales, nubes en un plano alto con ruido, bancos de niebla en anillos + niebla por altura, relámpagos en el cielo con destello y trueno retardado según la distancia.
- **Sonido**: `Sonidos` sintetiza por código los efectos (rayo con trinos, fuego, explosión, golpe, trueno, chapoteo, lluvia).

## Gráficos (v0.3): arte por código con Blender

- `tools/blender/` contiene scripts de Blender (bpy) que generan todo el arte; se ejecutan fuera de Godot y su salida se versiona:
  - `texturas.py`: materiales procedurales horneados en Cycles a `assets/texturas/*_color.png` (RGB + rugosidad en A) y `*_normal.png`.
    Ruido 4D sobre un toro → texturas sin costuras.
  - `kit.py` + `geo.py`: kit modular de la aldea (edificio, silo, tanque, pasarela, tuberías, muro de canal, torre con rostro,
    siluetas lejanas) exportado a `assets/modelos/*.glb`, con UV a escala de mundo.
  - `personaje.py`: cuerpo continuo y chaleco con piel deformable y el mismo esqueleto que usan las animaciones.
- `tools/ajustar_importacion.py` fija compresión VRAM, mipmaps y mapas de normales en los `.import`.
- En Godot, `Kit` carga cada GLB y sustituye sus materiales (por nombre) por `Shaders.toon_tex` (cel shading con texturas,
  humedad y chorreaduras). `Trazado` monta la aldea a partir de `data/escenario.json` → `trazado`, y `Mapa` usa las mismas
  huellas como colisiones del servidor.
- Animaciones con esqueleto de Blender: cada clave se convierte a `padre_reposo⁻¹ · D · hueso_reposo`; las piezas hechas
  por código cuelgan de un nodo "Marco" que anula la rotación de reposo del hueso.
- Herramientas de verificación: `tools/captura.gd` (capturas con guion), `tools/vista_kit.gd` (fotografía piezas del kit),
  `tools/medir.gd` (llamadas de dibujo, primitivas y sombras por calidad).

## Rendimiento móvil

- Escenario con **MultiMesh** (torres, ventanas, tuberías, pasarelas, charcos): pocas llamadas de dibujo.
- Lluvia: 2 sistemas GPU (≈1400 gotas + 220 salpicaduras) que siguen a la cámara.
- Solo 3 luces fijas; las demás son temporales (efectos). Sombras solo de la luz direccional, a 30 m.
- Simulación a 30 ticks/s; el cliente interpola.
- Personajes: las piezas por código de cada hueso se fusionan en una malla (`Materiales.fusionar`); las piezas del trazado
  se agrupan por tipo en MultiMesh. Medido: alta 99 llamadas de dibujo / 63k primitivas / 35 de sombra; baja 67 / 56k / 0.
- Calidad **baja/media** (`data/graficos.json`): sin contorno del escenario, sin distorsión de calor, menos gotas y partículas, escala 3D 0.7–0.85, sombras opcionales, menos luces y capas de niebla; tope de 30 fps.
