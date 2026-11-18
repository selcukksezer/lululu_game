import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import '../screens/result_screen.dart';
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
/// 4. Görev: [recordPlayTask] `true` ise `recordTaskProgress('play')`
///    kaydedilir.
/// 5. Sonuç ekranı: [showGameResult] ile gösterilir; dönüş değeri
///    "TEKRAR OYNA" seçildiyse `true`'dur.
///
/// TEK-ÖDEME SÖZLEŞMESİ (korunur): ödeme bu yardımcı (çağırıcı tarafı)
/// tarafından yapılır; sonuç ekranı `coinsAwardedByCaller` varsayılanı
/// (`true`) ile tekrar ödemez. [settle] veren çağırıcılar ödemeyi
/// yalnızca o kapama içinde yapar; yardımcı ayrıca ödemez.
///
/// ADIM YALITIMI (Y1/B8): 1–4. adımların her biri kendi try-catch'iyle
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
/// [awaitSettle] `false` ise 1–4. adımlar ateşle-unut başlatılır ve
/// sonuç ekranı beklenmeden gösterilir (Suika / 2048'in eski
/// `unawaited` davranışı). `true` (varsayılan) ise adımlar sırayla
/// beklenir (diğer modların eski `await` davranışı). Adımlar
/// birbirinden bağımsız depolara yazdığı için (coin / mod skoru /
/// liderlik / günlük görev) aralarındaki sıra gözlemlenebilir
/// davranışı değiştirmez. Ateşle-unut yolunda da adım hataları log +
/// telemetride görünür kılınır (`settleStep` hata fırlatmaz).
///
/// [stars] verilmezse `ResultScoring.starsFor(score: score, best: best)`
/// kullanılır. [bestScore] verilmezse `max(score, best)` (tura ait
/// gerçek rekor) kullanılır; [bestCombo]/[merges] verilmezse 0
/// gösterilir — tohum varsayılanlar (4820/x6/18) oyun-içi sonuç
/// ekranına sızmaz (playtest bulgu #3). [ResultScoring] sabitleri
/// yalnız doğrudan açılan `/result` prototip sayfasının varsayılanı
/// olarak kalır.
///
/// [won] verilmezse `score > 0` sayılır: skor 0'ken BİTİR veya
/// canların bitmesi kayıp başlığını ("OYUN BİTTİ!") gösterir
/// (playtest bulgu #2). Kazanma/kaybetme ayrımı olan modlar
/// (Match3/Connect hedefi, can-biten modlar) açık değer geçirir.
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
}) async {
  final pm = ProgressManager.instance;
  // F10-kuralı: skor > 0 ise varsayılan ödeme en az 1 coindir.
  final effectiveCoins = coins ??
      (score > 0 ? max(1, ResultScoring.coinsFor(score)) : 0);
  final effectiveStars =
      stars ?? ResultScoring.starsFor(score: score, best: best);
  final effectiveWon = won ?? score > 0;

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
          await pm.recordTaskProgress('play');
        });
      }
    } catch (error, stack) {
      // Adım yalıtımı üstündeki beklenmedik hata: sonuç diyaloğu yine
      // gösterilsin (B8); hata görünür kılınır.
      _logSettleError('settle', error, stack);
    }
  }

  if (awaitSettle) {
    await settleStep();
  } else {
    unawaited(settleStep());
  }
  // Ödeme sürerken tur değişmiş olabilir: gösterimden önce tekrar kontrol.
  if (!isStillValid()) return false;
  if (!context.mounted) return false;
  return showGameResult(
    context,
    score: score,
    coins: effectiveCoins,
    stars: effectiveStars,
    bestScore: bestScore ?? max(score, best),
    bestCombo: bestCombo ?? 0,
    merges: merges ?? 0,
    won: effectiveWon,
  );
}
