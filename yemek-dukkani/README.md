# Köşe Dükkan (prototip)

Tasarım: [../fikirler/02-yemek-dukkani.md](../fikirler/02-yemek-dukkani.md) ·
Meshy modelleri: [MESHY.md](MESHY.md)

Godot 4.7, mobil renderer, dikey ekran.

## Çalıştırma

Godot `../tools/godot/` klasöründe (git'e eklenmez). Oyunu başlatmak için:

```bash
../tools/godot/Godot_v4.7.2-stable_win64.exe --path .
```

Editörde açmak için sonuna `--editor` ekle.

## Nasıl oynanır

Üç ekran var; alttaki butonlarla, parmağı sağa/sola kaydırarak ya da
masaüstünde ← → tuşlarıyla geçilir.

- **Market:** Çiğ malzeme ve içecek alınır (5'li paket).
- **Dükkan:** Müşteriler gelir, başlarının üstünde siparişleri ve sabır
  çubukları görünür. Sipariş hazırsa müşteriye ya da "Servis Et"e dokun.
  Müşteri ödeme yapar, yıldız ve yorum bırakır. Puan yükseldikçe daha sık
  müşteri gelir.
- **Mutfak:** Alttan malzeme seç; ızgaraya ya da fritöze konur. Ürünün rengi
  çiğden yanığa doğru değişir. Kıvam çubuğu yeşildeyken ürüne dokun. Erken
  alırsan az pişmiş, geç alırsan fazla pişmiş olur (müşteri yorumlarına
  yansır), çok geç kalırsan yanar ve çöpe gider.

## Yapı

Sahne `scripts/main.gd` içinde koddan kurulur. Üç ekran birbirinden uzak üç
istasyondur; kamera aralarında kısa bir kararmayla geçer.

| Dosya | Görevi |
|---|---|
| `main.gd` | İstasyonlar, kamera, ekran geçişi, dokunma / kaydırma |
| `hud.gd` | Tüm arayüz: üst bar, alt menü, paneller, sipariş kartları, yorumlar |
| `kitchen.gd`, `cook_slot.gd`, `cook_gauge.gd` | Izgara, fritöz, pişme ve kıvam göstergesi |
| `shop.gd`, `shop_customer.gd` | Müşteriler, sipariş, servis, puan ve yorumlar |
| `market.gd` | Market sahnesi (dekor) |
| `items.gd` | Ürün tanımları (fiyat, pişme süresi) ve modeller |
| `game_state.gd` | Para, stok, hazır ürünler, yorumlar (autoload) |
| `util.gd` | Şekil, materyal, arayüz stili yardımcıları |
