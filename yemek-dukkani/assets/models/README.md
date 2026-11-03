# 3D modeller (Meshy AI, GLB)

## İsimlendirme kuralı

`<klasör>/<id>[_varyant].glb`

- Küçük harf, Türkçe karakter yok (ş→s, ı→i, ğ→g, ü→u, ö→o, ç→c), boşluk yerine `_`.
- Yiyecek ve içeceklerde `id`, `Items.PRODUCTS` anahtarıyla aynı olur (`patates`, `tavuk_sis`).
- Aynı objenin farklı hali `_varyant` alır: `sandalye_eski` (harabe salon için).

| Klasör | İçerik |
|---|---|
| `food/` | Yiyecek, içecek, ambalaj |
| `equipment/` | Mutfak cihazları, kasa, POS, tepsi |
| `furniture/` | Masa, sandalye, saksı, raf |
| `lighting/` | Tavan ve duvar lambaları |
| `characters/` | Müşteri, garson (rig + animasyon) |

## Optimizasyon

Meshy çıktıları çok ağır geliyor (200–850 bin üçgen, 2K–4K doku). Hepsi
Blender'da (headless betikle) şu işlemlerden geçirildi:

- Dikişlerde ayrık noktalar birleştirildi, sonra üçgen sayısı düşürüldü:
  yiyecek ~1.500–3.000, mobilya/cihaz ~3.000–5.000, karakter ~8.000.
- Dokular 512 (yiyecek, küçük obje) ve 1024 (kasa, masa, karakter) JPEG'e indirildi;
  metal/pürüzlülük ve normal dokuları atıldı.
- Gerçek boyuta ölçeklendi, pivot tabanın ortasına alındı (Godot'ta 1 birim = 1 m).
- Karaktere yüz mimikleri shape key olarak eklendi: `blink`, `brow_angry`,
  `brow_up`, `mouth_close`, `mouth_frown`, `mouth_open`.

Toplam: 289 MB → 5 MB. Yeni gelen modeller aynı işlemden geçirilmeli.

## Kaynak listesi

| Dosya | Meshy dosyası | Not |
|---|---|---|
| `food/tavuk_sis.glb` | minced_meat_1103075738 | Şişte tavuk |
| `food/kajun_tavuk.glb` | Chicken_Curls_1103075533 | Çıtır kajun tavuk |
| `food/kofte.glb` | grilled_meatball_mode_1103123242 | Tek köfte, ızgara izi üstte (`flatflip`). Oyunda bir porsiyon = yan yana 3 köfte |
| `food/patates.glb` | Hyper_realistic_pile_1103075950 | Patates kızartması yığını |
| `food/icecek_bardak.glb` | A_hyper_realistic_4K_1103080140 | Pipetli bardak. Üstünde marka logoları var, yeniden dokulanmalı |
| `equipment/tepsi.glb` | Red_Tray_1103080346 | Kırmızı servis tepsisi |
| `equipment/kasa.glb` | Touchscreen_POS_Syste_1103081119 | Dokunmatik ekranlı yazar kasa + çekmece |
| `equipment/pos.glb` | Pedestal_Mounted_POS_1103081124 | Ayaklı kart POS cihazı |
| `furniture/masa.glb` | Wood_Top_Table_1103080737 | Tek ayaklı ahşap masa |
| `furniture/sandalye.glb` | Green_chair_1103080631 | Yeşil plastik sandalye. Meshy'de dokusuz indi, Blender'da düz yeşil renk verildi |
| `furniture/sandalye_eski.glb` | Rusty_chair_1103080623 | Paslı sandalye, harabe hali |
| `lighting/tavan_lambasi.glb` | lampe_1103080517 | Sarkıt tavan lambası |
| `lighting/duvar_lambasi.glb` | Wall_lamp_1103080524 | Duvar apliği |
| `characters/erkek.glb` | Smiling_Boy_in_Orange_Jacket_20261103 (mixamo) | Bütün erkek müşterilerin modeli. Oyunda %10 büyütülür (~1.87 m). Animasyonlar: Walking, Talk_with_Hands_Open (bekleme), Stand_Talking_Angry (kızgın), `_01a1a095…` (oturma). Kullanılmayanlar: Running, `_01a1a091…` (kök hareketli yürüme), Step_to_Sit_Transition |
| `characters/kadin.glb` | Sunny_Welcome_20261103 (mixamo) | Bütün kadın müşterilerin modeli. Oyunda %6 büyütülür (~1.80 m). Bekleme animasyonu Talk_Passionately; diğerleri erkekle aynı |
| `characters/kadin_maske.png` | `color_mask.py ... kadin` | Renk bölgeleri: R ten, G saç, B hırka, A pantolon |
| `characters/temizlikci_erkek.glb` | Friendly_Garden_Helper_20261103 (mixamo) | Erkek temizlikçi. Yüz mimiği yok. Animasyonlar: Walking, `_01a1a125…` (yer süpürme), `_01a1a138…` (masa silme), `_01a1a13a…` (cam silme). Bekleme animasyonu yok (yürümenin ilk karesinde durur) |
| `characters/temizlikci_kadin.glb` | Friendly_Cleaner_20261103 (mixamo) | Kadın temizlikçi. Animasyonlar ve aletler erkek temizlikçiyle aynı |
| `characters/temizlikci_erkek_maske.png`, `_maske_2.png` (kadın için de aynı adlarla) | `color_mask.py ... temizlikci` | 1. maske: ten, saç, gömlek, pantolon. 2. maske: R önlük, G eldiven (dükkan boyasına göre boyanır) |
| `characters/erkek_maske.png` | `tools/blender/color_mask.py` ile üretildi | Renk bölgeleri: R ten, G saç, B ceket, A pantolon. `CharacterSkin` her müşteriyi bu maskeyle farklı boyar |

## Blender betikleri (`tools/blender/`)

```
blender -b --factory-startup --python tools/blender/optimize.py -- <kaynak.glb> <hedef.glb> <üçgen> <doku_px> <h|l|flat> <metre> <önizleme.png> [renk_hex]
blender -b --factory-startup --python tools/blender/export_character.py -- <kaynak.glb> <hedef.glb> <erkek|kadin|yok>
blender -b --factory-startup --python tools/blender/color_mask.py -- <karakter.glb> <maske.png> 512 <erkek|kadin|temizlikci>
```

`h`: yükseklik `metre` olur, `l`: en uzun yatay kenar, `flat`: kenarı üstünde duran objeyi yatırır, `flatflip`: yatırır ve ön yüzünü yukarı çevirir.
Dokusuz modellere `renk_hex` (ör. `4f9a52`) düz renk verir. Karakterlerin yüz noktaları `faces.py` içindeki `PROFILES`'ta; yeni karakter için yüzün yakın plan render'ından ölçülüp eklenir.
