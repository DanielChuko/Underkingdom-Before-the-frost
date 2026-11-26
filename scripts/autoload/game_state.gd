extends Node
## Global game state: story flags, the current act, input setup, and a small
## event bus that the quest tracker and world scripts listen to.

signal event_raised(event_name: String)
signal toast_requested(text: String)
signal bark_requested(speaker: String, text: String)

## 0 = Prelude, 1 = Act 1 ("Two months later").
var act := 0
var flags: Dictionary = {}


func _ready() -> void:
	_register_inputs()


func set_flag(flag: String, value := true) -> void:
	flags[flag] = value


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


## Broadcast a story event (e.g. "reached_kings_hall"). Quests complete
## objectives by listening for these names.
func raise(event_name: String) -> void:
	event_raised.emit(event_name)


## Show a short message on screen (locked doors, inspecting props, ...).
func toast(text: String) -> void:
	toast_requested.emit(text)


## Show a one-line remark from an NPC without opening a dialogue.
func bark(speaker: String, text: String) -> void:
	bark_requested.emit(speaker, text)


func reset() -> void:
	act = 0
	flags.clear()


func _register_inputs() -> void:
	var bindings := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"advance": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
		"journal": [KEY_J, KEY_TAB],
		"release_mouse": [KEY_ESCAPE],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
