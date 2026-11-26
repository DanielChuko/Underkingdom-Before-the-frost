extends StaticBody3D
## A simple interactable object: shows a message and/or emits `used`.

signal used

var prompt := "Inspect"
var message := ""


func get_prompt() -> String:
	return "[E] " + prompt


func interact(_player: Node) -> void:
	if message != "":
		GameState.toast(message)
	used.emit()
