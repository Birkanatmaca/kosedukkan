extends Node

## Otomatik kayıt. Oyun durumu telefonda user://save.json dosyasında tutulur:
## açılışta yüklenir, bir şey değiştikçe birkaç saniyede bir ve oyun arka
## plana alınınca / kapanırken kaydedilir. Hesap bağlıysa bulut kaydı da
## buradan güncellenir. Autoload olarak "Saves" adıyla yüklenir.

const PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const VERSION := 1
const AUTOSAVE_DELAY := 4.0

## Hesap ve ayarlar oyun kaydından ayrı tutulur (sıfırlamada hesap kalsın).
var settings := { "sound": true, "account": {} }
## Testlerde (--script ile çalışırken) diske yazılmaz.
var enabled := true

var _dirty := false
var _timer := 0.0


func _ready() -> void:
	# Oyun durdurulsa da sesler ve kayıt çalışsın.
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = not OS.get_cmdline_args().has("--script")
	_load_settings()
	if enabled:
		load_game()
	for sig in ["money_changed", "stock_changed", "prepared_changed", "reviews_changed", "xp_changed",
			"upgrades_changed", "staff_changed", "day_started", "day_ended", "decor_changed", "setup_finished"]:
		GameState.connect(sig, func(_a = null) -> void: _dirty = true)


func _process(delta: float) -> void:
	if not _dirty:
		return
	_timer += delta
	if _timer >= AUTOSAVE_DELAY:
		save_game()


func _notification(what: int) -> void:
	# Telefon uygulamayı arka plana aldığında ya da kapanırken hemen kaydet.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty:
			save_game()


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func snapshot() -> Dictionary:
	var data := GameState.to_dict()
	data["version"] = VERSION
	data["saved_at"] = Time.get_unix_time_from_system()
	return data


func save_game() -> void:
	_dirty = false
	_timer = 0.0
	if not enabled:
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Kayıt yazılamadı: %s" % FileAccess.get_open_error())
		return
	var data := snapshot()
	file.store_string(JSON.stringify(data))
	file.close()
	AccountLink.upload_if_linked(data)


func load_game() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		push_warning("Kayıt dosyası okunamadı, yeni oyun başlıyor.")
		return false
	apply(data)
	# Gece (gün sonu özetinde) kapatıldıysa sabah yeni günle açılır.
	if GameState.setup_done and not GameState.is_open:
		GameState.start_day()
	return true


## Kayıt verisini oyuna uygular (bulut kaydı yüklerken de kullanılır).
func apply(data: Dictionary) -> void:
	GameState.from_dict(data)
	_dirty = false


## Tüm ilerlemeyi siler ve oyunu baştan başlatır (hesap bağlantısı kalır).
func reset_progress() -> void:
	get_tree().paused = false
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	get_tree().reload_current_scene.call_deferred()
	# Autoload'daki durum da sıfırlansın
	GameState.from_dict(_fresh_state())


func _fresh_state() -> Dictionary:
	return {
		"money": Decor.START_BUDGET, "stock": { "tavuk": 3, "tavuk_sis": 3, "kofte": 3, "patates": 3, "kola": 5, "ayran": 0, "lahmacun": 0, "pizza": 0, "pide": 0 },
		"prepared": { "tavuk": [], "tavuk_sis": [], "kofte": [], "patates": [], "lahmacun": [], "pizza": [], "pide": [] }, "reviews": [], "level": 1, "xp": 0,
		"upgrades": {}, "day": 1, "minutes": GameState.OPEN_TIME, "is_open": true, "staff": [],
		"candidates": Staff.make_candidates(), "shop_name": GameState.DEFAULT_SHOP_NAME, "setup_done": false,
		"decor": Decor.default_state(), "tutorial_step": -1,
		"day_stats": { "revenue": 0, "tips": 0, "supplies": 0, "upgrades": 0, "wages": 0, "served": 0, "lost": 0 },
	}


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_save_settings()
	if key == "sound":
		AudioServer.set_bus_mute(0, not value)


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if data is Dictionary:
			settings.merge(data, true)
	AudioServer.set_bus_mute(0, not settings["sound"])


func _save_settings() -> void:
	if not enabled:
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
