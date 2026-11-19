import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/models/insect_tier.dart';
import 'package:lululu_game/models/lululu_game_mode.dart';

// W20-3 TESTS-4: model `*For(Locale)` erişimcileri. Kaynaklar:
// - lib/models/lululu_game_mode.dart:68-186 (`*En` getter + `*For`)
// - lib/models/insect_tier.dart:248,286-386 (`viralReplik`, `*En`/`*For`)
// - lib/models/campaign_level.dart:45-120 (temalı bölüm), 219-276 (seviye)
// Davranış: yalnız `languageCode == 'en'` EN döndürür, diğer her dil TR
// alanına düşer. `viralReplik`'in `Locale` parametresi yoktur ve EN
// karşılığı bilinçli olarak yoktur (insect_tier.dart:280-285 yorumu).
// Altyazı haritaları (`_chapterSubtitles`/`_chapterSubtitlesEn`,
// campaign_level.dart:399/493) özeldir; 80/80 eşleşme her seviyenin
// herkese açık `title`/`titleEn` değeri üzerinden denetlenir.

const _tr = Locale('tr');
const _en = Locale('en');

const _modeTitlesEn = <LululuGameModeId, String>{
  LululuGameModeId.suikaArena: 'Suika Arena',
  LululuGameModeId.grid2048: '2048 Grid',
  LululuGameModeId.bubblePop: 'Balloon Pop',
  LululuGameModeId.match3: 'Match 3',
  LululuGameModeId.connectBlast: 'Link Pop',
  LululuGameModeId.stackDrop: 'Stack Drop',
  LululuGameModeId.terlikTap: 'Slipper Tap',
  LululuGameModeId.yuvaDefense: 'Nest Defense',
  LululuGameModeId.osmantus: 'Osmantuş',
  LululuGameModeId.screamBug: 'Scream Bug',
  LululuGameModeId.makarayiz: 'Makarayız',
};

const _modeSubtitlesEn = <LululuGameModeId, String>{
  LululuGameModeId.suikaArena: 'The classic merge game',
  LululuGameModeId.grid2048: 'Slide, merge, reach 2048',
  LululuGameModeId.bubblePop: 'Aim and pop 3 matching balloons',
  LululuGameModeId.match3: 'Swap a neighbor, blast rows of 3',
  LululuGameModeId.connectBlast: 'Draw chains of the same bug and blast them',
  LululuGameModeId.stackDrop: 'Stack the tower without clipping the edge',
  LululuGameModeId.terlikTap: 'Slap what pops out of the holes with a slipper',
  LululuGameModeId.yuvaDefense:
      'Slap anything reaching the nest with a slipper',
  LululuGameModeId.osmantus: 'Hit the double tap in the green ring!',
  LululuGameModeId.screamBug:
      'Shout to fly through the gates without getting squashed',
  LululuGameModeId.makarayiz: 'Swipe on the beat, wind the reel',
};

const _modeBadgesEn = <LululuGameModeId, String>{
  LululuGameModeId.suikaArena: 'HOT',
  LululuGameModeId.grid2048: '2048',
  LululuGameModeId.bubblePop: 'BONUS',
  LululuGameModeId.match3: 'NEON',
  LululuGameModeId.connectBlast: 'CHAIN',
  LululuGameModeId.stackDrop: 'TOWER',
  LululuGameModeId.terlikTap: 'NEW',
  LululuGameModeId.yuvaDefense: 'NEW',
  LululuGameModeId.osmantus: 'VIRAL',
  LululuGameModeId.screamBug: 'VIRAL',
  LululuGameModeId.makarayiz: 'VIRAL',
};

const _modeMechanicsEn = <LululuGameModeId, String>{
  LululuGameModeId.suikaArena:
      'Drop bugs into the jar and bump matching levels together to reach the King Bug!',
  LululuGameModeId.grid2048:
      'Slide the 4x4 board in 4 directions! Matching bugs evolve to the next level.',
  LululuGameModeId.bubblePop:
      'Aim from below, hit at least 3 balloons with the same bug, and drop them!',
  LululuGameModeId.match3:
      'Swap neighboring bugs and blast horizontal or vertical rows of 3!',
  LululuGameModeId.connectBlast:
      'Draw long chains between neighboring matching bugs without lifting your finger!',
  LululuGameModeId.stackDrop:
      'Drop the swaying bug blocks exactly on top of each other and raise the tower without toppling it!',
  LululuGameModeId.terlikTap:
      'Slap the bugs popping out of the holes with a slipper, and never touch the bombs!',
  LululuGameModeId.yuvaDefense:
      'Stop the bugs running toward the kitchen counter through 4 lanes with your slipper and protect the cake!',
  LululuGameModeId.osmantus:
      'Catch the shrinking timing ring exactly on the green line and hit the Osman button!',
  LululuGameModeId.screamBug:
      'Fly the bug by shouting into the microphone or holding down, and never hit the pipes!',
  LululuGameModeId.makarayiz:
      'Catch the rhythm notes on the line and spin the reel to multiply your combo!',
};

const _tierNamesEn = <InsectTier, String>{
  InsectTier.cone: 'Baby Funnel',
  InsectTier.helmet: 'Pot-Wearing Apprentice',
  InsectTier.fan: 'Reel Fan',
  InsectTier.dancer: 'Pajama Dancer',
  InsectTier.diva: 'Bathhouse Diva',
  InsectTier.can: 'Bathhouse Can',
  InsectTier.kongo: 'Kongo Leader',
  InsectTier.bed: 'Ailing Sage',
  InsectTier.milli: 'National Jersey Bug',
  InsectTier.pinkJacket: 'Pink Jacket Bug',
  InsectTier.whiteGhost: 'White Ghost',
  InsectTier.greyShirt: 'Gray T-Shirt Bug',
  InsectTier.pinkRobe: 'Pink Robe Bug',
};

const _tierTitlesEn = <InsectTier, String>{
  InsectTier.cone: 'Lülülü Baby',
  InsectTier.helmet: 'Helmeted Bug',
  InsectTier.fan: 'Makarayız Bro',
  InsectTier.dancer: 'Hoppa, Sweetheart',
  InsectTier.diva: "I'm a Diva, Honey!",
  InsectTier.can: 'Dear Viewers',
  InsectTier.kongo: 'My Dearest One',
  InsectTier.bed: 'Call the Doctor!',
  InsectTier.milli: 'Striker Bug',
  InsectTier.pinkJacket: "You've Got Style!",
  InsectTier.whiteGhost: 'Invisible Knight',
  InsectTier.greyShirt: 'Quiet Strength',
  InsectTier.pinkRobe: 'Pinnacle of Evolution',
};

const _tierRaritiesEn = <InsectTier, String>{
  InsectTier.cone: 'Common',
  InsectTier.helmet: 'Uncommon',
  InsectTier.fan: 'Rare',
  InsectTier.dancer: 'Epic',
  InsectTier.diva: 'Legendary',
  InsectTier.can: 'Mythic',
  InsectTier.kongo: 'Hidden',
  InsectTier.bed: 'Evolution Crystal',
  InsectTier.milli: 'Super',
  InsectTier.pinkJacket: 'Ultra',
  InsectTier.whiteGhost: 'Cosmic',
  InsectTier.greyShirt: 'Ancient',
  InsectTier.pinkRobe: 'Absolute',
};

const _tierViralReplikTr = <InsectTier, String>{
  InsectTier.cone: 'Lülülü bebek!',
  InsectTier.helmet: 'Vurma kafama usta!',
  InsectTier.fan: 'Makarayız abi!',
  InsectTier.dancer: 'Hoppa oyna gülüm!',
  InsectTier.diva: 'Ben divayım ayol! Divalar yemek yapmaz!',
  InsectTier.can: 'Sayın seyirciler flaş flaş!',
  InsectTier.kongo: 'Kurban olduğum Kongo istilası!',
  InsectTier.bed: 'Dukturu arayın ölüyorum lülülü!',
  InsectTier.milli: 'Sahaya çıktık!',
  InsectTier.pinkJacket: 'Tarzımsın!',
  InsectTier.whiteGhost: 'Görünmezim!',
  InsectTier.greyShirt: 'Rahatına bak!',
  InsectTier.pinkRobe: 'Zirvedeyim!',
};

const _themedTitlesTr = <int, String>{
  1: 'Mutfak Tezgahı Baskını',
  2: 'Kiler ve Erzak Kavanozu',
  3: 'Banyo Gideri Labirenti',
  4: 'Bodrum Karanlığı',
  5: 'Fırın Ateşi Meydanı',
  6: 'Çatı Katı Fırtınası',
  7: 'Kanalizasyon Krallığı',
  8: "Osman'ın Altın Sarayı",
};

const _themedTitlesEn = <int, String>{
  1: 'Kitchen Counter Raid',
  2: 'Pantry and Provisions Jar',
  3: 'Bathroom Drain Labyrinth',
  4: 'Basement Darkness',
  5: 'Oven-Fire Square',
  6: 'Attic Storm',
  7: 'Sewer Kingdom',
  8: "Osman's Golden Palace",
};

const _themedBossTr = <int, String>{
  1: 'Şef Terlikli Muzaffer',
  2: 'Turşu Kralı Kavanoz Bey',
  3: 'Köpük Divası Şampuanella',
  4: 'Karanlık Kömürlük Baronu',
  5: 'Kızgın Rezistans Ejderi',
  6: 'Kiremit Fırtınası Kaptanı',
  7: 'Toksik Rögar Mareşali',
  8: 'İmparator Altın Osman',
};

const _themedBossEn = <int, String>{
  1: 'Slippered Chef Muzaffer',
  2: 'Pickle King Mr. Jar',
  3: 'Foam Diva Shampooella',
  4: 'Dark Coal-Cellar Baron',
  5: 'Scorching Coil Dragon',
  6: 'Roof-Tile Storm Captain',
  7: 'Toxic Manhole Marshal',
  8: 'Emperor Golden Osman',
};

const _themedHazardsTr = <int, String>{
  1: 'Kaynar Çaydanlık Buharı & Merdane Bariyeri',
  2: 'Yapışkan Reçel Damlaları & Tuzluk Tuzağı',
  3: 'Kaygan Sabun Köpüğü & Gider Girdabı',
  4: 'Zifiri Sis Perdesi & Paslı Boru Engeli',
  5: 'Alevli Tepsi Dalgası & Termal Hava Akımı',
  6: 'Şimşek Çarpması & Ters Rüzgar Savrulması',
  7: 'Radyoaktif Neon Dalga & Demir Izgara Kapanı',
  8: 'Kraliyet Altın Terlik Yağmuru & Lazer Kalkanı',
};

const _themedHazardsEn = <int, String>{
  1: 'Boiling Kettle Steam & Rolling-Pin Barrier',
  2: 'Sticky Jam Drops & Salt-Shaker Trap',
  3: 'Slippery Soap Foam & Drain Vortex',
  4: 'Pitch-Black Fog Curtain & Rusty Pipe Barrier',
  5: 'Flaming Tray Wave & Thermal Air Current',
  6: 'Lightning Strikes & Reverse-Wind Drift',
  7: 'Radioactive Neon Wave & Iron Grate Trap',
  8: 'Royal Golden Slipper Rain & Laser Shield',
};

// `_chapterSubtitles` (campaign_level.dart:399) birebir kopyası: 4 eski
// bölüm x 20 altyazı, kaynak sıra korunur.
const _trSubtitlesByChapter = <int, List<String>>{
  1: [
    'Tezgah Isınması',
    'Kırıntı Avı',
    'Tencere Tıkırtısı',
    'Kavanoz Kuşatması',
    'Çaydanlık Fırtınası',
    'Ekmek Sepeti Baskını',
    'Bulaşık Köpüğü',
    'Baharat Rafı',
    'Kesme Tahtası Düellosu',
    'Mutfak Şefi Sınavı',
    'Gece Yarısı Atıştırması',
    'Buzdolabı Gölgesi',
    'Fırın Sıcağı',
    'Tava Kaydırağı',
    'Lavabo Girdabı',
    'Merdane Engeli',
    'Kiler Labirenti',
    'Tuzluk Tuzağı',
    'Tezgah Derbisi',
    'Mutfak Kralı Finali',
  ],
  2: [
    'Malikane Girişi',
    'Altın Avize',
    'Kırmızı Halı',
    'Pırlanta Ayna',
    'İpek Perde',
    'VIP Buhar Odası',
    'Mermer Havuz',
    'Köpük Partisi',
    'Sahne Işıkları',
    'Diva Tacı Sınavı',
    'Kadife Koltuk',
    'Kristal Şamdan',
    'Jakuzi Dalgası',
    'Parfüm Bulutu',
    'Bornoz Defilesi',
    'Gümüş Tepsi',
    'Teras Galası',
    'Kuliste Kaos',
    'Kraliyet Süiti',
    'Diva Malikanesi Finali',
  ],
  3: [
    'Kamera Motor',
    'İlk Reel Çekimi',
    'Mikrofon Testi',
    'Ring Işığı',
    'Trend Alarmı',
    'Canlı Yayın Baskını',
    'Montaj Masası',
    'Yeşil Perde',
    'Stüdyo Spotları',
    'Viral Patlama',
    'Remix Kabini',
    'Yorum Yağmuru',
    'Algoritma Ustası',
    'Dans Koreografisi',
    'Stüdyo Maratonu',
    'Büyük Prömiyer',
    'Milyon İzlenme',
    'Kulis Fırtınası',
    'Altın Plaket',
    'Pikomotions Sezon Finali',
  ],
  4: [
    'İstila Başlangıcı',
    'Kongo Öncüleri',
    'Sıcak Dalga',
    'Tamirhane Baskını',
    'Gece Kuşatması',
    'Siren Sesleri',
    'Zırhlı Hat',
    'Büyük Göç',
    'Şimşek Hattı',
    'Komutan Karargahı',
    'Karanlık Koridor',
    'Çelik Barikat',
    'Kaos Çemberi',
    'Elit Muhafızlar',
    'Son Savunma',
    'Fırtına Gözü',
    'Kongo Zaferi',
    'Bilge Konseyi',
    'Evrim Zirvesi',
    'Büyük Kongo İmparatoru',
  ],
};

// `_chapterSubtitlesEn` (campaign_level.dart:493) birebir kopyası: TR
// haritasıyla aynı anahtarlar, aynı sıra.
const _enSubtitlesByChapter = <int, List<String>>{
  1: [
    'Counter Warm-Up',
    'Crumb Hunt',
    'Pot Clatter',
    'Jar Siege',
    'Kettle Storm',
    'Bread Basket Raid',
    'Dish Foam',
    'Spice Rack',
    'Cutting Board Duel',
    'Head Chef Trial',
    'Midnight Snack',
    'Fridge Shadow',
    'Oven Heat',
    'Pan Slide',
    'Sink Vortex',
    'Rolling-Pin Barrier',
    'Pantry Labyrinth',
    'Salt-Shaker Trap',
    'Counter Derby',
    'Kitchen King Finale',
  ],
  2: [
    'Mansion Entrance',
    'Golden Chandelier',
    'Red Carpet',
    'Diamond Mirror',
    'Silk Curtain',
    'VIP Steam Room',
    'Marble Pool',
    'Foam Party',
    'Stage Lights',
    'Diva Crown Trial',
    'Velvet Armchair',
    'Crystal Candelabra',
    'Jacuzzi Wave',
    'Perfume Cloud',
    'Robe Fashion Show',
    'Silver Tray',
    'Terrace Gala',
    'Backstage Chaos',
    'Royal Suite',
    'Diva Mansion Finale',
  ],
  3: [
    'Camera Rolling',
    'First Reel Shoot',
    'Mic Check',
    'Ring Light',
    'Trend Alert',
    'Livestream Raid',
    'Editing Desk',
    'Green Screen',
    'Studio Spotlights',
    'Viral Explosion',
    'Remix Booth',
    'Comment Rain',
    'Algorithm Master',
    'Dance Choreography',
    'Studio Marathon',
    'Grand Premiere',
    'Million Views',
    'Backstage Storm',
    'Golden Plaque',
    'Pikomotions Season Finale',
  ],
  4: [
    'Invasion Begins',
    'Kongo Vanguard',
    'Heat Wave',
    'Workshop Raid',
    'Night Siege',
    'Siren Sounds',
    'Armored Line',
    'Great Migration',
    'Lightning Line',
    'Commander Headquarters',
    'Dark Corridor',
    'Steel Barricade',
    'Chaos Circle',
    'Elite Guards',
    'Last Stand',
    'Eye of the Storm',
    'Kongo Victory',
    'Sage Council',
    'Evolution Summit',
    'Great Kongo Emperor',
  ],
};

/// `objectiveDescription` şablonunun aynısı (campaign_level.dart:200-208).
String _expectedObjectiveTr(CampaignLevel level) {
  switch (level.objectiveType) {
    case ObjectiveType.mergeTargetTier:
      return '${level.allowedMoves} atışta ${level.targetTier?.name ?? "Böcek"} çıkar!';
    case ObjectiveType.reachScore:
      return '${level.allowedMoves} atışta ${level.targetScore} puana ulaş!';
    case ObjectiveType.survivalTimer:
      return '${level.timeLimitSeconds} saniye boyunca taşmadan hayatta kal!';
  }
}

/// `objectiveDescriptionEn` şablonunun aynısı (campaign_level.dart:244-253).
String _expectedObjectiveEn(CampaignLevel level) {
  switch (level.objectiveType) {
    case ObjectiveType.mergeTargetTier:
      return 'Hatch a ${level.targetTier?.nameEn ?? "Bug"} in ${level.allowedMoves} shots!';
    case ObjectiveType.reachScore:
      return 'Reach ${level.targetScore} points in ${level.allowedMoves} shots!';
    case ObjectiveType.survivalTimer:
      return 'Survive ${level.timeLimitSeconds} seconds without overflowing!';
  }
}

void main() {
  group('LululuGameMode *For', () {
    test('TR locale 11 modda da katalog TR değerini döndürür', () {
      expect(LululuGameMode.catalog.length, 11);
      for (final mode in LululuGameMode.catalog) {
        expect(mode.titleFor(_tr), mode.title, reason: '${mode.id} title');
        expect(
          mode.subtitleFor(_tr),
          mode.subtitle,
          reason: '${mode.id} subtitle',
        );
        expect(
          mode.badgeLabelFor(_tr),
          mode.badgeLabel,
          reason: '${mode.id} badge',
        );
        expect(
          mode.mechanicSummaryFor(_tr),
          mode.mechanicSummary,
          reason: '${mode.id} mechanic',
        );
      }
      // TR tarafı nokta kontrolleri (katalog, lululu_game_mode.dart:189+).
      expect(
        LululuGameMode.byId(LululuGameModeId.bubblePop).title,
        'Balon Patlat',
      );
      expect(
        LululuGameMode.byId(LululuGameModeId.bubblePop).subtitle,
        'Nişan al, 3 aynı balonu patlat',
      );
      expect(
        LululuGameMode.byId(LululuGameModeId.yuvaDefense).title,
        'Yuva Savunması',
      );
      expect(
        LululuGameMode.byId(LululuGameModeId.screamBug).title,
        'Çığlık Böcek',
      );
    });

    test('EN locale 11 modun EN tablosunu döndürür', () {
      for (final mode in LululuGameMode.catalog) {
        expect(
          mode.titleFor(_en),
          _modeTitlesEn[mode.id],
          reason: '${mode.id} titleEn',
        );
        expect(
          mode.subtitleFor(_en),
          _modeSubtitlesEn[mode.id],
          reason: '${mode.id} subtitleEn',
        );
        expect(
          mode.badgeLabelFor(_en),
          _modeBadgesEn[mode.id],
          reason: '${mode.id} badgeEn',
        );
        expect(
          mode.mechanicSummaryFor(_en),
          _modeMechanicsEn[mode.id],
          reason: '${mode.id} mechanicEn',
        );
        // `*En` getter ile `*For(en)` aynı değeri verir.
        expect(mode.titleFor(_en), mode.titleEn);
        expect(mode.subtitleFor(_en), mode.subtitleEn);
        expect(mode.badgeLabelFor(_en), mode.badgeLabelEn);
        expect(mode.mechanicSummaryFor(_en), mode.mechanicSummaryEn);
      }
    });

    test('iki dilde aynen kalan özel adlar EN localede korunur', () {
      // Başlık: özel ad / zaten İngilizce olanlar aynen kalır.
      // `terlikTap` burada DEĞİLDİR: kanonik `titleEn` 'Slipper Tap'
      // olup TR katalog başlığı 'Terlik Tap'ten farklıdır (aşağıda
      // ayrıca kilitlenir).
      for (final id in [
        LululuGameModeId.suikaArena,
        LululuGameModeId.grid2048,
        LululuGameModeId.match3,
        LululuGameModeId.osmantus,
        LululuGameModeId.makarayiz,
      ]) {
        final mode = LululuGameMode.byId(id);
        expect(mode.titleFor(_en), mode.title, reason: '$id title');
      }
      // Çevrilen başlıklar: kanonik `titleEn` TR katalog başlığından
      // farklıdır; katalogdaki TR `title` alanı aynen kalır
      // (lululu_game_mode.dart:302 `title: 'Terlik Tap'` TR alanıdır,
      // EN karşılığı değildir).
      expect(
        LululuGameMode.byId(LululuGameModeId.connectBlast).title,
        'Bağla Patlat',
      );
      expect(
        LululuGameMode.byId(LululuGameModeId.connectBlast).titleFor(_en),
        'Link Pop',
      );
      expect(
        LululuGameMode.byId(LululuGameModeId.terlikTap).title,
        'Terlik Tap',
      );
      expect(
        LululuGameMode.byId(LululuGameModeId.terlikTap).titleFor(_en),
        'Slipper Tap',
      );
      // Rozet: HOT / 2048 / BONUS / NEON iki dilde de aynı yazılır.
      for (final id in [
        LululuGameModeId.suikaArena,
        LululuGameModeId.grid2048,
        LululuGameModeId.bubblePop,
        LululuGameModeId.match3,
      ]) {
        final mode = LululuGameMode.byId(id);
        expect(mode.badgeLabelFor(_en), mode.badgeLabel, reason: '$id badge');
      }
      // TR'de farklı yazılan rozetler EN'de çevrilir.
      expect(
        LululuGameMode.byId(LululuGameModeId.connectBlast).badgeLabel,
        'ZİNCİR',
      );
      expect(
        LululuGameMode.byId(LululuGameModeId.connectBlast).badgeLabelFor(_en),
        'CHAIN',
      );
      expect(
        LululuGameMode.byId(LululuGameModeId.osmantus).badgeLabel,
        'VİRAL',
      );
      expect(
        LululuGameMode.byId(LululuGameModeId.osmantus).badgeLabelFor(_en),
        'VIRAL',
      );
      expect(
        LululuGameMode.byId(LululuGameModeId.stackDrop).badgeLabelFor(_en),
        'TOWER',
      );
    });

    test('desteklenmeyen dil TR, en-US EN döndürür', () {
      const de = Locale('de');
      const enUs = Locale('en', 'US');
      const trTr = Locale('tr', 'TR');
      final mode = LululuGameMode.byId(LululuGameModeId.bubblePop);
      expect(mode.titleFor(de), mode.title);
      expect(mode.titleFor(trTr), mode.title);
      expect(mode.subtitleFor(de), mode.subtitle);
      expect(mode.badgeLabelFor(de), mode.badgeLabel);
      expect(mode.mechanicSummaryFor(de), mode.mechanicSummary);
      expect(mode.titleFor(enUs), 'Balloon Pop');
      expect(
        mode.subtitleFor(enUs),
        'Aim and pop 3 matching balloons',
      );
    });
  });

  group('InsectTier *For', () {
    test('TR locale 13 kademede TR ad, başlık ve nadirlik döndürür', () {
      expect(InsectTier.values.length, 13);
      for (final tier in InsectTier.values) {
        expect(tier.nameFor(_tr), tier.name, reason: '$tier name');
        expect(tier.titleFor(_tr), tier.title, reason: '$tier title');
        expect(tier.rarityFor(_tr), tier.rarity, reason: '$tier rarity');
      }
      // TR tarafı nokta kontrolleri (insect_tier.dart:3-236).
      expect(InsectTier.cone.name, 'Bebek Huni');
      expect(InsectTier.cone.title, 'Lülülü Bebek');
      expect(InsectTier.cone.rarity, 'Sıradan');
      expect(InsectTier.diva.name, 'Hamam Diva');
      expect(InsectTier.diva.title, 'Ben Divayım Ayol!');
      expect(InsectTier.diva.rarity, 'Efsanevi');
      expect(InsectTier.bed.title, 'Dukturu Arayın!');
    });

    test('EN locale 13 kademenin EN ad, başlık ve nadirlik tablosunu döndürür',
        () {
      for (final tier in InsectTier.values) {
        expect(tier.nameFor(_en), _tierNamesEn[tier], reason: '$tier nameEn');
        expect(
          tier.titleFor(_en),
          _tierTitlesEn[tier],
          reason: '$tier titleEn',
        );
        expect(
          tier.rarityFor(_en),
          _tierRaritiesEn[tier],
          reason: '$tier rarityEn',
        );
        expect(tier.nameFor(_en), tier.nameEn);
        expect(tier.titleFor(_en), tier.titleEn);
        expect(tier.rarityFor(_en), tier.rarityEn);
      }
    });

    test('viralReplik 13 kademede de Türkçe kalır (EN karşılığı yok)', () {
      // `viralReplik` `Locale` parametresi almaz (insect_tier.dart:248);
      // karakter kimliği gereği her dilde Türkçe kalır. Bu test TR
      // tablosunu kilitler: EN locale kavramı bu getter için yoktur.
      for (final tier in InsectTier.values) {
        expect(
          tier.viralReplik,
          _tierViralReplikTr[tier],
          reason: '$tier viralReplik',
        );
        expect(tier.viralReplik.trim(), isNotEmpty);
      }
    });

    test('desteklenmeyen dil TR, en-GB EN döndürür', () {
      const de = Locale('de');
      const enGb = Locale('en', 'GB');
      expect(InsectTier.diva.nameFor(de), InsectTier.diva.name);
      expect(InsectTier.diva.titleFor(de), InsectTier.diva.title);
      expect(InsectTier.diva.rarityFor(de), InsectTier.diva.rarity);
      expect(InsectTier.diva.nameFor(enGb), 'Bathhouse Diva');
      expect(InsectTier.diva.titleFor(enGb), "I'm a Diva, Honey!");
      expect(InsectTier.diva.rarityFor(enGb), 'Legendary');
      expect(InsectTier.cone.nameFor(enGb), 'Baby Funnel');
    });
  });

  group('CampaignThemedChapter *For', () {
    test('TR locale 8 temalı bölümde TR değerleri döndürür', () {
      expect(CampaignDatabase.themedChapters.length, 8);
      expect(CampaignDatabase.themedChapterCount, 8);
      for (final chapter in CampaignDatabase.themedChapters) {
        expect(
          chapter.titleFor(_tr),
          _themedTitlesTr[chapter.chapterIndex],
          reason: 'bölüm ${chapter.chapterIndex} title',
        );
        expect(chapter.titleFor(_tr), chapter.title);
        expect(
          chapter.bossNameFor(_tr),
          _themedBossTr[chapter.chapterIndex],
          reason: 'bölüm ${chapter.chapterIndex} boss',
        );
        expect(chapter.bossNameFor(_tr), chapter.bossName);
        expect(
          chapter.bossSpecialHazardFor(_tr),
          _themedHazardsTr[chapter.chapterIndex],
          reason: 'bölüm ${chapter.chapterIndex} hazard',
        );
        expect(
          chapter.bossSpecialHazardFor(_tr),
          chapter.bossSpecialHazard,
        );
      }
    });

    test('EN locale 8 temalı bölümün EN tablosunu döndürür', () {
      for (final chapter in CampaignDatabase.themedChapters) {
        expect(
          chapter.titleFor(_en),
          _themedTitlesEn[chapter.chapterIndex],
          reason: 'bölüm ${chapter.chapterIndex} titleEn',
        );
        expect(
          chapter.bossNameFor(_en),
          _themedBossEn[chapter.chapterIndex],
          reason: 'bölüm ${chapter.chapterIndex} bossEn',
        );
        expect(
          chapter.bossSpecialHazardFor(_en),
          _themedHazardsEn[chapter.chapterIndex],
          reason: 'bölüm ${chapter.chapterIndex} hazardEn',
        );
        expect(chapter.titleFor(_en), chapter.titleEn);
        expect(chapter.bossNameFor(_en), chapter.bossNameEn);
        expect(
          chapter.bossSpecialHazardFor(_en),
          chapter.bossSpecialHazardEn,
        );
      }
      // Özel adlar EN metin içinde aynen korunur (Osman, Muzaffer, Diva).
      expect(
        CampaignDatabase.getThemedChapter(8).titleFor(_en),
        "Osman's Golden Palace",
      );
      expect(
        CampaignDatabase.getThemedChapter(1).bossNameFor(_en),
        'Slippered Chef Muzaffer',
      );
      expect(
        CampaignDatabase.getThemedChapter(3).bossNameFor(_en),
        'Foam Diva Shampooella',
      );
    });

    test('bilinmeyen bölüm indeksi EN localede de TR değere düşer', () {
      // `*En` switch'lerinde default dalı TR alanı döndürür
      // (campaign_level.dart:45-120).
      const unknown = CampaignThemedChapter(
        chapterIndex: 99,
        title: 'TR Başlık',
        iconEmoji: '❓',
        startLevel: 1,
        endLevel: 10,
        bossLevelNumber: 10,
        bossName: 'TR Boss',
        bossHp: 1,
        bossSpecialHazard: 'TR Tehlike',
        firstClearBonusCoins: 0,
        backgroundPath: 'x.png',
      );
      expect(unknown.titleFor(_en), 'TR Başlık');
      expect(unknown.bossNameFor(_en), 'TR Boss');
      expect(unknown.bossSpecialHazardFor(_en), 'TR Tehlike');
      expect(unknown.titleFor(_tr), 'TR Başlık');
    });
  });

  group('CampaignLevel *For', () {
    test('TR locale 80 seviyede TR bölüm adı, başlık, hedef ve engel döndürür',
        () {
      expect(CampaignDatabase.totalLevels, 80);
      expect(CampaignDatabase.allLevels.length, 80);
      for (final level in CampaignDatabase.allLevels) {
        expect(
          level.chapterNameFor(_tr),
          _themedTitlesTr[level.chapterIndex],
          reason: 'seviye ${level.id} chapter',
        );
        expect(level.chapterNameFor(_tr), level.chapterName);
        expect(
          level.themedChapterTitleFor(_tr),
          level.themedChapterTitle,
          reason: 'seviye ${level.id} themed',
        );
        expect(level.titleFor(_tr), level.title, reason: 'seviye ${level.id}');
        expect(
          level.objectiveDescriptionFor(_tr),
          level.objectiveDescription,
          reason: 'seviye ${level.id} objective',
        );
        expect(
          level.objectiveDescriptionFor(_tr),
          _expectedObjectiveTr(level),
          reason: 'seviye ${level.id} objectiveTr',
        );
        expect(
          level.obstacleLabelFor(_tr),
          level.obstacleLabel,
          reason: 'seviye ${level.id} obstacle',
        );
        expect(
          level.obstacleLabelFor(_tr),
          level.hasObstacles ? 'Arena engelleri aktif' : 'Açık arena',
        );
      }
    });

    test('EN altyazı haritası 80/80 TR ile eşleşir (sayı + sıra)', () {
      // Haritalar özel olduğundan eşleşme her seviyenin `title`/`titleEn`
      // değeri üzerinden denetlenir: 4 eski bölüm x 20 altyazı, aynı sıra.
      expect(_trSubtitlesByChapter.length, 4);
      expect(_enSubtitlesByChapter.length, 4);
      for (final chapter in [1, 2, 3, 4]) {
        expect(
          _trSubtitlesByChapter[chapter]!.length,
          20,
          reason: 'TR bölüm $chapter',
        );
        expect(
          _enSubtitlesByChapter[chapter]!.length,
          20,
          reason: 'EN bölüm $chapter',
        );
      }
      for (var i = 0; i < CampaignDatabase.allLevels.length; i++) {
        final level = CampaignDatabase.allLevels[i];
        final id = i + 1;
        expect(level.id, id);
        final slot = (id - 1) % CampaignDatabase.levelsPerChapter;
        final trSubtitle = _trSubtitlesByChapter[level.chapter]![slot];
        final enSubtitle = _enSubtitlesByChapter[level.chapter]![slot];
        expect(
          level.title,
          'Bölüm $id: $trSubtitle',
          reason: 'TR seviye $id',
        );
        expect(
          level.titleEn,
          'Level $id: $enSubtitle',
          reason: 'EN seviye $id',
        );
        expect(level.titleFor(_tr), level.title, reason: 'titleFor TR $id');
        expect(
          level.titleFor(_en),
          level.titleEn,
          reason: 'titleFor EN $id',
        );
        expect(
          enSubtitle,
          isNot(trSubtitle),
          reason: 'çevrilmemiş altyazı $id',
        );
        expect(enSubtitle.trim(), isNotEmpty);
      }
      // Sıra kanıtı: bölüm başı/sonu nokta kontrolleri.
      expect(CampaignDatabase.getLevel(1).titleEn, 'Level 1: Counter Warm-Up');
      expect(
        CampaignDatabase.getLevel(20).titleEn,
        'Level 20: Kitchen King Finale',
      );
      expect(
        CampaignDatabase.getLevel(21).titleEn,
        'Level 21: Mansion Entrance',
      );
      expect(
        CampaignDatabase.getLevel(40).titleEn,
        'Level 40: Diva Mansion Finale',
      );
      expect(
        CampaignDatabase.getLevel(41).titleEn,
        'Level 41: Camera Rolling',
      );
      expect(
        CampaignDatabase.getLevel(60).titleEn,
        'Level 60: Pikomotions Season Finale',
      );
      expect(
        CampaignDatabase.getLevel(61).titleEn,
        'Level 61: Invasion Begins',
      );
      expect(
        CampaignDatabase.getLevel(80).titleEn,
        'Level 80: Great Kongo Emperor',
      );
    });

    test(
        'EN locale 80 seviyede EN bölüm adı, hedef açıklaması ve engel etiketi döndürür',
        () {
      for (final level in CampaignDatabase.allLevels) {
        expect(
          level.chapterNameFor(_en),
          _themedTitlesEn[level.chapterIndex],
          reason: 'seviye ${level.id} chapterEn',
        );
        expect(
          level.themedChapterTitleFor(_en),
          _themedTitlesEn[level.chapterIndex],
          reason: 'seviye ${level.id} themedEn',
        );
        expect(
          level.objectiveDescriptionFor(_en),
          _expectedObjectiveEn(level),
          reason: 'seviye ${level.id} objectiveEn',
        );
        expect(
          level.obstacleLabelFor(_en),
          level.hasObstacles ? 'Arena obstacles active' : 'Open arena',
          reason: 'seviye ${level.id} obstacleEn',
        );
      }
      // Hedef açıklaması EN'de hedef kademenin EN adını kullanır.
      final mergeLevel = CampaignDatabase.allLevels.firstWhere(
        (l) => l.objectiveType == ObjectiveType.mergeTargetTier,
      );
      expect(mergeLevel.targetTier, isNotNull);
      expect(
        mergeLevel.objectiveDescriptionFor(_en),
        contains(mergeLevel.targetTier!.nameEn),
      );
      expect(
        mergeLevel.objectiveDescriptionFor(_tr),
        contains(mergeLevel.targetTier!.name),
      );
    });

    test(
        'bossName null ise EN karşılığı da null kalır; boss seviyelerinde EN boss adı gelir',
        () {
      expect(CampaignDatabase.bossLevels.length, 8);
      var nullCount = 0;
      for (final level in CampaignDatabase.allLevels) {
        if (level.isBossLevel) {
          expect(level.bossName, isNotNull);
          expect(level.bossNameFor(_tr), level.bossName);
          expect(
            level.bossNameFor(_en),
            _themedBossEn[level.chapterIndex],
            reason: 'boss seviye ${level.id}',
          );
          expect(level.bossSpecialHazard, isNotNull);
          expect(
            level.bossSpecialHazardFor(_tr),
            level.bossSpecialHazard,
          );
          expect(
            level.bossSpecialHazardFor(_en),
            _themedHazardsEn[level.chapterIndex],
            reason: 'boss tehlike ${level.id}',
          );
        } else {
          nullCount++;
          expect(level.bossName, isNull);
          expect(level.bossNameFor(_tr), isNull);
          expect(level.bossNameFor(_en), isNull);
          expect(level.bossNameEn, isNull);
          expect(level.bossSpecialHazard, isNull);
          expect(level.bossSpecialHazardFor(_tr), isNull);
          expect(level.bossSpecialHazardFor(_en), isNull);
          expect(level.bossSpecialHazardEn, isNull);
        }
      }
      expect(nullCount, 72);
    });

    test('elle kurulan seviyede bossNameEn null korur, doluysa temalı EN adı döner',
        () {
      // `bossNameEn` null kontrolü dışında örnekteki metni okumaz; dolu
      // ise temalı bölümün EN boss adını döndürür (campaign_level.dart:265).
      const withBoss = CampaignLevel(
        id: 5,
        chapter: 1,
        chapterName: 'Mutfak Tezgahı Baskını',
        title: 'Bölüm 5: X',
        objectiveType: ObjectiveType.reachScore,
        targetScore: 100,
        allowedMoves: 20,
        star1Score: 70,
        star2Score: 100,
        star3Score: 140,
        bossName: 'Özel Boss',
        bossSpecialHazard: 'Özel Tehlike',
      );
      expect(withBoss.bossNameFor(_tr), 'Özel Boss');
      expect(withBoss.bossNameFor(_en), 'Slippered Chef Muzaffer');
      expect(withBoss.bossSpecialHazardFor(_tr), 'Özel Tehlike');
      expect(
        withBoss.bossSpecialHazardFor(_en),
        'Boiling Kettle Steam & Rolling-Pin Barrier',
      );
      // `titleEn` de örnek başlığını okumaz; haritadan üretir.
      expect(withBoss.titleFor(_en), 'Level 5: Kettle Storm');

      const withoutBoss = CampaignLevel(
        id: 5,
        chapter: 1,
        chapterName: 'Mutfak Tezgahı Baskını',
        title: 'Bölüm 5: X',
        objectiveType: ObjectiveType.reachScore,
        targetScore: 100,
        allowedMoves: 20,
        star1Score: 70,
        star2Score: 100,
        star3Score: 140,
      );
      expect(withoutBoss.bossNameFor(_tr), isNull);
      expect(withoutBoss.bossNameFor(_en), isNull);
      expect(withoutBoss.bossSpecialHazardFor(_en), isNull);
    });

    test('desteklenmeyen dil TR, en-US EN döndürür', () {
      const de = Locale('de');
      const enUs = Locale('en', 'US');
      final first = CampaignDatabase.getLevel(1);
      final boss = CampaignDatabase.getLevel(10);
      expect(first.titleFor(de), first.title);
      expect(first.chapterNameFor(de), first.chapterName);
      expect(first.objectiveDescriptionFor(de), first.objectiveDescription);
      expect(boss.bossNameFor(de), boss.bossName);
      expect(first.titleFor(enUs), 'Level 1: Counter Warm-Up');
      expect(first.chapterNameFor(enUs), 'Kitchen Counter Raid');
      expect(boss.bossNameFor(enUs), 'Slippered Chef Muzaffer');
    });
  });
}
