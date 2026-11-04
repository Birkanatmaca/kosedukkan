class_name PaymentPanel
extends Control

## Kasa: servis edilen müşteri burada öder. Müşteri ya kartla öder (POS
## cihazına kartı okutursun) ya da nakit verir (çekmeceden banknot ve bozuk
## para seçip paraüstünü verirsin). Fazla verilen paraüstü kasadan gider.

signal completed(customer: ShopCustomer, loss: int)
signal card_swiped

const NOTES := [200, 100, 50, 20, 10, 5, 1]
const NOTE_COLORS := {
	200: Color("#9b6fc0"), 100: Color("#3f8fd0"), 50: Color("#e0873a"),
	20: Color("#3fa866"), 10: Color("#d9566a"), 5: Color("#8f7a52"), 1: Color("#d4af37"),
}
const BILLS := [5, 10, 20, 50, 100, 200]
const C_TEXT := UiKit.TEXT
const C_MUTED := UiKit.MUTED
const C_GREEN := UiKit.GREEN
const C_ORANGE := UiKit.ORANGE
const C_RED := UiKit.RED

var customer: ShopCustomer
var total := 0
var paid := 0
var by_card := false

var _given: Array[int] = []
var _busy := false
var _sheet: PanelContainer
var _title: Label
var _amount: Label
var _content: VBoxContainer
var _screen: Label
var _card_btn: Button
var _card_icon: TextureRect
var _tray: HFlowContainer
var _given_label: Label
var _give_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# Ödeme de kasanın ekranında yapılır (sipariş ekranıyla aynı görünüm).
	_sheet = OrderEntry.pos_frame(self)
	var box: VBoxContainer = _sheet.get_meta("box")
	var header := OrderEntry.pos_header(box)
	_title = UiKit.label("", 24, Color.WHITE, 900)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_amount = UiKit.label("", 34, Color.WHITE, 900)
	header.add_child(_amount)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_content)


## Arayüzü kasa ekranının telefondaki dikdörtgenine oturtur.
func place(rect: Rect2) -> void:
	_sheet.position = rect.position
	_sheet.scale = rect.size / OrderEntry.DESIGN
	_sheet.size = OrderEntry.DESIGN


func open(c: ShopCustomer, amount: int) -> void:
	customer = c
	total = amount
	_given.clear()
	_busy = false
	for child in _content.get_children():
		child.queue_free()
	_amount.text = "₺%d" % total

	by_card = randf() < 0.5
	if by_card:
		_title.text = "Ödeme • %s • Kart" % c.customer_name
		_build_card()
		Sfx.play("pop")
	else:
		paid = _customer_cash(total)
		_title.text = "Ödeme • %s • Nakit" % c.customer_name
		_build_cash()
		Sfx.play("drawer")

	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


## Test ve kolaylık için: ödemeyi doğru şekilde kendiliğinden tamamlar.
func auto_complete() -> void:
	if not visible or _busy:
		return
	if by_card:
		_swipe_card()
		return
	var change := paid - total
	for note in NOTES:
		while change >= note:
			_add_note(note)
			change -= note
	_give()


# --- Kartla ödeme --------------------------------------------------------------

func _build_card() -> void:
	var screen_box := PanelContainer.new()
	screen_box.add_theme_stylebox_override("panel", Util.style(Color("#d8f0e0"), 14, 14))
	_content.add_child(screen_box)
	_screen = Label.new()
	_screen.text = "₺%d
Kartınızı POS cihazına okutun" % total
	_screen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen.add_theme_color_override("font_color", Color("#1d4d2e"))
	_screen.add_theme_font_size_override("font_size", 28)
	screen_box.add_child(_screen)

	# Kartın kayacağı okuyucu yuvası
	var reader := Control.new()
	reader.custom_minimum_size = Vector2(0, 92)
	_content.add_child(reader)
	var slot := ColorRect.new()
	slot.color = Color("#14171b")
	slot.position = Vector2(110, 72)
	slot.size = Vector2(300, 10)
	reader.add_child(slot)
	_card_icon = UiKit.badge_rect("credit-card", UiKit.BLUE, 72)
	_card_icon.position = Vector2(500, 4)
	_card_icon.size = Vector2(72, 72)
	reader.add_child(_card_icon)

	_card_btn = OrderEntry.pos_button("Kartı Okut", C_GREEN, Color.WHITE, 30)
	UiKit.set_icon(_card_btn, "credit-card", 34)
	_card_btn.custom_minimum_size = Vector2(0, 90)
	_card_btn.pressed.connect(_swipe_card)
	_content.add_child(_card_btn)


func _swipe_card() -> void:
	if _busy:
		return
	_busy = true
	_card_btn.disabled = true
	_screen.text = "İşleniyor..."
	Sfx.play("swipe")
	var tween := create_tween()
	tween.tween_property(_card_icon, "position:x", 110.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.45)
	tween.tween_callback(func() -> void:
		_screen.text = "ONAYLANDI\n₺%d" % total
		Sfx.play("approve")
		card_swiped.emit()
	)
	tween.tween_interval(0.55)
	tween.tween_callback(_finish.bind(0))


# --- Nakit ödeme ---------------------------------------------------------------

func _customer_cash(amount: int) -> int:
	if randf() < 0.15:
		return amount
	for i in BILLS.size():
		if BILLS[i] >= amount:
			var bigger := 1 if randf() < 0.3 else 0
			return BILLS[mini(i + bigger, BILLS.size() - 1)]
	return ceili(amount / 100.0) * 100


func _build_cash() -> void:
	var change := paid - total
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 12)
	_content.add_child(info)
	info.add_child(UiKit.label("Müşteri verdi:", 20, C_MUTED))
	info.add_child(_note_chip(paid, 1.0))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)

	if change == 0:
		info.add_child(UiKit.label("Tam para", 26, C_GREEN, 900))
		var ok := OrderEntry.pos_button("Kasaya Koy", C_GREEN, Color.WHITE, 28)
		ok.custom_minimum_size = Vector2(0, 90)
		ok.pressed.connect(_finish.bind(0))
		_content.add_child(ok)
		return
	info.add_child(UiKit.label("Paraüstü ₺%d" % change, 28, C_ORANGE, 900))

	# Verilen paraüstü tepsisi: dokunulan banknot geri alınır.
	var tray_box := PanelContainer.new()
	tray_box.add_theme_stylebox_override("panel", UiKit.flat(Color("#e6ecf4"), 12, 6))
	tray_box.custom_minimum_size = Vector2(0, 66)
	_content.add_child(tray_box)
	var tray_row := HBoxContainer.new()
	tray_row.add_theme_constant_override("separation", 8)
	tray_box.add_child(tray_row)
	_given_label = Label.new()
	_given_label.add_theme_font_size_override("font_size", 19)
	_given_label.custom_minimum_size = Vector2(150, 0)
	tray_row.add_child(_given_label)
	_tray = HFlowContainer.new()
	_tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tray.add_theme_constant_override("h_separation", 4)
	_tray.add_theme_constant_override("v_separation", 4)
	tray_row.add_child(_tray)

	# Açık kasa çekmecesi: banknotlar ve bozuk para tek sırada
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 6)
	_content.add_child(grid)
	for note in NOTES:
		var btn := OrderEntry.pos_button("₺%d" % note, NOTE_COLORS[note], Color.WHITE, 21)
		btn.custom_minimum_size = Vector2(0, 74)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_add_note.bind(note))
		grid.add_child(btn)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	var reset := OrderEntry.pos_button("Sıfırla", Color("#d7dde6"), C_TEXT, 22)
	reset.custom_minimum_size = Vector2(170, 70)
	reset.pressed.connect(func() -> void:
		_given.clear()
		_refresh_tray()
	)
	row.add_child(reset)
	_give_btn = OrderEntry.pos_button("Paraüstünü Ver", C_GREEN, Color.WHITE, 26)
	UiKit.set_icon(_give_btn, "banknote", 28)
	_give_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_give_btn.custom_minimum_size = Vector2(0, 70)
	_give_btn.pressed.connect(_give)
	row.add_child(_give_btn)
	_refresh_tray()


func _add_note(note: int) -> void:
	_given.append(note)
	Sfx.play("coin" if note == 1 else "note", 0.08)
	_refresh_tray()
	var chip := _tray.get_child(_tray.get_child_count() - 1) as Control
	if chip:
		chip.pivot_offset = chip.custom_minimum_size * 0.5
		chip.scale = Vector2(1.4, 1.4)
		chip.create_tween().tween_property(chip, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_tray() -> void:
	for child in _tray.get_children():
		child.queue_free()
	var sum := 0
	for i in _given.size():
		sum += _given[i]
		var chip := _note_chip(_given[i], 0.7)
		chip.gui_input.connect(_on_chip_input.bind(i))
		_tray.add_child(chip)
	var change := paid - total
	_given_label.text = "Verilen ₺%d / ₺%d" % [sum, change]
	_given_label.add_theme_color_override("font_color", C_GREEN if sum == change else (C_RED if sum > change else C_TEXT))
	_give_btn.disabled = sum < change


func _on_chip_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and index < _given.size():
		_given.remove_at(index)
		Sfx.play("pop")
		_refresh_tray()


func _give() -> void:
	if _busy:
		return
	var sum := 0
	for note in _given:
		sum += note
	var change := paid - total
	if sum < change:
		Sfx.play("error")
		return
	_finish(sum - change)


## Banknot ya da bozuk para görünümü.
func _note_chip(value: int, size_scale: float) -> Control:
	var chip := PanelContainer.new()
	var coin := value == 1
	var style := Util.style(NOTE_COLORS.get(value, Color("#6aa84f")), 40 if coin else 8, 6)
	style.border_color = Color(1, 1, 1, 0.55)
	style.set_border_width_all(3)
	chip.add_theme_stylebox_override("panel", style)
	chip.custom_minimum_size = (Vector2(56, 56) if coin else Vector2(104, 54)) * size_scale
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var l := Label.new()
	l.text = "₺%d" % value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_font_size_override("font_size", int(24 * size_scale))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(l)
	return chip


func _finish(loss: int) -> void:
	_busy = true
	Sfx.play("kaching")
	var tween := create_tween()
	tween.tween_interval(0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func() -> void:
		visible = false
		completed.emit(customer, loss)
	)


func _style(btn: Button, bg: Color, fg: Color, _radius := 20) -> void:
	UiKit.candy(btn, bg, fg)
