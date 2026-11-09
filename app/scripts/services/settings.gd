extends Node
## Player preferences (autoload "Settings"), saved to user://settings.json.
##   Settings.get_value("volume")  Settings.set_value("volume", 80)
## set_value saves at once and emits changed(key).

signal changed(key: String)

const PATH := "user://settings.json"

## key -> default. Choices for the settings screen live in settings_screen.gd.
const DEFAULTS := {
	"lang": "",                # "" = from the system language on first start
	"volume": 80,              # 0..100
	"ui_sounds": true,
	"fullscreen": false,
	"display": "integer",      # integer | fit | stretch
	"filter": "none",          # none | crt | lcd | smooth
	"resume": true,            # auto-save on exit, continue on start
	"rewind": true,
	"ff_speed": 3,             # 2..8
	"touch_pad": "auto",       # auto | on | off
	"keys": {},                # retro id (String) -> [physical keycodes]
	"pad": {},                 # retro id (String) -> joy button
	"ra_user": "",
	"ra_token": "",            # RetroAchievements login token (never the password)
	"ra_hardcore": false,
	"update_check": true,
	"update_last": 0,
	"update_latest": "",
}

var _data := {}


func _ready() -> void:
	_data = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for k in parsed:
				if DEFAULTS.has(k):
					_data[k] = parsed[k]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			_data.lang = arg.trim_prefix("--lang=")
		elif arg.begins_with("--set="):
			# dev / screenshots: --set=filter=crt (not saved unless something else saves)
			var kv := arg.trim_prefix("--set=").split("=", true, 1)
			if kv.size() == 2 and DEFAULTS.has(kv[0]):
				_data[kv[0]] = str_to_var(kv[1]) if kv[1].is_valid_int() or kv[1] in ["true", "false"] else kv[1]
	if String(_data.lang).is_empty():
		_data.lang = "tr" if OS.get_locale_language() == "tr" else "en"
	apply_volume()
	if not OS.has_feature("movie"):
		_apply_fullscreen.call_deferred()


func get_value(key: String) -> Variant:
	return _data.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	_data[key] = value
	save()
	match key:
		"volume": apply_volume()
		"fullscreen": _apply_fullscreen()
	changed.emit(key)


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_data, "  "))


func apply_volume() -> void:
	var v: float = clampf(float(_data.volume) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(v) if v > 0.0 else -80.0)
	AudioServer.set_bus_mute(0, v <= 0.0)


func _apply_fullscreen() -> void:
	if OS.get_name() in ["Android", "iOS"] or DisplayServer.get_name() == "headless":
		return
	var full: bool = _data.fullscreen
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if full and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not full and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## True when the on-screen gamepad should be shown in the player.
func touch_pad_visible() -> bool:
	match String(_data.touch_pad):
		"on": return true
		"off": return false
	return DisplayServer.is_touchscreen_available() and OS.get_name() in ["Android", "iOS"] \
		and Input.get_connected_joypads().is_empty()
