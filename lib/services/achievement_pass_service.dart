import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'energy_service.dart';
import 'progress_manager.dart';

/// 5 ana başarım kategorisi.
enum AchievementCategory {
  mergeMaster('Birleştirme Ustası', '🪳'),
  modeChampion('11 Mod Şampiyonu', '🏆'),
  comboReflex('Kombo & Refleks', '⚡'),
  studioDirector('Böcek Stüdyo Yönetmeni', '🎬'),
  economyCollection('Ekonomi & Koleksiyon', '👑');

  final String titleTr;
  final String iconEmoji;
  const AchievementCategory(this.titleTr, this.iconEmoji);
}

/// Tek bir başarım tanımı.
class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final String iconEmoji;
  final int targetValue;
  final int coinReward;
  final int seasonXpReward;
  final String rewardTitle;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.iconEmoji,
    required this.targetValue,
    required this.coinReward,
    required this.seasonXpReward,
    required this.rewardTitle,
  });
}

/// Lülülü Sezon Bileti tek bir ödül paketi (Ücretsiz veya Altın Bilet hattı).
class SeasonPassReward {
  final String label;
  final String iconEmoji;
  final int coins;
  final int stars;
  final int energy;
  final Map<String, int> boosters;
  final bool grantsAll33PowerPack;
  final String? unlockedTitle;

  const SeasonPassReward({
    required this.label,
    required this.iconEmoji,
    this.coins = 0,
    this.stars = 0,
    this.energy = 0,
    this.boosters = const <String, int>{},
    this.grantsAll33PowerPack = false,
    this.unlockedTitle,
  });
}

/// 1..20 arası Sezon Bileti kademesi.
class SeasonPassTier {
  final int tier;
  final int requiredXp;
  final SeasonPassReward freeReward;
  final SeasonPassReward goldReward;

  const SeasonPassTier({
    required this.tier,
    required this.requiredXp,
    required this.freeReward,
    required this.goldReward,
  });
}

/// 30 Başarım, Rozetler, 11 Oyun Modu Ustalık ve 20 Kademeli "Lülülü Pass" Sezon Bileti Servisi.
class AchievementPassService extends ChangeNotifier {
  static final AchievementPassService _instance =
      AchievementPassService._internal();
  factory AchievementPassService() => _instance;
  static AchievementPassService get instance => _instance;
  AchievementPassService._internal() {
    // Kalıcı durum (açık başarımlar, sezon XP'si, talep edilen kademeler)
    // hiçbir çağırıcı load() çağırmadığı için ilk erişimde yüklenir;
    // aksi hâlde talep edilen kademeler her açılışta yeniden talep
    // edilebilirdi. Yükleme bitince notifyListeners ile dinleyiciler
    // (örn. başarımlar sayfası) yenilenir.
    unawaited(_autoLoad());
  }

  /// İlk erişimde kalıcı durumu sessizce yükler; okuma başarısız olursa
  /// bellek-içi varsayılanlarla devam edilir (açık `load()` çağrıları
  /// hatayı çağırıcıya aynen iletmeye devam eder).
  Future<void> _autoLoad() async {
    try {
      await load();
    } catch (_) {}
  }

  static const String _prefUnlockedAchievements =
      'lululu_ach_unlocked_ids_v1';
  static const String _prefAchievementProgress =
      'lululu_ach_progress_map_v1';
  static const String _prefUnlockedTitles = 'lululu_ach_unlocked_titles_v1';
  static const String _prefSelectedTitle = 'lululu_ach_selected_title_v1';
  static const String _prefSeasonXp = 'lululu_season_pass_xp_v1';
  static const String _prefHasGoldPass = 'lululu_season_has_gold_pass_v1';
  static const String _prefClaimedFreeTiers =
      'lululu_season_claimed_free_tiers_v1';
  static const String _prefClaimedGoldTiers =
      'lululu_season_claimed_gold_tiers_v1';
  static const String _prefBonusStars = 'lululu_season_bonus_stars_v1';

  /// 5 kategori altında 30 özgün Türkçe başarım listesi.
  static const List<AchievementDefinition> all30Achievements = [
    // 1. BİRLEŞTİRME USTASI (6 Başarım)
    AchievementDefinition(
      id: 'merge_first',
      title: 'İlk Birleşim',
      description: 'Arenada ilk iki böceği birleştirerek evrimi başlat.',
      category: AchievementCategory.mergeMaster,
      iconEmoji: '🐣',
      targetValue: 1,
      coinReward: 100,
      seasonXpReward: 60,
      rewardTitle: 'Çırak Böcekçi',
    ),
    AchievementDefinition(
      id: 'merge_100',
      title: '100 Birleşim',
      description: 'Toplam 100 başarılı böcek birleşimine ulaş.',
      category: AchievementCategory.mergeMaster,
      iconEmoji: '🔥',
      targetValue: 100,
      coinReward: 300,
      seasonXpReward: 140,
      rewardTitle: 'Sentez Ustası',
    ),
    AchievementDefinition(
      id: 'merge_1000',
      title: '1.000 Birleşim',
      description: 'Toplam 1.000 böcek birleştirerek mutfağı fethet.',
      category: AchievementCategory.mergeMaster,
      iconEmoji: '🌋',
      targetValue: 1000,
      coinReward: 900,
      seasonXpReward: 320,
      rewardTitle: 'Evrim Lordu',
    ),
    AchievementDefinition(
      id: 'merge_tier_12',
      title: 'Osman Kralı Tier 12',
      description: 'Tier 12 Osman Kralı evrim kademesine ulaş.',
      category: AchievementCategory.mergeMaster,
      iconEmoji: '👑',
      targetValue: 12,
      coinReward: 1200,
      seasonXpReward: 400,
      rewardTitle: "Osman'ın Sağ Kolu",
    ),
    AchievementDefinition(
      id: 'merge_tier_13',
      title: 'Makara Efsanesi Tier 13',
      description: 'En üst evrim olan Tier 13 Makara Efsanesini yarat.',
      category: AchievementCategory.mergeMaster,
      iconEmoji: '🌌',
      targetValue: 13,
      coinReward: 2000,
      seasonXpReward: 600,
      rewardTitle: 'Lülülü İmparatoru',
    ),
    AchievementDefinition(
      id: 'merge_chain_reaction',
      title: 'Zincirleme Reaksiyon',
      description: 'Tek hamlede 4 ardışık zincirleme birleşim tetikle.',
      category: AchievementCategory.mergeMaster,
      iconEmoji: '⛓️',
      targetValue: 4,
      coinReward: 450,
      seasonXpReward: 180,
      rewardTitle: 'Zincir Kıran',
    ),

    // 2. 11 MOD ŞAMPİYONU (11 Başarım)
    AchievementDefinition(
      id: 'mode_suika_master',
      title: 'Suika Arena Ustası',
      description: 'Suika Arena modunda 2.500 puana ulaş.',
      category: AchievementCategory.modeChampion,
      iconEmoji: '🍉',
      targetValue: 2500,
      coinReward: 350,
      seasonXpReward: 150,
      rewardTitle: 'Kavanoz Hakimi',
    ),
    AchievementDefinition(
      id: 'mode_2048_master',
      title: '2048 Grid Şampiyonu',
      description: '2048 Grid modunda 2.048 puana ulaş.',
      category: AchievementCategory.modeChampion,
      iconEmoji: '🔢',
      targetValue: 2048,
      coinReward: 350,
      seasonXpReward: 150,
      rewardTitle: 'Kare Matrisi',
    ),
    AchievementDefinition(
      id: 'mode_balloon_master',
      title: 'Balon Patlat Ustası',
      description: 'Balon Patlat modunda 1.500 puana ulaş.',
      category: AchievementCategory.modeChampion,
      iconEmoji: '🎈',
      targetValue: 1500,
      coinReward: 350,
      seasonXpReward: 150,
      rewardTitle: 'Keskin İğne',
    ),
    AchievementDefinition(
      id: 'mode_match3_master',
      title: 'Match 3 Şampiyonu',
      description: 'Match 3 modunda 1.800 puana ulaş.',
      category: AchievementCategory.modeChampion,
      iconEmoji: '💎',
      targetValue: 1800,
      coinReward: 350,
      seasonXpReward: 150,
      rewardTitle: 'Üçlü Dizici',
    ),
    AchievementDefinition(
      id: 'mode_connect_master',
      title: 'Bağla Patlat Ustası',
      description: 'Bağla Patlat modunda 1.600 puana ulaş.',
      category: AchievementCategory.modeChampion,
      iconEmoji: '🔗',
      targetValue: 1600,
      coinReward: 350,
      seasonXpReward: 150,
      rewardTitle: 'Hat Bağlayıcı',
    ),
    AchievementDefinition(
      id: 'mode_stack_master',
      title: 'Stack Drop Mimarı',
      description: 'Stack Drop modunda 1.400 puana ulaş.',
      category: AchievementCategory.modeChampion,
      iconEmoji: '🏗️',
      targetValue: 1400,
      coinReward: 350,
      seasonXpReward: 150,
      rewardTitle: 'Kule Mimarı',
    ),
    AchievementDefinition(
      id: 'mode_terlik_master',
      title: 'Terlik Tap Efsanesi',
      description: 'Terlik Tap modunda 2.000 puana ulaş.',
      category: AchievementCategory.modeChampion,
      iconEmoji: '🩴',
      targetValue: 2000,
      coinReward: 400,
      seasonXpReward: 175,
      rewardTitle: 'Terlik Nişancısı',
    ),
    AchievementDefinition(
      id: 'mode_yuva_master',
      title: 'Yuva Savunması Komutanı',
      description: 'Yuva Savunması modunda 1.800 puana ulaş.',
      category: AchievementCategory.modeChampion,
      iconEmoji: '🛡️',
      targetValue: 1800,
      coinReward: 400,
      seasonXpReward: 175,
      rewardTitle: 'Yuva Muhafızı',
    ),
    AchievementDefinition(
      id: 'mode_osmantus_master',
      title: 'Osmantuş Ritim Kralı',
      description: 'Osmantuş modunda 1.700 puana ulaş.',
      category: AchievementCategory.modeChampion,
      iconEmoji: '🥁',
      targetValue: 1700,
      coinReward: 400,
      seasonXpReward: 175,
      rewardTitle: 'Dikkiş Virtüözü',
    ),
    AchievementDefinition(
      id: 'mode_scream_master',
      title: 'Çığlık Böcek Koşucusu',
      description: 'Çığlık Böcek modunda 1.500 puana ulaş.',
      category: AchievementCategory.modeChampion,
      iconEmoji: '😱',
      targetValue: 1500,
      coinReward: 400,
      seasonXpReward: 175,
      rewardTitle: 'Desibel Şampiyonu',
    ),
    AchievementDefinition(
      id: 'mode_makarayiz_master',
      title: 'Makarayız Şovmeni',
      description: 'Makarayız modunda 2.200 puana ulaş.',
      category: AchievementCategory.modeChampion,
      iconEmoji: '🪩',
      targetValue: 2200,
      coinReward: 450,
      seasonXpReward: 200,
      rewardTitle: 'Makara Ustası',
    ),

    // 3. KOMBO & REFLEKS (5 Başarım)
    AchievementDefinition(
      id: 'combo_5x',
      title: '5x Kombo',
      description: 'Herhangi bir modda 5x kesintisiz kombo serisi yakala.',
      category: AchievementCategory.comboReflex,
      iconEmoji: '⚡',
      targetValue: 5,
      coinReward: 250,
      seasonXpReward: 120,
      rewardTitle: 'Hızlı Bilek',
    ),
    AchievementDefinition(
      id: 'combo_10x_ultra',
      title: '10x Ultra Kombo',
      description: '10x Ultra Kombo zincirine ulaşarak ekranı salla.',
      category: AchievementCategory.comboReflex,
      iconEmoji: '💥',
      targetValue: 10,
      coinReward: 600,
      seasonXpReward: 240,
      rewardTitle: 'Ultra Kombo Şefi',
    ),
    AchievementDefinition(
      id: 'reflex_perfect_stack',
      title: 'Kusursuz Stack',
      description: 'Stack modunda üst üste 10 bloğu sıfır taşmayla hizala.',
      category: AchievementCategory.comboReflex,
      iconEmoji: '📐',
      targetValue: 10,
      coinReward: 500,
      seasonXpReward: 200,
      rewardTitle: 'Milimetrik Göz',
    ),
    AchievementDefinition(
      id: 'reflex_flawless_terlik',
      title: 'Hiç Kaçırmadan Terlik',
      description: 'Terlik modunda art arda 25 isabetli vuruş yap.',
      category: AchievementCategory.comboReflex,
      iconEmoji: '🎯',
      targetValue: 25,
      coinReward: 550,
      seasonXpReward: 220,
      rewardTitle: 'Anne Terliği Keskin Nişancısı',
    ),
    AchievementDefinition(
      id: 'reflex_f16_blitz',
      title: 'Yıldırım Refleks',
      description: '3 saniye içinde 6 böceği etkisiz hale getir veya birleştir.',
      category: AchievementCategory.comboReflex,
      iconEmoji: '✈️',
      targetValue: 6,
      coinReward: 450,
      seasonXpReward: 180,
      rewardTitle: 'F-16 Pilotu',
    ),

    // 4. BÖCEK STÜDYO YÖNETMENİ (4 Başarım)
    AchievementDefinition(
      id: 'studio_first_video',
      title: 'İlk Sahne Videosu',
      description: 'Böcek Stüdyosunda ilk sahne videonu kaydet.',
      category: AchievementCategory.studioDirector,
      iconEmoji: '🎥',
      targetValue: 1,
      coinReward: 300,
      seasonXpReward: 150,
      rewardTitle: 'Set Yönetmeni',
    ),
    AchievementDefinition(
      id: 'studio_first_gif',
      title: 'İlk GIF',
      description: 'Böcek Stüdyosunda ilk animasyonlu GIF çıkartmanı üret.',
      category: AchievementCategory.studioDirector,
      iconEmoji: '🎞️',
      targetValue: 1,
      coinReward: 250,
      seasonXpReward: 130,
      rewardTitle: 'GIF Sanatçısı',
    ),
    AchievementDefinition(
      id: 'studio_10_likes',
      title: '10 Beğeni',
      description: 'Stüdyo sahnelerinde toplam 10 beğeni reaksiyonu topla.',
      category: AchievementCategory.studioDirector,
      iconEmoji: '❤️',
      targetValue: 10,
      coinReward: 450,
      seasonXpReward: 190,
      rewardTitle: 'Sahne Yıldızı',
    ),
    AchievementDefinition(
      id: 'studio_viral_sharer',
      title: 'Viral Paylaşımcı',
      description: '5 farklı böcek sahnesini veya çıkartmasını paylaş.',
      category: AchievementCategory.studioDirector,
      iconEmoji: '🚀',
      targetValue: 5,
      coinReward: 700,
      seasonXpReward: 280,
      rewardTitle: 'Viral Fenomen',
    ),

    // 5. EKONOMİ & KOLEKSİYON (4 Başarım)
    AchievementDefinition(
      id: 'eco_10000_coins',
      title: '10.000 Altın Biriktir',
      description: 'Kasanda aynı anda 10.000 altına ulaş.',
      category: AchievementCategory.economyCollection,
      iconEmoji: '💰',
      targetValue: 10000,
      coinReward: 1000,
      seasonXpReward: 350,
      rewardTitle: 'Altın Kasası Baronu',
    ),
    AchievementDefinition(
      id: 'eco_12_families',
      title: 'Tüm 12 Böcek Ailesini Aç',
      description: 'Koleksiyondaki 12 böcek ailesinin tamamının kilidini aç.',
      category: AchievementCategory.economyCollection,
      iconEmoji: '🧬',
      targetValue: 12,
      coinReward: 1200,
      seasonXpReward: 400,
      rewardTitle: 'Entomoloji Profesörü',
    ),
    AchievementDefinition(
      id: 'eco_7_day_streak',
      title: '7 Gün Seri',
      description: '7 gün üst üste oyuna girerek günlük hediye serisini tamamla.',
      category: AchievementCategory.economyCollection,
      iconEmoji: '📅',
      targetValue: 7,
      coinReward: 800,
      seasonXpReward: 300,
      rewardTitle: 'Sadık Lülülücü',
    ),
    AchievementDefinition(
      id: 'eco_all_33_boosters',
      title: '33 Güçlendirici Koleksiyoncusu',
      description: '11 moddaki 33 özel güçlendiricinin tamamına sahip ol.',
      category: AchievementCategory.economyCollection,
      iconEmoji: '🧰',
      targetValue: 33,
      coinReward: 1500,
      seasonXpReward: 500,
      rewardTitle: 'Cephanelik Komutanı',
    ),
  ];

  /// 1'den 20'ye kadar kademeli "Lülülü Sezon Bileti" tablosu.
  static final List<SeasonPassTier> all20PassTiers = [
    const SeasonPassTier(
      tier: 1,
      requiredXp: 100,
      freeReward: SeasonPassReward(
        label: '150 Altın',
        iconEmoji: '🪙',
        coins: 150,
      ),
      goldReward: SeasonPassReward(
        label: '400 Altın + 2 Terlik',
        iconEmoji: '🩴',
        coins: 400,
        boosters: {'terlik': 2},
      ),
    ),
    const SeasonPassTier(
      tier: 2,
      requiredXp: 250,
      freeReward: SeasonPassReward(
        label: '+3 Enerji',
        iconEmoji: '⚡',
        energy: 3,
      ),
      goldReward: SeasonPassReward(
        label: '500 Altın + 2 Raid',
        iconEmoji: '🧴',
        coins: 500,
        boosters: {'raid': 2},
      ),
    ),
    const SeasonPassTier(
      tier: 3,
      requiredXp: 420,
      freeReward: SeasonPassReward(
        label: '250 Altın + 1 Yıldız',
        iconEmoji: '⭐',
        coins: 250,
        stars: 1,
      ),
      goldReward: SeasonPassReward(
        label: '2 F-16 + 3 Yıldız',
        iconEmoji: '✈️',
        stars: 3,
        boosters: {'f16': 2},
      ),
    ),
    const SeasonPassTier(
      tier: 4,
      requiredXp: 600,
      freeReward: SeasonPassReward(
        label: '2048 Paketi (Undo + Shuffle)',
        iconEmoji: '🔢',
        boosters: {'undo': 2, 'shuffle': 1},
      ),
      goldReward: SeasonPassReward(
        label: '750 Altın + 2048 Tam Paket',
        iconEmoji: '💠',
        coins: 750,
        boosters: {'undo': 3, 'shuffle': 2, 'pair': 2},
      ),
    ),
    const SeasonPassTier(
      tier: 5,
      requiredXp: 820,
      freeReward: SeasonPassReward(
        label: '400 Altın + 5 Enerji',
        iconEmoji: '⚡',
        coins: 400,
        energy: 5,
      ),
      goldReward: SeasonPassReward(
        label: '1.000 Altın + Balon Paketi',
        iconEmoji: '🎈',
        coins: 1000,
        boosters: {'triple': 2, 'bombb': 2, 'slowb': 2},
      ),
    ),
    const SeasonPassTier(
      tier: 6,
      requiredXp: 1060,
      freeReward: SeasonPassReward(
        label: 'Match 3 Çekiç x2',
        iconEmoji: '🔨',
        boosters: {'hammer': 2},
      ),
      goldReward: SeasonPassReward(
        label: '900 Altın + Match 3 Seti',
        iconEmoji: '💎',
        coins: 900,
        boosters: {'hammer': 2, 'bomb3': 2, 'hunter': 2},
      ),
    ),
    const SeasonPassTier(
      tier: 7,
      requiredXp: 1320,
      freeReward: SeasonPassReward(
        label: '500 Altın + 2 Yıldız',
        iconEmoji: '⭐',
        coins: 500,
        stars: 2,
      ),
      goldReward: SeasonPassReward(
        label: '1.200 Altın + Bağla Seti',
        iconEmoji: '🔗',
        coins: 1200,
        boosters: {'chain': 2, 'bolt': 2, 'magnet': 2},
      ),
    ),
    const SeasonPassTier(
      tier: 8,
      requiredXp: 1600,
      freeReward: SeasonPassReward(
        label: '+5 Enerji + Dondur x2',
        iconEmoji: '❄️',
        energy: 5,
        boosters: {'freeze': 2},
      ),
      goldReward: SeasonPassReward(
        label: '1.400 Altın + Stack Seti',
        iconEmoji: '🏗️',
        coins: 1400,
        boosters: {'freeze': 2, 'widen': 2, 'slows': 2},
      ),
    ),
    const SeasonPassTier(
      tier: 9,
      requiredXp: 1900,
      freeReward: SeasonPassReward(
        label: '650 Altın',
        iconEmoji: '🪙',
        coins: 650,
      ),
      goldReward: SeasonPassReward(
        label: '1.600 Altın + Terlik Tap Seti',
        iconEmoji: '🩴',
        coins: 1600,
        boosters: {'dblslip': 2, 'goldslip': 2, 'spraybug': 2},
      ),
    ),
    const SeasonPassTier(
      tier: 10,
      requiredXp: 2250,
      freeReward: SeasonPassReward(
        label: '1.000 Altın + 3 Yıldız',
        iconEmoji: '🌟',
        coins: 1000,
        stars: 3,
      ),
      goldReward: SeasonPassReward(
        label: '2.500 Altın + Yuva Savunma Seti',
        iconEmoji: '🛡️',
        coins: 2500,
        stars: 5,
        boosters: {'yuva_dblslip': 2, 'yuva_goldslip': 2, 'nest_shield': 2},
        unlockedTitle: 'Sezon Şövalyesi',
      ),
    ),
    const SeasonPassTier(
      tier: 11,
      requiredXp: 2620,
      freeReward: SeasonPassReward(
        label: '+6 Enerji',
        iconEmoji: '⚡',
        energy: 6,
      ),
      goldReward: SeasonPassReward(
        label: '1.800 Altın + Osmantuş Seti',
        iconEmoji: '🥁',
        coins: 1800,
        boosters: {'dik': 2, 'ring': 2, 'mic': 2},
      ),
    ),
    const SeasonPassTier(
      tier: 12,
      requiredXp: 3020,
      freeReward: SeasonPassReward(
        label: '800 Altın + Zıplama Botu x2',
        iconEmoji: '🥾',
        coins: 800,
        boosters: {'jump': 2},
      ),
      goldReward: SeasonPassReward(
        label: '2.000 Altın + Çığlık Böcek Seti',
        iconEmoji: '😱',
        coins: 2000,
        boosters: {'jump': 2, 'shield': 2, 'nitro': 2},
      ),
    ),
    const SeasonPassTier(
      tier: 13,
      requiredXp: 3450,
      freeReward: SeasonPassReward(
        label: '950 Altın + 2 Yıldız',
        iconEmoji: '⭐',
        coins: 950,
        stars: 2,
      ),
      goldReward: SeasonPassReward(
        label: '2.200 Altın + Makarayız Seti',
        iconEmoji: '🪩',
        coins: 2200,
        boosters: {'beat': 2, 'auto': 2, 'x2': 2},
      ),
    ),
    const SeasonPassTier(
      tier: 14,
      requiredXp: 3900,
      freeReward: SeasonPassReward(
        label: 'Suika Üçlü Paket (Raid/Terlik/F16)',
        iconEmoji: '🧰',
        boosters: {'raid': 2, 'terlik': 2, 'f16': 1},
      ),
      goldReward: SeasonPassReward(
        label: '2.600 Altın + Suika Mega Paket',
        iconEmoji: '🚀',
        coins: 2600,
        boosters: {'raid': 4, 'terlik': 4, 'f16': 3},
      ),
    ),
    const SeasonPassTier(
      tier: 15,
      requiredXp: 4400,
      freeReward: SeasonPassReward(
        label: '1.250 Altın + 8 Enerji',
        iconEmoji: '⚡',
        coins: 1250,
        energy: 8,
      ),
      goldReward: SeasonPassReward(
        label: '3.000 Altın + 6 Yıldız + 10 Enerji',
        iconEmoji: '👑',
        coins: 3000,
        stars: 6,
        energy: 10,
      ),
    ),
    const SeasonPassTier(
      tier: 16,
      requiredXp: 4950,
      freeReward: SeasonPassReward(
        label: '1.400 Altın + 2 F-16',
        iconEmoji: '✈️',
        coins: 1400,
        boosters: {'f16': 2},
      ),
      goldReward: SeasonPassReward(
        label: '3.400 Altın + Karma Güç Paketi',
        iconEmoji: '🎁',
        coins: 3400,
        boosters: {
          'f16': 3,
          'hunter': 2,
          'bolt': 2,
          'goldslip': 2,
          'x2': 2,
        },
      ),
    ),
    const SeasonPassTier(
      tier: 17,
      requiredXp: 5550,
      freeReward: SeasonPassReward(
        label: '1.600 Altın + 4 Yıldız',
        iconEmoji: '🌟',
        coins: 1600,
        stars: 4,
      ),
      goldReward: SeasonPassReward(
        label: '3.800 Altın + 8 Yıldız',
        iconEmoji: '🌟',
        coins: 3800,
        stars: 8,
      ),
    ),
    const SeasonPassTier(
      tier: 18,
      requiredXp: 6200,
      freeReward: SeasonPassReward(
        label: '+10 Enerji + 3 Anne Terliği',
        iconEmoji: '🩴',
        energy: 10,
        boosters: {'terlik': 3},
      ),
      goldReward: SeasonPassReward(
        label: '4.200 Altın + 15 Enerji',
        iconEmoji: '⚡',
        coins: 4200,
        energy: 15,
      ),
    ),
    const SeasonPassTier(
      tier: 19,
      requiredXp: 6900,
      freeReward: SeasonPassReward(
        label: '2.000 Altın + 5 Yıldız',
        iconEmoji: '💰',
        coins: 2000,
        stars: 5,
      ),
      goldReward: SeasonPassReward(
        label: '5.000 Altın + 10 Yıldız',
        iconEmoji: '💎',
        coins: 5000,
        stars: 10,
      ),
    ),
    const SeasonPassTier(
      tier: 20,
      requiredXp: 7700,
      freeReward: SeasonPassReward(
        label: '3.000 Altın + 33 Güçlendirici Paketi (x1)',
        iconEmoji: '🏆',
        coins: 3000,
        stars: 5,
        energy: 10,
        grantsAll33PowerPack: true,
        unlockedTitle: 'Lülülü Pass Mezunu',
      ),
      goldReward: SeasonPassReward(
        label: '7.500 Altın + 33 Güçlendirici Mega Paketi (x2)',
        iconEmoji: '👑',
        coins: 7500,
        stars: 15,
        energy: 20,
        grantsAll33PowerPack: true,
        boosters: {'raid': 2, 'terlik': 2, 'f16': 2},
        unlockedTitle: 'Altın Lülülü İmparatoru',
      ),
    ),
  ];

  final Set<String> unlockedAchievementIds = <String>{};
  final Map<String, int> achievementProgress = <String, int>{};
  final Set<String> unlockedTitles = <String>{};
  String selectedTitle = 'Yeni Böcekçi';

  int _seasonXp = 0;
  int get seasonXp => _seasonXp;

  bool _hasGoldPass = false;
  bool get hasGoldPass => _hasGoldPass;

  int _bonusStars = 0;

  final Set<int> claimedFreeTiers = <int>{};
  final Set<int> claimedGoldTiers = <int>{};

  final List<AchievementDefinition> _toastQueue = <AchievementDefinition>[];
  final ValueNotifier<AchievementDefinition?> activeToastNotifier =
      ValueNotifier<AchievementDefinition?>(null);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Mevcut Sezon Bileti kademesini (0..20) hesaplar.
  int get currentPassTier {
    var tier = 0;
    for (final t in all20PassTiers) {
      if (_seasonXp >= t.requiredXp) {
        tier = t.tier;
      } else {
        break;
      }
    }
    return tier;
  }

  /// Bir sonraki Sezon Bileti kademesine ilerleme oranı (`0.0`..`1.0`).
  double get nextTierProgress {
    final current = currentPassTier;
    if (current >= all20PassTiers.length) return 1.0;
    final prevXp = current == 0 ? 0 : all20PassTiers[current - 1].requiredXp;
    final nextXp = all20PassTiers[current].requiredXp;
    final span = (nextXp - prevXp).clamp(1, 999999);
    return ((_seasonXp - prevXp) / span).clamp(0.0, 1.0);
  }

  /// Bir sonraki kademe için gereken toplam XP.
  int get nextTierRequiredXp {
    final current = currentPassTier;
    if (current >= all20PassTiers.length) {
      return all20PassTiers.last.requiredXp;
    }
    return all20PassTiers[current].requiredXp;
  }

  /// Belirtilen başarım tanımını döndürür.
  AchievementDefinition? getDefinition(String id) {
    for (final def in all30Achievements) {
      if (def.id == id) return def;
    }
    return null;
  }

  bool isAchievementUnlocked(String id) => unlockedAchievementIds.contains(id);

  int getAchievementProgress(String id) => achievementProgress[id] ?? 0;

  double getAchievementProgressRatio(String id) {
    final def = getDefinition(id);
    if (def == null) return 0.0;
    if (isAchievementUnlocked(id)) return 1.0;
    final current = getAchievementProgress(id);
    return (current / def.targetValue).clamp(0.0, 1.0);
  }

  List<AchievementDefinition> achievementsByCategory(
    AchievementCategory category,
  ) {
    return all30Achievements
        .where((def) => def.category == category)
        .toList(growable: false);
  }

  /// Kalıcı verileri `SharedPreferences` üzerinden yükler.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    unlockedAchievementIds
      ..clear()
      ..addAll(prefs.getStringList(_prefUnlockedAchievements) ?? const []);

    achievementProgress.clear();
    final progressRaw = prefs.getString(_prefAchievementProgress);
    if (progressRaw != null && progressRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(progressRaw) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          achievementProgress[key] = (value as num).toInt();
        });
      } catch (_) {}
    }

    unlockedTitles
      ..clear()
      ..addAll(prefs.getStringList(_prefUnlockedTitles) ?? const []);
    for (final id in unlockedAchievementIds) {
      final def = getDefinition(id);
      if (def != null && def.rewardTitle.isNotEmpty) {
        unlockedTitles.add(def.rewardTitle);
      }
    }

    selectedTitle = prefs.getString(_prefSelectedTitle) ??
        (unlockedTitles.isNotEmpty ? unlockedTitles.first : 'Yeni Böcekçi');

    _seasonXp = (prefs.getInt(_prefSeasonXp) ?? 0).clamp(0, 9999999);
    _hasGoldPass = prefs.getBool(_prefHasGoldPass) ?? false;
    _bonusStars = (prefs.getInt(_prefBonusStars) ?? 0).clamp(0, 999999);

    claimedFreeTiers
      ..clear()
      ..addAll(
        (prefs.getStringList(_prefClaimedFreeTiers) ?? const [])
            .map(int.tryParse)
            .whereType<int>(),
      );
    claimedGoldTiers
      ..clear()
      ..addAll(
        (prefs.getStringList(_prefClaimedGoldTiers) ?? const [])
            .map(int.tryParse)
            .whereType<int>(),
      );

    _loaded = true;
    notifyListeners();
  }

  /// Testler veya sıfırlama senaryoları için durumu temizler.
  Future<void> resetForTesting() async {
    unlockedAchievementIds.clear();
    achievementProgress.clear();
    unlockedTitles.clear();
    selectedTitle = 'Yeni Böcekçi';
    _seasonXp = 0;
    _hasGoldPass = false;
    _bonusStars = 0;
    claimedFreeTiers.clear();
    claimedGoldTiers.clear();
    _toastQueue.clear();
    activeToastNotifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefUnlockedAchievements);
    await prefs.remove(_prefAchievementProgress);
    await prefs.remove(_prefUnlockedTitles);
    await prefs.remove(_prefSelectedTitle);
    await prefs.remove(_prefSeasonXp);
    await prefs.remove(_prefHasGoldPass);
    await prefs.remove(_prefClaimedFreeTiers);
    await prefs.remove(_prefClaimedGoldTiers);
    await prefs.remove(_prefBonusStars);
    notifyListeners();
  }

  /// Hesap silme için yerel başarım / sezon verisinin tamamını temizler
  /// (hesap-silme, yerel-temizlik). [resetForTesting] gövdesi yalnız
  /// bellek-içi temizlik + 9 prefs anahtarının kaldırılması yapar
  /// (yan etkisi yok), bu yüzden üretimdeki silme aynı mantığı bu
  /// metot üzerinden çağırır; testler `resetForTesting` adını
  /// kullanmaya devam eder.
  Future<void> clearLocalData() => resetForTesting();

  /// Altın Bilet (Gold Pass) kilidini açar.
  Future<bool> activateGoldPass({int coinCost = 0}) async {
    if (_hasGoldPass) return true;
    if (coinCost > 0) {
      final spent = await ProgressManager.instance.spendCoins(coinCost);
      if (!spent) return false;
    }
    _hasGoldPass = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefHasGoldPass, true);
    notifyListeners();
    return true;
  }

  /// Başarım ilerlemesini artırır veya mutlak değer olarak günceller; hedefe ulaşıldığında kilidi açar.
  Future<bool> recordProgress(
    String achievementId, {
    int delta = 1,
    int? absoluteValue,
  }) async {
    final def = getDefinition(achievementId);
    if (def == null) return false;
    if (unlockedAchievementIds.contains(achievementId)) {
      return false;
    }

    final current = achievementProgress[achievementId] ?? 0;
    int next = current;
    if (absoluteValue != null) {
      if (absoluteValue > current) {
        next = absoluteValue;
      }
    } else if (delta > 0) {
      next = current + delta;
    }

    achievementProgress[achievementId] = next.clamp(0, def.targetValue);
    await _persistAchievements();

    if (next >= def.targetValue) {
      return unlockAchievement(achievementId);
    }

    notifyListeners();
    return false;
  }

  /// Belirtilen başarımın kilidini doğrudan açar (çift ödül korumalı).
  /// Açıldığında oyuncuya altın (`ProgressManager.instance.addCoins`), Sezon XP'si
  /// ve özel profil unvanı (`unlockedTitles`) kazandırır.
  Future<bool> unlockAchievement(String achievementId) async {
    final def = getDefinition(achievementId);
    if (def == null) return false;
    if (unlockedAchievementIds.contains(achievementId)) {
      return false;
    }

    unlockedAchievementIds.add(achievementId);
    achievementProgress[achievementId] = def.targetValue;

    if (def.rewardTitle.isNotEmpty) {
      unlockedTitles.add(def.rewardTitle);
      if (selectedTitle == 'Yeni Böcekçi') {
        selectedTitle = def.rewardTitle;
      }
    }

    if (def.coinReward > 0) {
      await ProgressManager.instance.addCoins(def.coinReward);
    }

    if (def.seasonXpReward > 0) {
      await addSeasonXp(
        def.seasonXpReward,
        reason: 'achievement:${def.id}',
      );
    }

    _enqueueToast(def);
    await _persistAchievements();
    notifyListeners();
    return true;
  }

  /// 11 oyun modundan birinde skor elde edildiğinde ilgili ustalık başarımını günceller.
  Future<bool> evaluateModeScore(String modeId, int score) async {
    final normalized = ProgressManager.normalizeModeId(modeId);
    const modeToAchievement = <String, String>{
      'suika': 'mode_suika_master',
      'grid_2048': 'mode_2048_master',
      'balloon_pop': 'mode_balloon_master',
      'match3': 'mode_match3_master',
      'connect_pop': 'mode_connect_master',
      'stack_drop': 'mode_stack_master',
      'terlik_tap': 'mode_terlik_master',
      'yuva_defense': 'mode_yuva_master',
      'osmantus': 'mode_osmantus_master',
      'scream_roach': 'mode_scream_master',
      'makarayiz': 'mode_makarayiz_master',
    };
    final achId = modeToAchievement[normalized];
    if (achId == null) return false;
    return recordProgress(achId, absoluteValue: score);
  }

  /// Mevcut `ProgressManager` durumunu (altın, seri, güçlendiriciler, mod skorları) tarayarak
  /// hak edilen başarımları senkronize eder.
  Future<int> syncWithProgressManager() async {
    final pm = ProgressManager.instance;
    var newlyUnlocked = 0;

    if (await recordProgress('eco_10000_coins', absoluteValue: pm.coins)) {
      newlyUnlocked++;
    }
    if (await recordProgress('eco_7_day_streak', absoluteValue: pm.streak)) {
      newlyUnlocked++;
    }
    if (await recordProgress(
      'eco_12_families',
      absoluteValue: pm.unlockedTiers.length,
    )) {
      newlyUnlocked++;
    }

    var ownedPowerTypes = 0;
    for (final key in ProgressManager.all33PowerKeys) {
      if (pm.powerCount(key) > 0) {
        ownedPowerTypes++;
      }
    }
    if (await recordProgress(
      'eco_all_33_boosters',
      absoluteValue: ownedPowerTypes,
    )) {
      newlyUnlocked++;
    }

    for (final entry in pm.modeHighScores.entries) {
      if (await evaluateModeScore(entry.key, entry.value)) {
        newlyUnlocked++;
      }
    }
    return newlyUnlocked;
  }

  /// Sezon Bileti XP'si ekler ve `SharedPreferences` üzerine kaydeder.
  Future<int> addSeasonXp(int xp, {String reason = ''}) async {
    if (xp <= 0) return _seasonXp;
    _seasonXp = (_seasonXp + xp).clamp(0, 9999999);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSeasonXp, _seasonXp);
    notifyListeners();
    return _seasonXp;
  }

  /// Belirtilen kademenin ödülünün talep edilip edilemeyeceğini döndürür.
  bool canClaimPassTierReward(int tier, {bool goldTrack = false}) {
    if (tier < 1 || tier > all20PassTiers.length) return false;
    final tierDef = all20PassTiers[tier - 1];
    if (_seasonXp < tierDef.requiredXp) return false;
    if (goldTrack) {
      if (!_hasGoldPass) return false;
      return !claimedGoldTiers.contains(tier);
    } else {
      return !claimedFreeTiers.contains(tier);
    }
  }

  bool isPassTierClaimed(int tier, {bool goldTrack = false}) {
    return goldTrack
        ? claimedGoldTiers.contains(tier)
        : claimedFreeTiers.contains(tier);
  }

  /// Sezon Bileti kademe ödülünü toplar (çift talep korumalı ve kalıcı).
  Future<bool> claimPassTierReward(int tier, {bool goldTrack = false}) async {
    if (!canClaimPassTierReward(tier, goldTrack: goldTrack)) {
      return false;
    }

    final tierDef = all20PassTiers[tier - 1];
    final reward = goldTrack ? tierDef.goldReward : tierDef.freeReward;

    if (goldTrack) {
      claimedGoldTiers.add(tier);
    } else {
      claimedFreeTiers.add(tier);
    }

    final pm = ProgressManager.instance;
    if (reward.coins > 0) {
      await pm.addCoins(reward.coins);
    }
    if (reward.energy > 0) {
      EnergyService.instance.addEnergy(reward.energy);
    }
    if (reward.stars > 0) {
      _bonusStars += reward.stars;
    }
    if (reward.grantsAll33PowerPack) {
      final packCount = goldTrack ? 2 : 1;
      for (final powerKey in ProgressManager.all33PowerKeys) {
        await pm.incrementPowerCount(powerKey, packCount);
      }
    }
    for (final entry in reward.boosters.entries) {
      await pm.incrementPowerCount(entry.key, entry.value);
    }
    if (reward.unlockedTitle != null && reward.unlockedTitle!.isNotEmpty) {
      unlockedTitles.add(reward.unlockedTitle!);
    }

    await _persistSeasonPass();
    await _persistAchievements();
    notifyListeners();
    return true;
  }

  void _enqueueToast(AchievementDefinition def) {
    if (activeToastNotifier.value == null) {
      activeToastNotifier.value = def;
    } else {
      _toastQueue.add(def);
    }
  }

  /// Aktif başarım bildirimini kapatır ve kuyrukta bekleyen varsa sıradakini gösterir.
  void dismissActiveToast() {
    if (_toastQueue.isNotEmpty) {
      activeToastNotifier.value = _toastQueue.removeAt(0);
    } else {
      activeToastNotifier.value = null;
    }
    notifyListeners();
  }

  Future<void> _persistAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefUnlockedAchievements,
      unlockedAchievementIds.toList(),
    );
    await prefs.setString(
      _prefAchievementProgress,
      jsonEncode(achievementProgress),
    );
    await prefs.setStringList(
      _prefUnlockedTitles,
      unlockedTitles.toList(),
    );
    await prefs.setString(_prefSelectedTitle, selectedTitle);
  }

  Future<void> _persistSeasonPass() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSeasonXp, _seasonXp);
    await prefs.setBool(_prefHasGoldPass, _hasGoldPass);
    await prefs.setInt(_prefBonusStars, _bonusStars);
    await prefs.setStringList(
      _prefClaimedFreeTiers,
      claimedFreeTiers.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList(
      _prefClaimedGoldTiers,
      claimedGoldTiers.map((e) => e.toString()).toList(),
    );
  }
}
