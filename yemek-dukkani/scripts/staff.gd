class_name Staff
extends RefCounted

## Personel adayları ve özellikleri. Hız ve çalışkanlık maaşı belirler:
## hızlı ve çalışkan olanlar pahalıdır, tembel olanlar molaya çıkar.

const MAX_STAFF := 2
## Cinsiyete göre isimler ve temizlikçi modelleri (ModelBody.CHARACTERS anahtarı).
## Yeni bir temizlikçi modeli eklenince WORKER_MODELS'a bir satır yeter.
const NAMES := {
	"erkek": ["Ali", "Murat", "Okan", "Tolga", "Cem", "Barış", "Kaan", "Serkan", "Hakan", "Oğuz", "Volkan", "Sinan"],
	"kadin": ["Hande", "Gizem", "Seda", "Büşra", "Nazlı", "İpek", "Derya", "Pınar", "Gamze", "Tuba", "Ceren", "Aslı"],
}
const WORKER_MODELS := { "erkek": "temizlikci_erkek", "kadin": "temizlikci_kadin" }

## move: yürüme hızı, clean: masa temizleme süresi (sn), pay: maaşa etkisi
const SPEEDS := [
	{ "name": "Yavaş", "move": 1.6, "clean": 4.0, "pay": 0 },
	{ "name": "Normal", "move": 2.2, "clean": 2.8, "pay": 10 },
	{ "name": "Hızlı", "move": 2.9, "clean": 1.8, "pay": 22 },
]
## rest: işten sonra molaya çıkma olasılığı, haggle: pazarlığı kabul etme olasılığı
const WORK := [
	{ "name": "Tembel", "rest": 0.45, "pay": -8, "haggle": 0.7 },
	{ "name": "Normal", "rest": 0.15, "pay": 0, "haggle": 0.5 },
	{ "name": "Çalışkan", "rest": 0.0, "pay": 12, "haggle": 0.35 },
]
const BASE_WAGE := 35
## Pazarlıkta önerilen indirim
const HAGGLE_RATIO := 0.8


static func make_candidate() -> Dictionary:
	var speed := randi_range(0, SPEEDS.size() - 1)
	var work := randi_range(0, WORK.size() - 1)
	var wage: int = BASE_WAGE + SPEEDS[speed]["pay"] + WORK[work]["pay"] + randi_range(-4, 6)
	var gender: String = WORKER_MODELS.keys().pick_random()
	return {
		"name": (NAMES[gender] as Array).pick_random(), "speed": speed, "work": work, "wage": wage, "haggled": false,
		"model": WORKER_MODELS[gender], "gender": gender, "look": CharacterSkin.look_to_save(CharacterSkin.random_look()),
	}


## Adaylar birbirinden ve mevcut çalışanlardan farklı isimlerde gelir.
static func make_candidates(count := 3, taken: Array[Dictionary] = []) -> Array[Dictionary]:
	var used := taken.map(func(p: Dictionary) -> String: return p["name"])
	var list: Array[Dictionary] = []
	for i in count:
		var person := make_candidate()
		var names: Array = (NAMES[person["gender"]] as Array).filter(func(n: String) -> bool: return not used.has(n))
		person["name"] = names.pick_random()
		used.append(person["name"])
		list.append(person)
	return list


static func traits(person: Dictionary) -> String:
	return "%s • %s" % [SPEEDS[person["speed"]]["name"], WORK[person["work"]]["name"]]


static func haggle_offer(person: Dictionary) -> int:
	return roundi(person["wage"] * HAGGLE_RATIO)


static func move_speed(person: Dictionary) -> float:
	return SPEEDS[person["speed"]]["move"]


static func clean_time(person: Dictionary) -> float:
	return SPEEDS[person["speed"]]["clean"]


static func rest_chance(person: Dictionary) -> float:
	return WORK[person["work"]]["rest"]


static func accepts_haggle(person: Dictionary) -> bool:
	return randf() < WORK[person["work"]]["haggle"]
