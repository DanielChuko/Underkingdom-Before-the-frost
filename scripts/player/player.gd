extends CharacterBody3D
## First-person controller: mouse look, WASD movement, sprint, jump, a
## stepping head motion, and a camera raycast that finds anything with an interact() method.
## Interactables also provide get_prompt() for the on-screen hint.

signal focus_changed(prompt: String)

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.6
const ACCELERATION := 10.0
const INTERACT_RANGE := 2.6
const EYE_HEIGHT := 1.65
const JUMP_VELOCITY := 4.2
## Distance covered by one step, walking and running.
const WALK_STEP := 0.72
const RUN_STEP := 1.05
## How far the eyes dip at each footfall, walking and running.
const WALK_BOB := 0.045
const RUN_BOB := 0.08

var mouse_sensitivity := 0.0025
var controls_enabled := true
var head: Node3D
var camera: Camera3D
var ray: RayCast3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _last_prompt := ""
var _step_phase := 0.0
var _bob_amount := 0.0
var _land_dip := 0.0
var _land_velocity := 0.0
var _jump_block := 0.0


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	# Stay on ramps and stairs when walking down them instead of skipping off.
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)

	head = Node3D.new()
	head.position.y = EYE_HEIGHT
	add_child(head)

	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.05
	head.add_child(camera)
	camera.make_current()

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -INTERACT_RANGE)
	ray.add_exception(self)
	camera.add_child(ray)


func set_controls(enabled: bool) -> void:
	controls_enabled = enabled
	# The key that closed a conversation should not also make you jump.
	_jump_block = 0.25
	if not enabled:
		_set_prompt("")


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		var target = _find_interactable()
		if target != null:
			get_viewport().set_input_as_handled()
			target.interact(self)


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()
	if not was_on_floor:
		velocity.y -= _gravity * delta
	_jump_block = maxf(_jump_block - delta, 0.0)
	if controls_enabled and was_on_floor and _jump_block <= 0.0 and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := global_transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	dir = dir.normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var step := ACCELERATION * speed * delta
	velocity.x = move_toward(velocity.x, dir.x * speed, step)
	velocity.z = move_toward(velocity.z, dir.z * speed, step)
	var fall_speed := -velocity.y
	move_and_slide()
	if not was_on_floor and is_on_floor() and fall_speed > 1.0:
		# Landing: the knees take the weight and the view dips, then recovers.
		_land_velocity = -minf(fall_speed * 0.35, 2.5)

	_head_motion(delta)
	_update_focus()


## Walking moves the eyes the way a body does: they rise over each leg and dip
## as each foot lands, sway a little towards the leg carrying the weight, and
## roll slightly with it. Running makes the steps longer, faster and heavier.
func _head_motion(delta: float) -> void:
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	var on_floor := is_on_floor()
	var running := ground_speed > (WALK_SPEED + SPRINT_SPEED) * 0.5
	var target := 0.0
	if on_floor and ground_speed > 0.3:
		var t := clampf((ground_speed - WALK_SPEED) / (SPRINT_SPEED - WALK_SPEED), 0.0, 1.0)
		target = lerpf(WALK_BOB, RUN_BOB, t) * clampf(ground_speed / WALK_SPEED, 0.0, 1.0)
		# One step per half turn of the phase.
		_step_phase += delta * ground_speed / (RUN_STEP if running else WALK_STEP) * PI
	_bob_amount = lerpf(_bob_amount, target, clampf(delta * 6.0, 0.0, 1.0))
	var rise := absf(sin(_step_phase))
	# Footfall is a sharp dip, mid-stride a rounded crest.
	var bob := (pow(rise, 0.7) - 1.0) * _bob_amount
	var sway := cos(_step_phase) * _bob_amount * 0.45

	# Landing dip on a spring.
	_land_velocity += (-_land_dip * 60.0 - _land_velocity * 11.0) * delta
	_land_dip += _land_velocity * delta

	camera.position = Vector3(sway, bob + _land_dip, 0.0)
	camera.rotation.z = -sway * 0.35


func _update_focus() -> void:
	var target = _find_interactable()
	_set_prompt(target.get_prompt() if target != null else "")


func _set_prompt(prompt: String) -> void:
	if prompt != _last_prompt:
		_last_prompt = prompt
		focus_changed.emit(prompt)


## Walk up from the hit collider until we find a node that can be interacted with.
func _find_interactable() -> Node:
	if not controls_enabled or not ray.is_colliding():
		return null
	var n: Node = ray.get_collider()
	while n != null:
		if n.has_method("interact") and n.has_method("get_prompt"):
			return n
		n = n.get_parent()
	return null
