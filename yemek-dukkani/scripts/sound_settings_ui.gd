class_name SoundSettingsUI
extends ColorRect

## Ses Ayarları: en üstte tüm sesleri açıp kapatan ana düğme, altında her ses
## kategorisi için (müzik, kasa, mutfak, müşteriler, temizlikçi...) açma/kapama
## ve ses düzeyi kaydırıcısı. Kaydırıcı bırakılınca o kategoriden örnek ses çalar.
## Ayarlar Saves'e kaydedilir, oyun yeniden açılınca da geçerlidir.

signal closed

## Kaydırıcı bırakılınca çalan örnek ses (müzik zaten çalıyor)
const PREVIEW := {
	"ui": "approve", "register": "kaching", "kitchen": "sizzle_start",
	"customers": "door_bell", "cleaner": "spray", "street": "car_pass",
}

var _master: Button
## kategori -> { "toggle": Button, "slider": HSlider, "percent": Label, "card": Control }
var _rows := {}


func _ready() -> void:
	color = Color(0.08, 0.05, 0.03, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(UiKit.badge_rect("volume-2", UiKit.BLUE, 56))
	var title := UiKit.label("Ses Ayarları", 34, UiKit.TEXT, 900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	UiKit.set_icon(close, "x", 30)
	UiKit.candy(close, UiKit.NEUTRAL, UiKit.TEXT)
	close.custom_minimum_size = Vector2(64, 64)
	close.pressed.connect(_close)
	head.add_child(close)

	_master = Button.new()
	_master.custom_minimum_size = Vector2(0, 70)
	_master.add_theme_font_size_override("font_size", 24)
	_master.pressed.connect(func() -> void:
		Saves.set_setting("sound", not Saves.settings["sound"])
		_refresh()
	)
	v.add_child(_master)

	for cat in Sfx.CATEGORIES:
		v.add_child(_category_row(cat))
	_refresh()

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func _category_row(cat: String) -> Control:
	var info: Array = Sfx.CATEGORIES[cat]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(UiKit.badge_rect(info[1], UiKit.ORANGE, 48))
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 2)
	row.add_child(middle)
	var top := HBoxContainer.new()
	middle.add_child(top)
	var name_label := UiKit.label(info[0], 21, UiKit.TEXT, 900)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var percent := UiKit.label("", 19, UiKit.MUTED, 900)
	top.add_child(percent)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.custom_minimum_size = Vector2(0, 40)
	_style_slider(slider)
	slider.value = Sfx.category(cat)["vol"] * 100.0
	slider.value_changed.connect(func(value: float) -> void:
		Sfx.set_category(cat, Sfx.category(cat)["on"], value / 100.0)
		_refresh()
	)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		if PREVIEW.has(cat):
			Sfx.play(PREVIEW[cat])
	)
	middle.add_child(slider)
	var toggle := Button.new()
	toggle.custom_minimum_size = Vector2(112, 60)
	toggle.add_theme_font_size_override("font_size", 19)
	toggle.pressed.connect(func() -> void:
		var entry := Sfx.category(cat)
		Sfx.set_category(cat, not entry["on"], entry["vol"])
		_refresh()
		if not entry["on"] and PREVIEW.has(cat):
			Sfx.play(PREVIEW[cat])
	)
	row.add_child(toggle)
	_rows[cat] = { "toggle": toggle, "slider": slider, "percent": percent, "card": card }
	return card


## Kalın, turuncu dolgulu, parmakla kolay tutulan kaydırıcı.
static func _style_slider(slider: HSlider) -> void:
	var track := UiKit.flat(Color("#eadfd3"), 8, 0)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	var fill := UiKit.flat(UiKit.ORANGE, 8, 0)
	fill.content_margin_top = 7
	fill.content_margin_bottom = 7
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture()
	for key in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(key, knob)


static var _knob: Texture2D


## Beyaz, turuncu kenarlı yuvarlak tutamaç.
static func _knob_texture() -> Texture2D:
	if _knob:
		return _knob
	var size := 34
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var color := Color(0, 0, 0, 0)
			if d <= c:
				color = UiKit.ORANGE if d > c - 4.0 else Color.WHITE
				color.a = clampf(c - d + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, color)
	_knob = ImageTexture.create_from_image(image)
	return _knob


func _refresh() -> void:
	var all_on: bool = Saves.settings["sound"]
	_master.text = "Tüm Sesler: Açık" if all_on else "Tüm Sesler: Kapalı"
	UiKit.set_icon(_master, "volume-2" if all_on else "volume-x", 30)
	UiKit.candy(_master, UiKit.BLUE if all_on else UiKit.NEUTRAL, Color.WHITE if all_on else UiKit.TEXT)
	for cat in _rows:
		var entry := Sfx.category(cat)
		var row: Dictionary = _rows[cat]
		var on: bool = entry["on"]
		(row["percent"] as Label).text = "%d%%" % roundi(entry["vol"] * 100.0) if on else "Kapalı"
		var toggle: Button = row["toggle"]
		toggle.text = "Açık" if on else "Kapalı"
		UiKit.set_icon(toggle, "volume-2" if on else "volume-x", 22)
		UiKit.candy(toggle, UiKit.GREEN if on else UiKit.NEUTRAL, Color.WHITE if on else UiKit.TEXT)
		(row["slider"] as HSlider).editable = on
		# Kapalı kategori ve kapalı ana ses soluk görünür
		(row["card"] as Control).modulate.a = 1.0 if on and all_on else 0.55


func _close() -> void:
	closed.emit()
	queue_free()
