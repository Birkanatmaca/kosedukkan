class_name SettingsUI
extends ColorRect

## Ayarlar: hesap bağlama (Google / Apple), ses, dükkan bilgisi ve
## ilerlemeyi sıfırlama. Üst bardaki dişli butonuyla açılır.

signal closed

var _account_box: VBoxContainer
var _sound_btn: Button
var _reset_btn: Button
var _reset_armed := false
## Gizli sıfırlama: dükkan kartına art arda bu kadar dokununca buton çıkar.
const RESET_TAPS := 5
var _taps := 0
var _last_tap := 0.0


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
	info.mouse_filter = Control.MOUSE_FILTER_STOP
	info.gui_input.connect(_on_info_input)
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

	_reset_btn = Button.new()
	_reset_btn.custom_minimum_size = Vector2(0, 76)
	_reset_btn.add_theme_font_size_override("font_size", 24)
	UiKit.set_icon(_reset_btn, "rotate-ccw", 30)
	_reset_btn.pressed.connect(_on_reset)
	_reset_btn.visible = false
	v.add_child(_reset_btn)
	_set_reset_armed(false)

	modulate.a = 0.0
	panel.pivot_offset = Vector2(320, 400)
	panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_account() -> void:
	for child in _account_box.get_children():
		child.queue_free()

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_style())
	_account_box.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var linked := AccountLink.is_linked()
	row.add_child(UiKit.badge_rect("cloud" if linked else "user", UiKit.GREEN if linked else UiKit.MUTED, 64))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	if linked:
		var acc := AccountLink.account()
		text.add_child(UiKit.label("%s hesabı bağlı" % AccountLink.provider_name(acc["provider"]), 26, UiKit.TEXT, 900))
		text.add_child(_wrap(UiKit.label("%s • İlerlemen buluta kaydediliyor. Yeni telefonda aynı hesapla girince dükkanın geri gelir." % acc.get("name", ""), 20, UiKit.MUTED)))
	else:
		text.add_child(UiKit.label("Misafir oyuncu", 26, UiKit.TEXT, 900))
		text.add_child(_wrap(UiKit.label("İlerlemen sadece bu telefonda. Hesabını bağla, telefon değişse de dükkanın kaybolmasın.", 20, UiKit.MUTED)))

	if linked:
		var unlink := Button.new()
		unlink.text = "Bağlantıyı Kaldır"
		unlink.custom_minimum_size = Vector2(0, 72)
		UiKit.set_icon(unlink, "unlink", 28)
		UiKit.candy(unlink, UiKit.NEUTRAL, UiKit.TEXT)
		unlink.pressed.connect(func() -> void:
			AccountLink.unlink()
			_refresh_account()
		)
		_account_box.add_child(unlink)
		return

	# Google: beyaz buton; Apple: siyah buton (mağaza kılavuzlarındaki gibi).
	_account_box.add_child(_provider_button("google", "Google ile Bağla", Color.WHITE, UiKit.TEXT))
	_account_box.add_child(_provider_button("apple", "Apple ile Bağla", Color("#111111"), Color.WHITE))


func _provider_button(provider: String, text: String, bg: Color, fg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 80)
	btn.add_theme_font_size_override("font_size", 27)
	UiKit.set_icon(btn, "log-in", 30)
	UiKit.candy(btn, bg, fg)
	if bg == Color.WHITE:
		# Beyaz butonun kenarı belli olsun
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var style := btn.get_theme_stylebox(state) as StyleBoxFlat
			style.border_color = Color("#d9cfc6")
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
	btn.pressed.connect(func() -> void:
		AccountLink.link(provider, func(ok: bool, message: String) -> void:
			GameState.show_toast(message)
			Sfx.play("approve" if ok else "error")
			if ok:
				_refresh_account()
		)
	)
	return btn


func _refresh_sound() -> void:
	var on: bool = Saves.settings["sound"]
	_sound_btn.text = "Ses: Açık" if on else "Ses: Kapalı"
	UiKit.set_icon(_sound_btn, "volume-2" if on else "volume-x", 30)
	UiKit.candy(_sound_btn, UiKit.BLUE if on else UiKit.NEUTRAL, Color.WHITE if on else UiKit.TEXT)


## Dükkan kartına hızlıca 5 kez dokununca gizli "İlerlemeyi Sıfırla" butonu belirir.
func _on_info_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var now := Time.get_ticks_msec() / 1000.0
	_taps = _taps + 1 if now - _last_tap < 0.6 else 1
	_last_tap = now
	if _taps >= RESET_TAPS and not _reset_btn.visible:
		_reset_btn.visible = true
		_reset_btn.modulate.a = 0.0
		_reset_btn.create_tween().tween_property(_reset_btn, "modulate:a", 1.0, 0.25)
		Sfx.play("pop")


## Yanlışlıkla basılmasın: ilk basış onay ister, ikincisi sıfırlar.
func _on_reset() -> void:
	if not _reset_armed:
		_set_reset_armed(true)
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(self):
				_set_reset_armed(false)
		)
		return
	Saves.reset_progress()


func _set_reset_armed(armed: bool) -> void:
	_reset_armed = armed
	_reset_btn.text = "Emin misin? Tekrar bas" if armed else "İlerlemeyi Sıfırla"
	UiKit.candy(_reset_btn, UiKit.RED if armed else UiKit.NEUTRAL, Color.WHITE if armed else UiKit.RED)


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	return l


func _close() -> void:
	closed.emit()
	queue_free()
