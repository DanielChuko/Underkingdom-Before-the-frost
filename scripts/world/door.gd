extends Node3D
## A hinged door with one or two leaves. Built by greybox.gd's door().
## Locked doors only show a message; unlocked ones swing open and shut.

var label := "door"
var locked := false
var locked_message := "It's locked."
var is_open := false
## Each leaf: {"node": Node3D pivot, "closed": yaw, "open": yaw}
var leaves: Array = []


func get_prompt() -> String:
	if locked:
		return "[E] Try the %s" % label
	return "[E] %s the %s" % ["Close" if is_open else "Open", label]


func interact(_player: Node) -> void:
	if locked:
		GameState.toast(locked_message)
		return
	set_open(not is_open)


func set_open(open: bool, instant := false) -> void:
	is_open = open
	for leaf in leaves:
		var pivot: Node3D = leaf["node"]
		var target: float = leaf["open"] if open else leaf["closed"]
		if instant:
			pivot.rotation.y = target
		else:
			var tw := create_tween()
			tw.tween_property(pivot, "rotation:y", target, 0.7) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
