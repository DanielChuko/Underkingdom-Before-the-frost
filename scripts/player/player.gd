extends CharacterBody3D
## First-person controller: mouse look, WASD movement, sprint, head bob,
## and a camera raycast that finds anything with an interact() method.
## Interactables also provide get_prompt() for the on-screen hint.

signal focus_changed(prompt: String)

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.6
const ACCELERATION := 10.0
const INTERACT_RANGE := 2.6
const EYE_HEIGHT := 1.65

var mouse_sensitivity := 0.0025
var controls_enabled := true
var head: Node3D
var camera: Camera3D
var ray: RayCast3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _last_prompt := ""
var _bob_time := 0.0


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.9
	add_child(col)

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
	if not is_on_floor():
		velocity.y -= _gravity * delta

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
	move_and_slide()

	_head_bob(delta, input.length() > 0.1, speed)
	_update_focus()


func _head_bob(delta: float, moving: bool, speed: float) -> void:
	if moving and is_on_floor():
		_bob_time += delta * speed * 2.4
		camera.position.y = sin(_bob_time) * 0.035
	else:
		camera.position.y = lerpf(camera.position.y, 0.0, clampf(delta * 8.0, 0.0, 1.0))


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
