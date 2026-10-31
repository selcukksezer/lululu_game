import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/lululu_theme.dart';
import '../widgets/dot_scaffold.dart';
import '../widgets/lululu_press.dart';

enum BugVideoTab { watch, create }

/// STÜDYO → VİDEO İZLE / VİDEO YAP — prototip birebir.
///
/// İZLE: öne çıkan video + "SIRADAKİ VİDEOLAR" listesi.
/// YAP: "LÜLÜLÜ!" alt başlık, Kırp|Yazı|Sticker sekmeleri.
class BugVideoHubScreen extends StatefulWidget {
  const BugVideoHubScreen({super.key, this.initial = BugVideoTab.watch});

  final BugVideoTab initial;

  @override
  State<BugVideoHubScreen> createState() => _BugVideoHubScreenState();
}

class _BugVideoHubScreenState extends State<BugVideoHubScreen> {
  late BugVideoTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initial;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DotScaffold(
      appBar: AppBar(
        title: Text(
          _tab == BugVideoTab.watch ? 'VİDEO İZLE' : 'VİDEO YAP',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
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
                    label: 'YAP',
                    selected: _tab == BugVideoTab.create,
                    onTap: () =>
                        setState(() => _tab = BugVideoTab.create),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tab == BugVideoTab.watch
                ? _WatchPane(onToast: _toast)
                : _CreatePane(onToast: _toast),
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
        height: LululuMotion.minTap,
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

/// Öne çıkan video + sıradaki videolar (prototip metinleri birebir).
class _WatchPane extends StatelessWidget {
  const _WatchPane({required this.onToast});

  final ValueChanged<String> onToast;

  static const _upcoming = <_VideoItem>[
    _VideoItem(
      duration: '0:32',
      title: 'Böcek Birleştirme Rekoru! 51.200 Puan',
      meta: '128 B görüntülenme · 2 gün önce',
      thumb: 'assets/design/backgrounds/suika_kitchen.webp',
    ),
    _VideoItem(
      duration: '1:04',
      title: "Çığlık Böcek'te KAPI 7'ye Nasıl Geçilir?",
      meta: '86 B görüntülenme · 5 gün önce',
      thumb: 'assets/design/backgrounds/scream_sky.webp',
    ),
    _VideoItem(
      duration: '0:47',
      title: 'Pembe Bornozlu İlk Kez Evrimleşti!',
      meta: '203 B görüntülenme · 1 hafta önce',
      thumb: 'assets/design/backgrounds/osmantus_mansion.webp',
    ),
    _VideoItem(
      duration: '0:58',
      title: 'Terlik Yağmuru: Kombo x12 Nasıl Yapılır?',
      meta: '57 B görüntülenme · 2 hafta önce',
      thumb: 'assets/design/backgrounds/terlik_livingroom.webp',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Öne çıkan video.
        _FeaturedCard(onToast: onToast),
        const SizedBox(height: 20),
        Text(
          'SIRADAKİ VİDEOLAR',
          style: GoogleFonts.exo2(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: LululuColors.inkDark,
          ),
        ),
        const SizedBox(height: 10),
        for (final v in _upcoming) ...[
          _VideoRow(item: v, onToast: onToast),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _VideoItem {
  const _VideoItem({
    required this.duration,
    required this.title,
    required this.meta,
    required this.thumb,
  });

  final String duration;
  final String title;
  final String meta;
  final String thumb;
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.onToast});

  final ValueChanged<String> onToast;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LululuRadii.card),
        gradient: LululuGradients.elevatedCard,
        border: Border.all(
          color: LululuColors.liquidGold.withValues(alpha: 0.45),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.asset(
                    'assets/design/backgrounds/suika_kitchen.webp',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: LululuColors.darkObsidian,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: LululuPress(
                    onTap: () => onToast('Önizleme yakında'),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: LululuColors.liquidGold,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 40,
                        color: LululuColors.carbonVoid,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: LululuColors.carbonVoid.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '0:00 / 0:32',
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: LululuColors.paper,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Böcek Birleştirme Rekoru! 51.200 Puan',
            style: GoogleFonts.exo2(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: LululuColors.paper,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '128 B görüntülenme · 2 gün önce',
            style: GoogleFonts.exo2(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LululuColors.mutedTitanium,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.thumb_up_rounded,
                size: 20,
                color: LululuColors.liquidGold,
              ),
              const SizedBox(width: 6),
              Text(
                '1.248',
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: LululuColors.paper,
                ),
              ),
              const Spacer(),
              _SmallAction(
                icon: Icons.ios_share_rounded,
                label: 'Paylaş',
                onTap: () => onToast('Paylaşım bağlantısı kopyalandı'),
              ),
              const SizedBox(width: 8),
              _SmallAction(
                icon: Icons.download_rounded,
                label: 'İndir',
                onTap: () => onToast('İndirilenlere eklendi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: LululuColors.darkObsidian,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: LululuColors.mutedTitanium.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: LululuColors.liquidGold),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: LululuColors.paper,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  const _VideoRow({required this.item, required this.onToast});

  final _VideoItem item;
  final ValueChanged<String> onToast;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: () => onToast('Önizleme yakında'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: LululuColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: LululuColors.mutedTitanium.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 128,
                    height: 76,
                    child: Image.asset(
                      item.thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: LululuColors.darkObsidian,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          LululuColors.carbonVoid.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.duration,
                      style: GoogleFonts.exo2(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: LululuColors.paper,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.exo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: LululuColors.inkDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.meta,
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: LululuColors.mutedTitanium,
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
}

/// VİDEO YAP — Kırp | Yazı | Sticker sekmeleri (prototip birebir).
class _CreatePane extends StatefulWidget {
  const _CreatePane({required this.onToast});

  final ValueChanged<String> onToast;

  @override
  State<_CreatePane> createState() => _CreatePaneState();
}

class _CreatePaneState extends State<_CreatePane> {
  int _tab = 0;
  final _textCtrl = TextEditingController(text: 'LÜLÜLÜ!');
  int _sticker = 0;

  static const _stickers = <String>[
    'assets/design/bugs_hd/tier1_hd.png',
    'assets/design/bugs_hd/tier4_hd.png',
    'assets/design/bugs_hd/tier5_hd.png',
    'assets/design/bugs_hd/tier7_hd.png',
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(
          'VİDEO YAP',
          style: GoogleFonts.bangers(
            fontSize: 34,
            letterSpacing: 1.2,
            color: LululuColors.inkDark,
          ),
        ),
        Text(
          'LÜLÜLÜ!',
          style: GoogleFonts.exo2(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: LululuColors.cyberFuchsia,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i < 2 ? 8 : 0,
                  ),
                  child: _MiniTab(
                    label: const ['Kırp', 'Yazı', 'Sticker'][i],
                    selected: _tab == i,
                    onTap: () => setState(() => _tab = i),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_tab == 0) _buildTrim(),
        if (_tab == 1) _buildText(),
        if (_tab == 2) _buildStickers(),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () =>
                widget.onToast('Taslak kaydedildi · önizleme yakında'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LululuColors.liquidGold,
              foregroundColor: LululuColors.carbonVoid,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: Text(
              'KAYDET VE ÖNİZLE',
              style: GoogleFonts.exo2(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Taslak, Yükle ekranından paylaşılabilir.',
          textAlign: TextAlign.center,
          style: GoogleFonts.exo2(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: LululuColors.mutedTitanium,
          ),
        ),
      ],
    );
  }

  Widget _buildTrim() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Klibi Kırp',
            style: GoogleFonts.exo2(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: LululuColors.inkDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seçili bölüm: 0:00 – 0:29 · Toplam 0:47',
            style: GoogleFonts.exo2(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: LululuColors.mutedTitanium,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    LululuColors.cyberFuchsia,
                    LululuColors.cyberFuchsia.withValues(alpha: 0.25),
                  ],
                  stops: const [0.62, 0.62],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      LululuColors.mutedTitanium.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildText() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yazı Ekle',
            style: GoogleFonts.exo2(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: LululuColors.inkDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Yazı, önizlemede anında görünür.',
            style: GoogleFonts.exo2(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LululuColors.mutedTitanium,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _textCtrl,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w800,
              color: LululuColors.inkDark,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: LululuColors.paper,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: AssetImage(
                    'assets/design/backgrounds/suika_kitchen.webp'),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Text(
                _textCtrl.text.isEmpty ? 'LÜLÜLÜ!' : _textCtrl.text,
                style: GoogleFonts.bangers(
                  fontSize: 30,
                  color: LululuColors.paper,
                  shadows: const [
                    Shadow(
                      color: LululuColors.carbonVoid,
                      blurRadius: 0,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickers() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sticker Seç',
            style: GoogleFonts.exo2(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: LululuColors.inkDark,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _stickers.length,
            itemBuilder: (context, i) {
              final sel = _sticker == i;
              return GestureDetector(
                onTap: () => setState(() => _sticker = i),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel
                          ? LululuColors.liquidGold
                          : LululuColors.mutedTitanium
                              .withValues(alpha: 0.3),
                      width: sel ? 3 : 1.5,
                    ),
                    color: LululuColors.paper,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    _stickers[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.bug_report_rounded),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MiniTab extends StatelessWidget {
  const _MiniTab({
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
      child: Container(
        height: LululuMotion.minTap,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? LululuColors.cyberFuchsia
              : LululuColors.darkObsidian,
        ),
        child: Text(
          label,
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w900,
            color: selected
                ? LululuColors.paper
                : LululuColors.mutedTitanium,
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LululuColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LululuColors.mutedTitanium.withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );
  }
}
