class_name Staff
extends RefCounted

## Personel adayları ve özellikleri. Hız ve çalışkanlık maaşı belirler:
## hızlı ve çalışkan olanlar pahalıdır, tembel olanlar molaya çıkar.
## Görevler: garson (masaları temizler), kurye (paket siparişleri götürür),
## aşçı (mutfakta siparişleri kendisi pişirip tepsiye koyar) ve kasiyer (Ek Kasa'da
## sipariş ve ödeme alır, hazır siparişlerini teslim eder; sıra ikiye bölünür).

## Görevler: ad, en fazla kaç kişi, hangi seviyede açıldığı, taban maaş
const ROLES := {
	"garson": { "name": "Garson", "max": 2, "unlock": 1, "base": 35 },
	"kurye": { "name": "Kurye", "max": 2, "unlock": 2, "base": 42 },
	"asci": { "name": "Aşçı", "max": 1, "unlock": 2, "base": 52 },
	"kasiyer": { "name": "Kasiyer", "max": 1, "unlock": 3, "base": 48 },
}
## Aşçı ve kasiyerin bir işi bitirme süresi (sn), hızına göre: yavaş, normal, hızlı
const WORK_TIMES := [3.2, 2.3, 1.6]
## Kurye bir seferde en fazla bu kadar paket taşır.
const COURIER_CAPACITY := 4
const COURIER_MODELS := { "erkek": "kurye" }
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
## Pazarlıkta önerilen indirim
const HAGGLE_RATIO := 0.8


static func make_candidate(job := "garson") -> Dictionary:
	var speed := randi_range(0, SPEEDS.size() - 1)
	var work := randi_range(0, WORK.size() - 1)
	var wage: int = ROLES[job]["base"] + SPEEDS[speed]["pay"] + WORK[work]["pay"] + randi_range(-4, 6)
	var models: Dictionary = COURIER_MODELS if job == "kurye" else WORKER_MODELS
	var gender: String = models.keys().pick_random()
	return {
		"name": (NAMES[gender] as Array).pick_random(), "speed": speed, "work": work, "wage": wage, "haggled": false,
		"model": models[gender], "gender": gender, "look": CharacterSkin.look_to_save(CharacterSkin.random_look()),
		"role": job,
	}


## Kişinin görevi (eski kayıtlarda görev yoksa garson).
static func role(person: Dictionary) -> String:
	return person.get("role", "garson")


static func role_name(person: Dictionary) -> String:
	return ROLES[role(person)]["name"]


static func count(people: Array[Dictionary], job: String) -> int:
	return people.filter(func(p: Dictionary) -> bool: return role(p) == job).size()


## Kuryenin gidip dönme süresi (sn): paket başına uzar, hızlı kurye kısa sürer.
static func trip_time(person: Dictionary, packages: int) -> float:
	return (22.0 + 7.0 * packages) * 2.2 / move_speed(person)


## Günün adayları: garsonlar, seviyesi gelince kuryeler de. İsimler birbirinden ve
## mevcut çalışanlardan farklıdır.
static func make_candidates(count := 3, taken: Array[Dictionary] = [], level := 1) -> Array[Dictionary]:
	var jobs: Array[String] = []
	for i in count:
		jobs.append("garson")
	if level >= int(ROLES["kurye"]["unlock"]):
		jobs.append_array(["kurye", "kurye"])
	for job in ["asci", "kasiyer"]:
		if level >= int(ROLES[job]["unlock"]):
			jobs.append(job)
	return make_people(jobs, taken)


static func make_people(jobs: Array[String], taken: Array[Dictionary]) -> Array[Dictionary]:
	var used := taken.map(func(p: Dictionary) -> String: return p["name"])
	var list: Array[Dictionary] = []
	for job in jobs:
		var person := make_candidate(job)
		var names: Array = (NAMES[person["gender"]] as Array).filter(func(n: String) -> bool: return not used.has(n))
		person["name"] = names.pick_random()
		used.append(person["name"])
		list.append(person)
	return list


static func traits(person: Dictionary) -> String:
	return "%s • %s" % [SPEEDS[person["speed"]]["name"], WORK[person["work"]]["name"]]


## Aşçının / kasiyerin bir işi (pişirme hamlesi, sipariş alma) bitirme süresi.
static func work_time(person: Dictionary) -> float:
	return WORK_TIMES[person["speed"]]


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
