class_name SettingsUI
extends ColorRect

## Ayarlar: hesap kartı (dokununca Hesap Ayarları: bağlama, ilerlemeyi sıfırlama,
## hesabı silme), ses, titreşim ve dükkan bilgisi. Üst bardaki dişli butonuyla açılır.

signal closed

var _account_box: VBoxContainer
var _sound_btn: Button
var _haptics_btn: Button


func _ready() -> void:
	color = Color(0.08, 0.05, 0.03, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(UiKit.badge_rect("settings", UiKit.MUTED, 56))
	var title := UiKit.label("Ayarlar", 36, UiKit.TEXT, 900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	UiKit.set_icon(close, "x", 30)
	close.custom_minimum_size = Vector2(72, 64)
	UiKit.candy(close, UiKit.NEUTRAL, UiKit.TEXT)
	close.pressed.connect(_close)
	head.add_child(close)

	# Hesap
	v.add_child(UiKit.label("HESAP", 20, UiKit.MUTED, 900))
	_account_box = VBoxContainer.new()
	_account_box.add_theme_constant_override("separation", 12)
	v.add_child(_account_box)
	_refresh_account()

	# Oyun
	v.add_child(UiKit.label("OYUN", 20, UiKit.MUTED, 900))
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UiKit.card_style())
	v.add_child(info)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	info.add_child(info_row)
	info_row.add_child(UiKit.badge_rect("store", UiKit.ORANGE, 56))
	var info_text := VBoxContainer.new()
	info_text.add_theme_constant_override("separation", 0)
	info_row.add_child(info_text)
	info_text.add_child(UiKit.label(GameState.shop_name, 26, UiKit.TEXT, 900))
	info_text.add_child(UiKit.label("Gün %d  •  Seviye %d  •  ₺%d" % [GameState.day, GameState.level, GameState.money], 20, UiKit.MUTED))

	_sound_btn = Button.new()
	_sound_btn.custom_minimum_size = Vector2(0, 76)
	_sound_btn.pressed.connect(func() -> void:
		Saves.set_setting("sound", not Saves.settings["sound"])
		_refresh_sound()
	)
	v.add_child(_sound_btn)
	_refresh_sound()

	_haptics_btn = Button.new()
	_haptics_btn.custom_minimum_size = Vector2(0, 76)
	_haptics_btn.pressed.connect(func() -> void:
		Saves.set_setting("haptics", not Saves.settings.get("haptics", true))
		_refresh_haptics()
		Haptics.success()
	)
	v.add_child(_haptics_btn)
	_refresh_haptics()

	# Ses Ayarları: müzik, kasa, mutfak, müşteriler... ayrı ayrı aç/kapa ve ses düzeyi
	var sound_settings := Button.new()
	sound_settings.text = "Ses Ayarları"
	sound_settings.custom_minimum_size = Vector2(0, 76)
	sound_settings.add_theme_font_size_override("font_size", 24)
	UiKit.set_icon(sound_settings, "music", 30)
	UiKit.candy(sound_settings, Color("#ffe6d2"), UiKit.TEXT)
	sound_settings.pressed.connect(func() -> void:
		var page := SoundSettingsUI.new()
		page.closed.connect(_refresh_sound)
		get_parent().add_child(page)
	)
	v.add_child(sound_settings)

	modulate.a = 0.0
	panel.pivot_offset = Vector2(320, 400)
	panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Hesap kartı: durum ve "Hesap Ayarları" sayfasına giden ok.
func _refresh_account() -> void:
	for child in _account_box.get_children():
		child.queue_free()
	var linked := AccountLink.is_linked()
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 104)
	UiKit.candy(btn, UiKit.CARD, UiKit.TEXT)
	btn.pressed.connect(_open_account)
	_account_box.add_child(btn)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -16
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)
	var badge := UiKit.badge_rect("cloud" if linked else "user", UiKit.GREEN if linked else UiKit.MUTED, 64)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(UiKit.label("Hesap Ayarları", 26, UiKit.TEXT, 900))
	var status := "%s hesabı bağlı" % AccountLink.provider_name(AccountLink.account()["provider"]) if linked else "Misafir • bağla, sıfırla, sil"
	text.add_child(UiKit.label(status, 19, UiKit.MUTED))
	var arrow := UiKit.icon_rect("chevron-right", UiKit.MUTED, 34)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	for child in text.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _open_account() -> void:
	Sfx.play("tap")
	var page := AccountSettingsUI.new()
	page.closed.connect(_refresh_account)
	get_parent().add_child(page)


func _refresh_sound() -> void:
	var on: bool = Saves.settings["sound"]
	_sound_btn.text = "Ses: Açık" if on else "Ses: Kapalı"
	UiKit.set_icon(_sound_btn, "volume-2" if on else "volume-x", 30)
	UiKit.candy(_sound_btn, UiKit.BLUE if on else UiKit.NEUTRAL, Color.WHITE if on else UiKit.TEXT)


func _refresh_haptics() -> void:
	var on: bool = Saves.settings.get("haptics", true)
	_haptics_btn.text = "Titreşim: Açık" if on else "Titreşim: Kapalı"
	UiKit.set_icon(_haptics_btn, "vibrate" if on else "vibrate-off", 30)
	UiKit.candy(_haptics_btn, UiKit.BLUE if on else UiKit.NEUTRAL, Color.WHITE if on else UiKit.TEXT)


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	return l


func _close() -> void:
	closed.emit()
	queue_free()
