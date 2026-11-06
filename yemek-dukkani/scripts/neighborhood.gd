class_name Neighborhood
extends Node3D

## Mahalle: dükkanın önündeki kaldırım boyunca, iki yanda satılık dükkan
## binaları (Branches.LOTS). Oyuncu "Mahalle"ye çıkınca karakteriyle kaldırımda
## yürür; binalara dokununca önüne gidip bakar, satın alır ya da o dükkana geçer.
## Dokunma alanları sadece yürürken açıktır (dükkan içinden pencereye dokunmak
## yürüyüşü başlatmasın).

signal ground_tapped(point: Vector3)
signal lot_tapped(lot: int)
signal home_tapped

## Kaldırımda yürünen çizgi ve sınırlar
const WALK_Z := -11.4
const WALK_X := 28.0
const FACADE_Z := -10.2
const SIZE := Vector3(7.0, 7.0, 6.0)
## Yürürken dokunma ışını yalnızca bu fizik katmanına bakar.
const LAYER := 2

var _bodies: Array[StaticBody3D] = []
## lot -> { "sign": Label3D, "board": MeshInstance3D, "sub": Label3D, "sale": Node3D }
var _signs := {}
var _home_sign: Label3D


func _ready() -> void:
	var ground := Util.collider_box(self, Vector3(WALK_X * 2.0 + 2.0, 0.1, 2.6), Vector3(0, -0.05, -11.5))
	ground.set_meta("tap_at", func(point: Vector3) -> void: ground_tapped.emit(point))
	_bodies.append(ground)
	for lot in range(1, Branches.LOTS.size()):
		_build_lot(lot)
	_build_home()
	set_active(false)
	refresh()


## Dokunma alanlarını açar / kapatır.
func set_active(active: bool) -> void:
	for body in _bodies:
		body.collision_layer = LAYER if active else 0


## Tabelaları günceller (satın alınca, dükkan değişince, ad değişince).
func refresh() -> void:
	for lot in _signs:
		var refs: Dictionary = _signs[lot]
		var shown := Branches.shown_lot(lot)
		var owned := Branches.owned(shown)
		var data: Dictionary = Branches.LOTS[lot]
		(refs["sale"] as Node3D).visible = not owned
		var sign: Label3D = refs["sign"]
		var sub: Label3D = refs["sub"]
		if owned:
			sign.text = Util.upper_tr(Branches.name_at(lot))
			sign.modulate = Color.WHITE
			(refs["board"] as MeshInstance3D).material_override = Util.material(Color("#e8553e"))
			sub.text = "SENİN DÜKKANIN"
		else:
			sign.text = "SATILIK"
			sign.modulate = Color("#d6452f")
			(refs["board"] as MeshInstance3D).material_override = Util.material(Color("#fbf7f0"))
			sub.text = "₺%s  •  Sv %d" % [money_text(data["price"]), data["level"]]
		sign.font_size = 110 if sign.text.length() <= 14 else 80
	_home_sign.text = Util.upper_tr(Branches.name_at(0))


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
	# Bina gövdesi (cephe z=0, arkaya doğru +z)
	root.add_child(Util.no_shadow(Util.box(SIZE, color, Vector3(0, SIZE.y / 2.0, SIZE.z / 2.0))))
	root.add_child(Util.no_shadow(Util.box(Vector3(SIZE.x + 0.3, 0.3, SIZE.z + 0.3), color.darkened(0.25), Vector3(0, SIZE.y, SIZE.z / 2.0))))
	# Zemin kat vitrini: koyu çerçeve, iki cam, ortada kapı
	root.add_child(Util.box(Vector3(6.2, 2.9, 0.1), Color("#5a3a2a"), Vector3(0, 1.45, -0.05)))
	for x in [-1.85, 1.85]:
		root.add_child(Util.box(Vector3(2.1, 1.9, 0.05), Color("#7d9fb3"), Vector3(x, 1.45, -0.11)))
	root.add_child(Util.box(Vector3(1.2, 2.3, 0.05), Color("#3a2a20"), Vector3(0, 1.15, -0.11)))
	root.add_child(Util.sphere(0.05, Color("#e0b84a"), Vector3(0.4, 1.15, -0.16)))
	# Üst kat pencereleri
	for x in [-2.2, 0.0, 2.2]:
		root.add_child(Util.box(Vector3(1.1, 1.3, 0.05), Color("#5b7489"), Vector3(x, 5.0, -0.03)))
		root.add_child(Util.box(Vector3(1.3, 0.08, 0.2), Color("#f4efe6"), Vector3(x, 4.33, -0.08)))
	# Çizgili tente
	for i in 8:
		var stripe := Util.no_shadow(Util.box(Vector3(6.6 / 8.0, 0.06, 1.0), Color("#d6452f") if i % 2 == 0 else Color("#fbf7f0"),
			Vector3(-3.3 + (i + 0.5) * 6.6 / 8.0, 3.05, -0.45)))
		stripe.rotation_degrees.x = 14
		root.add_child(stripe)
	# Tabela (tentenin üstünde)
	var board := Util.box(Vector3(5.2, 0.85, 0.12), Color("#fbf7f0"), Vector3(0, 3.75, -0.08))
	root.add_child(board)
	var sign := Util.label3d("", 110, Color.WHITE, Vector3(0, 3.78, -0.16))
	sign.rotation_degrees.y = 180
	root.add_child(sign)
	var sub := Util.label3d("", 56, Color("#3a2a20"), Vector3(0, 3.42, -0.16))
	sub.rotation_degrees.y = 180
	sub.visible = true
	root.add_child(sub)
	# Satılıkken camlarda çapraz "SATILIK" bantları ve kapıda kilit
	var sale := Node3D.new()
	root.add_child(sale)
	for x in [-1.85, 1.85]:
		var band := Util.no_shadow(Util.box(Vector3(2.4, 0.32, 0.03), Color("#d6452f"), Vector3(x, 1.45, -0.15)))
		band.rotation_degrees.z = 24.0 if x < 0 else -24.0
		sale.add_child(band)
		var text := Util.label3d("SATILIK", 44, Color.WHITE, Vector3(x, 1.45, -0.17))
		text.rotation_degrees = Vector3(0, 180, 24.0 if x > 0 else -24.0)
		sale.add_child(text)
	var body := Util.collider_box(root, Vector3(SIZE.x, 4.2, 1.2), Vector3(0, 2.1, -0.4))
	body.set_meta("tap", func() -> void: lot_tapped.emit(lot))
	_bodies.append(body)
	_signs[lot] = { "sign": sign, "board": board, "sub": sub, "sale": sale }


## Kendi dükkanımızın dışarıdan görünen tabelası ve kapısına dokunma alanı.
func _build_home() -> void:
	var board := Util.box(Vector3(4.6, 0.75, 0.1), Color("#e8553e"), Vector3(0, 3.4, FACADE_Z - 0.07))
	add_child(board)
	_home_sign = Util.label3d("", 96, Color.WHITE, Vector3(0, 3.4, FACADE_Z - 0.14))
	_home_sign.rotation_degrees.y = 180
	add_child(_home_sign)
	var door := Util.collider_box(self, Vector3(2.0, 2.6, 0.8), Vector3(0, 1.3, FACADE_Z - 0.4))
	door.set_meta("tap", func() -> void: home_tapped.emit())
	_bodies.append(door)
