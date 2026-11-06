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
signal order_placed(order: Dictionary)
signal orders_changed
## Kasadaki müşterinin siparişi girilecek (Hud kasa ekranını açar).
signal order_requested(customer: ShopCustomer)
signal order_delivered(customer: ShopCustomer, tip: int)
## Paket servis telefonu: çalmaya başladı, açıldı ya da kapandı (Hud çağrı kartını gösterir).
signal call_changed
## Bir kuryenin durumu değişti (yola çıktı, döndü, paket aldı).
signal couriers_changed
## Kurye paketleri teslim etti: toplam ücret ve bahşiş.
signal deliveries_completed(courier: Courier, amount: int, tip: int)

## Paket siparişlerin adresleri (rastgele seçilir)
const STREETS := ["Çiçek Sk.", "Lale Sk.", "Gül Sk.", "Papatya Cd.", "Çınar Sk.", "Menekşe Sk.", "Okul Cd.", "Pazar Sk.", "Bahçe Sk.", "Kavak Cd.", "Fırın Sk.", "Yalı Cd."]
## Telefon bu kadar saniye çalar, açılmazsa sipariş kaçar.
const RING_TIME := 14.0
## Açılan çağrıda karar süresi (saniye)
const DECIDE_TIME := 15.0

## Kasaların önündeki sipariş yerleri: 0 oyuncunun kasası, 1 Ek Kasa (kasiyer)
const SPOTS := [Vector3(0.6, 0, 0.2), Vector3(1.55, 0, 0.2)]
## Ek Kasa'nın sırası: masalara çarpmasın diye kısa (en fazla 3 kişi)
const QUEUE2 := [Vector3(1.6, 0, -0.55), Vector3(1.6, 0, -1.3), Vector3(1.6, 0, -2.05)]
## Kapıdan Ek Kasa sırasına giderken masaların arasından değil koridordan geçilir.
const LANE2_APPROACH := Vector3(1.0, 0, -2.0)
const REGISTER2_POS := Vector3(1.55, 0.98, 1.15)
## Kasiyer tezgâhın arkasında, Ek Kasa'nın başında durur.
const CASHIER_POS := Vector3(1.6, 0, 1.75)
## Sıra kasanın arkasında, koridor boyunca tek sıra halinde uzar.
const QUEUE_START := Vector3(0.45, 0, -0.55)
const DOOR := Vector3(0, 0, -9.9)
## Müşteriler kaldırımda bu x'ten gelir / buraya kadar gidip kaybolur.
const STREET_END_X := 11.0
## Tabela: vitrinlerin üstünde ortalanır; ada göre 2.8–6.6 m genişler,
## yazı en fazla SIGN_TEXT_MAX genişliğe sığdırılır (gerekirse küçülür, iki satıra iner).
const SIGN_Y := 3.55
const SIGN_FONT := 120
const SIGN_MIN_FONT := 80
const SIGN_TEXT_MAX := 5.6
const DOOR_WIDTH := 1.5
const DOOR_HEIGHT := 2.5
## Pencereler: arka duvarda kapının iki yanında vitrin, yan duvarlarda bahçeye bakan.
## Boyutlar: (genişlik, yükseklik). Arka vitrinler yola baksın diye alçaktan,
## yan pencereler lambrinin üstünden başlar.
const WINDOW_BOTTOM := 1.0
const BACK_WINDOW_BOTTOM := 0.45
const BACK_WINDOW_X := [-3.4, 3.4]
const BACK_WINDOW_SIZE := Vector2(2.8, 2.45)
const SIDE_WINDOW_Z := [-3.0, -6.4]
const SIDE_WINDOW_SIZE := Vector2(2.4, 1.8)
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
## Genişletmeler: sol duvar yıkılıp Yan Salon, sağ duvar açılıp Bahçe Teras olur.
## Yan duvardaki geçidin z aralığı ve yüksekliği; dış kenarlar.
const OPENING_Z := [-8.6, -1.6]
const OPENING_TOP := 3.0
const ANNEX_X := -12.2
const GARDEN_X := 12.2
const ANNEX_TABLES := [Vector3(-8.9, 0, -3.0), Vector3(-8.9, 0, -5.3), Vector3(-8.9, 0, -7.6)]
const GARDEN_TABLES := [Vector3(8.9, 0, -3.0), Vector3(8.9, 0, -5.3), Vector3(8.9, 0, -7.6)]
## Masanın merkezinden sandalyeye uzaklık (x ekseninde).
const SEAT_OFFSET := 0.85
## Masaya yaklaşırken kullanılan, masaların önündeki boş şerit.
const LANE_OFFSET := 1.05
const MALE_NAMES := ["Mehmet", "Can", "Burak", "Emre", "Kerem", "Mert", "Efe", "Ahmet", "Yusuf", "Onur", "Barış", "Arda"]
const FEMALE_NAMES := ["Ayşe", "Zeynep", "Elif", "Selin", "Ece", "Defne", "Ada", "Merve", "Esra", "Duru", "İrem", "Buse"]
## Masa bulamayan müşteri bu masanın ucunda (önünde, dış tarafta) ayakta bekler.
const STAND_OFFSET := Vector3(0.5, 0, 0.78)
## Teslim alanı: sipariş veren sola kayar, kasanın solundaki boşlukta numarasıyla
## bekler (önce tezgâha yakın sıra dolar).
## Tezgâhın önü (kasanın solu) paket teslim noktasıdır; orada kurye bekler
## (Courier.SPOTS), müşteriler onun arkasındaki sıralarda.
const PICKUP_WAIT := [
	Vector3(-0.4, 0, -0.5), Vector3(-1.15, 0, -0.5), Vector3(-1.9, 0, -0.5),
	Vector3(-2.65, 0, -0.5), Vector3(-1.4, 0, -1.2), Vector3(-2.2, 0, -1.2),
]
## Paket teslim noktası: tezgâhta "PAKET TESLİM" tabelası, önünde kuryeler bekler.
const PACKAGE_SIGN := Vector3(-1.1, 0.98, 1.0)

## Kasanın önündeki yer (SPOTS ile aynı sırada; boşsa null)
var spots: Array = [null, null]
## Kasanın arkasındaki sıra (önden arkaya)
var queue: Array[ShopCustomer] = []
## Ek Kasa'nın (kasiyerin) sırası
var queue2: Array[ShopCustomer] = []
var register2: CashRegister
var _cashier: ModelBody
var _cashier_busy: ShopCustomer
var _cashier_timer := 0.0
var _cashier_deliver_timer := 0.0
## Her masa: { "pos", "customer", "dirty", "tray", "cleaner", "mark" }. Bir masada tek müşteri oturur.
var tables: Array[Dictionary] = []
## Masa ucunda ayakta bekleyenler (TABLES ile aynı sırada; boşsa null)
var standing: Array = []
## Açık siparişler (fişler): { number, customer, items, filled: {ürün: [kalite]}, ready }
var orders: Array[Dictionary] = []
## Teslim alanında bekleyenler (PICKUP_WAIT ile aynı sırada; boşsa null)
var pickup_wait: Array = [null, null, null, null, null, null]
## Kasada ödemesi alınan müşteri (aynı anda tek ödeme).
var paying: ShopCustomer
var register: CashRegister

var _spawn_timer := 2.0
var _next_number := 1
var _workers: Array[Worker] = []
var couriers: Array[Courier] = []
## Gelen paket çağrısı: { name, address, km, items, price, time, open }; çağrı yoksa boş.
var call := {}
var _call_timer := 12.0
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
var _sign_board: MeshInstance3D
var _sign_trim: MeshInstance3D
var _sign_lamps: Array[Node3D] = []
var _ceiling: MeshInstance3D
var _ceiling_open := false
## Tavan lambaları (kuşbakışında tavanla birlikte gizlenir)
var _ceiling_lamps: Array[Node3D] = []
## Dekor mağazası: kapı kanadı ve pencere / kapı çerçevesi rengi, halılar, süsler
var _door_mat := StandardMaterial3D.new()
var _frame_mat := StandardMaterial3D.new()
var _rugs: Array[Node3D] = []
var _ornaments := {}
var _table_style := -1
var _plants: Array[Node3D] = []
var _lamps: Array[OmniLight3D] = []
var _bulbs: Array[MeshInstance3D] = []
var _sconces: Array[Node3D] = []
var _chair_mat := StandardMaterial3D.new()
var _glass_mat: StandardMaterial3D
var _door: Node3D
var _door_open := false
var _street := Street.new()
## Kaldırım ve satılık dükkanlar (Mahalle modu)
var neighborhood: Neighborhood
## Yan duvarlar: side (-1 sol, 1 sağ) -> [kapalı, açık]
var _side_walls := {}
var _annex: Node3D
var _garden: Node3D
## Tavanla birlikte gizlenen ek tavanlar (Yan Salon)
var _extra_ceilings: Array[Node3D] = []
var _expansions_synced := false


func _ready() -> void:
	_build_room()
	_apply_decor()
	_sync_staff()
	GameState.upgrades_changed.connect(_sync_tables)
	GameState.upgrades_changed.connect(_sync_staff)
	GameState.register_mode_changed.connect(_on_register_mode)
	GameState.decor_changed.connect(_apply_decor)
	GameState.decor_changed.connect(neighborhood.refresh)
	GameState.branches_changed.connect(neighborhood.refresh)
	GameState.setup_finished.connect(_apply_decor)
	GameState.staff_changed.connect(_sync_staff)
	# Sipariş numaraları her gün 1'den başlar.
	GameState.day_started.connect(func(_day: int) -> void: _next_number = 1)


func _process(delta: float) -> void:
	_update_door(delta)
	# Salon kalabalıklaştıkça uğultu artar.
	# Salon kalabalığı döngüsü kapalı: bant gürültüsünden yapılan mırıltı telefonda
	# müşteriler yürürken sürekli sürtünme / cızırtı gibi duyuluyordu.
	Sfx.set_loop_level("crowd", 0.0)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = Progression.spawn_interval(GameState.level, GameState.rating()) * (1.0 - Decor.spawn_bonus(GameState.decor))
		if GameState.tutorial_active():
			# Tanıtımda tek müşteri gelir, o çıkınca sıradaki.
			_spawn_timer = 1.0
			if GameState.tutorial_step <= 8 and _customer_count() == 0 and GameState.accepting_customers():
				_spawn()
		elif GameState.accepting_customers() and _customer_count() < Progression.max_customers(GameState.level) and orders.size() < Progression.max_orders(GameState.level):
			# Açık kasalardan birinde yer ya da sırada boşluk varsa yeni müşteri gelir.
			if _pick_lane() != -1:
				_spawn()

	_update_standing()
	_update_calls(delta)
	_update_deliveries(delta)
	# Kapanış saati geldi, içeride kimse ve yolda paket kalmadıysa gün biter.
	if GameState.is_open and GameState.minutes >= GameState.CLOSE_TIME and _customer_count() == 0 and deliveries_done():
		GameState.end_day()

	# Kasada yer boşaldıysa o kasanın sırasındaki ilk kişi öne geçer.
	for lane in 2:
		var lane_queue := _lane_queue(lane)
		if spots[lane] == null and not lane_queue.is_empty():
			var next: ShopCustomer = lane_queue.pop_front()
			spots[lane] = next
			next.state = ShopCustomer.State.ARRIVING
			next.follow([QUEUE_START if lane == 0 else QUEUE2[0], SPOTS[lane]], 0.0)
			customer_added.emit(next)
			_update_queue()
	_update_cashier(delta)

	for customer in spots:
		if customer and customer.state == ShopCustomer.State.WAITING and customer.patience <= 0.0:
			_leave_angry(customer)
	for customer in queue + queue2:
		if customer.patience <= 0.0:
			_leave_angry(customer)
	for order in orders.duplicate():
		if order.get("delivery", false):
			continue
		var customer: ShopCustomer = order["customer"]
		if customer.state == ShopCustomer.State.ORDERED and customer.food_patience <= 0.0:
			_order_timeout(order)


## Kasada ya da sırada sipariş vermeyi bekleyen müşteri sayısı.
func waiting_count() -> int:
	var count := queue.size() + queue2.size()
	for customer in spots:
		if customer and customer.state == ShopCustomer.State.WAITING:
			count += 1
	return count


## Henüz hazırlanmamış (tepsisi dolmamış) sipariş sayısı.
func open_order_count() -> int:
	var count := 0
	for order in orders:
		if not order["ready"]:
			count += 1
	return count


## Müşteriye dokununca: kasadaysa siparişini al, teslim bekliyorsa ve hazırsa teslim et.
func _on_customer_tapped(customer: ShopCustomer) -> void:
	if customer.state == ShopCustomer.State.WAITING:
		if customer.lane == 1 and cashier_active():
			GameState.show_toast("%s ile kasiyer ilgileniyor" % customer.customer_name)
			return
		request_order(customer)
	elif customer.state == ShopCustomer.State.ORDERED:
		var order := order_of(customer)
		if not order.is_empty():
			deliver(order)


func order_of(customer: ShopCustomer) -> Dictionary:
	for order in orders:
		if order["customer"] == customer:
			return order
	return {}


## Kasa ekranını açtırır: önce sipariş alınabilir mi bakılır (ödeme sürüyor mu,
## teslim alanında yer var mı).
func request_order(customer: ShopCustomer) -> void:
	if can_take_order(customer):
		order_requested.emit(customer)


func can_take_order(customer: ShopCustomer) -> bool:
	if customer.state != ShopCustomer.State.WAITING:
		return false
	if paying:
		GameState.show_toast("Önce kasadaki ödemeyi tamamla")
		return false
	if pickup_wait.find(null) == -1:
		GameState.show_toast("Teslim alanı dolu! Önce hazır siparişleri teslim et")
		Sfx.play("error")
		return false
	return true


## Kasa ekranında doğru girilen siparişin ödemesini başlatır. Ürünlerin hazır
## olması gerekmez.
func take_order(customer: ShopCustomer) -> bool:
	if not can_take_order(customer):
		return false
	var price := 0
	for id in customer.order:
		price += Items.price(id) * int(customer.order[id])
	customer.sale_price = price
	customer.counter_wait_ratio = customer.patience / customer.max_patience
	customer.state = ShopCustomer.State.PAYING
	paying = customer
	payment_requested.emit(customer, price)
	return true


## Kasa ödemeyi bitirince: müşteri sipariş numarasını alır, teslim alanına geçer,
## mutfakta fişi açılır. loss: fazladan verilen paraüstü.
func complete_payment(customer: ShopCustomer, loss: int) -> void:
	if paying == customer:
		paying = null
	GameState.money += customer.sale_price - loss
	if loss > 0:
		GameState.show_toast("₺%d fazla paraüstü verdin!" % loss)
	sale_completed.emit(customer, customer.sale_price, 0)
	GameState.record_sale(customer.sale_price, 0)
	# Kasa "çın" dedikten sonra yazıcı siparişin fişini basar.
	get_tree().create_timer(0.35).timeout.connect(Sfx.play.bind("receipt"))

	var order := { "number": _next_number, "customer": customer, "items": customer.order.duplicate(), "filled": {}, "ready": false, "lane": customer.lane }
	_next_number += 1
	for id in order["items"]:
		order["filled"][id] = []
	orders.append(order)
	customer.order_number = order["number"]
	customer.max_food_patience = Progression.food_patience(GameState.level, customer.item_count()) * (1.0 + Decor.patience_bonus(GameState.decor))
	if GameState.tutorial_active():
		customer.max_food_patience = 9999.0
	customer.food_patience = customer.max_food_patience
	customer.state = ShopCustomer.State.ORDERED

	_release_spot(customer)
	var spot := pickup_wait.find(null)
	pickup_wait[spot] = customer
	customer.follow([PICKUP_WAIT[spot]], 0.0)
	order_placed.emit(order)
	orders_changed.emit()


## Mutfakta fişin tepsisine hazır ürünleri koyar; tamamlanınca fiş "hazır" olur.
func fill_order(order: Dictionary) -> void:
	if order["ready"]:
		return
	var placed := 0
	for id in order["items"]:
		var filled: Array = order["filled"][id]
		while filled.size() < int(order["items"][id]) and GameState.available(id) > 0:
			filled.append(GameState.take_for_order(id))
			placed += 1
	var complete := true
	for id in order["items"]:
		if (order["filled"][id] as Array).size() < int(order["items"][id]):
			complete = false
	order["ready"] = complete
	if complete:
		Sfx.play("approve")
		if order.get("delivery", false):
			GameState.show_toast("#%d paket hazır! Dükkanda kuryeye ver" % order["number"])
		else:
			GameState.show_toast("#%d hazır! Dükkanda teslim et" % order["number"])
	elif placed > 0:
		Sfx.play("pop")
	else:
		Sfx.play("error")
		GameState.show_toast("Önce eksik ürünleri pişir")
	orders_changed.emit()


## Hazır siparişi müşteriye teslim eder: tepsi kasanın yanına konur, müşteri alıp masasına gider.
func deliver(order: Dictionary) -> void:
	if order.get("delivery", false):
		give_to_courier(order)
		return
	var customer: ShopCustomer = order["customer"]
	if order["ready"] and customer.state == ShopCustomer.State.ORDERED:
		Sfx.play("clink", 0.05)
	if not order["ready"]:
		GameState.show_toast("#%d henüz hazır değil" % order["number"])
		Sfx.play("error")
		return
	if customer.state != ShopCustomer.State.ORDERED:
		return

	var served: Array[Array] = []
	var quality_sum := 0
	var spoiled := false
	var base_price := 0
	var under: Array[String] = []
	var over: Array[String] = []
	for id in order["filled"]:
		for quality in order["filled"][id]:
			served.append([id, quality])
			quality_sum += quality
			base_price += int(Items.PRODUCTS[id]["price"])
			if quality == 1:
				spoiled = true
			if quality == 2 and not under.has(Items.display_name(id)):
				under.append(Items.display_name(id))
			elif quality == 3 and not over.has(Items.display_name(id)):
				over.append(Items.display_name(id))
	# Puan: ürün kalitesi; kasada ya da teslimde çok beklediyse bir yıldız düşer.
	var wait_ratio := minf(customer.counter_wait_ratio, customer.food_patience / customer.max_food_patience)
	var stars := roundi(float(quality_sum) / served.size())
	if wait_ratio < 0.25:
		stars -= 1
	# Fiyat: müşterinin razı olduğundan pahalıysa puan düşer, ucuzsa memnun kalır.
	var price_ratio := float(customer.sale_price) / maxf(base_price, 1.0) / Progression.price_tolerance()
	if price_ratio > 1.7:
		stars -= 2
	elif price_ratio > 1.3:
		stars -= 1
	elif price_ratio < 0.8:
		stars += 1
	stars = clampi(stars, 1, 5)
	# Tarihi geçmiş malzemeyle yapılmış yemek: yer, 1 yıldız verir, kızıp gider.
	if spoiled:
		stars = 1
		customer.set_meta("spoiled", true)
	var tip := roundi(customer.sale_price * 0.2) if stars == 5 else 0
	customer.sale_tip = tip
	if tip > 0:
		GameState.money += tip
		GameState.record_tip(tip)
	GameState.add_xp(Progression.sale_xp(served.size(), stars))
	customer.served_items = served
	var review := _review_text(stars, wait_ratio, under, over)
	if spoiled:
		review = ["Yemek bozuktu, midem bulandı! Bir daha asla gelmem.", "Malzemenin tarihi geçmiş, tadından belli. Rezalet!"].pick_random()
	elif price_ratio > 1.3:
		review += " Ama fiyatlar çok tuzlu."
	elif price_ratio < 0.8:
		review += " Bu fiyata harika!"
	customer.pending_review = [stars, review]
	GameState.quest_event("serve")
	for item in served:
		GameState.quest_event("sell", 1, item[0])

	orders.erase(order)
	pickup_wait[pickup_wait.find(customer)] = null
	orders_changed.emit()
	order_delivered.emit(customer, tip)
	Sfx.play("kaching")

	# Tepsi kasanın yanına konur; müşteri gelip alır.
	customer.state = ShopCustomer.State.PAYING
	var tray := _make_bag() if customer.takeaway else _make_tray(served)
	add_child(tray)
	tray.position = TRAY_SPOT
	customer.follow([PICKUP_SPOT], 0.0)
	var walk := Vector2(customer.position.x - PICKUP_SPOT.x, customer.position.z - PICKUP_SPOT.z).length() / ShopCustomer.SPEED
	get_tree().create_timer(maxf(walk + 0.3, 0.35 + 0.18 * served.size())).timeout.connect(_pick_up.bind(customer, tray))


## Sipariş zamanında teslim edilmedi: para iade, hazırlanmış ürünler geri, kötü yorum.
func _order_timeout(order: Dictionary) -> void:
	var customer: ShopCustomer = order["customer"]
	for id in order["filled"]:
		for quality in order["filled"][id]:
			if GameState.prepared.has(id):
				GameState.add_prepared(id, quality)
			else:
				GameState.stock[id] += 1
				GameState.stock_changed.emit()
	GameState.money -= customer.sale_price
	GameState.record_refund(customer.sale_price)
	GameState.record_lost_customer()
	GameState.add_review(1, "Siparişim çok gecikti, paramı geri aldım.", customer.customer_name)
	GameState.show_toast("#%d çok gecikti! %s ₺%d iade aldı" % [order["number"], customer.customer_name, customer.sale_price])
	Sfx.play("error")
	customer.angry = true
	orders.erase(order)
	pickup_wait[pickup_wait.find(customer)] = null
	orders_changed.emit()
	customer.leave(_exit_path(customer.position, signf(customer.position.x)))


## Müşteri tepsiyi alır; temiz ve boş masa varsa oturmaya, yoksa ayakta beklemeye gider.
func _pick_up(customer: ShopCustomer, tray: Node3D) -> void:
	if not is_instance_valid(customer):
		tray.queue_free()
		return
	customer.take(tray)
	_release_spot(customer)
	if customer.takeaway:
		# Paket servis: masaya oturmaz, yorumunu bırakıp poşetiyle çıkar.
		_post_review(customer)
		customer.leave(_exit_path(customer.position, [-1.0, 1.0].pick_random()))
		return
	if _reserve_table(customer):
		_send_to_seat(customer, customer.position)
		return
	# Açık masaların ucundaki boş bekleme yerlerinden birine gider.
	var spot := -1
	for i in tables.size():
		if i < standing.size() and standing[i] == null:
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
	var pos: Vector3 = tables[i]["pos"] if i < tables.size() else TABLES[mini(i, TABLES.size() - 1)]
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
	customer.male = randf() < 0.5
	customer.customer_name = (MALE_NAMES if customer.male else FEMALE_NAMES).pick_random()
	customer.order = Progression.random_order(GameState.level)
	customer.takeaway = randf() < Progression.takeaway_chance(GameState.level)
	customer.max_patience = Progression.patience(GameState.level, customer.item_count(), GameState.upgrade_level("comfort"))
	customer.max_patience *= 1.0 + Decor.patience_bonus(GameState.decor)
	if GameState.tutorial_active():
		# Tanıtım müşterisi menüdeki tek bir ürünü ister ve sabrı tükenmez.
		customer.order = { GameState.tutorial_food(): 1 }
		customer.max_patience = 9999.0
	customer.tap = _on_customer_tapped.bind(customer)
	customer.sat_down.connect(_on_sat_down)
	customer.finished_eating.connect(_on_finished_eating)
	add_child(customer)
	# Kaldırımın bir ucundan yürüyüp kapıdan girer (pencereden gelişi görünür).
	var from := [-1.0, 1.0].pick_random() as float
	customer.position = Vector3(from * STREET_END_X, 0, Street.SIDEWALK_Z)
	customer.entry = [Vector3(from * 1.0, 0, Street.SIDEWALK_Z), Vector3(0, 0, -10.8), DOOR]

	var lane := maxi(_pick_lane(), 0)
	customer.lane = lane
	if spots[lane] == null and _lane_queue(lane).is_empty():
		spots[lane] = customer
		customer.follow([QUEUE_START, SPOTS[0]] if lane == 0 else [LANE2_APPROACH, QUEUE2[0], SPOTS[1]], 0.0)
		customer_added.emit(customer)
	else:
		customer.state = ShopCustomer.State.QUEUED
		_lane_queue(lane).append(customer)
		_update_queue()


## Sıradakileri arka arkaya dizer: oyuncunun sırası koridorda, kasiyerin sırası
## Ek Kasa'nın önünde (henüz koridordaysa önce koridordan gelir).
func _update_queue() -> void:
	for i in queue.size():
		queue[i].follow([QUEUE_START + Vector3(0, 0, -QUEUE_SPACING * i)], 0.0)
	for i in queue2.size():
		var target: Vector3 = QUEUE2[mini(i, QUEUE2.size() - 1)]
		var far := queue2[i].position.z < LANE2_APPROACH.z + 0.3
		queue2[i].follow([LANE2_APPROACH, target] if far else [target], 0.0)


## Oyuncu kasasını kapatınca sırasında bekleyenler kasiyerin sırasına geçer
## (yer kaldıkça); kasanın önündeki müşteriyi yine oyuncu alabilir.
func _on_register_mode() -> void:
	if not GameState.player_register_closed or not cashier_active():
		return
	while not queue.is_empty() and queue2.size() + (0 if spots[1] == null else 1) < QUEUE2.size() + 1:
		var customer: ShopCustomer = queue.pop_front()
		customer.lane = 1
		queue2.append(customer)
	_update_queue()


func _lane_queue(lane: int) -> Array[ShopCustomer]:
	return queue if lane == 0 else queue2


## Kasiyer çalışıyor mu (Ek Kasa alınmış ve kasiyer tutulmuş)
func cashier_active() -> bool:
	return register2 != null and Staff.count(GameState.staff, "kasiyer") > 0


## Yeni müşterinin gideceği kasa: açık kasalardan en az kalabalık olanı; ikisi de
## doluysa -1. Oyuncu kasasını kapattıysa sadece kasiyerin kasası açıktır.
func _pick_lane() -> int:
	var lanes: Array[int] = []
	if not (GameState.player_register_closed and cashier_active()):
		lanes.append(0)
	if cashier_active():
		lanes.append(1)
	var best := -1
	var best_load := 999
	for lane in lanes:
		var lane_queue := _lane_queue(lane)
		var limit := Progression.max_queue(GameState.level) if lane == 0 else QUEUE2.size()
		var has_room := (spots[lane] == null and lane_queue.is_empty()) or lane_queue.size() < limit
		var load := lane_queue.size() + (0 if spots[lane] == null else 1)
		if has_room and load < best_load:
			best = lane
			best_load = load
	return best


## Kasiyer: Ek Kasa'daki müşterinin siparişini alır, ödemesini alır (kendi hızında)
## ve kendi aldığı hazır siparişleri teslim eder. Oyuncu kasasını kapattıysa bütün
## hazır siparişleri o teslim eder.
func _update_cashier(delta: float) -> void:
	if not cashier_active():
		_cashier_busy = null
		return
	var person: Dictionary = GameState.staff.filter(func(p: Dictionary) -> bool: return Staff.role(p) == "kasiyer")[0]
	var customer: ShopCustomer = spots[1]
	if _cashier_busy == null and customer and customer.state == ShopCustomer.State.WAITING and pickup_wait.has(null):
		_cashier_busy = customer
		_cashier_timer = Staff.work_time(person) * (1.0 + 0.25 * customer.item_count())
		var price := 0
		for id in customer.order:
			price += Items.price(id) * int(customer.order[id])
		register2.show_amount(price)
		register2.card_wait()
		if _cashier:
			_cashier.play_action("wipe")
	if _cashier_busy:
		if not is_instance_valid(_cashier_busy) or _cashier_busy.state != ShopCustomer.State.WAITING:
			_cashier_busy = null
		else:
			_cashier_timer -= delta
			if _cashier_timer <= 0.0:
				var done := _cashier_busy
				_cashier_busy = null
				_cashier_checkout(done)
	_cashier_deliver_timer -= delta
	if _cashier_deliver_timer <= 0.0:
		_cashier_deliver_timer = Staff.work_time(person) * 0.6
		for order in orders:
			if order["ready"] and not order.get("delivery", false) \
					and (order.get("lane", 0) == 1 or GameState.player_register_closed) \
					and (order["customer"] as ShopCustomer).state == ShopCustomer.State.ORDERED:
				deliver(order)
				break


func _cashier_checkout(customer: ShopCustomer) -> void:
	var price := 0
	for id in customer.order:
		price += Items.price(id) * int(customer.order[id])
	customer.sale_price = price
	customer.counter_wait_ratio = customer.patience / customer.max_patience
	customer.state = ShopCustomer.State.PAYING
	register2.card_ok()
	register2.show_thanks()
	Sfx.play("beep", 0.05, Main.SHOP)
	if _cashier:
		_cashier.relax(0.0, false, false)
	complete_payment(customer, 0)


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
## Paket servis poşeti (dükkanın adı üstünde).
func _make_bag() -> Node3D:
	var bag := Node3D.new()
	bag.add_child(Util.box(Vector3(0.26, 0.3, 0.17), Color("#c8a06a"), Vector3(0, 0.15, 0)))
	bag.add_child(Util.box(Vector3(0.27, 0.05, 0.18), Color("#a8814f"), Vector3(0, 0.3, 0)))
	var tag := Util.label3d(Util.upper_tr(GameState.shop_name), 30, Color("#e8553e"), Vector3(0, 0.17, 0.087))
	tag.pixel_size = 0.0018
	Util.fit_label(tag, 0.22, 16)
	bag.add_child(tag)
	bag.scale = Vector3.ONE * 0.01
	bag.create_tween().tween_property(bag, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return bag


func _make_tray(served_items: Array[Array]) -> Node3D:
	var tray := Node3D.new()
	tray.add_child(Util.model("equipment/tepsi", Vector3.ZERO, 90.0, 1.28))
	tray.add_child(Util.box(Vector3(0.46, 0.004, 0.28), Color("#f6ecd9"), Vector3(0, 0.03, 0)))

	var items := Node3D.new()
	items.name = "Items"
	items.position.y = 0.032
	tray.add_child(items)
	# Yemekler önde tabaklarda, içecekler arkada (tabaksız, yemeği örtmesin).
	var foods: Array[Array] = served_items.filter(func(e: Array) -> bool: return Items.PRODUCTS[e[0]]["device"] != "")
	var drinks: Array[Array] = served_items.filter(func(e: Array) -> bool: return Items.PRODUCTS[e[0]]["device"] == "")
	var ordered: Array[Array] = foods + drinks
	var count := ordered.size()
	for i in count:
		var id: String = ordered[i][0]
		var drink: bool = i >= foods.size()
		var slot := Node3D.new()
		if drink:
			var k := i - foods.size()
			slot.position = Vector3(0.17 - k * 0.11, 0, -0.08)
		else:
			slot.position = Vector3((i - (foods.size() - 1) * 0.5) * 0.15, 0, 0.04 if not drinks.is_empty() else 0.0)
			slot.add_child(Util.cylinder(0.07, 0.012, Color("#ffffff"), Vector3(0, 0.006, 0)))
		var item := Items.model(id, Util.material(Items.quality_color(id, ordered[i][1])))
		item.position.y = 0.0 if drink else 0.012
		item.rotation_degrees.y = 90.0
		item.scale = Vector3.ONE * (0.75 if drink else 0.6)
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
	if customer.has_meta("spoiled"):
		customer.angry = true
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
## Kapıdan çıkınca kaldırımda o tarafa doğru yürüyüp gözden kaybolur.
func exit_path(from: Vector3, side: float) -> Array:
	return _exit_path(from, side)


func _exit_path(from: Vector3, side: float) -> Array:
	var lane_x := side * SIDE_LANE_X
	var away := side if side != 0.0 else 1.0
	return [
		Vector3(lane_x, 0, minf(from.z, AISLE_FRONT.z)), Vector3(lane_x, 0, DOOR.z + 0.7), DOOR,
		Vector3(0, 0, -10.8), Vector3(away * 1.0, 0, Street.SIDEWALK_Z), Vector3(away * STREET_END_X, 0, Street.SIDEWALK_Z),
	]


func _post_review(customer: ShopCustomer) -> void:
	if customer.pending_review.is_empty():
		return
	GameState.add_review(customer.pending_review[0], customer.pending_review[1], customer.customer_name)
	customer.pending_review = []


func _leave_angry(customer: ShopCustomer) -> void:
	var in_queue := queue.has(customer) or queue2.has(customer)
	var text := "Sıra çok uzundu, beklemekten vazgeçtim." if in_queue else "Çok bekledim, siparişim hiç alınmadı!"
	GameState.add_review(1, text, customer.customer_name)
	GameState.show_toast("%s beklemekten sıkılıp gitti!" % customer.customer_name)
	GameState.record_lost_customer()
	Sfx.play("error")
	customer.angry = true
	if in_queue:
		queue.erase(customer)
		queue2.erase(customer)
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
	_sync_expansions()
	var want := table_positions()
	for table in tables.duplicate():
		if not want.has(table["pos"]):
			tables.erase(table)
			(table["root"] as Node3D).queue_free()
	for pos in want:
		if not tables.any(func(t: Dictionary) -> bool: return t["pos"] == pos):
			_build_table(pos)
	if standing.size() < tables.size():
		var old := standing.size()
		standing.resize(tables.size())
		for i in range(old, standing.size()):
			standing[i] = null


## Açık masaların yerleri: salon (kurulum + Yeni Masalar), Yan Salon ve Bahçe.
static func table_positions() -> Array:
	var list: Array = []
	var count := mini(GameState.decor["tables"] + 2 * GameState.upgrade_level("tables"), TABLES.size())
	for i in count:
		list.append(TABLES[i])
	if GameState.upgrade_level("annex") > 0:
		list.append_array(ANNEX_TABLES)
	if GameState.upgrade_level("garden") > 0:
		list.append_array(GARDEN_TABLES)
	return list


## Genişletmeye göre yan duvarı açar, ek salonu / bahçeyi gösterir.
func _sync_expansions() -> void:
	var annex := GameState.upgrade_level("annex") > 0
	var garden := GameState.upgrade_level("garden") > 0
	for side in _side_walls:
		var open := annex if side < 0 else garden
		(_side_walls[side][0] as Node3D).visible = not open
		(_side_walls[side][1] as Node3D).visible = open
	if _expansions_synced:
		if not _annex.visible and annex:
			_pop_in(_annex)
		if not _garden.visible and garden:
			_pop_in(_garden)
	_expansions_synced = true
	_annex.visible = annex
	_garden.visible = garden
	_street.set_side_open(-1, annex)
	_street.set_side_open(1, garden)


## Mahalle modunda kameranın önünden araba geçmesin.
func set_walk_mode(active: bool) -> void:
	_street.near_lane_clear = active
	neighborhood.set_active(active)
	if active:
		neighborhood.refresh()


## Yeni açılan bölüm aşağıdan yükselerek belirir.
func _pop_in(node: Node3D) -> void:
	node.position.y = -4.6
	node.create_tween().tween_property(node, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("level_up", 0.0, Main.SHOP)


## Yan Salon: solda yan dükkan; aynı zemin ve duvar boyası, arka duvarda
## sokağa bakan vitrin, dış duvarda iki pencere, tavanda lamba.
func _build_annex() -> void:
	_annex = Node3D.new()
	_annex.visible = false
	add_child(_annex)
	var x0 := ANNEX_X
	var x1 := -6.0
	var cx := (x0 + x1) / 2.0
	var w := x1 - x0
	_annex.add_child(Util.box(Vector3(w, 0.1, 12.3), _floor_mat, Vector3(cx, -0.04, -3.95)))
	var ceiling := Util.no_shadow(Util.box(Vector3(w, 0.1, 12.3), Color("#fbf3e6"), Vector3(cx, 4.5, -3.95)))
	_annex.add_child(ceiling)
	_extra_ceilings.append(ceiling)
	# Arka duvar (sokak tarafı): ortada vitrin
	var shop_window := [cx - 1.3, cx + 1.3, BACK_WINDOW_BOTTOM, BACK_WINDOW_BOTTOM + BACK_WINDOW_SIZE.y]
	_wall(true, -10.1, x0, x1, 4.5, 0.2, _wall_mat, [shop_window], _annex)
	_wall(true, -10.08, x0, x1, 1.0, 0.22, _panel_mat, [shop_window], _annex)
	_window(Vector3(cx, BACK_WINDOW_BOTTOM, -10.1), Vector2(2.6, BACK_WINDOW_SIZE.y), 0.0, _annex)
	# Dış duvar: iki pencere
	var holes := []
	for z: float in SIDE_WINDOW_Z:
		holes.append([z - SIDE_WINDOW_SIZE.x / 2, z + SIDE_WINDOW_SIZE.x / 2, WINDOW_BOTTOM, WINDOW_BOTTOM + SIDE_WINDOW_SIZE.y])
	_wall(false, x0, -10.2, 2.2, 4.5, 0.2, _side_mat, holes, _annex)
	_annex.add_child(Util.no_shadow(Util.box(Vector3(0.22, 1.0, 12.4), _panel_mat, Vector3(x0 + 0.01, 0.5, -4.0))))
	for z: float in SIDE_WINDOW_Z:
		_window(Vector3(x0, WINDOW_BOTTOM, z), SIDE_WINDOW_SIZE, 90.0, _annex)
	# Dış duvarın üstü (arka duvarla birleşen köşe)
	for z in [-5.3]:
		var hanging := Util.model("lighting/tavan_lambasi", Vector3(cx, 3.62, z), 0.0, 1.2)
		_annex.add_child(hanging)
		_ceiling_lamps.append(hanging)
		var bulb := Util.sphere(0.08, Color("#ffd27a"), Vector3(cx, 3.66, z))
		_annex.add_child(bulb)
		_bulbs.append(bulb)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(cx, 3.4, -5.0)
	lamp.light_color = Color("#ffd9a0")
	lamp.omni_range = 7.5
	_annex.add_child(lamp)
	_lamps.append(lamp)
	# Köşelerde bitki
	for pos in [Vector3(x0 + 0.6, 0, -9.4), Vector3(x0 + 0.6, 0, 1.4)]:
		_annex.add_child(Util.cylinder(0.25, 0.5, Color("#c0703f"), pos + Vector3(0, 0.25, 0)))
		_annex.add_child(Util.sphere(0.42, Color("#4f9a52"), pos + Vector3(0, 0.85, 0)))


## Bahçe Teras: sağda ahşap zemin, alçak çit ve çiçek saksıları, üstte pergola
## ve ampul zinciri. Masalarda şemsiye var (_build_table).
func _build_garden() -> void:
	_garden = Node3D.new()
	_garden.visible = false
	add_child(_garden)
	var x0 := 6.0
	var x1 := GARDEN_X
	var cx := (x0 + x1) / 2.0
	var w := x1 - x0
	var deck := Util.tile_material(Color("#b98552"), Color("#a9784a"), 0.9)
	_garden.add_child(Util.box(Vector3(w, 0.12, 11.6), deck, Vector3(cx, -0.02, -4.2)))
	var wood := Color("#7a4b32")
	# Alçak çit: dış kenarda ve önde/arkada
	for z in range(-10, 2):
		_garden.add_child(Util.box(Vector3(0.08, 0.8, 0.08), Color("#f4efe6"), Vector3(x1 - 0.1, 0.4, z + 0.4)))
	for y in [0.3, 0.65]:
		_garden.add_child(Util.box(Vector3(0.05, 0.08, 11.6), Color("#f4efe6"), Vector3(x1 - 0.1, y, -4.2)))
		for z in [-9.95, 1.55]:
			_garden.add_child(Util.box(Vector3(w, 0.08, 0.05), Color("#f4efe6"), Vector3(cx, y, z)))
	# Pergola: köşelerde dikmeler, üstte kirişler
	for px in [x0 + 0.3, x1 - 0.3]:
		for pz in [-9.7, -4.2, 1.3]:
			_garden.add_child(Util.box(Vector3(0.16, 3.2, 0.16), wood, Vector3(px, 1.6, pz)))
		_garden.add_child(Util.box(Vector3(0.14, 0.18, 11.4), wood, Vector3(px, 3.25, -4.2)))
	for i in 9:
		_garden.add_child(Util.no_shadow(Util.box(Vector3(w - 0.4, 0.1, 0.1), wood.lightened(0.1), Vector3(cx, 3.38, -9.6 + i * 1.36))))
	# Ampul zinciri: pergolanın altında, iki sıra
	var colors := [Color("#ffd166"), Color("#fff1c4"), Color("#ff9f43")]
	for row in [x0 + 1.4, x1 - 1.4]:
		for i in 23:
			var z := -9.6 + i * 0.5
			var y := 3.05 - 0.15 * absf(sin(z / 1.8 * PI))
			var mat := StandardMaterial3D.new()
			mat.albedo_color = colors[i % colors.size()]
			mat.emission_enabled = true
			mat.emission = colors[i % colors.size()]
			mat.emission_energy_multiplier = 1.4
			_garden.add_child(Util.no_shadow(Util.sphere(0.05, mat, Vector3(row, y, z))))
	var glow := OmniLight3D.new()
	glow.position = Vector3(cx, 2.8, -4.5)
	glow.light_color = Color("#ffe1a8")
	glow.omni_range = 7.0
	glow.light_energy = 0.6
	_garden.add_child(glow)
	# Çiçek saksıları çitin önünde
	var petals := [Color("#ff7aa2"), Color("#ffd166"), Color("#c77dff"), Color("#ff9f43")]
	for z in [-8.6, -6.4, -4.2, -1.9, 0.4]:
		_garden.add_child(Util.box(Vector3(0.45, 0.4, 0.9), Color("#c0703f"), Vector3(x1 - 0.45, 0.2, z)))
		for k in 3:
			_garden.add_child(Util.no_shadow(Util.sphere(0.16, Color("#4f9a52"), Vector3(x1 - 0.45, 0.48, z - 0.3 + k * 0.3))))
			_garden.add_child(Util.no_shadow(Util.sphere(0.08, petals[(k + int(z)) % petals.size()], Vector3(x1 - 0.42, 0.6, z - 0.28 + k * 0.3))))


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
	GameState.quest_event("clean")


func _clean_table(table: Dictionary) -> void:
	table["dirty"] = false
	table["cleaner"] = null
	(table["mark"] as Node3D).visible = false
	(table["progress"] as Label3D).visible = false
	Util.float_text(self, (table["pos"] as Vector3) + Vector3(0, 1.2, 0), "Temiz!", UiKit.GREEN)
	Sfx.play("spray", 0.05, Main.SHOP)


# --- Personel ------------------------------------------------------------------

## İşe alınan personeli dükkana getirir, çıkarılanları gönderir.
func _sync_staff() -> void:
	for worker in _workers.duplicate():
		if not GameState.staff.any(func(p: Dictionary) -> bool: return is_same(p, worker.data)):
			_workers.erase(worker)
			worker.fire()
	for courier in couriers.duplicate():
		if not GameState.staff.any(func(p: Dictionary) -> bool: return is_same(p, courier.data)):
			_fire_courier(courier)
	if _package_point:
		_package_point.visible = GameState.staff.any(func(p: Dictionary) -> bool: return Staff.role(p) == "kurye")
	_sync_register2()
	for person in GameState.staff:
		if Staff.role(person) in ["asci", "kasiyer"]:
			continue
		if Staff.role(person) == "kurye":
			if not couriers.any(func(c: Courier) -> bool: return is_same(c.data, person)):
				var courier := Courier.new()
				courier.data = person
				courier.shop = self
				var taken := couriers.map(func(c: Courier) -> int: return c.spot_index)
				courier.spot_index = 0 if not taken.has(0) else 1
				add_child(courier)
				couriers.append(courier)
			continue
		if not _workers.any(func(w: Worker) -> bool: return is_same(w.data, person)):
			var worker := Worker.new()
			worker.data = person
			worker.shop = self
			add_child(worker)
			worker.position = DOOR
			_workers.append(worker)


## Ek Kasa alınınca tezgâha ikinci kasa konur; kasiyer tutulunca başına geçer.
func _sync_register2() -> void:
	if register2 == null and GameState.upgrade_level("register2") > 0:
		register2 = CashRegister.new()
		register2.secondary = true
		register2.position = REGISTER2_POS
		register2.rotation_degrees.y = 6
		add_child(register2)
		register2.scale = Vector3.ONE * 0.01
		register2.create_tween().tween_property(register2, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var people := GameState.staff.filter(func(p: Dictionary) -> bool: return Staff.role(p) == "kasiyer")
	if _cashier and (people.is_empty() or not is_same(_cashier.get_meta("data"), people[0])):
		_cashier.queue_free()
		_cashier = null
	if _cashier == null and not people.is_empty() and register2:
		var person: Dictionary = people[0]
		if not person.has("look"):
			person["look"] = CharacterSkin.look_to_save(CharacterSkin.random_look())
		_cashier = ModelBody.new()
		_cashier.set_meta("data", person)
		add_child(_cashier)
		_cashier.build_model(person.get("model", Staff.WORKER_MODELS["erkek"]), CharacterSkin.look_from_save(person["look"]))
		var colors := uniform_colors()
		_cashier.set_uniform(colors[0], colors[1])
		_cashier.position = CASHIER_POS
		_cashier.rotation.y = PI
		var tag := Util.label3d("%s • Kasiyer" % person["name"], 40, Color.WHITE, Vector3(0, 2.05, 0))
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.outline_size = 10
		tag.outline_modulate = Color(0.16, 0.11, 0.09)
		_cashier.add_child(tag)


# --- Paket servis ------------------------------------------------------------------

## Tezgâhta paket teslim tabelası ve hazır poşetlerin konduğu altlık (kurye varken görünür).
var _package_point: Node3D


func _build_package_point() -> void:
	_package_point = Node3D.new()
	_package_point.position = PACKAGE_SIGN
	add_child(_package_point)
	_package_point.add_child(Util.box(Vector3(0.5, 0.012, 0.36), Color("#7c5cff"), Vector3(0, 0.006, -0.08)))
	var board := Node3D.new()
	board.position = Vector3(0, 0, 0.12)
	board.rotation_degrees.x = -12
	_package_point.add_child(board)
	board.add_child(Util.box(Vector3(0.025, 0.2, 0.025), Color("#3b2a25"), Vector3(0, 0.1, 0)))
	board.add_child(Util.box(Vector3(0.66, 0.2, 0.025), Color("#7c5cff"), Vector3(0, 0.29, 0)))
	board.add_child(Util.box(Vector3(0.6, 0.15, 0.004), Color("#9a80ff"), Vector3(0, 0.29, 0.014)))
	var text := Util.label3d("PAKET TESLİM", 96, Color.WHITE, Vector3(0, 0.29, 0.018))
	text.font = UiKit.font(900)
	text.pixel_size = 0.0011
	text.outline_size = 0
	Util.fit_label(text, 0.54, 60)
	board.add_child(text)
	_package_point.visible = false

## Siparişin bekleme sabrının kalan oranı (müşteri ya da paket siparişi).
static func patience_ratio(order: Dictionary) -> float:
	if order.get("delivery", false):
		return clampf(order["patience"] / order["max_patience"], 0.0, 1.0)
	var customer: ShopCustomer = order["customer"]
	return clampf(customer.food_patience / customer.max_food_patience, 0.0, 1.0)


## Kuryelerin yükü: henüz teslim edilmemiş paketlerin taşıma kapasitesine oranı.
## Yoldaki kurye dönene kadar paket alamadığından onun kapasitesinin yarısı dolu sayılır.
func delivery_load() -> float:
	var capacity := couriers.size() * Staff.COURIER_CAPACITY
	if capacity == 0:
		return 1.0
	var pending := 0
	for order in orders:
		if order.get("delivery", false):
			pending += 1
	for courier in couriers:
		pending += courier.packages.size()
		if courier.state == Courier.State.AWAY or courier.state == Courier.State.LEAVING:
			pending += Staff.COURIER_CAPACITY / 2
	return float(pending) / capacity


## Telefon: kurye varsa ve kuryeler çok yüklü değilse arada bir çalar.
func _update_calls(delta: float) -> void:
	if not call.is_empty():
		call["time"] -= delta
		if call["time"] <= 0.0:
			if call["open"]:
				reject_call(true)
			else:
				_miss_call()
		return
	if couriers.is_empty() or not GameState.accepting_customers() or GameState.tutorial_active():
		return
	_call_timer -= delta
	if _call_timer > 0.0:
		return
	var load := delivery_load()
	_call_timer = Progression.delivery_interval(GameState.level, couriers.size(), load) * randf_range(0.7, 1.3)
	if load >= 1.0:
		return
	var items := Progression.delivery_order(GameState.level)
	var price := 0
	for id in items:
		price += Items.price(id) * int(items[id])
	var male := randf() < 0.5
	call = {
		"name": (MALE_NAMES if male else FEMALE_NAMES).pick_random(),
		"address": "%s No:%d" % [STREETS.pick_random(), randi_range(1, 60)],
		"km": snappedf(randf_range(0.6, 3.5), 0.1),
		"items": items, "price": price, "time": RING_TIME, "open": false,
	}
	register.set_ringing(true)
	call_changed.emit()


## Telefonu açar: sipariş kartı açılır, karar için süre başlar.
func answer_call() -> void:
	if call.is_empty() or call["open"]:
		return
	call["open"] = true
	call["time"] = DECIDE_TIME
	register.set_ringing(false)
	Sfx.play("tap")
	call_changed.emit()


## Siparişi onaylar: mutfakta paket fişi açılır.
func accept_call() -> void:
	if call.is_empty():
		return
	var items: Dictionary = call["items"]
	var count := 0
	for id in items:
		count += int(items[id])
	var patience := Progression.delivery_patience(GameState.level, count) * (1.0 + Decor.patience_bonus(GameState.decor))
	var order := {
		"number": _next_number, "customer": null, "delivery": true, "name": call["name"], "address": call["address"],
		"km": call["km"], "items": items.duplicate(), "filled": {}, "ready": false, "price": call["price"],
		"patience": patience, "max_patience": patience,
	}
	_next_number += 1
	for id in items:
		order["filled"][id] = []
	orders.append(order)
	call = {}
	call_changed.emit()
	Sfx.play("approve")
	get_tree().create_timer(0.3).timeout.connect(Sfx.play.bind("receipt"))
	GameState.show_toast("#%d paket sipariş mutfağa düştü (%s)" % [order["number"], order["name"]])
	order_placed.emit(order)
	orders_changed.emit()


## Siparişi reddeder (ya da karar süresi dolar). Müşteri başka yerden söyler.
func reject_call(timed_out := false) -> void:
	if call.is_empty():
		return
	GameState.show_toast("%s siparişi %s" % [call["name"], "zaman aşımıyla düştü" if timed_out else "reddedildi"])
	Sfx.play("error" if timed_out else "tap")
	call = {}
	register.set_ringing(false)
	call_changed.emit()


func _miss_call() -> void:
	GameState.show_toast("Telefon cevapsız kaldı, paket sipariş kaçtı")
	call = {}
	register.set_ringing(false)
	call_changed.emit()


## Paket siparişlerin sabrı: mutfakta ve kuryenin kucağında beklerken azalır;
## biterse sipariş iptal olur.
func _update_deliveries(delta: float) -> void:
	for order in orders.duplicate():
		if order.get("delivery", false):
			order["patience"] -= delta
			if order["patience"] <= 0.0:
				_cancel_delivery(order, null)
	for courier in couriers:
		if courier.state != Courier.State.WAITING:
			continue
		for order in courier.packages.duplicate():
			order["patience"] -= delta
			if order["patience"] <= 0.0:
				_cancel_delivery(order, courier)


func _cancel_delivery(order: Dictionary, courier: Courier) -> void:
	for id in order["filled"]:
		for quality in order["filled"][id]:
			if GameState.prepared.has(id):
				GameState.add_prepared(id, quality)
			else:
				GameState.stock[id] += 1
				GameState.stock_changed.emit()
	if courier:
		courier.drop_package(order)
	else:
		orders.erase(order)
		orders_changed.emit()
	GameState.record_lost_customer()
	GameState.add_review(1, "Paketim saatlerce gelmedi, iptal ettim.", order["name"])
	GameState.show_toast("#%d paket çok gecikti, %s iptal etti!" % [order["number"], order["name"]])
	Sfx.play("error")


## Hazır paketi dükkanda bekleyen, kucağında yer olan kuryeye verir.
func give_to_courier(order: Dictionary) -> void:
	if not order["ready"]:
		GameState.show_toast("#%d henüz hazır değil" % order["number"])
		Sfx.play("error")
		return
	var courier: Courier = null
	for c in couriers:
		if c.can_load():
			courier = c
			break
	if courier == null:
		var all_away := couriers.all(func(c: Courier) -> bool: return c.state != Courier.State.WAITING)
		GameState.show_toast("Kuryeler yolda, dönünce ver" if all_away else "Kuryenin kucağı dolu! Ona dokunup yola çıkar")
		Sfx.play("error")
		return
	orders.erase(order)
	orders_changed.emit()
	var bag := _make_bag()
	add_child(bag)
	bag.position = TRAY_SPOT
	courier.load_package(order, bag)
	Sfx.play("pop")
	if courier.is_full():
		GameState.show_toast("%s doldu (%d paket). Dokun, yola çıksın" % [courier.data["name"], Staff.COURIER_CAPACITY])


## Hazır paketleri verebileceğin kurye var mı?
func courier_waiting() -> bool:
	return couriers.any(func(c: Courier) -> bool: return c.can_load())


## Kuryeye dokununca: kucağında paket varsa yola çıkar.
func dispatch(courier: Courier) -> void:
	if courier.state != Courier.State.WAITING:
		return
	if courier.packages.is_empty():
		GameState.show_toast("%s paket bekliyor. Hazır paketi \"Kuryeye Ver\" ile ver" % courier.data["name"])
		Sfx.play("error")
		return
	Sfx.play("approve")
	GameState.show_toast("%s %d paketle yola çıktı" % [courier.data["name"], courier.packages.size()])
	courier.depart()


## Kurye paketleri teslim etti: her müşteri öder, puan verir, beğenirse bahşiş bırakır.
func complete_deliveries(courier: Courier, delivered: Array[Dictionary]) -> void:
	if delivered.is_empty():
		return
	var total := 0
	var tips := 0
	for order in delivered:
		var quality_sum := 0
		var count := 0
		var spoiled := false
		var base_price := 0
		for id in order["filled"]:
			for quality in order["filled"][id]:
				quality_sum += quality
				count += 1
				base_price += int(Items.PRODUCTS[id]["price"])
				if quality == 1:
					spoiled = true
		var stars := roundi(float(quality_sum) / maxf(count, 1))
		if patience_ratio(order) < 0.25:
			stars -= 1
		var price_ratio := float(order["price"]) / maxf(base_price, 1.0) / Progression.price_tolerance()
		if price_ratio > 1.7:
			stars -= 2
		elif price_ratio > 1.3:
			stars -= 1
		stars = clampi(stars, 1, 5)
		var review: String
		if spoiled:
			stars = 1
			review = "Gelen yemek bozuktu! Paket servisten bir daha söylemem."
		elif stars >= 5:
			review = ["Paket sıcacık ve çabucak geldi, kurye de çok kibardı!", "Evde dükkan tadı! Hızlı teslimat, harika.", "Kurye uçarak getirdi, her şey tam kıvamında."].pick_random()
		elif stars >= 4:
			review = ["Paket servis gayet iyiydi.", "Lezzetli, teslimat biraz sürdü ama değdi."].pick_random()
		elif stars >= 3:
			review = ["Fena değil ama paket soğumuştu.", "İdare eder, teslimat geç kaldı."].pick_random()
		else:
			review = ["Paket çok geç geldi, yemekler buz gibiydi.", "Siparişim geldiğinde iştahım kaçmıştı."].pick_random()
		if price_ratio > 1.3 and not spoiled:
			review += " Fiyatlar da pahalı."
		var tip := roundi(order["price"] * 0.15) if stars == 5 else 0
		total += int(order["price"])
		tips += tip
		GameState.record_sale(order["price"], tip)
		GameState.quest_event("serve")
		GameState.quest_event("delivery")
		for id in order["filled"]:
			GameState.quest_event("sell", (order["filled"][id] as Array).size(), id)
		GameState.add_review(stars, review, order["name"])
		GameState.add_xp(Progression.sale_xp(count, stars))
	GameState.money += total + tips
	deliveries_completed.emit(courier, total, tips)
	if tips > 0:
		register.add_tip(tips)
	Sfx.play("kaching")
	var text := "%s %d paketi teslim etti: +₺%d" % [courier.data["name"], delivered.size(), total]
	if tips > 0:
		text += " (+₺%d bahşiş)" % tips
	GameState.show_toast(text)


## Gün bitebilir mi: çağrı yok, mutfakta paket fişi yok, kuryeler dönmüş ve kucakları boş.
func deliveries_done() -> bool:
	if not call.is_empty():
		return false
	for order in orders:
		if order.get("delivery", false):
			return false
	for courier in couriers:
		if courier.state != Courier.State.WAITING or not courier.packages.is_empty():
			return false
	return true


func _fire_courier(courier: Courier) -> void:
	couriers.erase(courier)
	for order in courier.packages.duplicate():
		_cancel_delivery(order, courier)
	courier.queue_free()


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
	# Plastik sandalye: hafif parlak
	_chair_mat.roughness = 0.45
	_floor_mat = Util.tile_material(Color.WHITE, Color.WHITE, 1.2)
	_door_mat.roughness = 0.6
	_frame_mat.roughness = 0.5
	add_child(Util.box(Vector3(12, 0.1, 12.2), _floor_mat, Vector3(0, -0.05, -3.9)))
	# Tavan: kurulumda salona yukarıdan bakılsın diye gizlidir.
	# Tavan ve duvarlar güneşe gölge düşürmez; yoksa salonun tamamı gölgede
	# kalıp kararır. Müşteri ve mobilyaların zemine düşen gölgesi kalır.
	_ceiling = Util.no_shadow(Util.box(Vector3(12, 0.1, 12.2), Color("#fbf3e6"), Vector3(0, 4.5, -3.9)))
	add_child(_ceiling)

	# Pencere camı: şeffaf, hafif parlak; dışarısı (Street) görünür.
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(0.82, 0.92, 0.97, 0.16)
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.roughness = 0.04
	_glass_mat.metallic_specular = 0.9

	# Arka duvar: ortada camlı kapı, iki yanda büyük vitrin pencereleri.
	var door_hole := [-DOOR_WIDTH / 2, DOOR_WIDTH / 2, 0.0, DOOR_HEIGHT]
	var back_holes := [door_hole]
	for x: float in BACK_WINDOW_X:
		back_holes.append([x - BACK_WINDOW_SIZE.x / 2, x + BACK_WINDOW_SIZE.x / 2, BACK_WINDOW_BOTTOM, BACK_WINDOW_BOTTOM + BACK_WINDOW_SIZE.y])
	_wall(true, -10.1, -6.0, 6.0, 4.5, 0.2, _wall_mat, back_holes)
	_wall(true, -10.08, -6.0, 6.0, 1.0, 0.22, _panel_mat, back_holes)
	for x: float in BACK_WINDOW_X:
		_window(Vector3(x, BACK_WINDOW_BOTTOM, -10.1), BACK_WINDOW_SIZE, 0.0)
	_build_door()
	add_child(_street)
	neighborhood = Neighborhood.new()
	add_child(neighborhood)
	# Tabela: boyutu dükkanın adına göre _layout_sign'da ayarlanır.
	_sign = Node3D.new()
	_sign.position = Vector3(0, SIGN_Y, -9.97)
	add_child(_sign)
	_sign_trim = Util.box(Vector3(1, 1, 0.08), Color("#9c3524"))
	_sign.add_child(_sign_trim)
	_sign_board = Util.box(Vector3(1, 1, 0.1), Color("#e8553e"), Vector3(0, 0, 0.02))
	_sign.add_child(_sign_board)
	_sign_label = Util.label3d("", SIGN_FONT, Color.WHITE, Vector3(0, 0, 0.08))
	_sign_label.outline_size = 14
	_sign_label.outline_modulate = Color("#9c3524")
	_sign_label.line_spacing = -18.0
	_sign.add_child(_sign_label)
	# Tabelayı aydınlatan iki küçük lamba
	for i in 2:
		var lamp := Node3D.new()
		lamp.add_child(Util.cylinder(0.015, 0.3, Color("#2b2d33"), Vector3(0, 0.15, 0.12)))
		var arm := Util.cylinder(0.015, 0.28, Color("#2b2d33"), Vector3(0, 0.3, 0.26))
		arm.rotation_degrees.x = 90
		lamp.add_child(arm)
		lamp.add_child(Util.cylinder(0.07, 0.08, Color("#2b2d33"), Vector3(0, 0.27, 0.4)))
		lamp.add_child(Util.sphere(0.04, Color("#fff1c4"), Vector3(0, 0.23, 0.4)))
		_sign.add_child(lamp)
		_sign_lamps.append(lamp)

	# Yan duvarlar, lambri ve pencereler (dışarıda bahçe ve ağaçlar)
	var side_holes := []
	for z: float in SIDE_WINDOW_Z:
		side_holes.append([z - SIDE_WINDOW_SIZE.x / 2, z + SIDE_WINDOW_SIZE.x / 2, WINDOW_BOTTOM, WINDOW_BOTTOM + SIDE_WINDOW_SIZE.y])
	# Her yan duvarın iki hali var: kapalı (pencereli) ve genişletme alınınca
	# açılan geniş geçitli hali (_sync_expansions).
	for side in [-1.0, 1.0]:
		var x: float = side * 6.0
		var closed := Node3D.new()
		add_child(closed)
		var opened := Node3D.new()
		opened.visible = false
		add_child(opened)
		_side_walls[int(side)] = [closed, opened]
		_wall(false, x, -10.0, 2.2, 4.5, 0.2, _side_mat, side_holes, closed)
		closed.add_child(Util.no_shadow(Util.box(Vector3(0.22, 1.0, 12.2), _panel_mat, Vector3(x - side * 0.01, 0.5, -3.9))))
		for z: float in SIDE_WINDOW_Z:
			_window(Vector3(x, WINDOW_BOTTOM, z), SIDE_WINDOW_SIZE, -side * 90.0, closed)
		# Geniş geçit: üstte ahşap kiriş, iki yanında dikme
		var gap := [OPENING_Z[0], OPENING_Z[1], 0.0, OPENING_TOP]
		_wall(false, x, -10.0, 2.2, 4.5, 0.2, _side_mat, [gap], opened)
		for span in [[-10.0, OPENING_Z[0]], [OPENING_Z[1], 2.2]]:
			var length: float = span[1] - span[0]
			opened.add_child(Util.no_shadow(Util.box(Vector3(0.22, 1.0, length), _panel_mat, Vector3(x - side * 0.01, 0.5, (span[0] + span[1]) / 2.0))))
		var length_open: float = OPENING_Z[1] - OPENING_Z[0]
		opened.add_child(Util.box(Vector3(0.34, 0.26, length_open + 0.3), Color("#8a5a3a"), Vector3(x, OPENING_TOP + 0.13, (OPENING_Z[0] + OPENING_Z[1]) / 2.0)))
		for z: float in OPENING_Z:
			opened.add_child(Util.box(Vector3(0.34, OPENING_TOP, 0.26), Color("#8a5a3a"), Vector3(x, OPENING_TOP / 2.0, z)))
		# Pencerelerin arasında duvar aplikleri (lambalar alınınca takılır)
		for z in [-1.4, -4.7, -8.1]:
			var sconce := Util.model("lighting/duvar_lambasi", Vector3(x - side * 0.1, 2.3, z), -side * 90.0, 1.2)
			(self if z > OPENING_Z[1] else closed).add_child(sconce)
			_sconces.append(sconce)

	_build_annex()
	_build_garden()
	_build_ruin()
	_build_rugs()
	_build_ornaments()

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
	# En arkadaki lamba tabelanın önüne düşmesin diye kapıdan biraz uzakta.
	for z in [-2.2, -4.6, -7.0]:
		var hanging := Util.model("lighting/tavan_lambasi", Vector3(0, 3.62, z), 0.0, 1.2)
		add_child(hanging)
		_ceiling_lamps.append(hanging)
		var bulb := Util.sphere(0.08, Color("#ffd27a"), Vector3(0, 3.66, z))
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
	register.phone_tapped.connect(answer_call)
	_build_package_point()


## Harabe hali: duvar lekeleri, zemin çatlakları, çöp yığınları, örümcek ağları
## ve pencerelere çakılmış tahtalar. Temizlik / pencere alınınca kaybolur.
func _build_ruin() -> void:
	_junk = Node3D.new()
	add_child(_junk)
	var stain := Color("#5d564c")
	# Lekeler pencere boşluklarına denk gelmeyen duvar parçalarında
	for pos in [Vector3(-5.3, 3.5, -9.99), Vector3(1.4, 1.5, -9.99), Vector3(5.3, 3.6, -9.99)]:
		_junk.add_child(Util.box(Vector3(1.0, 0.8, 0.02), stain, pos))
	for side in [-1.0, 1.0]:
		_junk.add_child(Util.box(Vector3(0.02, 0.9, 1.4), stain, Vector3(side * 5.89, 2.6, -9.0)))
	# Çöp yığınları, kırık kasalar, çöp poşetleri
	for pos in [Vector3(-3.4, 0, -3.6), Vector3(3.0, 0, -5.8), Vector3(-1.8, 0, -7.4), Vector3(4.2, 0, -2.4), Vector3(-4.4, 0, -6.2)]:
		_junk.add_child(Util.box(Vector3(0.6, 0.45, 0.5), Color("#6b5a45"), pos + Vector3(0, 0.22, 0)))
		var lid := Util.box(Vector3(0.55, 0.06, 0.45), Color("#56483a"), pos + Vector3(0.15, 0.5, 0.1))
		lid.rotation_degrees.z = 18
		_junk.add_child(lid)
		_junk.add_child(Util.sphere(0.28, Color("#2a2a2e"), pos + Vector3(0.55, 0.22, -0.2)))
		_junk.add_child(Util.sphere(0.2, Color("#33333a"), pos + Vector3(-0.45, 0.16, 0.25)))
	# Devrilmiş eski sandalye
	var chair := Util.model("furniture/sandalye_eski", Vector3(1.9, 0.27, -4.0))
	chair.rotation_degrees = Vector3(-90, 30, 0)
	_junk.add_child(chair)
	_junk.add_child(Util.model("furniture/sandalye_eski", Vector3(-2.6, 0, -8.6), 160.0))
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
	# Harabe halinde pencereler tahtalarla çakılı (pencereler alınınca sökülür)
	for x: float in BACK_WINDOW_X:
		for y in [0.8, 1.35, 1.95, 2.5]:
			var board := Util.box(Vector3(BACK_WINDOW_SIZE.x + 0.4, 0.24, 0.04), plank, Vector3(x, y, -9.94))
			board.rotation_degrees.z = randf_range(-8, 8)
			_boards.add_child(board)
	for side in [-1.0, 1.0]:
		for z: float in SIDE_WINDOW_Z:
			for y in [1.4, 1.95, 2.5]:
				var board := Util.box(Vector3(0.04, 0.24, SIDE_WINDOW_SIZE.x + 0.4), plank, Vector3(side * 5.86, y, z))
				board.rotation_degrees.x = 7 if y > 2 else -5
				_boards.add_child(board)


## Dekoru uygular: boya, zemin, temizlik, pencere, lamba, bitki, tabela, kasa, masa.
func _apply_decor() -> void:
	var decor := GameState.decor
	var colors: Dictionary = Decor.WALL_COLORS[decor["paint_color"]] if decor["paint"] else Decor.RUIN_WALL
	_wall_mat.albedo_color = colors["wall"]
	_side_mat.albedo_color = colors["side"]
	_panel_mat.albedo_color = colors["panel"]
	# Sandalyeler ve temizlikçilerin önlüğü/eldiveni duvar boyasının lambri rengine uyar.
	_chair_mat.albedo_color = colors["panel"]
	var uniform := uniform_colors()
	for worker in _workers:
		worker.set_uniform(uniform[0], uniform[1])
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
	for sconce in _sconces:
		sconce.visible = decor["lamps"]
	for i in _plants.size():
		_plants[i].visible = i < decor["plants"]
	_sign.visible = decor["sign"]
	_layout_sign(Util.upper_tr(GameState.shop_name))
	register.visible = decor["register"]
	_door_mat.albedo_color = Decor.STYLES["door"]["options"][decor["door"]]["color"]
	_frame_mat.albedo_color = Decor.STYLES["window"]["options"][decor["window_style"]]["color"]
	for i in _rugs.size():
		_rugs[i].visible = i == decor["rug"]
	for id in _ornaments:
		(_ornaments[id] as Node3D).visible = Decor.ornament_on(decor, id)
	if _table_style != decor["table_style"]:
		_table_style = decor["table_style"]
		for table in tables:
			_set_table_top(table)
	_ceiling.visible = GameState.setup_done and not _ceiling_open
	for c in _extra_ceilings:
		c.visible = _ceiling.visible
	_sync_tables()


## Kuşbakışı kamerada tavan kaldırılır.
func set_ceiling_open(open: bool) -> void:
	_ceiling_open = open
	_ceiling.visible = GameState.setup_done and not open
	for c in _extra_ceilings:
		c.visible = _ceiling.visible
	for lamp in _ceiling_lamps:
		lamp.visible = not open
	for bulb in _bulbs:
		bulb.visible = not open


## Boşluklu duvar: boşlukların etrafını kutularla doldurur.
## along_x: duvar x ekseni boyunca uzanır (arka duvar), değilse z boyunca (yan duvar).
## fixed: duvarın sabit ekseni (z ya da x), u0..u1 uzunluk, height yükseklik.
## holes: [u0, u1, alt, üst] listesi.
func _wall(along_x: bool, fixed: float, u0: float, u1: float, height: float, thickness: float, look, holes: Array, parent: Node3D = null) -> void:
	if parent == null:
		parent = self
	var cuts := [u0, u1]
	for hole in holes:
		cuts.append_array([hole[0], hole[1]])
	cuts.sort()
	for i in cuts.size() - 1:
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		if b - a < 0.001:
			continue
		var mid := (a + b) / 2.0
		var spans := [[0.0, height]]
		for hole in holes:
			if hole[0] < mid and mid < hole[1]:
				var rest := []
				for span in spans:
					if hole[2] > span[0]:
						rest.append([span[0], minf(span[1], hole[2])])
					if hole[3] < span[1]:
						rest.append([maxf(span[0], hole[3]), span[1]])
				spans = rest
		for span in spans:
			var h: float = span[1] - span[0]
			if h < 0.001:
				continue
			var y: float = (span[0] + span[1]) / 2.0
			var size := Vector3(b - a, h, thickness) if along_x else Vector3(thickness, h, b - a)
			var pos := Vector3(mid, y, fixed) if along_x else Vector3(fixed, y, mid)
			parent.add_child(Util.no_shadow(Util.box(size, look, pos)))


## Gerçekçi pencere: duvar kalınlığını saran beyaz pervaz, iç ve dış denizlik,
## ortada kayıt ve üstte vasistas, şeffaf cam. pos: pencerenin alt ortası.
## yaw: yerel +z salonun içine baksın diye dönüş (arka duvar 0, yan duvarlar ±90).
func _window(pos: Vector3, size: Vector2, yaw: float, parent: Node3D = null) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw
	(parent if parent else self).add_child(root)
	var white := _frame_mat
	var t := 0.08
	var depth := 0.26
	# Pervaz (boşluğun dört kenarı)
	root.add_child(Util.box(Vector3(size.x + t * 2, t, depth), white, Vector3(0, size.y + t / 2, 0)))
	root.add_child(Util.box(Vector3(size.x + t * 2, t, depth), white, Vector3(0, -t / 2, 0)))
	for x in [-1.0, 1.0]:
		root.add_child(Util.box(Vector3(t, size.y, depth), white, Vector3(x * (size.x + t) / 2, size.y / 2, 0)))
	# İç denizlik (salona taşar) ve dış denizlik
	root.add_child(Util.box(Vector3(size.x + 0.3, 0.05, 0.16), white, Vector3(0, -0.02, 0.17)))
	root.add_child(Util.box(Vector3(size.x + 0.2, 0.05, 0.14), Color("#d9d4cb"), Vector3(0, -0.06, -0.17)))
	# Kayıtlar: ortada dikey, üstte vasistas
	var transom := size.y * 0.72
	root.add_child(Util.box(Vector3(0.06, transom, 0.08), white, Vector3(0, transom / 2, 0)))
	root.add_child(Util.box(Vector3(size.x, 0.06, 0.08), white, Vector3(0, transom, 0)))
	# Cam
	root.add_child(Util.no_shadow(Util.box(Vector3(size.x, size.y, 0.02), _glass_mat, Vector3(0, size.y / 2, 0))))


## Camlı dükkan kapısı: sol kenarından menteşeli, müşteri yaklaşınca içeri açılır.
func _build_door() -> void:
	var wood := _door_mat
	var w := DOOR_WIDTH
	var h := DOOR_HEIGHT
	# Kasa
	add_child(Util.box(Vector3(w + 0.16, 0.08, 0.26), _frame_mat, Vector3(0, h + 0.04, -10.1)))
	for x in [-1.0, 1.0]:
		add_child(Util.box(Vector3(0.08, h, 0.26), _frame_mat, Vector3(x * (w + 0.08) / 2, h / 2, -10.1)))
	# Kanat: menteşe noktası etrafında döner
	_door = Node3D.new()
	_door.position = Vector3(-w / 2, 0, -10.1)
	add_child(_door)
	var leaf_w := w - 0.02
	var cx := leaf_w / 2
	for x in [0.05, leaf_w - 0.05]:
		_door.add_child(Util.box(Vector3(0.1, h - 0.02, 0.06), wood, Vector3(x, h / 2, 0)))
	for y in [0.12, h - 0.07, 1.0]:
		_door.add_child(Util.box(Vector3(leaf_w, 0.12 if y != 1.0 else 0.06, 0.06), wood, Vector3(cx, y, 0)))
	_door.add_child(Util.no_shadow(Util.box(Vector3(leaf_w - 0.2, h - 0.3, 0.02), _glass_mat, Vector3(cx, h / 2, 0))))
	# Kulp ve "AÇIK" levhası
	_door.add_child(Util.box(Vector3(0.04, 0.4, 0.04), Color("#c9a54a"), Vector3(leaf_w - 0.16, 1.05, 0.06)))
	var tag := Util.label3d("AÇIK", 60, Color("#2f8f5b"), Vector3(cx, 1.6, 0.04))
	tag.pixel_size = 0.004
	_door.add_child(tag)


## Kapıya yakın biri (müşteri, garson) varsa kapı açılır.
func _update_door(delta: float) -> void:
	var near := false
	for child in get_children():
		if (child is ShopCustomer or child is Worker) and Vector2(child.position.x, child.position.z).distance_to(Vector2(0, -10.1)) < 1.5:
			near = true
			break
	# Kapı açılmaya başlarken kapı zili çalar.
	if near and not _door_open:
		Sfx.play("door_bell", 0.03, Main.SHOP)
	_door_open = near
	_door.rotation_degrees.y = lerpf(_door.rotation_degrees.y, -85.0 if near else 0.0, 6.0 * delta)


## Tabelayı ada göre boyutlar: yazı sığacak kadar geniş, uzun adda yazı
## küçülür, en uzunlarda iki satıra iner ve tabela yükselir.
func _layout_sign(text: String) -> void:
	_sign_label.text = text
	_sign_label.font_size = SIGN_FONT
	var fit := Util.fit_label(_sign_label, SIGN_TEXT_MAX, SIGN_MIN_FONT)
	var width := maxf(2.8, fit[0] + 0.9)
	var height := 0.75 if fit[1] == 1 else 1.1
	_sign_board.scale = Vector3(width, height, 1)
	_sign_trim.scale = Vector3(width + 0.12, height + 0.12, 1)
	# Alt kenar hep aynı yerde kalır (vitrinlerin üstü); iki satırlısı yukarı uzar.
	_sign.position.y = SIGN_Y + (height - 0.75) / 2
	for i in _sign_lamps.size():
		_sign_lamps[i].position = Vector3((i * 2 - 1) * width * 0.3, height / 2, 0)


## Temizlikçi kıyafeti: [önlük, eldiven] (dükkanın boyasına göre).
func uniform_colors() -> Array[Color]:
	return Decor.uniform_colors(GameState.decor)


## Gün ışığını dışarıya (gökyüzü) da uygular.
func set_daylight(light: float, tint: Color) -> void:
	_street.set_daylight(light, tint)


func _build_table(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	# Tepsi ve iki müşteri sığsın diye masa üstü genişletilir, boyu aynı kalır.
	# Masanın üstünde küçük bir vazo
	root.add_child(Util.cylinder(0.05, 0.14, Color("#e8553e"), Vector3(0, 0.85, -0.35)))
	root.add_child(Util.sphere(0.06, Color("#ffd166"), Vector3(0, 0.95, -0.35)))

	for side in [-1.0, 1.0]:
		_build_chair(root, Vector3(side * SEAT_OFFSET, 0, 0), side)
	if pos.x > 6.0:
		# Bahçe masası: ortasında şemsiye
		root.add_child(Util.cylinder(0.03, 2.3, Color("#e9e4dc"), Vector3(0, 1.15, 0.15)))
		var canopy := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.04
		cone.bottom_radius = 1.25
		cone.height = 0.45
		cone.radial_segments = 8
		canopy.mesh = cone
		canopy.material_override = Util.material([Color("#e8553e"), Color("#f4efe6"), Color("#3f8f6a")][int(-pos.z / 2.3) % 3])
		canopy.position = Vector3(0, 2.35, 0.15)
		canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(canopy)

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
	var table := { "pos": pos, "customer": null, "dirty": false, "tray": null, "cleaner": null, "mark": mark, "progress": progress, "root": root, "top": null }
	_set_table_top(table)
	var collider := Util.collider_box(root, Vector3(1.3, 1.0, 1.3), Vector3(0, 0.5, 0))
	collider.set_meta("tap", _on_table_tapped.bind(table))
	tables.append(table)
	# Yeni masa yerine "pop" diye konur.
	root.scale = Vector3.ONE * 0.01
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Masanın tablası seçili masa çeşidine göre: Klasik model ya da ahşap kare,
## mermer yuvarlak, retro kırmızı (üstü 0.78 m'de, tepsiler aynı yükseklikte durur).
func _set_table_top(table: Dictionary) -> void:
	if table["top"]:
		(table["top"] as Node3D).queue_free()
	var top := Node3D.new()
	(table["root"] as Node3D).add_child(top)
	table["top"] = top
	var style: int = GameState.decor["table_style"]
	var color: Color = Decor.STYLES["table"]["options"][style]["color"]
	match style:
		0:
			var model := Util.model("furniture/masa")
			model.scale = Vector3(1.35, 1.0, 1.35)
			top.add_child(model)
		1:
			top.add_child(Util.box(Vector3(1.25, 0.07, 1.25), color, Vector3(0, 0.765, 0)))
			top.add_child(Util.box(Vector3(1.29, 0.03, 1.29), color.darkened(0.25), Vector3(0, 0.72, 0)))
			for x in [-0.52, 0.52]:
				for z in [-0.52, 0.52]:
					top.add_child(Util.box(Vector3(0.07, 0.72, 0.07), color.darkened(0.3), Vector3(x, 0.36, z)))
		2:
			top.add_child(Util.cylinder(0.68, 0.06, color, Vector3(0, 0.77, 0)))
			top.add_child(Util.cylinder(0.05, 0.74, Color("#3a3d42"), Vector3(0, 0.37, 0)))
			top.add_child(Util.cylinder(0.3, 0.04, Color("#3a3d42"), Vector3(0, 0.02, 0)))
		3:
			top.add_child(Util.cylinder(0.66, 0.06, color, Vector3(0, 0.77, 0)))
			top.add_child(Util.cylinder(0.68, 0.03, Color("#d9dde2"), Vector3(0, 0.735, 0)))
			top.add_child(Util.cylinder(0.045, 0.74, Color("#c9ced4"), Vector3(0, 0.37, 0)))
			top.add_child(Util.cylinder(0.28, 0.03, Color("#c9ced4"), Vector3(0, 0.015, 0)))


## Giriş halıları (Decor.STYLES["rug"]): 0 yok, 1 paspas, 2 kilim, 3 koridor yolluğu.
func _build_rugs() -> void:
	_rugs.append(Node3D.new())
	add_child(_rugs[0])
	# [merkez, boyut, zemin, kenar, iç desen]
	var specs := [
		[Vector3(0, 0, -9.45), Vector2(1.8, 1.0), Color("#3f7f5a"), Color("#2c5e41"), Color("#4f9a6c")],
		[Vector3(0, 0, -8.7), Vector2(2.3, 2.5), Color("#b53a2c"), Color("#f1c27d"), Color("#2f4f7f")],
		[Vector3(0, 0, -5.95), Vector2(1.3, 7.7), Color("#7a3b6a"), Color("#e8c06a"), Color("#5a2a4f")],
	]
	for spec in specs:
		var rug := Node3D.new()
		rug.position = spec[0]
		var size: Vector2 = spec[1]
		rug.add_child(Util.no_shadow(Util.box(Vector3(size.x, 0.02, size.y), spec[3], Vector3(0, 0.01, 0))))
		rug.add_child(Util.no_shadow(Util.box(Vector3(size.x - 0.16, 0.02, size.y - 0.16), spec[2], Vector3(0, 0.014, 0))))
		rug.add_child(Util.no_shadow(Util.box(Vector3(size.x - 0.42, 0.02, size.y - 0.42), spec[4], Vector3(0, 0.018, 0))))
		# Ortada eşkenar dörtgen motifler
		var motifs := maxi(1, int(size.y / 1.2))
		for i in motifs:
			var z := (i - (motifs - 1) / 2.0) * (size.y - 0.6) / maxf(motifs, 1.0)
			var diamond := Util.no_shadow(Util.box(Vector3(0.32, 0.02, 0.32), spec[3], Vector3(0, 0.022, z)))
			diamond.rotation_degrees.y = 45
			rug.add_child(diamond)
		rug.visible = false
		add_child(rug)
		_rugs.append(rug)


## Süsler (Decor.ORNAMENTS); alınınca ve açıkken görünür.
func _build_ornaments() -> void:
	# Işık zinciri: vitrin duvarının üst kenarında sarkarak uzanan renkli ampuller
	var lights := Node3D.new()
	var colors := [Color("#ff6b6b"), Color("#ffd166"), Color("#06d6a0"), Color("#4cc9f0"), Color("#c77dff")]
	for i in 37:
		var x := -5.6 + i * (11.2 / 36.0)
		var y := 4.3 - 0.14 * absf(sin(x / 1.4 * PI))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		mat.emission_enabled = true
		mat.emission = colors[i % colors.size()]
		mat.emission_energy_multiplier = 1.6
		lights.add_child(Util.no_shadow(Util.sphere(0.045, mat, Vector3(x, y, -9.95))))
	_ornaments["lights"] = lights

	# Vitrin çiçekleri: iki vitrinin önünde çiçekli kasa
	var flowers := Node3D.new()
	var petals := [Color("#ff7aa2"), Color("#ffd166"), Color("#ffffff"), Color("#c77dff"), Color("#ff9f43")]
	for wx: float in BACK_WINDOW_X:
		flowers.add_child(Util.box(Vector3(2.3, 0.2, 0.26), Color("#8a5a3a"), Vector3(wx, BACK_WINDOW_BOTTOM + 0.1, -9.8)))
		for i in 11:
			var fx := wx - 1.0 + i * 0.2
			flowers.add_child(Util.no_shadow(Util.sphere(0.09, Color("#4f9a52"), Vector3(fx, BACK_WINDOW_BOTTOM + 0.24, -9.8))))
			flowers.add_child(Util.no_shadow(Util.sphere(0.06, petals[i % petals.size()], Vector3(fx + 0.04, BACK_WINDOW_BOTTOM + 0.33, -9.76))))
	_ornaments["flowers"] = flowers

	# Duvar saati: sol duvarda, pencerenin üstünde
	var clock := Node3D.new()
	clock.position = Vector3(-5.86, 3.5, -3.0)
	var rim := Util.cylinder(0.4, 0.07, Color("#3a2a20"))
	rim.rotation_degrees.z = 90
	clock.add_child(rim)
	var face := Util.cylinder(0.34, 0.08, Color("#fbf6ec"))
	face.rotation_degrees.z = 90
	clock.add_child(face)
	for i in 12:
		var a := i * TAU / 12.0
		clock.add_child(Util.box(Vector3(0.02, 0.05 if i % 3 else 0.08, 0.02), Color("#3a2a20"), Vector3(0.045, cos(a) * 0.28, sin(a) * 0.28)))
	var hour := Util.box(Vector3(0.02, 0.18, 0.035), Color("#3a2a20"), Vector3(0.05, 0.07, 0.03))
	hour.rotation_degrees.x = -40
	clock.add_child(hour)
	var minute := Util.box(Vector3(0.02, 0.26, 0.025), Color("#b53a2c"), Vector3(0.055, 0.1, -0.06))
	minute.rotation_degrees.x = 35
	clock.add_child(minute)
	_ornaments["clock"] = clock

	# Tablolar: sağ duvarda iki manzara
	var frames := Node3D.new()
	var scenes := [[Color("#8fc9f0"), Color("#5fa05a"), Color("#ffd166")], [Color("#f4b183"), Color("#2f6f8f"), Color("#fff1c4")]]
	for i in 2:
		var z: float = SIDE_WINDOW_Z[i]
		var colors_i: Array = scenes[i]
		frames.add_child(Util.box(Vector3(0.05, 0.8, 1.05), Color("#6b4428"), Vector3(5.87, 3.55, z)))
		frames.add_child(Util.box(Vector3(0.02, 0.32, 0.9), colors_i[0], Vector3(5.84, 3.7, z)))
		frames.add_child(Util.box(Vector3(0.02, 0.32, 0.9), colors_i[1], Vector3(5.84, 3.38, z)))
		frames.add_child(Util.sphere(0.08, colors_i[2], Vector3(5.83, 3.75, z + 0.22)))
	_ornaments["frames"] = frames

	# Nazar boncuğu: kapının sağında ipte asılı
	var nazar := Node3D.new()
	nazar.position = Vector3(1.15, 2.2, -9.97)
	nazar.add_child(Util.box(Vector3(0.012, 0.4, 0.012), Color("#c9a54a"), Vector3(0, 0.36, 0)))
	var rings := [[0.17, Color("#1f4fa8")], [0.115, Color("#ffffff")], [0.075, Color("#5fb3f0")], [0.035, Color("#111111")]]
	for i in rings.size():
		var disc := Util.cylinder(rings[i][0], 0.02, rings[i][1], Vector3(0, 0, 0.012 * (i + 1)))
		disc.rotation_degrees.x = 90
		nazar.add_child(disc)
	_ornaments["nazar"] = nazar

	# Menü panosu: kapının solunda ayaklı kara tahta
	var board := Node3D.new()
	board.position = Vector3(-1.5, 0, -9.35)
	board.rotation_degrees.y = 18
	var slate := Node3D.new()
	slate.rotation_degrees.x = -10
	board.add_child(slate)
	slate.add_child(Util.box(Vector3(0.78, 1.05, 0.05), Color("#8a5a3a"), Vector3(0, 0.6, 0)))
	slate.add_child(Util.box(Vector3(0.66, 0.92, 0.05), Color("#2d3a32"), Vector3(0, 0.6, 0.012)))
	var chalk := Util.label3d("GÜNÜN\nMENÜSÜ\n~\nLahmacun\nKöfte\nAyran", 40, Color("#f5f1e6"), Vector3(0, 0.62, 0.045))
	chalk.pixel_size = 0.0035
	chalk.line_spacing = -6.0
	slate.add_child(chalk)
	var leg := Util.box(Vector3(0.05, 1.1, 0.05), Color("#6b4428"), Vector3(0, 0.55, -0.32))
	leg.rotation_degrees.x = 18
	board.add_child(leg)
	_ornaments["board"] = board

	for id in _ornaments:
		(_ornaments[id] as Node3D).visible = false
		add_child(_ornaments[id])


## Sandalye modeli +Z'ye bakar; masaya dönsün diye çevrilir (sırtlık dışarıda).
## Rengi ortak materyalden gelir (duvar boyasına göre _apply_decor değiştirir).
func _build_chair(root: Node3D, pos: Vector3, side: float) -> void:
	var chair := Util.model("furniture/sandalye", pos, -side * 90.0)
	for mesh: MeshInstance3D in Util.meshes(chair):
		mesh.material_override = _chair_mat
	root.add_child(chair)
