extends Control
## Runs the selected game: picture (size + filter from Settings), sound,
## input (keyboard, pads, on-screen pad), rewind / fast forward, pause menu
## with 4 save slots, cheats and achievements. Saves an automatic state on
## exit and continues from it next time ("resume").

const SLOTS := 4
const SHADERS := {
	"crt": "res://shaders/crt.gdshader",
	"lcd": "res://shaders/lcd.gdshader",
	"smooth": "res://shaders/smooth.gdshader",
}

var host: Object  # RetroHost (created through ClassDB so a missing extension shows an error instead of a parse failure)
var _game := ""
var _system := ""
var _screen: TextureRect
var _audio: AudioStreamPlayer
var _pause: PanelContainer
var _menu: VBoxContainer
var _page := "main"
var _scrim: ColorRect
var _toast: Label
var _status: Label            # rewind / fast-forward indicator
var _touch: TouchPad
var _combo_was_down := false
var _quitting := false
var _triggers_hotkeys := true


func _ready() -> void:
	theme = App.theme

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_screen = TextureRect.new()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_screen)
	_apply_filter()

	_audio = AudioStreamPlayer.new()
	add_child(_audio)

	_status = App.pixel_label("", 24, App.C_GOLD)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 8)
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_status.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_status.offset_right = -24
	_status.offset_top = 24
	add_child(_status)

	_build_pause_menu()
	_build_toast()
	resized.connect(_layout_screen)
	Settings.changed.connect(_on_setting)

	if not ClassDB.class_exists("RetroHost"):
		_fail(App.t("NO_EXTENSION"))
		return
	host = ClassDB.instantiate("RetroHost")
	add_child(host)
	host.set_system_directory(App.SYSTEM_DIR)
	host.set_save_directory(App.SAVE_DIR)
	host.video_size_changed.connect(func(_s): _layout_screen())

	_game = App.selected_game
	_system = App.selected_system
	if _system.is_empty():
		_system = Library.find_game(_game).get("system", App.system_of(_game))
	_triggers_hotkeys = _system != "ps1"
	var core := Cores.find(_system)
	if core.is_empty():
		_fail(App.t("NO_CORE", [App.system_name(_system)]))
		return
	if not host.load_core(core):
		_fail(App.t("CORE_OPEN_FAILED", [core]))
		return
	if not host.load_game(_game):
		_fail(App.t("GAME_OPEN_FAILED", [_game]))
		return

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = host.get_sample_rate()
	gen.buffer_length = 0.1
	_audio.stream = gen
	_audio.play()
	host.set_audio_playback(_audio.get_stream_playback())

	_screen.texture = host.get_texture()
	_layout_screen()
	_apply_gameplay_settings()
	Cheats.apply(host, _system, _game)
	Stats.begin(_game, _system)
	Achievements.start_game(host, _game, _system)
	Achievements.reset_requested.connect(_on_ra_reset)

	if Settings.get_value("resume") and FileAccess.file_exists(_auto_path()):
		# let the core settle one frame before restoring
		host.step_frame()
		if host.load_state(FileAccess.get_file_as_bytes(_auto_path())):
			_show_toast(App.t("RESUMED"))

	if Settings.touch_pad_visible() or not App.dev_arg("--touch").is_empty():
		_touch = TouchPad.new()
		add_child(_touch)
		move_child(_touch, _scrim.get_index())
		_touch.setup(_system)
		_touch.pause_pressed.connect(_toggle_pause)

	# Dev shortcut for screenshots: ... -- --rom=... --pause
	if not App.dev_arg("--pause").is_empty():
		var page := App.dev_arg("--page")
		get_tree().create_timer(0.3).timeout.connect(func():
			_toggle_pause()
			if not page.is_empty():
				_show_page(page))


func _process(_delta: float) -> void:
	if host == null or not host.is_game_loaded():
		return
	var combo := RetroInput.menu_combo_pressed()
	if combo and not _combo_was_down:
		_toggle_pause()
	_combo_was_down = combo
	if _pause.visible:
		return
	RetroInput.apply(host, _triggers_hotkeys)

	var hardcore: bool = Settings.get_value("ra_hardcore")
	var rew: bool = Settings.get_value("rewind") and not hardcore and RetroInput.rewind_held(_triggers_hotkeys)
	var fast := RetroInput.fast_held(_triggers_hotkeys)
	host.set_rewinding(rew)
	host.set_speed(float(Settings.get_value("ff_speed")) if fast and not rew else 1.0)
	if rew:
		_status.text = App.t("REWINDING")
	elif fast:
		_status.text = App.t("FAST_FORWARD", [int(Settings.get_value("ff_speed"))])
	else:
		_status.text = ""


func _input(event: InputEvent) -> void:
	# remember quick taps so they reach the game even if released within a frame
	if host != null and host.is_game_loaded() and not _pause.visible:
		RetroInput.latch(event)


func _unhandled_input(event: InputEvent) -> void:
	if host == null:
		return
	if _is_back_key(event):
		get_viewport().set_input_as_handled()
		if App.take_back():
			_back_pressed()
		return
	if _pause.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _page != "main":
			Sfx.play("back")
			_show_page("main")
		else:
			_toggle_pause()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			_save_slot(1)
		elif event.keycode == KEY_F4:
			_load_slot(1)


## Remote / phone back button: closes a sub page, otherwise toggles pause.
func _back_pressed() -> void:
	if _pause.visible and _page != "main":
		Sfx.play("back")
		_show_page("main")
	else:
		_toggle_pause()


func _is_back_key(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and event.keycode == KEY_BACK


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if host != null and App.take_back():
				_back_pressed()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_save_auto()
			Stats.end()
		NOTIFICATION_APPLICATION_PAUSED:
			# Android: the app may be killed in the background
			_save_auto()
			if host and not _pause.visible:
				_toggle_pause()


func _exit_tree() -> void:
	Achievements.stop_game()


func _on_ra_reset() -> void:
	if host and host.is_game_loaded():
		host.reset()


# ---------------------------------------------------------------- picture

func _layout_screen() -> void:
	if host == null or not host.is_game_loaded():
		return
	var frame: Vector2i = host.get_frame_size()
	if frame.y <= 0:
		return
	var aspect: float = host.get_aspect_ratio()
	var avail := size
	var w: float
	var h: float
	match String(Settings.get_value("display")):
		"stretch":
			w = avail.x
			h = avail.y
		"fit":
			h = minf(avail.y, avail.x / aspect)
			w = h * aspect
		_:
			# largest whole-number scale that fits, using the core's aspect ratio
			var scale_y := floorf(avail.y / frame.y)
			while scale_y > 1 and frame.y * scale_y * aspect > avail.x:
				scale_y -= 1
			scale_y = maxf(scale_y, 1.0)
			h = frame.y * scale_y
			w = roundf(h * aspect)
	_screen.size = Vector2(w, h).round()
	_screen.position = ((avail - _screen.size) / 2.0).floor()


func _apply_filter() -> void:
	var f: String = Settings.get_value("filter")
	_screen.material = null
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if SHADERS.has(f):
		var m := ShaderMaterial.new()
		m.shader = load(SHADERS[f])
		_screen.material = m
	if f == "smooth":
		_screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _apply_gameplay_settings() -> void:
	if host == null or not host.is_game_loaded():
		return
	host.set_rewind_enabled(Settings.get_value("rewind") and not Settings.get_value("ra_hardcore"))


func _on_setting(key: String) -> void:
	match key:
		"filter": _apply_filter()
		"display": _layout_screen()
		"rewind", "ra_hardcore": _apply_gameplay_settings()


# ---------------------------------------------------------------- pause menu

func _build_pause_menu() -> void:
	_scrim = ColorRect.new()
	_scrim.color = Color(App.C_BG, 0.78)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.visible = false
	add_child(_scrim)

	_pause = PanelContainer.new()
	_pause.visible = false
	_pause.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_pause)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 16)
	_pause.add_child(_menu)


func _toggle_pause() -> void:
	if host == null or not host.is_game_loaded():
		return
	_pause.visible = not _pause.visible
	_scrim.visible = _pause.visible
	host.set_paused(_pause.visible)
	host.set_rewinding(false)
	host.set_speed(1.0)
	_status.text = ""
	if _touch:
		_touch.release_all()
		_touch.visible = not _pause.visible
	if _pause.visible:
		host.clear_input()
		Sfx.play("select")
		_show_page("main")


func _show_page(page: String, arg: Variant = null) -> void:
	_page = page
	for c in _menu.get_children():
		_menu.remove_child(c)
		c.queue_free()
	var first: Control
	match page:
		"main": first = _page_main()
		"save": first = _page_slots(true)
		"load": first = _page_slots(false)
		"cheats": first = _page_cheats()
		"cheat_add": first = _page_cheat_add()
		"achievements": first = Achievements.build_page(_menu, self)
	_pause.reset_size()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	Sfx.hush()
	if first:
		first.grab_focus.call_deferred()


func _title(text: String, sub := "") -> void:
	var title := App.pixel_label(text, 32, App.C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(title)
	if not sub.is_empty():
		var l := App.body_label(sub, 32, App.C_MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 900
		_menu.add_child(l)


func _menu_button(text: String, cb: Callable, parent: Control = null, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.x = 640
	b.disabled = not enabled
	b.pressed.connect(cb)
	(parent if parent else _menu).add_child(b)
	return b


func _page_main() -> Control:
	var hardcore: bool = Settings.get_value("ra_hardcore")
	_title(App.t("PAUSED"), Library.find_game(_game).get("title", App.pretty_title(_game)))
	var first := _menu_button(App.t("CONTINUE"), _toggle_pause)
	_menu_button(App.t("SAVE_STATE"), _show_page.bind("save"))
	_menu_button(App.t("LOAD_STATE") if not hardcore else App.t("LOAD_STATE") + " · " + App.t("RA_DISABLED_HC"),
		_show_page.bind("load"), null, not hardcore)
	_menu_button(App.t("CHEATS"), _show_page.bind("cheats"))
	if Achievements.is_active():
		_menu_button(App.t("ACHIEVEMENTS"), _show_page.bind("achievements"))
	_menu_button(App.t("RESET"), func():
		host.reset()
		DirAccess.remove_absolute(_auto_path())
		_toggle_pause())
	_menu_button(App.t("QUIT_LIBRARY"), _quit_to_library)
	return first


# ------------------------------------------------------------------- slots

func _base() -> String:
	return App.STATE_DIR.path_join(_game.get_file().get_basename())


func _slot_path(n: int) -> String:
	return _base() + ".slot%d.state" % n


func _auto_path() -> String:
	return _base() + ".auto.state"


func _page_slots(saving: bool) -> Control:
	_title(App.t("CHOOSE_SLOT_SAVE") if saving else App.t("CHOOSE_SLOT_LOAD"))
	_migrate_old_state()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_menu.add_child(row)
	var first: Control
	for n in range(1, SLOTS + 1):
		var exists := FileAccess.file_exists(_slot_path(n))
		var card := Button.new()
		card.custom_minimum_size = Vector2(300, 340)
		card.disabled = not saving and not exists
		card.pressed.connect((_save_slot if saving else _load_slot).bind(n))
		row.add_child(card)
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 14
		col.offset_right = -14
		col.offset_top = 14
		col.offset_bottom = -14
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 10)
		card.add_child(col)
		var shot := TextureRect.new()
		shot.custom_minimum_size = Vector2(272, 220)
		shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shot.texture = App.load_image_texture(_slot_path(n).get_basename() + ".png") if exists else null
		col.add_child(shot)
		var l := App.pixel_label(App.t("SLOT", [n]), 16, App.C_TEXT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
		var when := App.t("EMPTY_SLOT")
		if exists:
			var dt := Time.get_datetime_dict_from_unix_time(FileAccess.get_modified_time(_slot_path(n)) + _tz_offset())
			when = "%02d.%02d.%d %02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute]
		var d := App.body_label(when, 30, App.C_MUTED)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(d)
		if first == null and not card.disabled:
			first = card
	var back := _menu_button(App.t("BACK"), _show_page.bind("main"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return first if first else back


func _tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## 0.1 kept one state per game in <name>.state: it becomes slot 1.
func _migrate_old_state() -> void:
	var old := _base() + ".state"
	if FileAccess.file_exists(old) and not FileAccess.file_exists(_slot_path(1)):
		DirAccess.rename_absolute(old, _slot_path(1))


func _write_state(path: String) -> bool:
	var data: PackedByteArray = host.save_state()
	if data.is_empty():
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(data)
	f.close()
	var img: Image = host.get_frame_image()
	if img and not img.is_empty():
		img.save_png(path.get_basename() + ".png")
	return true


func _save_slot(n: int) -> void:
	if host == null or not host.is_game_loaded():
		return
	if _write_state(_slot_path(n)):
		_show_toast(App.t("STATE_SAVED", [n]))
		if _pause.visible:
			_toggle_pause()
	else:
		Sfx.play("error")
		_show_toast(App.t("SAVE_FAILED"))


func _load_slot(n: int) -> void:
	if host == null or Settings.get_value("ra_hardcore"):
		return
	_migrate_old_state()
	if not FileAccess.file_exists(_slot_path(n)):
		_show_toast(App.t("NO_SAVE"))
		return
	if host.load_state(FileAccess.get_file_as_bytes(_slot_path(n))):
		_show_toast(App.t("STATE_LOADED", [n]))
		if _pause.visible:
			_toggle_pause()
	else:
		Sfx.play("error")
		_show_toast(App.t("LOAD_FAILED"))


func _save_auto() -> void:
	if host != null and host.is_game_loaded() and Settings.get_value("resume"):
		_write_state(_auto_path())


func _quit_to_library() -> void:
	if _quitting:
		return
	_quitting = true
	_save_auto()
	Stats.end()
	Achievements.stop_game()
	if host:
		host.unload_core()
	App.go("games")


# ------------------------------------------------------------------ cheats

func _page_cheats() -> Control:
	_title(App.t("CHEATS_FOR", [Library.find_game(_game).get("title", App.pretty_title(_game))]))
	if Settings.get_value("ra_hardcore"):
		_title("", App.t("CHEAT_HARDCORE"))
		return _menu_button(App.t("BACK"), _show_page.bind("main"))
	var cheats := Cheats.list(_system, _game)
	var first: Control
	if cheats.is_empty():
		_title("", App.t("CHEAT_EMPTY"))
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(1000, mini(cheats.size(), 6) * 84)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		_menu.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 12)
		scroll.add_child(list)
		for i in cheats.size():
			var c: Dictionary = cheats[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			list.add_child(row)
			var toggle := Button.new()
			toggle.toggle_mode = true
			toggle.button_pressed = c.get("on", false)
			toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
			toggle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			toggle.add_theme_font_size_override("font_size", 18)
			toggle.text = ("[X] " if toggle.button_pressed else "[ ] ") + String(c.get("name", c.code)).to_upper()
			toggle.toggled.connect(func(on: bool):
				var all := Cheats.list(_system, _game)
				all[i]["on"] = on
				Cheats.store(_system, _game, all)
				Cheats.apply(host, _system, _game)
				toggle.text = ("[X] " if on else "[ ] ") + String(c.get("name", c.code)).to_upper())
			row.add_child(toggle)
			var del := Button.new()
			del.text = App.t("CHEAT_DELETE")
			del.add_theme_font_size_override("font_size", 16)
			del.pressed.connect(func():
				var all := Cheats.list(_system, _game)
				all.remove_at(i)
				Cheats.store(_system, _game, all)
				Cheats.apply(host, _system, _game)
				_show_page("cheats"))
			row.add_child(del)
			if first == null:
				first = toggle
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 16)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_child(row2)
	var add := _menu_button(App.t("CHEAT_ADD"), _show_page.bind("cheat_add"), row2)
	add.custom_minimum_size.x = 0
	var fetch := _menu_button(App.t("CHEAT_FETCH"), func(): pass, row2)
	fetch.custom_minimum_size.x = 0
	fetch.pressed.connect(func():
		fetch.text = App.t("CHEAT_FETCHING")
		fetch.disabled = true
		var n: int = await Cheats.fetch(_system, _game)
		if not is_instance_valid(fetch):
			return
		if n > 0:
			_show_toast(App.t("CHEAT_FOUND", [n]))
			_show_page("cheats")
		else:
			fetch.disabled = false
			fetch.text = App.t("CHEAT_FETCH")
			Sfx.play("error")
			_show_toast(App.t("CHEAT_NONE_ONLINE") if n == 0 else App.t("CHECK_INTERNET")))
	var back := _menu_button(App.t("BACK"), _show_page.bind("main"), row2)
	back.custom_minimum_size.x = 0
	return first if first else add


func _page_cheat_add() -> Control:
	_title(App.t("CHEAT_ADD").trim_prefix("+ "))
	var name := LineEdit.new()
	name.placeholder_text = App.t("CHEAT_NAME")
	name.custom_minimum_size = Vector2(900, 72)
	_menu.add_child(name)
	var code := LineEdit.new()
	code.placeholder_text = App.t("CHEAT_CODE")
	code.custom_minimum_size = Vector2(900, 72)
	_menu.add_child(code)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_child(row)
	var save := func():
		var c := code.text.strip_edges().to_upper().replace(" ", "")
		if c.is_empty():
			Sfx.play("error")
			return
		var all := Cheats.list(_system, _game)
		all.append({"name": name.text.strip_edges() if not name.text.strip_edges().is_empty() else c, "code": c, "on": true})
		Cheats.store(_system, _game, all)
		Cheats.apply(host, _system, _game)
		_show_page("cheats")
	_menu_button(App.t("CHEAT_SAVE"), save, row).custom_minimum_size.x = 0
	_menu_button(App.t("BACK"), _show_page.bind("cheats"), row).custom_minimum_size.x = 0
	name.text_submitted.connect(func(_t): code.grab_focus())
	code.text_submitted.connect(func(_t): save.call())
	return name


# --------------------------------------------------------------------- misc

func _build_toast() -> void:
	_toast = Label.new()
	_toast.add_theme_color_override("font_color", App.C_GOLD)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.position = Vector2(24, 24)
	_toast.modulate.a = 0.0
	_toast.z_index = 10
	add_child(_toast)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _fail(message: String) -> void:
	push_error(message)
	Sfx.play("error")
	var l := Label.new()
	l.text = message + "\n\n" + App.t("ESC_LIBRARY")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", App.C_RED)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(l)
	host = null
	set_process_unhandled_input(false)
	var back := func(e: InputEvent):
		if e.is_action_pressed("ui_cancel"):
			App.go("games")
	gui_input.connect(back)
	focus_mode = Control.FOCUS_ALL
	grab_focus()
