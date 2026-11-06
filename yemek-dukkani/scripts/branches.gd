class_name Branches
extends RefCounted

## Şubeler: mahallede satın alınabilen dükkanlar (Neighborhood'da yürüyüp bakılır).
##
## Her dükkanın kendi adı, dekoru, menüsü, geliştirmeleri, personeli ve stoğu
## vardır (SHOP_KEYS); para, seviye, gün ve görevler bütün dükkanlar için ortaktır.
## Oyuncu aynı anda tek dükkanda oynar (GameState'teki alanlar onundur). Diğer
## dükkanlar gün sonunda kendi kasiyer ve aşçısıyla çalışır (simulate_day):
## kasiyer ve aşçısı olmayan şube kapalı kalır ama kirası yine ödenir.

## Dükkana ait alanlar (GameState.to_dict anahtarları)
const SHOP_KEYS := ["shop_name", "decor", "menu", "upgrades", "staff", "candidates", "stock", "batches",
	"prepared", "reviews", "price_factors", "player_register_closed"]

## Mahalledeki dükkan yerleri. 0 ilk dükkan (oyunun başındaki), diğerleri satılık.
## x: sokakta dükkanın ortası (Shop koordinatında). demand: müşteri yoğunluğu.
const LOTS := [
	{ "name": "Köşe", "x": 0.0 },
	{ "name": "Fırın Sokağı", "x": -17.0, "price": 6000, "level": 5, "demand": 1.0, "rent": 70,
		"desc": "Sakin ama sadık müşterili bir köşe. İlk şube için ideal.", "color": Color("#e8c9a0") },
	{ "name": "Okul Önü", "x": 17.0, "price": 11000, "level": 8, "demand": 1.2, "rent": 100,
		"desc": "Öğrenciler hiç eksik olmaz: kalabalık, siparişler küçük.", "color": Color("#a9c4c9") },
	{ "name": "Çarşı Başı", "x": -25.5, "price": 18000, "level": 11, "demand": 1.45, "rent": 140,
		"desc": "Mahallenin en işlek yeri. Pahalı ama çok kazandırır.", "color": Color("#d9b3b3") },
]
## Bir şubenin kendi başına bir günde (kasiyer ve aşçıyla) servis ettiği ortalama müşteri
const BRANCH_SALES := 34
## Stok bitince müdür malzemeyi toptancıdan bu kadar pahalıya getirtir.
const RESTOCK_MARKUP := 1.25


## Dükkan yerinin sahibi olan dükkanın GameState.shops içindeki sırası (yoksa -1).
static func shop_at(lot: int) -> int:
	for i in GameState.shops.size():
		if int(GameState.shops[i]["lot"]) == lot:
			return i
	return -1


static func owned(lot: int) -> bool:
	return lot == 0 or shop_at(lot) != -1


## Oyuncunun şu an içinde olduğu dükkanın yeri
static func active_lot() -> int:
	if GameState.shops.is_empty():
		return 0
	return int(GameState.shops[GameState.active_shop]["lot"])


## Sokakta bu yerde görünen dükkanın adı. Oyuncu hep "buradaki" binada oynar;
## bir şubedeyken o şubenin yerinde ilk dükkan görünür (yerler yer değiştirir).
static func name_at(lot: int) -> String:
	var shown := shown_lot(lot)
	var index := shop_at(shown)
	if index == -1:
		return GameState.shop_name if shown == 0 else ""
	if index == GameState.active_shop:
		return GameState.shop_name
	return str(GameState.shops[index]["data"].get("shop_name", ""))


## Sokakta bu yerdeki binanın gerçek yeri (name_at ile aynı yer değiştirme).
static func shown_lot(lot: int) -> int:
	if lot == active_lot():
		return 0
	if lot == 0:
		return active_lot()
	return lot


## Yeni şube: kurulmuş, temiz, 4 masalı; menüsü oynanan dükkanınkiyle aynı.
static func new_shop(lot: int) -> Dictionary:
	var decor := Decor.default_state()
	for key in ["clean", "register", "paint", "windows", "lamps", "sign"]:
		decor[key] = true
	decor["paint_color"] = (lot * 3) % Decor.WALL_COLORS.size()
	decor["floor"] = 2
	decor["tables"] = 4
	decor["plants"] = 2
	var stock := {}
	var batches := {}
	var prepared := {}
	for id in Items.PRODUCTS:
		stock[id] = 0
		batches[id] = []
		if Items.PRODUCTS[id]["device"] != "":
			prepared[id] = []
	# İlk dükkanın menüsüyle açılır (cihazları hazır gelir).
	var menu: Array = GameState.menu.duplicate() if not GameState.menu.is_empty() else ["kofte", "patates", "kola"]
	for id in menu:
		stock[id] = 10
		for i in 10:
			batches[id].append(GameState.day + 4)
	return {
		"shop_name": "%s %s" % [GameState.DEFAULT_SHOP_NAME, LOTS[lot]["name"]],
		"decor": decor, "menu": menu, "upgrades": {}, "staff": [],
		"candidates": Staff.make_candidates(3, [], GameState.level), "stock": stock, "batches": batches,
		"prepared": prepared, "reviews": [], "price_factors": {}, "player_register_closed": false,
	}


## Şube kendi başına çalışabiliyor mu (kasiyer ve aşçı)?
static func can_run(data: Dictionary) -> bool:
	var roles: Array = (data.get("staff", []) as Array).map(func(p: Dictionary) -> String: return Staff.role(p))
	return roles.has("kasiyer") and roles.has("asci")


## Şubenin günlük kira ve faturası
static func daily_costs(lot: int, data: Dictionary) -> int:
	var cost: int = LOTS[lot]["rent"]
	var devices := {}
	for id in data.get("menu", []):
		var device: String = Items.PRODUCTS[id]["device"]
		if device != "":
			devices[device] = true
	cost += Progression.BILL_PER_DEVICE * devices.size()
	var upgrades: Dictionary = data.get("upgrades", {})
	for id in Progression.EXPANSIONS:
		if int(upgrades.get(id, 0)) > 0:
			cost += int(Progression.UPGRADES[id]["rent"])
	return cost


## Kapalı (oynanmayan) şubenin bir günü: satışlar stoktan düşer, stok bitince
## malzeme toptancıdan getirtilir; maaş ve kira ödenir.
## Rapor döner: { lot, name, open, served, revenue, supplies, wages, rent, net, quitters }
static func simulate_day(shop: Dictionary) -> Dictionary:
	var lot: int = shop["lot"]
	var data: Dictionary = shop["data"]
	var report := { "lot": lot, "name": data.get("shop_name", ""), "open": can_run(data), "served": 0,
		"revenue": 0, "supplies": 0, "wages": 0, "rent": 0, "net": 0, "quitters": [] }
	var stock: Dictionary = data["stock"]
	if report["open"]:
		var speed := 0
		for person in data["staff"]:
			if Staff.role(person) in ["kasiyer", "asci"]:
				speed += int(person["speed"])
		var upgrades: Dictionary = data.get("upgrades", {})
		var expansions := 0
		for id in Progression.EXPANSIONS:
			expansions += int(upgrades.get(id, 0))
		var sales := roundi(BRANCH_SALES * float(LOTS[lot]["demand"]) * (0.75 + 0.12 * speed)
			* (1.0 + 0.2 * expansions) * randf_range(0.85, 1.15))
		var menu: Array = data["menu"]
		var foods: Array = menu.filter(func(id: String) -> bool: return Items.is_food(id))
		var drinks: Array = menu.filter(func(id: String) -> bool: return not Items.is_food(id))
		for i in sales:
			# Müşterinin fişi: 1–3 çeşit yemek (seviyeyle büyür), çoğu zaman yanında içecek.
			var ticket: Array = []
			foods.shuffle()
			var kinds := 1
			if GameState.level >= 3 and randf() < 0.5:
				kinds += 1
			if GameState.level >= 6 and randf() < 0.35:
				kinds += 1
			for k in mini(kinds, foods.size()):
				ticket.append(foods[k])
				if GameState.level >= 5 and randf() < 0.25:
					ticket.append(foods[k])
			if not drinks.is_empty() and randf() < 0.55:
				ticket.append(drinks.pick_random())
			if ticket.is_empty():
				continue
			for id in ticket:
				report["revenue"] += roundi(float(Items.PRODUCTS[id]["price"]) * float(data["price_factors"].get(id, 1.0)))
				# Stokta varsa ondan, yoksa müdür toptancıdan getirtir (biraz pahalıya).
				if int(stock.get(id, 0)) > 0:
					stock[id] = int(stock[id]) - 1
					if not (data["batches"][id] as Array).is_empty():
						(data["batches"][id] as Array).pop_front()
				else:
					report["supplies"] += ceili(GameState.pack_price(id) / float(Items.PACK_SIZE) * RESTOCK_MARKUP)
			report["served"] += 1
	# Maaşlar: para yetmezse çalışan ayrılır.
	var money_left := GameState.money + int(report["revenue"]) - int(report["supplies"])
	for person in (data["staff"] as Array).duplicate():
		var wage: int = person["wage"]
		if money_left >= wage:
			money_left -= wage
			report["wages"] += wage
		else:
			(data["staff"] as Array).erase(person)
			report["quitters"].append(person["name"])
	report["rent"] = mini(daily_costs(lot, data), maxi(money_left, 0))
	report["net"] = int(report["revenue"]) - int(report["supplies"]) - int(report["wages"]) - int(report["rent"])
	return report
