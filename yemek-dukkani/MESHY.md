# Meshy AI Model Listesi

Oyundaki basit şekillerin yerine geçecek modeller. Öncelik sırasına göre
dizildi: en üstteki modeller görünüme en çok katkıyı yapar.

## Genel kurallar

**Hepsi aynı stilde olmalı.** Her promptun sonuna aşağıdaki stil cümlesini
aynen ekle. Stil karışırsa oyun ucuz görünür.

> **Stil cümlesi:** `stylized cartoon mobile game asset, smooth simple shapes, soft rounded edges, warm vibrant colors, hand-painted texture look, clean and cute, single object, no base, no background`

Meshy ayarları:

- Promptları **İngilizce** yaz (Meshy İngilizcede daha iyi sonuç veriyor).
- **Remesh / hedef poligon** ayarını aç. Hedefler:
  - Yiyecek: 1.000–2.000 üçgen
  - Mobilya ve cihaz: 2.000–5.000 üçgen
  - Karakter: 5.000–8.000 üçgen
- Texture çözünürlüğü: karakterler 1024, diğerleri 512–1024.
- İndirme formatı: **GLB**.
- Aynı nesneden 4 öneri gelirse en sade ve en "oyuncak gibi" olanı seç;
  çok detaylı olanlar küçük ekranda kirli görünür.

Dosyaları `yemek-dukkani/models/` altına aşağıdaki **dosya adlarıyla** koy,
gerisini ben bağlarım.

## Yiyecekler hakkında önemli not

Pişme renk değişimini oyun kendisi yapacak (çiğ → kıvamında → yanık).
Bunun için yiyecekleri **tam kıvamında, altın-kahverengi halleriyle** üret.
Çiğ ve yanık versiyon üretme.

---

## 1. Öncelik: yiyecekler

| Dosya | Prompt |
|---|---|
| `models/food/tavuk.glb` | `a single grilled chicken drumstick, golden brown crispy skin, small white bone end` + stil |
| `models/food/kofte.glb` | `five separate oblong Turkish grilled köfte meatballs, slightly flattened and plump, each with a few bold simple brown grill marks, arranged compactly in a shallow 3-over-2 group with small gaps, no plate, grill, tray, side dishes, or background` + stil |
| `models/food/patates.glb` | `a small pile of loose golden french fries, thick cut` + stil |
| `models/food/kola.glb` | `a red paper soda cup with white lid and a striped straw` + stil |

## 2. Öncelik: mutfak cihazları

| Dosya | Prompt |
|---|---|
| `models/kitchen/izgara.glb` | `a wide flat rectangular charcoal grill for a restaurant kitchen, black metal grates, glowing orange coals underneath, three control knobs on the front, top view friendly` + stil |
| `models/kitchen/fritoz.glb` | `a stainless steel commercial deep fryer with two square wire baskets side by side, golden oil, black basket handles facing front` + stil |
| `models/kitchen/tezgah.glb` | `a long stainless steel restaurant kitchen counter, simple box shape, metal top, grey cabinet doors` + stil |
| `models/kitchen/servis_rafi.glb` | `a stainless steel restaurant heated pass shelf with red heat lamp bar above it, long and thin` + stil |

## 3. Öncelik: müşteriler

Karakterleri **T-pose** ile üret, sonra Meshy'nin otomatik rig (Auto-Rig)
özelliğiyle iskelet ekleyip **Idle** (bekleme) ve **Walking** (yürüme)
animasyonlarını seç. 4–6 farklı karakter yeterli.

| Dosya | Prompt |
|---|---|
| `models/characters/musteri_1.glb` | `a cheerful young woman, casual blue t-shirt and jeans, short brown hair, chibi proportions with slightly big head, T-pose` + stil |
| `models/characters/musteri_2.glb` | `a friendly middle-aged man with a mustache, green sweater, dark trousers, chibi proportions, T-pose` + stil |
| `models/characters/musteri_3.glb` | `a teenage boy with a red hoodie and sneakers, messy black hair, chibi proportions, T-pose` + stil |
| `models/characters/musteri_4.glb` | `an elderly woman with grey hair in a bun, purple cardigan, chibi proportions, T-pose` + stil |
| `models/characters/musteri_5.glb` | `a young businessman in a light blue shirt and loose tie, chibi proportions, T-pose` + stil |
| `models/characters/musteri_6.glb` | `a young woman with curly hair and a yellow summer dress, chibi proportions, T-pose` + stil |

## 4. Öncelik: dükkan

| Dosya | Prompt |
|---|---|
| `models/shop/servis_tezgahi.glb` | `a long wooden fast food service counter with a white marble top, warm orange wood front panels` + stil |
| `models/shop/kasa.glb` | `a small modern cash register with a little screen` + stil |
| `models/shop/masa.glb` | `a small round wooden cafe table with one central leg` + stil |
| `models/shop/tabure.glb` | `a round cafe stool with an orange cushion` + stil |
| `models/shop/bitki.glb` | `a potted green leafy plant in a terracotta pot` + stil |
| `models/shop/lamba.glb` | `a hanging pendant lamp with a warm yellow glass shade` + stil |
| `models/shop/kapi.glb` | `a wooden shop entrance door with a small glass window and brass handle` + stil |

## 5. Öncelik: market

| Dosya | Prompt |
|---|---|
| `models/market/raf.glb` | `a wooden storage shelf unit with three shelves, empty` + stil |
| `models/market/kasa_tavuk.glb` | `a wooden crate full of raw chicken drumsticks` + stil |
| `models/market/kasa_kofte.glb` | `a wooden crate full of raw meatballs on paper` + stil |
| `models/market/kasa_patates.glb` | `a wooden crate full of raw potatoes` + stil |
| `models/market/kasa_kola.glb` | `a plastic crate full of red soda cans` + stil |

## Sonra gelecekler

Paket servis eklendiğinde: kâğıt poşet, burger kutusu, patates kutusu, kurye
motoru. Menüye yeni ürünler geldikçe (pizza, döner, simit…) aynı stil
cümlesiyle üretilecek.
