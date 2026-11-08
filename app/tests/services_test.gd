extends Node
## End-to-end check of the online services (needs internet):
##   Godot --headless --path app res://tests/services_test.tscn
## catalog list → install a free game → download its core → run it,
## box art lookup, folder scan.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	print("RedoX services test")

	# --- free catalog
	var items: Array = await Catalog.list("snes")
	check(items.size() > 0, "Retrobrews SNES list (%d games)" % items.size())
	var nes_items: Array = await Catalog.list("nes")
	check(nes_items.size() > 50, "Retrobrews NES list (%d games)" % nes_items.size())
	if items.is_empty():
		_finish()
		return
	# smallest game keeps the test fast
	var pick: Dictionary = items[0]
	for e in items:
		if e.file.get_extension() in ["sfc", "smc"]:
			pick = e
			break
	print("  picked: %s by %s (%s)" % [pick.name, pick.developer, pick.file])
	var ok: bool = await Catalog.install(pick)
	check(ok and Catalog.is_installed(pick), "install %s" % pick.file)
	var game: Dictionary = Library.find_game(Catalog.installed_path(pick))
	check(not game.is_empty() and game.system == "snes", "library sees it as SNES")
	check(not game.get("cover", "").is_empty(), "screenshot saved as cover")
	check(String(game.get("meta", {}).get("source", "")) == "Retrobrews", "metadata saved")

	# --- core download + run (skip with: -- --no-core)
	var core := ""
	if "--no-core" in OS.get_cmdline_user_args():
		print("  skip core download (--no-core)")
	else:
		core = await Cores.ensure("snes")
	if not "--no-core" in OS.get_cmdline_user_args():
		check(not core.is_empty(), "snes9x core downloaded (%s)" % core.get_file())
	if not core.is_empty():
		var host: Object = ClassDB.instantiate("RetroHost")
		add_child(host)
		host.set_paused(true)
		check(host.load_core(core) and host.load_game(game.path), "snes9x runs the game")
		var frames := 240
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--frames="):
				frames = arg.trim_prefix("--frames=").to_int()
		for i in frames:
			# press Start now and then to get past title screens
			host.set_button(0, 3, i % 120 > 100)
			host.step_frame()
		var img: Image = host.get_frame_image()
		var colors := {}
		for y in range(0, img.get_height(), 8):
			for x in range(0, img.get_width(), 8):
				colors[img.get_pixel(x, y).to_html()] = true
		img.save_png("user://services_frame.png")
		check(colors.size() > 3, "picture has content (%d colours, %s)" % [colors.size(), host.get_frame_size()])
		host.unload_core()

	# --- box art lookup (downloads a picture only)
	var key := Covers.normalize("Legend of Zelda, The (USA) (Rev 1) [!]")
	check(key == "the legend of zelda", "title normalising ('%s')" % key)
	var fake := {"path": "user://nowhere/Super Mario Bros. (World).nes", "system": "nes", "cover": ""}
	var dest := Library.cover_path("nes", fake.path)
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	Covers.request_boxart(fake)
	var got: String = await Covers.image_ready
	check(got == dest and FileAccess.file_exists(dest), "box art found for 'Super Mario Bros. (World)'")
	DirAccess.remove_absolute(dest)

	# --- folder scan
	var root := ProjectSettings.globalize_path("user://scan_test")
	DirAccess.make_dir_recursive_absolute(root + "/Mega Drive")
	DirAccess.make_dir_recursive_absolute(root + "/misc/deeper")
	for f in ["/Mega Drive/sonic_like.bin", "/misc/deeper/game.gba", "/misc/readme.bin", "/misc/x.sfc"]:
		FileAccess.open(root + f, FileAccess.WRITE).store_string("x")
	var before_md := Library.count("md")
	var found := Library.add_source(root)
	check(found == 3, "folder scan finds 3 games, ignores a loose .bin (found %d)" % found)
	check(Library.count("md") == before_md + 1, ".bin inside 'Mega Drive' folder counts as Mega Drive")
	Library.remove_source(root)
	for f in ["/Mega Drive/sonic_like.bin", "/misc/deeper/game.gba", "/misc/readme.bin", "/misc/x.sfc"]:
		DirAccess.remove_absolute(root + f)

	_finish()


func _finish() -> void:
	print("RESULT: ", "PASS" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures else 0)
