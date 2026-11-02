class_name Icons
extends RefCounted

## İkonlar: Lucide çizgi ikonları (beyaz; Button/TextureRect rengiyle boyanır),
## renkli daire içinde "rozet" ikonlar (3D'de kafaların üstünde) ve oyundaki
## 3D modellerden çekilmiş yiyecek ikonları.

static var _cache := {}
static var _food := {}


## Beyaz çizgi ikon. size: piksel boyu.
static func tex(icon: String, size := 48) -> Texture2D:
	var key := "%s:%d" % [icon, size]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_render(icon, size))
	return _cache[key]


## Renkli daire üstünde beyaz ikon (3D sahnede ve kartlarda durum göstergesi).
static func badge(icon: String, color: Color, size := 96) -> Texture2D:
	var key := "badge:%s:%s:%d" % [icon, color.to_html(), size]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	var radius := size * 0.5 - 2.0
	var ring := color.darkened(0.25)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= radius:
				# Kenarda koyu halka, içi düz renk; kenar yumuşatılır.
				var c := ring if d > radius - size * 0.07 else color
				c.a = clampf(radius - d + 0.5, 0.0, 1.0)
				img.set_pixel(x, y, c)
	var icon_size := int(size * 0.56)
	var icon_img := _render(icon, icon_size)
	var offset := Vector2i((size - icon_size) / 2, (size - icon_size) / 2)
	img.blend_rect(icon_img, Rect2i(Vector2i.ZERO, icon_img.get_size()), offset)
	var texture := ImageTexture.create_from_image(img)
	_cache[key] = texture
	return texture


## Başının üstünde duran rozet (her zaman kameraya bakar).
static func sprite(texture: Texture2D, height := 2.0) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = texture
	s.pixel_size = 0.0035
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.position = Vector3(0, height, 0)
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


static func register_food(id: String, texture: Texture2D) -> void:
	_food[id] = texture


## 3D modelden çekilmiş yiyecek ikonu (FoodStudio üretir).
static func food(id: String) -> Texture2D:
	return _food.get(id)


static func _render(icon: String, size: int) -> Image:
	var img := Image.new()
	var svg: String = IconsData.SVG.get(icon, IconsData.SVG["circle-alert"])
	img.load_svg_from_string(svg, size / 24.0)
	img.convert(Image.FORMAT_RGBA8)
	return img
