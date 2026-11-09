extends Node
## RetroAchievements (autoload "Achievements"), on top of the C++ RAClient
## (rcheevos). Signs in with the saved token, starts a session per game,
## does the HTTP for rcheevos, shows an unlock banner and builds the
## achievement list page in the pause menu.
## Only the login token is stored, never the password.

signal unlocked(data: Dictionary)
## rcheevos asks for a console reset (hardcore was switched on mid-game)
signal reset_requested

const CONSOLES := {
	"nes": 7, "snes": 3, "gb": 4, "gbc": 6, "gba": 5, "md": 1, "sms": 11, "gg": 15,
	"pce": 8, "a26": 25, "ngp": 14, "ps1": 12, "arcade": 27,
	"nds": 18, "32x": 10, "ws": 53, "a78": 51, "lynx": 13, "vb": 28,
}
const BADGE_DIR := "user://ra_badges"

var client: Object      # RAClient, null when the extension is missing
var _banner: CanvasLayer
var _banner_queue: Array = []
var _banner_busy := false
var _game_ok := false
var _login_waiters := 0


func _ready() -> void:
	if not ClassDB.class_exists("RAClient"):
		return
	client = ClassDB.instantiate("RAClient")
	add_child(client)
	client.http_request.connect(_on_http_request)
	client.event.connect(_on_event)
	client.set_hardcore(Settings.get_value("ra_hardcore"))
	Settings.changed.connect(func(key):
		if key == "ra_hardcore" and client:
			client.set_hardcore(Settings.get_value("ra_hardcore")))
	_build_banner()


func is_signed_in() -> bool:
	return not String(Settings.get_value("ra_token")).is_empty()


## True while a game with achievements is running.
func is_active() -> bool:
	return client != null and _game_ok


# ----------------------------------------------------------------- login

## Returns [ok, message]. On success the token (not the password) is saved.
func login(user: String, password: String) -> Array:
	if client == null:
		return [false, "RAClient missing"]
	client.login_with_password(user, password)
	var res: Array = await client.login_done
	if res[0]:
		var u: Dictionary = client.get_user()
		Settings.set_value("ra_user", String(u.get("username", user)))
		Settings.set_value("ra_token", String(u.get("token", "")))
	return [res[0], String(res[1])]


func logout() -> void:
	if client:
		client.logout()
	Settings.set_value("ra_token", "")


func _ensure_login() -> bool:
	if client == null or not is_signed_in():
		return false
	if client.is_logged_in():
		return true
	client.login_with_token(Settings.get_value("ra_user"), Settings.get_value("ra_token"))
	var res: Array = await client.login_done
	if not res[0]:
		push_warning("RetroAchievements: token login failed: %s" % res[1])
	return res[0]


# ------------------------------------------------------------------ game

func start_game(host: Object, path: String, system: String) -> void:
	_game_ok = false
	if client == null or not CONSOLES.has(system) or not is_signed_in():
		return
	if not await _ensure_login():
		return
	if not is_instance_valid(host) or not host.is_game_loaded():
		return
	client.load_game(host, path, CONSOLES[system])
	var res: Array = await client.game_loaded
	_game_ok = res[0] and client.is_game_loaded()
	if _game_ok:
		var g: Dictionary = client.get_game()
		if int(g.get("num_achievements", 0)) > 0:
			_show_banner({"title": String(g.title).to_upper(),
				"description": App.t("RA_GAME", ["", g.num_unlocked, g.num_achievements]).trim_prefix(" · "),
				"badge_url": g.get("badge_url", "")}, false)
	elif not String(res[1]).is_empty():
		print("RetroAchievements: ", res[1])


func stop_game() -> void:
	_game_ok = false
	if client:
		client.unload_game()


# ------------------------------------------------------------------ http

func _on_http_request(id: int, url: String, post: String, content_type: String) -> void:
	var headers := PackedStringArray()
	var method := HTTPClient.METHOD_GET
	if not post.is_empty():
		method = HTTPClient.METHOD_POST
		headers.append("Content-Type: " + (content_type if not content_type.is_empty() else "application/x-www-form-urlencoded"))
	var res: Array = await Net.request(url, method, post, headers, 30.0)
	if client:
		client.http_response(id, res[0], res[1])


# ---------------------------------------------------------------- events

func _on_event(type: String, data: Dictionary) -> void:
	match type:
		"unlocked":
			Sfx.play("unlock")
			_show_banner(data, true)
			unlocked.emit(data)
		"reset":
			reset_requested.emit()
		"completed":
			_show_banner({"title": App.t("RA_COMPLETE"), "description": "", "badge_url": ""}, true)
		"server_error":
			push_warning("RetroAchievements: %s" % data.get("message", ""))


# ---------------------------------------------------------------- banner

func _build_banner() -> void:
	_banner = CanvasLayer.new()
	_banner.layer = 50
	add_child(_banner)


func _show_banner(data: Dictionary, unlock: bool) -> void:
	_banner_queue.append([data, unlock])
	if not _banner_busy:
		_next_banner()


func _next_banner() -> void:
	if _banner_queue.is_empty():
		_banner_busy = false
		return
	_banner_busy = true
	var item: Array = _banner_queue.pop_front()
	var data: Dictionary = item[0]
	var panel := PanelContainer.new()
	var style := App.box(App.C_BG.lerp(Color.BLACK, 0.2), App.C_GOLD, App.FOCUS_BORDER)
	style.content_margin_left = 24
	style.content_margin_right = 32
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	var badge := TextureRect.new()
	badge.custom_minimum_size = Vector2(96, 96)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	if item[1]:
		col.add_child(App.pixel_label(App.t("RA_UNLOCKED"), 16, App.C_ORANGE))
	col.add_child(App.pixel_label(String(data.get("title", "")).to_upper(), 20, App.C_GOLD))
	var desc := String(data.get("description", ""))
	if data.has("points"):
		desc += "  ·  " + App.t("RA_POINTS", [int(data.points)])
	if not desc.is_empty():
		col.add_child(App.body_label(desc, 30, App.C_TEXT))
	_banner.add_child(panel)
	panel.reset_size()
	var vp := get_viewport().get_visible_rect().size
	panel.position = Vector2((vp.x - panel.size.x) / 2.0, -panel.size.y - 10)
	_load_badge(String(data.get("badge_url", "")), badge)
	var tw := create_tween()
	tw.tween_property(panel, "position:y", 40.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(4.0)
	tw.tween_property(panel, "position:y", -panel.size.y - 10, 0.2)
	tw.tween_callback(func():
		panel.queue_free()
		_next_banner())


func _load_badge(url: String, target: TextureRect) -> void:
	if url.is_empty():
		target.texture = load("res://assets/svg/logo.svg")
		return
	var dest := BADGE_DIR.path_join(url.get_file())
	if not FileAccess.file_exists(dest):
		if not await Net.download(url, dest, Callable(), 15.0):
			return
	if is_instance_valid(target):
		target.texture = App.load_image_texture(dest)


# ------------------------------------------------------------ pause page

## Achievement list for the pause menu; returns the control to focus.
func build_page(menu: VBoxContainer, player: Control) -> Control:
	var g: Dictionary = client.get_game() if client else {}
	var title := App.pixel_label(App.t("ACHIEVEMENTS"), 32, App.C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(title)
	var sub := App.body_label(App.t("RA_GAME", [String(g.get("title", "")).to_upper(), g.get("num_unlocked", 0), g.get("num_achievements", 0)])
		+ "  ·  " + App.t("RA_POINTS", [int(g.get("points_unlocked", 0))]) + " / %d" % int(g.get("points", 0)), 32, App.C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1200, 620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	menu.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var first: Control
	for a in (client.get_achievements() if client else []):
		var b := Button.new()
		b.custom_minimum_size = Vector2(1180, 112)
		b.set_meta("silent", true)
		list.add_child(b)
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 12
		row.offset_right = -20
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 20)
		b.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(88, 88)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		_load_badge(String(a.badge_url if a.unlocked else a.badge_locked_url), icon)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		var t := App.pixel_label(String(a.title).to_upper(), 16, App.C_GOLD if a.unlocked else App.C_TEXT)
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(t)
		var d := App.body_label(String(a.description), 28, App.C_MUTED)
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(d)
		var state := App.t("RA_DONE") if a.unlocked else (String(a.progress) if not String(a.progress).is_empty() else App.t("RA_LOCKED"))
		var r := App.pixel_label("%s\n%s" % [App.t("RA_POINTS", [int(a.points)]), state], 14, App.C_ORANGE if a.unlocked else App.C_MUTED)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(r)
		if first == null:
			first = b
	var back := Button.new()
	back.text = App.t("BACK")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size.x = 400
	back.pressed.connect(player._show_page.bind("main"))
	menu.add_child(back)
	return first if first else back
