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
]
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

const TABLE_PRICE := 35
const MAX_SETUP_TABLES := 4
const PLANT_PRICE := 15
const MAX_PLANTS := 4


static func default_state() -> Dictionary:
	return {
		"clean": false, "register": false, "paint": false, "windows": false, "lamps": false, "sign": false,
		"paint_color": 0, "floor": 0, "tables": 0, "plants": 0,
	}


## Temizlikçi kıyafeti: [önlük, eldiven]. Önlük duvar boyasının lambri renginde,
## eldiven onun açığı (boya yoksa harabe duvarın rengi).
static func uniform_colors(decor: Dictionary) -> Array[Color]:
	var panel: Color = (WALL_COLORS[decor["paint_color"]] if decor["paint"] else RUIN_WALL)["panel"]
	return [panel, panel.lightened(0.35)]


## Dekor müşterileri daha sabırlı yapar (en fazla %30).
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
	return minf(bonus, 0.3)


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
