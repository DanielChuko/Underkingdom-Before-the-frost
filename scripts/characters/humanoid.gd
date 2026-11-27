extends Node3D
## A procedurally built, procedurally animated humanoid.
##
## The body is a small joint hierarchy (pelvis, chest, neck, head, shoulders,
## elbows, hips, knees). Each joint carries smooth meshes lofted in code by
## mesh_lib.gd: a sculpted head and face, a shaped torso, tapering limbs, hands
## and boots. Clothing is layered on top (mail, surcoats, robes, aprons, fur),
## dressed from a "look" in res://data/characters.json and textured with the
## generated character textures. Vertex colours add grime toward hems and boots,
## stains, and skin shading. Everything faces local -Z.
##
## Animation is computed every frame instead of using keyframes:
##   - a heavy, tired walk cycle driven by `speed` (metres per second)
##   - idle breathing, slouch and weight shift
##   - "sit" pose for the king's throne
##   - talking: mouth movement, small nods and a restrained hand gesture
##   - the head slowly turns to look at the camera when it is close

const G := preload("res://scripts/world/greybox.gd")
const S := preload("res://scripts/world/surfaces.gd")
const P := preload("res://scripts/world/props.gd")
const M := preload("res://scripts/characters/mesh_lib.gd")
const LOOKS_PATH := "res://data/characters.json"

const HIP_HEIGHT := 0.93
const STRIDE := 1.35  # metres per full walk cycle (two steps)

## Average albedo of each generated texture, so a look's colour comes out as
## that colour once the texture is multiplied in.
const TEXTURE_MEAN := {
	"chainmail": Color(0.41, 0.41, 0.41), "leather": Color(0.29, 0.21, 0.15),
	"wool": Color(0.68, 0.66, 0.63), "skin": Color(0.87, 0.85, 0.83),
	"rust_metal": Color(0.31, 0.3, 0.3), "fur": Color(0.55, 0.53, 0.5),
	"cloth": Color(0.78, 0.78, 0.78), "quilted": Color(0.68, 0.65, 0.6),
}
const TEXTURE_TILE := {
	"chainmail": 0.12, "leather": 0.35, "wool": 0.3, "skin": 0.25,
	"rust_metal": 0.3, "fur": 0.25, "cloth": 0.4, "quilted": 0.32,
}

static var _looks: Dictionary = {}
static var _materials: Dictionary = {}

## "stand" or "sit"
var pose := "stand"
## Current ground speed of the character, set by the owner each frame.
var speed := 0.0
var look_at_camera := true

var look: Dictionary = {}
var pelvis: Node3D
var chest: Node3D
var neck: Node3D
var head: Node3D
var mouth: Node3D
var l_shoulder: Node3D
var r_shoulder: Node3D
var l_elbow: Node3D
var r_elbow: Node3D
var l_hip: Node3D
var r_hip: Node3D
var l_knee: Node3D
var r_knee: Node3D
var front_panel: Node3D
var back_panel: Node3D
var cape: Node3D
var robe: Node3D
var spear: Node3D

var _phase := 0.0
var _walk := 0.0
var _time := 0.0
var _talk := 0.0
var _head_yaw := 0.0
var _head_pitch := 0.0
var _gesture := 0.0
var _slouch := 0.0
var _belly := false
var _pelvis_y := HIP_HEIGHT + 0.02
var _sit_y := 0.55
## An imported model's face with blend shapes (jawOpen, eyeBlink...), if any.
var _face_mi: MeshInstance3D
var _blink := 0.0
var _next_blink := 2.0


static func load_look(look_id: String) -> Dictionary:
	if _looks.is_empty():
		var f := FileAccess.open(LOOKS_PATH, FileAccess.READ)
		if f != null:
			var data = JSON.parse_string(f.get_as_text())
			if typeof(data) == TYPE_DICTIONARY:
				_looks = data
	var l = _looks.get(look_id, {})
	if typeof(l) != TYPE_DICTIONARY or l.is_empty():
		push_warning("Humanoid: unknown look '%s'" % look_id)
		return {}
	return l


func build(look_id: String) -> void:
	look = load_look(look_id)
	_time = randf() * 10.0
	_slouch = float(look.get("slouch", 0.0))
	_belly = bool(look.get("belly", false))

	# --- Skeleton -------------------------------------------------------------
	# Joint positions in the rest pose, feet at the origin. An imported model
	# brings its own proportions (written by tools/rig_model_v2.py).
	var model_path := str(look.get("model", ""))
	var rig := _default_rig()
	var model_rig := _load_rig(model_path)
	for k in model_rig:
		rig[k] = model_rig[k]
	var p: Vector3 = rig["pelvis"]
	_pelvis_y = p.y
	# Seated, the pelvis sits just above knee height so the feet reach the floor.
	_sit_y = maxf(float(rig["l_knee"].y) + 0.04, 0.52)
	pelvis = _joint(self, p)
	chest = _joint(pelvis, rig["chest"] - p)
	neck = _joint(chest, rig["neck"] - rig["chest"])
	head = _joint(neck, rig["head"] - rig["neck"])
	l_shoulder = _joint(chest, rig["l_shoulder"] - rig["chest"])
	r_shoulder = _joint(chest, rig["r_shoulder"] - rig["chest"])
	# Limbs hang straight down from each joint at rest.
	l_elbow = _joint(l_shoulder, Vector3(0, -rig["l_shoulder"].distance_to(rig["l_elbow"]), 0))
	r_elbow = _joint(r_shoulder, Vector3(0, -rig["r_shoulder"].distance_to(rig["r_elbow"]), 0))
	l_hip = _joint(pelvis, rig["l_hip"] - p)
	r_hip = _joint(pelvis, rig["r_hip"] - p)
	l_knee = _joint(l_hip, Vector3(0, -rig["l_hip"].distance_to(rig["l_knee"]), 0))
	r_knee = _joint(r_hip, Vector3(0, -rig["r_hip"].distance_to(rig["r_knee"]), 0))

	if model_path != "" and ResourceLoader.exists(model_path):
		_build_from_model(model_path)
		if str(look.get("weapon", "")) == "spear":
			_build_spear()
		return
	_build_body()
	_build_head()
	_build_costume()


## Starts the talking animation for `duration` seconds.
func speak(duration: float) -> void:
	_talk = maxf(_talk, duration)


# --- Imported models ------------------------------------------------------------------

func _default_rig() -> Dictionary:
	var hip := HIP_HEIGHT + 0.02
	return {
		"pelvis": Vector3(0, hip, 0), "chest": Vector3(0, hip + 0.28, 0),
		"neck": Vector3(0, hip + 0.53, 0), "head": Vector3(0, hip + 0.62, 0),
		"l_shoulder": Vector3(-0.2, hip + 0.47, 0), "r_shoulder": Vector3(0.2, hip + 0.47, 0),
		"l_elbow": Vector3(-0.2, hip + 0.18, 0), "r_elbow": Vector3(0.2, hip + 0.18, 0),
		"l_hip": Vector3(-0.095, hip - 0.02, 0), "r_hip": Vector3(0.095, hip - 0.02, 0),
		"l_knee": Vector3(-0.095, hip - 0.46, 0), "r_knee": Vector3(0.095, hip - 0.46, 0),
	}


## Joint positions saved next to an imported model as <model>.rig.json.
func _load_rig(model_path: String) -> Dictionary:
	var out := {}
	if model_path == "":
		return out
	var f := FileAccess.open(model_path.get_basename() + ".rig.json", FileAccess.READ)
	if f == null:
		return out
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return out
	for k in data:
		var v = data[k]
		if typeof(v) == TYPE_ARRAY and v.size() == 3:
			out[k] = Vector3(float(v[0]), float(v[1]), float(v[2]))
	return out


## Dresses the rig in a multi-part model prepared by tools/rig_model.py: every
## part is a node named "<joint>__<part>" whose geometry is already in that
## joint's local space, so it only has to be moved under the joint to walk,
## turn its head and talk with the rest of the rig.
func _build_from_model(path: String) -> void:
	var packed = load(path)
	if packed == null or not (packed is PackedScene):
		push_warning("Humanoid: could not load model %s" % path)
		return
	front_panel = _joint(pelvis, Vector3(0, -0.02, 0))
	back_panel = _joint(pelvis, Vector3(0, -0.02, 0))
	cape = _joint(chest, Vector3.ZERO)
	var joints := {
		"cape": cape,
		"pelvis": pelvis, "chest": chest, "neck": neck, "head": head,
		"front_panel": front_panel, "back_panel": back_panel,
		"l_shoulder": l_shoulder, "r_shoulder": r_shoulder, "l_elbow": l_elbow, "r_elbow": r_elbow,
		"l_hip": l_hip, "r_hip": r_hip, "l_knee": l_knee, "r_knee": r_knee,
	}
	var inst: Node = packed.instantiate()
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var bits := String(mi.name).split("__", true, 1)
		if bits.size() < 2 or not joints.has(bits[0]):
			continue
		var local := mi.transform
		mi.get_parent().remove_child(mi)
		var joint: Node3D = joints[bits[0]]
		joint.add_child(mi)
		mi.transform = local
		if mi.mesh != null and mi.mesh.get_blend_shape_count() > 0:
			_face_mi = mi
		elif bits[1] == "Mouth" and _face_mi == null:
			mouth = mi
	if _face_mi != null:
		mouth = null
	inst.free()


# --- Body ---------------------------------------------------------------------------

func _build_body() -> void:
	var skin := _mat("skin", _c("skin", "#b88a70"))
	var torso_mat := _mat(str(look.get("torso", "wool")), _c("shirt", "#8a8070"))
	var trousers := _mat("wool", _c("trousers", "#3a3128"))
	var boots := _mat("leather", _c("boots", "#2a1f17"))
	var gloves := skin
	if look.has("mittens"):
		gloves = _mat("chainmail", _c("mail", "#9a9690"), 0.8)
	elif look.has("gloves"):
		gloves = _mat("leather", _c("gloves", "#3a2a1e"))
	var upper_mat := torso_mat
	var fore_mat := torso_mat
	match str(look.get("sleeves", "cloth")):
		"mail":
			upper_mat = _mat("chainmail", _c("mail", "#9a9690"), 1.0)
			fore_mat = upper_mat
		"rolled":
			fore_mat = skin
		"quilted":
			upper_mat = _mat("quilted", _c("gambeson", "#9a9078"))
			fore_mat = upper_mat

	# Pelvis and hips, in trousers.
	_mesh(pelvis, M.loft([[0.13, 0.15, 0.1], [0.04, 0.168, 0.112], [-0.06, 0.17, 0.112], [-0.12, 0.13, 0.1]], 18, [], [0.9, 0.75]), trousers)
	# Torso from the waist to the base of the neck.
	var torso: Array = [[-0.16, 0.15, 0.1], [-0.08, 0.152, 0.1], [0.0, 0.165, 0.104], [0.1, 0.183, 0.11],
		[0.18, 0.192, 0.105], [0.235, 0.17, 0.088], [0.27, 0.1, 0.07], [0.31, 0.055, 0.055]]
	if _belly:
		torso = [[-0.16, 0.16, 0.12, 0.0, -0.02], [-0.08, 0.185, 0.155, 0.0, -0.045], [0.0, 0.19, 0.15, 0.0, -0.04],
			[0.1, 0.19, 0.125, 0.0, -0.015], [0.18, 0.195, 0.108], [0.235, 0.17, 0.09], [0.27, 0.1, 0.07], [0.31, 0.055, 0.055]]
	if str(look.get("torso", "")) == "quilted":
		# A gambeson is thick: the padding fills out the chest and shoulders.
		torso_mat = _mat("quilted", _c("gambeson", "#9a9078"))
		var padded: Array = []
		for sec in torso:
			var t2: Array = sec.duplicate()
			if float(t2[0]) < 0.26:
				t2[1] = float(t2[1]) * 1.08
				t2[2] = float(t2[2]) * 1.12
			padded.append(t2)
		torso = padded
	_mesh(chest, M.loft(torso, 24), torso_mat)
	_mesh(neck, M.loft([[-0.04, 0.052, 0.055], [0.04, 0.047, 0.05], [0.12, 0.045, 0.048, 0.0, 0.005]], 12), skin)

	for side in [-1.0, 1.0]:
		var shoulder: Node3D = l_shoulder if side < 0 else r_shoulder
		var elbow: Node3D = l_elbow if side < 0 else r_elbow
		var hip: Node3D = l_hip if side < 0 else r_hip
		var knee: Node3D = l_knee if side < 0 else r_knee
		# Shoulder cap, upper arm and forearm.
		_mesh(shoulder, M.loft([[0.065, 0.03, 0.035], [0.035, 0.062, 0.068], [-0.02, 0.064, 0.068],
			[-0.12, 0.056, 0.06], [-0.22, 0.047, 0.05], [-0.31, 0.04, 0.043]], 14), upper_mat)
		var fore: Array = [[0.03, 0.04, 0.042], [-0.07, 0.046, 0.048, 0.0, 0.004], [-0.17, 0.037, 0.036], [-0.255, 0.029, 0.025]]
		_mesh(elbow, M.loft(fore, 14), fore_mat)
		if fore_mat != skin and not (str(look.get("sleeves", "")) in ["mail", "quilted"]):
			# Bare wrist below a cloth sleeve.
			_mesh(elbow, M.loft([[-0.2, 0.031, 0.028], [-0.265, 0.028, 0.024]], 10), skin)
		_build_hand(elbow, side, gloves)
		# Thigh, shin and boot.
		_mesh(hip, M.loft([[0.05, 0.075, 0.08], [0.0, 0.085, 0.09], [-0.1, 0.082, 0.086, 0.0, -0.004],
			[-0.25, 0.068, 0.073, 0.0, -0.006], [-0.4, 0.053, 0.058], [-0.47, 0.05, 0.056]], 14), trousers)
		_mesh(knee, M.loft([[0.04, 0.052, 0.056], [-0.08, 0.054, 0.062, 0.0, 0.012], [-0.17, 0.047, 0.052, 0.0, 0.006]], 14), trousers)
		_build_boot(knee, boots)


func _build_hand(elbow: Node3D, side: float, material: Material) -> void:
	var hand := _joint(elbow, Vector3(0, -0.255, -0.004))
	hand.rotation = Vector3(0.12, 0, 0)
	# Palm: the palm faces the thigh, so it is narrow side to side and broad front to back.
	_mesh(hand, M.loft([[0.012, 0.02, 0.026], [-0.02, 0.017, 0.037], [-0.06, 0.015, 0.04], [-0.078, 0.013, 0.036]], 12), material)
	# Four fingers, index at the front, each slightly curled toward the palm.
	var lengths := [0.068, 0.074, 0.07, 0.056]
	for i in 4:
		var z := -0.027 + i * 0.018
		var finger := _joint(hand, Vector3(side * 0.001, -0.07, z))
		finger.rotation = Vector3((i - 1.5) * -0.04, 0, -side * (0.1 + i * 0.03))
		var l: float = lengths[i]
		var r := 0.0085 - i * 0.0006
		_mesh(finger, M.loft([[0.006, r, r], [-l * 0.45, r * 0.95, r * 0.92, -side * 0.004, 0.0],
			[-l * 0.85, r * 0.85, r * 0.8, -side * 0.011, 0.0], [-l, r * 0.6, r * 0.6, -side * 0.015, 0.0]], 8), material)
	var thumb := _joint(hand, Vector3(-side * 0.006, -0.025, -0.03))
	thumb.rotation = Vector3(0.45, 0, -side * 0.15)
	_mesh(thumb, M.loft([[0.0, 0.012, 0.012], [-0.03, 0.0105, 0.0105], [-0.05, 0.009, 0.009], [-0.06, 0.006, 0.006]], 8), material)


func _build_boot(knee: Node3D, material: Material) -> void:
	# Shaft from mid-calf to the ankle; scuffed and muddy toward the bottom.
	_mesh(knee, M.loft([[-0.15, 0.06, 0.066, 0.0, 0.008], [-0.26, 0.052, 0.056, 0.0, 0.004], [-0.38, 0.046, 0.05],
		[-0.44, 0.05, 0.056]], 14, [], [0.95, 0.6]), material)
	# Foot lofted heel to toe, laid flat (loft +Y points forward, loft +Z points up).
	var foot := _joint(knee, Vector3(0, -0.445, 0.01))
	foot.rotation.x = -PI * 0.5
	_mesh(foot, M.loft([[-0.045, 0.032, 0.028, 0.0, 0.012], [-0.02, 0.044, 0.042, 0.0, 0.018], [0.04, 0.047, 0.034, 0.0, 0.006],
		[0.11, 0.046, 0.026, 0.0, -0.003], [0.155, 0.036, 0.02, 0.0, -0.006], [0.178, 0.018, 0.012, 0.0, -0.009]], 14, [], [0.75, 0.55]), material)


# --- Head ---------------------------------------------------------------------------

func _build_head() -> void:
	var skin_col := _c("skin", "#b88a70")
	var face := _joint(head, Vector3(0, 0.095, -0.005))
	var beard := str(look.get("beard", "none"))
	var face_tex := str(look.get("face", ""))
	if face_tex != "":
		# A painted face: brows, creases, lips and stubble are in the texture.
		_mesh(face, M.head(false, 0.1), _face_mat(face_tex, skin_col))
	else:
		_mesh(face, M.head(beard == "stubble", float(look.get("ruddy", 0.3))), _mat("skin", skin_col, 1.0, 0.0, 0.25))

	# Ears, eyes, brows.
	var plain_skin := _mat("skin", skin_col, 1.0, 0.0, 0.25, false)
	for sx in [-1.0, 1.0]:
		P.ellipsoid(face, Vector3(sx * 0.072, -0.004, 0.008), Vector3(0.011, 0.03, 0.019), plain_skin)
	var eye_white := P.m(Color(0.66, 0.62, 0.56), 0.35)
	var iris := P.m(_c("eyes", "#3a3026"), 0.25)
	var hair_col := _c("hair", "#3b2e24")
	var hair := _mat("fur", hair_col, 0.6)
	var brow_mat := _mat("fur", hair_col.darkened(0.15), 0.6, 0.0, 0.0, false)
	for x in [-0.031, 0.031]:
		var c := M.eye_centre(x)
		P.ellipsoid(face, c, Vector3(0.0125, 0.0115, 0.0125), eye_white)
		P.ellipsoid(face, c + Vector3(0, 0, -0.0105), Vector3(0.0058, 0.0058, 0.0028), iris)
		# Heavy upper lid, half-closing the eye: weary, not wide-eyed.
		var lid := P.ellipsoid(face, c + Vector3(0, 0.009, -0.0015), Vector3(0.0138, 0.0075, 0.0133), plain_skin)
		lid.rotation.x = -0.25
		if face_tex == "":
			var brow := P.ellipsoid(face, M.face_point(x * 1.08, 0.033, 0.003), Vector3(0.019, 0.0045, 0.006), brow_mat)
			brow.rotation.z = signf(x) * -0.12
	# A dark gap between the lips that opens while talking.
	mouth = _joint(face, M.face_point(0.0, -0.0545, -0.0015))
	P.ellipsoid(mouth, Vector3.ZERO, Vector3(0.019, 0.0016, 0.006), P.m(Color(0.16, 0.07, 0.06), 0.5))

	var headwear := str(look.get("headwear", "none"))
	if not (headwear in ["helmet", "coif", "kettle_hat"]):
		_mesh(face, M.shell("hair", 0.011), hair)
	match beard:
		"full":
			_mesh(face, M.shell("beard", 0.008), hair)
		"long":
			_mesh(face, M.shell("long_beard", 0.009), hair)
	var hair_plain := _mat("fur", hair_col, 0.6, 0.0, 0.0, false)
	if beard in ["mustache", "full", "long"]:
		var stache := P.ellipsoid(face, M.face_point(0.0, -0.043, 0.006), Vector3(0.028, 0.0065, 0.009), hair_plain)
		stache.rotation.x = 0.15
		for sx in [-1.0, 1.0]:
			var droop := P.ellipsoid(face, M.face_point(sx * 0.024, -0.054, 0.005), Vector3(0.006, 0.013, 0.006), hair_plain)
			droop.rotation.z = sx * 0.3

	match headwear:
		"helmet", "coif", "kettle_hat":
			_build_mail_hood(face, headwear)
		"crown":
			var gold := _mat("rust_metal", _c("crown", "#9a7a3a"), 1.0, 0.75)
			var band := P.torus(face, Vector3(0, 0.055, 0.004), 0.072, 0.086, gold)
			band.scale = Vector3(1.0, 1.6, 1.25)
			for i in 8:
				var a := TAU * i / 8.0
				var tine := _joint(face, Vector3(cos(a) * 0.079, 0.067, 0.004 + sin(a) * 0.099))
				tine.rotation.y = -a
				_mesh(tine, M.loft([[0.0, 0.004, 0.009], [0.025, 0.002, 0.005], [0.035, 0.0005, 0.001]], 4), gold)
			P.ellipsoid(face, Vector3(0, 0.055, -0.106), Vector3(0.009, 0.011, 0.005), P.m(Color(0.32, 0.03, 0.05), 0.2, 0.1))
		"cap":
			_mesh(face, M.shell("cap", 0.016), _mat("cloth", _c("cap", "#b9b09c")))


func _build_mail_hood(face: Node3D, headwear: String) -> void:
	var mail := _mat("chainmail", _c("mail", "#9a9690"), 1.0)
	_mesh(face, M.shell("coif", 0.006), mail)
	# The padded arming cap under the mail shows as a rolled edge around the face.
	_mesh(face, M.shell("coif_lining", 0.009), _mat("quilted", _c("coif_lining", "#7a2a22"), 0.4))
	# Mail mantle over the shoulders.
	_mesh(chest, M.loft([[0.37, 0.06, 0.065], [0.31, 0.08, 0.08], [0.26, 0.17, 0.11], [0.2, 0.23, 0.13], [0.14, 0.22, 0.135]], 20, [], [1.0, 0.85], 0.02), mail)
	if headwear == "coif":
		return
	var steel := _mat("rust_metal", _c("helmet", "#c8c0b4"), 1.0, 0.7)
	if headwear == "kettle_hat":
		# A kettle hat: a rounded iron crown with a broad, sloping brim.
		_mesh(face, M.shell("helmet", 0.024), steel)
		var brim := _joint(face, Vector3(0, 0.03, 0.004))
		var steel2 := _two_sided_mat(steel)
		_mesh(brim, M.loft([[0.012, 0.094, 0.114], [0.0, 0.12, 0.14], [-0.028, 0.155, 0.175], [-0.036, 0.158, 0.178]], 32, [], [1.0, 0.85], 0.0, false), steel2)
		var rim := P.torus(brim, Vector3(0, -0.036, 0), 0.152, 0.164, steel)
		rim.scale = Vector3(1.0, 0.6, 1.13)
		P.ellipsoid(face, Vector3(0, 0.13, 0.004), Vector3(0.012, 0.006, 0.012), steel)
		return
	_mesh(face, M.shell("helmet", 0.02), steel)
	var rim := P.torus(face, Vector3(0, 0.034, 0.006), 0.092, 0.104, steel)
	rim.scale = Vector3(1.0, 0.8, 1.2)
	var nasal := _joint(face, M.face_point(0.0, 0.03, 0.026))
	_mesh(nasal, M.loft([[0.012, 0.006, 0.003], [-0.045, 0.0055, 0.003], [-0.058, 0.004, 0.0025]], 6), steel)


# --- Costumes -----------------------------------------------------------------------

func _build_costume() -> void:
	var belt := _mat("leather", _c("belt", "#3a2a1e"))
	var belt_y := 0.12
	var waist := 0.168 if not _belly else 0.19
	if look.has("gambeson"):
		# The quilted skirts of the gambeson, split front and back for walking.
		var quilt := _mat("quilted", _c("gambeson", "#9a9078"))
		var gskirt := [[0.02, 0.185, 0.13], [-0.14, 0.2, 0.145], [-0.3, 0.208, 0.152]]
		front_panel = _joint(pelvis, Vector3(0, -0.02, 0))
		back_panel = _joint(pelvis, Vector3(0, -0.02, 0))
		_mesh(front_panel, M.loft(gskirt, 16, [PI + 0.05, TAU - 0.05], [1.0, 0.7], 0.01, false), quilt, true)
		_mesh(back_panel, M.loft(gskirt, 16, [0.05, PI - 0.05], [1.0, 0.7], 0.01, false), quilt, true)
		_mesh(pelvis, M.loft([[0.14, 0.18, 0.125], [-0.0, 0.19, 0.132]], 20, [], [1.0, 1.0], 0.0, false), quilt)
		waist = 0.19
	if look.has("hauberk"):
		var mail := _mat("chainmail", _c("mail", "#9a9690"), 1.0)
		var skirt := [[0.0, 0.175, 0.122], [-0.18, 0.19, 0.135], [-0.34, 0.2, 0.145]]
		front_panel = _joint(pelvis, Vector3(0, -0.02, 0))
		back_panel = _joint(pelvis, Vector3(0, -0.02, 0))
		_mesh(front_panel, M.loft(skirt, 12, [PI + 0.1, TAU - 0.1], [1.0, 0.8], 0.015, false), mail, true)
		_mesh(back_panel, M.loft(skirt, 12, [0.1, PI - 0.1], [1.0, 0.8], 0.015, false), mail, true)
		_mesh(pelvis, M.loft([[0.14, 0.168, 0.115], [-0.02, 0.18, 0.124]], 18, [], [1.0, 1.0], 0.0, false), mail)
	if look.has("surcoat"):
		var coat := _mat("wool", _c("surcoat", "#2c3446"))
		var body := [[0.255, 0.16, 0.118], [0.18, 0.207, 0.123], [0.1, 0.2, 0.127], [0.0, 0.183, 0.12], [-0.16, 0.17, 0.12]]
		var device := str(look.get("device", ""))
		if device != "":
			# The livery's device is painted onto the front panel's cloth.
			_mesh(chest, M.loft(body, 16, [PI + 0.55, TAU - 0.55], [1.0, 0.9], 0.0, false, 0.15, 0.0, true), _painted_mat(device, true), false)
		else:
			_mesh(chest, M.loft(body, 10, [PI + 0.55, TAU - 0.55], [1.0, 0.9], 0.0, false, 0.25), coat, true)
		_mesh(chest, M.loft(body, 10, [0.55, PI - 0.55], [1.0, 0.9], 0.0, false, 0.25), coat, true)
		var hang := [[0.0, 0.2, 0.135], [-0.25, 0.215, 0.15], [-0.52, 0.225, 0.158]]
		if front_panel == null:
			front_panel = _joint(pelvis, Vector3(0, -0.02, 0))
			back_panel = _joint(pelvis, Vector3(0, -0.02, 0))
		var fp := _joint(front_panel, Vector3.ZERO)
		var bp := _joint(back_panel, Vector3.ZERO)
		_mesh(fp, M.loft(hang, 20, [PI + 0.55, TAU - 0.55], [0.95, 0.45], 0.05, false, 0.3, 0.06), coat, true)
		_mesh(bp, M.loft(hang, 20, [0.55, PI - 0.55], [0.95, 0.45], 0.05, false, 0.3, 0.06), coat, true)
		_mesh(pelvis, M.loft([[0.14, 0.175, 0.124], [0.0, 0.19, 0.13]], 18, [], [0.9, 0.9], 0.0, false), coat)
		if look.has("emblem"):
			# A faded, hand-stitched sun on the chest.
			var sun := _joint(chest, Vector3(0, 0.1, -0.128))
			sun.rotation.x = PI * 0.5 - 0.08
			var thread := P.m(_c("emblem", "#8a7440"), 0.9)
			_mesh(sun, M.loft([[0.002, 0.038, 0.038], [-0.002, 0.038, 0.038]], 16), thread)
			for i in 8:
				var ray := _joint(sun, Vector3.ZERO)
				ray.rotation.y = TAU * i / 8.0
				P.ellipsoid(ray, Vector3(0.055, 0, 0), Vector3(0.018, 0.002, 0.006), thread)
		belt_y = 0.09
		waist = 0.19
	if look.has("robe"):
		var robe_mat := _mat("wool", _c("robe", "#3d1a22"))
		robe = _joint(pelvis, Vector3(0, 0.05, 0))
		_mesh(robe, M.loft([[0.06, 0.18, 0.125], [-0.2, 0.22, 0.16], [-0.55, 0.26, 0.2], [-0.98, 0.3, 0.24]], 48, [], [1.0, 0.4], 0.03, false, 0.0, 0.07), robe_mat, true)
		_mesh(robe, M.loft([[-0.91, 0.302, 0.242], [-0.99, 0.31, 0.25]], 22, [], [0.6, 0.45], 0.0, false), _mat("fur", _c("collar", "#8a7f70"), 0.4), true)
	if look.has("collar"):
		# A heavy fur mantle over the shoulders.
		_mesh(chest, M.loft([[0.36, 0.07, 0.072], [0.3, 0.11, 0.1], [0.25, 0.215, 0.135], [0.17, 0.25, 0.155], [0.08, 0.235, 0.15]], 22, [], [1.0, 0.7], 0.03), _mat("fur", _c("collar", "#8a7f70"), 0.4))
	if look.has("cape"):
		cape = _joint(chest, Vector3(0, 0.22, 0.02))
		_mesh(cape, M.loft([[0.04, 0.18, 0.12], [-0.3, 0.24, 0.17], [-0.8, 0.29, 0.23], [-1.32, 0.33, 0.27]], 30, [0.25, PI - 0.25], [0.95, 0.35], 0.04, false, 0.2, 0.08), _mat("wool", _c("cape", "#4a1616")), true)
	if look.has("apron"):
		var apron := _mat("cloth", _c("apron", "#cfc6b0"))
		var bib := [[0.17, 0.165, 0.1], [0.05, 0.2, 0.165, 0.0, -0.045], [-0.08, 0.2, 0.17, 0.0, -0.05], [-0.16, 0.18, 0.135, 0.0, -0.025]]
		if not _belly:
			bib = [[0.17, 0.17, 0.1], [0.0, 0.17, 0.11], [-0.16, 0.16, 0.108]]
		_mesh(chest, M.loft(bib, 10, [PI + 0.75, TAU - 0.75], [1.0, 0.85], 0.0, false, 0.6), apron, true)
		front_panel = _joint(pelvis, Vector3(0, 0.12, 0))
		var skirt := [[0.0, 0.19, 0.135, 0.0, -0.01], [-0.3, 0.21, 0.15], [-0.62, 0.22, 0.155]]
		_mesh(front_panel, M.loft(skirt, 20, [PI + 0.6, TAU - 0.6], [0.9, 0.55], 0.03, false, 0.7, 0.05), apron, true)
	# Belt, buckle and the long strap end hanging down the front.
	var bw := float(look.get("belt_width", 0.045))
	var bz := waist * 0.7 + 0.011
	_mesh(pelvis, M.loft([[belt_y + bw * 0.5, waist + 0.008, bz - 0.001], [belt_y - bw * 0.5, waist + 0.01, bz + 0.001]], 24, [], [1.0, 0.85]), belt)
	var buckle_mat := _mat("rust_metal", Color(0.72, 0.66, 0.56), 1.0, 0.7, 0.0, false)
	var buckle := _joint(pelvis, Vector3(0.02, belt_y, -bz - 0.006))
	var bh := bw + 0.016
	for sx in [-1.0, 1.0]:
		var side_bar := _mesh(buckle, M.bevel_box(Vector3(0.008, bh, 0.008), 0.002), buckle_mat)
		side_bar.position = Vector3(sx * 0.024, 0, 0)
		var end_bar := _mesh(buckle, M.bevel_box(Vector3(0.056, 0.008, 0.008), 0.002), buckle_mat)
		end_bar.position = Vector3(0, sx * bh * 0.5, 0)
	var pin := _mesh(buckle, M.bevel_box(Vector3(0.006, bh * 0.9, 0.006), 0.002), buckle_mat)
	pin.position = Vector3(-0.004, 0, -0.003)
	if bw > 0.05:
		# The strap end passes through the buckle and hangs, swinging with the cloth.
		var tongue_parent: Node3D = front_panel if front_panel != null else pelvis
		var tongue := _joint(tongue_parent, Vector3(0.045, belt_y + (0.02 if front_panel != null else 0.0) - bw * 0.3, -waist * 0.72 - 0.035))
		tongue.rotation = Vector3(-0.08, 0.0, 0.08)
		var strap := _mesh(tongue, M.bevel_box(Vector3(bw * 0.8, 0.34, 0.006), 0.002), belt)
		strap.position = Vector3(0, -0.17, 0)
		var tip := _mesh(tongue, M.bevel_box(Vector3(bw * 0.8 + 0.004, 0.035, 0.009), 0.002), buckle_mat)
		tip.position = Vector3(0, -0.33, 0)
	if look.has("pouch"):
		P.ellipsoid(pelvis, Vector3(0.14, belt_y - 0.06, -0.08), Vector3(0.04, 0.05, 0.025), _mat("leather", _c("belt", "#3a2a1e"), 1.0, 0.0, 0.0, false))
	if str(look.get("weapon", "")) == "spear":
		_build_spear()
	if look.has("sword"):
		_build_sword(belt_y, waist)


## An arming sword in a leather scabbard hanging from the belt on the left hip.
func _build_sword(belt_y: float, waist: float) -> void:
	var hang := _joint(pelvis, Vector3(-waist - 0.025, belt_y - 0.03, 0.03))
	hang.rotation = Vector3(-0.38, 0.0, -0.1)
	var leather := _mat("leather", Color(0.2, 0.14, 0.1), 0.6)
	var steel := _mat("rust_metal", Color(0.85, 0.82, 0.78), 0.5, 0.75)
	# Scabbard: a flattened, tapering sheath with an iron chape at the tip.
	_mesh(hang, M.loft([[0.0, 0.009, 0.026], [-0.4, 0.008, 0.022], [-0.78, 0.007, 0.016], [-0.82, 0.004, 0.006]], 10, [], [1.0, 0.8]), leather)
	_mesh(hang, M.loft([[-0.73, 0.0085, 0.019], [-0.83, 0.005, 0.007]], 10), steel)
	_mesh(hang, M.loft([[0.01, 0.011, 0.029], [-0.03, 0.011, 0.029]], 10), steel)
	# Hilt: crossguard, leather-wrapped grip and a wheel pommel.
	var guard := _mesh(hang, M.bevel_box(Vector3(0.012, 0.016, 0.18), 0.004), steel)
	guard.position = Vector3(0, 0.02, 0)
	_mesh(hang, M.loft([[0.13, 0.012, 0.014], [0.09, 0.014, 0.016], [0.03, 0.012, 0.014]], 8), leather)
	P.ellipsoid(hang, Vector3(0, 0.15, 0), Vector3(0.012, 0.027, 0.027), steel)


func _build_spear() -> void:
	spear = _joint(r_elbow, Vector3(0, -0.3, -0.02))
	spear.rotation.x = -0.9
	var wood := _mat("wood_dark", Color(0.42, 0.33, 0.24), 1.5, 0.0, 0.0, false)
	var shaft := G.cylinder(spear, 0.016, 2.1, Vector3(0, 0.45, 0), wood, 0.014)
	shaft.name = "Shaft"
	var steel := _mat("rust_metal", Color(0.95, 0.9, 0.85), 0.4, 0.7)
	var head_node := _joint(spear, Vector3(0, 1.48, 0))
	_mesh(head_node, M.loft([[0.0, 0.017, 0.017], [0.06, 0.013, 0.013], [0.08, 0.032, 0.009], [0.16, 0.022, 0.006], [0.25, 0.002, 0.002]], 4), steel)


# --- Animation ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if pelvis == null:
		return
	_time += delta
	_walk = lerpf(_walk, clampf(speed / 1.1, 0.0, 1.0), clampf(delta * 5.0, 0.0, 1.0))
	_talk = maxf(_talk - delta, 0.0)
	_gesture = lerpf(_gesture, 1.0 if _talk > 0.0 else 0.0, clampf(delta * 3.0, 0.0, 1.0))
	if pose == "sit":
		_animate_sit()
	else:
		_animate_stand(delta)
	_animate_head(delta)
	_animate_layers()


func _animate_stand(delta: float) -> void:
	_phase = fmod(_phase + delta * speed / STRIDE * TAU, TAU)
	var s := sin(_phase)
	var c := cos(_phase)
	var amp := 0.36 * _walk
	var breath := sin(_time * 1.4)
	var sway := sin(_time * 0.33)
	var idle := 1.0 - _walk

	# Heavy steps: the body drops onto each foot, and idles with its weight on one leg.
	pelvis.position.y = _pelvis_y - 0.035 * _walk + absf(c) * 0.025 * _walk - 0.012 * idle
	pelvis.position.x = sway * 0.018 * idle
	pelvis.rotation = Vector3(0.0, s * 0.07 * _walk, sway * 0.035 * idle + c * 0.025 * _walk)
	chest.rotation = Vector3(0.06 * _walk + _slouch + breath * 0.012, -s * 0.09 * _walk, -sway * 0.03 * idle - c * 0.02 * _walk)

	l_hip.rotation = Vector3(s * amp + 0.03 * idle * maxf(0.0, -sway), 0, -sway * 0.03 * idle)
	r_hip.rotation = Vector3(-s * amp + 0.03 * idle * maxf(0.0, sway), 0, -sway * 0.03 * idle)
	l_knee.rotation.x = -maxf(0.0, c) * 0.85 * _walk - 0.04 - 0.08 * idle * maxf(0.0, -sway)
	r_knee.rotation.x = -maxf(0.0, -c) * 0.85 * _walk - 0.04 - 0.08 * idle * maxf(0.0, sway)

	var arm := amp * 0.55
	l_shoulder.rotation = Vector3(-s * arm + 0.04, 0, -0.08)
	r_shoulder.rotation = Vector3(s * arm + 0.04, 0, 0.08)
	l_elbow.rotation.x = 0.18 + 0.2 * _walk + maxf(0.0, -s) * 0.2 * _walk
	r_elbow.rotation.x = 0.18 + 0.2 * _walk + maxf(0.0, s) * 0.2 * _walk

	if spear != null:
		# The spear hand stays steady and keeps the shaft upright.
		r_shoulder.rotation = Vector3(0.15, 0, 0.1)
		r_elbow.rotation.x = 0.75
	_apply_gesture()


func _animate_sit() -> void:
	var breath := sin(_time * 1.2)
	pelvis.position = Vector3(0, _sit_y, 0.0)
	pelvis.rotation = Vector3.ZERO
	chest.rotation = Vector3(0.05 + breath * 0.01, 0, 0.02)
	for hip in [l_hip, r_hip]:
		hip.rotation = Vector3(PI * 0.5, 0, 0)
	l_hip.rotation.z = -0.1
	r_hip.rotation.z = 0.1
	l_knee.rotation.x = -PI * 0.5
	r_knee.rotation.x = -PI * 0.5
	l_shoulder.rotation = Vector3(0.45, 0, -0.18)
	r_shoulder.rotation = Vector3(0.45, 0, 0.18)
	l_elbow.rotation.x = 0.9
	r_elbow.rotation.x = 0.9
	_apply_gesture()


func _apply_gesture() -> void:
	if _gesture < 0.01:
		return
	var right := str(look.get("gesture_arm", "right")) == "right"
	var shoulder := r_shoulder if right else l_shoulder
	var elbow := r_elbow if right else l_elbow
	var wave := sin(_time * 1.7)
	shoulder.rotation.x = lerpf(shoulder.rotation.x, 0.4 + wave * 0.1, _gesture)
	shoulder.rotation.z = lerpf(shoulder.rotation.z, (0.18 if right else -0.18), _gesture)
	elbow.rotation.x = lerpf(elbow.rotation.x, 0.95 + sin(_time * 2.3) * 0.12, _gesture)


func _animate_head(delta: float) -> void:
	var yaw := 0.0
	var pitch := -_slouch * 0.6
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if look_at_camera and cam != null:
		var to := cam.global_position - head.global_position
		if to.length() < 6.0:
			var local := global_transform.basis.inverse() * to
			var raw := atan2(-local.x, -local.z)
			if absf(raw) < 1.9:
				yaw = clampf(raw, -1.1, 1.1)
				pitch = clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.4, 0.4)
	var k := clampf(delta * 2.5, 0.0, 1.0)
	_head_yaw = lerpf(_head_yaw, yaw, k)
	_head_pitch = lerpf(_head_pitch, pitch, k)
	var nod := sin(_time * 3.6) * 0.04 * _gesture
	neck.rotation = Vector3(-_slouch * 0.5, _head_yaw * 0.4, 0)
	head.rotation = Vector3(_head_pitch + nod, _head_yaw * 0.6, 0)
	if mouth != null:
		var open := 0.0
		if _talk > 0.0:
			open = absf(sin(_time * 12.0)) * 0.7 + absf(sin(_time * 6.7)) * 0.3
		mouth.scale = Vector3(1.0 - open * 0.15, 1.0 + open * 3.5, 1.0)
	if _face_mi != null:
		_animate_face(delta)


## Speech and blinking on an imported face's blend shapes.
func _animate_face(delta: float) -> void:
	var jaw := 0.0
	var wide := 0.0
	if _talk > 0.0:
		jaw = absf(sin(_time * 11.0)) * 0.45 + absf(sin(_time * 6.3)) * 0.25
		wide = maxf(0.0, sin(_time * 4.1)) * 0.3
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.16
		_next_blink = randf_range(2.5, 6.0)
	_blink = maxf(_blink - delta, 0.0)
	_set_shape("jawOpen", jaw)
	_set_shape("mouthWide", wide)
	_set_shape("eyeBlink", 1.0 - absf(_blink - 0.08) / 0.08 if _blink > 0.0 else 0.0)


func _set_shape(shape_name: String, value: float) -> void:
	var i := _face_mi.find_blend_shape_by_name(shape_name)
	if i >= 0:
		_face_mi.set_blend_shape_value(i, value)


func _animate_layers() -> void:
	# Cloth and mail panels swing out of the way of the legs.
	var forward := maxf(maxf(l_hip.rotation.x, r_hip.rotation.x), 0.0)
	var back := minf(minf(l_hip.rotation.x, r_hip.rotation.x), 0.0)
	if pose == "sit":
		forward = PI * 0.42
		back = 0.0
	if front_panel != null:
		front_panel.rotation.x = forward * 0.85
	if back_panel != null:
		back_panel.rotation.x = back * 0.85
	if cape != null:
		cape.rotation.x = -0.03 - _walk * 0.12 + sin(_time * 1.1) * 0.015
	if robe != null:
		robe.visible = pose != "sit"
		robe.rotation.x = sin(_phase) * 0.035 * _walk


# --- Construction helpers --------------------------------------------------------

func _joint(parent: Node, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func _mesh(parent: Node, mesh: Mesh, material: Material, two_sided := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if two_sided:
		var m: StandardMaterial3D = (material as StandardMaterial3D)
		var key := str(m.get_instance_id()) + "|2"
		if not _materials.has(key):
			var d := m.duplicate() as StandardMaterial3D
			d.cull_mode = BaseMaterial3D.CULL_DISABLED
			_materials[key] = d
		material = _materials[key]
	mi.material_override = material
	parent.add_child(mi)
	return mi


## A painted face texture (tools/gen_faces.py), tinted by the skin colour.
func _face_mat(face_name: String, skin_col: Color) -> StandardMaterial3D:
	var key := "face|%s|%s" % [face_name, skin_col.to_html()]
	if _materials.has(key):
		return _materials[key]
	var m := _painted_mat("face_" + face_name, false).duplicate() as StandardMaterial3D
	m.albedo_color = Color(minf(skin_col.r / 0.86, 1.0), minf(skin_col.g / 0.82, 1.0), minf(skin_col.b / 0.79, 1.0))
	m.vertex_color_use_as_albedo = true
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.25
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.6
	_materials[key] = m
	return m


## A UV-mapped material from res://assets/textures/<texture_name>_*.png.
func _painted_mat(texture_name: String, two_sided: bool) -> StandardMaterial3D:
	var key := "painted|%s|%s" % [texture_name, two_sided]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	var dir := "res://assets/textures/" + texture_name
	if ResourceLoader.exists(dir + "_albedo.png"):
		m.albedo_texture = load(dir + "_albedo.png")
	if ResourceLoader.exists(dir + "_normal.png"):
		m.normal_enabled = true
		m.normal_texture = load(dir + "_normal.png")
	if ResourceLoader.exists(dir + "_rough.png"):
		m.roughness_texture = load(dir + "_rough.png")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = m
	return m


func _two_sided_mat(material: Material) -> Material:
	var key := str(material.get_instance_id()) + "|2"
	if not _materials.has(key):
		var d := material.duplicate() as StandardMaterial3D
		d.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = d
	return _materials[key]


func _c(key: String, fallback: String) -> Color:
	return Color.html(str(look.get(key, fallback)))


## A textured character material: `color` is the colour the surface should read
## as on average; vertex colours (grime, stains, skin shading) multiply on top.
func _mat(surface: String, color: Color, tile_mult := 1.0, metallic := 0.0, subsurface := 0.0, vertex_colour := true) -> StandardMaterial3D:
	var key := "%s|%s|%.2f|%.2f|%.2f|%s" % [surface, color.to_html(), tile_mult, metallic, subsurface, vertex_colour]
	if _materials.has(key):
		return _materials[key]
	var mean: Color = TEXTURE_MEAN.get(surface, Color(0.7, 0.7, 0.7))
	var tint := Color(minf(color.r / mean.r, 1.0), minf(color.g / mean.g, 1.0), minf(color.b / mean.b, 1.0))
	var tile: float = float(TEXTURE_TILE.get(surface, 0.4)) * tile_mult
	var m := S.get_material(surface, tint, tile, false).duplicate() as StandardMaterial3D
	m.vertex_color_use_as_albedo = vertex_colour
	m.uv1_triplanar_sharpness = 2.0
	if metallic > 0.0:
		m.metallic = metallic
		m.metallic_specular = 0.6
	if subsurface > 0.0:
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = subsurface
		m.rim_enabled = true
		m.rim = 0.12
		m.rim_tint = 0.6
	_materials[key] = m
	return m
