class_name LotUI
extends ColorRect

## Mahallede bir dükkanın önüne gelince açılan pencere. Satılıksa bilgisi ve
## "Satın Al"; bizimse durumu (personel, stok, dün ne kazandı) ve "Bu Dükkana Geç".

signal closed
signal switch_requested(index: int)

## Sokaktaki yer (Branches.LOTS sırası)
var lot := 1
var _box: VBoxContainer


func _ready() -> void:
	color = Color(0.08, 0.05, 0.03, 0.55)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close()
	)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	panel.add_child(_box)
	_build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func _build() -> void:
	for child in _box.get_children():
		child.queue_free()
	var shown := Branches.shown_lot(lot)
	if Branches.owned(shown):
		_build_owned(shown)
	else:
		_build_for_sale(shown)


func _header(icon: String, color_: Color, title: String, sub: String) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_box.add_child(head)
	head.add_child(UiKit.badge_rect(icon, color_, 72))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	head.add_child(text)
	var t := UiKit.label(title, 32, UiKit.TEXT, 900)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(t)
	text.add_child(UiKit.label(sub, 20, UiKit.MUTED, 800))


func _row(icon: String, text: String, value: String, value_color := UiKit.TEXT) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_box.add_child(row)
	row.add_child(UiKit.icon_rect(icon, UiKit.MUTED, 26))
	var l := UiKit.label(text, 21, UiKit.TEXT, 800)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UiKit.label(value, 22, value_color, 900))


func _note(text: String, color_ := UiKit.MUTED) -> void:
	var l := UiKit.label(text, 19, color_, 800)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	_box.add_child(l)


func _button(text: String, icon: String, color_: Color, fg: Color, action: Callable, disabled := false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 86)
	btn.add_theme_font_size_override("font_size", 28)
	UiKit.set_icon(btn, icon, 32)
	UiKit.candy(btn, color_, fg)
	btn.disabled = disabled
	btn.pressed.connect(action)
	_box.add_child(btn)
	return btn


func _build_for_sale(shown: int) -> void:
	var data: Dictionary = Branches.LOTS[shown]
	_header("store", UiKit.ORANGE, "Satılık Dükkan", data["name"])
	_note(data["desc"])
	_row("users", "Müşteri yoğunluğu", "%%%d" % roundi(float(data["demand"]) * 100.0), UiKit.GREEN)
	_row("receipt", "Günlük kira", "₺%d" % data["rent"])
	_row("star", "Gereken seviye", "Sv %d" % data["level"], UiKit.TEXT if GameState.level >= int(data["level"]) else UiKit.RED)
	_note("Aldığın dükkan hazır döşenmiş açılır. Kendi kasiyeri ve aşçısı olunca sen başka dükkandayken de her gün kendi kendine satış yapar; kazancı ortak kasana girer.")
	var price: int = data["price"]
	var can := GameState.level >= int(data["level"]) and GameState.money >= price
	var text := "Satın Al  ₺%s" % Neighborhood.money_text(price)
	if GameState.level < int(data["level"]):
		text = "Seviye %d gerekli" % data["level"]
	elif GameState.money < price:
		text = "₺%s eksik" % Neighborhood.money_text(price - GameState.money)
	_button(text, "shopping-cart" if can else "lock", UiKit.GREEN if can else UiKit.NEUTRAL, Color.WHITE if can else UiKit.TEXT, func() -> void:
		if GameState.buy_lot(shown):
			Sfx.play("level_up")
			Haptics.celebrate()
			GameState.show_toast("Tebrikler! %s artık senin" % data["name"])
			_build()
	, not can)
	_button("Kapat", "x", UiKit.NEUTRAL, UiKit.TEXT, _close)


func _build_owned(shown: int) -> void:
	var index := Branches.shop_at(shown)
	var data: Dictionary = GameState.shops[index]["data"] if index != -1 else GameState.shop_data()
	var lot_name: String = Branches.LOTS[shown]["name"]
	_header("store", UiKit.GREEN, str(data.get("shop_name", GameState.shop_name)),
		"İlk dükkanın" if shown == 0 else "Şuben • %s" % lot_name)
	var staff: Array = data.get("staff", [])
	var roles: Array = staff.map(func(p: Dictionary) -> String: return Staff.role_name(p))
	_row("users", "Personel", ", ".join(roles) if not roles.is_empty() else "Yok")
	var stock := 0
	for id in data.get("menu", []):
		stock += int((data.get("stock", {}) as Dictionary).get(id, 0))
	_row("package", "Menüdeki malzeme", "%d adet" % stock, UiKit.TEXT if stock > 10 else UiKit.ORANGE)
	var report := _last_report(shown)
	if not report.is_empty():
		var net: int = report["net"]
		_row("coins", "Dünkü sonuç", "%s₺%d" % ["+" if net >= 0 else "-", absi(net)], UiKit.GREEN if net >= 0 else UiKit.RED)
	if Branches.can_run(data):
		_note("Kasiyer ve aşçı var: sen burada değilken de her gün çalışır. Malzeme biterse müdür toptancıdan biraz pahalıya getirtir; ucuza stok için arada uğra.", UiKit.GREEN.darkened(0.2))
	else:
		_note("Kendi kendine çalışması için kasiyer ve aşçı lazım (kasiyer için Ek Kasa). Dükkana geç, Market › Personel'den tut.", UiKit.ORANGE.darkened(0.2))
	if index != -1:
		_button("Bu Dükkana Geç", "door-open", UiKit.ORANGE, Color.WHITE, func() -> void:
			switch_requested.emit(index)
			_close()
		)
	_button("Kapat", "x", UiKit.NEUTRAL, UiKit.TEXT, _close)


## Bu yerdeki dükkanın son gün sonu raporu (dün oynanmadıysa).
func _last_report(shown: int) -> Dictionary:
	for report in GameState.day_stats.get("branch_reports", []):
		if int(report["lot"]) == shown:
			return report
	if not GameState.history.is_empty():
		for report in GameState.history.back().get("branch_reports", []):
			if int(report["lot"]) == shown:
				return report
	return {}


func _close() -> void:
	closed.emit()
	queue_free()
