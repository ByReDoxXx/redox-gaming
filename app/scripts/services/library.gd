extends Node
## The player's games (autoload "Library").
##
## Where games come from:
##   user://roms/<system>/...   downloaded free games and copied files
##   user://roms/*              loose files (system from the extension)
##   res://roms/                the bundled test ROM
##   sources                    folders the player added (USB, NAS, Downloads);
##                              scanned in place, nothing is copied
##
## Each game: {path, system, title, cover, meta}

signal changed

const CONFIG := "user://library.json"
const META_DIR := "user://meta"
const COVER_DIR := "user://covers"
const MAX_DEPTH := 6
const MAX_FILES := 20000

## Extensions that only count inside a folder that names the system,
## because they are shared between systems.
const FOLDER_ONLY_EXT := {"md": ["bin"], "a26": ["bin"], "gba": ["bin"], "arcade": ["zip"]}

## Folder-name hints (lowercase) -> system
const FOLDER_HINTS := {
	"nes": ["nes", "famicom", "fc"],
	"snes": ["snes", "sfc", "super nintendo", "super famicom"],
	"gb": ["gb", "gameboy", "game boy"],
	"gbc": ["gbc", "gameboy color", "game boy color"],
	"gba": ["gba", "gameboy advance", "game boy advance"],
	"md": ["md", "megadrive", "mega drive", "genesis"],
	"sms": ["sms", "mastersystem", "master system"],
	"gg": ["gg", "gamegear", "game gear"],
	"pce": ["pce", "pcengine", "pc engine", "turbografx", "tg16"],
	"a26": ["a26", "2600", "atari2600", "atari 2600"],
	"ngp": ["ngp", "ngpc", "neogeo pocket", "neo geo pocket"],
	"ps1": ["ps1", "psx", "playstation"],
	"arcade": ["arcade", "mame", "fbneo", "fba", "neogeo"],
}

var games: Array[Dictionary] = []
var sources: PackedStringArray = []
var _ext := {}   # extension -> system (unambiguous ones)


func _ready() -> void:
	for id in App.SYSTEMS:
		for e in App.SYSTEMS[id]["ext"]:
			_ext[e] = id
	_load_config()
	_install_bundled()
	rescan()


## Exported builds keep res:// inside the .pck, where cores cannot open files
## by path. Copy the bundled games (the test ROM) to user://roms once.
func _install_bundled() -> void:
	if OS.has_feature("editor"):
		return
	var d := DirAccess.open("res://roms")
	if d == null:
		return
	for f in d.get_files():
		var id: String = _ext.get(f.get_extension().to_lower(), "")
		if id.is_empty():
			continue
		var dest := system_dir(id).path_join(f)
		if FileAccess.file_exists(dest):
			continue
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var bytes := FileAccess.get_file_as_bytes("res://roms".path_join(f))
		if bytes.size() > 0:
			FileAccess.open(dest, FileAccess.WRITE).store_buffer(bytes)


func system_dir(id: String) -> String:
	return App.USER_ROM_DIR.path_join(id)


func cover_path(id: String, game_path: String) -> String:
	return COVER_DIR.path_join(id).path_join(game_path.get_file().get_basename() + ".png")


func meta_path(id: String, game_path: String) -> String:
	return META_DIR.path_join(id).path_join(game_path.get_file().get_basename() + ".json")


func games_for(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in games:
		if g.system == id:
			out.append(g)
	return out


func count(id: String) -> int:
	return games_for(id).size()


func find_game(path: String) -> Dictionary:
	for g in games:
		if g.path == path:
			return g
	return {}


# ---------------------------------------------------------------- sources

## Adds a folder (USB stick, network share...) and returns how many games it holds.
func add_source(folder: String) -> int:
	folder = folder.simplify_path()
	if not folder in sources:
		sources.append(folder)
		_save_config()
	var before := games.size()
	rescan()
	return games.size() - before


func remove_source(folder: String) -> void:
	var i := sources.find(folder)
	if i >= 0:
		sources.remove_at(i)
		_save_config()
		rescan()


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if data is Dictionary and data.get("sources") is Array:
		sources = PackedStringArray(data["sources"])


func _save_config() -> void:
	var f := FileAccess.open(CONFIG, FileAccess.WRITE)
	f.store_string(JSON.stringify({"sources": Array(sources)}, "  "))


# ------------------------------------------------------------------ scan

func rescan() -> void:
	var found := {}   # path -> system
	if OS.has_feature("editor"):
		_scan_flat("res://roms", found)
	_scan_flat(App.USER_ROM_DIR, found)
	for id in App.SYSTEMS:
		_scan_dir(system_dir(id), id, found, 0)
	for src in sources:
		_scan_dir(src, "", found, 0)

	games.clear()
	for path in found:
		games.append(_entry(path, found[path]))
	games.sort_custom(func(a, b): return a.title < b.title)
	changed.emit()


func _scan_flat(dir: String, found: Dictionary) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		var id: String = _ext.get(f.get_extension().to_lower(), "")
		if not id.is_empty():
			found[dir.path_join(f)] = id


## hint: system implied by the folder ("" if unknown)
func _scan_dir(dir: String, hint: String, found: Dictionary, depth: int) -> void:
	if depth > MAX_DEPTH or found.size() > MAX_FILES:
		return
	var d := DirAccess.open(dir)
	if d == null:
		return
	var folder_hint := _hint_from_name(dir.get_file())
	if not folder_hint.is_empty():
		hint = folder_hint
	for f in d.get_files():
		var ext := f.get_extension().to_lower()
		var id: String = _ext.get(ext, "")
		if not hint.is_empty() and ext in FOLDER_ONLY_EXT.get(hint, []):
			id = hint
		if not id.is_empty():
			found[dir.path_join(f)] = id
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_scan_dir(dir.path_join(sub), hint, found, depth + 1)


func _hint_from_name(folder: String) -> String:
	var name := folder.to_lower().replace("_", " ").replace("-", " ").strip_edges()
	for id in FOLDER_HINTS:
		for h in FOLDER_HINTS[id]:
			if name == h or (h.length() > 3 and name.contains(h)):
				return id
	return ""


func _entry(path: String, id: String) -> Dictionary:
	var meta := {}
	var mp := meta_path(id, path)
	if FileAccess.file_exists(mp):
		var m = JSON.parse_string(FileAccess.get_file_as_string(mp))
		if m is Dictionary:
			meta = m
	var cp := cover_path(id, path)
	return {
		"path": path,
		"system": id,
		"title": String(meta.get("title", App.pretty_title(path))).to_upper(),
		"cover": cp if FileAccess.file_exists(cp) else "",
		"meta": meta,
	}


func refresh_cover(path: String) -> void:
	for g in games:
		if g.path == path:
			var cp := cover_path(g.system, path)
			g.cover = cp if FileAccess.file_exists(cp) else ""
