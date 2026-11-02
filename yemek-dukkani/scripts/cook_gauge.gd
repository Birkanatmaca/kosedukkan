class_name CookGauge
extends Control

## Pişen ürünün üstünde duran kıvam çubuğu: kırmızı çiğ, turuncu az / fazla,
## yeşil tam kıvam, koyu yanık. Beyaz işaret o anki pişme oranını gösterir.

const W := 88.0
const H := 14.0
const ZONES := [
	[0.0, Items.RAW_LIMIT, Color("#e05555")],
	[Items.RAW_LIMIT, Items.UNDER_LIMIT, Color("#f0a540")],
	[Items.UNDER_LIMIT, Items.PERFECT_LIMIT, Color("#3fbf6f")],
	[Items.PERFECT_LIMIT, Items.BURNT_LIMIT, Color("#f0a540")],
	[Items.BURNT_LIMIT, Items.MAX_DONENESS, Color("#3a2a22")],
]

var slot: CookSlot


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W, H)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-3, -3, W + 6, H + 6), Color(0, 0, 0, 0.45))
	for zone in ZONES:
		var x0: float = zone[0] / Items.MAX_DONENESS * W
		var x1: float = zone[1] / Items.MAX_DONENESS * W
		draw_rect(Rect2(x0, 0, x1 - x0, H), zone[2])

	var x := clampf(slot.doneness() / Items.MAX_DONENESS, 0.0, 1.0) * W
	draw_rect(Rect2(x - 3, -6, 6, H + 12), Color.BLACK)
	draw_rect(Rect2(x - 1.5, -4.5, 3, H + 9), Color.WHITE)

	var text := _status()
	var font := ThemeDB.fallback_font
	var font_size := 22
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(W * 0.5 - text_w * 0.5, -12)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _status() -> String:
	var d := slot.doneness()
	if d < Items.RAW_LIMIT:
		return "Çiğ"
	match Items.quality_for(d):
		2: return "Az"
		5: return "Tamam!"
		3: return "Fazla"
	return "Yandı!"
