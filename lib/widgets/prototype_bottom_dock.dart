import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../navigation/game_routes.dart';

/// Prototip alt navigasyon barı (`.dock` / `.dock-ic` / `.dock-label`).
/// `LululuDockBar` ile birebir aynı `padding: const EdgeInsets.all(7)`,
/// aktif/pasif `.dock-ic` iç-dış gölgeleri, yazı gölgeleri ve tıklanabilir
/// `onTap` navigasyon desteğini sağlar.
class PrototypeBottomDock extends StatelessWidget {
  const PrototypeBottomDock({
    super.key,
    required this.activeIndex,
    this.onSelect,
  });

  final int activeIndex;
  final ValueChanged<int>? onSelect;

  // S3#27: dock etiketleri tek kaynaktan (nav* anahtarları); bu
  // dosyadaki tekrar kaldırıldı. Etiketler build'de l10n'den okunup
  // [_DockButton]a parametreyle verilir; rota/ikon verisi const kalır.
  static const List<_DockNavItem> _items = [
    _DockNavItem(
      route: LululuRoutes.hub,
      customAsset: 'assets/design/ui/icons2/home.png',
      fallbackAsset: 'assets/icons2/home.png',
    ),
    _DockNavItem(
      route: LululuRoutes.modes,
      customAsset: 'assets/design/ui/icons2/target.png',
      fallbackAsset: 'assets/icons2/target.png',
    ),
    _DockNavItem(
      route: LululuRoutes.tiers,
      customAsset: 'assets/design/ui/icons2/paw.png',
      fallbackAsset: 'assets/icons2/paw.png',
    ),
    _DockNavItem(
      route: LululuRoutes.shop,
      customAsset: 'assets/design/ui/icons2/cart.png',
      fallbackAsset: 'assets/icons2/cart.png',
    ),
    _DockNavItem(
      route: LululuRoutes.scores,
      customAsset: 'assets/design/ui/icons2/trophy.png',
      fallbackAsset: 'assets/icons2/trophy.png',
    ),
  ];

  void _handleSelect(BuildContext context, int index) {
    if (onSelect != null) {
      onSelect!(index);
      return;
    }
    if (index == activeIndex || index < 0 || index >= _items.length) return;
    goTo(context, _items[index].route, replace: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = <String>[
      l10n.navHome,
      l10n.navModes,
      l10n.navFamily,
      l10n.navShop,
      l10n.navScores,
    ];
    final clampedIndex = activeIndex.clamp(0, _items.length - 1);

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
                final tabWidth = usableWidth / _items.length;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      left: clampedIndex * tabWidth,
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
                    Row(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          Expanded(
                            child: SizedBox(
                              height: 64,
                              child: _DockButton(
                                item: _items[i],
                                label: labels[i],
                                active: i == clampedIndex,
                                onTap: () => _handleSelect(context, i),
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

class _DockNavItem {
  const _DockNavItem({
    required this.route,
    required this.customAsset,
    required this.fallbackAsset,
  });

  final String route;
  final String customAsset;
  final String fallbackAsset;
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.item,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final _DockNavItem item;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, active ? -4 : 0),
              child: Transform.scale(
                scale: active ? 1.06 : 1.0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? Colors.white : const Color(0x17FFFFFF),
                    border: Border.all(
                      color: active ? Colors.white : const Color(0x2EFFFFFF),
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
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 4,
                            child: ColoredBox(color: Color(0x1F080B12)),
                          )
                        else
                          const Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: 2,
                            child: ColoredBox(color: Color(0x29FFFFFF)),
                          ),
                        Image.asset(
                          item.customAsset,
                          width: 33,
                          height: 33,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Image.asset(
                            item.fallbackAsset,
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
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
