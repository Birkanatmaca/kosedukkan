class_name Rewards
extends RefCounted

## Giriş serisi ve "sen yokken" kazancı.
##
## Giriş serisi: oyun her açıldığında bugünün tarihi bakılır. Dün de girildiyse seri
## bir artar, bir gün atlandıysa 1'e döner. Her gün bir kez ödül alınır; 7 günlük
## döngünün son günü büyük sandıktır. Ödüller seviyeyle büyür.
##
## Sen yokken: kasiyer ve aşçı tutulmuşsa oyun kapalıyken (ya da arka plandayken)
## dükkan kendi kendine satış yapar. Her satış stoktan malzeme harcar; malzeme
## bitince satış durur. En fazla OFFLINE_MAX_MINUTES dakika sayılır.

const STREAK_DAYS := [
	{ "money": 30, "xp": 0 },
	{ "money": 45, "xp": 10 },
	{ "money": 60, "xp": 15 },
	{ "money": 80, "xp": 20 },
	{ "money": 100, "xp": 30 },
	{ "money": 130, "xp": 40 },
	{ "money": 220, "xp": 80 },
]
## Sen yokken: en fazla bu kadar dakika sayılır, bir satış ortalama bu kadar dakika sürer.
const OFFLINE_MAX_MINUTES := 180.0
const OFFLINE_SALE_MINUTES := 4.0
## Bundan kısa aradan sonra rapor çıkmaz (dakika).
const OFFLINE_MIN_MINUTES := 2.0


# --- Giriş serisi ------------------------------------------------------------------

## Bugünün girişini işler (oyun açılınca ve arka plandan dönünce).
static func check_login() -> void:
	var today := Time.get_date_string_from_system()
	if GameState.last_login_day == today:
		return
	var gap := _days_between(GameState.last_login_day, today)
	GameState.login_streak = GameState.login_streak + 1 if gap == 1 else 1
	GameState.last_login_day = today


static func can_claim_streak() -> bool:
	return GameState.setup_done and GameState.login_streak > 0 \
		and GameState.streak_claimed_day != Time.get_date_string_from_system()


## Serinin döngüdeki günü (0–6)
static func streak_index() -> int:
	return (maxi(GameState.login_streak, 1) - 1) % STREAK_DAYS.size()


## Döngüdeki bir günün ödülü (seviyeyle büyür).
static func streak_reward(index: int) -> Dictionary:
	var base: Dictionary = STREAK_DAYS[index]
	var factor := 1.0 + 0.15 * (GameState.level - 1)
	return { "money": snappedi(roundi(base["money"] * factor), 5), "xp": roundi(base["xp"] * factor) }


static func claim_streak() -> Dictionary:
	if not can_claim_streak():
		return {}
	var reward := streak_reward(streak_index())
	GameState.streak_claimed_day = Time.get_date_string_from_system()
	GameState.money += reward["money"]
	GameState.day_stats["gifts"] = int(GameState.day_stats.get("gifts", 0)) + reward["money"]
	GameState.add_xp(reward["xp"])
	return reward


static func _days_between(from: String, to: String) -> int:
	if from == "":
		return 999
	var a := Time.get_unix_time_from_datetime_string(from)
	var b := Time.get_unix_time_from_datetime_string(to)
	return roundi((b - a) / 86400.0)


# --- Sen yokken ------------------------------------------------------------------

## Kasiyer ve aşçı varsa dükkan sen yokken de çalışır.
static func staff_ready() -> bool:
	return Staff.count(GameState.staff, "kasiyer") > 0 and Staff.count(GameState.staff, "asci") > 0 \
		and GameState.upgrade_level("register2") > 0


## seconds kadar süre yokken yapılan satışları işler; rapor döner (boşsa rapor yok):
## { minutes, served, revenue, xp, used: { ürün: adet }, out_of_stock: bool }
static func run_offline(seconds: float) -> Dictionary:
	var minutes := seconds / 60.0
	if not GameState.setup_done or minutes < OFFLINE_MIN_MINUTES or not staff_ready():
		return {}
	minutes = minf(minutes, OFFLINE_MAX_MINUTES)
	# Hızlı kasiyer ve aşçı daha çok müşteriye yetişir.
	var speed := 0
	for person in GameState.staff:
		if Staff.role(person) in ["kasiyer", "asci"]:
			speed += int(person["speed"])
	var interval := OFFLINE_SALE_MINUTES / (0.75 + 0.15 * speed)
	var sales := floori(minutes / interval)
	var report := { "minutes": roundi(minutes), "served": 0, "revenue": 0, "xp": 0, "used": {}, "out_of_stock": false }
	for i in sales:
		var order := Progression.random_order(GameState.level)
		var items := _sellable(order)
		if items.is_empty():
			# İstenen bitti: müşteri stokta kalan başka bir şeyi alır.
			var left := Items.unlocked_ids().filter(func(id: String) -> bool: return not _sellable({ id: 1 }).is_empty())
			if not left.is_empty():
				items = { left.pick_random(): 1 }
		if items.is_empty():
			report["out_of_stock"] = true
			break
		var price := 0
		for id in items:
			for n in int(items[id]):
				_consume(id)
				price += Items.price(id)
			report["used"][id] = int(report["used"].get(id, 0)) + int(items[id])
		report["served"] += 1
		report["revenue"] += price
		report["xp"] += roundi(Progression.sale_xp(items.size(), 4) * 0.3)
		GameState.day_stats["revenue"] += price
		GameState.day_stats["served"] += 1
	if report["served"] == 0 and not report["out_of_stock"]:
		return {}
	GameState.money += report["revenue"]
	GameState.add_xp(report["xp"])
	GameState.stock_changed.emit()
	GameState.prepared_changed.emit()
	return report


## Siparişin stokta olan kısmı (hiçbiri yoksa boş).
static func _sellable(order: Dictionary) -> Dictionary:
	var items := {}
	for id in order:
		var have := GameState.available(id) + (int(GameState.stock[id]) if GameState.prepared.has(id) else 0)
		var n := mini(int(order[id]), have)
		if n > 0:
			items[id] = n
	return items


## Hazır ürün varsa ondan, yoksa stoktan bir tane düşer.
static func _consume(id: String) -> void:
	if GameState.prepared.has(id) and not (GameState.prepared[id] as Array).is_empty():
		(GameState.prepared[id] as Array).pop_front()
	else:
		GameState.take_stock_item(id)
