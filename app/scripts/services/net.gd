extends Node
## HTTP downloads (autoload "Net").
##   var ok: bool = await Net.download(url, "user://x.zip", func(done, total): ...)
##   var text: String = await Net.fetch_text(url)

const USER_AGENT := "RedoXGaming/0.1 (+https://github.com)"

var _active := {}   # HTTPRequest -> Callable(progress)


func _process(_delta: float) -> void:
	for req in _active.keys():
		var cb: Callable = _active[req]
		if is_instance_valid(req) and cb.is_valid():
			cb.call(req.get_downloaded_bytes(), req.get_body_size())


func download(url: String, dest: String, on_progress := Callable(), timeout := 120.0) -> bool:
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var tmp := dest + ".part"
	var req := HTTPRequest.new()
	req.download_file = tmp
	req.timeout = timeout
	req.use_threads = true
	add_child(req)
	if on_progress.is_valid():
		_active[req] = on_progress
	var err := req.request(url, ["User-Agent: " + USER_AGENT])
	var ok := false
	if err == OK:
		var res: Array = await req.request_completed
		ok = res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200
	_active.erase(req)
	req.queue_free()
	if not ok:
		if FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)
		push_warning("Net: download failed %s" % url)
		return false
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	return DirAccess.rename_absolute(tmp, dest) == OK


## Returns "" on failure.
func fetch_text(url: String, timeout := 60.0) -> String:
	var req := HTTPRequest.new()
	req.timeout = timeout
	req.use_threads = true
	add_child(req)
	var text := ""
	if req.request(url, ["User-Agent: " + USER_AGENT]) == OK:
		var res: Array = await req.request_completed
		if res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200:
			text = (res[3] as PackedByteArray).get_string_from_utf8()
	req.queue_free()
	return text
