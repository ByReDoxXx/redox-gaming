extends Node
## Menu sounds (autoload "Sfx"): short square-wave bleeps generated at start,
## so there are no sound files to license. Plays when focus moves and when a
## button is pressed, anywhere in the interface.
##   Sfx.play("move" | "select" | "back" | "error" | "toggle" | "unlock")

const RATE := 22050

## name -> list of [frequency Hz, milliseconds, volume 0..1]
const SOUNDS := {
	"move": [[880.0, 22, 0.25]],
	"select": [[660.0, 35, 0.3], [990.0, 55, 0.3]],
	"back": [[620.0, 35, 0.3], [410.0, 55, 0.3]],
	"toggle": [[740.0, 30, 0.28], [740.0, 0, 0.0], [1110.0, 30, 0.28]],
	"error": [[180.0, 90, 0.35], [140.0, 110, 0.35]],
	"unlock": [[523.0, 70, 0.3], [659.0, 70, 0.3], [784.0, 70, 0.3], [1046.0, 180, 0.3]],
}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _quiet_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name in SOUNDS:
		_streams[name] = _make(SOUNDS[name])
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)
	get_viewport().gui_focus_changed.connect(_on_focus)
	get_tree().node_added.connect(_on_node_added)


func play(name: String) -> void:
	if not Settings.get_value("ui_sounds") or not _streams.has(name) or OS.has_feature("movie"):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.play()


## Screens grab focus while they build; stay quiet for a moment after a change.
func hush(ms := 250) -> void:
	_quiet_until = Time.get_ticks_msec() + ms


func _on_focus(_c: Control) -> void:
	if Time.get_ticks_msec() >= _quiet_until:
		play("move")


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("silent"):
		n.pressed.connect(func(): if not n.has_meta("silent"): play("select"))


func _make(notes: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	for note in notes:
		var freq: float = note[0]
		var n := int(RATE * float(note[1]) / 1000.0)
		var vol: float = note[2]
		var period := RATE / freq
		for i in n:
			# square wave with a short linear fade-out against clicks
			var env := minf(1.0, float(n - i) / (RATE * 0.008))
			var s := vol * env * (1.0 if fmod(i, period) < period / 2.0 else -1.0)
			var v := int(clampf(s, -1.0, 1.0) * 32767.0)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
