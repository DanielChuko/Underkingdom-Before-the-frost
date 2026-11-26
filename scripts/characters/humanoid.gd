extends Node3D
## A procedurally built, procedurally animated humanoid.
##
## The body is a small joint hierarchy (pelvis, chest, neck, head, shoulders,
## elbows, hips, knees) with primitive meshes hung off each joint, dressed from
## a "look" in res://data/characters.json. Everything faces local -Z.
##
## Animation is computed every frame instead of using keyframes:
##   - walk cycle driven by `speed` (metres per second, set by the owner)
##   - idle breathing and weight shift
##   - "sit" pose for the king's throne
##   - talking: mouth movement, head nods and a hand gesture (speak())
##   - the head turns to look at the camera when it is close

const G := preload("res://scripts/world/greybox.gd")
const S := preload("res://scripts/world/surfaces.gd")
const LOOKS_PATH := "res://data/characters.json"

const HIP_HEIGHT := 0.93
const STRIDE := 1.5  # metres per full walk cycle (two steps)

static var _looks: Dictionary = {}

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
	var skin := _skin(_c("skin", "#d6a587"))
	var shirt := _cloth(_c("shirt", "#8a7a66"))
	var trousers := _cloth(_c("trousers", "#3a2e24"))
	var boots := _leather(_c("boots", "#2a1d14"))
	var sleeve_mat: Material = shirt
	var forearm_mat: Material = shirt
	match str(look.get("sleeves", "cloth")):
		"metal":
			sleeve_mat = _metal(_c("shirt", "#6f7178"))
			forearm_mat = sleeve_mat
		"rolled":
			forearm_mat = skin

	# --- Skeleton -------------------------------------------------------------
	pelvis = _joint(self, Vector3(0, HIP_HEIGHT + 0.02, 0))
	chest = _joint(pelvis, Vector3(0, 0.28, 0))
	neck = _joint(chest, Vector3(0, 0.25, 0))
	head = _joint(neck, Vector3(0, 0.09, 0))
	l_shoulder = _joint(chest, Vector3(-0.215, 0.19, 0))
	r_shoulder = _joint(chest, Vector3(0.215, 0.19, 0))
	l_elbow = _joint(l_shoulder, Vector3(0, -0.29, 0))
	r_elbow = _joint(r_shoulder, Vector3(0, -0.29, 0))
	l_hip = _joint(pelvis, Vector3(-0.1, -0.02, 0))
	r_hip = _joint(pelvis, Vector3(0.1, -0.02, 0))
	l_knee = _joint(l_hip, Vector3(0, -0.44, 0))
	r_knee = _joint(r_hip, Vector3(0, -0.44, 0))

	# --- Body -------------------------------------------------------------------
	G.box(pelvis, Vector3(0.32, 0.18, 0.21), Vector3(0, 0.0, 0), trousers, false)
	var torso := G.cylinder(chest, 0.17, 0.56, Vector3(0, -0.03, 0), shirt, 0.205)
	torso.scale = Vector3(1, 1, 0.64)
	G.box(pelvis, Vector3(0.34, 0.06, 0.23), Vector3(0, 0.1, 0), _leather(_c("belt", "#4a3322")), false)
	G.sphere(chest, 0.075, Vector3(-0.2, 0.19, 0), sleeve_mat)
	G.sphere(chest, 0.075, Vector3(0.2, 0.19, 0), sleeve_mat)
	if bool(look.get("belly", false)):
		var belly := G.sphere(chest, 0.2, Vector3(0, -0.13, -0.05), shirt)
		belly.scale = Vector3(1.0, 0.9, 0.85)

	G.cylinder(neck, 0.055, 0.12, Vector3(0, 0.03, 0), skin)
	for side in [-1.0, 1.0]:
		var shoulder: Node3D = l_shoulder if side < 0 else r_shoulder
		var elbow: Node3D = l_elbow if side < 0 else r_elbow
		_capsule(shoulder, 0.058, 0.32, Vector3(0, -0.14, 0), sleeve_mat)
		_capsule(elbow, 0.05, 0.28, Vector3(0, -0.13, 0), forearm_mat)
		var hand := G.sphere(elbow, 0.052, Vector3(0, -0.29, -0.01), skin)
		hand.scale = Vector3(0.8, 1.1, 0.9)
		var hip: Node3D = l_hip if side < 0 else r_hip
		var knee: Node3D = l_knee if side < 0 else r_knee
		_capsule(hip, 0.078, 0.48, Vector3(0, -0.21, 0), trousers)
		_capsule(knee, 0.062, 0.3, Vector3(0, -0.12, 0), trousers)
		_capsule(knee, 0.066, 0.26, Vector3(0, -0.3, 0), boots)
		G.box(knee, Vector3(0.11, 0.07, 0.25), Vector3(0, -0.43, -0.05), boots, false)

	_build_head(skin)
	_build_layers()


## Starts the talking animation for `duration` seconds.
func speak(duration: float) -> void:
	_talk = maxf(_talk, duration)


func _process(delta: float) -> void:
	if pelvis == null:
		return
	_time += delta
	_walk = lerpf(_walk, clampf(speed / 1.2, 0.0, 1.0), clampf(delta * 6.0, 0.0, 1.0))
	_talk = maxf(_talk - delta, 0.0)
	_gesture = lerpf(_gesture, 1.0 if _talk > 0.0 else 0.0, clampf(delta * 4.0, 0.0, 1.0))
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
	var amp := 0.42 * _walk
	var breath := sin(_time * 1.7)
	var sway := sin(_time * 0.45)

	pelvis.position.y = HIP_HEIGHT + 0.02 - 0.03 * _walk + absf(c) * 0.035 * _walk
	pelvis.position.x = sway * 0.012 * (1.0 - _walk)
	pelvis.rotation = Vector3(0.0, s * 0.09 * _walk, sway * 0.02 * (1.0 - _walk))
	chest.rotation = Vector3(0.04 * _walk + breath * 0.015, -s * 0.13 * _walk, -sway * 0.02 * (1.0 - _walk))

	l_hip.rotation.x = s * amp
	r_hip.rotation.x = -s * amp
	l_knee.rotation.x = -maxf(0.0, c) * 0.95 * _walk - 0.03
	r_knee.rotation.x = -maxf(0.0, -c) * 0.95 * _walk - 0.03

	var arm := amp * 0.85
	l_shoulder.rotation = Vector3(-s * arm, 0, -0.06)
	r_shoulder.rotation = Vector3(s * arm, 0, 0.06)
	l_elbow.rotation.x = 0.12 + 0.25 * _walk + maxf(0.0, -s) * 0.3 * _walk
	r_elbow.rotation.x = 0.12 + 0.25 * _walk + maxf(0.0, s) * 0.3 * _walk

	if spear != null:
		# The spear hand stays steady and keeps the shaft upright.
		r_shoulder.rotation = Vector3(0.15, 0, 0.1)
		r_elbow.rotation.x = 0.75
	_apply_gesture()


func _animate_sit() -> void:
	var breath := sin(_time * 1.5)
	pelvis.position = Vector3(0, 0.55, 0.0)
	pelvis.rotation = Vector3.ZERO
	chest.rotation = Vector3(-0.06 + breath * 0.012, 0, 0)
	for hip in [l_hip, r_hip]:
		hip.rotation = Vector3(PI * 0.5, 0, 0)
	l_hip.rotation.z = -0.08
	r_hip.rotation.z = 0.08
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
	var wave := sin(_time * 2.3)
	shoulder.rotation.x = lerpf(shoulder.rotation.x, 0.55 + wave * 0.18, _gesture)
	shoulder.rotation.z = lerpf(shoulder.rotation.z, (0.25 if right else -0.25), _gesture)
	elbow.rotation.x = lerpf(elbow.rotation.x, 1.0 + sin(_time * 3.1) * 0.2, _gesture)


func _animate_head(delta: float) -> void:
	var yaw := 0.0
	var pitch := 0.0
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if look_at_camera and cam != null:
		var to := cam.global_position - head.global_position
		if to.length() < 6.0:
			var local := global_transform.basis.inverse() * to
			var raw := atan2(-local.x, -local.z)
			if absf(raw) < 1.9:
				yaw = clampf(raw, -1.1, 1.1)
				pitch = clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.4, 0.4)
	var k := clampf(delta * 4.0, 0.0, 1.0)
	_head_yaw = lerpf(_head_yaw, yaw, k)
	_head_pitch = lerpf(_head_pitch, pitch, k)
	var nod := sin(_time * 5.0) * 0.06 * _gesture
	neck.rotation = Vector3(0, _head_yaw * 0.4, 0)
	head.rotation = Vector3(_head_pitch + nod, _head_yaw * 0.6, 0)
	if mouth != null:
		var open := 0.0
		if _talk > 0.0:
			open = absf(sin(_time * 13.0)) * 0.7 + absf(sin(_time * 7.3)) * 0.3
		mouth.scale = Vector3(1.0, 1.0 + open * 3.0, 1.0)


func _animate_layers() -> void:
	# Cloth panels swing out of the way of the legs.
	var forward := maxf(maxf(l_hip.rotation.x, r_hip.rotation.x), 0.0)
	var back := minf(minf(l_hip.rotation.x, r_hip.rotation.x), 0.0)
	if pose == "sit":
		forward = 0.0
		back = 0.0
	if front_panel != null:
		front_panel.rotation.x = forward * 0.9
	if back_panel != null:
		back_panel.rotation.x = back * 0.9
	if cape != null:
		cape.rotation.x = -0.05 - _walk * 0.18 + sin(_time * 1.3) * 0.02
	if robe != null:
		robe.visible = pose != "sit"
		robe.rotation.x = sin(_phase) * 0.04 * _walk


# --- Construction helpers --------------------------------------------------------

func _build_head(skin: Material) -> void:
	var hair_col := _c("hair", "#3b2a1e")
	var hair := _cloth(hair_col)
	var skull := G.sphere(head, 0.125, Vector3(0, 0.08, 0), skin)
	skull.scale = Vector3(0.9, 1.08, 1.0)
	var dark := G.mat(Color(0.08, 0.06, 0.05), 0.0, 0.0, 0.4)
	var white := G.mat(Color(0.92, 0.9, 0.86), 0.0, 0.0, 0.4)
	for x in [-0.043, 0.043]:
		G.sphere(head, 0.02, Vector3(x, 0.1, -0.103), white)
		G.sphere(head, 0.011, Vector3(x, 0.1, -0.12), dark)
		G.box(head, Vector3(0.05, 0.012, 0.02), Vector3(x, 0.13, -0.112), hair, false)
		var ear := G.sphere(head, 0.03, Vector3(x * 2.75, 0.08, 0.0), skin)
		ear.scale = Vector3(0.5, 1.0, 0.8)
	G.box(head, Vector3(0.032, 0.055, 0.045), Vector3(0, 0.07, -0.128), skin, false)
	mouth = _joint(head, Vector3(0, 0.025, -0.113))
	G.box(mouth, Vector3(0.05, 0.01, 0.012), Vector3.ZERO, G.mat(Color(0.35, 0.1, 0.1)), false)

	var headwear := str(look.get("headwear", "none"))
	if headwear != "helmet":
		var cap := G.sphere(head, 0.13, Vector3(0, 0.12, 0.015), hair)
		cap.scale = Vector3(0.95, 0.75, 1.05)
		var back := G.sphere(head, 0.12, Vector3(0, 0.06, 0.04), hair)
		back.scale = Vector3(0.95, 0.9, 0.85)

	match str(look.get("beard", "none")):
		"stubble":
			var st := G.sphere(head, 0.105, Vector3(0, 0.025, -0.02), _cloth(hair_col.darkened(0.2)))
			st.scale = Vector3(0.95, 0.6, 0.95)
		"mustache":
			G.box(head, Vector3(0.09, 0.022, 0.03), Vector3(0, 0.045, -0.118), hair, false)
		"full":
			var b := G.sphere(head, 0.11, Vector3(0, 0.005, -0.04), hair)
			b.scale = Vector3(0.95, 0.85, 0.85)
			G.box(head, Vector3(0.09, 0.022, 0.03), Vector3(0, 0.045, -0.118), hair, false)
		"long":
			var lb := G.cylinder(head, 0.035, 0.24, Vector3(0, -0.06, -0.08), hair, 0.09)
			lb.rotation.x = -0.25
			var jaw := G.sphere(head, 0.11, Vector3(0, 0.01, -0.035), hair)
			jaw.scale = Vector3(0.95, 0.85, 0.85)
			G.box(head, Vector3(0.1, 0.025, 0.03), Vector3(0, 0.045, -0.118), hair, false)

	match headwear:
		"helmet":
			var steel := _metal(Color(0.62, 0.64, 0.68))
			var dome := MeshInstance3D.new()
			var hemi := SphereMesh.new()
			hemi.radius = 0.15
			hemi.height = 0.15
			hemi.is_hemisphere = true
			dome.mesh = hemi
			dome.material_override = steel
			dome.position = Vector3(0, 0.1, 0)
			head.add_child(dome)
			G.cylinder(head, 0.152, 0.035, Vector3(0, 0.1, 0), steel)
			G.box(head, Vector3(0.025, 0.09, 0.02), Vector3(0, 0.07, -0.145), steel, false)
		"crown":
			var gold := G.mat(Color(0.95, 0.75, 0.25), 0.3, 0.9, 0.3)
			G.cylinder(head, 0.125, 0.07, Vector3(0, 0.2, 0.01), gold)
			for i in 6:
				var a := TAU * i / 6.0
				var spike := G.box(head, Vector3(0.03, 0.07, 0.02), Vector3(sin(a) * 0.12, 0.26, 0.01 + cos(a) * 0.12), gold, false)
				spike.rotation.y = a
			G.sphere(head, 0.018, Vector3(0, 0.2, -0.125), G.mat(Color(0.7, 0.05, 0.1), 0.5, 0.2, 0.2))
		"chef_hat":
			var linen := _cloth(Color(0.96, 0.95, 0.92))
			G.cylinder(head, 0.12, 0.14, Vector3(0, 0.22, 0.01), linen)
			var puff := G.sphere(head, 0.15, Vector3(0, 0.31, 0.01), linen)
			puff.scale = Vector3(1, 0.6, 1)


func _build_layers() -> void:
	if look.has("tabard"):
		var tabard := _cloth(_c("tabard", "#26396b"))
		var emblem := G.mat(_c("emblem", "#e0b44a"), 0.2, 0.6, 0.4)
		var t := G.box(chest, Vector3(0.36, 0.42, 0.02), Vector3(0, -0.02, -0.125), tabard, false)
		t.rotation.x = 0.05
		G.box(chest, Vector3(0.36, 0.42, 0.02), Vector3(0, -0.02, 0.125), tabard, false)
		var sun := G.cylinder(chest, 0.07, 0.01, Vector3(0, 0.02, -0.14), emblem)
		sun.rotation.x = PI * 0.5
		front_panel = _joint(pelvis, Vector3(0, 0.05, -0.12))
		G.box(front_panel, Vector3(0.32, 0.42, 0.02), Vector3(0, -0.19, 0), tabard, false)
		back_panel = _joint(pelvis, Vector3(0, 0.05, 0.12))
		G.box(back_panel, Vector3(0.32, 0.42, 0.02), Vector3(0, -0.19, 0), tabard, false)
	if look.has("apron"):
		var apron := _cloth(_c("apron", "#f2efe6"))
		var bib := G.box(chest, Vector3(0.26, 0.3, 0.02), Vector3(0, -0.02, -0.15 if bool(look.get("belly", false)) else -0.125), apron, false)
		bib.rotation.x = 0.1
		front_panel = _joint(pelvis, Vector3(0, 0.08, -0.15 if bool(look.get("belly", false)) else -0.12))
		G.box(front_panel, Vector3(0.38, 0.6, 0.02), Vector3(0, -0.28, 0), apron, false)
	if look.has("robe"):
		robe = _joint(pelvis, Vector3(0, 0.08, 0))
		G.cylinder(robe, 0.4, 1.0, Vector3(0, -0.5, 0), _cloth(_c("robe", "#4a1d5c")), 0.19)
		G.cylinder(robe, 0.405, 0.06, Vector3(0, -0.97, 0), G.mat(_c("belt", "#d9a83a"), 0.2, 0.7, 0.4))
	if look.has("cape"):
		cape = _joint(chest, Vector3(0, 0.22, 0.12))
		G.box(cape, Vector3(0.5, 1.4, 0.03), Vector3(0, -0.7, 0.03), _cloth(_c("cape", "#8a1418")), false)
	if look.has("collar"):
		var fur := _cloth(_c("collar", "#ece6da"))
		var collar := G.cylinder(chest, 0.17, 0.09, Vector3(0, 0.24, 0), fur, 0.11)
		collar.scale = Vector3(1.2, 1, 0.9)
	if str(look.get("weapon", "")) == "spear":
		spear = _joint(r_elbow, Vector3(0, -0.29, -0.02))
		spear.rotation.x = -0.9
		var wood := S.get_material("wood_floor", Color(0.8, 0.75, 0.7), 1.0, false)
		G.box(spear, Vector3(0.035, 2.1, 0.035), Vector3(0, 0.45, 0), wood, false)
		var tip := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.07, 0.22, 0.02)
		tip.mesh = prism
		tip.material_override = _metal(Color(0.75, 0.77, 0.8))
		tip.position = Vector3(0, 1.61, 0)
		spear.add_child(tip)


func _joint(parent: Node, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func _capsule(parent: Node, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = height
	cap.radial_segments = 12
	cap.rings = 4
	mi.mesh = cap
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


func _c(key: String, fallback: String) -> Color:
	return Color.html(str(look.get(key, fallback)))


func _cloth(color: Color) -> Material:
	return S.get_material("cloth", color, 0.5, false)


func _leather(color: Color) -> Material:
	return G.mat(color, 0.0, 0.0, 0.6)


func _metal(color: Color) -> Material:
	return G.mat(color, 0.0, 0.85, 0.35)


func _skin(color: Color) -> Material:
	var m := G.mat(color, 0.0, 0.0, 0.65)
	m.rim_enabled = true
	m.rim = 0.2
	return m
