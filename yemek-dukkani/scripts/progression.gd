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
const UPGRADES := {
	"grill_slot": { "name": "Ekstra Izgara Yeri", "icon": "flame", "desc": "Izgaraya +1 pişirme yeri", "costs": [90, 180, 320], "levels": [2, 4, 6] },
	"fryer_slot": { "name": "Ekstra Fritöz Sepeti", "icon": "cooking-pot", "desc": "Fritöze +1 sepet", "costs": [80, 200], "levels": [3, 6] },
	"grill_speed": { "name": "Güçlü Izgara", "icon": "zap", "desc": "Izgara %15 daha hızlı pişirir", "costs": [70, 150, 280], "levels": [2, 4, 7] },
	"fryer_speed": { "name": "Güçlü Fritöz", "icon": "trending-up", "desc": "Fritöz %15 daha hızlı pişirir", "costs": [60, 140, 260], "levels": [3, 5, 8] },
	"tables": { "name": "Yeni Masalar", "icon": "armchair", "desc": "Salona +2 masa", "costs": [120], "levels": [3] },
	"comfort": { "name": "Müzik ve Dekor", "icon": "music", "desc": "Müşteriler %12 daha sabırlı", "costs": [60, 130, 250], "levels": [2, 5, 8] },
}

const BASE_GRILL_SLOTS := 3
const BASE_FRYER_SLOTS := 2
const BASE_TABLES := 4


## Sonraki seviye için gereken XP. Satış başına ~15–35 XP kazanılır:
## seviye 2 için ~3 satış, seviye 5 için ~10, seviye 10 için ~35 satış.
static func xp_needed(level: int) -> int:
	return 50 + 30 * (level - 1) + 8 * (level - 1) * (level - 1)


## Yeni müşteri gelme aralığı (saniye). İyi puan müşteriyi sıklaştırır.
static func spawn_interval(level: int, rating: float) -> float:
	var base := maxf(3.5, 15.0 - 0.9 * (level - 1))
	return base * lerpf(1.4, 0.8, clampf((rating - 1.0) / 4.0, 0.0, 1.0))


static func patience(level: int, item_count: int, comfort_level: int) -> float:
	var base := maxf(30.0, 60.0 - 3.0 * (level - 1)) + 10.0 * item_count
	return base * (1.0 + 0.12 * comfort_level)


## Kasadaki 3 yerin arkasında bekleyebilecek en fazla kişi.
static func max_queue(level: int) -> int:
	return mini(2 + level / 2, 7)


static func random_order(level: int) -> Dictionary:
	var foods: Array = ["tavuk", "kofte", "patates"]
	foods.shuffle()
	var kinds := 1
	if level >= 6:
		kinds = randi_range(1, 3)
	elif level >= 3:
		kinds = randi_range(1, 2)
	var order := {}
	for i in kinds:
		order[foods[i]] = 2 if level >= 5 and randf() < 0.25 else 1
	if randf() < 0.3 + 0.03 * level:
		order["kola"] = 1
	return order


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
		if (UPGRADES[id]["levels"] as Array).has(level):
			names.append(UPGRADES[id]["name"])
	return names
