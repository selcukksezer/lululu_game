import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/lululu_press.dart';

/// STÜDYO → YÜKLE — prototip mock'u (scr-studio-upload).
///
/// Dosya seç + başlık + sahte yükleme çubuğu (%0'dan başlar,
/// "YÜKLEMEYİ BAŞLAT" ile mock ilerleme oynar). Gerçek dosya
/// seçimi/yükleme yok — içerik prototiple birebir.
class StudioUploadScreen extends StatefulWidget {
  const StudioUploadScreen({super.key});

  @override
  State<StudioUploadScreen> createState() => _StudioUploadScreenState();
}

class _StudioUploadScreenState extends State<StudioUploadScreen> {
  final _titleCtrl = TextEditingController();
  double _progress = 0;
  bool _uploading = false;
  bool _done = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _startUpload() async {
    if (_uploading) return;
    AudioManager().playPop();
    setState(() {
      _uploading = true;
      _done = false;
      _progress = 0;
    });
    for (var i = 1; i <= 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _progress = i / 20);
    }
    if (!mounted) return;
    setState(() {
      _uploading = false;
      _done = true;
    });
    AudioManager().playWin();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).round();
    final statusText = _done
        ? 'Yüklendi!'
        : _uploading
            ? 'Yükleniyor…'
            : '%$percent';

    return Scaffold(
      backgroundColor: LululuColors.paper,
      appBar: AppBar(
        backgroundColor: LululuColors.paper,
        foregroundColor: LululuColors.inkDark,
        elevation: 0,
        title: Text(
          'YÜKLE',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 22,
            ),
            decoration: BoxDecoration(
              color: LululuColors.paperSoft,
              borderRadius: BorderRadius.circular(LululuRadii.card),
              border: Border.all(
                color: LululuColors.mutedTitanium.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_upload_rounded,
                  color: LululuColors.cyberFuchsia,
                  size: 44,
                ),
                const SizedBox(height: 10),
                LululuPress(
                  onTap: () => AudioManager().playPop(),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: LululuMotion.minTap,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LululuGradients.fuchsiaToGold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'DOSYA SEÇ',
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: LululuColors.paper,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'MP4 veya MOV · en fazla 500 MB',
                  style: GoogleFonts.exo2(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LululuColors.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: LululuColors.mutedTitanium.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LululuGradients.fuchsiaToGold,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: LululuColors.paper,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'lululu_birlesme_rekoru.mp4',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.exo2(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: LululuColors.inkDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '84,2 MB · 0:47 · 1080p',
                        style: GoogleFonts.exo2(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: LululuColors.mutedTitanium,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.check_circle_rounded,
                  color: LululuColors.toxicNeon,
                  size: 26,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'VİDEO BAŞLIĞI',
            style: GoogleFonts.exo2(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: LululuColors.inkDark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            style: GoogleFonts.exo2(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: LululuColors.inkDark,
            ),
            decoration: InputDecoration(
              hintText: 'Örn: rekor birleşme!',
              hintStyle: GoogleFonts.exo2(
                color: LululuColors.mutedTitanium,
              ),
              filled: true,
              fillColor: LululuColors.paperSoft,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color:
                      LululuColors.mutedTitanium.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color:
                      LululuColors.mutedTitanium.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: LululuColors.cyberFuchsia,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          LululuPress(
            onTap: _startUpload,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: LululuMotion.minTap,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _uploading
                    ? null
                    : LululuGradients.fuchsiaToGold,
                color: _uploading
                    ? LululuColors.mutedTitanium.withValues(alpha: 0.4)
                    : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'YÜKLEMEYİ BAŞLAT',
                style: GoogleFonts.exo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: LululuColors.paper,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusText,
                style: GoogleFonts.exo2(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _done
                      ? LululuColors.toxicNeon
                      : LululuColors.inkDark,
                ),
              ),
              if (_uploading || _done)
                Text(
                  '%$percent',
                  style: GoogleFonts.exo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 12,
              backgroundColor:
                  LululuColors.mutedTitanium.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                LululuColors.cyberFuchsia,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
