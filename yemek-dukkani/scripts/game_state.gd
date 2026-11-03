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
## İşe alınmış personel ve günün adayları
var staff: Array[Dictionary] = []
var candidates: Array[Dictionary] = []

## Başlangıç kurulumu: dükkan adı ve dekor. Kurulum bitene kadar müşteri gelmez.
var shop_name := DEFAULT_SHOP_NAME
var setup_done := false
var decor := Decor.default_state()
## Tanıtım adımı; -1 ise tanıtım yok / bitti.
var tutorial_step := -1


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


func finish_setup() -> void:
	if not Decor.missing(decor).is_empty():
		return
	setup_done = true
	tutorial_step = 0
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
		"tutorial_step": tutorial_step,
	}


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
	shop_name = str(data.get("shop_name", shop_name))
	setup_done = bool(data.get("setup_done", setup_done))
	decor = _merge(Decor.default_state(), data.get("decor", {}), true)
	tutorial_step = int(data.get("tutorial_step", -1))
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
	decor = { "clean": true, "register": true, "paint": true, "windows": true, "lamps": true, "sign": true,
		"paint_color": 0, "floor": 2, "tables": 4, "plants": 2 }
	setup_done = true
	tutorial_step = -1
	decor_changed.emit()
	setup_finished.emit()

var money := Decor.START_BUDGET:
	set(value):
		money = value
		money_changed.emit(money)

## Çiğ malzeme ve hazır içecek stoğu.
var stock := { "tavuk": 3, "tavuk_sis": 3, "kofte": 3, "patates": 3, "kola": 5 }
## Pişmiş, servise hazır ürünler: ürün -> kalite listesi (5 tam, 3 fazla, 2 az pişmiş).
var prepared := { "tavuk": [], "tavuk_sis": [], "kofte": [], "patates": [] }
var reviews: Array[Dictionary] = []
var level := 1
var xp := 0
## Geliştirme kademeleri: id -> alınan kademe sayısı
var upgrades := {}


func _ready() -> void:
	candidates = Staff.make_candidates(3, staff)
	_reset_stats()


func _process(delta: float) -> void:
	# Kurulum ve tanıtım sırasında saat ilerlemez.
	if setup_done and not tutorial_active() and is_open and minutes < CLOSE_TIME:
		var before := minutes
		minutes = minf(minutes + delta * (CLOSE_TIME - OPEN_TIME) / DAY_SECONDS, CLOSE_TIME)
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
	var quitters: Array[String] = []
	for person in staff.duplicate():
		var wage: int = person["wage"]
		if money >= wage:
			money -= wage
			day_stats["wages"] += wage
		else:
			staff.erase(person)
			quitters.append(person["name"])
	day_stats["quitters"] = quitters
	day_stats["money"] = money
	if not quitters.is_empty():
		staff_changed.emit()
	day_ended.emit(day_stats)


func start_day() -> void:
	day += 1
	minutes = OPEN_TIME
	is_open = true
	candidates = Staff.make_candidates(3, staff)
	_reset_stats()
	staff_changed.emit()
	day_started.emit(day)


func record_sale(amount: int, tip: int) -> void:
	day_stats["revenue"] += amount
	day_stats["tips"] += tip
	day_stats["served"] += 1


func record_tip(tip: int) -> void:
	day_stats["tips"] += tip


## Masa bulamayan ya da siparişi gecikene para iadesi: satış geri alınır.
func record_refund(amount: int) -> void:
	day_stats["revenue"] -= amount
	day_stats["served"] -= 1


func record_lost_customer() -> void:
	day_stats["lost"] += 1


func hire(index: int) -> bool:
	if staff.size() >= Staff.MAX_STAFF:
		show_toast("En fazla %d çalışan alabilirsin" % Staff.MAX_STAFF)
		return false
	staff.append(candidates[index])
	candidates.remove_at(index)
	staff_changed.emit()
	return true


func fire(index: int) -> void:
	staff.remove_at(index)
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
	day_stats = { "revenue": 0, "tips": 0, "supplies": 0, "upgrades": 0, "wages": 0, "served": 0, "lost": 0 }


func add_xp(amount: int) -> void:
	xp += amount
	while level < Progression.MAX_LEVEL and xp >= Progression.xp_needed(level):
		xp -= Progression.xp_needed(level)
		level += 1
		level_up.emit(level)
	xp_changed.emit()


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


func buy_pack(id: String) -> bool:
	var cost: int = Items.PRODUCTS[id]["pack_price"]
	if money < cost:
		return false
	money -= cost
	day_stats["supplies"] += cost
	stock[id] += Items.PACK_SIZE
	stock_changed.emit()
	return true


func take_stock(id: String) -> bool:
	if stock[id] <= 0:
		return false
	stock[id] -= 1
	stock_changed.emit()
	return true


func add_prepared(id: String, quality: int) -> void:
	prepared[id].append(quality)
	prepared_changed.emit()


## Siparişe bir ürün verir ve kalitesini döndürür. Pişmeyen ürünler stoktan düşer.
func take_for_order(id: String) -> int:
	if prepared.has(id):
		var quality: int = prepared[id].pop_front()
		prepared_changed.emit()
		return quality
	stock[id] -= 1
	stock_changed.emit()
	return 5


func add_review(stars: int, text: String, customer_name: String) -> void:
	reviews.push_front({ "stars": stars, "text": text, "name": customer_name })
	if reviews.size() > MAX_REVIEWS:
		reviews.pop_back()
	reviews_changed.emit()


func show_toast(text: String) -> void:
	toast_requested.emit(text)
