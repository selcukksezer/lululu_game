import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../screens/result_screen.dart';
import 'leaderboard_service.dart';
import 'progress_manager.dart';

/// Tek tur-bitirme noktası (S1#49).
///
/// Eskiden ~11 ayrı `_presentResult` / `_triggerVictory` / `_triggerDefeat`
/// gövdesinde kopyalanmış adımlar tek yerden yapılır:
///
/// 1. Ödül: [coins] verilmezse `ResultScoring.coinsFor(score)` kadar
///    [ProgressManager.addCoins] ile ödenir (`addCoins` ≤0 tutarları
///    kendisi yoksayar). [settle] verilirse varsayılan ödeme yerine o
///    çalışır (Suika kampanya akışı: `recordLevelResult` + fark coini;
///    Terlik Tap: birikmiş turun tek `grantArcadeDrop` ödemesi).
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
/// [awaitSettle] `false` ise 1–4. adımlar ateşle-unut başlatılır ve
/// sonuç ekranı beklenmeden gösterilir (Suika / 2048'in eski
/// `unawaited` davranışı). `true` (varsayılan) ise adımlar sırayla
/// beklenir (diğer modların eski `await` davranışı). Adımlar
/// birbirinden bağımsız depolara yazdığı için (coin / mod skoru /
/// liderlik / günlük görev) aralarındaki sıra gözlemlenebilir
/// davranışı değiştirmez.
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
///
/// [stillValid] verilirse sonuç ekranı gösterilmeden önce kontrol
/// edilir; `false` dönerse ekran gösterilmeden `false` dönülür
/// (Terlik Tap'in tur-kimliği koruması). Bağlam artık bağlı
/// (`mounted`) değilse de ekran gösterilmeden `false` dönülür.
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
}) async {
  final pm = ProgressManager.instance;
  final effectiveCoins = coins ?? ResultScoring.coinsFor(score);
  final effectiveStars =
      stars ?? ResultScoring.starsFor(score: score, best: best);
  final effectiveWon = won ?? score > 0;

  Future<void> settleStep() async {
    if (settle != null) {
      await settle();
    } else {
      await pm.addCoins(effectiveCoins);
    }
    if (modeScoreId != null) {
      await pm.recordModeScore(modeScoreId, score);
    }
    if (leaderboardMode != null &&
        (!leaderboardOnlyIfPositiveScore || score > 0)) {
      await LeaderboardService.instance.submitScore(leaderboardMode, score);
    }
    if (recordPlayTask) {
      await pm.recordTaskProgress('play');
    }
  }

  if (awaitSettle) {
    await settleStep();
  } else {
    unawaited(settleStep());
  }
  if (!context.mounted) return false;
  if (stillValid != null && !stillValid()) return false;
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
