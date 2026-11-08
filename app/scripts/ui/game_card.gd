class_name GameCard
extends Button
## One game in a grid: cover (box art / screenshot, or the platform icon),
## title, a sub line, an optional badge. Draws its own frame so focus can lift
## the card and cast a hard pixel shadow (docs/DESIGN.md → Focus).
##
##   card.setup({title, subtitle, system, cover, badge})

const COVER_H := 216
const ICON := 176.0

var data := {}
var accent := Color.WHITE
var badge := ""
var progress := -1.0          # 0..1 while downloading, -1 otherwise
var _lift := 0.0
var _content: Control
var _cover: TextureRect
var _sub: Label
var _overlay: Control


func setup(d: Dictionary) -> void:
	data = d
	accent = App.system_accent(d.get("system", ""))
	badge = d.get("badge", "")

	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	custom_minimum_size = Vector2(320, 360)
	focus_mode = Control.FOCUS_ALL

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_content)

	_cover = TextureRect.new()
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_cover)
	set_cover(d.get("cover", ""))

	var title := App.pixel_label(String(d.get("title", "")), 16, App.C_TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.add_theme_constant_override("line_spacing", 10)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.position = Vector2(20, COVER_H + 26)
	title.size = Vector2(280, 40)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.name = "Title"
	_content.add_child(title)

	_sub = App.body_label(String(d.get("subtitle", "")), 32, App.C_MUTED)
	_sub.position = Vector2(20, COVER_H + 80)
	_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_sub)

	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	_content.add_child(_overlay)

	focus_entered.connect(_animate_lift.bind(App.LIFT))
	focus_exited.connect(_animate_lift.bind(0.0))
	mouse_entered.connect(grab_focus)
	resized.connect(_place)
	_place()


## Shows a picture file, or the platform illustration when there is none.
func set_cover(path: String) -> void:
	var tex := App.load_image_texture(path)
	if tex:
		_cover.texture = tex
		# small pictures are pixel screenshots: keep them crisp
		_cover.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if tex.get_width() <= 320 \
			else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_cover.set_meta("full", true)
	else:
		_cover.texture = App.system_icon(data.get("system", ""))
		_cover.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_cover.set_meta("full", false)
	_place()


func set_badge(text: String) -> void:
	badge = text
	if _overlay:
		_overlay.queue_redraw()


func set_progress(v: float) -> void:
	progress = v
	if _overlay:
		_overlay.queue_redraw()


func _place() -> void:
	if _cover == null:
		return
	if _cover.get_meta("full", false):
		_cover.position = Vector2(14, 14)
		_cover.size = Vector2(size.x - 28, COVER_H - 14)
	else:
		_cover.position = Vector2((size.x - ICON) / 2.0, 6 + (COVER_H - ICON) / 2.0)
		_cover.size = Vector2(ICON, ICON)
	var title: Label = _content.get_node_or_null("Title")
	if title:
		title.size.x = size.x - 40
	if _sub:
		_sub.size.x = size.x - 40


func _animate_lift(target: float) -> void:
	create_tween().tween_method(_set_lift, _lift, target, App.MOTION)


func _set_lift(v: float) -> void:
	_lift = v
	_content.position.y = -v
	queue_redraw()


func _draw() -> void:
	var focused := has_focus()
	var r := Rect2(Vector2(0, -_lift), size)

	if _lift > 0.0:
		draw_rect(Rect2(r.position + Vector2(_lift, _lift), r.size), App.C_SHADOW)

	draw_rect(r, App.C_SURFACE_HI if focused else App.C_SURFACE)

	# cover area: accent-tinted with retro scanlines
	var cover := Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, COVER_H))
	draw_rect(cover, accent.darkened(0.62))
	var y := cover.position.y + 4.0
	while y < cover.end.y:
		draw_rect(Rect2(cover.position.x, y, cover.size.x, 2), accent.darkened(0.7))
		y += 8.0
	draw_rect(Rect2(cover.position.x, cover.end.y - 6, cover.size.x, 6), accent)

	var w := App.FOCUS_BORDER if focused else App.BORDER
	_frame(r, App.C_GOLD if focused else App.C_LINE, w)


## Badge and progress bar, drawn on a layer above the cover picture.
func _draw_overlay() -> void:
	if not badge.is_empty():
		var font := App.font_pixel
		var tw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var box := Rect2(Vector2(14, 14), Vector2(tw + 24, 36))
		var fill := App.C_GOLD if badge != "YÜKLÜ" else Color("2f855a")
		_overlay.draw_rect(box, fill)
		_overlay.draw_string(font, box.position + Vector2(12, 26), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			App.C_BG if badge != "YÜKLÜ" else App.C_TEXT)
	if progress >= 0.0:
		var bar := Rect2(Vector2(14, COVER_H - 30), Vector2(size.x - 28, 16))
		_overlay.draw_rect(bar, App.C_BG)
		_overlay.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(progress, 0, 1), bar.size.y)), App.C_GOLD)


func _frame(r: Rect2, c: Color, w: int) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, w)), c)
	draw_rect(Rect2(r.position.x, r.end.y - w, r.size.x, w), c)
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), c)
	draw_rect(Rect2(r.end.x - w, r.position.y, w, r.size.y), c)
