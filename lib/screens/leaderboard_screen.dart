import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../navigation/game_routes.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../widgets/home/lululu_dock_bar.dart';

class LeaderboardScreen extends StatefulWidget {
  final bool embedded;
  final bool showBackButton;
  final VoidCallback? onClose;
  final ValueChanged<LululuDockTab>? onSelectDockTab;

  const LeaderboardScreen({
    super.key,
    this.embedded = false,
    // Bağımsız açılışta geri düğmesi varsayılan olarak açıktır. Gömülü
    // (ana sekme içi) kullanımda geri düğmesi gizlenir; bkz. _handleBack.
    // Çağrıcılar: game_routes `const LeaderboardScreen()` (bağımsız),
    // home_shell `LeaderboardScreen(embedded: true)` (gömülü) — ikisi de bozulmaz.
    this.showBackButton = true,
    this.onClose,
    this.onSelectDockTab,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await LeaderboardService.instance.ensureLoaded();
    } catch (_) {
      // Yerel kayıt okunamazsa bile iskelet ekranda takılı kalmasın.
    }
    if (mounted) setState(() => _loading = false);
  }

  static String _formatScore(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _handleBack() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    // Yığında ekran yoksa (bağımsız/ilk açılış): ana sekmeye git.
    goTo(context, LululuRoutes.hub, replace: true);
  }

  void _handleDockSelect(BuildContext context, LululuDockTab tab) {
    if (widget.onSelectDockTab != null) {
      widget.onSelectDockTab!(tab);
      return;
    }
    if (tab == LululuDockTab.scores) return;
    final route = switch (tab) {
      LululuDockTab.home => LululuRoutes.hub,
      LululuDockTab.modes => LululuRoutes.modes,
      LululuDockTab.family => LululuRoutes.tiers,
      LululuDockTab.shop => LululuRoutes.shop,
      LululuDockTab.scores => LululuRoutes.scores,
    };
    goTo(context, route, replace: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ProgressManager.instance,
        LeaderboardService.instance,
      ]),
      builder: (context, _) {
        final int myScoreVal = 7915 + ProgressManager.instance.total11ModesScore;
        final myScoreText = _formatScore(myScoreVal);

        // Gerçek kayıtlar (yalnızca gerçek oyuncular): boşsa boş durum bandı
        // gösterilir. Yükleme bitmeden bu dala düşülmez — _loading iskelet çizer.
        final isBoardEmpty =
            LeaderboardService.instance.getOverallTop().isEmpty;

        final scoreItems = <_ScoreRowData>[
          const _ScoreRowData(
            rank: 4,
            name: 'TerlikUstası',
            level: 'Seviye 24',
            score: '8.540',
            avatar: 'assets/design/bugs_hd/tier4_hd.png',
            imgTop: 2.4,
            imgHeight: 35.2,
          ),
          _ScoreRowData(
            rank: 5,
            name: 'SEN · LülüSever',
            level: 'Seviye 18',
            score: myScoreText,
            avatar: 'assets/design/bugs_hd/tier5_hd.png',
            imgTop: 4.3,
            imgHeight: 62.3,
            isMe: true,
          ),
          const _ScoreRowData(
            rank: 6,
            name: 'MakaraMehmet',
            level: 'Seviye 21',
            score: '7.402',
            avatar: 'assets/design/bugs_hd/tier3_hd.png',
            imgTop: 2.4,
            imgHeight: 35.2,
          ),
          const _ScoreRowData(
            rank: 7,
            name: 'HuniKafa',
            level: 'Seviye 15',
            score: '6.988',
            avatar: 'assets/design/bugs_hd/tier1_hd.png',
            imgTop: 5.6,
            imgHeight: 82.6,
          ),
          const _ScoreRowData(
            rank: 8,
            name: 'BilgeDede',
            level: 'Seviye 27',
            score: '6.511',
            avatar: 'assets/design/bugs_hd/tier8_hd.png',
            imgTop: 3.2,
            imgHeight: 46.0,
          ),
        ];

        final mqTop = MediaQuery.of(context).padding.top;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          body: Stack(
            fit: StackFit.expand,
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    if (mqTop == 0) const _ScoresPrototypeStatusBar(),
                    // .page-title (y=35.4, h=47, padding: 10px 14px 2px 14px)
                    Container(
                      height: 47,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (!widget.embedded &&
                              (widget.showBackButton ||
                                  widget.onClose != null)) ...[
                            GestureDetector(
                              onTap: _handleBack,
                              child: Container(
                                width: 35,
                                height: 35,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x1A141B2A),
                                      offset: Offset(0, 3),
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Image.asset(
                                  'assets/icons2/back.png',
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Transform.translate(
                                offset: const Offset(0, -1),
                                child: Text(
                                  context.l10n.leaderboardTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textHeightBehavior: TextHeightBehavior(
                                    applyHeightToFirstAscent: false,
                                    applyHeightToLastDescent: false,
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'Baloo 2',
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF141B2A),
                                    height: 1.12,
                                    letterSpacing: -0.05,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            height: 35,
                            padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF33363C),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x59000000),
                                  offset: Offset(0, 3),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/icons2/clock.png',
                                  width: 25,
                                  height: 25,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 6),
                                Transform.translate(
                                  offset: const Offset(-1, 0),
                                  child: Transform.scale(
                                    scaleX: 1.02,
                                    scaleY: 1.0,
                                    child: Text(
                                      context.l10n.weeklyLabel,
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.55,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // .scroll
                    Expanded(
                      child: _loading
                          ? _buildLoadingSkeleton()
                          : ListView(
                        padding: const EdgeInsets.only(bottom: 120),
                        children: [
                          if (isBoardEmpty) _buildEmptyStateBanner(),
                          // .podium (y=82, h=190, padding: 14px 16px 4px 16px)
                          Container(
                            height: 190,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildPodiumCol(
                                  rank: 2,
                                  name: 'HamamCan_34',
                                  score: '9.310',
                                  avatar: 'assets/design/bugs_hd/tier6_hd.png',
                                  faceSize: 64,
                                  imgLeft: 3.5,
                                  imgTop: 6.3,
                                  imgWidth: 51.0,
                                  imgHeight: 93.2,
                                  borderColor: const Color(0xFF8E9CAE),
                                  baseHeight: 32,
                                  baseFontSize: 17,
                                  baseDecoration: const BoxDecoration(
                                    color: Color(0xFFA9B6C8),
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _buildPodiumCol(
                                  rank: 1,
                                  name: 'KongoKralı',
                                  score: '11.204',
                                  avatar: 'assets/design/bugs_hd/tier7_hd.png',
                                  faceSize: 78,
                                  imgLeft: 4.3,
                                  imgTop: 7.1,
                                  imgWidth: 63.4,
                                  imgHeight: 90.4,
                                  borderColor: const Color(0xFFFFB800),
                                  baseHeight: 44,
                                  baseFontSize: 20,
                                  baseDecoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFFB800),
                                        Color(0xFFE09E00),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _buildPodiumCol(
                                  rank: 3,
                                  name: 'DivaNur',
                                  score: '8.977',
                                  avatar: 'assets/design/bugs_hd/tier5_hd.png',
                                  faceSize: 64,
                                  imgLeft: 3.5,
                                  imgTop: 7.1,
                                  imgWidth: 51.0,
                                  imgHeight: 90.3,
                                  borderColor: const Color(0xFF8E9CAE),
                                  baseHeight: 26,
                                  baseFontSize: 15,
                                  baseDecoration: const BoxDecoration(
                                    color: Color(0xFFD08A4E),
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          for (final item in scoreItems) _buildScoreRow(item),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (!widget.embedded)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  height: 84,
                  child: _ScoresFloatingDock(
                    activeTab: LululuDockTab.scores,
                    onSelectTab: (tab) => _handleDockSelect(context, tab),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _skeletonBox({
    required double width,
    required double height,
    bool circle = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE3E7EF),
        borderRadius: circle ? null : BorderRadius.circular(12),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }

  /// Yükleme iskeleti: gerçek kayıtlar okunurken podyum + satır yer tutucuları.
  Widget _buildLoadingSkeleton() {
    return Semantics(
      label: context.l10n.leaderboardLoadingLabel,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          const LinearProgressIndicator(
            minHeight: 4,
            backgroundColor: Color(0xFFE3E7EF),
            color: Color(0xFFFFB800),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _skeletonBox(width: 64, height: 110),
                const SizedBox(width: 10),
                _skeletonBox(width: 78, height: 140),
                const SizedBox(width: 10),
                _skeletonBox(width: 64, height: 100),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Container(
                height: 61,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _skeletonBox(width: 40, height: 40, circle: true),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _skeletonBox(width: 140, height: 14),
                          const SizedBox(height: 6),
                          _skeletonBox(width: 90, height: 11),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Boş durum bandı: gerçek kayıtlarda hiç skor yokken gösterilir.
  Widget _buildEmptyStateBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB800), width: 1.5),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/icons2/trophy.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.noScoresYet,
                    style: TextStyle(
                      fontFamily: 'Baloo 2',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF141B2A),
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    context.l10n.noScoresHint,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF66738A),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumCol({
    required int rank,
    required String name,
    required String score,
    required String avatar,
    required double faceSize,
    required double imgLeft,
    required double imgTop,
    required double imgWidth,
    required double imgHeight,
    required Color borderColor,
    required double baseHeight,
    required double baseFontSize,
    required BoxDecoration baseDecoration,
  }) {
    final innerSize = faceSize - 6;
    return SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: faceSize,
            height: faceSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 3),
            ),
            child: ClipOval(
              child: SizedBox(
                width: innerSize,
                height: innerSize,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: imgLeft,
                      top: imgTop,
                      width: imgWidth,
                      height: imgHeight,
                      child: Image.asset(
                        avatar,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 19.4,
            child: OverflowBox(
              maxWidth: 104,
              child: Center(
                child: Transform.scale(
                  scaleX: 0.98,
                  scaleY: 1.0,
                  child: Text(
                    name,
                    maxLines: 1,
                    softWrap: false,
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF141B2A),
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 18.6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons2/trophy.png',
                  width: 17,
                  height: 17,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 4),
                Text(
                  score,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8A6D00),
                    height: 1.55,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 88,
            height: baseHeight,
            decoration: baseDecoration,
            alignment: Alignment.center,
            child: Text(
              '$rank',
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              style: TextStyle(
                fontFamily: 'Baloo 2',
                fontSize: baseFontSize,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(_ScoreRowData item) {
    final double cardHeight = (item.rank == 4 || item.rank == 7) ? 62.0 : 61.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: CustomPaint(
        foregroundPainter: item.isMe ? const _MeRowOutlinePainter() : null,
        child: Container(
          height: cardHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: item.isMe ? const Color(0xFFFFF2F7) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F141B2A),
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24.8,
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -1),
                    child: Text(
                      '${item.rank}',
                      textAlign: TextAlign.center,
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                      style: const TextStyle(
                        fontFamily: 'Baloo 2',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF66738A),
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F6FA),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: 2.4,
                          top: item.imgTop,
                          width: 35.2,
                          height: item.imgHeight,
                          child: Image.asset(
                            item.avatar,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: SizedBox(
                  height: 43.4,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 1.0,
                        height: 19.0,
                        child: Transform.scale(
                          alignment: Alignment.centerLeft,
                          scaleX: 0.97,
                          scaleY: 1.0,
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF141B2A),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 24.5,
                        height: 16.0,
                        child: Transform.scale(
                          alignment: Alignment.centerLeft,
                          scaleX: 0.975,
                          scaleY: 1.0,
                          child: Text(
                            item.level,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF66738A),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 24,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons2/trophy.png',
                      width: 19,
                      height: 19,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 5),
                    Transform.translate(
                      offset: const Offset(0, -1),
                      child: Transform.scale(
                        alignment: Alignment.centerRight,
                        scaleX: 0.985,
                        scaleY: 1.0,
                        child: Text(
                          item.score,
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                          style: const TextStyle(
                            fontFamily: 'Baloo 2',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF141B2A),
                            height: 1.55,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeRowOutlinePainter extends CustomPainter {
  const _MeRowOutlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final innerRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    final outerRRect = innerRRect.inflate(2.0);
    final ringPath = Path.combine(
      PathOperation.difference,
      Path()..addRRect(outerRRect),
      Path()..addRRect(innerRRect),
    );
    canvas.drawPath(
      ringPath,
      Paint()
        ..color = const Color(0xFFE01E5A)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScoreRowData {
  final int rank;
  final String name;
  final String level;
  final String score;
  final String avatar;
  final double imgTop;
  final double imgHeight;
  final bool isMe;

  const _ScoreRowData({
    required this.rank,
    required this.name,
    required this.level,
    required this.score,
    required this.avatar,
    required this.imgTop,
    required this.imgHeight,
    this.isMe = false,
  });
}

class _ScoresFloatingDock extends StatelessWidget {
  final LululuDockTab activeTab;
  final ValueChanged<LululuDockTab> onSelectTab;

  const _ScoresFloatingDock({
    required this.activeTab,
    required this.onSelectTab,
  });

  static const _tabs = LululuDockTab.values;

  static String _label(AppLocalizations l10n, LululuDockTab tab) => switch (tab) {
        LululuDockTab.home => l10n.navHome,
        LululuDockTab.modes => l10n.navModes,
        LululuDockTab.family => l10n.navFamily,
        LululuDockTab.shop => l10n.navShop,
        LululuDockTab.scores => l10n.navScores,
      };

  static String _icon(LululuDockTab tab) => switch (tab) {
        LululuDockTab.home => 'assets/icons2/home.png',
        LululuDockTab.modes => 'assets/icons2/target.png',
        LululuDockTab.family => 'assets/icons2/paw.png',
        LululuDockTab.shop => 'assets/icons2/cart.png',
        LululuDockTab.scores => 'assets/icons2/trophy.png',
      };

  static Widget _buildIconWithDropShadow(String asset, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(0, 2),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0x47000000),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    asset,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _ScoresBlurShadowPainter(
        color: Color(0x62080B12),
        offset: Offset(0, 22),
        blurRadius: 38,
        borderRadius: 999,
      ),
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 3),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.72],
            colors: [
              Color(0xFF1E2538),
              Color(0xFF080B12),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x47080B12),
              offset: Offset(0, 7),
              blurRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth =
                  (constraints.maxWidth - 14.0).clamp(100.0, 410.0);
              final tabWidth = usableWidth / _tabs.length;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: _DockSurfacePainter(),
                    ),
                  ),
                  Positioned(
                    left: 26,
                    right: 26,
                    top: 5,
                    height: 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.20),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 7.0 + activeTab.index * tabWidth,
                    top: 7.0,
                    width: tabWidth,
                    height: 64.0,
                    child: CustomPaint(
                      painter: const _ScoresBlurShadowPainter(
                        color: Color(0x47E01E5A),
                        offset: Offset(0, 10),
                        blurRadius: 18,
                        borderRadius: 999,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xF0FFFFFF),
                            width: 2,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.40, 0.74, 1.0],
                            colors: [
                              Color(0xFFFFE27A),
                              Color(0xFFFFB800),
                              Color(0xFFFF6B35),
                              Color(0xFFE01E5A),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D000000),
                              offset: Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: CustomPaint(
                                  painter: _DockActiveIndInsetPainter(),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                right: 8,
                                top: 2,
                                height: 9,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0x61FFFFFF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(7),
                    child: Row(
                      children: [
                        for (final tab in _tabs)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelectTab(tab),
                              child: SizedBox(
                                height: 64,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.topCenter,
                                  children: [
                                    if (tab == activeTab)
                                      Positioned(
                                        top: 1.8,
                                        width: 42.4,
                                        height: 42.4,
                                        child: CustomPaint(
                                          painter:
                                              const _ScoresBlurShadowPainter(
                                            color: Color(0x3D000000),
                                            offset: Offset(0, 7),
                                            blurRadius: 12,
                                            borderRadius: 999,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x597A082E),
                                                  offset: Offset(0, 4),
                                                  blurRadius: 0,
                                                ),
                                              ],
                                            ),
                                            child: ClipOval(
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  const Positioned.fill(
                                                    child: CustomPaint(
                                                      painter:
                                                          _DockCircleInsetPainter(
                                                        dy: -4.24,
                                                        color:
                                                            Color(0x1F080B12),
                                                      ),
                                                    ),
                                                  ),
                                                  _buildIconWithDropShadow(
                                                    _icon(tab),
                                                    35,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                  else
                                    Positioned(
                                      top: 7.0,
                                      width: 40.0,
                                      height: 40.0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0x17FFFFFF),
                                          border: Border.all(
                                            color: const Color(0x2EFFFFFF),
                                            width: 2,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x4D000000),
                                              offset: Offset(0, 3),
                                              blurRadius: 0,
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              const Positioned.fill(
                                                child: CustomPaint(
                                                  painter:
                                                      _DockCircleInsetPainter(
                                                    dy: 2.0,
                                                    color: Color(0x29FFFFFF),
                                                  ),
                                                ),
                                              ),
                                              _buildIconWithDropShadow(
                                                _icon(tab),
                                                33,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: 46.0,
                                    height: 16.0,
                                    child: Center(
                                      child: Text(
                                        _label(context.l10n, tab),
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                        style: TextStyle(
                                          fontFamily: 'Baloo 2',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          height: 1.0,
                                          letterSpacing: 0,
                                          color: tab == activeTab
                                              ? Colors.white
                                              : const Color(0xA8FFFFFF),
                                          shadows: tab == activeTab
                                              ? const [
                                                  Shadow(
                                                    color: Color(0x737A082E),
                                                    offset: Offset(0, 2),
                                                    blurRadius: 0,
                                                  ),
                                                ]
                                              : const [
                                                  Shadow(
                                                    color: Color(0xBF000000),
                                                    offset: Offset(0, 1),
                                                    blurRadius: 0,
                                                  ),
                                                ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScoresBlurShadowPainter extends CustomPainter {
  final Color color;
  final Offset offset;
  final double blurRadius;
  final double borderRadius;

  const _ScoresBlurShadowPainter({
    required this.color,
    required this.offset,
    required this.blurRadius,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sigma = blurRadius * 0.57735 + 0.5;
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
    final rect = offset & size;
    final r = borderRadius >= size.height / 2
        ? Radius.circular(size.height / 2)
        : Radius.circular(borderRadius);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, r), paint);
  }

  @override
  bool shouldRepaint(covariant _ScoresBlurShadowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.offset != offset ||
      oldDelegate.blurRadius != blurRadius ||
      oldDelegate.borderRadius != borderRadius;
}

class _DockSurfacePainter extends CustomPainter {
  const _DockSurfacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // radial-gradient(120% 160% at 18% -30%, rgba(255,255,255,.22), rgba(255,255,255,0) 48%)
    canvas.save();
    canvas.translate(size.width * 0.18, -size.height * 0.30);
    canvas.scale(size.width * 1.20, size.height * 1.60);
    final radialPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1.0,
        const [Color(0x38FFFFFF), Color(0x00FFFFFF)],
        const [0.0, 0.48],
      );
    canvas.drawRect(const Rect.fromLTRB(-2, -2, 2, 2), radialPaint);
    canvas.restore();

    final radius = Radius.circular(size.height / 2);
    final outerPath = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));

    // inset 0 3px 0 rgba(255,255,255,.16)
    final topInsetPath = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, 3)),
    );
    canvas.drawPath(topInsetPath, Paint()..color = const Color(0x29FFFFFF));

    // inset 0 -7px 0 rgba(0,0,0,.34)
    final bottomInsetPath = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, -7)),
    );
    canvas.drawPath(bottomInsetPath, Paint()..color = const Color(0x57000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DockActiveIndInsetPainter extends CustomPainter {
  const _DockActiveIndInsetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final outerPath = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));

    final topInset = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, 3)),
    );
    canvas.drawPath(topInset, Paint()..color = const Color(0x8CFFFFFF));

    final bottomInset = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, -6)),
    );
    canvas.drawPath(bottomInset, Paint()..color = const Color(0x3D7A082E));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DockCircleInsetPainter extends CustomPainter {
  final double dy;
  final Color color;

  const _DockCircleInsetPainter({required this.dy, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addOval(Offset.zero & size);
    final crescent = Path.combine(
      PathOperation.difference,
      outer,
      outer.shift(Offset(0, dy)),
    );
    canvas.drawPath(crescent, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DockCircleInsetPainter oldDelegate) =>
      oldDelegate.dy != dy || oldDelegate.color != color;
}

class _ScoresPrototypeStatusBar extends StatelessWidget {
  const _ScoresPrototypeStatusBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 35.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 1.6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '09:41',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF141B2A),
                height: 1.55,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CustomPaint(
                  size: Size(15, 15),
                  painter: _ScoresSignalPainter(),
                ),
                SizedBox(width: 5),
                CustomPaint(
                  size: Size(15, 15),
                  painter: _ScoresBatteryPainter(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoresSignalPainter extends CustomPainter {
  const _ScoresSignalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = const Color(0xFF141B2A)
      ..style = PaintingStyle.fill;
    canvas.drawRect(const Rect.fromLTWH(2, 17, 3, 4), paint);
    canvas.drawRect(const Rect.fromLTWH(7.5, 13, 3, 8), paint);
    canvas.drawRect(const Rect.fromLTWH(13, 9, 3, 12), paint);
    canvas.drawRect(const Rect.fromLTWH(18.5, 5, 3, 16), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScoresBatteryPainter extends CustomPainter {
  const _ScoresBatteryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    final strokePaint = Paint()
      ..color = const Color(0xFF141B2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.5, 8, 17, 9),
        const Radius.circular(2.5),
      ),
      strokePaint,
    );
    final fillPaint = Paint()
      ..color = const Color(0xFF141B2A)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4.5, 10, 10, 5),
        const Radius.circular(1),
      ),
      fillPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



