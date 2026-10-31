# LÜLÜLÜ iOS Simulator Playtest Findings

**Date:** 2026-10-30  
**Device:** iPhone 17 Pro Max (`176302EF-495E-4A8E-B936-2DC1537C067C`)  
**Bundle:** `com.lululu.game.lululuGame`  
**Driver:** `orca emulator` + serve-sim `http://127.0.0.1:3100`  
**Build note:** Concurrent `flutter run` stayed on `Running pod install...` (~25+ min). Playtest used the already-installed debug binary (not a fresh rebuild).

**Screenshots:** `playtest_suika.png`, `playtest_osmantus.png`, `playtest_balon.png` (actually Stack result overlay), `playtest_viral.png`

---

## Cross-cutting bugs

| Issue | Detail | Suggested fix |
|---|---|---|
| Result overlay blocks back | `ArcadeResultOverlay` is `Positioned.fill` above chrome; back `IconButton` not tappable; no “Hub / Ana” action — only `PAYLAŞ KART` + retry | `lib/widgets/arcade_chrome.dart` — leave top safe-area chrome above overlay, or add `ANA SAYFA` / `Navigator.pop` on overlay |
| Accidental share sheet | Taps during/after game-over hit `PAYLAŞ KART` → iOS share UI (`Save Image` / `Copy`); traps automation and players | Debounce share; require long-press; or move share out of primary tap zone |
| Hub title ≠ in-mode title | Catalog / tiles use English-ish names; `ArcadeScreen.title` often Turkish ALL-CAPS | Align `LululuGameMode.title` with screen `title` / `modeTitle` in each `lib/modes/*_screen.dart` + `grid_2048_screen.dart` |
| Suika back unreliable under automation | Empty-label back button present in AX; repeated `tap` / edge swipe often no-op | `lib/screens/game_screen.dart` `_buildHeaderRow` — verify hit-test vs arena/`Listener`; add Semantics label `"Geri"` |
| Fresh launch restores last tab | Relaunch opened **Sohbet** (lobi) instead of Ana | `lib/screens/home_shell.dart` — default index 0 on cold start unless intentional |
| Rebuild stuck | `pod install` hung in flutter run terminal | Investigate CocoaPods lock / dual `pod install` processes |

---

## Per-mode

### 1. Suika Arena
- **Worked:** Featured `HEMEN OYNA` opens arcade; drops score to **1047**; speech juice (`Ben divayım ayol!`); boosters (Aydınlat / Terlik / Raid); next/hold UI.
- **Bugs:** Back navigation often fails (see cross-cutting). Title `SUIKA ARENA` OK vs catalog.
- **Fixes:** Hit-test / Semantics on back in `game_screen.dart`.

### 2. 2048 Grid
- **Worked:** Opens; swipes merge (score **0→24**, peak tile **8**); speech (`Vurma kafama usta!`); undo/pause/new.
- **Bugs:** In-mode title **`LÜLÜLÜ 2048`** vs hub **`2048 Grid`** (`grid_2048_screen.dart`). Footer **`GERİ (3)`** reads like navigation but is undo — UX confusion next to missing chrome back clarity.
- **Fixes:** Unify title; rename undo to `UNDO` only (already in header) / drop duplicate footer label.

### 3. Balon Patlat
- **Worked:** Opens as **`BALON PATLAT`**; aim/drop; score spiked to **10202** with milestone `SKOR 10000!`; ceiling counter / next / hold present.
- **Bugs:** Mild title casing mismatch vs catalog `Balon Patlat`.
- **Fixes:** Optional title sync in `balloon_pop_screen.dart`.

### 4. Match 3
- **Worked:** Opens as **`3'LÜ EŞLE`**; İPUCU lights cells (`İpucu parlıyor.`); pause/undo chrome.
- **Bugs:** Title mismatch vs hub `Match 3`. ~14 neighbor pans + taps left score **0** / moves **22** — either pan threshold/hit area feels stiff for coarse input, or swaps rarely resolve; juice for successful match not observed in this session.
- **Fixes:** `match3_screen.dart` — verify `_cellAt` / pan distance; enlarge drag slop; keep `modeTitle: 'Match 3'` consistent with chrome `title`.

### 5. Bağla Patlat
- **Worked:** Opens as **`ÇİZGİ BAĞLA`**; hint updates to `En az 3 böcek bağla.` after strokes; lines remaining **20**.
- **Bugs:** Title mismatch. ~14 connect gestures never scored (path likely not hitting same-kind neighbors of length ≥3) — feel picky; risk of “broken” perception.
- **Fixes:** `connect_pop_screen.dart` — looser adjacency / visual trail; title sync with catalog.

### 6. Stack Drop
- **Worked:** Opens as **`DÜŞEN KULE`**; tap-to-drop; fail state **`KULE DÜŞTÜ`** (e.g. score **23**, kat 1–2); retry/share overlay.
- **Bugs:** Title mismatch (`Stack Drop` vs `DÜŞEN KULE`). Overlay blocks hub exit. Share easy to misfire. Screenshot `playtest_balon.png` captured this overlay (naming mix-up during run).
- **Fixes:** Overlay hub button; title sync in `stack_drop_screen.dart`.

### 7. Osmantuş
- **Worked:** Viral tile opens; pulse ring + cast stickers; miss feedback (`Kaçırdın! Timing kaçtı.`); lives; game-over **`OSMAN YENDİ`**.
- **Bugs:** Overlay blocks back (repro’d). Daily card also contains “Osmantuş” — easy to open wrong surface from AX/search. Score often **0** if taps miss green window (expected difficulty).
- **Fixes:** Overlay exit; Semantics on daily vs mode tiles.

### 8. Çığlık Böcek
- **Worked:** Opens; spam taps score **18→24**, best **58→135**; voice/juice lines (`Dukturu arayın ölüyorum lülülü!`); SES / character callouts.
- **Bugs:** None blocking in short session. Back not stress-tested with overlay.
- **Fixes:** —

### 9. Makarayız
- **Worked:** Opens; lane/timing feedback; lives drain; game-over **`MAKARA BİTTİ`**.
- **Bugs:** Very punishing for imprecise input (score stayed **0** in automated taps) — may be OK design; overlay exit same as others.
- **Fixes:** Optional practice / wider timing window for early beats; overlay hub button.

### 10. Terlik Tap
- **Worked:** **Not reachable** on the installed hub binary under test.
- **Bugs:** Hub grid showed 8 non-featured tiles (2048…Makarayız) — **no Terlik card**. Viral row AX showed GIF / Video İzle / Böcek Videosu Yap — **no `Terlik Tap` chip**. Source (`lululu_game_mode.dart`, `game_selector_screen.dart` viral row) includes Terlik, but simulator build did not expose it (stale binary while pod install hung).
- **Fixes:** Finish iOS rebuild/deploy so catalog + viral chip ship; confirm Semantics label `Terlik Tap` on chip/tile; add regression that hub lists all `LululuGameMode.catalog` entries.

---

## Juice / UX notes (positive)
- Suika / 2048 / Balon / Çığlık: Turkish speech + milestones feel present.
- Arcade chrome (score/best/hint) consistent across modes.
- Hub featured banner + viral section structure clear when scrolled.

## Tooling notes
- Prefer `orca emulator ax --json` then tap frame centers; empty-label buttons need frame-based taps.
- Mode tiles with `width==0` are off-screen — scroll until `w>0` before tap.
- Do **not** `orca emulator kill/shutdown` (per session rules); used `simctl terminate/launch` only to escape overlay traps.

## Follow-up after full play agent
- 2048 undo label `GERİ` → `UNDO` (back ile karışmasın).
- Suika back: `Semantics(label: Geri)`.
- Result overlay: **HUB/YENİDEN önce**, PAYLAŞ alta (yanlış share sheet).
- Terlik + chrome padding: önceki diff; iOS Xcode build hâlâ sürüyor.

## Fixes applied (rapor)
- Title sync: in-mode titles = catalog (`Suika Arena`, `2048 Grid`, `Balon Patlat`, `Match 3`, `Bağla Patlat`, `Stack Drop`, `Terlik Tap`).
- Match3/Connect: cell hit + gap slop; Connect diagonal adjacency.
- Overlay: header back chrome overlay üstünde kalır; PAYLAŞ debounce 900ms + alta taşındı.
- Makarayız: ilk 4 beat window 200ms.
- Daily card Semantics `Günlük viral` / `Günlük oyna`.
- HomeShell cold start Ana force.
- Regression: `test/hub_catalog_test.dart` + smoke title update.
