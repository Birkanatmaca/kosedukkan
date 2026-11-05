class_name Quests
extends RefCounted

## Günlük görevler: her gün başında 3 görev çıkar (biri mutfak görevi). Görev
## tamamlanınca ödülü (para + XP) Görevler panelinden alınır; üçü de alınınca
## "günün sandığı" bonusu gelir. Gün biterken alınmamış ama tamamlanmış görevlerin
## ödülü kendiliğinden kasaya girer. İlerleme GameState.quest_event ile sayılır.

const DAILY_COUNT := 3

## Görev türleri.
## kitchen: mutfak görevi (her gün bir tane garanti), max: ilerleme toplanmaz,
## en yüksek değer tutulur (seri gibi), need: görevin çıkması için şart.
const KINDS := {
	"serve": { "icon": "smile", "text": "%d müşteriye servis yap", "reward": 1.0 },
	"revenue": { "icon": "coins", "text": "Satıştan ₺%d kazan", "reward": 1.0 },
	"tips": { "icon": "heart", "text": "₺%d bahşiş topla", "reward": 1.2 },
	"five_star": { "icon": "star", "text": "%d tane 5 yıldızlı yorum al", "reward": 1.3 },
	"sell": { "icon": "utensils", "text": "%d adet %s sat", "reward": 1.0 },
	"clean": { "icon": "spray-can", "text": "%d masayı kendin temizle", "reward": 0.8 },
	"delivery": { "icon": "package", "text": "%d paket siparişi teslim et", "reward": 1.2, "need": "courier" },
	"bullseye": { "icon": "flame", "text": "%d kez TAM KIVAM yakala", "reward": 1.2, "kitchen": true },
	"streak": { "icon": "zap", "text": "Art arda %d TAM KIVAM yakala", "reward": 1.5, "kitchen": true, "max": true, "need": "level2" },
}


## Günün görevlerini üretir. Aynı gün aynı dükkan için hep aynı görevler çıkar
## (kayıt silinip yüklense de değişmez).
static func generate(day: int, level: int, menu: Array[String], has_courier: bool, seed_text: String) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [seed_text, day])
	var kitchen: Array[String] = []
	var others: Array[String] = []
	for kind in KINDS:
		if not _allowed(kind, level, menu, has_courier):
			continue
		if KINDS[kind].get("kitchen", false):
			kitchen.append(kind)
		else:
			others.append(kind)
	var picked: Array[String] = []
	if not kitchen.is_empty():
		picked.append(kitchen[rng.randi() % kitchen.size()])
	while picked.size() < DAILY_COUNT and not others.is_empty():
		picked.append(others.pop_at(rng.randi() % others.size()))
	var list: Array[Dictionary] = []
	for kind in picked:
		list.append(_make(kind, level, menu, rng))
	return list


static func _allowed(kind: String, level: int, menu: Array[String], has_courier: bool) -> bool:
	match KINDS[kind].get("need", ""):
		"courier": return has_courier
		"level2": return level >= 2
	if kind == "sell":
		return not menu.is_empty()
	return true


## Hedef seviyeyle büyür; ödül hedefin zorluğuna göre.
static func _make(kind: String, level: int, menu: Array[String], rng: RandomNumberGenerator) -> Dictionary:
	var target := 1
	var item := ""
	match kind:
		"serve": target = mini(5 + level, 25)
		"revenue": target = mini(snappedi(60 + level * 25, 10), 600)
		"tips": target = mini(snappedi(8 + level * 4, 2), 80)
		"five_star": target = mini(2 + level / 3, 8)
		"clean": target = mini(3 + level / 4, 8)
		"delivery": target = mini(2 + level / 4, 8)
		"bullseye": target = mini(3 + level / 3, 10)
		"streak": target = mini(3 + level / 5, 6)
		"sell":
			item = menu[rng.randi() % menu.size()]
			target = mini(3 + level / 2, 12)
	var factor: float = KINDS[kind]["reward"]
	return {
		"kind": kind, "item": item, "target": target, "progress": 0, "claimed": false,
		"money": snappedi(roundi((15 + 6 * level) * factor), 5),
		"xp": roundi((10 + 4 * level) * factor),
	}


## Üç görevin hepsi alınınca gelen sandık bonusu.
static func bonus(level: int) -> Dictionary:
	return { "money": 25 + 10 * level, "xp": 20 + 6 * level }


static func title(quest: Dictionary) -> String:
	var text: String = KINDS[quest["kind"]]["text"]
	if quest["kind"] == "sell":
		return text % [quest["target"], Items.display_name(quest["item"])]
	return text % quest["target"]


static func icon(quest: Dictionary) -> String:
	return KINDS[quest["kind"]]["icon"]


static func done(quest: Dictionary) -> bool:
	return int(quest["progress"]) >= int(quest["target"])


## Olayı göreve işler; görev bu olayla tamamlandıysa true döner.
static func apply(quest: Dictionary, kind: String, amount: int, item: String) -> bool:
	if quest["kind"] != kind or done(quest):
		return false
	if kind == "sell" and quest["item"] != item:
		return false
	if KINDS[kind].get("max", false):
		quest["progress"] = maxi(int(quest["progress"]), amount)
	else:
		quest["progress"] = int(quest["progress"]) + amount
	quest["progress"] = mini(int(quest["progress"]), int(quest["target"]))
	return done(quest)
