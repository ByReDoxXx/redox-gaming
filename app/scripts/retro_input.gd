class_name RetroInput
extends RefCounted
## Reads keyboard and gamepads and pushes the state to RetroHost.
## Gamepad face buttons follow position (SNES layout):
##   bottom = B, right = A, left = Y, top = X.

enum { B, Y, SELECT, START, UP, DOWN, LEFT, RIGHT, A, X, L, R, L2, R2, L3, R3 }

const DEFAULT_KEYS := {
	B: [KEY_Z], A: [KEY_X], Y: [KEY_A], X: [KEY_S],
	L: [KEY_Q], R: [KEY_W],
	SELECT: [KEY_SHIFT, KEY_BACKSPACE], START: [KEY_ENTER],
	UP: [KEY_UP], DOWN: [KEY_DOWN], LEFT: [KEY_LEFT], RIGHT: [KEY_RIGHT],
}

const DEFAULT_JOY := {
	B: JOY_BUTTON_A, A: JOY_BUTTON_B, Y: JOY_BUTTON_X, X: JOY_BUTTON_Y,
	L: JOY_BUTTON_LEFT_SHOULDER, R: JOY_BUTTON_RIGHT_SHOULDER,
	SELECT: JOY_BUTTON_BACK, START: JOY_BUTTON_START,
	UP: JOY_BUTTON_DPAD_UP, DOWN: JOY_BUTTON_DPAD_DOWN,
	LEFT: JOY_BUTTON_DPAD_LEFT, RIGHT: JOY_BUTTON_DPAD_RIGHT,
	L3: JOY_BUTTON_LEFT_STICK, R3: JOY_BUTTON_RIGHT_STICK,
}

const STICK_DEADZONE := 0.5

## Buttons shown on the remap screen, in order: [id, label]
const REMAP := [
	[UP, "UP"], [DOWN, "DOWN"], [LEFT, "LEFT"], [RIGHT, "RIGHT"],
	[A, "A"], [B, "B"], [X, "X"], [Y, "Y"],
	[L, "L"], [R, "R"], [START, "START"], [SELECT, "SELECT"],
]

## Hotkeys outside the game pad (keyboard only)
const KEY_REWIND := KEY_R
const KEY_FAST := KEY_SPACE

static var KEYS := DEFAULT_KEYS.duplicate(true)
static var JOY := DEFAULT_JOY.duplicate(true)
## Bits held on the on-screen gamepad (port 0).
static var touch_mask := 0


## Applies the player's remapping from Settings over the defaults.
static func load_bindings() -> void:
	KEYS = DEFAULT_KEYS.duplicate(true)
	JOY = DEFAULT_JOY.duplicate(true)
	var keys: Dictionary = Settings.get_value("keys")
	for k in keys:
		KEYS[int(k)] = Array(keys[k]).map(func(v): return int(v))
	var pad: Dictionary = Settings.get_value("pad")
	for k in pad:
		JOY[int(k)] = int(pad[k])


static func key_name(id: int) -> String:
	var keys: Array = KEYS.get(id, [])
	return " / ".join(keys.map(func(k): return OS.get_keycode_string(k))) if not keys.is_empty() else "-"


static func pad_name(id: int) -> String:
	if not JOY.has(id):
		return "-"
	var names := {
		JOY_BUTTON_A: "A (alt)", JOY_BUTTON_B: "B (sağ)", JOY_BUTTON_X: "X (sol)", JOY_BUTTON_Y: "Y (üst)",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
		JOY_BUTTON_BACK: "SELECT", JOY_BUTTON_START: "START",
		JOY_BUTTON_DPAD_UP: "D-PAD ↑", JOY_BUTTON_DPAD_DOWN: "D-PAD ↓",
		JOY_BUTTON_DPAD_LEFT: "D-PAD ←", JOY_BUTTON_DPAD_RIGHT: "D-PAD →",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_GUIDE: "GUIDE",
	}
	var b: int = JOY[id]
	var n: String = names.get(b, "#%d" % b)
	if Settings.get_value("lang") == "en":
		n = n.replace("alt", "bottom").replace("sağ", "right").replace("sol", "left").replace("üst", "top")
	return n


## Returns a bitmask per port (port 0 = keyboard + first pad).
static func read_ports() -> Array[int]:
	var ports: Array[int] = [touch_mask, 0]

	for id in KEYS:
		for key in KEYS[id]:
			if Input.is_physical_key_pressed(key):
				ports[0] |= 1 << id

	var pads := Input.get_connected_joypads()
	for i in mini(pads.size(), 2):
		var dev: int = pads[i]
		var mask := 0
		for id in JOY:
			if Input.is_joy_button_pressed(dev, JOY[id]):
				mask |= 1 << id
		var lx := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		var ly := Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		if lx < -STICK_DEADZONE: mask |= 1 << LEFT
		if lx > STICK_DEADZONE: mask |= 1 << RIGHT
		if ly < -STICK_DEADZONE: mask |= 1 << UP
		if ly > STICK_DEADZONE: mask |= 1 << DOWN
		if Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > STICK_DEADZONE: mask |= 1 << L2
		if Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > STICK_DEADZONE: mask |= 1 << R2
		ports[i] |= mask
	return ports


## Buttons pressed since the last frame, so a tap shorter than one frame still
## reaches the game. Filled by latch() from input events.
static var _pulse: Array[int] = [0, 0]


## Call from _input/_unhandled_input with every key / pad button event.
static func latch(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		for id in KEYS:
			if event.physical_keycode in KEYS[id]:
				_pulse[0] |= 1 << id
	elif event is InputEventJoypadButton:
		var pads := Input.get_connected_joypads()
		var port := pads.find(event.device)
		if port < 0 or port > 1:
			return
		for id in JOY:
			if JOY[id] == event.button_index:
				_pulse[port] |= 1 << id


## triggers_are_hotkeys: L2/R2 rewind and fast-forward instead of reaching
## the game (all systems except PlayStation, which needs them).
static func apply(host: Object, triggers_are_hotkeys := true) -> void:
	var ports := read_ports()
	for port in ports.size():
		var mask: int = ports[port] | _pulse[port]
		if triggers_are_hotkeys:
			mask &= ~((1 << L2) | (1 << R2))
		_pulse[port] = 0
		for id in 16:
			host.set_button(port, id, (mask >> id) & 1 == 1)


## Rewind is held: keyboard R or the left trigger (L2) of any pad.
static func rewind_held(triggers := true) -> bool:
	if Input.is_physical_key_pressed(KEY_REWIND):
		return true
	for dev in Input.get_connected_joypads():
		if triggers and Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > STICK_DEADZONE:
			return true
	return touch_mask & (1 << L2) != 0


## Fast forward is held: keyboard Space or the right trigger (R2).
static func fast_held(triggers := true) -> bool:
	if Input.is_physical_key_pressed(KEY_FAST):
		return true
	for dev in Input.get_connected_joypads():
		if triggers and Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > STICK_DEADZONE:
			return true
	return touch_mask & (1 << R2) != 0


## Select + Start together (or the pad's Guide button) opens the pause menu.
static func menu_combo_pressed() -> bool:
	for dev in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_GUIDE):
			return true
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_BACK) and Input.is_joy_button_pressed(dev, JOY_BUTTON_START):
			return true
	return false
