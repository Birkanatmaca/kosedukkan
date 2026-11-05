class_name QuestsUI
extends ColorRect

## Günlük görevler paneli: her görevin ilerleme çubuğu ve ödülü. Biten görevde
## "Al" butonu çıkar; üç görev de alınınca günün sandığı açılır.

signal closed

var _list: VBoxContainer
var _bonus_label: Label
var _bonus_state: Label


func _ready() -> void:
	color = Color(0.08, 0.05, 0.03, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(UiKit.badge_rect("clipboard-list", UiKit.ORANGE, 56))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", -2)
	head.add_child(titles)
	titles.add_child(UiKit.label("Günlük Görevler", 34, UiKit.TEXT, 900))
	titles.add_child(UiKit.label("%d. Gün • her sabah yenilenir" % GameState.day, 19, UiKit.MUTED))
	var close := Button.new()
	UiKit.set_icon(close, "x", 30)
	UiKit.candy(close, UiKit.NEUTRAL, UiKit.TEXT)
	close.custom_minimum_size = Vector2(64, 64)
	close.pressed.connect(_close)
	head.add_child(close)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	v.add_child(_list)

	# Günün sandığı: üç görevin hepsi alınınca gelen bonus
	var bonus_card := PanelContainer.new()
	bonus_card.add_theme_stylebox_override("panel", UiKit.card_style(Color("#efe4fb")))
	v.add_child(bonus_card)
	var bonus_row := HBoxContainer.new()
	bonus_row.add_theme_constant_override("separation", 12)
	bonus_card.add_child(bonus_row)
	bonus_row.add_child(UiKit.badge_rect("party-popper", UiKit.PURPLE, 52))
	var bonus_text := VBoxContainer.new()
	bonus_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus_text.alignment = BoxContainer.ALIGNMENT_CENTER
	bonus_text.add_theme_constant_override("separation", 0)
	bonus_row.add_child(bonus_text)
	bonus_text.add_child(UiKit.label("Günün Sandığı", 23, UiKit.TEXT, 900))
	_bonus_label = UiKit.label("", 18, UiKit.MUTED)
	_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus_text.add_child(_bonus_label)
	_bonus_state = UiKit.label("", 22, UiKit.PURPLE, 900)
	_bonus_state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bonus_row.add_child(_bonus_state)

	var hint := UiKit.label("Gün biterken alınmamış ödüller kasaya kendiliğinden girer.", 18, UiKit.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)

	GameState.quests_changed.connect(_refresh)
	_refresh()

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	for i in GameState.quests.size():
		_list.add_child(_quest_row(i, GameState.quests[i]))
	if GameState.quests.is_empty():
		_list.add_child(UiKit.label("Bugün görev yok. Yarın sabah yenileri gelecek.", 20, UiKit.MUTED))
	var bonus := Quests.bonus(GameState.level)
	_bonus_label.text = "Üç görevin ödülünü de al: +₺%d  •  +%d XP" % [bonus["money"], bonus["xp"]]
	var claimed := GameState.quests.filter(func(q: Dictionary) -> bool: return q["claimed"]).size()
	_bonus_state.text = "Açıldı!" if GameState.quest_bonus_claimed else "%d / %d" % [claimed, GameState.quests.size()]


func _quest_row(index: int, quest: Dictionary) -> Control:
	var done := Quests.done(quest)
	var claimed: bool = quest["claimed"]
	var card := PanelContainer.new()
	var bg := Color("#e3f5dc") if done and not claimed else UiKit.CARD
	card.add_theme_stylebox_override("panel", UiKit.card_style(bg))
	if claimed:
		card.modulate.a = 0.6
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	if quest["kind"] == "sell":
		row.add_child(UiKit.food_rect(quest["item"], 52))
	else:
		row.add_child(UiKit.badge_rect(Quests.icon(quest), UiKit.GREEN if done else UiKit.ORANGE, 52))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	var title := UiKit.label(Quests.title(quest), 21, UiKit.TEXT, 900)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(title)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	info.add_child(bar_row)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = int(quest["target"])
	bar.value = int(quest["progress"])
	bar.add_theme_stylebox_override("fill", UiKit.flat(UiKit.GREEN if done else UiKit.ORANGE, 6, 0))
	bar.add_theme_stylebox_override("background", UiKit.flat(Color("#e6dcd2"), 6, 0))
	bar_row.add_child(bar)
	var amount := "%d / %d" % [quest["progress"], quest["target"]]
	if quest["kind"] in ["revenue", "tips"]:
		amount = "₺%d / ₺%d" % [quest["progress"], quest["target"]]
	bar_row.add_child(UiKit.label(amount, 18, UiKit.MUTED, 900))

	var reward := "+₺%d\n+%d XP" % [quest["money"], quest["xp"]]
	if done and not claimed:
		var claim := Button.new()
		claim.custom_minimum_size = Vector2(150, 72)
		claim.add_theme_font_size_override("font_size", 19)
		UiKit.candy(claim, UiKit.GREEN, Color.WHITE)
		claim.pressed.connect(_claim.bind(index))
		claim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		claim.text = "Al\n" + reward.replace("\n", " • ")
		row.add_child(claim)
	elif claimed:
		var ok := UiKit.icon_rect("check", UiKit.GREEN, 40)
		ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ok)
	else:
		var r := UiKit.label(reward, 19, UiKit.ORANGE, 900)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(r)
	return card


func _claim(index: int) -> void:
	var reward := GameState.claim_quest(index)
	if reward.is_empty():
		return
	Sfx.play("kaching")
	Haptics.success()
	if reward["bonus"]:
		Sfx.play("approve")
		GameState.show_toast("Günün sandığı açıldı! +₺%d • +%d XP" % [reward["money"], reward["xp"]])
	else:
		GameState.show_toast("Ödül alındı: +₺%d • +%d XP" % [reward["money"], reward["xp"]])


func _close() -> void:
	closed.emit()
	queue_free()
