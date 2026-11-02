class_name SetupUI
extends Control

## Başlangıç: önce dükkan adı sorulur, sonra harabe dükkan verilen bütçeyle
## döşenir. Alınan her şey salonda anında görünür; alınana tekrar dokununca
## iade edilir. Zorunlular tamamlanınca "Dükkanı Aç" ile oyun başlar.

const C_TEXT := UiKit.TEXT
const C_MUTED := UiKit.MUTED
const C_GREEN := UiKit.GREEN
const C_ORANGE := UiKit.ORANGE
const C_CREAM := UiKit.CARD

var _sheet: PanelContainer
var _budget: Label
var _open_btn: Button
var _toggle_buttons := {}
var _count_labels := {}
var _swatches: Array[Button] = []
var _floor_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_sheet()
	_sheet.visible = false
	_build_name_dialog()
	GameState.decor_changed.connect(_refresh)
	GameState.money_changed.connect(func(_v: int) -> void: _refresh())
	_refresh()


# --- Dükkan adı -----------------------------------------------------------------

func _build_name_dialog() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.08, 0.05, 0.03, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)

	var welcome := UiKit.badge_rect("house", UiKit.ORANGE, 110)
	welcome.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(welcome)
	var game_name := UiKit.label("KÖŞE DÜKKAN", 22, UiKit.ORANGE, 900)
	game_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(game_name)
	var title := Label.new()
	title.text = "Hoş geldin!"
	title.add_theme_font_override("font", UiKit.font(900))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	v.add_child(title)
	var desc := Label.new()
	desc.text = "Mahallenin köşesinde eski, harabe bir dükkan devraldın. Elinde ₺%d var. Önce dükkanına bir isim ver:" % Decor.START_BUDGET
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", C_MUTED)
	v.add_child(desc)

	var edit := LineEdit.new()
	edit.placeholder_text = GameState.DEFAULT_SHOP_NAME
	edit.max_length = 20
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(0, 84)
	edit.add_theme_font_size_override("font_size", 34)
	edit.add_theme_stylebox_override("normal", Util.style(C_CREAM, 18, 14))
	edit.add_theme_stylebox_override("focus", Util.style(Color("#ffe9d6"), 18, 14))
	edit.add_theme_color_override("font_color", C_TEXT)
	v.add_child(edit)

	var go := Button.new()
	go.text = "Devam"
	UiKit.set_icon(go, "arrow-right", 34)
	go.custom_minimum_size = Vector2(0, 88)
	go.add_theme_font_size_override("font_size", 32)
	v.add_child(go)
	var confirm := func() -> void:
		GameState.set_shop_name(edit.text)
		Sfx.play("approve")
		overlay.queue_free()
		_show_sheet()
	go.pressed.connect(confirm)
	edit.text_submitted.connect(func(_t: String) -> void: confirm.call())


# --- Kurulum paneli ---------------------------------------------------------------

func _show_sheet() -> void:
	_sheet.visible = true
	_sheet.modulate.a = 0.0
	_sheet.create_tween().tween_property(_sheet, "modulate:a", 1.0, 0.3)
	GameState.show_toast("Burası biraz harabe... Hadi düzenleyelim!")


func _build_sheet() -> void:
	_sheet = PanelContainer.new()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_sheet.offset_left = 16
	_sheet.offset_right = -16
	_sheet.offset_top = -16
	_sheet.offset_bottom = -16
	_sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_sheet.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_theme_constant_override("separation", 10)
	head.add_child(UiKit.badge_rect("hammer", UiKit.ORANGE, 52))
	var title := Label.new()
	title.text = "Dükkanını Kur"
	title.add_theme_font_override("font", UiKit.font(900))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 34)
	head.add_child(title)
	_budget = Label.new()
	_budget.add_theme_font_size_override("font_size", 30)
	head.add_child(_budget)
	var hint := Label.new()
	hint.text = "Aldığına tekrar dokunursan iade edilir. Kalan para malzeme almak için lazım!"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", C_MUTED)
	hint.add_theme_font_size_override("font_size", 20)
	box.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	list.add_child(_section("Zorunlu"))
	list.add_child(_toggle_row("clean"))
	list.add_child(_toggle_row("register"))
	list.add_child(_count_row("tables", "armchair", "Masa + 2 Sandalye", Decor.TABLE_PRICE, Decor.MAX_SETUP_TABLES))

	list.add_child(_section("Görünüm"))
	list.add_child(_toggle_row("paint"))
	list.add_child(_paint_row())
	list.add_child(_floor_row())
	list.add_child(_toggle_row("windows"))
	list.add_child(_toggle_row("lamps"))
	list.add_child(_toggle_row("sign"))
	list.add_child(_count_row("plants", "sprout", "Saksı Bitkisi", Decor.PLANT_PRICE, Decor.MAX_PLANTS))

	_open_btn = Button.new()
	_open_btn.custom_minimum_size = Vector2(0, 92)
	_open_btn.add_theme_font_size_override("font_size", 30)
	_open_btn.pressed.connect(_open_shop)
	box.add_child(_open_btn)


func _open_shop() -> void:
	GameState.finish_setup()
	if GameState.setup_done:
		Sfx.play("kaching")
		if GameState.money < 30:
			GameState.show_toast("Dikkat: malzeme alacak az paran kaldı!")


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", C_MUTED)
	return l


func _row_shell(icon: String, title: String, desc: String) -> Array:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiKit.card_style())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	h.add_child(UiKit.badge_rect(icon, UiKit.ORANGE, 56))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	h.add_child(info)
	var name_l := Label.new()
	name_l.text = title
	name_l.add_theme_font_size_override("font_size", 25)
	info.add_child(name_l)
	var desc_l := Label.new()
	desc_l.text = desc
	desc_l.add_theme_color_override("font_color", C_MUTED)
	desc_l.add_theme_font_size_override("font_size", 19)
	info.add_child(desc_l)
	return [row, h]


func _toggle_row(id: String) -> Control:
	var item: Dictionary = Decor.ITEMS[id]
	var parts := _row_shell(item["icon"], item["name"], item["desc"])
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(160, 64)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func() -> void:
		GameState.toggle_decor(id)
		Sfx.play("pop")
	)
	(parts[1] as HBoxContainer).add_child(btn)
	_toggle_buttons[id] = btn
	return parts[0]


func _count_row(id: String, icon: String, title: String, price: int, limit: int) -> Control:
	var parts := _row_shell(icon, title, "₺%d / adet • en fazla %d" % [price, limit])
	var h: HBoxContainer = parts[1]
	var minus := Button.new()
	UiKit.set_icon(minus, "minus", 30)
	minus.custom_minimum_size = Vector2(64, 64)
	minus.pressed.connect(func() -> void:
		GameState.change_count(id, -1)
		Sfx.play("pop")
	)
	h.add_child(minus)
	var count := Label.new()
	count.custom_minimum_size = Vector2(44, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 30)
	h.add_child(count)
	var plus := Button.new()
	UiKit.set_icon(plus, "plus", 30)
	plus.custom_minimum_size = Vector2(64, 64)
	plus.pressed.connect(func() -> void:
		GameState.change_count(id, 1)
		Sfx.play("pop")
	)
	h.add_child(plus)
	_count_labels[id] = count
	return parts[0]


## Duvar rengi seçimi (boya alındıysa).
func _paint_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in Decor.WALL_COLORS.size():
		var btn := Button.new()
		btn.text = Decor.WALL_COLORS[i]["name"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 64)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(func() -> void:
			GameState.set_paint_color(i)
			Sfx.play("pop")
		)
		row.add_child(btn)
		_swatches.append(btn)
	return row


func _floor_row() -> Control:
	var parts := _row_shell("grid-3x3", "Zemin", "Çatlak zemini yenile")
	var outer: PanelContainer = parts[0]
	var h: HBoxContainer = parts[1]
	# Zemin seçenekleri satırın altına
	var v := VBoxContainer.new()
	outer.remove_child(h)
	outer.add_child(v)
	v.add_child(h)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 8)
	v.add_child(options)
	for i in Decor.FLOORS.size():
		var data: Dictionary = Decor.FLOORS[i]
		var btn := Button.new()
		btn.text = "%s\n%s" % [data["name"], "ücretsiz" if data["price"] == 0 else "₺%d" % data["price"]]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 74)
		btn.add_theme_font_size_override("font_size", 19)
		btn.pressed.connect(func() -> void:
			GameState.set_floor(i)
			Sfx.play("pop")
		)
		options.add_child(btn)
		_floor_buttons.append(btn)
	return outer


func _refresh() -> void:
	var decor := GameState.decor
	_budget.text = "Bütçe: ₺%d" % GameState.money
	_budget.add_theme_color_override("font_color", C_GREEN if GameState.money >= 40 else Color("#e05555"))
	for id in _toggle_buttons:
		var btn: Button = _toggle_buttons[id]
		if decor[id]:
			btn.text = "Alındı"
			UiKit.set_icon(btn, "check", 26)
			_style(btn, C_GREEN, Color.WHITE, 0)
		else:
			btn.text = "Al ₺%d" % Decor.ITEMS[id]["price"]
			btn.icon = null
			_style(btn, C_ORANGE, Color.WHITE, 0)
	for id in _count_labels:
		(_count_labels[id] as Label).text = str(decor[id])
	for i in _swatches.size():
		var colors: Dictionary = Decor.WALL_COLORS[i]
		var selected: bool = decor["paint"] and decor["paint_color"] == i
		_style(_swatches[i], colors["wall"], C_TEXT, 5 if selected else 0)
		_swatches[i].disabled = not decor["paint"]
	for i in _floor_buttons.size():
		var data: Dictionary = Decor.FLOORS[i]
		_style(_floor_buttons[i], (data["a"] as Color).lerp(Color.WHITE, 0.3), C_TEXT, 5 if decor["floor"] == i else 0)

	var missing := Decor.missing(decor)
	_open_btn.disabled = not missing.is_empty()
	_open_btn.text = "Dükkanı Aç" if missing.is_empty() else "Eksik: " + ", ".join(missing)
	if missing.is_empty():
		UiKit.set_icon(_open_btn, "party-popper", 34)
	else:
		_open_btn.icon = null
	_style(_open_btn, C_ORANGE if missing.is_empty() else Color("#cfc6c0"), Color.WHITE, 0)


## border > 0 ise seçili olduğunu gösteren koyu çerçeve çizilir.
func _style(btn: Button, bg: Color, fg: Color, border: int) -> void:
	UiKit.candy(btn, bg, fg, border)
