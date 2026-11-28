extends RefCounted
## Places the project owner's prop models from assets/models/props/ (file
## names in lower case, without ".glb"). They are Y-up, in metres, with the
## origin at floor or table level, and carry no collision, so callers add
## collision boxes where needed. Every function returns null when a model is
## missing, so callers can fall back to the generated versions.

const DIR := "res://assets/models/props/"

static var _cache := {}


static func exists(file: String) -> bool:
	return _scene(file) != null


static func place(parent: Node, file: String, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> Node3D:
	var packed := _scene(file)
	if packed == null:
		return null
	var n: Node3D = packed.instantiate()
	n.position = pos
	n.rotation = rot
	n.scale = scale
	parent.add_child(n)
	return n


static func _scene(file: String) -> PackedScene:
	if _cache.has(file):
		return _cache[file]
	var path := DIR + file + ".glb"
	var packed: PackedScene = null
	if ResourceLoader.exists(path):
		packed = load(path) as PackedScene
	else:
		push_warning("Models: missing prop model %s" % path)
	_cache[file] = packed
	return packed
