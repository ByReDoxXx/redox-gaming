extends Node
## Cheat codes per game (autoload "Cheats").
##   user://cheats/<system>/<game name>.json   [{"name", "code", "on"}]
## Codes can be typed in, or looked up in the libretro-database .cht files
## on GitHub (matched by game name, like the box art).

const DIR := "user://cheats"
const INDEX_DIR := "user://cheats/_index"
const INDEX_MAX_AGE := 7 * 24 * 3600
const API_ROOT := "https://api.github.com/repos/libretro/libretro-database/contents/cht"
const API_TREE := "https://api.github.com/repos/libretro/libretro-database/git/trees/%s"
const RAW := "https://raw.githubusercontent.com/libretro/libretro-database/master/cht/%s/%s"


func path_for(system: String, game: String) -> String:
	return DIR.path_join(system).path_join(game.get_file().get_basename() + ".json")


func list(system: String, game: String) -> Array:
	var p := path_for(system, game)
	if not FileAccess.file_exists(p):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(p))
	return data if data is Array else []


func store(system: String, game: String, cheats: Array) -> void:
	var p := path_for(system, game)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cheats, "  "))


## Sends the enabled codes to the running core.
func apply(host: Object, system: String, game: String) -> void:
	host.cheat_reset()
	if Settings.get_value("ra_hardcore"):
		return
	var i := 0
	for c in list(system, game):
		if c.get("on", false) and not String(c.get("code", "")).is_empty():
			host.cheat_set(i, true, String(c.code))
			i += 1


# --------------------------------------------------------------- database

## Looks the game up in libretro-database and merges what it finds.
## Returns how many new cheats were added (-1 on network error).
func fetch(system: String, game: String) -> int:
	var folders: Array = Covers.THUMB_SYSTEMS.get(system, [])
	var key := Covers.normalize(game.get_file().get_basename())
	for folder in folders:
		var names: PackedStringArray = await _index(folder)
		if names.is_empty():
			continue
		var matches: Array = []
		for n in names:
			if Covers.normalize(n.get_basename()) == key:
				matches.append(n)
		if matches.is_empty():
			continue
		var text: String = await Net.fetch_text(RAW % [folder.uri_encode(), _best(matches).uri_encode()], 30.0)
		if text.is_empty():
			return -1
		return _merge(system, game, parse_cht(text))
	return 0


func _best(names: Array) -> String:
	for region in Covers.REGION_ORDER:
		for n in names:
			if region in n:
				return n
	return names[0]


## .cht files of one system folder, cached for a week (3 small API calls).
func _index(folder: String) -> PackedStringArray:
	var file := INDEX_DIR.path_join(folder.replace(" ", "_") + ".txt")
	if FileAccess.file_exists(file) and Time.get_unix_time_from_system() - FileAccess.get_modified_time(file) < INDEX_MAX_AGE:
		return FileAccess.get_file_as_string(file).split("\n", false)
	var names := PackedStringArray()
	var root = JSON.parse_string(await Net.fetch_text(API_ROOT, 20.0))
	if root is Array:
		for entry in root:
			if entry.get("name", "") == folder and entry.get("type", "") == "dir":
				var tree = JSON.parse_string(await Net.fetch_text(API_TREE % entry.sha, 30.0))
				if tree is Dictionary and tree.get("tree") is Array:
					for t in tree.tree:
						if String(t.get("path", "")).ends_with(".cht"):
							names.append(t.path)
				break
	if names.size() > 0:
		DirAccess.make_dir_recursive_absolute(INDEX_DIR)
		FileAccess.open(file, FileAccess.WRITE).store_string("\n".join(names))
	elif FileAccess.file_exists(file):
		names = FileAccess.get_file_as_string(file).split("\n", false)
	return names


## RetroArch .cht:  cheat0_desc = "Infinite lives"  cheat0_code = "SXIOPO"
static func parse_cht(text: String) -> Array:
	var by_index := {}
	var re := RegEx.create_from_string("^\\s*cheat(\\d+)_(desc|code|enable)\\s*=\\s*\"?(.*?)\"?\\s*$")
	for line in text.split("\n"):
		var m := re.search(line)
		if m == null:
			continue
		var i := m.get_string(1).to_int()
		if not by_index.has(i):
			by_index[i] = {"name": "", "code": "", "on": false}
		match m.get_string(2):
			"desc": by_index[i].name = m.get_string(3)
			"code": by_index[i].code = m.get_string(3)
	var keys := by_index.keys()
	keys.sort()
	var out := []
	for k in keys:
		if not String(by_index[k].code).is_empty():
			out.append(by_index[k])
	return out


func _merge(system: String, game: String, found: Array) -> int:
	var have := list(system, game)
	var codes := {}
	for c in have:
		codes[c.code] = true
	var added := 0
	for c in found:
		if not codes.has(c.code):
			have.append(c)
			codes[c.code] = true
			added += 1
	store(system, game, have)
	return added
