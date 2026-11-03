class_name TicketStrip
extends ScrollContainer

## Açık sipariş fişleri, yan yana kaydırılabilir şerit. Mutfakta her fişte
## "Tepsiye Koy" (hazır ürünleri fişin tepsisine koyar), dükkanda ise
## "Teslim Et" (hazır siparişi müşteriye verir) butonu vardır. Fişin üstündeki
## çubuk müşterinin yemeği bekleme sabrını gösterir.

enum Mode { KITCHEN, SHOP }

var mode := Mode.KITCHEN
var shop: Shop

var _row: HBoxContainer
var _empty: Control
## sipariş numarası -> { "card", "bar", "counts": {ürün: Label}, "button" }
var _cards := {}
var _bar_styles: Array[StyleBoxFlat] = []


## Fiş varken şeridin yüksekliği; boşken tek satırlık bilgi kartı kadar küçülür.
const CARDS_HEIGHT := 250
const EMPTY_HEIGHT := 84


func _ready() -> void:
	custom_minimum_size = Vector2(0, CARDS_HEIGHT)
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	add_child(_row)
	_empty = _empty_card()
	_row.add_child(_empty)
	for color in [UiKit.RED, UiKit.YELLOW, UiKit.GREEN]:
		_bar_styles.append(UiKit.flat(color, 6, 0))
	shop.orders_changed.connect(_rebuild)
	_rebuild()


func _process(_delta: float) -> void:
	for order in shop.orders:
		var refs: Dictionary = _cards.get(order["number"], {})
		if refs.is_empty():
			continue
		var customer: ShopCustomer = order["customer"]
		var ratio := clampf(customer.food_patience / customer.max_food_patience, 0.0, 1.0)
		var bar: ProgressBar = refs["bar"]
		bar.value = ratio
		bar.add_theme_stylebox_override("fill", _bar_styles[0 if ratio < 0.25 else (1 if ratio < 0.55 else 2)])
		if mode == Mode.KITCHEN and not order["ready"]:
			# Tepsiye koyabilecek hazır ürün var mı? Varsa buton canlı görünür.
			var can_fill := false
			for id in order["items"]:
				if (order["filled"][id] as Array).size() < int(order["items"][id]) and GameState.available(id) > 0:
					can_fill = true
			(refs["button"] as Button).disabled = not can_fill


func _rebuild() -> void:
	for number in _cards:
		(_cards[number]["card"] as Control).queue_free()
	_cards.clear()
	_empty.visible = shop.orders.is_empty()
	custom_minimum_size.y = EMPTY_HEIGHT if shop.orders.is_empty() else CARDS_HEIGHT
	for order in shop.orders:
		_cards[order["number"]] = _make_card(order)


## Sipariş yokken: ikon ve ne yapılacağını söyleyen tek satır.
func _empty_card() -> Control:
	var card := PanelContainer.new()
	var style := UiKit.flat(Color("#fbf6ef"), 18, 12)
	style.border_color = Color("#efe4d6")
	style.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(640, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(UiKit.icon_rect("receipt", UiKit.MUTED, 34))
	var text := "Sipariş yok • Kasadaki müşteriye dokun, siparişini al" if mode == Mode.SHOP else "Fiş yok • Kasada sipariş alınınca burada görünür"
	var label := UiKit.label(text, 20, UiKit.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return card


func _make_card(order: Dictionary) -> Dictionary:
	var ready: bool = order["ready"]
	var card := PanelContainer.new()
	var style := UiKit.card_style(Color("#eafbea") if ready else UiKit.CARD, 20)
	style.set_content_margin_all(10)
	if ready:
		style.border_color = UiKit.GREEN
		style.border_width_bottom = 5
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(196, 0)
	_row.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	# Durum etiketi: mutfakta hazırlanıyor / teslime hazır
	var status := PanelContainer.new()
	var status_color := UiKit.GREEN if ready else UiKit.ORANGE
	status.add_theme_stylebox_override("panel", UiKit.flat(status_color, 12, 4))
	v.add_child(status)
	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 6)
	status.add_child(status_row)
	status_row.add_child(UiKit.icon_rect("check" if ready else "chef-hat", Color.WHITE, 18))
	status_row.add_child(UiKit.label("HAZIR" if ready else "HAZIRLANIYOR", 16, Color.WHITE, 900))

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	head.add_child(UiKit.icon_rect("receipt", UiKit.ORANGE if not ready else UiKit.GREEN, 24))
	var number := UiKit.label("#%d" % order["number"], 26, UiKit.TEXT, 900)
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(number)
	var customer: ShopCustomer = order["customer"]
	if customer.takeaway:
		head.add_child(UiKit.label("PAKET", 17, UiKit.PURPLE, 900))
	else:
		head.add_child(UiKit.label(customer.customer_name, 18, UiKit.MUTED))

	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	v.add_child(bar)

	# Ürünler: ikon ve "konan / istenen"
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 4)
	v.add_child(items)
	var counts := {}
	for id in order["items"]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -4)
		items.add_child(box)
		box.add_child(UiKit.food_rect(id, 44))
		var need := int(order["items"][id])
		var have := (order["filled"][id] as Array).size()
		var count := UiKit.label("%d/%d" % [have, need], 19, UiKit.GREEN if have >= need else UiKit.TEXT, 900)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(count)
		counts[id] = count

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 20)
	if mode == Mode.KITCHEN:
		if ready:
			button.text = "Hazır"
			UiKit.set_icon(button, "check", 24)
			UiKit.candy(button, UiKit.GREEN, Color.WHITE)
			button.disabled = true
		else:
			button.text = "Tepsiye Koy"
			UiKit.set_icon(button, "hand-platter", 24)
			UiKit.candy(button, UiKit.ORANGE, Color.WHITE)
			button.pressed.connect(shop.fill_order.bind(order))
	else:
		if ready:
			button.text = "Teslim Et"
			UiKit.set_icon(button, "hand-platter", 24)
			UiKit.candy(button, UiKit.GREEN, Color.WHITE)
			button.pressed.connect(shop.deliver.bind(order))
		else:
			button.text = "Mutfakta"
			UiKit.set_icon(button, "chef-hat", 24)
			UiKit.candy(button, UiKit.NEUTRAL, UiKit.TEXT)
			button.disabled = true
	v.add_child(button)

	# Yeni fiş hafifçe zıplayarak gelir.
	card.pivot_offset = Vector2(98, 125)
	card.scale = Vector2(0.9, 0.9)
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return { "card": card, "bar": bar, "counts": counts, "button": button }
