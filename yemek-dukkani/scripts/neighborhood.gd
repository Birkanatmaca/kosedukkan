class_name Neighborhood
extends Node3D

## Mahalle: dükkanımızın iki yanında bitişik komşu dükkanlar (Branches.LOTS).
## Her binanın üç hali var: komşu şirket açık (kendi renkli tentesi ve tabelası),
## kapanıp satılık (kepenk inik, "SATILIK" tabelası) ya da bizim (kırmızı
## tabelamız). Bitişik komşu salona katıldıysa bina gizlenir, yerine Shop'un
## birleşik salonu görünür.
## Oyuncu "Mahalle"ye çıkınca karakteriyle kaldırımda yürür; binalara dokununca
## önüne gidip bakar. Dokunma alanları sadece yürürken açıktır.

signal ground_tapped(point: Vector3)
signal lot_tapped(lot: int)
signal home_tapped

## Kaldırımda yürünen çizgi ve sınırlar
const WALK_Z := Street.SIDEWALK_Z
const WALK_X := 29.0
const FACADE_Z := -10.2
const WIDTH := 11.9
const DEPTH := 12.4
const HEIGHTS := [0.0, 6.6, 7.4, 8.0, 6.2]
## Yürürken dokunma ışını yalnızca bu fizik katmanına bakar.
const LAYER := 2
const OUR_RED := Color("#e8553e")

var _active := false
var _ground: StaticBody3D
var _door: StaticBody3D
## lot -> parçalar (bkz. _build_lot)
var _lots := {}
var _home_sign: Label3D


func _ready() -> void:
	var depth := FACADE_Z - Street.ROAD_NEAR
	_ground = Util.collider_box(self, Vector3(WALK_X * 2.0 + 2.0, 0.1, depth), Vector3(0, -0.05, (FACADE_Z + Street.ROAD_NEAR) / 2.0))
	_ground.set_meta("tap_at", func(point: Vector3) -> void: ground_tapped.emit(point))
	for lot in range(1, Branches.LOTS.size()):
		_build_lot(lot)
	_build_home()
	refresh()


## Dokunma alanlarını açar / kapatır.
func set_active(active: bool) -> void:
	_active = active
	_update_layers()


func _update_layers() -> void:
	_ground.collision_layer = LAYER if _active else 0
	_door.collision_layer = LAYER if _active else 0
	for lot in _lots:
		var root: Node3D = _lots[lot]["root"]
		(_lots[lot]["body"] as StaticBody3D).collision_layer = LAYER if _active and root.visible else 0


## Binaları duruma göre günceller (satın alınca, komşu kapanınca, ad değişince).
func refresh() -> void:
	for lot in _lots:
		var refs: Dictionary = _lots[lot]
		var shown := Branches.shown_lot(lot)
		# Salona katılan komşu: Shop'un birleşik salonu görünür; üstünde bizim tabela.
		var merged := Branches.merged(shown) and Branches.active_lot() == 0
		(refs["root"] as Node3D).visible = not merged
		(refs["merged"] as Node3D).visible = merged
		(refs["merged_sign"] as Label3D).text = Util.upper_tr(Branches.home_name())
		var state := Branches.state(shown) if shown != 0 else "owned"
		var data: Dictionary = Branches.LOTS[lot]
		var sign: Label3D = refs["sign"]
		var sub: Label3D = refs["sub"]
		var board: MeshInstance3D = refs["board"]
		(refs["shutters"] as Node3D).visible = state == "for_sale"
		(refs["open_sign"] as Node3D).visible = state != "for_sale"
		(refs["sale"] as Node3D).visible = state == "for_sale"
		match state:
			"owned":
				sign.text = Util.upper_tr(Branches.name_at(lot))
				board.material_override = Util.material(OUR_RED)
				sub.text = "SENİN DÜKKANIN"
				sub.modulate = Color("#fff1c4")
				_set_awning(refs, OUR_RED)
			"for_sale":
				sign.text = "SATILIK"
				board.material_override = Util.material(Color("#fbf7f0"))
				sub.text = "₺%s  •  Sv %d" % [money_text(data["price"]), data["level"]]
				sub.modulate = Color("#3a2a20")
				_set_awning(refs, Color("#8a8f99"))
			_:
				sign.text = Util.upper_tr(data["company"])
				board.material_override = Util.material(data["brand"])
				sub.text = Util.upper_tr(data["kind"])
				sub.modulate = Color("#fff1c4")
				_set_awning(refs, data["brand"])
		sign.modulate = Color("#d6452f") if state == "for_sale" else Color.WHITE
		sign.font_size = 120 if sign.text.length() <= 14 else 90
	_home_sign.text = Util.upper_tr(Branches.name_at(0))
	_update_layers()


func _set_awning(refs: Dictionary, color: Color) -> void:
	var stripes: Array = refs["stripes"]
	for i in stripes.size():
		(stripes[i] as MeshInstance3D).material_override = Util.material(color if i % 2 == 0 else Color("#fbf7f0"))


## 12000 -> "12.000"
static func money_text(value: int) -> String:
	var s := str(value)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


func _build_lot(lot: int) -> void:
	var data: Dictionary = Branches.LOTS[lot]
	var root := Node3D.new()
	root.position = Vector3(data["x"], 0, FACADE_Z)
	add_child(root)
	var color: Color = data["color"]
	var height: float = HEIGHTS[lot]
	# Bina gövdesi (cephe z=0, arkaya doğru +z), saçak ve kat ayrımı
	root.add_child(Util.no_shadow(Util.box(Vector3(WIDTH, height, DEPTH), color, Vector3(0, height / 2.0, DEPTH / 2.0))))
	root.add_child(Util.no_shadow(Util.box(Vector3(WIDTH + 0.1, 0.35, 0.5), color.darkened(0.3), Vector3(0, height, -0.1))))
	root.add_child(Util.no_shadow(Util.box(Vector3(WIDTH, 0.18, 0.16), color.darkened(0.15), Vector3(0, 4.3, -0.05))))
	# Zemin kat vitrini: koyu çerçeve, iki büyük cam (içerisi sıcak ışıklı), ortada kapı
	root.add_child(Util.box(Vector3(10.6, 3.0, 0.1), Color("#4a3226"), Vector3(0, 1.5, -0.05)))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#f3d9a4")
	glass.emission_enabled = true
	glass.emission = Color("#f0c27a")
	glass.emission_energy_multiplier = 0.35
	for x in [-3.0, 3.0]:
		root.add_child(Util.box(Vector3(4.0, 2.0, 0.05), glass, Vector3(x, 1.45, -0.11)))
		root.add_child(Util.box(Vector3(0.06, 2.0, 0.07), Color("#4a3226"), Vector3(x, 1.45, -0.13)))
	root.add_child(Util.box(Vector3(1.4, 2.4, 0.05), Color("#6e8ea3"), Vector3(0, 1.2, -0.11)))
	root.add_child(Util.box(Vector3(0.08, 2.4, 0.07), Color("#4a3226"), Vector3(0, 1.2, -0.13)))
	# Üst kat pencereleri
	for x in [-3.8, -1.25, 1.25, 3.8]:
		root.add_child(Util.box(Vector3(1.2, 1.4, 0.05), Color("#5b7489"), Vector3(x, 5.4, -0.03)))
		root.add_child(Util.box(Vector3(1.4, 0.08, 0.22), Color("#f4efe6"), Vector3(x, 4.68, -0.1)))
	# Çizgili tente (rengi duruma göre)
	var stripes: Array = []
	for i in 10:
		var stripe := Util.no_shadow(Util.box(Vector3(10.8 / 10.0, 0.06, 1.1), Color.WHITE,
			Vector3(-5.4 + (i + 0.5) * 10.8 / 10.0, 3.15, -0.5)))
		stripe.rotation_degrees.x = 16
		root.add_child(stripe)
		stripes.append(stripe)
	# Tabela (tentenin üstünde)
	var board := Util.box(Vector3(8.0, 0.95, 0.12), Color.WHITE, Vector3(0, 3.78, -0.08))
	root.add_child(board)
	var sign := Util.label3d("", 120, Color.WHITE, Vector3(0, 3.86, -0.16))
	sign.rotation_degrees.y = 180
	root.add_child(sign)
	var sub := Util.label3d("", 50, Color.WHITE, Vector3(0, 3.47, -0.16))
	sub.rotation_degrees.y = 180
	root.add_child(sub)
	# Kapının yanında yeşil "AÇIK" yazısı
	var open_sign := Util.label3d("AÇIK", 60, Color("#5be37a"), Vector3(1.25, 2.15, -0.17))
	open_sign.rotation_degrees.y = 180
	open_sign.outline_size = 12
	open_sign.outline_modulate = Color("#103018")
	root.add_child(open_sign)
	# Satılıkken: kepenkler inik, kepenklerde çapraz "SATILIK" bantları
	var shutters := Node3D.new()
	root.add_child(shutters)
	for x in [-3.0, 0.0, 3.0]:
		var w := 1.5 if x == 0.0 else 4.1
		shutters.add_child(Util.box(Vector3(w, 2.5, 0.06), Color("#9aa0a8"), Vector3(x, 1.25, -0.16)))
		for k in 9:
			shutters.add_child(Util.box(Vector3(w, 0.03, 0.08), Color("#80868f"), Vector3(x, 0.2 + k * 0.27, -0.18)))
	var sale := Node3D.new()
	root.add_child(sale)
	for x in [-3.0, 3.0]:
		var band := Util.no_shadow(Util.box(Vector3(4.3, 0.42, 0.03), Color("#d6452f"), Vector3(x, 1.45, -0.22)))
		band.rotation_degrees.z = 16.0 if x < 0 else -16.0
		sale.add_child(band)
		var text := Util.label3d("SATILIK", 70, Color.WHITE, Vector3(x, 1.45, -0.24))
		text.rotation_degrees = Vector3(0, 180, 16.0 if x > 0 else -16.0)
		sale.add_child(text)
	var body := Util.collider_box(root, Vector3(WIDTH, 4.4, 1.4), Vector3(0, 2.2, -0.5))
	body.set_meta("tap", func() -> void: lot_tapped.emit(lot))
	# Salona katılınca: birleşik salonun cephesinde bizim tabela ve kırmızı tente
	var merged := Node3D.new()
	merged.position = root.position
	add_child(merged)
	merged.add_child(Util.box(Vector3(6.4, 0.7, 0.1), OUR_RED, Vector3(0, 3.6, -0.07)))
	var merged_sign := Util.label3d("", 90, Color.WHITE, Vector3(0, 3.6, -0.14))
	merged_sign.rotation_degrees.y = 180
	merged.add_child(merged_sign)
	for i in 10:
		var stripe := Util.no_shadow(Util.box(Vector3(10.8 / 10.0, 0.06, 0.9), OUR_RED if i % 2 == 0 else Color("#fbf7f0"),
			Vector3(-5.4 + (i + 0.5) * 10.8 / 10.0, 3.05, -0.45)))
		stripe.rotation_degrees.x = 16
		merged.add_child(stripe)
	_lots[lot] = { "root": root, "body": body, "sign": sign, "sub": sub, "board": board, "stripes": stripes,
		"shutters": shutters, "sale": sale, "open_sign": open_sign, "merged": merged, "merged_sign": merged_sign }


## Kendi dükkanımızın dışarıdan görünen tabelası ve kapısına dokunma alanı.
func _build_home() -> void:
	var board := Util.box(Vector3(4.6, 0.75, 0.1), OUR_RED, Vector3(0, 3.55, FACADE_Z - 0.07))
	add_child(board)
	_home_sign = Util.label3d("", 96, Color.WHITE, Vector3(0, 3.55, FACADE_Z - 0.14))
	_home_sign.rotation_degrees.y = 180
	add_child(_home_sign)
	_door = Util.collider_box(self, Vector3(2.0, 2.6, 0.8), Vector3(0, 1.3, FACADE_Z - 0.4))
	_door.set_meta("tap", func() -> void: home_tapped.emit())
