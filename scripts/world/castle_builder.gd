extends RefCounted
## Builds the greybox castle interior in code.
##
## Layout (top-down, metres; north is -Z):
##
##   King's hall          x 2.5..22.5, z -34..-58  (crest, throne, banners, stairs to a landing)
##        |  open double doors at z -34
##   Corridor C           x 11..14,   z -19..-34   (guard on duty by the hall doors)
##   Corridor B  ---------x 1.5..14,  z -16..-19   (toilet room to the north)
##   Corridor A           x -1.5..1.5, z 0..-19    (Casimir's room west, kitchen east)
##
## The corridor winds twice on the way to the hall. Five single doors and two
## great double doors are locked; only the player's room, the kitchen and the
## toilet open (and only in Act 1). The kitchen's outer door leaves the castle.

const G := preload("res://scripts/world/greybox.gd")
const NpcScript := preload("res://scripts/world/npc.gd")

const CORRIDOR_H := 4.0
const CORRIDOR_C_H := 5.0
const ROOM_H := 3.5
const HALL_H := 9.0
const DOOR_W := 1.2
const DOOR_H := 2.3
const GAP_W := 1.3
const GAP_H := 2.4

var root: Node3D
var act := 0
var npcs: Dictionary = {}

var stone: Material
var stone_dark: Material
var floor_mat: Material
var ceiling_mat: Material
var wood: Material
var wood_dark: Material
var red_cloth: Material
var gold: Material


## Returns {"root", "spawn_position", "spawn_yaw", "npcs", "hall_trigger", "exit_door"}.
func build(for_act: int) -> Dictionary:
	act = for_act
	root = Node3D.new()
	root.name = "Castle"
	_materials()
	_corridors()
	_kings_hall()
	_player_room()
	_kitchen()
	_toilet()
	_characters()

	var hall_trigger := Area3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 2.0)
	cs.shape = shape
	hall_trigger.position = Vector3(12.5, 1.5, -35.5)
	hall_trigger.add_child(cs)
	root.add_child(hall_trigger)

	var exit_door := G.prop(root, Vector3(0.2, 3.0, 2.4), Vector3(9.27, 1.5, -8.5), null, "Leave the castle")
	G.box(exit_door, Vector3(0.1, 3.0, 1.15), Vector3(0, 0, -0.6), wood_dark, false)
	G.box(exit_door, Vector3(0.1, 3.0, 1.15), Vector3(0, 0, 0.6), wood_dark, false)
	G.box(exit_door, Vector3(0.14, 0.1, 2.3), Vector3(0, -0.7, 0), stone_dark, false)
	G.box(exit_door, Vector3(0.14, 0.1, 2.3), Vector3(0, 0.8, 0), stone_dark, false)

	var spawn_pos := Vector3(0.0, 0.05, -1.6)
	var spawn_yaw := 0.0
	if act >= 1:
		spawn_pos = Vector3(-5.0, 0.05, -6.2)
		spawn_yaw = -PI * 0.5
	return {
		"root": root,
		"spawn_position": spawn_pos,
		"spawn_yaw": spawn_yaw,
		"npcs": npcs,
		"hall_trigger": hall_trigger,
		"exit_door": exit_door,
	}


func _materials() -> void:
	stone = G.mat(Color(0.47, 0.45, 0.42))
	stone_dark = G.mat(Color(0.3, 0.29, 0.28))
	floor_mat = G.mat(Color(0.33, 0.3, 0.28))
	ceiling_mat = G.mat(Color(0.24, 0.22, 0.2))
	wood = G.mat(Color(0.42, 0.27, 0.15))
	wood_dark = G.mat(Color(0.26, 0.16, 0.09))
	red_cloth = G.mat(Color(0.58, 0.07, 0.08))
	gold = G.mat(Color(0.9, 0.7, 0.25), 0.4, 0.8, 0.35)


func _locked(hinge: Vector3, along: Vector3, label := "door") -> void:
	var d = G.door(root, hinge, along, Vector3.ZERO, DOOR_W, DOOR_H, wood_dark, label)
	d.locked = true
	d.locked_message = "It's locked."


func _corridors() -> void:
	# Corridor A: entrance, running north.
	G.floor_and_ceiling(root, -1.5, 1.5, 0.0, -19.0, CORRIDOR_H, floor_mat, ceiling_mat)
	G.wall(root, Vector2(-1.5, 0), Vector2(-1.5, -19), CORRIDOR_H, stone, [[-7.0, GAP_W, GAP_H]])
	G.wall(root, Vector2(1.5, 0), Vector2(1.5, -16), CORRIDOR_H, stone, [[-9.0, GAP_W, GAP_H]])
	G.wall(root, Vector2(-1.65, 0), Vector2(1.65, 0), CORRIDOR_H, stone)
	G.wall(root, Vector2(-1.65, -19), Vector2(1.65, -19), CORRIDOR_H, stone)

	# Corridor B: turns east.
	G.floor_and_ceiling(root, 1.5, 14.0, -16.0, -19.0, CORRIDOR_H, floor_mat, ceiling_mat)
	G.wall(root, Vector2(1.5, -16), Vector2(14.15, -16), CORRIDOR_H, stone)
	G.wall(root, Vector2(1.5, -19), Vector2(11.0, -19), CORRIDOR_H, stone, [[4.5, GAP_W, GAP_H]])

	# Corridor C: turns north again, a little taller, to the king's hall.
	G.floor_and_ceiling(root, 11.0, 14.0, -19.0, -34.0, CORRIDOR_C_H, floor_mat, ceiling_mat)
	G.wall(root, Vector2(11.0, -19), Vector2(11.0, -34), CORRIDOR_C_H, stone)
	G.wall(root, Vector2(14.0, -16), Vector2(14.0, -34), CORRIDOR_C_H, stone)
	G.box(root, Vector3(3.0, 1.0, 0.3), Vector3(12.5, 4.5, -19.0), stone)

	# The two great double doors: barred shut.
	for z in [-0.22, -18.78]:
		var big = G.door(root, Vector3(-1.3, 0, z), Vector3(1, 0, 0), Vector3.ZERO, 2.6, 3.2, wood_dark, "great doors", true)
		big.locked = true
		big.locked_message = "The great doors are barred from the other side."

	# Five locked side doors, flush against the walls.
	_locked(Vector3(-1.28, 0, -13.4), Vector3(0, 0, -1))
	_locked(Vector3(8.4, 0, -16.22), Vector3(1, 0, 0))
	_locked(Vector3(11.22, 0, -23.4), Vector3(0, 0, -1))
	_locked(Vector3(11.22, 0, -29.4), Vector3(0, 0, -1))
	_locked(Vector3(13.78, 0, -26.4), Vector3(0, 0, -1))

	# Crest above the hall entrance (corridor side).
	_crest(Vector3(12.5, 4.2, -33.8), 0.9, 0.0)

	# Torches.
	G.torch(root, Vector3(-1.35, 2.4, -3.0), Vector3(1, 0, 0))
	G.torch(root, Vector3(1.35, 2.4, -13.0), Vector3(-1, 0, 0))
	G.torch(root, Vector3(-1.35, 2.4, -17.5), Vector3(1, 0, 0))
	G.torch(root, Vector3(7.0, 2.4, -16.15), Vector3(0, 0, -1))
	G.torch(root, Vector3(11.15, 2.4, -21.0), Vector3(1, 0, 0))
	G.torch(root, Vector3(13.85, 2.4, -31.5), Vector3(-1, 0, 0))


func _kings_hall() -> void:
	G.floor_and_ceiling(root, 2.5, 22.5, -34.0, -58.0, HALL_H, G.mat(Color(0.36, 0.32, 0.29)), ceiling_mat)
	G.wall(root, Vector2(2.35, -34), Vector2(22.65, -34), HALL_H, stone, [[12.5, 3.0, 3.4]])
	G.wall(root, Vector2(2.35, -58), Vector2(22.65, -58), HALL_H, stone)
	G.wall(root, Vector2(2.5, -34), Vector2(2.5, -58), HALL_H, stone)
	G.wall(root, Vector2(22.5, -34), Vector2(22.5, -58), HALL_H, stone)

	# Open double doors into the hall.
	var hall_doors = G.door(root, Vector3(11.05, 0, -34.0), Vector3(1, 0, 0), Vector3(0, 0, -1), 2.9, 3.3, wood, "hall doors", true)
	hall_doors.set_open(true, true)

	# Carpet runner to the throne.
	G.box(root, Vector3(2.4, 0.02, 21.0), Vector3(12.5, 0.01, -45.0), red_cloth, false)

	# Great crest on the far wall.
	_crest(Vector3(12.5, 5.8, -57.8), 3.0, 0.0)

	# Throne under the crest.
	var throne := G.mat(Color(0.35, 0.12, 0.12))
	G.box(root, Vector3(2.0, 0.4, 1.8), Vector3(12.5, 0.2, -55.9), stone_dark)
	G.box(root, Vector3(1.1, 0.5, 0.9), Vector3(12.5, 0.65, -55.9), throne)
	G.box(root, Vector3(1.2, 2.4, 0.2), Vector3(12.5, 1.6, -56.5), throne)
	G.box(root, Vector3(0.15, 0.5, 0.9), Vector3(11.95, 1.05, -55.9), gold, false)
	G.box(root, Vector3(0.15, 0.5, 0.9), Vector3(13.05, 1.05, -55.9), gold, false)

	# Red banners bearing the crest on both side walls.
	for z in [-38.0, -44.0, -50.0]:
		_banner(Vector3(2.68, 5.4, z), Vector3(1, 0, 0))
		_banner(Vector3(22.32, 5.4, z), Vector3(-1, 0, 0))

	# Staircase along the east wall up to a landing with a (locked) door.
	var step_count := 14
	var run := 10.0
	var rise := 3.5
	var step_depth := run / step_count
	for i in step_count:
		var top := (i + 1) * rise / step_count
		G.box(root, Vector3(3.35, top, step_depth), Vector3(20.675, top * 0.5, -44.0 - (i + 0.5) * step_depth), stone_dark, false)
	var slope := atan2(rise, run)
	var ramp_len := sqrt(run * run + rise * rise) + 1.0
	G.solid(root, Vector3(3.35, 0.1, ramp_len), Vector3(20.675, rise * 0.5 + 0.06, -49.0), Vector3(slope, 0, 0))
	G.solid(root, Vector3(0.1, 3.0, 9.0), Vector3(18.95, 1.5, -49.5))
	G.box(root, Vector3(3.35, rise, 3.85), Vector3(20.675, rise * 0.5, -55.925), stone_dark)
	G.box(root, Vector3(0.15, 1.0, 3.85), Vector3(19.075, rise + 0.5, -55.925), wood_dark)
	_locked(Vector3(20.15, rise, -57.78), Vector3(1, 0, 0))

	# Light: four hanging lamps and two braziers by the throne.
	for p in [Vector3(7.5, 6.5, -40), Vector3(17.5, 6.5, -40), Vector3(7.5, 6.5, -51), Vector3(17.5, 6.5, -51)]:
		G.light(root, p, Color(1.0, 0.8, 0.55), 2.4, 15.0)
		G.cylinder(root, 0.5, 0.15, p + Vector3(0, 0.3, 0), G.mat(Color(0.2, 0.18, 0.16), 0.0, 0.7, 0.5))
		G.sphere(root, 0.18, p + Vector3(0, 0.45, 0), G.mat(Color(1.0, 0.7, 0.35), 4.0))
	for x in [9.5, 15.5]:
		G.cylinder(root, 0.35, 1.0, Vector3(x, 0.5, -54.5), stone_dark, 0.45)
		G.sphere(root, 0.3, Vector3(x, 1.1, -54.5), G.mat(Color(1.0, 0.55, 0.2), 5.0))
		G.light(root, Vector3(x, 1.8, -54.0), Color(1.0, 0.6, 0.3), 2.0, 8.0, true)


func _player_room() -> void:
	G.floor_and_ceiling(root, -7.5, -1.5, -4.0, -10.0, ROOM_H, G.mat(Color(0.4, 0.3, 0.22)), ceiling_mat)
	G.wall(root, Vector2(-7.65, -4), Vector2(-1.5, -4), ROOM_H, stone)
	G.wall(root, Vector2(-7.65, -10), Vector2(-1.5, -10), ROOM_H, stone)
	G.wall(root, Vector2(-7.5, -4), Vector2(-7.5, -10), ROOM_H, stone)

	var room_door = G.door(root, Vector3(-1.5, 0, -6.4), Vector3(0, 0, -1), Vector3(-1, 0, 0), DOOR_W, DOOR_H, wood, "door")
	room_door.locked = act == 0
	room_door.locked_message = "Locked. Someone's private chamber, no doubt."

	# Bed against the south wall.
	G.box(root, Vector3(2.0, 0.45, 1.1), Vector3(-6.4, 0.225, -4.75), wood_dark)
	G.box(root, Vector3(1.9, 0.15, 1.0), Vector3(-6.4, 0.52, -4.75), G.mat(Color(0.88, 0.85, 0.78)), false)
	G.box(root, Vector3(0.45, 0.12, 0.75), Vector3(-7.1, 0.65, -4.75), G.mat(Color(0.95, 0.95, 0.92)), false)
	G.box(root, Vector3(1.3, 0.06, 1.04), Vector3(-5.95, 0.61, -4.75), G.mat(Color(0.2, 0.3, 0.5)), false)
	G.prop(root, Vector3(2.0, 0.7, 1.1), Vector3(-6.4, 0.35, -4.75), null, "Look at the bed", "Your bed. You slept like a stone after the feast.")

	# Window on the west wall: bright daylight.
	var daylight := G.mat(Color(0.92, 0.96, 1.0), 3.0)
	G.box(root, Vector3(0.06, 1.3, 1.0), Vector3(-7.33, 1.9, -7.0), daylight, false)
	G.box(root, Vector3(0.1, 1.4, 0.08), Vector3(-7.3, 1.9, -7.0), wood_dark, false)
	G.box(root, Vector3(0.1, 0.08, 1.1), Vector3(-7.3, 1.9, -7.0), wood_dark, false)
	G.prop(root, Vector3(0.3, 1.3, 1.0), Vector3(-7.2, 1.9, -7.0), null, "Look out the window", "Bright daylight pours in. The sun still shines... for now.")
	G.light(root, Vector3(-6.6, 2.0, -7.0), Color(0.9, 0.95, 1.0), 1.8 if act >= 1 else 0.4, 7.0)

	# Writing table with a lit candle, and a chair.
	G.box(root, Vector3(1.2, 0.06, 0.7), Vector3(-2.6, 0.75, -9.3), wood)
	for off in [Vector2(-0.5, -0.28), Vector2(0.5, -0.28), Vector2(-0.5, 0.28), Vector2(0.5, 0.28)]:
		G.box(root, Vector3(0.06, 0.72, 0.06), Vector3(-2.6 + off.x, 0.36, -9.3 + off.y), wood_dark, false)
	G.cylinder(root, 0.035, 0.2, Vector3(-2.3, 0.88, -9.4), G.mat(Color(0.95, 0.93, 0.85)))
	G.sphere(root, 0.03, Vector3(-2.3, 1.01, -9.4), G.mat(Color(1.0, 0.75, 0.3), 8.0))
	G.light(root, Vector3(-2.3, 1.15, -9.2), Color(1.0, 0.75, 0.45), 1.2, 5.0)
	G.box(root, Vector3(0.45, 0.05, 0.45), Vector3(-2.6, 0.45, -8.5), wood)
	G.box(root, Vector3(0.45, 0.6, 0.05), Vector3(-2.6, 0.75, -8.28), wood)

	# Mirror on the north wall.
	G.box(root, Vector3(0.85, 1.45, 0.03), Vector3(-4.6, 1.6, -9.84), wood_dark, false)
	G.box(root, Vector3(0.7, 1.3, 0.03), Vector3(-4.6, 1.6, -9.81), G.mat(Color(0.8, 0.85, 0.9), 0.0, 1.0, 0.05), false)
	G.prop(root, Vector3(0.85, 1.45, 0.2), Vector3(-4.6, 1.6, -9.75), null, "Look in the mirror", "Casimir Vael of Hollowmere looks back at you, well rested at last.")

	# Small table with a pot and a single flower (blooming in Act 1; it withers act by act).
	G.box(root, Vector3(0.5, 0.04, 0.5), Vector3(-6.9, 0.7, -9.4), wood)
	G.box(root, Vector3(0.06, 0.7, 0.06), Vector3(-6.9, 0.35, -9.4), wood_dark, false)
	G.cylinder(root, 0.12, 0.2, Vector3(-6.9, 0.82, -9.4), G.mat(Color(0.65, 0.35, 0.22)), 0.14)
	G.cylinder(root, 0.012, 0.3, Vector3(-6.9, 1.07, -9.4), G.mat(Color(0.25, 0.55, 0.2)))
	G.sphere(root, 0.07, Vector3(-6.9, 1.24, -9.4), G.mat(Color(0.95, 0.45, 0.65), 0.3))
	G.prop(root, Vector3(0.5, 0.9, 0.5), Vector3(-6.9, 0.85, -9.4), null, "Look at the flower", "A single flower, in full bloom.")

	# Painting of a snowy mountain above the bed.
	G.box(root, Vector3(1.25, 0.95, 0.04), Vector3(-5.6, 2.2, -4.17), wood_dark, false)
	var painting := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1, 0.8)
	painting.mesh = quad
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = _mountain_texture()
	pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	painting.material_override = pm
	painting.position = Vector3(-5.6, 2.2, -4.2)
	painting.rotation.y = PI
	root.add_child(painting)
	G.prop(root, Vector3(1.25, 0.95, 0.2), Vector3(-5.6, 2.2, -4.25), null, "Look at the painting", "A painting of a snowy mountain.")


func _kitchen() -> void:
	G.floor_and_ceiling(root, 1.5, 9.5, -3.0, -14.0, ROOM_H, G.mat(Color(0.35, 0.32, 0.3)), ceiling_mat)
	G.wall(root, Vector2(1.5, -3), Vector2(9.65, -3), ROOM_H, stone)
	G.wall(root, Vector2(1.5, -14), Vector2(9.65, -14), ROOM_H, stone)
	G.wall(root, Vector2(9.5, -3), Vector2(9.5, -14), ROOM_H, stone)

	var kitchen_door = G.door(root, Vector3(1.5, 0, -8.4), Vector3(0, 0, -1), Vector3(1, 0, 0), DOOR_W, DOOR_H, wood, "door")
	kitchen_door.locked = act == 0
	kitchen_door.locked_message = "Locked. You can smell something cooking."

	# Table with a knife stuck in it and a piece of meat.
	G.box(root, Vector3(2.4, 0.08, 1.2), Vector3(5.5, 0.85, -8.5), wood)
	for off in [Vector2(-1.1, -0.5), Vector2(1.1, -0.5), Vector2(-1.1, 0.5), Vector2(1.1, 0.5)]:
		G.box(root, Vector3(0.08, 0.82, 0.08), Vector3(5.5 + off.x, 0.41, -8.5 + off.y), wood_dark, false)
	var knife := G.box(root, Vector3(0.03, 0.28, 0.06), Vector3(5.0, 1.0, -8.4), G.mat(Color(0.75, 0.77, 0.8), 0.0, 0.9, 0.25), false)
	knife.rotation.z = 0.25
	G.box(root, Vector3(0.04, 0.12, 0.05), Vector3(4.97, 1.18, -8.4), wood_dark, false)
	G.box(root, Vector3(0.45, 0.15, 0.32), Vector3(5.9, 0.965, -8.6), G.mat(Color(0.6, 0.22, 0.2)), false)

	# Fireplace on the south wall with a hanging pot.
	G.box(root, Vector3(0.4, 1.7, 0.8), Vector3(4.6, 0.85, -3.55), stone_dark)
	G.box(root, Vector3(0.4, 1.7, 0.8), Vector3(6.4, 0.85, -3.55), stone_dark)
	G.box(root, Vector3(2.4, 0.5, 0.9), Vector3(5.5, 1.95, -3.6), stone_dark)
	G.box(root, Vector3(1.0, 0.25, 0.45), Vector3(5.5, 0.12, -3.5), G.mat(Color(1.0, 0.45, 0.12), 5.0), false)
	G.box(root, Vector3(0.03, 0.9, 0.03), Vector3(5.5, 1.25, -3.6), G.mat(Color(0.1, 0.1, 0.1)), false)
	G.cylinder(root, 0.3, 0.4, Vector3(5.5, 0.65, -3.6), G.mat(Color(0.12, 0.12, 0.12), 0.0, 0.7, 0.5), 0.26)
	G.light(root, Vector3(5.5, 0.9, -4.3), Color(1.0, 0.55, 0.25), 3.0, 9.0, true)

	# Open cabinet full of vegetables, fruit and meat on the north wall.
	G.box(root, Vector3(2.4, 2.2, 0.05), Vector3(5.5, 1.1, -13.82), wood_dark, false)
	for x in [4.32, 6.68]:
		G.box(root, Vector3(0.06, 2.2, 0.5), Vector3(x, 1.1, -13.6), wood_dark, false)
	var foods := [Color(0.35, 0.6, 0.2), Color(0.9, 0.5, 0.1), Color(0.75, 0.15, 0.15), Color(0.85, 0.75, 0.4), Color(0.55, 0.25, 0.2)]
	var shelf_y := [0.5, 1.1, 1.7]
	for s in shelf_y.size():
		G.box(root, Vector3(2.3, 0.05, 0.5), Vector3(5.5, shelf_y[s], -13.6), wood, false)
		for k in 6:
			var c: Color = foods[(k + s * 2) % foods.size()]
			G.sphere(root, 0.09, Vector3(4.6 + k * 0.36, shelf_y[s] + 0.12, -13.58), G.mat(c))
	G.solid(root, Vector3(2.4, 2.2, 0.55), Vector3(5.5, 1.1, -13.6))
	G.torch(root, Vector3(2.0, 2.2, -3.15), Vector3(0, 0, -1), 1.5, 7.0)


func _toilet() -> void:
	G.floor_and_ceiling(root, 3.0, 6.0, -19.0, -23.0, 3.0, floor_mat, ceiling_mat)
	G.wall(root, Vector2(3.0, -19), Vector2(3.0, -23.15), 3.0, stone)
	G.wall(root, Vector2(6.0, -19), Vector2(6.0, -23.15), 3.0, stone)
	G.wall(root, Vector2(3.0, -23), Vector2(6.0, -23), 3.0, stone)
	var toilet_door = G.door(root, Vector3(3.9, 0, -19.0), Vector3(1, 0, 0), Vector3(0, 0, -1), DOOR_W, DOOR_H, wood, "door")
	toilet_door.locked = act == 0
	toilet_door.locked_message = "Locked. Occupied, by the sound of it."
	G.box(root, Vector3(2.0, 0.5, 0.75), Vector3(4.5, 0.25, -22.5), stone_dark)
	G.cylinder(root, 0.18, 0.02, Vector3(4.5, 0.51, -22.45), G.mat(Color(0.02, 0.02, 0.02)))
	G.torch(root, Vector3(5.85, 1.9, -21.0), Vector3(-1, 0, 0), 1.4, 5.0)


func _characters() -> void:
	# Guard 1 stands by the hall doors.
	var guard_hall = G.npc(root, NpcScript, "Guard", Vector3(13.3, 0, -32.6), PI, Color(0.25, 0.32, 0.5), "helmet")
	guard_hall.bark_key = "guard_hall"
	npcs["guard_hall"] = guard_hall

	# Guard 2 patrols the winding corridor.
	var guard_patrol = G.npc(root, NpcScript, "Guard", Vector3(0, 0, -4.0), 0.0, Color(0.25, 0.32, 0.5), "helmet")
	guard_patrol.bark_key = "guard_patrol"
	guard_patrol.patrol_points = [
		Vector3(0, 0, -4.0), Vector3(0, 0, -17.5), Vector3(12.5, 0, -17.5),
		Vector3(12.5, 0, -28.0), Vector3(12.5, 0, -17.5), Vector3(0, 0, -17.5),
	]
	npcs["guard_patrol"] = guard_patrol

	var king
	if act == 0:
		# Prelude: the king stands in the middle of his hall.
		king = G.npc(root, NpcScript, "King", Vector3(12.5, 0, -46.0), PI, Color(0.35, 0.15, 0.45), "crown")
		king.dialogue_id = "king_prelude"
	else:
		# Act 1: the king sits on his throne under the crest.
		king = G.npc(root, NpcScript, "King", Vector3(12.5, 0.4, -55.6), PI, Color(0.35, 0.15, 0.45), "crown")
		king.seated = true
		king.get_node("Visual").position.y = -0.45
		king.dialogue_id = "king_act1"
		king.done_flag = "act1_briefed"
		king.bark_key = "king_after_briefing"

		var cook = G.npc(root, NpcScript, "Cook", Vector3(3.2, 0, -5.5), 0.0, Color(0.7, 0.66, 0.6), "cook")
		cook.bark_key = "cook"
		cook.patrol_speed = 0.9
		cook.patrol_points = [Vector3(3.2, 0, -5.5), Vector3(7.8, 0, -5.5), Vector3(7.8, 0, -11.8), Vector3(3.2, 0, -11.8)]
		npcs["cook"] = cook
	npcs["king"] = king


## An original crest: a sun above a white peak on a deep blue shield.
func _crest(center: Vector3, scale: float, yaw: float) -> void:
	var c := Node3D.new()
	c.position = center
	c.rotation.y = yaw
	c.scale = Vector3.ONE * scale
	root.add_child(c)
	G.box(c, Vector3(0.9, 1.0, 0.05), Vector3(0, 0.05, 0), G.mat(Color(0.1, 0.16, 0.36)), false)
	var point := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.9, 0.35, 0.05)
	point.mesh = prism
	point.material_override = G.mat(Color(0.1, 0.16, 0.36))
	point.position = Vector3(0, -0.62, 0)
	point.rotation.z = PI
	c.add_child(point)
	var sun := G.cylinder(c, 0.17, 0.03, Vector3(0, 0.25, 0.04), gold)
	sun.rotation.x = PI * 0.5
	var peak := MeshInstance3D.new()
	var peak_mesh := PrismMesh.new()
	peak_mesh.size = Vector3(0.6, 0.45, 0.03)
	peak.mesh = peak_mesh
	peak.material_override = G.mat(Color(0.92, 0.94, 0.97))
	peak.position = Vector3(0, -0.2, 0.04)
	c.add_child(peak)


func _banner(pos: Vector3, normal: Vector3) -> void:
	var b := Node3D.new()
	b.position = pos
	b.rotation.y = atan2(-normal.x, -normal.z) + PI
	root.add_child(b)
	G.box(b, Vector3(1.5, 0.1, 0.1), Vector3(0, 1.85, 0.05), wood_dark, false)
	G.box(b, Vector3(1.3, 3.6, 0.04), Vector3(0, 0, 0.05), red_cloth, false)
	var emblem := Node3D.new()
	emblem.position = Vector3(0, 0.6, 0.08)
	emblem.scale = Vector3.ONE * 0.7
	b.add_child(emblem)
	var disc := G.cylinder(emblem, 0.25, 0.03, Vector3.ZERO, gold)
	disc.rotation.x = PI * 0.5


func _mountain_texture() -> ImageTexture:
	var w := 48
	var h := 36
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var t := float(y) / h
		for x in w:
			img.set_pixel(x, y, Color(0.45, 0.6, 0.8).lerp(Color(0.85, 0.9, 0.95), t))
	var peak_x := 26
	var peak_y := 6
	for y in range(peak_y, h):
		var half := int((y - peak_y) * 1.3)
		for x in range(maxi(0, peak_x - half), mini(w, peak_x + half + 1)):
			var snow := y < peak_y + 10 or (y < peak_y + 13 and (x + y) % 3 == 0)
			img.set_pixel(x, y, Color(0.96, 0.97, 1.0) if snow else Color(0.38, 0.4, 0.46))
	for y in range(h - 5, h):
		for x in w:
			img.set_pixel(x, y, Color(0.92, 0.94, 0.97))
	return ImageTexture.create_from_image(img)
