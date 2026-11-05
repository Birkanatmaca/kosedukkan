class_name AccountSettingsUI
extends ColorRect

## Hesap Ayarları: hesap bağlama (Google / Apple), ilerlemeyi sıfırlama ve hesabı
## silme. Ayarlar'daki hesap kartından açılır. Sıfırlama ve silme geri alınamaz;
## ikisi de açıklamalı bir onay penceresi ister, onay düğmesi birkaç saniye
## bekledikten sonra basılabilir hale gelir (yanlışlıkla silinmesin).

signal closed

## Onay düğmesinin açılması için beklenen süre (sn)
const CONFIRM_DELAY := 3

var _account_box: VBoxContainer
var _info_label: Label


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
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var back := Button.new()
	UiKit.set_icon(back, "chevron-left", 32)
	back.custom_minimum_size = Vector2(64, 64)
	UiKit.candy(back, UiKit.NEUTRAL, UiKit.TEXT)
	back.pressed.connect(_close)
	head.add_child(back)
	var title := UiKit.label("Hesap Ayarları", 34, UiKit.TEXT, 900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	# Hesap
	v.add_child(UiKit.label("HESAP", 20, UiKit.MUTED, 900))
	_account_box = VBoxContainer.new()
	_account_box.add_theme_constant_override("separation", 12)
	v.add_child(_account_box)
	_refresh_account()

	# İlerleme
	v.add_child(UiKit.label("İLERLEME", 20, UiKit.MUTED, 900))
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
	_info_label = UiKit.label("Gün %d  •  Seviye %d  •  ₺%d" % [GameState.day, GameState.level, GameState.money], 20, UiKit.MUTED)
	info_text.add_child(_info_label)

	v.add_child(_action_button("İlerlemeyi Sıfırla", "rotate-ccw", false,
		"Dükkanın, paran, seviyen, çalışanların ve bütün günlerin silinir; oyuna baştan başlarsın. Hesap bağlantın ve ses ayarların kalır.",
		_confirm_reset))
	v.add_child(_action_button("Hesabı Sil", "trash-2", true,
		"Bu telefondaki her şey silinir: ilerleme, ayarlar ve hesap bağlantısı%s. Oyun ilk kez açılmış gibi başlar." % (" (buluttaki kaydın da)" if AccountLink.is_linked() else ""),
		_confirm_delete))

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


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


## Sıfırla / Sil satırı: düğme ve altında ne olacağını anlatan kısa yazı.
func _action_button(text: String, icon: String, danger: bool, desc: String, action: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 80)
	btn.add_theme_font_size_override("font_size", 26)
	UiKit.set_icon(btn, icon, 30)
	if danger:
		UiKit.candy(btn, UiKit.RED, Color.WHITE)
	else:
		UiKit.candy(btn, UiKit.NEUTRAL, UiKit.RED)
	btn.pressed.connect(action)
	box.add_child(btn)
	var l := _wrap(UiKit.label(desc, 18, UiKit.MUTED))
	box.add_child(l)
	return box


func _confirm_reset() -> void:
	_confirm("İlerleme sıfırlansın mı?",
		"%s dükkanı, ₺%d paran, %d. seviyen ve %d günlük geçmişin silinecek. Bu geri alınamaz." % [GameState.shop_name, GameState.money, GameState.level, GameState.day],
		"Sıfırla", Saves.reset_progress)


func _confirm_delete() -> void:
	_confirm("Hesap silinsin mi?",
		"Bu telefondaki bütün verin silinecek: ilerleme, ayarlar ve hesap bağlantısı%s. Bu geri alınamaz." % (" ile buluttaki kaydın" if AccountLink.is_linked() else ""),
		"Hesabı Sil", Saves.delete_account)


## Onay penceresi: kırmızı düğme CONFIRM_DELAY saniye sayar, sonra basılabilir.
func _confirm(title: String, body: String, ok_text: String, action: Callable) -> void:
	Sfx.play("error")
	Haptics.warning()
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.02, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(UiKit.badge_rect("circle-alert", UiKit.RED, 56))
	var t := UiKit.label(title, 30, UiKit.TEXT, 900)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(t)
	var b := UiKit.label(body, 21, UiKit.MUTED)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(540, 0)
	v.add_child(b)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var cancel := Button.new()
	cancel.text = "Vazgeç"
	cancel.custom_minimum_size = Vector2(0, 80)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.add_theme_font_size_override("font_size", 26)
	UiKit.candy(cancel, UiKit.NEUTRAL, UiKit.TEXT)
	cancel.pressed.connect(shade.queue_free)
	row.add_child(cancel)
	var ok := Button.new()
	ok.custom_minimum_size = Vector2(0, 80)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.add_theme_font_size_override("font_size", 26)
	UiKit.candy(ok, UiKit.RED, Color.WHITE)
	ok.disabled = true
	ok.pressed.connect(func() -> void:
		ok.disabled = true
		action.call()
	)
	row.add_child(ok)
	# Geri sayım: düğme ancak süre dolunca açılır.
	for left in range(CONFIRM_DELAY, 0, -1):
		if not is_instance_valid(ok):
			return
		ok.text = "%s (%d)" % [ok_text, left]
		await get_tree().create_timer(1.0).timeout
	if is_instance_valid(ok):
		ok.text = ok_text
		ok.disabled = false


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	return l


func _close() -> void:
	closed.emit()
	queue_free()
