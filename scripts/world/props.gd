extends RefCounted
## Small, detailed props built from rounded primitives (spheres, capsules,
## cylinders, cones and tori): food, tableware, kitchen tools and desk items.
## Every function takes a parent and a position on the surface the item rests on.

const G := preload("res://scripts/world/greybox.gd")
const S := preload("res://scripts/world/surfaces.gd")


static func m(color: Color, roughness := 0.6, metallic := 0.0) -> StandardMaterial3D:
	return G.mat(color, 0.0, metallic, roughness)


static func ellipsoid(parent: Node, pos: Vector3, radii: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 20
	sm.rings = 12
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	mi.scale = radii
	parent.add_child(mi)
	return mi


static func torus(parent: Node, pos: Vector3, inner: float, outer: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 24
	tm.ring_segments = 8
	mi.mesh = tm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func capsule(parent: Node, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func pivot(parent: Node, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation = rot
	parent.add_child(n)
	return n


# --- Food -------------------------------------------------------------------------

static func apple(parent: Node, pos: Vector3, color := Color(0.72, 0.1, 0.08)) -> void:
	ellipsoid(parent, pos + Vector3(0, 0.036, 0), Vector3(0.042, 0.038, 0.042), m(color, 0.35))
	G.cylinder(parent, 0.003, 0.02, pos + Vector3(0, 0.08, 0), m(Color(0.3, 0.2, 0.1)))
	var leaf := ellipsoid(parent, pos + Vector3(0.012, 0.082, 0), Vector3(0.016, 0.003, 0.008), m(Color(0.25, 0.5, 0.15)))
	leaf.rotation.z = 0.4


static func pear(parent: Node, pos: Vector3) -> void:
	var c := m(Color(0.65, 0.68, 0.2), 0.4)
	ellipsoid(parent, pos + Vector3(0, 0.035, 0), Vector3(0.037, 0.035, 0.037), c)
	ellipsoid(parent, pos + Vector3(0, 0.08, 0), Vector3(0.022, 0.03, 0.022), c)
	G.cylinder(parent, 0.003, 0.02, pos + Vector3(0, 0.115, 0), m(Color(0.3, 0.2, 0.1)))


static func carrot(parent: Node, pos: Vector3, yaw := 0.0) -> void:
	var p := pivot(parent, pos + Vector3(0, 0.02, 0), Vector3(0, yaw, PI * 0.5))
	G.cylinder(p, 0.0, 0.15, Vector3.ZERO, m(Color(0.92, 0.45, 0.08), 0.5), 0.02)
	for i in 3:
		var top := G.cylinder(p, 0.0, 0.09, Vector3(0, 0.11, 0), m(Color(0.25, 0.55, 0.15)), 0.004)
		top.rotation = Vector3((i - 1) * 0.35, 0, 0)


static func cabbage(parent: Node, pos: Vector3) -> void:
	ellipsoid(parent, pos + Vector3(0, 0.07, 0), Vector3(0.075, 0.07, 0.075), m(Color(0.62, 0.78, 0.42), 0.5))
	for i in 5:
		var a := TAU * i / 5.0
		var leaf := ellipsoid(parent, pos + Vector3(cos(a) * 0.05, 0.065, sin(a) * 0.05), Vector3(0.06, 0.07, 0.025), m(Color(0.42, 0.62, 0.3), 0.5))
		leaf.rotation = Vector3(0, -a + PI * 0.5, 0.25)


static func onion(parent: Node, pos: Vector3) -> void:
	ellipsoid(parent, pos + Vector3(0, 0.035, 0), Vector3(0.04, 0.035, 0.04), m(Color(0.78, 0.55, 0.3), 0.35))
	G.cylinder(parent, 0.012, 0.03, pos + Vector3(0, 0.075, 0), m(Color(0.7, 0.5, 0.28)), 0.0)


static func potato(parent: Node, pos: Vector3, yaw := 0.0) -> void:
	var p := ellipsoid(parent, pos + Vector3(0, 0.025, 0), Vector3(0.048, 0.03, 0.036), m(Color(0.62, 0.46, 0.28), 0.9))
	p.rotation.y = yaw


static func bread(parent: Node, pos: Vector3, yaw := 0.0) -> void:
	var p := pivot(parent, pos, Vector3(0, yaw, 0))
	var crust := m(Color(0.72, 0.45, 0.2), 0.75)
	var loaf := ellipsoid(p, Vector3(0, 0.05, 0), Vector3(0.12, 0.055, 0.065), crust)
	loaf.rotation.y = 0.0
	for x in [-0.06, 0.0, 0.06]:
		var cut := ellipsoid(p, Vector3(x, 0.1, 0), Vector3(0.008, 0.006, 0.045), m(Color(0.92, 0.8, 0.55), 0.8))
		cut.rotation.y = 0.5


static func cheese(parent: Node, pos: Vector3) -> void:
	G.cylinder(parent, 0.11, 0.08, pos + Vector3(0, 0.04, 0), m(Color(0.95, 0.78, 0.3), 0.5))
	var rind := torus(parent, pos + Vector3(0, 0.04, 0), 0.1, 0.115, m(Color(0.85, 0.6, 0.2), 0.6))
	rind.scale = Vector3(1, 2.6, 1)


static func sausages(parent: Node, top: Vector3, count := 4) -> void:
	var skin := m(Color(0.55, 0.22, 0.16), 0.45)
	for i in count:
		var p := top + Vector3((i - count * 0.5) * 0.06, 0, 0)
		G.cylinder(parent, 0.003, 0.06, p + Vector3(0, -0.03, 0), m(Color(0.8, 0.75, 0.6)))
		var s := capsule(parent, p + Vector3(0, -0.14, 0), 0.022, 0.18, skin)
		s.rotation.z = (i % 2 - 0.5) * 0.12


static func ham(parent: Node, top: Vector3) -> void:
	G.cylinder(parent, 0.003, 0.1, top + Vector3(0, -0.05, 0), m(Color(0.8, 0.75, 0.6)))
	var h := ellipsoid(parent, top + Vector3(0, -0.24, 0), Vector3(0.1, 0.15, 0.09), m(Color(0.6, 0.28, 0.18), 0.5))
	h.rotation.z = 0.1
	G.cylinder(parent, 0.018, 0.07, top + Vector3(0, -0.1, 0), m(Color(0.92, 0.88, 0.78), 0.5))


## A roast joint with a bone and a fat cap, lying on a surface.
static func roast(parent: Node, pos: Vector3, yaw := 0.0) -> void:
	var p := pivot(parent, pos, Vector3(0, yaw, 0))
	ellipsoid(p, Vector3(0, 0.065, 0), Vector3(0.15, 0.07, 0.1), m(Color(0.55, 0.2, 0.12), 0.45))
	ellipsoid(p, Vector3(-0.02, 0.1, 0), Vector3(0.12, 0.04, 0.085), m(Color(0.72, 0.45, 0.3), 0.4))
	var cut := ellipsoid(p, Vector3(0.13, 0.065, 0), Vector3(0.025, 0.06, 0.085), m(Color(0.8, 0.35, 0.3), 0.35))
	cut.rotation.z = 0.1
	var bone := G.cylinder(p, 0.017, 0.14, Vector3(-0.19, 0.07, 0), m(Color(0.93, 0.9, 0.82), 0.5))
	bone.rotation.z = PI * 0.5
	for z in [-0.016, 0.016]:
		G.sphere(p, 0.022, Vector3(-0.26, 0.07, z), m(Color(0.93, 0.9, 0.82), 0.5))


# --- Tableware and tools ------------------------------------------------------------

## A kitchen knife stuck point-first into a surface at `pos`.
static func knife_stuck(parent: Node, pos: Vector3, yaw := 0.0, tilt := 0.25) -> void:
	var p := pivot(parent, pos, Vector3(0, yaw, tilt))
	var steel := m(Color(0.78, 0.8, 0.84), 0.25, 0.9)
	var blade := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.04, 0.2, 0.004)
	pm.left_to_right = 0.0
	blade.mesh = pm
	blade.material_override = steel
	blade.position = Vector3(0, 0.08, 0)
	blade.rotation.z = PI
	p.add_child(blade)
	G.box(p, Vector3(0.006, 0.18, 0.006), Vector3(0.018, 0.09, 0), steel, false)
	G.box(p, Vector3(0.065, 0.012, 0.018), Vector3(-0.005, 0.186, 0), m(Color(0.2, 0.18, 0.16), 0.4, 0.7), false)
	G.cylinder(p, 0.013, 0.1, Vector3(-0.005, 0.245, 0), S.get_material("wood_dark", Color.WHITE, 0.3, false), 0.011)
	G.sphere(p, 0.015, Vector3(-0.005, 0.3, 0), m(Color(0.2, 0.18, 0.16), 0.4, 0.7))


static func cutting_board(parent: Node, pos: Vector3, yaw := 0.0) -> void:
	var p := pivot(parent, pos, Vector3(0, yaw, 0))
	var wood := S.get_material("wood_floor", Color(1.05, 1.0, 0.95), 0.6, false)
	G.box(p, Vector3(0.5, 0.03, 0.32), Vector3(0, 0.015, 0), wood, false)
	G.cylinder(p, 0.16, 0.03, Vector3(0.25, 0.015, 0), wood)


static func plate(parent: Node, pos: Vector3, color := Color(0.6, 0.6, 0.62)) -> void:
	var mt := m(color, 0.35, 0.6)
	G.cylinder(parent, 0.11, 0.012, pos + Vector3(0, 0.006, 0), mt)
	var rim := torus(parent, pos + Vector3(0, 0.014, 0), 0.105, 0.125, mt)
	rim.scale = Vector3(1, 0.5, 1)


static func goblet(parent: Node, pos: Vector3, color := Color(0.85, 0.65, 0.25)) -> void:
	var mt := m(color, 0.3, 0.9)
	G.cylinder(parent, 0.032, 0.008, pos + Vector3(0, 0.004, 0), mt)
	G.cylinder(parent, 0.007, 0.06, pos + Vector3(0, 0.035, 0), mt)
	G.cylinder(parent, 0.018, 0.07, pos + Vector3(0, 0.1, 0), mt, 0.036)
	G.cylinder(parent, 0.031, 0.005, pos + Vector3(0, 0.133, 0), m(Color(0.35, 0.05, 0.08), 0.1))


static func jug(parent: Node, pos: Vector3, color := Color(0.62, 0.42, 0.3), yaw := 0.0) -> void:
	var p := pivot(parent, pos, Vector3(0, yaw, 0))
	var clay := m(color, 0.55)
	ellipsoid(p, Vector3(0, 0.09, 0), Vector3(0.075, 0.09, 0.075), clay)
	G.cylinder(p, 0.045, 0.07, Vector3(0, 0.19, 0), clay, 0.04)
	torus(p, Vector3(0, 0.225, 0), 0.036, 0.05, clay)
	var handle := torus(p, Vector3(0.075, 0.14, 0), 0.035, 0.05, clay)
	handle.rotation.x = PI * 0.5


static func bowl(parent: Node, pos: Vector3, radius := 0.12, color := Color(0.55, 0.38, 0.24)) -> void:
	var wood := m(color, 0.6)
	G.cylinder(parent, radius * 0.6, radius * 0.5, pos + Vector3(0, radius * 0.25, 0), wood, radius)
	var rim := torus(parent, pos + Vector3(0, radius * 0.5, 0), radius * 0.9, radius * 1.05, wood)
	rim.scale = Vector3(1, 0.6, 1)
	G.cylinder(parent, radius * 0.88, 0.005, pos + Vector3(0, radius * 0.4, 0), m(color.darkened(0.4), 0.8))


## Wicker basket; returns the height of its rim so callers can fill it.
static func basket(parent: Node, pos: Vector3, radius := 0.16, height := 0.12) -> float:
	var wicker := S.get_material("wood_floor", Color(1.2, 1.05, 0.75), 0.18, false)
	G.cylinder(parent, radius * 0.85, height, pos + Vector3(0, height * 0.5, 0), wicker, radius)
	torus(parent, pos + Vector3(0, height, 0), radius * 0.92, radius * 1.06, wicker)
	G.cylinder(parent, radius * 0.95, 0.005, pos + Vector3(0, height * 0.75, 0), m(Color(0.2, 0.14, 0.08), 0.9))
	return height * 0.75


static func cooking_pot(parent: Node, pos: Vector3, radius := 0.26) -> void:
	var iron := m(Color(0.1, 0.1, 0.1), 0.5, 0.7)
	ellipsoid(parent, pos + Vector3(0, radius * 0.75, 0), Vector3(radius, radius * 0.8, radius), iron)
	torus(parent, pos + Vector3(0, radius * 1.4, 0), radius * 0.78, radius * 0.92, iron)
	G.cylinder(parent, radius * 0.8, 0.01, pos + Vector3(0, radius * 1.32, 0), m(Color(0.45, 0.28, 0.12), 0.2))
	var bail := torus(parent, pos + Vector3(0, radius * 1.4, 0), radius * 0.86, radius * 0.9, iron)
	bail.rotation.x = PI * 0.5


static func pan(parent: Node, pos: Vector3, normal: Vector3) -> void:
	# Hangs flat against a wall; normal points out of the wall.
	var p := pivot(parent, pos, Vector3(0, atan2(normal.x, normal.z), 0))
	var iron := m(Color(0.12, 0.12, 0.12), 0.45, 0.75)
	var disc := G.cylinder(p, 0.13, 0.03, Vector3(0, 0, 0.02), iron)
	disc.rotation.x = PI * 0.5
	G.box(p, Vector3(0.025, 0.22, 0.012), Vector3(0, 0.22, 0.01), iron, false)
	G.sphere(p, 0.012, Vector3(0, 0.34, 0.0), iron)


static func ladle(parent: Node, top: Vector3) -> void:
	var wood := S.get_material("wood_floor", Color.WHITE, 0.4, false)
	G.cylinder(parent, 0.008, 0.32, top + Vector3(0, -0.16, 0), wood)
	ellipsoid(parent, top + Vector3(0, -0.34, 0), Vector3(0.045, 0.03, 0.045), wood)


static func herb_bundle(parent: Node, top: Vector3, color := Color(0.35, 0.5, 0.22)) -> void:
	G.cylinder(parent, 0.003, 0.12, top + Vector3(0, -0.06, 0), m(Color(0.75, 0.68, 0.5)))
	G.cylinder(parent, 0.018, 0.02, top + Vector3(0, -0.13, 0), m(Color(0.6, 0.5, 0.3)))
	for i in 7:
		var a := TAU * i / 7.0
		var stalk := G.cylinder(parent, 0.012, 0.22, top + Vector3(cos(a) * 0.025, -0.25, sin(a) * 0.025), m(color.lightened(0.1 * (i % 3)), 0.8), 0.003)
		stalk.rotation = Vector3(sin(a) * 0.2, 0, -cos(a) * 0.2)


## A stack of split logs lying along X.
static func firewood(parent: Node, pos: Vector3, rows := 3) -> void:
	var bark := S.get_material("wood_dark", Color(0.8, 0.75, 0.7), 0.5, false)
	var end_grain := m(Color(0.72, 0.55, 0.35), 0.8)
	var r := 0.065
	for row in rows:
		var count := rows + 1 - row
		for i in count:
			var c := pos + Vector3(0, r + row * r * 1.75, (i - (count - 1) * 0.5) * r * 2.05)
			var piece := G.cylinder(parent, r, 0.55, c, bark)
			piece.rotation.z = PI * 0.5
			for sx in [-0.276, 0.276]:
				var face := G.cylinder(parent, r * 0.88, 0.005, c + Vector3(sx, 0, 0), end_grain)
				face.rotation.z = PI * 0.5


static func bucket(parent: Node, pos: Vector3) -> void:
	var wood := S.get_material("wood_floor", Color.WHITE, 0.5, false)
	var iron := m(Color(0.15, 0.14, 0.13), 0.45, 0.7)
	G.cylinder(parent, 0.13, 0.3, pos + Vector3(0, 0.15, 0), wood, 0.16)
	for y in [0.06, 0.24]:
		var band := torus(parent, pos + Vector3(0, y, 0), 0.135 + y * 0.1, 0.155 + y * 0.1, iron)
		band.scale = Vector3(1, 0.5, 1)
	G.cylinder(parent, 0.15, 0.005, pos + Vector3(0, 0.26, 0), m(Color(0.25, 0.32, 0.35), 0.05))
	var handle := torus(parent, pos + Vector3(0, 0.3, 0), 0.15, 0.16, iron)
	handle.rotation.x = PI * 0.5


static func candle_holder(parent: Node, pos: Vector3) -> void:
	var brass := m(Color(0.8, 0.6, 0.3), 0.3, 0.9)
	G.cylinder(parent, 0.06, 0.012, pos + Vector3(0, 0.006, 0), brass)
	var dish_rim := torus(parent, pos + Vector3(0, 0.014, 0), 0.05, 0.065, brass)
	dish_rim.scale = Vector3(1, 0.5, 1)
	var handle := torus(parent, pos + Vector3(0.07, 0.03, 0), 0.015, 0.024, brass)
	handle.rotation.x = PI * 0.5
	G.cylinder(parent, 0.022, 0.13, pos + Vector3(0, 0.075, 0), m(Color(0.93, 0.9, 0.8), 0.5))
	ellipsoid(parent, pos + Vector3(0.018, 0.12, 0), Vector3(0.008, 0.02, 0.008), m(Color(0.93, 0.9, 0.8), 0.5))
	G.flame(parent, pos + Vector3(0, 0.155, 0), 0.28)


static func inkwell_and_quill(parent: Node, pos: Vector3) -> void:
	G.cylinder(parent, 0.03, 0.045, pos + Vector3(0, 0.022, 0), m(Color(0.08, 0.08, 0.1), 0.15), 0.022)
	var q := pivot(parent, pos + Vector3(0, 0.04, 0), Vector3(0.0, 0.3, -0.45))
	G.cylinder(q, 0.003, 0.22, Vector3(0, 0.1, 0), m(Color(0.9, 0.88, 0.8)))
	ellipsoid(q, Vector3(0.008, 0.15, 0), Vector3(0.016, 0.07, 0.002), m(Color(0.95, 0.94, 0.9), 0.8))


static func book_stack(parent: Node, pos: Vector3, count := 3) -> void:
	var colors := [Color(0.45, 0.12, 0.1), Color(0.15, 0.22, 0.4), Color(0.25, 0.32, 0.18)]
	var y := 0.0
	for i in count:
		var p := pivot(parent, pos + Vector3(0, y, 0), Vector3(0, (i - 1) * 0.2, 0))
		var h := 0.035 + 0.01 * (i % 2)
		G.box(p, Vector3(0.2, h, 0.15), Vector3(0, h * 0.5, 0), m(colors[i % colors.size()], 0.7), false)
		G.box(p, Vector3(0.19, h * 0.8, 0.152), Vector3(0.006, h * 0.5, 0), m(Color(0.92, 0.88, 0.76), 0.9), false)
		y += h


## A flower in a clay pot: curved stem, leaves and a ring of petals.
## wilt 0 = full bloom, 1 = withered (for later acts).
static func potted_flower(parent: Node, pos: Vector3, wilt := 0.0) -> void:
	var clay := m(Color(0.7, 0.38, 0.24), 0.8)
	G.cylinder(parent, 0.075, 0.15, pos + Vector3(0, 0.075, 0), clay, 0.1)
	torus(parent, pos + Vector3(0, 0.15, 0), 0.092, 0.112, clay)
	G.cylinder(parent, 0.092, 0.005, pos + Vector3(0, 0.14, 0), m(Color(0.22, 0.15, 0.1), 0.95))
	var green := m(Color(0.25, 0.55, 0.2).lerp(Color(0.45, 0.38, 0.2), wilt), 0.6)
	var stem := pivot(parent, pos + Vector3(0, 0.14, 0))
	var seg_len := 0.09
	var joint := stem
	for i in 3:
		var seg := pivot(joint, Vector3(0, 0.0 if i == 0 else seg_len, 0), Vector3(0.12 + wilt * 0.5, 0, 0.06))
		G.cylinder(seg, 0.006, seg_len, Vector3(0, seg_len * 0.5, 0), green, 0.005)
		joint = seg
	for side in [-1.0, 1.0]:
		var leaf := ellipsoid(stem, Vector3(side * 0.03, 0.07, 0), Vector3(0.035, 0.006, 0.014), green)
		leaf.rotation.z = side * (0.5 + wilt * 0.6)
	var head := pivot(joint, Vector3(0, seg_len, 0))
	var petal_col := Color(0.95, 0.42, 0.62).lerp(Color(0.45, 0.3, 0.25), wilt)
	G.sphere(head, 0.016, Vector3(0, 0.01, 0), m(Color(0.98, 0.8, 0.2), 0.5))
	for i in 7:
		var a := TAU * i / 7.0
		var petal := ellipsoid(head, Vector3(cos(a) * 0.028, 0.008, sin(a) * 0.028), Vector3(0.026, 0.005, 0.014), m(petal_col, 0.5))
		petal.rotation = Vector3(0, -a, 0.35 + wilt * 0.9)
