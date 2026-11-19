class_name Shaders
extends RefCounted
## Shaders escritos por código (sin editor) y fábricas de materiales que los usan.

static var _cache: Dictionary = {}

const RUIDO := """
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
float ruido3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1,0,0)), f.x),
				   mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), f.x), f.y),
			   mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), f.x),
				   mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * ruido3(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}
vec2 hash22(vec2 p) {
	vec3 a = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	a += dot(a, a.yzx + 33.33);
	return fract((a.xx + a.yz) * a.zy);
}
"""

## Cel shading: 3 bandas de luz, color de sombra frío, luz de contorno (rim) y brillo duro.
const TOON := """
shader_type spatial;
render_mode cull_back;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 color_sombra : source_color = vec4(0.38, 0.42, 0.6, 1.0);
uniform float bandas = 3.0;
uniform float rim_fuerza = 0.45;
uniform vec4 rim_color : source_color = vec4(0.7, 0.82, 1.0, 1.0);
uniform float brillo = 0.0;
uniform float metalico = 0.0;
uniform float rugosidad = 0.85;
uniform vec4 emision : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emision_fuerza = 0.0;

void fragment() {
	ALBEDO = albedo.rgb;
	METALLIC = metalico;
	ROUGHNESS = rugosidad;
	EMISSION = emision.rgb * emision_fuerza;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float l = clamp(ndl * 0.5 + 0.5, 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		l *= mix(0.35, 1.0, ATTENUATION);
		float b = clamp(floor(l * bandas) / (bandas - 1.0), 0.0, 1.0);
		DIFFUSE_LIGHT += mix(color_sombra.rgb, vec3(1.0), b) * LIGHT_COLOR / PI;
	} else {
		float b = clamp(floor(l * ATTENUATION * bandas * 1.5) / (bandas - 1.0), 0.0, 1.2);
		DIFFUSE_LIGHT += b * LIGHT_COLOR / PI;
	}
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	rim = smoothstep(0.62, 0.72, rim) * clamp(ndl + 0.5, 0.0, 1.0);
	SPECULAR_LIGHT += rim * rim_fuerza * rim_color.rgb * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION);
	if (brillo > 0.0) {
		vec3 h = normalize(VIEW + LIGHT);
		SPECULAR_LIGHT += step(0.93, dot(NORMAL, h)) * brillo * LIGHT_COLOR / PI * ATTENUATION;
	}
}
"""

## Cel shading con texturas horneadas: color (A = rugosidad) + normales, humedad por lluvia
## (oscurece y abrillanta las caras que miran arriba, chorreaduras que bajan por las paredes).
## Modo triplanar opcional en espacio mundo (para piezas escaladas sin UV coherentes).
const TOON_TEX := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D tex_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tinte : source_color = vec4(1.0);
uniform vec2 escala_uv = vec2(1.0);
uniform float triplanar = 0.0;
uniform float escala_mundo = 0.25;
uniform float fuerza_normal = 1.0;
uniform float metalico = 0.0;
uniform float humedad = 0.6;
uniform float chorreo = 1.0;
uniform vec4 color_sombra : source_color = vec4(0.3, 0.32, 0.48, 1.0);
uniform float rim_fuerza = 0.35;
uniform vec4 emision : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emision_fuerza = 0.0;
varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 muestra(sampler2D t, vec2 uv) { return texture(t, uv); }

void fragment() {
	vec4 c;
	vec3 nm;
	if (triplanar > 0.5) {
		vec3 b = pow(abs(wnorm), vec3(4.0));
		b /= (b.x + b.y + b.z);
		vec3 p = wpos * escala_mundo;
		c = texture(tex_color, p.zy) * b.x + texture(tex_color, p.xz) * b.y + texture(tex_color, p.xy) * b.z;
		nm = texture(tex_normal, p.zy).rgb * b.x + texture(tex_normal, p.xz).rgb * b.y + texture(tex_normal, p.xy).rgb * b.z;
	} else {
		vec2 uv = UV * escala_uv;
		c = texture(tex_color, uv);
		nm = texture(tex_normal, uv).rgb;
	}
	vec3 alb = c.rgb * tinte.rgb;
	float rug = c.a;
	// Humedad: caras hacia arriba encharcadas; paredes con chorreaduras animadas que bajan.
	float arriba = clamp(wnorm.y, 0.0, 1.0);
	float chorros = 0.0;
	if (chorreo > 0.0) {
		float col_x = floor((wpos.x + wpos.z) * 7.0);
		float h = fract(sin(col_x * 12.9898) * 43758.5453);
		float y = fract(wpos.y * 0.12 + TIME * (0.25 + h * 0.4) + h * 7.0);
		chorros = step(0.72, h) * smoothstep(0.0, 0.08, y) * smoothstep(0.35, 0.1, y) * (1.0 - arriba) * chorreo;
	}
	float mojado = clamp(humedad * (0.35 + arriba * 0.65) + chorros * 0.6, 0.0, 1.0);
	alb *= mix(1.0, 0.62, mojado);
	rug = mix(rug, rug * 0.25, mojado);
	ALBEDO = alb;
	ROUGHNESS = clamp(rug, 0.04, 1.0);
	METALLIC = metalico;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = fuerza_normal;
	EMISSION = emision.rgb * emision_fuerza;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float l = clamp(ndl * 0.5 + 0.5, 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		l *= mix(0.4, 1.0, ATTENUATION);
		// Bandas con borde suave (aspecto de ilustración pintada).
		float b = smoothstep(0.42, 0.5, l) * 0.55 + smoothstep(0.68, 0.74, l) * 0.45;
		DIFFUSE_LIGHT += mix(color_sombra.rgb, vec3(1.0), b) * LIGHT_COLOR / PI;
	} else {
		float a = l * ATTENUATION;
		float b = smoothstep(0.08, 0.16, a) * 0.6 + smoothstep(0.3, 0.42, a) * 0.6;
		DIFFUSE_LIGHT += b * LIGHT_COLOR / PI;
	}
	vec3 h = normalize(VIEW + LIGHT);
	float brillo = pow(clamp(dot(NORMAL, h), 0.0, 1.0), mix(160.0, 12.0, ROUGHNESS));
	SPECULAR_LIGHT += smoothstep(0.35, 0.55, brillo) * (1.0 - ROUGHNESS) * 0.8 * LIGHT_COLOR * ATTENUATION;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	rim = smoothstep(0.65, 0.75, rim) * clamp(ndl + 0.5, 0.0, 1.0);
	SPECULAR_LIGHT += rim * rim_fuerza * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION);
}
"""

## Contorno negro por casco invertido: el mismo mesh, inflado en espacio mundo y con caras traseras.
const CONTORNO := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled;
uniform float grosor = 0.012;
uniform vec4 color : source_color = vec4(0.02, 0.02, 0.05, 1.0);
void vertex() {
	vec3 pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = length(CAMERA_POSITION_WORLD - pm);
	pm += n * grosor * clamp(d * 0.16, 0.7, 5.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pm, 1.0);
}
void fragment() {
	ALBEDO = color.rgb;
}
"""

## Fuego con ruido animado: núcleo blanco-amarillo, cuerpo naranja y borde rojo; la superficie ondula.
const FUEGO := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, fog_disabled;
uniform vec4 color_nucleo : source_color = vec4(1.0, 0.95, 0.65, 1.0);
uniform vec4 color_medio : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 color_borde : source_color = vec4(0.6, 0.06, 0.02, 1.0);
uniform float intensidad = 3.0;
uniform float desplazamiento = 0.18;
uniform float escala_ruido = 1.0;
uniform float velocidad = 1.0;
uniform float opacidad = 1.0;
varying vec3 p_obj;
RUIDO
void vertex() {
	p_obj = VERTEX * escala_ruido;
	float n = fbm3(p_obj * 2.2 + vec3(0.0, -TIME * 2.5 * velocidad, 0.0));
	VERTEX += NORMAL * (n - 0.35) * desplazamiento / max(escala_ruido, 0.01);
}
void fragment() {
	float fres = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.3);
	float n = fbm3(p_obj * 3.2 + vec3(0.0, -TIME * 3.4 * velocidad, TIME * 0.8));
	float t = clamp(fres * 0.85 + n * 1.25 - 0.5, 0.0, 1.0);
	vec3 c = mix(color_borde.rgb, color_medio.rgb, smoothstep(0.08, 0.45, t));
	c = mix(c, color_nucleo.rgb, smoothstep(0.55, 0.92, t));
	ALBEDO = c * intensidad;
	ALPHA = clamp(t * 2.2 + 0.15, 0.0, 1.0) * opacidad;
}
"""

## Distorsión de calor: refracta la pantalla alrededor de la bola de fuego (solo calidad alta).
const CALOR := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, fog_disabled;
uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform float fuerza = 0.025;
RUIDO
void fragment() {
	float fres = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 q = vec3(SCREEN_UV * 12.0, TIME * 2.5);
	vec2 off = vec2(ruido3(q) - 0.5, ruido3(q + vec3(5.2, 1.3, 0.0)) - 0.5);
	// Solo un anillo alrededor de la bola: el centro lo cubre el fuego.
	ALBEDO = texture(pantalla, SCREEN_UV + off * fuerza).rgb;
	ALPHA = smoothstep(0.05, 0.35, fres) * (1.0 - smoothstep(0.45, 0.75, fres)) * 0.85;
}
"""

## Charcos: muy brillantes (reflejan la sonda) con ondas de gotas animadas.
const CHARCO := """
shader_type spatial;
render_mode cull_back;
uniform vec4 color : source_color = vec4(0.08, 0.11, 0.15, 1.0);
uniform float densidad = 1.6;
uniform float fuerza = 1.0;
uniform vec4 reflejo : source_color = vec4(0.42, 0.46, 0.62, 1.0);
varying vec3 wpos;
RUIDO
float ondas(vec2 p) {
	float h = 0.0;
	vec2 celda = floor(p * densidad);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 c = celda + vec2(float(x), float(y));
			vec2 rnd = hash22(c);
			vec2 centro = (c + rnd) / densidad;
			float fase = fract(TIME * 0.85 + rnd.x * 7.31 + rnd.y * 3.1);
			float d = length(p - centro);
			float r = fase * 0.55;
			h += sin((d - r) * 45.0) * smoothstep(0.07, 0.0, abs(d - r)) * (1.0 - fase);
		}
	}
	return h;
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz;
	vec3 n = vec3(0.0, 1.0, 0.0);
	if (fuerza > 0.0) {
		float e = 0.012;
		float h = ondas(p);
		float hx = ondas(p + vec2(e, 0.0));
		float hz = ondas(p + vec2(0.0, e));
		n = normalize(vec3((h - hx) * 0.35 * fuerza, 1.0, (h - hz) * 0.35 * fuerza));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = color.rgb;
	METALLIC = 0.85;
	ROUGHNESS = 0.03;
	SPECULAR = 0.8;
	// Espejo de agua: el cielo se refleja más cuanto más rasante es la mirada (fresnel), deformado por las ondas.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = reflejo.rgb * (0.12 + fres * 0.55);
}
"""

## Agua del canal: corriente con ondas grandes de ruido + anillos de lluvia, muy reflectante y oscura.
const AGUA := """
shader_type spatial;
render_mode cull_back;
uniform vec4 color : source_color = vec4(0.05, 0.07, 0.1, 1.0);
uniform vec2 flujo = vec2(0.35, 0.0);
uniform float fuerza = 1.0;
varying vec3 wpos;
RUIDO
float altura(vec2 p) {
	float h = fbm3(vec3(p * 0.35 + flujo * TIME * 0.6, TIME * 0.15)) * 1.2;
	vec2 celda = floor(p * 1.3);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 c = celda + vec2(float(x), float(y));
			vec2 rnd = hash22(c);
			vec2 centro = (c + rnd) / 1.3;
			float fase = fract(TIME * 0.9 + rnd.x * 5.1);
			float d = length(p - centro);
			float r = fase * 0.6;
			h += sin((d - r) * 40.0) * smoothstep(0.08, 0.0, abs(d - r)) * (1.0 - fase) * 0.25;
		}
	}
	return h;
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz;
	float e = 0.05;
	float h = altura(p);
	vec3 n = normalize(vec3((h - altura(p + vec2(e, 0.0))) * 0.6 * fuerza, 1.0, (h - altura(p + vec2(0.0, e))) * 0.6 * fuerza));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = color.rgb;
	METALLIC = 0.6;
	ROUGHNESS = 0.05;
	SPECULAR = 0.7;
}
"""

## Cascada que cae de un desagüe: franjas de ruido que bajan y espuma abajo.
const CASCADA := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
uniform vec4 color : source_color = vec4(0.75, 0.82, 0.92, 1.0);
uniform float velocidad = 2.5;
RUIDO
void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float n = ruido3(vec3(UV.x * 14.0, UV.y * 2.5 - TIME * velocidad, TIME * 0.3));
	float n2 = ruido3(vec3(UV.x * 30.0, UV.y * 5.0 - TIME * velocidad * 1.4, 3.0));
	float franjas = smoothstep(0.35, 0.75, n * 0.6 + n2 * 0.5);
	float borde = 1.0 - smoothstep(0.55, 1.0, x + (1.0 - UV.y) * 0.0);
	float espuma = smoothstep(0.75, 1.0, UV.y);
	ALBEDO = color.rgb * (0.8 + franjas * 0.6 + espuma * 0.5);
	ALPHA = clamp((0.25 + franjas * 0.6 + espuma * 0.5) * borde, 0.0, 0.9);
}
"""

## Figura espectral (Susanoo, auras): fresnel aditivo con ruido que sube y parpadeo.
const ESPECTRAL := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;
uniform vec4 color : source_color = vec4(0.55, 0.35, 1.0, 1.0);
uniform float intensidad = 1.4;
uniform float opacidad = 1.0;
varying vec3 wpos;
RUIDO
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.6);
	float n = fbm3(wpos * 1.8 + vec3(0.0, -TIME * 1.6, TIME * 0.3));
	float a = clamp(fres * 1.3 + n * 0.45 - 0.1, 0.0, 1.0);
	ALBEDO = color.rgb * intensidad * (0.7 + n * 0.6);
	ALPHA = a * opacidad * (0.85 + 0.15 * sin(TIME * 23.0));
}
"""

## Capa de nubes en movimiento, con destello de relámpago.
const NUBES := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
uniform vec4 color_oscuro : source_color = vec4(0.2, 0.23, 0.27, 1.0);
uniform vec4 color_claro : source_color = vec4(0.55, 0.6, 0.66, 1.0);
uniform float relampago = 0.0;
uniform float radio = 280.0;
varying vec3 wpos;
RUIDO
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = wpos.xz * 0.012;
	float n = fbm3(vec3(uv + TIME * vec2(0.02, 0.008), TIME * 0.02));
	float n2 = fbm3(vec3(uv * 2.3 - TIME * vec2(0.015, 0.02), 4.0));
	float d = n * 0.7 + n2 * 0.3;
	float borde = 1.0 - smoothstep(radio * 0.55, radio, length(wpos.xz));
	vec3 c = mix(color_oscuro.rgb, color_claro.rgb, smoothstep(0.35, 0.75, d));
	c += relampago * vec3(0.75, 0.82, 1.0) * (0.4 + d);
	ALBEDO = c;
	ALPHA = smoothstep(0.28, 0.6, d) * 0.92 * borde;
}
"""

## Banco de niebla vertical (capas alrededor del campo), con ruido que se desplaza.
const NIEBLA := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
uniform vec4 color : source_color = vec4(0.5, 0.55, 0.6, 1.0);
uniform float opacidad = 0.35;
uniform float velocidad = 0.02;
uniform float semilla = 0.0;
RUIDO
void fragment() {
	float n = fbm3(vec3(UV * vec2(4.0, 1.5) + vec2(TIME * velocidad, 0.0), semilla));
	float vert = smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.45, UV.y);
	float horiz = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	ALBEDO = color.rgb;
	ALPHA = smoothstep(0.3, 0.75, n) * vert * horiz * opacidad;
}
"""

## Ojo con iris; con el modo ocular se vuelve rojo con 3 tomoe que giran.
const OJO := """
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;
uniform float activo = 0.0;
uniform float patron = 1.0;   // 1 tomoe, 2 caleidoscopio, 3 anillos, 4 blanco con venas
uniform vec4 iris_normal : source_color = vec4(0.08, 0.07, 0.07, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 1.6;
	// forma de almendra
	float alm = abs(p.y) - (1.0 - pow(abs(p.x) / 1.6, 2.0)) * 0.95;
	if (alm > 0.0) { discard; }
	vec3 c = vec3(0.95, 0.95, 0.97);
	vec2 q = vec2(p.x, p.y) / 0.9;
	float r = length(q);
	float ang = atan(q.y, q.x);
	int pt = int(patron + 0.5);
	vec3 activo_col = pt == 3 ? vec3(0.62, 0.52, 0.86) : (pt == 4 ? vec3(0.9, 0.88, 0.96) : vec3(0.85, 0.02, 0.04));
	vec3 iris = mix(iris_normal.rgb, activo_col, activo);
	if (pt == 4 && activo > 0.5) {
		// Venas alrededor del ojo.
		c = mix(c, vec3(0.75, 0.72, 0.85), 0.4 + 0.3 * sin(ang * 9.0));
	}
	if (r < 0.75) {
		c = iris;
		if (activo > 0.5) {
			if (pt == 1) {
				if (abs(r - 0.42) < 0.035) { c = vec3(0.05, 0.0, 0.0); }
				float a0 = ang + TIME * 1.5;
				for (int i = 0; i < 3; i++) {
					float a = a0 + float(i) * 2.094;
					vec2 t = vec2(cos(a), sin(a)) * 0.42;
					vec2 rp = vec2(cos(a - 0.35), sin(a - 0.35)) * 0.45;
					if (length(q - t) < 0.12 || length(q - rp) < 0.07) { c = vec3(0.03, 0.0, 0.0); }
				}
			} else if (pt == 2) {
				// Caleidoscopio: tres aspas curvas que giran.
				float a2 = ang + TIME * 0.8 + r * 2.5;
				float aspa = abs(sin(a2 * 1.5));
				if (aspa > 0.75 && r > 0.12) { c = vec3(0.03, 0.0, 0.0); }
			} else if (pt == 3) {
				// Anillos concéntricos.
				if (fract(r * 5.0) < 0.18) { c = vec3(0.15, 0.08, 0.25); }
			} else {
				c = vec3(0.88, 0.86, 0.94);
			}
		}
		if (r < 0.16 && !(pt == 4 && activo > 0.5)) { c = vec3(0.01); }
		if (r > 0.68) { c *= 0.6; }
	}
	ALBEDO = c * (1.0 + activo * (pt == 4 ? 0.6 : 1.6));
}
"""

## Indicador de apuntado en el suelo: franja con flechas que avanzan.
## Torre de los modelos IA: color por vértice (de TRELLIS) + detalle triplanar de concreto/lámina,
## metal mojado con chorreaduras de lluvia y bandas de luz estilo anime.
const TORRE_IA := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D tex_detalle : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float escala_mundo = 0.22;
uniform float brillo = 2.7;
uniform float humedad = 0.75;
uniform float chorreo = 1.0;
uniform vec4 color_sombra : source_color = vec4(0.42, 0.44, 0.6, 1.0);
varying vec3 wpos;
varying vec3 wnorm;
varying vec3 col;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	col = COLOR.rgb;
}

void fragment() {
	vec3 b = pow(abs(wnorm), vec3(4.0));
	b /= (b.x + b.y + b.z);
	vec3 p = wpos * escala_mundo;
	vec3 det = texture(tex_detalle, p.zy).rgb * b.x + texture(tex_detalle, p.xz).rgb * b.y + texture(tex_detalle, p.xy).rgb * b.z;
	vec3 nm = texture(tex_normal, p.zy).rgb * b.x + texture(tex_normal, p.xz).rgb * b.y + texture(tex_normal, p.xy).rgb * b.z;
	// El color de TRELLIS manda; el detalle aporta grano de metal y concreto.
	float lum = dot(det, vec3(0.33));
	vec3 alb = col * brillo * mix(0.75, 1.25, lum);
	float sat = length(col - vec3(dot(col, vec3(0.33))));
	// Metal gris (poco saturado) liso y mojado; óxido y tuberías más ásperos.
	float metal = clamp(1.0 - sat * 9.0, 0.0, 1.0);
	float arriba = clamp(wnorm.y, 0.0, 1.0);
	float chorros = 0.0;
	if (chorreo > 0.0) {
		float col_x = floor((wpos.x + wpos.z) * 2.5);
		float h = fract(sin(col_x * 12.9898) * 43758.5453);
		float y = fract(wpos.y * 0.05 + TIME * (0.18 + h * 0.3) + h * 7.0);
		chorros = step(0.7, h) * smoothstep(0.0, 0.08, y) * smoothstep(0.35, 0.1, y) * (1.0 - arriba) * chorreo;
	}
	float mojado = clamp(humedad * (0.4 + arriba * 0.6) + chorros * 0.6, 0.0, 1.0);
	ALBEDO = alb * mix(1.0, 0.7, mojado);
	METALLIC = metal * 0.18;
	ROUGHNESS = clamp(mix(0.7, 0.2, metal) * mix(1.0, 0.35, mojado), 0.05, 1.0);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.6;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float l = clamp(ndl * 0.5 + 0.5, 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		l *= mix(0.45, 1.0, ATTENUATION);
		float bb = smoothstep(0.42, 0.5, l) * 0.55 + smoothstep(0.68, 0.74, l) * 0.45;
		DIFFUSE_LIGHT += mix(color_sombra.rgb, vec3(1.0), bb) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += clamp(ndl, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
	vec3 h = normalize(VIEW + LIGHT);
	float spec = pow(max(dot(NORMAL, h), 0.0), 40.0);
	SPECULAR_LIGHT += smoothstep(0.3, 0.9, spec) * LIGHT_COLOR * 0.12 * (1.0 - ROUGHNESS) * ATTENUATION;
}
"""

## Ojo de la torre: anillos concéntricos morados con brillo leve que respira.
const OJO_TORRE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 color_iris : source_color = vec4(0.62, 0.42, 0.95, 1.0);
uniform vec4 color_anillo : source_color = vec4(0.22, 0.08, 0.38, 1.0);
uniform float anillos = 4.0;
uniform float brillo = 1.4;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	if (r > 1.0) discard;
	float banda = smoothstep(0.42, 0.5, abs(fract(r * anillos) - 0.5) * 2.0);
	vec3 c = mix(color_anillo.rgb, color_iris.rgb, banda);
	c = mix(c, vec3(0.08, 0.02, 0.14), smoothstep(0.16, 0.1, r));
	c *= mix(0.55, 1.0, smoothstep(1.0, 0.75, r));
	float pulso = 0.85 + 0.15 * sin(TIME * 1.3);
	ALBEDO = c;
	EMISSION = c * brillo * pulso * 0.6;
}
"""

## Ninja de los modelos IA: textura de Meshy recoloreada por zonas (COLOR: R piel, G pelo, B chaleco,
## A ropa 0,5 camisa / 1 pantalón). Cada zona toma el color elegido conservando el sombreado de la textura.
const NINJA_IA := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 c_piel : source_color = vec4(1.0);
uniform vec4 c_pelo : source_color = vec4(1.0);
uniform vec4 c_chaleco : source_color = vec4(1.0);
uniform vec4 c_camisa : source_color = vec4(1.0);
uniform vec4 c_pantalon : source_color = vec4(1.0);
uniform vec4 o_piel : source_color = vec4(1.0);
uniform vec4 o_pelo : source_color = vec4(1.0);
uniform vec4 o_chaleco : source_color = vec4(1.0);
uniform vec4 o_camisa : source_color = vec4(1.0);
uniform vec4 o_pantalon : source_color = vec4(1.0);
uniform float zona_pelo_forzada = 0.0;   // 1 en la malla del cabello
uniform vec4 color_sombra : source_color = vec4(0.38, 0.42, 0.6, 1.0);
uniform float rim_fuerza = 0.45;
uniform vec4 rim_color : source_color = vec4(0.7, 0.82, 1.0, 1.0);
varying vec4 zona;

void vertex() {
	zona = COLOR;
}

float lum(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }

// Recolor: el color elegido más la variación de la textura respecto al color medio de la zona
// (conserva pliegues y brillos; con el color original devuelve la textura tal cual).
vec3 recolor(vec3 t, vec3 orig, vec3 nuevo) {
	return clamp(nuevo + (t - orig) * mix(1.0, 1.6, step(lum(orig), 0.05)), 0.0, 1.0);
}

void fragment() {
	vec3 t = texture(tex, UV).rgb;
	vec4 z = zona;
	if (zona_pelo_forzada > 0.5) z = vec4(0.0, 1.0, 0.0, 0.0);
	float w_pant = clamp((z.a - 0.5) * 2.0, 0.0, 1.0);
	float w_cam = clamp(z.a * 2.0, 0.0, 1.0) - w_pant;
	vec3 c = t;
	c = mix(c, recolor(t, o_piel.rgb, c_piel.rgb), z.r);
	c = mix(c, recolor(t, o_pelo.rgb, c_pelo.rgb), z.g);
	c = mix(c, recolor(t, o_chaleco.rgb, c_chaleco.rgb), z.b);
	c = mix(c, recolor(t, o_camisa.rgb, c_camisa.rgb), w_cam);
	c = mix(c, recolor(t, o_pantalon.rgb, c_pantalon.rgb), w_pant);
	ALBEDO = c;
	ROUGHNESS = 0.75;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float l = clamp(ndl * 0.5 + 0.5, 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		l *= mix(0.35, 1.0, ATTENUATION);
		float b = smoothstep(0.45, 0.52, l) * 0.6 + smoothstep(0.7, 0.76, l) * 0.4;
		DIFFUSE_LIGHT += mix(color_sombra.rgb, vec3(1.0), b) * LIGHT_COLOR / PI;
	} else {
		float a = l * ATTENUATION;
		DIFFUSE_LIGHT += (smoothstep(0.08, 0.16, a) * 0.6 + smoothstep(0.3, 0.42, a) * 0.6) * LIGHT_COLOR / PI;
	}
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	rim = smoothstep(0.62, 0.72, rim) * clamp(ndl + 0.5, 0.0, 1.0);
	SPECULAR_LIGHT += rim * rim_fuerza * rim_color.rgb * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION);
}
"""

const INDICADOR := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float largo = 10.0;
uniform float cancelar = 0.0;
void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float borde = smoothstep(0.75, 0.95, x) * (1.0 - smoothstep(0.95, 1.0, x));
	float y = UV.y * largo;
	float chevron = fract(y * 0.6 - TIME * 1.8 + x * 0.35);
	float flechas = smoothstep(0.0, 0.15, chevron) * (1.0 - smoothstep(0.25, 0.4, chevron)) * (1.0 - x);
	float fin = smoothstep(0.0, 0.05, UV.y) * smoothstep(1.0, 0.85, UV.y);
	vec3 c = mix(color.rgb, vec3(0.5), cancelar);
	ALBEDO = c * 2.0;
	ALPHA = clamp(borde * 0.9 + flechas * 0.7 + 0.12, 0.0, 1.0) * fin * mix(1.0, 0.35, cancelar);
}
"""


static func _shader(clave: String, codigo: String) -> Shader:
	if _cache.has("sh_" + clave):
		return _cache["sh_" + clave]
	var s := Shader.new()
	s.code = codigo.replace("RUIDO", RUIDO)
	_cache["sh_" + clave] = s
	return s


static func shader(clave: String) -> Shader:
	match clave:
		"toon": return _shader(clave, TOON)
		"toon_tex": return _shader(clave, TOON_TEX)
		"contorno": return _shader(clave, CONTORNO)
		"fuego": return _shader(clave, FUEGO)
		"calor": return _shader(clave, CALOR)
		"charco": return _shader(clave, CHARCO)
		"nubes": return _shader(clave, NUBES)
		"niebla": return _shader(clave, NIEBLA)
		"ojo": return _shader(clave, OJO)
		"agua": return _shader(clave, AGUA)
		"espectral": return _shader(clave, ESPECTRAL)
		"cascada": return _shader(clave, CASCADA)
		"indicador": return _shader(clave, INDICADOR)
		"torre_ia": return _shader(clave, TORRE_IA)
		"ojo_torre": return _shader(clave, OJO_TORRE)
		"ninja_ia": return _shader(clave, NINJA_IA)
	push_error("Shader desconocido " + clave)
	return null


## Material de cel shading (con contorno opcional como segunda pasada).
static func toon(c: Color, contorno := true, grosor := 0.012, metalico := 0.0, rugosidad := 0.85, brillo := 0.0) -> ShaderMaterial:
	var clave := "toon_%s_%s_%.3f_%.2f_%.2f_%.2f" % [c.to_html(), str(contorno), grosor, metalico, rugosidad, brillo]
	if _cache.has(clave):
		return _cache[clave]
	var m := ShaderMaterial.new()
	m.shader = shader("toon")
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("metalico", metalico)
	m.set_shader_parameter("rugosidad", rugosidad)
	m.set_shader_parameter("brillo", brillo)
	# Sombra fría y algo saturada (estilo anime): mezcla el color base con azul.
	m.set_shader_parameter("color_sombra", Color(0.32, 0.36, 0.55).lerp(c, 0.25))
	if contorno:
		m.next_pass = material_contorno(grosor)
	_cache[clave] = m
	return m


## Material con textura horneada de assets/texturas/<nombre>_color.png y _normal.png.
static func toon_tex(nombre: String, tinte := Color.WHITE, escala_uv := Vector2.ONE, triplanar := false, escala_mundo := 0.25,
		metalico := 0.0, humedad := 0.6, contorno := 0.0) -> ShaderMaterial:
	var clave := "tt_%s_%s_%s_%s_%.3f_%.2f_%.2f_%.3f" % [nombre, tinte.to_html(), str(escala_uv), str(triplanar), escala_mundo, metalico, humedad, contorno]
	if _cache.has(clave):
		return _cache[clave]
	var m := ShaderMaterial.new()
	m.shader = shader("toon_tex")
	m.set_shader_parameter("tex_color", load("res://assets/texturas/%s_color.png" % nombre))
	m.set_shader_parameter("tex_normal", load("res://assets/texturas/%s_normal.png" % nombre))
	m.set_shader_parameter("tinte", tinte)
	m.set_shader_parameter("escala_uv", escala_uv)
	m.set_shader_parameter("triplanar", 1.0 if triplanar else 0.0)
	m.set_shader_parameter("escala_mundo", escala_mundo)
	m.set_shader_parameter("metalico", metalico)
	m.set_shader_parameter("humedad", humedad)
	m.set_shader_parameter("chorreo", 1.0 if Ajustes.g("chorreo", true) else 0.0)
	if contorno > 0.0:
		m.next_pass = material_contorno(contorno)
	_cache[clave] = m
	return m


static func material_contorno(grosor := 0.012) -> ShaderMaterial:
	var clave := "contorno_%.3f" % grosor
	if _cache.has(clave):
		return _cache[clave]
	var m := ShaderMaterial.new()
	m.shader = shader("contorno")
	m.set_shader_parameter("grosor", grosor)
	_cache[clave] = m
	return m


static func material(clave: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(clave)
	return m
