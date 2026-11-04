class_name Exchange
extends RefCounted

## Toptancı borsası: malzeme paket fiyatları gün içinde birkaç kez değişir
## (yavaşça normale döner), arada fırsatlar çıkar. Malzemelerin raf ömrü vardır;
## son kullanma tarihi geçen malzeme pişirilirse müşteri 1 yıldız verip gider.

## Raf ömrü (gün): alındığı gün + bu kadar gün taze kalır.
const SHELF_LIFE := { "tavuk": 3, "tavuk_sis": 3, "kofte": 2, "patates": 5, "kola": 8, "ayran": 4, "lahmacun": 2, "pizza": 2, "pide": 2 }
## Fırsatlar: ad -> [etiket, fiyat çarpanı]. "skt": tarihi yakın, ömrü 1 gün.
const DEALS := {
	"indirim": ["İNDİRİM", 0.65],
	"skt": ["SKT YAKIN", 0.5],
	"zam": ["ZAM", 1.3],
}
## Fiyatın taban fiyata göre en düşük / en yüksek oranı (fırsatlar hariç)
const MIN_FACTOR := 0.7
const MAX_FACTOR := 1.5
## Gün içinde fiyatların değiştiği saatler (dakika)
const TICKS := [12 * 60, 15 * 60, 18 * 60]
const HISTORY := 8


## Yeni bir ürün kaydı: taban fiyatta, fırsatsız.
static func fresh(id: String) -> Dictionary:
	var base: int = Items.PRODUCTS[id]["pack_price"]
	return { "factor": 1.0, "deal": "", "price": base, "history": [base] }


## Fiyatı bir adım oynatır: rastgele dalgalanır, yavaşça normale döner;
## bazen fırsat (indirim, tarihi yakın) ya da zam çıkar.
static func step(id: String, entry: Dictionary) -> Dictionary:
	var factor: float = entry.get("factor", 1.0)
	factor += (1.0 - factor) * 0.15 + randfn(0.0, 0.08)
	factor = clampf(factor, MIN_FACTOR, MAX_FACTOR)
	var roll := randf()
	var deal := ""
	if roll < 0.10:
		deal = "indirim"
	elif roll < 0.17:
		deal = "skt"
	elif roll < 0.24:
		deal = "zam"
	var base: int = Items.PRODUCTS[id]["pack_price"]
	var multiplier: float = DEALS[deal][1] if deal != "" else 1.0
	var price := maxi(1, roundi(base * factor * multiplier))
	var history: Array = entry.get("history", []).duplicate()
	history.append(price)
	while history.size() > HISTORY:
		history.pop_front()
	return { "factor": factor, "deal": deal, "price": price, "history": history }


## Son değişimin yüzdesi (önceki fiyata göre).
static func change_percent(entry: Dictionary) -> int:
	var history: Array = entry.get("history", [])
	if history.size() < 2:
		return 0
	var before: float = history[history.size() - 2]
	return roundi((float(history.back()) - before) / maxf(before, 1.0) * 100.0)


## Alınan paketin raf ömrü: tarihi yakın fırsatında 1 gün.
static func shelf_life(id: String, deal: String) -> int:
	return 1 if deal == "skt" else SHELF_LIFE.get(id, 3)
