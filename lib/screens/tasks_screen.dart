import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/lululu_press.dart';

/// Günlük görevler. İlerleme mock state ile dolar; gerçek oyun olayı
/// bağlantısı sonraki fazda eklenecek.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _Task {
  _Task({
    required this.title,
    required this.progress,
    required this.target,
    required this.reward,
    required this.icon,
    this.claimed = false,
  });

  final String title;
  final int progress;
  final int target;
  final String reward;
  final IconData icon;
  bool claimed;

  bool get complete => progress >= target;
}

class _TasksScreenState extends State<TasksScreen> {
  final _tasks = <_Task>[
    _Task(
      title: '3 OYUN OYNA',
      progress: 1,
      target: 3,
      reward: '+100 COİN',
      icon: Icons.sports_esports_rounded,
    ),
    _Task(
      title: '5 BİRLEŞTİRME YAP',
      progress: 3,
      target: 5,
      reward: '+100 COİN',
      icon: Icons.merge_rounded,
    ),
    _Task(
      title: '1 VİDEO İZLE',
      progress: 1,
      target: 1,
      reward: '+50 COİN',
      icon: Icons.play_circle_fill_rounded,
    ),
    _Task(
      title: 'X4 KOMBO YAP',
      progress: 2,
      target: 4,
      reward: '+5 ENERJİ',
      icon: Icons.bolt_rounded,
    ),
  ];

  void _claim(int index) {
    final task = _tasks[index];
    if (!task.complete || task.claimed) return;
    setState(() => task.claimed = true);
    AudioManager().playWin();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ödül alındı: ${task.reward}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LululuColors.paper,
      appBar: AppBar(
        backgroundColor: LululuColors.paper,
        foregroundColor: LululuColors.inkDark,
        elevation: 0,
        title: Text(
          'GÜNLÜK GÖREVLER',
          style: GoogleFonts.exo2(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LululuGradients.paperHero,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: LululuColors.paper,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BUGÜNÜN GÖREVLERİ',
                        style: GoogleFonts.exo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: LululuColors.paper,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Görevleri bitir, ödülü kap — yarın yenileri gelir!',
                        style: GoogleFonts.exo2(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: LululuColors.paper.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < _tasks.length; i++) ...[
            _TaskCard(
              task: _tasks[i],
              onClaim: () => _claim(i),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          Text(
            'İlerleme bu oturumda oynadıkça dolar. Tamamlanan görevde ÖDÜLÜ AL belirir; coin cüzdanına, enerji kalbine anında işler.',
            style: GoogleFonts.exo2(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: LululuColors.mutedTitanium,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onClaim});

  final _Task task;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final t = (task.progress / task.target).clamp(0.0, 1.0);
    final claimable = task.complete && !task.claimed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LululuColors.paper,
        borderRadius: BorderRadius.circular(LululuRadii.card),
        border: Border.all(
          color: claimable
              ? LululuColors.liquidGold
              : LululuColors.mutedTitanium.withValues(alpha: 0.3),
          width: claimable ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: LululuColors.cyberFuchsia.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  task.icon,
                  color: LululuColors.cyberFuchsia,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: LululuColors.inkDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ödül: ${task.reward}',
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: LululuColors.mutedTitanium,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${task.progress}/${task.target}',
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.inkDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: t),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor:
                    LululuColors.mutedTitanium.withValues(alpha: 0.18),
                color: task.complete
                    ? LululuColors.toxicNeon
                    : LululuColors.cyberFuchsia,
              ),
            ),
          ),
          const SizedBox(height: 12),
          LululuPress(
            onTap: claimable ? onClaim : () {},
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: claimable ? LululuGradients.fuchsiaToGold : null,
                color: claimable
                    ? null
                    : LululuColors.mutedTitanium.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                task.claimed
                    ? 'ALINDI'
                    : task.complete
                        ? 'ÖDÜLÜ AL'
                        : 'DEVAM EDİYOR',
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: claimable
                      ? LululuColors.paper
                      : LululuColors.mutedTitanium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
