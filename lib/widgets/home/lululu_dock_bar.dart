import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sözleşme: bu isimler değişmez.
enum LululuDockTab { home, modes, family, shop, scores }

/// Floating hap dock v5 — HTML prototype `#scr-hub .dock` ile 1:1 piksel piksel aynı.
/// - Tamamen yüzen kapsül: x: 10, width: 410, height: 84, bottom: 10
/// - Dış çerçeve: 3px solid #ffffff, borderRadius: 999px
/// - Zemin: radyal + dikey gradyan (#2A3042 → #080B12)
/// - Aktif gösterge: 78x64 kapsül (#FFD34D → #FFB800 → #FF6B35 → #E01E5A), 2px beyaz kenarlık
class LululuDockBar extends StatelessWidget {
  const LululuDockBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final LululuDockTab selected;
  final ValueChanged<LululuDockTab> onSelect;

  static const _tabs = LululuDockTab.values;

  static String _label(LululuDockTab tab) => switch (tab) {
        LululuDockTab.home => 'ANA SAYFA',
        LululuDockTab.modes => 'MODLAR',
        LululuDockTab.family => 'AİLEM',
        LululuDockTab.shop => 'MAĞAZA',
        LululuDockTab.scores => 'SKORLAR',
      };

  static String _assetIcon(LululuDockTab tab) => switch (tab) {
        LululuDockTab.home => 'assets/design/ui/icons2/home.png',
        LululuDockTab.modes => 'assets/design/ui/icons2/target.png',
        LululuDockTab.family => 'assets/design/ui/icons2/paw.png',
        LululuDockTab.shop => 'assets/design/ui/icons2/cart.png',
        LululuDockTab.scores => 'assets/design/ui/icons2/trophy.png',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 410),
          child: Container(
            width: double.infinity,
            height: 84,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 3),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.72],
                colors: [
                  Color(0xFF2A3042),
                  Color(0xFF080B12),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x7A080B12),
                  blurRadius: 38,
                  offset: Offset(0, 22),
                ),
                BoxShadow(
                  color: Color(0x47080B12),
                  blurRadius: 0,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final usableWidth = constraints.maxWidth.clamp(100.0, 390.0);
                final tabWidth = usableWidth / _tabs.length;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Aktif gösterge kapsülü (dock-ind: 78x64 at rect: [20 + idx*78, 848, 78x64])
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      left: selected.index * tabWidth,
                      top: 0.0,
                      width: tabWidth,
                      height: 64.0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.94),
                            width: 2,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.40, 0.74, 1.0],
                            colors: [
                              Color(0xFFFFD34D),
                              Color(0xFFFFB800),
                              Color(0xFFFF6B35),
                              Color(0xFFE01E5A),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D000000),
                              blurRadius: 0,
                              offset: Offset(0, 5),
                            ),
                            BoxShadow(
                              color: Color(0x47E01E5A),
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Sekmeler: 3px border + 7px padding = 10px iç boşluk (64px yükseklik)
                    Row(
                      children: [
                        for (final tab in _tabs)
                          Expanded(
                            child: SizedBox(
                              height: 64,
                              child: _DockItem(
                                tab: tab,
                                active: tab == selected,
                                onTap: () => onSelect(tab),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final LululuDockTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = LululuDockBar._label(tab);
    final iconAsset = LululuDockBar._assetIcon(tab);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // dock-ic yuvarlak ikon kapsülü
            Transform.translate(
              offset: Offset(0, active ? -4 : 0),
              child: Transform.scale(
                scale: active ? 1.06 : 1.0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? Colors.white
                        : const Color(0x17FFFFFF),
                    border: Border.all(
                      color: active
                          ? Colors.white
                          : const Color(0x2EFFFFFF),
                      width: 2,
                    ),
                    boxShadow: active
                        ? const [
                            BoxShadow(
                              color: Color(0x597A082E),
                              blurRadius: 0,
                              offset: Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Color(0x52000000),
                              blurRadius: 12,
                              offset: Offset(0, 7),
                            ),
                          ]
                        : const [
                            BoxShadow(
                              color: Color(0x4D000000),
                              blurRadius: 0,
                              offset: Offset(0, 3),
                            ),
                          ],
                  ),
                  child: ClipOval(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (active)
                          // inset 0 -4px 0 rgba(8,11,18,0.12)
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 4,
                            child: ColoredBox(color: Color(0x1F080B12)),
                          )
                        else
                          // inset 0 2px 0 rgba(255,255,255,0.16)
                          const Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: 2,
                            child: ColoredBox(color: Color(0x29FFFFFF)),
                          ),
                        Image.asset(
                          iconAsset,
                          width: 33,
                          height: 33,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.star_rounded,
                            size: 26,
                            color: active
                                ? const Color(0xFF141B2A)
                                : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // dock-label
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: GoogleFonts.baloo2(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: 0,
                  color: active
                      ? const Color(0xFF1F1300)
                      : const Color(0xA8FFFFFF),
                  shadows: active
                      ? const [
                          Shadow(
                            color: Color(0x73FFFFFF),
                            offset: Offset(0, 1),
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
          ],
        ),
      ),
    );
  }
}
