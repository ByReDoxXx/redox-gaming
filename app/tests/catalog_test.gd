extends Node
## Free-games catalog + core check: lists a system's FREE GAMES, optionally
## installs one, downloads the core and runs the game for a few seconds.
##   Godot --path app res://tests/catalog_test.tscn -- --system=doom [--pick=Freedoom] [--seconds=6] [--out=dir]
##   Godot --path app res://tests/catalog_test.tscn -- --rom=<file> [--seconds=6]   (skip the catalog)
## Saves <out>/catalog_<system>.png and prints PASS or FAIL.

func _ready() -> void:
	var system := App.dev_arg("--system")
	var rom := App.dev_arg("--rom")
	var pick := App.dev_arg("--pick")
	var sec_arg := App.dev_arg("--seconds")
	var seconds := float(sec_arg) if not sec_arg.is_empty() else 6.0
	var out := App.dev_arg("--out")
	if out.is_empty():
		out = OS.get_user_data_dir()

	if rom.is_empty():
		var items: Array = await Catalog.list(system)
		print("catalog %s: %d games" % [system, items.size()])
		for i in mini(items.size(), 12):
			print("  ", items[i].name, "  <", items[i].file, ">")
		if pick.is_empty():
			get_tree().quit(0 if not items.is_empty() else 1)
			return
		var entry := {}
		for e in items:   # exact name first, then the first that contains it
			if e.name.to_lower() == pick.to_lower():
				entry = e
				break
		if entry.is_empty():
			for e in items:
				if e.name.to_lower().contains(pick.to_lower()):
					entry = e
					break
		if entry.is_empty():
			return _done(false, "no game matching " + pick)
		if not Catalog.is_installed(entry):
			if not await Catalog.install(entry):
				return _done(false, "install failed")
		rom = Catalog.installed_path(entry)
		print("installed: ", rom, "  title: ", Library.find_game(rom).get("title", "?"))
	if system.is_empty():
		system = Library.find_game(rom).get("system", App.system_of(rom))

	var core: String = await Cores.ensure(system)
	if core.is_empty():
		return _done(false, "core download failed")
	print("core: ", core)

	App.selected_game = rom
	App.selected_system = system
	var player: Control = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	await get_tree().create_timer(seconds).timeout
	var host = player.get("host")
	var ok: bool = host != null and host.is_game_loaded()
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join("catalog_%s.png" % system))
	_done(ok, "ran %s for %.0f s" % [rom.get_file(), seconds])


func _done(ok: bool, msg: String) -> void:
	print("RESULT: ", "PASS" if ok else "FAIL", " - ", msg)
	get_tree().quit(0 if ok else 1)
