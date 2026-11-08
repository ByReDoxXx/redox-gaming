class_name HintBar
extends RefCounted
## Controller hints shown at the bottom of every screen: [A] OYNA  [B] GERİ ...


static func build(items: Array, center := false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	if center:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	for item in items:
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 10)
		for key in item[0]:
			group.add_child(key_cap(key))
		var l := App.body_label(item[1], 36, App.C_MUTED)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		group.add_child(l)
		row.add_child(group)
	return row


static func key_cap(text: String) -> Control:
	var p := PanelContainer.new()
	var s := App.box(App.C_SURFACE, App.C_MUTED, 3)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	p.add_child(App.pixel_label(text, 16, App.C_TEXT))
	return p
