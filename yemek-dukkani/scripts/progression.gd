class_name Progression
extends RefCounted

## Oyun dengesi tek yerde: seviyeye göre zorluk, deneyim (XP) ve geliştirmeler.
## Rakamlar değiştirilerek oyunun zorluğu ayarlanır.
##
## Zorluk eğrisi (seviye 1 → 10):
##   müşteri aralığı  15 sn → ~7 sn (seviye 14+ için 3.5 sn)
##   temel sabır      60 sn → 33 sn (+ ürün başına 10 sn)
##   en uzun sıra     2 → 7 kişi
##   sipariş          tek ürün → 3 çeşit, bazen 2'şer adet

const MAX_LEVEL := 30

## Geliştirmeler. costs[i] ve levels[i]: i. kademenin fiyatı ve gereken seviye.
## device: sadece o cihaz menüdeyse görünür.
const UPGRADES := {
	"grill_slot": { "name": "Ekstra Izgara Yeri", "icon": "flame", "desc": "Izgaraya +1 pişirme yeri", "costs": [270, 540, 960, 1440, 2040, 2700], "levels": [2, 4, 6, 8, 10, 12], "device": "izgara" },
	"fryer_slot": { "name": "Ekstra Fritöz Sepeti", "icon": "cooking-pot", "desc": "Fritöze +1 sepet", "costs": [240, 600], "levels": [3, 6], "device": "fritoz" },
	"oven_slot": { "name": "Ekstra Fırın Yeri", "icon": "flame", "desc": "Fırına +1 pişirme yeri", "costs": [480, 960], "levels": [4, 7], "device": "firin" },
	"grill_speed": { "name": "Güçlü Izgara", "icon": "zap", "desc": "Izgara %15 daha hızlı pişirir", "costs": [210, 450, 840], "levels": [2, 4, 7], "device": "izgara" },
	"fryer_speed": { "name": "Güçlü Fritöz", "icon": "trending-up", "desc": "Fritöz %15 daha hızlı pişirir", "costs": [180, 420, 780], "levels": [3, 5, 8], "device": "fritoz" },
	"tables": { "name": "Yeni Masalar", "icon": "armchair", "desc": "Salona +2 masa", "costs": [360], "levels": [3] },
	"comfort": { "name": "Müzik ve Dekor", "icon": "music", "desc": "Müşteriler %12 daha sabırlı", "costs": [180, 390, 750], "levels": [2, 5, 8] },
	"register2": { "name": "Ek Kasa", "icon": "receipt", "desc": "İkinci kasa: kasiyer tutunca sıra ikiye bölünür", "costs": [750], "levels": [3] },
	# Genişletmeler (EXPANSIONS): dükkan büyür, masa ve müşteri artar, kira da artar.
	"terrace": { "name": "Çatı Terası", "icon": "sun", "desc": "İçeride döner merdiven, çatıda korkuluklu teras. Masa ve süsleri Dekor'dan koy", "costs": [3600], "levels": [5], "rent": 50 },
	# Komşu birleştirme (Mahalle'de bitişik komşu alınıp duvar yıkılınca verilir; satılmaz).
	"annex": { "name": "Sol Salon", "icon": "store", "desc": "Soldaki komşu dükkan salona katıldı", "costs": [0], "levels": [1], "rent": 70, "hidden": true },
	"annex_r": { "name": "Sağ Salon", "icon": "store", "desc": "Sağdaki komşu dükkan salona katıldı", "costs": [0], "levels": [1], "rent": 70, "hidden": true },
}
## Komşu birleştirmeleri (salon büyür, kira artar)
const EXPANSIONS := ["annex", "annex_r", "terrace"]
## Her genişletme içeride aynı anda bulunabilecek müşteriyi artırır, geliş aralığını kısaltır.
const EXPANSION_CUSTOMERS := 2
const EXPANSION_SPAWN := 0.88

## Günlük sabit giderler (gün sonunda maaşlardan sonra ödenir).
const RENT_BASE := 40
const RENT_PER_LEVEL := 10
## Faturalar: menüdeki her pişirme cihazı ve her ek pişirme yeri için.
const BILL_PER_DEVICE := 12
const BILL_PER_SLOT := 5
const BILL_REGISTER2 := 15

const BASE_GRILL_SLOTS := 3
const BASE_FRYER_SLOTS := 2
const BASE_OVEN_SLOTS := 2
const BASE_TABLES := 4

## Menü: başlangıçta en az MENU_MIN_FOOD, en fazla START_FOOD_SLOTS yemek ve en az
## MENU_MIN_DRINK içecek seçilir. FOOD_SLOT_LEVELS'teki her seviyede +1 yemek yeri açılır.
const MENU_MIN_FOOD := 2
const MENU_MIN_DRINK := 1
const START_FOOD_SLOTS := 4
const FOOD_SLOT_LEVELS := [4, 7, 10]


## Menüdeki yer sayısı: kind "food" ya da "drink".
static func menu_slots(kind: String, level: int) -> int:
	if kind == "drink":
		# İçecek az: hepsi menüye alınabilir.
		return Items.PRODUCTS.keys().filter(func(id: String) -> bool: return not Items.is_food(id)).size()
	var slots := START_FOOD_SLOTS
	for at in FOOD_SLOT_LEVELS:
		if level >= at:
			slots += 1
	return slots


## Bir sonraki yemek yerinin açıldığı seviye (yoksa -1).
static func next_food_slot_level(level: int) -> int:
	for at in FOOD_SLOT_LEVELS:
		if level < at:
			return at
	return -1



## Sonraki seviye için gereken XP. Satış başına ~15–35 XP kazanılır:
## seviye 2 için ~3 satış, seviye 5 için ~10, seviye 10 için ~35 satış.
static func xp_needed(level: int) -> int:
	return 50 + 30 * (level - 1) + 8 * (level - 1) * (level - 1)


## Sakin başlangıç: ilk garson işe alınana kadar müşteriler seyrek gelir,
## sıra oluşmaz, içeride en fazla CALM_MAX_CUSTOMERS kişi olur, siparişler
## tek ürünlüdür ve sabır daha uzundur. Oyuncu masaları kendisi temizlerken
## yığılma olmasın diye; garson gelince normal tempo başlar.
const CALM_SPAWN_FACTOR := 2.0
const CALM_PATIENCE_FACTOR := 1.4
const CALM_MAX_CUSTOMERS := 3


## Alınmış genişletme sayısı.
static func expansions() -> int:
	var n := 0
	for id in EXPANSIONS:
		n += GameState.upgrade_level(id)
	return n


## Günün kira ve faturası: { rent, bills }
static func daily_costs() -> Dictionary:
	var rent := RENT_BASE + RENT_PER_LEVEL * (GameState.level - 1)
	for id in EXPANSIONS:
		if GameState.upgrade_level(id) > 0:
			rent += int(UPGRADES[id]["rent"])
	var bills := BILL_PER_DEVICE * GameState.menu_devices().size()
	for id in ["grill_slot", "fryer_slot", "oven_slot"]:
		bills += BILL_PER_SLOT * GameState.upgrade_level(id)
	if GameState.upgrade_level("register2") > 0:
		bills += BILL_REGISTER2
	return { "rent": rent, "bills": bills }


static func calm() -> bool:
	return GameState.staff.is_empty()


## İçeride aynı anda bulunabilecek en fazla müşteri. Sakin dönemde 3,
## sonra seviyeyle kademeli artar: Sv1 5, Sv5 7, Sv10 10, en fazla 14.
static func max_customers(level: int) -> int:
	if calm():
		return CALM_MAX_CUSTOMERS
	return mini(5 + (level - 1) / 2 + maxi(level - 8, 0), 14) + EXPANSION_CUSTOMERS * expansions()


## Aynı anda açık olabilecek en fazla sipariş (mutfakta hazırlanan + teslim
## bekleyen). Teslim alanında 6 yer var; seviye düşükken daha az sipariş açılır
## ki oyuncu boğulmasın: sakin 2, Sv1–2 3, Sv3–4 4, Sv5–7 5, Sv8+ 6.
static func max_orders(level: int) -> int:
	if calm():
		return 2
	if level >= 8:
		return 6
	if level >= 5:
		return 5
	if level >= 3:
		return 4
	return 3


## Siparişini paket alıp masaya oturmadan çıkan müşteri oranı. Masa sayısı
## sınırlı olduğu için yoğunluk arttıkça paket servis artar: sakin dönemde 0,
## Sv3 %15, Sv9 %40.
static func takeaway_chance(level: int) -> float:
	if calm() or level < 3:
		return 0.0
	return minf(0.15 + 0.042 * (level - 3), 0.4)


## Sipariş verdikten sonra yemeğini bekleme sabrı (saniye): ürün başına süre
## eklenir, seviyeyle biraz kısalır. Dolarsa para iade edilir, kötü yorum gelir.
static func food_patience(level: int, item_count: int) -> float:
	var base := maxf(70.0, 100.0 - 2.0 * (level - 1)) + 18.0 * item_count
	if calm():
		base *= CALM_PATIENCE_FACTOR
	return base


## Paket servis telefonu ne sıklıkla çalar (saniye). Kurye sayısı arttıkça sıklaşır;
## kuryelerin yükü (yoldaki ve bekleyen paketlerin taşıma kapasitesine oranı)
## arttıkça seyrekleşir, kapasite dolunca hiç çalmaz.
static func delivery_interval(level: int, couriers: int, load: float) -> float:
	var base := maxf(14.0, 32.0 - 1.6 * (level - 1)) / maxf(couriers, 1)
	if calm():
		base *= CALM_SPAWN_FACTOR
	return base * (1.0 + 3.0 * load * load) * lerpf(1.4, 0.8, clampf((GameState.rating() - 1.0) / 4.0, 0.0, 1.0)) * price_demand()


## Paket siparişin hazırlanıp kuryeye verilme süresi (saniye).
static func delivery_patience(level: int, item_count: int) -> float:
	return food_patience(level, item_count) * 1.4 + 20.0


## Paket sipariş: normal siparişten biraz büyük (aile, ofis), arada ikinci içecek.
static func delivery_order(level: int) -> Dictionary:
	var order := random_order(level)
	var foods: Array = order.keys().filter(func(id: String) -> bool: return Items.PRODUCTS[id]["device"] != "")
	if not foods.is_empty() and randf() < 0.6:
		var id: String = foods.pick_random()
		order[id] = int(order[id]) + 1
	return order


## Yeni müşteri gelme aralığı (saniye). İyi puan müşteriyi sıklaştırır.
static func spawn_interval(level: int, rating: float) -> float:
	var base := maxf(5.0, 18.0 - 0.8 * (level - 1)) * pow(EXPANSION_SPAWN, expansions())
	if calm():
		base *= CALM_SPAWN_FACTOR
	return base * lerpf(1.4, 0.8, clampf((rating - 1.0) / 4.0, 0.0, 1.0)) * price_demand()


static func patience(level: int, item_count: int, comfort_level: int) -> float:
	var base := maxf(45.0, 80.0 - 2.5 * (level - 1)) + 14.0 * item_count
	if calm():
		base *= CALM_PATIENCE_FACTOR
	# Bahçe teras: açık havada beklemek daha keyifli (+%10 sabır)
	# Ön bahçe: dışarıda beklemek daha keyifli (+%8 sabır)
	return base * (1.0 + 0.12 * comfort_level) * (1.08 if int(GameState.decor.get("patio_floor", 0)) > 0 else 1.0)


## Kasadaki tek yerin arkasında sırada bekleyebilecek en fazla kişi
## (sakin dönemde bir kişi).
static func max_queue(level: int) -> int:
	return 1 if calm() else mini(3 + level / 2, 7)


## Müşterinin ödemeye razı olduğu fiyat oranı: puan ve dekor arttıkça yükselir.
## 1.0 = menüdeki taban fiyat. Örn. 4.5 yıldız ve iyi dekorla ~1.25.
static func price_tolerance() -> float:
	var decor := 0
	for key in ["clean", "register", "paint", "windows", "lamps", "sign"]:
		if GameState.decor.get(key, false):
			decor += 1
	decor += int(GameState.decor.get("plants", 0))
	decor += Decor.style_points(GameState.decor)
	return clampf(1.0 + 0.12 * (GameState.rating() - 3.5) + 0.015 * decor, 0.8, 1.5)


## Ürünün fiyatının müşteriye göre ne kadar pahalı geldiği (1 = makul).
static func price_ratio(id: String) -> float:
	return float(GameState.price_factors.get(id, 1.0)) / price_tolerance()


## Menü pahalıysa müşteriler seyrek gelir, ucuzsa sık: müşteri geliş aralığı çarpanı.
static func price_demand() -> float:
	var total := 0.0
	var ids := Items.unlocked_ids()
	for id in ids:
		total += price_ratio(id)
	return clampf(pow(total / maxf(ids.size(), 1.0), 1.8), 0.55, 3.0)


static func random_order(level: int) -> Dictionary:
	var foods: Array = []
	for id in Items.unlocked_ids():
		if Items.PRODUCTS[id]["device"] != "":
			foods.append(id)
	var drinks := Items.unlocked_ids("")
	# Pahalı ürün daha az seçilir: ağırlıklı karıştırma (ucuz olan öne geçer).
	var keys := {}
	for id in foods:
		keys[id] = -log(maxf(randf(), 0.0001)) * pow(price_ratio(id), 2.0)
	foods.sort_custom(func(a: String, b: String) -> bool: return keys[a] < keys[b])
	var kinds := 1
	if calm():
		# Sakin dönemde tek ürün, bazen yanında kola.
		var simple := { foods[0]: 1 }
		var drink := _pick_drink(drinks)
		if randf() < 0.3 / pow(price_ratio(drink), 1.5):
			simple[drink] = 1
		return simple
	if level >= 6:
		kinds = randi_range(1, 3)
	elif level >= 3:
		kinds = randi_range(1, 2)
	var order := {}
	for i in mini(kinds, foods.size()):
		order[foods[i]] = 2 if level >= 5 and randf() < 0.25 else 1
	var drink := _pick_drink(drinks)
	if randf() < (0.3 + 0.03 * level) / pow(price_ratio(drink), 1.5):
		order[drink] = 1
	return order


## İçeceklerden biri: ucuz olan daha çok seçilir.
static func _pick_drink(drinks: Array[String]) -> String:
	var best := drinks[0]
	var best_key := INF
	for id in drinks:
		var key := -log(maxf(randf(), 0.0001)) * pow(price_ratio(id), 2.0)
		if key < best_key:
			best_key = key
			best = id
	return best


static func sale_xp(item_count: int, stars: int) -> int:
	return 10 * item_count + (5 if stars == 5 else 0)


static func upgrade_max(id: String) -> int:
	return UPGRADES[id]["costs"].size()


## Bir sonraki kademenin fiyatı; maksimumdaysa -1.
static func upgrade_cost(id: String, current: int) -> int:
	var costs: Array = UPGRADES[id]["costs"]
	return costs[current] if current < costs.size() else -1


static func upgrade_required_level(id: String, current: int) -> int:
	var levels: Array = UPGRADES[id]["levels"]
	return levels[current] if current < levels.size() else -1


## Bu seviyeye gelince açılan geliştirmelerin adları (seviye atlama bildirimi için).
static func unlocks_at(level: int) -> Array[String]:
	var names: Array[String] = []
	for id in UPGRADES:
		if not UPGRADES[id].get("hidden", false) and (UPGRADES[id]["levels"] as Array).has(level):
			names.append(UPGRADES[id]["name"])
	return names
