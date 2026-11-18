class_name Materiales
extends RefCounted
## Fábrica y caché de materiales y mallas simples (todo por código, sin texturas externas).

static var _cache: Dictionary = {}
static var _textura_suave: Texture2D = null


## Contorno que reciben los materiales sólidos creados a continuación (lo fija quien construye:
## personajes o escenario, según la calidad gráfica). 0 = sin contorno.
static var grosor_contorno := 0.0


## Material sólido con cel shading (bandas, rim) y, si corresponde, contorno negro.
static func solido(c: Color, rugosidad := 0.8, metalico := 0.0) -> Material:
	return Shaders.toon(c, grosor_contorno > 0.0, grosor_contorno, metalico, rugosidad, 0.0 if rugosidad > 0.5 else 0.6)


## Material PBR normal (para el suelo mojado y superficies que deben reflejar).
static func pbr(c: Color, rugosidad := 0.8, metalico := 0.0) -> StandardMaterial3D:
	var clave := "s_%s_%.2f_%.2f" % [c.to_html(), rugosidad, metalico]
	if _cache.has(clave):
		return _cache[clave]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugosidad
	m.metallic = metalico
	_cache[clave] = m
	return m


static func emisivo(c: Color, energia := 2.0) -> StandardMaterial3D:
	var clave := "e_%s_%.2f" % [c.to_html(), energia]
	if _cache.has(clave):
		return _cache[clave]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energia
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache[clave] = m
	return m


## Material aditivo para partículas y brillos (usa el color de vértice de la partícula).
static func particula(c: Color, aditivo := true) -> StandardMaterial3D:
	var clave := "p_%s_%s" % [c.to_html(), str(aditivo)]
	if _cache.has(clave):
		return _cache[clave]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if aditivo else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	m.albedo_texture = textura_suave()
	m.disable_receive_shadows = true
	m.no_depth_test = false
	_cache[clave] = m
	return m


static func transparente(c: Color, aditivo := false) -> StandardMaterial3D:
	var clave := "t_%s_%s" % [c.to_html(), str(aditivo)]
	if _cache.has(clave):
		return _cache[clave]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if aditivo else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	_cache[clave] = m
	return m


## Textura radial suave generada por código (para partículas y marcas).
static func textura_suave() -> Texture2D:
	if _textura_suave != null:
		return _textura_suave
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.8))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_textura_suave = t
	return t


# ---- mallas

static func caja(tam: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	b.material = mat
	mi.mesh = b
	return mi


static func cilindro(r_sup: float, r_inf: float, alto: float, mat: Material, lados := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_sup
	c.bottom_radius = r_inf
	c.height = alto
	c.radial_segments = lados
	c.rings = 1
	c.material = mat
	mi.mesh = c
	return mi


static func esfera(r: float, mat: Material, seg := 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(seg / 2, 4)
	s.material = mat
	mi.mesh = s
	return mi


static func capsula(r: float, alto: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(alto, r * 2.0)
	c.radial_segments = 8
	c.rings = 2
	c.material = mat
	mi.mesh = c
	return mi


static func plano_suelo(radio: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radio * 2.0, radio * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	q.material = mat
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Disco plano (polígono) en el plano XZ.
static func disco(radio: float, mat: Material, lados := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radio
	c.bottom_radius = radio
	c.height = 0.02
	c.radial_segments = lados
	c.rings = 1
	c.cap_bottom = false
	c.material = mat
	mi.mesh = c
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
