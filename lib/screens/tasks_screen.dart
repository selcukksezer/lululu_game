import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../navigation/game_routes.dart';
import '../services/energy_service.dart';
import '../services/progress_manager.dart';
import '../widgets/home/lululu_dock_bar.dart';

class TasksScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<LululuDockTab>? onSelectDockTab;

  const TasksScreen({
    super.key,
    this.embedded = false,
    this.onClose,
    this.onSelectDockTab,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final List<_TaskItem> _tasks = [
    _TaskItem(
      id: 'play3',
      pmKey: 'play',
      rewardType: 'coin',
      rewardAmount: 150,
      max: 3,
      cur: 0,
      claimed: false,
      iconAsset: 'assets/icons2/target.png',
      iconColors: const [Color(0xFF37E08B), Color(0xFF12B76A)],
    ),
    _TaskItem(
      id: 'merge5',
      pmKey: 'merge',
      rewardType: 'coin',
      rewardAmount: 100,
      max: 5,
      cur: 0,
      claimed: false,
      iconAsset: 'assets/icons2/magnet.png',
      iconColors: const [Color(0xFFF4538B), Color(0xFFE01E5A)],
    ),
    _TaskItem(
      id: 'watch1',
      pmKey: 'video',
      rewardType: 'energy',
      rewardAmount: 3,
      max: 1,
      cur: 0,
      claimed: false,
      iconAsset: 'assets/icons/play.png',
      iconColors: const [Color(0xFF9B5DE5), Color(0xFF7C3AED)],
    ),
    _TaskItem(
      id: 'combo4',
      pmKey: 'combo',
      rewardType: 'coin',
      rewardAmount: 200,
      max: 4,
      cur: 0,
      claimed: false,
      iconAsset: 'assets/icons2/flame.png',
      iconColors: const [Color(0xFFFF8A5C), Color(0xFFFF6B35)],
    ),
  ];

  static String _formatDots(int value) {
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

  void _syncFromProgressManager() {
    final pm = ProgressManager.instance;
    for (final t in _tasks) {
      final pVal = pm.dailyTaskProgress[t.pmKey] ??
          pm.dailyTaskProgress[t.id] ??
          0;
      if (pVal > t.cur) {
        t.cur = pVal;
      }
      final cVal = pm.claimedDailyTasks.contains(t.pmKey) ||
          pm.claimedDailyTasks.contains(t.id);
      if (cVal) {
        t.claimed = true;
      }
    }
  }

  void _claimTask(_TaskItem task) {
    if (task.claimed || task.cur < task.max) return;
    setState(() {
      task.claimed = true;
    });
    final pm = ProgressManager.instance;
    pm.claimedDailyTasks.add(task.pmKey);
    pm.claimedDailyTasks.add(task.id);
    if (task.rewardType == 'coin') {
      pm.addCoins(task.rewardAmount);
    } else if (task.rewardType == 'energy') {
      EnergyService.instance.addEnergy(task.rewardAmount);
    }
  }

  void _handleDockSelect(BuildContext context, LululuDockTab tab) {
    if (widget.onSelectDockTab != null) {
      widget.onSelectDockTab!(tab);
      return;
    }
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
    final mqTop = MediaQuery.of(context).padding.top;
    final screenW = MediaQuery.sizeOf(context).width;
    final isNarrow = screenW < 400;

    return ListenableBuilder(
      listenable: Listenable.merge([
        ProgressManager.instance,
        EnergyService.instance,
      ]),
      builder: (context, _) {
        _syncFromProgressManager();
        final l10n = context.l10n;
        final rawCoins = ProgressManager.instance.coins;
        final coinsText = (rawCoins == ProgressManager.defaultCoins ||
                rawCoins == 300 ||
                rawCoins == 12450)
            ? '12.450'
            : _formatDots(rawCoins);

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          body: Stack(
            fit: StackFit.expand,
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    if (mqTop == 0) const _TasksPrototypeStatusBar(),
                    // .page-title (y=35.4, h=60, padding: 10px 14px 2px 14px)
                    Container(
                      height: 60,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Semantics(
                            button: true,
                            label: l10n.goBackLabel,
                            child: GestureDetector(
                            onTap: widget.onClose ??
                                () => Navigator.of(context).maybePop(),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1A141B2A),
                                    offset: Offset(0, 4),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/icons2/back.png',
                                width: 29,
                                height: 29,
                                fit: BoxFit.contain,
                              ),
                            ),
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Transform.translate(
                              offset: const Offset(0, 1),
                              child: Transform.scale(
                                alignment: Alignment.centerLeft,
                                scaleX: 0.98,
                                scaleY: 1.0,
                                child: Text(
                                  l10n.dailyTasksTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Baloo 2',
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF141B2A),
                                    height: 1.12,
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
                                  'assets/icons2/coin.png',
                                  width: 25,
                                  height: 25,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                                const SizedBox(width: 6),
                                // Sabit genişlik yok: metin doğal
                                // genişliğinde, sığmazsa küçülerek sığar.
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Transform.translate(
                                      offset: const Offset(0, -0.5),
                                      child: Transform.scale(
                                        alignment: Alignment.centerLeft,
                                        scaleX: 0.96,
                                        scaleY: 1.0,
                                        child: Text(
                                          coinsText,
                                          maxLines: 1,
                                          softWrap: false,
                                          style: const TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            height: 1.55,
                                          ),
                                        ),
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
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 120),
                        children: [
                          // Stack so .tasks-hero (position:relative in CSS) paints its
                          // drop shadow over the top of the first .task-card (position:static)
                          Column(
                            verticalDirection: VerticalDirection.up,
                            children: [
                              _buildTaskCard(l10n, _tasks[0]),
                              // .tasks-hero (x=12, y=105.4, w=406, h=123.1, margin: 10px 12px 2px)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 10, 12, 0),
                                child: CustomPaint(
                                  painter: const _TasksBlurShadowPainter(
                                    color: Color(0x47E01E5A),
                                    offset: Offset(0, 10),
                                    blurRadius: 20,
                                    borderRadius: 22,
                                  ),
                                  child: Container(
                                    height: 123.1,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment(-0.881, -1.678),
                                        end: Alignment(0.881, 1.678),
                                        stops: [0.0, 0.62, 1.0],
                                        colors: [
                                          Color(0xFFFF8A00),
                                          Color(0xFFE01E5A),
                                          Color(0xFFB80F42),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 58,
                                          height: 58,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Positioned.fill(
                                                child: Transform.translate(
                                                  offset: const Offset(0, 4),
                                                  child: ImageFiltered(
                                                    imageFilter:
                                                        ui.ImageFilter.blur(
                                                      sigmaX: 3.0,
                                                      sigmaY: 3.0,
                                                    ),
                                                    child: ColorFiltered(
                                                      colorFilter:
                                                          const ColorFilter
                                                              .mode(
                                                        Color(0x4D000000),
                                                        BlendMode.srcIn,
                                                      ),
                                                      child: Image.asset(
                                                        'assets/icons2/gift_box.png',
                                                        width: 58,
                                                        height: 58,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Image.asset(
                                                'assets/icons2/gift_box.png',
                                                width: 58,
                                                height: 58,
                                                fit: BoxFit.contain,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: SizedBox(
                                            height: 95.1,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Positioned(
                                                  left: 0,
                                                  right: 0,
                                                  top: 22.9,
                                                  height: 27.9,
                                                  child: Transform.scale(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    scaleX: 0.98,
                                                    scaleY: 1.0,
                                                    child: Text(
                                                      l10n.todaysTasks,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontFamily: 'Baloo 2',
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                        height: 1.55,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  left: 0,
                                                  right: 0,
                                                  top: 75.7,
                                                  height: 19.4,
                                                  child: isNarrow
                                                      ? FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          child: Text(
                                                            l10n.tasksHeroSubtitle,
                                                            maxLines: 1,
                                                            softWrap: false,
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'Nunito',
                                                              fontSize: 12.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: Color(
                                                                  0xEBFFFFFF),
                                                              height: 1.55,
                                                            ),
                                                          ),
                                                        )
                                                      : OverflowBox(
                                                          maxWidth: 320,
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          child:
                                                              Transform.scale(
                                                            alignment: Alignment
                                                                .centerLeft,
                                                            scaleX: 0.96,
                                                            scaleY: 1.0,
                                                            child: Text(
                                                              l10n.tasksHeroSubtitle,
                                                              maxLines: 1,
                                                              softWrap: false,
                                                              style: TextStyle(
                                                                fontFamily:
                                                                    'Nunito',
                                                                fontSize: 12.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Color(
                                                                    0xEBFFFFFF),
                                                                height: 1.55,
                                                              ),
                                                            ),
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
                                ),
                              ),
                            ],
                          ),

                          for (int i = 1; i < _tasks.length; i++)
                            _buildTaskCard(l10n, _tasks[i]),

                          // .tasks-note (margin: 12px 16px 4px)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF66738A),
                                  height: 1.55,
                                ),
                                children: [
                                  TextSpan(
                                    text: l10n.tasksNotePrefix,
                                  ),
                                  TextSpan(
                                    text: l10n.claimReward,
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF66738A),
                                      height: 1.55,
                                    ),
                                  ),
                                  TextSpan(
                                    text: l10n.tasksNoteSuffix,
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                  child: _TasksFloatingDock(
                    activeTab: LululuDockTab.home,
                    onSelectTab: (tab) => _handleDockSelect(context, tab),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Görev başlığı/ödülü BuildContext gerektirdiği için _TaskItem
  // alanında tutulamaz; id + ödül bilgisinden üretim anında çözülür.
  // Başlık anahtarları ana sayfa görev özetiyle ortaktır (tek kaynak).
  String _taskTitle(AppLocalizations l10n, _TaskItem task) =>
      switch (task.id) {
        'play3' => l10n.taskPlay3Games,
        'merge5' => l10n.taskMerge5,
        'watch1' => l10n.taskWatch1Video,
        'combo4' => l10n.taskCombo4,
        _ => task.id,
      };

  String _taskRewardText(AppLocalizations l10n, _TaskItem task) =>
      task.rewardType == 'energy'
          ? l10n.rewardEnergy(task.rewardAmount)
          : l10n.rewardCoins(task.rewardAmount);

  Widget _buildTaskCard(AppLocalizations l10n, _TaskItem t) {
    final pct = (t.cur / t.max).clamp(0.0, 1.0);
    final isDone = t.cur >= t.max;
    final isEnergy = t.rewardType == 'energy';
    final title = _taskTitle(l10n, t);
    final rewardText = _taskRewardText(l10n, t);

    return Opacity(
      opacity: t.claimed ? 0.68 : 1.0,
      child: Container(
        height: 138.4,
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (isDone && !t.claimed)
              const BoxShadow(
                color: Color(0xFF12B76A),
                spreadRadius: 2,
                blurRadius: 0,
              ),
            const BoxShadow(
              color: Color(0x12141B2A),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 90.4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(-0.342, -0.940),
                        end: const Alignment(0.342, 0.940),
                        colors: t.iconColors,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      t.iconAsset,
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        height: 43.2,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              top: -2.7,
                              height: 18.2,
                              child: Transform.scale(
                                alignment: Alignment.centerLeft,
                                scaleX: 0.97,
                                scaleY: 1.0,
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textHeightBehavior: const TextHeightBehavior(
                                    applyHeightToFirstAscent: true,
                                    applyHeightToLastDescent: true,
                                    leadingDistribution:
                                        TextLeadingDistribution.even,
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'Baloo 2',
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF141B2A),
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 41.4,
                              height: 19.4,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    isEnergy
                                        ? 'assets/design/ui/icon_heart_exact.webp'
                                        : 'assets/icons2/coin.png',
                                    width: 18,
                                    height: 18,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 5),
                                  Transform.scale(
                                    alignment: Alignment.centerLeft,
                                    scaleX: 0.96,
                                    scaleY: 1.0,
                                    child: Text(
                                      rewardText,
                                      textHeightBehavior:
                                          const TextHeightBehavior(
                                        applyHeightToFirstAscent: true,
                                        applyHeightToLastDescent: true,
                                        leadingDistribution:
                                            TextLeadingDistribution.even,
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: isEnergy
                                            ? const Color(0xFFB80F42)
                                            : const Color(0xFF8A6D00),
                                        height: 1.55,
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
                  ),
                  if (t.claimed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        l10n.claimedWithCheck,
                        style: TextStyle(
                          fontFamily: 'Baloo 2',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A9553),
                        ),
                      ),
                    )
                  else if (isDone)
                    Semantics(
                      button: true,
                      label: l10n.claimTaskLabel(title, rewardText),
                      child: GestureDetector(
                      onTap: () => _claimTask(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF37E08B),
                              Color(0xFF12B76A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF066C3C),
                              offset: Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          l10n.claimReward,
                          style: TextStyle(
                            fontFamily: 'Baloo 2',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ))
                  else
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'Baloo 2',
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF66738A),
                          height: 1.55,
                        ),
                        children: [
                          TextSpan(
                            text: '${t.cur}',
                            style: const TextStyle(
                              fontFamily: 'Baloo 2',
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF141B2A),
                              height: 1.55,
                            ),
                          ),
                          TextSpan(text: '/${t.max}'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Container(
              height: 13,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFDADEE8),
                    Color(0xFFEDF0F6),
                    Color(0xFFEDF0F6),
                  ],
                  stops: [0.0, 0.25, 1.0],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDone
                          ? const [Color(0xFF37E08B), Color(0xFF12B76A)]
                          : const [Color(0xFFFFD84A), Color(0xFFE01E5A)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskItem {
  final String id;
  final String pmKey;
  final String rewardType;
  final int rewardAmount;
  final int max;
  int cur;
  bool claimed;
  final String iconAsset;
  final List<Color> iconColors;

  _TaskItem({
    required this.id,
    required this.pmKey,
    required this.rewardType,
    required this.rewardAmount,
    required this.max,
    required this.cur,
    required this.claimed,
    required this.iconAsset,
    required this.iconColors,
  });
}

class _TasksFloatingDock extends StatelessWidget {
  final LululuDockTab activeTab;
  final ValueChanged<LululuDockTab> onSelectTab;

  const _TasksFloatingDock({
    required this.activeTab,
    required this.onSelectTab,
  });

  static const _tabs = LululuDockTab.values;

  // S3#27: dock etiketleri tek kaynaktan (nav* anahtarları).
  static String _label(AppLocalizations l10n, LululuDockTab tab) =>
      switch (tab) {
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
    final l10n = context.l10n;
    return CustomPaint(
      painter: const _TasksBlurShadowPainter(
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
                      painter: _TasksDockSurfacePainter(),
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
                      painter: const _TasksBlurShadowPainter(
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
                                  painter: _TasksDockActiveIndInsetPainter(),
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
                            child: Semantics(
                              button: true,
                              label: _label(l10n, tab),
                              selected: tab == activeTab,
                              child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelectTab(tab),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
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
                                                const _TasksBlurShadowPainter(
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
                                                            _TasksDockCircleInsetPainter(
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
                                                        _TasksDockCircleInsetPainter(
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
                                          _label(l10n, tab),
                                          maxLines: 1,
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
                                                      color:
                                                          Color(0x737A082E),
                                                      offset: Offset(0, 2),
                                                      blurRadius: 0,
                                                    ),
                                                  ]
                                                : const [
                                                    Shadow(
                                                      color:
                                                          Color(0xBF000000),
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
                          )),
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

class _TasksBlurShadowPainter extends CustomPainter {
  final Color color;
  final Offset offset;
  final double blurRadius;
  final double borderRadius;

  const _TasksBlurShadowPainter({
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
  bool shouldRepaint(covariant _TasksBlurShadowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.offset != offset ||
      oldDelegate.blurRadius != blurRadius ||
      oldDelegate.borderRadius != borderRadius;
}

class _TasksDockSurfacePainter extends CustomPainter {
  const _TasksDockSurfacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
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

    final topInsetPath = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, 3)),
    );
    canvas.drawPath(topInsetPath, Paint()..color = const Color(0x29FFFFFF));

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

class _TasksDockActiveIndInsetPainter extends CustomPainter {
  const _TasksDockActiveIndInsetPainter();

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

class _TasksDockCircleInsetPainter extends CustomPainter {
  final double dy;
  final Color color;

  const _TasksDockCircleInsetPainter({required this.dy, required this.color});

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
  bool shouldRepaint(covariant _TasksDockCircleInsetPainter oldDelegate) =>
      oldDelegate.dy != dy || oldDelegate.color != color;
}

class _TasksPrototypeStatusBar extends StatelessWidget {
  const _TasksPrototypeStatusBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 35.4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 2),
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
                  painter: _TasksSignalPainter(),
                ),
                SizedBox(width: 5),
                CustomPaint(
                  size: Size(15, 15),
                  painter: _TasksBatteryPainter(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TasksSignalPainter extends CustomPainter {
  const _TasksSignalPainter();

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

class _TasksBatteryPainter extends CustomPainter {
  const _TasksBatteryPainter();

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


