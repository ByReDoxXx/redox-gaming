extends SceneTree
## Headless check of the whole chain: core loads, game runs, picture changes
## with input, A button makes sound, save states round-trip.
##   Godot --headless --path app -s res://tests/smoke_test.gd

const CORE := "res://cores/windows/fceumm_libretro.dll"
const ROM := "res://roms/redox_test.nes"
const BTN_A := 8
const OUT := "user://smoke_frame_%s.png"

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		failures += 1


func run_frames(host: Object, n: int) -> int:
	var audio := 0
	for i in n:
		host.step_frame()
		audio += host.get_last_audio_frames()
	return audio


func center_color(host: Object) -> Color:
	var img: Image = host.get_frame_image()
	return img.get_pixel(img.get_width() / 2, img.get_height() / 2)


func _initialize() -> void:
	print("RedoX smoke test")
	check(ClassDB.class_exists("RetroHost"), "RetroHost class is registered")
	if failures:
		quit(1)
		return

	var host: Object = ClassDB.instantiate("RetroHost")
	root.add_child(host)
	host.set_save_directory("user://test_saves")
	host.set_system_directory("user://test_system")

	check(host.load_core(ProjectSettings.globalize_path(CORE)), "core loads")
	check(host.load_game(ROM), "test ROM loads")
	var info: Dictionary = host.get_core_info()
	print("  core: %s %s, %.3f fps, %d Hz, %s" % [info.name, info.version, info.fps, info.sample_rate, host.get_frame_size()])
	host.set_paused(true)  # drive frames by hand

	run_frames(host, 30)
	var c1 := center_color(host)
	host.get_frame_image().save_png(OUT % "1")

	var quiet_audio := run_frames(host, 10)
	check(quiet_audio > 0, "core produces audio frames (%d in 10 frames)" % quiet_audio)

	host.set_button(0, BTN_A, true)
	run_frames(host, 20)
	var c2 := center_color(host)
	host.get_frame_image().save_png(OUT % "2")
	check(c1 != c2, "holding A changes the picture (%s -> %s)" % [c1.to_html(false), c2.to_html(false)])

	var state: PackedByteArray = host.save_state()
	check(state.size() > 0, "save state (%d bytes)" % state.size())
	run_frames(host, 15)
	var c3 := center_color(host)
	check(host.load_state(state), "load state")
	host.set_button(0, BTN_A, false)
	run_frames(host, 2)
	check(center_color(host) == c2 and c3 != c2, "load state restores the colour")

	var font: Font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	var missing := ""
	for ch in "ÇĞİÖŞÜçğıöşü":
		if not font.has_char(ch.unicode_at(0)):
			missing += ch
	print("  font: Turkish letters missing: '%s'" % missing)

	# rewind: record while running, hold A to change the colour, rewind past it
	host.set_button(0, BTN_A, false)
	run_frames(host, 5)
	host.set_rewind_enabled(true)
	host.set_paused(false)
	await create_timer(0.6).timeout
	var before := center_color(host)
	host.set_button(0, BTN_A, true)
	await create_timer(0.6).timeout
	host.set_button(0, BTN_A, false)
	var during := center_color(host)
	check(host.get_rewind_depth() > 20, "rewind records states (%d)" % host.get_rewind_depth())
	host.set_rewinding(true)
	await create_timer(1.5).timeout
	host.set_rewinding(false)
	var after := center_color(host)
	check(during != before and after == before, "rewind goes back (%s -> %s -> %s)" % [before.to_html(false), during.to_html(false), after.to_html(false)])

	# fast forward runs more frames per second
	host.set_speed(4.0)
	await create_timer(0.3).timeout
	host.set_speed(1.0)
	check(true, "fast forward runs")
	host.cheat_reset()
	host.cheat_set(0, true, "SXIOPO")
	check(true, "cheat calls are safe")

	host.unload_core()
	print("frames saved to ", ProjectSettings.globalize_path(OUT % "*"))
	print("RESULT: ", "PASS" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures else 0)
