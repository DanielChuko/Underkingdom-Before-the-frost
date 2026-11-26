extends RefCounted
## Procedural character meshes.
##
## loft():  smooth tubes from a list of elliptical cross-sections (torsos, limbs,
##          sleeves, boots) or open curved panels (surcoats, aprons, capes).
## head():  a sphere sculpted into a human head: jaw, chin, brow ridge, eye
##          sockets, nose, cheekbones and lips, with skin shading in vertex colours.
## shell(): a layer over the head (hair, beards, mail coif, helmet dome) cut to a mask.
##
## Front faces wind clockwise (Godot's convention). Meshes carry no UVs: their
## materials use triplanar mapping. Vertex colours carry grime and skin shading.

const RX := 0.074
const RY := 0.108
const RZ := 0.095
const HEAD_ROWS := 48
const HEAD_COLS := 64

static var _cache: Dictionary = {}


## sections: [[y, rx, rz], ...] or [[y, rx, rz, cx, cz], ...] in any order.
## arc: [] for a closed tube, or [start, end] radians for an open panel
##      (angle 0 = +X, PI/2 = +Z (back), 3PI/2 = -Z (front)).
## shade: vertex brightness at the top and bottom (dirt toward hems).
## jag: random lift of the bottom edge (a torn, uneven hem).
static func loft(sections: Array, segments := 16, arc := [], shade := [1.0, 1.0], jag := 0.0, caps := true, stains := 0.0) -> ArrayMesh:
	var key := "loft|%s|%d|%s|%s|%.4f|%s|%.3f" % [str(sections), segments, str(arc), str(shade), jag, caps, stains]
	if _cache.has(key):
		return _cache[key]
	var secs := sections.duplicate()
	secs.sort_custom(func(p, q) -> bool: return p[0] > q[0])
	var closed := arc.is_empty()
	var a0: float = 0.0 if closed else float(arc[0])
	var a1: float = TAU if closed else float(arc[1])
	var y_top: float = secs[0][0]
	var y_bot: float = secs[secs.size() - 1][0]
	var rings: Array = []
	for i in secs.size():
		var s: Array = secs[i]
		var cx: float = s[3] if s.size() > 3 else 0.0
		var cz: float = s[4] if s.size() > 4 else 0.0
		var ring: Array = []
		for j in segments + 1:
			var a := lerpf(a0, a1, float(j) / segments)
			if closed and j == segments:
				a = a0
			var y: float = s[0]
			if i == secs.size() - 1 and jag > 0.0:
				y += (_hash(Vector3(a, 0.0, 1.7)) - 0.35) * jag
			ring.append(Vector3(cx + cos(a) * s[1], y, cz + sin(a) * s[2]))
		rings.append(ring)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colour := func(p: Vector3) -> Color:
		var t := 0.0 if absf(y_top - y_bot) < 0.0001 else clampf((y_top - p.y) / (y_top - y_bot), 0.0, 1.0)
		var v := lerpf(float(shade[0]), float(shade[1]), t * t) * (0.94 + _hash(p) * 0.12)
		if stains > 0.0:
			var blot := _blotch(p * 9.0)
			v *= 1.0 - stains * clampf((blot - 0.55) * 4.0, 0.0, 1.0)
		return Color(v, v * (1.0 - (1.0 - v) * 0.08), v * (1.0 - (1.0 - v) * 0.15))
	for i in rings.size() - 1:
		for j in segments:
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][j + 1]
			var c: Vector3 = rings[i + 1][j + 1]
			var d: Vector3 = rings[i + 1][j]
			_tri(st, a, d, c, colour)
			_tri(st, a, c, b, colour)
	if closed and caps:
		var top: Array = rings[0]
		var bot: Array = rings[rings.size() - 1]
		var ct := _centre(top, segments)
		var cb := _centre(bot, segments)
		for j in segments:
			_tri(st, ct, top[j], top[j + 1], colour)
			_tri(st, cb, bot[j + 1], bot[j], colour)
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Point on the sculpted head surface for a unit direction (face toward -Z).
static func head_point(d: Vector3, offset := 0.0) -> Vector3:
	var p := Vector3(d.x * RX, d.y * RY, d.z * RZ)
	# Narrower jaw and a neck-ward taper at the back of the lower head.
	if p.y < -0.01:
		var k := clampf((-p.y - 0.01) / 0.09, 0.0, 1.0)
		p.x *= 1.0 - 0.2 * pow(k, 1.3)
		if p.z > 0.0:
			p.z *= 1.0 - 0.4 * k
	# Flatten the underside into a jaw line instead of an egg point.
	if p.y < -0.065:
		p.y = -0.065 - (-0.065 - p.y) * 0.55
	var front := clampf(-p.z / RZ * 1.6 - 0.3, 0.0, 1.0)
	var off := 0.0
	off += _bump(p, 0.0, 0.036, 0.05, 0.011, 0.011)  # brow ridge
	for sx in [-0.031, 0.031]:
		off -= _bump(p, sx, 0.016, 0.017, 0.013, 0.012)  # eye sockets
		off += _bump(p, sx * 1.55, -0.012, 0.02, 0.018, 0.007)  # cheekbones
		off += _bump(p, sx * 0.33, -0.031, 0.007, 0.006, 0.005)  # nostrils
	off += _bump(p, 0.0, -0.002, 0.0085, 0.028, 0.024)  # nose bridge
	off += _bump(p, 0.0, -0.026, 0.012, 0.012, 0.016)  # nose tip
	off += _bump(p, 0.0, -0.05, 0.022, 0.0065, 0.006)  # lips
	off -= _bump(p, 0.0, -0.0545, 0.024, 0.0018, 0.004)  # mouth line
	off += _bump(p, 0.0, -0.08, 0.022, 0.014, 0.013)  # chin
	return p + d * (off * front + offset)


## The sculpted head. stubble darkens the jaw; ruddy reddens nose and cheeks.
static func head(stubble := false, ruddy := 0.3) -> ArrayMesh:
	var key := "head|%s|%.2f" % [stubble, ruddy]
	if _cache.has(key):
		return _cache[key]
	var grid := _head_grid(0.0)
	var colour := func(p: Vector3) -> Color:
		var front := clampf(-p.z / RZ * 1.6 - 0.3, 0.0, 1.0)
		var c := Color(1, 1, 1)
		for sx in [-0.031, 0.031]:
			var sock := _bump(p, sx, 0.016, 0.022, 0.016, 1.0) * front
			c = c.lerp(Color(0.62, 0.5, 0.48), sock * 0.75)
			var cheek := _bump(p, sx * 1.6, -0.02, 0.022, 0.02, 1.0) * front
			c = c.lerp(Color(1.0, 0.72, 0.68), cheek * ruddy)
		c = c.lerp(Color(1.0, 0.7, 0.65), _bump(p, 0.0, -0.022, 0.014, 0.02, 1.0) * front * ruddy * 1.2)
		c = c.lerp(Color(0.78, 0.48, 0.45), _bump(p, 0.0, -0.05, 0.02, 0.006, 1.0) * front * 0.8)
		if stubble:
			var jaw := clampf((-p.y - 0.035) / 0.03, 0.0, 1.0) * clampf(1.0 - p.z / 0.05, 0.0, 1.0)
			jaw *= 1.0 - _bump(p, 0.0, -0.05, 0.02, 0.008, 1.0) * front
			c = c.lerp(Color(0.55, 0.5, 0.48), jaw * 0.7)
		return c
	var mesh := _grid_mesh(grid, colour, func(_p: Vector3, _q: Vector3) -> bool: return true)
	_cache[key] = mesh
	return mesh


## A layer over the head. kind: hair | beard | long_beard | coif | helmet | cap
static func shell(kind: String, thickness := 0.012) -> ArrayMesh:
	var key := "shell|%s|%.3f" % [kind, thickness]
	if _cache.has(key):
		return _cache[key]
	var grid := _head_grid(thickness, kind)
	var mask := func(p: Vector3, base: Vector3) -> bool:
		var j := (_hash(base * 31.0) - 0.5) * 0.012
		match kind:
			"hair":
				var t := clampf((-base.z / RZ + 1.0) * 0.5, 0.0, 1.0)
				return base.y > lerpf(-0.085, 0.058, pow(t, 1.5)) + j and not _ear_gap(base)
			"cap":
				var t2 := clampf((-base.z / RZ + 1.0) * 0.5, 0.0, 1.0)
				return base.y > lerpf(-0.03, 0.05, t2) + j * 0.3
			"helmet":
				return base.y > 0.032
			"coif":
				var face := base.z < -0.015 and absf(base.x) < 0.053 and base.y > -0.08 and base.y < 0.048
				return not face and base.y > -0.11
			"beard", "long_beard":
				var lips := absf(base.x) < 0.024 and base.y > -0.064 and base.y < -0.04
				return base.y < -0.022 + j and base.z < 0.03 and not lips and base.y < 0.0
		return false
	var colour := func(p: Vector3) -> Color:
		var v := 0.9 + _hash(p * 40.0) * 0.2
		return Color(v, v, v)
	var mesh := _grid_mesh(grid, colour, mask)
	_cache[key] = mesh
	return mesh


## The point on the front of the sculpted face at head-local (x, y).
static func face_point(x: float, y: float, offset := 0.0) -> Vector3:
	var dx := clampf(x / RX, -0.99, 0.99)
	var dy := clampf(y / RY, -0.99, 0.99)
	var d := Vector3(dx, dy, -sqrt(maxf(0.0, 1.0 - dx * dx - dy * dy)))
	return head_point(d, offset)


## Where the eyeball centre sits for a socket at head-local x.
static func eye_centre(x: float) -> Vector3:
	return face_point(x, 0.016) + Vector3(0, 0, 0.0095)


# --- Internals ----------------------------------------------------------------------

static func _head_grid(thickness: float, kind := "") -> Array:
	var grid: Array = []
	for i in HEAD_ROWS + 1:
		var theta := PI * float(i) / HEAD_ROWS
		var row: Array = []
		for j in HEAD_COLS + 1:
			var phi := TAU * float(j % HEAD_COLS) / HEAD_COLS
			var d := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			var base := head_point(d)
			var p := head_point(d, thickness)
			if kind == "long_beard":
				var k := clampf((-base.y - 0.05) / 0.05, 0.0, 1.0) * clampf(-base.z / 0.05, 0.0, 1.0)
				p += Vector3(0, -k * 0.07, -k * 0.025) + d * k * 0.01
			elif kind == "beard":
				var k2 := clampf((-base.y - 0.06) / 0.04, 0.0, 1.0)
				p += d * k2 * 0.01
			elif kind == "helmet":
				p += d * 0.006
			row.append([p, base])
		grid.append(row)
	return grid


static func _grid_mesh(grid: Array, colour: Callable, mask: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for i in grid.size() - 1:
		for j in grid[i].size() - 1:
			var a: Array = grid[i][j]
			var b: Array = grid[i][j + 1]
			var c: Array = grid[i + 1][j + 1]
			var d: Array = grid[i + 1][j]
			var mid: Vector3 = (a[1] + b[1] + c[1] + d[1]) * 0.25
			if not mask.call(mid, mid):
				continue
			any = true
			_tri(st, a[0], d[0], c[0], colour)
			_tri(st, a[0], c[0], b[0], colour)
	if not any:
		return ArrayMesh.new()
	st.index()
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Callable) -> void:
	for p in [a, b, c]:
		st.set_color(colour.call(p))
		st.add_vertex(p)


static func _centre(ring: Array, segments: int) -> Vector3:
	var c := Vector3.ZERO
	for j in segments:
		c += ring[j]
	return c / segments


static func _bump(p: Vector3, cx: float, cy: float, sx: float, sy: float, amount: float) -> float:
	var dx := (p.x - cx) / sx
	var dy := (p.y - cy) / sy
	return amount * exp(-dx * dx - dy * dy)


static func _ear_gap(p: Vector3) -> bool:
	return absf(p.x) > 0.055 and p.y < 0.02 and p.y > -0.04 and absf(p.z) < 0.03


static func _hash(p: Vector3) -> float:
	var h := sin(p.x * 127.1 + p.y * 311.7 + p.z * 74.7) * 43758.5453
	return h - floor(h)


static func _blotch(p: Vector3) -> float:
	return 0.5 + 0.25 * sin(p.x * 1.7 + sin(p.y * 2.3)) * cos(p.z * 1.9 + p.y) + 0.25 * sin(p.y * 3.1 + p.x * 0.7)
