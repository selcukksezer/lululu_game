import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/progress_manager.dart';
import '../services/score_share_card.dart';
import '../theme/lululu_theme.dart';
import 'lululu_press.dart';

/// Shared play chrome: dot mesh, prototype HUD (`mode-top` + `game-hud`),
/// info strip (`evo-strip` / `mode-info`), and prototype result screen (`result-screen` / `res-card`).
class ArcadeScreen extends StatelessWidget {
  const ArcadeScreen({
    super.key,
    required this.title,
    required this.hint,
    required this.score,
    required this.best,
    required this.child,
    this.statLabel,
    this.statValue,
    this.statValueWidget,
    this.onRestart,
    this.onPausePressed,
    this.onHowToPlayVisibilityChanged,
    this.overlay,
    this.footer,
    this.backgroundAsset,
    this.tag,
    this.hintLabel,
    this.wideStage = false,
    this.prototypeChrome = false,
    this.prototypeBaglaChrome = false,
    this.prototypeStackChrome = false,
    this.tagColor = const Color(0xFFFF6B35),
    this.tagTextColor = Colors.white,
    this.showStatusBar = true,
    this.backgroundWash = false,
    this.stageWash = false,
    this.prototypeModeChrome = false,
    this.stageTopOffset = 0,
    this.prototypeStatsLayout = false,
    this.prototypeCoinLayout = false,
    this.topBackButtonWidth,
    this.prototypeTagLayout = false,
    this.evoStrip,
  });

  final String title;
  final String hint;
  final int score;
  final int best;
  final Widget child;
  final String? statLabel;
  final String? statValue;
  final Widget? statValueWidget;
  final VoidCallback? onRestart;

  /// Duraklat düğmesi kancası: verilirse başlık satırına 48px'lik
  /// duraklat düğmesi eklenir; verilmezse düğme çizilmez ve mevcut
  /// çağırıcılar (stack, scream) aynen çalışır.
  final VoidCallback? onPausePressed;

  /// Yardım sayfası görünürlük kancası: sayfa açılırken `true`,
  /// kapanırken `false` ile çağrılır. Gerçek-zamanlı modlar açılırken
  /// oyunu duraklatıp kapanırken yalnız bu kancayla duraklatıldıysa
  /// devam ettirmelidir.
  final ValueChanged<bool>? onHowToPlayVisibilityChanged;

  final Widget? overlay;
  final Widget? footer;
  final String? backgroundAsset;
  final String? tag;
  final String? hintLabel;
  final bool wideStage;
  final bool prototypeChrome;
  final bool prototypeBaglaChrome;
  final bool prototypeStackChrome;
  final Color tagColor;
  final Color tagTextColor;
  final bool showStatusBar;
  final bool backgroundWash;
  final bool stageWash;
  final bool prototypeModeChrome;
  final double stageTopOffset;
  final bool prototypeStatsLayout;
  final bool prototypeCoinLayout;
  final double? topBackButtonWidth;
  final bool prototypeTagLayout;
  final Widget? evoStrip;

  void _showHowToPlaySheet(BuildContext context) {
    onHowToPlayVisibilityChanged?.call(true);
    final future = showDialog<void>(
      context: context,
      barrierColor: const Color(0xB805070C),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: LululuColors.spaceNavy,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0x73FFB800),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 40,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${title.toUpperCase()} ${dialogContext.l10n.howToPlaySuffix}',
                style: GoogleFonts.baloo2(
                  fontSize: 20,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFB800),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    hint,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD8E0EE),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: dialogContext.l10n.understoodLabel,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.55, 1.0],
                      colors: [
                        Color(0xFFFFCF3F),
                        Color(0xFFFFB800),
                        Color(0xFFF59E00),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFB97A00),
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    dialogContext.l10n.understoodButton,
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
    unawaited(future.then((_) => onHowToPlayVisibilityChanged?.call(false)));
  }

  @override
  Widget build(BuildContext context) {
    final pauseCallback = onPausePressed;
    return Scaffold(
      backgroundColor: LululuColors.carbonVoid,
      body: LayoutBuilder(
        builder: (context, viewport) {
          final maxW = viewport.maxWidth.isFinite ? viewport.maxWidth : 374.0;
          final maxH = viewport.maxHeight.isFinite ? viewport.maxHeight : 680.0;
          final isCompactW = maxW < 372;
          final isCompactH = maxH < 630;
          final statBoxHeight = isCompactH ? 40.0 : 50.5;
          final backBtnW = isCompactW
              ? 40.0
              : (topBackButtonWidth ??
                    (prototypeBaglaChrome
                        ? 44.6
                        : (prototypeStackChrome || prototypeModeChrome
                              ? 47.9
                              : 48.0)));

          Widget wrapStat(Widget stat, {double? minWidth, double? maxWidth}) {
            if (isCompactW) return Expanded(child: stat);
            if (minWidth != null || maxWidth != null) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: minWidth ?? 0,
                  maxWidth: maxWidth ?? double.infinity,
                ),
                child: stat,
              );
            }
            return stat;
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              if (backgroundAsset != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.96,
                    child: Image.asset(
                      backgroundAsset!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, _) {
                        // Sessiz boşluk yerine yer tutucu + hata kaydı.
                        debugPrint(
                          'ArcadeScreen: arka plan yüklenemedi: '
                          '$backgroundAsset ($error)',
                        );
                        return Container(
                          color: LululuColors.carbonVoid,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.bug_report_rounded,
                            size: 72,
                            color: Color(0x33FFFFFF),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (backgroundAsset != null)
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.24, 0.76, 1],
                        colors: [
                          Color(0x4D080B12),
                          Color(0x00080B12),
                          Color(0x00080B12),
                          Color(0x52080B12),
                        ],
                      ),
                    ),
                  ),
                ),
              if (backgroundAsset == null)
                const CustomPaint(
                  painter: ArcadeDotPainter(paintBase: true),
                ),
              SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  children: [
                    if (showStatusBar)
                      _statusBar(context, isCompactH: isCompactH),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isCompactW ? 8 : 12,
                        isCompactH ? 0 : 6,
                        isCompactW ? 8 : 12,
                        0,
                      ),
                      child: Row(
                        children: [
                          _ChromeRound(
                            width: backBtnW,
                            // Dokunma yüksekliği her zaman 48; dar ekranda
                            // iç simge küçülür, düğme küçülmez.
                            height: 48,
                            semanticLabel: context.l10n.goBackLabel,
                            onTap: () => Navigator.maybePop(context),
                            child: Image.asset(
                              'assets/icons2/back-prototype.png',
                              width: (isCompactW || isCompactH) ? 24 : 29,
                              height: (isCompactW || isCompactH) ? 24 : 29,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.arrow_back_rounded,
                                size: 20,
                                color: Color(0xFF4A9DDB),
                              ),
                            ),
                          ),
                          SizedBox(width: isCompactW ? 6 : 10),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              // F-06/F-10/F-07(a)/F-08: başlık artık
                              // ellipsis ile kesilmiyor — FittedBox
                              // (scaleDown) tam mod adını ayrılan
                              // genişliğe sığdırır; 175 px'lik üst sınır
                              // kaldırıldı (Expanded zaten kalan alanı
                              // verir, etiket Wrap ile alt satıra iner).
                              child: Wrap(
                                  spacing: 6,
                                  runSpacing: 3,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      // 7A: yatay iç boşluk 10→6 — başlık
                                      // metnine +8px kazandırır (390'da
                                      // BAĞLA PATLAT ~10px'ten ~12.5px'e).
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: isCompactH ? 0 : 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0x8C080B12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          title.toUpperCase(),
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.clip,
                                          style: GoogleFonts.baloo2(
                                            fontSize: isCompactW ? 16 : 20,
                                            height: 1.05,
                                            letterSpacing: 0.2,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (tag != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tagColor,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          tag!,
                                          maxLines: 1,
                                          style: GoogleFonts.baloo2(
                                            fontSize: 10.5,
                                            height: 1.55,
                                            letterSpacing: 0.63,
                                            fontWeight: FontWeight.w800,
                                            color: tagTextColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ),
                          ),
                          SizedBox(width: isCompactW ? 6 : 10),
                          Flexible(
                            flex: 0,
                            child: Container(
                              height: 35,
                              // 7A: coin hapı daraltıldı (simge 25→20,
                              // sağ iç boşluk 12→8 / 8→6) — başlık satırına
                              // +10px kazandırır, dokunma hedefi aynı (35).
                              padding: EdgeInsets.fromLTRB(
                                isCompactW ? 5 : 6,
                                5,
                                isCompactW ? 6 : 8,
                                5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xD1080B12),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x59000000),
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/icons2/coin.png',
                                      width: 20,
                                      height: 20,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.monetization_on_rounded,
                                        size: 18,
                                        color: Color(0xFFFFB800),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _fmt(
                                        ProgressManager().coins,
                                      ),
                                      style: GoogleFonts.nunito(
                                        fontSize: 13.5,
                                        height: 1.2,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isCompactW ? 6 : 10),
                          _ChromeRound(
                            circular: true,
                            width: 48,
                            // Dokunma kutusu her zaman 48x48; dar ekranda
                            // iç '?' küçülür, düğme küçülmez.
                            height: 48,
                            semanticLabel: context.l10n.helpButtonLabel,
                            onTap: () => _showHowToPlaySheet(context),
                            child: Text(
                              '?',
                              style: GoogleFonts.baloo2(
                                fontSize: (isCompactW || isCompactH) ? 19 : 22,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFFB800),
                              ),
                            ),
                          ),
                          if (pauseCallback != null) ...[
                            SizedBox(width: isCompactW ? 6 : 10),
                            _ChromeRound(
                              circular: true,
                              width: 48,
                              height: 48,
                              semanticLabel: context.l10n.pause,
                              onTap: pauseCallback,
                              child: Icon(
                                Icons.pause_rounded,
                                size: (isCompactW || isCompactH) ? 19 : 22,
                                color: const Color(0xFFFFB800),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isCompactW ? 8 : 12,
                        isCompactH ? 2 : 8,
                        isCompactW ? 8 : 12,
                        0,
                      ),
                      child: Row(
                        children: [
                          wrapStat(
                            ArcadeStat(
                              label: context.l10n.gameScoreLabel,
                              value: _fmt(score),
                              height: statBoxHeight,
                              valueFontSize: 21,
                              horizontalPadding: isCompactW ? 8 : 14,
                            ),
                            minWidth: 104,
                            maxWidth: 104,
                          ),
                          SizedBox(width: isCompactW ? 4 : 8),
                          wrapStat(
                            ArcadeStat(
                              label: context.l10n.gameBestLabel,
                              value: _fmt(best),
                              height: statBoxHeight,
                              valueFontSize: 21,
                              horizontalPadding: isCompactW ? 8 : 14,
                            ),
                            minWidth: 84,
                            maxWidth: 86,
                          ),
                          if (!isCompactW) const Spacer(),
                          if (statLabel != null && statValue != null) ...[
                            SizedBox(width: isCompactW ? 4 : 8),
                            wrapStat(
                              ArcadeStat(
                                label: statLabel!,
                                value: statValue!,
                                valueWidget: statValueWidget,
                                height: statBoxHeight,
                                valueFontSize: 21,
                                horizontalPadding: isCompactW ? 8 : 14,
                              ),
                              minWidth: 74,
                              maxWidth: 74,
                            ),
                          ],
                          SizedBox(width: isCompactW ? 4 : 8),
                          Semantics(
                            button: true,
                            label: context.l10n.finishRoundLabel,
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: onRestart,
                              child: Container(
                                width: isCompactW ? 48 : 57.8,
                                // Dokunma yüksekliği her zaman 48; iç yazı
                                // FittedBox ile zaten küçülerek sığar.
                                height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB800),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFFB97A00),
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    context.l10n.finishCaps,
                                    style: GoogleFonts.baloo2(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF4A2E00),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ),
                        ],
                      ),
                    ),
                    if (hintLabel != null)
                      Container(
                        height: isCompactH ? 26 : 30,
                        margin: EdgeInsets.only(top: isCompactH ? 2 : 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: const BoxDecoration(
                          color: Color(0x38E52E2E),
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xD9E52E2E),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              hintLabel!,
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                letterSpacing: 0.88,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFFFB3B3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hint,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  letterSpacing: 0.88,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFFFB3B3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ?evoStrip,
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Column(
                            children: [
                              Expanded(
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(
                                    wideStage
                                        ? 0
                                        : isCompactW
                                        ? 8
                                        : 14,
                                    hintLabel != null
                                        ? 0
                                        : (isCompactH ? 4 : 10),
                                    wideStage
                                        ? 0
                                        : isCompactW
                                        ? 8
                                        : 14,
                                    0,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      wideStage ? 0 : 20,
                                    ),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x660E1422),
                                        Color(0x800E1422),
                                      ],
                                    ),
                                    border: wideStage
                                        ? null
                                        : Border.all(
                                            color: const Color(0x24FFFFFF),
                                            width: 2,
                                          ),
                                  ),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 2,
                                      sigmaY: 2,
                                    ),
                                    child: child,
                                  ),
                                ),
                              ),
                              if (footer != null)
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.fromLTRB(
                                    0,
                                    isCompactH ? 4 : 8,
                                    0,
                                    isCompactH ? 4 : 10,
                                  ),
                                  child: footer,
                                ),
                            ],
                          ),
                          ?overlay,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusBar(BuildContext context, {bool isCompactH = false}) {
    final topPad = MediaQuery.paddingOf(context).top;
    if (topPad > 0) {
      return SizedBox(height: topPad);
    }
    return SizedBox(
      height: isCompactH ? 26 : 35.4,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          isCompactH ? 6 : 14,
          22,
          4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '09:41',
              style: GoogleFonts.nunito(
                fontSize: 12.5,
                height: 1,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Row(
              children: const [
                Icon(
                  Icons.signal_cellular_alt_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                SizedBox(width: 5),
                Icon(
                  Icons.battery_full_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
}

/// Prototip `evo-strip` / `mode-info` bilgi ve evrim şeridi bileşeni.
class ArcadeEvoStrip extends StatelessWidget {
  const ArcadeEvoStrip({
    super.key,
    required this.text,
    this.iconAsset,
    this.highlightText,
  });

  final String text;
  final String? iconAsset;
  final String? highlightText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE0080B12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Row(
        children: [
          if (iconAsset != null) ...[
            Image.asset(
              iconAsset!,
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.auto_awesome_rounded,
                size: 22,
                color: Color(0xFFFFB800),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFC9D4E6),
                ),
                children: [
                  if (highlightText != null)
                    TextSpan(
                      text: '$highlightText ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChromeRound extends StatelessWidget {
  const _ChromeRound({
    required this.child,
    required this.onTap,
    this.circular = false,
    this.width,
    this.height = 48,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool circular;
  final double? width;
  final double height;

  /// Ekran okuyucu etiketi ve uzun basma ipucu (örn. 'Geri').
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? 48,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xDC080B12),
          borderRadius: BorderRadius.circular(circular ? 99 : 14),
          border: circular
              ? Border.all(color: const Color(0xB3FFB800), width: 2)
              : Border.all(color: const Color(0x3DFFFFFF), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
    final label = semanticLabel;
    if (label != null) {
      button = Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: button,
        ),
      );
    }
    return button;
  }
}

class ArcadeStat extends StatelessWidget {
  const ArcadeStat({
    super.key,
    required this.label,
    required this.value,
    this.valueWidget,
    this.height = 50.5,
    this.valueFontSize = 21,
    this.horizontalPadding = 14,
    this.backgroundColor,
    this.borderColor,
  });

  final String label;
  final String value;
  final Widget? valueWidget;
  final double height;
  final double valueFontSize;
  final double horizontalPadding;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xD9080B12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? const Color(0x73FFB800),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 10,
                height: 1.55,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFFB800),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child:
                  valueWidget ??
                  Text(
                    value,
                    maxLines: 1,
                    style: GoogleFonts.baloo2(
                      fontSize: valueFontSize,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArcadeButton extends StatefulWidget {
  const ArcadeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  State<ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<ArcadeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? LululuMotion.pressScale : 1,
        duration: LululuMotion.pressDuration,
        curve: LululuMotion.elastic,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: LululuMotion.minTap),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: widget.primary
                  ? LululuGradients.fuchsiaToGold
                  : const LinearGradient(
                      colors: [
                        LululuColors.darkObsidian,
                        LululuColors.spaceNavy,
                      ],
                    ),
              border: Border.all(
                color: widget.primary
                    ? LululuColors.liquidGold.withValues(alpha: 0.7)
                    : LululuColors.cyberFuchsia.withValues(alpha: 0.45),
              ),
              boxShadow: widget.primary
                  ? [
                      BoxShadow(
                        color: LululuColors.liquidGold.withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: widget.primary
                          ? LululuColors.carbonVoid
                          : LululuColors.liquidGold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Prototip `result-screen` / `res-score-card` ahşap ödül ekranı ile birebir uyumlu
/// ve tüm telefon/tablet boyutlarında taşmayan (zero-overflow) sonuç katmanı.
class ArcadeResultOverlay extends StatefulWidget {
  const ArcadeResultOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.score,
    required this.won,
    required this.retryLabel,
    required this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
    this.modeTitle,
    this.best,
    this.shareLine,
    this.showShare = true,
    this.statLabel,
    this.statValue,
    this.badgeLabel,
    this.mascotAsset,
    this.coins,
    this.stars,
  });

  final String title;
  final String message;
  final int score;
  final bool won;
  final String retryLabel;
  final VoidCallback onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Paylaşım kartı başlığı (mod adı). Boşsa [title] kullanılır.
  final String? modeTitle;
  final int? best;
  final String? shareLine;
  final bool showShare;
  final String? statLabel;
  final String? statValue;
  final String? badgeLabel;
  final String? mascotAsset;
  final int? coins;
  final int? stars;

  static DateTime? _lastShareAt;

  @override
  State<ArcadeResultOverlay> createState() => _ArcadeResultOverlayState();
}

class _ArcadeResultOverlayState extends State<ArcadeResultOverlay> {
  late int _displayCoins;
  bool _doubled = false;
  bool _shared = false;

  @override
  void initState() {
    super.initState();
    _displayCoins = widget.coins ?? (180 + (widget.score.abs() % 220));
  }

  static String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );

  int get _stars {
    if (widget.stars != null) return widget.stars!.clamp(1, 3);
    final b = max(1, widget.best ?? widget.score);
    if (widget.score >= b * 0.85) return 3;
    if (widget.score >= b * 0.4) return 2;
    return 1;
  }

  String get _resolvedMascot {
    if (widget.mascotAsset != null) return widget.mascotAsset!;
    final m = (widget.modeTitle ?? widget.title).toLowerCase();
    if (m.contains('balon') || m.contains('makara')) {
      return 'assets/bugs/tier3_hd.png';
    }
    if (m.contains('match')) return 'assets/bugs/tier4_hd.png';
    if (m.contains('bağla') || m.contains('bagla')) {
      return 'assets/bugs/tier5_hd.webp';
    }
    if (m.contains('stack') || m.contains('yuva')) {
      return 'assets/bugs/tier2_hd.png';
    }
    if (m.contains('terlik')) return 'assets/bugs/tier1_hd.png';
    if (m.contains('osman') || m.contains('çığlık') || m.contains('ciglik')) {
      return 'assets/bugs/tier7_hd.png';
    }
    return 'assets/design/ui/res_mascot.png';
  }

  String get _resolvedBadge {
    if (widget.badgeLabel != null) return widget.badgeLabel!;
    final m = (widget.modeTitle ?? widget.title).toLowerCase();
    if (m.contains('2048')) return '2048';
    if (m.contains('balon')) return context.l10n.badgeBonus;
    if (m.contains('match')) return context.l10n.badgeNeon;
    if (m.contains('bağla') || m.contains('bagla')) {
      return context.l10n.connectChainBadge;
    }
    if (m.contains('stack')) return context.l10n.stackTowerBadge;
    if (m.contains('terlik') || m.contains('yuva')) {
      return context.l10n.newBadge;
    }
    return context.l10n.viralBadge;
  }

  /// Ödüllü reklam SDK'sı kurulu değil: reklam gösterilemez, devam hakkı
  /// ve 2× altın verilmez. Gerçek SDK eklendiğinde bu düğmeler gerçek
  /// reklam akışına bağlanmalıdır; sahte (mock) reklamla ödül verilmez
  /// (madde 4). Düğmeye dokunmak yalnızca bilgi gösterir.
  void _showRewardsComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.rewardedAdsComingSoon,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
        ),
        backgroundColor: LululuColors.carbonVoid,
      ),
    );
  }

  Future<void> _handleContinueAd() async {
    _showRewardsComingSoon();
  }

  Future<void> _handleDoubleCoinsAd() async {
    _showRewardsComingSoon();
  }

  Future<void> _handleShare() async {
    final now = DateTime.now();
    final last = ArcadeResultOverlay._lastShareAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 900)) {
      return;
    }
    ArcadeResultOverlay._lastShareAt = now;
    final shared = await ScoreShareCard.instance.share(
      l10n: context.l10n,
      modeTitle: widget.modeTitle ?? widget.title,
      score: widget.score,
      best: widget.best,
      line: widget.shareLine ?? widget.message,
    );
    if (!mounted) return;
    if (shared) {
      setState(() => _shared = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.shareScoreFailed,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
          ),
          backgroundColor: LululuColors.carbonVoid,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bestVal = max(widget.score, widget.best ?? widget.score);
    final starsEarned = _stars;
    final subtitleText = widget.modeTitle != null
        ? '${widget.modeTitle} · ${widget.message}'
        : widget.message;

    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xFFE9B872),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/design/backgrounds/result_wood_bg.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFE9B872),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final isShort = constraints.maxHeight < 620;
                final isNarrow = constraints.maxWidth < 350;
                final hPad = isNarrow ? 12.0 : 18.0;
                final vTop = isShort ? 12.0 : 22.0;

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                      minWidth: constraints.maxWidth,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, vTop, hPad, 12),
                        child: Column(
                          children: [
                            // 3 Stars Row (`res-stars`)
                            SizedBox(
                              height: isShort ? 44 : 56,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildStar(
                                    earned: starsEarned >= 1,
                                    size: isShort ? 36 : 46,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStar(
                                    earned: starsEarned >= 2,
                                    size: isShort ? 42 : 54,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStar(
                                    earned: starsEarned >= 3,
                                    size: isShort ? 36 : 46,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isShort ? 4 : 6),

                            // Wooden Banner Title (`res-title`)
                            Container(
                              padding: EdgeInsets.fromLTRB(
                                isNarrow ? 16 : 24,
                                isShort ? 5 : 7,
                                isNarrow ? 16 : 24,
                                isShort ? 6 : 9,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFB07534),
                                    Color(0xFF8A5220),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                border: Border.all(
                                  color: const Color(0xFF6E3F14),
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFF5C340E),
                                    offset: Offset(0, 5),
                                  ),
                                  BoxShadow(
                                    color: Color(0x595A3400),
                                    blurRadius: 20,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.title.toUpperCase(),
                                  style: GoogleFonts.bangers(
                                    fontSize: isShort ? 25 : 30,
                                    letterSpacing: 1.0,
                                    height: 1.05,
                                    color: const Color(0xFFFFE9A8),
                                    shadows: const [
                                      Shadow(
                                        color: Color(0x8C3C2000),
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isShort ? 4 : 7),

                            // Subtitle (`res-sub`)
                            Text(
                              subtitleText,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: isShort ? 12 : 13.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF5C340E),
                                shadows: const [
                                  Shadow(
                                    color: Color(0xBFFFEDA8),
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isShort ? 6 : 8),

                            // Score Card (`res-score-card`)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                14,
                                isShort ? 6 : 8,
                                14,
                                isShort ? 6 : 9,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFF9E9),
                                    Color(0xFFFFEFC4),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                border: Border.all(
                                  color: const Color(0xFFB97A2E),
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x8C8C5414),
                                    offset: Offset(0, 5),
                                  ),
                                  BoxShadow(
                                    color: Color(0x405A3400),
                                    blurRadius: 20,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          context.l10n.gameScoreLabel,
                                          style: GoogleFonts.nunito(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.54,
                                            color: const Color(0xFFA96A2C),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${widget.score}',
                                          style: GoogleFonts.baloo2(
                                            fontSize: isShort ? 28 : 34,
                                            fontWeight: FontWeight.w800,
                                            height: 1,
                                            color: const Color(0xFF7A4A00),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: isShort ? 4 : 7),
                                  Container(
                                    height: 1.5,
                                    color: const Color(0x73A96A2C),
                                  ),
                                  SizedBox(height: isShort ? 4 : 7),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildSubMetric(
                                          label: context.l10n.gameBestLabel,
                                          value: _fmt(bestVal),
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildSubMetric(
                                          label:
                                              widget.statLabel ??
                                              context.l10n.statusLabel,
                                          value:
                                              widget.statValue ??
                                              (widget.won
                                                  ? context.l10n.resultComplete
                                                  : context.l10n.resultOver),
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildSubMetric(
                                          label:
                                              context.l10n.modeBadgeTitle,
                                          value: _resolvedBadge,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isShort ? 2 : 4),

                            // Mascot & Chest Row (`res-chest-row`)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Image.asset(
                                    _resolvedMascot,
                                    width: isShort ? 74 : 100,
                                    height: isShort ? 90 : 124,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => Image.asset(
                                      'assets/design/ui/res_mascot.png',
                                      width: isShort ? 74 : 100,
                                      height: isShort ? 90 : 124,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, error, _) {
                                        // Sessiz boşluk yerine yer tutucu + hata kaydı.
                                        debugPrint(
                                          'ArcadeResultOverlay: maskot yüklenemedi: '
                                          '$_resolvedMascot ($error)',
                                        );
                                        return SizedBox(
                                          width: isShort ? 74 : 100,
                                          height: isShort ? 90 : 124,
                                          child: const Icon(
                                            Icons.bug_report_rounded,
                                            size: 56,
                                            color: Color(0xFF8A5220),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: isShort ? 116 : 138,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.topCenter,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 14),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Image.asset(
                                              'assets/design/ui/res_chest.png',
                                              width: isShort ? 76 : 100,
                                              height: isShort ? 76 : 100,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.inventory_2_rounded,
                                                    size: 64,
                                                    color: Color(0xFF8A5220),
                                                  ),
                                            ),
                                            const SizedBox(height: 3),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                context.l10n.goldEarnedLabel,
                                                style: GoogleFonts.nunito(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.1,
                                                  color: const Color(
                                                    0xFF6E3F14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        child: Container(
                                          padding: const EdgeInsets.fromLTRB(
                                            6,
                                            4,
                                            13,
                                            4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xED2E1A00),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFFFB800),
                                              width: 2,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x665A3400),
                                                blurRadius: 10,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Image.asset(
                                                'assets/design/ui/res_coin.png',
                                                width: 22,
                                                height: 22,
                                                errorBuilder: (_, _, _) =>
                                                    const Icon(
                                                      Icons
                                                          .monetization_on_rounded,
                                                      size: 20,
                                                      color: Color(0xFFFFB800),
                                                    ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '+$_displayCoins',
                                                style: GoogleFonts.baloo2(
                                                  fontSize: 16.5,
                                                  height: 1,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(
                                                    0xFFFFD34D,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),
                            SizedBox(height: isShort ? 6 : 10),

                            // Action Buttons (`result-btns`)
                            _buildAdButton(
                              label: context.l10n.continueWithAdSoon,
                              onTap: _handleContinueAd,
                              minHeight: isShort ? 44 : 52,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.l10n.rewardedAdsComingSoon,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF6E3F14),
                              ),
                            ),
                            SizedBox(height: isShort ? 5 : 8),
                            _buildAdButton(
                              label: _doubled
                                  ? context.l10n.doubleGoldEarnedCaps
                                  : context.l10n.doubleGoldAdSoon,
                              onTap: _handleDoubleCoinsAd,
                              minHeight: isShort ? 44 : 52,
                              disabled: _doubled,
                            ),
                            SizedBox(height: isShort ? 6 : 8),

                            // `res-btn-row`: TEKRAR OYNA + PAYLAŞ
                            Row(
                              children: [
                                Expanded(
                                  child: LululuPress(
                                    onTap: widget.onRetry,
                                    child: Container(
                                      constraints: BoxConstraints(
                                        minHeight: isShort ? 44 : 52,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF37E08B),
                                            Color(0xFF12B76A),
                                            Color(0xFF0A9553),
                                          ],
                                          stops: [0.0, 0.55, 1.0],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0xFF066C3C),
                                            offset: Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.refresh_rounded,
                                              size: 19,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              widget.retryLabel.isNotEmpty
                                                  ? widget.retryLabel
                                                  : context.l10n.playAgainButton,
                                              style: GoogleFonts.baloo2(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.showShare) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: LululuPress(
                                      onTap: _handleShare,
                                      child: Container(
                                        constraints: BoxConstraints(
                                          minHeight: isShort ? 44 : 52,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFF4538B),
                                              Color(0xFFE01E5A),
                                              Color(0xFFB80F42),
                                            ],
                                            stops: [0.0, 0.55, 1.0],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0xFF7E0A2E),
                                              offset: Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.share_rounded,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                _shared
                                                    ? context.l10n.sharedButton
                                                    : context.l10n.shareButton,
                                                style: GoogleFonts.baloo2(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: isShort ? 6 : 8),

                            // Ghost button: ANA SAYFA
                            LululuPress(
                              onTap:
                                  widget.onSecondary ??
                                  () => Navigator.maybePop(context),
                              child: Container(
                                width: double.infinity,
                                constraints: BoxConstraints(
                                  minHeight: isShort ? 42 : 48,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xE64A2E00),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0xF22E1A00),
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  widget.secondaryLabel ??
                                  context.l10n.navHome,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFFE9A8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStar({required bool earned, required double size}) {
    final img = Image.asset(
      'assets/design/ui/res_star.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(
        Icons.star_rounded,
        size: size,
        color: const Color(0xFFFFD700),
      ),
    );
    if (earned) return SizedBox(width: size, height: size, child: img);
    return SizedBox(
      width: size,
      height: size,
      child: Opacity(
        opacity: 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      1, 0,
          ]),
          child: img,
        ),
      ),
    );
  }

  Widget _buildSubMetric({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.nunito(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.65,
                color: const Color(0xFFA96A2C),
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.baloo2(
                fontSize: 16,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF4A2E00),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdButton({
    required String label,
    required VoidCallback onTap,
    required double minHeight,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: LululuPress(
        enabled: !disabled,
        onTap: disabled ? () {} : onTap,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x8C080B12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFB800), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x73000000), offset: Offset(0, 4)),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.l10n.comingSoon,
                    style: GoogleFonts.nunito(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 19,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.baloo2(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ArcadeDotPainter extends CustomPainter {
  const ArcadeDotPainter({this.paintBase = true});

  final bool paintBase;

  @override
  void paint(Canvas canvas, Size size) {
    if (paintBase) {
      final base = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [LululuColors.carbonVoid, LululuColors.spaceNavy],
        ).createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, base);
    }

    const step = 14.0;
    final dot = Paint()..color = LululuColors.dotMesh(opacity: 0.08);
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.05, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
