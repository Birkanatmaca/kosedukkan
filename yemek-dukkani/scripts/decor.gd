class_name Decor
extends RefCounted

## Başlangıçtaki dükkan kurulumu: harabe bir dükkanı verilen bütçeyle
## temizleyip boyar, masalarını ve kasasını alırsın. Kalan para oyunun
## başlangıç sermayesi olur. Güzel dekor müşterileri daha sabırlı yapar.

const START_BUDGET := 300

const WALL_COLORS := [
	{ "name": "Krem", "wall": Color("#f6e7d0"), "side": Color("#efdcc2"), "panel": Color("#b5714a") },
	{ "name": "Nane", "wall": Color("#d8efe2"), "side": Color("#c7e6d4"), "panel": Color("#3f8f6a") },
	{ "name": "Gül", "wall": Color("#f7dde0"), "side": Color("#f0cdd2"), "panel": Color("#b5546a") },
	{ "name": "Gök", "wall": Color("#dbe8f7"), "side": Color("#cadcf0"), "panel": Color("#3f6fae") },
	{ "name": "Limon", "wall": Color("#fbf1c7"), "side": Color("#f3e6ad"), "panel": Color("#c79a2e") },
	{ "name": "Lavanta", "wall": Color("#e6def3"), "side": Color("#dbd0ec"), "panel": Color("#6f58a8") },
	{ "name": "Şeftali", "wall": Color("#fbe0cc"), "side": Color("#f5d1b8"), "panel": Color("#c8643c") },
	{ "name": "Zeytin", "wall": Color("#e8e6cf"), "side": Color("#dddab9"), "panel": Color("#6b7036") },
]
## Oyun içinde (Market › Dekor) yeni bir duvar rengi almanın bedeli
const PAINT_PRICE := 100
const RUIN_WALL := { "wall": Color("#8c8478"), "side": Color("#7d766b"), "panel": Color("#4f463d") }

const FLOORS := [
	{ "name": "Eski", "a": Color("#7d746a"), "b": Color("#6a6259"), "price": 0 },
	{ "name": "Ahşap", "a": Color("#c89a64"), "b": Color("#b88a56"), "price": 40 },
	{ "name": "Seramik", "a": Color("#ead9bf"), "b": Color("#d9c09c"), "price": 50 },
	{ "name": "Mermer", "a": Color("#f2f2f0"), "b": Color("#d9dde2"), "price": 70 },
]

## Tek seferlik alınan şeyler. required: dükkan açılmadan alınması şart.
const ITEMS := {
	"clean": { "name": "Temizlik", "icon": "spray-can", "desc": "Çöpleri at, lekeleri sil", "price": 40, "required": true },
	"register": { "name": "Yazar Kasa", "icon": "receipt", "desc": "Kart ve nakit ödeme alır", "price": 60, "required": true },
	"paint": { "name": "Duvar Boyası", "icon": "paint-roller", "desc": "Rengini aşağıdan seç", "price": 30, "required": false },
	"windows": { "name": "Yeni Pencereler", "icon": "app-window", "desc": "Tahtaları sök, cam tak", "price": 25, "required": false },
	"lamps": { "name": "Lambalar", "icon": "lamp-ceiling", "desc": "Sıcak ve aydınlık salon", "price": 30, "required": false },
	"sign": { "name": "Tabela", "icon": "signpost", "desc": "Dükkanının adı kapının üstünde", "price": 25, "required": false },
}

## Oyun içi dekor mağazası (Market › Dekor). Her kategoride bir seçenek seçilidir;
## alınan seçenek sahiplenilir, sonra ücretsiz geri dönülebilir. İlk seçenek bedava.
## key: GameState.decor içindeki alan.
const STYLES := {
	"rug": { "name": "Giriş Halısı", "icon": "layout-grid", "key": "rug", "options": [
		{ "name": "Yok", "price": 0, "color": Color("#b8ada0") },
		{ "name": "Yeşil Paspas", "price": 90, "color": Color("#3f7f5a") },
		{ "name": "Kırmızı Kilim", "price": 180, "color": Color("#b53a2c") },
		{ "name": "Uzun Yolluk", "price": 300, "color": Color("#7a3b6a") },
	] },
	"door": { "name": "Kapı", "icon": "door-open", "key": "door", "options": [
		{ "name": "Ahşap", "price": 0, "color": Color("#7a4b32") },
		{ "name": "Kırmızı Retro", "price": 250, "color": Color("#b53a2c") },
		{ "name": "Nane Yeşili", "price": 250, "color": Color("#3f8f6a") },
		{ "name": "Siyah Metal", "price": 320, "color": Color("#2b2d33") },
	] },
	"window": { "name": "Pencere Çerçevesi", "icon": "app-window", "key": "window_style", "options": [
		{ "name": "Beyaz", "price": 0, "color": Color("#f7f4ee") },
		{ "name": "Ahşap", "price": 200, "color": Color("#8a5a3a") },
		{ "name": "Yeşil", "price": 200, "color": Color("#3f7f5a") },
		{ "name": "Siyah", "price": 220, "color": Color("#2b2d33") },
	] },
	"table": { "name": "Masa Çeşidi", "icon": "armchair", "key": "table_style", "options": [
		{ "name": "Klasik", "price": 0, "color": Color("#c9a77a") },
		{ "name": "Ahşap Kare", "price": 300, "color": Color("#a0703f") },
		{ "name": "Mermer Yuvarlak", "price": 420, "color": Color("#e9e7e2") },
		{ "name": "Retro Kırmızı", "price": 380, "color": Color("#c8402f") },
	] },
	# Ön bahçe (dükkanın önündeki şerit): zemin alınınca masa, gölgelik ve süs eklenir.
	"patio": { "name": "Ön Bahçe Zemini", "icon": "grid-3x3", "key": "patio_floor", "patio": true, "options": [
		{ "name": "Yok", "price": 0, "color": Color("#c9c4bb") },
		{ "name": "Ahşap Deck", "price": 450, "color": Color("#b98552") },
		{ "name": "Taş Döşeme", "price": 500, "color": Color("#a7a29a") },
		{ "name": "Çim ve Taş", "price": 550, "color": Color("#7fb366") },
	] },
	"shade": { "name": "Gölgelik", "icon": "sun", "key": "patio_shade", "patio": true, "options": [
		{ "name": "Yok", "price": 0, "color": Color("#c9c4bb") },
		{ "name": "Şemsiyeler", "price": 450, "color": Color("#e8553e") },
		{ "name": "Çizgili Tente", "price": 750, "color": Color("#d6452f") },
		{ "name": "Ahşap Pergola", "price": 1100, "color": Color("#7a4b32") },
	] },
	# Çatı terası (Geliştir › Çatı Terası inşa edilince)
	"roof_floor": { "name": "Teras Zemini", "icon": "grid-3x3", "key": "roof_floor", "roof": true, "options": [
		{ "name": "Ahşap Deck", "price": 0, "color": Color("#b98552") },
		{ "name": "Terracotta", "price": 380, "color": Color("#c2693e") },
		{ "name": "Suni Çim", "price": 420, "color": Color("#79b85a") },
		{ "name": "Beyaz Taş", "price": 480, "color": Color("#ece7de") },
	] },
	"roof_shade": { "name": "Teras Gölgeliği", "icon": "sun", "key": "roof_shade", "roof": true, "options": [
		{ "name": "Yok", "price": 0, "color": Color("#c9c4bb") },
		{ "name": "Şemsiyeler", "price": 480, "color": Color("#e8553e") },
		{ "name": "Sarmaşık Pergola", "price": 1100, "color": Color("#7a4b32") },
		{ "name": "Yelken Gölgelik", "price": 850, "color": Color("#f3efe6") },
	] },
}
## Süsler: bir kez alınır, sonra açılıp kapatılabilir.
const ORNAMENTS := {
	"lights": { "name": "Işık Zinciri", "icon": "sparkles", "desc": "Vitrin duvarında renkli ampuller", "price": 180 },
	"flowers": { "name": "Vitrin Çiçekleri", "icon": "sprout", "desc": "Pencere önlerinde çiçek kasaları", "price": 140 },
	"clock": { "name": "Duvar Saati", "icon": "clock", "desc": "Sol duvarda büyük saat", "price": 110 },
	"frames": { "name": "Tablolar", "icon": "image", "desc": "Sağ duvarda iki tablo", "price": 150 },
	"nazar": { "name": "Nazar Boncuğu", "icon": "heart", "desc": "Kapının yanında, uğur getirir", "price": 60 },
	"board": { "name": "Menü Panosu", "icon": "clipboard-list", "desc": "Kapı yanında kara tahta", "price": 130 },
	"patio_lights": { "name": "Bahçe Işıkları", "icon": "sparkles", "desc": "Bahçenin üstünde sarı ampul zinciri", "price": 280, "patio": true },
	"patio_lanterns": { "name": "Fener Direkleri", "icon": "lamp-ceiling", "desc": "Bahçenin köşelerinde sokak fenerleri", "price": 240, "patio": true },
	"patio_plants": { "name": "Bahçe Saksıları", "icon": "sprout", "desc": "Zeytin ağaçları, vitrin altında çiçekler, lavantalar", "price": 200, "patio": true },
	"roof_lights": { "name": "Teras Işıkları", "icon": "sparkles", "desc": "Terasın üstünde çapraz ampul zincirleri", "price": 320, "roof": true },
	"roof_plants": { "name": "Teras Bahçesi", "icon": "sprout", "desc": "Çiçek kasaları, zeytin ağaçları, lavanta", "price": 300, "roof": true },
	"roof_lounge": { "name": "Oturma Köşesi", "icon": "armchair", "desc": "Minderli L sedir, kilim ve çay sehpası", "price": 550, "roof": true },
}
## Teras masası: adet başı fiyat ve en fazla adet.
const ROOF_TABLE_PRICE := 380
const MAX_ROOF_TABLES := 6
## Ön bahçe masası: adet başı fiyat ve en fazla adet (müşteriler oturur).
const PATIO_TABLE_PRICE := 320
const MAX_PATIO_TABLES := 4

const TABLE_PRICE := 35
const MAX_SETUP_TABLES := 4
const PLANT_PRICE := 15
const MAX_PLANTS := 4


static func default_state() -> Dictionary:
	return {
		"clean": false, "register": false, "paint": false, "windows": false, "lamps": false, "sign": false,
		"paint_color": 0, "floor": 0, "tables": 0, "plants": 0,
		"rug": 0, "door": 0, "window_style": 0, "table_style": 0,
		"patio_floor": 0, "patio_shade": 0, "patio_tables": 0,
		"roof_floor": 0, "roof_shade": 0, "roof_tables": 0,
		## Alınan seçenekler ("door:2", "paint:3", "floor:1"...) ve süsler
		"owned": [], "ornaments": [], "ornaments_off": [],
	}


## Kategorideki seçenek sahiplenilmiş mi? (ilk seçenek ve şu an seçili olan hep sahiplidir)
static func owns(decor: Dictionary, category: String, index: int) -> bool:
	if category == "paint":
		return decor["paint"] and (index == decor["paint_color"] or (decor["owned"] as Array).has("paint:%d" % index))
	if index == 0 or index == int(decor[_key(category)]):
		return true
	return (decor["owned"] as Array).has("%s:%d" % [category, index])


static func price_of(category: String, index: int) -> int:
	match category:
		"paint": return PAINT_PRICE
		"floor": return int(FLOORS[index]["price"])
	return int(STYLES[category]["options"][index]["price"])


static func _key(category: String) -> String:
	match category:
		"paint": return "paint_color"
		"floor": return "floor"
	return STYLES[category]["key"]


static func selected(decor: Dictionary, category: String) -> int:
	return int(decor[_key(category)])


## Seçer (sahip değilse önce alır). Döner: ödenen tutar, alınamadıysa -1.
static func choose(decor: Dictionary, category: String, index: int, money: int) -> int:
	var cost := 0 if owns(decor, category, index) else price_of(category, index)
	if cost > money:
		return -1
	var tag := "%s:%d" % [category, index]
	if cost > 0 and not (decor["owned"] as Array).has(tag):
		(decor["owned"] as Array).append(tag)
	# Önceki seçim de sahipli kalsın (geri dönülebilsin)
	var before := "%s:%d" % [category, selected(decor, category)]
	if not (decor["owned"] as Array).has(before) and (category != "paint" or decor["paint"]):
		(decor["owned"] as Array).append(before)
	decor[_key(category)] = index
	if category == "paint":
		decor["paint"] = true
	return cost


## Görünen süsler
static func ornament_on(decor: Dictionary, id: String) -> bool:
	return (decor["ornaments"] as Array).has(id) and not (decor["ornaments_off"] as Array).has(id)


## Oyun içi dekorun puanı: her stil seçimi ve görünen süs biraz sabır ve fiyat
## toleransı kazandırır.
static func style_points(decor: Dictionary) -> int:
	var points := 0
	for category in STYLES:
		if int(decor[STYLES[category]["key"]]) > 0:
			points += 1
	for id in ORNAMENTS:
		if ornament_on(decor, id):
			points += 1
	return points


## Temizlikçi kıyafeti: [önlük, eldiven]. Önlük duvar boyasının lambri renginde,
## eldiven onun açığı (boya yoksa harabe duvarın rengi).
static func uniform_colors(decor: Dictionary) -> Array[Color]:
	var panel: Color = (WALL_COLORS[decor["paint_color"]] if decor["paint"] else RUIN_WALL)["panel"]
	return [panel, panel.lightened(0.35)]


## Dekor müşterileri daha sabırlı yapar (en fazla %45).
static func patience_bonus(decor: Dictionary) -> float:
	var bonus := 0.0
	if decor["paint"]:
		bonus += 0.06
	if decor["floor"] > 0:
		bonus += 0.03 + 0.02 * decor["floor"]
	if decor["lamps"]:
		bonus += 0.05
	if decor["windows"]:
		bonus += 0.03
	bonus += 0.02 * decor["plants"]
	bonus += 0.02 * style_points(decor) + 0.01 * (int(decor.get("patio_tables", 0)) + int(decor.get("roof_tables", 0)))
	return minf(bonus, 0.45)


## Tabelası olan dükkana müşteri daha sık gelir.
static func spawn_bonus(decor: Dictionary) -> float:
	return 0.12 if decor["sign"] else 0.0


## Dükkanı açmak için eksik kalanlar.
static func missing(decor: Dictionary) -> Array[String]:
	var list: Array[String] = []
	for id in ITEMS:
		if ITEMS[id]["required"] and not decor[id]:
			list.append(ITEMS[id]["name"])
	if decor["tables"] < 1:
		list.append("en az 1 masa")
	return list
