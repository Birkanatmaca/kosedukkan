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
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)

	_world_ui = Control.new()
	_world_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_world_ui)

	_bar_styles = [Util.style(Color("#e05555"), 6, 0), Util.style(Color("#f0a540"), 6, 0), Util.style(C_GREEN, 6, 0)]

	_build_top_bar()
	_panels = [_build_market_panel(), _build_shop_panel(), _build_kitchen_panel()]
	_build_nav()
	if not GameState.setup_done:
		_setup = SetupUI.new()
		_root.add_child(_setup)
	_build_toast()
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
	var on_shop := main.screen == Main.SHOP and not main.transitioning and not main.register_focus
	var on_kitchen := main.screen == Main.KITCHEN and not main.transitioning

	for customer in _cards:
		_update_card(customer, _cards[customer], on_shop)
	for order in main.shop.orders:
		if _pickup_cards.has(order["number"]):
			_update_pickup_card(order, _pickup_cards[order["number"]], on_shop)
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
	for i in 3:
		var tab := Button.new()
		tab.text = ["Malzeme", "Geliştir", "Personel"][i]
		UiKit.set_icon(tab, ["package", "circle-arrow-up", "users"][i], 28)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 64)
		tab.add_theme_font_size_override("font_size", 24)
		tab.pressed.connect(_show_market_tab.bind(i))
		tabs.add_child(tab)
		_market_tabs.append(tab)

	_market_pages = [_build_supplies_page(), _build_upgrades_page(), _build_staff_page()]
	for page in _market_pages:
		box.add_child(page)
	_show_market_tab(0)
	return panel


## Personel sekmesi: çalışanlar (maaş, çıkar) ve günün adayları (işe al, pazarlık).
func _build_staff_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(_heading("Personel", "Garson masaları temizler • maaş gün sonunda ödenir"))
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

	_staff_list.add_child(_section_label("Çalışanların (%d/%d)" % [GameState.staff.size(), Staff.MAX_STAFF]))
	if GameState.staff.is_empty():
		_staff_list.add_child(_muted_label("Henüz çalışanın yok. Masaları kendin temizlemelisin."))
	for i in GameState.staff.size():
		var person: Dictionary = GameState.staff[i]
		var fire := _small_button("Çıkar", Color("#d9d0c9"), C_TEXT)
		fire.pressed.connect(func() -> void:
			GameState.fire(i)
			show_toast("%s işten çıkarıldı" % person["name"])
		)
		_staff_list.add_child(_person_row("chef-hat", person, "₺%d / gün" % person["wage"], [fire]))

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
	traits.text = Staff.traits(person)
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


func _build_supplies_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(_heading("Toptancı", "Malzeme bitince buradan al"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
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
		v.add_child(top)
		top.add_child(UiKit.food_rect(id, 72))
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		top.add_child(info)
		var name_l := Label.new()
		name_l.text = Items.display_name(id)
		info.add_child(name_l)
		var stock_l := Label.new()
		stock_l.add_theme_color_override("font_color", C_MUTED)
		stock_l.add_theme_font_size_override("font_size", 22)
		info.add_child(stock_l)
		_market_stock[id] = stock_l

		var buy := Button.new()
		buy.text = "+%d   ₺%d" % [Items.PACK_SIZE, Items.PRODUCTS[id]["pack_price"]]
		UiKit.set_icon(buy, "shopping-cart", 28)
		_style_button(buy, C_GREEN, Color.WHITE)
		buy.pressed.connect(_buy.bind(id))
		v.add_child(buy)
	return box


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
	Sfx.play("approve")
	Sfx.play("kaching")
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
	sub.text = "Müşteriler artıyor, siparişler büyüyor!"
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


func _build_shop_panel() -> Control:
	var panel := _bottom_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_heading("Siparişler", "Kasadaki müşteriye dokun: sipariş al. Hazır olanı teslim et."))
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
	box.add_child(_heading("Pişir", "Kıvamı yeşildeyken ürüne dokun, sonra fişin tepsisine koy"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for id in Items.PRODUCTS:
		if Items.PRODUCTS[id]["device"] == "":
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 132)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 23)
		btn.icon = Icons.food(id)
		btn.expand_icon = false
		btn.add_theme_constant_override("icon_max_width", 64)
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_button(btn, Color("#ffe6d2"), C_TEXT)
		# Yiyecek ikonu kendi renginde kalsın.
		for key in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			btn.add_theme_color_override(key, Color.WHITE)
		btn.pressed.connect(main.kitchen.add_ingredient.bind(id))
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


func _on_node_added(node: Node) -> void:
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
	btn.pressed.connect(func() -> void: main.shop.take_order(customer))
	box.add_child(btn)

	card.set_meta("bar", bar)
	card.set_meta("mood", mood)
	card.set_meta("labels", labels)
	_world_ui.add_child(card)
	_cards[customer] = card


## Sipariş veren müşterinin üstünde: numara, bekleme çubuğu, Teslim Et.
func _add_pickup_card(order: Dictionary) -> void:
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
func _on_delivered(customer: ShopCustomer, tip: int) -> void:
	if tip <= 0 or main.screen != Main.SHOP:
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
	if customer.sale_tip > 0:
		reg.add_tip(customer.sale_tip)
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
	for id in _market_stock:
		(_market_stock[id] as Label).text = "Stok: %d" % GameState.stock[id]
	for id in _kitchen_buttons:
		(_kitchen_buttons[id] as Button).text = "%s\nStok %d • Hazır %d" % [Items.display_name(id), GameState.stock[id], GameState.available(id)]
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
