class_name Kitchen
extends Node3D

## Mutfak ekranı: ızgara ve fritöz. Malzeme alttaki butonlardan seçilir,
## pişen ürüne dokununca alınır ve servis rafına (pass) konur. Rafın solunda açık
## siparişlerin tepsileri durur; "Tepsiye Koy" denince ürünler raftaki tabaklardan
## tepsiye uçar. Izgaranın altındaki kömürler kızgın kızgın parlar.

signal slot_added(slot: CookSlot)

const GRILL_X := -0.9
const FRYER_X := 0.9
## Pişirme yerleri: önce ön sıra, geliştirmeyle arka sıra açılır.
const GRILL_SLOTS := [
	Vector2(-0.55, 0.18), Vector2(0.0, 0.18), Vector2(0.55, 0.18),
	Vector2(0.0, -0.27), Vector2(-0.55, -0.27), Vector2(0.55, -0.27),
]
const FRYER_SLOTS := [Vector2(-0.24, 0.17), Vector2(0.24, 0.17), Vector2(-0.24, -0.2), Vector2(0.24, -0.2)]
## Her hız kademesinde pişme süresi bu oranla çarpılır.
const SPEED_STEP := 0.85
## Servis rafı: yüksekliği, solda sipariş tepsilerinin, sağda ürün tabaklarının yeri
const PASS_Y := 1.55
const PASS_Z := -0.68
## (Kamera rafın x -1.9..1.7 arasını görür; hepsi bu aralığa sığar.)
const TRAY_X := [-1.65, -1.18, -0.71, -0.24]
const PLATE_X := { "tavuk": 0.25, "tavuk_sis": 0.67, "kofte": 1.09, "patates": 1.51 }
## Pişirilmeyen ürünler (kola) tepsiye rafın sağ ucundan gelir.
const COLD_X := 1.75
## Tepsideki ürün yerleri (tepsinin ortasına göre)
const TRAY_SLOTS := [Vector3(-0.1, 0, -0.06), Vector3(0.1, 0, -0.06), Vector3(-0.1, 0, 0.07), Vector3(0.1, 0, 0.07), Vector3(0, 0.05, 0)]
const ON_TRAY_SCALE := 0.55
const ON_PLATE_SCALE := 0.62

var slots: Array[CookSlot] = []
var shop: Shop

var _pass_root: Node3D
var _trays_root: Node3D
## sipariş numarası -> tepsideki ürün sayısı (yeni konanları uçurmak için)
var _tray_counts := {}
var _coals: StandardMaterial3D
var _embers: Array[MeshInstance3D] = []
var _grill_light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	_build_room()
	_build_grill()
	_build_fryer()
	_build_pass()
	_sync_upgrades()
	GameState.prepared_changed.connect(_refresh_pass)
	GameState.upgrades_changed.connect(_sync_upgrades)
	shop.orders_changed.connect(_sync_trays)
	_refresh_pass()
	_sync_trays()


## Kömürler nefes alır gibi parlar, közler tek tek yanıp söner, ışık titrer.
func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 2.3) * sin(_t * 0.7 + 1.0)
	_coals.emission_energy_multiplier = 1.4 + 0.6 * pulse
	_grill_light.light_energy = 0.9 + 0.35 * pulse + randf_range(-0.05, 0.05)
	for i in _embers.size():
		var mat := _embers[i].material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 1.5 + 2.5 * maxf(0.0, sin(_t * (1.3 + i * 0.37) + i * 2.1))


## Yer sayısını ve pişirme hızını geliştirmelere göre ayarlar.
func _sync_upgrades() -> void:
	var grill_count := Progression.BASE_GRILL_SLOTS + GameState.upgrade_level("grill_slot")
	var fryer_count := Progression.BASE_FRYER_SLOTS + GameState.upgrade_level("fryer_slot")
	while _count("izgara") < mini(grill_count, GRILL_SLOTS.size()):
		var p: Vector2 = GRILL_SLOTS[_count("izgara")]
		_add_slot("izgara", Vector3(GRILL_X + p.x, 1.09, p.y))
	while _count("fritoz") < mini(fryer_count, FRYER_SLOTS.size()):
		var p: Vector2 = FRYER_SLOTS[_count("fritoz")]
		var pos := Vector3(FRYER_X + p.x, 1.18, p.y)
		add_child(Util.box(Vector3(0.42, 0.03, 0.32), Color("#8f989f"), pos + Vector3(0, -0.005, 0)))
		add_child(Util.box(Vector3(0.05, 0.05, 0.22), Color("#2d2f33"), pos + Vector3(0, 0.02, signf(p.y) * 0.27)))
		_add_slot("fritoz", pos)
	for slot in slots:
		var upgrade := "grill_speed" if slot.device == "izgara" else "fryer_speed"
		slot.speed = pow(SPEED_STEP, GameState.upgrade_level(upgrade))


func _count(device: String) -> int:
	var n := 0
	for slot in slots:
		if slot.device == device:
			n += 1
	return n


func add_ingredient(id: String) -> void:
	var device: String = Items.PRODUCTS[id]["device"]
	for slot in slots:
		if slot.device == device and slot.is_empty():
			if not GameState.take_stock(id):
				GameState.show_toast("%s bitti! Marketten al." % Items.display_name(id))
				return
			slot.start(id)
			return
	GameState.show_toast("Izgara dolu!" if device == "izgara" else "Fritöz dolu!")


func _on_slot_tapped(slot: CookSlot) -> void:
	if slot.is_empty():
		GameState.show_toast("Aşağıdan malzeme seç")
		return
	if slot.doneness() < Items.RAW_LIMIT:
		GameState.show_toast("Daha çok çiğ!")
		return
	var id := slot.product
	var quality := Items.quality_for(slot.doneness())
	slot.clear()
	match quality:
		0: GameState.show_toast("Yandı! Çöpe gitti")
		2: GameState.show_toast("Az pişmiş... müşteri fark edebilir")
		3: GameState.show_toast("Biraz fazla pişti")
		5: GameState.show_toast("Tam kıvamında!")
	if quality > 0:
		GameState.add_prepared(id, quality)


func _add_slot(device: String, pos: Vector3) -> void:
	var slot := CookSlot.new()
	slot.device = device
	slot.position = pos
	slot.tapped.connect(_on_slot_tapped)
	add_child(slot)
	slots.append(slot)
	slot_added.emit(slot)
	if is_inside_tree() and slots.size() > Progression.BASE_GRILL_SLOTS + Progression.BASE_FRYER_SLOTS:
		# Yeni açılan yer parlayarak belirsin.
		slot.scale = Vector3.ONE * 0.01
		slot.create_tween().tween_property(slot, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_room() -> void:
	add_child(Util.box(Vector3(8, 0.1, 6), Util.tile_material(Color("#d8dce0"), Color("#c3c9cf"), 1.5), Vector3(0, -0.05, 0)))
	add_child(Util.box(Vector3(8, 4, 0.2), Util.tile_material(Color("#ffffff"), Color("#e3eef3"), 5.0, true), Vector3(0, 2, -1.0)))
	# Tezgâh
	add_child(Util.box(Vector3(4.8, 0.9, 1.3), Color("#7d8a96"), Vector3(0, 0.45, 0)))
	add_child(Util.box(Vector3(4.9, 0.05, 1.35), Color("#c9d1d9"), Vector3(0, 0.925, 0)))
	add_child(Util.box(Vector3(4.8, 0.06, 0.02), Color("#5d6873"), Vector3(0, 0.55, 0.66)))

	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.4, 1.0)
	light.light_color = Color("#ffe2b8")
	light.light_energy = 0.8
	light.omni_range = 5.0
	add_child(light)


func _build_grill() -> void:
	add_child(Util.box(Vector3(1.75, 0.14, 1.0), Color("#2d2f33"), Vector3(GRILL_X, 1.0, 0)))
	# Kızgın kömür yatağı: kendi ışığını veren, gürültülü turuncu-kırmızı yüzey
	_coals = StandardMaterial3D.new()
	_coals.albedo_color = Color("#3a0d05")
	_coals.emission_enabled = true
	_coals.emission = Color("#ff4512")
	var noise := NoiseTexture2D.new()
	noise.width = 128
	noise.height = 128
	noise.noise = FastNoiseLite.new()
	noise.noise.frequency = 0.06
	var ramp := Gradient.new()
	ramp.set_color(0, Color("#2a0802"))
	ramp.set_color(1, Color("#ffb347"))
	noise.color_ramp = ramp
	_coals.emission_texture = noise
	_coals.roughness = 1.0
	add_child(Util.box(Vector3(1.65, 0.02, 0.9), _coals, Vector3(GRILL_X, 1.06, 0)))
	# Közler: kömürlerin arasında tek tek parlayan küçük parçalar
	for i in 16:
		var ember_mat := StandardMaterial3D.new()
		ember_mat.albedo_color = Color("#5a1405")
		ember_mat.emission_enabled = true
		ember_mat.emission = Color("#ffd27a") if i % 3 == 0 else Color("#ff6a1f")
		var ember := Util.sphere(randf_range(0.025, 0.045), ember_mat, Vector3(GRILL_X + randf_range(-0.78, 0.78), 1.068, randf_range(-0.42, 0.42)))
		ember.scale.y = 0.5
		add_child(ember)
		_embers.append(ember)
	# Izgara telleri: koyu metal, alttan gelen kızıllıkla parlar
	var bars := StandardMaterial3D.new()
	bars.albedo_color = Color("#1a1716")
	bars.metallic = 0.6
	bars.roughness = 0.45
	for i in 9:
		add_child(Util.box(Vector3(1.65, 0.025, 0.035), bars, Vector3(GRILL_X, 1.08, -0.4 + i * 0.1)))
	_grill_light = OmniLight3D.new()
	_grill_light.position = Vector3(GRILL_X, 1.22, 0.05)
	_grill_light.light_color = Color("#ff6a2a")
	_grill_light.omni_range = 1.6
	add_child(_grill_light)
	_build_sparks()
	add_child(Util.box(Vector3(1.75, 0.1, 0.06), Color("#3d4046"), Vector3(GRILL_X, 0.98, 0.52)))
	for k in 3:
		add_child(Util.cylinder(0.035, 0.05, Color("#d0d0d0"), Vector3(GRILL_X - 0.5 + k * 0.5, 0.98, 0.56)))


func _build_fryer() -> void:
	add_child(Util.box(Vector3(1.15, 0.26, 1.0), Color("#b9c2cc"), Vector3(FRYER_X, 1.05, 0)))
	add_child(Util.box(Vector3(0.95, 0.02, 0.75), Color("#e0a83a"), Vector3(FRYER_X, 1.17, 0)))




## Izgaradan yükselen küçük kıvılcımlar
func _build_sparks() -> void:
	var sparks := CPUParticles3D.new()
	sparks.amount = 14
	sparks.lifetime = 1.2
	sparks.position = Vector3(GRILL_X, 1.1, 0)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(0.75, 0.01, 0.4)
	sparks.direction = Vector3.UP
	sparks.spread = 25.0
	sparks.gravity = Vector3(0, 0.3, 0)
	sparks.initial_velocity_min = 0.2
	sparks.initial_velocity_max = 0.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.75, 0.3, 1.0))
	fade.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	sparks.color_ramp = fade
	var mesh := SphereMesh.new()
	mesh.radius = 0.008
	mesh.height = 0.016
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	sparks.mesh = mesh
	add_child(sparks)


func _build_pass() -> void:
	add_child(Util.box(Vector3(4.5, 0.06, 0.62), Color("#c9d1d9"), Vector3(0, PASS_Y - 0.03, PASS_Z)))
	add_child(Util.box(Vector3(4.5, 0.03, 0.04), Color("#9aa4ae"), Vector3(0, PASS_Y - 0.01, PASS_Z + 0.3)))
	add_child(Util.box(Vector3(4.4, 0.1, 0.3), Color("#e8553e"), Vector3(0, PASS_Y + 0.6, PASS_Z)))
	for x in [-2.15, 2.15]:
		add_child(Util.box(Vector3(0.05, 0.6, 0.05), Color("#9aa4ae"), Vector3(x, PASS_Y + 0.3, PASS_Z)))
	var heat := OmniLight3D.new()
	heat.position = Vector3(0, PASS_Y + 0.4, PASS_Z + 0.15)
	heat.light_color = Color("#ff9a5a")
	heat.light_energy = 0.35
	heat.omni_range = 2.4
	add_child(heat)
	# Raftaki bölümlerin adları
	for part in [["SİPARİŞLER", -0.95], ["HAZIR ÜRÜNLER", 0.88]]:
		var tag := Util.label3d(part[0], 40, Color("#7a8591"), Vector3(part[1], PASS_Y + 0.005, PASS_Z + 0.27))
		tag.rotation_degrees.x = -90
		tag.pixel_size = 0.0035
		add_child(tag)
	_pass_root = Node3D.new()
	_pass_root.position = Vector3(0, PASS_Y, PASS_Z)
	add_child(_pass_root)
	_trays_root = Node3D.new()
	_trays_root.position = Vector3(0, PASS_Y, PASS_Z)
	add_child(_trays_root)


## Pişen ürünler türüne göre tabaklarda; tabakta en fazla üç tanesi görünür, yanında adedi.
func _refresh_pass() -> void:
	for child in _pass_root.get_children():
		child.queue_free()
	for id in GameState.prepared:
		var qualities: Array = GameState.prepared[id]
		if qualities.is_empty() or not PLATE_X.has(id):
			continue
		var plate := Node3D.new()
		plate.position.x = PLATE_X[id]
		_pass_root.add_child(plate)
		plate.add_child(Util.cylinder(0.18, 0.02, Color("#ffffff"), Vector3(0, 0.01, 0)))
		for i in mini(qualities.size(), 3):
			var item := Items.model(id, Util.material(Items.quality_color(id, qualities[i])))
			item.scale = Vector3.ONE * ON_PLATE_SCALE
			item.position = Vector3((i - 1) * 0.06, 0.02 + i * 0.025, (i % 2) * 0.04 - 0.02)
			item.rotation_degrees.y = -20.0 + i * 25.0
			plate.add_child(item)
		var count := Util.label3d("×%d" % qualities.size(), 64, Color.WHITE, Vector3(0.14, 0.22, 0.12))
		count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		count.outline_size = 16
		count.outline_modulate = Color("#2d2f33")
		count.pixel_size = 0.003
		plate.add_child(count)


## Açık siparişlerin tepsileri: üstünde numarası, içinde konmuş ürünler.
## Yeni konan ürünler raftaki tabaktan tepsiye kavis çizerek uçar.
func _sync_trays() -> void:
	for child in _trays_root.get_children():
		child.queue_free()
	var counts := {}
	for i in mini(shop.orders.size(), TRAY_X.size()):
		var order: Dictionary = shop.orders[i]
		var tray := Node3D.new()
		tray.position.x = TRAY_X[i]
		_trays_root.add_child(tray)
		tray.add_child(Util.model("equipment/tepsi", Vector3.ZERO, 90.0, 1.05))
		var tag := Util.label3d("#%d" % order["number"], 70, Color.WHITE, Vector3(0, 0.34, 0.05))
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.outline_size = 18
		tag.outline_modulate = UiKit.GREEN if order["ready"] else Color("#e8553e")
		tag.pixel_size = 0.0032
		tray.add_child(tag)
		if order["ready"]:
			var done := Util.label3d("HAZIR", 40, UiKit.GREEN, Vector3(0, 0.22, 0.05))
			done.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			done.outline_size = 12
			done.outline_modulate = Color.WHITE
			done.pixel_size = 0.0032
			tray.add_child(done)
		var placed := 0
		var before: int = _tray_counts.get(order["number"], 0)
		for id in order["filled"]:
			for quality in order["filled"][id]:
				if placed >= TRAY_SLOTS.size():
					break
				var item := Items.model(id, Util.material(Items.quality_color(id, quality)))
				item.scale = Vector3.ONE * ON_TRAY_SCALE
				var target: Vector3 = TRAY_SLOTS[placed] + Vector3(0, 0.035, 0)
				tray.add_child(item)
				if placed >= before:
					_fly_to_tray(item, id, tray, target, (placed - before) * 0.12)
				else:
					item.position = target
				placed += 1
		counts[order["number"]] = placed
	_tray_counts = counts


func _fly_to_tray(item: Node3D, id: String, tray: Node3D, target: Vector3, delay: float) -> void:
	var start := Vector3(float(PLATE_X.get(id, COLD_X)) - tray.position.x, 0.05, 0)
	item.position = start
	var tween := item.create_tween()
	tween.tween_interval(delay)
	tween.tween_method(func(t: float) -> void:
		item.position = start.lerp(target, t) + Vector3(0, sin(t * PI) * 0.35, 0)
		item.rotation_degrees.y = t * 360.0
	, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Sfx.play.bind("pop", 0.1))
