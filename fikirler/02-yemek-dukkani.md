# Fikir 02 — Kendi Dükkanın: Yemek Hazırla, Servis Et, Büyü

> Durum: Fikir aşaması · Tarih: 2026-11-02
> Tür: 3D arcade-idle yemek dükkanı / restoran yönetimi
> Platform: Mobil, **dikey ekran** · Asset kaynağı: Meshy AI
> Referanslar: *Pizza Ready!*, *My Perfect Hotel*, *Cooking Fever*, *Good Pizza Great Pizza*

## Özet

Oyuncu kendi dükkanını açar: ismini koyar, menüsünü kataloğun tamamından
**istediği gibi** seçer (burger, pizza, döner, simit, tatlı, kahve…). Siparişleri
hazırlar, paketleyip kuryeye verir ya da masaya götürür. Kazandıkça cihazlarını,
kapasitesini ve dükkanını geliştirir; seviye atladıkça menüsüne yeni ürün ekleyebilir.

**Çekirdek döngü:** Sipariş gelir → hazırla → paketle / servis et → para + XP → geliştir → daha çok ve daha çeşitli sipariş

**Ana fark:** Sabit bir tema yok. Her oyuncunun menüsü, dolayısıyla dükkanı ve
cihazları farklı. "Benim dükkanım" hissi.

## Kontrol

- Dikey ekran, tek el.
- Karakter joystick ile dükkanda gezer (Pizza Ready! tarzı). Cihazın yanından
  geçince hazır ürünler eline yığılır; tezgâha, paket masasına, kuryeye veya
  müşteri masasına bırakır.
- Kamera sabit, hafif eğik üstten bakış.

## Başlangıç akışı

1. **Kayıt:** Misafir olarak başla; istenirse Google / Apple hesabı ile bağla (bulut kayıt).
2. **Dükkan ismi:** Oyuncu yazar. Küfür filtresi gerekli (isim sıralamalarda ve
   arkadaş ziyaretlerinde görünecek).
3. **Menü seçimi:** Tüm katalogdan kart seçimi. Her kartta fiyat, hazırlama
   süresi, gereken cihaz ve popülerlik yazar. Kategori karıştırmak serbest
   (burger + simit + kahve olabilir).
   - Yemek: başlangıçta en az 2, en fazla 4 *(sayılar netleştirilecek)*
   - İçecek: başlangıçta en az 2, en fazla 4 *(sayılar netleştirilecek)*
   - Fazlası için seviye atlamak gerekir.
4. **Dükkan açılır:** Seçilen ürünlerin gerektirdiği cihazlar otomatik yerleşir.
5. **Öğretici:** İlk 3–4 dakika sadece 1 yemek + 1 içecek ile oynatılır, diğer
   seçilen ürünler ardından devreye girer (yeni oyuncu bunalmasın diye).

## Ürün kataloğu (taslak)

Her ürün bir cihaz ister. Aynı cihazı paylaşan ürünler seçmek ucuzdur; farklı
cihazlar gerektiren menü daha pahalı ama daha çeşitlidir.

| Kategori | Ürünler | Cihaz(lar) |
|---|---|---|
| Burger | Klasik burger, cheeseburger, tavuk burger, vegan burger, patates kızartması | Izgara, fritöz |
| Pizza | Margarita, karışık, sucuklu, ton balıklı | Pizza fırını |
| Türk sokak | Döner dürüm, lahmacun, pide, kokoreç, tost | Döner ocağı, taş fırın, tost makinesi |
| Fırın | Simit, poğaça, açma, kruvasan | Vitrin (hazır), fırın |
| Tatlı | Künefe, baklava, waffle, dondurma, cheesecake | Künefe ocağı, vitrin, waffle makinesi, dondurma dolabı |
| Uzak Doğu | Suşi, noodle, bao | Suşi tezgâhı, wok |
| Sıcak içecek | Çay, Türk kahvesi, latte, sıcak çikolata | Semaver, cezve ocağı, espresso makinesi |
| Soğuk içecek | Ayran, kola, limonata, taze portakal suyu, milkshake, smoothie | Buzdolabı, sıkma makinesi, blender |

Lansman için gerçekçi hedef: ~20–25 ürün. Diğerleri güncellemelerle eklenir.

## Siparişler

- **Masa siparişi:** Müşteri oturur, sipariş verir, bekler. Servis edilince
  yer, öder, masayı kirli bırakır (temizlenmesi gerekir).
- **Paket sipariş:** Kurye kapıda bekler. Ürünler kutulanır / poşetlenir.
- **Sabır çubuğu:** Hızlı servis bahşiş getirir; geç kalınırsa müşteri kızıp gider.
- **Özel siparişler:** Ara sıra yüksek ödüllü büyük siparişler (parti siparişi,
  ofis siparişi).

## Gelişim sistemi

**Dükkan seviyesi (satıştan XP)** — kilit açar:
- Yeni menü slotları (ör. seviye 5'te +1 yemek, seviye 8'de +1 içecek)
- Yeni ürünler ve cihaz türleri
- Eleman tutabilme, yeni dükkan alanları

**Para** — geliştirir:
- **Cihazlar:** hız (fırın 30 sn → 15 sn) ve kapasite (aynı anda 2 → 4 ürün)
- **Oturma kapasitesi:** masa sayısı, masa başına sandalye
- **Kuyruk kapasitesi:** kapıda bekleyebilen müşteri sayısı
- **Depo:** malzeme stoğu; malzeme biterse ürün satılamaz, tedarik gerekir
- **Kurye kapasitesi:** aynı anda alınabilen paket sipariş sayısı
- **Dükkan büyüklüğü:** duvar yıkma, üst kat, bahçe / teras
- **Dekorasyon:** müşteri memnuniyeti ve bahşişi artırır

**Elemanlar:** garson, aşçı, kurye, kasiyer, temizlikçi. Her birinin hızı ayrıca
geliştirilir; dükkan zamanla kendi kendine döner.

**Menü değişikliği:** Ürün çıkarıp yenisini eklemek serbest, ama yeni cihaz
gerekiyorsa onun bedeli ödenir.

**İleri aşama:** Dükkan dolunca yeni şube / mekân (sahil büfesi, AVM, havalimanı).

## Teknik notlar (performans)

- Tek dükkan sahnesi, sabit kamera; ekranda ~30–50 obje. Düşük segment
  telefonlarda bile rahat.
- Müşteri ve elemanlar için object pooling; aynı karakter modelinin renk /
  aksesuar varyasyonları.
- Toon shader, baked ışık.
- Meshy: ürünler 300–1.500 üçgen, cihazlar 1–3k, karakterler 3–6k; texture 512–1024.
- Motor kararı açık (Unity önerildi, Godot alternatif).

## Meshy asset listesi (ilk sürüm)

- Oyuncu karakteri (yürüme, taşıma, servis animasyonları)
- Müşteri modelleri (4–6 baz model + varyasyon), kurye + motor
- Seçilen lansman ürünlerinin modelleri + paket / kutu / poşet / tepsi
- Cihazlar: ızgara, fritöz, pizza fırını, döner ocağı, vitrin, semaver,
  espresso makinesi, buzdolabı, blender vb.
- Dükkan: masa, sandalye, tezgâh, kasa, paket masası, kapı, dekor objeleri

## Yol haritası

1. **Prototip:** karakter hareketi, 1 cihaz + 1 ürün, masa siparişi, para.
2. **Çekirdek:** paket sipariş + kurye, sabır çubuğu, cihaz geliştirme, 6–8 ürün.
3. **Menü sistemi:** dükkan ismi, menü seçimi, seviye ile slot açma, ürüne göre cihaz yerleşimi.
4. **Büyüme:** elemanlar, dükkan genişletme, depo ve tedarik, dekorasyon.
5. **Cila ve yayın:** hesap / bulut kayıt, ses, UI, reklam ve uygulama içi satın alma.

## Açık sorular

- Başlangıç menü sayıları tam olarak ne olacak?
- Para birimleri: sadece para mı, yoksa premium para (elmas) da olacak mı?
- Arkadaş dükkanını ziyaret / sıralama olacak mı?
