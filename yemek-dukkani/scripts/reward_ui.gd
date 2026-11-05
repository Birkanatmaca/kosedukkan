class_name RewardUI
extends ColorRect

## Oyuna dönünce çıkan pencereler: "Sen yokken" raporu (kasiyer ve aşçının
## satışları) ve giriş serisi (7 günlük ödül döngüsü). Hud sırayla gösterir.

signal closed

enum Kind { OFFLINE, STREAK }

var kind := Kind.STREAK
var report := {}
var _box: VBoxContainer


func _ready() -> void:
	color = Color(0.08, 0.05, 0.03, 0.65)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	panel.add_child(_box)
	if kind == Kind.OFFLINE:
		_build_offline()
	else:
		_build_streak()
	modulate.a = 0.0
	panel.pivot_offset = Vector2(320, 300)
	panel.scale = Vector2(0.9, 0.9)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _title(icon: String, color_: Color, text: String, sub: String) -> void:
	var badge := UiKit.badge_rect(icon, color_, 96)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(badge)
	var t := UiKit.label(text, 38, UiKit.TEXT, 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	var s := UiKit.label(sub, 21, UiKit.MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(s)


func _row(icon: String, text: String, value: String, value_color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_box.add_child(row)
	row.add_child(UiKit.icon_rect(icon, UiKit.MUTED, 28))
	var l := UiKit.label(text, 22, UiKit.TEXT, 800)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UiKit.label(value, 24, value_color, 900))


func _button(text: String, icon: String, color_: Color, action: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 92)
	btn.add_theme_font_size_override("font_size", 30)
	UiKit.set_icon(btn, icon, 34)
	UiKit.candy(btn, color_, Color.WHITE)
	btn.pressed.connect(action)
	_box.add_child(btn)


# --- Sen yokken ------------------------------------------------------------------

func _build_offline() -> void:
	var minutes: int = report["minutes"]
	var duration := "%d saat %d dakika" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d dakika" % minutes
	_title("store", UiKit.GREEN, "Sen Yokken", "%s boyunca kasiyerin ve aşçın dükkanı işletti." % duration)
	_row("smile", "Servis edilen müşteri", "%d" % report["served"], UiKit.TEXT)
	_row("coins", "Kazanç", "+₺%d" % report["revenue"], UiKit.GREEN)
	_row("star", "Deneyim", "+%d XP" % report["xp"], UiKit.PURPLE)
	var used: Dictionary = report["used"]
	if not used.is_empty():
		var parts: Array[String] = []
		for id in used:
			parts.append("%d %s" % [used[id], Items.display_name(id)])
		var l := UiKit.label("Kullanılan malzeme: " + ", ".join(parts), 18, UiKit.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(l)
	if report["out_of_stock"]:
		var warn := UiKit.label("Malzeme bitince satış durdu. Gitmeden önce stoğu doldur, dükkan daha çok kazansın!", 19, UiKit.RED, 800)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(warn)
	_button("Harika!", "check", UiKit.GREEN, func() -> void:
		Sfx.play("kaching")
		Haptics.success()
		_close()
	)


# --- Giriş serisi ------------------------------------------------------------------

func _build_streak() -> void:
	var today := Rewards.streak_index()
	_title("gift", UiKit.ORANGE, "Giriş Serisi", "%d gündür art arda geliyorsun! Her gün ödül büyür, bir gün kaçırırsan seri baştan başlar." % GameState.login_streak)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_box.add_child(grid)
	for i in Rewards.STREAK_DAYS.size():
		grid.add_child(_day_card(i, today))
	var reward := Rewards.streak_reward(today)
	_button("Ödülü Al  +₺%d" % reward["money"], "gift", UiKit.ORANGE, func() -> void:
		var got := Rewards.claim_streak()
		if not got.is_empty():
			Sfx.play("level_up" if today == Rewards.STREAK_DAYS.size() - 1 else "kaching")
			Haptics.celebrate() if today == Rewards.STREAK_DAYS.size() - 1 else Haptics.success()
			GameState.show_toast("Giriş ödülü: +₺%d%s" % [got["money"], "  •  +%d XP" % got["xp"] if got["xp"] > 0 else ""])
		_close()
	)


## Döngüdeki bir günün kartı: geçmiş günler alındı, bugün parlak, sonrakiler sönük.
func _day_card(index: int, today: int) -> Control:
	var big := index == Rewards.STREAK_DAYS.size() - 1
	var card := PanelContainer.new()
	var bg := Color("#e3f5dc") if index < today else (Color("#ffe8c7") if index == today else UiKit.CARD)
	var style := UiKit.card_style(bg)
	if index == today:
		style.border_color = UiKit.ORANGE
		style.set_border_width_all(4)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(0, 132)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if index > today:
		card.modulate.a = 0.7
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var day := UiKit.label("%d. Gün" % (index + 1), 18, UiKit.MUTED, 900)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(day)
	var icon := UiKit.icon_rect("check" if index < today else ("party-popper" if big else "coins"), UiKit.GREEN if index < today else UiKit.ORANGE, 34)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	var money := UiKit.label("₺%d" % Rewards.streak_reward(index)["money"], 22, UiKit.TEXT, 900)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(money)
	if big:
		var chest := UiKit.label("SANDIK", 15, UiKit.PURPLE, 900)
		chest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(chest)
	return card


func _close() -> void:
	closed.emit()
	queue_free()
