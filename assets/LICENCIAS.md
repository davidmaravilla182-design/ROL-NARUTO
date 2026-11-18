# Licencias y créditos

## Recursos de arte y sonido

Este demo solo incluye como recursos externos **dos tipografías con licencia OFL**. Todo lo demás (modelos, animaciones, efectos y sonidos) se genera por código en tiempo de ejecución:

| Recurso | Origen | Licencia |
|---|---|---|
| Personaje humanoide, esqueleto y animaciones | Generado por código (`scripts/cliente/personaje_visual.gd`, `animaciones.gd`) | Igual que el proyecto |
| Ropa ninja (banda, chaleco, vendas, sandalias, emblema) | Generado por código (`scripts/cliente/vestimenta.gd`) | Igual que el proyecto |
| Sector de la aldea, lluvia y efectos | Generado por código (`escenario.gd`, `lluvia.gd`, `efectos.gd`) | Igual que el proyecto |
| Kit de la aldea, torre monumental y cuerpo del personaje (`assets/modelos/*.glb`) | Generados por scripts de Blender (`tools/blender/`) | Igual que el proyecto |
| Texturas (`assets/texturas/*.png`) | Horneadas en Blender a partir de nodos procedurales (`tools/blender/texturas.py`) | Igual que el proyecto |
| Imágenes de referencia (`referencias/amegakure/`) | Aportadas por el usuario como guía visual; no se incluyen en el APK | Uso interno de referencia |
| Icono de la app (`icon.svg`) | Dibujado a mano en SVG para este proyecto | Igual que el proyecto |
| Efectos de sonido (rayo, fuego, explosión, golpe, trueno, chapoteo, lluvia) | **Sintetizados por código** en `scripts/cliente/sonidos.gd` | Creación propia, dedicada al dominio público (CC0) |
| Shaders (cel shading, contorno, fuego, calor, charcos, nubes, niebla, ojos) | Escritos para este proyecto (`scripts/cliente/shaders.gd`) | Igual que el proyecto |
| Fuente **Shojumaru** | Astigmatic (Brian J. Bonislawsky), vía google/fonts — `assets/fuentes/Shojumaru-Regular.ttf` | SIL Open Font License 1.1 (`assets/fuentes/OFL-Shojumaru.txt`) |
| Fuente **Rajdhani** | Indian Type Foundry, vía google/fonts — `assets/fuentes/Rajdhani-*.ttf` | SIL Open Font License 1.1 (`assets/fuentes/OFL-Rajdhani.txt`) |

Se intentó usar modelos CC0 de **Quaternius** y **Kenney**, pero no se pudieron descargar desde el entorno de desarrollo. Si se agregan en el futuro, deben ser **CC0** y registrarse en esta tabla con autor, enlace y licencia.

## Motor

- **Blender 5.3** (módulo `bpy`) — GPL; se usa solo como herramienta para generar arte, que no queda sujeto a la GPL.
- **Godot Engine 4.7.2** — licencia MIT. © 2014-present Godot Engine contributors; © 2007-2014 Juan Linietsky, Ariel Manzur. https://godotengine.org/license
- La fuente por defecto de Godot (Open Sans / Noto) se distribuye bajo SIL Open Font License 1.1 como parte del motor.

## Aviso

Proyecto de fans sin fines de lucro. Sin relación con Masashi Kishimoto, Shueisha ni Bandai Namco. No se usa música, audio, logotipos ni arte oficial de la serie. Los nombres de personajes, técnicas y lugares pertenecen a sus respectivos dueños y solo aparecen en los archivos de datos (`/data`), por lo que pueden cambiarse sin tocar el código.
