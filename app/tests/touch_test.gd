extends Node
## Touch screen (Nintendo DS): taps a point of the game picture with a mouse
## click and saves screenshots before and after.
##   Godot --path app res://tests/touch_test.tscn -- --rom=<file.nds> --tap=0.5,0.67 [--out=<dir>]
## --tap is the point in 0..1 of the whole picture (both DS screens).

func _ready() -> void:
	var rom := App.dev_arg("--rom")
	var tap := App.dev_arg("--tap").split(",")
	var out := App.dev_arg("--out")
	if out.is_empty():
		out = OS.get_user_data_dir()
	if rom.is_empty() or tap.size() != 2:
		print("usage: -- --rom=<file> --tap=x,y [--out=dir]")
		get_tree().quit(2)
		return
	App.selected_game = rom
	App.selected_system = App.system_of(rom)
	var player: Control = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	await get_tree().create_timer(4.0).timeout
	_shot(out.path_join("touch_before.png"))
	var screen: TextureRect = player.get("_screen")
	var pos := screen.global_position + screen.size * Vector2(float(tap[0]), float(tap[1]))
	print("tap at ", pos, " on picture ", Rect2(screen.global_position, screen.size))
	_mouse(pos, true)
	await get_tree().create_timer(0.25).timeout
	_mouse(pos, false)
	await get_tree().create_timer(2.5).timeout
	_shot(out.path_join("touch_after.png"))
	get_tree().quit()


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
