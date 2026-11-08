extends Control
## Runs the selected game: pixel-perfect picture, sound, input, pause menu.

var host: Object  # RetroHost (created through ClassDB so a missing extension shows an error instead of a parse failure)
var _screen: TextureRect
var _audio: AudioStreamPlayer
var _pause: PanelContainer
var _scrim: ColorRect
var _pause_first: Button
var _toast: Label
var _combo_was_down := false


func _ready() -> void:
	theme = App.theme

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_screen = TextureRect.new()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_screen)

	_audio = AudioStreamPlayer.new()
	add_child(_audio)

	_build_pause_menu()
	_build_toast()
	resized.connect(_layout_screen)

	if not ClassDB.class_exists("RetroHost"):
		_fail("RetroHost eklentisi yüklenemedi.\nextension klasöründe scons ile derleyin.")
		return
	host = ClassDB.instantiate("RetroHost")
	add_child(host)
	host.set_system_directory(App.SYSTEM_DIR)
	host.set_save_directory(App.SAVE_DIR)
	host.video_size_changed.connect(func(_s): _layout_screen())

	var game := App.selected_game
	var system_id := App.selected_system
	if system_id.is_empty():
		system_id = Library.find_game(game).get("system", App.system_of(game))
	var core := Cores.find(system_id)
	if core.is_empty():
		_fail("%s çekirdeği yüklü değil.\nOyunu platform ekranından açın; çekirdek otomatik indirilir." % App.system_name(system_id))
		return
	if not host.load_core(core):
		_fail("Çekirdek açılamadı:\n%s" % core)
		return
	if not host.load_game(game):
		_fail("Oyun açılamadı:\n%s" % game)
		return

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = host.get_sample_rate()
	gen.buffer_length = 0.1
	_audio.stream = gen
	_audio.play()
	host.set_audio_playback(_audio.get_stream_playback())

	_screen.texture = host.get_texture()
	_layout_screen()

	# Dev shortcut for screenshots: ... -- --rom=... --pause
	if not App.dev_arg("--pause").is_empty():
		get_tree().create_timer(0.3).timeout.connect(_toggle_pause)


func _process(_delta: float) -> void:
	if host == null or not host.is_game_loaded():
		return
	var combo := RetroInput.menu_combo_pressed()
	if combo and not _combo_was_down:
		_toggle_pause()
	_combo_was_down = combo
	if not _pause.visible:
		RetroInput.apply(host)


func _input(event: InputEvent) -> void:
	# remember quick taps so they reach the game even if released within a frame
	if host != null and host.is_game_loaded() and not _pause.visible:
		RetroInput.latch(event)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			_save_state()
		elif event.keycode == KEY_F4:
			_load_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle_pause()


## Largest whole-number scale that fits, using the core's aspect ratio.
func _layout_screen() -> void:
	if host == null or not host.is_game_loaded():
		return
	var frame: Vector2i = host.get_frame_size()
	if frame.y <= 0:
		return
	var aspect: float = host.get_aspect_ratio()
	var avail := size
	var scale_y := floorf(avail.y / frame.y)
	while scale_y > 1 and frame.y * scale_y * aspect > avail.x:
		scale_y -= 1
	scale_y = maxf(scale_y, 1.0)
	var h := frame.y * scale_y
	var w := roundf(h * aspect)
	_screen.size = Vector2(w, h)
	_screen.position = ((avail - _screen.size) / 2.0).floor()


# ---------------------------------------------------------------- pause menu

func _build_pause_menu() -> void:
	_scrim = ColorRect.new()
	_scrim.color = Color(App.C_BG, 0.75)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.visible = false
	add_child(_scrim)

	_pause = PanelContainer.new()
	_pause.visible = false
	_pause.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_pause)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_pause.add_child(box)

	var title := Label.new()
	title.text = "DURAKLATILDI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", App.C_GOLD)
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	var items := [
		["DEVAM ET", _toggle_pause],
		["DURUMU KAYDET", _save_state],
		["DURUMU YÜKLE", _load_state],
		["SIFIRLA", func(): host.reset(); _toggle_pause()],
		["KÜTÜPHANEYE DÖN", _quit_to_library],
	]
	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size.x = 600
		b.pressed.connect(item[1])
		box.add_child(b)
		if _pause_first == null:
			_pause_first = b


func _toggle_pause() -> void:
	if host == null or not host.is_game_loaded():
		return
	_pause.visible = not _pause.visible
	_scrim.visible = _pause.visible
	host.set_paused(_pause.visible)
	if _pause.visible:
		host.clear_input()
		_pause_first.grab_focus()


func _state_path() -> String:
	return App.STATE_DIR.path_join(App.selected_game.get_file().get_basename() + ".state")


func _save_state() -> void:
	var data: PackedByteArray = host.save_state()
	if data.is_empty():
		_show_toast("KAYDEDİLEMEDİ")
		return
	var f := FileAccess.open(_state_path(), FileAccess.WRITE)
	f.store_buffer(data)
	_show_toast("DURUM KAYDEDİLDİ")


func _load_state() -> void:
	if not FileAccess.file_exists(_state_path()):
		_show_toast("KAYIT YOK")
		return
	if host.load_state(FileAccess.get_file_as_bytes(_state_path())):
		_show_toast("DURUM YÜKLENDİ")
		if _pause.visible:
			_toggle_pause()
	else:
		_show_toast("YÜKLENEMEDİ")


func _quit_to_library() -> void:
	if host:
		host.unload_core()
	App.go("games")


# --------------------------------------------------------------------- misc

func _build_toast() -> void:
	_toast = Label.new()
	_toast.add_theme_color_override("font_color", App.C_GOLD)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.position = Vector2(24, 24)
	_toast.modulate.a = 0.0
	add_child(_toast)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _fail(message: String) -> void:
	push_error(message)
	var l := Label.new()
	l.text = message + "\n\nESC: KÜTÜPHANE"
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
