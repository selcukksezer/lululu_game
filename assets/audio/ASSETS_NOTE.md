# Viral TikTok ses klipleri — kaynak notu

Bu klasördeki `*_siktigim` / `diva_*` / `lululu_nakarat` / `duktur` / `kanka` /
`husur_aday` klipleri TikTok videolarından kesildi (mp3, 128k). Her klip aynı
isimle `assets/design/sounds/` altında da bulunur; iki klasör de pubspec'te
bildirilir, `GameAudio.allAssets` bütünlük testleri iki klasörü de denetler.

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
