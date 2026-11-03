extends Node

## Kısa ses efektleri. Ses dosyası yerine açılışta kodla sentezlenir.
## Autoload olarak "Sfx" adıyla yüklenir: Sfx.play("kaching")

const RATE := 22050
const VOICES := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	# Oyun durdurulsa da sesler ve kayıt çalışsın.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

	_streams["coin"] = _synth(0.25, func(t: float) -> float:
		return _bell(t, [2637.0, 3951.0], 22.0) * 0.45)
	_streams["kaching"] = _synth(0.9, func(t: float) -> float:
		var click := randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.5
		var first := _bell(t, [1568.0, 2349.0, 3136.0], 9.0) * 0.35
		var second := _bell(t - 0.13, [2093.0, 3136.0, 4186.0], 6.0) * 0.4 if t > 0.13 else 0.0
		return click + first + second)
	_streams["note"] = _synth(0.14, func(t: float) -> float:
		return randf_range(-1.0, 1.0) * sin(PI * t / 0.14) * 0.22)
	_streams["beep"] = _synth(0.12, func(t: float) -> float:
		return signf(sin(TAU * 1046.0 * t)) * 0.18)
	_streams["approve"] = _synth(0.3, func(t: float) -> float:
		if t < 0.09:
			return sin(TAU * 1318.0 * t) * 0.4
		if t > 0.13 and t < 0.26:
			return sin(TAU * 1760.0 * t) * 0.4
		return 0.0)
	_streams["drawer"] = _synth(0.3, func(t: float) -> float:
		return randf_range(-1.0, 1.0) * exp(-t * 28.0) * 0.4 + sin(TAU * 110.0 * t) * exp(-t * 18.0) * 0.5)
	_streams["error"] = _synth(0.25, func(t: float) -> float:
		return signf(sin(TAU * 180.0 * t)) * 0.18 * (1.0 - t / 0.25))
	_streams["tap"] = _synth(0.05, func(t: float) -> float:
		return sin(TAU * 1400.0 * t) * exp(-t * 90.0) * 0.25)
	_streams["pop"] = _synth(0.1, func(t: float) -> float:
		return sin(TAU * (600.0 + 6000.0 * t) * t) * (1.0 - t / 0.1) * 0.35)


func play(sound: String, pitch_variation := 0.0) -> void:
	if not _streams.has(sound):
		return
	for player in _players:
		if not player.playing:
			player.stream = _streams[sound]
			player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
			player.play()
			return


## Sönümlenen çan / metal sesi.
func _bell(t: float, freqs: Array, decay: float) -> float:
	var s := 0.0
	for i in freqs.size():
		s += sin(TAU * freqs[i] * t) / (i + 1)
	return s * exp(-t * decay)


func _synth(duration: float, wave: Callable) -> AudioStreamWAV:
	var count := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var sample := clampf(wave.call(float(i) / RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
