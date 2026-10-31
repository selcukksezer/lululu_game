import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/firebase_bootstrap.dart';
import '../services/leaderboard_service.dart';
import '../theme/lululu_theme.dart';
import '../widgets/dot_scaffold.dart';
import 'auth_screen.dart';

/// Gerçek kayıtlı kullanıcı skorları (yerel vault + Firestore sync).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _service = LeaderboardService.instance;
  String _modeFilter = 'overall';
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onDataChanged);
    AuthService.instance.addListener(_onDataChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await AuthService.instance.ensureLoaded();
    await _service.ensureLoaded();
    await CloudSyncService.instance.enableOnlineWhenSignedIn();
    await _service.refreshFromCloud();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pullToRefresh() async {
    setState(() => _refreshing = true);
    try {
      await CloudSyncService.instance.enableOnlineWhenSignedIn();
      await CloudSyncService.instance.flushPending();
      await _service.refreshFromCloud();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onDataChanged);
    AuthService.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _buildBody();

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'Sıralama',
              style: GoogleFonts.exo2(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: LululuColors.ink,
              ),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return DotScaffold(
      appBar: AppBar(
        title: const Text('Sıralama'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: body,
    );
  }

  Widget _buildBody() {
    final auth = AuthService.instance;
    final myRank = _modeFilter == 'overall'
        ? _service.getMyOverallRank(n: 50)
        : _service.getMyModeRank(_modeFilter, n: 50);
    final myScore = _modeFilter == 'overall'
        ? _service.myBestOverall
        : _service.getBest(_modeFilter);
    final rows = _modeFilter == 'overall'
        ? _service.getOverallTop(n: 50)
        : _service.getTop(_modeFilter, n: 50);
    final sourceLabel = FirebaseBootstrap.ready
        ? 'Canlı · kayıtlı oyuncular'
        : 'Yerel · kayıtlı hesap skorları';

    return RefreshIndicator(
      color: LululuColors.liquidGold,
      onRefresh: _pullToRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _MyRankCard(
            signedIn: auth.isSignedIn,
            displayName: auth.displayName,
            rank: myRank,
            score: myScore,
            onLogin: () => AuthScreen.open(context),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  sourceLabel,
                  style: GoogleFonts.exo2(
                    fontSize: 11,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
              ),
              if (_refreshing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: _pullToRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: LululuColors.mutedTitanium,
                ),
            ],
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'Herkes',
                  selected: _modeFilter == 'overall',
                  onTap: () => setState(() => _modeFilter = 'overall'),
                ),
                for (final id in LeaderboardService.allModeIds)
                  _FilterChip(
                    label: LeaderboardService.modeDisplayNames[id] ?? id,
                    selected: _modeFilter == id,
                    onTap: () => setState(() => _modeFilter = id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _modeFilter == 'overall' ? 'GENEL LİSTE' : 'MOD LİSTESİ',
            style: GoogleFonts.exo2(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: LululuColors.mutedTitanium,
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              auth.isSignedIn
                  ? 'Henüz skor yok — oyna, listeye gir.'
                  : 'Giriş yap, oyna — sıralama gerçek skorlarla dolacak.',
              style: GoogleFonts.exo2(color: LululuColors.mutedTitanium),
            )
          else
            for (var i = 0; i < rows.length; i++)
              _RankTile(
                rank: i + 1,
                entry: rows[i],
                highlight: rows[i].isLocalPlayer ||
                    rows[i].playerId == auth.playerId ||
                    rows[i].playerName == auth.displayName,
              ),
        ],
      ),
    );
  }
}

class _MyRankCard extends StatelessWidget {
  const _MyRankCard({
    required this.signedIn,
    required this.displayName,
    required this.rank,
    required this.score,
    required this.onLogin,
  });

  final bool signedIn;
  final String displayName;
  final int? rank;
  final int score;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LululuRadii.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LululuColors.spaceNavy,
            LululuColors.cyberFuchsia.withValues(alpha: 0.28),
            LululuColors.carbonVoid,
          ],
        ),
        border: Border.all(
          color: LululuColors.liquidGold.withValues(alpha: 0.5),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: LululuColors.liquidGold.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: LululuColors.darkObsidian,
              border: Border.all(color: LululuColors.toxicNeon.withValues(alpha: 0.5)),
            ),
            child: Text(
              rank == null ? '—' : '#$rank',
              style: GoogleFonts.exo2(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: LululuColors.toxicNeon,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SENİN SIRAN',
                  style: GoogleFonts.exo2(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
                Text(
                  signedIn ? displayName : 'Giriş yok',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.exo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                    color: LululuColors.ink,
                  ),
                ),
                Text(
                  score > 0 ? 'En iyi: $score' : 'Skor yok — oyna!',
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    color: LululuColors.liquidGold,
                  ),
                ),
              ],
            ),
          ),
          if (!signedIn)
            TextButton(
              onPressed: onLogin,
              child: Text(
                'GİRİŞ',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w900,
                  color: LululuColors.liquidGold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? LululuColors.darkObsidian
                : LululuColors.carbonVoid,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? LululuColors.toxicNeon.withValues(alpha: 0.6)
                  : LululuColors.mutedTitanium.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.exo2(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected ? LululuColors.toxicNeon : LululuColors.mutedTitanium,
            ),
          ),
        ),
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({
    required this.rank,
    required this.entry,
    required this.highlight,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final mode =
        LeaderboardService.modeDisplayNames[entry.modeId] ?? entry.modeId;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      constraints: const BoxConstraints(minHeight: LululuMotion.minTap),
      decoration: BoxDecoration(
        gradient: highlight
            ? LinearGradient(
                colors: [
                  LululuColors.cyberFuchsia.withValues(alpha: 0.28),
                  LululuColors.spaceNavy,
                ],
              )
            : LululuGradients.navyToCarbon,
        borderRadius: BorderRadius.circular(LululuRadii.pill),
        border: Border.all(
          color: highlight
              ? LululuColors.liquidGold.withValues(alpha: 0.65)
              : LululuColors.darkObsidian.withValues(alpha: 0.9),
          width: highlight ? 1.3 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: LululuColors.liquidGold.withValues(alpha: 0.2),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '$rank',
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w900,
                color: rank <= 3
                    ? LululuColors.liquidGold
                    : LululuColors.mutedTitanium,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.playerName + (highlight ? '  · sen' : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                    color: LululuColors.ink,
                  ),
                ),
                Text(
                  mode,
                  style: GoogleFonts.exo2(
                    fontSize: 10,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.score}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
              color: LululuColors.liquidGold,
            ),
          ),
        ],
      ),
    );
  }
}
