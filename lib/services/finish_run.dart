import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/result_screen.dart';
import 'achievement_pass_service.dart';
import 'game_telemetry_service.dart';
import 'leaderboard_service.dart';
import 'progress_manager.dart';

/// Tüketilmiş tur anahtarları (Y3): aynı anahtarla ikinci `finishRun`
/// çağrısı ödeme/gösterim yapmadan `false` döner. Bellek içi ve sınırlı
/// büyüklüktedir (en eski anahtar atılır); uygulama yeniden başlayınca
/// sıfırlanır — kalıcı çift-ödeme koruması değil, aynı oturumdaki
/// çift-sunum yarışını (BİTİR + bitiş kenarı, çift dokunma) kapatır.
final LinkedHashSet<String> _settledRunKeys = LinkedHashSet<String>();
const int _maxSettledRunKeys = 128;

/// Anahtar geçmeyen çağırıcılar için tekil varsayılan anahtar sayacı.
var _autoRunKeyCounter = 0;

/// [key] daha önce tüketilmediyse sahiplenir ve `true` döner; tüketildiyse
/// `false` döner. Senkron çalıştığı için eşzamanlı çift çağrıda yalnız
/// ilki sahiplenir.
bool _claimRunKey(String key) {
  if (_settledRunKeys.contains(key)) return false;
  _settledRunKeys.add(key);
  while (_settledRunKeys.length > _maxSettledRunKeys) {
    _settledRunKeys.remove(_settledRunKeys.first);
  }
  return true;
}

/// Settle adım hatasını log'a + telemetriye yazar (Y1). Telemetrinin
/// kendisi hata verse bile settle akışını bozamaz.
void _logSettleError(String step, Object error, StackTrace stack) {
  debugPrint('[lululu] finishRun: $step hatası: $error');
  try {
    GameTelemetryService.instance.recordError(
      error,
      stackTrace: stack,
      category: 'finish_run',
      action: 'settle_step_failed',
      meta: <String, Object?>{'step': step},
    );
  } catch (_) {
    // Telemetri hatası settle akışını bozamaz.
  }
}

/// Tek settle adımını kendi try-catch'iyle yalıtılmış çalıştırır (Y1):
/// adım hata verse bile kalan adımlar ve sonuç diyaloğu çalışır.
Future<void> _runSettleStep(
  String step,
  Future<void> Function() stepFn,
) async {
  try {
    await stepFn();
  } catch (error, stack) {
    _logSettleError(step, error, stack);
  }
}

/// S7 — görev kimliğinden görev başlığına: Görevler ekranındaki
/// başlıklarla aynı l10n anahtarları (`tasks_screen.dart::_taskTitle`
/// ile birebir). Bilinmeyen kimlikte ham kimlik döner (çekirdek yalnız
/// hedefi olan kimlikleri tamamlanmış sayar; pratikte ulaşılmaz).
String _taskTitleFor(AppLocalizations l10n, String taskId) =>
    switch (taskId) {
      'play' => l10n.taskPlay3Games,
      'merge' => l10n.taskMerge5,
      'video' => l10n.taskWatch1Video,
      'combo' => l10n.taskCombo4,
      _ => taskId,
    };

/// Tek tur-bitirme noktası (S1#49).
///
/// Eskiden ~11 ayrı `_presentResult` / `_triggerVictory` / `_triggerDefeat`
/// gövdesinde kopyalanmış adımlar tek yerden yapılır:
///
/// 1. Ödül: [coins] verilmezse skor > 0 iken en az 1 coin ödenir
///    (`max(1, ResultScoring.coinsFor(score))`, F10-kuralı); skor 0 ise
///    0 ödenir. [settle] verilirse varsayılan ödeme yerine o çalışır
///    (Suika kampanya akışı: `recordLevelResult` + fark coini;
///    Terlik Tap: birikmiş turun tek `grantArcadeDrop` ödemesi).
///    Açık [coins] tutarı aynen ödenir (F10 yalnız varsayılana uygulanır).
/// 2. İlerleme: [modeScoreId] verilirse `recordModeScore` yazılır.
/// 3. Liderlik: [leaderboardMode] verilirse `submitScore` gönderilir;
///    [leaderboardOnlyIfPositiveScore] `true` ise yalnız `score > 0` iken.
/// 4. Görev: [recordPlayTask] `true` ise
///    `recordTaskProgressDetailed('play')` kaydedilir; bu çağrıyla yeni
///    tamamlanan görev kimliği saklanır (7. adımda bildirilir).
/// 5. Başarım/pass (K1a): `modeScoreId ?? leaderboardMode` kimliğiyle
///    `evaluateModeScore` çağrılır (mod→başarım eşlemesi servis
///    tarafındadır; `grid2048` gibi takma adlar `normalizeModeId` ile
///    çözülür) ve skor > 0 ise tur XP'si verilir (kural aşağıda).
///    Kimlik geçmeyen çağırıcıda değerlendirme atlanır (4F sonrası
///    tüm modlar kimlik geçirir); hak edilen ustalık boot
///    senkronuyla (`syncWithProgressManager`) kapanır. Ödeme adımından bağımsızdır: `settle` veren çağırıcılar
///    da bu adımdan geçer.
/// 6. Sonuç ekranı: [showGameResult] ile gösterilir; dönüş değeri
///    "TEKRAR OYNA" seçildiyse `true`'dur.
/// 7. Bildirim (S7): sonuç ekranı kapandıktan sonra, bu turda yeni
///    tamamlanan görev varsa görev başlıklı snackbar gösterilir.
///    Ödül burada ödenmez; Görevler ekranından alınır. Bildirim
///    hata verse bile dönüş değeri bozulmaz.
///
/// TEK-ÖDEME SÖZLEŞMESİ (korunur): ödeme bu yardımcı (çağırıcı tarafı)
/// tarafından yapılır; sonuç ekranı `coinsAwardedByCaller` varsayılanı
/// (`true`) ile tekrar ödemez. [settle] veren çağırıcılar ödemeyi
/// yalnızca o kapama içinde yapar; yardımcı ayrıca ödemez.
///
/// ADIM YALITIMI (Y1/B8): 1–5. adımların her biri kendi try-catch'iyle
/// çalışır; bir adım hata verse bile kalan adımlar kaydedilir ve sonuç
/// diyaloğu gösterilir. Hatalar log'a + telemetriye yazılır.
///
/// GEÇERLİLİK (Y2): [stillValid] ödeme ÖNCESİNDE kontrol edilir; bayat
/// turun ödemesi hiç yapılmaz. Ödeme sonrasında gösterimden önce tekrar
/// kontrol edilir (ödeme sürerken tur değişmiş olabilir). Bağlam artık
/// bağlı (`mounted`) değilse de gösterim yapılmadan `false` dönülür.
///
/// ÇİFT-KAYIT KORUMASI (Y3): [idempotencyKey] verilirse aynı anahtarla
/// ikinci çağrı ödeme/gösterim yapmadan `false` döner. Anahtar
/// önerilen biçimi: `'<mod>:<tur başlangıç damgası>'` (ör.
/// `'suika:1731840000000'`). Anahtar geçilmezse çağrıya özgü tekil bir
/// varsayılan üretilir (meşru ayrı turlar birbirini engellemez).
/// Ödeme-öncesi geçerlilik elenmesinde anahtar serbest bırakılır, böylece
/// aynı turun geçerli yeniden denemesi engellenmez; ödeme yapıldıktan
/// sonra anahtar tüketilmiş kalır.
///
/// [awaitSettle] `false` ise 1–5. adımlar ateşle-unut başlatılır ve
/// sonuç ekranı beklenmeden gösterilir (Suika / 2048'in eski
/// `unawaited` davranışı). `true` (varsayılan) ise adımlar sırayla
/// beklenir (diğer modların eski `await` davranışı). Adımlar
/// birbirinden bağımsız depolara yazdığı için (coin / mod skoru /
/// liderlik / günlük görev) aralarındaki sıra gözlemlenebilir
/// davranışı değiştirmez. Ateşle-unut yolunda da adım hataları log +
/// telemetride görünür kılınır (`settleStep` hata fırlatmaz).
///
/// [stars] verilmezse modun sabit 3-yıldız çıtasına göre hesaplanır
/// (`ResultScoring.starsForMode`, `modeScoreId` anahtarıyla); kişisel
/// rekor yıldızı belirlemez (12Q-stars). Rekor kırma ayrıca hesaplanır
/// (`ResultScoring.isNewRecord`) ve sonuç ekranında yıldızdan ayrı bir
/// rozetle gösterilir. [bestScore] verilmezse `max(score, best)` (tura
/// ait gerçek rekor) kullanılır; [bestCombo]/[merges] verilmezse 0
/// gösterilir — tohum varsayılanlar (4820/x6/18) oyun-içi sonuç
/// ekranına sızmaz (playtest bulgu #3). [ResultScoring] sabitleri
/// yalnız doğrudan açılan `/result` prototip sayfasının varsayılanı
/// olarak kalır.
///
/// [won] verilmezse `score > 0` sayılır: skor 0'ken BİTİR veya
/// canların bitmesi kayıp başlığını ("OYUN BİTTİ!") gösterir
/// (playtest bulgu #2). Kazanma/kaybetme ayrımı olan modlar
/// (Match3/Connect hedefi, can-biten modlar) açık değer geçirir.
///
/// [firstClearExtras] (5B, salt-görünüm) verilirse settle tamamlandıktan
/// sonra, gösterimden önce çağrılır ve dönen ekstralar sonuç ekranında
/// ayrı bir bantta gösterilir. Ödeme yapmaz. Ekstralar settle özetinden
/// türetildiği için [awaitSettle] `false` olsa bile settle gösterimden
/// önce beklenir, böylece özet hazır olur. Verilmezse bant gösterilmez
/// (diğer çağırıcıların davranışı değişmez).
Future<bool> finishRun(
  BuildContext context, {
  required int score,
  required int best,
  int? coins,
  int? stars,
  int? bestScore,
  int? bestCombo,
  int? merges,
  bool? won,
  String? leaderboardMode,
  bool leaderboardOnlyIfPositiveScore = false,
  String? modeScoreId,
  Future<void> Function()? settle,
  bool awaitSettle = true,
  bool recordPlayTask = true,
  bool Function()? stillValid,
  String? idempotencyKey,
  FirstClearExtras Function()? firstClearExtras,
  // 12P: bitiş sebebi satırı; sonuç ekranının alt başlığında gösterilir.
  String? resultLine,
}) async {
  final pm = ProgressManager.instance;
  // F10-kuralı: skor > 0 ise varsayılan ödeme en az 1 coindir.
  final effectiveCoins = coins ??
      (score > 0 ? max(1, ResultScoring.coinsFor(score)) : 0);
  final effectiveStars = stars ??
      ResultScoring.starsForMode(
        score: score,
        modeScoreId: modeScoreId ?? '',
      );
  final effectiveWon = won ?? score > 0;
  // 12Q-stars: rekor rozeti yıldızdan ayrı hesaplanır.
  final effectiveIsNewRecord =
      ResultScoring.isNewRecord(score: score, best: best);

  // Y3: çift-kayıt koruması — anahtar ödeme öncesinde sahiplenilir.
  final explicitKey = idempotencyKey?.trim();
  final runKey = (explicitKey != null && explicitKey.isNotEmpty)
      ? explicitKey
      : 'auto:${DateTime.now().microsecondsSinceEpoch}:${_autoRunKeyCounter++}';
  if (!_claimRunKey(runKey)) return false;

  bool isStillValid() {
    if (!context.mounted) return false;
    if (stillValid == null) return true;
    try {
      return stillValid();
    } catch (error, stack) {
      _logSettleError('stillValid', error, stack);
      return false;
    }
  }

  // Y2: bayat tur ödeme ÖNCESİ elenir; anahtar serbest bırakılır ki
  // aynı turun geçerli yeniden denemesi engellenmesin.
  if (!isStillValid()) {
    _settledRunKeys.remove(runKey);
    return false;
  }

  // S7: bu turda yeni tamamlanan görev kimlikleri (en fazla bir;
  // playTask adımında dolar, sonuç ekranı kapandıktan sonra bildirilir).
  var newlyCompletedTasks = <String>[];

  Future<void> settleStep() async {
    try {
      await _runSettleStep('payment', () async {
        if (settle != null) {
          await settle();
        } else {
          await pm.addCoins(effectiveCoins);
        }
      });
      if (modeScoreId != null) {
        await _runSettleStep('modeScore', () async {
          await pm.recordModeScore(modeScoreId, score);
        });
      }
      if (leaderboardMode != null &&
          (!leaderboardOnlyIfPositiveScore || score > 0)) {
        await _runSettleStep('leaderboard', () async {
          await LeaderboardService.instance.submitScore(
            leaderboardMode,
            score,
          );
        });
      }
      if (recordPlayTask) {
        await _runSettleStep('playTask', () async {
          newlyCompletedTasks =
              await pm.recordTaskProgressDetailed('play');
        });
      }
      // K1a — başarım/pass adımı (Y1 yalıtımlı): hata verse bile
      // kalan adımlar ve sonuç diyaloğu çalışır. Ödeme adımından
      // bağımsızdır; `settle` veren çağırıcılar da buradan geçer.
      await _runSettleStep('achievements', () async {
        final service = AchievementPassService.instance;
        await service.ensureLoaded();
        final modeId = modeScoreId ?? leaderboardMode;
        if (modeId != null) {
          await service.evaluateModeScore(modeId, score);
        }
        // Tur XP kuralı (K1a kararı): tur başına sabit 10 + yıldız
        // başına 5 (yıldız 0..3 ile sınırlı → tur başına en çok 25),
        // yalnız skor > 0 iken (0 skorlu tur XP çiftçiliği yapmaz).
        // Emsal: kademe-1 eşiği 100 XP, kademe aralıkları 150..800 XP,
        // başarım XP ödülleri 60..600 — tur XP'si bilinçli olarak
        // bunların çok altında tutuldu; kademe 1 yaklaşık 5-7 skorlu
        // turda açılır. STATUS bayrağı: kural koordinatör/Selçuk
        // onayına açıktır.
        if (score > 0) {
          final starBonus = 5 * effectiveStars.clamp(0, 3);
          await service.addSeasonXp(
            10 + starBonus,
            reason: 'finish_run:${modeId ?? 'unknown'}',
          );
        }
      });
    } catch (error, stack) {
      // Adım yalıtımı üstündeki beklenmedik hata: sonuç diyaloğu yine
      // gösterilsin (B8); hata görünür kılınır.
      _logSettleError('settle', error, stack);
    }
  }

  final settleFuture = settleStep();
  // 5B: ekstralar settle özetinden türetiliyorsa gösterimden önce settle
  // beklenir (awaitSettle false olsa bile); yoksa özet henüz hazır olmaz.
  if (awaitSettle || firstClearExtras != null) {
    await settleFuture;
  } else {
    unawaited(settleFuture);
  }
  // Ödeme sürerken tur değişmiş olabilir: gösterimden önce tekrar kontrol.
  if (!isStillValid()) return false;
  if (!context.mounted) return false;
  // 5B: salt-görünüm ekstraları settle sonrasında bir kez okunur; okuma
  // hata verirse bant boş gösterilir, sonuç ekranı yine açılır.
  var displayExtras = const FirstClearExtras();
  if (firstClearExtras != null) {
    try {
      displayExtras = firstClearExtras();
    } catch (error, stack) {
      _logSettleError('firstClearExtras', error, stack);
    }
  }
  final replay = await showGameResult(
    context,
    score: score,
    coins: effectiveCoins,
    stars: effectiveStars,
    bestScore: bestScore ?? max(score, best),
    bestCombo: bestCombo ?? 0,
    merges: merges ?? 0,
    won: effectiveWon,
    isNewRecord: effectiveIsNewRecord,
    firstClearExtras: displayExtras,
    resultLine: resultLine,
  );
  // S7: sonuç ekranı kapandıktan sonra görev bildirimi. Ateşle-unut
  // yolunda settle hâlâ sürüyor olabilir; bildirimden önce tamamlanması
  // beklenir (adımlar yalıtımlı biter, bekleme akışı bozamaz).
  await settleFuture;
  if (newlyCompletedTasks.isNotEmpty && context.mounted) {
    try {
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.taskCompletedSnack(
              _taskTitleFor(l10n, newlyCompletedTasks.first),
            ),
          ),
        ),
      );
    } catch (error, stack) {
      _logSettleError('taskNotify', error, stack);
    }
  }
  return replay;
}
