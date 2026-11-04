class_name Hud
extends CanvasLayer

## Tüm arayüz: üst bar, alt menü, ekranlara özel paneller, müşteri sipariş
## kartları, pişme göstergeleri, bildirimler ve yorumlar penceresi.

const C_TEXT := UiKit.TEXT
const C_MUTED := UiKit.MUTED
const C_ORANGE := UiKit.ORANGE
const C_GREEN := UiKit.GREEN
const C_CREAM := UiKit.CARD
const NAV_TEXT := ["Market", "Dükkan", "Mutfak"]
const NAV_ICONS := ["shopping-cart", "store", "chef-hat"]
const BOTTOM_MARGIN := 24.0
const NAV_HEIGHT := 92.0

var main: Main

var _root: Control
var _portraits := PortraitStudio.new()
var _calendar: CalendarUI
var _delivery_call: DeliveryCallUI
## kurye -> başının üstündeki kart
var _courier_cards := {}
var _phone_badge: Button
var _order_entry: OrderEntry
var _pos_backdrop: ColorRect
## Mutfak kamera açısı düğmeleri: açı -> buton
var _view_buttons := {}
## Dükkan panelindeki sayaçlar: sırada / hazırlanıyor / hazır
var _sum_queue: Label
var _sum_cooking: Label
var _sum_ready: Label
var _world_ui: Control
var _money: Label
var _rating_btn: Button
var _nav: Array[Button] = []
var _panels: Array[Control] = []
var _cards := {}
var _gauges: Array[CookGauge] = []
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _market_stock := {}
## Borsa kartları: ürün -> etiket ve düğmeler
var _market_refs := {}
## Menü fiyat satırları: ürün -> etiketler
var _menu_refs := {}
var _tolerance_label: Label
var _kitchen_buttons := {}
var _ready_labels: Array[Dictionary] = []
var _reviews_overlay: Control
var _reviews_list: VBoxContainer
var _reviews_title: Label
var _bar_styles: Array[StyleBoxFlat] = []
var _payment: PaymentPanel
var _money_value := 0.0
var _money_tween: Tween
var _fx: Control
var _level_label: Label
var _xp_bar: ProgressBar
var _market_tabs: Array[Button] = []
var _market_pages: Array[Control] = []
var _upgrade_rows := {}
var _staff_list: VBoxContainer
var _nav_row: HBoxContainer
var _sky_icon: TextureRect
var _sky_name := ""
var _nav_kitchen_icon := ""
var _setup: SetupUI
var _tutorial: TutorialUI
var _settings: SettingsUI
var _pause_overlay: ColorRect
## sipariş numarası -> teslim bekleyen müşterinin kartı
var _pickup_cards := {}


func setup(m: Main) -> void:
	main = m


func _ready() -> void:
	# Oyun durdurulunca da arayüz çalışsın (Devam Et butonu vb.).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Yiyecek ikonları 3D modellerden çekilir; paneller kurulmadan önce hazır olmalı.
	add_child(FoodStudio.new())
	# Personel kartlarındaki yüzler de 3D modelden çekilir.
	add_child(_portraits)
	# Sonradan eklenenler dahil tüm butonlara basma animasyonu ve tık sesi.
	get_tree().node_added.connect(_on_node_added)
	# 3D'nin üstündeki göstergeler (pişme çubukları) ekranın tamamına göre konur;
	# arayüzün geri kalanı telefonun güvenli alanının (çentik, ev çubuğu) içinde kalır.
	_world_ui = Control.new()
	_world_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_ui.theme = _make_theme()
	add_child(_world_ui)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _world_ui.theme
	add_child(_root)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

	_bar_styles = [Util.style(Color("#e05555"), 6, 0), Util.style(Color("#f0a540"), 6, 0), Util.style(C_GREEN, 6, 0)]

	_build_top_bar()
	_panels = [_build_market_panel(), _build_shop_panel(), _build_kitchen_panel()]
	_build_nav()
	if not GameState.setup_done:
		_setup = SetupUI.new()
		_root.add_child(_setup)
	# Paket servis çağrısı: üstte bildirim, açılınca onay/ret kartı.
	_delivery_call = DeliveryCallUI.new()
	_delivery_call.shop = main.shop
	_delivery_call.top_offset = 112.0
	_root.add_child(_delivery_call)
	_build_toast()
	# Kasa ekranı açıkken arka plan bulanıklaşır (üst bar ve alt menü net kalır).
	_pos_backdrop = OrderEntry.backdrop()
	_pos_backdrop.modulate.a = 0.0
	_pos_backdrop.visible = false
	_root.add_child(_pos_backdrop)
	_root.move_child(_pos_backdrop, 0)
	_order_entry = OrderEntry.new()
	_root.add_child(_order_entry)
	_order_entry.confirmed.connect(func(c: ShopCustomer) -> void: main.shop.take_order(c))
	_order_entry.cancelled.connect(func(_c: ShopCustomer) -> void: main.focus_register(false))
	main.shop.order_requested.connect(_open_order_entry)
	_payment = PaymentPanel.new()
	_root.add_child(_payment)
	_build_reviews()
	# Uçan paralar ve satış yazıları en üstte
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fx)
	for slot in main.kitchen.slots:
		_add_gauge(slot)
	main.kitchen.slot_added.connect(_add_gauge)

	GameState.money_changed.connect(_animate_money)
	main.shop.payment_requested.connect(_payment.open)
	main.shop.payment_requested.connect(_on_payment_started)
	_payment.card_swiped.connect(main.shop.register.card_ok)
	_payment.completed.connect(_on_payment_finished)
	main.shop.sale_completed.connect(_on_sale)
	_payment.completed.connect(main.shop.complete_payment)
	GameState.stock_changed.connect(_refresh_stock)
	GameState.prepared_changed.connect(_refresh_stock)
	GameState.reviews_changed.connect(_refresh_reviews)
	GameState.toast_requested.connect(show_toast)
	main.shop.customer_added.connect(_add_card)
	main.shop.customer_removed.connect(_remove_card)
	main.shop.order_placed.connect(_add_pickup_card)
	main.shop.orders_changed.connect(_sync_pickup_cards)
	main.shop.order_delivered.connect(_on_delivered)
	main.shop.couriers_changed.connect(_refresh_staff)
	main.screen_changed.connect(_on_screen_changed)
	GameState.xp_changed.connect(_refresh_level)
	GameState.level_up.connect(_on_level_up)
	GameState.upgrades_changed.connect(_refresh_upgrades)
	GameState.staff_changed.connect(_refresh_staff)
	GameState.setup_finished.connect(_on_setup_finished)
	GameState.tutorial_changed.connect(_on_tutorial_changed)
	GameState.day_ended.connect(_on_day_ended)
	GameState.day_started.connect(func(_d: int) -> void: _refresh_staff())
	GameState.money_changed.connect(func(_v: int) -> void: _refresh_upgrades())

	_money_value = GameState.money
	_set_money_text(_money_value)
	_refresh_stock()
	_refresh_reviews()
	_refresh_level()
	_refresh_upgrades()
	_refresh_staff()
	_on_screen_changed(main.screen)


func _process(_delta: float) -> void:
	_avoid_keyboard()
	_refresh_summary()
	_place_pos_screen()
	var on_shop := main.screen == Main.SHOP and not main.transitioning and not main.register_focus
	var on_kitchen := main.screen == Main.KITCHEN and not main.transitioning

	for customer in _cards:
		_update_card(customer, _cards[customer], on_shop)
	for order in main.shop.orders:
		if _pickup_cards.has(order["number"]):
			_update_pickup_card(order, _pickup_cards[order["number"]], on_shop)
	_update_courier_cards(on_shop)
	_update_phone_badge(on_shop)
	var waiting := main.shop.waiting_count()

	var cooked := false
	for gauge in _gauges:
		gauge.visible = on_kitchen and not gauge.slot.is_empty()
		if not gauge.slot.is_empty() and gauge.slot.doneness() >= Items.UNDER_LIMIT:
			cooked = true
		if gauge.visible:
			var p := main.camera.unproject_position(gauge.slot.global_position + Vector3(0, 0.3, 0))
			gauge.position = p - Vector2(CookGauge.W * 0.5, CookGauge.H)

	_set_text(_nav[Main.SHOP], NAV_TEXT[Main.SHOP] + (" (%d)" % waiting if waiting > 0 else ""))
	# Pişen bir şey varsa mutfak ikonu aleve döner.
	var open_orders := main.shop.open_order_count()
	_set_text(_nav[Main.KITCHEN], NAV_TEXT[Main.KITCHEN] + (" (%d)" % open_orders if open_orders > 0 else ""))
	var kitchen_icon := "flame" if cooked else NAV_ICONS[Main.KITCHEN]
	if _nav_kitchen_icon != kitchen_icon:
		_nav_kitchen_icon = kitchen_icon
		UiKit.set_icon(_nav[Main.KITCHEN], kitchen_icon, 36, true)

	# Seviye, gün ve saat
	var sky := "sun"
	var sky_color := UiKit.YELLOW
	if not GameState.is_open or GameState.minutes >= GameState.LAST_ORDER:
		sky = "moon"
		sky_color = UiKit.PURPLE
	elif GameState.minutes >= 18 * 60:
		sky = "sunset"
		sky_color = UiKit.ORANGE
	if _sky_name != sky:
		_sky_name = sky
		_sky_icon.texture = Icons.tex(sky, 48)
		_sky_icon.modulate = sky_color
	var clock := "Sv%d • G%d • %s" % [GameState.level, GameState.day, GameState.clock_text()]
	if _level_label.text != clock:
		_level_label.text = clock


func show_toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)


# --- Kurulum -----------------------------------------------------------------

func _make_theme() -> Theme:
	return UiKit.make_theme()


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 20
	bar.offset_right = -20
	bar.offset_top = 24
	bar.offset_bottom = 24
	_root.add_child(bar)

	var row := HBoxContainer.new()
	bar.add_child(row)
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.badge_rect("coins", UiKit.YELLOW, 42))
	_money = Label.new()
	_money.add_theme_font_size_override("font_size", 34)
	_money.add_theme_font_override("font", UiKit.font(900))
	row.add_child(_money)

	# Ortada seviye ve deneyim çubuğu
	var level_box := VBoxContainer.new()
	level_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_box.alignment = BoxContainer.ALIGNMENT_CENTER
	level_box.add_theme_constant_override("separation", 4)
	row.add_child(level_box)
	var clock_row := HBoxContainer.new()
	clock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_row.add_theme_constant_override("separation", 6)
	level_box.add_child(clock_row)
	_sky_icon = UiKit.icon_rect("sun", UiKit.YELLOW, 24)
	clock_row.add_child(_sky_icon)
	_level_label = Label.new()
	_level_label.add_theme_color_override("font_color", C_MUTED)
	_level_label.add_theme_font_size_override("font_size", 18)
	clock_row.add_child(_level_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(130, 10)
	_xp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_xp_bar.add_theme_stylebox_override("fill", UiKit.flat(UiKit.PURPLE, 8, 0))
	level_box.add_child(_xp_bar)

	var calendar := Button.new()
	calendar.custom_minimum_size = Vector2(56, 0)
	UiKit.set_icon(calendar, "calendar-days", 30)
	UiKit.candy(calendar, UiKit.NEUTRAL, UiKit.TEXT)
	calendar.pressed.connect(open_calendar)
	row.add_child(calendar)

	var pause := Button.new()
	pause.custom_minimum_size = Vector2(56, 0)
	UiKit.set_icon(pause, "pause", 30)
	UiKit.candy(pause, UiKit.NEUTRAL, UiKit.TEXT)
	pause.pressed.connect(set_paused.bind(true))
	row.add_child(pause)

	var gear := Button.new()
	gear.custom_minimum_size = Vector2(56, 0)
	UiKit.set_icon(gear, "settings", 30)
	UiKit.candy(gear, UiKit.NEUTRAL, UiKit.TEXT)
	gear.pressed.connect(open_settings)
	row.add_child(gear)

	_rating_btn = Button.new()
	_rating_btn.add_theme_font_size_override("font_size", 24)
	UiKit.set_icon(_rating_btn, "star", 30)
	_style_button(_rating_btn, UiKit.YELLOW, C_TEXT)
	_rating_btn.pressed.connect(func() -> void: _reviews_overlay.visible = true)
	row.add_child(_rating_btn)


func _build_nav() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 20
	row.offset_right = -20
	row.offset_top = -BOTTOM_MARGIN
	row.offset_bottom = -BOTTOM_MARGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.add_theme_constant_override("separation", 12)
	_root.add_child(row)
	_nav_row = row
	for i in NAV_TEXT.size():
		var btn := Button.new()
		btn.text = NAV_TEXT[i]
		btn.custom_minimum_size = Vector2(0, NAV_HEIGHT)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 22)
		UiKit.set_icon(btn, NAV_ICONS[i], 36, true)
		btn.pressed.connect(main.go_to.bind(i))
		row.add_child(btn)
		_nav.append(btn)


## Alt menünün hemen üstünde duran, içeriğe göre yukarı doğru büyüyen panel.
func _bottom_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 20
	panel.offset_right = -20
	panel.offset_top = -(BOTTOM_MARGIN + NAV_HEIGHT + 16)
	panel.offset_bottom = panel.offset_top
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(panel)
	return panel


func _build_market_panel() -> Control:
	var panel := _bottom_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	box.add_child(tabs)
	for i in 4:
		var tab := Button.new()
		tab.text = ["Malzeme", "Menü", "Geliştir", "Personel"][i]
		UiKit.set_icon(tab, ["package", "utensils", "circle-arrow-up", "users"][i], 24)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 64)
		tab.add_theme_font_size_override("font_size", 20)
		tab.pressed.connect(_show_market_tab.bind(i))
		tabs.add_child(tab)
		_market_tabs.append(tab)

	_market_pages = [_build_supplies_page(), _build_menu_page(), _build_upgrades_page(), _build_staff_page()]
	GameState.market_changed.connect(_refresh_market)
	GameState.stock_changed.connect(_refresh_market)
	GameState.day_started.connect(func(_d: int) -> void: _refresh_market())
	GameState.reviews_changed.connect(_refresh_market)
	_refresh_market()
	GameState.level_up.connect(func(_l: int) -> void: _refresh_unlocks())
	_refresh_unlocks.call_deferred()
	for page in _market_pages:
		box.add_child(page)
	_show_market_tab(0)
	return panel


## Personel sekmesi: çalışanlar (maaş, çıkar) ve günün adayları (işe al, pazarlık).
func _build_staff_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(_heading("Personel", "Garson masaları temizler, kurye paket götürür • maaş gün sonunda"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_staff_list = VBoxContainer.new()
	_staff_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_staff_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_staff_list)
	return box


func _refresh_staff() -> void:
	if _staff_list == null:
		return
	for child in _staff_list.get_children():
		child.queue_free()

	var max_total := 0
	for job in Staff.ROLES:
		if GameState.level >= int(Staff.ROLES[job]["unlock"]):
			max_total += int(Staff.ROLES[job]["max"])
	_staff_list.add_child(_section_label("Çalışanların (%d/%d)" % [GameState.staff.size(), max_total]))
	if GameState.staff.is_empty():
		_staff_list.add_child(_muted_label("Henüz çalışanın yok. Masaları kendin temizlemelisin."))
	for i in GameState.staff.size():
		var person: Dictionary = GameState.staff[i]
		var fire := _small_button("Çıkar", Color("#d9d0c9"), C_TEXT)
		fire.pressed.connect(func() -> void:
			GameState.fire(i)
			show_toast("%s işten çıkarıldı" % person["name"])
		)
		var wage_text := "₺%d / gün" % person["wage"]
		if Staff.role(person) == "kurye":
			for courier in main.shop.couriers:
				if is_same(courier.data, person):
					wage_text += " • " + courier.status_text()
		_staff_list.add_child(_person_row("chef-hat", person, wage_text, [fire]))
	if GameState.level < int(Staff.ROLES["kurye"]["unlock"]):
		_staff_list.add_child(_muted_label("Kurye Seviye %d'de açılır: paket servis telefonu çalmaya başlar." % Staff.ROLES["kurye"]["unlock"]))
	elif Staff.count(GameState.staff, "kurye") == 0:
		_staff_list.add_child(_muted_label("Kurye alırsan kasadaki telefona paket siparişleri gelir."))

	_staff_list.add_child(_section_label("Bugünün adayları"))
	if GameState.candidates.is_empty():
		_staff_list.add_child(_muted_label("Yarın yeni adaylar gelecek."))
	for i in GameState.candidates.size():
		var person: Dictionary = GameState.candidates[i]
		var buttons: Array[Button] = []
		var hire := _small_button("İşe Al ₺%d" % person["wage"], C_GREEN, Color.WHITE)
		hire.pressed.connect(func() -> void:
			if GameState.hire(i):
				Sfx.play("approve")
				show_toast("%s işe başladı!" % person["name"])
		)
		buttons.append(hire)
		if not person["haggled"]:
			var haggle := _small_button("Pazarlık ₺%d" % Staff.haggle_offer(person), C_ORANGE, Color.WHITE)
			haggle.pressed.connect(func() -> void:
				var who: String = person["name"]
				if GameState.haggle(i):
					Sfx.play("coin")
					show_toast("%s kabul etti: ₺%d / gün" % [who, person["wage"]])
				else:
					Sfx.play("error")
					show_toast("%s teklifini beğenmedi" % who)
			)
			buttons.append(haggle)
		_staff_list.add_child(_person_row("user-plus", person, "İstediği: ₺%d / gün" % person["wage"], buttons))


## Kişinin yüz portresi, renkli yuvarlak köşeli bir çerçevede.
func _portrait_frame(person: Dictionary, color: Color) -> Control:
	var frame := PanelContainer.new()
	var style := UiKit.card_style()
	style.bg_color = color.lightened(0.55)
	style.set_corner_radius_all(18)
	style.border_color = color
	style.set_border_width_all(3)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 0
	frame.add_theme_stylebox_override("panel", style)
	var face := TextureRect.new()
	face.texture = _portraits.portrait(person)
	face.custom_minimum_size = Vector2(84, 84)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(face)
	return frame


func _person_row(icon: String, person: Dictionary, wage_text: String, buttons: Array[Button]) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiKit.card_style())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	row.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	h.add_child(_portrait_frame(person, UiKit.BLUE if icon == "chef-hat" else UiKit.PURPLE))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	h.add_child(info)
	var name_l := Label.new()
	name_l.text = person["name"]
	name_l.add_theme_font_size_override("font_size", 26)
	info.add_child(name_l)
	var traits := Label.new()
	traits.text = "%s • %s" % [Staff.role_name(person), Staff.traits(person)]
	traits.add_theme_color_override("font_color", Color("#8a6cf0"))
	traits.add_theme_font_size_override("font_size", 20)
	info.add_child(traits)
	var wage := Label.new()
	wage.text = wage_text
	wage.add_theme_color_override("font_color", C_MUTED)
	wage.add_theme_font_size_override("font_size", 20)
	info.add_child(wage)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	v.add_child(actions)
	for btn in buttons:
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(btn)
	return row


func _small_button(text: String, bg: Color, fg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 60)
	btn.add_theme_font_size_override("font_size", 22)
	_style_button(btn, bg, fg)
	return btn


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	return l


func _muted_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", C_MUTED)
	l.add_theme_font_size_override("font_size", 21)
	return l


## Gün sonu: ortada gecenin özeti, "Yeni Güne Başla" ile sabah olur.
func _on_day_ended(stats: Dictionary) -> void:
	Sfx.play("day_end")
	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.04, 0.12, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := Label.new()
	title.text = "%d. Gün Bitti" % GameState.day
	var moon := UiKit.badge_rect("moon", UiKit.PURPLE, 84)
	moon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(moon)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	v.add_child(title)
	var expenses: int = stats["supplies"] + stats["upgrades"] + stats["wages"]
	var net: int = stats["revenue"] + stats["tips"] - expenses
	var lines := [
		["smile", "Servis edilen müşteri", "%d" % stats["served"], C_TEXT],
		["angry", "Kaçan müşteri", "%d" % stats["lost"], UiKit.RED if stats["lost"] > 0 else C_TEXT],
		["coins", "Satış", "+₺%d" % stats["revenue"], C_GREEN],
		["heart", "Bahşiş", "+₺%d" % stats["tips"], C_GREEN],
		["package", "Malzeme", "-₺%d" % stats["supplies"], C_TEXT],
		["circle-arrow-up", "Geliştirme", "-₺%d" % stats["upgrades"], C_TEXT],
		["users", "Maaşlar", "-₺%d" % stats["wages"], C_TEXT],
	]
	for line in lines:
		v.add_child(_summary_row(line[1], line[2], line[3], 26, line[0]))
	v.add_child(HSeparator.new())
	v.add_child(_summary_row("Günün sonucu", "%s₺%d" % ["+" if net >= 0 else "-", absi(net)], C_GREEN if net >= 0 else Color("#e05555"), 32))
	v.add_child(_summary_row("Kasadaki para", "₺%d" % stats["money"], C_TEXT, 26))
	var quitters: Array = stats.get("quitters", [])
	if not quitters.is_empty():
		v.add_child(_muted_label("Maaşı ödenemediği için ayrılanlar: " + ", ".join(quitters)))

	var start := Button.new()
	start.text = "Yeni Güne Başla"
	UiKit.set_icon(start, "sun", 36)
	start.custom_minimum_size = Vector2(0, 90)
	start.add_theme_font_size_override("font_size", 32)
	_style_button(start, C_ORANGE, Color.WHITE)
	start.pressed.connect(func() -> void:
		overlay.queue_free()
		GameState.start_day()
		Sfx.play("approve")
	)
	v.add_child(start)
	Sfx.play("drawer")

	panel.pivot_offset = Vector2(310, 300)
	panel.scale = Vector2(0.85, 0.85)
	overlay.modulate.a = 0.0
	var tween := overlay.create_tween().set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.4)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _summary_row(left: String, right: String, color: Color, size: int, icon := "") -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	if icon != "":
		h.add_child(UiKit.icon_rect(icon, C_MUTED, 30))
	var l := Label.new()
	l.text = left
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", size)
	h.add_child(l)
	var r := Label.new()
	r.text = right
	r.add_theme_color_override("font_color", color)
	r.add_theme_font_size_override("font_size", size)
	h.add_child(r)
	return h


func _show_market_tab(index: int) -> void:
	for i in _market_tabs.size():
		_market_pages[i].visible = i == index
		if i == index:
			_style_button(_market_tabs[i], C_TEXT, Color.WHITE)
		else:
			_style_button(_market_tabs[i], Color("#efe6dd"), C_TEXT)


## Toptancı borsası: fiyatlar gün içinde değişir (ok ve yüzde), arada fırsat çıkar.
## Her kartta stok, tarihi geçenler ve en yakın son kullanma günü yazar.
func _build_supplies_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_heading("Toptancı Borsası", "Fiyatlar 12:00, 15:00, 18:00 ve her sabah değişir"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for id in Items.PRODUCTS:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiKit.card_style())
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)

		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		v.add_child(top)
		top.add_child(UiKit.food_rect(id, 56))
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", -2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(info)
		info.add_child(UiKit.label(Items.display_name(id), 21, UiKit.TEXT, 900))
		var stock_l := UiKit.label("", 17, C_MUTED)
		info.add_child(stock_l)
		var expiry_l := UiKit.label("", 15, C_MUTED)
		info.add_child(expiry_l)

		# Borsa: güncel paket fiyatı, son değişim ve fırsat etiketi
		var price_row := HBoxContainer.new()
		price_row.add_theme_constant_override("separation", 6)
		v.add_child(price_row)
		var price_l := UiKit.label("", 26, UiKit.TEXT, 900)
		price_row.add_child(price_l)
		var trend_l := UiKit.label("", 17, C_MUTED, 900)
		trend_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		price_row.add_child(trend_l)
		var deal := PanelContainer.new()
		price_row.add_child(deal)
		var deal_l := UiKit.label("", 13, Color.WHITE, 900)
		deal.add_child(deal_l)

		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		v.add_child(actions)
		var buy := Button.new()
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy.add_theme_font_size_override("font_size", 20)
		UiKit.set_icon(buy, "shopping-cart", 24)
		_style_button(buy, C_GREEN, Color.WHITE)
		buy.pressed.connect(_buy.bind(id))
		actions.add_child(buy)
		var toss := Button.new()
		toss.text = "At"
		toss.add_theme_font_size_override("font_size", 18)
		UiKit.set_icon(toss, "trash-2", 22)
		_style_button(toss, UiKit.RED, Color.WHITE)
		toss.pressed.connect(func() -> void:
			var n := GameState.discard_expired(id)
			if n > 0:
				Sfx.play("pop")
				show_toast("%d bozuk %s çöpe atıldı" % [n, Items.display_name(id)])
		)
		actions.add_child(toss)
		_market_stock[id] = stock_l
		_market_refs[id] = { "card": card, "stock": stock_l, "expiry": expiry_l, "price": price_l, "trend": trend_l, "deal": deal, "deal_label": deal_l, "buy": buy, "toss": toss }
	return box


## Menü fiyatları: her ürünün satış fiyatı ayarlanır. Pahalı olursa müşteri azalır
## ve puan düşer, ucuz olursa kalabalık olur. İtibar arttıkça müşteri daha yüksek
## fiyata razı olur.
func _build_menu_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_heading("Menü Fiyatları", "Pahalıysa müşteri azalır, ucuzsa kalabalık olur"))
	_tolerance_label = UiKit.label("", 19, UiKit.PURPLE, 900)
	_tolerance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_tolerance_label)
	for id in Items.PRODUCTS:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiKit.card_style())
		box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		row.add_child(UiKit.food_rect(id, 52))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		var name_row := HBoxContainer.new()
		info.add_child(name_row)
		var name_l := UiKit.label(Items.display_name(id), 21, UiKit.TEXT, 900)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(name_l)
		var interest_l := UiKit.label("", 16, C_MUTED, 900)
		name_row.add_child(interest_l)
		var profit_l := UiKit.label("", 16, C_MUTED)
		info.add_child(profit_l)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.step = 0.01
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		info.add_child(bar)
		var minus := Button.new()
		UiKit.set_icon(minus, "minus", 26)
		minus.custom_minimum_size = Vector2(60, 60)
		_style_button(minus, Color("#efe6dd"), C_TEXT)
		minus.pressed.connect(_change_price.bind(id, -0.1))
		row.add_child(minus)
		var price_l := UiKit.label("", 28, UiKit.TEXT, 900)
		price_l.custom_minimum_size = Vector2(76, 0)
		price_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(price_l)
		var plus := Button.new()
		UiKit.set_icon(plus, "plus", 26)
		plus.custom_minimum_size = Vector2(60, 60)
		_style_button(plus, Color("#efe6dd"), C_TEXT)
		plus.pressed.connect(_change_price.bind(id, 0.1))
		row.add_child(plus)
		_menu_refs[id] = { "card": card, "price": price_l, "profit": profit_l, "interest": interest_l, "bar": bar }
	return box


## Kilitli ürünler mutfakta, markette ve menüde görünmez; seviye atlayınca açılır.
func _refresh_unlocks() -> void:
	_filter_kitchen_cards()
	for id in _market_refs:
		(_market_refs[id]["card"] as Control).visible = Items.unlocked(id)
	for id in _menu_refs:
		(_menu_refs[id]["card"] as Control).visible = Items.unlocked(id)
	_refresh_market()


func _change_price(id: String, step: float) -> void:
	GameState.set_price_factor(id, float(GameState.price_factors.get(id, 1.0)) + step)
	Sfx.play("beep", 0.05)


## Borsa ve menü kartlarını günceller.
func _refresh_market() -> void:
	for id in _market_refs:
		var refs: Dictionary = _market_refs[id]
		var entry: Dictionary = GameState.market[id]
		var expired := GameState.expired_count(id)
		var fresh: int = GameState.stock[id] - expired
		(refs["stock"] as Label).text = "%d taze" % fresh + ("  •  %d bozuk" % expired if expired > 0 else "")
		(refs["stock"] as Label).add_theme_color_override("font_color", UiKit.RED if expired > 0 else C_MUTED)
		var next := GameState.next_expiry(id)
		(refs["expiry"] as Label).text = "" if next < 0 else ("SKT: bugün" if next == GameState.day else "SKT: %d gün" % (next - GameState.day))
		(refs["price"] as Label).text = "₺%d" % GameState.pack_price(id)
		var change := Exchange.change_percent(entry)
		var trend: Label = refs["trend"]
		trend.text = "▲ %%%d" % change if change > 0 else ("▼ %%%d" % -change if change < 0 else "–")
		# Alıcı için fiyatın düşmesi iyi (yeşil), artması kötü (kırmızı)
		trend.add_theme_color_override("font_color", UiKit.RED if change > 0 else (UiKit.GREEN if change < 0 else C_MUTED))
		var deal: String = entry["deal"]
		(refs["deal"] as Control).visible = deal != ""
		if deal != "":
			var color := UiKit.RED if deal == "zam" else (UiKit.ORANGE if deal == "skt" else UiKit.GREEN)
			(refs["deal"] as PanelContainer).add_theme_stylebox_override("panel", UiKit.flat(color, 8, 4))
			(refs["deal_label"] as Label).text = Exchange.DEALS[deal][0]
		(refs["buy"] as Button).text = "+%d   ₺%d" % [Items.PACK_SIZE, GameState.pack_price(id)]
		(refs["toss"] as Button).visible = expired > 0
	var tolerance := Progression.price_tolerance()
	if _tolerance_label:
		_tolerance_label.text = "Makul fiyat sınırı: %%%d (puan ve dekorla artar)  •  Müşteri akışı: %%%d" % [
			roundi(tolerance * 100.0), roundi(100.0 / Progression.price_demand())]
	for id in _menu_refs:
		var refs: Dictionary = _menu_refs[id]
		var price := Items.price(id)
		var base: int = Items.PRODUCTS[id]["price"]
		(refs["price"] as Label).text = "₺%d" % price
		var cost := float(GameState.pack_price(id)) / Items.PACK_SIZE
		(refs["profit"] as Label).text = "Taban ₺%d  •  Maliyet ₺%.1f  •  Kâr ₺%.1f" % [base, cost, price - cost]
		var ratio := Progression.price_ratio(id)
		var interest := "Yüksek ilgi"
		var color := UiKit.GREEN
		if ratio > 1.4:
			interest = "Çok pahalı"
			color = UiKit.RED
		elif ratio > 1.15:
			interest = "Düşük ilgi"
			color = UiKit.ORANGE
		elif ratio > 0.9:
			interest = "Normal"
			color = UiKit.YELLOW
		(refs["interest"] as Label).text = interest
		(refs["interest"] as Label).add_theme_color_override("font_color", color.darkened(0.15))
		var bar: ProgressBar = refs["bar"]
		bar.value = clampf(1.6 - ratio, 0.05, 1.0)
		bar.add_theme_stylebox_override("fill", UiKit.flat(color, 5, 0))


func _build_upgrades_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(_heading("Geliştirmeler", "Seviye atladıkça yenileri açılır"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	for id in Progression.UPGRADES:
		var data: Dictionary = Progression.UPGRADES[id]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.card_style())
		list.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		h.add_child(UiKit.badge_rect(data["icon"], UiKit.ORANGE, 60))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		h.add_child(info)
		var name_l := Label.new()
		name_l.text = data["name"]
		name_l.add_theme_font_size_override("font_size", 26)
		info.add_child(name_l)
		var desc := Label.new()
		desc.text = data["desc"]
		desc.add_theme_color_override("font_color", C_MUTED)
		desc.add_theme_font_size_override("font_size", 20)
		info.add_child(desc)
		var tier := Label.new()
		tier.add_theme_color_override("font_color", Color("#8a6cf0"))
		tier.add_theme_font_size_override("font_size", 20)
		info.add_child(tier)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 72)
		btn.add_theme_font_size_override("font_size", 26)
		btn.pressed.connect(_buy_upgrade.bind(id))
		h.add_child(btn)
		_upgrade_rows[id] = { "button": btn, "tier": tier }
	return box


func _buy_upgrade(id: String) -> void:
	if GameState.buy_upgrade(id):
		Sfx.play("kaching")
		show_toast("%s alındı!" % Progression.UPGRADES[id]["name"])


func _refresh_upgrades() -> void:
	for id in _upgrade_rows:
		var btn: Button = _upgrade_rows[id]["button"]
		var tier: Label = _upgrade_rows[id]["tier"]
		var current := GameState.upgrade_level(id)
		var max_tier := Progression.upgrade_max(id)
		tier.text = "Kademe %d / %d" % [current, max_tier]
		if current >= max_tier:
			btn.text = "MAKS"
			UiKit.set_icon(btn, "check", 28)
			btn.disabled = true
			continue
		var needed := Progression.upgrade_required_level(id, current)
		if GameState.level < needed:
			btn.text = "Sv %d" % needed
			UiKit.set_icon(btn, "lock", 28)
			btn.disabled = true
			continue
		var cost := Progression.upgrade_cost(id, current)
		btn.text = "₺%d" % cost
		btn.icon = null
		btn.disabled = GameState.money < cost
		_style_button(btn, C_GREEN, Color.WHITE)


func _refresh_level() -> void:
	_xp_bar.max_value = Progression.xp_needed(GameState.level)
	_xp_bar.value = GameState.xp


## Seviye atlayınca ortada büyük bir kutlama ve açılan geliştirmeler.
func _on_level_up(level: int) -> void:
	Sfx.play("level_up")
	var card := PanelContainer.new()
	var level_style := UiKit.panel_style(32)
	level_style.bg_color = UiKit.PURPLE
	level_style.border_color = UiKit.PURPLE.darkened(0.25)
	level_style.border_width_bottom = 8
	card.add_theme_stylebox_override("panel", level_style)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	var title := Label.new()
	title.text = "SEVİYE %d" % level
	title.add_theme_font_override("font", UiKit.font(900))
	var badge := UiKit.badge_rect("party-popper", UiKit.YELLOW, 96)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(badge)
	v.move_child(badge, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color.WHITE)
	v.add_child(title)
	var sub := Label.new()
	var unlocks := Progression.unlocks_at(level)
	var products := Items.unlocking_at(level)
	sub.text = "Müşteriler artıyor, siparişler büyüyor!"
	if not products.is_empty():
		sub.text += "\nYeni ürün açıldı: " + ", ".join(products) + "\n(Marketten malzemesini al)"
	if not unlocks.is_empty():
		sub.text += "\nYeni geliştirme: " + ", ".join(unlocks)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(560, 0)
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color("#efe9ff"))
	v.add_child(sub)
	_fx.add_child(card)
	card.reset_size()
	card.position = Vector2(360, 470) - card.size * 0.5
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ZERO
	var tween := card.create_tween()
	tween.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.2)
	tween.tween_property(card, "modulate:a", 0.0, 0.4)
	tween.tween_callback(card.queue_free)
	_refresh_level()
	_refresh_upgrades()


func _add_gauge(slot: CookSlot) -> void:
	var gauge := CookGauge.new()
	gauge.slot = slot
	gauge.visible = false
	_world_ui.add_child(gauge)
	_gauges.append(gauge)


## Dükkan paneli: başlıkta sıra / hazırlanıyor / hazır sayaçları, altında fişler.
func _build_shop_panel() -> Control:
	var panel := _bottom_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var title := UiKit.label("Siparişler", 30, UiKit.TEXT, 900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_sum_queue = _summary_chip(head, "users", UiKit.BLUE)
	_sum_cooking = _summary_chip(head, "chef-hat", UiKit.ORANGE)
	_sum_ready = _summary_chip(head, "check", UiKit.GREEN)
	var strip := TicketStrip.new()
	strip.mode = TicketStrip.Mode.SHOP
	strip.shop = main.shop
	box.add_child(strip)
	return panel


func _build_kitchen_panel() -> Control:
	var panel := _bottom_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	# Başlık ve kamera açısı: genel / ızgara / fritöz
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var title := UiKit.label("Pişir", 30, UiKit.TEXT, 900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for view in [["", "layout-grid", "Genel"], ["izgara", "flame", "Izgara"], ["fritoz", "cooking-pot", "Fritöz"], ["firin", "house", "Fırın"]]:
		var b := Button.new()
		b.text = view[2]
		UiKit.set_icon(b, view[1], 22)
		b.add_theme_font_size_override("font_size", 18)
		b.custom_minimum_size = Vector2(0, 50)
		b.pressed.connect(main.kitchen_focus.bind(view[0]))
		head.add_child(b)
		_view_buttons[view[0]] = b
	main.kitchen_view_changed.connect(_refresh_view_buttons)
	_refresh_view_buttons("")
	box.add_child(UiKit.label("Kıvamı yeşildeyken ürüne dokun, sonra fişin tepsisine koy", 19, UiKit.MUTED))
	# Ürün kartları ekrana sığar; ürün çoğalırsa yana kaydırılır.
	var cards := ScrollContainer.new()
	cards.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	cards.custom_minimum_size = Vector2(0, 138)
	box.add_child(cards)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(row)
	for id in Items.PRODUCTS:
		if Items.PRODUCTS[id]["device"] == "":
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 132)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 16)
		btn.clip_text = true
		btn.icon = Icons.food(id)
		btn.expand_icon = false
		btn.add_theme_constant_override("icon_max_width", 64)
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_button(btn, Color("#ffe6d2"), C_TEXT)
		# Yiyecek ikonu kendi renginde kalsın.
		for key in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			btn.add_theme_color_override(key, Color.WHITE)
		btn.pressed.connect(func() -> void:
			main.kitchen.add_ingredient(id)
			# Ürünün konduğu cihaza yakın plan
			main.kitchen_focus(Items.PRODUCTS[id]["device"])
		)
		row.add_child(btn)
		_kitchen_buttons[id] = btn
	var strip := TicketStrip.new()
	strip.mode = TicketStrip.Mode.KITCHEN
	strip.shop = main.shop
	box.add_child(strip)
	return panel


func _build_toast() -> void:
	_toast = PanelContainer.new()
	var toast_style := UiKit.flat(Color(0.16, 0.11, 0.09, 0.94), 26, 18)
	toast_style.content_margin_left = 26
	toast_style.content_margin_right = 26
	_toast.add_theme_stylebox_override("panel", toast_style)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 150
	_toast.offset_bottom = 150
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_root.add_child(_toast)
	_toast_label = Label.new()
	_toast_label.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_child(_toast_label)


func _build_reviews() -> void:
	_reviews_overlay = ColorRect.new()
	(_reviews_overlay as ColorRect).color = Color(0, 0, 0, 0.55)
	_reviews_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reviews_overlay.visible = false
	_root.add_child(_reviews_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 140)
	_reviews_overlay.add_child(margin)

	var panel := PanelContainer.new()
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_reviews_title = Label.new()
	_reviews_title.add_theme_font_size_override("font_size", 34)
	box.add_child(_reviews_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_reviews_list = VBoxContainer.new()
	_reviews_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reviews_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_reviews_list)

	var close := Button.new()
	close.text = "Kapat"
	UiKit.set_icon(close, "x", 28)
	close.pressed.connect(func() -> void: _reviews_overlay.visible = false)
	box.add_child(close)


# --- Yardımcı parçalar --------------------------------------------------------

## Başlıktaki küçük sayaç: renkli zemin üstünde ikon ve sayı.
func _summary_chip(parent: Control, icon: String, color: Color) -> Label:
	var chip := PanelContainer.new()
	var style := UiKit.flat(color.lightened(0.82), 16, 6)
	style.content_margin_left = 10
	style.content_margin_right = 12
	chip.add_theme_stylebox_override("panel", style)
	parent.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	chip.add_child(row)
	row.add_child(UiKit.icon_rect(icon, color, 22))
	var count := UiKit.label("0", 22, color.darkened(0.25), 900)
	row.add_child(count)
	return count


## Sayaçlar: kasada/sırada bekleyen, mutfakta hazırlanan, teslime hazır sipariş.
func _refresh_summary() -> void:
	var cooking := 0
	var ready := 0
	for order in main.shop.orders:
		if order["ready"]:
			ready += 1
		else:
			cooking += 1
	_sum_queue.text = str(main.shop.waiting_count())
	_sum_cooking.text = str(cooking)
	_sum_ready.text = str(ready)


func _heading(title: String, hint: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 32)
	box.add_child(t)
	var h := Label.new()
	h.text = hint
	h.add_theme_color_override("font_color", C_MUTED)
	h.add_theme_font_size_override("font_size", 21)
	box.add_child(h)
	return box


func _ready_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var labels := {}
	for id in Items.PRODUCTS:
		var chip := PanelContainer.new()
		var chip_style := UiKit.card_style(C_CREAM, 18)
		chip_style.set_content_margin_all(6)
		chip.add_theme_stylebox_override("panel", chip_style)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := HBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 4)
		chip.add_child(inner)
		inner.add_child(UiKit.food_rect(id, 44))
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_font_override("font", UiKit.font(900))
		inner.add_child(l)
		row.add_child(chip)
		labels[id] = l
	_ready_labels.append(labels)
	return row


## Telefonun güvenli alanı (iPhone çentiği / Dynamic Island ve alttaki ev çubuğu):
## arayüz bu alanın içine çekilir. Masaüstünde ekranın kullanılabilir alanı
## pencereyle ilgisiz olduğundan sadece mobilde uygulanır.
func _apply_safe_area() -> void:
	if not OS.has_feature("mobile"):
		return
	var window := Vector2(DisplayServer.window_get_size())
	if window.y <= 0.0:
		return
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var scale := get_viewport().get_visible_rect().size.y / window.y
	_root.offset_top = safe.position.y * scale
	_root.offset_bottom = -maxf(0.0, window.y - safe.end.y) * scale
	_root.offset_left = safe.position.x * scale
	_root.offset_right = -maxf(0.0, window.x - safe.end.x) * scale


## Güvenli alanın üst boşluğu (çentik); masaüstünde 0.
func safe_top() -> float:
	return _root.offset_top


## Klavye açıkken yazılan kutu klavyenin altında kalmasın: tüm arayüz yukarı kayar.
func _avoid_keyboard() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var shift := 0.0
	var focused := get_viewport().gui_get_focus_owner()
	var keyboard := float(DisplayServer.virtual_keyboard_get_height()) if focused is LineEdit else 0.0
	if keyboard > 0.0:
		var window_h := float(DisplayServer.window_get_size().y)
		var visible := get_viewport().get_visible_rect().size.y
		var keyboard_top := visible - keyboard * visible / maxf(window_h, 1.0)
		var bottom := (focused as Control).get_global_rect().end.y + 24.0
		shift = maxf(0.0, bottom - keyboard_top)
	offset.y = lerpf(offset.y, -shift, 0.35)


## Klavye açıkken yazı kutusunun dışına dokununca klavye kapanır.
func _input(event: InputEvent) -> void:
	var touch := (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed()
	if not touch:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit and not (focused as Control).get_global_rect().has_point(event.position - offset):
		focused.release_focus()


func _on_node_added(node: Node) -> void:
	# Kaydırılabilir alanlar telefonda parmakla (butonların üstünden de) kayar.
	if node is ScrollContainer and not node.has_meta("touch_scroll"):
		node.set_meta("touch_scroll", true)
		node.add_child.call_deferred(TouchScroll.new())
	if node is Button and not node.has_meta("press_fx"):
		node.set_meta("press_fx", true)
		var btn := node as Button
		btn.button_down.connect(_press_fx.bind(btn, true))
		btn.button_up.connect(_press_fx.bind(btn, false))


## Basınca hafif küçülür, bırakınca yaylanarak döner.
func _press_fx(btn: Button, down: bool) -> void:
	btn.pivot_offset = btn.size * 0.5
	var tween := btn.create_tween()
	if down:
		Sfx.play("tap", 0.05)
		tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.06)
	else:
		tween.tween_property(btn, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _style_button(btn: Button, bg: Color, fg: Color) -> void:
	UiKit.candy(btn, bg, fg)


func _set_text(btn: Button, text: String) -> void:
	if btn.text != text:
		btn.text = text


# --- Sipariş kartları ----------------------------------------------------------

func _add_card(customer: ShopCustomer) -> void:
	var card := PanelContainer.new()
	var card_style := UiKit.panel_style(22)
	card_style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(200, 0)
	card.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	var mood := TextureRect.new()
	mood.custom_minimum_size = Vector2(28, 28)
	mood.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mood.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(mood)
	var name_l := Label.new()
	name_l.text = customer.customer_name
	name_l.add_theme_color_override("font_color", C_MUTED)
	name_l.add_theme_font_size_override("font_size", 20)
	head.add_child(name_l)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	box.add_child(flow)
	var labels := {}
	for id in customer.order:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 0)
		item.add_child(UiKit.food_rect(id, 48))
		var l := Label.new()
		l.text = "×%d" % customer.order[id]
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_font_override("font", UiKit.font(900))
		item.add_child(l)
		flow.add_child(item)
		labels[id] = l

	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	box.add_child(bar)

	var btn := Button.new()
	btn.text = "Sipariş Al"
	btn.add_theme_font_size_override("font_size", 22)
	UiKit.set_icon(btn, "receipt", 26)
	_style_button(btn, C_ORANGE, Color.WHITE)
	btn.pressed.connect(func() -> void: main.shop.request_order(customer))
	box.add_child(btn)

	card.set_meta("bar", bar)
	card.set_meta("mood", mood)
	card.set_meta("labels", labels)
	_world_ui.add_child(card)
	_cards[customer] = card


## Sipariş veren müşterinin üstünde: numara, bekleme çubuğu, Teslim Et.
func _add_pickup_card(order: Dictionary) -> void:
	# Paket servis siparişinin dükkanda bekleyen müşterisi yok.
	if order.get("delivery", false):
		return
	var card := PanelContainer.new()
	var style := UiKit.panel_style(20)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(150, 0)
	card.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	var mood := TextureRect.new()
	mood.custom_minimum_size = Vector2(26, 26)
	mood.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mood.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(mood)
	head.add_child(UiKit.label("#%d" % order["number"], 26, C_TEXT, 900))
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	box.add_child(bar)
	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 19)
	btn.custom_minimum_size = Vector2(0, 52)
	btn.pressed.connect(main.shop.deliver.bind(order))
	box.add_child(btn)
	card.set_meta("bar", bar)
	card.set_meta("mood", mood)
	card.set_meta("button", btn)
	card.set_meta("ready", "")
	_world_ui.add_child(card)
	_pickup_cards[order["number"]] = card


func _update_pickup_card(order: Dictionary, card: PanelContainer, on_shop: bool) -> void:
	var customer: ShopCustomer = order["customer"]
	card.visible = on_shop and customer.state == ShopCustomer.State.ORDERED
	if not card.visible:
		return
	var p := main.camera.unproject_position(customer.global_position + Vector3(0, 1.9, 0))
	card.position = p - Vector2(card.size.x * 0.5, card.size.y)
	var ratio := clampf(customer.food_patience / customer.max_food_patience, 0.0, 1.0)
	var bar: ProgressBar = card.get_meta("bar")
	bar.value = ratio
	bar.add_theme_stylebox_override("fill", _bar_styles[0 if ratio < 0.25 else (1 if ratio < 0.55 else 2)])
	(card.get_meta("mood") as TextureRect).texture = customer.mood_icon()
	# Buton sadece hazır olma durumu değişince yeniden boyanır.
	var ready_state := "hazir" if order["ready"] else "bekliyor"
	if card.get_meta("ready") != ready_state:
		card.set_meta("ready", ready_state)
		var btn: Button = card.get_meta("button")
		if order["ready"]:
			btn.text = "Teslim Et"
			UiKit.set_icon(btn, "hand-platter", 22)
			UiKit.candy(btn, C_GREEN, Color.WHITE)
		else:
			btn.text = "Bekliyor"
			UiKit.set_icon(btn, "timer", 22)
			UiKit.candy(btn, UiKit.NEUTRAL, C_TEXT)


func _sync_pickup_cards() -> void:
	var open := {}
	for order in main.shop.orders:
		open[order["number"]] = true
	for number in _pickup_cards.keys():
		if not open.has(number):
			(_pickup_cards[number] as Control).queue_free()
			_pickup_cards.erase(number)


## Teslimde bahşiş çıkarsa müşterinin üstünde gösterilir.
## Bahşiş teslimde (müşteri puan verince) gelir: kavanoz dolar, para uçar.
func _on_delivered(customer: ShopCustomer, tip: int) -> void:
	if tip <= 0:
		return
	main.shop.register.add_tip(tip)
	if main.screen != Main.SHOP:
		return
	var p := main.camera.unproject_position(customer.global_position + Vector3(0, 1.9, 0))
	_popup(p, "Bahşiş +₺%d" % tip, Color("#f2b33c"), 44, 0.0)
	for i in 4:
		_fly_coin(p + Vector2(randf_range(-30, 30), randf_range(-20, 20)), i * 0.06)


func _remove_card(customer: ShopCustomer) -> void:
	if _cards.has(customer):
		_cards[customer].queue_free()
		_cards.erase(customer)


func _update_card(customer: ShopCustomer, card: PanelContainer, on_shop: bool) -> void:
	card.visible = on_shop and customer.state == ShopCustomer.State.WAITING
	if not card.visible:
		return
	var p := main.camera.unproject_position(customer.global_position + Vector3(0, 1.9, 0))
	card.position = p - Vector2(card.size.x * 0.5, card.size.y)

	var ratio := clampf(customer.patience / customer.max_patience, 0.0, 1.0)
	var bar: ProgressBar = card.get_meta("bar")
	bar.value = ratio
	bar.add_theme_stylebox_override("fill", _bar_styles[0 if ratio < 0.25 else (1 if ratio < 0.55 else 2)])


	# Ruh hali ikonu isminin önünde
	(card.get_meta("mood") as TextureRect).texture = customer.mood_icon()


# --- Yenileme -----------------------------------------------------------------

## Oyunu durdurur / devam ettirir. Durunca ortada "Durduruldu" penceresi çıkar.
func set_paused(on: bool) -> void:
	if on == get_tree().paused or not GameState.setup_done:
		return
	get_tree().paused = on
	if on:
		_build_pause_overlay()
	elif _pause_overlay:
		_pause_overlay.queue_free()
		_pause_overlay = null


func _build_pause_overlay() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.color = Color(0.08, 0.05, 0.03, 0.6)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_pause_overlay)
	_root.move_child(_pause_overlay, _toast.get_index())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var badge := UiKit.badge_rect("pause", UiKit.BLUE, 96)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(badge)
	var title := UiKit.label("Durduruldu", 44, UiKit.TEXT, 900)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var hint := UiKit.label("Saat, müşteriler ve ocak bekliyor.", 22, UiKit.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var resume := Button.new()
	resume.text = "Devam Et"
	resume.custom_minimum_size = Vector2(0, 92)
	resume.add_theme_font_size_override("font_size", 32)
	UiKit.set_icon(resume, "play", 34)
	UiKit.candy(resume, UiKit.GREEN, Color.WHITE)
	resume.pressed.connect(set_paused.bind(false))
	v.add_child(resume)
	var settings := Button.new()
	settings.text = "Ayarlar"
	settings.custom_minimum_size = Vector2(0, 80)
	UiKit.set_icon(settings, "settings", 30)
	UiKit.candy(settings, UiKit.NEUTRAL, UiKit.TEXT)
	settings.pressed.connect(open_settings)
	v.add_child(settings)


## Telefon uygulamayı arka plana alınca oyun kendiliğinden durur.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		set_paused(true)


## Seçili kamera açısının düğmesi turuncu görünür.
func _refresh_view_buttons(view: String) -> void:
	for key in _view_buttons:
		var on: bool = key == view
		UiKit.candy(_view_buttons[key], UiKit.ORANGE if on else UiKit.NEUTRAL, Color.WHITE if on else UiKit.TEXT)
	_filter_kitchen_cards()


## Mutfak kartları: genel görünümde açık ürünlerin hepsi, cihaz yakın planında
## sadece o cihazda pişenler.
func _filter_kitchen_cards() -> void:
	var view := main.kitchen_view
	for id in _kitchen_buttons:
		var device: String = Items.PRODUCTS[id]["device"]
		(_kitchen_buttons[id] as Control).visible = Items.unlocked(id) and (view == "" or device == view)


## Sipariş ve ödeme ekranları kasanın ekranına oturur: kamera 3D ekranı tam bu
## alanın arkasına getirir (Main.pos_screen_rect). Kasa ekranı açıkken alttaki
## sipariş paneli gizlenir.
func _place_pos_screen() -> void:
	var active := _order_entry.visible or _payment.visible
	if main.screen == Main.SHOP and GameState.setup_done:
		_panels[Main.SHOP].visible = not active
	_pos_backdrop.modulate.a = move_toward(_pos_backdrop.modulate.a, 1.0 if active else 0.0, get_process_delta_time() * 4.0)
	_pos_backdrop.visible = _pos_backdrop.modulate.a > 0.0
	if not active:
		return
	var rect := main.pos_screen_rect()
	rect.position -= _root.position
	if _order_entry.visible:
		_order_entry.place(rect)
	if _payment.visible:
		_payment.place(rect)


## Kasa ekranı: kamera kasaya yaklaşır, müşterinin isteği menüden fişe girilir.
func _open_order_entry(customer: ShopCustomer) -> void:
	if _order_entry.visible:
		return
	main.focus_register(true)
	_order_entry.open(customer)


## Takvim: gün gün kazanç ve gider dökümü.
func open_calendar() -> void:
	if _calendar and is_instance_valid(_calendar):
		return
	_calendar = CalendarUI.new()
	_root.add_child(_calendar)


func open_settings() -> void:
	if _settings and is_instance_valid(_settings):
		return
	_settings = SettingsUI.new()
	_root.add_child(_settings)


func nav_button(screen: int) -> Button:
	return _nav[screen]


func kitchen_button(id: String) -> Button:
	return _kitchen_buttons.get(id)


func _on_setup_finished() -> void:
	if _setup:
		_setup.queue_free()
		_setup = null
	_nav_row.visible = true
	_on_screen_changed(main.screen)


func _on_tutorial_changed(step: int) -> void:
	if step == 0 and _tutorial == null:
		_tutorial = TutorialUI.new()
		_tutorial.hud = self
		_root.add_child(_tutorial)
		_root.move_child(_tutorial, _toast.get_index())


func _on_screen_changed(screen: int) -> void:
	Sfx.set_screen(screen)
	# Kurulum sırasında sadece kurulum paneli görünür.
	_nav_row.visible = GameState.setup_done
	for i in _panels.size():
		_panels[i].visible = i == screen and GameState.setup_done
	for i in _nav.size():
		if i == screen:
			_style_button(_nav[i], C_ORANGE, Color.WHITE)
		else:
			_style_button(_nav[i], Color(1, 1, 1, 0.95), C_TEXT)


## Para sayacı yeni değere doğru sayarak gider.
func _animate_money(value: int) -> void:
	if _money_tween:
		_money_tween.kill()
	_money_tween = create_tween()
	_money_tween.tween_method(_set_money_text, _money_value, float(value), 0.7).set_ease(Tween.EASE_OUT)


func _set_money_text(value: float) -> void:
	_money_value = value
	_money.text = "₺ %d" % roundi(value)


# --- Satış efekti -------------------------------------------------------------

## Ödeme başlayınca kasa açılır, kamera kasaya yakınlaşır.
func _on_payment_started(_customer: ShopCustomer, amount: int) -> void:
	var reg := main.shop.register
	reg.show_amount(amount)
	if _payment.by_card:
		reg.card_wait()
	else:
		reg.open_drawer()
	main.focus_register(true)


func _on_payment_finished(customer: ShopCustomer, _loss: int) -> void:
	var reg := main.shop.register
	reg.close_drawer()
	reg.show_thanks()
	# Satış efekti kasada görünsün, sonra kamera salona döner.
	get_tree().create_timer(1.8).timeout.connect(main.focus_register.bind(false))


func _on_sale(customer: ShopCustomer, amount: int, tip: int) -> void:
	# Kasaya yakınlaşılmışsa efekt kasadan, değilse müşterinin üstünden çıkar.
	var source := main.shop.register.global_position + Vector3(0, 0.45, 0) if main.register_focus else customer.global_position + Vector3(0, 1.9, 0)
	var p := main.camera.unproject_position(source)
	_popup(p, "+₺%d" % amount, Color("#3fbf6f"), 72, 0.0)
	if tip > 0:
		_popup(p + Vector2(0, 74), "Bahşiş +₺%d" % tip, Color("#f2b33c"), 44, 0.35)
	var coins := clampi((amount + tip) / 3, 5, 12)
	for i in coins:
		_fly_coin(p + Vector2(randf_range(-50, 50), randf_range(-30, 30)), i * 0.05)


## Zıplayarak büyüyen, yükselip kaybolan yazı.
func _popup(pos: Vector2, text: String, color: Color, font_size: int, delay: float) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#2b1d16"))
	label.add_theme_constant_override("outline_size", 14)
	_fx.add_child(label)
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	label.position = pos - label.size * 0.5
	label.scale = Vector2.ZERO
	var tween := label.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(label, "scale", Vector2(1.25, 1.25), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 90.0, 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.75)
	tween.chain().tween_callback(label.queue_free)


## Satış yerinden kavis çizerek üstteki para sayacına uçan altın para.
func _fly_coin(start: Vector2, delay: float) -> void:
	var coin := Coin.new()
	coin.position = start
	coin.scale = Vector2.ZERO
	_fx.add_child(coin)
	var target := _money.get_global_rect().get_center()
	var control := Vector2(lerpf(start.x, target.x, 0.3) + randf_range(-140, 140), minf(start.y, target.y) - randf_range(60, 200))
	var tween := coin.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(coin, "scale", Vector2.ONE, 0.12)
	tween.tween_method(func(t: float) -> void:
		coin.position = start.lerp(control, t).lerp(control.lerp(target, t), t)
		coin.rotation = t * TAU
	, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		Sfx.play("coin", 0.12)
		_punch_money()
		coin.queue_free()
	)


func _punch_money() -> void:
	_money.pivot_offset = _money.size * 0.5
	_money.scale = Vector2(1.18, 1.18)
	_money.create_tween().tween_property(_money, "scale", Vector2.ONE, 0.15)


## Çizimle yapılmış küçük altın para.
class Coin extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 17.0, Color("#b8860b"))
		draw_circle(Vector2(0, -1), 15.0, Color("#f6c945"))
		draw_circle(Vector2(0, -1), 10.0, Color("#ffd966"))
		draw_arc(Vector2(-3, -4), 8.0, PI, PI * 1.5, 8, Color(1, 1, 1, 0.8), 2.0)


func _refresh_stock() -> void:
	for id in _kitchen_buttons:
		(_kitchen_buttons[id] as Button).text = "%s\n%d stok · %d hazır" % [Items.display_name(id), GameState.stock[id], GameState.available(id)]
	for labels in _ready_labels:
		for id in labels:
			(labels[id] as Label).text = str(GameState.available(id))


func _refresh_reviews() -> void:
	var count := GameState.reviews.size()
	_rating_btn.text = "Yeni" if count == 0 else "%.1f" % GameState.rating()
	_reviews_title.text = "Müşteri Yorumları" if count == 0 else "Müşteri Yorumları  •  %.1f puan (%d)" % [GameState.rating(), count]

	for child in _reviews_list.get_children():
		child.queue_free()
	if count == 0:
		var empty := Label.new()
		empty.text = "Henüz yorum yok. İlk müşterini mutlu et!"
		empty.add_theme_color_override("font_color", C_MUTED)
		_reviews_list.add_child(empty)
		return
	for review in GameState.reviews:
		var entry := PanelContainer.new()
		entry.add_theme_stylebox_override("panel", UiKit.card_style())
		var v := VBoxContainer.new()
		entry.add_child(v)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 2)
		var stars: int = review["stars"]
		for i in 5:
			head.add_child(UiKit.icon_rect("star", UiKit.YELLOW if i < stars else Color("#d8cfc6"), 26))
		var who := UiKit.label("   " + review["name"], 24, C_MUTED, 800)
		head.add_child(who)
		v.add_child(head)
		var body := Label.new()
		body.text = review["text"]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(560, 0)
		body.add_theme_font_size_override("font_size", 24)
		v.add_child(body)
		_reviews_list.add_child(entry)


func _buy(id: String) -> void:
	if GameState.buy_pack(id):
		show_toast("+%d %s alındı" % [Items.PACK_SIZE, Items.display_name(id)])
	else:
		show_toast("Yeterli paran yok!")


# --- Kurye kartları ve telefon rozeti -------------------------------------------------

## Kuryenin başının üstünde, müşteri kartları gibi: adı, kucağındaki paketler
## (4 yuva), paketlerin bekleme çubuğu, "Paket Ver" ve "Yola Çık".
func _update_courier_cards(on_shop: bool) -> void:
	var shop := main.shop
	for courier in _courier_cards.keys():
		if not is_instance_valid(courier) or not shop.couriers.has(courier):
			(_courier_cards[courier] as Control).queue_free()
			_courier_cards.erase(courier)
	for courier in shop.couriers:
		if not _courier_cards.has(courier):
			_courier_cards[courier] = _make_courier_card(courier)
		var card: PanelContainer = _courier_cards[courier]
		var here := courier.state == Courier.State.WAITING
		card.visible = on_shop and here
		if not card.visible:
			continue
		var p := main.camera.unproject_position(courier.global_position + Vector3(0, courier.card_height, 0))
		# Kenara yakın kuryenin kartı ekrandan taşmasın.
		var width := _world_ui.size.x
		card.position = Vector2(clampf(p.x - card.size.x * 0.5, 12.0, width - card.size.x - 12.0), p.y - card.size.y)
		var count := courier.packages.size()
		var slots: Array = card.get_meta("slots")
		for i in slots.size():
			var full: bool = i < count
			var slot: PanelContainer = slots[i]
			slot.add_theme_stylebox_override("panel", UiKit.flat(UiKit.PURPLE if full else Color("#ece6f7"), 8, 2))
			(slot.get_child(0) as TextureRect).modulate = Color.WHITE if full else Color(1, 1, 1, 0.0)
		# Bekleme çubuğu: kucaktaki en sabırsız müşteri
		var bar: ProgressBar = card.get_meta("bar")
		bar.visible = count > 0
		if count > 0:
			var ratio := 1.0
			for order in courier.packages:
				ratio = minf(ratio, Shop.patience_ratio(order))
			bar.value = ratio
			bar.add_theme_stylebox_override("fill", _bar_styles[0 if ratio < 0.25 else (1 if ratio < 0.55 else 2)])
		var ready := 0
		for order in shop.orders:
			if order.get("delivery", false) and order["ready"]:
				ready += 1
		var give: Button = card.get_meta("give")
		var go: Button = card.get_meta("go")
		var give_state := "%d|%d" % [ready, count]
		if card.get_meta("state") != give_state:
			card.set_meta("state", give_state)
			give.visible = ready > 0 and not courier.is_full()
			give.text = "Paket Ver" if ready <= 1 else "Paket Ver (%d)" % ready
			go.visible = count > 0
			go.text = "Yola Çık"
			(card.get_meta("hint") as Label).visible = ready == 0 and count == 0
			(card.get_meta("hint") as Label).text = "Paket bekliyor"
			# Gizlenen düğmelerin yeri kalmasın: kart içeriğe göre küçülür.
			card.reset_size()


func _make_courier_card(courier: Courier) -> PanelContainer:
	var card := PanelContainer.new()
	var style := UiKit.panel_style(20)
	style.set_content_margin_all(10)
	style.border_color = UiKit.PURPLE
	style.border_width_bottom = 4
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(176, 0)
	card.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	head.add_child(UiKit.icon_rect("package", UiKit.PURPLE, 26))
	var name_l := UiKit.label(courier.data["name"], 22, C_TEXT, 900)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	head.add_child(UiKit.label("KURYE", 14, UiKit.PURPLE, 900))
	# Kucaktaki paketler: 4 yuva
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	box.add_child(row)
	var slots: Array = []
	for i in Staff.COURIER_CAPACITY:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(34, 34)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := UiKit.icon_rect("package", Color.WHITE, 22)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.add_child(icon)
		row.add_child(slot)
		slots.append(slot)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	box.add_child(bar)
	var hint := UiKit.label("", 17, C_MUTED, 700)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var give := Button.new()
	give.add_theme_font_size_override("font_size", 18)
	give.custom_minimum_size = Vector2(0, 50)
	UiKit.set_icon(give, "hand-platter", 22)
	UiKit.candy(give, UiKit.PURPLE, Color.WHITE)
	give.pressed.connect(func() -> void:
		for order in main.shop.orders:
			if order.get("delivery", false) and order["ready"]:
				main.shop.give_to_courier(order)
				return
	)
	box.add_child(give)
	var go := Button.new()
	go.add_theme_font_size_override("font_size", 18)
	go.custom_minimum_size = Vector2(0, 50)
	UiKit.set_icon(go, "arrow-right", 22)
	UiKit.candy(go, C_GREEN, Color.WHITE)
	go.pressed.connect(func() -> void: main.shop.dispatch(courier))
	box.add_child(go)
	card.set_meta("slots", slots)
	card.set_meta("bar", bar)
	card.set_meta("give", give)
	card.set_meta("go", go)
	card.set_meta("hint", hint)
	card.set_meta("state", "")
	_world_ui.add_child(card)
	return card


## Telefon çalarken üstünde zıplayan "PAKET!" rozeti; dokununca çağrı açılır.
func _update_phone_badge(on_shop: bool) -> void:
	var reg := main.shop.register
	if _phone_badge == null:
		_phone_badge = Button.new()
		_phone_badge.text = "PAKET!"
		_phone_badge.add_theme_font_size_override("font_size", 20)
		_phone_badge.custom_minimum_size = Vector2(0, 46)
		UiKit.set_icon(_phone_badge, "smartphone", 22)
		UiKit.candy(_phone_badge, UiKit.PURPLE, Color.WHITE)
		_phone_badge.pressed.connect(main.shop.answer_call)
		_world_ui.add_child(_phone_badge)
	_phone_badge.visible = on_shop and reg.is_ringing()
	if _phone_badge.visible:
		var p := main.camera.unproject_position(reg.phone_top())
		var bob := 6.0 * sin(Time.get_ticks_msec() * 0.008)
		_phone_badge.position = p - Vector2(_phone_badge.size.x * 0.5, _phone_badge.size.y + bob)
