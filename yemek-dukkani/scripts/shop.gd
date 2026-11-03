class_name Shop
extends Node3D

## Dükkan ekranı. Kamera kasanın arkasından salona bakar: müşteriler en
## arkadaki kapıdan girip ortadaki koridordan tezgâha gelir. Servis edilince
## tepsisini alıp temiz ve boş bir masaya oturur, yer, yorumunu bırakıp çıkar.
## Masa kirli kalır; garson ya da oyuncu (masaya dokunarak) temizleyene kadar
## kullanılamaz. Boş masa yoksa müşteri tepsisiyle ayakta bekler, bulamazsa
## tepsiyi kasaya geri getirip parasını geri alır.

signal customer_added(customer: ShopCustomer)
signal customer_removed(customer: ShopCustomer)
signal payment_requested(customer: ShopCustomer, amount: int)
signal sale_completed(customer: ShopCustomer, amount: int, tip: int)

const SPOTS := [Vector3(-1.5, 0, -0.4), Vector3(0, 0, -0.6), Vector3(1.5, 0, -0.4)]
const DOOR := Vector3(0, 0, -9.9)
## Koridorun tezgâha en yakın noktası; kasa dolunca sıra buradan geriye uzar.
const AISLE_FRONT := Vector3(0, 0, -1.7)
const QUEUE_SPACING := 0.75
## Tepsinin konduğu yer (kasanın hemen solu) ve müşterinin onu aldığı nokta.
const TRAY_SPOT := Vector3(0.0, 0.98, 0.92)
const PICKUP_SPOT := Vector3(0.0, 0, 0.35)
## Masaya giden / masadan çıkan müşteriler sıranın içinden geçmesin diye
## koridorun iki yanındaki şeritten yürür.
const SIDE_LANE_X := 1.05
## İlk BASE_TABLES masa açık, kalanları "Yeni Masalar" geliştirmesiyle açılır.
const TABLES := [
	Vector3(-2.5, 0, -3.0), Vector3(2.5, 0, -3.0),
	Vector3(-2.5, 0, -5.3), Vector3(2.5, 0, -5.3),
	Vector3(-2.5, 0, -7.6), Vector3(2.5, 0, -7.6),
]
## Masanın merkezinden sandalyeye uzaklık (x ekseninde).
const SEAT_OFFSET := 0.85
## Masaya yaklaşırken kullanılan, masaların önündeki boş şerit.
const LANE_OFFSET := 1.05
const NAMES := ["Ayşe", "Mehmet", "Zeynep", "Can", "Elif", "Burak", "Selin", "Emre", "Deniz", "Ece", "Kerem", "Defne", "Mert", "Ada"]
## Masa bulamayan müşteri bu masanın ucunda (önünde, dış tarafta) ayakta bekler.
const STAND_OFFSET := Vector3(0.5, 0, 0.78)

## Kasanın önündeki 3 yer
var spots: Array = [null, null, null]
## Kasanın arkasındaki sıra (önden arkaya)
var queue: Array[ShopCustomer] = []
## Her masa: { "pos", "customer", "dirty", "tray", "cleaner", "mark" }. Bir masada tek müşteri oturur.
var tables: Array[Dictionary] = []
## Masa ucunda ayakta bekleyenler (TABLES ile aynı sırada; boşsa null)
var standing: Array = [null, null, null, null, null, null]
## Kasada ödemesi alınan müşteri (aynı anda tek ödeme).
var paying: ShopCustomer
var register: CashRegister

var _spawn_timer := 2.0
var _workers: Array[Worker] = []
# Dekor parçaları (kurulumda değişir)
var _wall_mat: StandardMaterial3D
var _side_mat: StandardMaterial3D
var _panel_mat: StandardMaterial3D
var _floor_mat: ShaderMaterial
var _junk: Node3D
var _cracks: Node3D
var _boards: Node3D
var _sign: Node3D
var _sign_label: Label3D
var _ceiling: MeshInstance3D
var _plants: Array[Node3D] = []
var _lamps: Array[OmniLight3D] = []
var _bulbs: Array[MeshInstance3D] = []


func _ready() -> void:
	_build_room()
	_apply_decor()
	_sync_staff()
	GameState.upgrades_changed.connect(_sync_tables)
	GameState.decor_changed.connect(_apply_decor)
	GameState.setup_finished.connect(_apply_decor)
	GameState.staff_changed.connect(_sync_staff)


func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = Progression.spawn_interval(GameState.level, GameState.rating()) * (1.0 - Decor.spawn_bonus(GameState.decor))
		if GameState.tutorial_active():
			# Tanıtımda tek müşteri gelir, o çıkınca sıradaki.
			_spawn_timer = 1.0
			if GameState.tutorial_step <= 6 and _customer_count() == 0 and GameState.accepting_customers():
				_spawn()
		elif GameState.accepting_customers() and _customer_count() < Progression.max_customers():
			# Kasada boş yer varsa doğrudan oraya, yoksa sıra sınırına kadar sıraya.
			var counter_free := spots.has(null) and queue.is_empty()
			if counter_free or queue.size() < Progression.max_queue(GameState.level):
				_spawn()

	_update_standing()
	# Kapanış saati geldi ve içeride kimse kalmadıysa gün biter.
	if GameState.is_open and GameState.minutes >= GameState.CLOSE_TIME and _customer_count() == 0:
		GameState.end_day()

	# Kasada yer boşaldıysa sıradaki öne geçer.
	var free := spots.find(null)
	if free != -1 and not queue.is_empty():
		var next: ShopCustomer = queue.pop_front()
		spots[free] = next
		next.state = ShopCustomer.State.ARRIVING
		next.follow([SPOTS[free]], 0.0)
		customer_added.emit(next)
		_update_queue()

	for customer in spots:
		if customer and customer.state == ShopCustomer.State.WAITING and customer.patience <= 0.0:
			_leave_angry(customer)
	for customer in queue.duplicate():
		if customer.patience <= 0.0:
			_leave_angry(customer)


## Kasada ya da sırada bekleyen müşteri sayısı.
func waiting_count() -> int:
	var count := queue.size()
	for customer in spots:
		if customer and customer.state == ShopCustomer.State.WAITING:
			count += 1
	return count


## Siparişin tamamı hazırsa servis eder. Eksik varsa bildirim gösterir.
func serve(customer: ShopCustomer) -> bool:
	if customer.state != ShopCustomer.State.WAITING:
		return false
	if paying:
		GameState.show_toast("Önce kasadaki ödemeyi tamamla")
		return false
	var missing: Array[String] = []
	for id in customer.order:
		if GameState.available(id) < int(customer.order[id]):
			missing.append(Items.display_name(id))
	if not missing.is_empty():
		GameState.show_toast("Eksik: " + ", ".join(missing))
		return false

	var price := 0
	var quality_sum := 0
	var under: Array[String] = []
	var over: Array[String] = []
	var served: Array[Array] = []
	for id in customer.order:
		for i in int(customer.order[id]):
			var quality := GameState.take_for_order(id)
			served.append([id, quality])
			quality_sum += quality
			price += int(Items.PRODUCTS[id]["price"])
			if quality == 2 and not under.has(Items.display_name(id)):
				under.append(Items.display_name(id))
			elif quality == 3 and not over.has(Items.display_name(id)):
				over.append(Items.display_name(id))

	var wait_ratio := customer.patience / customer.max_patience
	var stars := roundi(float(quality_sum) / customer.item_count())
	if wait_ratio < 0.25:
		stars -= 1
	stars = clampi(stars, 1, 5)
	customer.sale_price = price
	customer.sale_tip = roundi(price * 0.2) if stars == 5 else 0
	customer.served_items = served
	customer.pending_review = [stars, _review_text(stars, wait_ratio, under, over)]
	customer.state = ShopCustomer.State.PAYING
	paying = customer
	payment_requested.emit(customer, price)
	return true


## Kasa ödemeyi bitirince çağrılır. loss: fazladan verilen paraüstü.
func complete_payment(customer: ShopCustomer, loss: int) -> void:
	paying = null
	GameState.money += customer.sale_price + customer.sale_tip - loss
	if loss > 0:
		GameState.show_toast("₺%d fazla paraüstü verdin!" % loss)
	sale_completed.emit(customer, customer.sale_price, customer.sale_tip)
	GameState.record_sale(customer.sale_price, customer.sale_tip)
	GameState.add_xp(Progression.sale_xp(customer.item_count(), customer.pending_review[0]))

	# Tepsi kasanın yanına konur; müşteri teslim noktasına gelip alır.
	var tray := _make_tray(customer.served_items)
	add_child(tray)
	tray.position = TRAY_SPOT
	customer.follow([PICKUP_SPOT], 0.0)
	var delay := maxf(0.35 + 0.18 * customer.served_items.size(), 0.9) + 0.25
	get_tree().create_timer(delay).timeout.connect(_pick_up.bind(customer, tray))


## Müşteri tepsiyi alır; temiz ve boş masa varsa oturmaya, yoksa ayakta beklemeye gider.
func _pick_up(customer: ShopCustomer, tray: Node3D) -> void:
	if not is_instance_valid(customer):
		tray.queue_free()
		return
	customer.take(tray)
	_release_spot(customer)
	if _reserve_table(customer):
		_send_to_seat(customer, customer.position)
		return
	# Açık masaların ucundaki boş bekleme yerlerinden birine gider.
	var spot := -1
	for i in tables.size():
		if standing[i] == null:
			spot = i
			break
	if spot == -1:
		_give_up(customer)
		return
	standing[spot] = customer
	customer.wait_for_table(corridor_path(customer.position, stand_spot(spot)), PI)
	GameState.show_toast("Boş masa yok! %s masa başında bekliyor" % customer.customer_name)


## i. masanın ucundaki ayakta bekleme noktası (masanın dış yanında, önünde).
func stand_spot(i: int) -> Vector3:
	var pos: Vector3 = TABLES[i]
	return pos + Vector3(signf(pos.x) * STAND_OFFSET.x, 0, STAND_OFFSET.z)


## Salonda masaların arasından geçmeden yürünen yol: önce bulunduğu sıranın
## şeridinden koridor kenarına, oradan hedefin sırasına, sonra hedefe.
static func corridor_path(from: Vector3, to: Vector3) -> Array:
	var a := signf(from.x) if absf(from.x) > 0.01 else signf(to.x)
	if a == 0.0:
		a = 1.0
	var b := signf(to.x) if absf(to.x) > 0.01 else a
	var path: Array = [Vector3(a * SIDE_LANE_X, 0, from.z)]
	if a != b:
		path.append(Vector3(b * SIDE_LANE_X, 0, from.z))
	path.append(Vector3(b * SIDE_LANE_X, 0, to.z))
	path.append(to)
	return path


## Masası ayrılmış müşteriyi koridorun yan şeridinden sandalyesine yürütür.
func _send_to_seat(customer: ShopCustomer, from: Vector3) -> void:
	var table_pos: Vector3 = customer.seat["table"]["pos"]
	var pos: Vector3 = customer.seat["pos"]
	var side := signf(pos.x - table_pos.x)
	var lane_z := table_pos.z + LANE_OFFSET
	var path: Array = []
	if from.z > AISLE_FRONT.z:
		# Kasadan geliyor: önce koridorun yan şeridine geçer.
		var lane_x := signf(table_pos.x) * SIDE_LANE_X
		path = [Vector3(lane_x, 0, AISLE_FRONT.z), Vector3(lane_x, 0, lane_z)]
	else:
		# Masa başında bekliyordu: salon koridorlarından masasının önüne gelir.
		path = corridor_path(from, Vector3(pos.x, 0, lane_z))
	if path.back() != Vector3(pos.x, 0, lane_z):
		path.append(Vector3(pos.x, 0, lane_z))
	path.append(pos)
	# Masaya dönük oturur.
	customer.go_sit(path, -side * PI * 0.5)


## Ayakta bekleyenlere masa açılırsa oturtur; süresi dolan tepsiyi geri getirir.
func _update_standing() -> void:
	for i in standing.size():
		var customer: ShopCustomer = standing[i]
		if customer == null or customer.state != ShopCustomer.State.WAIT_TABLE:
			continue
		if _reserve_table(customer):
			standing[i] = null
			_send_to_seat(customer, customer.position)
		elif customer.table_wait <= 0.0:
			standing[i] = null
			_give_up(customer)


## Oturacak yer bulamadı: tepsiyi kasaya geri getirir, parasını geri alır.
func _give_up(customer: ShopCustomer) -> void:
	customer.returned_tray.connect(_on_returned_tray, CONNECT_ONE_SHOT)
	var path := corridor_path(customer.position, Vector3(signf(customer.position.x) * SIDE_LANE_X, 0, AISLE_FRONT.z))
	path.append(PICKUP_SPOT)
	customer.return_tray(path)


func _on_returned_tray(customer: ShopCustomer) -> void:
	var tray := customer.put_down()
	if tray:
		tray.reparent(self)
		tray.create_tween().tween_property(tray, "position", TRAY_SPOT, 0.25)
		get_tree().create_timer(1.2).timeout.connect(tray.queue_free)
	GameState.money -= customer.sale_price
	GameState.record_refund(customer.sale_price)
	GameState.record_lost_customer()
	GameState.show_toast("%s oturacak yer bulamadı, ₺%d iade aldı" % [customer.customer_name, customer.sale_price])
	Sfx.play("error")
	customer.pending_review = []
	GameState.add_review(1, "Oturacak temiz masa yoktu, tepsimi geri verdim.", customer.customer_name)
	customer.leave(_exit_path(customer.position, [-1.0, 1.0].pick_random()))


## Yeni müşteri kapıdan girer: kasada yer varsa oraya, yoksa sıranın sonuna.
func _spawn() -> void:
	var customer := ShopCustomer.new()
	customer.customer_name = NAMES.pick_random()
	customer.order = Progression.random_order(GameState.level)
	customer.max_patience = Progression.patience(GameState.level, customer.item_count(), GameState.upgrade_level("comfort"))
	customer.max_patience *= 1.0 + Decor.patience_bonus(GameState.decor)
	if GameState.tutorial_active():
		# Tanıtım müşterisi tek köfte ister ve sabrı tükenmez.
		customer.order = { "kofte": 1 }
		customer.max_patience = 9999.0
	customer.tap = serve.bind(customer)
	customer.sat_down.connect(_on_sat_down)
	customer.finished_eating.connect(_on_finished_eating)
	add_child(customer)
	customer.position = DOOR

	var free := spots.find(null)
	if free != -1 and queue.is_empty():
		spots[free] = customer
		customer.follow([AISLE_FRONT, SPOTS[free]], 0.0)
		customer_added.emit(customer)
	else:
		customer.state = ShopCustomer.State.QUEUED
		queue.append(customer)
		_update_queue()


## Sıradakileri koridorda arka arkaya dizer.
func _update_queue() -> void:
	for i in queue.size():
		queue[i].follow([AISLE_FRONT + Vector3(0, 0, -QUEUE_SPACING * i)], 0.0)


## Temiz ve boş bir masa ayırır; yoksa false.
func _reserve_table(customer: ShopCustomer) -> bool:
	var free := tables.filter(func(t: Dictionary) -> bool: return t["customer"] == null and not t["dirty"])
	if free.is_empty():
		return false
	var table: Dictionary = free.pick_random()
	table["customer"] = customer
	var side: float = [-1.0, 1.0].pick_random()
	customer.seat = { "pos": (table["pos"] as Vector3) + Vector3(side * SEAT_OFFSET, 0, 0), "table": table }
	return true


## Tepsi: ürünler tabaklarda, tek tek "pop" diye konur.
func _make_tray(served_items: Array[Array]) -> Node3D:
	var tray := Node3D.new()
	tray.add_child(Util.box(Vector3(0.54, 0.025, 0.36), Color("#b5452f"), Vector3(0, 0.0125, 0)))
	for z in [-0.17, 0.17]:
		tray.add_child(Util.box(Vector3(0.54, 0.035, 0.02), Color("#9a3a28"), Vector3(0, 0.03, z)))
	for x in [-0.26, 0.26]:
		tray.add_child(Util.box(Vector3(0.02, 0.035, 0.36), Color("#9a3a28"), Vector3(x, 0.03, 0)))
	tray.add_child(Util.box(Vector3(0.46, 0.004, 0.28), Color("#f6ecd9"), Vector3(0, 0.027, 0)))

	var items := Node3D.new()
	items.name = "Items"
	items.position.y = 0.03
	tray.add_child(items)
	var count := served_items.size()
	for i in count:
		var id: String = served_items[i][0]
		var slot := Node3D.new()
		slot.position = Vector3((i - (count - 1) * 0.5) * 0.15, 0, 0)
		if id != "kola":
			slot.add_child(Util.cylinder(0.07, 0.012, Color("#ffffff"), Vector3(0, 0.006, 0)))
		var item := Items.model(id, Util.material(Items.quality_color(id, served_items[i][1])))
		item.position.y = 0.012
		item.rotation_degrees.y = 90.0
		item.scale = Vector3.ONE * 0.6
		slot.add_child(item)
		items.add_child(slot)
		slot.scale = Vector3.ONE * 0.01
		var tween := slot.create_tween()
		tween.tween_interval(0.1 + i * 0.18)
		tween.tween_callback(Sfx.play.bind("pop", 0.1))
		tween.tween_property(slot, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tray


## Müşteri masaya varınca tepsiyi masaya bırakır.
func _on_sat_down(customer: ShopCustomer) -> void:
	var seat := customer.seat
	var table: Vector3 = seat["table"]["pos"]
	var side := signf((seat["pos"] as Vector3).x - table.x)
	var tray := customer.put_down()
	if tray == null:
		return
	tray.reparent(self)
	tray.rotation = Vector3(0, PI * 0.5, 0)
	tray.create_tween().tween_property(tray, "position", table + Vector3(side * 0.3, 0.81, 0), 0.25)
	customer.food = tray


## Yemek bitince tepsi ve kırıntılar masada kalır; masa kirlenir.
func _on_finished_eating(customer: ShopCustomer) -> void:
	var seat := customer.seat
	var table: Dictionary = seat["table"]
	table["customer"] = null
	if customer.food:
		_leave_mess(table, customer.food)
		customer.food = null
	_post_review(customer)
	var pos: Vector3 = seat["pos"]
	var table_pos: Vector3 = seat["table"]["pos"]
	var lane_z := table_pos.z + LANE_OFFSET
	var path: Array = [Vector3(pos.x, 0, lane_z)]
	path.append_array(_exit_path(Vector3(0, 0, lane_z), signf(table_pos.x)))
	customer.leave(path)


## Koridorun yan şeridinden kapıya giden yol (sıranın içinden geçmez).
func _exit_path(from: Vector3, side: float) -> Array:
	var lane_x := side * SIDE_LANE_X
	return [Vector3(lane_x, 0, minf(from.z, AISLE_FRONT.z)), Vector3(lane_x, 0, DOOR.z + 0.7), DOOR]


func _post_review(customer: ShopCustomer) -> void:
	if customer.pending_review.is_empty():
		return
	GameState.add_review(customer.pending_review[0], customer.pending_review[1], customer.customer_name)
	customer.pending_review = []


func _leave_angry(customer: ShopCustomer) -> void:
	var in_queue := queue.has(customer)
	var text := "Sıra çok uzundu, beklemekten vazgeçtim." if in_queue else "Çok bekledim, siparişim hiç alınmadı!"
	GameState.add_review(1, text, customer.customer_name)
	GameState.show_toast("%s beklemekten sıkılıp gitti!" % customer.customer_name)
	GameState.record_lost_customer()
	Sfx.play("error")
	customer.angry = true
	if in_queue:
		queue.erase(customer)
		_update_queue()
	else:
		_release_spot(customer)
	customer.leave(_exit_path(customer.position, [-1.0, 1.0].pick_random()))


func _release_spot(customer: ShopCustomer) -> void:
	var index := spots.find(customer)
	if index != -1:
		spots[index] = null
	customer_removed.emit(customer)


## Açık masa sayısını geliştirmeye göre ayarlar; yeni açılanları kurar.
## Masa sayısı: kurulumda alınanlar + "Yeni Masalar" geliştirmesi.
## Kurulumda masa azaltılabildiği için fazlalar kaldırılır.
func _sync_tables() -> void:
	var count := mini(GameState.decor["tables"] + 2 * GameState.upgrade_level("tables"), TABLES.size())
	while tables.size() > count:
		var table: Dictionary = tables.pop_back()
		(table["root"] as Node3D).queue_free()
	while tables.size() < count:
		_build_table(TABLES[tables.size()])


# --- Kirli masalar ------------------------------------------------------------

## Yemek bitince boş tabaklı tepsi ve kırıntılar masada kalır.
func _leave_mess(table: Dictionary, tray: Node3D) -> void:
	var items: Node3D = tray.get_node_or_null("Items")
	if items:
		items.scale = Vector3.ONE * 0.25
	for i in 5:
		tray.add_child(Util.sphere(0.012, Color("#8a5a2e"), Vector3(randf_range(-0.2, 0.2), 0.035, randf_range(-0.12, 0.12))))
	table["dirty"] = true
	table["tray"] = tray
	(table["mark"] as Node3D).visible = true


## Garson temizleyecek kirli masa ister; varsa ona ayrılır.
func claim_dirty_table(worker: Worker) -> Dictionary:
	for table in tables:
		if table["dirty"] and table["cleaner"] == null:
			table["cleaner"] = worker
			return table
	return {}


## Garson silerken masanın üstünde ilerleme yüzdesi görünür.
func set_clean_progress(table: Dictionary, progress: float) -> void:
	var label: Label3D = table["progress"]
	label.visible = true
	label.text = "%%%d" % clampi(roundi(progress * 100.0), 0, 100)


## İşten çıkarılan garsonun yarım bıraktığı masa yeniden kirli bekler.
func release_cleaning(table: Dictionary) -> void:
	table["cleaner"] = null
	(table["progress"] as Label3D).visible = false


## Garson masayı temizledi: tepsiyi ona verir, masa temizlenir.
func collect_tray(table: Dictionary) -> Node3D:
	var tray: Node3D = table["tray"]
	table["tray"] = null
	_clean_table(table)
	return tray


## Oyuncu kirli masaya dokunarak kendisi de temizleyebilir.
func _on_table_tapped(table: Dictionary) -> void:
	if not table["dirty"]:
		return
	if table["cleaner"] != null:
		GameState.show_toast("Garson bu masayı temizliyor")
		return
	if table["tray"]:
		(table["tray"] as Node3D).queue_free()
		table["tray"] = null
	_clean_table(table)


func _clean_table(table: Dictionary) -> void:
	table["dirty"] = false
	table["cleaner"] = null
	(table["mark"] as Node3D).visible = false
	(table["progress"] as Label3D).visible = false
	Util.float_text(self, (table["pos"] as Vector3) + Vector3(0, 1.2, 0), "Temiz!", UiKit.GREEN)
	Sfx.play("pop")


# --- Personel ------------------------------------------------------------------

## İşe alınan personeli dükkana getirir, çıkarılanları gönderir.
func _sync_staff() -> void:
	for worker in _workers.duplicate():
		if not GameState.staff.any(func(p: Dictionary) -> bool: return is_same(p, worker.data)):
			_workers.erase(worker)
			worker.fire()
	for person in GameState.staff:
		if not _workers.any(func(w: Worker) -> bool: return is_same(w.data, person)):
			var worker := Worker.new()
			worker.data = person
			worker.shop = self
			add_child(worker)
			worker.position = DOOR
			_workers.append(worker)


## İçerideki müşteri sayısı (gün sonunu belirlemek için).
func _customer_count() -> int:
	var count := 0
	for child in get_children():
		if child is ShopCustomer:
			count += 1
	return count


func _review_text(stars: int, wait_ratio: float, under: Array[String], over: Array[String]) -> String:
	var parts: Array[String] = []
	if not under.is_empty():
		parts.append("%s az pişmişti." % ", ".join(under))
	if not over.is_empty():
		parts.append("%s biraz fazla pişmişti." % ", ".join(over))
	if wait_ratio < 0.25:
		parts.append("Çok bekledim.")
	if parts.is_empty():
		if wait_ratio > 0.7:
			return ["Servis çok hızlıydı, her şey tam kıvamındaydı!", "Hem hızlı hem lezzetli, yine gelirim!"].pick_random()
		return ["Her şey tam kıvamındaydı, yine gelirim!", "Harika lezzet, ellerinize sağlık!", "Mükemmeldi, herkese tavsiye ederim!"].pick_random()
	if stars >= 4:
		parts.append("Yine de lezzetliydi.")
	return " ".join(parts)


func _build_room() -> void:
	_wall_mat = StandardMaterial3D.new()
	_side_mat = StandardMaterial3D.new()
	_panel_mat = StandardMaterial3D.new()
	for mat in [_wall_mat, _side_mat, _panel_mat]:
		mat.roughness = 0.8
	_floor_mat = Util.tile_material(Color.WHITE, Color.WHITE, 1.2)
	add_child(Util.box(Vector3(12, 0.1, 12.2), _floor_mat, Vector3(0, -0.05, -3.9)))
	# Tavan: kurulumda salona yukarıdan bakılsın diye gizlidir.
	_ceiling = Util.box(Vector3(12, 0.1, 12.2), Color("#fbf3e6"), Vector3(0, 4.5, -3.9))
	add_child(_ceiling)

	# Arka duvar: ortada kapı, iki yanda pencere, kapının üstünde tabela.
	add_child(Util.box(Vector3(12, 4.5, 0.2), _wall_mat, Vector3(0, 2.25, -10.1)))
	add_child(Util.box(Vector3(12, 1.0, 0.22), _panel_mat, Vector3(0, 0.5, -10.08)))
	add_child(Util.box(Vector3(1.7, 2.6, 0.06), Color("#ffffff"), Vector3(0, 1.3, -9.99)))
	add_child(Util.box(Vector3(1.5, 2.5, 0.07), Color("#7a4b32"), Vector3(0, 1.25, -9.97)))
	add_child(Util.box(Vector3(1.1, 1.0, 0.08), Color("#bfe3f2"), Vector3(0, 1.75, -9.95)))
	_sign = Node3D.new()
	add_child(_sign)
	_sign.add_child(Util.box(Vector3(3.6, 0.8, 0.1), Color("#e8553e"), Vector3(0, 3.3, -9.97)))
	_sign_label = Util.label3d("", 130, Color.WHITE, Vector3(0, 3.3, -9.91))
	_sign.add_child(_sign_label)
	for x in [-3.6, 3.6]:
		_window(Vector3(x, 2.0, -9.99), false)

	# Yan duvarlar, lambri ve pencereler
	for side in [-1.0, 1.0]:
		var x: float = side * 6.0
		add_child(Util.box(Vector3(0.2, 4.5, 12.2), _side_mat, Vector3(x, 2.25, -3.9)))
		add_child(Util.box(Vector3(0.22, 1.0, 12.2), _panel_mat, Vector3(x - side * 0.01, 0.5, -3.9)))
		for z in [-3.0, -6.4]:
			_window(Vector3(x - side * 0.11, 2.1, z), true)

	_build_ruin()

	# Köşelerdeki bitkiler (kurulumda alınan kadarı görünür)
	for pos in [Vector3(-5.4, 0, -1.2), Vector3(5.4, 0, -1.2), Vector3(-5.4, 0, -9.4), Vector3(5.4, 0, -9.4)]:
		var plant := Node3D.new()
		plant.position = pos
		plant.add_child(Util.cylinder(0.25, 0.5, Color("#c0703f"), Vector3(0, 0.25, 0)))
		plant.add_child(Util.sphere(0.42, Color("#4f9a52"), Vector3(0, 0.85, 0)))
		plant.add_child(Util.sphere(0.3, Color("#5fb062"), Vector3(0.12, 1.2, 0.05)))
		add_child(plant)
		_plants.append(plant)

	# Koridor boyunca sarkan lambalar: kurulumda alınmadıysa kırık ve sönük.
	for z in [-2.6, -5.6, -8.4]:
		add_child(Util.cylinder(0.01, 0.8, Color("#333333"), Vector3(0, 4.1, z)))
		add_child(Util.cylinder(0.22, 0.12, Color("#3a3f47"), Vector3(0, 3.66, z)))
		var bulb := Util.sphere(0.12, Color("#ffd27a"), Vector3(0, 3.56, z))
		add_child(bulb)
		_bulbs.append(bulb)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, 3.4, z)
		lamp.light_color = Color("#ffd9a0")
		lamp.omni_range = 6.0
		add_child(lamp)
		_lamps.append(lamp)

	# Kasa tezgâhı (kameraya en yakın)
	add_child(Util.box(Vector3(6.4, 0.9, 0.7), Color("#c0703f"), Vector3(0, 0.45, 1.2)))
	for i in 7:
		add_child(Util.box(Vector3(0.04, 0.8, 0.02), Color("#a85f33"), Vector3(-2.7 + i * 0.9, 0.45, 1.56)))
	add_child(Util.box(Vector3(6.6, 0.08, 0.8), Color("#f3efe9"), Vector3(0, 0.94, 1.2)))
	register = CashRegister.new()
	register.position = Vector3(0.75, 0.98, 1.15)
	register.rotation_degrees.y = -10
	add_child(register)


## Harabe hali: duvar lekeleri, zemin çatlakları, çöp yığınları, örümcek ağları
## ve pencerelere çakılmış tahtalar. Temizlik / pencere alınınca kaybolur.
func _build_ruin() -> void:
	_junk = Node3D.new()
	add_child(_junk)
	var stain := Color("#5d564c")
	for pos in [Vector3(-3.0, 1.6, -9.99), Vector3(2.4, 2.8, -9.99), Vector3(4.8, 1.2, -9.99)]:
		_junk.add_child(Util.box(Vector3(1.1, 0.8, 0.02), stain, pos))
	for side in [-1.0, 1.0]:
		_junk.add_child(Util.box(Vector3(0.02, 0.9, 1.4), stain, Vector3(side * 5.89, 2.6, -4.6)))
	# Çöp yığınları, kırık kasalar, çöp poşetleri
	for pos in [Vector3(-3.4, 0, -3.6), Vector3(3.0, 0, -5.8), Vector3(-1.8, 0, -7.4), Vector3(4.2, 0, -2.4), Vector3(-4.4, 0, -6.2)]:
		_junk.add_child(Util.box(Vector3(0.6, 0.45, 0.5), Color("#6b5a45"), pos + Vector3(0, 0.22, 0)))
		var lid := Util.box(Vector3(0.55, 0.06, 0.45), Color("#56483a"), pos + Vector3(0.15, 0.5, 0.1))
		lid.rotation_degrees.z = 18
		_junk.add_child(lid)
		_junk.add_child(Util.sphere(0.28, Color("#2a2a2e"), pos + Vector3(0.55, 0.22, -0.2)))
		_junk.add_child(Util.sphere(0.2, Color("#33333a"), pos + Vector3(-0.45, 0.16, 0.25)))
	# Devrilmiş eski sandalye
	var chair := Util.box(Vector3(0.46, 0.06, 0.46), Color("#5b4636"), Vector3(1.9, 0.2, -4.0))
	chair.rotation_degrees = Vector3(70, 30, 0)
	_junk.add_child(chair)
	# Köşelerde örümcek ağları
	for pos in [Vector3(-5.85, 4.3, -9.95), Vector3(5.85, 4.3, -9.95), Vector3(-5.85, 4.3, 1.9), Vector3(5.85, 4.3, 1.9)]:
		var web := Util.box(Vector3(0.9, 0.9, 0.01), Color(0.85, 0.85, 0.85), pos)
		web.rotation_degrees = Vector3(0, 45 if pos.x < 0 else -45, 45)
		_junk.add_child(web)

	_cracks = Node3D.new()
	add_child(_cracks)
	for i in 9:
		var crack := Util.box(Vector3(randf_range(0.6, 1.6), 0.005, 0.03), Color("#3e3832"), Vector3(randf_range(-5, 5), 0.003, randf_range(-9, 0)))
		crack.rotation_degrees.y = randf_range(0, 180)
		_cracks.add_child(crack)

	_boards = Node3D.new()
	add_child(_boards)
	var plank := Color("#7a5a3a")
	for x in [-3.6, 3.6]:
		for y in [1.65, 2.35]:
			var board := Util.box(Vector3(2.2, 0.22, 0.04), plank, Vector3(x, y, -9.95))
			board.rotation_degrees.z = 8 if y > 2 else -6
			_boards.add_child(board)
	for side in [-1.0, 1.0]:
		for z in [-3.0, -6.4]:
			for y in [1.75, 2.45]:
				var board := Util.box(Vector3(0.04, 0.22, 2.2), plank, Vector3(side * 5.86, y, z))
				board.rotation_degrees.x = 7 if y > 2 else -5
				_boards.add_child(board)


## Dekoru uygular: boya, zemin, temizlik, pencere, lamba, bitki, tabela, kasa, masa.
func _apply_decor() -> void:
	var decor := GameState.decor
	var colors: Dictionary = Decor.WALL_COLORS[decor["paint_color"]] if decor["paint"] else Decor.RUIN_WALL
	_wall_mat.albedo_color = colors["wall"]
	_side_mat.albedo_color = colors["side"]
	_panel_mat.albedo_color = colors["panel"]
	var floor_data: Dictionary = Decor.FLOORS[decor["floor"]]
	_floor_mat.set_shader_parameter("color_a", floor_data["a"])
	_floor_mat.set_shader_parameter("color_b", floor_data["b"])
	_cracks.visible = decor["floor"] == 0

	_junk.visible = not decor["clean"]
	_boards.visible = not decor["windows"]
	for lamp in _lamps:
		lamp.light_energy = 0.9 if decor["lamps"] else 0.12
	for bulb in _bulbs:
		bulb.material_override = Util.material(Color("#ffd27a") if decor["lamps"] else Color("#4a4a4a"))
	for i in _plants.size():
		_plants[i].visible = i < decor["plants"]
	_sign.visible = decor["sign"]
	_sign_label.text = GameState.shop_name.to_upper()
	register.visible = decor["register"]
	_ceiling.visible = GameState.setup_done
	_sync_tables()


func _window(pos: Vector3, on_side_wall: bool) -> void:
	var frame := Vector3(0.04, 1.5, 2.0) if on_side_wall else Vector3(2.0, 1.5, 0.04)
	var glass := Vector3(0.05, 1.3, 1.8) if on_side_wall else Vector3(1.8, 1.3, 0.05)
	var bar := Vector3(0.06, 1.3, 0.04) if on_side_wall else Vector3(0.04, 1.3, 0.06)
	add_child(Util.box(frame, Color("#ffffff"), pos))
	add_child(Util.box(glass, Color("#bfe3f2"), pos))
	add_child(Util.box(bar, Color("#ffffff"), pos))


func _build_table(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	root.add_child(Util.cylinder(0.07, 0.78, Color("#5b4636"), Vector3(0, 0.39, 0)))
	root.add_child(Util.cylinder(0.32, 0.04, Color("#5b4636"), Vector3(0, 0.02, 0)))
	root.add_child(Util.cylinder(0.62, 0.06, Color("#8b5e3c"), Vector3(0, 0.78, 0)))
	# Masanın üstünde küçük bir vazo
	root.add_child(Util.cylinder(0.05, 0.14, Color("#e8553e"), Vector3(0, 0.88, -0.3)))
	root.add_child(Util.sphere(0.06, Color("#ffd166"), Vector3(0, 0.98, -0.3)))

	for side in [-1.0, 1.0]:
		_build_chair(root, Vector3(side * SEAT_OFFSET, 0, 0), side)

	# Kirliyken üstünde süngerli işaret çıkar; dokununca temizlenir.
	var mark := Icons.sprite(Icons.badge("spray-can", UiKit.BLUE), 1.95)
	mark.visible = false
	root.add_child(mark)
	var progress := Util.label3d("", 80, Color.WHITE, Vector3(0, 2.4, 0))
	progress.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	progress.outline_size = 18
	progress.outline_modulate = Color(0.16, 0.11, 0.09)
	progress.visible = false
	root.add_child(progress)
	var table := { "pos": pos, "customer": null, "dirty": false, "tray": null, "cleaner": null, "mark": mark, "progress": progress, "root": root }
	var collider := Util.collider_box(root, Vector3(1.3, 1.0, 1.3), Vector3(0, 0.5, 0))
	collider.set_meta("tap", _on_table_tapped.bind(table))
	tables.append(table)
	# Yeni masa yerine "pop" diye konur.
	root.scale = Vector3.ONE * 0.01
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_chair(root: Node3D, pos: Vector3, side: float) -> void:
	var wood := Color("#c0703f")
	root.add_child(Util.box(Vector3(0.46, 0.06, 0.46), Color("#e8553e"), pos + Vector3(0, 0.45, 0)))
	for lx in [-0.18, 0.18]:
		for lz in [-0.18, 0.18]:
			root.add_child(Util.box(Vector3(0.05, 0.43, 0.05), wood, pos + Vector3(lx, 0.215, lz)))
	# Sırtlık masanın ters tarafında
	root.add_child(Util.box(Vector3(0.06, 0.55, 0.46), wood, pos + Vector3(side * 0.21, 0.75, 0)))
