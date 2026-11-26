extends Node3D
## Story flow for the vertical slice:
##   Prelude: gate (fixed camera) -> guard dialogue -> castle corridor (player
##   control) -> king's hall -> king dialogue -> title card
##   Act 1:   "Two months later" -> wake in Casimir's room -> roam the castle ->
##   king's briefing -> leave through the kitchen -> end of slice.

const HudScript := preload("res://scripts/ui/hud.gd")
const PlayerScript := preload("res://scripts/player/player.gd")
const CastleBuilder := preload("res://scripts/world/castle_builder.gd")
const GateBuilder := preload("res://scripts/world/gate_builder.gd")

var hud
var player
var world: Node3D
var castle: Dictionary = {}
var world_env: WorldEnvironment
var _awaiting_restart := false
var _leaving := false


func _ready() -> void:
	world_env = WorldEnvironment.new()
	add_child(world_env)
	hud = HudScript.new()
	add_child(hud)
	Dialogue.dialogue_started.connect(_on_dialogue_started)
	Dialogue.dialogue_ended.connect(_on_dialogue_ended)
	Dialogue.cue.connect(_on_cue)
	_play_prelude()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif _awaiting_restart and event.is_action_pressed("advance"):
		GameState.reset()
		Quests.reset()
		get_tree().reload_current_scene()


# --- Prelude -----------------------------------------------------------------

func _play_prelude() -> void:
	GameState.act = 0
	_use_exterior_environment()
	var gate: Dictionary = GateBuilder.new().build()
	_set_world(gate["root"])
	var cam: Camera3D = gate["camera"]
	cam.make_current()
	cam.rotation.x = -1.15  # looking down at the map
	hud.set_black(1.0)
	await hud.caption("Envoy Casimir Vael of Hollowmere checks his map one last time...", 3.0)
	await hud.fade_to(0.0, 1.5)
	var look_up := create_tween()
	look_up.tween_property(cam, "rotation:x", 0.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await look_up.finished
	hud.bark("Casimir", "Looks like I've arrived!")
	await get_tree().create_timer(2.5).timeout

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Dialogue.start("gate_guard")
	await Dialogue.dialogue_ended

	await hud.fade_to(1.0, 1.2)
	await hud.caption("The gates groan open. Casimir follows the muddy path between the houses, up to the castle.", 3.5)
	_enter_castle(0)
	Quests.start("q_prelude")
	await hud.fade_to(0.0, 1.2)
	_give_control()
	hud.toast("WASD to move, mouse to look, E to interact, J for your journal.", 6.0)


func _to_act_one() -> void:
	player.set_controls(false)
	await hud.fade_to(1.0, 2.0)
	await hud.show_title("UNDERKINGDOM", "Before the Frost", 4.0)
	await hud.card_in("Two months later", 2.5)
	GameState.act = 1
	_enter_castle(1)
	Quests.start("q_act1")
	hud.set_black(0.0)
	await hud.card_out(1.5)
	_give_control()


func _leave_castle() -> void:
	if _leaving:
		return
	if not GameState.has_flag("act1_briefed"):
		hud.toast("I should see the king before I leave.")
		return
	_leaving = true
	player.set_controls(false)
	GameState.raise("left_castle")
	await hud.fade_to(1.0, 1.5)
	await hud.caption("Casimir steps out into the bright morning. The dig site awaits...", 3.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await hud.show_title("End of the prelude slice", "Press Enter to play again", 0.0)
	_awaiting_restart = true


# --- World setup ---------------------------------------------------------------

func _enter_castle(act: int) -> void:
	_use_interior_environment()
	castle = CastleBuilder.new().build(act)
	_set_world(castle["root"])
	player = PlayerScript.new()
	player.position = castle["spawn_position"]
	player.rotation.y = castle["spawn_yaw"]
	world.add_child(player)
	player.set_controls(false)
	player.focus_changed.connect(hud.set_prompt)
	castle["hall_trigger"].body_entered.connect(_on_hall_entered)
	castle["exit_door"].used.connect(_leave_castle)


func _set_world(new_world: Node3D) -> void:
	if world != null:
		world.queue_free()
	player = null
	world = new_world
	add_child(world)


func _give_control() -> void:
	if player == null:
		return
	player.set_controls(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _use_interior_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.55, 0.5)
	env.ambient_light_energy = 0.35 if GameState.act == 0 else 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	world_env.environment = env


func _use_exterior_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.45, 0.65)
	sky_mat.sky_horizon_color = Color(0.75, 0.72, 0.68)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.008
	world_env.environment = env


# --- Dialogue hooks --------------------------------------------------------------

func _on_dialogue_started(_id: String) -> void:
	if player != null:
		player.set_controls(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_dialogue_ended(id: String) -> void:
	match id:
		"gate_guard":
			pass  # handled by _play_prelude
		"king_prelude":
			_to_act_one()
		_:
			_give_control()


func _on_cue(cue_name: String) -> void:
	var npcs: Dictionary = castle.get("npcs", {})
	var king = npcs.get("king")
	if king == null:
		return
	match cue_name:
		"king_to_crest":
			king.walk_to(Vector3(12.5, 0.0, -51.0), 0.0)
		"king_face_player":
			if player != null:
				king.turn_to(player.global_position, 0.8)


func _on_hall_entered(body: Node3D) -> void:
	if body == player:
		GameState.raise("reached_kings_hall")
