extends SceneTree
## Renders the SVGs with Godot's own SVG rasteriser next to the PNG originals.
##   Godot --headless --path app -s res://tests/svg_preview.gd
## Writes user://svg_compare.png (top row PNG, bottom row SVG).

const ITEMS := [
	["res://assets/logo.png", "res://assets/svg/logo.svg"],
	["res://assets/brand/icon_foreground.png", "res://assets/svg/bull.svg"],
	["res://assets/systems_hd/snes.png", "res://assets/svg/systems/snes.svg"],
	["res://assets/systems_hd/gb.png", "res://assets/svg/systems/gb.svg"],
	["res://assets/systems_hd/arcade.png", "res://assets/svg/systems/arcade.svg"],
	["res://assets/systems_hd/ps1.png", "res://assets/svg/systems/ps1.svg"],
]
const CELL := 320


func _initialize() -> void:
	var sheet := Image.create(CELL * ITEMS.size(), CELL * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0a0e1c"))
	for i in ITEMS.size():
		var png := Image.load_from_file(ProjectSettings.globalize_path(ITEMS[i][0]))
		var svg := Image.new()
		svg.load_svg_from_string(FileAccess.get_file_as_string(ITEMS[i][1]), 1.0)
		for row in 2:
			var img: Image = png if row == 0 else svg
			img.convert(Image.FORMAT_RGBA8)
			img.resize(CELL - 20, CELL - 20, Image.INTERPOLATE_LANCZOS if row == 0 else Image.INTERPOLATE_NEAREST)
			sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * CELL + 10, row * CELL + 10))
	sheet.save_png("user://svg_compare.png")
	print("saved ", ProjectSettings.globalize_path("user://svg_compare.png"))
	quit()
