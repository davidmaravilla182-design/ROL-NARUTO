# DISEÑO — Ciclo de juego premium (v0.9)

Proyecto de fans sin fines de lucro. Sin relación con Masashi Kishimoto, Shueisha ni Bandai Namco.

Todo lo de este documento vive en datos (`/data/*.json`) y lo aplica el servidor autoritativo; el cliente solo muestra.
Las cifras son el punto de partida del equilibrio y se ajustan en los JSON sin tocar código.

---

## 0. Regla de arte (desde v0.9)

- Ningún modelo nuevo se genera con imágenes de Meshy. El usuario genera la imagen en GPT; nosotros la convertimos
  con Meshy **Imagen a 3D (Smart Topology)** y la integramos con las herramientas de Blender de siempre.
- Cada modelo que haga falta se pide en `referencias/gpt/PEDIDOS.md` con: archivo esperado, para qué sirve y el
  prompt exacto (objeto aislado, fondo gris liso, luz de estudio pareja, vista de tres cuartos; personajes de frente
  en pose A; estilo anime coherente con el juego y la paleta de la aldea de la lluvia).
- Mientras la imagen no exista se usa un **marcador** procedural (se ve bien, pero sencillo) y el código busca el GLB
  definitivo por nombre: en cuanto existe `assets/modelos/<nombre>.glb`, se usa sin cambiar código.

---

## 1. Atributos con sentido real

Ocho atributos de 0 a 5. Cada uno tiene **efectos medibles** (fórmulas en `data/reglas.json → efectos_atributos`) y la
ficha del personaje muestra el efecto actual de cada punto («Recarga −12 %», «Combo de 5 golpes»…).

| Atributo | Efectos (por punto, desde 0) | Requisito para |
|---|---|---|
| **Ninjutsu** | Daño de ninjutsu +12 %; tamaño +6 %; alcance +5 %. | Jutsus avanzados (`atributos_min`). |
| **Taijutsu** | Daño cuerpo a cuerpo +10 %; **largo del combo = 2 + Taijutsu** (1 → 3 golpes … 5 → 7 golpes; con 0, 2). | Técnicas de taijutsu (Loto, Liger Bomb…). |
| **Genjutsu** | Duración de tus genjutsu +15 % y potencia +10 %; **resistencia**: los genjutsu enemigos te duran −12 % por punto (con 5, −60 %). | Genjutsu del repertorio. |
| **Inteligencia** | Recarga −4 % por punto; maestría +10 % por uso; 1+ ves la vida del enemigo en números, 3+ su debilidad elemental, 4+ las emboscadas aparecen en el minimapa antes de que salten. | — |
| **Fuerza** | Daño físico +8 %; empuje +15 %; con 3+ los golpes fuertes **rompen la guardia** (bloqueo de NPC) y ganas los choques (el rival queda aturdido). | — |
| **Velocidad** | Movimiento +8 %; velocidad de ataque +5 % (golpes más cortos); ventana de esquiva/sustitución +0,04 s; shunshin +1,5 m. | — |
| **Estamina** | Vida +12; estamina +10; regeneración de estamina +8 %; caminar por paredes y agua gasta −8 % por punto. | — |
| **Sellos** | Secuencia de sellos −12 % por punto; con 4 se hace **con una mano** (−50 % extra), con 5 casi sin sellos (tope 15 % del tiempo). | Técnicas de sellado: Sellos Explosivos (2), Invocación (3), Dios del Trueno Volador (4), **sellar a un bijuu (3)**. |

**Reserva vs. Control** (deslizador de la creación) se mantiene igual: mueve hasta ±1 entre la reserva (chakra máximo,
tamaño) y el control (costo, precisión, regeneración).

### 1.1 Progresión de puntos

| Rango | Tope de puntos | Cómo se gana |
|---|---|---|
| Genin (creación) | **14** (+ clan) | Reparto libre al crear. |
| Chūnin | 18 | +2 con experiencia antes de ascender (1 cada 400 XP) y +2 al ascender. |
| Jōnin | 22 | Igual. |
| Élite | **26** (máximo; nunca 40) | Igual. |

- Rangos: `estudiante → genin → chunin → jonin → elite → kage` (kage no se alcanza en esta versión).
- Los personajes antiguos (creados con 16–26 puntos) conservan sus puntos: el tope nunca baja de lo que ya tenían.
- **XP de combate y misiones** (`xp_total`): derrotar enemigos (10–40), eventos (60–150), capítulos (200–400).
- **Ascender** exige XP del rango (Chūnin 600, Jōnin 1500, Élite 3000) **y** superar una **prueba de combate**:
  Genin→Chūnin es el capítulo 5 (Examen Chūnin); Chūnin→Jōnin y Jōnin→Élite son duelos contra el instructor reforzado.

### 1.2 Entrenamiento con sentido (usar algo lo entrena)

Cada atributo tiene una barra de entrenamiento (0–1). Al llenarse da **+0,5 de bonificación de entrenamiento** a ese
atributo (efectiva en combate, máximo +0,5 por atributo; no cuenta para el tope de puntos). El control de chakra tiene
su propia barra.

| Acción | Entrena |
|---|---|
| Correr por paredes y sobre el agua (por segundo) | Control de chakra |
| Golpes de combo que conectan | Taijutsu |
| Combos completos / remates | Fuerza |
| Lanzar jutsus con sellos | Sellos (y maestría del jutsu, como ya pasaba) |
| Esquivas justas, shunshin | Velocidad |
| Romper o resistir genjutsu | Genjutsu |
| Correr / caminar con chakra (distancia) | Estamina |

---

## 2. Repertorio por tipo y técnicas nuevas

El menú del repertorio gana un segundo filtro **Ninjutsu / Taijutsu / Genjutsu** (campo `tipo` en cada jutsu), además
del de naturaleza que ya existía. Clasificación de los 40 actuales: genjutsu = Tsukuyomi; taijutsu = Ocho Puertas,
Fuerza Sobrehumana, Palmas 64, Rotación; el resto ninjutsu (los modos oculares cuentan como ninjutsu de ojos).

### 2.1 Taijutsu nuevo (cada uno con 3 niveles: más daño, más golpes, más alcance)

| Técnica | Mecánica | Requisito |
|---|---|---|
| Remolino de la Hoja | Patada giratoria barrida: área alrededor, derriba. | Taijutsu 2 |
| Loto Primario | Lanza al rival al aire, salta, lo atrapa y caen en barrena: gran golpe al suelo. | Taijutsu 4 + 1.ª puerta abierta |
| Loto Oculto | Lanza al rival, ráfaga de golpes en el aire y golpe final. | Taijutsu 4 + 3 puertas |
| Pavo Real Matutino | Lluvia de golpes en llamas que forma un abanico frente a ti. | Taijutsu 5 + 6 puertas |
| Tigre Diurno | Un puñetazo libera un tigre de aire comprimido (proyectil enorme que explota). | Taijutsu 5 + 7 puertas |
| Lariat | Embestida con el brazo extendido cubierto de rayo. | Taijutsu 3 + Manto de Rayo activo |
| Liger Bomb | Atrapa, salta y estrella al rival contra el suelo. | Taijutsu 3, Fuerza 3 |
| Entrada Dinámica | Patada voladora desde lejos (hasta 12 m) que **interrumpe** el ataque del rival. | Taijutsu 2, Velocidad 2 |

«Puertas abiertas» = Ocho Puertas activo con nivel suficiente (N1: puertas 1–3, N2: 4–6, N3: 7–8).

**Ocho Puertas espectacular**: aura del color de la puerta (verde → azul → rojo), piel enrojecida (tinte en el
personaje), el suelo se agrieta bajo los pies al abrirla y al moverse, y la velocidad deja estelas (imágenes residuales).

### 2.2 Genjutsu nuevo

| Técnica | Efecto | Requisito |
|---|---|---|
| Atadura del Árbol | Raíces ilusorias inmovilizan al rival (2 / 3 / 4 s). | Genjutsu 2 |
| Ilusión de Plumas | Plumas caen y el rival se duerme (3 / 4 / 5 s; un golpe lo despierta). | Genjutsu 3 |
| Oscuridad | Ciega al rival: su pantalla se oscurece y la IA pierde de vista al jugador (3 / 4,5 / 6 s). | Genjutsu 3 |
| Visión del Infierno | El rival ve su peor miedo y huye de ti (3 / 4 / 5 s). | Genjutsu 4 |
| Romper genjutsu | Te libera de cualquier genjutsu y te da 2 s de inmunidad (N3: devuelve el genjutsu). | Genjutsu 1 |

La duración real = base × (1 + 0,15 × Genjutsu del lanzador) × (1 − 0,12 × Genjutsu del objetivo).

---

## 3. Misiones dinámicas (sin «ve y trae»)

Motor de misiones en el servidor (`Misiones`): una misión es una lista de **fases** con objetivo, escena y combate.
Tipos de fase: `escena` (diálogo corto con cámara y pájaro de papel), `derrotar` (lista de enemigos), `oleadas`,
`perseguir` (el objetivo huye por los techos; perderlo = fallar), `defender` (aguantar N s con la muralla en pie),
`duelos` (torneo por rondas), `jefe`. Se anuncia todo con un letrero y el panel de misión del HUD.

### 3.1 Historia principal (capítulos)

1. **Graduación** — prueba de combate contra el instructor en la academia (duelo; a 30 % de vida se rinde).
2. **Emboscada en el distrito industrial** — 3 oleadas de rebeldes y su líder (minijefe).
3. **La lluvia detecta un intruso** — perseguirlo por los techos (pared, techos) y derribarlo antes de 90 s.
4. **Defensa de la puerta** — rebeldes atacan la muralla; aguantar 120 s y derrotar a los capitanes.
5. **Examen Chūnin** — torneo de 3 duelos contra IA (después también contra jugadores). Ganar = prueba de ascenso.
6. **La bestia del lago** — el Tres Colas emerge (ver §4).

**El líder de la torre nunca aparece en persona**: sus órdenes llegan en un **pájaro de papel** que vuela hasta el
jugador, se despliega y muestra el texto (escena).

### 3.2 Eventos dinámicos (aparecen solos y se anuncian)

| Evento | Qué pasa | Cada |
|---|---|---|
| Emboscada rebelde | 3–5 rebeldes aparecen en un distrito al azar. Con Inteligencia 4 se ven antes en el minimapa. | 3–5 min |
| Alarma de la lluvia | Un intruso huye por los techos: encontrarlo y derribarlo antes de 75 s. | 4–6 min |
| Cazarrecompensas | Un rebelde con nombre (minijefe: más vida, técnica propia) con recompensa especial. | 6–9 min |
| Duelo con el instructor | Duelo de entrenamiento: ganar da 1 punto de atributo (hasta el tope del rango). | a pedido (instructor) |

### 3.3 Recompensas

XP, **ryō**, **pergaminos** (cada pergamino enseña un jutsu: lo desbloquea para el repertorio aunque no se cumplan los
requisitos de rango; los de atributos siguen valiendo) y **cosméticos** (colores de prenda, bandas, capas y máscaras
que se ponen en la ficha). Pantalla de recompensa con animación (cofre de papel que se abre, objetos que entran).

---

## 4. Primer jefe: el Tres Colas

Tortuga gigante (≈18 m) con caparazón de púas de coral, tres colas y un ojo grande. Emerge del lago que rodea la isla.

| Fase (vida) | Comportamiento | Cómo se gana |
|---|---|---|
| 1 (100–70 %) | Desde el agua: balas de agua en abanico y olas que barren la orilla. | Caminar sobre el agua para alcanzarlo. |
| 2 (70–45 %) | Se enrolla y **rueda** contra la muralla y los puentes (línea marcada en el suelo). | Esquivar la línea; tras rodar queda aturdido (ventana de daño). |
| 3 (45–20 %) | **Niebla de alucinaciones**: aparecen 3 copias falsas. | Genjutsu 3+ las ve falsas; «Romper genjutsu» las disipa; golpear una falsa no hace nada. |
| 4 (20–0 %) | **Bomba con cola de bestia**: carga 3 s (esfera oscura y aviso) y dispara. | Esquivar en el instante justo o morir (daño enorme). |

- Al derrotarlo: **minijuego de sellado** (secuencia de sellos que hay que tocar a tiempo). Requiere **Sellos 3+**;
  sin eso solo se le ahuyenta y escapa al lago (la misión se completa, pero sin la recompensa de sellado).
- Música de jefe (sintetizada), cámara de jefe (se aleja y encuadra a los dos), barra de vida enorme arriba con su
  nombre y fase, sacudidas y salpicaduras.
- Modelo: pedido a GPT (`referencias/gpt/tres_colas.png`); marcador procedural mientras tanto.

---

## 5. Guardado y calidad premium

- `Perfil` guarda por personaje: atributos, rango, XP, entrenamiento, ryō, misiones (capítulo actual, completadas),
  pergaminos aprendidos, cosméticos y equipados, además de maestría y repertorios (ya existían).
- El servidor recibe el progreso y lo valida (tope de puntos según rango y XP).
- Interfaz premium nueva: **Ficha** (atributos con su efecto actual, barras de entrenamiento, rango y XP),
  **Misiones** (capítulos y eventos), **Pergaminos**, **Cosméticos** y **Recompensa**, con animaciones de entrada,
  sonidos (papel, campana, monedas) y el estilo de la interfaz actual.
- Revisión con secuencias de cuadros (como en v0.8) de todo lo nuevo.

---

## 6. Orden de implementación

1. Atributos (efectos, progresión, entrenamiento, ficha).
2. Repertorio por tipo + 8 taijutsu + 5 genjutsu + Ocho Puertas espectacular.
3. Motor de misiones, 6 capítulos (el 6 con el jefe), 4 eventos, recompensas.
4. El Tres Colas (fases, sellado, música y cámara).
5. Guardado completo e interfaz premium; QA por cuadros; APK.
