extends RefCounted
## Textured surface materials built from the generated textures in
## res://assets/textures/ (made by tools/gen_textures.py).
##
## Materials use triplanar mapping, so any box from greybox.gd gets evenly
## sized, seamless texturing without UV work. World-space triplanar keeps
## textures continuous across neighbouring wall pieces; moving objects
## (doors) use local-space triplanar so the texture moves with them.

const TEXTURE_DIR := "res://assets/textures/"

static var _cache: Dictionary = {}


## surface: stone_wall, flagstone, wood_floor, wood_dark, cloth, plaster, mud, cobbles
## tile: metres covered by one repeat of the texture.
static func get_material(surface: String, tint := Color.WHITE, tile := 2.0, world_space := true) -> StandardMaterial3D:
	var key := "%s|%s|%.3f|%s" % [surface, tint.to_html(), tile, world_space]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = _texture(surface + "_albedo")
	var normal := _texture(surface + "_normal")
	if normal != null:
		m.normal_enabled = true
		m.normal_texture = normal
		m.normal_scale = 1.0
	m.roughness = 1.0
	m.roughness_texture = _texture(surface + "_rough")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world_space
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / tile
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m


static func _texture(texture_name: String) -> Texture2D:
	var path := TEXTURE_DIR + texture_name + ".png"
	if not ResourceLoader.exists(path):
		push_warning("Surfaces: missing texture %s (run tools/gen_textures.py)" % path)
		return null
	return load(path)
