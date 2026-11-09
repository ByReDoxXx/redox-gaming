extends Control
## One platform (App.last_system), or a cross-platform list ("recent", "favorites"):
##   MY GAMES      the player's games (+ box art fetched automatically)
##   FREE GAMES    free homebrew from Retrobrews: pick → download → play
##   + ADD FOLDER  scan a folder / USB stick for games
## X favourite · Y search · SELECT sort · LB/RB tab.
## B / Esc / Android back closes a dialog or the search, then returns to the carousel.

const COLUMNS := 5

var _id := ""
var _tab := "mine"
var _accent := Color.WHITE
var _count_label: Label
var _tab_buttons := {}
var _add_button: Button
var _back_button: Button
var _scroll: ScrollContainer
var _grid: GridContainer
var _message: VBoxContainer
var _cards := {}              # key -> GameCard
var _fill_token := 0

var _scrim: ColorRect
var _dialog: PanelContainer
var _dialog_primary: Button
var _status: Label
var _bar_fill: ColorRect
var _bar: Control
var _working := false
var _toast: Label
var _file_dialog: FileDialog
var _search: LineEdit
var _sort_button: Button
var _query := ""
var _sort := "name"           # name | recent | time


func _ready() -> void:
	theme = App.theme
	_id = App.last_system
	_accent = App.system_accent(_id)
	if _id == App.selected_system and App.has_meta("games_tab"):
		_tab = App.get_meta("games_tab")
	# Dev shortcuts for screenshots: -- --tab=store --detail=3
	var dev_tab := App.dev_arg("--tab")
	if not dev_tab.is_empty():
		_tab = dev_tab
	if not Catalog.has_store(_id):
		_tab = "mine"
	_sort = App.get_meta("games_sort", "name")
	if _id == "recent":
		_sort = "recent"

	var bg := ColorRect.new()
	bg.color = App.C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var bar := ColorRect.new()
	bar.color = _accent
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

	col.add_child(_build_header())
	col.add_child(_build_tabs())

	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(area)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.follow_focus = true
	area.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 24)
	pad.add_theme_constant_override("margin_right", 12)
	_scroll.add_child(pad)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 32)
	_grid.add_theme_constant_override("v_separation", 32)
	pad.add_child(_grid)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(center)
	_message = VBoxContainer.new()
	_message.add_theme_constant_override("separation", 24)
	center.add_child(_message)

	var hints := [[["A"], App.t("SELECT")], [["B"], App.t("BACK")], [["X"], App.t("FAVORITE")], [["Y"], App.t("SEARCH")]]
	if _id != "recent":
		hints.append([["SELECT"], App.t("SORT")])
	if Catalog.has_store(_id):
		hints.append([["LB", "RB"], App.t("TAB")])
	col.add_child(HintBar.build(hints))

	_build_dialog()
	_build_toast()

	Covers.image_ready.connect(_on_cover_ready)
	Library.changed.connect(_on_library_changed)
	Sfx.hush(400)
	_show_tab(_tab, true)


func _exit_tree() -> void:
	Covers.clear_queue()


# ----------------------------------------------------------------- header

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)

	var back := Button.new()
	back.text = "<"
	_back_button = back
	back.custom_minimum_size = Vector2(88, 88)
	back.pressed.connect(_back)
	row.add_child(back)

	var icon := TextureRect.new()
	icon.texture = App.system_icon(_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.custom_minimum_size = Vector2(128, 128)
	row.add_child(icon)

	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 10)
	texts.add_child(App.pixel_label(App.system_name(_id), 40, _accent.lerp(App.C_TEXT, 0.25)))
	_count_label = App.body_label("", 40, App.C_MUTED)
	texts.add_child(_count_label)
	row.add_child(texts)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/svg/logo.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.custom_minimum_size = Vector2(112, 112)
	row.add_child(logo)
	return row


func _build_tabs() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var tabs := [["mine", App.t("MY_GAMES") if not App.is_virtual(_id) else App.system_name(_id)]]
	if Catalog.has_store(_id):
		tabs.append(["store", App.t("FREE_GAMES")])
	for t in tabs:
		var b := Button.new()
		b.text = t[1]
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_show_tab.bind(t[0], true))
		row.add_child(b)
		_tab_buttons[t[0]] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_search = LineEdit.new()
	_search.placeholder_text = App.t("SEARCH_HINT")
	_search.custom_minimum_size = Vector2(420, 0)
	_search.add_theme_font_size_override("font_size", 16)
	_search.clear_button_enabled = true
	_search.visible = false
	_search.text_changed.connect(_on_search_changed)
	_search.text_submitted.connect(func(_t): _focus_first_card())
	row.add_child(_search)

	_sort_button = Button.new()
	_sort_button.add_theme_font_size_override("font_size", 16)
	_sort_button.pressed.connect(_cycle_sort)
	_sort_button.visible = _id != "recent"
	row.add_child(_sort_button)
	_update_sort_label()

	_add_button = Button.new()
	_add_button.text = App.t("ADD_FOLDER")
	_add_button.add_theme_font_size_override("font_size", 16)
	_add_button.pressed.connect(_add_folder)
	_add_button.visible = not App.is_virtual(_id)
	row.add_child(_add_button)
	return row


# ------------------------------------------------------- search and sort

func _toggle_search() -> void:
	if _search.visible and _search.has_focus():
		_close_search()
		return
	_search.visible = true
	_search.grab_focus()


func _close_search() -> void:
	_search.visible = false
	if not _query.is_empty():
		_search.text = ""
		_on_search_changed("")
	_focus_first_card()


func _on_search_changed(text: String) -> void:
	_query = text.strip_edges().to_upper()
	if _tab == "store":
		_filter_cards()
	else:
		_fill_mine(false)


## Store tab: hide the cards that do not match instead of reloading the list.
func _filter_cards() -> void:
	for key in _cards:
		var card: GameCard = _cards[key]
		card.visible = _query.is_empty() or String(card.data.get("title", "")).contains(_query)


func _cycle_sort() -> void:
	var order := ["name", "recent", "time"]
	_sort = order[(order.find(_sort) + 1) % order.size()]
	App.set_meta("games_sort", _sort)
	_update_sort_label()
	if _tab == "mine":
		_fill_mine(true)


func _update_sort_label() -> void:
	_sort_button.text = App.t({"name": "SORT_NAME", "recent": "SORT_RECENT", "time": "SORT_TIME"}[_sort])
	_sort_button.disabled = _tab == "store"


func _focus_first_card() -> void:
	for c in _grid.get_children():
		if c.visible:
			(c as Control).grab_focus()
			return


func _toggle_favorite() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if not focused is GameCard or _tab != "mine":
		return
	var card := focused as GameCard
	var key := _key_of(card)
	var fav := Stats.toggle_favorite(key, card.data.get("system", _id))
	card.set_favorite(fav)
	Sfx.play("toggle")
	_show_toast(App.t("ADDED_FAV") if fav else App.t("REMOVED_FAV"))
	if _id == "favorites" and not fav:
		_fill_mine(true)


func _style_tabs() -> void:
	for key in _tab_buttons:
		var b: Button = _tab_buttons[key]
		var on: bool = key == _tab
		b.add_theme_stylebox_override("normal", App.box(_accent.darkened(0.45) if on else App.C_SURFACE, _accent if on else App.C_LINE))
		b.add_theme_color_override("font_color", App.C_TEXT if on else App.C_MUTED)


# ------------------------------------------------------------------- tabs

func _show_tab(tab: String, focus_grid: bool) -> void:
	_tab = tab
	if not App.is_virtual(_id):
		App.selected_system = _id
	App.set_meta("games_tab", tab)
	_style_tabs()
	if _sort_button:
		_update_sort_label()
	if tab == "store":
		_fill_store(focus_grid)
	else:
		_fill_mine(focus_grid)


func _cycle_tab() -> void:
	if _tab_buttons.size() > 1:
		_show_tab("store" if _tab == "mine" else "mine", true)


func _clear() -> void:
	_fill_token += 1
	Covers.clear_queue()
	_cards.clear()
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	for c in _message.get_children():
		_message.remove_child(c)
		c.queue_free()


func _fill_mine(focus_grid: bool) -> void:
	_clear()
	var games: Array[Dictionary]
	match _id:
		"recent": games = Stats.recent()
		"favorites": games = Stats.favorites()
		_: games = Library.games_for(_id)
	var total := games.size()
	if not _query.is_empty():
		games.assign(games.filter(func(g): return String(g.title).contains(_query)))
	match _sort:
		"recent": games.sort_custom(func(a, b): return Stats.last_played(a.path) > Stats.last_played(b.path))
		"time": games.sort_custom(func(a, b): return Stats.seconds(a.path) > Stats.seconds(b.path))
		_: if _id != "recent": games.sort_custom(func(a, b): return a.title < b.title)
	_count_label.text = App.t("ONE_GAME") if total == 1 else App.t("N_GAMES", [total])
	if games.is_empty():
		if not _query.is_empty():
			_say(App.t("NO_MATCH"), "")
		elif _id == "recent":
			_say(App.t("NO_GAMES_YET"), App.t("EMPTY_RECENT"))
		elif _id == "favorites":
			_say(App.t("NO_GAMES_YET"), App.t("EMPTY_FAVORITES"))
		else:
			_say(App.t("NO_GAMES_YET"), App.t("EMPTY_HELP") +
				("\n" + App.t("EMPTY_HELP_STORE") if Catalog.has_store(_id) else ""))
			if Catalog.has_store(_id):
				_message_button(App.t("BROWSE_FREE"), _show_tab.bind("store", true))
			_message_button(App.t("ADD_FOLDER"), _add_folder)
		_link_focus(focus_grid and _query.is_empty())
		return
	for g in games:
		var meta: Dictionary = g.meta
		var sub := Stats.summary(g.path)
		if App.is_virtual(_id) and sub.is_empty():
			sub = App.system_name(g.system)
		elif App.is_virtual(_id):
			sub = App.system_name(g.system) + " · " + Stats.format_when(Stats.last_played(g.path))
		if sub.is_empty():
			sub = String(meta.get("developer", "")).to_upper()
		if sub.is_empty():
			sub = App.system_name(g.system)
		var card := _add_card(g.path, {
			"title": g.title, "subtitle": sub, "system": g.system,
			"cover": g.cover, "cover_target": Library.cover_path(g.system, g.path),
		})
		card.set_favorite(Stats.is_favorite(g.path))
		card.pressed.connect(_play.bind(g.path, g.system))
		Covers.request_boxart(g)
	_link_focus(focus_grid)


func _fill_store(focus_grid: bool) -> void:
	_clear()
	var token := _fill_token
	_count_label.text = App.t("FREE_GAMES")
	_say(App.t("LIST_LOADING"), "")
	var items: Array = await Catalog.list(_id)
	if token != _fill_token:
		return
	_clear()
	if items.is_empty():
		_say(App.t("LIST_FAILED"), App.t("CHECK_INTERNET"))
		_message_button(App.t("RETRY"), _show_tab.bind("store", true))
		_link_focus(focus_grid)
		return
	_count_label.text = App.t("N_FREE_GAMES", [items.size()])
	for e in items:
		var cache := Catalog.image_cache_path(e)
		var sub: String = e.developer.to_upper()
		if not e.year.is_empty():
			sub += " · " + e.year
		var card := _add_card(e.file, {
			"title": e.name.to_upper(), "subtitle": sub, "system": e.system,
			"cover": cache if FileAccess.file_exists(cache) else "", "cover_target": cache,
			"badge": App.t("INSTALLED") if Catalog.is_installed(e) else App.t("FREE"),
			"badge_ok": Catalog.is_installed(e),
		})
		card.pressed.connect(_open_detail.bind(e, card))
		if not e.image.is_empty():
			Covers.request_image(Catalog.RAW % [e.repo, e.image.uri_encode()], cache)
	_filter_cards()
	_link_focus(focus_grid)
	var dev_detail := App.dev_arg("--detail")
	if not dev_detail.is_empty():
		var i := clampi(dev_detail.to_int(), 0, items.size() - 1)
		await get_tree().create_timer(2.0).timeout
		_open_detail(items[i], _cards[items[i].file])


func _add_card(key: String, data: Dictionary) -> GameCard:
	var card := GameCard.new()
	card.setup(data)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(card)
	_cards[key] = card
	return card


func _say(title: String, text: String) -> void:
	var t := App.pixel_label(title, 32, App.C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_child(t)
	if not text.is_empty():
		var l := App.body_label(text, 36)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 1100
		_message.add_child(l)


func _message_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size.x = 560
	b.pressed.connect(cb)
	_message.add_child(b)


## Grid ↔ tab row focus links; focuses the first item when asked.
func _link_focus(focus_grid: bool) -> void:
	var tab_btn: Button = _tab_buttons[_tab]
	var cards := _grid.get_children()
	for i in mini(COLUMNS, cards.size()):
		(cards[i] as Control).focus_neighbor_top = cards[i].get_path_to(tab_btn)
	var first: Control = cards[0] if cards.size() > 0 else null
	if first == null and _message.get_child_count() > 0:
		for c in _message.get_children():
			if c is Button:
				first = c
				break
	for b in _tab_buttons.values() + [_add_button]:
		b.focus_neighbor_bottom = b.get_path_to(first) if first else NodePath()
	# header back button: above the tab row, and DOWN returns to the open tab
	for b in _tab_buttons.values() + [_sort_button, _add_button, _search]:
		b.focus_neighbor_top = b.get_path_to(_back_button)
	_back_button.focus_neighbor_bottom = _back_button.get_path_to(tab_btn)
	_back_button.focus_neighbor_right = NodePath(".")
	_back_button.focus_neighbor_left = NodePath(".")
	_back_button.focus_neighbor_top = NodePath(".")
	if focus_grid:
		var target: Control = first if first else tab_btn
		if _cards.has(App.selected_game):
			target = _cards[App.selected_game]
		target.grab_focus.call_deferred()


func _key_of(card: GameCard) -> String:
	for k in _cards:
		if _cards[k] == card:
			return k
	return ""


func _on_cover_ready(dest: String) -> void:
	for card in _cards.values():
		if is_instance_valid(card) and card.data.get("cover_target", "") == dest:
			card.set_cover(dest)


func _on_library_changed() -> void:
	if _tab == "mine" and not _working:
		_fill_mine(true)


# --------------------------------------------------------- store details

func _build_dialog() -> void:
	_scrim = ColorRect.new()
	_scrim.color = Color(App.C_BG, 0.85)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.visible = false
	add_child(_scrim)

	_dialog = PanelContainer.new()
	_dialog.visible = false
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_dialog)


func _open_dialog(build: Callable) -> void:
	for c in _dialog.get_children():
		_dialog.remove_child(c)
		c.queue_free()
	_dialog_primary = null
	build.call()
	_scrim.visible = true
	_dialog.visible = true
	_dialog.reset_size()
	if _dialog_primary:
		_dialog_primary.grab_focus.call_deferred()


func _close_dialog() -> void:
	if _working:
		return
	_scrim.visible = false
	_dialog.visible = false
	var key := App.selected_game
	if _cards.has(key):
		(_cards[key] as Control).grab_focus()


func _open_detail(e: Dictionary, card: GameCard) -> void:
	App.selected_game = e.file
	_open_dialog(func():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 40)
		_dialog.add_child(row)

		var shot := TextureRect.new()
		shot.texture = App.load_image_texture(Catalog.image_cache_path(e))
		if shot.texture == null:
			shot.texture = App.system_icon(e.system)
		shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shot.custom_minimum_size = Vector2(512, 448)
		row.add_child(shot)

		var info := VBoxContainer.new()
		info.custom_minimum_size.x = 720
		info.add_theme_constant_override("separation", 16)
		row.add_child(info)
		var title := App.pixel_label(e.name.to_upper(), 32, App.C_GOLD)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size.x = 720
		info.add_child(title)
		var facts := PackedStringArray()
		if not e.developer.is_empty(): facts.append(e.developer)
		if not e.year.is_empty(): facts.append(e.year)
		if not e.players.is_empty(): facts.append(App.t("N_PLAYERS", [e.players]))
		info.add_child(App.body_label(" · ".join(facts), 36, App.C_TEXT))
		var desc := App.body_label(e.desc if not e.desc.is_empty() else App.t("NO_DESC"), 32, App.C_MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.max_lines_visible = 8
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		desc.custom_minimum_size = Vector2(720, 240)
		info.add_child(desc)
		var src := App.body_label(App.t("SOURCE_NOTE", [Catalog.SOURCE_NAME]), 28, App.C_MUTED)
		src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		src.custom_minimum_size.x = 720
		info.add_child(src)

		_bar = Control.new()
		_bar.custom_minimum_size = Vector2(0, 20)
		_bar.visible = false
		var bar_bg := ColorRect.new()
		bar_bg.color = App.C_SURFACE
		bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bar.add_child(bar_bg)
		_bar_fill = ColorRect.new()
		_bar_fill.color = App.C_GOLD
		_bar_fill.size = Vector2(0, 20)
		_bar.add_child(_bar_fill)
		info.add_child(_bar)
		_status = App.body_label("", 32, App.C_TEXT)
		info.add_child(_status)

		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 20)
		info.add_child(buttons)
		var play := Button.new()
		play.text = App.t("PLAY") if Catalog.is_installed(e) else App.t("DOWNLOAD_PLAY")
		play.pressed.connect(_install_and_play.bind(e, card))
		buttons.add_child(play)
		var close := Button.new()
		close.text = App.t("BACK")
		close.pressed.connect(_close_dialog)
		buttons.add_child(close)
		_dialog_primary = play
	)


func _set_progress(done: int, total: int, label: String) -> void:
	_bar.visible = true
	var f := float(done) / float(total) if total > 0 else 0.0
	_bar_fill.size = Vector2(_bar.size.x * f, 20)
	_status.text = "%s %d%%" % [label, int(f * 100)] if total > 0 else "%s %d KB" % [label, done / 1024]


func _install_and_play(e: Dictionary, card: GameCard) -> void:
	if _working:
		return
	_working = true
	if not Catalog.is_installed(e):
		var ok: bool = await Catalog.install(e, func(d, t):
			_set_progress(d, t, App.t("DOWNLOADING_GAME"))
			card.set_progress(float(d) / t if t > 0 else 0.0))
		card.set_progress(-1)
		if not ok:
			_working = false
			_status.text = App.t("DOWNLOAD_FAILED")
			Sfx.play("error")
			return
		card.set_badge(App.t("INSTALLED"), true)
	_working = false
	_play(Catalog.installed_path(e), e.system)


# ----------------------------------------------------------------- start

## Makes sure the emulator core is there (downloads it once), then starts.
func _play(path: String, system_id: String) -> void:
	if _working:
		return
	App.selected_game = path
	App.selected_system = system_id
	if Cores.find(system_id).is_empty():
		if not _dialog.visible:
			_open_dialog(func():
				var box := VBoxContainer.new()
				box.custom_minimum_size.x = 900
				box.add_theme_constant_override("separation", 20)
				_dialog.add_child(box)
				box.add_child(App.pixel_label(App.t("EMULATOR_OF", [App.system_name(system_id)]), 32, App.C_GOLD))
				var why := App.body_label(App.t("CORE_WHY"), 32)
				why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				why.custom_minimum_size.x = 900
				box.add_child(why)
				_bar = Control.new()
				_bar.custom_minimum_size = Vector2(0, 20)
				var bar_bg := ColorRect.new()
				bar_bg.color = App.C_SURFACE
				bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				_bar.add_child(bar_bg)
				_bar_fill = ColorRect.new()
				_bar_fill.color = App.C_GOLD
				_bar.add_child(_bar_fill)
				box.add_child(_bar)
				_status = App.body_label("", 32, App.C_TEXT)
				box.add_child(_status)
				var close := Button.new()
				close.text = App.t("BACK")
				close.pressed.connect(_close_dialog)
				box.add_child(close)
				_dialog_primary = close
			)
		_working = true
		var core: String = await Cores.ensure(system_id, func(d, t): _set_progress(d, t, App.t("DOWNLOADING_CORE")))
		_working = false
		if core.is_empty():
			_status.text = App.t("CORE_FAILED")
			Sfx.play("error")
			return
	App.go("player")


# ------------------------------------------------------------ add folder

func _add_folder() -> void:
	if OS.get_name() == "Android":
		OS.request_permissions()
	var start := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if OS.get_name() == "Android":
		# Android's own picker returns content:// links that cores cannot open;
		# with the storage permission Godot's dialog sees real paths (and USB
		# sticks under /storage).
		start = "/storage/emulated/0"
	elif DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show(App.t("PICK_FOLDER"), start, "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_DIR, PackedStringArray(), _on_native_dialog)
		return
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.title = App.t("PICK_FOLDER")
		_file_dialog.dir_selected.connect(_on_folder_chosen)
		_file_dialog.show_hidden_files = false
		_file_dialog.add_theme_font_size_override("font_size", 24)
		add_child(_file_dialog)
	_file_dialog.current_dir = start
	_file_dialog.popup_centered_ratio(0.8)


func _on_native_dialog(status: bool, paths: PackedStringArray, _filter: int) -> void:
	if status and paths.size() > 0:
		_on_folder_chosen(paths[0])


func _on_folder_chosen(dir: String) -> void:
	var before := Library.count(_id)
	var added := Library.add_source(dir)
	var here := Library.count(_id) - before
	_show_toast(App.t("FOUND_N", [added]) + (App.t("FOUND_HERE", [here]) if added != here else ""))
	_show_tab("mine", true)


func _build_toast() -> void:
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


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	var back := event.is_action_pressed("ui_cancel")
	if event is InputEventKey and event.pressed and event.keycode == KEY_BACK:
		back = App.take_back()
		if not back:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		back = true
	if back:
		get_viewport().set_input_as_handled()
		Sfx.play("back")
		if _dialog.visible:
			_close_dialog()
		elif _search.visible:
			_close_search()
		else:
			_back()
		return
	if _dialog.visible:
		return
	if _search.has_focus():
		# typing: only the pad's Y closes the search box
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
			get_viewport().set_input_as_handled()
			_close_search()
		return
	if event.is_action_pressed("rx_search"):
		get_viewport().set_input_as_handled()
		_toggle_search()
		return
	if event.is_action_pressed("rx_fav"):
		get_viewport().set_input_as_handled()
		_toggle_favorite()
		return
	if event.is_action_pressed("rx_sort") and _id != "recent" and _tab == "mine":
		get_viewport().set_input_as_handled()
		_cycle_sort()
		return
	var tab_switch := false
	if event is InputEventJoypadButton and event.pressed:
		tab_switch = event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]
	elif event is InputEventKey and event.pressed and not event.echo:
		tab_switch = event.keycode in [KEY_Q, KEY_E, KEY_PAGEUP, KEY_PAGEDOWN]
	if tab_switch:
		get_viewport().set_input_as_handled()
		_cycle_tab()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and App.take_back():
		Sfx.play("back")
		if _dialog.visible:
			_close_dialog()
		elif _search.visible:
			_close_search()
		else:
			_back()


func _back() -> void:
	if _working:
		return
	App.go("home")
