class_name Kitchen
extends Node3D

## Mutfak ekranı: ızgara ve fritöz. Malzeme alttaki butonlardan seçilir,
## pişen ürüne dokununca alınır ve servis rafına (pass) konur.

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

var slots: Array[CookSlot] = []

var _pass_root: Node3D


func _ready() -> void:
	_build_room()
	_build_grill()
	_build_fryer()
	_build_pass()
	_sync_upgrades()
	GameState.prepared_changed.connect(_refresh_pass)
	GameState.upgrades_changed.connect(_sync_upgrades)


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
	add_child(Util.box(Vector3(1.65, 0.02, 0.9), Color("#a33a1a"), Vector3(GRILL_X, 1.06, 0)))
	for i in 9:
		add_child(Util.box(Vector3(1.65, 0.025, 0.035), Color("#141414"), Vector3(GRILL_X, 1.08, -0.4 + i * 0.1)))
	add_child(Util.box(Vector3(1.75, 0.1, 0.06), Color("#3d4046"), Vector3(GRILL_X, 0.98, 0.52)))
	for k in 3:
		add_child(Util.cylinder(0.035, 0.05, Color("#d0d0d0"), Vector3(GRILL_X - 0.5 + k * 0.5, 0.98, 0.56)))


func _build_fryer() -> void:
	add_child(Util.box(Vector3(1.15, 0.26, 1.0), Color("#b9c2cc"), Vector3(FRYER_X, 1.05, 0)))
	add_child(Util.box(Vector3(0.95, 0.02, 0.75), Color("#e0a83a"), Vector3(FRYER_X, 1.17, 0)))


func _build_pass() -> void:
	add_child(Util.box(Vector3(4.4, 0.06, 0.4), Color("#c9d1d9"), Vector3(0, 1.95, -0.75)))
	add_child(Util.box(Vector3(4.4, 0.1, 0.3), Color("#e8553e"), Vector3(0, 2.55, -0.72)))
	for x in [-2.1, 2.1]:
		add_child(Util.box(Vector3(0.05, 0.65, 0.05), Color("#9aa4ae"), Vector3(x, 2.25, -0.75)))
	var heat := OmniLight3D.new()
	heat.position = Vector3(0, 2.35, -0.6)
	heat.light_color = Color("#ff9a5a")
	heat.light_energy = 0.3
	heat.omni_range = 2.0
	add_child(heat)
	_pass_root = Node3D.new()
	_pass_root.position = Vector3(0, 1.98, -0.75)
	add_child(_pass_root)


func _refresh_pass() -> void:
	for child in _pass_root.get_children():
		child.queue_free()
	var i := 0
	for id in GameState.prepared:
		for quality in GameState.prepared[id]:
			if i >= 14:
				return
			var item := Items.model(id, Util.material(Items.quality_color(id, quality)))
			item.position = Vector3(-1.95 + i * 0.3, 0, 0)
			_pass_root.add_child(item)
			i += 1
