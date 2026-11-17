# Viral TikTok ses klipleri — kaynak notu

## Kanonik klasör: `assets/audio/` (madde 17)

Bu klasördeki TÜM ses dosyaları kanonik kopyadır. `GameAudio` sabitleri YALIN
dosya adıdır (tam yol değil — Mac birleştirme kuralı, asla bozulmaz); oynatma
anında `AudioManager._normalizeAssetPath` yalın adı `assets/audio/` ile
birleştirir. Eski `assets/design/sounds/` önekiyle gelen tam yollar da aynı
kanonik klasöre çevrilir, böylece eski yol kullanan çağrılar bile tek
klasörden çalar.

`assets/design/sounds/` altındaki 50 mp3 hâlâ diskte duruyor; bu klasördeki
dosyaların bayt birebir kopyasıdır (isim listesi + md5 ile doğrulandı,
2026-11-18). Ancak pubspec'teki `design/sounds/` girişi KALDIRILDI:
`InsectTier.soundFile`/`voiceFile` (`lib/models/insect_tier.dart`) yalın
dosya adıdır ve `AudioManager._normalizeAssetPath` ile `assets/audio/`'ya
çözülür; `ZeroJankPreloader.criticalSoundAssets`
(`lib/services/zero_jank_preloader.dart`) artık `assets/audio/`'yu gösterir.
Kodda `design/sounds/`'a kalan göndermeler yalnızca yorumlar ile
`AudioManager`'ın eski yolları kanonik klasöre çeviren uyumluluk katmanıdır;
hiçbir ses o klasörden yüklenmez. Eski klasördeki kopyaların silinmesi,
testler geçtikten sonraya bırakıldı — silme henüz YAPILMADI. Yeni klip
ASLA `design/sounds/` altına eklenmez. Bütünlük testleri
(`test/asset_integrity_test.dart`, grup 2) yalnız kanonik klasörü denetler.

Aşağıdaki 7 klip TikTok videolarından kesildi (mp3, 128k).

Klip → kaynak eşleşmesi (`GameAudio` sabiti parantez içinde):

| Dosya | Kaynak video | Kesim aralığı (sn) | Not |
|---|---|---|---|
| `mezarina_siktigim.mp3` (`mezarinaSiktigim`) | original_4 (video4) | 12.08–13.76 | "mezarına sıçtığım" kesin |
| `diva_sinyal.mp3` (`divaSinyal`) | sim_hamamdaralem_7697726382641614100 | 3.59–5.89 | Diva repliği 1 |
| `diva_yasla.mp3` (`divaYasla`) | sim_hamamdaralem_7697726382641614100 | 6.23–9.69 | Diva repliği 2 |
| `lululu_nakarat.mp3` (`lululuNakarat`) | original_3 (video3) | 0–2.9 | Lülülü nakaratı |
| `duktur.mp3` (`duktur`) | original_2 (video2) | 0–14 | Duktur repliği |
| `kanka.mp3` (`kanka`) | original_5 (video5) | 5.4–13.9 | Kanka ikilisi |
| `husur_aday.mp3` (`husurAday`) | sim_bocekalem.i_7704406490743901448 | 2.16–3.62 | **DOĞRULANMAMIŞ ADAY** — bkz. aşağıda |

## UYARI: `husur_aday.mp3` doğrulanmamış adaydır

63 transkriptin hiçbirinde "hışır" kelimesi geçmiyor. Bu klip, benzer bir
klipte 2,64 sn'de transkripte "huşur" diye geçen sesin kesimidir; "hışır"
olduğu kulakla teyit EDİLMEDİ. Hışır karakterinin sesi olarak bu aday
bağlıdır; gerçek "hışır" sesi bulunursa/tespit edilirse bu dosya (ve
`GameAudio.husurAday` sabiti) yenisiyle değiştirilmelidir.

6. kaynak link (ZSpnBpRLe) TikTok girişi istediği için indirilemedi;
"hışır" sesinin o videoda olma ihtimali var.

## Telif notu

Selçuk'un kararı (2026-11-17): sesler yapay zekâ üretimidir, telif kaygısı
yoktur, aynen kullanılacaktır.

## Kullanım

Oynatma metotları `lib/services/audio_manager.dart` içindedir:
`playMezarinaSiktigim`, `playDivaSinyal`, `playDivaYasla`,
`playLululuNakarat`, `playDuktur`, `playKanka`, `playHusurAday`.
Tümü ses ayarlarına (`voiceEnabled` + `sfxEnabled`) saygı duyar.

Yeni klip eklerken: dosyayı YALNIZ `assets/audio/` altına koy, `GameAudio`'ya
yalın dosya adıyla sabit ekle, `viralOneShots`/`allAssets` listesine dahil et.
`assets/design/sounds/` altına kopya ekleme.
