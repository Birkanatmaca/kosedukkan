# Fikir 01 — Issız Ada: Hayatta Kalma

> Durum: Fikir aşaması · Tarih: 2026-11-02
> Tür: Üstten kameralı (Brawl Stars tarzı) 3D hayatta kalma + üs kurma + action-RPG
> Platform: Mobil (yatay ekran) · Asset kaynağı: Meshy AI
> Referans: *Last Day on Earth* (zombi yerine vahşi doğa / ada teması)

## Özet

Gemi batar, karakter ıssız bir adanın kıyısına vurur. Elinde hiçbir şey yoktur.
Kaynak toplar, alet ve silah üretir, üs kurar, geceleri vahşi hayvanlara karşı
hayatta kalmaya çalışır. Adayı gezdikçe harita açılır (fog of war) ve
güçlendikçe daha tehlikeli bölgelere geçebilir.

**Çekirdek döngü:** Keşfet → topla / savaş → üret → güçlen → üssü geliştir → daha tehlikeli bölgeye geç

## Kamera ve kontrol

- Üstten, hafif eğik kamera (Brawl Stars benzeri), karakter 3D.
- Yatay ekran, sol joystick ile hareket, sağda saldırı / etkileşim / özel yetenek tuşları.

## Açılış (ilk 5 dakika)

Kıyıya vuruş → yerden dal ve taş toplama → ilk taş balta → ilk ateş → ilk gece.
Hem öğretici hem de oyunun tüm döngüsünü gösteren bir açılış.

## Harita

- Çok geniş harita, başta tamamen karanlık; gezilen yerler kalıcı olarak açılır.
- Bölgeler zorluk sırasıyla:
  1. **Sahil:** tavşan, yengeç (öğretici)
  2. **Orman kenarı:** yaban domuzu
  3. **Derin orman:** kurt sürüleri (uluyunca diğerlerini çağırır, birlikte saldırır)
  4. **Kayalık tepeler:** ayı (yavaş, ağır vurur, yere vurarak alan hasarı yapar)
  5. **Bataklık:** zehirli yaratıklar (zehir alanı bırakır)
  6. **Karlı dağ / harabeler:** alfa yaratıklar ve bölge boss'ları
- Bölge kapıları: kırılması gereken kaya, anahtar isteyen kapı, belirli seviye
  gerektiren kar fırtınası gibi doğal engeller. Oyuncu bölgeyi görür ama hazır
  olana kadar giremez.

## Kaynaklar ve alet kademeleri

| Kademe | Alet | Toplayabildiği | Bölge |
|---|---|---|---|
| 0 | Çıplak el | Dal, çakıl, böğürtlen | Sahil |
| 1 | Taş balta / kazma | Ağaç, taş kaya | Sahil + orman kenarı |
| 2 | Gelişmiş taş alet | Kalın ağaç, demir kaya | Derin orman |
| 3 | Demir alet | Sert ağaç, altın kaya | Kayalık tepeler |
| 4 | Altın / özel | Nadir kaynaklar | Dağ, harabeler |

- Kayalar görselden ayırt edilir: gri taş, pas kırmızısı damarlı demir, sarı damarlı altın.
- Ağaç ve kayalar bir süre sonra yeniden doğar (farm yapılabilir).
- Hayvanlardan deri, diş ve pençe düşer; bunlar üretimde kullanılır.

## Envanter

- Başlangıçta 8 slot, her seviyede +2 slot.
- Çantalar: deri çanta +4, ayı derisi çanta +6.
- Yığın limitleri: odun 20, taş 20, demir 10, altın 5.
- Ağırlık sistemi yok, sadece slot.

## Savaş ve ekipman

- Silah türleri: kılıç (hızlı, yakın), balta (yavaş, güçlü), yay (uzak), mızrak.
  Her birinin bir özel yeteneği var (Brawl Stars'taki süper yetenek gibi).
- Zırh: baş, gövde, ayak. Kalite seviyeleri: sıradan → nadir → epik.
- Örnek tarif: ayı derisi zırh.

## Üs kurma

- **Ev:** yaprak barınak → ahşap kulübe → taş ev. Yeniden doğma noktası ve uyku yeri.
- **Depo:** ahşap sandık (12 slot), demir sandık (24 slot); ileride tüccardan satın alma.
- **Savunma:** grid'e yerleştirilen ahşap çit, taş duvar, kapı, sivri kazık.
  Canları var, hasar alır, tamir edilir.
- **İstasyonlar:** kamp ateşi (yemek), tezgâh (alet), ocak (eritme), örs (silah ve zırh).

## Gece ve gündüz

- Bir gün yaklaşık 10–12 dakika: ~8 dk gündüz, ~3–4 dk gece.
- Gündüz: keşif, toplama, avlanma.
- Gece: görüş daralır (sadece meşale ve ateş çevresi aydınlık), kurt sürüleri
  üsse saldırır ve çitleri zorlar.
- Üs güvenliyse gece uyuyarak atlanabilir; dışarıda kalanı nadir gece kaynakları
  ve gece yaratıkları bekler.

## Hayatta kalma göstergeleri

Can, açlık, susuzluk. Sıcaklık yalnızca karlı bölgeye özel bir mekanik olabilir.

## Teknik notlar (performans)

- **Motor:** Unity (URP, mobil profil) önerildi; alternatif Godot 4. Henüz karar verilmedi.
- Chunk'lı harita: sadece karakterin çevresindeki parçalar aktif.
- Uzaktaki düşmanlar uyur; object pooling kullanılır.
- Ağaç, kaya ve çitler GPU instancing ile çizilir.
- Fog of war: düşük çözünürlüklü maske texture'ı ve shader.
- Tek yönlü güneş ışığı, toon shader; gölge sadece karakter ve düşmanlarda.
- Meshy modelleri: karakter 3–8k, prop 500–2k üçgen; texture 512–1024.

## İlk Meshy asset listesi

- Ana karakter (rigli: yürüme, koşma, saldırı, toplama, ölme)
- Hayvanlar: tavşan, domuz, kurt, ayı, alfa kurt
- Aletler ve silahlar: taş / demir balta ve kazma, kılıç, yay, mızrak
- Zırh setleri (2–3 kalite)
- Ortam: 5 ağaç, taş / demir / altın kayalar (2–3 varyasyon), çalı, kütük, sahil enkazı
- Üs: barınak, kulübe, sandık, çit, duvar, kapı, kamp ateşi, tezgâh, ocak, örs

## Yol haritası

1. **Prototip:** hareket, ağaç kesme, taş kırma, 8 slotlu envanter, basit üretim,
   gece/gündüz, küçük ada parçası, sadece kurt.
2. **Üs:** grid'e çit, sandık ve ev yerleştirme, gece kurt saldırısı.
3. **İlerleme:** demir ve altın, ocak ve örs, ayı, fog of war ile büyük harita.
4. **Cila:** bölgeler, boss'lar, ses, kaydetme ve yükleme, UI.
