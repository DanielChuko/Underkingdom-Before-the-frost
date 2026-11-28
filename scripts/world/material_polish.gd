extends RefCounted
## Finishes the materials of imported models (characters and props), which
## arrive as flat colour textures with no surface detail. Each material is
## matched by its name and given a tiling detail normal map (projected
## triplanar on UV2, so it works on any UV layout), plus the roughness,
## sheen, metalness or skin scattering that suits it. Each material is only
## polished once, however many models share it.

const TEX := "res://assets/textures/"

## [keywords, detail texture, detail scale, kind]
const RULES := [
	[["cloth and skin"], "cloth", 16.0, "cloth"],
	[["face", "skin", "hand", "neck"], "", 0.0, "skin"],
	[["gem", "cabochon", "jewel"], "", 0.0, "gem"],
	[["gold", "gilded", "gilt", "brass", "crown", "buckle"], "", 0.0, "gold"],
	[["iron", "steel", "metal", "helmet", "rim", "mail"], "rust_metal", 10.0, "iron"],
	[["hair", "fur", "ermine", "beard"], "fur", 14.0, "fur"],
	[["leather", "boot", "glove", "girdle", "belt"], "leather", 9.0, "leather"],
	[["oak", "wood", "grain", "plank"], "wood_dark", 3.0, "wood"],
	[["limestone", "stone", "mortar"], "stone_wall", 0.8, "stone"],
	[["cloth", "silk", "velvet", "tunic", "mantle", "linen", "wool", "vest",
	  "apron", "coat", "sleeve", "fabric", "artwork", "runner", "flax", "cushion", "cap"], "cloth", 16.0, "cloth"],
]

static var _white: ImageTexture


static func polish(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is StandardMaterial3D:
				_polish_material(m)


static func _polish_material(m: StandardMaterial3D) -> void:
	if m.has_meta("polished"):
		return
	m.set_meta("polished", true)
	var name := m.resource_name.to_lower()
	for rule in RULES:
		for key in rule[0]:
			if name.contains(key):
				_apply(m, rule[3], rule[1], rule[2])
				return


static func _apply(m: StandardMaterial3D, kind: String, detail: String, scale: float) -> void:
	match kind:
		"skin":
			m.roughness = 0.6
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.25
			m.rim_enabled = true
			m.rim = 0.15
			m.rim_tint = 0.6
		"gem":
			m.roughness = 0.08
			m.metallic = 0.0
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
		"gold":
			m.metallic = 0.92
			m.roughness = 0.3
		"iron":
			m.metallic = 0.75
			m.roughness = 0.45
		"fur":
			m.roughness = 0.95
			m.rim_enabled = true
			m.rim = 0.35
			m.rim_tint = 0.8
		"leather":
			m.roughness = 0.55
			m.metallic = 0.0
		"wood":
			m.roughness = maxf(m.roughness, 0.72)
			# The supplied wood reads too orange under torchlight.
			m.albedo_color = m.albedo_color * Color(0.78, 0.72, 0.68)
		"stone":
			m.roughness = maxf(m.roughness, 0.85)
		"cloth":
			m.roughness = maxf(m.roughness, 0.88)
			m.metallic = 0.0
			# Soft sheen at grazing angles, as wool and velvet have.
			m.rim_enabled = true
			m.rim = 0.3
			m.rim_tint = 0.7
	if detail == "":
		return
	var path := TEX + detail + "_normal.png"
	if not ResourceLoader.exists(path):
		return
	# Detail normals blend into the main normal map, so switch it on (an
	# unset normal texture reads as flat).
	m.normal_enabled = true
	m.detail_enabled = true
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.uv2_triplanar = true
	m.uv2_scale = Vector3.ONE * scale
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_albedo = _white_texture()
	m.detail_normal = load(path)


static func _white_texture() -> ImageTexture:
	if _white == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white
