class_name Items
extends RefCounted

## Ürün tanımları ve modelleri. Modeller şimdilik basit şekiller;
## Meshy modelleri gelince model() içindekiler değiştirilecek.

const PACK_SIZE := 5

const PRODUCTS := {
	"tavuk": { "name": "Tavuk", "price": 14, "cook_time": 9.0, "device": "izgara", "pack_price": 20 },
	"kofte": { "name": "Köfte", "price": 12, "cook_time": 7.0, "device": "izgara", "pack_price": 16 },
	"patates": { "name": "Patates", "price": 7, "cook_time": 5.0, "device": "fritoz", "pack_price": 8 },
	"kola": { "name": "Kola", "price": 5, "cook_time": 0.0, "device": "", "pack_price": 10 },
}

## Pişme renkleri: [çiğ, tam kıvam, yanık]
const COLORS := {
	"tavuk": [Color("#f2b8a8"), Color("#d98a3a"), Color("#2b1a12")],
	"kofte": [Color("#c46a6a"), Color("#6b3a22"), Color("#1e1210")],
	"patates": [Color("#f3e6b0"), Color("#f2b53c"), Color("#4a2c10")],
}

## Pişme oranı (doneness) eşikleri: 1.0 = tam pişme süresi.
const RAW_LIMIT := 0.5
const UNDER_LIMIT := 0.85
const PERFECT_LIMIT := 1.2
const BURNT_LIMIT := 1.6
const MAX_DONENESS := 1.8


static func display_name(id: String) -> String:
	return PRODUCTS[id]["name"]


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


static func quality_color(id: String, quality: int) -> Color:
	if not COLORS.has(id):
		return Color.WHITE
	match quality:
		2: return cook_color(id, 0.7)
		3: return cook_color(id, 1.3)
	return cook_color(id, 1.0)


static func model(id: String, mat: Material) -> Node3D:
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
	return root
