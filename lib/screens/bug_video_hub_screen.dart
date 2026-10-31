import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../services/auth_service.dart';
import '../services/bug_video_service.dart';
import '../theme/lululu_theme.dart';
import '../widgets/dot_scaffold.dart';
import 'auth_screen.dart';

enum BugVideoTab { watch, create }

/// Böcek videosu izle / yap — herkese açık paylaş.
class BugVideoHubScreen extends StatefulWidget {
  const BugVideoHubScreen({super.key, this.initial = BugVideoTab.watch});

  final BugVideoTab initial;

  @override
  State<BugVideoHubScreen> createState() => _BugVideoHubScreenState();
}

class _BugVideoHubScreenState extends State<BugVideoHubScreen> {
  late BugVideoTab _tab;
  bool _loading = true;
  final _titleCtrl = TextEditingController();
  bool _sharePublic = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _tab = widget.initial;
    BugVideoService.instance.addListener(_refresh);
    _boot();
  }

  Future<void> _boot() async {
    await AuthService.instance.ensureLoaded();
    await BugVideoService.instance.ensureLoaded();
    if (mounted) setState(() => _loading = false);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    BugVideoService.instance.removeListener(_refresh);
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    setState(() => _status = null);
    if (!AuthService.instance.isSignedIn) {
      await AuthScreen.open(context);
      return;
    }
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      await BugVideoService.instance.addFromPicker(
        sourcePath: picked.path,
        title: _titleCtrl.text,
        isPublic: _sharePublic,
      );
      if (!mounted) return;
      setState(() {
        _status = _sharePublic
            ? 'Yüklendi · herkese açık'
            : 'Yüklendi · sadece sen';
        _tab = BugVideoTab.watch;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = BugVideoService.instance.publicFeed;
    final mine = BugVideoService.instance.mine();

    return DotScaffold(
      appBar: AppBar(
        title: Text(
          'Böcek Video',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabChip(
                          label: 'İZLE',
                          selected: _tab == BugVideoTab.watch,
                          onTap: () =>
                              setState(() => _tab = BugVideoTab.watch),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TabChip(
                          label: 'YAP / YÜKLE',
                          selected: _tab == BugVideoTab.create,
                          onTap: () =>
                              setState(() => _tab = BugVideoTab.create),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _status!,
                      style: GoogleFonts.exo2(
                        color: LululuColors.toxicNeon,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Expanded(
                  child: _tab == BugVideoTab.watch
                      ? _WatchPane(feed: feed, mine: mine)
                      : _CreatePane(
                          titleCtrl: _titleCtrl,
                          sharePublic: _sharePublic,
                          onTogglePublic: (v) =>
                              setState(() => _sharePublic = v),
                          onUpload: _pickAndUpload,
                        ),
                ),
              ],
            ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(LululuRadii.pill),
          gradient: selected ? LululuGradients.fuchsiaToGold : null,
          color: selected ? null : LululuColors.darkObsidian,
          border: Border.all(
            color: selected
                ? LululuColors.liquidGold
                : LululuColors.mutedTitanium.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w900,
            color: selected ? LululuColors.carbonVoid : LululuColors.ink,
          ),
        ),
      ),
    );
  }
}

class _CreatePane extends StatelessWidget {
  const _CreatePane({
    required this.titleCtrl,
    required this.sharePublic,
    required this.onTogglePublic,
    required this.onUpload,
  });

  final TextEditingController titleCtrl;
  final bool sharePublic;
  final ValueChanged<bool> onTogglePublic;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Böcek videosu yap',
          style: GoogleFonts.exo2(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: LululuColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Galeriden video seç. Herkese açık paylaşırsan feed’de görünür.',
          style: GoogleFonts.exo2(color: LululuColors.mutedTitanium),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: titleCtrl,
          style: const TextStyle(color: LululuColors.ink),
          decoration: InputDecoration(
            labelText: 'Başlık',
            labelStyle: const TextStyle(color: LululuColors.mutedTitanium),
            filled: true,
            fillColor: LululuColors.darkObsidian,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LululuRadii.pill),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: sharePublic,
          onChanged: onTogglePublic,
          activeThumbColor: LululuColors.toxicNeon,
          title: Text(
            'Herkese açık paylaş',
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w800,
              color: LululuColors.ink,
            ),
          ),
          subtitle: Text(
            sharePublic ? 'Feed’de herkes görür' : 'Sadece sende kalır',
            style: GoogleFonts.exo2(
              color: LululuColors.mutedTitanium,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.video_call_rounded),
            style: FilledButton.styleFrom(
              backgroundColor: LululuColors.cyberFuchsia,
              foregroundColor: LululuColors.ink,
            ),
            label: Text(
              'VİDEO SEÇ & YÜKLE',
              style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _WatchPane extends StatelessWidget {
  const _WatchPane({required this.feed, required this.mine});

  final List<BugVideoPost> feed;
  final List<BugVideoPost> mine;

  @override
  Widget build(BuildContext context) {
    if (feed.isEmpty && mine.isEmpty) {
      return Center(
        child: Text(
          'Henüz video yok.\nYAP sekmesinden yükle.',
          textAlign: TextAlign.center,
          style: GoogleFonts.exo2(color: LululuColors.mutedTitanium),
        ),
      );
    }

    final rows = <BugVideoPost>[
      ...feed,
      ...mine.where((m) => !m.isPublic),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: rows.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final post = rows[i];
        return _VideoCard(post: post);
      },
    );
  }
}

class _VideoCard extends StatefulWidget {
  const _VideoCard({required this.post});

  final BugVideoPost post;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.post.filePath))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LululuRadii.card),
        gradient: LululuGradients.navyToCarbon,
        border: Border.all(
          color: post.isPublic
              ? LululuColors.toxicNeon.withValues(alpha: 0.45)
              : LululuColors.darkObsidian,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.title,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w900,
                    color: LululuColors.ink,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: post.isPublic
                      ? LululuColors.toxicNeon.withValues(alpha: 0.15)
                      : LululuColors.darkObsidian,
                ),
                child: Text(
                  post.isPublic ? 'AÇIK' : 'GİZLİ',
                  style: GoogleFonts.exo2(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: post.isPublic
                        ? LululuColors.toxicNeon
                        : LululuColors.mutedTitanium,
                  ),
                ),
              ),
            ],
          ),
          Text(
            post.authorName,
            style: GoogleFonts.exo2(
              fontSize: 11,
              color: LululuColors.mutedTitanium,
            ),
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: _ready ? _ctrl!.value.aspectRatio : 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _ready
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_ctrl!),
                        IconButton(
                          iconSize: 48,
                          color: LululuColors.liquidGold,
                          onPressed: () {
                            setState(() {
                              if (_ctrl!.value.isPlaying) {
                                _ctrl!.pause();
                              } else {
                                _ctrl!.play();
                              }
                            });
                          },
                          icon: Icon(
                            _ctrl!.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                          ),
                        ),
                      ],
                    )
                  : const ColoredBox(
                      color: LululuColors.darkObsidian,
                      child: Center(child: CircularProgressIndicator()),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (post.authorId == AuthService.instance.playerId)
                TextButton(
                  onPressed: () => BugVideoService.instance
                      .setPublic(post.id, !post.isPublic),
                  child: Text(
                    post.isPublic ? 'Gizle' : 'Herkese aç',
                    style: GoogleFonts.exo2(
                      color: LululuColors.liquidGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(post.filePath)],
                      text: '${post.title} — Lülülü böcek videosu',
                    ),
                  );
                },
                icon: const Icon(Icons.ios_share_rounded,
                    color: LululuColors.cyberFuchsia),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
