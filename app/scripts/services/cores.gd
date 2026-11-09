extends Node
## Finds libretro cores and downloads missing ones from the official libretro
## buildbot (autoload "Cores").
##   var path: String = await Cores.ensure("snes", func(done, total): ...)

const BUILDBOT := {
	"windows": "https://buildbot.libretro.com/nightly/windows/x86_64/latest/%s.zip",
	"linux": "https://buildbot.libretro.com/nightly/linux/x86_64/latest/%s.zip",
	"android": "https://buildbot.libretro.com/nightly/android/latest/%s/%s.zip",
}

const USER_CORES := "user://cores"


func file_name(system_id: String) -> String:
	if not App.SYSTEMS.has(system_id):
		return ""
	var base: String = App.SYSTEMS[system_id]["core"]
	match App.platform_folder():
		"windows": return base + ".dll"
		"android": return base + "_android.so"
		_: return base + ".so"


## Download URL of a core; Android picks the build matching the CPU
## (many Android TVs run a 32-bit armeabi-v7a system on a 64-bit chip).
func _url(plat: String, f: String) -> String:
	if plat == "android":
		var abi := "armeabi-v7a" if Engine.get_architecture_name() == "arm32" else "arm64-v8a"
		return BUILDBOT[plat] % [abi, f]
	return BUILDBOT[plat] % f


## Absolute path of an installed core, or "".
func find(system_id: String) -> String:
	var f := file_name(system_id)
	if f.is_empty():
		return ""
	var plat := App.platform_folder()
	var candidates := [
		ProjectSettings.globalize_path("res://cores/%s/%s" % [plat, f]),
		OS.get_executable_path().get_base_dir().path_join("cores").path_join(f),
		ProjectSettings.globalize_path("%s/%s/%s" % [USER_CORES, plat, f]),
	]
	for c in candidates:
		if FileAccess.file_exists(c):
			return c
	return ""


## Returns the core path, downloading it first if needed; "" on failure.
func ensure(system_id: String, on_progress := Callable()) -> String:
	var found := find(system_id)
	if not found.is_empty():
		return found
	var f := file_name(system_id)
	if f.is_empty():
		return ""
	var plat := App.platform_folder()
	var dir := "%s/%s" % [USER_CORES, plat]
	var zip_path := "%s/%s.zip" % [dir, f]
	if not await Net.download(_url(plat, f), zip_path, on_progress):
		return ""
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return ""
	var data := zip.read_file(f)
	zip.close()
	DirAccess.remove_absolute(zip_path)
	if data.is_empty():
		push_error("Cores: %s not found inside the zip" % f)
		return ""
	var out := FileAccess.open("%s/%s" % [dir, f], FileAccess.WRITE)
	if out == null:
		return ""
	out.store_buffer(data)
	out.close()
	return find(system_id)
