extends Node
## Play history (autoload "Stats"): play time, last played, favourites.
## Saved to user://stats.json, keyed by game path.
##   {path: {"seconds": int, "last": unix time, "fav": bool, "system": id}}

signal changed

const PATH := "user://stats.json"
const RECENT_MAX := 24

var _games := {}
var _session_path := ""
var _session_start := 0.0


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_games = parsed


func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_games))


func entry(path: String) -> Dictionary:
	return _games.get(path, {})


func seconds(path: String) -> int:
	return int(entry(path).get("seconds", 0))


func last_played(path: String) -> int:
	return int(entry(path).get("last", 0))


func is_favorite(path: String) -> bool:
	return bool(entry(path).get("fav", false))


func toggle_favorite(path: String, system: String) -> bool:
	var e: Dictionary = _games.get(path, {})
	e["fav"] = not bool(e.get("fav", false))
	e["system"] = system
	_games[path] = e
	_save()
	changed.emit()
	return e["fav"]


# ------------------------------------------------------------- sessions

func begin(path: String, system: String) -> void:
	end()
	_session_path = path
	_session_start = Time.get_unix_time_from_system()
	var e: Dictionary = _games.get(path, {})
	e["last"] = int(_session_start)
	e["system"] = system
	_games[path] = e
	_save()


## Adds the time since begin(). Safe to call twice.
func end() -> void:
	if _session_path.is_empty():
		return
	var e: Dictionary = _games.get(_session_path, {})
	var now := Time.get_unix_time_from_system()
	e["seconds"] = int(e.get("seconds", 0)) + int(now - _session_start)
	e["last"] = int(now)
	_games[_session_path] = e
	_session_path = ""
	_save()
	changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		end()


# ---------------------------------------------------------------- lists

## Played games that still exist in the library, newest first.
func recent() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in Library.games:
		if last_played(g.path) > 0:
			out.append(g)
	out.sort_custom(func(a, b): return last_played(a.path) > last_played(b.path))
	return out.slice(0, RECENT_MAX)


func favorites() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in Library.games:
		if is_favorite(g.path):
			out.append(g)
	return out


# ------------------------------------------------------------- formatting

static func format_time(secs: int) -> String:
	var m := secs / 60
	if m < 60:
		return App.t("PLAYED_MIN", [maxi(m, 1)])
	return App.t("PLAYED_HOURS", [m / 60, m % 60])


static func format_when(unix: int) -> String:
	var today := int(Time.get_unix_time_from_system()) / 86400
	var day := unix / 86400
	var d := today - day
	if d <= 0:
		return App.t("TODAY")
	if d == 1:
		return App.t("YESTERDAY")
	return App.t("DAYS_AGO", [d])


## "2 SA 15 DK · DÜN" or "" when never played.
func summary(path: String) -> String:
	var last := last_played(path)
	if last == 0:
		return ""
	return "%s · %s" % [format_time(seconds(path)), format_when(last)]
