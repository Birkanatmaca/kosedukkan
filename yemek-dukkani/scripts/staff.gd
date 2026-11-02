class_name Staff
extends RefCounted

## Personel adayları ve özellikleri. Hız ve çalışkanlık maaşı belirler:
## hızlı ve çalışkan olanlar pahalıdır, tembel olanlar molaya çıkar.

const MAX_STAFF := 2
const NAMES := ["Ali", "Hande", "Murat", "Gizem", "Okan", "Seda", "Tolga", "Büşra", "Cem", "Nazlı", "Barış", "İpek"]

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
	return { "name": NAMES.pick_random(), "speed": speed, "work": work, "wage": wage, "haggled": false }


## Adaylar birbirinden ve mevcut çalışanlardan farklı isimlerde gelir.
static func make_candidates(count := 3, taken: Array[Dictionary] = []) -> Array[Dictionary]:
	var names := NAMES.duplicate()
	for person in taken:
		names.erase(person["name"])
	names.shuffle()
	var list: Array[Dictionary] = []
	for i in count:
		var person := make_candidate()
		person["name"] = names[i]
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
