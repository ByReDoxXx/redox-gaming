extends Control
## Home: RedoX logo on top, platform carousel underneath (left/right to browse,
## A to open). Rules: docs/DESIGN.md → Home.

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


func _ready() -> void:
	theme = App.theme
	_ids = App.system_ids()
	for id in _ids:
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
	col.add_child(HintBar.build([[["<", ">"], "PLATFORM SEÇ"], [["A"], "OYUNLARI AÇ"]], true))

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
	var line := "%d OYUN" % count if count > 0 else "HENÜZ OYUN YOK"
	if Catalog.has_store(id):
		line += "  ·  ÜCRETSİZ OYUNLAR VAR"
	_count_label.text = line
	for i in _dots.get_child_count():
		var dot: ColorRect = _dots.get_child(i)
		dot.color = App.system_accent(id) if i == _index else App.C_LINE
		dot.custom_minimum_size = Vector2(28, 12) if i == _index else Vector2(12, 12)
	_stage.queue_redraw()


func _move(step: int) -> void:
	_index = wrapi(_index + step, 0, _ids.size())
	App.last_system = _ids[_index]
	_layout(true)


func _open() -> void:
	App.last_system = _ids[_index]
	App.go("games")


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		_move(-1)
	elif event.is_action_pressed("ui_right", true):
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_open()
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
