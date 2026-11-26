extends Node
## Data-driven quest tracker. Quests live in res://data/quests.json.
## Each objective completes when GameState raises its "complete_on" event.
## Objectives are ordered; an event may also complete a later objective,
## which skips the ones before it.

signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)

const DATA_PATH := "res://data/quests.json"

var tracked_id := ""
var _defs: Dictionary = {}
var _order: Array = []
## quest id -> {"step": int, "done": bool}
var _state: Dictionary = {}


func _ready() -> void:
	_load()
	GameState.event_raised.connect(_on_event)


func start(quest_id: String) -> void:
	if not _defs.has(quest_id):
		push_error("Quests: unknown quest '%s'" % quest_id)
		return
	if _state.has(quest_id):
		return
	_state[quest_id] = {"step": 0, "done": false}
	_order.append(quest_id)
	tracked_id = quest_id
	quest_updated.emit(quest_id)


func is_done(quest_id: String) -> bool:
	return _state.has(quest_id) and bool(_state[quest_id]["done"])


func title_of(quest_id: String) -> String:
	var q: Dictionary = _defs.get(quest_id, {})
	return str(q.get("title", quest_id))


## The quest shown in the corner tracker: {"title", "objective"} or {}.
func get_tracked() -> Dictionary:
	if tracked_id == "" or not _state.has(tracked_id):
		return {}
	var st: Dictionary = _state[tracked_id]
	var q: Dictionary = _defs[tracked_id]
	var objective := "Completed"
	if not st["done"]:
		objective = str(q["objectives"][int(st["step"])]["text"])
	return {"title": str(q["title"]), "objective": objective}


## Plain-text journal of every started quest, newest first.
func journal_text() -> String:
	if _order.is_empty():
		return "No quests yet."
	var out := ""
	for i in range(_order.size() - 1, -1, -1):
		var qid: String = _order[i]
		var q: Dictionary = _defs[qid]
		var st: Dictionary = _state[qid]
		out += "%s%s\n" % [str(q["title"]), "  (completed)" if st["done"] else ""]
		out += "%s\n" % str(q.get("description", ""))
		var objs: Array = q["objectives"]
		var shown: int = objs.size() if st["done"] else int(st["step"]) + 1
		for j in range(shown):
			var mark := "[x]" if j < int(st["step"]) or st["done"] else "[  ]"
			out += "   %s %s\n" % [mark, str(objs[j]["text"])]
		out += "\n"
	return out.strip_edges()


func reset() -> void:
	_state.clear()
	_order.clear()
	tracked_id = ""


func _on_event(event_name: String) -> void:
	for qid in _order:
		var st: Dictionary = _state[qid]
		if st["done"]:
			continue
		var objs: Array = _defs[qid]["objectives"]
		for i in range(int(st["step"]), objs.size()):
			if str(objs[i].get("complete_on", "")) == event_name:
				st["step"] = i + 1
				if int(st["step"]) >= objs.size():
					st["done"] = true
					quest_completed.emit(qid)
				quest_updated.emit(qid)
				break


func _load() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("Quests: cannot open %s" % DATA_PATH)
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Quests: %s is not valid JSON" % DATA_PATH)
		return
	for q in data.get("quests", []):
		_defs[str(q["id"])] = q
