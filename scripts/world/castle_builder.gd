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
const S := preload("res://scripts/world/surfaces.gd")
const D := preload("res://scripts/world/decor.gd")
const P := preload("res://scripts/world/props.gd")
const F := preload("res://scripts/world/furniture.gd")
const H := preload("res://scripts/world/heraldry.gd")

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
var entrance_doors

var stone: Material
var stone_dark: Material
var floor_mat: Material
var ceiling_mat: Material
var wood: Material
var wood_dark: Material
var plaster: Material


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
	_architecture()
	_dressing()
	_characters()

	var hall_trigger := Area3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 2.0)
	cs.shape = shape
	hall_trigger.position = Vector3(12.5, 1.5, -35.5)
	hall_trigger.add_child(cs)
	root.add_child(hall_trigger)

	# The kitchen's yard door stays bolted; the castle is left by the entrance doors.
	var yard = G.door(root, Vector3(9.28, 0, -7.3), Vector3(0, 0, -1), Vector3.ZERO, 2.4, 2.9, wood_dark, "yard door", true)
	yard.locked = true
	yard.locked_message = "The yard door is bolted. The way out is through the great doors at the entrance."

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
		"exit_door": entrance_doors,
	}


func _materials() -> void:
	stone = D.stone()
	stone_dark = S.get_material("stone_wall", Color(0.46, 0.44, 0.42), 1.6)
	floor_mat = S.get_material("flagstone", Color(0.66, 0.63, 0.6), 3.0)
	ceiling_mat = S.get_material("wood_dark", Color(0.42, 0.4, 0.38), 2.5)
	wood = D.wood()
	wood_dark = D.wood_dark()
	plaster = S.get_material("plaster", Color(0.74, 0.7, 0.64), 3.0)


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

	# The entrance doors (where the prelude starts) lead out of the castle in
	# Act 1. The great doors at the far end of the corridor stay barred.
	entrance_doors = G.door(root, Vector3(-1.3, 0, -0.22), Vector3(1, 0, 0), Vector3.ZERO, 2.6, 3.2, wood_dark, "entrance doors", true)
	entrance_doors.locked = true
	entrance_doors.locked_message = "Not now. The king is waiting for your message."
	if act >= 1:
		entrance_doors.use_prompt = "Leave the castle"
	var far_doors = G.door(root, Vector3(-1.3, 0, -18.78), Vector3(1, 0, 0), Vector3.ZERO, 2.6, 3.2, wood_dark, "great doors", true)
	far_doors.locked = true
	far_doors.locked_message = "The great doors are barred from the other side."

	# Five locked side doors, flush against the walls.
	_locked(Vector3(-1.28, 0, -13.4), Vector3(0, 0, -1))
	_locked(Vector3(8.4, 0, -16.22), Vector3(1, 0, 0))
	_locked(Vector3(11.22, 0, -23.4), Vector3(0, 0, -1))
	_locked(Vector3(11.22, 0, -29.4), Vector3(0, 0, -1))
	_locked(Vector3(13.78, 0, -26.4), Vector3(0, 0, -1))

	# The kingdom's shield above the hall entrance (corridor side), and
	# banners on the way to the hall.
	H.shield(root, Vector3(12.5, 4.3, -33.85), Vector3(0, 0, 1), "shield_sun_pale", 1.0)
	H.banner(root, Vector3(-1.35, 3.7, -4.8), Vector3(1, 0, 0), 0.75)
	H.banner(root, Vector3(1.35, 3.7, -2.8), Vector3(-1, 0, 0), 0.75)
	H.banner(root, Vector3(11.15, 4.7, -32.4), Vector3(1, 0, 0), 0.85)
	H.banner(root, Vector3(13.85, 4.7, -29.0), Vector3(-1, 0, 0), 0.85)

	# Torches.
	G.torch(root, Vector3(-1.35, 2.4, -3.0), Vector3(1, 0, 0))
	G.torch(root, Vector3(1.35, 2.4, -13.0), Vector3(-1, 0, 0))
	G.torch(root, Vector3(-1.35, 2.4, -17.5), Vector3(1, 0, 0))
	G.torch(root, Vector3(7.0, 2.4, -16.15), Vector3(0, 0, -1))
	G.torch(root, Vector3(11.15, 2.4, -21.0), Vector3(1, 0, 0))
	G.torch(root, Vector3(13.85, 2.4, -31.5), Vector3(-1, 0, 0))


func _kings_hall() -> void:
	G.floor_and_ceiling(root, 2.5, 22.5, -34.0, -58.0, HALL_H, S.get_material("flagstone", Color(0.7, 0.66, 0.62), 4.0), ceiling_mat)
	G.wall(root, Vector2(2.35, -34), Vector2(22.65, -34), HALL_H, stone, [[12.5, 3.0, 3.4]])
	G.wall(root, Vector2(2.35, -58), Vector2(22.65, -58), HALL_H, stone)
	G.wall(root, Vector2(2.5, -34), Vector2(2.5, -58), HALL_H, stone)
	G.wall(root, Vector2(22.5, -34), Vector2(22.5, -58), HALL_H, stone)

	# Open double doors into the hall.
	var hall_doors = G.door(root, Vector3(11.05, 0, -34.0), Vector3(1, 0, 0), Vector3(0, 0, -1), 2.9, 3.3, wood, "hall doors", true)
	hall_doors.set_open(true, true)

	# Carpet runner to the throne.
	D.rug(root, Vector3(12.5, 0, -45.0), Vector2(2.6, 21.0), Color(0.6, 0.07, 0.08), Color(0.85, 0.62, 0.22))

	# The great shield of the kingdom on the far wall, flanked by two
	# standing flags.
	H.shield(root, Vector3(12.5, 5.8, -57.85), Vector3(0, 0, 1), "shield_sun_bend", 3.2)
	H.standard(root, Vector3(8.0, 0, -57.35), 0.0, 1.6)
	H.standard(root, Vector3(14.3, 0, -57.35), 0.0, 1.6)

	# Throne under the crest.
	G.box(root, Vector3(2.0, 0.4, 1.8), Vector3(12.5, 0.2, -55.9), stone_dark)
	F.throne(root, Vector3(12.5, 0.4, -55.95), PI, Color(0.42, 0.08, 0.1))

	# The kingdom's banners on both side walls, hanging still.
	for z in [-38.0, -44.0, -50.0]:
		H.banner(root, Vector3(2.65, 7.3, z), Vector3(1, 0, 0), 1.4)
		H.banner(root, Vector3(22.35, 7.3, z), Vector3(-1, 0, 0), 1.4)

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

	# Light: two chandeliers and two braziers by the throne.
	D.chandelier(root, Vector3(12.5, 6.2, -40.0), HALL_H)
	D.chandelier(root, Vector3(12.5, 6.2, -50.0), HALL_H)
	for x in [9.5, 15.5]:
		G.cylinder(root, 0.35, 1.0, Vector3(x, 0.5, -54.5), stone_dark, 0.45)
		G.cylinder(root, 0.5, 0.15, Vector3(x, 1.05, -54.5), D.iron(), 0.42)
		G.sphere(root, 0.22, Vector3(x, 1.08, -54.5), G.mat(Color(1.0, 0.45, 0.12), 3.0))
		G.flame(root, Vector3(x, 1.15, -54.5), 2.2)
		G.light(root, Vector3(x, 1.9, -54.0), Color(1.0, 0.6, 0.3), 2.2, 9.0, true, 0.25)


func _player_room() -> void:
	G.floor_and_ceiling(root, -7.5, -1.5, -4.0, -10.0, ROOM_H, S.get_material("wood_floor", Color(0.72, 0.68, 0.64), 2.2), ceiling_mat)
	G.wall(root, Vector2(-7.65, -4), Vector2(-1.5, -4), ROOM_H, plaster)
	G.wall(root, Vector2(-7.65, -10), Vector2(-1.5, -10), ROOM_H, plaster)
	G.wall(root, Vector2(-7.5, -4), Vector2(-7.5, -10), ROOM_H, plaster)

	var room_door = G.door(root, Vector3(-1.5, 0, -6.4), Vector3(0, 0, -1), Vector3(-1, 0, 0), DOOR_W, DOOR_H, wood, "door")
	room_door.locked = act == 0
	room_door.locked_message = "Locked. Someone's private chamber, no doubt."

	# Bed against the south wall.
	F.bed(root, Vector3(-6.4, 0, -4.7), 0.0, 2.0, 1.1, Color(0.3, 0.34, 0.46))
	G.prop(root, Vector3(2.0, 0.7, 1.1), Vector3(-6.4, 0.35, -4.7), null, "Look at the bed", "Your bed. You slept like a stone after the feast.")

	# Window on the west wall: bright daylight.
	var daylight := G.mat(Color(0.92, 0.96, 1.0), 3.0)
	G.box(root, Vector3(0.06, 1.3, 1.0), Vector3(-7.33, 1.9, -7.0), daylight, false)
	G.box(root, Vector3(0.1, 1.4, 0.08), Vector3(-7.3, 1.9, -7.0), wood_dark, false)
	G.box(root, Vector3(0.1, 0.08, 1.1), Vector3(-7.3, 1.9, -7.0), wood_dark, false)
	G.prop(root, Vector3(0.3, 1.3, 1.0), Vector3(-7.2, 1.9, -7.0), null, "Look out the window", "Bright daylight pours in. The sun still shines... for now.")
	G.light(root, Vector3(-6.6, 2.0, -7.0), Color(0.9, 0.95, 1.0), 1.0 if act >= 1 else 0.3, 6.0)
	if act >= 1:
		var sun := SpotLight3D.new()
		sun.position = Vector3(-7.1, 2.4, -7.0)
		sun.rotation = Vector3(deg_to_rad(-32.0), deg_to_rad(-90.0), 0)
		sun.light_color = Color(1.0, 0.95, 0.85)
		sun.light_energy = 6.0
		sun.spot_range = 9.0
		sun.spot_angle = 24.0
		sun.light_volumetric_fog_energy = 3.0
		sun.shadow_enabled = true
		root.add_child(sun)
		G.dust(root, Vector3(-4.5, 1.6, -7.0), Vector3(2.6, 1.3, 2.6), 90)

	# Writing table with a lit candle, and a chair.
	F.joined_table(root, Vector3(-2.6, 0, -9.3), Vector3(1.2, 0.78, 0.7))
	P.candle_holder(root, Vector3(-2.3, 0.78, -9.45))
	P.inkwell_and_quill(root, Vector3(-2.75, 0.78, -9.5))
	P.book_stack(root, Vector3(-3.0, 0.78, -9.2), 3)
	G.light(root, Vector3(-2.3, 1.15, -9.2), Color(1.0, 0.75, 0.45), 1.2, 5.0, true, 0.12)
	F.chair(root, Vector3(-2.55, 0, -8.45), 0.08)

	# Mirror on the north wall.
	G.box(root, Vector3(0.85, 1.45, 0.03), Vector3(-4.6, 1.6, -9.84), wood_dark, false)
	G.box(root, Vector3(0.7, 1.3, 0.03), Vector3(-4.6, 1.6, -9.81), G.mat(Color(0.8, 0.85, 0.9), 0.0, 1.0, 0.05), false)
	G.prop(root, Vector3(0.85, 1.45, 0.2), Vector3(-4.6, 1.6, -9.75), null, "Look in the mirror", "Casimir Vael of Hollowmere looks back at you, well rested at last.")

	# Small table with a pot and a single flower (blooming in Act 1; it withers act by act).
	F.round_table(root, Vector3(-6.9, 0, -9.4), 0.26, 0.72)
	P.potted_flower(root, Vector3(-6.9, 0.72, -9.4), 0.0)
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
	G.floor_and_ceiling(root, 1.5, 9.5, -3.0, -14.0, ROOM_H, S.get_material("flagstone", Color(0.6, 0.57, 0.54), 2.2), ceiling_mat)
	G.wall(root, Vector2(1.5, -3), Vector2(9.65, -3), ROOM_H, stone)
	G.wall(root, Vector2(1.5, -14), Vector2(9.65, -14), ROOM_H, stone)
	G.wall(root, Vector2(9.5, -3), Vector2(9.5, -14), ROOM_H, stone)

	var kitchen_door = G.door(root, Vector3(1.5, 0, -8.4), Vector3(0, 0, -1), Vector3(1, 0, 0), DOOR_W, DOOR_H, wood, "door")
	kitchen_door.locked = act == 0
	kitchen_door.locked_message = "Locked. You can smell something cooking."

	# Table with a knife stuck in it and a piece of meat.
	D.table(root, Vector3(5.5, 0, -8.5), Vector3(2.4, 0.89, 1.2))
	var top := 0.89
	P.knife_stuck(root, Vector3(4.95, top, -8.35), 0.4, 0.28)
	P.cutting_board(root, Vector3(5.85, top, -8.55), 0.1)
	F.stool(root, Vector3(8.95, 0, -8.2))
	F.stool(root, Vector3(2.25, 0, -10.6))
	P.roast(root, Vector3(5.8, top + 0.03, -8.55), 0.1)
	P.bread(root, Vector3(4.55, top, -8.85), 0.6)
	P.cheese(root, Vector3(6.45, top, -8.15))
	P.onion(root, Vector3(4.6, top, -8.2))
	P.onion(root, Vector3(4.68, top, -8.12))
	P.carrot(root, Vector3(5.1, top, -8.95), 0.3)
	P.carrot(root, Vector3(5.15, top, -9.0), 0.1)
	P.jug(root, Vector3(6.55, top, -8.95), Color(0.62, 0.42, 0.3), 2.0)
	P.bowl(root, Vector3(4.3, top, -8.4), 0.1)

	# Fireplace on the south wall with a hanging pot.
	G.box(root, Vector3(0.4, 1.7, 0.8), Vector3(4.6, 0.85, -3.55), stone_dark)
	G.box(root, Vector3(0.4, 1.7, 0.8), Vector3(6.4, 0.85, -3.55), stone_dark)
	G.box(root, Vector3(2.4, 0.5, 0.9), Vector3(5.5, 1.95, -3.6), stone_dark)
	G.box(root, Vector3(1.0, 0.25, 0.45), Vector3(5.5, 0.12, -3.5), G.mat(Color(1.0, 0.45, 0.12), 5.0), false)
	G.box(root, Vector3(0.03, 0.9, 0.03), Vector3(5.5, 1.25, -3.6), G.mat(Color(0.1, 0.1, 0.1)), false)
	P.cooking_pot(root, Vector3(5.5, 0.4, -3.6), 0.26)
	P.ladle(root, Vector3(6.4, 1.55, -4.0))
	P.pan(root, Vector3(4.0, 1.7, -3.15), Vector3(0, 0, -1))
	P.pan(root, Vector3(3.55, 1.6, -3.15), Vector3(0, 0, -1))
	P.firewood(root, Vector3(7.2, 0, -3.55), 3)
	P.bucket(root, Vector3(3.6, 0, -3.5))
	for hx in [3.0, 4.2, 6.8, 8.0]:
		P.herb_bundle(root, Vector3(hx, ROOM_H - 0.28, -11.0), Color(0.35, 0.5, 0.22) if hx < 5.0 else Color(0.5, 0.45, 0.25))
	G.flame(root, Vector3(5.2, 0.2, -3.5), 2.0)
	G.flame(root, Vector3(5.8, 0.2, -3.55), 1.8)
	G.light(root, Vector3(5.5, 0.9, -4.3), Color(1.0, 0.55, 0.25), 3.0, 9.0, true, 0.3)

	# Open cabinet full of vegetables, fruit and meat on the north wall.
	G.box(root, Vector3(2.4, 2.2, 0.05), Vector3(5.5, 1.1, -13.82), wood_dark, false)
	for x in [4.32, 6.68]:
		G.box(root, Vector3(0.06, 2.2, 0.5), Vector3(x, 1.1, -13.6), wood_dark, false)
	var shelf_y := [0.5, 1.1, 1.7]
	for y in shelf_y:
		G.box(root, Vector3(2.3, 0.05, 0.5), Vector3(5.5, y, -13.6), wood, false)
	var z := -13.6
	# Bottom shelf: cabbages and a basket of potatoes.
	var b0: float = shelf_y[0] + 0.025
	P.cabbage(root, Vector3(4.6, b0, z))
	P.cabbage(root, Vector3(4.85, b0, z + 0.08))
	var fill := P.basket(root, Vector3(5.6, b0, z), 0.18, 0.13)
	for i in 6:
		P.potato(root, Vector3(5.6 + (i % 3 - 1) * 0.07, b0 + fill - 0.02 + (i / 3) * 0.025, z + (i % 2 - 0.5) * 0.08), i * 0.9)
	for i in 5:
		P.potato(root, Vector3(6.15 + (i % 3) * 0.08, b0, z + (i / 3) * 0.09 - 0.04), i * 1.3)
	# Middle shelf: a basket of apples, pears, onions.
	var b1: float = shelf_y[1] + 0.025
	var afill := P.basket(root, Vector3(4.75, b1, z), 0.17, 0.11)
	for i in 7:
		var a := TAU * i / 7.0
		P.apple(root, Vector3(4.75 + cos(a) * 0.08, b1 + afill - 0.03, z + sin(a) * 0.08), Color(0.72, 0.1, 0.08) if i % 3 else Color(0.55, 0.65, 0.15))
	P.apple(root, Vector3(4.75, b1 + afill + 0.02, z))
	for i in 3:
		P.pear(root, Vector3(5.35 + i * 0.09, b1, z + (i % 2) * 0.06))
	for i in 6:
		P.onion(root, Vector3(5.95 + (i % 3) * 0.085, b1, z - 0.06 + (i / 3) * 0.09))
	# Top shelf: bread, cheese wheels and jugs.
	var b2: float = shelf_y[2] + 0.025
	P.bread(root, Vector3(4.65, b2, z), 0.1)
	P.bread(root, Vector3(4.85, b2, z + 0.1), -0.2)
	P.cheese(root, Vector3(5.45, b2, z))
	P.cheese(root, Vector3(5.45, b2 + 0.08, z))
	P.jug(root, Vector3(6.0, b2, z), Color(0.55, 0.4, 0.3), 1.2)
	P.jug(root, Vector3(6.35, b2, z + 0.05), Color(0.4, 0.35, 0.3), 2.5)
	# Hanging meat under the cabinet top.
	G.box(root, Vector3(2.3, 0.03, 0.03), Vector3(5.5, 2.12, -13.45), D.iron(), false)
	P.sausages(root, Vector3(4.7, 2.1, -13.45), 4)
	P.ham(root, Vector3(5.6, 2.1, -13.45))
	P.sausages(root, Vector3(6.35, 2.1, -13.45), 3)
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
	P.bucket(root, Vector3(3.35, 0, -21.6))


func _architecture() -> void:
	var x_axis := Vector3(1, 0, 0)
	var z_axis := Vector3(0, 0, 1)
	# Door frames around every doorway (open, locked and barred).
	D.door_frame(root, Vector3(-1.5, 0, -7.0), z_axis, x_axis, GAP_W, GAP_H)
	D.door_frame(root, Vector3(1.5, 0, -9.0), z_axis, x_axis, GAP_W, GAP_H)
	D.door_frame(root, Vector3(4.5, 0, -19.0), x_axis, z_axis, GAP_W, GAP_H)
	D.door_frame(root, Vector3(12.5, 0, -34.0), x_axis, z_axis, 3.0, 3.4)
	D.door_frame(root, Vector3(-1.5, 0, -14.0), z_axis, x_axis, DOOR_W, DOOR_H, false)
	D.door_frame(root, Vector3(9.0, 0, -16.0), x_axis, -z_axis, DOOR_W, DOOR_H, false)
	D.door_frame(root, Vector3(11.0, 0, -24.0), z_axis, x_axis, DOOR_W, DOOR_H, false)
	D.door_frame(root, Vector3(11.0, 0, -30.0), z_axis, x_axis, DOOR_W, DOOR_H, false)
	D.door_frame(root, Vector3(14.0, 0, -27.0), z_axis, -x_axis, DOOR_W, DOOR_H, false)
	D.door_frame(root, Vector3(20.75, 3.5, -58.0), x_axis, z_axis, DOOR_W, DOOR_H, false)
	D.door_frame(root, Vector3(0, 0, 0.0), x_axis, -z_axis, 2.6, 3.2, false)
	D.door_frame(root, Vector3(0, 0, -19.0), x_axis, z_axis, 2.6, 3.2, false)

	# Ceiling beams.
	for z in [-2.5, -5.5, -8.5, -11.5, -14.5, -17.5]:
		D.beam(root, Vector3(0, CORRIDOR_H - 0.14, z), 3.0, "x")
	for x in [4.0, 7.0, 10.0]:
		D.beam(root, Vector3(x, CORRIDOR_H - 0.14, -17.5), 3.0, "z")
	for z in [-21.0, -24.5, -28.0, -31.5]:
		D.beam(root, Vector3(12.5, CORRIDOR_C_H - 0.14, z), 3.0, "x")
	for z in [-5.0, -8.0, -11.0, -13.5]:
		D.beam(root, Vector3(5.5, ROOM_H - 0.14, z), 8.0, "x")
	for z in [-5.5, -8.5]:
		D.beam(root, Vector3(-4.5, ROOM_H - 0.14, z), 6.0, "x")

	# The hall: two rows of pillars and heavy roof beams.
	for z in [-38.0, -44.0, -50.0]:
		D.pillar(root, Vector3(6.5, 0, z), HALL_H)
		D.pillar(root, Vector3(18.0, 0, z), HALL_H)
	for z in [-35.0, -41.0, -47.0, -53.0, -57.0]:
		G.box(root, Vector3(20.0, 0.5, 0.45), Vector3(12.5, HALL_H - 0.25, z), wood_dark, false)
	G.torch(root, Vector3(6.9, 2.6, -44.0), Vector3(1, 0, 0), 1.8, 9.0)
	G.torch(root, Vector3(17.6, 2.6, -44.0), Vector3(-1, 0, 0), 1.8, 9.0)
	G.dust(root, Vector3(12.5, 3.0, -46.0), Vector3(8.0, 2.5, 10.0), 160)


func _dressing() -> void:
	# Corridor: shields, barrels and crates.
	H.shield(root, Vector3(-1.35, 2.3, -10.5), Vector3(1, 0, 0), "shield_sun_bend", 0.7)
	H.shield(root, Vector3(1.35, 2.3, -5.0), Vector3(-1, 0, 0), "shield_sun_pale", 0.7)
	H.shield(root, Vector3(11.15, 2.6, -27.0), Vector3(1, 0, 0), "shield_sun_pale", 0.7)
	H.shield(root, Vector3(13.85, 2.6, -23.5), Vector3(-1, 0, 0), "shield_sun_bend", 0.7)
	D.barrel(root, Vector3(-1.0, 0, -0.65))
	D.barrel(root, Vector3(1.0, 0, -0.7))
	D.crate(root, Vector3(-1.0, 0, -18.35), 0.6, 0.2)
	D.crate(root, Vector3(-1.0, 0.6, -18.35), 0.45, -0.3)

	# King's hall: feasting tables with benches, plates and candles.
	for tx in [8.8, 16.2]:
		D.table(root, Vector3(tx, 0, -42.0), Vector3(1.0, 0.8, 9.0))
		D.bench(root, Vector3(tx - 0.75, 0, -42.0), 8.5)
		D.bench(root, Vector3(tx + 0.75, 0, -42.0), 8.5)
		for i in 6:
			var z := -38.5 - i * 1.4
			P.plate(root, Vector3(tx - 0.27, 0.8, z))
			P.plate(root, Vector3(tx + 0.27, 0.8, z))
			P.goblet(root, Vector3(tx - 0.3, 0.8, z - 0.25))
			P.goblet(root, Vector3(tx + 0.3, 0.8, z + 0.25))
		for z in [-39.2, -42.0, -44.8]:
			P.candle_holder(root, Vector3(tx, 0.8, z))
		P.bowl(root, Vector3(tx, 0.8, -40.6), 0.14)
		for i in 5:
			var a := TAU * i / 5.0
			P.apple(root, Vector3(tx + cos(a) * 0.06, 0.84, -40.6 + sin(a) * 0.06), Color(0.72, 0.1, 0.08) if i % 2 else Color(0.85, 0.6, 0.12))
		P.bread(root, Vector3(tx, 0.8, -43.4), 1.57)
		P.jug(root, Vector3(tx, 0.8, -46.0), Color(0.6, 0.42, 0.3), 0.5)
	for z in [-41.0, -47.0]:
		H.shield(root, Vector3(2.65, 3.1, z), Vector3(1, 0, 0), "shield_sun_pale", 1.1)
		H.shield(root, Vector3(22.35, 3.3, z), Vector3(-1, 0, 0), "shield_sun_bend", 1.1)

	# Casimir's room: rug, chest, shelf of books.
	D.rug(root, Vector3(-4.4, 0, -7.0), Vector2(2.4, 1.7), Color(0.5, 0.12, 0.1), Color(0.75, 0.6, 0.3))
	F.chest(root, Vector3(-5.07, 0, -4.75), -PI * 0.5, Vector3(0.95, 0.48, 0.5))
	D.shelf(root, Vector3(-2.6, 0.75, -9.85), Vector3(0, 0, 1), 1.2, 2, 7)

	# Kitchen: barrels, sacks, a crate and a shelf of jars.
	D.barrel(root, Vector3(8.85, 0, -3.7))
	D.barrel(root, Vector3(8.2, 0, -3.65), 0.75)
	D.sack(root, Vector3(8.9, 0, -13.35))
	D.sack(root, Vector3(8.35, 0, -13.45), Color(0.68, 0.6, 0.45))
	D.crate(root, Vector3(2.15, 0, -13.3), 0.7, 0.15)
	D.shelf(root, Vector3(1.65, 0.6, -5.5), Vector3(1, 0, 0), 1.6, 2, 11)


func _characters() -> void:
	# Guard 1 stands by the hall doors.
	var guard_hall = G.npc(root, NpcScript, "Guard", Vector3(13.3, 0, -32.6), PI, "guard")
	guard_hall.bark_key = "guard_hall"
	npcs["guard_hall"] = guard_hall

	# Guard 2 patrols the winding corridor.
	var guard_patrol = G.npc(root, NpcScript, "Guard", Vector3(0, 0, -4.0), 0.0, "guard_patrol")
	guard_patrol.bark_key = "guard_patrol"
	guard_patrol.patrol_points = [
		Vector3(0, 0, -4.0), Vector3(0, 0, -17.5), Vector3(12.5, 0, -17.5),
		Vector3(12.5, 0, -28.0), Vector3(12.5, 0, -17.5), Vector3(0, 0, -17.5),
	]
	npcs["guard_patrol"] = guard_patrol

	var king
	if act == 0:
		# Prelude: the king stands in the middle of his hall.
		king = G.npc(root, NpcScript, "King", Vector3(12.5, 0, -46.0), PI, "king")
		king.dialogue_id = "king_prelude"
	else:
		# Act 1: the king sits on his throne under the crest.
		king = G.npc(root, NpcScript, "King", Vector3(12.5, 0.4, -55.95), PI, "king")
		king.seated = true
		king.dialogue_id = "king_act1"
		king.done_flag = "act1_briefed"
		king.bark_key = "king_after_briefing"

		var cook = G.npc(root, NpcScript, "Cook", Vector3(3.2, 0, -5.5), 0.0, "cook")
		cook.bark_key = "cook"
		cook.patrol_speed = 0.9
		cook.patrol_points = [Vector3(3.2, 0, -5.5), Vector3(7.8, 0, -5.5), Vector3(7.8, 0, -11.8), Vector3(3.2, 0, -11.8)]
		npcs["cook"] = cook
	npcs["king"] = king


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
