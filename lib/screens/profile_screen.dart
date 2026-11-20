import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../navigation/game_routes.dart';
import '../services/audio_manager.dart';
import '../services/auth_service.dart';
import '../services/progress_manager.dart';
import '../utils/number_format.dart';
import '../widgets/achievement_toast_overlay.dart';
import '../widgets/invite_redeem_sheet.dart';
import '../widgets/home/lululu_dock_bar.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<LululuDockTab>? onSelectDockTab;

  const ProfileScreen({
    super.key,
    this.embedded = false,
    this.onClose,
    this.onSelectDockTab,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<double> _grayscaleMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ];

  void _openAuth() {
    // S11: avatar + misafir CTA dokunuş sesi (iki giriş de bu yoldan).
    AudioManager().playPop();
    Navigator.of(context).pushNamed('/account');
  }

  void _handleBack() {
    AudioManager().playPop();
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// K1-entry: Başarımlar / Pass sheet girişi. Sheet'in `show`
  /// yardımcısı yok; doğrudan bottom-sheet çağrısı (diğer sheet
  /// açma desenleriyle aynı). Sheet içi `Expanded` için yükseklik
  /// sınırlıdır.
  void _openPassSheet() {
    AudioManager().playPop();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.88,
        child: AchievementPassSheet(),
      ),
    );
  }

  /// K17 + 9A: davet sheet'i — paylaşım + kod karşılama aynı yerde.
  /// Paylaşım akışı aynen kalır (sheet içindeki Paylaş düğmesi eski
  /// `shareInvite` yolunu kullanır); redeem sheet'in alt bölümündedir.
  void _openInviteSheet() {
    AudioManager().playPop();
    showInviteRedeemSheet(context);
  }

  /// Misafir çağrısı: giriş yap / kayıt ol düğmesi + kısa açıklama.
  /// Yalnızca misafir görünümünde, profil başlığının altında gösterilir.
  Widget _buildGuestSignInCta() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: l10n.signInOrUpLabel,
            child: GestureDetector(
              onTap: _openAuth,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
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
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  l10n.signInOrUpButton,
                  style: TextStyle(
                    fontFamily: 'Baloo 2',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.guestSignInExplanation,
            textAlign: TextAlign.center,
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
    );
  }

  void _handleDefaultDockSelect(LululuDockTab tab) {
    AudioManager().playPop();
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        AuthService.instance,
        ProgressManager.instance,
      ]),
      builder: (context, _) {
        final l10n = context.l10n;
        final auth = AuthService.instance;
        final pm = ProgressManager.instance;
        final isNarrow = MediaQuery.sizeOf(context).width < 400;

        // Misafir (oturum yok ya da misafir oturumu) asla "Apple Oyuncu" gibi
        // gösterilmez; Apple etiketi yalnızca gerçekten Apple ile girene aittir.
        final isGuest = !auth.isSignedIn || auth.isGuest;
        final userName = auth.isSignedIn ? auth.displayName : l10n.guestName;
        final handleText = !auth.isSignedIn
            ? l10n.guestHandleNotSignedIn
            : auth.provider == AuthProviderKind.apple
                ? l10n.appleHandle
                : auth.isGuest
                    ? l10n.guestSessionHandle
                    : '@${userName.toLowerCase().replaceAll(' ', '')} · ${auth.providerLabel}';

        final displayCoins = pm.coins;
        final totalBest = pm.total11ModesScore;
        // 12A: gerçek değerler — şişirme sabitleri kaldırıldı (0 ilerlemede
        // 0 skor / 0 oyun / 0 kombo / seviye 1 / tabansız XP).
        final displayTotalScore = totalBest;
        final playProgress = pm.dailyTaskProgress['play'] ?? 0;
        final displayGamesPlayed = playProgress;
        final comboProgress = pm.dailyTaskProgress['combo'] ?? 0;
        final displayBestCombo = comboProgress;
        final displayLevel = pm.unlockedLevel < 1 ? 1 : pm.unlockedLevel;
        final displayXpCurrent = pm.xp;
        // Seviye başına 2000 XP hedefi: şişirme değil, seviye hedefi
        // (ProgressManager.xpTargetPerLevel ile aynı değer).
        final displayXpTarget = ProgressManager.xpTargetPerLevel;
        final xpRatio =
            (displayXpCurrent / displayXpTarget).clamp(0.0, 1.0);

        final unlockedCombo = displayBestCombo >= 5;
        final unlockedMarathon = displayGamesPlayed >= 50;
        final unlockedVideo = (pm.dailyTaskProgress['video'] ?? 0) >= 1;
        final unlockedGoldFinger = displayTotalScore >= 10000;
        final unlockedTaskHunter = pm.claimedDailyTasks.length >= 4;
        final unlockedEvolution = pm.maxUnlockedTier >= 9;

        final row1Badges = <_BadgeData>[
          _BadgeData(
            title: l10n.badgeComboKing,
            sub: unlockedCombo ? l10n.badgeEarned : l10n.badgeComboKingReq,
            bg: const Color(0xFFFFF1E6),
            iconAsset: 'assets/icons2/flame.png',
            unlocked: unlockedCombo,
          ),
          _BadgeData(
            title: l10n.badgeMarathon,
            sub: unlockedMarathon ? l10n.badgeEarned : l10n.badgeMarathonReq,
            bg: const Color(0xFFE8F8F0),
            iconAsset: 'assets/icons2/stopwatch.png',
            unlocked: unlockedMarathon,
          ),
          _BadgeData(
            title: l10n.badgeVideoBuff,
            sub: unlockedVideo ? l10n.badgeEarned : l10n.badgeVideoBuffReq,
            bg: const Color(0xFFF0EAFB),
            iconAsset: 'assets/icons/play.png',
            unlocked: unlockedVideo,
          ),
        ];

        final row2Badges = <_BadgeData>[
          _BadgeData(
            title: l10n.badgeGoldenFinger,
            sub: unlockedGoldFinger
                ? l10n.badgeEarned
                : l10n.badgeGoldenFingerReq,
            bg: const Color(0xFFFFF7DB),
            iconAsset: 'assets/icons2/coin_stack.png',
            unlocked: unlockedGoldFinger,
          ),
          _BadgeData(
            title: l10n.badgeTaskHunter,
            sub: unlockedTaskHunter
                ? l10n.badgeEarned
                : l10n.badgeTaskHunterReq,
            bg: const Color(0xFFFDEAF1),
            iconAsset: 'assets/icons2/target.png',
            unlocked: unlockedTaskHunter,
          ),
          _BadgeData(
            title: l10n.badgeEvolutionMaster,
            sub: unlockedEvolution
                ? l10n.badgeEarned
                : l10n.badgeEvolutionMasterReq,
            bg: const Color(0xFFFFF7DB),
            iconAsset: 'assets/icons2/crown.png',
            unlocked: unlockedEvolution,
          ),
        ];

        final unlockedCount = [
          ...row1Badges,
          ...row2Badges,
        ].where((b) => b.unlocked).length;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          body: Stack(
            fit: StackFit.expand,
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // .page-title (y=35.4, h=60, padding: 10px 14px 2px 14px)
                    Container(
                      height: 60,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Semantics(
                            button: true,
                            label: context.l10n.goBackLabel,
                            child: GestureDetector(
                            onTap: _handleBack,
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
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Transform.translate(
                              offset: const Offset(0, 1),
                              child: Transform.scale(
                                alignment: Alignment.centerLeft,
                                scaleX: 0.985,
                                scaleY: 1.0,
                                child: Text(
                                  l10n.playerProfileTitle,
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
                                SizedBox(
                                  width: displayCoins == 12450 ? 44.2 : null,
                                  child: Transform.translate(
                                    offset: const Offset(0, -0.5),
                                    child: Transform.scale(
                                      alignment: Alignment.centerLeft,
                                      scaleX: 0.96,
                                      scaleY: 1.0,
                                      child: Text(
                                        formatGroupedInt(
                                          displayCoins,
                                          Localizations.localeOf(context)
                                              .languageCode,
                                        ),
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
                          // .prof-head (y=95.4, h=285.6, padding: 14px 16px 2px 16px)
                          Container(
                            height: 285.6,
                            padding:
                                const EdgeInsets.fromLTRB(16, 14, 16, 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Semantics(
                                  button: true,
                                  label: l10n.signInOrUpLabel,
                                  child: GestureDetector(
                                    onTap: _openAuth,
                                    child: CustomPaint(
                                      painter: const _ProfileBlurShadowPainter(
                                        color: Color(0x59FFB800),
                                        offset: Offset(0, 10),
                                        blurRadius: 22,
                                        borderRadius: 999,
                                      ),
                                      child: Container(
                                        width: 118,
                                        height: 118,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFFFB800),
                                            width: 5,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: SizedBox(
                                            width: 108,
                                            height: 108,
                                            child: Stack(
                                              clipBehavior: Clip.hardEdge,
                                              children: [
                                                Positioned(
                                                  left: 5.4,
                                                  top: 9.8,
                                                  width: 97.2,
                                                  height: 176.0,
                                                  child: Image.asset(
                                                    'assets/design/bugs_hd/tier5_hd.png',
                                                    fit: BoxFit.contain,
                                                    filterQuality:
                                                        FilterQuality.medium,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 26.9,
                                  child: Center(
                                    child: Transform.translate(
                                      offset: const Offset(0, -1),
                                      child: Transform.scale(
                                        scaleX: 0.985,
                                        scaleY: 1.0,
                                        child: Text(
                                          userName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Baloo 2',
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF141B2A),
                                            height: 1.12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 20.1,
                                  child: Center(
                                    child: Transform.scale(
                                      scaleX: 0.96,
                                      scaleY: 1.0,
                                      child: Text(
                                        handleText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF66738A),
                                          height: 1.55,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 33.7,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFF4538B),
                                        Color(0xFFE01E5A),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0xFF7E0A2E),
                                        offset: Offset(0, 4),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/icons/level_up.png',
                                        width: 19,
                                        height: 19,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.medium,
                                      ),
                                      const SizedBox(width: 6),
                                      SizedBox(
                                        width: 44.3,
                                        child: Transform.translate(
                                          offset: const Offset(0, -1),
                                          child: Transform.scale(
                                            alignment: Alignment.centerLeft,
                                            scaleX: 0.96,
                                            scaleY: 1.0,
                                            child: Text(
                                              l10n.levelLabel,
                                              maxLines: 1,
                                              softWrap: false,
                                              style: TextStyle(
                                                fontFamily: 'Baloo 2',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                height: 1.55,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      SizedBox(
                                        width:
                                            displayLevel >= 10 ? 13.3 : null,
                                        child: Transform.translate(
                                          offset: const Offset(0, -1),
                                          child: Transform.scale(
                                            alignment: Alignment.centerLeft,
                                            scaleX: 0.96,
                                            scaleY: 1.0,
                                            child: Text(
                                              '$displayLevel',
                                              maxLines: 1,
                                              softWrap: false,
                                              style: const TextStyle(
                                                fontFamily: 'Baloo 2',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                height: 1.55,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 320),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        height: 15,
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
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: xpRatio,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF37E08B),
                                                  Color(0xFF12B76A),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      SizedBox(
                                        height: 18.6,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Transform.translate(
                                              offset: const Offset(0, -1),
                                              child: RichText(
                                                text: TextSpan(
                                                  style: const TextStyle(
                                                    fontFamily: 'Nunito',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF66738A),
                                                    height: 1.55,
                                                  ),
                                                  children: [
                                                    const TextSpan(text: 'XP '),
                                                    TextSpan(
                                                      text: formatGroupedInt(
                                                        displayXpCurrent,
                                                        Localizations.localeOf(
                                                          context,
                                                        ).languageCode,
                                                      ),
                                                      style: const TextStyle(
                                                        fontFamily: 'Nunito',
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color:
                                                            Color(0xFF0A9553),
                                                        height: 1.55,
                                                      ),
                                                    ),
                                                    const TextSpan(
                                                      text: ' / 2.000',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Transform.translate(
                                              offset: const Offset(-0.5, 0),
                                              child: Transform.scale(
                                                alignment:
                                                    Alignment.centerRight,
                                                scaleX: 0.956,
                                                scaleY: 1.0,
                                                child: Text(
                                                  l10n.nextLevel,
                                                  style: TextStyle(
                                                    fontFamily: 'Nunito',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF66738A),
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
                              ],
                            ),
                          ),

                          // K8-profil: pelerin sahipliği rozeti — PM bu
                          // build'de zaten dinleniyor (ListenableBuilder),
                          // değer değişince görünüm güncellenir.
                          if (pm.hasRoyalCape ||
                              pm.ownedCosmetics.contains('royal_cape'))
                            _buildCapeBadge(),

                          if (isGuest) _buildGuestSignInCta(),

                          // .prof-stats (y=381.0, h=114.0, padding: 16px 12px 2px 12px)
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(12, 16, 12, 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    iconAsset: 'assets/icons2/trophy.png',
                                    value: formatGroupedInt(
                                      displayTotalScore,
                                      Localizations.localeOf(context)
                                          .languageCode,
                                    ),
                                    label: l10n.totalScoreLabel,
                                    isNarrow: isNarrow,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildStatCard(
                                    iconAsset: 'assets/icons/play.png',
                                    value: '$displayGamesPlayed',
                                    label: l10n.gamesPlayedLabel,
                                    isNarrow: isNarrow,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildStatCard(
                                    iconAsset: 'assets/icons2/flame.png',
                                    value: '×$displayBestCombo',
                                    label: l10n.bestComboLabel,
                                    isNarrow: isNarrow,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // .sec-head (y=495.0, h=47.0, padding: 18px 16px 8px 16px)
                          Container(
                            height: 47.0,
                            padding:
                                const EdgeInsets.fromLTRB(16, 18, 16, 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Transform.translate(
                                  offset: const Offset(0, -1),
                                  child: Transform.scale(
                                    alignment: Alignment.centerLeft,
                                    scaleX: 0.985,
                                    scaleY: 1.0,
                                    child: Text(
                                      l10n.myBadges,
                                      style: TextStyle(
                                        fontFamily: 'Baloo 2',
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF141B2A),
                                        height: 1.12,
                                      ),
                                    ),
                                  ),
                                ),
                                Transform.translate(
                                  offset: const Offset(1, -1),
                                  child: Transform.scale(
                                    alignment: Alignment.centerRight,
                                    scaleX: 0.985,
                                    scaleY: 1.0,
                                    child: Text(
                                      l10n.badgesEarnedCount(unlockedCount),
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF66738A),
                                        height: 1.55,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // .badge-grid (y=542.0, padding: 2px 12px 6px 12px)
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(12, 2, 12, 6),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    for (int i = 0;
                                        i < row1Badges.length;
                                        i++) ...[
                                      if (i > 0) const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildBadgeCard(
                                          row1Badges[i],
                                          cardHeight: 116.0,
                                          isNarrow: isNarrow,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    for (int i = 0;
                                        i < row2Badges.length;
                                        i++) ...[
                                      if (i > 0) const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildBadgeCard(
                                          row2Badges[i],
                                          cardHeight: 132.0,
                                          isNarrow: isNarrow,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // K1-entry + K17: Başarımlar/Pass + Davet girişleri.
                          _buildProfileActionRow(
                            key: const Key('profile_pass_row'),
                            emoji: '🏆',
                            title: l10n.masteryPassTitle,
                            subtitle: l10n.profilePassRowSub,
                            onTap: _openPassSheet,
                          ),
                          const SizedBox(height: 10),
                          _buildProfileActionRow(
                            key: const Key('profile_invite_row'),
                            emoji: '✉️',
                            title: l10n.profileInviteRowTitle,
                            subtitle: l10n.profileInviteRowSub,
                            onTap: _openInviteSheet,
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
                  child: _ProfileFloatingDock(
                    activeTab: LululuDockTab.home,
                    onSelectTab: _handleDefaultDockSelect,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// K8-profil: pelerin sahipliği rozeti (yalnız sahipken çizilir).
  Widget _buildCapeBadge() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Center(
        child: Container(
          key: const Key('profile_royal_cape_badge'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7DB),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFFB800), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👑', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                context.l10n.profileRoyalCapeBadge,
                style: const TextStyle(
                  fontFamily: 'Baloo 2',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7A5B00),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Profil giriş satırı (K1-entry / K17): rozet kartlarıyla aynı
  /// beyaz kart dili, ≥56px dokunuş yüksekliği.
  Widget _buildProfileActionRow({
    Key? key,
    required String emoji,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Semantics(
        button: true,
        label: '$title, $subtitle',
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12141B2A),
                  offset: Offset(0, 5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF7DB),
                    shape: BoxShape.circle,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Baloo 2',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF141B2A),
                          height: 1.2,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
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
                const SizedBox(width: 8),
                const ExcludeSemantics(
                  child: Text(
                    '›',
                    style: TextStyle(
                      fontFamily: 'Baloo 2',
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFB800),
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String iconAsset,
    required String value,
    required String label,
    required bool isNarrow,
  }) {
    final labelText = Transform.translate(
      offset: const Offset(0, -1),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF66738A),
          letterSpacing: 0.7,
          height: 1.55,
        ),
      ),
    );

    return Container(
      height: 96.0,
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 11.6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12141B2A),
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            iconAsset,
            width: 30,
            height: 30,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 19.9,
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -1),
                child: Transform.scale(
                  scaleX: 0.98,
                  scaleY: 1.0,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Baloo 2',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF141B2A),
                      height: 1.05,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 15.5,
            child: isNarrow
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: labelText,
                  )
                : OverflowBox(
                    maxWidth: 140,
                    child: Center(child: labelText),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(
    _BadgeData b, {
    required double cardHeight,
    required bool isNarrow,
  }) {
    final l10n = context.l10n;
    Widget iconWidget = Image.asset(
      b.iconAsset,
      width: 36,
      height: 36,
      fit: BoxFit.contain,
    );
    if (!b.unlocked) {
      iconWidget = Opacity(
        opacity: 0.4,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
          child: iconWidget,
        ),
      );
    }

    final titleWidget = Transform.translate(
      offset: const Offset(0, -1),
      child: Transform.scale(
        scaleX: 0.975,
        scaleY: 1.0,
        child: Text(
          b.title,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontFamily: 'Baloo 2',
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color:
                b.unlocked ? const Color(0xFF141B2A) : const Color(0xFF93A0B5),
            height: 1.15,
          ),
        ),
      ),
    );

    final subWidget = Transform.translate(
      offset: Offset(0, cardHeight < 120 ? 0.0 : -1.0),
      child: Transform.scale(
        scaleX: 0.975,
        scaleY: 1.0,
        child: Text(
          b.sub,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF66738A),
            height: 1.55,
          ),
        ),
      ),
    );

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12141B2A),
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: b.bg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: iconWidget,
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 14.4,
                    child: isNarrow
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: titleWidget,
                          )
                        : OverflowBox(
                            maxWidth: 130,
                            child: Center(child: titleWidget),
                          ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: b.sub.contains('\n') ? 32.6 : 16.3,
                    child: isNarrow
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: subWidget,
                          )
                        : OverflowBox(
                            maxWidth: 126,
                            alignment: Alignment.topCenter,
                            child: subWidget,
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (!b.unlocked)
            Positioned(
              top: 10,
              right: 8,
              child: Container(
                height: 18.7,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF0F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  l10n.lockedLabel,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF66738A),
                    letterSpacing: 0.475,
                    height: 1.55,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgeData {
  final String title;
  final String sub;
  final Color bg;
  final String iconAsset;
  final bool unlocked;

  const _BadgeData({
    required this.title,
    required this.sub,
    required this.bg,
    required this.iconAsset,
    required this.unlocked,
  });
}

class _ProfileFloatingDock extends StatelessWidget {
  final LululuDockTab activeTab;
  final ValueChanged<LululuDockTab> onSelectTab;

  const _ProfileFloatingDock({
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
      painter: const _ProfileBlurShadowPainter(
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
                      painter: _ProfileDockSurfacePainter(),
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
                      painter: const _ProfileBlurShadowPainter(
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
                                  painter: _ProfileDockActiveIndInsetPainter(),
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
                                                const _ProfileBlurShadowPainter(
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
                                                            _ProfileDockCircleInsetPainter(
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
                                                        _ProfileDockCircleInsetPainter(
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

class _ProfileBlurShadowPainter extends CustomPainter {
  final Color color;
  final Offset offset;
  final double blurRadius;
  final double borderRadius;

  const _ProfileBlurShadowPainter({
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
  bool shouldRepaint(covariant _ProfileBlurShadowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.offset != offset ||
      oldDelegate.blurRadius != blurRadius ||
      oldDelegate.borderRadius != borderRadius;
}

class _ProfileDockSurfacePainter extends CustomPainter {
  const _ProfileDockSurfacePainter();

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

class _ProfileDockActiveIndInsetPainter extends CustomPainter {
  const _ProfileDockActiveIndInsetPainter();

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

class _ProfileDockCircleInsetPainter extends CustomPainter {
  final double dy;
  final Color color;

  const _ProfileDockCircleInsetPainter({required this.dy, required this.color});

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
  bool shouldRepaint(covariant _ProfileDockCircleInsetPainter oldDelegate) =>
      oldDelegate.dy != dy || oldDelegate.color != color;
}


