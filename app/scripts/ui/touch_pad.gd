class_name TouchPad
extends Control
## On-screen gamepad for phones and tablets: D-pad, face buttons for the
## platform, shoulders, START/SELECT, plus pause, rewind and fast-forward.
## Multi-touch; writes RetroInput.touch_mask. Drawn in the pixel style,
## semi-transparent so the game stays visible.

signal pause_pressed

const ALPHA := 0.42

## Face buttons per platform: [retro id, label]; the order sets the layout
## (first = bottom right ... like a real pad).
const FACE := {
	"default": [[RetroInput.A, "A"], [RetroInput.B, "B"]],
	"snes": [[RetroInput.A, "A"], [RetroInput.B, "B"], [RetroInput.X, "X"], [RetroInput.Y, "Y"]],
	"gba": [[RetroInput.A, "A"], [RetroInput.B, "B"]],
	"md": [[RetroInput.A, "C"], [RetroInput.B, "B"], [RetroInput.Y, "A"]],
	"nds": [[RetroInput.A, "A"], [RetroInput.B, "B"], [RetroInput.X, "X"], [RetroInput.Y, "Y"]],
	"32x": [[RetroInput.A, "C"], [RetroInput.B, "B"], [RetroInput.Y, "A"]],
	"ps1": [[RetroInput.A, "O"], [RetroInput.B, "X"], [RetroInput.X, "^"], [RetroInput.Y, "[]"]],
	"pce": [[RetroInput.A, "I"], [RetroInput.B, "II"]],
	"arcade": [[RetroInput.A, "2"], [RetroInput.B, "1"], [RetroInput.X, "4"], [RetroInput.Y, "3"]],
}
const SHOULDERS := ["snes", "gba", "ps1", "arcade", "vb", "nds"]

var system := ""
var _buttons: Array = []     # {rect: Rect2, id: int, label: String, kind: "btn"|"dpad"|"pause"}
var _touches := {}           # touch index -> button index
var _held := {}              # button index -> true
var _dpad_dirs := {}         # touch index -> mask from the D-pad


func setup(system_id: String) -> void:
	system = system_id
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	_buttons.clear()
	var s := size
	var u := minf(s.y / 1080.0, s.x / 1920.0) * 1.0
	var big := 150.0 * u
	var margin := 70.0 * u

	# D-pad: one square area, direction from the touch position
	var dp := 420.0 * u
	_buttons.append({"rect": Rect2(margin, s.y - margin - dp, dp, dp), "id": -1, "label": "", "kind": "dpad"})

	# face buttons in a diamond / row on the right
	var face: Array = FACE.get(system, FACE["default"])
	var cx := s.x - margin - big * 1.6
	var cy := s.y - margin - big * 1.6
	var spots := {
		2: [Vector2(0.75, 0.35), Vector2(-0.75, 0.85)],
		3: [Vector2(1.0, -0.2), Vector2(0.0, 0.55), Vector2(-1.0, 1.1)],
		4: [Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0), Vector2(-1.0, 0.0)],
	}
	var pts: Array = spots[clampi(face.size(), 2, 4)]
	for i in face.size():
		var p: Vector2 = Vector2(cx, cy) + pts[i] * big * 1.05
		_buttons.append({"rect": Rect2(p - Vector2(big, big) / 2.0, Vector2(big, big)), "id": face[i][0], "label": face[i][1], "kind": "btn"})

	var small := Vector2(190, 76) * u
	if system in SHOULDERS:
		_buttons.append({"rect": Rect2(Vector2(margin, margin + 60 * u), small), "id": RetroInput.L, "label": "L", "kind": "btn"})
		_buttons.append({"rect": Rect2(Vector2(s.x - margin - small.x, margin + 60 * u), small), "id": RetroInput.R, "label": "R", "kind": "btn"})
	if system == "ps1":
		_buttons.append({"rect": Rect2(Vector2(margin, margin + 150 * u), small), "id": RetroInput.L2, "label": "L2", "kind": "btn"})
		_buttons.append({"rect": Rect2(Vector2(s.x - margin - small.x, margin + 150 * u), small), "id": RetroInput.R2, "label": "R2", "kind": "btn"})

	var mid := s.x / 2.0
	var bottom := s.y - margin - small.y
	_buttons.append({"rect": Rect2(Vector2(mid - small.x - 20 * u, bottom), small), "id": RetroInput.SELECT, "label": "SELECT", "kind": "btn"})
	_buttons.append({"rect": Rect2(Vector2(mid + 20 * u, bottom), small), "id": RetroInput.START, "label": "START", "kind": "btn"})

	# top centre: rewind, pause, fast forward
	var tool := Vector2(110, 76) * u
	var top := margin * 0.5
	_buttons.append({"rect": Rect2(Vector2(mid - tool.x * 1.5 - 20 * u, top), tool), "id": RetroInput.L2 if system != "ps1" else -2, "label": "<<", "kind": "btn"})
	_buttons.append({"rect": Rect2(Vector2(mid - tool.x / 2.0, top), tool), "id": -1, "label": "II", "kind": "pause"})
	_buttons.append({"rect": Rect2(Vector2(mid + tool.x / 2.0 + 20 * u, top), tool), "id": RetroInput.R2 if system != "ps1" else -2, "label": ">>", "kind": "btn"})
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var i := _hit(event.position)
			if i < 0:
				return
			if _buttons[i].kind == "pause":
				pause_pressed.emit()
				get_viewport().set_input_as_handled()
				return
			_touches[event.index] = i
			_update_dpad(event.index, event.position)
		else:
			_touches.erase(event.index)
			_dpad_dirs.erase(event.index)
		_refresh()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		# sliding a finger moves between buttons, like on a real pad
		var i := _hit(event.position)
		if i >= 0 and _buttons[i].kind != "pause":
			_touches[event.index] = i
		_update_dpad(event.index, event.position)
		_refresh()
		get_viewport().set_input_as_handled()


func release_all() -> void:
	_touches.clear()
	_dpad_dirs.clear()
	_refresh()


func _hit(p: Vector2) -> int:
	for i in _buttons.size():
		var r: Rect2 = _buttons[i].rect
		if r.grow(r.size.x * 0.12).has_point(p):
			return i
	return -1


func _update_dpad(index: int, p: Vector2) -> void:
	if not _touches.has(index) or _buttons[_touches[index]].kind != "dpad":
		_dpad_dirs.erase(index)
		return
	var r: Rect2 = _buttons[_touches[index]].rect
	var v := (p - r.get_center()) / (r.size.x / 2.0)
	var m := 0
	if v.length() > 0.2:
		var ang := fposmod(rad_to_deg(v.angle()), 360.0)
		# 8 directions, 45° each, diagonals press two bits
		if ang < 67.5 or ang >= 292.5: m |= 1 << RetroInput.RIGHT
		if ang >= 112.5 and ang < 247.5: m |= 1 << RetroInput.LEFT
		if ang >= 22.5 and ang < 157.5: m |= 1 << RetroInput.DOWN
		if ang >= 202.5 and ang < 337.5: m |= 1 << RetroInput.UP
	_dpad_dirs[index] = m


func _refresh() -> void:
	var mask := 0
	_held.clear()
	for t in _touches:
		var b: Dictionary = _buttons[_touches[t]]
		_held[_touches[t]] = true
		if b.kind == "btn" and b.id >= 0:
			mask |= 1 << b.id
	for t in _dpad_dirs:
		mask |= _dpad_dirs[t]
	RetroInput.touch_mask = mask
	queue_redraw()


func _exit_tree() -> void:
	RetroInput.touch_mask = 0


# ------------------------------------------------------------------ draw

func _draw() -> void:
	for i in _buttons.size():
		var b: Dictionary = _buttons[i]
		var on: bool = _held.has(i)
		if b.kind == "dpad":
			_draw_dpad(b.rect)
		else:
			_draw_button(b.rect, b.label, on, b.kind == "pause" or b.label.length() > 2)


func _draw_button(r: Rect2, label: String, on: bool, square: bool) -> void:
	var fill := Color(App.C_GOLD if on else App.C_SURFACE_HI, ALPHA + (0.25 if on else 0.0))
	var line := Color(App.C_GOLD if on else App.C_TEXT, 0.55)
	var cut := 0.0 if square else r.size.x * 0.25
	_chamfer(r, cut, fill)
	_chamfer_frame(r, cut, line, 4.0)
	var font := App.font_pixel
	var fs := int(clampf(r.size.y * 0.32, 14, 40))
	if label.length() > 3:
		fs = int(fs * 0.6)
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, r.get_center() + Vector2(-tw.x / 2.0, fs * 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(App.C_BG if on else App.C_TEXT, 0.85))


func _draw_dpad(r: Rect2) -> void:
	var third := r.size / 3.0
	var mask := RetroInput.touch_mask
	var arms := [
		[Rect2(r.position + Vector2(third.x, 0), third), RetroInput.UP],
		[Rect2(r.position + Vector2(third.x, third.y * 2), third), RetroInput.DOWN],
		[Rect2(r.position + Vector2(0, third.y), third), RetroInput.LEFT],
		[Rect2(r.position + Vector2(third.x * 2, third.y), third), RetroInput.RIGHT],
	]
	draw_rect(Rect2(r.position + third, third), Color(App.C_SURFACE_HI, ALPHA))
	for a in arms:
		var on: bool = mask & (1 << a[1]) != 0
		draw_rect(a[0], Color(App.C_GOLD if on else App.C_SURFACE_HI, ALPHA + (0.25 if on else 0.0)))
	# outline of the cross
	var c := Color(App.C_TEXT, 0.5)
	for a in arms:
		_rect_frame(a[0], c, 4.0)
	# arrows pointing outwards
	var dirs := {RetroInput.UP: Vector2.UP, RetroInput.DOWN: Vector2.DOWN, RetroInput.LEFT: Vector2.LEFT, RetroInput.RIGHT: Vector2.RIGHT}
	for a in arms:
		var ctr: Vector2 = (a[0] as Rect2).get_center()
		var d: Vector2 = dirs[a[1]]
		var side := Vector2(-d.y, d.x)
		var k := third.x * 0.2
		draw_colored_polygon(PackedVector2Array([ctr + d * k, ctr - d * k * 0.6 + side * k, ctr - d * k * 0.6 - side * k]),
			Color(App.C_TEXT, 0.7))


func _chamfer(r: Rect2, cut: float, c: Color) -> void:
	if cut <= 0.0:
		draw_rect(r, c)
		return
	var step := cut / 3.0
	for k in 3:
		var inset := cut - step * k
		draw_rect(Rect2(r.position.x + inset, r.position.y + step * k, r.size.x - inset * 2, step), c)
		draw_rect(Rect2(r.position.x + inset, r.end.y - step * (k + 1), r.size.x - inset * 2, step), c)
	draw_rect(Rect2(r.position.x, r.position.y + cut, r.size.x, r.size.y - cut * 2), c)


func _chamfer_frame(r: Rect2, cut: float, c: Color, w: float) -> void:
	if cut <= 0.0:
		_rect_frame(r, c, w)
		return
	draw_rect(Rect2(r.position.x + cut, r.position.y, r.size.x - cut * 2, w), c)
	draw_rect(Rect2(r.position.x + cut, r.end.y - w, r.size.x - cut * 2, w), c)
	draw_rect(Rect2(r.position.x, r.position.y + cut, w, r.size.y - cut * 2), c)
	draw_rect(Rect2(r.end.x - w, r.position.y + cut, w, r.size.y - cut * 2), c)
	var step := cut / 3.0
	for k in 3:
		var a := Vector2(cut - step * (k + 1), step * k)
		draw_rect(Rect2(r.position + a, Vector2(step, step)), c)
		draw_rect(Rect2(Vector2(r.end.x - a.x - step, r.position.y + a.y), Vector2(step, step)), c)
		draw_rect(Rect2(Vector2(r.position.x + a.x, r.end.y - a.y - step), Vector2(step, step)), c)
		draw_rect(Rect2(r.end - a - Vector2(step, step), Vector2(step, step)), c)


func _rect_frame(r: Rect2, c: Color, w: float) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, w)), c)
	draw_rect(Rect2(r.position.x, r.end.y - w, r.size.x, w), c)
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), c)
	draw_rect(Rect2(r.end.x - w, r.position.y, w, r.size.y), c)
