extends Node

## Oyunun genel durumu: para, stok, pişmiş ürünler ve müşteri yorumları.
## Autoload olarak "GameState" adıyla yüklenir.

signal money_changed(value: int)
signal stock_changed
signal prepared_changed
signal reviews_changed
signal toast_requested(text: String)
signal xp_changed
signal level_up(level: int)
signal upgrades_changed
signal staff_changed
signal day_started(day: int)
signal day_ended(stats: Dictionary)
signal decor_changed
signal setup_finished
signal tutorial_changed(step: int)
## Toptancı fiyatları değişti ya da satış fiyatı ayarlandı
signal market_changed
## Menüye ürün eklendi / menü seçildi
signal menu_changed
## Günlük görevlerde ilerleme oldu ya da ödül alındı
signal quests_changed
## Bir görev tamamlandı (ödülü alınmayı bekliyor)
signal quest_completed(quest: Dictionary)

const MAX_REVIEWS := 30
## Oyuncu isim vermezse dükkanın adı (oyunun adıyla aynı)
const DEFAULT_SHOP_NAME := "Köşe Dükkan"
## Çalışma saatleri (dakika). Son siparişten sonra yeni müşteri gelmez.
const OPEN_TIME := 9 * 60
const LAST_ORDER := 21 * 60
const CLOSE_TIME := 22 * 60
## Bir iş gününün gerçek süresi (saniye)
const DAY_SECONDS := 300.0

var day := 1
var minutes := float(OPEN_TIME)
## Gece (gün sonu özeti açıkken) false olur.
var is_open := true
## Gün içi kayıtlar: gelir, bahşiş, giderler, müşteri sayıları
var day_stats := {}
## Biten günlerin özeti (takvim için): gün, tarih, gelir/gider kalemleri,
## kime ne kadar maaş ödendiği, servis edilen ve kaybedilen müşteri.
var history: Array[Dictionary] = []
## İşe alınmış personel ve günün adayları
var staff: Array[Dictionary] = []
var candidates: Array[Dictionary] = []

## Başlangıç kurulumu: dükkan adı ve dekor. Kurulum bitene kadar müşteri gelmez.
var shop_name := DEFAULT_SHOP_NAME
var setup_done := false
var decor := Decor.default_state()
## Tanıtım adımı; -1 ise tanıtım yok / bitti.
var tutorial_step := -1
## Giriş serisi (Rewards): art arda girilen gün sayısı, son giriş ve ödülün alındığı gün
var login_streak := 0
var last_login_day := ""
var streak_claimed_day := ""
## Sen yokken yapılan satışların raporu (Rewards.run_offline); Hud gösterince boşaltır.
var offline_report := {}
## Gösterilecek bir ödül penceresi var (sen yokken raporu ya da giriş serisi)
signal rewards_pending

## Oyuncu kendi kasasını kapattı mı (kasiyer varken bütün müşteriler ona gider).
var player_register_closed := false

## Şubeler (Branches): her dükkan { lot, data } (data: Branches.SHOP_KEYS alanları).
## Şube alınmadıysa boş; alınınca ilk dükkan da (lot 0) listeye girer. Oynanan
## dükkanın alanları GameState'tedir, listedeki kopyası kayıtta güncellenir.
var shops: Array[Dictionary] = []
var active_shop := 0
signal branches_changed
signal register_mode_changed

## Oyuncunun menüsü: kurulumda seçilir, seviye atladıkça yemek eklenebilir.
var menu: Array[String] = []

## Menü sisteminden önceki kayıtlar: ürünlerin açıldığı seviye (eski kayıt
## yüklenirken menüsü bu seviyelere göre kurulur).
const LEGACY_UNLOCK := { "tavuk": 1, "tavuk_sis": 1, "kofte": 1, "patates": 1, "kola": 1, "ayran": 2, "lahmacun": 3, "pizza": 4, "pide": 5 }
## Kurulumda seçilen ürünlerden başlangıçta verilen stok
const START_FOOD_STOCK := 3
const START_DRINK_STOCK := 5
## Günlük görevler (Quests): { kind, item, target, progress, claimed, money, xp }
var quests: Array[Dictionary] = []
## Görevlerin üretildiği gün; gün değişince yenileri çıkar.
var quests_day := 0
## Üç görevin sandık bonusu bugün alındı mı?
var quest_bonus_claimed := false


func set_shop_name(text: String) -> void:
	text = text.strip_edges()
	shop_name = text.left(20) if text != "" else DEFAULT_SHOP_NAME
	decor_changed.emit()


## Kurulumda tek seferlik dekoru alır ya da (geri alınırsa) parasını iade eder.
func toggle_decor(id: String) -> void:
	var price: int = Decor.ITEMS[id]["price"]
	if decor[id]:
		decor[id] = false
		money += price
	elif money >= price:
		decor[id] = true
		money -= price
	else:
		show_toast("Bütçe yetmiyor!")
		return
	decor_changed.emit()


func set_paint_color(index: int) -> void:
	if not decor["paint"]:
		show_toast("Önce duvar boyasını al")
		return
	decor["paint_color"] = index
	decor_changed.emit()


## Zemin değiştirirken eskisinin parası iade edilir.
func set_floor(index: int) -> void:
	var old_price: int = Decor.FLOORS[decor["floor"]]["price"]
	var new_price: int = Decor.FLOORS[index]["price"]
	if money + old_price < new_price:
		show_toast("Bütçe yetmiyor!")
		return
	money += old_price - new_price
	decor["floor"] = index
	decor_changed.emit()


## Dekor mağazası: seçeneği seçer, sahip değilse satın alır. Döner: başarılı mı.
func choose_decor(category: String, index: int) -> bool:
	var cost := Decor.choose(decor, category, index, money)
	if cost < 0:
		return false
	money -= cost
	if setup_done:
		day_stats["upgrades"] += cost
	decor_changed.emit()
	return true


## Süs: alınmadıysa satın alır, alındıysa açıp kapatır. Döner: başarılı mı.
func toggle_ornament(id: String) -> bool:
	var owned: Array = decor["ornaments"]
	var off: Array = decor["ornaments_off"]
	if not owned.has(id):
		var price: int = Decor.ORNAMENTS[id]["price"]
		if money < price:
			return false
		money -= price
		day_stats["upgrades"] += price
		owned.append(id)
	elif off.has(id):
		off.erase(id)
	else:
		off.append(id)
	decor_changed.emit()
	return true


## Masa ya da bitki sayısını değiştirir (adet başı fiyat, iadeli).
func change_count(id: String, delta: int) -> void:
	var price := Decor.TABLE_PRICE if id == "tables" else Decor.PLANT_PRICE
	var limit := Decor.MAX_SETUP_TABLES if id == "tables" else Decor.MAX_PLANTS
	var next: int = decor[id] + delta
	if next < 0 or next > limit:
		return
	if delta > 0 and money < price:
		show_toast("Bütçe yetmiyor!")
		return
	money -= price * delta
	decor[id] = next
	decor_changed.emit()


## Kurulumda seçilen menü: stok sadece menüdeki ürünlere verilir.
func set_starting_menu(ids: Array[String]) -> void:
	menu = ids.duplicate()
	for id in Items.PRODUCTS:
		var amount := 0
		if menu.has(id):
			amount = START_FOOD_STOCK if Items.is_food(id) else START_DRINK_STOCK
		stock[id] = amount
		batches[id] = []
	_ensure_market()
	stock_changed.emit()
	menu_changed.emit()


## Menüdeki yemek / içecek sayısı (kind: "food" ya da "drink").
func menu_count(kind: String) -> int:
	return menu.filter(func(id: String) -> bool: return Items.is_food(id) == (kind == "food")).size()


## Menüdeki ürünlerin cihazları.
func menu_devices() -> Array[String]:
	var list: Array[String] = []
	for id in menu:
		var device: String = Items.PRODUCTS[id]["device"]
		if device != "" and not list.has(device):
			list.append(device)
	return list


## Ürünü menüye eklemenin bedeli: yeni cihaz gerekiyorsa cihazın fiyatı.
func menu_add_cost(id: String) -> int:
	var device: String = Items.PRODUCTS[id]["device"]
	if device == "" or menu_devices().has(device):
		return 0
	return Items.DEVICE_PRICES[device]


## Menüde yer var mı?
func menu_has_room(id: String) -> bool:
	var kind := "food" if Items.is_food(id) else "drink"
	return menu_count(kind) < Progression.menu_slots(kind, level)


func add_to_menu(id: String) -> bool:
	if menu.has(id) or not menu_has_room(id):
		return false
	var cost := menu_add_cost(id)
	if money < cost:
		return false
	money -= cost
	day_stats["upgrades"] += cost
	menu.append(id)
	menu_changed.emit()
	return true


## Tanıtımda pişirilecek ürün: menüdeki ilk ızgara ürünü, yoksa ilk yemek.
func tutorial_food() -> String:
	var foods := menu.filter(func(id: String) -> bool: return Items.is_food(id))
	for id in foods:
		if Items.PRODUCTS[id]["device"] == "izgara":
			return id
	return foods[0] if not foods.is_empty() else "kofte"


func finish_setup() -> void:
	if not Decor.missing(decor).is_empty():
		return
	setup_done = true
	tutorial_step = 0
	ensure_quests()
	Rewards.check_login()
	setup_finished.emit()
	tutorial_changed.emit(tutorial_step)


func tutorial_active() -> bool:
	return tutorial_step >= 0


func advance_tutorial(to_step: int) -> void:
	tutorial_step = to_step
	tutorial_changed.emit(tutorial_step)


## Kaydedilecek her şey (SaveSystem bunu JSON olarak saklar).
func to_dict() -> Dictionary:
	return {
		"money": money, "stock": stock, "prepared": prepared, "reviews": reviews,
		"level": level, "xp": xp, "upgrades": upgrades,
		"day": day, "minutes": minutes, "is_open": is_open, "day_stats": day_stats,
		"staff": staff, "candidates": candidates,
		"shop_name": shop_name, "setup_done": setup_done, "decor": decor,
		"tutorial_step": tutorial_step, "history": history,
		"batches": batches, "market": market, "price_factors": price_factors,
		"menu": menu,
		"quests": quests, "quests_day": quests_day, "quest_bonus_claimed": quest_bonus_claimed,
		"login_streak": login_streak, "last_login_day": last_login_day, "streak_claimed_day": streak_claimed_day,
		"player_register_closed": player_register_closed,
		"shops": _shops_snapshot(), "active_shop": active_shop,
	}


## Oynanan dükkanın kendine ait alanları (kopya).
func shop_data() -> Dictionary:
	var all := {
		"shop_name": shop_name, "decor": decor, "menu": menu, "upgrades": upgrades, "staff": staff,
		"candidates": candidates, "stock": stock, "batches": batches, "prepared": prepared,
		"reviews": reviews, "price_factors": price_factors, "player_register_closed": player_register_closed,
	}
	return all.duplicate(true)


func _shops_snapshot() -> Array:
	var list: Array = []
	for i in shops.size():
		var entry: Dictionary = shops[i].duplicate()
		if i == active_shop:
			entry["data"] = shop_data()
		list.append(entry)
	return list


## Mahalledeki bir dükkan yerini satın alır. Döner: başarılı mı.
func buy_lot(lot: int) -> bool:
	var data: Dictionary = Branches.LOTS[lot]
	if Branches.owned(lot):
		return false
	if level < int(data["level"]):
		show_toast("Bu dükkan için Seviye %d gerekli" % data["level"])
		return false
	if money < int(data["price"]):
		show_toast("Yeterli paran yok")
		return false
	money -= int(data["price"])
	day_stats["upgrades"] += int(data["price"])
	if shops.is_empty():
		shops.append({ "lot": 0, "data": {} })
		active_shop = 0
	shops.append({ "lot": lot, "data": Branches.new_shop(lot) })
	branches_changed.emit()
	return true


## Başka bir dükkana geçer: oynanan dükkanın alanları saklanır, diğeri yüklenir.
## Sahne yeniden kurulur (Main), dükkan yeni haliyle açılır.
func switch_shop(index: int) -> void:
	if index == active_shop or index < 0 or index >= shops.size():
		return
	shops[active_shop]["data"] = shop_data()
	active_shop = index
	var full := to_dict()
	var data: Dictionary = shops[index]["data"]
	for key in data:
		full[key] = data[key]
	from_dict(full)
	# Gece geçildiyse yeni dükkan sabahla açılır.
	if setup_done and not is_open:
		start_day()


## Kayıttan yükler. Eksik alanlar varsayılan kalır (eski kayıtlarla uyum için).
func from_dict(data: Dictionary) -> void:
	money = int(data.get("money", money))
	stock = _merge(stock, data.get("stock", {}), true)
	prepared = _merge(prepared, data.get("prepared", {}), false)
	reviews.clear()
	for review in data.get("reviews", []):
		review["stars"] = int(review["stars"])
		reviews.append(review)
	level = int(data.get("level", level))
	xp = int(data.get("xp", xp))
	upgrades = _merge({}, data.get("upgrades", {}), true)
	day = int(data.get("day", day))
	minutes = float(data.get("minutes", minutes))
	is_open = bool(data.get("is_open", is_open))
	day_stats = _merge(day_stats, data.get("day_stats", {}), true)
	staff.clear()
	for person in data.get("staff", []):
		staff.append(_int_fields(person))
	candidates.clear()
	for person in data.get("candidates", []):
		candidates.append(_int_fields(person))
	ensure_courier_candidates()
	ensure_role_candidates()
	shop_name = str(data.get("shop_name", shop_name))
	setup_done = bool(data.get("setup_done", setup_done))
	decor = _merge(Decor.default_state(), data.get("decor", {}), true)
	tutorial_step = int(data.get("tutorial_step", -1))
	history.clear()
	for record in data.get("history", []):
		history.append(record)
	batches = {}
	for id in data.get("batches", {}):
		batches[id] = (data["batches"][id] as Array).map(func(d) -> int: return int(d))
	market = data.get("market", {}).duplicate(true)
	price_factors = {}
	for id in data.get("price_factors", {}):
		price_factors[id] = float(data["price_factors"][id])
	_ensure_market()
	menu.clear()
	if data.has("menu"):
		for id in data["menu"]:
			if Items.PRODUCTS.has(id):
				menu.append(id)
	elif setup_done:
		# Menü sisteminden önceki kayıt: seviyesine kadar açılmış ürünler menüde.
		for id in LEGACY_UNLOCK:
			if level >= LEGACY_UNLOCK[id]:
				menu.append(id)
	menu_changed.emit()
	quests.clear()
	for quest in data.get("quests", []):
		if not Quests.KINDS.has(quest.get("kind", "")):
			continue
		for key in ["target", "progress", "money", "xp"]:
			quest[key] = int(quest.get(key, 0))
		quest["claimed"] = bool(quest.get("claimed", false))
		quest["item"] = str(quest.get("item", ""))
		quests.append(quest)
	quests_day = int(data.get("quests_day", 0))
	quest_bonus_claimed = bool(data.get("quest_bonus_claimed", false))
	player_register_closed = bool(data.get("player_register_closed", false))
	shops.clear()
	for entry in data.get("shops", []):
		shops.append({ "lot": int(entry["lot"]), "data": entry.get("data", {}) })
	active_shop = clampi(int(data.get("active_shop", 0)), 0, maxi(shops.size() - 1, 0))
	login_streak = int(data.get("login_streak", 0))
	last_login_day = str(data.get("last_login_day", ""))
	streak_claimed_day = str(data.get("streak_claimed_day", ""))
	ensure_quests()
	# Tanıtım yarıda kaldıysa kapalı başlasın (oyun tanıtım modunda takılmasın).
	tutorial_step = -1


## JSON sayıları float döndürür; tamsayı alanlar int'e çevrilir.
func _merge(base: Dictionary, loaded: Dictionary, as_int: bool) -> Dictionary:
	var result := base.duplicate(true)
	for key in loaded:
		var value = loaded[key]
		if as_int and value is float:
			value = int(value)
		elif value is Array:
			var list := []
			for v in value:
				list.append(int(v) if v is float else v)
			value = list
		result[key] = value
	return result


func _int_fields(person: Dictionary) -> Dictionary:
	for key in ["speed", "work", "wage"]:
		person[key] = int(person[key])
	return person


## Geliştirme ve testler için: hazır döşenmiş dükkanla, tanıtımsız başlar.
func quick_start() -> void:
	decor = _merge(Decor.default_state(), { "clean": true, "register": true, "paint": true, "windows": true, "lamps": true, "sign": true,
		"paint_color": 0, "floor": 2, "tables": 4, "plants": 2 }, false)
	setup_done = true
	tutorial_step = -1
	if menu.is_empty():
		set_starting_menu(["kofte", "tavuk", "patates", "kola", "ayran"])
	ensure_quests()
	decor_changed.emit()
	setup_finished.emit()

var money := Decor.START_BUDGET:
	set(value):
		money = value
		money_changed.emit(money)

## Çiğ malzeme ve hazır içecek stoğu.
var stock := { "tavuk": 3, "tavuk_sis": 3, "kofte": 3, "patates": 3, "kola": 5, "ayran": 0, "lahmacun": 0, "pizza": 0, "pide": 0 }
## Stoktaki her malzemenin son kullanma günü (eskiden yeniye). stock ile aynı adette.
var batches := {}
## Toptancı borsası: ürün -> { factor, deal, price, history } (Exchange)
var market := {}
## Satış fiyatı çarpanı: ürün -> 0.5–2.0 (menüdeki taban fiyata göre)
var price_factors := {}
## Pişmiş, servise hazır ürünler: ürün -> kalite listesi (5 tam, 3 fazla, 2 az pişmiş).
var prepared := { "tavuk": [], "tavuk_sis": [], "kofte": [], "patates": [], "lahmacun": [], "pizza": [], "pide": [] }
var reviews: Array[Dictionary] = []
var level := 1
var xp := 0
## Geliştirme kademeleri: id -> alınan kademe sayısı
var upgrades := {}


func _ready() -> void:
	candidates = Staff.make_candidates(3, staff, level)
	_reset_stats()
	_ensure_market()


func _process(delta: float) -> void:
	# Kurulum ve tanıtım sırasında saat ilerlemez.
	if setup_done and not tutorial_active() and is_open and minutes < CLOSE_TIME:
		var before := minutes
		minutes = minf(minutes + delta * (CLOSE_TIME - OPEN_TIME) / DAY_SECONDS, CLOSE_TIME)
		# Toptancı fiyatları gün içinde birkaç kez değişir.
		for tick in Exchange.TICKS:
			if before < tick and minutes >= tick:
				tick_market()
		if before < LAST_ORDER and minutes >= LAST_ORDER:
			show_toast("Son sipariş saati! Dükkan 22:00'de kapanıyor")


## Yeni müşteri kabul ediliyor mu?
func accepting_customers() -> bool:
	return setup_done and is_open and minutes < LAST_ORDER


func clock_text() -> String:
	return "%02d:%02d" % [int(minutes) / 60, int(minutes) % 60]


## Dükkan kapandı ve içeride kimse kalmadı: maaşlar ödenir, gün özeti çıkar.
func end_day() -> void:
	if not is_open:
		return
	is_open = false
	# Görev ödülleri maaşlardan önce kasaya girer.
	_auto_claim_quests()
	var quitters: Array[String] = []
	var paid: Array[Dictionary] = []
	for person in staff.duplicate():
		var wage: int = person["wage"]
		if money >= wage:
			money -= wage
			day_stats["wages"] += wage
			paid.append({ "name": person["name"], "wage": wage })
		else:
			staff.erase(person)
			quitters.append(person["name"])
	# Kira ve faturalar (para yetmezse kasadaki kadarı ödenir)
	var costs := Progression.daily_costs()
	var due: int = costs["rent"] + costs["bills"]
	var paid_rent := mini(due, maxi(money, 0))
	money -= paid_rent
	day_stats["rent"] = paid_rent
	day_stats["rent_due"] = due
	# Diğer dükkanlar kendi kasiyer ve aşçısıyla çalıştı
	var branch_reports: Array = []
	var branch_net := 0
	for i in shops.size():
		if i == active_shop:
			continue
		var report := Branches.simulate_day(shops[i])
		money += int(report["net"])
		branch_net += int(report["net"])
		branch_reports.append(report)
	day_stats["branches"] = branch_net
	day_stats["branch_reports"] = branch_reports
	day_stats["quitters"] = quitters
	day_stats["money"] = money
	_record_day(paid, quitters)
	if not quitters.is_empty():
		staff_changed.emit()
	day_ended.emit(day_stats)


## Günün özetini takvim geçmişine yazar.
func _record_day(paid: Array[Dictionary], quitters: Array[String]) -> void:
	var record := {
		"day": day, "date": Time.get_date_string_from_system(), "money": money,
		"wages_paid": paid, "quitters": quitters,
	}
	for key in ["revenue", "tips", "quests", "gifts", "supplies", "upgrades", "wages", "rent", "branches", "served", "lost"]:
		record[key] = int(day_stats.get(key, 0))
	record["branch_reports"] = day_stats.get("branch_reports", [])
	history.assign(history.filter(func(r: Dictionary) -> bool: return int(r["day"]) != day))
	history.append(record)


## Günün net kazancı: gelir + bahşiş + görev ödülü − malzeme − geliştirme − maaş.
static func net_of(record: Dictionary) -> int:
	return int(record.get("revenue", 0)) + int(record.get("tips", 0)) + int(record.get("quests", 0)) + int(record.get("gifts", 0)) - int(record.get("supplies", 0)) 		- int(record.get("upgrades", 0)) - int(record.get("wages", 0)) - int(record.get("rent", 0)) + int(record.get("branches", 0))


func start_day() -> void:
	day += 1
	minutes = OPEN_TIME
	is_open = true
	candidates = Staff.make_candidates(3, staff, level)
	_reset_stats()
	tick_market()
	ensure_quests()
	staff_changed.emit()
	day_started.emit(day)
	var spoiled := 0
	for id in batches:
		spoiled += expired_count(id)
	if spoiled > 0:
		show_toast("%d malzemenin son kullanma tarihi geçti! Market'ten atabilirsin" % spoiled)


func record_sale(amount: int, tip: int) -> void:
	Haptics.light()
	day_stats["revenue"] += amount
	day_stats["tips"] += tip
	day_stats["served"] += 1
	quest_event("revenue", amount)
	if tip > 0:
		quest_event("tips", tip)


func record_tip(tip: int) -> void:
	day_stats["tips"] += tip
	quest_event("tips", tip)


# --- Günlük görevler -----------------------------------------------------------

## Bugünün görevleri yoksa üretir (kurulum bitmeden görev çıkmaz).
func ensure_quests() -> void:
	if not setup_done or (quests_day == day and not quests.is_empty()):
		return
	var has_courier := Staff.count(staff, "kurye") > 0
	quests = Quests.generate(day, level, menu, has_courier, shop_name)
	quests_day = day
	quest_bonus_claimed = false
	quests_changed.emit()


## Oyunda bir şey oldu (kind: serve, revenue, tips, five_star, sell, clean,
## delivery, bullseye, streak). amount: adet ya da tutar, item: satılan ürün.
func quest_event(kind: String, amount := 1, item := "") -> void:
	if not setup_done or not is_open:
		return
	var changed := false
	for quest in quests:
		var before := int(quest["progress"])
		if Quests.apply(quest, kind, amount, item):
			quest_completed.emit(quest)
		changed = changed or int(quest["progress"]) != before
	if changed:
		quests_changed.emit()


func quests_ready_count() -> int:
	return quests.filter(func(q: Dictionary) -> bool: return Quests.done(q) and not q["claimed"]).size()


func quests_done_count() -> int:
	return quests.filter(func(q: Dictionary) -> bool: return Quests.done(q)).size()


## Görevin ödülünü verir; üç görev de alındıysa sandık bonusunu da verir.
## Döner: verilen toplam { money, xp, bonus }.
func claim_quest(index: int) -> Dictionary:
	if index < 0 or index >= quests.size():
		return {}
	var quest := quests[index]
	if quest["claimed"] or not Quests.done(quest):
		return {}
	quest["claimed"] = true
	var reward := { "money": int(quest["money"]), "xp": int(quest["xp"]), "bonus": false }
	if not quest_bonus_claimed and quests.all(func(q: Dictionary) -> bool: return q["claimed"]):
		quest_bonus_claimed = true
		var extra := Quests.bonus(level)
		reward["money"] += extra["money"]
		reward["xp"] += extra["xp"]
		reward["bonus"] = true
	_pay_quest(reward)
	quests_changed.emit()
	return reward


## Gün biterken tamamlanmış ama alınmamış görevlerin ödülü kasaya girer.
func _auto_claim_quests() -> void:
	var total := { "money": 0, "xp": 0 }
	for i in quests.size():
		var reward := claim_quest(i)
		if not reward.is_empty():
			total["money"] += reward["money"]
			total["xp"] += reward["xp"]
	day_stats["quest_auto"] = total["money"]


func _pay_quest(reward: Dictionary) -> void:
	money += reward["money"]
	day_stats["quests"] = int(day_stats.get("quests", 0)) + reward["money"]
	add_xp(reward["xp"])


## Masa bulamayan ya da siparişi gecikene para iadesi: satış geri alınır.
func record_refund(amount: int) -> void:
	day_stats["revenue"] -= amount
	day_stats["served"] -= 1


func record_lost_customer() -> void:
	day_stats["lost"] += 1


func hire(index: int) -> bool:
	var job := Staff.role(candidates[index])
	if job == "kasiyer" and upgrade_level("register2") == 0:
		show_toast("Kasiyer için önce Geliştir'den Ek Kasa al")
		return false
	var limit: int = Staff.ROLES[job]["max"]
	if Staff.count(staff, job) >= limit:
		show_toast("En fazla %d %s alabilirsin" % [limit, Staff.ROLES[job]["name"].to_lower()])
		return false
	staff.append(candidates[index])
	candidates.remove_at(index)
	staff_changed.emit()
	return true


func fire(index: int) -> void:
	staff.remove_at(index)
	if Staff.count(staff, "kasiyer") == 0:
		player_register_closed = false
	staff_changed.emit()


## Kendi kasanı kapat / aç: kapalıyken yeni müşteriler kasiyerin sırasına girer.
func set_player_register_closed(closed: bool) -> void:
	if closed and Staff.count(staff, "kasiyer") == 0:
		show_toast("Kasanı kapatmak için önce kasiyer tut")
		return
	player_register_closed = closed
	register_mode_changed.emit()


## Seviyesi gelen ama adaylarda olmayan aşçı / kasiyer adayı eklenir (eski kayıtlar
## ve gün ortasında seviye atlayınca yarını beklemesin).
func ensure_role_candidates() -> void:
	var added := false
	for job in ["asci", "kasiyer"]:
		if level < int(Staff.ROLES[job]["unlock"]) or Staff.count(staff, job) >= int(Staff.ROLES[job]["max"]):
			continue
		if candidates.any(func(p: Dictionary) -> bool: return Staff.role(p) == job):
			continue
		var taken: Array[Dictionary] = []
		taken.append_array(staff)
		taken.append_array(candidates)
		candidates.append_array(Staff.make_people([job] as Array[String], taken))
		added = true
	if added:
		staff_changed.emit()


## Pazarlık: kabul ederse maaş düşer; etmezse bir daha pazarlık yapılamaz.
func haggle(index: int) -> bool:
	var person := candidates[index]
	person["haggled"] = true
	var accepted := Staff.accepts_haggle(person)
	if accepted:
		person["wage"] = Staff.haggle_offer(person)
	staff_changed.emit()
	return accepted


func _reset_stats() -> void:
	day_stats = { "revenue": 0, "tips": 0, "quests": 0, "gifts": 0, "supplies": 0, "upgrades": 0, "wages": 0, "rent": 0, "served": 0, "lost": 0 }


func add_xp(amount: int) -> void:
	xp += amount
	while level < Progression.MAX_LEVEL and xp >= Progression.xp_needed(level):
		xp -= Progression.xp_needed(level)
		level += 1
		level_up.emit(level)
		ensure_courier_candidates()
		ensure_role_candidates()
	xp_changed.emit()


## Kurye açıldığı seviyeye gelince (ya da eski kayıtta) aday listesine kuryeler eklenir.
func ensure_courier_candidates() -> void:
	if level < int(Staff.ROLES["kurye"]["unlock"]):
		return
	if Staff.count(candidates, "kurye") > 0 or Staff.count(staff, "kurye") > 0:
		return
	var all: Array[Dictionary] = staff + candidates
	candidates.append_array(Staff.make_people(["kurye", "kurye"] as Array[String], all))
	staff_changed.emit()


func upgrade_level(id: String) -> int:
	return upgrades.get(id, 0)


## Geliştirme satın alır; olmazsa nedenini bildirim olarak gösterir.
func buy_upgrade(id: String) -> bool:
	var current := upgrade_level(id)
	var cost := Progression.upgrade_cost(id, current)
	if cost < 0:
		return false
	var needed := Progression.upgrade_required_level(id, current)
	if level < needed:
		show_toast("Seviye %d gerekli" % needed)
		return false
	if money < cost:
		show_toast("Yeterli paran yok!")
		return false
	money -= cost
	day_stats["upgrades"] += cost
	upgrades[id] = current + 1
	upgrades_changed.emit()
	return true


func rating() -> float:
	if reviews.is_empty():
		return 4.0
	var total := 0
	for review in reviews:
		total += int(review["stars"])
	return float(total) / reviews.size()


## Siparişe hemen verilebilecek adet (pişenler için hazır olanlar, içecek için stok).
func available(id: String) -> int:
	if prepared.has(id):
		return prepared[id].size()
	return stock[id]


## Toptancıdan bir paket alır: fiyat borsadaki güncel fiyattır, son kullanma
## günü alındığı güne raf ömrü eklenerek yazılır.
func buy_pack(id: String) -> bool:
	var cost := pack_price(id)
	if money < cost:
		return false
	money -= cost
	day_stats["supplies"] += cost
	var deal: String = market[id]["deal"]
	for i in Items.PACK_SIZE:
		(batches[id] as Array).append(day + Exchange.shelf_life(id, deal))
	(batches[id] as Array).sort()
	stock[id] += Items.PACK_SIZE
	stock_changed.emit()
	return true


func pack_price(id: String) -> int:
	return int(market[id]["price"])


func take_stock(id: String) -> bool:
	return take_stock_item(id) >= 0


## Stoktan en eski malzemeyi alır. Döner: -1 yok, 0 taze, 1 tarihi geçmiş.
func take_stock_item(id: String) -> int:
	if stock[id] <= 0:
		return -1
	stock[id] -= 1
	var expiry: int = (batches[id] as Array).pop_front() if not (batches[id] as Array).is_empty() else day
	stock_changed.emit()
	return 1 if expiry < day else 0


## Tarihi geçmiş malzeme sayısı.
func expired_count(id: String) -> int:
	var n := 0
	for expiry in batches.get(id, []):
		if expiry < day:
			n += 1
	return n


## En yakın son kullanma günü (stok yoksa -1).
func next_expiry(id: String) -> int:
	var list: Array = batches.get(id, [])
	for expiry in list:
		if expiry >= day:
			return expiry
	return -1


## Tarihi geçenleri çöpe atar; atılan adedi döner.
func discard_expired(id: String) -> int:
	var n := expired_count(id)
	if n == 0:
		return 0
	batches[id] = (batches[id] as Array).filter(func(expiry: int) -> bool: return expiry >= day)
	stock[id] -= n
	stock_changed.emit()
	return n


## Borsa: bütün malzemelerin fiyatı bir adım oynar.
func tick_market() -> void:
	for id in Items.PRODUCTS:
		market[id] = Exchange.step(id, market.get(id, Exchange.fresh(id)))
	market_changed.emit()


## Satış fiyatı çarpanını ayarlar (0.5–2.0).
func set_price_factor(id: String, factor: float) -> void:
	price_factors[id] = clampf(snappedf(factor, 0.05), 0.5, 2.0)
	market_changed.emit()


## Eksik borsa kaydı ve stoğun son kullanma günlerini tamamlar (eski kayıtlar için).
func _ensure_market() -> void:
	for id in Items.PRODUCTS:
		if not market.has(id):
			market[id] = Exchange.fresh(id)
		if not batches.has(id):
			batches[id] = []
		var list: Array = batches[id]
		while list.size() < int(stock.get(id, 0)):
			list.append(day + Exchange.SHELF_LIFE.get(id, 3))
		while list.size() > int(stock.get(id, 0)):
			list.pop_back()
		list.sort()


func add_prepared(id: String, quality: int) -> void:
	prepared[id].append(quality)
	prepared_changed.emit()


## Siparişe bir ürün verir ve kalitesini döndürür. Pişmeyen ürünler stoktan düşer.
func take_for_order(id: String) -> int:
	if prepared.has(id):
		var quality: int = prepared[id].pop_front()
		prepared_changed.emit()
		return quality
	# Pişirilmeyen ürün (kola) doğrudan stoktan gelir; tarihi geçmişse bozuktur.
	return 1 if take_stock_item(id) == 1 else 5


func add_review(stars: int, text: String, customer_name: String) -> void:
	if stars == 5:
		quest_event("five_star")
	reviews.push_front({ "stars": stars, "text": text, "name": customer_name })
	if reviews.size() > MAX_REVIEWS:
		reviews.pop_back()
	reviews_changed.emit()


func show_toast(text: String) -> void:
	toast_requested.emit(text)
