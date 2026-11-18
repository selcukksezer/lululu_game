import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/progress_manager.dart';

/// 1:1 Pixel-Perfect Energy Empty Popup matching `#energyOverlay` (`.energy-card`).
Future<void> showEnergyEmptyPopup(BuildContext context) {
  AudioManager().playPop();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xB805070C),
    builder: (_) => const _EnergyEmptyDialog(),
  );
}

class _EnergyEmptyDialog extends StatefulWidget {
  const _EnergyEmptyDialog();

  @override
  State<_EnergyEmptyDialog> createState() => _EnergyEmptyDialogState();
}

class _EnergyEmptyDialogState extends State<_EnergyEmptyDialog> {
  final EnergyService _energy = EnergyService.instance;
  final ProgressManager _pm = ProgressManager();
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _energy.addListener(_onChanged);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_energy.current > 0) {
        Navigator.of(context).maybePop();
        return;
      }
      setState(() {});
    });
  }

  void _onChanged() {
    if (!mounted) return;
    if (_energy.current > 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _energy.removeListener(_onChanged);
    super.dispose();
  }

  void _showToast(ScaffoldMessengerState messenger, String msg) {
    AudioManager().playPop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          duration: const Duration(milliseconds: 1600),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF141B2A),
        ),
      );
  }

  /// Enerji paketi ön-onayı (O3): mağaza onay deseniyle aynı
  /// (AlertDialog + Vazgeç / Onayla). Onaylanmazsa hiç harcama ve yan
  /// etki olmaz, popup açık kalır. Tutarlar kodda sabit: 100 coin
  /// karşılığı +5 enerji.
  Future<bool> _confirmEnergyPurchase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.shopPurchaseConfirmTitle),
        content: Text(ctx.l10n.shopEnergyEmptyConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.confirm),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _buyEnergyPack() async {
    if (_busy) return;
    final confirmed = await _confirmEnergyPurchase();
    if (!confirmed || !mounted || _busy) return;
    AudioManager().playPop();
    // l10n + messenger bağıştan ÖNCE alınır: bağış enerji dinleyicisini
    // tetikleyip diyaloğu kapatırsa bile bildirim gösterilebilir.
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final spent = await _pm.spendCoins(100);
      if (!spent) {
        // Yetersiz bakiye: enerji verilmez, diyalog açık kalır.
        _showToast(messenger, l10n.shopNotEnoughGoldToast);
        return;
      }
      try {
        await _energy.grantFull(5);
      } catch (_) {
        // Ödeme sonrası bağış hatası: coin iade edilir, bildirim gösterilir.
        try {
          await _pm.addCoins(100);
        } catch (_) {}
        _showToast(messenger, l10n.shopPurchaseFailedRefundToast);
        return;
      }
      _showToast(messenger, l10n.energyPackBoughtToast);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatWait(Duration d) {
    final total = d.inSeconds.clamp(0, 3599);
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final wait = _energy.timeUntilNextPoint;
    final waitLabel = wait != null ? _formatWait(wait) : '05:00';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 382),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFFFFB800),
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                offset: Offset(0, 18),
                blurRadius: 40,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // `.en-broken` -> 88x88 3D heart PNG split into two 44x88 halves
                Container(
                  width: 88,
                  height: 88,
                  margin: const EdgeInsets.only(bottom: 4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // `.hb-half.hb-l`: `width: 44px; height: 88px; transform: translate(-5px, 4px) rotate(-15deg)`
                      Positioned(
                        left: 0,
                        top: 0,
                        width: 44,
                        height: 88,
                        child: Transform.translate(
                          offset: const Offset(-5, 4),
                          child: Transform.rotate(
                            angle: -15 * math.pi / 180,
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: 0.5,
                                child: Image.asset(
                                  'assets/design/ui/hub_3_ep-heart.webp',
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // `.hb-half.hb-r`: `width: 44px; height: 88px; transform: translate(5px, 4px) rotate(15deg); img { margin-left: -44px }`
                      Positioned(
                        right: 0,
                        top: 0,
                        width: 44,
                        height: 88,
                        child: Transform.translate(
                          offset: const Offset(5, 4),
                          child: Transform.rotate(
                            angle: 15 * math.pi / 180,
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerRight,
                                widthFactor: 0.5,
                                child: Image.asset(
                                  'assets/design/ui/hub_3_ep-heart.webp',
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.energyEmptyTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE01E5A),
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5B6B82),
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: context.l10n.energyEmptyBodyStart),
                      TextSpan(
                        text: '${_energy.current}/${EnergyService.maxEnergy}',
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF141B2A),
                        ),
                      ),
                      TextSpan(
                        text: context.l10n.energyEmptyBodyMiddle,
                      ),
                      TextSpan(
                        text: waitLabel,
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF141B2A),
                        ),
                      ),
                      TextSpan(
                        text: context.l10n.energyEmptyBodyEnd,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Ödüllü reklam SDK'sı kurulu değil (madde 4): reklam
                // düğmesi devre dışıdır, ödül vermez. Gerçek SDK
                // eklendiğinde bu düğme gerçek reklam akışına bağlanmalıdır.
                _buildActionBtn(
                  label: context.l10n.rewardedAdsSoonCaps,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.55, 1.0],
                    colors: [
                      Color(0xFFB8BFCB),
                      Color(0xFF9AA3B2),
                      Color(0xFF8A93A3),
                    ],
                  ),
                  shadowColor: const Color(0xFF6B7482),
                  hasBlurShadow: true,
                  textColor: Colors.white,
                  hasTextShadow: false,
                  onTap: null,
                ),
                const SizedBox(height: 10),
                // `#energyShopBtn` (.btn gold)
                _buildActionBtn(
                  label: context.l10n.shopEnergyPackButton,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.55, 1.0],
                    colors: [
                      Color(0xFFFFCF3F),
                      Color(0xFFFFB800),
                      Color(0xFFF59E00),
                    ],
                  ),
                  shadowColor: const Color(0xFFB97A00),
                  hasBlurShadow: true,
                  textColor: Colors.white,
                  hasTextShadow: true,
                  onTap: _busy ? null : _buyEnergyPack,
                ),
                const SizedBox(height: 10),
                // `#energyWaitBtn` (.btn.soft)
                _buildActionBtn(
                  label: context.l10n.waitForTimerCaps,
                  solidColor: const Color(0xFFEEF1F7),
                  shadowColor: const Color(0x29141B2A),
                  shadowOffsetY: 4,
                  hasBlurShadow: false,
                  textColor: const Color(0xFF141B2A),
                  hasTextShadow: false,
                  onTap: () {
                    AudioManager().playPop();
                    Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required String label,
    Widget? leadingIcon,
    Gradient? gradient,
    Color? solidColor,
    required Color shadowColor,
    double shadowOffsetY = 5,
    required bool hasBlurShadow,
    required Color textColor,
    required bool hasTextShadow,
    required VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: solidColor,
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                offset: Offset(0, shadowOffsetY),
                blurRadius: 0,
              ),
              if (hasBlurShadow)
                const BoxShadow(
                  color: Color(0x47000000),
                  offset: Offset(0, 10),
                  blurRadius: 18,
                ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                leadingIcon,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 0.36,
                    height: 1.0,
                    shadows: hasTextShadow
                        ? const [
                            Shadow(
                              color: Color(0x59784000),
                              offset: Offset(0, 1),
                              blurRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

