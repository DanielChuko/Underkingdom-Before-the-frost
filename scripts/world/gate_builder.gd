extends RefCounted
## Exterior greybox for the prelude's opening: the road, the city wall with
## its closed gate, two towers and the gate guard. The camera is fixed here;
## the player only takes control once inside the castle.

const G := preload("res://scripts/world/greybox.gd")
const NpcScript := preload("res://scripts/world/npc.gd")
const S := preload("res://scripts/world/surfaces.gd")
const D := preload("res://scripts/world/decor.gd")
const F := preload("res://scripts/world/furniture.gd")
const P := preload("res://scripts/world/props.gd")
const H := preload("res://scripts/world/heraldry.gd")
const M := preload("res://scripts/world/models.gd")


## Returns {"root", "camera", "guard"}.
func build() -> Dictionary:
	var root := Node3D.new()
	root.name = "Gate"
	var mud := S.get_material("mud", Color.WHITE, 5.0)
	var road := S.get_material("cobbles", Color(0.95, 0.92, 0.88), 2.5)
	var stone := S.get_material("stone_wall", Color.WHITE, 3.0)
	var wood := S.get_material("wood_dark", Color.WHITE, 2.0, false)
	var iron := D.iron()
	var red := S.get_material("cloth", Color(0.62, 0.08, 0.09), 1.0)
	var leaf := G.mat(Color(0.2, 0.36, 0.18))
	var bark := G.mat(Color(0.3, 0.22, 0.14))

	G.box(root, Vector3(140, 0.2, 140), Vector3(0, -0.1, 0), mud)
	G.box(root, Vector3(4.6, 0.04, 60.0), Vector3(0, 0.01, 24.0), road, false)
	G.box(root, Vector3(5.6, 0.03, 60.0), Vector3(0, 0.005, 24.0), S.get_material("mud", Color(0.8, 0.75, 0.7), 2.0), false)

	# City wall with the gate opening and two flanking towers, faced with the
	# supplied 4 m wall pieces (battlements on top) over a solid core.
	var faced := M.exists("wall_4m")
	var wall_h := 6.0 if faced else 7.0
	G.box(root, Vector3(38.0, wall_h, 2.0), Vector3(-21.2, wall_h * 0.5, -6.0), stone)
	G.box(root, Vector3(38.0, wall_h, 2.0), Vector3(21.2, wall_h * 0.5, -6.0), stone)
	var gate_h := 4.06 if faced else 5.0
	G.box(root, Vector3(4.4, wall_h - gate_h, 2.0), Vector3(0, (wall_h + gate_h) * 0.5, -6.0), stone)
	var tower_h := 9.0 if faced else 10.0
	for x in [-4.2, 4.2]:
		G.box(root, Vector3(4.0, tower_h, 4.0), Vector3(x, tower_h * 0.5, -6.0), stone)
	if faced:
		# Over the gate: a battlemented piece squeezed to fit above the leaves.
		M.place(root, "wall_battlements_4m", Vector3(0, gate_h, -5.0), Vector3.ZERO, Vector3(1.1, (6.75 - gate_h) / 3.75, 1.0))
		for side in [-1.0, 1.0]:
			# Curtain wall: a plain course with a battlemented course on top.
			for i in 9:
				var cx: float = side * (8.2 + i * 4.0)
				M.place(root, "wall_4m", Vector3(cx, 0, -5.0))
				M.place(root, "wall_battlements_4m", Vector3(cx, 3.0, -5.0))
			# Towers: two courses and a battlemented one on the front and both sides.
			var tx: float = side * 4.2
			var faces := [[Vector3(tx, 0, -4.0), 0.0], [Vector3(tx - 2.0, 0, -6.0), -PI * 0.5], [Vector3(tx + 2.0, 0, -6.0), PI * 0.5]]
			for f in faces:
				for y in [0.0, 3.0]:
					M.place(root, "wall_4m", f[0] + Vector3(0, y, 0), Vector3(0, f[1], 0))
				M.place(root, "wall_battlements_4m", f[0] + Vector3(0, 6.0, 0), Vector3(0, f[1], 0))
			# The kingdom's banner on each tower, hanging still.
			H.banner(root, Vector3(tx, 8.4, -3.55), Vector3(0, 0, 1), 1.4)
	else:
		for x in [-4.2, 4.2]:
			for cx in [-1.5, 0.0, 1.5]:
				G.box(root, Vector3(0.9, 0.8, 4.1), Vector3(x + cx, 10.4, -6.0), stone, false)
			G.box(root, Vector3(1.2, 3.2, 0.06), Vector3(x, 6.6, -3.97), red, false)
		for i in range(-19, 20):
			var x := i * 2.0
			if absf(x) > 6.5:
				G.box(root, Vector3(1.0, 0.8, 2.1), Vector3(x, 7.4, -6.0), stone, false)

	# The closed gate: two of the supplied gate leaves at 125%, the right one
	# mirrored, or a plank gate with iron bands.
	if M.place(root, "gate_left", Vector3(-2.25, 0, -5.2), Vector3.ZERO, Vector3.ONE * 1.25) != null:
		M.place(root, "gate_left", Vector3(2.25, 0, -5.2), Vector3.ZERO, Vector3(-1.25, 1.25, 1.25))
	else:
		G.box(root, Vector3(4.3, 4.9, 0.3), Vector3(0, 2.45, -5.4), wood)
		G.box(root, Vector3(0.06, 4.9, 0.34), Vector3(0, 2.45, -5.4), iron, false)
		for y in [1.0, 2.6, 4.2]:
			G.box(root, Vector3(4.3, 0.14, 0.36), Vector3(0, y, -5.4), iron, false)
	G.torch(root, Vector3(-2.6, 3.0, -3.65), Vector3(0, 0, 1), 1.2, 6.0, false)
	G.torch(root, Vector3(2.6, 3.0, -3.65), Vector3(0, 0, 1), 1.2, 6.0, false)

	# Outside the gate: a provisions stall with the day's produce, barrels,
	# a crate and sacks, and a bench where the guard takes his ale.
	F.trestle_table(root, Vector3(-5.2, 0, -2.3), Vector3(1.65, 0.82, 0.78))
	var top := 0.82
	P.cabbage(root, Vector3(-5.85, top, -2.45))
	P.cabbage(root, Vector3(-5.7, top, -2.15))
	for i in 5:
		P.apple(root, Vector3(-5.35 + (i % 3) * 0.08, top, -2.5 + (i / 3) * 0.08), Color(0.72, 0.1, 0.08) if i % 2 else Color(0.55, 0.65, 0.15))
	for i in 3:
		P.carrot(root, Vector3(-4.85, top, -2.3 - i * 0.06), 0.1 * i)
	for i in 4:
		P.onion(root, Vector3(-4.75 + (i % 2) * 0.08, top, -2.45 + (i / 2) * 0.08))
	for i in 4:
		P.potato(root, Vector3(-4.6 + (i % 2) * 0.1, top, -2.15 + (i / 2) * 0.07), i * 0.8)
	P.item(root, "fish_whole", Vector3(-5.25, top, -2.1), 0.2)
	P.item(root, "grapes", Vector3(-4.55, top, -2.55))
	for i in 3:
		P.item(root, "garlic", Vector3(-5.0 + i * 0.07, top, -2.55))
	D.barrel(root, Vector3(-3.0, 0, -3.55))
	D.barrel(root, Vector3(-6.6, 0, -3.3), 0.9, true)
	for i in 4:
		P.apple(root, Vector3(-6.6 + (i % 2) * 0.1 - 0.05, 0.86, -3.3 + (i / 2) * 0.1 - 0.05))
	D.barrel(root, Vector3(-7.2, 0, -2.4), 0.7)
	D.crate(root, Vector3(-3.3, 0, -2.6), 0.7, 0.4)
	D.sack(root, Vector3(3.3, 0, -3.6))
	D.sack(root, Vector3(-6.1, 0, -1.6), Color(0.68, 0.6, 0.45))
	F.bench(root, Vector3(4.7, 0, -3.25), 1.6)
	P.item(root, "tankard_wood", Vector3(4.2, 0.45, -3.25), 0.6)
	P.item(root, "cup_clay", Vector3(5.2, 0.45, -3.2))
	F.stool(root, Vector3(3.5, 0, -2.2))
	P.potted_flower(root, Vector3(-4.85, top, -2.08), 0.25)

	# A few trees along the road outside the walls.
	var trees := [Vector2(-9, 4), Vector2(-13, 12), Vector2(-8, 20), Vector2(10, 6), Vector2(14, 15), Vector2(9, 24), Vector2(-18, 2), Vector2(19, 3)]
	for t in trees:
		G.cylinder(root, 0.25, 2.0, Vector3(t.x, 1.0, t.y), bark)
		G.cylinder(root, 1.6, 4.0, Vector3(t.x, 4.0, t.y), leaf, 0.0)

	# Daylight.
	var sun_light := DirectionalLight3D.new()
	sun_light.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(35.0), 0)
	sun_light.light_energy = 1.1
	sun_light.shadow_enabled = true
	root.add_child(sun_light)

	# The gate guard, facing the arriving envoy.
	var guard_pos := Vector3(1.8, 0, -3.4)
	var cam_pos := Vector3(0, 1.65, 5.0)
	var to_cam := cam_pos - guard_pos
	var guard = G.npc(root, NpcScript, "Gate Guard", guard_pos, atan2(-to_cam.x, -to_cam.z), "gate_guard")
	guard.speaker_name = "Guard"

	var cam := Camera3D.new()
	cam.position = cam_pos
	cam.fov = 70.0
	root.add_child(cam)
	return {"root": root, "camera": cam, "guard": guard}
