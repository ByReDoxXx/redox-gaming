class_name SpaceBackdrop
extends Control
## Animated space behind the home screen: three layers of pixel stars drifting
## left at different speeds (parallax), twinkling stars, the odd shooting star,
## and sprites that fly across now and then.
##
## Flyer sprites come from res://assets/space/<kind>*.png, where kind is
## asteroid, ufo or ship (art made by the user, see wiki). Without sprites
## only the stars move. Settings "menu_motion" off = still stars, no flyers.

const SPRITE_DIR := "res://assets/space"
const PX := 2.0                         # one "pixel" of the star field
## [count, speed px/s, size, alpha] per layer, far to near
const LAYERS := [[110, 6.0, 2.0, 0.16], [60, 16.0, 2.0, 0.26], [24, 34.0, 4.0, 0.34]]
const FLYER_EVERY := Vector2(5.0, 11.0)   # seconds between flyers (min, max)
const SHOOT_EVERY := Vector2(3.0, 8.0)
const SHOOT_LIFE := 1.1                   # seconds a shooting star is visible
const SHOOT_TRAIL := 26                   # trail length in 6 px steps
const FLYER_ALPHA := 0.75

var _stars: Array = []        # [x, y, layer, phase, twinkle]
var _flyers: Array = []       # dicts
var _shoots: Array = []       # [pos, vel, life]
var _sprites := {}            # kind -> Array[Texture2D]
var _rng := RandomNumberGenerator.new()
var _next_flyer := 2.0
var _next_shoot := 1.5
var _time := 0.0
var _moving := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel sprites
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 7
	_load_sprites()
	_moving = Settings.get_value("menu_motion")
	Settings.changed.connect(func(key):
		if key == "menu_motion":
			_moving = Settings.get_value("menu_motion")
			_flyers.clear()
			_shoots.clear()
			queue_redraw())
	resized.connect(_scatter)
	_scatter()


func _scatter() -> void:
	_stars.clear()
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var w := maxf(size.x, 1.0)
	var h := maxf(size.y, 1.0)
	for li in LAYERS.size():
		for i in int(LAYERS[li][0]):
			_stars.append([r.randf() * w, r.randf() * h, li, r.randf() * TAU, r.randf() < 0.18])
	queue_redraw()


func _load_sprites() -> void:
	var dir := DirAccess.open(SPRITE_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		f = f.trim_suffix(".import").trim_suffix(".remap")
		if not f.ends_with(".png"):
			continue
		for kind in ["asteroid", "ufo", "ship"]:
			if f.begins_with(kind):
				var tex: Texture2D = load(SPRITE_DIR.path_join(f))
				if tex:
					if not _sprites.has(kind):
						_sprites[kind] = []
					if not _sprites[kind].has(tex):
						_sprites[kind].append(tex)


func _process(delta: float) -> void:
	if not _moving or not is_visible_in_tree():
		return
	_time += delta
	var w := size.x
	for s in _stars:
		s[0] -= float(LAYERS[s[2]][1]) * delta
		if s[0] < -8.0:
			s[0] += w + 16.0
			s[1] = _rng.randf() * size.y

	_next_shoot -= delta
	if _next_shoot <= 0.0:
		_next_shoot = _rng.randf_range(SHOOT_EVERY.x, SHOOT_EVERY.y)
		# upper part of the screen only, shallow angle, so it never crosses the carousel
		var start := Vector2(_rng.randf_range(w * 0.35, w * 1.05), _rng.randf_range(-10.0, size.y * 0.18))
		var vel := Vector2(-1.0, 0.28).normalized() * _rng.randf_range(900.0, 1200.0)
		_shoots.append([start, vel, 0.0])
	for sh in _shoots:
		sh[0] += sh[1] * delta
		sh[2] += delta
	_shoots = _shoots.filter(func(sh): return sh[2] < SHOOT_LIFE)

	if not _sprites.is_empty():
		_next_flyer -= delta
		if _next_flyer <= 0.0 and _flyers.size() < 2:
			_next_flyer = _rng.randf_range(FLYER_EVERY.x, FLYER_EVERY.y)
			_spawn_flyer()
	for f in _flyers:
		f.t += delta
		f.pos += f.vel * delta
		f.rot += f.spin * delta
	_flyers = _flyers.filter(func(f): return f.pos.x > -f.size - 40.0 and f.pos.x < w + f.size + 40.0)
	queue_redraw()


func _spawn_flyer() -> void:
	var kinds: Array = _sprites.keys()
	var kind: String = kinds[_rng.randi() % kinds.size()]
	var list: Array = _sprites[kind]
	var tex: Texture2D = list[_rng.randi() % list.size()]
	var left_to_right := _rng.randf() < 0.5
	var f := {"tex": tex, "kind": kind, "t": 0.0, "rot": 0.0, "spin": 0.0, "flip": not left_to_right}
	match kind:
		"asteroid":
			f.size = _rng.randf_range(56.0, 120.0)
			f.speed = _rng.randf_range(40.0, 80.0)
			f.spin = _rng.randf_range(-0.6, 0.6)
			f.flip = false
		"ufo":
			f.size = _rng.randf_range(80.0, 120.0)
			f.speed = _rng.randf_range(110.0, 170.0)
		_:
			f.size = _rng.randf_range(90.0, 140.0)
			f.speed = _rng.randf_range(160.0, 260.0)
	# keep the middle band (carousel) mostly clear: fly high or low
	var band := _rng.randf()
	var y := _rng.randf_range(size.y * 0.08, size.y * 0.3) if band < 0.6 else _rng.randf_range(size.y * 0.72, size.y * 0.86)
	var x: float = -f.size if left_to_right else size.x + f.size
	var dir := 1.0 if left_to_right else -1.0
	f.pos = Vector2(x, y)
	f.vel = Vector2(dir * f.speed, _rng.randf_range(-12.0, 12.0))
	_flyers.append(f)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), App.C_BG)
	for s in _stars:
		var layer: Array = LAYERS[s[2]]
		var a: float = layer[3]
		if s[4]:
			a *= 0.55 + 0.45 * sin(_time * 2.2 + s[3])
		var p := Vector2(s[0], s[1])
		p = (p / PX).floor() * PX
		draw_rect(Rect2(p, Vector2(layer[2], layer[2])), Color(App.C_TEXT, a))
	for sh in _shoots:
		var life := float(sh[2]) / SHOOT_LIFE
		var fade := minf(1.0, life * 6.0) * (1.0 - life)   # quick fade in, slow fade out
		var dir: Vector2 = (sh[1] as Vector2).normalized()
		for i in SHOOT_TRAIL:
			var k := float(i) / SHOOT_TRAIL
			var p: Vector2 = ((sh[0] - dir * i * 6.0) / PX).floor() * PX
			var sz := 6.0 if i == 0 else (4.0 if i < 6 else 2.0)
			var col := Color.WHITE.lerp(App.C_GOLD, minf(1.0, k * 2.0))
			draw_rect(Rect2(p - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color(col, fade * (1.0 - k) * 0.95))
	for f in _flyers:
		var tex: Texture2D = f.tex
		var sz := Vector2(f.size, f.size * tex.get_height() / maxf(tex.get_width(), 1.0))
		var pos: Vector2 = f.pos
		if f.kind == "ufo":
			pos.y += sin(f.t * 3.0) * 10.0
		draw_set_transform(pos, f.rot, Vector2(-1.0 if f.flip else 1.0, 1.0))
		draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false, Color(1, 1, 1, FLYER_ALPHA))
		draw_set_transform(Vector2.ZERO)
