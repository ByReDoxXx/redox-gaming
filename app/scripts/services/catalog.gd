extends Node
## Free games for the FREE GAMES tab (autoload "Catalog").
##
## Two sources:
##  - Retrobrews (https://retrobrews.github.io): homebrew whose authors allowed
##    sharing. One GitHub repo per system with a gamelist.xml.
##  - libretro's content downloader (buildbot.libretro.com/assets/cores): the
##    freely distributable games RetroArch offers (TIC-80 carts, Vectrex games
##    released for free by their rights holder, the DOOM shareware episode,
##    Cave Story), plus Freedoom from its GitHub releases.
##
##   var list: Array = await Catalog.list("nes")
##   var ok: bool = await Catalog.install(entry, func(done, total): ...)

const SOURCE_NAME := "Retrobrews"
const SOURCE_URL := "https://retrobrews.github.io"
const REPOS := {
	"nes": "nes-games", "snes": "snes-games", "gbc": "gbc-games", "gba": "gba-games",
	"md": "md-games", "sms": "sms-games", "a26": "atari2600-games",
	"coleco": "colecovision-games",
}
const RAW := "https://raw.githubusercontent.com/retrobrews/%s/master/%s"

const LIBRETRO_NAME := "libretro"
const LIBRETRO_URL := "https://buildbot.libretro.com/assets/cores/"
## system -> folder on the libretro asset server (also the thumbnail system name)
const LIBRETRO := {
	"tic80": "TIC-80", "vectrex": "GCE - Vectrex", "pokemini": "Nintendo - Pokemon Mini",
	"doom": "DOOM", "cave": "Cave Story",
	"quake": "Quake", "rick": "Rick Dangerous", "dinothawr": "Dinothawr", "jnb": "Jump 'n Bump",
	"sbw": "Super Bros War", "arduboy": "Arduous", "chip8": "CHIP-8", "uzebox": "Uzebox",
	"lowres": "LowResNX", "microw8": "MicroW8", "intv": "Mattel - Intellivision",
}
## Files in those folders that are not games.
const SKIP := ["quake-colored-lighting-pack.zip"]
## Thumbnail folder when it differs from the asset folder.
const THUMBS := {"arduboy": "Arduboy Inc - Arduboy"}
const SNAPS := "https://thumbnails.libretro.com/%s/Named_Snaps/%s.png"
## Games from elsewhere, shown before the libretro ones.
const EXTRA := {
	"doom": [{
		"name": "Freedoom", "developer": "Freedoom Project", "year": "2024",
		"url": "https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip",
		"source": "Freedoom", "source_url": "https://freedoom.github.io",
		"desc": "Free, open-source game data for Doom engines: Phase 1 (episodes) and Phase 2 (one long campaign). BSD licence.",
	}],
}

## Facts for the best-known libretro downloads (file name -> fields).
const INFO := {
	"Doom (Shareware).zip": {"developer": "id Software", "year": "1993",
		"desc": "Knee-Deep in the Dead, the first episode of DOOM, released by id Software as free shareware."},
	"Cave Story (En).zip": {"developer": "Studio Pixel", "year": "2004",
		"desc": "Daisuke Amaya's freeware action adventure, in the English translation by Aeon Genesis."},
}

const CACHE := "user://catalog"
const MAX_AGE := 24 * 3600

var _lists := {}


func has_store(id: String) -> bool:
	return REPOS.has(id) or LIBRETRO.has(id)


## Cached after the first call; uses yesterday's list when offline.
func list(id: String) -> Array:
	if _lists.has(id):
		return _lists[id]
	if not has_store(id):
		return []
	if LIBRETRO.has(id):
		var found := await _list_libretro(id)
		if not found.is_empty():
			_lists[id] = found
		return found
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


## Path of the game file ("" when a zip game is not unpacked yet).
func installed_path(e: Dictionary) -> String:
	if e.get("unzip", false):
		var games := _games_in(_unzip_dir(e), e.system)
		return games[0] if not games.is_empty() else ""
	return Library.system_dir(e.system).path_join(e.file)


func is_installed(e: Dictionary) -> bool:
	var p := installed_path(e)
	return not p.is_empty() and FileAccess.file_exists(p)


## Screenshot cached for the store grid ("" until downloaded).
func image_cache_path(e: Dictionary) -> String:
	return "%s/img/%s/%s" % [CACHE, e.repo, e.image]


func install(e: Dictionary, on_progress := Callable()) -> bool:
	if not e.get("url", "").is_empty():
		return await _install_url(e, on_progress)
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
		"image_url": "", "url": "", "unzip": false,
		"source": SOURCE_NAME, "source_url": SOURCE_URL,
	}


# ------------------------------------------------- libretro content + extras

func _list_libretro(id: String) -> Array:
	var folder: String = LIBRETRO[id]
	var html_path := "%s/libretro_%s.html" % [CACHE, id]
	var fresh := FileAccess.file_exists(html_path) and \
		Time.get_unix_time_from_system() - FileAccess.get_modified_time(html_path) < MAX_AGE
	if not fresh:
		await Net.download(LIBRETRO_URL + folder.uri_encode() + "/", html_path)
	var items := []
	for x in EXTRA.get(id, []):
		var e := _blank(id)
		e.merge(x, true)
		e.file = String(x.url).get_file()
		e.unzip = true
		items.append(e)
	if not FileAccess.file_exists(html_path):
		return items
	var html := FileAccess.get_file_as_string(html_path)
	var prefix := "/assets/cores/%s/" % folder.uri_encode()
	var seen := {}
	var re := RegEx.create_from_string('href="([^"]+)"')
	var listed := []
	for m in re.search_all(html):
		var href := m.get_string(1)
		if not href.begins_with(prefix) or href.ends_with("/"):
			continue
		var file := href.substr(prefix.length()).uri_decode()
		var ext := file.get_extension().to_lower()
		if file in SKIP or (ext != "zip" and App.system_of(file, id) != id):
			continue   # prboom.wad and other support files
		var name := _clean_name(file.get_basename())
		if seen.has(name):
			continue   # the same game twice (different dumps)
		seen[name] = true
		var e := _blank(id)
		e.file = file
		e.name = name
		e.url = "https://buildbot.libretro.com" + href
		e.unzip = ext == "zip" and App.system_of(file, id) != id
		e.image = file.get_basename() + ".png"
		e.image_url = SNAPS % [String(THUMBS.get(id, folder)).uri_encode(), _thumb_name(file.get_basename()).uri_encode()]
		e.merge(INFO.get(file, {}), true)
		listed.append(e)
	listed.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	items.append_array(listed)
	return items


func _blank(id: String) -> Dictionary:
	return {
		"system": id, "repo": "libretro_" + id, "file": "", "name": "", "desc": "",
		"developer": "", "year": "", "players": "", "image": "", "image_url": "",
		"url": "", "unzip": false, "source": LIBRETRO_NAME, "source_url": LIBRETRO_URL,
	}


## "Mine Storm (World)" -> "Mine Storm"
func _clean_name(base: String) -> String:
	var re := RegEx.create_from_string("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]")
	var t := re.sub(base, "", true).strip_edges()
	return t if not t.is_empty() else base


## libretro-thumbnails replaces these characters in file names.
func _thumb_name(base: String) -> String:
	for c in ["&", "*", "/", ":", "`", "<", ">", "?", "\\", "|", "\""]:
		base = base.replace(c, "_")
	return base


func _unzip_dir(e: Dictionary) -> String:
	return Library.system_dir(e.system).path_join(_clean_name(String(e.file).get_basename()))


## Game files of a system inside a folder (searched a few levels deep).
func _games_in(dir: String, system: String, depth := 0) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null or depth > 3:
		return out
	for f in d.get_files():
		if App.system_of(f, system) == system:
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_games_in(dir.path_join(sub), system, depth + 1))
	return out


func _install_url(e: Dictionary, on_progress: Callable) -> bool:
	var sys_dir := Library.system_dir(e.system)
	if not e.unzip:
		var dest := sys_dir.path_join(e.file)
		if not await Net.download(e.url, dest, on_progress):
			return false
		_write_meta(e, dest, e.name)
	else:
		var zip_path := "%s/%s" % [CACHE, e.file]
		if not await Net.download(e.url, zip_path, on_progress):
			return false
		var out_dir := _unzip_dir(e)
		# Cave Story needs its whole data folder; elsewhere only the game files
		var sys: Dictionary = App.SYSTEMS[e.system]
		var keep_all: bool = sys.get("keep_all", false) or not sys.get("files", []).is_empty()
		var zip := ZIPReader.new()
		if zip.open(zip_path) != OK:
			return false
		for name in zip.get_files():
			if name.ends_with("/") or name.contains(".."):
				continue
			if not keep_all and App.system_of(name, e.system) != e.system:
				continue
			var dest := out_dir.path_join(name if keep_all else name.get_file())
			DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
			var f := FileAccess.open(dest, FileAccess.WRITE)
			if f != null:
				f.store_buffer(zip.read_file(name))
				f.close()
		zip.close()
		DirAccess.remove_absolute(zip_path)
		_fix_game_dir(out_dir, e.system)
		var games := _games_in(out_dir, e.system)
		if games.is_empty():
			push_warning("Catalog: no %s game inside %s" % [e.system, e.file])
			return false
		for g in games:
			_write_meta(e, g, e.name if games.size() == 1 else App.pretty_title(g).capitalize())
	var img := image_cache_path(e)
	var game := installed_path(e)
	if FileAccess.file_exists(img) and not game.is_empty():
		var cover := Library.cover_path(e.system, game)
		DirAccess.make_dir_recursive_absolute(cover.get_base_dir())
		DirAccess.copy_absolute(img, cover)
	Library.rescan()
	return true


## Quake looks for id1/pak0.pak: move a loose pak0.pak (and its neighbours)
## into an id1 folder and use lower-case names.
func _fix_game_dir(out_dir: String, system: String) -> void:
	var want: String = App.SYSTEMS[system].get("game_dir", "")
	if want.is_empty():
		return
	for g in _games_in(out_dir, system):
		var dir := String(g).get_base_dir()
		if dir.get_file().to_lower() == want:
			continue
		var dest := dir.path_join(want)
		DirAccess.make_dir_recursive_absolute(dest)
		for f in DirAccess.get_files_at(dir):
			DirAccess.rename_absolute(dir.path_join(f), dest.path_join(f.to_lower()))


func _write_meta(e: Dictionary, game: String, title: String) -> void:
	var meta_file := Library.meta_path(e.system, game)
	DirAccess.make_dir_recursive_absolute(meta_file.get_base_dir())
	var f := FileAccess.open(meta_file, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"title": title, "developer": e.developer, "year": e.year, "players": e.players,
		"desc": e.desc, "source": e.source, "source_url": e.source_url,
	}, "  "))
	f.close()
