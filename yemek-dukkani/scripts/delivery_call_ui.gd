class_name DeliveryCallUI
extends Control

## Paket servis çağrısı. Telefon çalarken üstte sallanan bir bildirim çıkar
## (hangi ekranda olursan ol); dokununca ya da kasadaki telefona dokununca
## sipariş kartı açılır: müşteri, adres, ürünler, tutar, kuryelerin doluluğu.
## Onayla → mutfağa paket fişi düşer; Reddet → sipariş başka yere gider.
## Karar için süre sınırlı (çubuk azalır).

var shop: Shop
## Üst barın altı (güvenli alan dahil)
var top_offset := 120.0

var _banner: PanelContainer
var _banner_sub: Label
var _dim: ColorRect
var _card: PanelContainer
var _content: VBoxContainer
var _timer_bar: ProgressBar
var _timer_label: Label
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_banner()
	_build_card()
	shop.call_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if _banner.visible:
		_banner.position = Vector2((size.x - _banner.size.x) * 0.5, top_offset)
		_banner.rotation = deg_to_rad(2.2 * sin(_t * 30.0)) if fmod(_t, 2.0) < 0.9 else 0.0
		if not shop.call.is_empty():
			_banner_sub.text = "%s arıyor • %d sn" % [shop.call["name"], ceili(shop.call["time"])]
	if _card.visible and not shop.call.is_empty():
		var left: float = shop.call["time"]
		_timer_bar.value = left / Shop.DECIDE_TIME
		_timer_label.text = "%d sn" % ceili(left)


func _refresh() -> void:
	var ringing: bool = not shop.call.is_empty() and not shop.call["open"]
	var open: bool = not shop.call.is_empty() and shop.call["open"]
	_banner.visible = ringing
	_banner.pivot_offset = _banner.size * 0.5
	_dim.visible = open
	_card.visible = open
	if open:
		_fill_card()
		_card.scale = Vector2(0.9, 0.9)
		_card.pivot_offset = _card.size * 0.5
		_card.create_tween().tween_property(_card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_banner() -> void:
	_banner = PanelContainer.new()
	var style := UiKit.flat(UiKit.PURPLE, 26, 14)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	_banner.add_theme_stylebox_override("panel", style)
	_banner.custom_minimum_size = Vector2(560, 0)
	add_child(_banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_banner.add_child(row)
	row.add_child(UiKit.badge_rect("smartphone", UiKit.ORANGE, 56))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", -4)
	row.add_child(texts)
	texts.add_child(UiKit.label("Paket sipariş geliyor!", 26, Color.WHITE, 900))
	_banner_sub = UiKit.label("", 19, Color("#e6defd"))
	texts.add_child(_banner_sub)
	var answer := Button.new()
	answer.text = "Aç"
	answer.custom_minimum_size = Vector2(110, 60)
	answer.add_theme_font_size_override("font_size", 24)
	UiKit.set_icon(answer, "smartphone", 26)
	UiKit.candy(answer, UiKit.GREEN, Color.WHITE)
	answer.pressed.connect(shop.answer_call)
	row.add_child(answer)


func _build_card() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.08, 0.05, 0.03, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(center)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(620, 0)
	center.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_card.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(UiKit.badge_rect("smartphone", UiKit.PURPLE, 56))
	var title := UiKit.label("Paket Sipariş", 34, UiKit.TEXT, 900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.icon_rect("timer", UiKit.MUTED, 26))
	_timer_label = UiKit.label("", 24, UiKit.MUTED, 900)
	head.add_child(_timer_label)

	_timer_bar = ProgressBar.new()
	_timer_bar.max_value = 1.0
	_timer_bar.step = 0.001
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 10)
	_timer_bar.add_theme_stylebox_override("fill", UiKit.flat(UiKit.PURPLE, 6, 0))
	_timer_bar.add_theme_stylebox_override("background", UiKit.flat(UiKit.NEUTRAL, 6, 0))
	v.add_child(_timer_bar)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	v.add_child(_content)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	v.add_child(actions)
	var reject := Button.new()
	reject.text = "Reddet"
	reject.custom_minimum_size = Vector2(0, 72)
	reject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reject.add_theme_font_size_override("font_size", 26)
	UiKit.set_icon(reject, "x", 28)
	UiKit.candy(reject, UiKit.RED, Color.WHITE)
	reject.pressed.connect(func() -> void: shop.reject_call())
	actions.add_child(reject)
	var accept := Button.new()
	accept.text = "Onayla"
	accept.custom_minimum_size = Vector2(0, 72)
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.size_flags_stretch_ratio = 1.4
	accept.add_theme_font_size_override("font_size", 26)
	UiKit.set_icon(accept, "check", 28)
	UiKit.candy(accept, UiKit.GREEN, Color.WHITE)
	accept.pressed.connect(shop.accept_call)
	actions.add_child(accept)


func _fill_card() -> void:
	for child in _content.get_children():
		child.queue_free()
	var call: Dictionary = shop.call
	# Müşteri ve adres
	var who := PanelContainer.new()
	who.add_theme_stylebox_override("panel", UiKit.card_style(UiKit.CARD, 18))
	_content.add_child(who)
	var who_row := HBoxContainer.new()
	who_row.add_theme_constant_override("separation", 12)
	who.add_child(who_row)
	who_row.add_child(UiKit.icon_rect("house", UiKit.ORANGE, 34))
	var who_text := VBoxContainer.new()
	who_text.add_theme_constant_override("separation", -4)
	who_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who_row.add_child(who_text)
	who_text.add_child(UiKit.label(call["name"], 26, UiKit.TEXT, 900))
	who_text.add_child(UiKit.label("%s • %.1f km" % [call["address"], call["km"]], 20, UiKit.MUTED))

	# Ürünler
	var items: Dictionary = call["items"]
	for id in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_content.add_child(row)
		row.add_child(UiKit.food_rect(id, 44))
		var name_l := UiKit.label("%d× %s" % [int(items[id]), Items.display_name(id)], 23, UiKit.TEXT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		row.add_child(UiKit.label("₺%d" % (Items.price(id) * int(items[id])), 23, UiKit.TEXT, 900))
	var total := HBoxContainer.new()
	_content.add_child(total)
	var total_l := UiKit.label("Toplam (kapıda ödeme)", 22, UiKit.MUTED)
	total_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(total_l)
	total.add_child(UiKit.label("₺%d" % call["price"], 30, UiKit.GREEN, 900))

	# Kuryelerin durumu: kaç paket bekliyor, kaç kurye dükkanda
	var load := shop.delivery_load()
	var home := shop.couriers.filter(func(c: Courier) -> bool: return c.state == Courier.State.WAITING).size()
	var info := PanelContainer.new()
	var color := UiKit.GREEN if load < 0.5 else (UiKit.YELLOW if load < 0.85 else UiKit.RED)
	var info_style := UiKit.flat(color.lightened(0.75), 14, 10)
	info.add_theme_stylebox_override("panel", info_style)
	_content.add_child(info)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 10)
	info.add_child(info_row)
	info_row.add_child(UiKit.icon_rect("package", color.darkened(0.2), 28))
	var text := "Kurye yükü %%%d • %d/%d kurye dükkanda" % [roundi(minf(load, 1.0) * 100.0), home, shop.couriers.size()]
	var info_l := UiKit.label(text, 20, color.darkened(0.35), 900)
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(info_l)
