class_name RetroInput
extends RefCounted
## Reads keyboard and gamepads and pushes the state to RetroHost.
## Gamepad face buttons follow position (SNES layout):
##   bottom = B, right = A, left = Y, top = X.

enum { B, Y, SELECT, START, UP, DOWN, LEFT, RIGHT, A, X, L, R, L2, R2, L3, R3 }

const KEYS := {
	B: [KEY_Z], A: [KEY_X], Y: [KEY_A], X: [KEY_S],
	L: [KEY_Q], R: [KEY_W],
	SELECT: [KEY_SHIFT, KEY_BACKSPACE], START: [KEY_ENTER],
	UP: [KEY_UP], DOWN: [KEY_DOWN], LEFT: [KEY_LEFT], RIGHT: [KEY_RIGHT],
}

const JOY := {
	B: JOY_BUTTON_A, A: JOY_BUTTON_B, Y: JOY_BUTTON_X, X: JOY_BUTTON_Y,
	L: JOY_BUTTON_LEFT_SHOULDER, R: JOY_BUTTON_RIGHT_SHOULDER,
	SELECT: JOY_BUTTON_BACK, START: JOY_BUTTON_START,
	UP: JOY_BUTTON_DPAD_UP, DOWN: JOY_BUTTON_DPAD_DOWN,
	LEFT: JOY_BUTTON_DPAD_LEFT, RIGHT: JOY_BUTTON_DPAD_RIGHT,
	L3: JOY_BUTTON_LEFT_STICK, R3: JOY_BUTTON_RIGHT_STICK,
}

const STICK_DEADZONE := 0.5


## Returns a bitmask per port (port 0 = keyboard + first pad).
static func read_ports() -> Array[int]:
	var ports: Array[int] = [0, 0]

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


static func apply(host: Object) -> void:
	var ports := read_ports()
	for port in ports.size():
		var mask: int = ports[port] | _pulse[port]
		_pulse[port] = 0
		for id in 16:
			host.set_button(port, id, (mask >> id) & 1 == 1)


## Select + Start together (or the pad's Guide button) opens the pause menu.
static func menu_combo_pressed() -> bool:
	for dev in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_GUIDE):
			return true
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_BACK) and Input.is_joy_button_pressed(dev, JOY_BUTTON_START):
			return true
	return false
