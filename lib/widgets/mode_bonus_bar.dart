import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';

/// Tek güçlendirici yuvası — ikon, kısa etiket, stok rozeti.
class ModeBonus {
  const ModeBonus({
    required this.label,
    required this.asset,
    required this.count,
    this.onTap,
    this.description,
    this.price,
  });

  final String label;
  final String asset;
  final int count;
  final VoidCallback? onTap;
  final String? description;
  final int? price;
}

/// Prototip power-dock (`power-bar` / `power-dock`): 3 yuvarlak güçlendirici,
/// ≥48dp dokunma alanı ve 320px..tablet tüm ekranlarda sıfır taşma garantisi.
class ModeBonusBar extends StatelessWidget {
  const ModeBonusBar({
    super.key,
    required this.items,
    this.compact = false,
  });

  final List<ModeBonus> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 430.0;
        final isTight = compact || maxW < 238;
        final row = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(width: compact ? 10 : 20),
              _BonusButton(item: items[i], compact: compact),
            ],
          ],
        );
        if (isTight) {
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: row,
            ),
          );
        }
        return Center(child: row);
      },
    );
  }
}

class _BonusButton extends StatefulWidget {
  const _BonusButton({
    required this.item,
    required this.compact,
  });

  final ModeBonus item;
  final bool compact;

  @override
  State<_BonusButton> createState() => _BonusButtonState();
}

class _BonusButtonState extends State<_BonusButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasStock = item.count > 0;
    final enabled = item.onTap != null && hasStock;

    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.boosterCountLabel(item.label, item.count),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _pressed ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? item.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: Opacity(
            opacity: hasStock ? 1 : 0.55,
            child: SizedBox(
              width: widget.compact ? 58 : 66,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            height: 48,
                            width: 48,
                            padding: const EdgeInsets.all(6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF333F58), Color(0xFF1B2336)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x73000000),
                                  offset: Offset(0, 3),
                                ),
                                BoxShadow(
                                  color: Color(0x4D000000),
                                  offset: Offset(0, 6),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              item.asset,
                              width: 36,
                              height: 36,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.auto_awesome_rounded,
                                color: LululuColors.liquidGold,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: widget.compact ? 1 : 7,
                          child: Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE01E5A),
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: Color(0xFF080B12), width: 2),
                              ),
                            ),
                            child: Text(
                              '${item.count}',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: widget.compact ? 58 : 66,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 9,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.18,
                            color: const Color(0xFFD8E0EE),
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
    );
  }
}

/// Kasadan 1 yük harcar, sonra [effect] çalıştırır; stok 0 ise dokunulmaz.
///
/// [canApply] verilirse önce o kontrol edilir: `false` dönerse stok
/// tüketilmez ve [effect] çalışmaz (S1#30 önkoşul yolu). Etkinin başarı
/// durumunu döndüğü durumlarda [stockBonusWithResult] kullanılmalıdır —
/// orada `false` dönen etki stoğu iade eder.
ModeBonus stockBonus({
  required String id,
  required String label,
  required String asset,
  required VoidCallback effect,
  String? description,
  int? price,
  bool Function()? canApply,
}) {
  final pm = ProgressManager();
  final count = pm.powerCount(id);
  return ModeBonus(
    label: label,
    asset: asset,
    count: count,
    description: description,
    price: price,
    onTap: count <= 0
        ? null
        : () {
            if (canApply != null && !canApply()) return;
            if (!pm.takePower(id)) return;
            effect();
          },
  );
}

/// `bool` dönen etkili [stockBonus] varyantı (S1#30 iade yolu).
///
/// Akış: [canApply] önkoşulu → [ProgressManager.takePower] ile 1 yük
/// tüket → [effect] çalıştır. [effect] `false` dönerse (örn. balon
/// tahtası boşken bomba) tüketilen 1 yük
/// [ProgressManager.refundPower] ile iade edilir; stok harcanmış olmaz.
/// `true` dönen etki stoğu tüketmiş sayılır. Stok 0 ise dokunulmaz.
///
/// Mevcut `void` kapamalar (`effect: () { _useBomb(); setState(...); }`
/// gibi, `bool` sonucu atanlar) bu varyanta taşınmalıdır; taşınmayan
/// çağrıcılar eski davranışı korur.
ModeBonus stockBonusWithResult({
  required String id,
  required String label,
  required String asset,
  required bool Function() effect,
  String? description,
  int? price,
  bool Function()? canApply,
}) {
  final pm = ProgressManager();
  final count = pm.powerCount(id);
  return ModeBonus(
    label: label,
    asset: asset,
    count: count,
    description: description,
    price: price,
    onTap: count <= 0
        ? null
        : () {
            if (canApply != null && !canApply()) return;
            if (!pm.takePower(id)) return;
            if (!effect()) {
              pm.refundPower(id);
            }
          },
  );
}
