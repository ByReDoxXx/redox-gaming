class_name SpaceBackdrop
extends Control
## Animated space behind the home screen.
##
## Always: three layers of pixel stars drifting left (parallax), twinkling
## stars and the odd shooting star.
## With sprites in res://assets/space/ (asteroid*, ufo*, ship*; art made by
## the user): short scenes play in the upper band of the screen, one at a
## time, picked at random:
##   chase      a ship chases a UFO, fires lasers, the UFO zigzags, fires back
##              and blows up
##   ufo_wins   the UFO's plasma hits the ship, the ship blows up, UFO escapes
##   rock_hunt  a ship shoots an asteroid to pieces
##   crash      a ship that is not looking flies into an asteroid, both burst
##   bump       two asteroids collide and break apart
##   cruise     a single sprite drifts across
## Explosions, lasers and debris are drawn in code (pixel particles).
## Settings "menu_motion" off = still stars, no scenes.

const SPRITE_DIR := "res://assets/space"
const PX := 2.0                         # one "pixel" of the star field
## [count, speed px/s, size, alpha] per layer, far to near
const LAYERS := [[110, 6.0, 2.0, 0.16], [60, 16.0, 2.0, 0.26], [24, 34.0, 4.0, 0.34]]
const SHOOT_EVERY := Vector2(3.0, 8.0)
const SHOOT_LIFE := 1.1                   # seconds a shooting star is visible
const SHOOT_TRAIL := 26                   # trail length in 6 px steps
const SCENE_GAP := Vector2(2.5, 6.0)      # quiet seconds between scenes
const SPRITE_ALPHA := 0.85
const SCENE_MAX := 9.0                   # a new scene may start after this many seconds
const BAND := Vector2(0.08, 0.27)         # scenes stay in this part of the height
## weights of the scenes
const SCENES := {"chase": 5, "ufo_wins": 2, "rock_hunt": 4, "crash": 2, "bump": 2, "cruise": 2}
const FIRE := [Color(1, 1, 0.9), Color(1, 0.9, 0.4), Color(1, 0.62, 0.2), Color(0.95, 0.3, 0.15), Color(0.45, 0.42, 0.5)]
const LASER := Color(1.0, 0.35, 0.3)
const PLASMA := Color(0.45, 1.0, 0.5)

var _stars: Array = []        # [x, y, layer, phase, twinkle]
var _shoots: Array = []       # shooting stars [pos, vel, life]
var _sprites := {}            # kind -> Array[Texture2D]
var _ents: Array = []         # ships, ufos, asteroids, fragments (dicts)
var _shots: Array = []        # lasers and plasma (dicts)
var _parts: Array = []        # explosion particles (dicts)
var _rings: Array = []        # shock rings [pos, life, max_r]
var _rng := RandomNumberGenerator.new()
var _next_scene := 2.0
var _scene_time := 0.0
var _forced := ""             # dev: --space-scene=<name> plays only that scene
var _next_shoot := 1.5
var _time := 0.0
var _moving := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel sprites
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 7
	_load_sprites()
	_forced = App.dev_arg("--space-scene")
	_moving = Settings.get_value("menu_motion")
	Settings.changed.connect(func(key):
		if key == "menu_motion":
			_moving = Settings.get_value("menu_motion")
			_clear_scene()
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


func _clear_scene() -> void:
	for e in _ents:
		e.target = null
	_ents.clear()
	_shots.clear()
	_parts.clear()
	_rings.clear()


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if not _moving or not is_visible_in_tree():
		return
	_time += delta
	_update_stars(delta)
	_update_shooting_stars(delta)
	if _sprites.has("ship") or _sprites.has("ufo") or _sprites.has("asteroid"):
		# next scene when the stage is empty, or once the action is over
		# (only leftovers drifting off) or the scene has run long enough
		_scene_time += delta
		if _ents.is_empty() and _parts.is_empty() or _scene_time > SCENE_MAX or (_scene_time > 3.0 and not _action_left()):
			_next_scene -= delta
			if _next_scene <= 0.0:
				_next_scene = _rng.randf_range(SCENE_GAP.x, SCENE_GAP.y)
				_scene_time = 0.0
				_start_scene()
		_update_entities(delta)
		_update_shots(delta)
		_check_collisions()
		_update_effects(delta)
	queue_redraw()


func _update_stars(delta: float) -> void:
	var w := size.x
	for s in _stars:
		s[0] -= float(LAYERS[s[2]][1]) * delta
		if s[0] < -8.0:
			s[0] += w + 16.0
			s[1] = _rng.randf() * size.y


func _update_shooting_stars(delta: float) -> void:
	_next_shoot -= delta
	if _next_shoot <= 0.0:
		_next_shoot = _rng.randf_range(SHOOT_EVERY.x, SHOOT_EVERY.y)
		# upper part of the screen only, shallow angle, so it never crosses the carousel
		var start := Vector2(_rng.randf_range(size.x * 0.35, size.x * 1.05), _rng.randf_range(-10.0, size.y * 0.18))
		var vel := Vector2(-1.0, 0.28).normalized() * _rng.randf_range(900.0, 1200.0)
		_shoots.append([start, vel, 0.0])
	for sh in _shoots:
		sh[0] += sh[1] * delta
		sh[2] += delta
	_shoots = _shoots.filter(func(sh): return sh[2] < SHOOT_LIFE)


# ----------------------------------------------------------------- scenes

func _start_scene() -> void:
	var options := []
	for name in SCENES:
		var need: Array = {"chase": ["ship", "ufo"], "ufo_wins": ["ship", "ufo"], "rock_hunt": ["ship", "asteroid"],
			"crash": ["ship", "asteroid"], "bump": ["asteroid"], "cruise": []}[name]
		if need.all(func(k): return _sprites.has(k)):
			for i in int(SCENES[name]):
				options.append(name)
	var scene: String = options[_rng.randi() % options.size()]
	if SCENES.has(_forced):
		scene = _forced
	var ltr := _rng.randf() < 0.5          # left to right
	var dir := 1.0 if ltr else -1.0
	var y := _rng.randf_range(size.y * BAND.x, size.y * BAND.y)
	match scene:
		"chase", "ufo_wins":
			var ufo := _spawn("ufo", _edge(ltr, 0.0), y, Vector2(dir * 150.0, 0.0))
			ufo.hp = 3 if scene == "chase" else 99
			ufo.fire_cd = 1.6
			ufo.accurate = scene == "ufo_wins"
			var ship := _spawn("ship", _edge(ltr, 260.0), y + _rng.randf_range(-40.0, 40.0), Vector2(dir * 250.0, 0.0))
			ship.target = ufo
			ship.cruise = 250.0
			ship.hp = 1
			ufo.target = ship
		"rock_hunt":
			var rock := _spawn("asteroid", _edge(not ltr, 0.0), y, Vector2(-dir * 100.0, _rng.randf_range(-8.0, 8.0)))
			rock.hp = 3
			var ship := _spawn("ship", _edge(ltr, 120.0), y + _rng.randf_range(-50.0, 50.0), Vector2(dir * 220.0, 0.0))
			ship.target = rock
			ship.cruise = 220.0
		"crash":
			# both arrive at the same point, left or right of the logo
			var meet := _meet_x()
			var ship := _spawn("ship", _edge(ltr, 0.0), y, Vector2(dir * 240.0, 0.0))
			var t := absf(meet - ship.pos.x) / 240.0
			var rock := _spawn("asteroid", _edge(not ltr, 0.0), y, Vector2.ZERO)
			rock.vel = Vector2((meet - rock.pos.x) / t, 0.0)
			ship.unarmed = true
			ship.target = rock
			ship.cruise = 240.0
			rock.collide = true
			ship.collide = true
		"bump":
			var meet := _meet_x()
			var t := _rng.randf_range(5.0, 7.0)
			var a := _spawn("asteroid", _edge(true, 0.0), y, Vector2.ZERO)
			var b := _spawn("asteroid", _edge(false, 0.0), y + _rng.randf_range(-20.0, 20.0), Vector2.ZERO)
			a.vel = Vector2((meet - a.pos.x) / t, 0.0)
			b.vel = Vector2((meet - b.pos.x) / t, (a.pos.y - b.pos.y) / t)
			a.collide = true
			b.collide = true
		_:
			var kinds: Array = _sprites.keys()
			var kind: String = kinds[_rng.randi() % kinds.size()]
			var speed := {"asteroid": 130.0, "ufo": 170.0, "ship": 260.0}[kind] as float
			_spawn(kind, _edge(ltr, 0.0), y, Vector2(dir * speed, _rng.randf_range(-10.0, 10.0)))


## A meeting point for collisions, clear of the logo in the middle.
func _meet_x() -> float:
	var side := _rng.randf_range(0.14, 0.34)
	return size.x * (side if _rng.randf() < 0.5 else 1.0 - side)


## True while something still has a live target or explosions are playing.
func _action_left() -> bool:
	if not _parts.is_empty() or not _shots.is_empty():
		return true
	for e in _ents:
		if _target_alive(e) or (e.collide and not e.fragment):
			return true
	return false


## x just outside the screen on the left (ltr) or right side, `back` further out.
func _edge(ltr: bool, back: float) -> float:
	return -90.0 - back if ltr else size.x + 90.0 + back


func _spawn(kind: String, x: float, y: float, vel: Vector2) -> Dictionary:
	var list: Array = _sprites[kind]
	var e := {
		"kind": kind, "tex": list[_rng.randi() % list.size()], "pos": Vector2(x, y), "vel": vel,
		"size": {"asteroid": _rng.randf_range(90.0, 140.0), "ufo": _rng.randf_range(120.0, 150.0),
			"ship": _rng.randf_range(130.0, 165.0)}[kind],
		"rot": 0.0, "spin": _rng.randf_range(-0.7, 0.7) if kind == "asteroid" else 0.0,
		"t": _rng.randf() * 10.0, "hp": 1, "fire_cd": 0.6, "target": null, "cruise": vel.length(),
		"unarmed": false, "accurate": false, "collide": false, "fragment": false, "life": -1.0,
		"alive": true, "panic": 0.0,
	}
	_ents.append(e)
	return e


# --------------------------------------------------------------- behaviour

func _update_entities(delta: float) -> void:
	for e in _ents:
		if not e.alive:
			continue
		e.t += delta
		match e.kind:
			"ship": _think_ship(e, delta)
			"ufo": _think_ufo(e, delta)
		e.pos += e.vel * delta
		e.rot += e.spin * delta
		if e.kind == "ship":
			# nose follows the flight path a little
			var facing := 1.0 if e.vel.x >= 0.0 else -1.0
			e.rot = atan2(e.vel.y, absf(e.vel.x)) * facing * 0.8
		if e.life >= 0.0:
			e.life -= delta
			if e.life <= 0.0:
				e.alive = false
		var margin: float = e.size + 400.0
		if e.pos.x < -margin or e.pos.x > size.x + margin or e.pos.y < -margin or e.pos.y > size.y + margin:
			e.alive = false
	for e in _ents:
		if not e.alive:
			e.target = null              # ship <-> ufo point at each other: break the cycle
	_ents = _ents.filter(func(e): return e.alive)


func _target_alive(e: Dictionary) -> bool:
	return e.target != null and (e.target as Dictionary).get("alive", false)


func _think_ship(e: Dictionary, delta: float) -> void:
	var facing := 1.0 if e.vel.x >= 0.0 else -1.0
	var vy := 0.0
	if _target_alive(e):
		var t: Dictionary = e.target
		var dx: float = (t.pos.x - e.pos.x) * facing
		vy = clampf((t.pos.y - e.pos.y) * 1.8, -140.0, 140.0)
		# do not overtake a UFO: hang behind it and keep shooting
		var speed: float = e.cruise
		if t.kind == "ufo" and dx < 220.0:
			speed = absf(t.vel.x) * 0.95
		e.vel.x = lerpf(e.vel.x, facing * speed, minf(1.0, delta * 2.0))
		e.fire_cd -= delta
		if not e.unarmed and dx > 0.0 and dx < 900.0 and absf(t.pos.y - e.pos.y) < 45.0 and e.fire_cd <= 0.0:
			e.fire_cd = _rng.randf_range(0.28, 0.5)
			var nose: Vector2 = e.pos + Vector2(facing * e.size * 0.5, 0.0)
			_shots.append({"pos": nose, "vel": Vector2(facing * 950.0, 0.0), "team": "ship", "life": 1.6, "kind": "laser"})
	else:
		# target gone: weave a little, then leave at full speed
		vy = sin(e.t * 2.0) * 25.0
		e.vel.x = lerpf(e.vel.x, facing * e.cruise * 1.3, minf(1.0, delta))
	e.vel.y = lerpf(e.vel.y, vy, minf(1.0, delta * 3.0))


func _think_ufo(e: Dictionary, delta: float) -> void:
	var base := sin(e.t * 3.0) * 30.0
	if e.panic > 0.0:
		# just hit: zigzag hard and speed up
		e.panic -= delta
		base = sin(e.t * 9.0) * 160.0
	var top := size.y * BAND.x * 0.6
	var bottom := size.y * BAND.y * 1.15
	if e.pos.y < top:
		base = absf(base) + 40.0
	elif e.pos.y > bottom:
		base = -absf(base) - 40.0
	e.vel.y = lerpf(e.vel.y, base, minf(1.0, delta * 4.0))
	if _target_alive(e):
		e.fire_cd -= delta
		var t: Dictionary = e.target
		var behind: bool = signf(t.pos.x - e.pos.x) != signf(e.vel.x)
		if behind and e.fire_cd <= 0.0 and absf(t.pos.x - e.pos.x) < 700.0:
			e.fire_cd = _rng.randf_range(1.0, 1.6) if not e.accurate else 0.9
			var aim: Vector2 = t.pos
			if not e.accurate:
				aim.y += (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(70.0, 110.0)   # miss
			var v: Vector2 = (aim - e.pos).normalized() * 520.0
			_shots.append({"pos": e.pos, "vel": v, "team": "ufo", "life": 2.0, "kind": "plasma"})
	elif e.hp > 50:
		# won the duel: climb away fast
		e.vel = e.vel.lerp(Vector2(signf(e.vel.x) * 320.0, -90.0), minf(1.0, delta * 1.5))


# ----------------------------------------------------------- shots and hits

func _update_shots(delta: float) -> void:
	for s in _shots:
		s.pos += s.vel * delta
		s.life -= delta
	_shots = _shots.filter(func(s): return s.life > 0.0)


func _radius(e: Dictionary) -> float:
	return e.size * (0.42 if e.kind == "asteroid" else 0.3)


func _check_collisions() -> void:
	for s in _shots:
		if s.life <= 0.0:
			continue
		for e in _ents:
			if not e.alive or e.fragment or e.kind == s.team:
				continue
			if s.team == "ufo" and e.kind != "ship":
				continue
			if s.team == "ufo":
				# the UFO only hits in the "ufo_wins" scene
				var shooter := _ents.filter(func(u): return u.kind == "ufo" and u.alive)
				if shooter.is_empty() or not shooter[0].accurate:
					continue
			if (s.pos as Vector2).distance_to(e.pos) < _radius(e):
				s.life = 0.0
				_hit(e, s.pos)
				break
	for i in _ents.size():
		var a: Dictionary = _ents[i]
		if not a.alive or not a.collide:
			continue
		for j in range(i + 1, _ents.size()):
			var b: Dictionary = _ents[j]
			if not b.alive or not b.collide:
				continue
			if (a.pos as Vector2).distance_to(b.pos) < _radius(a) + _radius(b):
				_explode(a)
				_explode(b)


func _hit(e: Dictionary, at: Vector2) -> void:
	e.hp -= 1
	_burst(at, 7, 160.0, 0.35, 2.0)
	if e.kind == "ufo":
		e.panic = 0.9
	if e.hp <= 0:
		_explode(e)


func _explode(e: Dictionary) -> void:
	if not e.alive:
		return
	e.alive = false
	var big: float = e.size / 100.0
	_burst(e.pos, int(34 * big), 260.0 * big, 1.0, 4.0)
	_rings.append([e.pos, 0.0, e.size * 0.9])
	if e.kind == "asteroid":
		# break into 3 smaller, spinning pieces of the same rock
		for k in 3:
			var ang := TAU * k / 3.0 + _rng.randf_range(-0.5, 0.5)
			var f := _spawn("asteroid", e.pos.x, e.pos.y, e.vel * 0.5 + Vector2.from_angle(ang) * _rng.randf_range(60.0, 120.0))
			f.tex = e.tex
			f.size = e.size * _rng.randf_range(0.3, 0.45)
			f.spin = _rng.randf_range(-3.0, 3.0)
			f.fragment = true
			f.life = 2.6
	else:
		# metal debris: grey bits that fall away slowly
		for k in 10:
			_parts.append({"pos": e.pos, "vel": Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(40.0, 140.0),
				"col": Color(0.7, 0.72, 0.8), "life": 1.6, "max": 1.6, "size": 4.0, "drag": 0.6})


func _burst(at: Vector2, count: int, speed: float, life: float, px: float) -> void:
	for k in count:
		var col: Color = FIRE[mini(FIRE.size() - 1, int(_rng.randf() * _rng.randf() * FIRE.size() * 1.6))]
		var l := life * _rng.randf_range(0.5, 1.1)
		_parts.append({"pos": at, "vel": Vector2.from_angle(_rng.randf() * TAU) * speed * _rng.randf_range(0.2, 1.0),
			"col": col, "life": l, "max": l, "size": px * (2.0 if _rng.randf() < 0.3 else 1.0), "drag": 2.2})


func _update_effects(delta: float) -> void:
	for p in _parts:
		p.pos += p.vel * delta
		p.vel *= maxf(0.0, 1.0 - p.drag * delta)
		p.life -= delta
	_parts = _parts.filter(func(p): return p.life > 0.0)
	for r in _rings:
		r[1] += delta
	_rings = _rings.filter(func(r): return r[1] < 0.45)


# -------------------------------------------------------------------- draw

func _snap(p: Vector2) -> Vector2:
	return (p / PX).floor() * PX


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), App.C_BG)
	for s in _stars:
		var layer: Array = LAYERS[s[2]]
		var a: float = layer[3]
		if s[4]:
			a *= 0.55 + 0.45 * sin(_time * 2.2 + s[3])
		draw_rect(Rect2(_snap(Vector2(s[0], s[1])), Vector2(layer[2], layer[2])), Color(App.C_TEXT, a))
	for sh in _shoots:
		var life := float(sh[2]) / SHOOT_LIFE
		var fade := minf(1.0, life * 6.0) * (1.0 - life)   # quick fade in, slow fade out
		var dir: Vector2 = (sh[1] as Vector2).normalized()
		for i in SHOOT_TRAIL:
			var k := float(i) / SHOOT_TRAIL
			var sz := 6.0 if i == 0 else (4.0 if i < 6 else 2.0)
			var col := Color.WHITE.lerp(App.C_GOLD, minf(1.0, k * 2.0))
			draw_rect(Rect2(_snap(sh[0] - dir * i * 6.0) - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color(col, fade * (1.0 - k) * 0.95))

	for e in _ents:
		_draw_sprite(e)
	for s in _shots:
		_draw_shot(s)
	for r in _rings:
		var k: float = r[1] / 0.45
		var rad: float = r[2] * (0.3 + k)
		var col := Color(1.0, 0.85, 0.5, (1.0 - k) * 0.8)
		for i in 20:
			var p: Vector2 = r[0] + Vector2.from_angle(TAU * i / 20.0) * rad
			draw_rect(Rect2(_snap(p) - Vector2(3, 3), Vector2(6, 6)), col)
		if k < 0.25:
			# bright flash in the middle
			var f := (0.25 - k) / 0.25
			draw_rect(Rect2(_snap(r[0]) - Vector2(1, 1) * 24.0 * f, Vector2(48, 48) * f), Color(1, 1, 0.9, f * 0.9))
	for p in _parts:
		var a: float = clampf(p.life / p.max * 1.4, 0.0, 1.0)
		draw_rect(Rect2(_snap(p.pos), Vector2(p.size, p.size)), Color(p.col, a))


func _draw_sprite(e: Dictionary) -> void:
	var tex: Texture2D = e.tex
	var sz := Vector2(e.size, e.size * tex.get_height() / maxf(tex.get_width(), 1.0))
	var pos: Vector2 = e.pos
	var flip := 1.0
	if e.kind == "ship" and e.vel.x < 0.0:
		flip = -1.0                      # sprites face right
	var a := SPRITE_ALPHA
	if e.fragment:
		a *= clampf(e.life / 0.8, 0.0, 1.0)
	elif e.kind == "ufo" and e.panic > 0.0 and int(e.panic * 20.0) % 2 == 0:
		a *= 0.35                        # hit flicker
	draw_set_transform(pos, e.rot, Vector2(flip, 1.0))
	draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)


func _draw_shot(s: Dictionary) -> void:
	var dir: Vector2 = (s.vel as Vector2).normalized()
	if s.kind == "laser":
		for i in 7:
			var c := Color.WHITE if i < 2 else LASER
			draw_rect(Rect2(_snap(s.pos - dir * i * 4.0) - Vector2(2, 2), Vector2(4, 4)), Color(c, 1.0 - i / 9.0))
	else:
		var pulse := 1.0 + 0.3 * sin(_time * 20.0)
		draw_rect(Rect2(_snap(s.pos) - Vector2(7, 7) * pulse, Vector2(14, 14) * pulse), Color(PLASMA, 0.35))
		draw_rect(Rect2(_snap(s.pos) - Vector2(4, 4), Vector2(8, 8)), PLASMA)
		draw_rect(Rect2(_snap(s.pos) - Vector2(2, 2), Vector2(4, 4)), Color(0.9, 1, 0.9))
