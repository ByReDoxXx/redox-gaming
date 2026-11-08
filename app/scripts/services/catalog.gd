extends Node
## Free homebrew games from Retrobrews (autoload "Catalog").
## https://retrobrews.github.io — free games whose authors allowed sharing
## (Retrobrews' statement). One GitHub repo per system with a gamelist.xml.
##
##   var list: Array = await Catalog.list("nes")
##   var ok: bool = await Catalog.install(entry, func(done, total): ...)

const SOURCE_NAME := "Retrobrews"
const SOURCE_URL := "https://retrobrews.github.io"
const REPOS := {
	"nes": "nes-games", "snes": "snes-games", "gbc": "gbc-games", "gba": "gba-games",
	"md": "md-games", "sms": "sms-games", "a26": "atari2600-games",
}
const RAW := "https://raw.githubusercontent.com/retrobrews/%s/master/%s"
const CACHE := "user://catalog"
const MAX_AGE := 24 * 3600

var _lists := {}


func has_store(id: String) -> bool:
	return REPOS.has(id)


## Cached after the first call; uses yesterday's list when offline.
func list(id: String) -> Array:
	if _lists.has(id):
		return _lists[id]
	if not has_store(id):
		return []
	var repo: String = REPOS[id]
	var xml_path := "%s/%s.xml" % [CACHE, repo]
	var fresh := FileAccess.file_exists(xml_path) and \
		Time.get_unix_time_from_system() - FileAccess.get_modified_time(xml_path) < MAX_AGE
	if not fresh:
		await Net.download(RAW % [repo, "gamelist.xml"], xml_path)
	if not FileAccess.file_exists(xml_path):
		return []
	var items := _parse(id, repo, xml_path)
	_lists[id] = items
	return items


func installed_path(e: Dictionary) -> String:
	return Library.system_dir(e.system).path_join(e.file)


func is_installed(e: Dictionary) -> bool:
	return FileAccess.file_exists(installed_path(e))


## Screenshot cached for the store grid ("" until downloaded).
func image_cache_path(e: Dictionary) -> String:
	return "%s/img/%s/%s" % [CACHE, e.repo, e.image]


func install(e: Dictionary, on_progress := Callable()) -> bool:
	var dest := installed_path(e)
	if not await Net.download(RAW % [e.repo, e.file.uri_encode()], dest, on_progress):
		return false
	# cover + metadata are optional: the game works without them
	var cover := Library.cover_path(e.system, dest)
	if FileAccess.file_exists(image_cache_path(e)):
		DirAccess.make_dir_recursive_absolute(cover.get_base_dir())
		DirAccess.copy_absolute(image_cache_path(e), cover)
	elif not e.image.is_empty():
		await Net.download(RAW % [e.repo, e.image.uri_encode()], cover)
	var meta_file := Library.meta_path(e.system, dest)
	DirAccess.make_dir_recursive_absolute(meta_file.get_base_dir())
	var f := FileAccess.open(meta_file, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"title": e.name, "developer": e.developer, "year": e.year, "players": e.players,
		"desc": e.desc, "source": SOURCE_NAME, "source_url": SOURCE_URL,
		"repo_url": "https://github.com/retrobrews/%s" % e.repo,
	}, "  "))
	f.close()
	Library.rescan()
	return true


func _parse(id: String, repo: String, xml_path: String) -> Array:
	var items := []
	var p := XMLParser.new()
	if p.open(xml_path) != OK:
		return items
	var cur := {}
	var field := ""
	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				var n := p.get_node_name()
				if n == "game":
					cur = {}
				field = n
			XMLParser.NODE_TEXT:
				if not field.is_empty() and cur != null:
					cur[field] = String(cur.get(field, "")) + p.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				if p.get_node_name() == "game" and cur.has("path"):
					items.append(_entry(id, repo, cur))
				field = ""
	items.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	return items


func _entry(id: String, repo: String, g: Dictionary) -> Dictionary:
	var file := String(g.get("path", "")).strip_edges().trim_prefix("./")
	var system := id
	# the GBC repo also holds original Game Boy games
	if file.get_extension().to_lower() == "gb" and id == "gbc":
		system = "gb"
	var date := String(g.get("releasedate", "")).strip_edges()
	return {
		"system": system,
		"repo": repo,
		"file": file,
		"name": String(g.get("name", file.get_basename())).strip_edges().xml_unescape(),
		"desc": String(g.get("desc", "")).strip_edges().xml_unescape(),
		"developer": String(g.get("developer", "")).strip_edges().xml_unescape(),
		"year": date.substr(0, 4) if date.length() >= 4 else "",
		"players": String(g.get("players", "")).strip_edges(),
		"image": String(g.get("image", "")).strip_edges().trim_prefix("./"),
	}
