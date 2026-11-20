# Pedidos de imágenes para GPT

Sube cada imagen a `referencias/gpt/` con **el nombre exacto** indicado. Yo la convierto con Meshy (Imagen a 3D,
Smart Topology) y la integro; mientras no esté, el juego usa un marcador procedural.

Reglas comunes (ya incluidas en cada prompt): objeto aislado, fondo gris liso, luz de estudio pareja, vista de tres
cuartos; personajes de frente en pose A; estilo anime de videojuego coherente con la aldea de la lluvia (hormigón
gris manchado, metal oscuro remachado, tuberías granate, acentos lila, faroles ámbar, ambiente lluvioso).

## Imágenes de referencia (adjúntalas en GPT junto con el prompt)
Así el estilo, la paleta y las proporciones quedan iguales a lo que ya está en el juego.
- **Personajes** (`lider_rebelde`, `intruso`): `referencias/modelos-ia/ninja-frente.png` — mismo trazo anime, pose A,
  proporciones y fondo. Antepón al prompt: *«Usa la imagen adjunta como referencia de estilo, proporciones, pose A y
  nivel de detalle; dibuja un personaje distinto:»*
- **Objetos y criaturas** (`tres_colas`, `pajaro_papel`, `pergamino`, `cofre_recompensa`): `referencias/modelos-ia/edificio.png`
  (la casa de la plaza que te gustó) — materiales, paleta granate/gris, acabado de render y luz. Antepón: *«Usa la
  imagen adjunta solo como referencia de estilo, materiales, paleta y luz; dibuja un objeto distinto:»*
- No adjuntes imágenes oficiales de la serie: el resultado debe ser diseño propio (y GPT suele rechazar copiarlas).

| Estado | Archivo | Para qué | Referencia a adjuntar |
|---|---|---|---|
| Hecho (Meshy 15 cr, en el juego) | `tres_colas.png` | Jefe: el Tres Colas que emerge del lago (capítulo 6). | `edificio.png` |
| Pendiente | `pajaro_papel.png` | Mensajero del líder de la torre (escenas de misión). | `edificio.png` |
| Pendiente | `lider_rebelde.png` | Minijefe del capítulo 2 y cazarrecompensas. | `ninja-frente.png` |
| Pendiente | `intruso.png` | Ninja infiltrado (capítulo 3 y alarma de la lluvia). | `ninja-frente.png` |
| Pendiente | `pergamino.png` | Recompensa: pergamino que enseña un jutsu (pantalla de recompensas y objeto en el suelo). | `edificio.png` |
| Pendiente | `cofre_recompensa.png` | Cofre de papel y metal de la pantalla de recompensas. | `edificio.png` |

---

## tres_colas.png
Para qué: jefe del capítulo 6, emerge del lago que rodea la aldea (≈18 m de largo en el juego).
```
Stylized anime video game boss creature, a gigantic three-tailed sea turtle beast, huge domed shell completely covered in sharp coral spikes and barnacles, three long thick crustacean-like tails, short powerful legs with claws, a single large glowing red eye on the left of its face and a scarred closed eye on the right, small horns, heavy armored jaw, color palette of dark slate grey shell with pale coral-pink spikes and muted teal skin, wet glossy surfaces, full body, three-quarter front view, standing on all fours, isolated single object, plain flat light grey background, even soft studio lighting, no water, no ground, no text, no shadows on background, high detail game asset concept, clean readable silhouette
```

## pajaro_papel.png
Para qué: mensajero de papel que vuela hasta el jugador y se despliega con las órdenes del líder.
```
Stylized anime video game prop, an origami bird made of folded lilac-white paper, crisp geometric folds, wings spread in flight, a thin red paper seal strip around its body with four short vertical white lines printed on it, slightly glowing edges, three-quarter view, isolated single object, plain flat light grey background, even soft studio lighting, no text, no shadows, clean game asset
```

## lider_rebelde.png
Para qué: líder de los rebeldes (capítulo 2) y base de los cazarrecompensas con nombre.
```
Stylized anime video game character, adult male rogue ninja rebel leader, tall and muscular, torn dark grey rain cloak over black combat clothing, scratched metal forehead protector with a slash across it, bandaged forearms, heavy dark gauntlets, burgundy red scarf, a large cleaver sword strapped on his back, scar across the face, determined grim expression, full body, front view, standing in A-pose with arms angled down away from the body, feet slightly apart, isolated, plain flat light grey background, even soft studio lighting, no text, no shadows, clean cel-shaded anime game style, muted rainy village palette with lilac accents
```

## intruso.png
Para qué: ninja infiltrado que huye por los techos (capítulo 3 y evento «Alarma de la lluvia»).
```
Stylized anime video game character, slim agile infiltrator ninja, dark navy hooded bodysuit, cloth mask covering the lower face, short tanto blade on the lower back, light leather pouches on the thighs, rain-soaked look, sharp watchful eyes, full body, front view, standing in A-pose with arms angled down away from the body, feet slightly apart, isolated, plain flat light grey background, even soft studio lighting, no text, no shadows, clean cel-shaded anime game style, muted rainy village palette
```

## pergamino.png
Para qué: recompensa que enseña un jutsu nuevo (aparece en la pantalla de recompensas y en el suelo al ganarlo).
```
Stylized anime video game prop, a ninja jutsu scroll, thick rolled parchment with dark lacquered wooden end caps, partly unrolled showing brush ink hand-seal diagrams, tied with a burgundy red cord and a small metal clasp, faint lilac glow along the paper edge, three-quarter view, isolated single object, plain flat light grey background, even soft studio lighting, no readable text, no shadows, clean game asset
```

## cofre_recompensa.png
Para qué: cofre de la pantalla de recompensas (se abre con animación).
```
Stylized anime video game prop, a small reward chest made of dark riveted gunmetal plates and weathered wood, burgundy red trim, an amber glowing paper seal tag on the lid with four short vertical white lines, sturdy iron corners, closed lid, three-quarter view, isolated single object, plain flat light grey background, even soft studio lighting, no text, no shadows, clean game asset
```
