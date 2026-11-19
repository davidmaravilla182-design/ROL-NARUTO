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

## v0.2 — interfaz, apuntado y gráficos

### Apuntado
- La dirección del disparo va en el comando `accion` (`dir`, `objetivo`, `exacto`). El servidor tiene la última palabra: objetivo fijado válido > dirección exacta del arrastre > asistencia en cono. Así funciona igual en red.
- **Toque rápido**: el cliente propone el enemigo más cercano dentro de 65° frente a la cámara y al alcance del jutsu; prefiere enemigos sobre muñecos. Sin candidato, usa la dirección de la cámara (el servidor todavía aplica su asistencia en cono).
- **Arrastrar**: umbral de 26 px para entrar en modo apuntado (por debajo, cuenta como toque). Al soltar se dispara en la dirección exacta del dedo relativa a la cámara, sin asistencia.
- **Cancelar**: un círculo a la izquierda del arco de botones; aparece solo mientras apuntas. Cancelar no envía ningún comando, por eso no gasta chakra ni inicia la recarga.
- **Fijar objetivo**: el ciclo es «más cercano → siguiente → … → liberar». Se libera solo si el objetivo muere. La cámara gira suave para mantenerlo delante; el arrastre de cámara sigue cambiando la inclinación.
- El golpe también usa el objetivo fijado para orientarse.

### Interfaz
- Tipografías con licencia **SIL OFL** descargadas de google/fonts: **Shojumaru** (títulos con trazo de pincel) y **Rajdhani** (interfaz, aire metálico). Están en `assets/fuentes/` con sus licencias.
- Marcos de "metal de la aldea" dibujados por código: placa biselada, remaches, filo rojo y las 4 líneas del símbolo. El aviso legal y los carteles grandes van sobre un pergamino.
- Iconos 100 % vectoriales por código (llama, rayo, ojo con tomoe, puño, esquiva, salto, mira, cancelar).
- Botones en arco: el golpe grande en la esquina; anillo interior con esquivar, bola de fuego, Chidori y saltar; anillo exterior con Sharingan y fijar. Todo escala con el ajuste de tamaño.
- Áreas seguras: se usa `DisplayServer.get_display_safe_area()` con un margen mínimo de 18 px (+6 px laterales por los bordes curvos).
- La vibración usa `Input.vibrate_handheld` (permiso VIBRATE añadido al preset de Android).
- Los ajustes se guardan en `user://ajustes.cfg`. Cambiar la calidad reinicia la escena de entrenamiento porque los materiales y efectos se construyen según la calidad.

### Gráficos
- Cel shading con `light()` propio en vez de `diffuse_toon` para tener 3 bandas, sombra azulada y rim. Las luces puntuales usan bandas sin color de sombra para no iluminar objetos lejanos.
- Contorno por casco invertido en espacio mundo (sirve también para MultiMesh). En calidad media/baja solo los personajes tienen contorno.
- Reflejos: `ReflectionProbe` en modo UPDATE_ONCE (se calcula una vez) en lugar de reflejos en pantalla, por rendimiento.
- Las nubes van en un plano alto con shader y no en el shader del cielo: un cielo animado obligaría a recalcular la radiancia cada fotograma.
- Las intensidades de fuego y rayo se bajaron tras ver capturas: con glow, un nivel 3 a máxima intensidad dejaba la pantalla en blanco.
- Ojos: un quad con shader que dibuja esclerótica, iris y pupila; con el modo ocular se vuelve rojo con anillo y 3 tomoe que giran.

### Sonido
- No había forma de descargar efectos CC0 (los sitios no son accesibles desde el entorno de desarrollo), así que **todos los sonidos se sintetizan por código** al iniciar: el rayo combina chisporroteo, zumbido y cientos de trinos agudos que imitan "mil pájaros". Son creación propia, dedicados al dominio público (CC0). No se usa audio del anime.

### Sensación de impacto
- La pausa de impacto (0.07–0.09 s) y la cámara lenta (×0.3 durante 0.45 s en jutsus nivel 3) cambian `Engine.time_scale` solo en el cliente. El servidor compensa el `time_scale` y sigue en tiempo real. En modo offline las posiciones se ponen al día tras la pausa.

### Pruebas y verificación
- Nuevas pruebas de la dirección del disparo en el servidor (dirección exacta, objetivo fijado, asistencia del toque, flecha del Chidori, saneado del comando).
- La prueba de humo carga la partida en las tres calidades y ejercita toque, arrastre, cancelar, fijar, pausa de impacto, cámara lenta y el menú de ajustes.
- Los shaders se compilaron también con el renderizador **Mobile (Vulkan)** usando el Vulkan por software de Mesa, además de OpenGL.

## v0.3 — mejora gráfica (trabajo nocturno autónomo)

- **Sin descargas de texturas** (Poly Haven y ambientCG siguen bloqueados): todas las texturas son procedurales y se hornean
  en Blender (bpy por pip). Se versionan los PNG resultantes para que la compilación no necesite Blender.
- **Blender como herramienta de arte por código**: el kit modular, la torre monumental y el cuerpo del personaje se generan con
  scripts reproducibles en `tools/blender/`. Volver a ejecutarlos regenera el arte idéntico.
- **Referencias** en `referencias/amegakure/` (8 imágenes del usuario) con `.gdignore`: no entran en el APK.
- **Trazado fijo en datos** en vez de torres aleatorias: la composición (plaza, canal al norte, hito al fondo, calles con
  arcos de tuberías) se diseñó mirando las referencias, y vive en `data/escenario.json` para poder cambiarla sin código.
- **El canal** bloquea a los personajes pero no a los proyectiles (se puede disparar por encima del agua).
- **Contorno negro solo en personajes**: en el escenario parecía un boceto a lápiz.
- **Hito**: la torre con rostro se acercó (62 m) y se iluminó con focos porque a 88 m la niebla la borraba.
- **Cuerpo continuo**: Skin + Subsurf en Blender en lugar de esculpir, para que sea reproducible por código. Pesos calculados
  a mano (más predecibles que el pesado automático en modo sin interfaz).
- **Rendimiento**: la mayor ganancia vino de fusionar las mallas de los personajes (≈70 piezas → ≈17), no de agrupar los edificios.
- **Capturas**: con lavapipe instalado Godot usa Vulkan/Mobile por defecto; las revisiones visuales se hicieron con ambos renderizadores.
- **Impermeable** del ninja enemigo como tercera malla en el mismo GLB del cuerpo (comparte esqueleto), activado desde
  los datos (`aspecto.capa`), en vez de un GLB aparte: así no hay que reasignar la piel a otro esqueleto en Godot.


## v0.4 — repertorio de 40 jutsus

- `data/jutsus.json` reemplaza la lista anterior. Además de los 40, los ojos (Sharingan, Mangekyō, Rinnegan, Byakugan) son entradas de ranura MODO con sus 3 niveles; los jutsus de ojos exigen ese ojo como MODO y **activo** al lanzarlos.
- Los modos también cuestan puntos (1–4) para que el tope de 12 obligue a elegir.
- Personaje de prueba: rango Jōnin, linajes Sharingan y Mangekyō, naturalezas fuego y rayo. Con «Modo prueba» se ignoran requisitos, puntos e incompatibles.
- Maestría: 10 XP por uso, 15 XP por impacto, 2 XP por segundo de modo; N2 a 100 XP y N3 a 300 XP (en `reglas.json`). En el modo offline la maestría vive en `user://perfil.json` y el cliente la manda al servidor con el repertorio; en red la guardaría el servidor.
- Nivel en combate: el más alto desbloqueado, salvo el tope que el jugador elija por jutsu en el menú. El botón de depuración del HUD añade «Auto».
- Kirin necesita tormenta: la lluvia del campo de entrenamiento cuenta como tormenta (`clima.lluvia.tormenta`). Su costo es un porcentaje del chakra máximo.
- Amaterasu: fuego negro que no se apaga con la lluvia; N2 se propaga a 4,8 m; N3 añade armadura de fuego negro. Usarlo deja ceguera temporal (reduce la asistencia de apuntado).
- Susanoo es un interruptor que drena chakra; N2 añade flechas, N3 la espada.
- Shinra Tensei deja al usuario vulnerable 5 s (recibe +30 % de daño); N3 deja un cráter.
- Ocho Puertas consume vida en vez de chakra y multiplica velocidad y taijutsu; en N3 el tercer golpe del combo es un golpe definitivo.
- El Rasengan reutiliza el embiste del Chidori (estados `chidori_carga`/`chidori_embiste` con el id del jutsu), así el servidor no duplica código.
- La vista previa animada del menú se dibuja en 2D por código (sin escenas 3D extra) para que el menú sea ligero en el celular.
- El HUD se puede reconstruir al cambiar de repertorio sin duplicar nodos.
- Corrección tras probar en el celular: si el repertorio del menú no era válido, el servidor usaba el de por defecto pero los botones seguían mostrando el elegido (los jutsus no hacían nada). Ahora el servidor devuelve lo que aceptó, el HUD se reconstruye con eso y el aviso dice el motivo. Además, al equipar un jutsu que pide un ojo, el menú pone ese ojo en la ranura MODO y no deja pasar de 12 puntos; y en combate el ojo requerido se enciende solo al usar el jutsu.
- Los 34 jutsus restantes no tienen código propio cada uno: comparten cinco mecánicas genéricas (salva, área, aura, invocación, teletransporte) parametrizadas por nivel en `data/jutsus.json`, y un jutsu puede cambiar de mecánica entre niveles (p. ej. Manto de Rayo N3 se teletransporta; Fuerza Sobrehumana N3 es un sello de regeneración). Así añadir o rebalancear un jutsu es editar datos.
- Interpretaciones para el juego: las invocaciones y clones son criaturas aliadas temporales que persiguen y golpean (no entidades completas); el Dios del Trueno Volador salta detrás de los rivales en cadena; la Gran Cascada N3 deja el suelo inundado y el rayo hace +30 % a quien esté dentro; el Tiburón N3 se traga los proyectiles rivales; muro, cúpula, arena, rotación y Kamui N3 repelen proyectiles; Kamui vuelve intangible; las 64 Palmas y la Fuerza Sobrehumana dan un paso rápido hasta el rival.
- Los clones N3 son 20 en el servidor; en el cliente solo los 6 primeros son copias completas del personaje y el resto siluetas ligeras, para que el celular no se trabe.
- Los requisitos se mantienen (naturalezas, linajes, rango); el personaje de prueba no puede usar los de otras naturalezas o linajes salvo con «Modo prueba».

### Ajustes tras la prueba en el celular
- Temblor de cámara limitado (`data/graficos.json` → `limites`): como máximo 3 sacudidas cada 0,6 s y trauma acumulado ≤ 0,9; las cámaras lentas de N3 no se encadenan (1,2 s entre una y otra). Las explosiones se ven igual: solo se recorta el temblor sobrante.
- Equilibrio: Dragón de Agua N3 pasa de 5 a 3 dragones (20 de daño, lago más chico); Golem de Tierra, Golem de Lava e Invocación duran menos, golpean más lento y hacen menos daño; recargas más largas para golem e invocación.
- Clones de Sombra N3: 10 clones (antes 20) y solo 3 copias completas del personaje en pantalla; el resto, siluetas ligeras.
- Fuerza Sobrehumana N3: ahora salta sobre el rival, cae un puño gigante de chakra que abre un cráter (aturde y derriba) y además activa el sello de regeneración.
- Cada jutsu tiene un uso (`rol`): Ataque, Defensa, Control o Apoyo, con filtro en el menú y etiqueta en cada tarjeta.
- Tres defensas nuevas: Sustitución (anula el siguiente golpe; N2 te pone detrás del atacante; N3 el tronco estalla), Muro de Agua (cortina → remolino → remolino que devuelve proyectiles) y Barrera de Viento (desvía → empuja → devuelve y corta). Las defensas de nivel 2+ hacen inmune a atrapar y aturdir mientras duran.


## v0.5 — personaje y red local

### Rendimiento
- El límite de 30 FPS en calidad media y baja es a propósito (`data/graficos.json → fps_objetivo`): en gama media se ve estable y ahorra batería y calor. Ahora el jugador puede elegir 30 o 60 en Ajustes; por defecto sigue a la calidad.
- Panel de diagnóstico: reemplaza a «Mostrar FPS». Las partículas se cuentan sumando los sistemas activos (grupo `particulas`).

### Creación de personaje
- Uchiha empieza con Sharingan y despierta el Mangekyō al llegar a Jōnin (`linajes_por_rango`); así la regla de rangos tiene un efecto visible aunque aún no haya misiones.
- «Sin clan» da +1 punto de atributo (tope 27) para compensar no tener técnicas secretas.
- Los linajes de kekkei genkai traen sus dos naturalezas (madera: tierra+agua; hielo: agua+viento; lava: fuego+tierra; arcilla: tierra+rayo; arena: viento+tierra). El clan Hyūga trae Byakugan y el de papel, la Danza de Papel.
- Rarezas: común (sin clan, papel), raro (Uchiha, Hyūga, hielo, lava, arcilla), legendario (madera, arena). En línea se sortean por peso (70/25/5) con `Creacion.sortear_clan`; en offline se eligen.
- El deslizador «Reserva vs. Control» (−1…+1) suma a la reserva y resta al control derivados (o al revés), sin gastar puntos de atributo. Se guarda como `_balance` dentro de los atributos (las reglas ignoran claves que empiezan con `_`).
- Las aldeas distintas de Amegakure se muestran como «Próximamente» y el servidor las rechaza.
- El personaje creado empieza con un repertorio automático (hasta 3 jutsus que ya puede usar) para no entrar con ranuras vacías.
- El progreso (maestría y repertorios) es por personaje. El perfil anterior se migra como «personaje de práctica».

### Red local
- Listen server: el anfitrión juega sin pasar por la red (TransporteLocal) y además atiende a los invitados por ENet; no hace falta un servidor dedicado para probar.
- Las instantáneas van comprimidas y sin garantía (tamaño de un solo paquete); los eventos van por un canal fiable para que ningún impacto, jutsu o mensaje se pierda.
- Predicción solo del movimiento propio (lo que más se nota); jutsus, golpes y daño siguen siendo 100 % del servidor. Los demás se interpolan con 100 ms de retraso.
- Cada jugador está en su propio equipo (todos contra todos) además de la IA; el botón «Reaparecer» del anfitrión reinicia todo y el de un invitado solo lo reanima a él.
- La maestría y el «modo prueba» los manda el cliente también en red (es una prueba local entre amigos); en línea los guardaría el servidor.
- Descubrimiento por difusión UDP: en algunos Android el filtro de multidifusión puede impedir recibir anuncios; por eso siempre está la opción de escribir la IP.


## Prueba de arte con modelos IA (torre y ninja)
- Torre: geometría de Meshy (forma más limpia) con el color de TRELLIS transferido por vértice; el horneado a textura UV se descartó porque la malla reducida de Meshy se despliega en miles de islas diminutas. Detalle triplanar en el shader. Informe y medidas en `referencias/modelos-ia/INFORME.md`.
- La torre se movió de z −62 a z −76 porque el modelo IA es más ancho (42 m) y no debe tapar los edificios del canal; sigue fuera del área jugable.
- Ninja: reemplaza al personaje de los jugadores (también la vista previa de la creación y los clones). El enemigo de la IA conserva el personaje anterior con impermeable y máscara, para distinguirlo.
- La textura del ninja se reduce a 1024 px: +6,6 MB de memoria de video en lugar de +18,6 MB.
- Impermeable con el ninja IA: recoloreo de chaleco y camisa (la capa del cuerpo anterior no encaja en el nuevo esqueleto).

### Ajustes tras probar en el celular (retrato, plaza y letrero)
- Retrato del HUD: el mismo PersonajeVisual del jugador en un SubViewport de 200 px (busto), con el emblema del clan de fondo. Se renderiza unos instantes y se congela; solo se repinta al encender o apagar un modo ocular (casi sin costo por fotograma).
- Plaza: 5 piezas nuevas del kit de Blender (caja de madera, contenedor, barril, rejilla de suelo, tubería a ras del suelo con válvula) colocadas en `data/escenario.json → trazado.props` con su huella de colisión (la rejilla no choca; la tubería se puede saltar). Se colocan después de las cajas del campo y sin encimarse con ellas, para no cambiar el campo de combate. Las cajas del campo usan ahora la caja de madera.
- Charcos: más charcos alrededor de la plaza y shader más espejo (metálico 0,85, rugosidad 0,03 y reflejo del cielo por fresnel).
- Letrero de victoria/derrota: más pequeño, bajo la barra superior y se desvanece solo a los 4 s.
