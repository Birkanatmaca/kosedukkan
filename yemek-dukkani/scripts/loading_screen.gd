class_name LoadingScreen
extends Control

## Açılış / yükleme ekranı: arkada lahmacunlu fırın sahnesinin bulanık hali,
## ortada sahnenin kendisi (kenarları arka plana yumuşakça karışır), altında
## büyük oyun adı, kısa slogan ve dolan yükleme çubuğu.
## Telefonun açılış görseli (assets/brand/splash.png) bu ekranın ilk karesidir
## (tools/make_splash.gd ile üretilir); oyun açılınca Main bu ekranı aynı yerde
## gösterip çubuğu doldurur ve yumuşakça kaybolur, geçiş fark edilmez.

const ART := "res://assets/brand/uygulama-gorseli-firin-kurye.png"
const BG_TOP := Color("#2a0f08")
const BG_BOTTOM := Color("#8a2414")
const BAR_FILL := Color("#ffc93c")
const BAR_FILL_END := Color("#ff8a1f")

## 0–1 arası doluluk
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_layout()
var status := "Yükleniyor…":
	set(value):
		status = value
		if _status:
			_status.text = value

var _bg: TextureRect
var _art: TextureRect
var _title: Label
var _slogan: Label
var _track: Panel
var _fill: Panel
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture: Texture2D = load(ART)

	# Alt katman: koyu kırmızı-kahve dikey geçiş
	var base := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, BG_TOP)
	grad.set_color(1, BG_BOTTOM)
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	base.texture = gtex
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)

	# Sahnenin bulanık, kısık hali tüm ekranı kaplar
	_bg = TextureRect.new()
	# Bulanıklık: görsel çok küçültülüp yumuşak filtreyle büyütülür (pürüzsüz olur).
	var small := texture.get_image()
	small.resize(24, 24, Image.INTERPOLATE_LANCZOS)
	_bg.texture = ImageTexture.create_from_image(small)
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.material = _shader_material("""
shader_type canvas_item;
void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	// Sıcak ve koyu: yazılar okunsun; alta doğru biraz daha koyulaşır
	c = mix(c, vec3(0.30, 0.07, 0.03), 0.5 + 0.2 * UV.y);
	COLOR = vec4(c * 0.9, 1.0);
}
""")
	add_child(_bg)

	# Sahnenin kendisi: kenarları ve altı yumuşakça kaybolur
	_art = TextureRect.new()
	_art.texture = texture
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.material = _shader_material("""
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float side = smoothstep(0.0, 0.07, UV.x) * smoothstep(1.0, 0.93, UV.x);
	float top = smoothstep(0.0, 0.06, UV.y);
	float bottom = smoothstep(1.0, 0.8, UV.y);
	COLOR = vec4(c.rgb, c.a * side * top * bottom);
}
""")
	add_child(_art)

	_title = Label.new()
	_title.text = "KÖŞE DÜKKAN"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", UiKit.font(900))
	_title.add_theme_color_override("font_color", Color("#fff8ec"))
	_title.add_theme_color_override("font_outline_color", Color("#7a1d0e"))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	add_child(_title)

	_slogan = Label.new()
	_slogan.text = "Mahallenin lezzet durağı"
	_slogan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slogan.add_theme_font_override("font", UiKit.font(800))
	_slogan.add_theme_color_override("font_color", Color("#ffd9a8"))
	add_child(_slogan)

	_track = Panel.new()
	add_child(_track)
	_fill = Panel.new()
	_track.add_child(_fill)

	_status = Label.new()
	_status.text = status
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_override("font", UiKit.font(800))
	_status.add_theme_color_override("font_color", Color(1, 0.95, 0.88, 0.85))
	add_child(_status)

	resized.connect(_layout)
	_layout()


## Her şey ekran genişliğine göre ölçeklenir (telefon boyu fark etmez).
func _layout() -> void:
	if not _art:
		return
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var u := w / 1080.0
	# Sahne: tam genişlikte kare, dikeyde biraz yukarıda
	var art_size := w * 1.08
	# Sahne + yazılar + çubuk bütün olarak dikeyde ortalanır (biraz yukarıda).
	var block := art_size * 0.86 + 440.0 * u
	var art_top := maxf((h - block) * 0.42, 0.0)
	_art.position = Vector2((w - art_size) * 0.5, art_top)
	_art.size = Vector2(art_size, art_size)

	var y := art_top + art_size * 0.86
	_title.add_theme_font_size_override("font_size", int(132 * u))
	_title.add_theme_constant_override("outline_size", int(30 * u))
	_title.add_theme_constant_override("shadow_offset_y", int(10 * u))
	_title.add_theme_constant_override("shadow_outline_size", int(30 * u))
	_title.position = Vector2(0, y)
	_title.size = Vector2(w, 170 * u)
	y += 170 * u
	_slogan.add_theme_font_size_override("font_size", int(46 * u))
	_slogan.position = Vector2(0, y)
	_slogan.size = Vector2(w, 64 * u)
	y += 150 * u

	var bar_w := 640.0 * u
	var bar_h := 34.0 * u
	_track.position = Vector2((w - bar_w) * 0.5, y)
	_track.size = Vector2(bar_w, bar_h)
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0, 0, 0, 0.35)
	track_style.border_color = Color(1, 0.9, 0.75, 0.5)
	track_style.set_border_width_all(maxi(2, int(3 * u)))
	track_style.set_corner_radius_all(int(bar_h))
	_track.add_theme_stylebox_override("panel", track_style)
	var inset := 5.0 * u
	var fill_w := maxf((bar_w - inset * 2.0) * progress, bar_h - inset * 2.0)
	_fill.position = Vector2(inset, inset)
	_fill.size = Vector2(fill_w, bar_h - inset * 2.0)
	_fill.visible = progress > 0.0
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = BAR_FILL.lerp(BAR_FILL_END, progress)
	fill_style.set_corner_radius_all(int(bar_h))
	_fill.add_theme_stylebox_override("panel", fill_style)
	y += bar_h + 28 * u
	_status.add_theme_font_size_override("font_size", int(38 * u))
	_status.position = Vector2(0, y)
	_status.size = Vector2(w, 54 * u)


func _shader_material(code: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = code
	return mat
