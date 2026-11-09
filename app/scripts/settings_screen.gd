extends Control
## Settings: one scrolling list of rows grouped by section. Up/down moves,
## left/right (or A) changes a value, B goes back. Sub-pages: key remapping,
## pad remapping, RetroAchievements sign-in. Values live in Settings.

const LANG_CHOICES := ["tr", "en"]

var _list: VBoxContainer
var _scroll: ScrollContainer
var _back_button: Button
var _title: Label
var _page := "main"
var _rows: Array = []                # main page rows, for refreshing values
var _capture := {}                   # remap in progress: {kind, id, button}
var _toast: Label
var _focus_key := ""                 # row to focus after a rebuild


func _ready() -> void:
	theme = App.theme
	var bg := ColorRect.new()
	bg.color = App.C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var bar := ColorRect.new()
	bar.color = App.C_GOLD
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = 8
	add_child(bar)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = App.SAFE_Y
	col.offset_bottom = -App.SAFE_Y
	col.offset_left = App.SAFE_X
	col.offset_right = -App.SAFE_X
	col.add_theme_constant_override("separation", 28)
	add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 28)
	col.add_child(head)
	var back := Button.new()
	back.text = "<"
	_back_button = back
	for side in ["left", "right", "top"]:
		back.set("focus_neighbor_" + side, NodePath("."))
	back.custom_minimum_size = Vector2(88, 88)
	back.pressed.connect(_back)
	head.add_child(back)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/svg/ui/settings.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(88, 88)
	head.add_child(icon)
	_title = App.pixel_label(App.t("SETTINGS"), 40, App.C_GOLD)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.follow_focus = true
	col.add_child(_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	_list = VBoxContainer.new()
	_list.custom_minimum_size.x = 1280
	_list.add_theme_constant_override("separation", 12)
	center.add_child(_list)

	col.add_child(HintBar.build([[["A"], App.t("SELECT")], [["<", ">"], App.t("S_CHANGE")], [["B"], App.t("BACK")]]))

	_toast = App.pixel_label("", 24, App.C_GOLD)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_right = -App.SAFE_X
	_toast.offset_bottom = -App.SAFE_Y - 70
	_toast.modulate.a = 0.0
	add_child(_toast)

	Sfx.hush(400)
	_focus_key = App.get_meta("settings_focus", "")
	if App.has_meta("settings_focus"):
		App.remove_meta("settings_focus")
	var dev_page := App.dev_arg("--settings-page")
	_show(dev_page if not dev_page.is_empty() else "main")


# ------------------------------------------------------------------ pages

func _show(page: String) -> void:
	_page = page
	_rows.clear()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var first: Control
	match page:
		"main": first = _page_main()
		"keys": first = _page_remap("key")
		"pad": first = _page_remap("pad")
		"ra": first = _page_ra()
	_title.text = {"main": App.t("SETTINGS"), "keys": App.t("S_REMAP_KEYS"), "pad": App.t("S_REMAP_PAD"),
		"ra": App.t("S_ACCOUNT")}[page]
	Sfx.hush()
	_link_back_button()
	if first:
		first.grab_focus.call_deferred()
	_scroll.scroll_vertical = 0


## UP from the top item of the list reaches the header's back button
## (remotes have no B button); DOWN from it returns to that item.
func _link_back_button() -> void:
	var top := _first_focusable(_list)
	if top == null:
		return
	top.focus_neighbor_top = top.get_path_to(_back_button)
	_back_button.focus_neighbor_bottom = _back_button.get_path_to(top)


func _first_focusable(node: Node) -> Control:
	for c in node.get_children():
		if c is Control and (c as Control).visible:
			if (c as Control).focus_mode == Control.FOCUS_ALL:
				return c
			var inner := _first_focusable(c)
			if inner:
				return inner
	return null


func _section(text: String) -> void:
	var l := App.pixel_label(text, 20, App.C_ORANGE)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 20 if _list.get_child_count() > 0 else 0)
	m.add_child(l)
	_list.add_child(m)


func _note(text: String) -> void:
	var l := App.body_label(text, 32, App.C_MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 1280
	_list.add_child(l)


## A full-width row: label on the left, value on the right.
func _row(label: String, value := "", cb := Callable(), key := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(1280, 80)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = ""
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 28
	h.offset_right = -28
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var l := App.pixel_label(label, 20, App.C_TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	var v := App.pixel_label(value, 20, App.C_GOLD)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.name = "Value"
	h.add_child(v)
	if cb.is_valid():
		b.pressed.connect(cb)
	b.set_meta("key", key)
	_list.add_child(b)
	if key == _focus_key and not key.is_empty():
		b.grab_focus.call_deferred()
	return b


func _set_value(b: Button, text: String) -> void:
	(b.find_child("Value", true, false) as Label).text = text


## Row cycling through choices: [[value, label], ...]
func _choice(label: String, key: String, choices: Array) -> Button:
	var b := _row(label, "", Callable(), key)
	var show := func():
		var cur = Settings.get_value(key)
		for c in choices:
			if c[0] == cur:
				_set_value(b, "<  %s  >" % c[1])
	var step := func(d: int):
		var cur = Settings.get_value(key)
		var i := 0
		for k in choices.size():
			if choices[k][0] == cur:
				i = k
		var next = choices[wrapi(i + d, 0, choices.size())][0]
		Settings.set_value(key, next)
		Sfx.play("toggle")
		show.call()
		_after_change(key)
	b.pressed.connect(step.bind(1))
	b.set_meta("step", step)
	show.call()
	_rows.append(b)
	return b


func _toggle(label: String, key: String) -> Button:
	return _choice(label, key, [[true, App.t("ON")], [false, App.t("OFF")]])


func _page_main() -> Control:
	var first: Control
	_section(App.t("S_GENERAL"))
	first = _choice(App.t("S_LANGUAGE"), "lang", LANG_CHOICES.map(func(l): return [l, Strings.lang_name(l)]))
	var vol := []
	for v in range(0, 101, 10):
		vol.append([v, _bar(v)])
	_choice(App.t("S_VOLUME"), "volume", vol)
	_toggle(App.t("S_UI_SOUNDS"), "ui_sounds")
	if not OS.get_name() in ["Android", "iOS"]:
		_toggle(App.t("S_FULLSCREEN"), "fullscreen")

	_section(App.t("S_VIDEO"))
	_choice(App.t("S_DISPLAY"), "display", ["integer", "fit", "stretch"].map(func(v): return [v, App.t("S_DISPLAY_" + v)]))
	_choice(App.t("S_FILTER"), "filter", ["none", "crt", "lcd", "smooth"].map(func(v): return [v, App.t("S_FILTER_" + v)]))

	_section(App.t("S_GAMEPLAY"))
	_toggle(App.t("S_RESUME"), "resume")
	_toggle(App.t("S_REWIND"), "rewind")
	_choice(App.t("S_FF_SPEED"), "ff_speed", [2, 3, 4, 6, 8].map(func(v): return [v, "x%d" % v]))
	_choice(App.t("S_TOUCH"), "touch_pad", [["auto", App.t("AUTO")], ["on", App.t("ON")], ["off", App.t("OFF")]])

	_section(App.t("S_CONTROLS"))
	_row(App.t("S_REMAP_KEYS"), ">", _show.bind("keys"), "keys")
	_row(App.t("S_REMAP_PAD"), ">", _show.bind("pad"), "pad")
	_row(App.t("S_RESET_CONTROLS"), "", func():
		Settings.set_value("keys", {})
		Settings.set_value("pad", {})
		RetroInput.load_bindings()
		_toast_text(App.t("S_CONTROLS_RESET_DONE")), "reset_controls")

	_section(App.t("S_ACCOUNT"))
	var user: String = Settings.get_value("ra_user")
	var signed: bool = not String(Settings.get_value("ra_token")).is_empty()
	_row(App.t("RA_LOGGED_IN", [user.to_upper()]) if signed else App.t("RA_LOGIN"), ">", _show.bind("ra"), "ra")
	_toggle(App.t("RA_HARDCORE"), "ra_hardcore")

	_section(App.t("S_LIBRARY"))
	if Library.sources.is_empty():
		_note(App.t("S_NO_FOLDERS"))
	for src in Library.sources:
		var r := _row(_short_path(src), App.t("S_REMOVE"), func():
			Library.remove_source(src)
			_focus_key = "folders"
			_show("main"), "folders")
		r.tooltip_text = src

	_section(App.t("S_ABOUT"))
	_row("RedoX Gaming", App.t("S_VERSION", [Updates.current()]), func(): OS.shell_open(Updates.REPO_PAGE), "about")
	var latest := Updates.available()
	var upd := _row(App.t("S_UPDATES"), App.t("S_NEW_VERSION", [latest]) if not latest.is_empty() else "", Callable(), "updates")
	upd.pressed.connect(func():
		if not Updates.available().is_empty():
			Updates.open_page()
			return
		_set_value(upd, App.t("S_CHECKING"))
		var v: String = await Updates.check()
		if is_instance_valid(upd):
			_set_value(upd, App.t("S_NEW_VERSION", [v]) if not v.is_empty() else App.t("S_UP_TO_DATE")))
	_toggle(App.t("S_UPDATES") + " · " + App.t("AUTO"), "update_check")
	_row(App.t("S_OPEN_GITHUB"), ">", func(): OS.shell_open(Updates.REPO_PAGE), "github")
	return first


func _bar(v: int) -> String:
	var n := v / 10
	return "[" + "=".repeat(n) + "-".repeat(10 - n) + "] %d" % v


func _short_path(p: String) -> String:
	return p if p.length() <= 48 else "…" + p.right(47)


## Some changes need more than a stored value.
func _after_change(key: String) -> void:
	match key:
		"lang":
			# every text on screen changes: rebuild this screen in the new language
			App.set_meta("settings_focus", "lang")
			App.go("settings")
		"ra_hardcore":
			if Settings.get_value("ra_hardcore"):
				_toast_text(App.t("RA_HARDCORE_NOTE"))


# ------------------------------------------------------------------ remap

func _page_remap(kind: String) -> Control:
	_note(App.t("S_REMAP_CANCEL"))
	var first: Control
	for entry in RetroInput.REMAP:
		var id: int = entry[0]
		var b := _row(entry[1], RetroInput.key_name(id) if kind == "key" else RetroInput.pad_name(id), Callable(), "remap_%d" % id)
		b.pressed.connect(_begin_capture.bind(kind, id, b))
		if first == null:
			first = b
	_row(App.t("BACK"), "", _show.bind("main"))
	return first


func _begin_capture(kind: String, id: int, b: Button) -> void:
	_capture = {"kind": kind, "id": id, "button": b}
	var label: String = ""
	for e in RetroInput.REMAP:
		if e[0] == id:
			label = e[1]
	_set_value(b, App.t("S_PRESS_KEY" if kind == "key" else "S_PRESS_BUTTON", [label]))


func _finish_capture(code: int) -> void:
	var kind: String = _capture.kind
	var id: int = _capture.id
	var b: Button = _capture.button
	_capture = {}
	if code >= 0:
		var key := "keys" if kind == "key" else "pad"
		var map: Dictionary = Settings.get_value(key).duplicate()
		if kind == "key":
			map[str(id)] = [code]
		else:
			map[str(id)] = code
		Settings.set_value(key, map)
		RetroInput.load_bindings()
		Sfx.play("toggle")
	_set_value(b, RetroInput.key_name(id) if kind == "key" else RetroInput.pad_name(id))
	b.grab_focus()


func _input(event: InputEvent) -> void:
	if _capture.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			_finish_capture(-1)
		elif _capture.kind == "key":
			_finish_capture(event.physical_keycode)
	elif event is InputEventJoypadButton and event.pressed and _capture.kind == "pad":
		get_viewport().set_input_as_handled()
		_finish_capture(event.button_index)


# ---------------------------------------------------------- achievements

func _page_ra() -> Control:
	_note(App.t("RA_INTRO"))
	var signed: bool = not String(Settings.get_value("ra_token")).is_empty()
	if signed:
		_row(App.t("RA_LOGGED_IN", [String(Settings.get_value("ra_user")).to_upper()]), "")
		var out := _row(App.t("RA_LOGOUT"), "", func():
			Achievements.logout()
			_show("ra"))
		_row(App.t("BACK"), "", _show.bind("main"))
		return out

	var user := LineEdit.new()
	user.placeholder_text = App.t("RA_USER")
	user.text = Settings.get_value("ra_user")
	user.custom_minimum_size = Vector2(1280, 80)
	_list.add_child(user)
	var pw := LineEdit.new()
	pw.placeholder_text = App.t("RA_PASSWORD")
	pw.secret = true
	pw.custom_minimum_size = Vector2(1280, 80)
	_list.add_child(pw)
	var status := App.body_label("", 32, App.C_TEXT)
	_list.add_child(status)
	var login := _row(App.t("RA_LOGIN"), "", Callable())
	var do_login := func():
		if user.text.strip_edges().is_empty() or pw.text.is_empty():
			Sfx.play("error")
			return
		status.text = App.t("RA_LOGGING_IN")
		login.disabled = true
		var res: Array = await Achievements.login(user.text.strip_edges(), pw.text)
		if not is_instance_valid(login):
			return
		login.disabled = false
		pw.text = ""
		if res[0]:
			Sfx.play("unlock")
			_show("ra")
		else:
			Sfx.play("error")
			status.text = App.t("RA_LOGIN_FAILED", [res[1]])
	login.pressed.connect(do_login)
	user.text_submitted.connect(func(_t): pw.grab_focus())
	pw.text_submitted.connect(func(_t): do_login.call())
	_row(App.t("BACK"), "", _show.bind("main"))
	return user


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if not _capture.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			focused.release_focus()
			_back()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_BACK:
		get_viewport().set_input_as_handled()
		if App.take_back():
			_back()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
		return
	if focused is Button and focused.has_meta("step"):
		var d := 0
		if event.is_action_pressed("ui_left", true):
			d = -1
		elif event.is_action_pressed("ui_right", true):
			d = 1
		if d != 0:
			get_viewport().set_input_as_handled()
			focused.get_meta("step").call(d)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and App.take_back():
		_back()


func _back() -> void:
	Sfx.play("back")
	if not _capture.is_empty():
		_finish_capture(-1)
	elif _page != "main":
		_focus_key = {"keys": "keys", "pad": "pad", "ra": "ra"}.get(_page, "")
		_show("main")
	else:
		App.go("home")


func _toast_text(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
