class_name Patio
extends Node3D

## Ön bahçe: dükkanın önündeki şerit (arka duvarın dışı, Street.WALL_Z..PATIO_EDGE).
## Dekor › Ön Bahçe'den alınanlara göre görünür (apply):
##   zemin   1 ahşap deck (tahta tahta), 2 taş döşeme, 3 çim ve basamak taşları
##   gölgelik 1 şemsiye (masalarda, Shop), 2 rulolu çizgili tente, 3 sarmaşıklı pergola
##   süsler  ampul zinciri, fener direkleri, saksılar (zeytin ağaçları, pencere çiçekleri)
## Zemin alınınca her zaman: önde beyaz çit, kapı yanında kara tahta menü ve paspas.
## Masalar Shop'ta kurulur (müşteriler oturur).

const X := 5.9
const DOOR_GAP := 1.45
const WOOD := Color("#b98552")
const WOOD_DARK := Color("#94643a")

var _floors := {}
var _shades := {}
var _ornaments := {}
var _base: Node3D


func _ready() -> void:
	_base = Node3D.new()
	add_child(_base)
	_build_floors()
	_build_fence()
	_build_extras()
	_build_awning()
	_build_pergola()
	_build_lights()
	_build_lanterns()
	_build_plants()


func apply(decor: Dictionary) -> void:
	var floor_index: int = decor["patio_floor"]
	visible = floor_index > 0
	for key in _floors:
		(_floors[key] as Node3D).visible = key == floor_index
	var shade: int = decor["patio_shade"]
	for key in _shades:
		(_shades[key] as Node3D).visible = key == shade
	for id in _ornaments:
		(_ornaments[id] as Node3D).visible = Decor.ornament_on(decor, id)
	# Işıkların direkleri: pergola yoksa ampuller kendi direklerine asılır.
	(_ornaments["patio_lights"] as Node3D).get_node("Poles").visible = shade != 3


static func _z0() -> float:
	return Street.WALL_Z


static func _z1() -> float:
	return Street.PATIO_EDGE


func _add(parent: Node3D, node: Node3D) -> Node3D:
	parent.add_child(node)
	return node


func _box(parent: Node3D, size: Vector3, look, pos: Vector3, shadow := false) -> MeshInstance3D:
	var mesh := Util.box(size, look, pos)
	if not shadow:
		Util.no_shadow(mesh)
	parent.add_child(mesh)
	return mesh


## a'dan b'ye uzanan ince kiriş (direk, kol, ip).
static func beam(parent: Node3D, a: Vector3, b: Vector3, thickness: float, look) -> MeshInstance3D:
	var length := a.distance_to(b)
	var mesh := Util.no_shadow(Util.box(Vector3(thickness, thickness, length), look))
	parent.add_child(mesh)
	var mid := (a + b) * 0.5
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT
	mesh.transform = Transform3D(Basis(), mid).looking_at(b, up)
	return mesh


## Sarkan ampul zinciri: a ile b arasında hafif sarkan eğri üzerinde ampuller.
static func string_lights(parent: Node3D, a: Vector3, b: Vector3, count: int, sag := 0.25) -> void:
	var colors := [Color("#ffd166"), Color("#fff1c4"), Color("#ffb35a")]
	var prev := a
	for i in range(1, count + 1):
		var t := float(i) / (count + 1)
		var p := a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		beam(parent, prev, p, 0.012, Color("#2b2d33"))
		prev = p
		var mat := StandardMaterial3D.new()
		var c: Color = colors[i % colors.size()]
		mat.albedo_color = c
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 2.0
		parent.add_child(Util.no_shadow(Util.sphere(0.045, mat, p + Vector3(0, -0.05, 0))))
	beam(parent, prev, b, 0.012, Color("#2b2d33"))


# --- Zemin ---------------------------------------------------------------------

func _build_floors() -> void:
	var z0 := _z0()
	var z1 := _z1()
	var depth := z0 - z1
	var cz := (z0 + z1) / 2.0

	# 1: Ahşap deck — yükseltilmiş platform, tahtalar arasında koyu derz
	var deck := _add(self, Node3D.new())
	_box(deck, Vector3(X * 2.0, 0.08, depth), Color("#5a3a26"), Vector3(0, 0.03, cz))
	var boards := int(depth / 0.22)
	for i in boards:
		var z := z0 - 0.11 - i * (depth / boards)
		var tone := WOOD if i % 2 == 0 else WOOD.darkened(0.08)
		_box(deck, Vector3(X * 2.0 - 0.1, 0.03, depth / boards - 0.025), tone, Vector3(0, 0.085, z))
	_box(deck, Vector3(X * 2.0 + 0.04, 0.12, 0.08), WOOD_DARK, Vector3(0, 0.05, z1 + 0.04))
	_floors[1] = deck

	# 2: Taş döşeme — düzensiz renkli taşlar, aralarında harç
	var stone := _add(self, Node3D.new())
	_box(stone, Vector3(X * 2.0, 0.06, depth), Color("#8c8780"), Vector3(0, 0.02, cz))
	var tones := [Color("#c4beb4"), Color("#b5afa5"), Color("#d2ccc1"), Color("#a9a39a")]
	var rows := 5
	for r in rows:
		var z := z0 - (r + 0.5) * depth / rows
		var x := -X + 0.05 + (0.3 if r % 2 else 0.0)
		var k := 0
		while x < X - 0.3:
			var w: float = [0.55, 0.7, 0.62, 0.48][(r + k) % 4]
			w = minf(w, X - 0.05 - x)
			_box(stone, Vector3(w - 0.05, 0.03, depth / rows - 0.05), tones[(r * 3 + k) % tones.size()], Vector3(x + w / 2.0, 0.06, z))
			x += w
			k += 1
	_floors[2] = stone

	# 3: Çim ve taş — çim, kapıdan kaldırıma basamak taşları, taş bordür ve çiçekler
	var lawn := _add(self, Node3D.new())
	_box(lawn, Vector3(X * 2.0, 0.07, depth), Util.tile_material(Color("#7fb366"), Color("#76ab5e"), 0.35), Vector3(0, 0.025, cz))
	for i in 4:
		var stepping := Util.no_shadow(Util.cylinder(0.32, 0.05, Color("#d2ccc1"), Vector3(0.15 * (1 if i % 2 else -1), 0.07, z0 - 0.35 - i * 0.62)))
		stepping.scale = Vector3(1.0, 1.0, 0.75)
		lawn.add_child(stepping)
	for side in [-1.0, 1.0]:
		_box(lawn, Vector3(0.16, 0.1, depth), Color("#c4beb4"), Vector3(side * (X - 0.08), 0.06, cz))
	var petals := [Color("#ff7aa2"), Color("#ffd166"), Color("#c77dff"), Color("#ffffff")]
	for i in 26:
		var x := randf_range(1.0, X - 0.4) * (1 if i % 2 else -1)
		var z := randf_range(z1 + 0.3, z0 - 0.3)
		lawn.add_child(Util.no_shadow(Util.sphere(0.045, petals[i % petals.size()], Vector3(x, 0.09, z))))
	_floors[3] = lawn


## Önde beyaz çit (kapının önünde boşluk), boşluğun iki yanında top şimşir saksı.
func _build_fence() -> void:
	var z := _z1() + 0.12
	var white := Color("#f6f1e8")
	for side in [-1.0, 1.0]:
		var x0: float = DOOR_GAP * side
		var x1: float = X * side
		var count := 13
		for i in count + 1:
			var x := lerpf(x0, x1, float(i) / count)
			_box(_base, Vector3(0.07, 0.62, 0.05), white, Vector3(x, 0.36, z))
			_base.add_child(Util.no_shadow(Util.box(Vector3(0.05, 0.05, 0.05), white, Vector3(x, 0.69, z))))
		for y in [0.24, 0.52]:
			_box(_base, Vector3(absf(x1 - x0), 0.05, 0.04), white, Vector3((x0 + x1) / 2.0, y, z - 0.03))
		# Kapı yanında top şimşir
		var pot := Vector3(side * (DOOR_GAP - 0.15), 0, z + 0.05)
		_base.add_child(Util.cylinder(0.18, 0.42, Color("#c0703f"), pot + Vector3(0, 0.21, 0)))
		_base.add_child(Util.cylinder(0.2, 0.05, Color("#a85f33"), pot + Vector3(0, 0.42, 0)))
		_base.add_child(Util.sphere(0.3, Color("#4f8f3f"), pot + Vector3(0, 0.72, 0)))


## Kapı önünde paspas, kapının yanında kara tahta "Günün Menüsü".
func _build_extras() -> void:
	var z0 := _z0()
	_box(_base, Vector3(1.3, 0.02, 0.7), Color("#7a3b2c"), Vector3(0, 0.1, z0 - 0.45))
	var welcome := Util.label3d("HOŞ GELDİNİZ", 40, Color("#f2d9a8"), Vector3(0, 0.115, z0 - 0.45))
	welcome.rotation_degrees = Vector3(-90, 180, 0)
	_base.add_child(welcome)
	var board := Node3D.new()
	# Çitin dışında, kapı boşluğunun yanında (müşterilerin yolunda değil)
	board.position = Vector3(1.55, 0, _z1() - 0.3)
	board.rotation_degrees.y = 200
	_base.add_child(board)
	for s in [-1.0, 1.0]:
		var leg := Util.box(Vector3(0.62, 0.95, 0.04), Color("#6b4428"), Vector3(0, 0.47, s * 0.13))
		leg.rotation_degrees.x = s * 10.0
		board.add_child(leg)
	var slate := Util.box(Vector3(0.52, 0.72, 0.02), Color("#2b3330"), Vector3(0, 0.52, -0.16))
	slate.rotation_degrees.x = -10.0
	board.add_child(slate)
	var text := Util.label3d("GÜNÜN\nMENÜSÜ", 34, Color("#f6f1e8"), Vector3(0, 0.66, -0.185))
	text.rotation_degrees.x = -10.0
	board.add_child(text)
	var dish := Util.label3d("Lahmacun\nKöfte • Ayran", 22, Color("#ffd166"), Vector3(0, 0.4, -0.18))
	dish.rotation_degrees.x = -10.0
	board.add_child(dish)


# --- Gölgelik ------------------------------------------------------------------

## Rulolu tente: duvarda rulo kutusu, eğik çizgili bez, önde saçaklı fırfır, iki kol.
func _build_awning() -> void:
	var awning := _add(self, Node3D.new())
	var z0 := _z0() - 0.12
	var z1 := _z1() + 0.35
	var top := 3.05
	var low := 2.45
	var red := Color("#d6452f")
	var cream := Color("#fbf7f0")
	var roll := Util.no_shadow(Util.cylinder(0.12, X * 2.0, Color("#e9e4dc"), Vector3(0, top + 0.08, z0)))
	roll.rotation_degrees.z = 90
	awning.add_child(roll)
	var stripes := 16
	var w := X * 2.0 / stripes
	var length := Vector2(z0 - z1, top - low).length()
	var tilt := rad_to_deg(atan2(top - low, z0 - z1))
	for i in stripes:
		var x := -X + (i + 0.5) * w
		var cloth := Util.no_shadow(Util.box(Vector3(w, 0.03, length), red if i % 2 == 0 else cream, Vector3(x, (top + low) / 2.0, (z0 + z1) / 2.0)))
		cloth.rotation_degrees.x = -tilt
		awning.add_child(cloth)
		# Saçaklı fırfır: her şerit altında yarım daire
		var flap := Util.no_shadow(Util.cylinder(w / 2.0, 0.02, red if i % 2 == 0 else cream, Vector3(x, low - 0.1, z1)))
		flap.rotation_degrees.x = 90
		awning.add_child(flap)
		_box(awning, Vector3(w, 0.2, 0.02), red if i % 2 == 0 else cream, Vector3(x, low - 0.02, z1))
	_box(awning, Vector3(X * 2.0, 0.06, 0.06), Color("#3a3d42"), Vector3(0, low + 0.02, z1))
	for x in [-X + 0.3, X - 0.3]:
		beam(awning, Vector3(x, top - 0.3, z0), Vector3(x, low + 0.02, z1), 0.05, Color("#3a3d42"))
	_shades[2] = awning


## Ahşap pergola: önde dört dikme, kirişler, mertekler; üstünde sarmaşık ve çiçekler.
func _build_pergola() -> void:
	var pergola := _add(self, Node3D.new())
	var z0 := _z0()
	var z1 := _z1() + 0.15
	var wood := Color("#7a4b32")
	for x in [-X + 0.1, -DOOR_GAP - 0.1, DOOR_GAP + 0.1, X - 0.1]:
		_box(pergola, Vector3(0.16, 2.9, 0.16), wood, Vector3(x, 1.45, z1), true)
		_box(pergola, Vector3(0.24, 0.1, 0.24), wood.darkened(0.2), Vector3(x, 0.05, z1))
	_box(pergola, Vector3(X * 2.0 + 0.2, 0.2, 0.16), wood, Vector3(0, 2.95, z1), true)
	_box(pergola, Vector3(X * 2.0 + 0.2, 0.16, 0.12), wood, Vector3(0, 2.95, z0 - 0.1))
	for i in 11:
		var x := -X + 0.2 + i * (X * 2.0 - 0.4) / 10.0
		_box(pergola, Vector3(0.1, 0.12, z0 - z1 + 0.5), wood.lightened(0.08), Vector3(x, 3.08, (z0 + z1) / 2.0), true)
	var greens := [Color("#4f8f3f"), Color("#5fa04a"), Color("#6aab52")]
	var blossoms := [Color("#d36bd8"), Color("#ff7aa2"), Color("#ffffff")]
	for i in 34:
		var x := randf_range(-X, X)
		var z := randf_range(z1, z0)
		pergola.add_child(Util.no_shadow(Util.sphere(randf_range(0.16, 0.26), greens[i % 3], Vector3(x, 3.2, z))))
		if i % 2 == 0:
			pergola.add_child(Util.no_shadow(Util.sphere(0.07, blossoms[i % 3], Vector3(x + 0.1, 3.08, z))))
	# Dikmelerden sarkan sarmaşık
	for x in [-X + 0.1, X - 0.1, -DOOR_GAP - 0.1, DOOR_GAP + 0.1]:
		for k in 5:
			pergola.add_child(Util.no_shadow(Util.sphere(0.13, greens[k % 3], Vector3(x + randf_range(-0.08, 0.08), 2.7 - k * 0.42, z1 - 0.06))))
	_shades[3] = pergola


# --- Süsler --------------------------------------------------------------------

## Ampul zincirleri: duvardan öndeki direklere çapraz uzanır; sıcak bir ışık.
func _build_lights() -> void:
	var lights := _add(self, Node3D.new())
	var poles := Node3D.new()
	poles.name = "Poles"
	lights.add_child(poles)
	var z0 := _z0() - 0.1
	var z1 := _z1() + 0.15
	var posts := [-X + 0.1, -DOOR_GAP - 0.1, DOOR_GAP + 0.1, X - 0.1]
	for x in posts:
		_box(poles, Vector3(0.06, 2.75, 0.06), Color("#2b2d33"), Vector3(x, 1.37, z1))
	for i in posts.size():
		var x: float = posts[i]
		string_lights(lights, Vector3(x, 2.7, z1), Vector3(x + (1.6 if x < 0 else -1.6), 2.95, z0), 6, 0.18)
		if i < posts.size() - 1 and i != 1:
			string_lights(lights, Vector3(x, 2.7, z1), Vector3(posts[i + 1], 2.7, z1), 7, 0.3)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 2.3, (z0 + z1) / 2.0)
	glow.light_color = Color("#ffd9a0")
	glow.omni_range = 7.0
	glow.light_energy = 0.55
	lights.add_child(glow)
	_ornaments["patio_lights"] = lights


## Fener direkleri: köşelerde siyah direk, üstte camlı fener ve şapka.
func _build_lanterns() -> void:
	var lanterns := _add(self, Node3D.new())
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color("#ffe6a8")
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color("#ffd27a")
	lamp_mat.emission_energy_multiplier = 2.2
	for x in [-X + 0.35, X - 0.35]:
		var base := Vector3(x, 0, _z1() + 0.45)
		lanterns.add_child(Util.cylinder(0.12, 0.2, Color("#2b2d33"), base + Vector3(0, 0.1, 0)))
		lanterns.add_child(Util.cylinder(0.04, 2.2, Color("#2b2d33"), base + Vector3(0, 1.2, 0)))
		lanterns.add_child(Util.no_shadow(Util.box(Vector3(0.24, 0.32, 0.24), lamp_mat, base + Vector3(0, 2.45, 0))))
		for dx in [-0.12, 0.12]:
			for dz in [-0.12, 0.12]:
				lanterns.add_child(Util.no_shadow(Util.box(Vector3(0.025, 0.34, 0.025), Color("#2b2d33"), base + Vector3(dx, 2.45, dz))))
		var cap := Util.no_shadow(Util.cylinder(0.2, 0.12, Color("#2b2d33"), base + Vector3(0, 2.66, 0)))
		lanterns.add_child(cap)
		lanterns.add_child(Util.no_shadow(Util.sphere(0.05, Color("#2b2d33"), base + Vector3(0, 2.76, 0))))
		var light := OmniLight3D.new()
		light.position = base + Vector3(0, 2.4, 0)
		light.light_color = Color("#ffd9a0")
		light.omni_range = 4.0
		light.light_energy = 0.5
		lanterns.add_child(light)
	_ornaments["patio_lanterns"] = lanterns


## Saksılar: köşelerde büyük saksıda zeytin ağaçları, vitrinlerin altında çiçek
## kasaları, çitin dibinde lavanta.
func _build_plants() -> void:
	var plants := _add(self, Node3D.new())
	var z0 := _z0()
	var olive := [Color("#7d9a5a"), Color("#8eaa68"), Color("#6f8c4f")]
	for x in [-X + 0.45, X - 0.45]:
		var base := Vector3(x, 0, z0 - 0.45)
		plants.add_child(Util.cylinder(0.3, 0.55, Color("#e3d6c3"), base + Vector3(0, 0.27, 0)))
		plants.add_child(Util.cylinder(0.32, 0.06, Color("#cdbfaa"), base + Vector3(0, 0.55, 0)))
		plants.add_child(Util.cylinder(0.05, 1.0, Color("#6b5240"), base + Vector3(0, 1.05, 0)))
		for k in 6:
			var off := Vector3(randf_range(-0.35, 0.35), randf_range(1.45, 1.95), randf_range(-0.3, 0.3))
			plants.add_child(Util.no_shadow(Util.sphere(randf_range(0.22, 0.32), olive[k % 3], base + off)))
	var petals := [Color("#ff7aa2"), Color("#ffd166"), Color("#ffffff"), Color("#c77dff"), Color("#ff9f43")]
	for wx in [-3.4, 3.4]:
		# Vitrin altında dışarıdan çiçek kasası
		plants.add_child(Util.box(Vector3(2.5, 0.22, 0.28), WOOD_DARK, Vector3(wx, 0.32, z0 - 0.2)))
		for i in 12:
			var fx: float = wx - 1.1 + i * 0.2
			plants.add_child(Util.no_shadow(Util.sphere(0.1, Color("#4f9a52"), Vector3(fx, 0.48, z0 - 0.2))))
			plants.add_child(Util.no_shadow(Util.sphere(0.06, petals[i % petals.size()], Vector3(fx + 0.04, 0.58, z0 - 0.24))))
	# Çitin dibinde lavanta
	for side in [-1.0, 1.0]:
		for i in 9:
			var x: float = side * (DOOR_GAP + 0.5 + i * 0.45)
			plants.add_child(Util.no_shadow(Util.sphere(0.14, Color("#6f9a5a"), Vector3(x, 0.16, _z1() + 0.35))))
			plants.add_child(Util.no_shadow(Util.cylinder(0.035, 0.18, Color("#9b7fd6"), Vector3(x, 0.32, _z1() + 0.35))))
	_ornaments["patio_plants"] = plants
