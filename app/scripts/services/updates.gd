extends Node
## New-version check against GitHub Releases (autoload "Updates").
## Runs at most once a day, only reads the public release list.

signal checked(latest: String)

const API := "https://api.github.com/repos/ByReDoxXx/redox-gaming/releases/latest"
const PAGE := "https://github.com/ByReDoxXx/redox-gaming/releases/latest"
const REPO_PAGE := "https://github.com/ByReDoxXx/redox-gaming"
const EVERY := 24 * 3600

var _running := false


func current() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## Newer version tag ("0.2.0") or "" when up to date / unknown.
func available() -> String:
	var latest: String = Settings.get_value("update_latest")
	return latest if is_newer(latest, current()) else ""


func check_daily() -> void:
	if not Settings.get_value("update_check") or OS.has_feature("movie") or OS.has_feature("editor"):
		return
	if Time.get_unix_time_from_system() - float(Settings.get_value("update_last")) < EVERY:
		return
	check()


func check() -> String:
	if _running:
		await checked
		return available()
	_running = true
	var text: String = await Net.fetch_text(API, 15.0)
	_running = false
	var data = JSON.parse_string(text) if not text.is_empty() else null
	if data is Dictionary and data.has("tag_name"):
		Settings.set_value("update_latest", String(data.tag_name).trim_prefix("v"))
		Settings.set_value("update_last", int(Time.get_unix_time_from_system()))
	checked.emit(Settings.get_value("update_latest"))
	return available()


func open_page() -> void:
	OS.shell_open(PAGE)


## "0.10.0" > "0.9.1"
static func is_newer(a: String, b: String) -> bool:
	if a.is_empty():
		return false
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i].to_int() if i < pa.size() else 0
		var y := pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return x > y
	return false
