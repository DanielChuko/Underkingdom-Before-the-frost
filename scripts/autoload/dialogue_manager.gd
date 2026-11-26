extends Node
## Branching dialogue runner. Dialogues are JSON files in res://data/dialogue/.
##
## File format (see README for the full reference):
## {
##   "id": "king_prelude",
##   "start": "first_node",
##   "on_end": {"set": ["flag"], "events": ["event_name"]},
##   "nodes": {
##     "first_node": {"speaker": "King", "text": "...", "action": "stage direction",
##                    "cue": "world_cue", "set": ["flag"], "events": ["event"],
##                    "next": "other_node"},
##     "a_choice":   {"speaker": "King", "text": "...",
##                    "choices": [{"text": "...", "next": "x", "if": "!asked", "set": ["asked"]}]},
##     "a_branch":   {"branch": [{"if": "flag", "next": "x"}], "next": "fallback"}
##   }
## }
## "next": "end" (or a missing "next") ends the conversation.

signal dialogue_started(dialogue_id: String)
signal line_shown(line: Dictionary)
signal dialogue_ended(dialogue_id: String)
## Emitted when a node has a "cue"; the level script reacts (e.g. the king walks).
signal cue(cue_name: String)

const DIALOGUE_DIR := "res://data/dialogue/"
const BARKS_PATH := "res://data/dialogue/barks.json"

var _cache: Dictionary = {}
var _barks: Dictionary = {}
var _barks_loaded := false
var _current_id := ""
var _node: Dictionary = {}
var _choices: Array = []


func is_active() -> bool:
	return _current_id != ""


func start(dialogue_id: String) -> void:
	if is_active():
		return
	var d: Dictionary = _load(dialogue_id)
	if d.is_empty():
		return
	_current_id = dialogue_id
	dialogue_started.emit(dialogue_id)
	_goto(str(d.get("start", "")))


## Continue past a line that has no choices.
func advance() -> void:
	if not is_active() or not _choices.is_empty():
		return
	_goto(str(_node.get("next", "end")))


## Pick one of the currently visible choices (0-based).
func choose(index: int) -> void:
	if not is_active() or index < 0 or index >= _choices.size():
		return
	var c: Dictionary = _choices[index]
	_apply(c)
	_goto(str(c.get("next", "end")))


## One-liners for NPCs that do not open a dialogue (guards, the cook...).
func get_barks(key: String) -> Array:
	if not _barks_loaded:
		_barks_loaded = true
		var data = _read_json(BARKS_PATH)
		if typeof(data) == TYPE_DICTIONARY:
			_barks = data
	var lines = _barks.get(key, [])
	return lines if typeof(lines) == TYPE_ARRAY else []


func _goto(node_id: String) -> void:
	var hops := 0
	while true:
		if node_id == "" or node_id == "end":
			_finish()
			return
		var nodes: Dictionary = _cache[_current_id]["nodes"]
		if not nodes.has(node_id):
			push_error("Dialogue '%s': missing node '%s'" % [_current_id, node_id])
			_finish()
			return
		_node = nodes[node_id]
		_apply(_node)
		if _node.has("text"):
			break
		# Logic-only node: follow its branch without showing anything.
		node_id = _resolve_branch(_node)
		hops += 1
		if hops > 64:
			push_error("Dialogue '%s': branch loop" % _current_id)
			_finish()
			return

	_choices = []
	var texts: Array = []
	for c in _node.get("choices", []):
		if _check(str(c.get("if", ""))):
			_choices.append(c)
			texts.append(str(c["text"]))
	line_shown.emit({
		"speaker": str(_node.get("speaker", "")),
		"text": str(_node["text"]),
		"action": str(_node.get("action", "")),
		"choices": texts,
	})


func _resolve_branch(n: Dictionary) -> String:
	for b in n.get("branch", []):
		if _check(str(b.get("if", ""))):
			return str(b.get("next", "end"))
	return str(n.get("next", "end"))


## Conditions: "" (always), "flag", "!flag", or several joined by commas (all must hold).
func _check(condition: String) -> bool:
	if condition.strip_edges() == "":
		return true
	for part in condition.split(",", false):
		var p: String = str(part).strip_edges()
		if p.begins_with("!"):
			if GameState.has_flag(p.substr(1)):
				return false
		elif not GameState.has_flag(p):
			return false
	return true


func _apply(x: Dictionary) -> void:
	for f in x.get("set", []):
		GameState.set_flag(str(f), true)
	for f in x.get("clear", []):
		GameState.set_flag(str(f), false)
	if x.has("cue"):
		cue.emit(str(x["cue"]))
	for e in x.get("events", []):
		GameState.raise(str(e))


func _finish() -> void:
	var finished_id := _current_id
	var on_end: Dictionary = {}
	if _cache.has(finished_id):
		on_end = _cache[finished_id].get("on_end", {})
	_current_id = ""
	_node = {}
	_choices = []
	_apply(on_end)
	dialogue_ended.emit(finished_id)


func _load(dialogue_id: String) -> Dictionary:
	if _cache.has(dialogue_id):
		return _cache[dialogue_id]
	var path := DIALOGUE_DIR + dialogue_id + ".json"
	var data = _read_json(path)
	if typeof(data) != TYPE_DICTIONARY or not data.has("nodes") or not data.has("start"):
		push_error("Dialogue: '%s' is missing or malformed" % path)
		return {}
	_cache[dialogue_id] = data
	return data


func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Dialogue: cannot open %s" % path)
		return null
	return JSON.parse_string(f.get_as_text())
