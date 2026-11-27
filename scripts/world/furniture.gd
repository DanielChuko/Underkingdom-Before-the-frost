extends RefCounted
## Furniture built the way a medieval joiner would: boards and posts with
## chamfered edges, turned legs, pegged rails, trestles with wedged stretchers,
## iron-strapped chests, and soft goods (straw ticks, bolsters, wool blankets,
## fur throws) that sag and drape instead of being boxes.
##
## Every piece is built in its own local frame and placed with a position and a
## yaw. Collision is a simple solid block per piece.

const G := preload("res://scripts/world/greybox.gd")
const S := preload("res://scripts/world/surfaces.gd")
const D := preload("res://scripts/world/decor.gd")
const M := preload("res://scripts/characters/mesh_lib.gd")

static var _two_sided: Dictionary = {}


# --- Bed ------------------------------------------------------------------------------

## A box bed with turned posts, a boarded headboard, a lumpy straw tick, linen,
## a bolster, a wool blanket turned down at the head and a fur at the foot.
## pos: centre of the footprint on the floor. The head end is local -X.
static func bed(parent: Node, pos: Vector3, yaw := 0.0, length := 2.0, width := 1.1, blanket := Color(0.3, 0.33, 0.4)) -> Node3D:
	var n := _node(parent, pos, yaw)
	var oak := D.wood_dark()
	var hx := length * 0.5
	var hz := width * 0.5
	# Posts: tall at the head, short at the foot.
	for x in [-1.0, 1.0]:
		var h := 1.05 if x < 0.0 else 0.72
		for z in [-1.0, 1.0]:
			_post(n, Vector3(x * (hx - 0.04), 0, z * (hz - 0.04)), h, 0.042, oak)
	# Rails, pegged into the posts.
	for z in [-1.0, 1.0]:
		_b(n, Vector3(length - 0.1, 0.17, 0.055), Vector3(0, 0.3, z * (hz - 0.04)), oak)
		for x in [-1.0, 1.0]:
			_b(n, Vector3(0.022, 0.022, 0.07), Vector3(x * (hx - 0.04), 0.27, z * (hz - 0.04)), oak, 0.004)
	for x in [-1.0, 1.0]:
		_b(n, Vector3(0.055, 0.17, width - 0.1), Vector3(x * (hx - 0.04), 0.3, 0), oak)
	# Headboard: three upright boards framed by rails.
	_b(n, Vector3(0.05, 0.09, width - 0.08), Vector3(-hx + 0.04, 0.98, 0), oak)
	_b(n, Vector3(0.05, 0.07, width - 0.08), Vector3(-hx + 0.04, 0.5, 0), oak)
	var boards := 3
	var bw := (width - 0.1) / boards
	for i in boards:
		var z := -hz + 0.05 + bw * (i + 0.5)
		_b(n, Vector3(0.03, 0.42, bw - 0.012), Vector3(-hx + 0.04, 0.74, z), D.wood(), 0.006)
	# Footboard rail.
	_b(n, Vector3(0.05, 0.08, width - 0.08), Vector3(hx - 0.04, 0.62, 0), oak)
	# Rope or slat bed base, then the soft goods.
	for i in 7:
		_b(n, Vector3(0.08, 0.025, width - 0.12), Vector3(-hx + 0.2 + i * (length - 0.4) / 6.0, 0.37, 0), D.wood(), 0.005)
	var tick_size := Vector3(length - 0.14, 0.2, width - 0.12)
	var linen := _cloth("cloth", Color(0.8, 0.77, 0.69), 0.5)
	_mesh(n, M.cushion(tick_size, 0.3, 0.035, 0.015), Vector3(0, 0.48, 0), _cloth("cloth", Color(0.62, 0.55, 0.42), 0.5))
	var top := 0.48 + tick_size.y * 0.5 - 0.03
	_mesh(n, M.drape(Vector2(tick_size.x, tick_size.z), Vector4(0.06, 0.08, 0.1, 0.1), 0.008, 3, 0.012), Vector3(0, top, 0), _two(linen))
	# Bolster at the head.
	_mesh(n, M.cushion(Vector3(0.3, 0.14, tick_size.z - 0.06), 0.55, 0.03, 0.0), Vector3(-hx + 0.28, top + 0.07, 0), linen)
	# Blanket over the foot two thirds, its top edge turned down.
	var blanket_len := tick_size.x * 0.66
	var wool := _cloth("wool", blanket, 0.4)
	var bx := hx - 0.07 - blanket_len * 0.5
	_mesh(n, M.drape(Vector2(blanket_len, tick_size.z), Vector4(0.0, 0.13, 0.13, 0.13), 0.02, 5, 0.03), Vector3(bx, top, 0), _two(wool))
	var fold := _mesh(n, M.cushion(Vector3(0.12, 0.05, tick_size.z + 0.04), 0.6, 0.0, 0.0), Vector3(bx - blanket_len * 0.5 + 0.05, top + 0.045, 0), wool)
	fold.rotation.z = 0.12
	# A fur thrown across the foot.
	var fur := _mesh(n, M.drape(Vector2(0.55, tick_size.z * 0.85), Vector4(0.0, 0.05, 0.18, 0.12), 0.018, 9, 0.05), Vector3(hx - 0.45, top + 0.01, 0.04), _two(_cloth("fur", Color(0.42, 0.33, 0.25), 0.3)))
	fur.rotation.y = 0.12
	G.solid(n, Vector3(length, 0.66, width), Vector3(0, 0.33, 0))
	return n


# --- Chest ----------------------------------------------------------------------------

## A six-board chest bound with iron straps, a hasp and ring handles.
## The front faces local -Z.
static func chest(parent: Node, pos: Vector3, yaw := 0.0, size := Vector3(0.95, 0.48, 0.5)) -> Node3D:
	var n := _node(parent, pos, yaw)
	var oak := D.wood_dark()
	var iron := D.iron()
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var t := 0.03
	# End boards run to the floor as feet; front and back boards sit between them.
	for x in [-1.0, 1.0]:
		_b(n, Vector3(t, size.y - 0.04, size.z - 0.02), Vector3(x * (hx - t * 0.5 - 0.02), (size.y - 0.04) * 0.5, 0), oak)
	for z in [-1.0, 1.0]:
		_b(n, Vector3(size.x, size.y - 0.12, t), Vector3(0, 0.08 + (size.y - 0.12) * 0.5, z * (hz - t * 0.5)), oak)
	# Lid, overhanging slightly, with a moulded edge.
	_b(n, Vector3(size.x + 0.04, 0.035, size.z + 0.03), Vector3(0, size.y - 0.02, 0), oak, 0.01)
	_b(n, Vector3(size.x + 0.02, 0.025, size.z + 0.01), Vector3(0, size.y - 0.05, 0), oak, 0.006)
	# Iron straps over the lid and down the front and back, studded with nails.
	for x in [-hx + 0.16, hx - 0.16]:
		_b(n, Vector3(0.045, 0.006, size.z + 0.04), Vector3(x, size.y + 0.001, 0), iron, 0.002)
		for z in [-1.0, 1.0]:
			_b(n, Vector3(0.045, size.y - 0.12, 0.006), Vector3(x, size.y * 0.5, z * (hz + 0.018)), iron, 0.002)
			for i in 4:
				_stud(n, Vector3(x, 0.12 + i * (size.y - 0.2) / 3.0, z * (hz + 0.022)), iron)
	# Hasp and lock plate.
	_b(n, Vector3(0.05, 0.13, 0.006), Vector3(0, size.y - 0.09, -hz - 0.022), iron, 0.002)
	_b(n, Vector3(0.1, 0.08, 0.008), Vector3(0, size.y - 0.2, -hz - 0.018), iron, 0.003)
	var key := G.cylinder(n, 0.008, 0.01, Vector3(0, size.y - 0.2, -hz - 0.023), G.mat(Color(0.02, 0.02, 0.02)))
	key.rotation.x = PI * 0.5
	# Ring handles on the ends.
	for x in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.035
		tm.outer_radius = 0.047
		tm.rings = 16
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = iron
		ring.position = Vector3(x * (hx + 0.012), size.y * 0.62, 0)
		ring.rotation = Vector3(0, 0, PI * 0.5)
		n.add_child(ring)
		_stud(n, Vector3(x * (hx + 0.006), size.y * 0.66, 0), iron)
	G.solid(n, size, Vector3(0, size.y * 0.5, 0))
	return n


# --- Tables and seating -----------------------------------------------------------------

## A trestle table: a top of three boards on two splayed trestles, tied by a
## stretcher locked with wedges. Long axis is local X. Top surface at size.y.
static func trestle_table(parent: Node, center: Vector3, size: Vector3, yaw := 0.0, top_material: Material = null) -> Node3D:
	var n := _node(parent, center, yaw)
	var oak := D.wood_dark()
	var top_mat: Material = top_material if top_material != null else D.wood()
	var boards := 3 if size.z > 0.75 else 2
	var bw := size.z / boards
	for i in boards:
		var z := -size.z * 0.5 + bw * (i + 0.5)
		_b(n, Vector3(size.x, 0.045, bw - 0.006), Vector3(0, size.y - 0.0225 - (i % 2) * 0.002, z), top_mat, 0.006)
	var inset := minf(0.45, size.x * 0.2)
	for x in [-1.0, 1.0]:
		var tx: float = x * (size.x * 0.5 - inset)
		# Bearer under the top and a foot on the floor.
		_b(n, Vector3(0.07, 0.07, size.z - 0.12), Vector3(tx, size.y - 0.08, 0), oak)
		_b(n, Vector3(0.08, 0.07, size.z - 0.04), Vector3(tx, 0.035, 0), oak)
		# Two splayed legs.
		var leg_h := size.y - 0.15
		for z in [-1.0, 1.0]:
			var leg := _b(n, Vector3(0.065, leg_h + 0.04, 0.075), Vector3(tx, 0.06 + leg_h * 0.5, z * size.z * 0.17), oak)
			leg.rotation.x = -z * 0.22
	# Stretcher through both trestles, with wedges outside each.
	_b(n, Vector3(size.x - inset * 2.0 + 0.26, 0.06, 0.05), Vector3(0, 0.3, 0), oak)
	for x in [-1.0, 1.0]:
		var w := _b(n, Vector3(0.02, 0.11, 0.07), Vector3(x * (size.x * 0.5 - inset + 0.08), 0.3, 0), D.wood(), 0.004)
		w.rotation.z = x * 0.08
	G.solid(n, Vector3(size.x, 0.1, size.z), Vector3(0, size.y - 0.05, 0))
	G.solid(n, Vector3(size.x - inset * 2.0, size.y - 0.1, 0.3), Vector3(0, (size.y - 0.1) * 0.5, 0))
	return n


## A plank bench on slab ends with a rail under the seat. Long axis is local X.
static func bench(parent: Node, center: Vector3, length: float, yaw := 0.0, height := 0.45) -> Node3D:
	var n := _node(parent, center, yaw)
	var oak := D.wood_dark()
	_b(n, Vector3(length, 0.05, 0.3), Vector3(0, height - 0.025, 0), D.wood(), 0.008)
	var inset := minf(0.35, length * 0.15)
	for x in [-1.0, 1.0]:
		var slab := _b(n, Vector3(0.05, height - 0.05, 0.26), Vector3(x * (length * 0.5 - inset), (height - 0.05) * 0.5, 0), oak)
		slab.rotation.z = x * 0.05
	for z in [-1.0, 1.0]:
		_b(n, Vector3(length - inset * 2.0, 0.07, 0.03), Vector3(0, height - 0.09, z * 0.1), oak)
	G.solid(n, Vector3(length, height, 0.3), Vector3(0, height * 0.5, 0))
	return n


## A joined table on four turned legs with aprons and low stretchers.
static func joined_table(parent: Node, center: Vector3, size: Vector3, yaw := 0.0) -> Node3D:
	var n := _node(parent, center, yaw)
	var oak := D.wood_dark()
	_b(n, Vector3(size.x, 0.04, size.z), Vector3(0, size.y - 0.02, 0), D.wood(), 0.008)
	var lx := size.x * 0.5 - 0.07
	var lz := size.z * 0.5 - 0.07
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_leg(n, Vector3(x * lx, 0, z * lz), size.y - 0.04, 0.026, oak)
	for z in [-1.0, 1.0]:
		_b(n, Vector3(lx * 2.0, 0.08, 0.025), Vector3(0, size.y - 0.09, z * lz), oak)
		_b(n, Vector3(lx * 2.0, 0.035, 0.03), Vector3(0, 0.1, z * lz), oak)
	for x in [-1.0, 1.0]:
		_b(n, Vector3(0.025, 0.08, lz * 2.0), Vector3(x * lx, size.y - 0.09, 0), oak)
	G.solid(n, size, Vector3(0, size.y * 0.5, 0))
	return n


## A small round table on a turned pedestal with a cross foot.
static func round_table(parent: Node, center: Vector3, radius := 0.26, height := 0.7) -> Node3D:
	var n := _node(parent, center, 0.0)
	var oak := D.wood_dark()
	_mesh(n, M.turned([[0.0, radius - 0.005], [-0.012, radius], [-0.03, radius - 0.01], [-0.035, radius - 0.02]], 28), Vector3(0, height, 0), D.wood())
	_mesh(n, M.turned([[0.0, 0.035], [0.04, 0.045], [0.08, 0.03], [height * 0.45, 0.026], [height * 0.5, 0.04], [height * 0.55, 0.026], [height - 0.05, 0.03], [height - 0.035, 0.05]], 12), Vector3.ZERO, oak)
	for a in [0.0, PI * 0.5]:
		var foot := _b(n, Vector3(0.42, 0.05, 0.05), Vector3(0, 0.025, 0), oak)
		foot.rotation.y = a
	G.solid(n, Vector3(radius * 2.0, height, radius * 2.0), Vector3(0, height * 0.5, 0))
	return n


## A joined chair: turned legs, a board seat, back posts with finials and two
## shaped back rails. The sitter faces local -Z.
static func chair(parent: Node, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := _node(parent, pos, yaw)
	var oak := D.wood_dark()
	var seat_h := 0.46
	_b(n, Vector3(0.46, 0.035, 0.42), Vector3(0, seat_h, -0.01), D.wood(), 0.008)
	for x in [-1.0, 1.0]:
		_leg(n, Vector3(x * 0.2, 0, -0.18), seat_h - 0.018, 0.022, oak)
		# Back posts run from the floor to above the shoulders.
		_post(n, Vector3(x * 0.2, 0, 0.18), 1.02, 0.024, oak)
	for y in [0.75, 0.93]:
		var rail := _b(n, Vector3(0.38, 0.07, 0.025), Vector3(0, y, 0.185), oak)
		rail.rotation.x = -0.06
	for x in [-1.0, 1.0]:
		_b(n, Vector3(0.025, 0.03, 0.34), Vector3(x * 0.2, 0.14, 0.0), oak)
	_b(n, Vector3(0.38, 0.03, 0.025), Vector3(0, 0.12, -0.18), oak)
	_b(n, Vector3(0.38, 0.03, 0.025), Vector3(0, 0.12, 0.18), oak)
	G.solid(n, Vector3(0.46, seat_h, 0.42), Vector3(0, seat_h * 0.5, 0))
	return n


## A three-legged stool with a round seat.
static func stool(parent: Node, pos: Vector3, height := 0.42) -> Node3D:
	var n := _node(parent, pos, randf() * TAU)
	var oak := D.wood_dark()
	_mesh(n, M.turned([[0.0, 0.15], [-0.01, 0.16], [-0.035, 0.155], [-0.04, 0.14]], 22), Vector3(0, height, 0), D.wood())
	for i in 3:
		var a := TAU * i / 3.0
		var leg := Node3D.new()
		leg.position = Vector3(cos(a) * 0.09, height - 0.04, sin(a) * 0.09)
		leg.rotation = Vector3(-sin(a) * 0.2, 0, cos(a) * 0.2)
		n.add_child(leg)
		_mesh(leg, M.turned([[0.0, 0.02], [-(height - 0.03) * 0.5, 0.018], [-(height - 0.03), 0.014]], 8), Vector3.ZERO, oak)
	G.solid(n, Vector3(0.32, height, 0.32), Vector3(0, height * 0.5, 0))
	return n


## The king's throne: a heavy oak chair of state with carved posts, gilded
## finials, a tall panelled back, armrests on spindles and a red cushion.
## pos: floor under the seat centre. The sitter faces local -Z.
static func throne(parent: Node, pos: Vector3, yaw := 0.0, cushion := Color(0.42, 0.08, 0.1), gilt: Material = null) -> Node3D:
	var n := _node(parent, pos, yaw)
	var oak := S.get_material("wood_dark", Color(0.75, 0.62, 0.55), 1.2, false)
	var gold: Material = gilt if gilt != null else G.mat(Color(0.6, 0.45, 0.2), 0.0, 0.8, 0.45)
	var seat_h := 0.42
	# Box seat with a panelled front.
	_b(n, Vector3(1.0, seat_h - 0.03, 0.78), Vector3(0, (seat_h - 0.03) * 0.5, 0.0), oak, 0.012)
	_b(n, Vector3(0.84, seat_h - 0.14, 0.02), Vector3(0, seat_h * 0.5, -0.395), D.wood(), 0.006)
	_b(n, Vector3(1.04, 0.035, 0.82), Vector3(0, seat_h - 0.015, 0.0), oak, 0.01)
	_mesh(n, M.cushion(Vector3(0.86, 0.1, 0.68), 0.35, 0.025, 0.0), Vector3(0, seat_h + 0.045, -0.02), _cloth("wool", cushion, 0.4))
	# Four posts: tall back posts, shorter front posts carrying the arms.
	for x in [-1.0, 1.0]:
		_post(n, Vector3(x * 0.52, 0, 0.36), 2.3, 0.055, oak, gold)
		_post(n, Vector3(x * 0.52, 0, -0.38), 0.95, 0.048, oak, gold)
		_b(n, Vector3(0.09, 0.05, 0.86), Vector3(x * 0.52, 0.86, -0.01), oak, 0.012)
		for i in 3:
			_mesh(n, M.turned([[0.0, 0.016], [0.08, 0.022], [0.16, 0.016], [0.24, 0.022], [0.32, 0.016], [0.4, 0.016]], 8), Vector3(x * 0.52, seat_h + 0.03, -0.24 + i * 0.2), oak)
	# Tall back: framed panels and a pointed crest rail.
	_b(n, Vector3(0.98, 1.65, 0.05), Vector3(0, seat_h + 0.85, 0.37), D.wood(), 0.008)
	for y in [seat_h + 0.05, seat_h + 0.85, seat_h + 1.65]:
		_b(n, Vector3(1.0, 0.08, 0.07), Vector3(0, y, 0.35), oak, 0.012)
	for x in [-0.25, 0.25]:
		_b(n, Vector3(0.06, 1.6, 0.065), Vector3(x, seat_h + 0.85, 0.35), oak, 0.01)
	var crest := _b(n, Vector3(0.5, 0.5, 0.06), Vector3(0, seat_h + 1.75, 0.36), oak, 0.012)
	crest.rotation.z = PI * 0.25
	_mesh(n, M.turned([[0.0, 0.04], [0.04, 0.05], [0.09, 0.03], [0.14, 0.0]], 12), Vector3(0, seat_h + 2.1, 0.36), gold)
	G.solid(n, Vector3(1.1, seat_h, 0.85), Vector3(0, seat_h * 0.5, 0))
	G.solid(n, Vector3(1.1, 1.9, 0.12), Vector3(0, seat_h + 0.95, 0.36))
	return n


## A low footstool with a cushion, for a seated king's feet.
static func footstool(parent: Node, pos: Vector3, yaw := 0.0, cushion := Color(0.42, 0.08, 0.1)) -> Node3D:
	var n := _node(parent, pos, yaw)
	var oak := S.get_material("wood_dark", Color(0.75, 0.62, 0.55), 1.2, false)
	_b(n, Vector3(0.62, 0.11, 0.32), Vector3(0, 0.055, 0), oak, 0.012)
	_mesh(n, M.cushion(Vector3(0.56, 0.07, 0.28), 0.35, 0.01, 0.0), Vector3(0, 0.14, 0), _cloth("wool", cushion, 0.4))
	return n


# --- Helpers --------------------------------------------------------------------------

static func _node(parent: Node, pos: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	return n


## A bevelled board or beam.
static func _b(parent: Node, size: Vector3, pos: Vector3, material: Material, bevel := 0.01) -> MeshInstance3D:
	return _mesh(parent, M.bevel_box(size, bevel), pos, material)


static func _mesh(parent: Node, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## A turned post with a foot, rings and a finial. Finial optionally gilded.
static func _post(parent: Node, pos: Vector3, height: float, r: float, material: Material, finial: Material = null) -> void:
	var prof := [[0.0, r * 0.9], [0.03, r * 1.1], [0.07, r * 1.1], [0.1, r * 0.85], [height * 0.4, r * 0.8],
		[height * 0.4 + 0.02, r * 1.05], [height * 0.4 + 0.05, r * 0.8], [height - 0.12, r * 0.78], [height - 0.09, r * 1.05], [height - 0.06, r * 0.85]]
	_mesh(parent, M.turned(prof, 12), pos, material)
	var top := [[0.0, r * 0.85], [0.03, r * 1.0], [0.06, r * 0.6], [0.08, r * 0.2], [0.09, 0.0]]
	_mesh(parent, M.turned(top, 12), pos + Vector3(0, height - 0.06, 0), finial if finial != null else material)


## A turned leg: tapered, with a ring near the top and a small foot.
static func _leg(parent: Node, pos: Vector3, height: float, r: float, material: Material) -> void:
	var prof := [[0.0, r * 0.85], [0.02, r * 1.05], [0.05, r * 0.85], [height * 0.6, r], [height * 0.75, r * 1.25],
		[height * 0.8, r * 0.95], [height - 0.1, r * 1.15], [height, r * 1.15]]
	_mesh(parent, M.turned(prof, 10), pos, material)


static func _stud(parent: Node, pos: Vector3, material: Material) -> void:
	var s := G.sphere(parent, 0.009, pos, material)
	s.scale = Vector3(1, 1, 0.6)


static func _cloth(surface: String, color: Color, tile: float) -> Material:
	return S.get_material(surface, color, tile, false)


static func _two(material: Material) -> Material:
	var key := material.get_instance_id()
	if not _two_sided.has(key):
		var d := material.duplicate() as StandardMaterial3D
		d.cull_mode = BaseMaterial3D.CULL_DISABLED
		_two_sided[key] = d
	return _two_sided[key]
