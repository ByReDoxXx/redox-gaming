extends Node
## Global state: design tokens, theme, systems/cores, which game to start.
## Design rules: docs/DESIGN.md

# ---- colour tokens
const C_BG := Color("0a0e1c")
const C_SURFACE := Color("141a2e")
const C_SURFACE_HI := Color("1f2742")
const C_LINE := Color("2a3352")
const C_RED := Color("e0301e")
const C_ORANGE := Color("ff7a1a")
const C_GOLD := Color("ffc23d")
const C_TEXT := Color("f5e6c8")
const C_MUTED := Color("a3a9c2")
const C_SHADOW := Color(0, 0, 0, 0.6)

# ---- spacing
const SAFE_X := 96
const SAFE_Y := 54
const FOCUS_BORDER := 6
const BORDER := 4
const LIFT := 8.0
const MOTION := 0.1

## id -> name, accent, core file (without platform suffix), extensions
const SYSTEMS := {
	"nes": {"name": "NES", "accent": "e0301e", "core": "fceumm_libretro", "ext": ["nes", "fds", "unf"]},
	"snes": {"name": "SNES", "accent": "8b5cf6", "core": "snes9x_libretro", "ext": ["sfc", "smc"]},
	"gb": {"name": "GAME BOY", "accent": "84a90f", "core": "gambatte_libretro", "ext": ["gb"]},
	"gbc": {"name": "GB COLOR", "accent": "14b8a6", "core": "gambatte_libretro", "ext": ["gbc"]},
	"gba": {"name": "GB ADVANCE", "accent": "6366f1", "core": "mgba_libretro", "ext": ["gba"]},
	"md": {"name": "MEGA DRIVE", "accent": "2563eb", "core": "genesis_plus_gx_libretro", "ext": ["md", "gen", "smd"]},
	"sms": {"name": "MASTER SYSTEM", "accent": "f97316", "core": "genesis_plus_gx_libretro", "ext": ["sms"]},
	"gg": {"name": "GAME GEAR", "accent": "0ea5e9", "core": "genesis_plus_gx_libretro", "ext": ["gg"]},
	"pce": {"name": "PC ENGINE", "accent": "f59e0b", "core": "mednafen_pce_fast_libretro", "ext": ["pce"]},
	"a26": {"name": "ATARI 2600", "accent": "a16207", "core": "stella_libretro", "ext": ["a26"]},
	"ngp": {"name": "NEO GEO POCKET", "accent": "d946ef", "core": "mednafen_ngp_libretro", "ext": ["ngp", "ngc"]},
	"ps1": {"name": "PLAYSTATION", "accent": "94a3b8", "core": "pcsx_rearmed_libretro", "ext": ["cue", "chd", "pbp"]},
	"arcade": {"name": "ARCADE", "accent": "ec4899", "core": "fbneo_libretro", "ext": ["zip"]},
}

const SAVE_DIR := "user://saves"
const STATE_DIR := "user://states"
const SYSTEM_DIR := "user://system"
const USER_ROM_DIR := "user://roms"

var theme: Theme
var font_pixel: Font
var font_body: Font
var selected_game := ""
var selected_system := ""
var last_system := "nes"

## Screens that list games from every platform (carousel entries before the systems).
const VIRTUAL := {
	"recent": {"key": "RECENT", "accent": "ffc23d"},
	"favorites": {"key": "FAVORITES", "accent": "ff7a1a"},
}

## Menu actions beyond Godot's ui_* ones: [action, gamepad button, keys...]
const ACTIONS := [
	["rx_continue", JOY_BUTTON_Y, KEY_C],
	["rx_settings", JOY_BUTTON_START, KEY_F1, KEY_S],
	["rx_fav", JOY_BUTTON_X, KEY_F],
	["rx_search", JOY_BUTTON_Y, KEY_SLASH, KEY_F3],
	["rx_sort", JOY_BUTTON_BACK, KEY_O],
]

var _ext_to_system := {}
var _icons := {}
var _last_back := -1000


## Android reports one press of the remote's back button twice: as a KEY_BACK
## key event and as NOTIFICATION_WM_GO_BACK_REQUEST. Screens call this for
## both; it is true only for the first of the pair.
func take_back() -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_back < 250:
		return false
	_last_back = now
	return true


func _ready() -> void:
	font_pixel = load("res://assets/fonts/PressStart2P-Regular.ttf")
	font_body = load("res://assets/fonts/VT323-Regular.ttf")
	for id in SYSTEMS:
		for e in SYSTEMS[id]["ext"]:
			_ext_to_system[e] = id
	theme = _build_theme()
	RetroInput.load_bindings()
	for a in ACTIONS:
		if InputMap.has_action(a[0]):
			continue
		InputMap.add_action(a[0])
		var jb := InputEventJoypadButton.new()
		jb.button_index = a[1]
		InputMap.action_add_event(a[0], jb)
		for i in range(2, a.size()):
			var k := InputEventKey.new()
			k.physical_keycode = a[i]
			InputMap.action_add_event(a[0], k)
	# Movie Maker screenshots: ignore stray keyboard/mouse input on the window
	if OS.has_feature("movie"):
		get_tree().root.gui_disable_input = true
		get_tree().root.set_process_input(false)
	for dir in [SAVE_DIR, STATE_DIR, SYSTEM_DIR, USER_ROM_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)


# ---------------------------------------------------------------- systems

func system_of(path: String) -> String:
	return _ext_to_system.get(path.get_extension().to_lower(), "")


## Interface text in the chosen language (scripts/strings.gd).
func t(key: String, args: Array = []) -> String:
	var row = Strings.T.get(key)
	if row == null:
		return key
	var s: String = row[Strings.lang_index(Settings.get_value("lang"))]
	return s % args if not args.is_empty() else s


func is_virtual(id: String) -> bool:
	return VIRTUAL.has(id)


func system_name(id: String) -> String:
	if id == "all":
		return t("ALL")
	if VIRTUAL.has(id):
		return t(VIRTUAL[id]["key"])
	return SYSTEMS[id]["name"] if SYSTEMS.has(id) else "?"


func system_accent(id: String) -> Color:
	if id == "all":
		return C_GOLD
	if VIRTUAL.has(id):
		return Color(VIRTUAL[id]["accent"])
	return Color(SYSTEMS[id]["accent"]) if SYSTEMS.has(id) else C_LINE


## Large illustrated icon (art/gemini → systems_hd); falls back to the 32 px one.
func system_icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var hd := "res://assets/svg/systems/%s.svg" % id
		var ui := "res://assets/svg/ui/%s.svg" % id
		if ResourceLoader.exists(hd):
			_icons[id] = load(hd)
		elif ResourceLoader.exists(ui):
			_icons[id] = load(ui)
		else:
			_icons[id] = load("res://assets/svg/pixel/%s.svg" % id)
	return _icons[id]


func system_ids() -> Array:
	return SYSTEMS.keys()


var _dev_used := {}


## Developer shortcuts after "--" on the command line (--rom=, --system=,
## --tab=, --detail=, --pause). Each one is handed out once per run, so going
## back to a screen does not trigger it again. Returns "" when absent, "1" for flags.
func dev_arg(name: String) -> String:
	if _dev_used.has(name):
		return ""
	for arg in OS.get_cmdline_user_args():
		if arg == name or arg.begins_with(name + "="):
			_dev_used[name] = true
			return "1" if arg == name else arg.trim_prefix(name + "=")
	return ""


## Changes screen on the next frame, so the caller (often an input handler)
## can finish safely: touching get_viewport() after an immediate scene change
## crashed release builds.
func go(scene: String) -> void:
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").hush()
	get_tree().change_scene_to_file.call_deferred("res://scenes/%s.tscn" % scene)


func platform_folder() -> String:
	match OS.get_name():
		"Windows": return "windows"
		"Android": return "android"
		_: return "linux"


## "Super_Mario (USA) [!].nes" -> "SUPER MARIO"
func pretty_title(path: String) -> String:
	var t := path.get_file().get_basename().replace("_", " ")
	var re := RegEx.create_from_string("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]")
	t = re.sub(t, "", true).strip_edges()
	return (t if not t.is_empty() else path.get_file().get_basename()).to_upper()


## Loads a PNG/JPG from user:// or an absolute path (not imported resources).
func load_image_texture(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	# trust the bytes, not the extension: some ".png" files are really JPEG/WebP
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50:
		err = img.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = img.load_jpg_from_buffer(bytes)
	elif bytes.slice(0, 4).get_string_from_ascii() == "RIFF":
		err = img.load_webp_from_buffer(bytes)
	elif bytes[0] == 0x42 and bytes[1] == 0x4D:
		err = img.load_bmp_from_buffer(bytes)
	return ImageTexture.create_from_image(img) if err == OK else null


# ------------------------------------------------------------------ theme

func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_pixel
	t.default_font_size = 24

	t.set_color("font_color", "Label", C_TEXT)

	t.set_stylebox("normal", "Button", box(C_SURFACE, C_LINE))
	t.set_stylebox("hover", "Button", box(C_SURFACE_HI, C_ORANGE))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), C_GOLD, FOCUS_BORDER))
	t.set_stylebox("pressed", "Button", box(C_RED, C_GOLD))
	t.set_stylebox("hover_pressed", "Button", box(C_RED, C_GOLD))
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_GOLD)
	t.set_color("font_focus_color", "Button", C_GOLD)
	t.set_color("font_pressed_color", "Button", C_TEXT)
	t.set_font_size("font_size", "Button", 24)

	var panel := box(C_BG.lerp(Color.BLACK, 0.25), C_ORANGE, FOCUS_BORDER)
	panel.set_content_margin_all(40)
	panel.shadow_color = C_SHADOW
	panel.shadow_size = 1
	panel.shadow_offset = Vector2(12, 12)
	t.set_stylebox("panel", "PanelContainer", panel)

	var edit := box(C_SURFACE, C_LINE)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), C_GOLD, FOCUS_BORDER))
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", C_MUTED)
	t.set_color("caret_color", "LineEdit", C_GOLD)
	t.set_font_size("font_size", "LineEdit", 24)

	var check_off := box(C_SURFACE, C_LINE)
	t.set_stylebox("normal", "CheckButton", check_off)

	var scroll := StyleBoxEmpty.new()
	t.set_stylebox("panel", "ScrollContainer", scroll)
	return t


## Square corners and a thick border: the pixel-art frame used everywhere.
func box(fill: Color, border: Color, width := BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	return s


func body_label(text: String, size := 36, color := C_MUTED) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func pixel_label(text: String, size := 24, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
