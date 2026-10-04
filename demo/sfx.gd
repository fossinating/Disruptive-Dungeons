extends Node
## Procedural sound effects, so the demo has audio without any asset files.
## Each color has its own power-down and power-up sound, so you can hear what failed.

const RATE := 22050

var muted := false
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build()


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if muted or not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func _build() -> void:
	_add("shot", [_tone(0.07, 1400, 500, "square", 0.12)])
	_add("enemy_shot", [_tone(0.1, 500, 250, "square", 0.1)])
	_add("shotgun", [_noise(0.22, 0.6, 0.25), _tone(0.18, 180, 50, "saw", 0.4)])
	_add("hit", [_tone(0.05, 420, 200, "square", 0.15)])
	_add("kill", [_noise(0.35, 0.6, 0.15), _tone(0.3, 240, 40, "tri", 0.5)])
	_add("hurt", [_tone(0.22, 260, 90, "saw", 0.4)])
	_add("shield_break", [_tone(0.3, 1800, 300, "square", 0.15), _noise(0.25, 0.4, 0.6)])
	_add("jump", [_tone(0.09, 320, 640, "tri", 0.25)])
	_add("boost", [_noise(0.28, 0.4, 0.7), _tone(0.22, 400, 1400, "sine", 0.25)])
	_add("slam", [_noise(0.4, 0.8, 0.08), _tone(0.4, 140, 35, "sine", 0.7)])
	_add("vent", [_noise(0.4, 0.6, 0.4), _tone(0.3, 120, 60, "saw", 0.3)])
	_add("overheat", [_tone(0.07, 1300, 1300, "square", 0.15), _tone(0.07, 1300, 1300, "square", 0.15, 0.1), _tone(0.07, 1300, 1300, "square", 0.15, 0.2)])
	_add("door", [_tone(0.35, 180, 420, "tri", 0.4)])
	_add("pickup", [_tone(0.1, 660, 660, "tri", 0.3), _tone(0.15, 990, 990, "tri", 0.3, 0.08)])
	_add("deny", [_tone(0.12, 160, 140, "square", 0.2)])
	_add("zap", [_noise(0.2, 0.5, 0.9), _tone(0.2, 2200, 800, "saw", 0.2)])
	_add("roar", [_tone(0.8, 90, 50, "saw", 0.5), _noise(0.8, 0.4, 0.1)])
	var hack := []
	for i in 6:
		hack.append(_tone(0.05, 500 + i * 170, 500 + i * 170, "square", 0.15, i * 0.05))
	_add("hack", hack)

	# Color power-downs: blue falls like a spinning-down motor, green steps down like
	# a deflating spring, red growls out like a dying furnace, purple glitches.
	_add("down_blue", [_tone(0.6, 1400, 160, "sine", 0.5), _tone(0.6, 1050, 120, "sine", 0.25, 0.04)])
	_add("down_green", _steps([784, 622, 494, 392], 0.13, 0.1, "tri", 0.4))
	_add("down_red", [_tone(0.7, 260, 40, "saw", 0.45), _noise(0.5, 0.35, 0.1)])
	_add("down_purple", _steps([880, 620, 740, 440, 520, 260], 0.07, 0.07, "square", 0.25))
	_add("up_blue", [_tone(0.25, 300, 1400, "sine", 0.35)])
	_add("up_green", _steps([392, 494, 622, 784], 0.08, 0.06, "tri", 0.3))
	_add("up_red", [_tone(0.3, 60, 300, "saw", 0.35)])
	_add("up_purple", _steps([260, 520, 440, 880], 0.05, 0.05, "square", 0.2))


func _add(sound: String, parts: Array) -> void:
	_streams[sound] = _to_stream(_mix(parts))


func _steps(freqs: Array, dur: float, spacing: float, wave: String, vol: float) -> Array:
	var out := []
	for i in freqs.size():
		out.append(_tone(dur, freqs[i], freqs[i] * 0.94, wave, vol, i * spacing))
	return out


func _tone(dur: float, f0: float, f1: float, wave: String, vol: float, delay := 0.0) -> PackedFloat32Array:
	var start := int(delay * RATE)
	var n := start + int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in range(start, n):
		var t := float(i - start) / RATE
		var k := t / dur
		phase += f0 * pow(f1 / f0, k) / RATE
		var x := phase - floorf(phase)
		var s := 0.0
		match wave:
			"sine": s = sin(TAU * x)
			"square": s = 1.0 if x < 0.5 else -1.0
			"saw": s = 2.0 * x - 1.0
			_: s = 4.0 * absf(x - 0.5) - 1.0
		buf[i] = s * vol * pow(1.0 - k, 2.0) * minf(1.0, t * 200.0)
	return buf


func _noise(dur: float, vol: float, smooth: float, delay := 0.0) -> PackedFloat32Array:
	var start := int(delay * RATE)
	var n := start + int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var y := 0.0
	for i in range(start, n):
		var k := float(i - start) / (n - start)
		y += smooth * (randf_range(-1.0, 1.0) - y)
		buf[i] = y * vol * pow(1.0 - k, 2.0)
	return buf


func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out


func _to_stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, clampi(int(buf[i] * 26000.0), -32768, 32767))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s
