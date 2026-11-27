extends RefCounted
## The kingdom's heraldry, made from the user's own artwork: hall banners and
## wall shields use the textures in res://assets/textures/heraldry/, and the
## standing flags use the oak pole of res://assets/models/kingdom_flag_clean.glb.
## Indoors there is no wind, so all cloth hangs straight, still and clean.

const G := preload("res://scripts/world/greybox.gd")
const S := preload("res://scripts/world/surfaces.gd")
const D := preload("res://scripts/world/decor.gd")

const DIR := "res://assets/textures/heraldry/"
const FLAG_MODEL := "res://assets/models/kingdom_flag_clean.glb"
## Height / width of each picture.
const BANNER_ASPECT := 818.0 / 336.0
const SHIELD_ASPECT := 657.0 / 512.0
const FLAG_ASPECT := 683.0 / 1024.0
## Shield designs: "shield_sun_bend" (red and orange halves split diagonally)
## and "shield_sun_pale" (split down the middle).
const SHIELDS := ["shield_sun_bend", "shield_sun_pale"]

static var _materials: Dictionary = {}


## A long banner hanging from an iron rod on the wall. `top` is the middle of
## the rod; normal points out of the wall.
static func banner(parent: Node, top: Vector3, normal: Vector3, width := 1.4) -> Node3D:
	var b := Node3D.new()
	b.position = top
	b.rotation.y = atan2(normal.x, normal.z)
	parent.add_child(b)
	var iron = D.iron()
	var height := width * BANNER_ASPECT
	var rod_z := 0.1

	# Rod on two wall brackets, with ball finials.
	var rod := G.cylinder(b, 0.02, width + 0.32, Vector3(0, 0, rod_z), iron)
	rod.rotation.z = PI * 0.5
	for side in [-1.0, 1.0]:
		G.sphere(b, 0.038, Vector3(side * (width * 0.5 + 0.18), 0, rod_z), iron)
		G.box(b, Vector3(0.03, 0.03, rod_z), Vector3(side * (width * 0.5 + 0.06), 0, rod_z * 0.5), iron, false)

	# Three cloth loops around the rod.
	var loop_mat := S.get_material("cloth", Color(0.36, 0.07, 0.06), 0.5, false)
	for x in [-0.38, 0.0, 0.38]:
		G.box(b, Vector3(width * 0.13, 0.13, 0.055), Vector3(x * width, -0.02, rod_z), loop_mat, false)

	# The cloth: still, with soft vertical folds where it gathers at the loops.
	var cloth := MeshInstance3D.new()
	cloth.mesh = _sheet(Vector2(width, height), 18, 24, "banner")
	cloth.material_override = _material("banner_sun", 0.95)
	cloth.position = Vector3(0, -0.05, rod_z)
	b.add_child(cloth)
	return b


## A painted heater shield hung on a wall. `center` is on the wall surface;
## normal points out of the wall.
static func shield(parent: Node, center: Vector3, normal: Vector3, design := "shield_sun_bend", height := 0.75) -> Node3D:
	var s := Node3D.new()
	s.position = center
	s.rotation.y = atan2(normal.x, normal.z)
	parent.add_child(s)
	var width := height / SHIELD_ASPECT
	var bow := width * 0.07
	# Curved face, and a dark backing board behind it so the edge has thickness.
	var face := MeshInstance3D.new()
	face.mesh = _sheet(Vector2(width, height), 12, 12, "shield", bow)
	face.material_override = _material(design, 0.7)
	face.position = Vector3(0, height * 0.5, 0.035)
	s.add_child(face)
	var back := MeshInstance3D.new()
	back.mesh = face.mesh
	back.material_override = _backing(design)
	back.position = Vector3(0, height * 0.5, 0.012)
	s.add_child(back)
	return s


## A trophy of arms on a wall: two swords crossed behind a painted shield.
static func trophy(parent: Node, center: Vector3, normal: Vector3, design := "shield_sun_bend", height := 1.0) -> Node3D:
	var t := Node3D.new()
	t.position = center
	t.rotation.y = atan2(normal.x, normal.z)
	parent.add_child(t)
	var length := height * 1.6
	for side in [-1.0, 1.0]:
		sword(t, Vector3(0, height * 0.12, 0.012 + (0.006 if side > 0.0 else 0.0)), side * 0.75, length)
	shield(t, Vector3(0, 0, 0.03), Vector3(0, 0, 1), design, height)
	return t


## A plain arming sword lying in the local XY plane (blade pointing down,
## turned by `tilt` about Z), centred on the middle of its blade.
static func sword(parent: Node, pos: Vector3, tilt: float, length := 0.95) -> Node3D:
	var s := Node3D.new()
	s.position = pos
	s.rotation.z = tilt
	parent.add_child(s)
	var steel := G.mat(Color(0.62, 0.6, 0.58), 0.0, 0.85, 0.32)
	var dark := G.mat(Color(0.2, 0.17, 0.14), 0.0, 0.7, 0.5)
	var grip := G.mat(Color(0.22, 0.13, 0.08), 0.0, 0.0, 0.8)
	var blade := length * 0.76
	var top := blade * 0.5
	# Blade with a darker fuller down the middle, and a point.
	G.box(s, Vector3(0.048, blade - 0.06, 0.006), Vector3(0, top - (blade - 0.06) * 0.5 - 0.0, 0), steel, false)
	G.box(s, Vector3(0.012, blade * 0.7, 0.0075), Vector3(0, top - blade * 0.36, 0), dark, false)
	var point := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.048, 0.07, 0.006)
	point.mesh = prism
	point.material_override = steel
	point.position = Vector3(0, top - blade + 0.025, 0)
	point.rotation.z = PI
	s.add_child(point)
	# Crossguard, leather grip and wheel pommel above the blade.
	G.box(s, Vector3(0.2, 0.024, 0.024), Vector3(0, top + 0.012, 0), dark, false)
	G.cylinder(s, 0.015, length * 0.14, Vector3(0, top + 0.024 + length * 0.07, 0), grip, 0.013)
	var pommel := G.cylinder(s, 0.03, 0.022, Vector3(0, top + 0.05 + length * 0.14, 0), dark)
	pommel.rotation.x = PI * 0.5
	return s


## A standing flag on an oak pole (the user's model) with a crossbar, so the
## flag hangs flat with no wind. `base` is on the floor; the flag flies
## towards local +X, turned by `yaw`.
static func standard(parent: Node, base: Vector3, yaw: float, size := 1.25) -> Node3D:
	var f := Node3D.new()
	f.position = base
	f.rotation.y = yaw
	parent.add_child(f)
	var iron = D.iron()

	# Iron foot with three short legs.
	G.cylinder(f, 0.07, 0.16, Vector3(0, 0.08, 0), iron)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var leg := G.box(f, Vector3(0.3, 0.035, 0.05), Vector3(cos(a) * 0.14, 0.03, sin(a) * 0.14), iron, false)
		leg.rotation.y = -a
	G.solid(f, Vector3(0.3, 2.0, 0.3), Vector3(0, 1.0, 0))

	var pole := Node3D.new()
	pole.position = Vector3(0, 0.1, 0)
	pole.scale = Vector3.ONE * size
	f.add_child(pole)
	var packed = load(FLAG_MODEL) if ResourceLoader.exists(FLAG_MODEL) else null
	if packed is PackedScene:
		var inst: Node3D = packed.instantiate()
		# The model's own cloth is shaped by wind; indoors it is replaced.
		var old_cloth := inst.find_child("Flag_Cloth", true, false)
		if old_cloth != null:
			old_cloth.get_parent().remove_child(old_cloth)
			old_cloth.free()
		pole.add_child(inst)
	else:
		G.cylinder(pole, 0.032, 2.72, Vector3(0, 1.36, 0), D.wood_dark())

	# Crossbar at the top of the hoist, and the flag hanging from it.
	var top := 2.55
	var fly := 1.47
	var bar := G.cylinder(pole, 0.018, fly + 0.05, Vector3(fly * 0.5 + 0.01, top + 0.02, 0), D.wood_dark())
	bar.rotation.z = PI * 0.5
	G.sphere(pole, 0.03, Vector3(fly + 0.04, top + 0.02, 0), G.mat(Color(0.45, 0.33, 0.16), 0.0, 0.8, 0.4))
	var width := fly - 0.045
	var cloth := MeshInstance3D.new()
	cloth.mesh = _sheet(Vector2(width, width * FLAG_ASPECT), 20, 14, "flag")
	cloth.material_override = _material("flag_sun", 0.95)
	cloth.position = Vector3(0.045 + width * 0.5, top, 0)
	pole.add_child(cloth)
	return f


## How far the cloth or board stands out (+Z) at (u, v), 0..1 across and down.
## banner: soft folds gathered between the loops, the cloth settling back
## towards the wall lower down. flag: gentle hanging folds. shield: bowed.
static func _depth(kind: String, u: float, v: float, bow: float) -> float:
	match kind:
		"banner":
			var gather := 0.012 * sin(u * TAU * 3.0) * (1.0 - v) * (1.0 - v)
			var fold := 0.009 * sin(u * TAU * 2.0 + 1.1) * (0.4 + 0.6 * v)
			return gather + fold - 0.035 * v
		"flag":
			return 0.012 * sin(u * TAU * 2.5 + 0.4) * (0.5 + 0.5 * v)
		"shield":
			return bow * (1.0 - pow(2.0 * u - 1.0, 2.0))
	return 0.0


## A grid sheet hanging down from y = 0: x across, -y down, z from _depth().
## UVs run 0..1 left to right and top to bottom; faces point towards +Z.
static func _sheet(size: Vector2, cols: int, rows: int, kind: String, bow := 0.0) -> ArrayMesh:
	var pts: Array = []
	for i in rows + 1:
		var v := float(i) / rows
		var row: Array = []
		for j in cols + 1:
			var u := float(j) / cols
			row.append([Vector3((u - 0.5) * size.x, -v * size.y, _depth(kind, u, v, bow)), Vector2(u, v)])
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows:
		for j in cols:
			_tri(st, pts[i][j], pts[i + 1][j], pts[i + 1][j + 1])
			_tri(st, pts[i][j], pts[i + 1][j + 1], pts[i][j + 1])
	st.index()
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	# Godot's front faces wind clockwise: flip a triangle whose clockwise
	# cross product points towards +Z (i.e. it would face away from the viewer).
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	var order := [a, b, c] if (pb - pa).cross(pc - pa).z <= 0.0 else [a, c, b]
	for p in order:
		st.set_uv(p[1])
		st.add_vertex(p[0])


static func _material(texture_name: String, roughness: float) -> StandardMaterial3D:
	if _materials.has(texture_name):
		return _materials[texture_name]
	var m := StandardMaterial3D.new()
	var albedo := DIR + texture_name + "_albedo.png"
	if ResourceLoader.exists(albedo):
		m.albedo_texture = load(albedo)
	else:
		m.albedo_color = Color(0.5, 0.1, 0.08)
		push_warning("Heraldry: missing texture %s" % albedo)
	var normal := DIR + texture_name + "_normal.png"
	if ResourceLoader.exists(normal):
		m.normal_enabled = true
		m.normal_texture = load(normal)
		m.normal_scale = 0.7
	m.roughness = roughness
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[texture_name] = m
	return m


static func _backing(texture_name: String) -> StandardMaterial3D:
	var key := texture_name + "|back"
	if _materials.has(key):
		return _materials[key]
	var m: StandardMaterial3D = _material(texture_name, 0.9).duplicate()
	m.albedo_color = Color(0.16, 0.12, 0.09)
	m.normal_enabled = false
	_materials[key] = m
	return m
