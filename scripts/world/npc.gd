extends CharacterBody3D
## Greybox NPC. Talking either starts a dialogue (dialogue_id) or, once
## done_flag is set or when there is no dialogue, says the next bark line.
## Optional patrol between points; pauses while any dialogue is running.

var display_name := "Stranger"
## Name used by dialogue lines (defaults to display_name). The character
## animates talking while a line from this speaker is on screen.
var speaker_name := ""
## The Humanoid rig (scripts/characters/humanoid.gd), set by greybox.npc().
var body
var dialogue_id := ""
var done_flag := ""
var bark_key := ""
var patrol_points: Array = []
var patrol_speed := 1.3
var seated := false:
	set(value):
		seated = value
		if body != null:
			body.pose = "sit" if value else "stand"

var _bark_index := 0
var _patrol_index := 0
var _wait := 0.0
var _scripted := false
var _last_position := Vector3.ZERO
var _turn_tween: Tween


func _ready() -> void:
	_last_position = global_position
	Dialogue.line_shown.connect(_on_line_shown)


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


func turn_to(target: Vector3, duration := -1.0) -> void:
	if seated:
		return
	var d := target - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	turn_to_yaw(atan2(-d.x, -d.z), duration)


## Turns in place, easing in and out; by default the time grows with the
## angle (a quarter turn takes about 0.75 s), so a body never snaps round.
## The rig sees the turning and steps round with the head leading.
func turn_to_yaw(yaw: float, duration := -1.0) -> void:
	var from := rotation.y
	var angle := absf(angle_difference(from, yaw))
	if duration < 0.0:
		duration = clampf(0.25 + angle * 0.32, 0.3, 1.3)
	if _turn_tween != null and _turn_tween.is_valid():
		_turn_tween.kill()
	_turn_tween = create_tween()
	_turn_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn_tween.tween_method(func(t: float) -> void: rotation.y = lerp_angle(from, yaw, t), 0.0, 1.0, duration)


## Scripted walk used by dialogue cues (e.g. the king walking to his crest).
func walk_to(target: Vector3, final_yaw: float, speed := 1.2) -> void:
	_scripted = true
	var d := target - global_position
	d.y = 0.0
	if d.length() > 0.05:
		var yaw := atan2(-d.x, -d.z)
		var turn_time := clampf(0.25 + absf(angle_difference(rotation.y, yaw)) * 0.32, 0.3, 1.3)
		turn_to_yaw(yaw, turn_time)
		var tw := create_tween()
		tw.tween_interval(turn_time * 0.8)
		tw.tween_property(self, "global_position", target, d.length() / speed)
		await tw.finished
	turn_to_yaw(final_yaw)
	_scripted = false


func _on_line_shown(line: Dictionary) -> void:
	var who := speaker_name if speaker_name != "" else display_name
	if body != null and str(line.get("speaker", "")) == who:
		body.speak(str(line.get("text", "")).length() / 55.0 + 0.4, str(line.get("text", "")))


func _physics_process(delta: float) -> void:
	# Feed the rig our real ground speed so patrols and scripted walks animate.
	if body != null and delta > 0.0:
		var moved := global_position - _last_position
		moved.y = 0.0
		body.speed = lerpf(body.speed, moved.length() / delta, 0.5)
	_last_position = global_position
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
		# Turn round to face the next leg while pausing, rather than walking off sideways.
		var next: Vector3 = patrol_points[_patrol_index] - global_position
		if Vector2(next.x, next.z).length() > 0.1:
			turn_to_yaw(atan2(-next.x, -next.z))
		return
	var dir := to.normalized()
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(delta * 3.5, 0.0, 1.0))
	# Slow down while still turning into the new direction.
	var facing := clampf(cos(angle_difference(rotation.y, want)), 0.0, 1.0)
	velocity = dir * patrol_speed * facing * facing
	move_and_slide()
