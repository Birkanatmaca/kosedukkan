class_name OrderEntry
extends Control

## Kasa ekranı (POS): üst bar ile alt menü arasını dolduran büyük panel (Hud her
## karede place() ile yerleştirir, arkadaki sahne bulanıklaşır). Müşterinin isteği
## üstte büyük resimlerle görünür; kasiyer menüdeki büyük ürün kartlarına dokunarak
## fişi oluşturur (fişteki ürüne dokununca bir adet çıkar). "Ödeme Al" fiş istekle
## tutuyorsa ödemeye geçer; tutmuyorsa müşteri itiraz eder, sabrı biraz azalır.

signal confirmed(customer: ShopCustomer)
signal cancelled(customer: ShopCustomer)

## Kasa ekranının tasarım genişliği; yükseklik ekrandaki alana göre değişir
## (place() genişliğe göre ölçekler, kalan yükseklik içeriğe verilir).
const DESIGN := Vector2(660, 1000)
## POS renkleri: koyu çerçeve, açık ekran, mavi başlık şeridi
const BEZEL := Color("#1d2127")
const SCREEN_BG := Color("#f3f6fa")
const HEADER := Color("#2459b8")
## Yanlış fişte müşterinin sabrından düşen süre (sn)
const WRONG_PENALTY := 2.0

var customer: ShopCustomer

## ürün -> adet
var _ticket := {}
var _sheet: PanelContainer
var _title: Label
var _total: Label
var _wants: HBoxContainer
var _ticket_row: HBoxContainer
var _pay: Button
## ürün -> menü tuşu (fiyatlar açılışta güncellenir)
var _menu_buttons := {}
## Yanlış fişte ekran sallanır (place() bu kaydırmayı ekler)
var _shake := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_sheet = pos_frame(self)
	var box: VBoxContainer = _sheet.get_meta("box")
	box.add_theme_constant_override("separation", 12)

	var header := pos_header(box)
	_title = UiKit.label("", 30, Color.WHITE, 900)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	header.add_child(_title)
	_total = UiKit.label("₺0", 44, Color.WHITE, 900)
	header.add_child(_total)

	# Müşterinin isteği: büyük resimler, adet ve ad
	var wants_card := PanelContainer.new()
	var wants_style := UiKit.flat(Color("#fff4dc"), 16, 12)
	wants_style.border_color = Color("#f0c070")
	wants_style.set_border_width_all(3)
	wants_card.add_theme_stylebox_override("panel", wants_style)
	box.add_child(wants_card)
	var wants_box := VBoxContainer.new()
	wants_box.add_theme_constant_override("separation", 6)
	wants_card.add_child(wants_box)
	var wants_head := HBoxContainer.new()
	wants_head.add_theme_constant_override("separation", 8)
	wants_box.add_child(wants_head)
	wants_head.add_child(UiKit.icon_rect("message-circle", UiKit.ORANGE, 30))
	wants_head.add_child(UiKit.label("Müşterinin İsteği", 24, UiKit.TEXT, 900))
	_wants = HBoxContainer.new()
	_wants.alignment = BoxContainer.ALIGNMENT_CENTER
	_wants.add_theme_constant_override("separation", 22)
	wants_box.add_child(_wants)

	# Menü: 3 sütunlu büyük ürün kartları (resim üstte, ad ve fiyat altta)
	box.add_child(UiKit.label("Menü  •  ürüne dokun, fişe eklensin", 20, UiKit.MUTED, 900))
	# Kısa ekranlarda menü kayar; diğer her şey yerinde kalır.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var menu := GridContainer.new()
	menu.columns = 3
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.add_theme_constant_override("h_separation", 10)
	menu.add_theme_constant_override("v_separation", 10)
	scroll.add_child(menu)
	for id in Items.PRODUCTS:
		var btn := pos_button(Items.display_name(id), Color.WHITE, UiKit.TEXT, 22)
		_menu_buttons[id] = btn
		btn.custom_minimum_size = Vector2(0, 140)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.icon = Icons.food(id)
		btn.add_theme_constant_override("icon_max_width", 70)
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.clip_text = true
		btn.pressed.connect(_add.bind(id))
		menu.add_child(btn)

	# Fiş satırı
	var ticket_box := PanelContainer.new()
	var ticket_style := UiKit.flat(Color("#e6ecf4"), 14, 10)
	ticket_box.add_theme_stylebox_override("panel", ticket_style)
	ticket_box.custom_minimum_size = Vector2(0, 92)
	box.add_child(ticket_box)
	_ticket_row = HBoxContainer.new()
	_ticket_row.add_theme_constant_override("separation", 8)
	ticket_box.add_child(_ticket_row)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var cancel := pos_button("Vazgeç", Color("#d7dde6"), UiKit.TEXT, 28)
	cancel.custom_minimum_size = Vector2(200, 96)
	cancel.pressed.connect(_cancel)
	actions.add_child(cancel)
	_pay = pos_button("Ödeme Al", UiKit.GREEN, Color.WHITE, 34)
	UiKit.set_icon(_pay, "wallet", 36)
	_pay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pay.custom_minimum_size = Vector2(0, 96)
	_pay.pressed.connect(_confirm)
	actions.add_child(_pay)


# --- Kasa ekranı görünümü (ödeme ekranı da kullanır) ---------------------------

## Kasa ekranı cihazı: gölgeli koyu çerçeve, içinde açık ekran, alt kenarda marka.
## İçerik kutusu çerçevenin "box" bilgisinde döner.
static func pos_frame(parent: Control) -> PanelContainer:
	var frame := PanelContainer.new()
	var bezel := UiKit.flat(BEZEL, 30, 14)
	bezel.content_margin_bottom = 6
	bezel.shadow_color = Color(0, 0, 0, 0.45)
	bezel.shadow_size = 28
	bezel.shadow_offset = Vector2(0, 10)
	bezel.border_color = Color("#3a414b")
	bezel.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", bezel)
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	frame.size = DESIGN
	frame.custom_minimum_size = DESIGN
	parent.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	frame.add_child(column)
	var screen := PanelContainer.new()
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := UiKit.flat(SCREEN_BG, 16, 0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 0
	style.content_margin_bottom = 12
	screen.add_theme_stylebox_override("panel", style)
	column.add_child(screen)
	var brand := UiKit.label("KÖŞE DÜKKAN", 12, Color(1, 1, 1, 0.35), 900)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(brand)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	screen.add_child(box)
	frame.set_meta("box", box)
	return frame


## Kasa ekranı açıkken arkadaki sahneyi bulanıklaştırıp karartan perde.
static func backdrop() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 3.5).rgb;
	COLOR = vec4(mix(c, vec3(0.07, 0.05, 0.04), 0.55), 1.0);
}
"""
	rect.material = mat
	return rect


## Mavi başlık şeridi (ekranın üst kenarına yapışık): solda POS adı.
static func pos_header(box: VBoxContainer) -> HBoxContainer:
	var strip := PanelContainer.new()
	var style := UiKit.flat(HEADER, 0, 8)
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 14
	style.content_margin_right = 14
	strip.add_theme_stylebox_override("panel", style)
	box.add_child(strip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	strip.add_child(v)
	v.add_child(UiKit.label("KÖŞE DÜKKAN POS", 13, Color(1, 1, 1, 0.7), 900))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	return row


## Düz, köşeli dokunmatik ekran tuşu.
static func pos_button(text: String, bg: Color, fg: Color, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_size)
	var normal := UiKit.flat(bg, 12, 6)
	normal.border_color = bg.darkened(0.12)
	normal.border_width_bottom = 3
	var pressed := UiKit.flat(bg.darkened(0.1), 12, 6)
	var disabled := UiKit.flat(bg.lerp(Color("#c9d0da"), 0.6), 12, 6)
	for state in ["normal", "hover", "focus"]:
		btn.add_theme_stylebox_override(state, normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(key, fg)
	btn.add_theme_color_override("font_disabled_color", fg.lerp(Color.WHITE, 0.4))
	for key in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		btn.add_theme_color_override(key, Color.WHITE)
	return btn


## Arayüzü telefondaki kasa ekranı alanına oturtur.
func place(rect: Rect2) -> void:
	fit(_sheet, rect)
	_sheet.position.x += _shake


## Paneli genişliğe göre ölçekler; yükseklik alanın tamamını kullanır.
static func fit(sheet: Control, rect: Rect2) -> void:
	var s := rect.size.x / DESIGN.x
	sheet.scale = Vector2(s, s)
	sheet.custom_minimum_size = Vector2(DESIGN.x, rect.size.y / s)
	sheet.size = sheet.custom_minimum_size
	sheet.position = rect.position


# --- Sipariş ------------------------------------------------------------------

func open(c: ShopCustomer) -> void:
	customer = c
	# Menüdeki fiyatlar oyuncunun ayarladığı satış fiyatlarıdır.
	for id in _menu_buttons:
		(_menu_buttons[id] as Button).visible = Items.unlocked(id)
	_ticket.clear()
	_title.text = "Sipariş • " + c.customer_name + ("  (PAKET)" if c.takeaway else "")
	for child in _wants.get_children():
		child.queue_free()
	for id in c.order:
		var item := VBoxContainer.new()
		item.add_theme_constant_override("separation", 0)
		var pic_row := HBoxContainer.new()
		pic_row.add_theme_constant_override("separation", 4)
		pic_row.alignment = BoxContainer.ALIGNMENT_CENTER
		item.add_child(pic_row)
		pic_row.add_child(UiKit.food_rect(id, 84))
		pic_row.add_child(UiKit.label("×%d" % int(c.order[id]), 38, UiKit.TEXT, 900))
		var name_l := UiKit.label(Items.display_name(id), 20, UiKit.MUTED, 900)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(name_l)
		_wants.add_child(item)
	_refresh()
	visible = true
	modulate.a = 0.0
	# Kamera ekrana yaklaşırken ekran içeriği yanar
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35).set_delay(0.2)


func _process(_delta: float) -> void:
	# Müşteri beklerken vazgeçip giderse ekran kapanır.
	if visible and (not is_instance_valid(customer) or customer.state != ShopCustomer.State.WAITING):
		_close()


func _add(id: String) -> void:
	_ticket[id] = int(_ticket.get(id, 0)) + 1
	Sfx.play("beep", 0.05)
	_refresh()


func _remove(id: String) -> void:
	_ticket[id] = int(_ticket[id]) - 1
	if _ticket[id] <= 0:
		_ticket.erase(id)
	_refresh()


func _refresh() -> void:
	for child in _ticket_row.get_children():
		child.queue_free()
	var label := UiKit.label("FİŞ", 20, UiKit.MUTED, 900)
	label.custom_minimum_size = Vector2(50, 0)
	_ticket_row.add_child(label)
	var total := 0
	for id in _ticket:
		total += Items.price(id) * int(_ticket[id])
		var chip := pos_button("×%d" % int(_ticket[id]), Color.WHITE, UiKit.TEXT, 28)
		chip.icon = Icons.food(id)
		chip.add_theme_constant_override("icon_max_width", 48)
		chip.custom_minimum_size = Vector2(0, 72)
		chip.pressed.connect(_remove.bind(id))
		_ticket_row.add_child(chip)
	if _ticket.is_empty():
		var hint := UiKit.label("Fiş boş. Ürüne tekrar dokunursan fişten çıkar.", 20, UiKit.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ticket_row.add_child(hint)
	# Menü kartlarında fiyat ve fişteki adet; fişte olan kart vurgulanır.
	for id in _menu_buttons:
		var btn: Button = _menu_buttons[id]
		var n := int(_ticket.get(id, 0))
		btn.text = "%s\n₺%d" % [Items.display_name(id), Items.price(id)] + ("  •  ×%d" % n if n > 0 else "")
		var bg := Color("#d9f2d0") if n > 0 else Color.WHITE
		var normal := UiKit.flat(bg, 14, 6)
		normal.border_color = UiKit.GREEN if n > 0 else Color("#d3dae4")
		normal.set_border_width_all(3 if n > 0 else 1)
		normal.border_width_bottom = 5 if n > 0 else 3
		for state in ["normal", "hover", "focus"]:
			btn.add_theme_stylebox_override(state, normal)
	_total.text = "₺%d" % total
	_pay.disabled = _ticket.is_empty()


func _matches() -> bool:
	if _ticket.size() != customer.order.size():
		return false
	for id in customer.order:
		if int(_ticket.get(id, 0)) != int(customer.order[id]):
			return false
	return true


func _confirm() -> void:
	if not _matches():
		Sfx.play("error")
		GameState.show_toast("%s: \"Ben bunu istemedim!\"" % customer.customer_name)
		customer.patience = maxf(1.0, customer.patience - WRONG_PENALTY)
		var tween := create_tween()
		for x in [14.0, -12.0, 8.0, 0.0]:
			tween.tween_property(self, "_shake", x, 0.05)
		return
	var c := customer
	_close()
	confirmed.emit(c)


func _cancel() -> void:
	var c := customer
	_close()
	cancelled.emit(c)


func _close() -> void:
	visible = false
	customer = null
