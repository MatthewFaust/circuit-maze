extends Node
## Short sound effects synthesized at startup, so the game needs no audio files.
## Sfx.play(&"move") is safe to call often: each sound plays at most once per 60 ms.

const RATE := 22050
## name: [waveform, start Hz, end Hz, seconds, volume]
const SOUNDS := {
	"move": ["square", 196.0, 180.0, 0.05, 0.18],
	"turn": ["square", 294.0, 330.0, 0.04, 0.14],
	"bump": ["noise", 180.0, 60.0, 0.16, 0.55],
	"cut": ["noise", 2600.0, 900.0, 0.13, 0.32],
	"pickup": ["arp", 523.0, 523.0, 0.24, 0.3],
	"damage": ["saw", 320.0, 90.0, 0.24, 0.3],
	"scan": ["sine", 520.0, 1250.0, 0.2, 0.32],
	"backtrack": ["square", 330.0, 220.0, 0.06, 0.15],
	"win": ["arp", 523.0, 523.0, 0.7, 0.32],
	"fail": ["saw", 240.0, 70.0, 0.55, 0.3],
	"drop": ["sine", 480.0, 720.0, 0.06, 0.3],
	"delete": ["sine", 420.0, 180.0, 0.09, 0.3],
	"click": ["sine", 900.0, 900.0, 0.03, 0.18],
	"attack": ["noise", 1400.0, 300.0, 0.09, 0.4],
	"shield": ["sine", 660.0, 990.0, 0.12, 0.28],
	"boss_down": ["saw", 260.0, 50.0, 0.8, 0.32],
}
const ARPEGGIO := [1.0, 1.26, 1.5, 2.0]

var _players := {}
var _last_played := {}
## Headless runs (tests, CI) use a dummy audio driver; skip playback there.
var _silent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	for sound_name: String in SOUNDS:
		var p := AudioStreamPlayer.new()
		p.stream = _synthesize(SOUNDS[sound_name])
		p.max_polyphony = 4
		add_child(p)
		_players[sound_name] = p


func play(sound_name: StringName) -> void:
	var key := String(sound_name)
	if _silent or not _players.has(key):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(key, -1000)) < 60:
		return
	_last_played[key] = now
	var p: AudioStreamPlayer = _players[key]
	p.pitch_scale = randf_range(0.96, 1.04)
	p.play()


static func _synthesize(spec: Array) -> AudioStreamWAV:
	var wave: String = spec[0]
	var f0: float = spec[1]
	var f1: float = spec[2]
	var duration: float = spec[3]
	var volume: float = spec[4]
	var n := int(RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var phase := 0.0
	var smooth := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		if wave == "arp":
			f = f0 * float(ARPEGGIO[mini(int(t * ARPEGGIO.size()), ARPEGGIO.size() - 1)])
		phase += f / RATE
		var s := 0.0
		match wave:
			"sine":
				s = sin(TAU * phase)
			"square", "arp":
				s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"saw":
				s = 2.0 * fmod(phase, 1.0) - 1.0
			"noise":
				# One-pole low-pass: a lower frequency gives a duller thud.
				smooth += (rng.randf_range(-1.0, 1.0) - smooth) * clampf(f * 6.0 / RATE, 0.02, 1.0)
				s = smooth * 2.5
		var attack := minf(1.0, i / (0.005 * RATE))
		var envelope := attack * (1.0 - t) * (1.0 - t)
		bytes.encode_s16(i * 2, int(clampf(s * envelope * volume, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


func _exit_tree() -> void:
	for p: AudioStreamPlayer in _players.values():
		p.stop()
		p.stream = null
