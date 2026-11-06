class_name DecorPage
extends VBoxContainer

## Market › Dekor: duvar boyası, zemin, giriş halısı, kapı, pencere çerçevesi,
## masa çeşidi ve süsler. Alınan seçenek sahiplenilir, sonra ücretsiz geri
## dönülür. Her stil ve görünen süs müşterileri biraz daha sabırlı yapar.

## kategori -> [{ "button", "index" }]
var _option_buttons := {}
## süs -> Button
var _ornament_buttons := {}
var _bonus_label: Label
var _patio_label: Label
var _patio_btn: Button


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UiKit.label("Dekor", 30, UiKit.TEXT, 900))
	_bonus_label = UiKit.label("", 19, UiKit.PURPLE, 900)
	_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_bonus_label)

	_section("Duvar Boyası", "paint-roller")
	var paints: Array = []
	for i in Decor.WALL_COLORS.size():
		paints.append({ "name": Decor.WALL_COLORS[i]["name"], "color": Decor.WALL_COLORS[i]["wall"] })
	_option_grid("paint", paints, 4)
	_section("Zemin", "grid-3x3")
	var floors: Array = []
	for f in Decor.FLOORS:
		floors.append({ "name": f["name"], "color": f["a"] })
	_option_grid("floor", floors, 4)
	for category in Decor.STYLES:
		if not Decor.STYLES[category].get("patio", false):
			_section(Decor.STYLES[category]["name"], Decor.STYLES[category]["icon"])
			_option_grid(category, Decor.STYLES[category]["options"], 2)

	_section("Süsler", "sparkles")
	for id in Decor.ORNAMENTS:
		if not Decor.ORNAMENTS[id].get("patio", false):
			add_child(_ornament_row(id))

	# Ön bahçe: dükkanın önündeki şerit (masalarına müşteri oturur)
	var head := UiKit.label("Ön Bahçe", 30, UiKit.TEXT, 900)
	add_child(head)
	var hint := UiKit.label("Dükkanın önüne zemin döşe, masa koy: müşteriler dışarıda da oturur. Gölgelik, ışık ve saksılar müşteriyi daha sabırlı yapar.", 18, UiKit.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	for category in Decor.STYLES:
		if Decor.STYLES[category].get("patio", false):
			_section(Decor.STYLES[category]["name"], Decor.STYLES[category]["icon"])
			_option_grid(category, Decor.STYLES[category]["options"], 2)
	add_child(_patio_tables_row())
	for id in Decor.ORNAMENTS:
		if Decor.ORNAMENTS[id].get("patio", false):
			add_child(_ornament_row(id))

	GameState.decor_changed.connect(_refresh)
	GameState.money_changed.connect(func(_v: int) -> void: _refresh())
	_refresh()


func _section(title: String, icon: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	row.add_child(UiKit.icon_rect(icon, UiKit.ORANGE, 26))
	row.add_child(UiKit.label(title, 23, UiKit.TEXT, 900))


func _option_grid(category: String, options: Array, columns: int) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	_option_buttons[category] = []
	for i in options.size():
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 92 if columns > 2 else 78)
		btn.add_theme_font_size_override("font_size", 17 if columns > 2 else 19)
		btn.icon = _swatch(options[i]["color"])
		btn.add_theme_constant_override("icon_max_width", 30)
		btn.clip_text = true
		if columns > 2:
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.pressed.connect(_choose.bind(category, i))
		grid.add_child(btn)
		(_option_buttons[category] as Array).append({ "button": btn, "index": i, "name": options[i]["name"] })


func _ornament_row(id: String) -> Control:
	var data: Dictionary = Decor.ORNAMENTS[id]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(UiKit.badge_rect(data["icon"], UiKit.ORANGE, 48))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	info.add_child(UiKit.label(data["name"], 21, UiKit.TEXT, 900))
	var desc := UiKit.label(data["desc"], 16, UiKit.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 64)
	btn.add_theme_font_size_override("font_size", 20)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_toggle.bind(id))
	row.add_child(btn)
	_ornament_buttons[id] = btn
	return card


## Ön bahçe masası satırı: kaç masa var, "+1 Masa" düğmesi.
func _patio_tables_row() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(UiKit.badge_rect("armchair", UiKit.ORANGE, 48))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	info.add_child(UiKit.label("Bahçe Masası", 21, UiKit.TEXT, 900))
	_patio_label = UiKit.label("", 16, UiKit.MUTED)
	info.add_child(_patio_label)
	_patio_btn = Button.new()
	_patio_btn.custom_minimum_size = Vector2(150, 64)
	_patio_btn.add_theme_font_size_override("font_size", 20)
	_patio_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_patio_btn.pressed.connect(func() -> void:
		if GameState.buy_patio_table():
			Sfx.play("kaching")
			Haptics.success()
			GameState.show_toast("Bahçeye masa kondu!")
		else:
			Sfx.play("error")
	)
	row.add_child(_patio_btn)
	return card


func _refresh() -> void:
	var decor := GameState.decor
	var tables: int = decor["patio_tables"]
	_patio_label.text = "%d / %d masa  •  müşteriler dışarıda oturur" % [tables, Decor.MAX_PATIO_TABLES]
	if tables >= Decor.MAX_PATIO_TABLES:
		_patio_btn.text = "Tam"
		_patio_btn.icon = null
		UiKit.candy(_patio_btn, UiKit.NEUTRAL, UiKit.TEXT)
	else:
		_patio_btn.text = "₺%d" % Decor.PATIO_TABLE_PRICE
		UiKit.set_icon(_patio_btn, "shopping-cart" if int(decor["patio_floor"]) > 0 else "lock", 24)
		UiKit.candy(_patio_btn, UiKit.GREEN if int(decor["patio_floor"]) > 0 else UiKit.NEUTRAL, Color.WHITE if int(decor["patio_floor"]) > 0 else UiKit.TEXT)
	var bonus := roundi(Decor.patience_bonus(decor) * 100.0)
	_bonus_label.text = "Dekorun müşterileri %%%d daha sabırlı yapıyor (en fazla %%45). Her stil ve süs biraz daha ekler." % bonus
	for category in _option_buttons:
		var chosen := Decor.selected(decor, category) if category != "paint" or decor["paint"] else -1
		for entry in _option_buttons[category]:
			var btn: Button = entry["button"]
			var i: int = entry["index"]
			var owned := Decor.owns(decor, category, i)
			var status := "Seçili" if i == chosen else ("Sahip" if owned else "₺%d" % Decor.price_of(category, i))
			btn.text = "%s\n%s" % [entry["name"], status]
			if i == chosen:
				_style(btn, Color("#d9f2d0"), UiKit.GREEN)
			elif owned:
				_style(btn, UiKit.CARD, Color("#d3c4b4"))
			else:
				_style(btn, Color.WHITE, Color("#e3d8cc"))
	for id in _ornament_buttons:
		var btn: Button = _ornament_buttons[id]
		var owned: bool = (decor["ornaments"] as Array).has(id)
		if not owned:
			btn.text = "₺%d" % Decor.ORNAMENTS[id]["price"]
			UiKit.set_icon(btn, "shopping-cart", 24)
			UiKit.candy(btn, UiKit.GREEN, Color.WHITE)
		elif Decor.ornament_on(decor, id):
			btn.text = "Açık"
			UiKit.set_icon(btn, "check", 24)
			UiKit.candy(btn, UiKit.BLUE, Color.WHITE)
		else:
			btn.text = "Kapalı"
			btn.icon = null
			UiKit.candy(btn, UiKit.NEUTRAL, UiKit.TEXT)


func _choose(category: String, index: int) -> void:
	if _needs_patio(Decor.STYLES.get(category, {}).get("patio", false) and category != "patio" and index > 0):
		return
	var was_owned := Decor.owns(GameState.decor, category, index)
	if GameState.choose_decor(category, index):
		Sfx.play("pop" if was_owned else "kaching")
		Haptics.tap() if was_owned else Haptics.success()
		if not was_owned:
			GameState.show_toast("Yeni dekor alındı! Dükkana bak")
	else:
		Sfx.play("error")
		GameState.show_toast("Yeterli paran yok")


func _toggle(id: String) -> void:
	if _needs_patio(Decor.ORNAMENTS[id].get("patio", false)):
		return
	var owned: bool = (GameState.decor["ornaments"] as Array).has(id)
	if GameState.toggle_ornament(id):
		Sfx.play("pop" if owned else "kaching")
		Haptics.tap()
		if not owned:
			GameState.show_toast("%s dükkana asıldı!" % Decor.ORNAMENTS[id]["name"])
	else:
		Sfx.play("error")
		GameState.show_toast("Yeterli paran yok")


## Bahçe zemini yoksa bahçe eşyası alınamaz.
func _needs_patio(is_patio_item: bool) -> bool:
	if is_patio_item and int(GameState.decor["patio_floor"]) == 0:
		Sfx.play("error")
		GameState.show_toast("Önce ön bahçe zemini al")
		return true
	return false


## Seçili seçenek yeşil kenarlı, alınmış olan krem, alınmamış beyaz görünür.
func _style(btn: Button, bg: Color, border: Color) -> void:
	var normal := UiKit.flat(bg, 14, 8)
	normal.border_color = border
	normal.set_border_width_all(3)
	normal.border_width_bottom = 5
	var pressed := UiKit.flat(bg.darkened(0.08), 14, 8)
	pressed.border_color = border
	pressed.set_border_width_all(3)
	for state in ["normal", "hover", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(key, UiKit.TEXT)


## Seçeneğin rengini gösteren yuvarlak köşeli küçük kare.
static func _swatch(color: Color) -> Texture2D:
	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var border := color.darkened(0.3)
	for y in size:
		for x in size:
			var dx := maxf(absf(x - size / 2.0 + 0.5) - (size / 2.0 - 10.0), 0.0)
			var dy := maxf(absf(y - size / 2.0 + 0.5) - (size / 2.0 - 10.0), 0.0)
			var d := sqrt(dx * dx + dy * dy)
			if d > 10.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > 7.0:
				image.set_pixel(x, y, border)
			else:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
