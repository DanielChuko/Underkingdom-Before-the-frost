extends CharacterBody3D
## Greybox NPC. Talking either starts a dialogue (dialogue_id) or, once
## done_flag is set or when there is no dialogue, says the next bark line.
## Optional patrol between points; pauses while any dialogue is running.

var display_name := "Stranger"
var dialogue_id := ""
var done_flag := ""
var bark_key := ""
var patrol_points: Array = []
var patrol_speed := 1.3
var seated := false

var _bark_index := 0
var _patrol_index := 0
var _wait := 0.0
var _scripted := false


func get_prompt() -> String:
	return "[E] Talk to " + display_name


func interact(player) -> void:
	_wait = 3.0
	if player is Node3D:
		turn_to(player.global_position)
	if dialogue_id != "" and (done_flag == "" or not GameState.has_flag(done_flag)):
		Dialogue.start(dialogue_id)
		return
	if bark_key != "":
		var lines: Array = Dialogue.get_barks(bark_key)
		if not lines.is_empty():
			GameState.bark(display_name, str(lines[_bark_index % lines.size()]))
			_bark_index += 1


func turn_to(target: Vector3, duration := 0.4) -> void:
	if seated:
		return
	var d := target - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	turn_to_yaw(atan2(-d.x, -d.z), duration)


func turn_to_yaw(yaw: float, duration := 0.4) -> void:
	var from := rotation.y
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void: rotation.y = lerp_angle(from, yaw, t), 0.0, 1.0, duration)


## Scripted walk used by dialogue cues (e.g. the king walking to his crest).
func walk_to(target: Vector3, final_yaw: float, speed := 1.2) -> void:
	_scripted = true
	var d := target - global_position
	d.y = 0.0
	if d.length() > 0.05:
		turn_to_yaw(atan2(-d.x, -d.z), 0.3)
		var tw := create_tween()
		tw.tween_interval(0.3)
		tw.tween_property(self, "global_position", target, d.length() / speed)
		await tw.finished
	turn_to_yaw(final_yaw, 0.5)
	_scripted = false


func _physics_process(delta: float) -> void:
	if patrol_points.is_empty() or _scripted:
		return
	if Dialogue.is_active():
		velocity = Vector3.ZERO
		return
	if _wait > 0.0:
		_wait -= delta
		return
	var target: Vector3 = patrol_points[_patrol_index]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.15:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		_wait = 1.5
		return
	var dir := to.normalized()
	velocity = dir * patrol_speed
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 6.0, 0.0, 1.0))
	move_and_slide()
