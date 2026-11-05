class_name Haptics
extends RefCounted

## Telefon titreşimi: kısa dokunuşlar oyundaki önemli anları elde hissettirir.
## Ayarlardan kapatılabilir (Saves.settings["haptics"]). Masaüstünde bir şey yapmaz.

## Seçim, malzeme koyma gibi hafif dokunuşlar
static func tap() -> void:
	_buzz(12, 0.35)


## Kıvam yeşile girdi, para geldi
static func light() -> void:
	_buzz(20, 0.5)


## Tam kıvam yakalandı, menüye ürün eklendi
static func success() -> void:
	_buzz(35, 0.8)


## Ürün yandı: iki kısa sert titreşim
static func warning() -> void:
	_buzz(60, 1.0)
	(Engine.get_main_loop() as SceneTree).create_timer(0.12).timeout.connect(_buzz.bind(60, 1.0))


## Seviye atlandı: uzun ve güçlü
static func celebrate() -> void:
	_buzz(120, 1.0)


static func _buzz(ms: int, amplitude: float) -> void:
	if not OS.has_feature("mobile") or not Saves.settings.get("haptics", true):
		return
	Input.vibrate_handheld(ms, amplitude)
