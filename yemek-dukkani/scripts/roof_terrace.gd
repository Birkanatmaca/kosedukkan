class_name RoofTerrace
extends Node3D

## Çatı terası (Progression "terrace"): dükkanın sağ arka köşesinde döner merdiven,
## tavanda ve çatıda merdiven boşluğu, çatının üstünde korkuluklu teras.
## Dekor › Çatı Terası'ndan alınanlara göre (apply):
##   zemin    0 ahşap deck, 1 terracotta karo, 2 suni çim, 3 beyaz taş
##   gölgelik 1 şemsiye (masalarda, Shop), 2 sarmaşıklı pergola, 3 yelken gölgelik
##   süsler   ampul zinciri, saksılar ve zeytin ağaçları, minderli oturma köşesi
## Masalar Shop'ta kurulur (Shop.ROOF_TABLES); müşteriler merdivenden çıkar.

const Y := Shop.ROOF_Y
const X0 := -6.0
const X1 := 6.0
const Z0 := -10.2
const Z1 := 2.2
## Merdiven boşluğu (tavanda ve çatıda)
const HOLE_X := 4.1
const HOLE_Z := -8.25
const STEPS := 20

## Çatı katı (Kuşbakışı kamerada gizlenir); merdiven dükkanın içinde kalır.
var roof: Node3D
var stairs: Node3D
var _floors := {}
var _shades := {}
var _ornaments := {}
var _glass: StandardMaterial3D


func _ready() -> void:
	roof = Node3D.new()
	add_child(roof)
	stairs = Node3D.new()
	add_child(stairs)
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.8, 0.92, 0.97, 0.25)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.05
	_build_stairs()
	_build_floors()
	_build_railings()
	_build_pergola()
	_build_sails()
	_build_lights()
	_build_plants()
	_build_lounge()


func apply(decor: Dictionary, built: bool) -> void:
	visible = built
	var floor_index: int = decor["roof_floor"]
	for key in _floors:
		(_floors[key] as Node3D).visible = key == floor_index
	var shade: int = decor["roof_shade"]
	for key in _shades:
		(_shades[key] as Node3D).visible = key == shade
	for id in _ornaments:
		(_ornaments[id] as Node3D).visible = Decor.ornament_on(decor, id)


func _box(parent: Node3D, size: Vector3, look, pos: Vector3, shadow := false) -> MeshInstance3D:
	var mesh := Util.box(size, look, pos)
	if not shadow:
		Util.no_shadow(mesh)
	parent.add_child(mesh)
	return mesh


## Çatı alanını merdiven boşluğu hariç iki dikdörtgene böler: [merkez, boyut]
static func _pieces(height: float, y: float) -> Array:
	var w_a := HOLE_X - X0
	var w_b := X1 - HOLE_X
	var d_b := Z1 - HOLE_Z
	return [
		[Vector3((X0 + HOLE_X) / 2.0, y, (Z0 + Z1) / 2.0), Vector3(w_a, height, Z1 - Z0)],
		[Vector3((HOLE_X + X1) / 2.0, y, (HOLE_Z + Z1) / 2.0), Vector3(w_b, height, d_b)],
	]


# --- Merdiven --------------------------------------------------------------------

## Döner merdiven: ortada direk, kama basamaklar, dış kenarda korkuluk.
func _build_stairs() -> void:
	var c := Shop.STAIR_CENTER
	var metal := Color("#2b2d33")
	var wood := Color("#a0703f")
	stairs.add_child(Util.cylinder(0.07, Y + 1.0, metal, c + Vector3(0, (Y + 1.0) / 2.0, 0)))
	stairs.add_child(Util.sphere(0.1, Color("#c9a24a"), c + Vector3(0, Y + 1.05, 0)))
	var sweep := 450.0
	var prev_top := Vector3.ZERO
	for i in STEPS:
		var theta := deg_to_rad(-90.0 + sweep * (i + 0.5) / STEPS)
		var dir := Vector3(sin(theta), 0, cos(theta))
		var y := Y * float(i + 1) / STEPS
		var step := Util.box(Vector3(0.36, 0.06, 0.8), wood, c + dir * 0.43 + Vector3(0, y - 0.03, 0))
		step.rotation.y = theta
		stairs.add_child(step)
		var post := c + dir * 0.8 + Vector3(0, y, 0)
		stairs.add_child(Util.no_shadow(Util.cylinder(0.018, 0.9, metal, post + Vector3(0, 0.45, 0))))
		var top := post + Vector3(0, 0.9, 0)
		if i > 0:
			Patio.beam(stairs, prev_top, top, 0.05, wood.darkened(0.2))
		prev_top = top


# --- Zemin ----------------------------------------------------------------------

func _build_floors() -> void:
	var y := Y - 0.04
	# 0: ahşap deck (tahtalar x boyunca, boşluğun yanında kısa)
	var deck := Node3D.new()
	roof.add_child(deck)
	var rows := 46
	for r in rows:
		var z := Z0 + (r + 0.5) * (Z1 - Z0) / rows
		var x_end := HOLE_X if z < HOLE_Z else X1
		var tone := Color("#b98552") if r % 2 == 0 else Color("#ab7a4a")
		_box(deck, Vector3(x_end - X0, 0.08, (Z1 - Z0) / rows - 0.02), tone, Vector3((X0 + x_end) / 2.0, y, z))
	_floors[0] = deck
	var looks := {
		1: Util.tile_material(Color("#c2693e"), Color("#b45d35"), 0.6),
		2: Util.tile_material(Color("#79b85a"), Color("#70ad52"), 0.4),
		3: Util.tile_material(Color("#ece7de"), Color("#ddd6ca"), 0.7),
	}
	for key in looks:
		var floor := Node3D.new()
		roof.add_child(floor)
		for piece in _pieces(0.08, y):
			_box(floor, piece[1], looks[key], piece[0])
		_floors[key] = floor
	# Çatının altı ve kenar saçağı her zaman
	for piece in _pieces(0.06, Y - 0.1):
		_box(roof, piece[1], Color("#d9d2c6"), piece[0])


## Kenarlarda alçak duvar, üstünde cam korkuluk ve ahşap tutamak; merdiven
## boşluğunun yanında da korkuluk.
func _build_railings() -> void:
	var edges := [
		[Vector3(X0, Y, Z0 + 0.05), Vector3(X1, Y, Z0 + 0.05)],
		[Vector3(X0 + 0.05, Y, Z0), Vector3(X0 + 0.05, Y, Z1)],
		[Vector3(X1 - 0.05, Y, Z0), Vector3(X1 - 0.05, Y, Z1)],
		[Vector3(X0, Y, Z1 - 0.05), Vector3(X1, Y, Z1 - 0.05)],
		[Vector3(HOLE_X, Y, Z0), Vector3(HOLE_X, Y, HOLE_Z)],
	]
	for edge in edges:
		var a: Vector3 = edge[0]
		var b: Vector3 = edge[1]
		var mid := (a + b) / 2.0
		var along_x := absf(b.x - a.x) > absf(b.z - a.z)
		var length := a.distance_to(b)
		var size := func(t: float, h: float) -> Vector3: return Vector3(length, h, t) if along_x else Vector3(t, h, length)
		_box(roof, size.call(0.16, 0.22), Color("#e9e4dc"), mid + Vector3(0, 0.11, 0))
		_box(roof, size.call(0.03, 0.8), _glass, mid + Vector3(0, 0.62, 0))
		_box(roof, size.call(0.1, 0.06), Color("#8a5a3a"), mid + Vector3(0, 1.04, 0))
		var posts := int(length / 1.5)
		for i in posts + 1:
			var p := a.lerp(b, float(i) / maxi(posts, 1))
			_box(roof, Vector3(0.05, 0.85, 0.05), Color("#3a3d42"), p + Vector3(0, 0.62, 0))


# --- Gölgelik ---------------------------------------------------------------------

## Masaların üstünde ahşap pergola, sarmaşık ve sarkan mor çiçekler.
func _build_pergola() -> void:
	var pergola := Node3D.new()
	roof.add_child(pergola)
	var wood := Color("#7a4b32")
	var xa := -5.5
	var xb := 3.0
	var za := -7.6
	var zb := -2.2
	for x in [xa, xb]:
		for z in [za, zb]:
			_box(pergola, Vector3(0.16, 2.6, 0.16), wood, Vector3(x, Y + 1.3, z), true)
	for z in [za, zb]:
		_box(pergola, Vector3(xb - xa + 0.4, 0.18, 0.14), wood, Vector3((xa + xb) / 2.0, Y + 2.6, z), true)
	for i in 10:
		var x := xa + i * (xb - xa) / 9.0
		_box(pergola, Vector3(0.1, 0.12, zb - za + 0.6), wood.lightened(0.08), Vector3(x, Y + 2.72, (za + zb) / 2.0), true)
	var greens := [Color("#4f8f3f"), Color("#5fa04a"), Color("#6aab52")]
	for i in 40:
		var p := Vector3(randf_range(xa, xb), Y + 2.82, randf_range(za, zb))
		pergola.add_child(Util.no_shadow(Util.sphere(randf_range(0.16, 0.26), greens[i % 3], p)))
		if i % 3 == 0:
			for k in 3:
				pergola.add_child(Util.no_shadow(Util.sphere(0.06, Color("#b07ad8"), p + Vector3(0.05, -0.15 - k * 0.12, 0))))
	_shades[2] = pergola


## Yelken gölgelik: köşe direklerine gerilmiş iki üçgen bez.
func _build_sails() -> void:
	var sails := Node3D.new()
	roof.add_child(sails)
	var posts := [Vector3(-5.6, Y, -7.8), Vector3(3.2, Y, -7.8), Vector3(-5.6, Y, -1.8), Vector3(3.2, Y, -1.8)]
	var heights := [2.9, 2.3, 2.3, 2.9]
	for i in posts.size():
		_box(sails, Vector3(0.08, heights[i], 0.08), Color("#e9e4dc"), posts[i] + Vector3(0, heights[i] / 2.0, 0), true)
	var cloth := [Color("#f3efe6"), Color("#e8553e")]
	var tris := [[0, 1, 2], [1, 3, 2]]
	for t in tris.size():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for idx in tris[t]:
			st.add_vertex(posts[idx] + Vector3(0, heights[idx] - 0.1 * t, 0))
		for idx in [tris[t][2], tris[t][1], tris[t][0]]:
			st.add_vertex(posts[idx] + Vector3(0, heights[idx] - 0.1 * t, 0))
		st.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = st.commit()
		mesh.material_override = Util.material(cloth[t])
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		sails.add_child(mesh)
	_shades[3] = sails


# --- Süsler ----------------------------------------------------------------------

## Köşe direkleri arasında çapraz ampul zincirleri ve sıcak ışık.
func _build_lights() -> void:
	var lights := Node3D.new()
	roof.add_child(lights)
	var corners := [Vector3(-5.75, Y, -9.9), Vector3(3.8, Y, -9.9), Vector3(-5.75, Y, 1.9), Vector3(5.75, Y, 1.9)]
	for p in corners:
		_box(lights, Vector3(0.06, 2.7, 0.06), Color("#2b2d33"), p + Vector3(0, 1.35, 0))
	var top := Vector3(0, 2.65, 0)
	Patio.string_lights(lights, corners[0] + top, corners[3] + top, 18, 0.5)
	Patio.string_lights(lights, corners[1] + top, corners[2] + top, 18, 0.5)
	Patio.string_lights(lights, corners[0] + top, corners[1] + top, 12, 0.35)
	Patio.string_lights(lights, corners[2] + top, corners[3] + top, 14, 0.35)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, Y + 2.2, -4.0)
	glow.light_color = Color("#ffd9a0")
	glow.omni_range = 9.0
	glow.light_energy = 0.6
	lights.add_child(glow)
	_ornaments["roof_lights"] = lights


## Sokak tarafında çiçek kasaları, köşelerde zeytin ağaçları, yanlarda lavanta.
func _build_plants() -> void:
	var plants := Node3D.new()
	roof.add_child(plants)
	var petals := [Color("#ff7aa2"), Color("#ffd166"), Color("#ffffff"), Color("#c77dff"), Color("#ff9f43")]
	for i in 3:
		var x := -4.4 + i * 3.0
		_box(plants, Vector3(2.4, 0.4, 0.45), Color("#94643a"), Vector3(x, Y + 0.2, Z0 + 0.45))
		for k in 10:
			plants.add_child(Util.no_shadow(Util.sphere(0.13, Color("#4f9a52"), Vector3(x - 1.0 + k * 0.22, Y + 0.45, Z0 + 0.45))))
			plants.add_child(Util.no_shadow(Util.sphere(0.07, petals[(i + k) % petals.size()], Vector3(x - 0.95 + k * 0.22, Y + 0.56, Z0 + 0.4))))
	var olive := [Color("#7d9a5a"), Color("#8eaa68"), Color("#6f8c4f")]
	for p in [Vector3(-5.4, Y, 1.5), Vector3(5.35, Y, 1.5), Vector3(-5.4, Y, -8.9)]:
		plants.add_child(Util.cylinder(0.32, 0.6, Color("#e3d6c3"), p + Vector3(0, 0.3, 0)))
		plants.add_child(Util.cylinder(0.05, 1.0, Color("#6b5240"), p + Vector3(0, 1.0, 0)))
		for k in 6:
			plants.add_child(Util.no_shadow(Util.sphere(randf_range(0.22, 0.32), olive[k % 3],
				p + Vector3(randf_range(-0.35, 0.35), randf_range(1.4, 1.9), randf_range(-0.3, 0.3)))))
	for i in 12:
		var z := -7.5 + i * 0.7
		plants.add_child(Util.no_shadow(Util.sphere(0.15, Color("#6f9a5a"), Vector3(-5.65, Y + 0.18, z))))
		plants.add_child(Util.no_shadow(Util.cylinder(0.035, 0.2, Color("#9b7fd6"), Vector3(-5.65, Y + 0.36, z))))
	_ornaments["roof_plants"] = plants


## Minderli oturma köşesi: ön köşede L sedir, minderler, kilim ve sehpa.
func _build_lounge() -> void:
	var lounge := Node3D.new()
	roof.add_child(lounge)
	var wood := Color("#8a5a3a")
	var cushion := Color("#f3efe6")
	var accents := [Color("#e8553e"), Color("#3f8f6a"), Color("#ffd166"), Color("#4c7bd1")]
	# Kilim
	_box(lounge, Vector3(3.0, 0.02, 1.9), Util.tile_material(Color("#b53a2c"), Color("#d98a3a"), 2.5), Vector3(-3.9, Y + 0.01, 0.55))
	# L sedir: arkada uzun, yanda kısa
	_box(lounge, Vector3(3.4, 0.38, 0.8), wood, Vector3(-3.9, Y + 0.19, 1.65), true)
	_box(lounge, Vector3(3.3, 0.16, 0.74), cushion, Vector3(-3.9, Y + 0.46, 1.65))
	_box(lounge, Vector3(3.3, 0.55, 0.18), cushion.darkened(0.05), Vector3(-3.9, Y + 0.75, 1.98))
	_box(lounge, Vector3(0.8, 0.38, 1.6), wood, Vector3(-5.55, Y + 0.19, 0.45), true)
	_box(lounge, Vector3(0.74, 0.16, 1.5), cushion, Vector3(-5.55, Y + 0.46, 0.45))
	_box(lounge, Vector3(0.18, 0.55, 1.5), cushion.darkened(0.05), Vector3(-5.88, Y + 0.75, 0.45))
	for i in 4:
		var pillow := Util.box(Vector3(0.45, 0.4, 0.14), accents[i], Vector3(-5.1 + i * 0.85, Y + 0.72, 1.85))
		pillow.rotation_degrees.x = -12
		lounge.add_child(pillow)
	# Sehpa, üstünde çay tepsisi
	lounge.add_child(Util.cylinder(0.45, 0.06, wood, Vector3(-3.8, Y + 0.42, 0.55)))
	lounge.add_child(Util.cylinder(0.06, 0.4, wood.darkened(0.2), Vector3(-3.8, Y + 0.2, 0.55)))
	lounge.add_child(Util.cylinder(0.22, 0.02, Color("#c9a24a"), Vector3(-3.8, Y + 0.46, 0.55)))
	for k in 3:
		lounge.add_child(Util.cylinder(0.035, 0.09, Color("#b5402a"), Vector3(-3.95 + k * 0.14, Y + 0.51, 0.55)))
	_ornaments["roof_lounge"] = lounge
