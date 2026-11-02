class_name TutorialUI
extends Control

## İlk müşteride adım adım anlatan "Usta". Her adım oyuncu o işi yapınca
## kendiliğinden ilerler; gidilecek buton nabız gibi parlar. "Geç" ile atlanır.

const C_MUTED := Color("#8a7a72")
const STEPS := [
	"Hoş geldin patron! İlk müşterin kapıdan giriyor. Kasaya gelince başının üstündeki kartta ne istediği yazacak.",
	"Müşteri köfte istiyor. Pişirmek için alttan Mutfak'a geç.",
	"Alttaki Köfte butonuna dokun, köfte ızgaraya konsun.",
	"Köfte pişiyor! Üstündeki çubuk YEŞİL olunca köfteye dokunup al. Geç kalırsan yanar!",
	"Köfte hazır! Şimdi alttan Dükkan'a dön.",
	"Müşterinin kartındaki 'Servis Et' butonuna bas.",
	"Ödemeyi al: kartla öderse 'Kartı Okut'a bas, nakit verirse çekmeceden paraüstünü seçip ver.",
	"Müşteri tepsisini alıp masasına oturdu. Yemeği bitince masa kirlenir: üstünde sünger işareti olan masaya dokunup temizle.",
	"Harika iş! Malzemen azalınca Market'ten al, Personel sekmesinden garson tutabilirsin. Gün 22:00'de biter. Bol kazançlar!",
]

var hud: Hud

var _text: Label
var _counter: Label
var _button: Button
var _panel: PanelContainer
var _seen_dirty := false
var _t := 0.0
var _pulsing: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Util.style(Color("#fffaf0"), 24, 16, true))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_panel.offset_left = 20
	_panel.offset_right = -20
	_panel.offset_top = 130
	_panel.offset_bottom = 130
	add_child(_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	_panel.add_child(h)
	var avatar := UiKit.badge_rect("chef-hat", UiKit.ORANGE, 76)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(avatar)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	_counter = Label.new()
	_counter.add_theme_color_override("font_color", C_MUTED)
	_counter.add_theme_font_size_override("font_size", 19)
	v.add_child(_counter)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(440, 0)
	_text.add_theme_font_size_override("font_size", 24)
	v.add_child(_text)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(110, 60)
	_button.add_theme_font_size_override("font_size", 22)
	_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_finish)
	h.add_child(_button)
	GameState.tutorial_changed.connect(_show_step)
	_show_step(GameState.tutorial_step)


func _process(delta: float) -> void:
	_t += delta
	var step := GameState.tutorial_step
	if _check(step):
		GameState.advance_tutorial(step + 1)
	_pulse()


## Adımın tamamlanıp tamamlanmadığı.
func _check(step: int) -> bool:
	var main := hud.main
	match step:
		0:
			for c in main.shop.spots:
				if c and c.state == ShopCustomer.State.WAITING:
					return true
		1:
			return main.screen == Main.KITCHEN and not main.transitioning
		2:
			for slot in main.kitchen.slots:
				if not slot.is_empty():
					return true
		3:
			return GameState.available("kofte") > 0
		4:
			return main.screen == Main.SHOP and not main.transitioning
		5:
			return main.shop.paying != null
		6:
			return GameState.day_stats["served"] > 0
		7:
			var dirty := false
			for table in main.shop.tables:
				if table["dirty"]:
					dirty = true
			if dirty:
				_seen_dirty = true
			return _seen_dirty and not dirty
	return false


func _show_step(step: int) -> void:
	if step < 0 or step >= STEPS.size():
		queue_free()
		return
	_text.text = STEPS[step]
	_counter.text = "USTA  •  Adım %d / %d" % [step + 1, STEPS.size()]
	var last := step == STEPS.size() - 1
	_button.text = "Başla!" if last else "Geç"
	_style_button(Color("#ff7a45") if last else Color("#efe6dd"), Color.WHITE if last else Color("#3d2c29"))
	if step > 0:
		Sfx.play("pop")
	_panel.pivot_offset = Vector2(340, 60)
	_panel.scale = Vector2(0.94, 0.94)
	_panel.create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Gidilmesi gereken butonu nabız gibi parlatır.
func _pulse() -> void:
	var target: Control = null
	match GameState.tutorial_step:
		1: target = hud.nav_button(Main.KITCHEN)
		2: target = hud.kitchen_button("kofte")
		4: target = hud.nav_button(Main.SHOP)
	if _pulsing and _pulsing != target:
		_pulsing.modulate = Color.WHITE
	_pulsing = target
	if target:
		var k := absf(sin(_t * 5.0))
		target.modulate = Color.WHITE.lerp(Color(1.5, 1.3, 0.7), k)


func _finish() -> void:
	if _pulsing:
		_pulsing.modulate = Color.WHITE
	GameState.advance_tutorial(-1)
	Sfx.play("approve")


func _style_button(bg: Color, fg: Color) -> void:
	UiKit.candy(_button, bg, fg)
