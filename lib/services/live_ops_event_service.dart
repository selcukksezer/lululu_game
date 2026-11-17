import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'adaptive_difficulty_service.dart';
import 'anti_cheat_service.dart';

/// 4 özel dönüşümlü Canlı Etkinlik (LiveOps) türü.
enum LiveOpsEventType {
  /// 1. Altın Yağmuru Festivali (`coinMultiplier: 2.0`)
  goldRainFestival,

  /// 2. Terlik Fırtınası Maratonu (`terlik` & `yuva` modlarında `1.5x` skor ve ekstra terlik)
  slipperStormMarathon,

  /// 3. Osmantuş & Makara Müzik Gecesi (`osmantus` & `makara` ritim modlarında `1.5x` kombo ödülü)
  osmantusMakaraMusicNight,

  /// 4. Büyük Birleşim Çılgınlığı (`suika`, `grid2048`, `match3`, `connect` modlarında ekstra yıldız şansı)
  grandMergeFrenzy,
}

/// Bir LiveOps etkinliğinin kurallarını, hedef oyun modlarını ve çarpanlarını
/// tanımlayan değişmez (immutable) veri modeli.
@immutable
class LiveOpsEventDefinition {
  const LiveOpsEventDefinition({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.targetModes,
    this.coinMultiplier = 1.0,
    this.scoreMultiplier = 1.0,
    this.comboRewardMultiplier = 1.0,
    this.extraSlippers = 0,
    this.extraStarChance = 0.0,
  });

  final LiveOpsEventType type;
  final String id;
  final String title;
  final String subtitle;

  /// Etkinliğin geçerli olduğu kanonik oyun modları.
  final Set<String> targetModes;

  /// Altın kazanım çarpanı (Altın Yağmuru Festivali'nde `2.0`).
  final double coinMultiplier;

  /// Skor çarpanı (Terlik Fırtınası Maratonu'nda `terlik` & `yuva` için `1.5`).
  final double scoreMultiplier;

  /// Ritim kombo ödül çarpanı (Osmantuş & Makara Müzik Gecesi'nde `1.5`).
  final double comboRewardMultiplier;

  /// Maç başında verilen ekstra terlik/cephane sayısı.
  final int extraSlippers;

  /// Birleşimlerde ekstra yıldız düşme olasılığı (`0.0`..`1.0`).
  final double extraStarChance;

  /// Belirtilen oyun modunun bu etkinlik kapsamında olup olmadığını kontrol eder.
  bool appliesToMode(String rawMode) {
    final canonical = AdaptiveDifficultyService.tryResolveModeKey(rawMode);
    if (canonical == null) return false;
    return targetModes.contains(canonical);
  }
}

/// Belirli bir oyun modu ve zaman dilimi için hesaplanan birleşik LiveOps
/// çarpanları.
@immutable
class LiveOpsModeModifiers {
  const LiveOpsModeModifiers({
    required this.modeId,
    required this.activeEventIds,
    required this.coinMultiplier,
    required this.scoreMultiplier,
    required this.comboRewardMultiplier,
    required this.extraSlippers,
    required this.extraStarChance,
  });

  final String modeId;
  final List<String> activeEventIds;
  final double coinMultiplier;
  final double scoreMultiplier;
  final double comboRewardMultiplier;
  final int extraSlippers;
  final double extraStarChance;

  bool get hasActiveEvent => activeEventIds.isNotEmpty;

  @override
  String toString() =>
      'LiveOpsModeModifiers(mode: $modeId, events: $activeEventIds, '
      'coin: ${coinMultiplier}x, score: ${scoreMultiplier}x, '
      'combo: ${comboRewardMultiplier}x, slippers: +$extraSlippers, '
      'starChance: +$extraStarChance)';
}

/// Çevrimdışı "Böcek Kavanozu" (Idle Piggy/Jar Rewards) birikim durumu ve
/// talep (`claimIdleJarCoins`) sonucu.
@immutable
class IdleJarClaimResult {
  const IdleJarClaimResult({
    required this.isSuccess,
    required this.grantedCoins,
    required this.newCoinBalance,
    required this.accumulatedMinutes,
    required this.highestUnlockedTier,
    required this.coinsPerMinute,
    required this.reason,
  });

  final bool isSuccess;
  final int grantedCoins;
  final int newCoinBalance;
  final int accumulatedMinutes;
  final int highestUnlockedTier;
  final double coinsPerMinute;
  final String reason;

  @override
  String toString() =>
      'IdleJarClaimResult(isSuccess: $isSuccess, grantedCoins: $grantedCoins, '
      'newBalance: $newCoinBalance, minutes: $accumulatedMinutes, '
      'tier: $highestUnlockedTier, reason: $reason)';
}

/// Dönüşümlü Canlı Etkinlikler (LiveOps) & Çevrimdışı "Böcek Kavanozu"
/// Birikim Servisi.
///
/// Sorumluluklar:
/// 1. **4 Özel Dönüşümlü LiveOps Etkinliği:**
///    Haftanın gününe (`weekday`: 1..7) ve saatine (`hour`: 0..23) göre aktif
///    olan etkinlikleri yönetir:
///    - *Altın Yağmuru Festivali* (`coinMultiplier: 2.0`)
///    - *Terlik Fırtınası Maratonu* (`terlik` & `yuva` modlarında `1.5x` skor ve ekstra terlik)
///    - *Osmantuş & Makara Müzik Gecesi* (`osmantus` & `makara` ritim modlarında `1.5x` kombo ödülü)
///    - *Büyük Birleşim Çılgınlığı* (`suika`, `grid2048`, `match3`, `connect` modlarında ekstra yıldız şansı)
/// 2. **Çevrimdışı "Böcek Kavanozu" (Idle Piggy/Jar Rewards):**
///    Oyuncu oyunda değilken açtığı en yüksek böcek ailesi seviyesine
///    (`highestUnlockedTier`) göre dakikada altın biriktiren (maksimum 8 saat /
///    480 dakika ve 2.400 altın tavanlı) ve [AntiCheatService] cihaz saati
///    geri/ileri alma kontrolüyle korunan [claimIdleJarCoins] mekanizmasını sunar.
class LiveOpsEventService {
  LiveOpsEventService({AntiCheatService? antiCheat})
      : _antiCheat = antiCheat ?? AntiCheatService.instance;

  static final LiveOpsEventService instance = LiveOpsEventService();

  static const String _prefsLastActiveMsKey = 'lululu_idle_jar_last_active_ms';
  static const String _prefsHighestSeenMsKey = 'lululu_idle_jar_highest_seen_ms';

  /// Çevrimdışı Böcek Kavanozu maksimum birikim süresi (8 saat = 480 dakika).
  static const int maxIdleHours = 8;
  static const int maxIdleMinutes = maxIdleHours * 60; // 480 dakika

  /// Çevrimdışı Böcek Kavanozu maksimum altın tavanı (2.400 altın).
  static const int maxJarCoins = 2400;

  /// Cihaz saatinin ileri alınması (forward clock tamper) hilesini yakalamak için
  /// izin verilen maksimum çevrimdışı sıçrama penceresi (30 gün).
  static const Duration maxAllowedOfflineJump = Duration(days: 30);

  /// Böcek Kavanozu ödülü talep etmek için gereken minimum çevrimdışı süre (1 dakika).
  static const int minClaimableMinutes = 1;

  final AntiCheatService _antiCheat;

  /// Oturum içinde gözlemlenen en yüksek zaman damgası (saat geri alma koruması).
  int? _highestObservedTimestampMs;

  /// Son çevrimdışı başlangıç / son kavanoz toplama zaman damgası.
  int? _lastJarReferenceTimestampMs;

  /// 4 özel LiveOps etkinliğinin tam tanımları.
  static final Map<LiveOpsEventType, LiveOpsEventDefinition> eventCatalog =
      <LiveOpsEventType, LiveOpsEventDefinition>{
    LiveOpsEventType.goldRainFestival: LiveOpsEventDefinition(
      type: LiveOpsEventType.goldRainFestival,
      id: 'gold_rain_festival',
      title: 'Altın Yağmuru Festivali',
      subtitle: 'Tüm oyun modlarında kazandığın altınlar 2 katına çıkar!',
      targetModes: AdaptiveDifficultyService.supportedModes.toSet(),
      coinMultiplier: 2.0,
      scoreMultiplier: 1.0,
      comboRewardMultiplier: 1.0,
      extraSlippers: 0,
      extraStarChance: 0.0,
    ),
    LiveOpsEventType.slipperStormMarathon: const LiveOpsEventDefinition(
      type: LiveOpsEventType.slipperStormMarathon,
      id: 'slipper_storm_marathon',
      title: 'Terlik Fırtınası Maratonu',
      subtitle: 'Terlik ve Yuva Savunması modlarında 1.5x skor ve ekstra terlik!',
      targetModes: <String>{'terlik', 'yuva'},
      coinMultiplier: 1.0,
      scoreMultiplier: 1.5,
      comboRewardMultiplier: 1.0,
      extraSlippers: 2,
      extraStarChance: 0.0,
    ),
    LiveOpsEventType.osmantusMakaraMusicNight: const LiveOpsEventDefinition(
      type: LiveOpsEventType.osmantusMakaraMusicNight,
      id: 'osmantus_makara_music_night',
      title: 'Osmantuş & Makara Müzik Gecesi',
      subtitle: 'Osmantuş ve Makara ritim modlarında 1.5x kombo ödülü!',
      targetModes: <String>{'osmantus', 'makara'},
      coinMultiplier: 1.0,
      scoreMultiplier: 1.0,
      comboRewardMultiplier: 1.5,
      extraSlippers: 0,
      extraStarChance: 0.0,
    ),
    LiveOpsEventType.grandMergeFrenzy: const LiveOpsEventDefinition(
      type: LiveOpsEventType.grandMergeFrenzy,
      id: 'grand_merge_frenzy',
      title: 'Büyük Birleşim Çılgınlığı',
      subtitle: 'Suika, 2048, Match-3 ve Bağla modlarında ekstra yıldız şansı!',
      targetModes: <String>{'suika', 'grid2048', 'match3', 'connect'},
      coinMultiplier: 1.0,
      scoreMultiplier: 1.0,
      comboRewardMultiplier: 1.0,
      extraSlippers: 0,
      extraStarChance: 0.35,
    ),
  };

  // ---------------------------------------------------------------------------
  // 1. DÖNÜŞÜMLÜ CANLI ETKİNLİKLER (LIVEOPS SCHEDULE & MULTIPLIERS)
  // ---------------------------------------------------------------------------

  /// Haftanın gününe (`weekday`: 1=Pazartesi .. 7=Pazar) ve saatine (`hour`: 0..23)
  /// göre aktif olan birincil ve varsa hafta sonu/akşam bonus etkinliklerini döndürür.
  ///
  /// Zamanlama Kuralları (Deterministik Rotasyon):
  /// - Saat dilimi blokları (her gün 6 saatlik 4 ana pencere):
  ///   - `00:00 - 05:59`: Gün indeksine göre dönüşümlü etkinlik
  ///   - `06:00 - 11:59`: *Büyük Birleşim Çılgınlığı* (`grandMergeFrenzy`)
  ///   - `12:00 - 17:59`: *Terlik Fırtınası Maratonu* (`slipperStormMarathon`)
  ///   - `18:00 - 23:59`: *Osmantuş & Makara Müzik Gecesi* (`osmantusMakaraMusicNight`)
  /// - Gün bazlı ek tema / festival aktivasyonu (ana etkinliğe eklenir):
  ///   - Cumartesi (`6`) ve Pazar (`7`): *Altın Yağmuru Festivali*
  ///     (`goldRainFestival`) gün boyu aktiftir.
  ///   - Cuma (`5`): `16:00` ve sonrasında *Altın Yağmuru Festivali* aktiftir
  ///     (ayrıca `00:00 - 05:59` dönüşümünde de ana etkinliktir).
  ///   - Pazartesi (`1`): `12:00` öncesinde *Altın Yağmuru Festivali* aktiftir.
  ///   - Salı (`2`): *Terlik Fırtınası Maratonu* (`slipperStormMarathon`) eklenir.
  ///   - Çarşamba (`3`): *Büyük Birleşim Çılgınlığı* (`grandMergeFrenzy`)
  ///     eklenir; *Altın Yağmuru Festivali* Çarşamba günü aktif değildir.
  ///   - Perşembe (`4`): *Osmantuş & Makara Müzik Gecesi*
  ///     (`osmantusMakaraMusicNight`) eklenir.
  List<LiveOpsEventDefinition> getActiveEvents({DateTime? at}) {
    final targetTime = at ?? DateTime.now();
    final weekday = targetTime.weekday.clamp(1, 7); // 1 = Mon .. 7 = Sun
    final hour = targetTime.hour.clamp(0, 23);

    final activeTypes = <LiveOpsEventType>{};

    // 1. Saat dilimine göre ana dönüşümlü etkinlik:
    if (hour >= 6 && hour < 12) {
      activeTypes.add(LiveOpsEventType.grandMergeFrenzy);
    } else if (hour >= 12 && hour < 18) {
      activeTypes.add(LiveOpsEventType.slipperStormMarathon);
    } else if (hour >= 18 && hour <= 23) {
      activeTypes.add(LiveOpsEventType.osmantusMakaraMusicNight);
    } else {
      // 00:00 - 05:59 arası haftanın gününe göre 4 etkinlik arasında döner
      const ordered = LiveOpsEventType.values;
      activeTypes.add(ordered[(weekday - 1) % ordered.length]);
    }

    // 2. Haftanın gününe göre ek tema / festival etkinliği:
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      // Hafta sonu boyunca Altın Yağmuru Festivali her zaman aktiftir!
      activeTypes.add(LiveOpsEventType.goldRainFestival);
    } else if (weekday == DateTime.friday && hour >= 16) {
      // Cuma akşamından itibaren Altın Yağmuru Festivali başlar
      activeTypes.add(LiveOpsEventType.goldRainFestival);
    } else if (weekday == DateTime.monday && hour < 12) {
      activeTypes.add(LiveOpsEventType.goldRainFestival);
    } else if (weekday == DateTime.tuesday) {
      activeTypes.add(LiveOpsEventType.slipperStormMarathon);
    } else if (weekday == DateTime.wednesday) {
      activeTypes.add(LiveOpsEventType.grandMergeFrenzy);
    } else if (weekday == DateTime.thursday) {
      activeTypes.add(LiveOpsEventType.osmantusMakaraMusicNight);
    }

    return activeTypes
        .map((t) => eventCatalog[t]!)
        .toList(growable: false);
  }

  /// Belirtilen oyun modu ve zaman (veya manuel verilen etkinlik listesi) için
  /// geçerli tüm LiveOps çarpanlarını hesaplar.
  LiveOpsModeModifiers getModifiersForMode(
    String mode, {
    DateTime? at,
    Iterable<LiveOpsEventType>? overrideActiveEvents,
  }) {
    final canonicalMode = AdaptiveDifficultyService.resolveModeKey(mode);
    final events = overrideActiveEvents != null
        ? overrideActiveEvents.map((t) => eventCatalog[t]!).toList(growable: false)
        : getActiveEvents(at: at);

    var coinMult = 1.0;
    var scoreMult = 1.0;
    var comboMult = 1.0;
    var extraSlippers = 0;
    var extraStarChance = 0.0;
    final appliedIds = <String>[];

    for (final event in events) {
      if (!event.appliesToMode(canonicalMode)) continue;
      appliedIds.add(event.id);
      if (event.coinMultiplier > coinMult) {
        coinMult = event.coinMultiplier;
      }
      if (event.scoreMultiplier > scoreMult) {
        scoreMult = event.scoreMultiplier;
      }
      if (event.comboRewardMultiplier > comboMult) {
        comboMult = event.comboRewardMultiplier;
      }
      extraSlippers += event.extraSlippers;
      extraStarChance += event.extraStarChance;
    }

    return LiveOpsModeModifiers(
      modeId: canonicalMode,
      activeEventIds: List<String>.unmodifiable(appliedIds),
      coinMultiplier: coinMult.clamp(1.0, 3.0),
      scoreMultiplier: scoreMult.clamp(1.0, 3.0),
      comboRewardMultiplier: comboMult.clamp(1.0, 3.0),
      extraSlippers: extraSlippers.clamp(0, 10),
      extraStarChance: extraStarChance.clamp(0.0, 1.0),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. ÇEVRİMDIŞI "BÖCEK KAVANOZU" (IDLE PIGGY/JAR REWARDS)
  // ---------------------------------------------------------------------------

  /// Oyuncunun açtığı en yüksek böcek ailesi seviyesine (`highestUnlockedTier`: 1..12)
  /// göre dakikada biriken altın miktarını döndürür.
  ///
  /// Seviye 1'de dakikada `1.0` altın, Seviye 10 ve üzerinde dakikada `5.0` altın
  /// birikir (`5.0 * 480 dakika = 2.400 altın` maksimum kavanoz tavanı).
  static double coinsPerMinuteForTier(int highestUnlockedTier) {
    final safeTier = highestUnlockedTier.clamp(1, 12);
    // Tier 1 -> 1.0, Tier 2 -> 1.45, ..., Tier 9 -> 4.6, Tier 10+ -> 5.0 (tavan kırpması)
    final rate = 1.0 + ((safeTier - 1) * 0.45);
    return rate.clamp(1.0, 5.0);
  }

  /// Oyuncu oyundan çıkarken veya arka plana geçerken kavanoz zaman damgasını
  /// günceller. Saat geri alma hilesine karşı monotonik kontrol uygular.
  bool recordPlayerActiveTimestamp({DateTime? now, int? nowMs}) {
    final currentMs =
        nowMs ?? (now ?? DateTime.now()).millisecondsSinceEpoch;
    if (currentMs <= 0) return false;

    if (_highestObservedTimestampMs != null &&
        currentMs < _highestObservedTimestampMs!) {
      // Cihaz saati geri alınmış!
      return false;
    }

    _lastJarReferenceTimestampMs = currentMs;
    if (_highestObservedTimestampMs == null ||
        currentMs > _highestObservedTimestampMs!) {
      _highestObservedTimestampMs = currentMs;
    }
    return true;
  }

  /// Çevrimdışı "Böcek Kavanozu" ödülünü (`claimIdleJarCoins`) talep eder.
  ///
  /// Güvenlik & Kurallar:
  /// 1. `highestUnlockedTier` değerine göre dakikada altın hesaplar.
  /// 2. Maksimum **8 saat (`480` dakika)** ve **2.400 altın (`maxJarCoins`)**
  ///    tavanını kesin olarak uygular.
  /// 3. [AntiCheatService] ile:
  ///    - Cihaz saatinin geri alınmasını (`clock_rollback_detected`) engeller.
  ///    - Cihaz saatinin aşırı ileri alınmasını (`clock_forward_tamper_detected`)
  ///      engeller.
  ///    - Tekrar saldırılarını (`claimId` / `nonce`) ve bekleme süresi ihlalini
  ///      engeller.
  ///    - Altın kazanımını `validateCoinDelta` ile doğrular.
  IdleJarClaimResult claimIdleJarCoins({
    required int highestUnlockedTier,
    int currentCoinBalance = 0,
    DateTime? lastActiveAt,
    int? lastActiveMs,
    DateTime? now,
    int? nowMs,
    String? claimId,
    Duration? maxOfflineJump,
  }) {
    final safeTier = highestUnlockedTier.clamp(1, 12);
    final rate = coinsPerMinuteForTier(safeTier);
    final safeBalance =
        currentCoinBalance.clamp(0, AntiCheatService.maxCoinBalanceCap);

    final effectiveNowMs =
        nowMs ?? (now ?? DateTime.now()).millisecondsSinceEpoch;
    final effectiveLastMs = lastActiveMs ??
        lastActiveAt?.millisecondsSinceEpoch ??
        _lastJarReferenceTimestampMs;

    if (effectiveLastMs == null || effectiveLastMs <= 0) {
      return IdleJarClaimResult(
        isSuccess: false,
        grantedCoins: 0,
        newCoinBalance: safeBalance,
        accumulatedMinutes: 0,
        highestUnlockedTier: safeTier,
        coinsPerMinute: rate,
        reason: 'missing_last_active_timestamp',
      );
    }

    // 1. Saat Geri Alma (Clock Rollback) Hilesi Kontrolü:
    if (effectiveNowMs < effectiveLastMs ||
        (_highestObservedTimestampMs != null &&
            effectiveNowMs < _highestObservedTimestampMs!)) {
      return IdleJarClaimResult(
        isSuccess: false,
        grantedCoins: 0,
        newCoinBalance: safeBalance,
        accumulatedMinutes: 0,
        highestUnlockedTier: safeTier,
        coinsPerMinute: rate,
        reason: 'clock_rollback_detected',
      );
    }

    final elapsedMs = effectiveNowMs - effectiveLastMs;

    // 2. Saat İleri Alma (Forward Clock Tamper) Hilesi Kontrolü:
    final allowedJumpMs =
        (maxOfflineJump ?? maxAllowedOfflineJump).inMilliseconds;
    if (elapsedMs > allowedJumpMs) {
      return IdleJarClaimResult(
        isSuccess: false,
        grantedCoins: 0,
        newCoinBalance: safeBalance,
        accumulatedMinutes: 0,
        highestUnlockedTier: safeTier,
        coinsPerMinute: rate,
        reason: 'clock_forward_tamper_detected',
      );
    }

    final rawMinutes = elapsedMs ~/ 60000;
    if (rawMinutes < minClaimableMinutes) {
      return IdleJarClaimResult(
        isSuccess: false,
        grantedCoins: 0,
        newCoinBalance: safeBalance,
        accumulatedMinutes: 0,
        highestUnlockedTier: safeTier,
        coinsPerMinute: rate,
        reason: 'insufficient_idle_time',
      );
    }

    // 3. 8 Saat (480 Dakika) ve 2.400 Altın Tavanı Hesaplaması:
    final cappedMinutes = rawMinutes.clamp(0, maxIdleMinutes);
    final calculatedCoins = (cappedMinutes * rate).floor().clamp(1, maxJarCoins);

    // 4. AntiCheatService Ekonomi Doğrulaması:
    //    Cooldown/replay kaydından ÖNCE yapılır: ekonomi reddederse
    //    claimId tüketilmez, aynı claimId ile tekrar deneme yapılabilir.
    final economyCheck = _antiCheat.validateCoinDelta(
      calculatedCoins,
      currentBalance: safeBalance,
      allowSpend: false,
      maxGrant: maxJarCoins,
    );

    if (!economyCheck.isValid && economyCheck.sanitizedDelta <= 0) {
      return IdleJarClaimResult(
        isSuccess: false,
        grantedCoins: 0,
        newCoinBalance: safeBalance,
        accumulatedMinutes: cappedMinutes,
        highestUnlockedTier: safeTier,
        coinsPerMinute: rate,
        reason: economyCheck.reason,
      );
    }

    // 5. AntiCheatService Cooldown & Replay Kontrolü (talebi kaydeder):
    final canClaim = _antiCheat.canClaimCooldownReward(
      'idle_bug_jar',
      claimId: claimId,
      cooldown: const Duration(minutes: minClaimableMinutes),
      nowMs: effectiveNowMs,
      lastClaimMs: effectiveLastMs,
      recordClaim: true,
    );
    if (!canClaim) {
      return IdleJarClaimResult(
        isSuccess: false,
        grantedCoins: 0,
        newCoinBalance: safeBalance,
        accumulatedMinutes: 0,
        highestUnlockedTier: safeTier,
        coinsPerMinute: rate,
        reason: 'anti_cheat_cooldown_or_replay_blocked',
      );
    }

    // Zaman damgalarını ilerlet
    _lastJarReferenceTimestampMs = effectiveNowMs;
    if (_highestObservedTimestampMs == null ||
        effectiveNowMs > _highestObservedTimestampMs!) {
      _highestObservedTimestampMs = effectiveNowMs;
    }

    final granted = economyCheck.sanitizedDelta.clamp(0, maxJarCoins);
    return IdleJarClaimResult(
      isSuccess: true,
      grantedCoins: granted,
      newCoinBalance: economyCheck.sanitizedBalance,
      accumulatedMinutes: cappedMinutes,
      highestUnlockedTier: safeTier,
      coinsPerMinute: rate,
      reason: 'ok',
    );
  }

  /// Yerel depolamadan (`SharedPreferences`) kavanoz zaman damgalarını yükler.
  Future<void> loadJarStateFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _lastJarReferenceTimestampMs = prefs.getInt(_prefsLastActiveMsKey);
    _highestObservedTimestampMs = prefs.getInt(_prefsHighestSeenMsKey);
  }

  /// Yerel depolamaya (`SharedPreferences`) kavanoz zaman damgalarını kaydeder.
  Future<void> saveJarStateToPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (_lastJarReferenceTimestampMs != null) {
      await prefs.setInt(_prefsLastActiveMsKey, _lastJarReferenceTimestampMs!);
    }
    if (_highestObservedTimestampMs != null) {
      await prefs.setInt(_prefsHighestSeenMsKey, _highestObservedTimestampMs!);
    }
  }

  /// Testler için kavanoz geçmişini sıfırlar.
  void resetJarState() {
    _highestObservedTimestampMs = null;
    _lastJarReferenceTimestampMs = null;
    _antiCheat.resetRewardHistory();
  }
}
