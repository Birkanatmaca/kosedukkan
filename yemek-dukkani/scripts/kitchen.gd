class_name Kitchen
extends Node3D

## Mutfak ekranı: ızgara ve fritöz. Malzeme alttaki butonlardan seçilir,
## pişen ürüne dokununca alınır ve servis rafına (pass) konur. Rafın solunda açık
## siparişlerin tepsileri durur; "Tepsiye Koy" denince ürünler raftaki tabaklardan
## tepsiye uçar. Izgaranın altındaki kömürler kızgın kızgın parlar. Sağda taş
## fırın var: lahmacun, pizza ve pide kürekle fırına sürülür, pişince kürekle çıkarılır.
## Sadece menüdeki ürünlerin cihazları görünür; menüye yeni cihaz gelince belirir.

signal slot_added(slot: CookSlot)
## Tepsiye ürün kondu (kamera genel açıya döner, uçuş görünsün)
signal tray_filled

const GRILL_X := -0.9
const FRYER_X := 0.9
## Pişirme yerleri: önce ön sıra, geliştirmelerle orta ve arka sıra açılır (en fazla 9).
const GRILL_SLOTS := [
	Vector2(-0.55, 0.32), Vector2(0.0, 0.32), Vector2(0.55, 0.32),
	Vector2(0.0, 0.0), Vector2(-0.55, 0.0), Vector2(0.55, 0.0),
	Vector2(0.0, -0.32), Vector2(-0.55, -0.32), Vector2(0.55, -0.32),
]
## Taş fırın: tezgâhın sağında, kendi tabanında. Pişirme yerleri kubbenin içinde.
const OVEN_X := 3.25
const OVEN_FLOOR := 0.98
const OVEN_SLOTS := [Vector2(-0.2, -0.02), Vector2(0.2, -0.02), Vector2(-0.2, -0.32), Vector2(0.2, -0.32)]
## Fırın kapasitesine göre büyür: yer sayısı -> [ölçek, ağızda tek sıra dizilen x'ler].
## Ürünlerin hepsi ağızda yan yana durur (arkada kalıp görünmez olmasın).
const OVEN_LAYOUTS := {
	1: [1.0, [0.0]],
	2: [1.0, [-0.2, 0.2]],
	3: [1.18, [-0.32, 0.0, 0.32]],
	4: [1.34, [-0.45, -0.15, 0.15, 0.45]],
}
## Fırın sol kenarından (tezgâh tarafı) ve ağzından büyür: sağa ve arkaya genişler.
const OVEN_PIVOT := Vector3(OVEN_X - 0.7, 0, 0.27)
## Ürünlerin fırındaki derinliği (büyümeden önceki ölçüde)
const OVEN_SLOT_Z := -0.06
## Dokunulan noktaya bu kadar yakın ürünler aday; çiğ olanlar biraz geride sayılır.
const TAP_RADIUS := 0.5
## Kürek fırının ağzında bekler; ürünü içeri sürer ya da dışarı çeker.
const PEEL_REST_Z := 0.95
const FRYER_SLOTS := [Vector2(-0.24, 0.17), Vector2(0.24, 0.17), Vector2(-0.24, -0.2), Vector2(0.24, -0.2)]
## Her hız kademesinde pişme süresi bu oranla çarpılır.
const SPEED_STEP := 0.85
## Servis rafı: yüksekliği, solda sipariş tepsilerinin, sağda ürün tabaklarının yeri
const PASS_Y := 1.55
const PASS_Z := -0.68
## (Kamera rafın x -1.9..1.7 arasını görür; hepsi bu aralığa sığar.)
const TRAY_X := [-1.65, -1.18, -0.71, -0.24]
## Pişen ürün tabakları rafın sağ yarısına (bu aralığa) eşit aralıkla dizilir.
const PLATES_FROM := 0.22
const PLATES_TO := 1.72
## Pişirilmeyen ürünler (kola) tepsiye rafın sağ ucundan gelir.
const COLD_X := 1.75
## Tepsideki ürün yerleri (tepsinin ortasına göre)
const TRAY_SLOTS := [Vector3(-0.1, 0, -0.06), Vector3(0.1, 0, -0.06), Vector3(-0.1, 0, 0.07), Vector3(0.1, 0, 0.07), Vector3(0, 0.05, 0)]
const ON_TRAY_SCALE := 0.55
## Tepsi yerlerinin tercih sırası: yemek önce ön sıraya, içecek arka sıraya
const TRAY_FOOD_ORDER := [2, 3, 0, 1, 4]
const TRAY_DRINK_ORDER := [0, 1, 4, 2, 3]
const ON_PLATE_SCALE := 0.62
## Tam kıvam bonusu: ilk yakalayışta bu kadar bahşiş, seride her seferinde +1
## (en fazla BULLSEYE_STREAK_MAX kadar fazlası).
const BULLSEYE_TIP := 2
const BULLSEYE_STREAK_MAX := 3

var slots: Array[CookSlot] = []
var shop: Shop

var _pass_root: Node3D
var _trays_root: Node3D
## sipariş numarası -> tepsideki ürün sayısı (yeni konanları uçurmak için)
var _tray_counts := {}
var _coals: StandardMaterial3D
var _embers: Array[MeshInstance3D] = []
var _grill_light: OmniLight3D
var _oven_light: OmniLight3D
var _flames: Array[MeshInstance3D] = []
var _peel: Node3D
var _peel_tray: Node3D
var _peel_tween: Tween
var _peel_pending := Callable()
var _t := 0.0
## cihaz -> o cihazın bütün parçalarını tutan düğüm (menüde yoksa gizli)
var _device_roots := {}
## Fırının dokunma alanı (fırın büyüyünce o da büyür)
var _oven_tap: StaticBody3D
## Art arda tam kıvam yakalama sayısı (bonus büyür)
var _streak := 0
## Aşçı (Staff "asci"): tezgâhın arkasında durur, siparişleri kendisi pişirir.
var _cook: ModelBody
var _cook_timer := 0.0
## Bugün "malzeme bitti" uyarısı verilen ürünler (aynı uyarı tekrarlanmasın)
var _cook_warned := {}


func _ready() -> void:
	_build_room()
	_build_device("izgara", _build_grill)
	_build_device("fritoz", _build_fryer)
	_build_device("firin", _build_oven)
	# Kürek fırınla birlikte ölçeklenmesin: mutfağa bağlanır.
	_peel.reparent(self, false)
	_build_tap_areas()
	_build_pass()
	_sync_upgrades()
	GameState.prepared_changed.connect(_refresh_pass)
	GameState.upgrades_changed.connect(_sync_upgrades)
	GameState.menu_changed.connect(_sync_upgrades)
	shop.orders_changed.connect(_sync_trays)
	GameState.staff_changed.connect(_sync_cook)
	GameState.day_started.connect(func(_d: int) -> void: _cook_warned.clear())
	_refresh_pass()
	_sync_trays()
	_sync_cook()


## Kömürler nefes alır gibi parlar, közler tek tek yanıp söner, ışık titrer.
func _process(delta: float) -> void:
	_t += delta
	_update_cook(delta)
	# Dolu yer arttıkça ızgara daha çok cızırdar, fritöz daha çok fokurdar.
	var grill := 0
	var fryer := 0
	for slot in slots:
		if not slot.is_empty():
			if slot.device == "izgara":
				grill += 1
			elif slot.device == "fritoz":
				fryer += 1
	Sfx.set_loop_level("sizzle", 0.0 if grill == 0 else 0.45 + 0.55 * minf(1.0, grill / 4.0))
	Sfx.set_loop_level("fryer", 0.0 if fryer == 0 else 0.5 + 0.5 * minf(1.0, fryer / 3.0))
	var pulse := 0.5 + 0.5 * sin(_t * 2.3) * sin(_t * 0.7 + 1.0)
	_coals.emission_energy_multiplier = 1.4 + 0.6 * pulse
	_grill_light.light_energy = 0.9 + 0.35 * pulse + randf_range(-0.05, 0.05)
	for i in _embers.size():
		var mat := _embers[i].material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 1.5 + 2.5 * maxf(0.0, sin(_t * (1.3 + i * 0.37) + i * 2.1))
	# Fırın ateşi: alevler titreyip boy atar, ışık oynar.
	_oven_light.light_energy = 1.3 + 0.4 * sin(_t * 7.1) * sin(_t * 2.3) + randf_range(-0.08, 0.08)
	for i in _flames.size():
		var flame := _flames[i]
		flame.scale.y = 1.7 + 0.45 * sin(_t * (6.0 + i * 1.7) + i)
		flame.scale.x = 0.9 + 0.12 * sin(_t * (5.0 + i) + i * 2.0)


# --- Aşçı ---------------------------------------------------------------------------

## Aşçının durduğu yer: tezgâhın önü (kameraya sırtı dönük, cihazları örtmez);
## boşken sağda bekler, çalışırken cihazın önüne kayar.
const COOK_Z := 1.42
const COOK_REST_X := 1.2
## Aşçı ürünü bu kıvamda alır: çalışkan tam ortada, tembel biraz geç (fazla pişmiş olabilir).
const COOK_AIM := [1.13, 1.04, 1.0]


func _cook_data() -> Dictionary:
	for person in GameState.staff:
		if Staff.role(person) == "asci":
			return person
	return {}


func _sync_cook() -> void:
	var person := _cook_data()
	if _cook and (person.is_empty() or not is_same(_cook.get_meta("data"), person)):
		_cook.queue_free()
		_cook = null
	if _cook or person.is_empty():
		return
	if not person.has("look"):
		person["look"] = CharacterSkin.look_to_save(CharacterSkin.random_look())
	_cook = ModelBody.new()
	_cook.set_meta("data", person)
	add_child(_cook)
	_cook.build_model(person.get("model", Staff.WORKER_MODELS["erkek"]), CharacterSkin.look_from_save(person["look"]))
	# Beyaz aşçı önlüğü ve eldiveni
	_cook.set_uniform(Color("#f7f7f2"), Color("#e6e6e0"))
	_cook.scale = Vector3.ONE * 0.86
	_cook.position = Vector3(COOK_REST_X, 0, COOK_Z)
	_cook.rotation.y = PI
	# Başında aşçı şapkası
	var hat := Node3D.new()
	hat.position = Vector3(0, _cook.head_top + 0.02, 0)
	hat.add_child(Util.cylinder(0.11, 0.1, Color.WHITE, Vector3(0, 0.05, 0)))
	hat.add_child(Util.sphere(0.12, Color.WHITE, Vector3(0, 0.15, 0)))
	_cook.add_child(hat)
	var tag := Util.label3d("%s • Aşçı" % person["name"], 26, Color.WHITE, Vector3(0, _cook.head_top + 0.4, 0))
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.outline_size = 10
	tag.outline_modulate = Color(0.16, 0.11, 0.09)
	_cook.add_child(tag)


## Aşçının sırası: önce kıvamı gelen ürünü alır, sonra siparişlerde eksik olanı
## pişirmeye koyar, en son tamamlanabilen siparişi tepsiye koyar. Her iş kendi
## hızında sürer; oyuncu da aynı anda pişirebilir.
func _update_cook(delta: float) -> void:
	if _cook == null or not GameState.is_open:
		return
	_cook_timer -= delta
	if _cook_timer > 0.0:
		return
	var person := _cook_data()
	_cook_timer = Staff.work_time(person)
	# Tembel aşçı arada soluklanır.
	if randf() < Staff.rest_chance(person) * 0.25:
		_cook_timer *= 2.0
		_cook.relax(0.0, false, false)
		return
	var aim: float = COOK_AIM[person["work"]]
	for slot in slots:
		if not slot.is_empty() and slot.doneness() >= aim:
			_cook_take(slot)
			return
	var needs := _cook_needs()
	for id in needs:
		if needs[id] > 0 and _cook_start(id):
			return
	for order in shop.orders:
		if not order["ready"] and _completable(order):
			_cook_go(-1.2)
			shop.fill_order(order)
			return
	_cook.relax(0.0, false, false)
	_cook.position.x = move_toward(_cook.position.x, COOK_REST_X, 0.6)


## Hazır siparişlerde eksik kalan, ne rafta ne ocakta olan yemekler: ürün -> adet
func _cook_needs() -> Dictionary:
	var needs := {}
	for order in shop.orders:
		if order["ready"]:
			continue
		for id in order["items"]:
			if not Items.is_food(id):
				continue
			needs[id] = int(needs.get(id, 0)) + int(order["items"][id]) - (order["filled"][id] as Array).size()
	for id in needs:
		needs[id] -= GameState.available(id)
		for slot in slots:
			if slot.product == id and not slot.is_empty():
				needs[id] -= 1
	return needs


func _completable(order: Dictionary) -> bool:
	for id in order["items"]:
		var missing := int(order["items"][id]) - (order["filled"][id] as Array).size()
		if missing > GameState.available(id):
			return false
	return true


func _cook_start(id: String) -> bool:
	var device: String = Items.PRODUCTS[id]["device"]
	for slot in slots:
		if slot.device == device and slot.is_empty():
			if GameState.stock[id] <= 0:
				if not _cook_warned.has(id):
					_cook_warned[id] = true
					GameState.show_toast("Aşçı: %s malzemesi bitti! Marketten al" % Items.display_name(id))
				return false
			var item := GameState.take_stock_item(id)
			slot.start(id, item == 1)
			if device == "firin":
				_peel_in(slot, id)
			_cook_go(slot.global_position.x - global_position.x)
			return true
	return false


func _cook_take(slot: CookSlot) -> void:
	var id := slot.product
	var quality := Items.quality_for(slot.doneness())
	if slot.spoiled and quality > 0:
		quality = 1
	if slot.device == "firin":
		_peel_out(slot, id, quality)
	_cook_go(slot.global_position.x - global_position.x)
	slot.clear()
	Sfx.play("collect", 0.08, Main.KITCHEN)
	if quality > 0:
		GameState.add_prepared(id, quality)


## Aşçı işin başına kayar (tezgâhın arkasında, sınırlar içinde) ve çalışır.
func _cook_go(x: float) -> void:
	var target := clampf(x, -1.3, 1.25)
	_cook.create_tween().tween_property(_cook, "position:x", target, 0.3).set_trans(Tween.TRANS_SINE)
	_cook.play_action("wipe")


## Cihazı kurar ve eklediği bütün parçaları tek bir düğümün altına toplar
## (menüde değilse hepsi birlikte gizlenir).
func _build_device(device: String, build: Callable) -> void:
	var first := get_child_count()
	build.call()
	var root := Node3D.new()
	root.name = device
	var parts := get_children().slice(first)
	add_child(root)
	for part in parts:
		part.reparent(root, false)
	root.visible = false
	_device_roots[device] = root


## Menüdeki cihazları gösterir; menüye yeni gelen cihaz büyüyerek belirir.
func _sync_devices() -> void:
	var wanted := GameState.menu_devices()
	for device in _device_roots:
		var root: Node3D = _device_roots[device]
		var show := wanted.has(device)
		# (açılışta değil, oyun sırasında eklenince)
		if show and not root.visible and _t > 0.0:
			root.scale = Vector3.ONE * 0.01
			root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		root.visible = show


## Yer sayısını ve pişirme hızını geliştirmelere göre ayarlar. Pişirme yerleri
## sadece menüdeki cihazlarda açılır.
func _sync_upgrades() -> void:
	_sync_devices()
	var devices := GameState.menu_devices()
	var grill_count := Progression.BASE_GRILL_SLOTS + GameState.upgrade_level("grill_slot") if devices.has("izgara") else 0
	var fryer_count := Progression.BASE_FRYER_SLOTS + GameState.upgrade_level("fryer_slot") if devices.has("fritoz") else 0
	while _count("izgara") < mini(grill_count, GRILL_SLOTS.size()):
		var p: Vector2 = GRILL_SLOTS[_count("izgara")]
		_add_slot("izgara", Vector3(GRILL_X + p.x, 1.09, p.y))
	var oven_count := Progression.BASE_OVEN_SLOTS + GameState.upgrade_level("oven_slot") if devices.has("firin") else 0
	while _count("firin") < mini(oven_count, OVEN_SLOTS.size()):
		_add_slot("firin", Vector3(OVEN_X, OVEN_FLOOR + 0.01, OVEN_SLOT_Z))
	_layout_oven()
	while _count("fritoz") < mini(fryer_count, FRYER_SLOTS.size()):
		var p: Vector2 = FRYER_SLOTS[_count("fritoz")]
		var pos := Vector3(FRYER_X + p.x, 1.18, p.y)
		add_child(Util.box(Vector3(0.42, 0.03, 0.32), Color("#8f989f"), pos + Vector3(0, -0.005, 0)))
		add_child(Util.box(Vector3(0.05, 0.05, 0.22), Color("#2d2f33"), pos + Vector3(0, 0.02, signf(p.y) * 0.27)))
		_add_slot("fritoz", pos)
	for slot in slots:
		var upgrade: String = { "izgara": "grill_speed", "fritoz": "fryer_speed" }.get(slot.device, "")
		slot.speed = pow(SPEED_STEP, GameState.upgrade_level(upgrade)) if upgrade != "" else 1.0


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
			var item := GameState.take_stock_item(id)
			if item < 0:
				GameState.show_toast("%s bitti! Marketten al." % Items.display_name(id))
				return
			if item == 1:
				GameState.show_toast("Dikkat: %s malzemesinin tarihi geçmiş!" % Items.display_name(id))
			slot.start(id, item == 1)
			Haptics.tap()
			if device == "firin":
				_peel_in(slot, id)
			return
	GameState.show_toast("Izgara dolu!" if device == "izgara" else "Fritöz dolu!")


# --- Dokunma ve fırının büyümesi --------------------------------------------------

## Cihazların üstü de dokunma alanı: ürünlerin arasına dokununca da en yakın ürün alınır.
func _build_tap_areas() -> void:
	var areas := [
		["izgara", self, Vector3(1.75, 0.04, 1.0), Vector3(GRILL_X, 1.09, 0)],
		["fritoz", self, Vector3(1.0, 0.04, 0.9), Vector3(FRYER_X, 1.17, 0)],
		["firin", self, Vector3(1.3, 0.5, 0.75), Vector3(OVEN_X, OVEN_FLOOR + 0.25, -0.05)],
	]
	for area in areas:
		var body := Util.collider_box(area[1], area[2], area[3])
		body.set_meta("tap_at", _on_device_tapped.bind(area[0]))
		if area[0] == "firin":
			_oven_tap = body


func _on_device_tapped(point: Vector3, device: String) -> void:
	if not GameState.menu_devices().has(device):
		return
	var best := _nearest_slot(device, point)
	if best:
		_on_slot_tapped(best)
	else:
		GameState.show_toast("Aşağıdan malzeme seç")


func _on_slot_tapped_at(slot: CookSlot, point: Vector3) -> void:
	var best := _nearest_slot(slot.device, point)
	_on_slot_tapped(best if best else slot)


## Dokunulan noktaya en yakın dolu pişirme yeri; pişmiş olan çiğden önce gelir.
func _nearest_slot(device: String, point: Vector3) -> CookSlot:
	var local := to_local(point)
	var best: CookSlot = null
	var best_score := INF
	for slot in slots:
		if slot.device != device or slot.is_empty():
			continue
		var d := Vector2(slot.position.x - local.x, slot.position.z - local.z).length()
		var radius := TAP_RADIUS * (oven_scale() if device == "firin" else 1.0)
		if d > radius:
			continue
		var score := d + (0.3 if slot.doneness() < Items.RAW_LIMIT else 0.0)
		if score < best_score:
			best_score = score
			best = slot
	return best


## Fırının şu anki büyüklüğü (yer sayısına göre)
func oven_scale() -> float:
	var n := clampi(_count("firin"), 1, 4)
	return OVEN_LAYOUTS[n][0]


## Fırının ortasının x'i (büyüyünce sağa kayar)
func oven_center_x() -> float:
	return OVEN_PIVOT.x + (OVEN_X - OVEN_PIVOT.x) * oven_scale()


## Fırın gövdesini yer sayısına göre büyütür, ürünleri ağızda yan yana dizer.
func _layout_oven() -> void:
	var oven_slots := slots.filter(func(s: CookSlot) -> bool: return s.device == "firin")
	if oven_slots.is_empty():
		return
	var layout: Array = OVEN_LAYOUTS[clampi(oven_slots.size(), 1, 4)]
	var s: float = layout[0]
	var root: Node3D = _device_roots["firin"]
	var target := Transform3D(Basis.from_scale(Vector3(s, 1, s)), OVEN_PIVOT * Vector3(1 - s, 0, 1 - s))
	if root.transform.is_equal_approx(target):
		pass
	elif is_inside_tree() and _t > 0.0:
		root.create_tween().tween_property(root, "transform", target, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		root.transform = target
	if _oven_tap:
		_oven_tap.position = Vector3(OVEN_PIVOT.x + (OVEN_X - OVEN_PIVOT.x) * s, OVEN_FLOOR + 0.25, OVEN_PIVOT.z + (-0.05 - OVEN_PIVOT.z) * s)
		((_oven_tap.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = Vector3(1.3 * s, 0.5, 0.75 * s)
	var xs: Array = layout[1]
	for i in oven_slots.size():
		var slot: CookSlot = oven_slots[i]
		var local := Vector3(OVEN_X + xs[i], 0, OVEN_SLOT_Z)
		slot.position = Vector3(OVEN_PIVOT.x + (local.x - OVEN_PIVOT.x) * s, OVEN_FLOOR + 0.01, OVEN_PIVOT.z + (local.z - OVEN_PIVOT.z) * s)


func _on_slot_tapped(slot: CookSlot) -> void:
	if slot.is_empty():
		GameState.show_toast("Aşağıdan malzeme seç")
		return
	if slot.doneness() < Items.RAW_LIMIT:
		GameState.show_toast("Daha çok çiğ!")
		return
	var id := slot.product
	var quality := Items.quality_for(slot.doneness())
	if slot.spoiled and quality > 0:
		quality = 1
	var bullseye := quality == 5 and Items.is_bullseye(slot.doneness())
	var spot := slot.global_position
	if slot.device == "firin":
		_peel_out(slot, id, quality)
	slot.clear()
	Sfx.play("error" if quality == 0 else "collect", 0.08)
	if bullseye:
		_reward_bullseye(spot)
	else:
		_streak = 0
		match quality:
			0:
				GameState.show_toast("Yandı! Çöpe gitti")
				Haptics.warning()
			2: GameState.show_toast("Az pişmiş... müşteri fark edebilir")
			3: GameState.show_toast("Biraz fazla pişti")
			5: GameState.show_toast("İyi pişti! Çubuğun tam ortasında alırsan bonus var")
		if quality > 0:
			Haptics.tap()
	if quality > 0:
		GameState.add_prepared(id, quality)


## Çubuğun tam ortasında alınan ürün: bahşiş bonusu ve yükselen "TAM KIVAM!"
## yazısı. Art arda yakalandıkça bonus büyür (seri).
func _reward_bullseye(spot: Vector3) -> void:
	_streak += 1
	var bonus := BULLSEYE_TIP + mini(_streak - 1, BULLSEYE_STREAK_MAX)
	GameState.money += bonus
	GameState.record_tip(bonus)
	GameState.quest_event("bullseye")
	GameState.quest_event("streak", _streak)
	Sfx.play("coin", 0.1)
	Haptics.success()
	var text := "TAM KIVAM!\n+₺%d" % bonus
	if _streak >= 2:
		text += "  •  %d SERİ" % _streak
	var label := Util.label3d(text, 64, Color("#ffd23f"), spot + Vector3(0, 0.35, 0.1))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 14
	label.outline_modulate = Color("#5a2a00")
	label.no_depth_test = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.scale = Vector3.ONE * 0.3
	add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "position:y", label.position.y + 0.45, 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(label.queue_free)


func _add_slot(device: String, pos: Vector3) -> void:
	var slot := CookSlot.new()
	slot.device = device
	slot.position = pos
	slot.tapped.connect(_on_slot_tapped)
	slot.tapped_at.connect(_on_slot_tapped_at)
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
		if qualities.is_empty() or Items.PRODUCTS[id]["device"] == "":
			continue
		var plate := Node3D.new()
		plate.position.x = _plate_x(id)
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
	var filled := false
	for i in mini(shop.orders.size(), TRAY_X.size()):
		var order: Dictionary = shop.orders[i]
		var tray := Node3D.new()
		tray.position.x = TRAY_X[i]
		_trays_root.add_child(tray)
		tray.add_child(Util.model("equipment/tepsi", Vector3.ZERO, 90.0, 1.05))
		# Numara tepsinin önünde durur: arkadaki uzun bardakları örtmez.
		var tag := Util.label3d("#%d%s" % [order["number"], "  HAZIR" if order["ready"] else ""], 56, Color.WHITE, Vector3(0, 0.04, 0.26))
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font = UiKit.font(900)
		tag.outline_size = 16
		tag.outline_modulate = UiKit.GREEN if order["ready"] else Color("#e8553e")
		tag.pixel_size = 0.0028
		tag.no_depth_test = true
		tray.add_child(tag)
		var placed := 0
		var before: int = _tray_counts.get(order["number"], 0)
		# Yemekler ön sıradan, içecekler arka sıradan dizilir (uzun bardak yemeği örtmesin).
		var entries: Array[Array] = []
		for id in order["filled"]:
			for quality in order["filled"][id]:
				entries.append([id, quality])
		var free: Array = range(TRAY_SLOTS.size())
		for entry in entries:
			var id: String = entry[0]
			var quality: int = entry[1]
			if free.is_empty():
				break
			var drink: bool = Items.PRODUCTS[id]["device"] == ""
			var pick: int = free[0]
			for preferred in (TRAY_DRINK_ORDER if drink else TRAY_FOOD_ORDER):
				if free.has(preferred):
					pick = preferred
					break
			free.erase(pick)
			var item := Items.model(id, Util.material(Items.quality_color(id, quality)))
			item.scale = Vector3.ONE * ON_TRAY_SCALE
			var target: Vector3 = TRAY_SLOTS[pick] + Vector3(0, 0.035, 0)
			tray.add_child(item)
			if placed >= before:
				_fly_to_tray(item, id, tray, target, (placed - before) * 0.12)
				filled = true
			else:
				item.position = target
			placed += 1
		counts[order["number"]] = placed
	_tray_counts = counts
	if filled:
		tray_filled.emit()


func _fly_to_tray(item: Node3D, id: String, tray: Node3D, target: Vector3, delay: float) -> void:
	var start := Vector3(_plate_x(id) - tray.position.x, 0.05, 0)
	item.position = start
	var tween := item.create_tween()
	tween.tween_interval(delay)
	tween.tween_method(func(t: float) -> void:
		item.position = start.lerp(target, t) + Vector3(0, sin(t * PI) * 0.35, 0)
		item.rotation_degrees.y = t * 360.0
	, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Sfx.play.bind("clink", 0.12))



## Pişen ürünün raftaki tabağının yeri: açık pişirilen ürünler sırayla dizilir.
## Pişirilmeyen ürünler (içecekler) rafın sağ ucundan gelir.
func _plate_x(id: String) -> float:
	var cooked: Array[String] = []
	for key in Items.unlocked_ids():
		if Items.PRODUCTS[key]["device"] != "":
			cooked.append(key)
	var index := cooked.find(id)
	if index < 0:
		return COLD_X
	if cooked.size() == 1:
		return (PLATES_FROM + PLATES_TO) * 0.5
	return lerpf(PLATES_FROM, PLATES_TO, float(index) / (cooked.size() - 1))


## Taş fırın: taş taban, önü açık tuğla kubbe (içi görünür), kemerli ağız, baca,
## arkada odun ateşi ve kubbenin içine vuran turuncu ışık. Yanında kürek.
func _build_oven() -> void:
	var stone := Color("#8f8276")
	add_child(Util.box(Vector3(1.4, OVEN_FLOOR - 0.04, 1.3), stone, Vector3(OVEN_X, (OVEN_FLOOR - 0.04) / 2.0, -0.1)))
	for x in [-0.45, 0.0, 0.45]:
		add_child(Util.box(Vector3(0.36, 0.02, 0.02), Color("#7a6e63"), Vector3(OVEN_X + x, 0.45, 0.555)))
	add_child(Util.box(Vector3(1.34, 0.05, 1.2), Color("#c9b49a"), Vector3(OVEN_X, OVEN_FLOOR - 0.025, -0.1)))
	# Kubbe: yarım küre arkaya dönük, önü açık; içi de görünsün diye çift yüzlü.
	var dome_mat := StandardMaterial3D.new()
	dome_mat.albedo_color = Color("#a5583c")
	dome_mat.roughness = 0.95
	dome_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# SphereMesh yarım küresi ağzı kapakla kapattığından kabuk elle örülür:
	# önde yarım daire ağız, arkaya doğru çeyrek küre.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 16
	var rows := 8
	for r in rows:
		for c in cols:
			var quad: Array[Vector3] = []
			for k in [[c, r], [c + 1, r], [c + 1, r + 1], [c, r + 1]]:
				var a: float = PI * k[0] / cols
				var v: float = PI * 0.5 * k[1] / rows
				quad.append(Vector3(cos(a) * cos(v) * 0.62, sin(a) * cos(v) * 0.47, -sin(v) * 0.62))
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(quad[idx])
	st.generate_normals()
	var dome := MeshInstance3D.new()
	dome.mesh = st.commit()
	dome.material_override = dome_mat
	dome.position = Vector3(OVEN_X, OVEN_FLOOR, 0.25)
	add_child(dome)
	# Ağızdaki tuğla kemer
	for i in 13:
		var a := PI * i / 12.0
		var brick := Util.box(Vector3(0.15, 0.085, 0.14), Color("#b8623f") if i % 2 == 0 else Color("#97492f"),
			Vector3(OVEN_X + cos(a) * 0.62, OVEN_FLOOR + sin(a) * 0.62 * 0.75, 0.27))
		brick.rotation.z = a + PI / 2.0
		add_child(brick)
	add_child(Util.cylinder(0.08, 0.55, Color("#4a423c"), Vector3(OVEN_X, OVEN_FLOOR + 0.6, -0.1)))
	# Odunlar ve alevler (fırının arka tarafında)
	for x in [-0.12, 0.1]:
		var log_mesh := Util.cylinder(0.045, 0.38, Color("#5a3a22"), Vector3(OVEN_X + x, OVEN_FLOOR + 0.05, -0.5))
		log_mesh.rotation_degrees = Vector3(0, 30.0 if x > 0 else -30.0, 90)
		add_child(log_mesh)
	for i in 4:
		var flame_mat := StandardMaterial3D.new()
		flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame_mat.albedo_color = Color("#ffcf5a") if i % 2 == 0 else Color("#ff7a2a")
		flame_mat.emission_enabled = true
		flame_mat.emission = flame_mat.albedo_color
		flame_mat.emission_energy_multiplier = 2.0
		var flame := Util.sphere(0.06 if i % 2 == 0 else 0.075, flame_mat, Vector3(OVEN_X - 0.15 + i * 0.1, OVEN_FLOOR + 0.12, -0.48 + (i % 2) * 0.04))
		add_child(flame)
		_flames.append(flame)
	_oven_light = OmniLight3D.new()
	_oven_light.position = Vector3(OVEN_X, OVEN_FLOOR + 0.25, -0.25)
	_oven_light.light_color = Color("#ff8a3a")
	_oven_light.omni_range = 1.9
	add_child(_oven_light)
	# Kürek: uzun sap, ucunda yassı ahşap kürek; ürün kürekte taşınır.
	_peel = Node3D.new()
	_peel.visible = false
	add_child(_peel)
	var wood := Color("#c89a63")
	_peel.add_child(Util.box(Vector3(0.34, 0.012, 0.32), wood, Vector3.ZERO))
	var handle := Util.cylinder(0.018, 1.1, Color("#a97b48"), Vector3(0, 0.01, 0.7))
	handle.rotation_degrees.x = 90
	_peel.add_child(handle)
	_peel_tray = Node3D.new()
	_peel_tray.position.y = 0.01
	_peel.add_child(_peel_tray)


## Çiğ hamuru kürekle fırına sürer: ürün kürek yerine varınca fırında görünür.
func _peel_in(slot: CookSlot, id: String) -> void:
	slot.hide_item(true)
	_load_peel(Items.model(id, Util.material(Items.cook_color(id, 0.0))))
	_peel_move(slot, func() -> void:
		_load_peel(null)
		slot.hide_item(false)
		Sfx.play("collect", 0.1)
	)


## Pişen ürünü kürekle fırından çıkarır.
func _peel_out(slot: CookSlot, id: String, quality: int) -> void:
	var item := Items.model(id, Util.material(Items.quality_color(id, quality)))
	_load_peel(null)
	_peel_move(slot, func() -> void: _load_peel(item))


func _load_peel(item: Node3D) -> void:
	for child in _peel_tray.get_children():
		child.queue_free()
	if item:
		_peel_tray.add_child(item)


## Kürek fırının ağzından pişirme yerine gider, at_slot çağrılır, sonra geri çekilip kaybolur.
func _peel_move(slot: CookSlot, at_slot: Callable) -> void:
	var target := Vector3(slot.position.x, OVEN_FLOOR + 0.015, slot.position.z)
	var rest := Vector3(target.x, OVEN_FLOOR + 0.05, PEEL_REST_Z)
	# Önceki kürek hareketi yarıda kesilirse bekleyen adımı (ürünü bırakma) tamamla.
	if _peel_tween and _peel_tween.is_valid():
		_peel_tween.kill()
		if _peel_pending.is_valid():
			_peel_pending.call()
	_peel_pending = at_slot
	_peel.position = rest
	_peel.visible = true
	var tween := _peel.create_tween()
	_peel_tween = tween
	tween.tween_property(_peel, "position", target, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_peel_pending = Callable()
		at_slot.call()
	)
	tween.tween_interval(0.08)
	tween.tween_property(_peel, "position", rest + Vector3(0, 0, 0.35), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_peel.visible = false
		_load_peel(null)
	)
