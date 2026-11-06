class_name Branches
extends RefCounted

## Mahalle: dükkanımızın bulunduğu sokak. Sağımızda ve solumuzda bitişik komşu
## dükkanlar, onların yanında birer komşu daha var; her birinde başka bir şirket
## çalışır. Oyuncu seviye atladıkça komşular tek tek kapanıp satılığa çıkar
## (gün sonunda, close_neighbors), ekranda haber çıkar. Amaç: sokağın baştan
## sona bizim olması.
##
## Bitişik komşu alınınca iki seçenek var: duvarı yıkıp salona katmak (birleştir:
## Progression "annex" / "annex_r", +6 masa) ya da ayrı dükkan (şube) açmak.
## Şubenin türü seçilir (pizzacı, tavukçu…); kendi adı, dekoru, menüsü,
## geliştirmeleri, personeli ve stoğu vardır (SHOP_KEYS). Para, seviye, gün ve
## görevler ortaktır. Oyuncu aynı anda tek dükkanda oynar; diğer şubeler gün
## sonunda kendi kasiyer ve aşçısıyla çalışır (simulate_day).

## Dükkana ait alanlar (GameState.to_dict anahtarları)
const SHOP_KEYS := ["shop_name", "decor", "menu", "upgrades", "staff", "candidates", "stock", "batches",
	"prepared", "reviews", "price_factors", "player_register_closed"]

## Sokaktaki dükkan yerleri (12 m genişliğinde, yan yana). 0 bizim ilk dükkanımız.
## x: dükkanın ortası (Shop koordinatında). merge: bitişikse birleştirme geliştirmesi.
## level: komşunun kapanıp satılığa çıkabileceği en düşük seviye. demand: şube olunca
## müşteri yoğunluğu. company/kind/brand: orada çalışan komşu şirket.
const LOTS := [
	{ "name": "Köşe", "x": 0.0 },
	{ "name": "Sol Komşu", "x": -12.0, "merge": "annex", "price": 5000, "level": 4, "demand": 1.0, "rent": 70,
		"company": "Usta Pide Salonu", "kind": "Pideci", "brand": Color("#c0392b"), "color": Color("#e8c9a0"), "theme": "pideci" },
	{ "name": "Sağ Komşu", "x": 12.0, "merge": "annex_r", "price": 7000, "level": 5, "demand": 1.1, "rent": 90,
		"company": "Çıtır Tavuk", "kind": "Tavukçu", "brand": Color("#e67e22"), "color": Color("#a9c4c9"), "theme": "tavukcu" },
	{ "name": "Sokak Başı", "x": -24.0, "price": 11000, "level": 7, "demand": 1.25, "rent": 110,
		"company": "Anadolu Kebap", "kind": "Kebapçı", "brand": Color("#8e44ad"), "color": Color("#d9b3b3"), "theme": "kofteci" },
	{ "name": "Sokak Sonu", "x": 24.0, "price": 15000, "level": 9, "demand": 1.4, "rent": 140,
		"company": "Napoli Pizza", "kind": "Pizzacı", "brand": Color("#27ae60"), "color": Color("#e6dccb"), "theme": "pizzaci" },
]
## Ayrı dükkan açarken seçilen türler: ad eki, menü ve duvar boyası.
const THEMES := {
	"pizzaci": { "name": "Pizzacı", "suffix": "Pizza", "icon": "flame", "menu": ["pizza", "lahmacun", "kola", "ayran"], "paint": 3 },
	"tavukcu": { "name": "Tavukçu", "suffix": "Tavuk", "icon": "drumstick", "menu": ["tavuk", "tavuk_sis", "patates", "ayran", "kola"], "paint": 1 },
	"kofteci": { "name": "Köfteci", "suffix": "Köfte", "icon": "beef", "menu": ["kofte", "patates", "ayran", "kola"], "paint": 5 },
	"pideci": { "name": "Pideci", "suffix": "Pide", "icon": "cooking-pot", "menu": ["pide", "lahmacun", "ayran", "kola"], "paint": 2 },
	"menum": { "name": "Benim Menüm", "suffix": "", "icon": "utensils", "menu": [], "paint": 0 },
}
## Komşunun her gün kapanma ihtimali (seviyesi yettiyse; günde en fazla bir komşu)
const CLOSE_CHANCE := 0.5
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
	return lot == 0 or shop_at(lot) != -1 or merged(lot)


## İlk dükkanın (yer 0) geliştirmeleri (oynanan dükkan o değilse kayıttan).
static func home_upgrades() -> Dictionary:
	var index := shop_at(0)
	if index == -1 or index == GameState.active_shop:
		return GameState.upgrades if active_lot() == 0 else {}
	return GameState.shops[index]["data"].get("upgrades", {})


## Bitişik komşu ilk dükkanın salonuna katıldı mı?
static func merged(lot: int) -> bool:
	var id: String = LOTS[lot].get("merge", "")
	return id != "" and int(home_upgrades().get(id, 0)) > 0


## "owned", "for_sale" ya da "open" (komşu şirket çalışıyor)
static func state(lot: int) -> String:
	if owned(lot):
		return "owned"
	return str(GameState.neighbors.get(str(lot), "open"))


## İlk dükkanın adı
static func home_name() -> String:
	var index := shop_at(0)
	if index == -1 or index == GameState.active_shop:
		return GameState.shop_name if active_lot() == 0 else GameState.DEFAULT_SHOP_NAME
	return str(GameState.shops[index]["data"].get("shop_name", GameState.DEFAULT_SHOP_NAME))


## Gün sonu: seviyesi gelen bir komşu kapanıp satılığa çıkabilir. Döner: kapanan yer ya da -1.
static func close_neighbors() -> int:
	for lot in range(1, LOTS.size()):
		if state(lot) == "open" and GameState.level >= int(LOTS[lot]["level"]) and randf() < CLOSE_CHANCE:
			GameState.neighbors[str(lot)] = "for_sale"
			return lot
	return -1


## Satılıkta olup seviyesi yeten komşu var mı (Mahalle düğmesi parlar)?
static func any_for_sale() -> bool:
	for lot in range(1, LOTS.size()):
		if state(lot) == "for_sale":
			return true
	return false


## Bu yer birleştirilebilir mi? (bitişik ve şu an ilk dükkanda oynanıyor)
static func can_merge(lot: int) -> bool:
	return LOTS[lot].has("merge") and active_lot() == 0


## Oyuncunun şu an içinde olduğu dükkanın yeri
static func active_lot() -> int:
	if GameState.shops.is_empty():
		return 0
	return int(GameState.shops[GameState.active_shop]["lot"])


## Sokakta bu yerde görünen dükkanın adı. Oyuncu hep "buradaki" binada oynar;
## bir şubedeyken o şubenin yerinde ilk dükkan görünür (yerler yer değiştirir).
static func name_at(lot: int) -> String:
	var shown := shown_lot(lot)
	if merged(shown) or shown == 0 and shop_at(0) == -1:
		return home_name()
	var index := shop_at(shown)
	if index == -1:
		return str(LOTS[shown].get("company", ""))
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
static func new_shop(lot: int, theme := "menum") -> Dictionary:
	var decor := Decor.default_state()
	for key in ["clean", "register", "paint", "windows", "lamps", "sign"]:
		decor[key] = true
	var theme_data: Dictionary = THEMES.get(theme, THEMES["menum"])
	decor["paint_color"] = int(theme_data["paint"]) if theme != "menum" else (lot * 3) % Decor.WALL_COLORS.size()
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
	var menu: Array = (theme_data["menu"] as Array).duplicate()
	if menu.is_empty():
		menu = GameState.menu.duplicate() if not GameState.menu.is_empty() else ["kofte", "patates", "kola"]
	for id in menu:
		stock[id] = 10
		for i in 10:
			batches[id].append(GameState.day + 4)
	return {
		"shop_name": ("%s %s" % [home_name(), theme_data["suffix"]] if theme != "menum" else "%s %d" % [home_name(), GameState.shops.size() + 1]).left(24),
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


## Eski kayıtlar: önceki sürümde Yan Salon / Bahçe Teras geliştirmesi ve sokağın
## karşısındaki üç satılık yer vardı. Bahçe sağ komşuyla birleşmiş sayılır, şubeler
## boş yerlere taşınır.
static func migrate() -> void:
	if int(GameState.upgrades.get("garden", 0)) > 0:
		GameState.upgrades.erase("garden")
		GameState.upgrades["annex_r"] = 1
	var taken := {}
	for lot in range(1, LOTS.size()):
		if merged(lot):
			taken[lot] = true
	for entry in GameState.shops:
		var lot := int(entry["lot"])
		if lot == 0:
			continue
		if lot >= LOTS.size() or taken.has(lot):
			for free in [3, 4, 1, 2]:
				if not taken.has(free):
					lot = free
					break
		entry["lot"] = lot
		taken[lot] = true
