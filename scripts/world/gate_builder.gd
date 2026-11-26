extends RefCounted
## Exterior greybox for the prelude's opening: the road, the city wall with
## its closed gate, two towers and the gate guard. The camera is fixed here;
## the player only takes control once inside the castle.

const G := preload("res://scripts/world/greybox.gd")
const NpcScript := preload("res://scripts/world/npc.gd")


## Returns {"root", "camera", "guard"}.
func build() -> Dictionary:
	var root := Node3D.new()
	root.name = "Gate"
	var mud := G.mat(Color(0.3, 0.23, 0.15))
	var road := G.mat(Color(0.42, 0.34, 0.24))
	var stone := G.mat(Color(0.52, 0.5, 0.46))
	var wood := G.mat(Color(0.3, 0.19, 0.1))
	var iron := G.mat(Color(0.15, 0.15, 0.16), 0.0, 0.7, 0.5)
	var red := G.mat(Color(0.58, 0.07, 0.08))
	var leaf := G.mat(Color(0.2, 0.36, 0.18))
	var bark := G.mat(Color(0.3, 0.22, 0.14))

	G.box(root, Vector3(140, 0.2, 140), Vector3(0, -0.1, 0), mud)
	G.box(root, Vector3(4.0, 0.04, 60.0), Vector3(0, 0.01, 24.0), road, false)

	# City wall with the gate opening, two flanking towers and crenellations.
	G.box(root, Vector3(38.0, 7.0, 2.0), Vector3(-21.2, 3.5, -6.0), stone)
	G.box(root, Vector3(38.0, 7.0, 2.0), Vector3(21.2, 3.5, -6.0), stone)
	G.box(root, Vector3(4.4, 2.0, 2.0), Vector3(0, 6.0, -6.0), stone)
	for x in [-4.2, 4.2]:
		G.box(root, Vector3(4.0, 10.0, 4.0), Vector3(x, 5.0, -6.0), stone)
		for cx in [-1.5, 0.0, 1.5]:
			G.box(root, Vector3(0.9, 0.8, 4.1), Vector3(x + cx, 10.4, -6.0), stone, false)
		G.box(root, Vector3(1.2, 3.2, 0.06), Vector3(x, 6.6, -3.97), red, false)
		var sun := G.cylinder(root, 0.3, 0.03, Vector3(x, 7.3, -3.93), G.mat(Color(0.9, 0.7, 0.25), 0.4, 0.8, 0.35))
		sun.rotation.x = PI * 0.5
	for i in range(-19, 20):
		var x := i * 2.0
		if absf(x) > 6.5:
			G.box(root, Vector3(1.0, 0.8, 2.1), Vector3(x, 7.4, -6.0), stone, false)

	# The closed gate.
	G.box(root, Vector3(4.3, 4.9, 0.3), Vector3(0, 2.45, -5.4), wood)
	G.box(root, Vector3(0.06, 4.9, 0.34), Vector3(0, 2.45, -5.4), iron, false)
	for y in [1.0, 2.6, 4.2]:
		G.box(root, Vector3(4.3, 0.14, 0.36), Vector3(0, y, -5.4), iron, false)
	G.torch(root, Vector3(-2.6, 3.0, -4.95), Vector3(0, 0, 1), 1.2, 6.0)
	G.torch(root, Vector3(2.6, 3.0, -4.95), Vector3(0, 0, 1), 1.2, 6.0)

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
	var guard = G.npc(root, NpcScript, "Gate Guard", guard_pos, atan2(-to_cam.x, -to_cam.z), Color(0.25, 0.32, 0.5), "helmet")

	var cam := Camera3D.new()
	cam.position = cam_pos
	cam.fov = 70.0
	root.add_child(cam)
	return {"root": root, "camera": cam, "guard": guard}
