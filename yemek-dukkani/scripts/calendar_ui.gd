class_name CalendarUI
extends ColorRect

## Takvim: her oyun günü bir kare. Karede o günün net kazancı yazar (kârlı yeşil,
## zararlı kırmızı, bugün turuncu çerçeveli). Bir güne dokununca altta dökümü
## çıkar: gelir, bahşiş, malzeme, geliştirme, kime ne kadar maaş ödendiği,
## servis edilen ve kaçan müşteri. Ay 28 gündür (4 hafta).

signal closed

const MONTH_DAYS := 28

var _month := 0
var _selected := 0
var _month_label: Label
var _month_total: Label
var _grid: GridContainer
var _detail: VBoxContainer


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
	head.add_child(UiKit.badge_rect("calendar-days", UiKit.ORANGE, 56))
	var title := UiKit.label("Takvim", 36, UiKit.TEXT, 900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	UiKit.set_icon(close, "x", 30)
	UiKit.candy(close, UiKit.NEUTRAL, UiKit.TEXT)
	close.custom_minimum_size = Vector2(64, 64)
	close.pressed.connect(_close)
	head.add_child(close)

	# Ay değiştirme ve ayın toplamı
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	v.add_child(nav)
	var prev := _nav_button("chevron-left")
	prev.pressed.connect(_change_month.bind(-1))
	nav.add_child(prev)
	var month_box := VBoxContainer.new()
	month_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	month_box.add_theme_constant_override("separation", -2)
	nav.add_child(month_box)
	_month_label = UiKit.label("", 26, UiKit.TEXT, 900)
	_month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	month_box.add_child(_month_label)
	_month_total = UiKit.label("", 19, UiKit.MUTED)
	_month_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	month_box.add_child(_month_total)
	var next := _nav_button("chevron-right")
	next.pressed.connect(_change_month.bind(1))
	nav.add_child(next)

	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(_grid)

	var detail_card := PanelContainer.new()
	detail_card.add_theme_stylebox_override("panel", UiKit.card_style())
	v.add_child(detail_card)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	detail_card.add_child(_detail)

	_selected = GameState.day
	_month = (GameState.day - 1) / MONTH_DAYS
	_refresh()

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


## Günün kaydı: bitmiş günler geçmişten, bugün süren kayıtlardan; yoksa boş.
func _record(day: int) -> Dictionary:
	for record in GameState.history:
		if int(record["day"]) == day:
			return record
	if day == GameState.day:
		var today: Dictionary = GameState.day_stats.duplicate()
		today["day"] = day
		today["date"] = Time.get_date_string_from_system()
		today["today"] = true
		today["money"] = GameState.money
		return today
	return {}


func _change_month(step: int) -> void:
	var last := (GameState.day - 1) / MONTH_DAYS
	_month = clampi(_month + step, 0, last)
	_refresh()


func _refresh() -> void:
	var first := _month * MONTH_DAYS + 1
	_month_label.text = "%d. Ay" % (_month + 1)
	var total := 0
	for child in _grid.get_children():
		child.queue_free()
	for i in MONTH_DAYS:
		var day := first + i
		var record := _record(day)
		if not record.is_empty():
			total += GameState.net_of(record)
		_grid.add_child(_day_cell(day, record))
	_month_total.text = "Gün %d–%d  •  Ay toplamı %s" % [first, first + MONTH_DAYS - 1, _money(total)]
	_show_detail(_selected)


func _day_cell(day: int, record: Dictionary) -> Button:
	var cell := Button.new()
	cell.custom_minimum_size = Vector2(86, 80)
	cell.add_theme_font_size_override("font_size", 17)
	var has := not record.is_empty()
	var net := GameState.net_of(record) if has else 0
	cell.text = "%d\n%s" % [day, _short(net) if has else ""]
	var bg := Color("#f1ebe4")
	var fg := UiKit.MUTED
	if has:
		bg = Color("#dff5e4") if net >= 0 else Color("#fbe1df")
		fg = Color("#1f7a40") if net >= 0 else Color("#b8322a")
	var style := UiKit.flat(bg, 14, 4)
	if day == GameState.day:
		style.border_color = UiKit.ORANGE
		style.set_border_width_all(3)
	if day == _selected:
		style.bg_color = bg.darkened(0.08)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		cell.add_theme_stylebox_override(state, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		cell.add_theme_color_override(key, fg)
	cell.disabled = not has
	cell.pressed.connect(func() -> void:
		_selected = day
		_refresh()
	)
	return cell


func _show_detail(day: int) -> void:
	for child in _detail.get_children():
		child.queue_free()
	var record := _record(day)
	var title := "Gün %d" % day
	if record.get("today", false):
		title += "  •  Bugün (sürüyor)"
	elif record.has("date"):
		title += "  •  " + _date(str(record["date"]))
	_detail.add_child(UiKit.label(title, 24, UiKit.TEXT, 900))
	if record.is_empty():
		_detail.add_child(UiKit.label("Bu güne ait kayıt yok.", 20, UiKit.MUTED))
		return
	_row("Satış geliri", int(record.get("revenue", 0)), UiKit.GREEN)
	_row("Bahşiş", int(record.get("tips", 0)), UiKit.GREEN)
	if int(record.get("quests", 0)) > 0:
		_row("Görev ödülleri", int(record.get("quests", 0)), UiKit.GREEN)
	if int(record.get("gifts", 0)) > 0:
		_row("Giriş serisi", int(record.get("gifts", 0)), UiKit.GREEN)
	_row("Malzeme", -int(record.get("supplies", 0)), UiKit.RED)
	_row("Geliştirme", -int(record.get("upgrades", 0)), UiKit.RED)
	_row("Maaşlar", -int(record.get("wages", 0)), UiKit.RED)
	for person in record.get("wages_paid", []):
		_row("    • %s" % person["name"], -int(person["wage"]), UiKit.MUTED)
	if record.has("rent"):
		_row("Kira ve faturalar", -int(record.get("rent", 0)), UiKit.RED)
	for name in record.get("quitters", []):
		_detail.add_child(UiKit.label("    • %s maaşı ödenemedi, ayrıldı" % name, 18, UiKit.RED))
	var net := GameState.net_of(record)
	var sep := ColorRect.new()
	sep.color = Color("#eadfd3")
	sep.custom_minimum_size = Vector2(0, 2)
	_detail.add_child(sep)
	_row("Net kazanç", net, UiKit.GREEN if net >= 0 else UiKit.RED, true)
	_detail.add_child(UiKit.label("Servis: %d müşteri  •  Kaçan: %d  •  Kasa: ₺%d" % [
		int(record.get("served", 0)), int(record.get("lost", 0)), int(record.get("money", 0))], 19, UiKit.MUTED))


func _row(title: String, amount: int, color: Color, bold := false) -> void:
	var row := HBoxContainer.new()
	_detail.add_child(row)
	var name_label := UiKit.label(title, 21 if bold else 20, UiKit.TEXT, 900 if bold else 700)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiKit.label(_money(amount), 22 if bold else 20, color, 900))


func _nav_button(icon: String) -> Button:
	var btn := Button.new()
	UiKit.set_icon(btn, icon, 30)
	UiKit.candy(btn, UiKit.NEUTRAL, UiKit.TEXT)
	btn.custom_minimum_size = Vector2(64, 60)
	return btn


static func _money(amount: int) -> String:
	if amount == 0:
		return "₺0"
	return ("+₺%d" if amount > 0 else "−₺%d") % absi(amount)


## Karede kısa gösterim: 1250 → +1,2B
static func _short(amount: int) -> String:
	var sign := "+" if amount >= 0 else "−"
	var a := absi(amount)
	return "%s%.1fB" % [sign, a / 1000.0] if a >= 1000 else "%s%d" % [sign, a]


## 2026-11-04 → 4 Kasım 2026
static func _date(iso: String) -> String:
	var months := ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
	var parts := iso.split("-")
	if parts.size() != 3:
		return iso
	return "%d %s %s" % [int(parts[2]), months[clampi(int(parts[1]) - 1, 0, 11)], parts[0]]


func _close() -> void:
	closed.emit()
	queue_free()
