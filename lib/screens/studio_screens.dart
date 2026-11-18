import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/audio_manager.dart';
import '../services/bug_video_service.dart';
import '../services/progress_manager.dart';
import '../widgets/home/lululu_dock_bar.dart';

/// Dile duyarlı büyük-harf dönüşümü.
///
/// TR locale'de Türkçe eşleme (i→İ, ı→I, ...) aynen korunur; EN locale'de
/// düz [String.toUpperCase] kullanılır, aksi hâlde EN metindeki `i`
/// yanlışlıkla `İ` olur. Bilinmeyen dillerde varsayılan TR'dir
/// ([AppLocalizations.localeResolutionCallback] ile aynı kural).
String _trUpper(String input, Locale locale) {
  if (locale.languageCode == 'en') {
    return input.toUpperCase();
  }
  return input
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .replaceAll('ğ', 'Ğ')
      .replaceAll('ü', 'Ü')
      .replaceAll('ş', 'Ş')
      .replaceAll('ö', 'Ö')
      .replaceAll('ç', 'Ç')
      .toUpperCase();
}

/// Stüdyo kartlarının tasarım genişliği üst sınırı (430px tasarımda 402px içerik).
const double _kStudioMaxWidth = 402.0;

/// Stüdyo listelerinin yatay dolgusu (sol 14 + sağ 14).
const double _kStudioHorizontalPadding = 28.0;

/// LayoutBuilder kısıtından türetilmiş stüdyo içerik genişliği:
/// dar ekranda kullanılabilir genişliğe iner, geniş ekranda 402px'te durur.
double _studioContentWidth(BoxConstraints constraints) {
  if (!constraints.maxWidth.isFinite) return _kStudioMaxWidth;
  final available = constraints.maxWidth - _kStudioHorizontalPadding;
  return math.min(_kStudioMaxWidth, math.max(0.0, available));
}

/// Tasarım genişliğine (402) göre oranlanmış genişlik.
double _studioScaled(double designWidth, double studioWidth) =>
    studioWidth * designWidth / _kStudioMaxWidth;

// ============================================================================
// 1. VİDEO İZLE (scr-studio-watch)
// ============================================================================
class StudioWatchScreen extends StatefulWidget {
  final bool showDock;
  final bool prototypeVisualState;
  const StudioWatchScreen({
    super.key,
    this.showDock = false,
    this.prototypeVisualState = true,
  });

  @override
  State<StudioWatchScreen> createState() => _StudioWatchScreenState();
}

class _StudioWatchScreenState extends State<StudioWatchScreen> {
  int _activeVideoIndex = 0;
  bool _isPlaying = false;
  int _likes = 1248;
  bool _liked = false;
  bool _likeBusy = false;
  bool _downloadBusy = false;

  final _videos = [
    {
      'id': 'viral_watch_0',
      'title': 'Böcek Birleştirme Rekoru! 51.200 Puan',
      'dur': '0:32',
      'viewsK': 128,
      'agoValue': 2,
      'agoUnit': 'day',
      'thumb': 'assets/design/ui/studio_watch/video_thumb_1.png',
      'likes': 1248,
    },
    {
      'id': 'viral_watch_1',
      'title': "Çığlık Böcek'te KAPI 7'ye Nasıl Geçilir?",
      'dur': '1:04',
      'viewsK': 86,
      'agoValue': 5,
      'agoUnit': 'day',
      'thumb': 'assets/design/ui/studio_watch/video_thumb_2.png',
      'likes': 942,
    },
    {
      'id': 'viral_watch_2',
      'title': 'Pembe Bornozlu İlk Kez Evrimleşti!',
      'dur': '0:47',
      'viewsK': 203,
      'agoValue': 1,
      'agoUnit': 'week',
      'thumb': 'assets/design/ui/studio_watch/video_thumb_3.png',
      'likes': 2317,
    },
    {
      'id': 'viral_watch_3',
      'title': 'Terlik Yağmuru: Kombo x12 Nasıl Yapılır?',
      'dur': '0:58',
      'viewsK': 57,
      'agoValue': 2,
      'agoUnit': 'week',
      'thumb': 'assets/design/ui/studio_watch/video_thumb_4.png',
      'likes': 618,
    },
  ];

  String _videoMeta(Map<String, Object> v) {
    final l10n = context.l10n;
    final ago = v['agoUnit'] == 'week'
        ? l10n.weeksAgo(v['agoValue'] as int)
        : l10n.daysAgo(v['agoValue'] as int);
    return '${l10n.videoViewsShort(v['viewsK'] as int)} · $ago';
  }

  String _formatCount(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}';
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleLikeCurrent() async {
    if (_likeBusy) return;
    _likeBusy = true;
    final cur = _videos[_activeVideoIndex];
    final id = cur['id'] as String? ?? 'viral_watch_$_activeVideoIndex';
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
      cur['likes'] = _likes;
    });
    unawaited(AudioManager().playButtonTap());
    var persisted = false;
    try {
      persisted = await BugVideoService.instance.toggleLike(id) != null;
    } catch (_) {
      persisted = false;
    }
    _likeBusy = false;
    if (!persisted) {
      // Kalıcı kayıt başarısız olduysa iyimser güncelleme geri alınır.
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likes += _liked ? 1 : -1;
          cur['likes'] = _likes;
        });
      }
      return;
    }
    try {
      await ProgressManager.instance.recordTaskProgress('video');
    } catch (_) {
      // İlerleme kaydı en iyi çabayla; beğeni sonucunu etkilemez.
    }
  }

  Future<void> _shareCurrent() async {
    unawaited(AudioManager().playButtonTap());
    unawaited(ProgressManager.instance.recordTaskProgress('video'));
    _toast(context.l10n.linkCopiedToast);
  }

  Future<void> _downloadCurrent() async {
    if (_downloadBusy) return;
    _downloadBusy = true;
    final cur = _videos[_activeVideoIndex];
    unawaited(AudioManager().playButtonTap());
    final post = BugVideoPost(
      id: cur['id'] as String? ?? 'viral_watch_$_activeVideoIndex',
      title: cur['title'] as String,
      authorName: 'Lülülü Stüdyo',
      authorId: 'studio_official',
      filePath: BugVideoService.rawTiktokVideoPaths[
          _activeVideoIndex % BugVideoService.rawTiktokVideoPaths.length],
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      isPublic: true,
      durationText: cur['dur'] as String,
      metaText: _videoMeta(cur),
      thumbnailAsset: cur['thumb'] as String,
      likes: _likes,
      likedByMe: _liked,
    );
    var succeeded = false;
    try {
      await BugVideoService.instance.downloadPost(post);
      succeeded = true;
    } catch (_) {
      succeeded = false;
    }
    _downloadBusy = false;
    if (!mounted) return;
    if (!succeeded) {
      _toast(context.l10n.errorGeneric);
      return;
    }
    try {
      await ProgressManager.instance.recordTaskProgress('video');
    } catch (_) {
      // İlerleme kaydı en iyi çabayla; indirme sonucunu etkilemez.
    }
    if (!mounted) return;
    _toast(context.l10n.videoAddedToDownloadsToast);
  }

  @override
  Widget build(BuildContext context) {
    final cur = _videos[_activeVideoIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(context, context.l10n.studioWatchTitle),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final studioWidth = _studioContentWidth(constraints);
                      return Center(
                        child: SizedBox(
                          width: studioWidth + _kStudioHorizontalPadding,
                          child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      12,
                      14,
                      widget.showDock ? 110 : 40,
                    ),
                    children: [
                      // Player (x: 14, y: 107.4, width: 402, height: 226.1)
                      _BlurredRRectShadow(
                        width: studioWidth,
                        height: studioWidth * 226.125 / _kStudioMaxWidth,
                        radius: 20,
                        offset: const Offset(0, 10),
                        sigma: 11,
                        color: const Color(0x40141B2A),
                        child: Container(
                          width: studioWidth,
                          height: studioWidth * 226.125 / _kStudioMaxWidth,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.92,
                                  child: Image.asset(
                                    'assets/design/ui/studio_watch/video_thumb_0.png',
                                    width: studioWidth,
                                    height: studioWidth * 226.125 / _kStudioMaxWidth,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) {
                                      // Sessiz boşluk yerine görünür yer tutucu + hata kaydı.
                                      if (kDebugMode) {
                                        debugPrint(
                                          '[Studio] Video küçük resmi yüklenemedi: assets/design/ui/studio_watch/video_thumb_0.png ($e)',
                                        );
                                      }
                                      return const ColoredBox(
                                        color: Color(0xFF1B2336),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // Big Play Button
                              Align(
                                alignment: Alignment.center,
                                child: Semantics(
                                  button: true,
                                  label: context.l10n.videoPlayPauseLabel(_isPlaying, cur['title'] as String),
                                  child: GestureDetector(
                                  onTap: () {
                                    setState(() => _isPlaying = !_isPlaying);
                                    unawaited(AudioManager().playButtonTap());
                                    unawaited(AudioManager().playPop());
                                    unawaited(
                                      ProgressManager.instance
                                          .recordTaskProgress('video'),
                                    );
                                  },
                                  child: _BlurredRRectShadow(
                                    width: 64,
                                    height: 64,
                                    radius: 32,
                                    offset: const Offset(0, 6),
                                    sigma: 8,
                                    color: const Color(0x66000000),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xF0E01E5A),
                                      ),
                                      alignment: Alignment.center,
                                      child: _isPlaying
                                          ? const Icon(
                                              Icons.pause_rounded,
                                              size: 30,
                                              color: Colors.white,
                                            )
                                          : const CustomPaint(
                                              size: Size(30, 30),
                                              painter: _PlayTrianglePainter(
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                )),
                              ),
                            // Player Bar (bottom: 0, height: 36)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 36,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  10,
                                ),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Color(0xB8000000),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
                                        child: Container(
                                          height: 7,
                                          color: const Color(0x4DFFFFFF),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              width: _isPlaying ? 120 : 0,
                                              color: const Color(0xFFFFB800),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '0:00 / ${cur['dur']}',
                                      style: GoogleFonts.nunito(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        height: 1.2,
                                        letterSpacing: 0.0,
                                        color: Colors.white,
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
                      const SizedBox(height: 12),

                      // Title & Meta
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: SizedBox(
                          height: 20.7,
                          child: Transform.translate(
                            offset: const Offset(0, 0.5),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                cur['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.baloo2(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  letterSpacing: 0.015,
                                  color: const Color(0xFF141B2A),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: SizedBox(
                          height: 19.4,
                          child: Transform.translate(
                            offset: const Offset(0, 0.1),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _videoMeta(cur),
                                style: GoogleFonts.nunito(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  letterSpacing: 0.0,
                                  color: const Color(0xFF66738A),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12.4),

                      // Actions (y: 399.6, height: 48)
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            // Like
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: context.l10n.likeLabel(_formatCount(_likes), _liked),
                                child: GestureDetector(
                                onTap: _toggleLikeCurrent,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x14141B2A),
                                        offset: Offset(0, 4),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CustomPaint(
                                        size: const Size(19, 19),
                                        painter: _HeartIconPainter(
                                          color: _liked
                                              ? const Color(0xFFE01E5A)
                                              : const Color(0xFF141B2A),
                                          filled: _liked,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatCount(_likes),
                                        style: GoogleFonts.nunito(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          height: 1.25,
                                          letterSpacing: -0.04,
                                          color: _liked
                                              ? const Color(0xFFE01E5A)
                                              : const Color(0xFF141B2A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                            ),
                            const SizedBox(width: 8),
                            // Share
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: context.l10n.shareLabel,
                                child: GestureDetector(
                                onTap: _shareCurrent,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x14141B2A),
                                        offset: Offset(0, 4),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const CustomPaint(
                                        size: Size(19, 19),
                                        painter: _ShareIconPainter(
                                          color: Color(0xFF141B2A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        context.l10n.shareLabel,
                                        style: GoogleFonts.nunito(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          height: 1.25,
                                          letterSpacing: -0.04,
                                          color: const Color(0xFF141B2A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                            ),
                            const SizedBox(width: 8),
                            // Download
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: context.l10n.downloadLabel,
                                child: GestureDetector(
                                onTap: _downloadCurrent,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x14141B2A),
                                        offset: Offset(0, 4),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const CustomPaint(
                                        size: Size(19, 19),
                                        painter: _DownloadIconPainter(
                                          color: Color(0xFF141B2A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        context.l10n.downloadLabel,
                                        style: GoogleFonts.nunito(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          height: 1.25,
                                          letterSpacing: -0.04,
                                          color: const Color(0xFF141B2A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 17.6),

                      // SIRADAKİ VİDEOLAR
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 2,
                          right: 2,
                          bottom: 8.9,
                        ),
                        child: SizedBox(
                          height: 16.5,
                          child: Transform.translate(
                            offset: const Offset(0, 0.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                context.l10n.upNextVideosTitle,
                                style: GoogleFonts.baloo2(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  height: 1.03,
                                  letterSpacing: 0.0,
                                  color: const Color(0xFF141B2A),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      for (int i = 0; i < _videos.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Semantics(
                            button: true,
                            label: context.l10n.playVideoLabel(_videos[i]['title'] as String, _videoMeta(_videos[i])),
                            selected: _activeVideoIndex == i,
                            child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeVideoIndex = i;
                                _likes = _videos[i]['likes'] as int;
                                _liked = false;
                                _isPlaying = true;
                              });
                              unawaited(AudioManager().playButtonTap());
                              unawaited(AudioManager().playPop());
                              unawaited(
                                ProgressManager.instance
                                    .recordTaskProgress('video'),
                              );
                            },
                            child: CustomPaint(
                              foregroundPainter: _activeVideoIndex == i
                                  ? const _OutlineRRectPainter(
                                      color: Color(0xFFE01E5A),
                                      strokeWidth: 2,
                                      radius: 18,
                                    )
                                  : null,
                              child: Container(
                                width: studioWidth,
                                height: i == 2 ? 98.0 : 99.0,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0F141B2A),
                                      offset: Offset(0, 4),
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    // Thumbnail: x=+9, y=+19, 104x60
                                    Positioned(
                                      left: _studioScaled(9, studioWidth),
                                      top: i == 1
                                          ? 20.0
                                          : (i == 2 ? 19.0 : 19.5),
                                      width: _studioScaled(104, studioWidth),
                                      height: _studioScaled(60, studioWidth),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                          children: [
                                            Image.asset(
                                              _videos[i]['thumb'] as String,
                                              width: _studioScaled(104, studioWidth),
                                              height: _studioScaled(60, studioWidth),
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, e, s) {
                                                // Sessiz boşluk yerine görünür yer tutucu + hata kaydı.
                                                if (kDebugMode) {
                                                  debugPrint(
                                                    '[Studio] Video küçük resmi yüklenemedi: ${_videos[i]['thumb']} ($e)',
                                                  );
                                                }
                                                return ColoredBox(
                                                  color: Color(0xFF1B2336),
                                                  child: SizedBox(
                                                    width: _studioScaled(104, studioWidth),
                                                    height: _studioScaled(60, studioWidth),
                                                  ),
                                                );
                                              },
                                            ),
                                            Positioned(
                                              right: 5,
                                              bottom: 5,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xC7000000),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  _videos[i]['dur'] as String,
                                                  style: GoogleFonts.nunito(
                                                    color: Colors.white,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w900,
                                                    height: 1.3,
                                                    letterSpacing: 0.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Title (h5): x=+124
                                    Positioned(
                                      left: _studioScaled(124, studioWidth),
                                      right: 6,
                                      top: i == 1
                                          ? 32.6
                                          : (i == 0
                                              ? 34.0
                                              : (i == 2 ? 33.8 : 33.5)),
                                      child: Text(
                                        _videos[i]['title'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.baloo2(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          height: 1.12,
                                          letterSpacing: 0.015,
                                          color: const Color(0xFF141B2A),
                                        ),
                                      ),
                                    ),
                                    // Meta (p): x=+124
                                    Positioned(
                                      left: _studioScaled(124, studioWidth),
                                      right: 9,
                                      top: i == 2 ? 73.2 : 73.7,
                                      child: Text(
                                        _videoMeta(_videos[i]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.nunito(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          height: 1.35,
                                          letterSpacing: 0.0,
                                          color: const Color(0xFF66738A),
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (widget.showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LululuDockBar(
                selected: LululuDockTab.home,
                onSelect: (_) {
                  unawaited(AudioManager().playButtonTap());
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. VİDEO YAP (scr-studio-create)
// ============================================================================
class StudioCreateScreen extends StatefulWidget {
  final bool showDock;
  final bool prototypeVisualState;
  const StudioCreateScreen({
    super.key,
    this.showDock = false,
    this.prototypeVisualState = true,
  });

  @override
  State<StudioCreateScreen> createState() => _StudioCreateScreenState();
}

class _StudioCreateScreenState extends State<StudioCreateScreen> {
  int _activeTab = 0; // 0: trim, 1: text, 2: sticker
  double _trimPercent = 62.0;
  String _caption = 'LÜLÜLÜ!';
  int _selectedSticker = 1;
  bool _saveBusy = false;
  final _textController = TextEditingController(text: 'LÜLÜLÜ!');

  final _stickers = [
    'assets/design/ui/studio_create/img_3.png',
    'assets/design/ui/studio_create/edSticker.png',
    'assets/design/ui/studio_create/img_5.png',
    'assets/design/ui/studio_create/img_6.png',
    'assets/design/ui/studio_create/img_7.png',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saveBusy) return;
    _saveBusy = true;
    unawaited(AudioManager().playButtonTap());
    var succeeded = false;
    try {
      await BugVideoService.instance.createSceneVideo(
        caption: _caption,
        trimPercent: _trimPercent,
        stickerIndex: _selectedSticker,
        stickerAsset: _stickers[_selectedSticker],
      );
      succeeded = true;
    } catch (_) {
      succeeded = false;
    }
    _saveBusy = false;
    if (!mounted) return;
    if (!succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.errorGeneric)),
      );
      return;
    }
    unawaited(AudioManager().playWin());
    try {
      await ProgressManager.instance.recordTaskProgress('video');
    } catch (_) {
      // İlerleme kaydı en iyi çabayla; kaydetme sonucunu etkilemez.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.draftSavedToast,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final endSec = (_trimPercent * 0.47).round().toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(context, context.l10n.studioCreateTitle),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final studioWidth = _studioContentWidth(constraints);
                      return Center(
                        child: SizedBox(
                          width: studioWidth + _kStudioHorizontalPadding,
                          child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      12,
                      14,
                      widget.showDock ? 110 : 40,
                    ),
                    children: [
                      // Editor Preview Box (402 x 301.5, y: 107.4..408.9)
                      Container(
                        width: studioWidth,
                        height: studioWidth * 301.5 / _kStudioMaxWidth,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2336),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x38141B2A),
                              blurRadius: 22,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/design/ui/studio_create/ebg.png',
                                width: studioWidth,
                                height: studioWidth * 301.5 / _kStudioMaxWidth,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) {
                                  // Sessiz boşluk yerine görünür yer tutucu + hata kaydı.
                                  if (kDebugMode) {
                                    debugPrint(
                                      '[Studio] Arka plan görseli yüklenemedi: assets/design/ui/studio_create/ebg.png ($e)',
                                    );
                                  }
                                  return const ColoredBox(
                                    color: Color(0xFF1B2336),
                                  );
                                },
                              ),
                            ),
                            // Sticker: sağ kenara 10px, dikeyde tasarım oranıyla
                            // (merkez 209.2/301.5 -> Alignment y ~0.39), boyut genişliğe oranlı.
                            Align(
                              alignment: const Alignment(1.0, 0.39),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: SizedBox(
                                  width: _studioScaled(104, studioWidth),
                                  height: _studioScaled(116.4, studioWidth),
                                  child: _DropShadowImage(
                                    assetPath: _stickers[_selectedSticker],
                                    width: _studioScaled(104, studioWidth),
                                    height: _studioScaled(116.4, studioWidth),
                                    shadowOffset: const Offset(0, 6),
                                    shadowBlur: 4,
                                    shadowColor: const Color(0x66000000),
                                  ),
                                ),
                              ),
                            ),
                            // Caption: bottom 10
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 10,
                              child: Text(
                                _caption,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.bangers(
                                  fontSize: 24,
                                  height: 1.125,
                                  letterSpacing: 0.8,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xE6080B12),
                                      offset: Offset(0, 2),
                                      blurRadius: 0,
                                    ),
                                    Shadow(
                                      color: Color(0xB3E01E5A),
                                      offset: Offset.zero,
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tools Tab Row (y: 420.9, height: 48)
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            _buildToolTab(0, context.l10n.studioToolTrim),
                            const SizedBox(width: 8),
                            _buildToolTab(1, context.l10n.studioToolText),
                            const SizedBox(width: 8),
                            _buildToolTab(2, context.l10n.studioToolSticker),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Panels
                      if (_activeTab == 0)
                        // Trim panel (y: 480.9, height: 209.9)
                        Container(
                          width: studioWidth,
                          height: 209.9,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12141B2A),
                                offset: Offset(0, 5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // h4 KLİBİ KIRP: top=39.1
                              Positioned(
                                left: 14,
                                top: 39.1,
                                child: Text(
                                  context.l10n.trimClipTitle,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    height: 1.03,
                                    letterSpacing: 0.1,
                                    color: const Color(0xFF141B2A),
                                  ),
                                ),
                              ),
                              // .timeline: top=66.6, width=374, height=34
                              Positioned(
                                left: 14,
                                top: 66.6,
                                width: studioWidth - _kStudioHorizontalPadding,
                                height: 34,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CustomPaint(
                                    painter: const _TimelineStripesPainter(),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: (studioWidth - _kStudioHorizontalPadding) * (_trimPercent / 100.0),
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: const Color(0x59E01E5A),
                                          border: Border.all(
                                            color: const Color(0xFFE01E5A),
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // .ed-range: top=112.6, width=374, height=34
                              Positioned(
                                left: 14,
                                top: 112.6,
                                width: studioWidth - _kStudioHorizontalPadding,
                                height: 34,
                                child: Semantics(
                                  slider: true,
                                  label: context.l10n.trimEndLabel,
                                  value: '0:00 – 0:$endSec',
                                  onIncrease: () => setState(() => _trimPercent = math.min(100.0, _trimPercent + 5.0)),
                                  onDecrease: () => setState(() => _trimPercent = math.max(20.0, _trimPercent - 5.0)),
                                  child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragUpdate: (d) {
                                    final localX = d.localPosition.dx.clamp(
                                      0.0,
                                      studioWidth - _kStudioHorizontalPadding,
                                    );
                                    final pct = 20.0 + (localX / (studioWidth - _kStudioHorizontalPadding)) * 80.0;
                                    setState(() => _trimPercent = pct);
                                  },
                                  onTapDown: (d) {
                                    unawaited(AudioManager().playButtonTap());
                                    final localX = d.localPosition.dx.clamp(
                                      0.0,
                                      studioWidth - _kStudioHorizontalPadding,
                                    );
                                    final pct = 20.0 + (localX / (studioWidth - _kStudioHorizontalPadding)) * 80.0;
                                    setState(() => _trimPercent = pct);
                                  },
                                  child: CustomPaint(
                                    size: Size(studioWidth - _kStudioHorizontalPadding, 34),
                                    painter: _HtmlRangeSliderPainter(
                                      value: _trimPercent,
                                      min: 20,
                                      max: 100,
                                    ),
                                  ),
                                )),
                              ),
                              // p.st-note: top=166.5
                              Positioned(
                                left: 14,
                                top: 166.5,
                                child: Text.rich(
                                  TextSpan(
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                      letterSpacing: -0.04,
                                      color: const Color(0xFF66738A),
                                    ),
                                    children: [
                                      TextSpan(text: context.l10n.selectedSectionPrefix),
                                      TextSpan(
                                        text: '0:00 – 0:$endSec',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          height: 1.35,
                                          letterSpacing: -0.04,
                                          color: const Color(0xFF66738A),
                                        ),
                                      ),
                                      TextSpan(text: context.l10n.totalDurationSuffix),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_activeTab == 1)
                        // Text panel
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 39.1, 14, 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12141B2A),
                                offset: Offset(0, 5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.addTextTitle,
                                style: GoogleFonts.baloo2(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.03,
                                  letterSpacing: 0.2,
                                  color: const Color(0xFF141B2A),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F8FC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE3E8F2),
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.centerLeft,
                                child: TextField(
                                  controller: _textController,
                                  maxLength: 24,
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF141B2A),
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    counterText: '',
                                    isDense: true,
                                    hintText: context.l10n.videoCaptionHint,
                                  ),
                                  onChanged: (v) => setState(
                                    () => _caption = v.isEmpty ? 'LÜLÜLÜ!' : v,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.captionPreviewNote,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF66738A),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // Sticker panel
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 39.1, 14, 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12141B2A),
                                offset: Offset(0, 5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.chooseStickerTitle,
                                style: GoogleFonts.baloo2(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.03,
                                  letterSpacing: 0.2,
                                  color: const Color(0xFF141B2A),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  for (int i = 0; i < _stickers.length; i++)
                                    Semantics(
                                      button: true,
                                      label: context.l10n.stickerLabel(i + 1),
                                      selected: _selectedSticker == i,
                                      child: GestureDetector(
                                      onTap: () {
                                        unawaited(
                                          AudioManager().playButtonTap(),
                                        );
                                        unawaited(
                                          AudioManager().playTierVoice(
                                            (i + 1).clamp(1, 8),
                                          ),
                                        );
                                        setState(() => _selectedSticker = i);
                                      },
                                      child: Container(
                                        width: 68,
                                        height: 62,
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: _selectedSticker == i
                                              ? const Color(0xFFFFE4EE)
                                              : const Color(0xFFF1F4FA),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: _selectedSticker == i
                                                ? const Color(0xFFE01E5A)
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Image.asset(
                                          _stickers[i],
                                          fit: BoxFit.contain,
                                          errorBuilder: (c, e, s) {
                                            // Sessiz boşluk yerine görünür yer tutucu + hata kaydı.
                                            if (kDebugMode) {
                                              debugPrint(
                                                '[Studio] Çıkartma görseli yüklenemedi: ${_stickers[i]} ($e)',
                                              );
                                            }
                                            return const Icon(
                                              Icons.image_not_supported_outlined,
                                              color: Color(0xFF66738A),
                                            );
                                          },
                                        ),
                                      ),
                                    )),
                                ],
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),
                      // Save Button (#edSave, y: 702.8, height: 52)
                      Semantics(
                        button: true,
                        label: context.l10n.saveAndPreviewLabel,
                        child: GestureDetector(
                        onTap: _save,
                        child: Container(
                          width: studioWidth,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF37E08B),
                                Color(0xFF12B76A),
                                Color(0xFF0A9553),
                              ],
                              stops: [0.0, 0.55, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x47000000),
                                offset: Offset(0, 10),
                                blurRadius: 18,
                              ),
                              BoxShadow(
                                color: Color(0xFF066C3C),
                                offset: Offset(0, 5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            context.l10n.saveAndPreviewButton,
                            style: GoogleFonts.baloo2(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              letterSpacing: 0.36,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )),
                      const SizedBox(height: 10),
                      // Bottom note (y: 763.8)
                      Text(
                        context.l10n.draftShareableNote,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          letterSpacing: -0.04,
                          color: const Color(0xFF66738A),
                        ),
                      ),
                    ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (widget.showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LululuDockBar(
                selected: LululuDockTab.home,
                onSelect: (_) {
                  unawaited(AudioManager().playButtonTap());
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolTab(int index, String label) {
    final active = _activeTab == index;
    final fg = active ? const Color(0xFF4A2E00) : const Color(0xFF141B2A);
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: active,
        child: GestureDetector(
        onTap: () {
          unawaited(AudioManager().playButtonTap());
          setState(() => _activeTab = index);
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFB800) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: active
                    ? const Color(0xFFB97A00)
                    : const Color(0x14141B2A),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                size: const Size(18, 18),
                painter: _ToolIconPainter(index: index, color: fg),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

// ============================================================================
// 3. YÜKLE (scr-studio-upload)
// ============================================================================
class StudioUploadScreen extends StatefulWidget {
  final bool showDock;
  final bool prototypeVisualState;
  const StudioUploadScreen({
    super.key,
    this.showDock = false,
    this.prototypeVisualState = true,
  });

  @override
  State<StudioUploadScreen> createState() => _StudioUploadScreenState();
}

class _StudioUploadScreenState extends State<StudioUploadScreen> {
  final _titleCtrl = TextEditingController();
  bool _hasSelectedFile = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _pickFile() {
    unawaited(AudioManager().playButtonTap());
    setState(() {
      _hasSelectedFile = true;
      if (_titleCtrl.text.isEmpty) {
        _titleCtrl.text = context.l10n.uploadDefaultTitle;
      }
    });
    unawaited(AudioManager().playPop());
  }

  void _startUpload() {
    unawaited(AudioManager().playButtonTap());
    if (!_hasSelectedFile) return;
    unawaited(AudioManager().playWin());
    unawaited(
      BugVideoService.instance.uploadCustomVideo(
        title: _titleCtrl.text,
      ),
    );
    unawaited(ProgressManager.instance.recordTaskProgress('video'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.videoUploadedSnack)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(context, context.l10n.studioUploadTitle),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final studioWidth = _studioContentWidth(constraints);
                      return Center(
                        child: SizedBox(
                          width: studioWidth + _kStudioHorizontalPadding,
                          child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      12,
                      14,
                      widget.showDock ? 110 : 40,
                    ),
                    children: [
                      // Dropzone Card (x: 14, y: 107.4, width: 402, height: 127)
                      Semantics(
                        button: true,
                        label: context.l10n.chooseFileLabel,
                        child: GestureDetector(
                        onTap: _pickFile,
                        child: CustomPaint(
                          foregroundPainter: const _DashedRRectPainter(
                            color: Color(0xFFB9C6DC),
                            strokeWidth: 3,
                            radius: 20,
                          ),
                          child: Container(
                            width: studioWidth,
                            height: 127,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F8FC),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                // SVG icon: top=19, 36x36
                                const Positioned(
                                  top: 19,
                                  width: 36,
                                  height: 36,
                                  child: CustomPaint(
                                    size: Size(36, 36),
                                    painter: _UploadCloudArrowPainter(
                                      color: Color(0xFFE01E5A),
                                    ),
                                  ),
                                ),
                                // b DOSYA SEÇ: top=63
                                Positioned(
                                  top: 63,
                                  child: Text(
                                    context.l10n.chooseFileButton,
                                    style: GoogleFonts.baloo2(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      height: 1.35,
                                      letterSpacing: -0.1,
                                      color: const Color(0xFF141B2A),
                                    ),
                                  ),
                                ),
                                // span MP4 veya MOV · en fazla 500 MB: top=93
                                Positioned(
                                  top: 93,
                                  child: Text(
                                    context.l10n.fileConstraintsNote,
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                      letterSpacing: -0.18,
                                      color: const Color(0xFF66738A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                      const SizedBox(height: 12),

                      // Title Card (x: 14, y: 246.4, width: 402, height: 128.6)
                      Container(
                        width: studioWidth,
                        height: 128.6,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12141B2A),
                              offset: Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // h4 VİDEO BAŞLIĞI: top=39.1
                            Positioned(
                              left: 14,
                              top: 39.1,
                              child: Text(
                                context.l10n.videoTitleLabel,
                                style: GoogleFonts.baloo2(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.03,
                                  letterSpacing: 0.2,
                                  color: const Color(0xFF141B2A),
                                ),
                              ),
                            ),
                            // input #upTitle: top=66.6, width=374, height=48
                            Positioned(
                              left: 14,
                              top: 66.6,
                              width: studioWidth - _kStudioHorizontalPadding,
                              height: 48,
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F8FC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE3E8F2),
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.centerLeft,
                                child: TextField(
                                  controller: _titleCtrl,
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.18,
                                    color: const Color(0xFF141B2A),
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: context.l10n.videoTitleHint,
                                    hintStyle: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.18,
                                      color: const Color(0xFF757575),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Start Upload Button (#upStart, y: 387, width: 402, height: 52)
                      Semantics(
                        button: true,
                        label: context.l10n.startUploadLabel,
                        enabled: _hasSelectedFile,
                        child: GestureDetector(
                        onTap: _startUpload,
                        child: Opacity(
                          opacity: _hasSelectedFile ? 1.0 : 0.45,
                          child: Container(
                            width: studioWidth,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFFFCF3F),
                                  Color(0xFFFFB800),
                                  Color(0xFFFF8A00),
                                ],
                                stops: [0.0, 0.55, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x47000000),
                                  offset: Offset(0, 10),
                                  blurRadius: 18,
                                ),
                                BoxShadow(
                                  color: Color(0xFFB97A00),
                                  offset: Offset(0, 5),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              context.l10n.startUploadButton,
                              style: GoogleFonts.baloo2(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                letterSpacing: 0.36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )),
                    ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (widget.showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LululuDockBar(
                selected: LululuDockTab.home,
                onSelect: (_) {
                  unawaited(AudioManager().playButtonTap());
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. GIF OLUŞTUR (scr-studio-gif)
// ============================================================================
class StudioGifScreen extends StatefulWidget {
  final bool showDock;
  final bool prototypeVisualState;
  const StudioGifScreen({
    super.key,
    this.showDock = false,
    this.prototypeVisualState = true,
  });

  @override
  State<StudioGifScreen> createState() => _StudioGifScreenState();
}

class _StudioGifScreenState extends State<StudioGifScreen> {
  final Set<int> _selectedFrames = {0, 1};
  int _activePreviewFrame = 0; // Frame 0 (Pijamalı Dansçı, gifImg.png) matches reference-studio-gif.png
  int _selectedSpeed = 1; // 1: NORMAL is active (.on) in reference spec
  late final TextEditingController _captionCtrl;
  bool _captionInitialized = false;
  bool _generateBusy = false;

  final _frameAssets = [
    'assets/design/ui/studio_gif/gifImg.png',
    'assets/design/ui/studio_gif/img_3.png',
    'assets/design/ui/studio_gif/img_4.png',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_captionInitialized) {
      _captionCtrl = TextEditingController(
        text: context.l10n.gifDefaultCaption,
      );
      _captionInitialized = true;
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_generateBusy) return;
    _generateBusy = true;
    unawaited(AudioManager().playButtonTap());
    var succeeded = false;
    try {
      await BugVideoService.instance.createAnimatedGif(
        caption: _captionCtrl.text,
        selectedFrames: _selectedFrames,
        speedIndex: _selectedSpeed,
      );
      succeeded = true;
    } catch (_) {
      succeeded = false;
    }
    _generateBusy = false;
    if (!mounted) return;
    if (!succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.errorGeneric)),
      );
      return;
    }
    unawaited(AudioManager().playWin());
    try {
      await ProgressManager.instance.recordTaskProgress('video');
    } catch (_) {
      // İlerleme kaydı en iyi çabayla; GIF sonucunu etkilemez.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.gifCreatedSnack)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(context, context.l10n.studioGifTitle),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final studioWidth = _studioContentWidth(constraints);
                      return Center(
                        child: SizedBox(
                          width: studioWidth + _kStudioHorizontalPadding,
                          child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      12,
                      14,
                      widget.showDock ? 110 : 40,
                    ),
                    children: [
                      // GIF Preview Box (x: 14, y: 107.4, width: 402, height: 300)
                      Container(
                        width: studioWidth,
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            begin: Alignment(-0.34, -0.94),
                            end: Alignment(0.34, 0.94),
                            colors: [Color(0xFFFFE9A8), Color(0xFFFFC7DE)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x2E141B2A),
                              offset: Offset(0, 10),
                              blurRadius: 13,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // .gif-badge: left 10, top 10
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xD9080B12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'GIF',
                                  style: GoogleFonts.baloo2(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    height: 1.55,
                                    letterSpacing: 1.44,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            // #gifImg: width 72% (289.4), height 251.6, centered at (56.3, 35.5)
                            Positioned(
                              left: _studioScaled(56.3, studioWidth),
                              top: 35.5,
                              width: _studioScaled(289.4, studioWidth),
                              height: 251.6,
                              child: _DropShadowImage(
                                assetPath: _frameAssets[_activePreviewFrame],
                                width: _studioScaled(289.4, studioWidth),
                                height: 251.6,
                                shadowOffset: const Offset(0, 10),
                                shadowBlur: 7,
                                shadowColor: const Color(0x4D000000),
                              ),
                            ),
                            // #gifCap: bottom 12
                            Positioned(
                              left: 10,
                              right: 10,
                              bottom: 12,
                              child: Text(
                                _captionCtrl.text.isEmpty
                                    ? context.l10n.gifDefaultCaption
                                    : _captionCtrl.text,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.bangers(
                                  fontSize: 23,
                                  height: 1.55,
                                  letterSpacing: 0.8,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xE6080B12),
                                      offset: Offset(0, 2),
                                      blurRadius: 0,
                                    ),
                                    Shadow(
                                      color: Color(0xCC12B76A),
                                      offset: Offset.zero,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Frames Card (y: 419.4, width: 402, height: 196.2)
                      Container(
                        width: studioWidth,
                        height: 196.2,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12141B2A),
                              offset: Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // h4 KARELERİ SEÇ: top=39.1
                            Positioned(
                              left: 14,
                              top: 39.1,
                              child: Text(
                                context.l10n.chooseFramesTitle,
                                style: GoogleFonts.baloo2(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.03,
                                  letterSpacing: 0.0,
                                  color: const Color(0xFF141B2A),
                                ),
                              ),
                            ),
                            // .frame-row: top=66.6, width=374, height=77
                            Positioned(
                              left: 14,
                              top: 66.6,
                              width: studioWidth - _kStudioHorizontalPadding,
                              height: 77,
                              child: Row(
                                children: [
                                  _buildFrameBtn(
                                    0,
                                    'Pijamalı Dansçı',
                                    'assets/design/ui/studio_gif/img_2.png',
                                  ),
                                  const SizedBox(width: 9),
                                  _buildFrameBtn(
                                    1,
                                    'Hamam Diva',
                                    'assets/design/ui/studio_gif/img_3.png',
                                  ),
                                  const SizedBox(width: 9),
                                  _buildFrameBtn(
                                    2,
                                    'Kongo Lideri',
                                    'assets/design/ui/studio_gif/img_4.png',
                                  ),
                                ],
                              ),
                            ),
                            // p.st-note: top=152.2
                            Positioned(
                              left: 14,
                              top: 152.2,
                              child: Text(
                                context.l10n.selectedFramesNote,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                  letterSpacing: -0.04,
                                  color: const Color(0xFF66738A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Text & Speed Card (y: 627.6, width: 402, height: 186.6)
                      Container(
                        width: studioWidth,
                        height: 186.6,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12141B2A),
                              offset: Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // h4 METİN & HIZ: top=39.1
                            Positioned(
                              left: 14,
                              top: 39.1,
                              child: Text(
                                context.l10n.textAndSpeedTitle,
                                style: GoogleFonts.baloo2(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.03,
                                  letterSpacing: 0.0,
                                  color: const Color(0xFF141B2A),
                                ),
                              ),
                            ),
                            // input #gifText: top=66.6, width=374, height=48
                            Positioned(
                              left: 14,
                              top: 66.6,
                              width: studioWidth - _kStudioHorizontalPadding,
                              height: 48,
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F8FC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE3E8F2),
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.centerLeft,
                                child: TextField(
                                  controller: _captionCtrl,
                                  onChanged: (_) => setState(() {}),
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.02,
                                    color: const Color(0xFF141B2A),
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ),
                            // .speed-row: top=124.6, width=374, height=48
                            Positioned(
                              left: 14,
                              top: 124.6,
                              width: studioWidth - _kStudioHorizontalPadding,
                              height: 48,
                              child: Row(
                                children: [
                                  _buildSpeedBtn(0, context.l10n.speedSlow),
                                  const SizedBox(width: 8),
                                  _buildSpeedBtn(1, context.l10n.speedNormal),
                                  const SizedBox(width: 8),
                                  _buildSpeedBtn(2, context.l10n.speedFast),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Generate Button (#gifMake, y: 826.2, width: 402, height: 52)
                      Semantics(
                        button: true,
                        label: context.l10n.createGifLabel,
                        child: GestureDetector(
                        onTap: _generate,
                        child: Container(
                          width: studioWidth,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFF4538B),
                                Color(0xFFE01E5A),
                                Color(0xFFB80F42),
                              ],
                              stops: [0.0, 0.55, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x47000000),
                                offset: Offset(0, 10),
                                blurRadius: 18,
                              ),
                              BoxShadow(
                                color: Color(0xFF7E0A2E),
                                offset: Offset(0, 5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            context.l10n.studioGifTitle,
                            style: GoogleFonts.baloo2(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              color: Colors.white,
                              letterSpacing: 0.36,
                            ),
                          ),
                        ),
                      )),
                    ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (widget.showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LululuDockBar(
                selected: LululuDockTab.home,
                onSelect: (_) {
                  unawaited(AudioManager().playButtonTap());
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFrameBtn(int index, String label, String imagePath) {
    final on = _selectedFrames.contains(index);
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: on,
        child: GestureDetector(
        onTap: () {
          unawaited(AudioManager().playButtonTap());
          setState(() {
            if (on) {
              if (_selectedFrames.length > 1) _selectedFrames.remove(index);
            } else {
              _selectedFrames.add(index);
            }
            _activePreviewFrame = index;
          });
        },
        child: Container(
          height: 77,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFE4F8EE) : const Color(0xFFF1F4FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on ? const Color(0xFF12B76A) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                imagePath,
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) {
                  // Sessiz boşluk yerine görünür yer tutucu + hata kaydı.
                  if (kDebugMode) {
                    debugPrint(
                      '[Studio] Seçenek görseli yüklenemedi: $imagePath ($e)',
                    );
                  }
                  return const Icon(
                    Icons.image_not_supported_outlined,
                    size: 32,
                    color: Color(0xFF66738A),
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                  letterSpacing: -0.15,
                  color: const Color(0xFF66738A),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildSpeedBtn(int index, String label) {
    final on = _selectedSpeed == index;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: on,
        child: GestureDetector(
        onTap: () {
          unawaited(AudioManager().playButtonTap());
          setState(() {
            _selectedSpeed = index;
            if (_selectedFrames.isNotEmpty) {
              final frames = _selectedFrames.toList()..sort();
              final pos = frames.indexOf(_activePreviewFrame);
              _activePreviewFrame = frames[(pos + 1) % frames.length];
            }
          });
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: on ? const Color(0xFF12B76A) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: on
                    ? const Color(0xFF066C3C)
                    : const Color(0x14141B2A),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.baloo2(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: on ? Colors.white : const Color(0xFF141B2A),
            ),
          ),
        ),
      )),
    );
  }
}

// ============================================================================
// 5. İNDİRİLENLER (scr-studio-downloads)
// ============================================================================
class StudioDownloadsScreen extends StatefulWidget {
  final bool showDock;
  final bool prototypeVisualState;
  const StudioDownloadsScreen({
    super.key,
    this.showDock = false,
    this.prototypeVisualState = true,
  });

  @override
  State<StudioDownloadsScreen> createState() => _StudioDownloadsScreenState();
}

class _StudioDownloadsScreenState extends State<StudioDownloadsScreen> {
  bool _deleteBusy = false;
  final _downloads = [
    {
      'title': 'birlesme_rekoru.mp4',
      'size': '84,2 MB',
      'sizeMb': 84.2,
      'whenKind': 'today',
      'whenTime': '09:12',
      'thumb': 'assets/design/ui/studio_downloads/img_1.png',
      'isBug': false,
    },
    {
      'title': 'kapi7_rehberi.mp4',
      'size': '156,8 MB',
      'sizeMb': 156.8,
      'whenKind': 'yesterday',
      'whenTime': '21:40',
      'thumb': 'assets/design/ui/studio_downloads/img_2.png',
      'isBug': false,
    },
    {
      'title': 'dans_zamani.gif',
      'size': '6,4 MB',
      'sizeMb': 6.4,
      'whenKind': 'date',
      'whenDay': 28,
      'whenMonth': 10,
      'thumb': 'assets/design/ui/studio_downloads/bugimg.png',
      'isBug': true,
    },
    {
      'title': 'hamam_diva_klip.mp4',
      'size': '42,1 MB',
      'sizeMb': 42.1,
      'whenKind': 'date',
      'whenDay': 25,
      'whenMonth': 10,
      'thumb': 'assets/design/ui/studio_downloads/img_4.png',
      'isBug': false,
    },
  ];

  String _whenText(Map<String, Object> d) {
    final l10n = context.l10n;
    final kind = d['whenKind'] as String;
    if (kind == 'today') return l10n.downloadedTodayAt(d['whenTime'] as String);
    if (kind == 'yesterday') {
      return l10n.downloadedYesterdayAt(d['whenTime'] as String);
    }
    return l10n.downloadedDayMonth(
      d['whenDay'] as int,
      l10n.monthFullName(d['whenMonth'] as int),
    );
  }

  /// Özet satırındaki toplam boyut, listedeki dosyaların boyutlarının
  /// toplamıdır (sabit "1,21 GB" yazısı liste toplamı ~290 MB ile
  /// çelişiyordu, bulgu #8). Silme sonrası da güncel kalır.
  String _totalSizeText() {
    var totalMb = 0.0;
    for (final d in _downloads) {
      totalMb += (d['sizeMb'] as num?)?.toDouble() ?? 0.0;
    }
    if (totalMb >= 1024) {
      final gb = (totalMb / 1024).toStringAsFixed(2).replaceAll('.', ',');
      return '$gb GB';
    }
    return '${totalMb.toStringAsFixed(1).replaceAll('.', ',')} MB';
  }

  Future<void> _delete(int index) async {
    if (_deleteBusy) return;
    if (index < 0 || index >= _downloads.length) return;
    _deleteBusy = true;
    unawaited(AudioManager().playButtonTap());
    final item = _downloads[index];
    var removed = false;
    try {
      removed = await BugVideoService.instance.removeDownloadAt(index) != null;
    } catch (_) {
      removed = false;
    }
    _deleteBusy = false;
    if (!mounted) return;
    if (!removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.errorGeneric)),
      );
      return;
    }
    setState(() => _downloads.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.deletedItemSnack(item['title'] as String))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(context, context.l10n.studioDownloadsTitle),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final studioWidth = _studioContentWidth(constraints);
                      return Center(
                        child: SizedBox(
                          width: studioWidth + _kStudioHorizontalPadding,
                          child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      12,
                      14,
                      widget.showDock ? 110 : 40,
                    ),
                    children: [
                      // Storage card (x: 14, y: 107.4, width: 402, height: 137.2)
                      Container(
                        width: studioWidth,
                        height: 137.2,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12141B2A),
                              offset: Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // h4 DEPOLAMA: top=39.1
                            Positioned(
                              left: 14,
                              top: 39.1,
                              child: Text(
                                context.l10n.storageTitle,
                                style: GoogleFonts.baloo2(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF141B2A),
                                  height: 1.03,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                            // .bar: top=66.6, width=374, height=14
                            Positioned(
                              left: 14,
                              top: 66.6,
                              width: studioWidth - _kStudioHorizontalPadding,
                              height: 14,
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3E8F2),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: (studioWidth - _kStudioHorizontalPadding) * 113.2 / 374.0,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFB800),
                                          Color(0xFFFF6B35),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // p.st-note: top=93.8
                            Positioned(
                              left: 14,
                              top: 93.8,
                              child: Text.rich(
                                TextSpan(
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF66738A),
                                    height: 1.35,
                                    letterSpacing: -0.04,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _totalSizeText(),
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF66738A),
                                        height: 1.35,
                                        letterSpacing: -0.04,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          context.l10n.storageUsedSuffix(_downloads.length),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      for (int i = 0; i < _downloads.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Container(
                            width: studioWidth,
                            height: 66,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0F141B2A),
                                  offset: Offset(0, 4),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(11),
                                    color: const Color(0xFFF1F4FA),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  alignment: Alignment.center,
                                  child: Image.asset(
                                    _downloads[i]['thumb'] as String,
                                    width: (_downloads[i]['isBug'] as bool)
                                        ? 42
                                        : 64,
                                    height: (_downloads[i]['isBug'] as bool)
                                        ? 42
                                        : 48,
                                    fit: (_downloads[i]['isBug'] as bool)
                                        ? BoxFit.contain
                                        : BoxFit.fitWidth,
                                    alignment: (_downloads[i]['isBug'] as bool)
                                        ? Alignment.center
                                        : Alignment.topCenter,
                                    errorBuilder: (c, e, s) {
                                      // Sessiz boşluk yerine görünür yer tutucu + hata kaydı.
                                      if (kDebugMode) {
                                        debugPrint(
                                          '[Studio] İndirilen görsel yüklenemedi: ${_downloads[i]['thumb']} ($e)',
                                        );
                                      }
                                      return const Icon(Icons.movie_rounded);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Transform.translate(
                                    offset: const Offset(0, -3.5),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _downloads[i]['title'] as String,
                                          style: GoogleFonts.nunito(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF66738A),
                                            letterSpacing: -0.05,
                                            height: 1.25,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${_downloads[i]['size'] as String} · ${_whenText(_downloads[i])}',
                                          style: GoogleFonts.nunito(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF66738A),
                                            letterSpacing: -0.04,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Semantics(
                                      button: true,
                                      label: context.l10n.playItemLabel(_downloads[i]['title'] as String),
                                      child: GestureDetector(
                                      onTap: () {
                                        unawaited(
                                          AudioManager().playButtonTap(),
                                        );
                                        unawaited(AudioManager().playPop());
                                        unawaited(
                                          ProgressManager.instance
                                              .recordTaskProgress('video'),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              context.l10n.nowPlayingLabel(_downloads[i]['title'] as String),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        alignment: Alignment.center,
                                        child: const CustomPaint(
                                          size: Size(18, 18),
                                          painter: _PlayTrianglePainter(
                                            color: Color(0xFF141B2A),
                                          ),
                                        ),
                                      ),
                                    )),
                                    Semantics(
                                      button: true,
                                      label: context.l10n.deleteItemLabel(_downloads[i]['title'] as String),
                                      child: GestureDetector(
                                      onTap: () => _delete(i),
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        alignment: Alignment.center,
                                        child: const CustomPaint(
                                          size: Size(18, 18),
                                          painter: _TrashIconPainter(
                                            color: Color(0xFFC2274B),
                                          ),
                                        ),
                                      ),
                                    )),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (widget.showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LululuDockBar(
                selected: LululuDockTab.home,
                onSelect: (_) {
                  unawaited(AudioManager().playButtonTap());
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Ortak App Bar ────────────────────────────────────────────────────────────
Widget _buildAppBar(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(14, 9, 14, 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: context.l10n.goBackLabel,
          child: GestureDetector(
          onTap: () {
            unawaited(AudioManager().playButtonTap());
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
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
              'assets/design/ui/back_btn.png',
              width: 29,
              height: 29,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) {
                // Sessiz boşluk yerine görünür yer tutucu + hata kaydı.
                if (kDebugMode) {
                  debugPrint(
                    '[Studio] Geri düğmesi görseli yüklenemedi: assets/design/ui/back_btn.png ($e)',
                  );
                }
                return const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: Color(0xFF141B2A),
                );
              },
            ),
          ),
        )),
        const SizedBox(width: 10),
        Transform.translate(
          offset: const Offset(0, 1.3),
          child: Text(
            _trUpper(title, Localizations.localeOf(context)),
            style: GoogleFonts.baloo2(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              height: 1.03,
              letterSpacing: -0.02,
              color: const Color(0xFF141B2A),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Yardımcı Görsel & SVG Çiziciler ──────────────────────────────────────────

class _DropShadowImage extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final Offset shadowOffset;
  final double shadowBlur;
  final Color shadowColor;

  const _DropShadowImage({
    required this.assetPath,
    required this.width,
    required this.height,
    required this.shadowOffset,
    required this.shadowBlur,
    required this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: shadowOffset.dx,
          top: shadowOffset.dy,
          width: width,
          height: height,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: shadowBlur,
              sigmaY: shadowBlur,
            ),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(shadowColor, BlendMode.srcIn),
              child: Image.asset(
                assetPath,
                width: width,
                height: height,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) {
                  // Gölge kopya: görünür yer tutucu ana görselde;
                  // burada yalnızca hata kaydı + boyut koruyan saydam kutu.
                  if (kDebugMode) {
                    debugPrint(
                      '[_DropShadowImage] Gölge görseli yüklenemedi: $assetPath ($e)',
                    );
                  }
                  return Container(width: width, height: height);
                },
              ),
            ),
          ),
        ),
        Image.asset(
          assetPath,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (c, error, s) {
            // Sessiz boşluk yerine görünür yer tutucu + hata kaydı.
            if (kDebugMode) {
              debugPrint(
                '[_DropShadowImage] Görsel yüklenemedi: $assetPath ($error)',
              );
            }
            return Container(
              width: width,
              height: height,
              color: const Color(0xFFF1F4FA),
              alignment: Alignment.center,
              child: Icon(
                Icons.image_not_supported_outlined,
                size: math.min(
                  48.0,
                  math.max(24.0, math.min(width, height) * 0.4),
                ),
                color: const Color(0xFF66738A),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PlayTrianglePainter extends CustomPainter {
  final Color color;
  const _PlayTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;
    final path = Path()
      ..moveTo(8 * sx, 5.5 * sy)
      ..lineTo(8 * sx, 18.5 * sy)
      ..lineTo(19 * sx, 12.0 * sy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _PlayTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TrashIconPainter extends CustomPainter {
  final Color color;
  const _TrashIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // M4 7h16
    canvas.drawLine(Offset(4 * s, 7 * s), Offset(20 * s, 7 * s), paint);
    // M9.5 7V5a1.5 1.5 0 0 1 1.5-1.5h2A1.5 1.5 0 0 1 14.5 5v2
    final handle = Path()
      ..moveTo(9.5 * s, 7 * s)
      ..lineTo(9.5 * s, 5 * s)
      ..arcToPoint(
        Offset(11 * s, 3.5 * s),
        radius: Radius.circular(1.5 * s),
      )
      ..lineTo(13 * s, 3.5 * s)
      ..arcToPoint(
        Offset(14.5 * s, 5 * s),
        radius: Radius.circular(1.5 * s),
      )
      ..lineTo(14.5 * s, 7 * s);
    canvas.drawPath(handle, paint);
    // M6.5 7l1 12a1.5 1.5 0 0 0 1.5 1.4h6A1.5 1.5 0 0 0 16.5 19l1-12
    final body = Path()
      ..moveTo(6.5 * s, 7 * s)
      ..lineTo(7.5 * s, 19 * s)
      ..arcToPoint(
        Offset(9 * s, 20.4 * s),
        radius: Radius.circular(1.5 * s),
        clockwise: false,
      )
      ..lineTo(15 * s, 20.4 * s)
      ..arcToPoint(
        Offset(16.5 * s, 19 * s),
        radius: Radius.circular(1.5 * s),
        clockwise: false,
      )
      ..lineTo(17.5 * s, 7 * s);
    canvas.drawPath(body, paint);
  }

  @override
  bool shouldRepaint(covariant _TrashIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HeartIconPainter extends CustomPainter {
  final Color color;
  final bool filled;
  const _HeartIconPainter({required this.color, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final path = Path()
      ..moveTo(12 * s, 20.5 * s)
      ..cubicTo(12 * s, 20.5 * s, 4 * s, 15.2 * s, 4 * s, 9.2 * s)
      ..cubicTo(4 * s, 6.4 * s, 6.2 * s, 4.5 * s, 8.6 * s, 4.5 * s)
      ..cubicTo(10.3 * s, 4.5 * s, 11.5 * s, 5.4 * s, 12 * s, 6.6 * s)
      ..cubicTo(12.5 * s, 5.4 * s, 13.7 * s, 4.5 * s, 15.4 * s, 4.5 * s)
      ..cubicTo(17.8 * s, 4.5 * s, 20 * s, 6.4 * s, 20 * s, 9.2 * s)
      ..cubicTo(20 * s, 15.2 * s, 12 * s, 20.5 * s, 12 * s, 20.5 * s)
      ..close();

    if (filled) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1 * s
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HeartIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}

class _ShareIconPainter extends CustomPainter {
  final Color color;
  const _ShareIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1 * s
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(18 * s, 5 * s), 3 * s, stroke);
    canvas.drawCircle(Offset(6 * s, 12 * s), 3 * s, stroke);
    canvas.drawCircle(Offset(18 * s, 19 * s), 3 * s, stroke);
    canvas.drawLine(
      Offset(8.7 * s, 13.5 * s),
      Offset(15.3 * s, 17.5 * s),
      stroke,
    );
    canvas.drawLine(
      Offset(15.3 * s, 6.5 * s),
      Offset(8.7 * s, 10.5 * s),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ShareIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DownloadIconPainter extends CustomPainter {
  final Color color;
  const _DownloadIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // M12 4v11m0 0 4-4m-4 4-4-4
    canvas.drawLine(Offset(12 * s, 4 * s), Offset(12 * s, 15 * s), stroke);
    final arrow = Path()
      ..moveTo(8 * s, 11 * s)
      ..lineTo(12 * s, 15 * s)
      ..lineTo(16 * s, 11 * s);
    canvas.drawPath(arrow, stroke);
    // M4 19h16
    canvas.drawLine(Offset(4 * s, 19 * s), Offset(20 * s, 19 * s), stroke);
  }

  @override
  bool shouldRepaint(covariant _DownloadIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ToolIconPainter extends CustomPainter {
  final int index;
  final Color color;
  const _ToolIconPainter({required this.index, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (index == 0) {
      canvas.drawCircle(Offset(6 * s, 6 * s), 3 * s, stroke);
      canvas.drawCircle(Offset(6 * s, 18 * s), 3 * s, stroke);
      canvas.drawLine(
        Offset(20 * s, 4 * s),
        Offset(8.12 * s, 15.88 * s),
        stroke,
      );
      canvas.drawLine(
        Offset(14.47 * s, 14.48 * s),
        Offset(20 * s, 20 * s),
        stroke,
      );
      canvas.drawLine(
        Offset(8.12 * s, 8.12 * s),
        Offset(12 * s, 12 * s),
        stroke,
      );
    } else if (index == 1) {
      final top = Path()
        ..moveTo(4 * s, 7 * s)
        ..lineTo(4 * s, 4 * s)
        ..lineTo(20 * s, 4 * s)
        ..lineTo(20 * s, 7 * s);
      canvas.drawPath(top, stroke);
      canvas.drawLine(Offset(9 * s, 20 * s), Offset(15 * s, 20 * s), stroke);
      canvas.drawLine(Offset(12 * s, 4 * s), Offset(12 * s, 20 * s), stroke);
    } else {
      final star = Path()
        ..moveTo(12 * s, 3 * s)
        ..lineTo(14.6 * s, 8.3 * s)
        ..lineTo(20.5 * s, 9.2 * s)
        ..lineTo(16.2 * s, 13.4 * s)
        ..lineTo(17.2 * s, 19.3 * s)
        ..lineTo(12 * s, 16.5 * s)
        ..lineTo(6.8 * s, 19.3 * s)
        ..lineTo(7.8 * s, 13.4 * s)
        ..lineTo(3.5 * s, 9.2 * s)
        ..lineTo(9.4 * s, 8.3 * s)
        ..close();
      canvas.drawPath(star, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _ToolIconPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.color != color;
}

class _TimelineStripesPainter extends CustomPainter {
  const _TimelineStripesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFDCE3EF),
    );
    final stripePaint = Paint()..color = const Color(0xFFCBD5E6);
    for (double x = 26; x < size.width; x += 27) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HtmlRangeSliderPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;

  const _HtmlRangeSliderPainter({
    required this.value,
    required this.min,
    required this.max,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ratio = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final cy = size.height / 2.0;
    const trackH = 8.0;
    const thumbR = 8.0;
    final thumbX = thumbR + (size.width - thumbR * 2) * ratio;

    final fullTrack = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, cy - trackH / 2, size.width, trackH),
      const Radius.circular(4),
    );
    canvas.drawRRect(fullTrack, Paint()..color = const Color(0xFFEFEFEF));
    canvas.drawRRect(
      fullTrack,
      Paint()
        ..color = const Color(0xFFB2B2B2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final activeTrack = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, cy - trackH / 2, thumbX, trackH),
      const Radius.circular(4),
    );
    canvas.drawRRect(activeTrack, Paint()..color = const Color(0xFFE01E5A));

    canvas.drawCircle(
      Offset(thumbX, cy),
      thumbR,
      Paint()..color = const Color(0xFFE01E5A),
    );
  }

  @override
  bool shouldRepaint(covariant _HtmlRangeSliderPainter oldDelegate) =>
      oldDelegate.value != value;
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  const _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius - strokeWidth / 2),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double dist = 0.0;
      const dashLen = 9.0;
      const gapLen = 6.0;
      while (dist < metric.length) {
        final next = (dist + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) => false;
}

class _UploadCloudArrowPainter extends CustomPainter {
  final Color color;
  const _UploadCloudArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(Offset(12 * s, 16 * s), Offset(12 * s, 5 * s), stroke);
    final arrow = Path()
      ..moveTo(8 * s, 9 * s)
      ..lineTo(12 * s, 5 * s)
      ..lineTo(16 * s, 9 * s);
    canvas.drawPath(arrow, stroke);

    final tray = Path()
      ..moveTo(4 * s, 16 * s)
      ..lineTo(4 * s, 18.5 * s)
      ..arcToPoint(
        Offset(5.5 * s, 20 * s),
        radius: Radius.circular(1.5 * s),
        clockwise: false,
      )
      ..lineTo(18.5 * s, 20 * s)
      ..arcToPoint(
        Offset(20 * s, 18.5 * s),
        radius: Radius.circular(1.5 * s),
        clockwise: false,
      )
      ..lineTo(20 * s, 16 * s);
    canvas.drawPath(tray, stroke);
  }

  @override
  bool shouldRepaint(covariant _UploadCloudArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _OutlineRRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  const _OutlineRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final half = strokeWidth / 2.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        -half,
        -half,
        size.width + strokeWidth,
        size.height + strokeWidth,
      ),
      Radius.circular(radius + half),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _OutlineRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}

class _BlurredRRectShadow extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Offset offset;
  final double sigma;
  final Color color;
  final Widget child;

  const _BlurredRRectShadow({
    required this.width,
    required this.height,
    required this.radius,
    required this.offset,
    required this.sigma,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: offset.dx,
            top: offset.dy,
            width: width,
            height: height,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
