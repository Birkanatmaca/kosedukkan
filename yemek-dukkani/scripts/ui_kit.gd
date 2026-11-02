class_name UiKit
extends RefCounted

## Arayüzün ortak görünümü: renk paleti, Nunito font, mobil oyunlardaki gibi
## altı kalın "şeker" butonlar (basınca içe göçer), kartlar ve paneller.

const TEXT := Color("#3b2a25")
const MUTED := Color("#9a8a80")
const ORANGE := Color("#ff7a3d")
const GREEN := Color("#34c26a")
const YELLOW := Color("#ffc23c")
const PURPLE := Color("#7c5cff")
const RED := Color("#f25c5c")
const BLUE := Color("#3f9be0")
const NEUTRAL := Color("#efe6dd")
const CARD := Color("#fff6ec")
const PANEL := Color("#ffffff")

const FONT_PATH := "res://ui/fonts/Nunito.ttf"

static var _fonts := {}


## Nunito'nun istenen kalınlığı (400 normal, 700 kalın, 900 en kalın).
static func font(weight := 700) -> Font:
	if not _fonts.has(weight):
		var variation := FontVariation.new()
		variation.base_font = load(FONT_PATH)
		variation.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): weight }
		_fonts[weight] = variation
	return _fonts[weight]


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font(700)
	theme.default_font_size = 28
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_font("font", "Button", font(800))
	_apply_candy(theme, ORANGE, Color.WHITE)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_constant("icon_max_width", "Button", 40)
	theme.set_constant("h_separation", "Button", 10)
	theme.set_stylebox("background", "ProgressBar", flat(Color("#ece3da"), 8, 0))
	theme.set_stylebox("fill", "ProgressBar", flat(GREEN, 8, 0))
	theme.set_font("font", "LineEdit", font(800))
	return theme


## Beyaz, yumuşak gölgeli panel.
static func panel_style(radius := 28) -> StyleBoxFlat:
	var s := flat(PANEL, radius, 20)
	s.shadow_color = Color(0.24, 0.15, 0.1, 0.16)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 6)
	s.border_color = Color("#f1e7dd")
	s.set_border_width_all(1)
	return s


## Krem kart (liste satırları, ürün kartları).
static func card_style(color := CARD, radius := 22) -> StyleBoxFlat:
	var s := flat(color, radius, 14)
	s.border_color = color.darkened(0.06)
	s.border_width_bottom = 4
	return s


static func flat(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s


## Butona şeker görünümü verir: altında koyu "kalınlık", basınca aşağı göçer.
## outline > 0 ise seçili olduğunu gösteren çerçeve çizilir.
static func candy(btn: Button, color: Color, text_color := Color.WHITE, outline := 0) -> void:
	var depth := 7
	var states := {
		"normal": _candy_box(color, depth, 0, outline),
		"hover": _candy_box(color.lightened(0.05), depth, 0, outline),
		"pressed": _candy_box(color.darkened(0.06), 2, depth - 2, outline),
		"hover_pressed": _candy_box(color.darkened(0.06), 2, depth - 2, outline),
		"disabled": _candy_box(color.lerp(Color("#d8d0c8"), 0.65), depth, 0, 0),
	}
	for state in states:
		btn.add_theme_stylebox_override(state, states[state])
	var disabled_text := text_color.lerp(Color("#ffffff"), 0.3) if text_color != TEXT else MUTED
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(key, text_color)
	btn.add_theme_color_override("font_disabled_color", disabled_text)
	for key in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		btn.add_theme_color_override(key, text_color)
	btn.add_theme_color_override("icon_disabled_color", disabled_text)


static func _apply_candy(theme: Theme, color: Color, text_color: Color) -> void:
	theme.set_stylebox("normal", "Button", _candy_box(color, 7, 0, 0))
	theme.set_stylebox("hover", "Button", _candy_box(color.lightened(0.05), 7, 0, 0))
	theme.set_stylebox("pressed", "Button", _candy_box(color.darkened(0.06), 2, 5, 0))
	theme.set_stylebox("hover_pressed", "Button", _candy_box(color.darkened(0.06), 2, 5, 0))
	theme.set_stylebox("disabled", "Button", _candy_box(Color("#d8d0c8"), 7, 0, 0))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(key, "Button", text_color)
	for key in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		theme.set_color(key, "Button", text_color)


static func _candy_box(color: Color, depth: int, push: int, outline: int) -> StyleBoxFlat:
	var s := flat(color, 20, 14)
	s.border_color = color.darkened(0.28)
	s.border_width_bottom = depth
	# Basılıyken içerik aşağı kayar; toplam yükseklik aynı kalır.
	s.content_margin_top = 12 + push
	s.content_margin_bottom = 12
	if outline > 0:
		s.border_color = TEXT
		s.border_width_left = outline
		s.border_width_right = outline
		s.border_width_top = outline
		s.border_width_bottom = maxi(depth, outline)
	return s


## Butona ikon ekler (ikon yazının solunda ya da üstünde).
static func set_icon(btn: Button, icon: String, size := 40, on_top := false) -> void:
	btn.icon = Icons.tex(icon, size)
	btn.expand_icon = false
	btn.add_theme_constant_override("icon_max_width", size)
	if on_top:
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Boyanmış ikon (TextureRect).
static func icon_rect(icon: String, color: Color, size := 32) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = Icons.tex(icon, size * 2)
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Renkli yuvarlak rozet (TextureRect).
static func badge_rect(icon: String, color: Color, size := 56) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = Icons.badge(icon, color, 128)
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func food_rect(id: String, size := 56) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = Icons.food(id)
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Etiket: renk, boyut ve kalınlıkla.
static func label(text: String, size := 26, color := TEXT, weight := 700) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if weight != 700:
		l.add_theme_font_override("font", font(weight))
	return l
