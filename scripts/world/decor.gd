extends RefCounted
## Set dressing and architectural detail built from primitives and the
## generated surface materials: door frames, pillars, beams, furniture,
## barrels, crates, sacks, shields, rugs and shelves.

const G := preload("res://scripts/world/greybox.gd")
const S := preload("res://scripts/world/surfaces.gd")
const F := preload("res://scripts/world/furniture.gd")


static func stone() -> Material:
	return S.get_material("stone_wall", Color(0.68, 0.66, 0.63), 2.4)


static func stone_trim() -> Material:
	return S.get_material("stone_wall", Color(0.5, 0.48, 0.46), 1.2)


static func wood() -> Material:
	return S.get_material("wood_floor", Color.WHITE, 1.4, false)


static func wood_dark() -> Material:
	return S.get_material("wood_dark", Color.WHITE, 1.4, false)


static func iron() -> Material:
	return G.mat(Color(0.13, 0.12, 0.12), 0.0, 0.75, 0.45)


## Stone frame around a doorway. center = bottom middle of the opening on the
## wall line; along = unit vector along the wall; normal = towards the viewer.
## Both faces of the wall get a frame when two_sided is true.
static func door_frame(parent: Node, center: Vector3, along: Vector3, normal: Vector3, width: float, height: float, two_sided := true) -> void:
	var sides := [1.0, -1.0] if two_sided else [1.0]
	for side in sides:
		var out: Vector3 = normal * side * 0.17
		var depth := Vector3(absf(normal.x), 0, absf(normal.z)) * 0.08
		var across := Vector3(absf(along.x), 0, absf(along.z))
		var jamb := across * 0.22 + depth + Vector3(0, height + 0.25, 0)
		for s in [-1.0, 1.0]:
			G.box(parent, jamb, center + out + along * s * (width * 0.5 + 0.11) + Vector3(0, (height + 0.25) * 0.5, 0), stone_trim(), false)
		G.box(parent, across * (width + 0.44) + depth + Vector3(0, 0.25, 0), center + out + Vector3(0, height + 0.125, 0), stone_trim(), false)
		# Keystone.
		G.box(parent, across * 0.3 + depth * 1.3 + Vector3(0, 0.36, 0), center + out + Vector3(0, height + 0.18, 0), stone_trim(), false)


## Square stone pillar with a base and capital, floor to ceiling.
static func pillar(parent: Node, pos: Vector3, height: float, width := 0.8) -> void:
	G.box(parent, Vector3(width, height, width), pos + Vector3(0, height * 0.5, 0), stone())
	G.box(parent, Vector3(width + 0.25, 0.35, width + 0.25), pos + Vector3(0, 0.175, 0), stone_trim(), false)
	G.box(parent, Vector3(width + 0.25, 0.3, width + 0.25), pos + Vector3(0, height - 0.15, 0), stone_trim(), false)


## Ceiling beam across a corridor or room (axis "x" or "z").
static func beam(parent: Node, center: Vector3, length: float, axis := "x") -> void:
	var size := Vector3(length, 0.28, 0.24) if axis == "x" else Vector3(0.24, 0.28, length)
	G.box(parent, size, center, wood_dark(), false)


static func barrel(parent: Node, pos: Vector3, height := 0.9) -> void:
	var body := G.cylinder(parent, 0.32, height, pos + Vector3(0, height * 0.5, 0), wood(), 0.29)
	for y in [0.15, height - 0.15]:
		G.cylinder(parent, 0.325, 0.05, pos + Vector3(0, y, 0), iron(), 0.315)
	G.cylinder(parent, 0.34, 0.05, pos + Vector3(0, height * 0.5, 0), iron())
	G.solid(parent, Vector3(0.62, height, 0.62), pos + Vector3(0, height * 0.5, 0))


static func crate(parent: Node, pos: Vector3, size := 0.7, yaw := 0.0) -> void:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = yaw
	parent.add_child(c)
	G.box(c, Vector3.ONE * size, Vector3(0, size * 0.5, 0), wood())
	var t := 0.06
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			G.box(c, Vector3(t, size + 0.01, t), Vector3(x * (size * 0.5 - t * 0.4), size * 0.5, z * (size * 0.5 - t * 0.4)), wood_dark(), false)
	for y in [t * 0.5, size - t * 0.5]:
		G.box(c, Vector3(size + 0.01, t, t), Vector3(0, y, size * 0.5 - t * 0.4), wood_dark(), false)
		G.box(c, Vector3(size + 0.01, t, t), Vector3(0, y, -size * 0.5 + t * 0.4), wood_dark(), false)


static func sack(parent: Node, pos: Vector3, color := Color(0.75, 0.66, 0.48)) -> void:
	var s := G.sphere(parent, 0.28, pos + Vector3(0, 0.26, 0), S.get_material("cloth", color, 0.6))
	s.scale = Vector3(1.0, 0.95, 0.8)
	G.cylinder(parent, 0.07, 0.12, pos + Vector3(0, 0.56, 0), S.get_material("cloth", color * 0.8, 0.6), 0.04)


## Round wall shield; normal points out of the wall.
static func shield(parent: Node, pos: Vector3, normal: Vector3, color: Color) -> void:
	var disc := G.cylinder(parent, 0.38, 0.05, pos + normal * 0.03, S.get_material("wood_floor", color, 1.0, false))
	disc.rotation = Vector3(PI * 0.5 if absf(normal.z) > 0.5 else 0.0, 0, PI * 0.5 if absf(normal.x) > 0.5 else 0.0)
	G.sphere(parent, 0.08, pos + normal * 0.07, iron())
	var rim := G.cylinder(parent, 0.4, 0.03, pos + normal * 0.02, iron())
	rim.rotation = disc.rotation


static func rug(parent: Node, center: Vector3, size: Vector2, color: Color, border: Color) -> void:
	G.box(parent, Vector3(size.x, 0.02, size.y), center + Vector3(0, 0.01, 0), S.get_material("cloth", border, 0.8), false)
	G.box(parent, Vector3(size.x - 0.2, 0.025, size.y - 0.2), center + Vector3(0, 0.012, 0), S.get_material("cloth", color, 0.8), false)


## Trestle table, long axis along whichever of size.x / size.z is larger.
## The top surface is at center.y + size.y.
static func table(parent: Node, center: Vector3, size: Vector3, material: Material = null) -> void:
	if size.z > size.x:
		F.trestle_table(parent, center, Vector3(size.z, size.y, size.x), PI * 0.5, material)
	else:
		F.trestle_table(parent, center, size, 0.0, material)


static func bench(parent: Node, center: Vector3, length: float, axis := "z") -> void:
	F.bench(parent, center, length, PI * 0.5 if axis == "z" else 0.0)


## Wall shelf with books or jars. normal points out of the wall.
static func shelf(parent: Node, pos: Vector3, normal: Vector3, length := 1.2, rows := 3, rng_seed := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var along := Vector3(-normal.z, 0, normal.x)
	var depth := 0.3
	var size_along := Vector3(absf(along.x), 0, absf(along.z))
	var size_depth := Vector3(absf(normal.x), 0, absf(normal.z))
	var colors := [Color(0.5, 0.12, 0.1), Color(0.15, 0.25, 0.45), Color(0.2, 0.35, 0.2), Color(0.55, 0.45, 0.25), Color(0.3, 0.18, 0.12)]
	for r in rows:
		var y := 0.6 + r * 0.45
		G.box(parent, size_along * length + size_depth * depth + Vector3(0, 0.04, 0), pos + normal * depth * 0.5 + Vector3(0, y, 0), wood_dark(), false)
		var x := -length * 0.5 + 0.06
		while x < length * 0.5 - 0.08:
			var w := rng.randf_range(0.035, 0.07)
			var h := rng.randf_range(0.2, 0.32)
			var book := G.box(parent, size_along * w + size_depth * 0.2 + Vector3(0, h, 0), pos + normal * 0.14 + along * (x + w * 0.5) + Vector3(0, y + 0.02 + h * 0.5, 0), G.mat(colors[rng.randi() % colors.size()]), false)
			if rng.randf() < 0.1:
				book.rotation = Vector3(0, 0, 0.25) if absf(along.x) > 0.5 else Vector3(0.25, 0, 0)
			x += w + 0.005
			if rng.randf() < 0.08:
				x += 0.15
	for s in [-1.0, 1.0]:
		G.box(parent, size_along * 0.04 + size_depth * depth + Vector3(0, rows * 0.45 + 0.1, 0), pos + normal * depth * 0.5 + along * s * length * 0.5 + Vector3(0, 0.55 + rows * 0.225, 0), wood_dark(), false)


## Hanging iron chandelier with candle flames and one warm light.
static func chandelier(parent: Node, pos: Vector3, ceiling_y: float) -> void:
	G.box(parent, Vector3(0.03, ceiling_y - pos.y, 0.03), Vector3(pos.x, (ceiling_y + pos.y) * 0.5, pos.z), iron(), false)
	var ring := G.cylinder(parent, 0.7, 0.06, pos, iron())
	for i in 6:
		var a := TAU * i / 6.0
		var p := pos + Vector3(cos(a) * 0.65, 0.12, sin(a) * 0.65)
		G.cylinder(parent, 0.03, 0.16, p, G.mat(Color(0.93, 0.9, 0.8)))
		G.flame(parent, p + Vector3(0, 0.11, 0), 0.35)
	G.light(parent, pos + Vector3(0, -0.3, 0), Color(1.0, 0.72, 0.45), 2.2, 15.0, true, 0.08)
