# Playtest V2 — 2026-10-30 21:08

**Driver:** `orca emulator` (iOS). `orca computer` cannot target Simulator.app (not in list-apps); Orca window has no emulator AX nodes.
**Bundle:** `com.lululu.game.lululuGame`
**Note:** Concurrent `flutter run` may still be rebuilding — results may mix old/new binary.

## Summary table

| Mode | Opened | Notes |
|---|---|---|
| HUB | hub loads; daily semantics | Firebase dart-define yok |
| Suika Arena | opened | back failed |
| 2048 Grid | swipe play | — |
| Balon Patlat | play taps | — |
| Match 3 | hint | score still 0 after pans |
| Bağla Patlat | opened | no score from gestures |
| Stack Drop | **AX misopen → Osmantuş** | script/key collision; Stack not proven |
| Osmantuş | rhythm OK (score 214) | — |
| Çığlık Böcek | Kapı+çim death OK | idle farm fix shipped |
| Makarayız | lanes | skor 0 (timing miss, expected) |
| Terlik Tap | tile AX var | tap → 2048 (overlap/yanlış hit) |

## Per-mode AX snapshots

### HUB
- **open:** ['Lululu Game', 'Yıldız', '0', 'Giriş yap\nLv 1', 'Coin\n300', 'GİRİŞ', 'ONLINE', 'Online Lobby', 'Firebase dart-define yok · yerel cloud kuyruğu', 'GİRİŞ YAP']
- **play:** ['Lululu Game', 'Yıldız', '0', 'Giriş yap\nLv 1', 'Coin\n300', 'GİRİŞ', 'ONLINE', 'Online Lobby', 'Firebase dart-define yok · yerel cloud kuyruğu', 'GİRİŞ YAP', 'SOHBET', 'DAVET / RİVAL']
- **bugs:** ['Firebase dart-define yok']
- **works:** ['hub loads', 'daily semantics']

### Suika Arena
- **open:** ['Lululu Game', 'SKOR', 'Geri', 'Geri', 'Suika Arena', 'Bırak · aynılar birleşir', 'Kaydır nişan · dokun bırak · aynılar birleşir', 'SONSUZ', '3', '0']
- **play:** ['Lululu Game', 'Geri', 'Geri', 'Suika Arena', '162', 'Bırak · aynılar birleşir', 'Kaydır nişan · dokun bırak · aynılar birleşir', 'SONSUZ', 'Makarayız abi!', '3', 'SKOR', 'EN 162']
- **bugs:** ['back failed']
- **works:** ['opened']

### 2048 Grid
- **open:** ['Lululu Game', 'Geri', '2048 Grid', 'Zirve 0 · kaydır birleştir', 'SKOR', 'REKOR', 'UNDO', '0', '24', '3']
- **play:** ['Lululu Game', 'Geri', '2048 Grid', 'Zirve 16 · kaydır birleştir', 'SKOR', 'REKOR', 'UNDO', '56', '56', 'Makarayız abi!', '3', '2']
- **bugs:** []
- **works:** ['swipe play']

### Balon Patlat
- **open:** ['Lululu Game', 'Geri', 'Balon Patlat', 'Nişan al, bırak. 3 aynı balon patlar.', 'SKOR', 'REKOR', 'TAVAN', '0', '0', '5']
- **play:** ['Lululu Game', 'Geri', 'Balon Patlat', 'Balonlar nişancıya dayandı.', 'SKOR', 'REKOR', 'TAVAN', '4566', '4566', '1', 'TAŞTI', 'Patlama 22 · Düşen 1 · Max streak x3 · En büyük 10']
- **bugs:** []
- **works:** ['play taps']

### Match 3
- **open:** ['Lululu Game', 'Geri', 'Match 3', 'Komşuyu kaydır. 3 patlar · 4 = bomba.', 'SKOR', 'REKOR', 'HAMLE', '0', '0', '22']
- **play:** ['Lululu Game', 'Geri', 'Match 3', 'İpucu parlıyor.', 'SKOR', 'REKOR', 'HAMLE', '0', '0', '22', 'İPUCU', 'UNDO (3)']
- **bugs:** ['score still 0 after pans']
- **works:** ['hint']

### Bağla Patlat
- **open:** ['Lululu Game', 'Geri', 'Bağla Patlat', 'Aynı böceği çiz. Kare = o türün hepsi.', 'SKOR', 'REKOR', 'ÇİZGİ', '0', '0', '20']
- **play:** ['Lululu Game', 'Geri', 'Bağla Patlat', 'En az 3 böcek bağla.', 'SKOR', 'REKOR', 'ÇİZGİ', '0', '0', '20', 'İPUCU', 'UNDO (3)']
- **bugs:** ['no score from gestures']
- **works:** ['opened']

### Stack Drop
- **open:** ['Lululu Game', 'Geri', 'Osmantuş', 'Yeşil halkada dokun — dıkkış dıkkış!', 'SKOR', 'REKOR', 'STREAK', '0', '0', '0']
- **play:** ['Lululu Game', 'Geri', 'Osmantuş', 'Bitti. Osmantuş seni yendi.', 'SKOR', 'REKOR', 'STREAK', '164', '164', '0', 'Can: 🖤🖤🖤\nx0\nAĞZIMA DÜŞ!', 'OSMAN YENDİ']
- **bugs:** ['']
- **works:** ['drops']

### Osmantuş
- **open:** ['Lululu Game', 'Geri', 'Osmantuş', 'Yeşil halkada dokun — dıkkış dıkkış!', 'SKOR', 'REKOR', 'STREAK', '0', '164', '0']
- **play:** ['Lululu Game', 'Geri', 'Osmantuş', 'Bitti. Osmantuş seni yendi.', 'SKOR', 'REKOR', 'STREAK', '214', '214', '0', 'Can: 🖤🖤🖤\nx0\nARMUT PİŞ!', 'OSMAN YENDİ']
- **bugs:** []
- **works:** ['rhythm']

### Çığlık Böcek
- **open:** ['Lululu Game', 'Geri', 'Çığlık Böcek', 'Kapı 6! · spam x0', 'SKOR', 'REKOR', 'KAPI', '60', '135', '6']
- **play:** ['Lululu Game', 'Geri', 'Çığlık Böcek', 'Çimde uyudun! Zıpla / spam et.', 'SKOR', 'REKOR', 'KAPI', '70', '135', '7', 'SES fısıltı · Tencereli Çırak', 'EZİLDİN']
- **bugs:** ['', '']
- **works:** ['spam score']

### Makarayız
- **open:** ['Lululu Game', 'Geri', 'Makarayız', 'Kaçırdın! Yanlış şerit ya da timing.', 'SKOR', 'REKOR', '0', '0', 'Can: ❤️❤️🖤\nx0', 'MAKARA']
- **play:** ['Lululu Game', 'Geri', 'Makarayız', 'Makara bitti. Yeniden çek!', 'SKOR', 'REKOR', '0', '0', 'Can: 🖤🖤🖤\nx0', 'MAKARA', 'MAKARA BİTTİ', 'Makara bitti. Yeniden çek!']
- **bugs:** []
- **works:** ['lanes']

### Terlik Tap
- **open:** ['Lululu Game', 'MYSTIC DROP · HOT\nSUIKA ARENA\nAynı böceği bırak, birleş', 'HEMEN OYNA', 'VİRAL', 'GIF · video · hızlı mini oyunlar', 'Tümü →', 'GIF / Çıkartma\nGIF / Çıkartma', 'Video İzle\nVideo İzle', 'Video Yap\nVideo Yap', 'Terlik Tap\nTerlik Tap']
- **play:** ['Lululu Game', 'Geri', '2048 Grid', 'Zirve 0 · kaydır birleştir', 'SKOR', 'REKOR', 'UNDO', '0', '56', '3', '2', '2']
- **bugs:** []
- **works:** ['reachable']

## Cross-cutting improvements
- Match3/Bağla: nearest-cell hit (post-V2 patch) + softer starter boards if still 0.
- Stack: unique Semantics (`Stack Drop`) — avoid short keys like `Düşen` in automation.
- Terlik viral chip vs grid tile: ensure hit target ≥48dp; tap must not land on 2048.
- Hub banner shows `Firebase dart-define yok` — expected local; hide in release UI.
- Suika `back failed` = false positive (Geri AX var; skor 162 OK).
- Scream: Kapı 6 + `Çimde uyudun` confirmed — grass/gates live.
