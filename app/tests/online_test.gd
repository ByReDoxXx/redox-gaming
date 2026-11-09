extends Node
## Online features: cheat database lookup, update check, .cht parser.
##   Godot --headless --path app res://tests/online_test.tscn

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	print("RedoX online test")
	var parsed := Cheats.parse_cht('cheats = 2\ncheat0_desc = "Infinite lives"\ncheat0_code = "SXIOPO"\ncheat0_enable = false\ncheat1_desc = "Jump"\ncheat1_code = "AAAAAA+BBBBBB"\n')
	check(parsed.size() == 2 and parsed[0].code == "SXIOPO" and parsed[1].name == "Jump", ".cht parser (%s)" % [parsed])

	var game := "user://test_cheats/Super Mario Bros. (World).nes"
	DirAccess.remove_absolute(Cheats.path_for("nes", game))
	var n: int = await Cheats.fetch("nes", game)
	check(n > 0, "cheat database finds Super Mario Bros. (%d cheats)" % n)
	var list := Cheats.list("nes", game)
	if not list.is_empty():
		print("    first: %s = %s" % [list[0].name, list[0].code])

	check(Updates.is_newer("0.10.0", "0.9.1") and not Updates.is_newer("0.1.0", "0.1.0"), "version compare")
	var v: String = await Updates.check()
	check(not String(Settings.get_value("update_latest")).is_empty(), "GitHub latest release read (%s, newer: '%s')" % [Settings.get_value("update_latest"), v])

	print("RESULT: ", "PASS" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures else 0)
