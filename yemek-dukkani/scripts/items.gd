class_name Items
extends RefCounted

## Ürün tanımları ve modelleri. MODELS'te olan ürünler Meshy modeliyle,
## olmayanlar basit şekillerle çizilir.

const PACK_SIZE := 5

## Oyuncu menüsünü bu katalogdan seçer (GameState.menu). Menüde olmayan ürün
## mutfakta, markette ve siparişlerde görünmez.
const PRODUCTS := {
	"tavuk": { "name": "Kajun Tavuk", "price": 14, "cook_time": 9.0, "device": "izgara", "pack_price": 20 },
	"tavuk_sis": { "name": "Tavuk Şiş", "price": 15, "cook_time": 8.0, "device": "izgara", "pack_price": 18 },
	"kofte": { "name": "Köfte", "price": 12, "cook_time": 7.0, "device": "izgara", "pack_price": 16 },
	"patates": { "name": "Patates", "price": 7, "cook_time": 5.0, "device": "fritoz", "pack_price": 8 },
	"kola": { "name": "Kola", "price": 5, "cook_time": 0.0, "device": "", "pack_price": 10 },
	"ayran": { "name": "Ayran", "price": 5, "cook_time": 0.0, "device": "", "pack_price": 9 },
	"lahmacun": { "name": "Lahmacun", "price": 16, "cook_time": 8.0, "device": "firin", "pack_price": 22 },
	"pizza": { "name": "Pizza", "price": 22, "cook_time": 9.0, "device": "firin", "pack_price": 30 },
	"pide": { "name": "Kaşarlı Pide", "price": 20, "cook_time": 10.0, "device": "firin", "pack_price": 28 },
}
## Cihazların ekrandaki adı
const DEVICES := { "izgara": "Izgara", "fritoz": "Fritöz", "firin": "Fırın" }
## Oyun içinde menüye yeni cihaz isteyen ürün eklenince ödenen cihaz bedeli
## (kurulumda seçilen menünün cihazları ücretsizdir).
const DEVICE_PRICES := { "izgara": 160, "fritoz": 110, "firin": 220 }

## Meshy modelleri: ürün -> [dosya, ölçek, y dönüşü, (adet)]. Adet verilirse
## model yan yana o kadar kopya dizilir (bir porsiyon köfte = 3 köfte).
const MODELS := {
	"kofte": ["food/kofte", 1.0, 0.0, 3],
	"tavuk": ["food/kajun_tavuk", 1.9, 0.0],
	"tavuk_sis": ["food/tavuk_sis", 1.15, 0.0],
	"patates": ["food/patates", 1.1, 0.0],
	"kola": ["food/icecek_bardak", 1.0, 0.0],
	"lahmacun": ["food/lahmacun", 1.15, 0.0],
	"pizza": ["food/pizza", 1.05, 0.0],
}

## Pişme renkleri: [çiğ, tam kıvam, yanık]. Modelli ürünlerde bu renkler dokuyu
## boyar; tam kıvamı beyazdır (doku olduğu gibi görünür).
const COLORS := {
	"tavuk": [Color("#f7c9bd"), Color.WHITE, Color("#3a2a22")],
	"tavuk_sis": [Color("#f7c9bd"), Color.WHITE, Color("#3a2a22")],
	"kofte": [Color("#ffb3a8"), Color.WHITE, Color("#3a2a22")],
	"patates": [Color("#fff6d6"), Color.WHITE, Color("#4a2c10")],
	"lahmacun": [Color("#ffd9c8"), Color.WHITE, Color("#3a2a22")],
	"pizza": [Color("#fff0dc"), Color.WHITE, Color("#3a2a22")],
	"pide": [Color("#f0dfbd"), Color("#d9a052"), Color("#3a2414")],
}

## Doku + renk birleşimi önbelleği (paylaşılan renk materyalleri için)
static var _tinted := {}

## Pişme oranı (doneness) eşikleri: 1.0 = tam pişme süresi.
const RAW_LIMIT := 0.5
const UNDER_LIMIT := 0.85
const PERFECT_LIMIT := 1.2
const BURNT_LIMIT := 1.6
const MAX_DONENESS := 1.8


## Ürün menüde mi?
static func unlocked(id: String) -> bool:
	return GameState.menu.has(id)


## Yemek mi (bir cihazda pişer), içecek mi?
static func is_food(id: String) -> bool:
	return PRODUCTS[id]["device"] != ""


## Menüdeki ürünler (cihaz verilirse sadece o cihazda pişenler; "" içecekler).
static func unlocked_ids(device: Variant = null) -> Array[String]:
	var list: Array[String] = []
	for id in PRODUCTS:
		if unlocked(id) and (device == null or PRODUCTS[id]["device"] == device):
			list.append(id)
	return list


## Satış fiyatı: menüdeki taban fiyat × oyuncunun ayarladığı çarpan.
static func price(id: String) -> int:
	return maxi(1, roundi(float(PRODUCTS[id]["price"]) * float(GameState.price_factors.get(id, 1.0))))


static func display_name(id: String) -> String:
	return PRODUCTS[id]["name"]


## Kıvam çubuğunun tam ortası: pişme oranı 1.0'a bu kadar yakınken alınan ürün
## "tam kıvam" sayılır, bonus kazandırır.
const BULLSEYE := 0.08


static func is_bullseye(doneness: float) -> bool:
	return absf(doneness - 1.0) <= BULLSEYE


## Pişme oranına göre kalite: 5 tam, 3 fazla pişmiş, 2 az pişmiş, 0 yanık.
static func quality_for(doneness: float) -> int:
	if doneness < UNDER_LIMIT:
		return 2
	if doneness <= PERFECT_LIMIT:
		return 5
	if doneness < BURNT_LIMIT:
		return 3
	return 0


static func cook_color(id: String, doneness: float) -> Color:
	var c: Array = COLORS[id]
	if doneness < 1.0:
		return (c[0] as Color).lerp(c[1], doneness)
	return (c[1] as Color).lerp(c[2], clampf((doneness - 1.0) / (BURNT_LIMIT - 1.0), 0.0, 1.0))


## Tarihi geçmiş malzemeden pişen ürünün rengi (yeşilimsi, bozuk)
const SPOILED_TINT := Color("#8aa04a")


static func quality_color(id: String, quality: int) -> Color:
	if quality == 1:
		return (cook_color(id, 1.0) if COLORS.has(id) else Color.WHITE).lerp(SPOILED_TINT, 0.55)
	if not COLORS.has(id):
		return Color.WHITE
	match quality:
		2: return cook_color(id, 0.7)
		3: return cook_color(id, 1.3)
	return cook_color(id, 1.0)


## Ürünün modeli. `mat`in rengi pişme durumunu gösterir; Meshy modelinde bu
## renk dokuyla çarpılır. Paylaşılan (önbellekteki) bir renk materyali gelirse
## dokulu kopyası önbelleğe alınır, tekil bir materyal gelirse (ızgaradaki
## ürün gibi rengi sürekli değişen) dokuyu doğrudan ona takarız.
static func model(id: String, mat: Material) -> Node3D:
	if MODELS.has(id):
		var info: Array = MODELS[id]
		var count: int = info[3] if info.size() > 3 else 1
		var node := Node3D.new()
		for i in count:
			# Kopyalar yan yana, her biri biraz farklı açıyla (elle dizilmiş gibi)
			var x := (i - (count - 1) * 0.5) * 0.11
			var yaw: float = info[2] + (0.0 if count == 1 else [-8.0, 6.0, -3.0][i % 3])
			node.add_child(Util.model(info[0], Vector3(x, 0, 0), yaw, info[1]))
		for mesh: MeshInstance3D in Util.meshes(node):
			mesh.material_override = _textured(mesh.get_active_material(0), mat)
		return node
	var root := Node3D.new()
	match id:
		"tavuk":
			var meat := Util.capsule(0.075, 0.3, mat, Vector3(-0.03, 0.075, 0))
			meat.rotation_degrees.z = 90
			root.add_child(meat)
			var bone := Util.cylinder(0.018, 0.1, Color("#f4efe6"), Vector3(0.15, 0.075, 0))
			bone.rotation_degrees.z = 90
			root.add_child(bone)
			root.add_child(Util.sphere(0.03, Color("#f4efe6"), Vector3(0.2, 0.075, 0)))
		"kofte":
			for x in [-0.1, 0.0, 0.1]:
				var ball := Util.sphere(0.055, mat, Vector3(x, 0.04, 0))
				ball.scale.y = 0.75
				root.add_child(ball)
		"patates":
			var sticks := [
				Vector3(-0.06, 0.02, 0), Vector3(0, 0.02, 0.03), Vector3(0.06, 0.02, -0.02),
				Vector3(-0.03, 0.045, -0.03), Vector3(0.03, 0.045, 0.02), Vector3(0, 0.07, 0),
			]
			for i in sticks.size():
				var stick := Util.box(Vector3(0.028, 0.028, 0.18), mat, sticks[i])
				stick.rotation_degrees.y = i * 31.0
				root.add_child(stick)
		"kola":
			root.add_child(Util.cylinder(0.055, 0.17, Color("#d62f2f"), Vector3(0, 0.085, 0)))
			root.add_child(Util.cylinder(0.05, 0.01, Color("#d9dde0"), Vector3(0, 0.175, 0)))
		"ayran":
			# Beyaz bardak, mavi şerit, köpüklü üst
			root.add_child(Util.cylinder(0.05, 0.15, Color("#f7f9fb"), Vector3(0, 0.075, 0)))
			root.add_child(Util.cylinder(0.052, 0.035, Color("#2f7fd0"), Vector3(0, 0.07, 0)))
			root.add_child(Util.cylinder(0.047, 0.012, Color("#fffdf6"), Vector3(0, 0.152, 0)))
		"lahmacun":
			# İnce hamur (pişince kızarır), üstünde kıymalı harç ve maydanoz
			root.add_child(Util.cylinder(0.16, 0.012, mat, Vector3(0, 0.006, 0)))
			root.add_child(Util.cylinder(0.14, 0.006, Color("#a8402a"), Vector3(0, 0.014, 0)))
			for i in 7:
				var a := i * TAU / 7.0
				var leaf := Util.sphere(0.012, Color("#4f9a3a"), Vector3(cos(a) * 0.08, 0.019, sin(a) * 0.08))
				leaf.scale.y = 0.4
				root.add_child(leaf)
			var lemon := Util.sphere(0.022, Color("#f4d23c"), Vector3(0.0, 0.02, 0.0))
			lemon.scale = Vector3(1.4, 0.5, 0.8)
			root.add_child(lemon)
		"pide":
			# Kayık hamur: kıvrık kenarlar, ortada erimiş kaşar
			var boat := Util.box(Vector3(0.36, 0.022, 0.12), mat, Vector3(0, 0.011, 0))
			root.add_child(boat)
			for z in [-0.055, 0.055]:
				var edge := Util.capsule(0.018, 0.36, mat, Vector3(0, 0.022, z))
				edge.rotation_degrees.z = 90
				root.add_child(edge)
			var cheese := Util.box(Vector3(0.28, 0.012, 0.07), Color("#f5cf55"), Vector3(0, 0.026, 0))
			root.add_child(cheese)
			for x in [-0.08, 0.0, 0.08]:
				root.add_child(Util.sphere(0.012, Color("#e07a2a"), Vector3(x, 0.034, 0)))
	return root


static func _textured(source: Material, mat: Material) -> Material:
	var src := source as StandardMaterial3D
	var tint := mat as StandardMaterial3D
	if not src or not tint:
		return source
	if Util._materials.values().has(tint):
		var key := "%s|%s" % [src.get_instance_id(), tint.albedo_color.to_html()]
		if not _tinted.has(key):
			var copy := src.duplicate() as StandardMaterial3D
			copy.albedo_color = tint.albedo_color
			_tinted[key] = copy
		return _tinted[key]
	tint.albedo_texture = src.albedo_texture
	return tint
