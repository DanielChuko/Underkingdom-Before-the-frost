extends RefCounted
## Static helpers for building greybox geometry in code: boxes, walls with
## door gaps, doors, torches, NPC stand-ins and interactable props.
## Everything is plain primitives so the layout can be iterated quickly and
## later swapped for real art.

const DoorScript := preload("res://scripts/world/door.gd")
const PropScript := preload("res://scripts/world/prop.gd")
const FlickerScript := preload("res://scripts/world/flicker_light.gd")
const HumanoidScript := preload("res://scripts/characters/humanoid.gd")
const PM := preload("res://scripts/world/models.gd")

const WALL_THICKNESS := 0.3
## Render layer carrying the characters, lit by their own fill lights.
const CHARACTER_LAYER := 2

static var _flame_material: StandardMaterial3D
static var _dust_material: StandardMaterial3D
static var _grime_material: StandardMaterial3D
static var _soot_material: StandardMaterial3D
static var _torch_iron_material: StandardMaterial3D


static func mat(color: Color, emission_energy := 0.0, metallic := 0.0, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission_energy
	return m


## A box mesh. With collide=true it is wrapped in a StaticBody3D.
static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, collide := true) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	if not collide:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	body.add_child(mi)
	_add_box_shape(body, size)
	return body


## Invisible collision only.
static func solid(parent: Node, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	parent.add_child(body)
	_add_box_shape(body, size)
	return body


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, material: Material, top_radius := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func sphere(parent: Node, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## An omni light. flicker > 0 makes it a fire light (see flicker_light.gd).
## Lights fade out with distance so many shadowed torches stay cheap.
static func light(parent: Node, pos: Vector3, color: Color, energy: float, light_range: float, shadows := false, flicker := 0.0) -> OmniLight3D:
	var l: OmniLight3D
	if flicker > 0.0:
		var f = FlickerScript.new()
		f.amount = flicker
		l = f
	else:
		l = OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	l.shadow_bias = 0.08
	# Enough normal bias that layered clothing and faces don't shadow
	# themselves into dark blotches.
	l.shadow_normal_bias = 2.5
	l.distance_fade_enabled = true
	l.distance_fade_begin = 28.0
	l.distance_fade_length = 8.0
	l.distance_fade_shadow = 18.0
	parent.add_child(l)
	return l


## Small particle fire (torch flames, braziers, the hearth). size scales it.
static func flame(parent: Node, pos: Vector3, size := 1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = int(14 + 10 * size)
	p.lifetime = 0.5 + 0.15 * size
	var quad := QuadMesh.new()
	quad.size = Vector2(0.17, 0.17) * size
	quad.material = _get_flame_material()
	p.mesh = quad
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.035 * size
	p.direction = Vector3.UP
	p.spread = 14.0
	p.gravity = Vector3(0, 1.3 * size, 0)
	p.initial_velocity_min = 0.12 * size
	p.initial_velocity_max = 0.32 * size
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.25
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.9))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.15))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.55, 1.0))
	grad.set_color(1, Color(0.7, 0.12, 0.02, 0.0))
	grad.add_point(0.35, Color(1.0, 0.5, 0.12, 0.85))
	p.color_ramp = grad
	parent.add_child(p)
	return p


## Slow floating dust specks filling a box (catches torch and window light).
static func dust(parent: Node, center: Vector3, extents: Vector3, amount := 60) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = center
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.012)
	quad.material = _get_dust_material()
	p.mesh = quad
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, -0.005, 0)
	p.initial_velocity_min = 0.01
	p.initial_velocity_max = 0.05
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.95, 0.85, 0.0))
	grad.set_color(1, Color(1, 0.95, 0.85, 0.0))
	grad.add_point(0.5, Color(1, 0.95, 0.85, 0.5))
	p.color_ramp = grad
	parent.add_child(p)
	return p


static func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


static func _get_flame_material() -> StandardMaterial3D:
	if _flame_material == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _soft_dot()
		m.disable_receive_shadows = true
		_flame_material = m
	return _flame_material


static func _get_dust_material() -> StandardMaterial3D:
	if _dust_material == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _soft_dot()
		_dust_material = m
	return _dust_material


## Floor slab (top at y=0) and ceiling slab (bottom at y=height) for a rectangle.
static func floor_and_ceiling(parent: Node, x0: float, x1: float, z0: float, z1: float, height: float, floor_mat: Material, ceiling_mat: Material) -> void:
	var w := absf(x1 - x0)
	var d := absf(z1 - z0)
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	box(parent, Vector3(w, 0.2, d), Vector3(cx, -0.1, cz), floor_mat)
	box(parent, Vector3(w, 0.2, d), Vector3(cx, height + 0.1, cz), ceiling_mat)


## Axis-aligned wall from a to b (XZ coordinates). Each gap is
## [center (absolute x or z along the wall), width, opening height].
static func wall(parent: Node, a: Vector2, b: Vector2, height: float, material: Material, gaps := [], base_y := 0.0) -> void:
	var along_x := absf(a.y - b.y) < 0.001
	var s0: float = minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var s1: float = maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var fixed: float = a.y if along_x else a.x
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(p, q) -> bool: return p[0] < q[0])
	var cursor := s0
	for g in sorted:
		var g0: float = g[0] - g[1] * 0.5
		var g1: float = g[0] + g[1] * 0.5
		_wall_segment(parent, along_x, fixed, cursor, g0, base_y, base_y + height, material, true)
		_wall_segment(parent, along_x, fixed, g0, g1, base_y + g[2], base_y + height, material)
		cursor = g1
	_wall_segment(parent, along_x, fixed, cursor, s1, base_y, base_y + height, material, true)


## A door. `hinge` is the bottom of the hinge edge, `along` points from the hinge
## to the free edge, and `open_into` is the side the door swings towards.
## A double door puts the second hinge at hinge + along * width.
static func door(parent: Node, hinge: Vector3, along: Vector3, open_into: Vector3, width: float, height: float, material: Material, label := "door", double := false) -> Node3D:
	var d = DoorScript.new()
	d.label = label
	parent.add_child(d)
	var trim := mat(Color(0.12, 0.1, 0.09), 0.0, 0.6, 0.5)
	if double:
		_door_leaf(d, hinge, along, open_into, width * 0.5, height, material, trim)
		_door_leaf(d, hinge + along * width, -along, open_into, width * 0.5, height, material, trim)
	else:
		_door_leaf(d, hinge, along, open_into, width, height, material, trim)
	return d


## Wall torch: a riveted iron wall plate with pointed ends, an arm and a
## scrolled brace holding a collar, a tapering wooden torch bound with
## leather strips and an iron ferrule, an open iron cage of glowing coals at
## the top, a particle flame and a flickering light. `pos` is on the wall
## surface; `facing` points out of the wall.
static func torch(parent: Node, pos: Vector3, facing: Vector3, energy := 2.2, light_range := 9.0, shadows := true) -> Node3D:
	var t := Node3D.new()
	t.position = pos
	t.rotation.y = atan2(facing.x, facing.z)
	parent.add_child(t)
	var iron := _torch_iron()
	# Wall plate with pointed ends and rivets.
	box(t, Vector3(0.06, 0.42, 0.016), Vector3(0, -0.03, 0.008), iron, false)
	for y in [0.18, -0.24]:
		var tip := box(t, Vector3(0.043, 0.043, 0.016), Vector3(0, y, 0.008), iron, false)
		tip.rotation.z = PI * 0.25
	for y in [0.13, -0.2]:
		sphere(t, 0.009, Vector3(0, y, 0.018), iron)
	# Arm out to the collar, on a riveted saddle plate.
	box(t, Vector3(0.05, 0.1, 0.018), Vector3(0, 0.0, 0.022), iron, false)
	box(t, Vector3(0.028, 0.03, 0.2), Vector3(0, 0.0, 0.12), iron, false)
	for y in [0.03, -0.03]:
		sphere(t, 0.008, Vector3(0, y, 0.033), iron)
	# Scrolled brace from low on the plate up under the collar, with a curl.
	var prev := Vector3(0, -0.17, 0.02)
	for i in range(1, 8):
		var a := float(i) / 7.0 * PI * 0.5
		var p := Vector3(0, -0.17 + sin(a) * 0.15, 0.02 + (1.0 - cos(a)) * 0.19)
		var seg := box(t, Vector3(0.016, 0.016, prev.distance_to(p) + 0.01), (prev + p) * 0.5, iron, false)
		seg.rotation.x = -atan2(p.y - prev.y, p.z - prev.z)
		prev = p
	var curl := torus_ring(t, Vector3(0, -0.185, 0.04), 0.01, 0.02, iron)
	curl.rotation.z = PI * 0.5

	# The torch, leaning out from the wall, held by the collar.
	var h := Node3D.new()
	h.position = Vector3(0, 0.0, 0.235)
	h.rotation.x = 0.22
	t.add_child(h)
	var collar := torus_ring(h, Vector3.ZERO, 0.027, 0.042, iron)
	collar.scale = Vector3(1.0, 1.6, 1.0)
	var wood := mat(Color(0.33, 0.24, 0.16), 0.0, 0.0, 0.85)
	cylinder(h, 0.021, 0.52, Vector3(0, -0.06, 0), wood, 0.03)
	var strap := mat(Color(0.3, 0.13, 0.09), 0.0, 0.0, 0.7)
	for y in [0.1, -0.17]:
		var w := cylinder(h, 0.029 - (0.2 - y) * 0.01, 0.04, Vector3(0, y, 0), strap)
		w.rotation.z = 0.25
	cylinder(h, 0.025, 0.055, Vector3(0, -0.3, 0), iron, 0.023)
	cylinder(h, 0.002, 0.03, Vector3(0, -0.34, 0), iron, 0.016)
	# Open cage of bars between two rings, full of glowing coals.
	torus_ring(h, Vector3(0, 0.205, 0), 0.04, 0.05, iron)
	torus_ring(h, Vector3(0, 0.335, 0), 0.066, 0.076, iron)
	for i in 6:
		var a := TAU * i / 6.0
		var bar := Node3D.new()
		bar.position = Vector3(cos(a) * 0.058, 0.28, sin(a) * 0.058)
		bar.rotation = Vector3(0, -a, -0.16)
		h.add_child(bar)
		box(bar, Vector3(0.011, 0.18, 0.009), Vector3.ZERO, iron, false)
	var coal := mat(Color(1.0, 0.32, 0.07), 2.6, 0.0, 0.9)
	for c in [Vector3(0.0, 0.245, 0.0), Vector3(0.026, 0.26, 0.012), Vector3(-0.022, 0.255, -0.018), Vector3(0.006, 0.275, -0.026), Vector3(-0.015, 0.27, 0.022)]:
		sphere(h, 0.024, c, coal)
	flame(h, Vector3(0, 0.33, 0), 1.0)
	# Years of smoke have blackened the stone above the flame.
	stain(parent, pos + facing * 0.006 + Vector3(0, 1.25, 0), facing, Vector2(0.8, 1.5), _get_soot_material())
	# Torches burn a little brighter and reach further than the callers ask,
	# so the halls stay readable between them.
	light(t, Vector3(0, 0.5, 0.45), Color(1.0, 0.68, 0.38), energy * 1.3, light_range * 1.15, shadows, 0.2)
	return t


## A ring (torus) lying in the local XZ plane.
static func torus_ring(parent: Node, pos: Vector3, inner: float, outer: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 20
	tm.ring_segments = 8
	mi.mesh = tm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _torch_iron() -> StandardMaterial3D:
	if _torch_iron_material == null:
		_torch_iron_material = mat(Color(0.16, 0.13, 0.11), 0.0, 0.65, 0.62)
	return _torch_iron_material


## Interactable prop with a visible box and matching collision.
static func prop(parent: Node, size: Vector3, pos: Vector3, material: Material, prompt: String, message := "") -> StaticBody3D:
	var p = PropScript.new()
	p.position = pos
	p.prompt = prompt
	p.message = message
	parent.add_child(p)
	if material != null:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = material
		p.add_child(mi)
	_add_box_shape(p, size)
	return p


## A character: an NPC body (script) dressed and animated by the Humanoid rig
## using a look from res://data/characters.json. Faces local -Z.
static func npc(parent: Node, script: Script, display_name: String, pos: Vector3, yaw: float, look_id: String) -> CharacterBody3D:
	var n = script.new()
	n.display_name = display_name
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	var body = HumanoidScript.new()
	body.name = "Body"
	n.add_child(body)
	body.build(look_id)
	n.body = body
	# A soft fill light that only touches the character (render layer 2), so
	# faces and clothing read in the dark halls without lighting up the walls.
	# It sits in front at face height (characters face -Z), so the face is
	# never left in its own shade. The head does not cast shadows, so a helmet
	# brim or hood can't black out the face under a torch.
	for g in body.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).layers = 1 | CHARACTER_LAYER
	if body.head:
		for g in body.head.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fill := OmniLight3D.new()
	fill.name = "CharacterLight"
	fill.position = Vector3(0.25, 1.75, -1.0)
	fill.light_color = Color(1.0, 0.87, 0.72)
	fill.light_energy = 1.3
	fill.light_specular = 0.2
	fill.omni_range = 3.6
	fill.omni_attenuation = 1.0
	fill.light_cull_mask = CHARACTER_LAYER
	fill.shadow_enabled = false
	fill.light_volumetric_fog_energy = 0.0
	n.add_child(fill)

	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.9
	n.add_child(col)
	return n


static func _add_box_shape(body: Node, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)


static func _wall_segment(parent: Node, along_x: bool, fixed: float, s0: float, s1: float, y0: float, y1: float, material: Material, grime := false) -> void:
	if s1 - s0 < 0.01 or y1 - y0 < 0.01:
		return
	var mid := (s0 + s1) * 0.5
	var ymid := (y0 + y1) * 0.5
	if along_x:
		box(parent, Vector3(s1 - s0, y1 - y0, WALL_THICKNESS), Vector3(mid, ymid, fixed), material)
	else:
		box(parent, Vector3(WALL_THICKNESS, y1 - y0, s1 - s0), Vector3(fixed, ymid, mid), material)
	if not grime:
		return
	# Damp and dirt darken the foot of every wall, on both faces.
	var h := minf(0.8, y1 - y0)
	for side in [1.0, -1.0]:
		var normal := Vector3(0, 0, side) if along_x else Vector3(side, 0, 0)
		var centre := Vector3(mid, y0 + h * 0.5, fixed) if along_x else Vector3(fixed, y0 + h * 0.5, mid)
		stain(parent, centre + normal * (WALL_THICKNESS * 0.5 + 0.004), normal, Vector2(s1 - s0, h), _get_grime_material())


## A flat stain (soot, damp, grime) laid on a wall; normal points out of the wall.
static func stain(parent: Node, centre: Vector3, normal: Vector3, size: Vector2, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = centre
	mi.rotation.y = atan2(normal.x, normal.z)
	parent.add_child(mi)
	return mi


static func _stain_material(texture: Texture2D, strength: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.02, 0.015, 0.01, strength)
	m.albedo_texture = texture
	m.disable_receive_shadows = true
	return m


static func _get_grime_material() -> StandardMaterial3D:
	if _grime_material == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 1))
		g.add_point(0.55, Color(1, 1, 1, 0.3))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(0, 1)
		t.width = 4
		t.height = 64
		_grime_material = _stain_material(t, 0.55)
	return _grime_material


static func _get_soot_material() -> StandardMaterial3D:
	if _soot_material == null:
		# A plume that starts above the flame and widens and fades upwards.
		var w := 48
		var h := 96
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			var t := 1.0 - float(y) / (h - 1)
			var rise := smoothstep(0.0, 0.15, t) * pow(1.0 - t, 1.3)
			var sigma := 0.12 + 0.22 * t
			for x in w:
				var xn := (float(x) / (w - 1) - 0.5) / sigma
				img.set_pixel(x, y, Color(1, 1, 1, clampf(rise * exp(-0.5 * xn * xn) * 1.6, 0.0, 1.0)))
		_soot_material = _stain_material(ImageTexture.create_from_image(img), 0.75)
	return _soot_material


static func _door_leaf(door_node, hinge: Vector3, along: Vector3, open_into: Vector3, width: float, height: float, material: Material, trim: Material) -> void:
	var pivot := Node3D.new()
	pivot.position = hinge
	# Rotate so the leaf's local +X points along `along`.
	var closed := atan2(-along.z, along.x)
	pivot.rotation.y = closed
	door_node.add_child(pivot)
	# The supplied oak door (single leaves) or gate leaf (wide leaves of
	# double doors), stretched to the opening, with a collision box.
	var gate := width > 1.25
	var native := Vector2(1.8, 3.25) if gate else Vector2(1.05, 2.15)
	var leaf := PM.place(pivot, "gate_left" if gate else "door_oak", Vector3.ZERO, Vector3.ZERO, Vector3(width / native.x, height / native.y, 0.45 if gate else 0.5))
	if leaf != null:
		solid(pivot, Vector3(width - 0.04, height, 0.12), Vector3(width * 0.5, height * 0.5, 0))
	else:
		box(pivot, Vector3(width - 0.04, height, 0.08), Vector3(width * 0.5, height * 0.5, 0), material)
		# Iron bands and a handle so doors read as doors.
		box(pivot, Vector3(width - 0.1, 0.08, 0.1), Vector3(width * 0.5, height * 0.25, 0), trim, false)
		box(pivot, Vector3(width - 0.1, 0.08, 0.1), Vector3(width * 0.5, height * 0.75, 0), trim, false)
		box(pivot, Vector3(0.06, 0.2, 0.16), Vector3(width - 0.15, height * 0.45, 0), trim, false)
	var plus := closed + PI * 0.5
	var dir_plus := Vector3(cos(plus), 0.0, -sin(plus))
	var open := plus if dir_plus.dot(open_into) > 0.0 else closed - PI * 0.5
	door_node.leaves.append({"node": pivot, "closed": closed, "open": open})
