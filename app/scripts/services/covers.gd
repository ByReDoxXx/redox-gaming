extends Node
## Box art from libretro-thumbnails (autoload "Covers") plus a small queue for
## any image download. Only pictures are fetched, never games.
##
##   Covers.request_boxart(game)            -> emits image_ready(dest) when saved
##   Covers.request_image(url, dest)        -> emits image_ready(dest)

signal image_ready(dest: String)

const BASE := "https://thumbnails.libretro.com/%s/Named_Boxarts/"
const INDEX_DIR := "user://covers/_index"
const INDEX_MAX_AGE := 7 * 24 * 3600
const THUMB_SYSTEMS := {
	"nes": ["Nintendo - Nintendo Entertainment System"],
	"snes": ["Nintendo - Super Nintendo Entertainment System"],
	"gb": ["Nintendo - Game Boy"],
	"gbc": ["Nintendo - Game Boy Color"],
	"gba": ["Nintendo - Game Boy Advance"],
	"md": ["Sega - Mega Drive - Genesis"],
	"sms": ["Sega - Master System - Mark III"],
	"gg": ["Sega - Game Gear"],
	"pce": ["NEC - PC Engine - TurboGrafx 16"],
	"a26": ["Atari - 2600"],
	"ngp": ["SNK - Neo Geo Pocket Color", "SNK - Neo Geo Pocket"],
	"ps1": ["Sony - PlayStation"],
	"arcade": ["FBNeo - Arcade Games"],
	"nds": ["Nintendo - Nintendo DS"],
	"32x": ["Sega - 32X"],
	"ws": ["Bandai - WonderSwan Color", "Bandai - WonderSwan"],
	"a78": ["Atari - 7800"],
	"lynx": ["Atari - Lynx"],
	"vb": ["Nintendo - Virtual Boy"],
	"sg1000": ["Sega - SG-1000"],
	"vectrex": ["GCE - Vectrex"],
	"pokemini": ["Nintendo - Pokemon Mini"],
	"gw": ["Handheld Electronic Game"],
	"sv": ["Watara - Supervision"],
	"tic80": ["TIC-80"],
	"doom": ["DOOM"],
	"cave": ["Cave Story"],
	"segacd": ["Sega - Mega-CD - Sega CD"],
	"pcecd": ["NEC - PC Engine CD - TurboGrafx-CD"],
	"a5200": ["Atari - 5200"],
	"coleco": ["Coleco - ColecoVision"],
	"intv": ["Mattel - Intellivision"],
	"o2": ["Magnavox - Odyssey2"],
	"arduboy": ["Arduboy Inc - Arduboy"],
	"lowres": ["LowRes NX"],
}
## Preferred regions when several box arts match the same title.
const REGION_ORDER := ["(USA", "(World", "(Europe", "(Japan"]

var _queue: Array = []        # [kind, a, b]
var _busy := false
var _indexes := {}            # system -> {normalized title: [names]}
var _missed := {}             # paths we already tried without luck (this session)


func request_image(url: String, dest: String) -> void:
	if FileAccess.file_exists(dest) or _missed.has(dest):
		return
	_queue.append(["img", url, dest])
	_pump()


func request_boxart(game: Dictionary) -> void:
	if not game.cover.is_empty() or not THUMB_SYSTEMS.has(game.system) or _missed.has(game.path):
		return
	_queue.append(["box", game, ""])
	_pump()


func clear_queue() -> void:
	_queue.clear()


func _pump() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		if job[0] == "img":
			if await Net.download(job[1], job[2], Callable(), 30.0):
				image_ready.emit(job[2])
			else:
				_missed[job[2]] = true
		else:
			await _fetch_boxart(job[1])
	_busy = false


func _fetch_boxart(game: Dictionary) -> void:
	var dest := Library.cover_path(game.system, game.path)
	if FileAccess.file_exists(dest):
		Library.refresh_cover(game.path)
		image_ready.emit(dest)
		return
	var key := normalize(game.path.get_file().get_basename())
	for folder in THUMB_SYSTEMS[game.system]:
		var index: Dictionary = await _index(folder)
		if not index.has(key):
			continue
		var name := _best(index[key])
		var url := (BASE % folder.uri_encode()) + (name + ".png").uri_encode()
		if await Net.download(url, dest, Callable(), 30.0):
			Library.refresh_cover(game.path)
			image_ready.emit(dest)
			return
	_missed[game.path] = true


## Title list of one thumbnail folder, cached on disk for a week.
func _index(folder: String) -> Dictionary:
	if _indexes.has(folder):
		return _indexes[folder]
	var file := INDEX_DIR.path_join(folder.replace(" ", "_") + ".txt")
	var names: PackedStringArray
	var fresh := FileAccess.file_exists(file) and \
		Time.get_unix_time_from_system() - FileAccess.get_modified_time(file) < INDEX_MAX_AGE
	if fresh:
		names = FileAccess.get_file_as_string(file).split("\n", false)
	else:
		var html: String = await Net.fetch_text(BASE % folder.uri_encode())
		var re := RegEx.create_from_string("href=\"([^\"]+)\\.png\"")
		for m in re.search_all(html):
			names.append(m.get_string(1).uri_decode())
		if names.size() > 0:
			DirAccess.make_dir_recursive_absolute(INDEX_DIR)
			FileAccess.open(file, FileAccess.WRITE).store_string("\n".join(names))
		elif FileAccess.file_exists(file):
			names = FileAccess.get_file_as_string(file).split("\n", false)
	var index := {}
	for n in names:
		var k := normalize(n)
		if not index.has(k):
			index[k] = []
		index[k].append(n)
	_indexes[folder] = index
	return index


func _best(names: Array) -> String:
	for region in REGION_ORDER:
		for n in names:
			if region in n:
				return n
	return names[0]


## "Legend of Zelda, The (USA) (Rev 1) [!]" -> "the legend of zelda"
static func normalize(s: String) -> String:
	var re_tags := RegEx.create_from_string("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]")
	s = re_tags.sub(s, "", true)
	s = s.replace("_", " ").replace("&", " and ").to_lower()
	var re_the := RegEx.create_from_string("^(.*), (the|a|an)$")
	var m := re_the.search(s.strip_edges())
	if m:
		s = m.get_string(2) + " " + m.get_string(1)
	var out := ""
	for ch in s:
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else " "
	return " ".join(out.split(" ", false))
