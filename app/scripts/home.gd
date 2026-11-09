extends Control
## Home: RedoX logo on top, platform carousel underneath (left/right to browse,
## A to open). "Recently played" and "Favourites" lead the carousel when they
## have games. Y continues the last game, START opens the settings.
## Rules: docs/DESIGN.md → Home.

const SPACING := 400.0          # distance between neighbouring platforms
const SIZE_CENTER := 360.0
const SCALES := [1.0, 0.58, 0.40]
const ALPHAS := [1.0, 0.55, 0.22]
const SLIDE := 0.18
const SWIPE_MIN := 80.0

var _ids: Array = []
var _counts := {}
var _index := 0
var _tiles: Array[TextureRect] = []
var _stage: Control
var _carousel: Control
var _name_label: Label
var _count_label: Label
var _dots: HBoxContainer
var _drag := 0.0
var _update_badge: Button
var _gear: Button
var _last_game := {}


func _ready() -> void:
	theme = App.theme
	_ids = []
	var recent := Stats.recent()
	if not recent.is_empty():
		_ids.append("recent")
		_counts["recent"] = recent.size()
		_last_game = recent[0]
	var favs := Stats.favorites()
	if not favs.is_empty():
		_ids.append("favorites")
		_counts["favorites"] = favs.size()
	_ids.append_array(App.system_ids())
	for id in App.system_ids():
		_counts[id] = Library.count(id)
	_index = maxi(0, _ids.find(App.last_system))

	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	add_child(_stage)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = App.SAFE_Y
	col.offset_bottom = -App.SAFE_Y
	col.offset_left = App.SAFE_X
	col.offset_right = -App.SAFE_X
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/svg/logo.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.custom_minimum_size = Vector2(0, 260)
	col.add_child(logo)

	_carousel = Control.new()
	_carousel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_carousel.clip_contents = false
	col.add_child(_carousel)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 14)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(info)
	_name_label = App.pixel_label("", 40, App.C_TEXT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_name_label)
	_count_label = App.body_label("", 40, App.C_MUTED)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_count_label)

	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 12)
	info.add_child(_dots)
	for i in _ids.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(12, 12)
		_dots.add_child(d)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 36
	col.add_child(spacer)
	var hints := [[["<", ">"], App.t("PICK_PLATFORM")], [["A"], App.t("OPEN_GAMES")]]
	if not _last_game.is_empty():
		hints.append([["Y"], App.t("CONTINUE") + ": " + _short(String(_last_game.title))])
	hints.append([["^", "START"], App.t("SETTINGS")])
	col.add_child(HintBar.build(hints, true))

	_build_corner_buttons()

	for id in _ids:
		var t := TextureRect.new()
		t.texture = App.system_icon(id)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		t.size = Vector2(SIZE_CENTER, SIZE_CENTER)
		t.pivot_offset = t.size / 2.0
		t.gui_input.connect(_on_tile_input.bind(t))
		_carousel.add_child(t)
		_tiles.append(t)

	_build_arrows()
	_carousel.resized.connect(_layout.bind(false))
	_layout.call_deferred(false)

	# Dev shortcut: Godot ... -- --rom=res://roms/redox_test.nes
	var dev_system := App.dev_arg("--system")
	if not dev_system.is_empty():
		App.last_system = dev_system
		App.go.call_deferred("games")
	var dev_scene := App.dev_arg("--scene")
	if not dev_scene.is_empty():
		App.go.call_deferred(dev_scene)
	var dev_rom := App.dev_arg("--rom")
	if not dev_rom.is_empty():
		App.selected_game = dev_rom
		App.selected_system = Library.find_game(dev_rom).get("system", App.system_of(dev_rom))
		App.last_system = App.selected_system
		App.go.call_deferred("player")


# --------------------------------------------------------------- carousel

## Shortest signed distance from the selected platform (the list wraps around).
func _offset(i: int) -> int:
	var n := _ids.size()
	var d := wrapi(i - _index, 0, n)
	return d - n if d > n / 2 else d


func _layout(animate := true) -> void:
	var center := _carousel.size / 2.0
	for i in _tiles.size():
		var t := _tiles[i]
		var d := _offset(i)
		var a := absi(d)
		var level := mini(a, 2)
		var target_pos := Vector2(center.x + d * SPACING * (0.82 if a > 1 else 1.0), center.y) - t.size / 2.0
		var s: float = SCALES[level]
		var alpha: float = ALPHAS[level] if a <= 2 else 0.0
		t.mouse_filter = Control.MOUSE_FILTER_STOP if a <= 2 else Control.MOUSE_FILTER_IGNORE
		t.z_index = 10 - a
		# items wrapping from one side to the other jump instead of flying across
		var jump := absf(t.position.x - target_pos.x) > SPACING * 3.0
		if animate and not jump:
			var tw := t.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(t, "position", target_pos, SLIDE)
			tw.tween_property(t, "scale", Vector2(s, s), SLIDE)
			tw.tween_property(t, "modulate:a", alpha, SLIDE)
		else:
			t.position = target_pos
			t.scale = Vector2(s, s)
			t.modulate.a = alpha

	var id: String = _ids[_index]
	var count: int = _counts.get(id, 0)
	_name_label.text = App.system_name(id)
	_name_label.add_theme_color_override("font_color", App.system_accent(id).lerp(App.C_TEXT, 0.25))
	var line := (App.t("ONE_GAME") if count == 1 else App.t("N_GAMES", [count])) if count > 0 else App.t("NO_GAMES_YET")
	if Catalog.has_store(id):
		line += "  ·  " + App.t("FREE_GAMES_AVAILABLE")
	_count_label.text = line
	for i in _dots.get_child_count():
		var dot: ColorRect = _dots.get_child(i)
		dot.color = App.system_accent(id) if i == _index else App.C_LINE
		dot.custom_minimum_size = Vector2(28, 12) if i == _index else Vector2(12, 12)
	_stage.queue_redraw()


func _move(step: int) -> void:
	Sfx.play("move")
	_index = wrapi(_index + step, 0, _ids.size())
	App.last_system = _ids[_index]
	_layout(true)


func _open() -> void:
	Sfx.play("select")
	App.last_system = _ids[_index]
	App.go("games")


func _continue_last() -> void:
	if _last_game.is_empty():
		Sfx.play("error")
		return
	Sfx.play("select")
	App.selected_game = _last_game.path
	App.selected_system = _last_game.system
	App.last_system = _last_game.system
	App.go("player" if not Cores.find(_last_game.system).is_empty() else "games")


func _open_settings() -> void:
	Sfx.play("select")
	App.go("settings")


func _short(t: String) -> String:
	return t if t.length() <= 18 else t.substr(0, 17) + "…"


## Settings gear (top right) and the new-version badge (top left). Mouse and
## touch click them; a remote reaches them with UP from the carousel.
func _build_corner_buttons() -> void:
	var gear := Button.new()
	var gi := TextureRect.new()
	gi.texture = load("res://assets/svg/ui/settings.svg")
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gi.offset_left = 16
	gi.offset_top = 16
	gi.offset_right = -16
	gi.offset_bottom = -16
	gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear.add_child(gi)
	gear.focus_mode = Control.FOCUS_ALL
	_gear = gear
	gear.custom_minimum_size = Vector2(96, 96)
	gear.tooltip_text = App.t("SETTINGS")
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -App.SAFE_X - 96
	gear.offset_right = -App.SAFE_X
	gear.offset_top = App.SAFE_Y
	gear.offset_bottom = App.SAFE_Y + 96
	gear.pressed.connect(_open_settings)
	add_child(gear)

	_update_badge = Button.new()
	_update_badge.focus_mode = Control.FOCUS_ALL
	_update_badge.add_theme_font_size_override("font_size", 16)
	_update_badge.add_theme_stylebox_override("normal", App.box(App.C_GOLD.darkened(0.55), App.C_GOLD))
	_update_badge.add_theme_color_override("font_color", App.C_GOLD)
	_update_badge.position = Vector2(App.SAFE_X, App.SAFE_Y)
	_update_badge.pressed.connect(func(): App.go("settings"))
	_update_badge.visible = false
	add_child(_update_badge)
	_show_update(Updates.available())
	Updates.checked.connect(func(_v): _show_update(Updates.available()))
	Updates.check_daily()


func _show_update(version: String) -> void:
	if _update_badge and not version.is_empty():
		_update_badge.text = App.t("UPDATE_AVAILABLE", [version])
		_update_badge.visible = true


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	# top row (gear, update badge) has focus: A is handled by the button itself
	var top := get_viewport().gui_get_focus_owner()
	if top != null and (top == _gear or top == _update_badge):
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_cancel"):
			top.release_focus()
			Sfx.play("move")
		elif event.is_action_pressed("ui_left") and top == _gear and _update_badge.visible:
			_update_badge.grab_focus()
		elif event.is_action_pressed("ui_right") and top == _update_badge:
			_gear.grab_focus()
		elif not (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true)):
			return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up"):
		_gear.grab_focus()
	elif event.is_action_pressed("ui_left", true):
		_move(-1)
	elif event.is_action_pressed("ui_right", true):
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_open()
		return
	elif event.is_action_pressed("rx_continue"):
		get_viewport().set_input_as_handled()
		_continue_last()
		return
	elif event.is_action_pressed("rx_settings"):
		get_viewport().set_input_as_handled()
		_open_settings()
		return
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			_move(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			_move(1)
		else:
			return
	elif event is InputEventScreenDrag:
		_drag += event.relative.x
		if absf(_drag) > SWIPE_MIN:
			_move(-1 if _drag > 0 else 1)
			_drag = 0.0
	elif event is InputEventScreenTouch and not event.pressed:
		_drag = 0.0
		return
	else:
		return
	get_viewport().set_input_as_handled()


## Android back button on the home screen leaves the app (every other screen
## handles it as "back"; quit_on_go_back is off in the project settings).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and App.take_back():
		get_tree().quit()


func _on_tile_input(event: InputEvent, tile: TextureRect) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var d := _offset(_tiles.find(tile))
		if d == 0:
			_open()
		else:
			_move(d)
		accept_event()


func _build_arrows() -> void:
	for dir in [-1, 1]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.custom_minimum_size = Vector2(96, 120)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		b.pressed.connect(_move.bind(dir))
		b.draw.connect(_draw_arrow.bind(b, dir))
		b.mouse_entered.connect(b.queue_redraw)
		b.mouse_exited.connect(b.queue_redraw)
		_carousel.add_child(b)
		var place := func():
			b.position = Vector2(0 if dir < 0 else _carousel.size.x - b.size.x, (_carousel.size.y - b.size.y) / 2.0)
		_carousel.resized.connect(place)
		place.call_deferred()


## Chunky pixel triangle (8 px steps).
func _draw_arrow(b: Button, dir: int) -> void:
	var c := App.C_GOLD if b.is_hovered() else App.C_MUTED
	var cy := b.size.y / 2.0
	for i in 6:
		var h := (6 - i) * 16.0
		var x := 32.0 + i * 8.0 if dir > 0 else b.size.x - 40.0 - i * 8.0
		b.draw_rect(Rect2(x, cy - h / 2.0, 8, h), c)


# ------------------------------------------------------------------ stage

## Background: dark navy, faint pixel stars, a stepped glow in the selected
## platform's colour and a pixel pedestal under it.
func _draw_stage() -> void:
	var r := _stage.get_rect()
	_stage.draw_rect(r, App.C_BG)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		var p := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var s := 4.0 if rng.randf() > 0.8 else 2.0
		_stage.draw_rect(Rect2(p.floor(), Vector2(s, s)), Color(App.C_TEXT, 0.12 + rng.randf() * 0.15))

	if _carousel == null or _ids.is_empty():
		return
	var accent := App.system_accent(_ids[_index])
	var c := _carousel.global_position - _stage.global_position + _carousel.size / 2.0

	# stepped glow: 4 rings of 16 px blocks
	var block := 16.0
	var radius := 300.0
	var y := -radius
	while y <= radius:
		var x := -radius
		while x <= radius:
			var dist := Vector2(x, y * 1.25).length() / radius
			if dist < 1.0:
				var step := floorf((1.0 - dist) * 4.0) / 4.0
				_stage.draw_rect(Rect2((c + Vector2(x, y)).floor(), Vector2(block, block)), Color(accent, 0.05 + step * 0.13))
			x += block
		y += block

	# pedestal
	var top := c.y + SIZE_CENTER / 2.0 - 28.0
	var widths := [360.0, 400.0, 424.0, 432.0, 424.0, 400.0]
	for i in widths.size():
		var w: float = widths[i]
		var col := accent if i == 0 else App.C_SURFACE_HI.lerp(App.C_BG, i * 0.12)
		_stage.draw_rect(Rect2(Vector2(c.x - w / 2.0, top + i * 8.0).floor(), Vector2(w, 8)), col)
