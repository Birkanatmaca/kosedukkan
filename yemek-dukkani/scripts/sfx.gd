extends Node

## Oyunun sesleri. Hepsi tools/audio/make_sounds.py ile sentezlenip assets/audio
## altına WAV olarak yazılır. Autoload olarak "Sfx" adıyla yüklenir.
##   Sfx.play("kaching")             kısa ses (aynı anda en fazla VOICES ses)
##   Sfx.set_loop_level("sizzle", 0.6) sürekli sesin şiddeti (0 sessiz, 1 tam)
##   Sfx.set_screen(Main.KITCHEN)     hangi ekrandayız: döngüler ona göre kısılır
## Müzik hep alçak sesle çalar. Ayarlardaki ses kapatma ana kanalı susturur; Ses
## Ayarları ekranında her kategori ayrıca açılıp kapatılır ve kısılıp açılır
## (Saves.settings["audio"]: kategori -> { "on", "vol" }).

const VOICES := 12
## Ayarlarda ayrı ayrı yönetilen ses kategorileri: anahtar -> [ad, ikon]
const CATEGORIES := {
	"music": ["Müzik", "music"],
	"ui": ["Arayüz ve bildirimler", "smartphone"],
	"register": ["Kasa", "receipt"],
	"kitchen": ["Mutfak", "flame"],
	"customers": ["Müşteriler ve salon", "users"],
	"cleaner": ["Temizlikçi", "spray-can"],
	"street": ["Sokak", "signpost"],
}
## Her kısa sesin kategorisi
const SOUND_CATEGORY := {
	"tap": "ui", "pop": "ui", "approve": "ui", "error": "ui", "level_up": "ui", "day_end": "ui",
	"beep": "register", "swipe": "register", "receipt": "register", "kaching": "register",
	"coin": "register", "note": "register", "drawer": "register",
	"sizzle_start": "kitchen", "fryer_drop": "kitchen", "collect": "kitchen", "clink": "kitchen",
	"door_bell": "customers", "spray": "cleaner", "car_pass": "street",
	"phone_ring": "customers", "scooter": "street",
}
const SOUNDS := [
	"tap", "pop", "beep", "coin", "kaching", "note", "approve", "error", "drawer",
	"receipt", "swipe", "door_bell", "sizzle_start", "fryer_drop", "collect", "clink",
	"spray", "car_pass", "level_up", "day_end", "phone_ring", "scooter",
]
## Kısa seslerin varsayılan yüksekliği (dB); verilmeyenler 0
const VOLUME := { "scooter": -8.0, "phone_ring": -3.0, "car_pass": -10.0, "door_bell": -4.0, "spray": -6.0, "tap": -4.0, "beep": -3.0 }
## Döngüler: ad -> [dosya, en yüksek ses (dB), hangi ekranlarda tam duyulur, kategori]
## Ekranlar: 0 market, 1 dükkan, 2 mutfak. Diğer ekranlarda AWAY oranında kısık.
const LOOPS := {
	"sizzle": ["loop_sizzle", -8.0, [2], "kitchen"],
	"fryer": ["loop_fryer", -9.0, [2], "kitchen"],
	"kitchen": ["loop_kitchen", -16.0, [2], "kitchen"],
	"crowd": ["loop_crowd", -15.0, [1], "customers"],
}
const AWAY := 0.12
const MUSIC_DB := -17.0
## Döngülerin ses değişim hızı (saniyede)
const FADE := 2.5

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
## döngü adı -> { "player", "level" (istenen), "now" (şu anki) }
var _loops := {}
var _screen := 1
var _music: AudioStreamPlayer


func _ready() -> void:
	# Oyun durdurulsa da sesler ve kayıt çalışsın.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	for sound in SOUNDS:
		_streams[sound] = load("res://assets/audio/%s.wav" % sound)
	for name in LOOPS:
		var player := AudioStreamPlayer.new()
		player.stream = _looping(LOOPS[name][0])
		player.volume_db = -80.0
		add_child(player)
		_loops[name] = { "player": player, "level": 0.0, "now": 0.0 }
	_music = AudioStreamPlayer.new()
	_music.stream = _looping("music")
	add_child(_music)
	_music.play()
	# Kayıtlı ayarlar (Saves) bu düğümden sonra yüklenir; müzik ayarı bir kare sonra uygulanır.
	_apply_music.call_deferred()
	# Mutfakta aspiratör hep çalışır, dükkanda kalabalık müşteri sayısına göre artar.
	set_loop_level("kitchen", 1.0)


## screen verilirse ses sadece o ekrandayken çalar (ör. salondaki temizlik).
func play(sound: String, pitch_variation := 0.0, screen := -1) -> void:
	if not _streams.has(sound) or (screen >= 0 and screen != _screen):
		return
	var gain := category_gain(SOUND_CATEGORY.get(sound, "ui"))
	if gain <= 0.0:
		return
	for player in _players:
		if not player.playing:
			player.stream = _streams[sound]
			player.volume_db = VOLUME.get(sound, 0.0) + linear_to_db(gain)
			player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
			player.play()
			return


## Sürekli sesin istenen şiddeti (0–1); yumuşakça oraya gider.
func set_loop_level(name: String, level: float) -> void:
	if _loops.has(name):
		_loops[name]["level"] = clampf(level, 0.0, 1.0)


func set_screen(screen: int) -> void:
	_screen = screen


## Kategorinin ayarı: { "on": açık mı, "vol": 0–1 ses düzeyi }
func category(cat: String) -> Dictionary:
	var audio: Dictionary = Saves.settings.get("audio", {})
	var entry: Dictionary = audio.get(cat, {})
	return { "on": bool(entry.get("on", true)), "vol": float(entry.get("vol", 1.0)) }


## Kategorinin çarpanı (kapalıysa 0).
func category_gain(cat: String) -> float:
	var entry := category(cat)
	return entry["vol"] if entry["on"] else 0.0


## Kategori ayarını değiştirir ve kaydeder; döngüler ve müzik hemen uyar.
func set_category(cat: String, on: bool, vol: float) -> void:
	var audio: Dictionary = Saves.settings.get("audio", {}).duplicate(true)
	audio[cat] = { "on": on, "vol": clampf(vol, 0.0, 1.0) }
	Saves.set_setting("audio", audio)
	_apply_music()


func _apply_music() -> void:
	var gain := category_gain("music")
	_music.stream_paused = gain <= 0.0
	_music.volume_db = MUSIC_DB + linear_to_db(maxf(gain, 0.001))


func _process(delta: float) -> void:
	for name in _loops:
		var loop: Dictionary = _loops[name]
		var here: bool = LOOPS[name][2].has(_screen)
		var target: float = loop["level"] * (1.0 if here else AWAY) * category_gain(LOOPS[name][3])
		loop["now"] = move_toward(loop["now"], target, FADE * delta)
		var player: AudioStreamPlayer = loop["player"]
		if loop["now"] <= 0.001:
			if player.playing:
				player.stop()
			continue
		if not player.playing:
			player.play(randf() * player.stream.get_length())
		player.volume_db = LOOPS[name][1] + linear_to_db(loop["now"])


## WAV dosyasını baştan sona döner hale getirir.
func _looping(file: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % file).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


## Oyun kapanırken çalan sesleri durdur (açık kalan döngüler kapanışta sızıntı uyarısı verir).
func _exit_tree() -> void:
	for player in find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
		(player as AudioStreamPlayer).stream = null
