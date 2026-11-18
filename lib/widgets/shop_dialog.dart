import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/iap_service.dart';
import '../services/progress_manager.dart';

String _trUpper(String input, Locale locale) {
  if (locale.languageCode != 'tr') {
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

Future<void> showShopDialog(
  BuildContext context, {
  VoidCallback? onStateChanged,
}) {
  return ShopDialog.show(context, onStateChanged: onStateChanged);
}

/// LÜLÜLÜ MAĞAZA (`#scr-shop`) — Pixel-perfect 1:1 implementation
/// of `LÜLÜLÜ UI:UX Tasarım.html`.
class ShopDialog extends StatelessWidget {
  final VoidCallback? onStateChanged;

  const ShopDialog({super.key, this.onStateChanged});

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onStateChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ShopDialog(onStateChanged: onStateChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: ShopScreen(
        onStateChanged: onStateChanged,
        showBottomNav: false,
        onBack: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

class ShopScreen extends StatefulWidget {
  final VoidCallback? onStateChanged;
  final VoidCallback? onBack;
  final bool showBottomNav;
  final bool embedded;

  const ShopScreen({
    super.key,
    this.onStateChanged,
    this.onBack,
    this.showBottomNav = true,
    this.embedded = false,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final ProgressManager _pm = ProgressManager();

  /// IAP + coin'li alımların ortak kilidi: çift dokunma / eşzamanlı
  /// iki satın alma aynı anda işlemez.
  bool _purchaseBusy = false;

  List<_ModePowerGroup> _powerGroups(AppLocalizations l10n) => [
    _ModePowerGroup(
      modeName: l10n.shopModeSuikaArena,
      iconAsset: 'assets/icons2/target.png',
      powers: [
        _PowerRowItem(
          id: 'raid',
          name: l10n.shopPowerRaidSprayName,
          iconAsset: 'assets/powerup_raid_spreyi.png',
          desc: l10n.shopPowerRaidSprayDesc,
          cost: 450,
        ),
        _PowerRowItem(
          id: 'terlik',
          name: l10n.shopPowerSlipperShakeName,
          iconAsset: 'assets/powerup_terlik.png',
          desc: l10n.shopPowerSlipperShakeDesc,
          cost: 300,
        ),
        _PowerRowItem(
          id: 'f16',
          name: l10n.shopPowerLightItUpName,
          iconAsset: 'assets/powerup_aydinlat.png',
          desc: l10n.shopPowerLightItUpDesc,
          cost: 250,
        ),
      ],
    ),
    _ModePowerGroup(
      modeName: l10n.shopModeGrid2048,
      iconAsset: 'assets/icons/level_up.png',
      powers: [
        _PowerRowItem(
          id: 'undo',
          name: l10n.shopPowerUndoName,
          iconAsset: 'assets/icons2/back.png',
          desc: l10n.shopPowerUndoDesc,
          cost: 200,
        ),
        _PowerRowItem(
          id: 'shuffle',
          name: l10n.shopPowerShuffleName,
          iconAsset: 'assets/icons2/wand.png',
          desc: l10n.shopPowerShuffleDesc,
          cost: 350,
        ),
        _PowerRowItem(
          id: 'pair',
          name: l10n.shopPowerMergePairName,
          iconAsset: 'assets/icons2/magnet.png',
          desc: l10n.shopPowerMergePairDesc,
          cost: 400,
        ),
      ],
    ),
    _ModePowerGroup(
      modeName: l10n.shopModeBalloonPop,
      iconAsset: 'assets/icons2/boom.png',
      powers: [
        _PowerRowItem(
          id: 'triple',
          name: l10n.shopPowerTripleArrowName,
          iconAsset: 'assets/icons2/target.png',
          desc: l10n.shopPowerTripleArrowDesc,
          cost: 300,
        ),
        _PowerRowItem(
          id: 'bombb',
          name: l10n.shopPowerBombBalloonName,
          iconAsset: 'assets/icons2/boom.png',
          desc: l10n.shopPowerBombBalloonDesc,
          cost: 450,
        ),
        _PowerRowItem(
          id: 'slowb',
          name: l10n.shopPowerSlowName,
          iconAsset: 'assets/icons2/stopwatch.png',
          desc: l10n.shopPowerSlowBalloonDesc,
          cost: 250,
        ),
      ],
    ),
    _ModePowerGroup(
      modeName: l10n.shopModeMatch3,
      iconAsset: 'assets/icons2/gem_blue.png',
      powers: [
        _PowerRowItem(
          id: 'hammer',
          name: l10n.shopPowerHammerName,
          iconAsset: 'assets/icons2/hammer.png',
          desc: l10n.shopPowerHammerDesc,
          cost: 200,
        ),
        _PowerRowItem(
          id: 'bomb3',
          name: l10n.shopPowerBombName,
          iconAsset: 'assets/icons2/boom.png',
          desc: l10n.shopPowerBombDesc,
          cost: 400,
        ),
        _PowerRowItem(
          id: 'hunter',
          name: l10n.shopPowerColorHunterName,
          iconAsset: 'assets/icons2/gem_blue.png',
          desc: l10n.shopPowerColorHunterDesc,
          cost: 500,
        ),
      ],
    ),
    _ModePowerGroup(
      modeName: l10n.shopModeLinkPop,
      iconAsset: 'assets/icons2/magnet.png',
      powers: [
        _PowerRowItem(
          id: 'chain',
          name: l10n.shopPowerChainExtenderName,
          iconAsset: 'assets/icons2/flame.png',
          desc: l10n.shopPowerChainExtenderDesc,
          cost: 250,
        ),
        _PowerRowItem(
          id: 'bolt',
          name: l10n.shopPowerLightningName,
          iconAsset: 'assets/icons2/bolt.png',
          desc: l10n.shopPowerLightningDesc,
          cost: 350,
        ),
        _PowerRowItem(
          id: 'magnet',
          name: l10n.shopPowerMagnetName,
          iconAsset: 'assets/icons2/magnet.png',
          desc: l10n.shopPowerMagnetDesc,
          cost: 300,
        ),
      ],
    ),
    _ModePowerGroup(
      modeName: l10n.shopModeStackDrop,
      iconAsset: 'assets/icons2/block.png',
      powers: [
        _PowerRowItem(
          id: 'freeze',
          name: l10n.shopPowerFreezeName,
          iconAsset: 'assets/icons2/crystal.png',
          desc: l10n.shopPowerFreezeDesc,
          cost: 300,
        ),
        _PowerRowItem(
          id: 'widen',
          name: l10n.shopPowerWidenName,
          iconAsset: 'assets/icons2/block.png',
          desc: l10n.shopPowerWidenDesc,
          cost: 350,
        ),
        _PowerRowItem(
          id: 'slows',
          name: l10n.shopPowerSlowName,
          iconAsset: 'assets/icons2/clock.png',
          desc: l10n.shopPowerSlowStackDesc,
          cost: 250,
        ),
      ],
    ),
    _ModePowerGroup(
      modeName: l10n.shopModeSlipperTap,
      iconAsset: 'assets/icons2/boot.png',
      powers: [
        _PowerRowItem(
          id: 'dblslip',
          name: l10n.shopPowerDoubleSlipperName,
          iconAsset: 'assets/icons2/boot.png',
          desc: l10n.shopPowerDoubleSlipperDesc,
          cost: 300,
        ),
        _PowerRowItem(
          id: 'goldslip',
          name: l10n.shopPowerGoldenSlipperName,
          iconAsset: 'assets/icons2/premium_token.png',
          desc: l10n.shopPowerGoldenSlipperDesc,
          cost: 450,
        ),
        _PowerRowItem(
          id: 'spraybug',
          name: l10n.shopPowerBugSprayName,
          iconAsset: 'assets/icons2/potion_health.png',
          desc: l10n.shopPowerBugSprayDesc,
          cost: 400,
        ),
      ],
    ),
    _ModePowerGroup(
      modeName: l10n.shopModeNestDefense,
      iconAsset: 'assets/icons2/target.png',
      powers: [
        _PowerRowItem(
          id: 'yuva_dblslip',
          name: l10n.shopPowerDoubleSlipperName,
          iconAsset: 'assets/icons2/boot.png',
          desc: l10n.shopPowerDoubleSlipperDesc,
          cost: 300,
        ),
        _PowerRowItem(
          id: 'yuva_goldslip',
          name: l10n.shopPowerGoldenSlipperName,
          iconAsset: 'assets/icons2/premium_token.png',
          desc: l10n.shopPowerGoldenSlipperDesc,
          cost: 450,
        ),
        _PowerRowItem(
          id: 'nest_shield',
          name: l10n.shopPowerNestShieldName,
          iconAsset: 'assets/icons2/shield.png',
          desc: l10n.shopPowerNestShieldDesc,
          cost: 400,
        ),
      ],
    ),
    _ModePowerGroup(
      modeName: l10n.shopModeOsmantus,
      iconAsset: 'assets/icons2/crown.png',
      powers: [
        _PowerRowItem(
          id: 'dik',
          name: l10n.shopPowerDikkisBoostName,
          iconAsset: 'assets/icons2/fist.png',
          desc: l10n.shopPowerDikkisBoostDesc,
          cost: 250,
        ),
        _PowerRowItem(
          id: 'ring',
          name: l10n.shopPowerWideRingName,
          iconAsset: 'assets/icons2/wheel.png',
          desc: l10n.shopPowerWideRingDesc,
          cost: 300,
        ),
        _PowerRowItem(
          id: 'mic',
          name: l10n.shopPowerMicrophoneName,
          iconAsset: 'assets/icons2/star.png',
          desc: l10n.shopPowerMicrophoneDesc,
          cost: 400,
        ),
      ],
    ),
    _ModePowerGroup(
      modeName: l10n.shopModeScreamBug,
      iconAsset: 'assets/icons2/bolt.png',
      powers: [
        _PowerRowItem(
          id: 'jump',
          name: l10n.shopPowerJumpBootsName,
          iconAsset: 'assets/icons2/boot.png',
          desc: l10n.shopPowerJumpBootsDesc,
          cost: 300,
        ),
        _PowerRowItem(
          id: 'shield',
          name: l10n.shopPowerShieldName,
          iconAsset: 'assets/icons2/shield.png',
          desc: l10n.shopPowerShieldDesc,
          cost: 350,
        ),
        _PowerRowItem(
          id: 'nitro',
          name: l10n.shopPowerNitroName,
          iconAsset: 'assets/icons2/potion_speed.png',
          desc: l10n.shopPowerNitroDesc,
          cost: 400,
        ),
      ],
    ),
    _ModePowerGroup(
      modeName: l10n.shopModeMakarayiz,
      iconAsset: 'assets/icons2/wheel.png',
      powers: [
        _PowerRowItem(
          id: 'beat',
          name: l10n.shopPowerBeatFreezeName,
          iconAsset: 'assets/icons2/clock.png',
          desc: l10n.shopPowerBeatFreezeDesc,
          cost: 250,
        ),
        _PowerRowItem(
          id: 'auto',
          name: l10n.shopPowerAutoReelName,
          iconAsset: 'assets/icons2/wheel.png',
          desc: l10n.shopPowerAutoReelDesc,
          cost: 500,
        ),
        _PowerRowItem(
          id: 'x2',
          name: l10n.shopPowerScoreMultiplierName,
          iconAsset: 'assets/icons2/boost_coins.png',
          desc: l10n.shopPowerScoreMultiplierDesc,
          cost: 350,
        ),
      ],
    ),
  ];

  String _formatNumber(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _showToast(String msg) {
    AudioManager().playPop();
    ScaffoldMessenger.of(context)
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

  /// 2048 güçleri yalnız `*2048` anahtarlarına yazılır: 2048 ekranı
  /// yalnız bu anahtarları okur; `undo`/`shuffle`/`pair` anahtarlarını
  /// okuyan lib kodu yoktur. Çift-yazım kaldırıldı.
  static const Map<String, String> _power2048Keys = {
    'undo': 'undo2048',
    'shuffle': 'shuffle2048',
    'pair': 'pair2048',
  };

  Future<void> _grantPowerStock(String powerKey, [int amount = 1]) async {
    final targetKey = _power2048Keys[powerKey] ?? powerKey;
    await _pm.incrementPowerCount(targetKey, amount);
  }

  /// IAP satın alma: ortak kilit + try/catch. Başlatma başarısında EK
  /// ÖDEME YAPILMAZ — teslimat yalnız satın alma akışından
  /// (`IapService` purchase stream) gelir; `purchase()` dönüşü yalnız
  /// başlatmanın kabul edildiğini söyler.
  Future<void> _buyIapProduct({
    required String productId,
    required String successToast,
  }) async {
    if (_purchaseBusy) return;
    _purchaseBusy = true;
    bool ok;
    try {
      ok = await IapService.instance.purchase(productId);
    } catch (_) {
      ok = false;
    } finally {
      _purchaseBusy = false;
    }
    if (!mounted) return;
    setState(() {});
    widget.onStateChanged?.call();
    _showToast(
      ok ? successToast : context.l10n.shopStoreUnavailableToast,
    );
  }

  Future<void> _watchFreeChestAd() async {
    // Ödüllü reklam SDK'sı kurulu değil (IapService.rewardedAdsAvailable
    // `false`): reklam gösterilemez ve ödül verilmez. Gerçek ödüllü
    // reklam SDK'sı eklendiğinde bu yöntem gerçek reklam akışına
    // bağlanmalıdır; sahte (mock) reklamla ödül verilmez.
    _showToast(context.l10n.rewardedAdsComingSoon);
  }

  Future<void> _buyCoinItem({
    required String toastMsg,
    required int cost,
    FutureOr<void> Function()? onSuccess,
  }) async {
    if (_purchaseBusy) return;
    _purchaseBusy = true;
    var spent = false;
    try {
      spent = await _pm.spendCoins(cost);
      if (!spent) {
        if (mounted) {
          _showToast(context.l10n.shopNotEnoughGoldToast);
        }
        return;
      }
      await onSuccess?.call();
    } catch (_) {
      if (spent) {
        // Ödeme-sonrası bağış hatası: coin iade edilir. PM'de ayrı
        // refundCoins API'si yok; iade addCoins ile yapılır.
        try {
          await _pm.addCoins(cost);
        } catch (_) {}
        if (mounted) {
          _showToast(context.l10n.shopPurchaseFailedRefundToast);
        }
      } else if (mounted) {
        _showToast(context.l10n.errorGeneric);
      }
      return;
    } finally {
      _purchaseBusy = false;
    }
    if (!mounted) return;
    setState(() {});
    widget.onStateChanged?.call();
    _showToast(toastMsg);
  }

  Widget _buildStatusBar() {
    return SizedBox(
      height: 35.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Transform.translate(
              offset: const Offset(-0.5, 0),
              child: const Text(
                '09:41',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  fontVariations: [FontVariation('wght', 820)],
                  color: Color(0xFF141B2A),
                  height: 1.4,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CustomPaint(
                  size: Size(15, 15),
                  painter: _ShopSignalPainter(),
                ),
                SizedBox(width: 5),
                CustomPaint(
                  size: Size(15, 15),
                  painter: _ShopBatteryPainter(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_pm, EnergyService.instance]),
      builder: (context, _) {
        final rawCoins = _pm.coins;
        final l10n = context.l10n;
        final coinsText = _formatNumber(rawCoins);
        final mqTop = MediaQuery.of(context).padding.top;
        final topPad = mqTop > 0 ? mqTop : 35.0;
        final parentHasExtendBody =
            Scaffold.maybeOf(context)?.widget.extendBody == true;
        final renderDock = widget.showBottomNav && !parentHasExtendBody;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          body: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mqTop == 0)
                    _buildStatusBar()
                  else
                    SizedBox(height: topPad),
                  // .pillbar { display:flex; align-items:center; gap:8px; padding:8px 14px 4px; height:47px }
                  SizedBox(
                    height: 47,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(2, 2, 2, 0),
                            child: Text(
                              l10n.navShop,
                              style: TextStyle(
                                fontFamily: 'Baloo 2',
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                fontVariations: [FontVariation('wght', 800)],
                                letterSpacing: -0.05,
                                color: Color(0xFF141B2A),
                                height: 1.0,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Dark coin pill with +
                          Semantics(
                            button: true,
                            label: context.l10n.addCoinPackLabel,
                            child: GestureDetector(
                              onTap: () =>
                                  _showToast(l10n.shopAddedCoinPackToast),
                            child: Container(
                              height: 35,
                              padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF33363C),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x59000000),
                                    offset: Offset(0, 3),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/design/ui/res_coin.png',
                                    width: 25,
                                    height: 25,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                  ),
                                  const SizedBox(width: 6),
                                  Transform.translate(
                                    offset: const Offset(0, -0.5),
                                    child: Text(
                                      coinsText,
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        fontVariations: [
                                          FontVariation('wght', 900)
                                        ],
                                        letterSpacing: -0.14,
                                        color: Colors.white,
                                        height: 1.15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00C853),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '+',
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          fontVariations: [
                                            FontVariation('wght', 900)
                                          ],
                                          color: Color(0xFF04140A),
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ),
                          const SizedBox(width: 8),
                          // Dark star pill (86)
                          Container(
                            height: 35,
                            padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF33363C),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x59000000),
                                  offset: Offset(0, 3),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/design/ui/res_star.png',
                                  width: 25,
                                  height: 25,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                                const SizedBox(width: 6),
                                Transform.translate(
                                  offset: const Offset(0, -0.5),
                                  child: const Text(
                                    '86',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      fontVariations: [
                                        FontVariation('wght', 900)
                                      ],
                                      color: Colors.white,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Scrollable Shop Content
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 120),
                      children: [
                        // .shop-banner (rect: x=12, y=92, w=406, h=119)
                        Container(
                          height: 119.0,
                          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: const LinearGradient(
                              begin: Alignment(-0.877, -1.727),
                              end: Alignment(0.877, 1.727),
                              stops: [0.0, 0.55, 1.0],
                              colors: [
                                Color(0xFFB8860B),
                                Color(0xFFFFB800),
                                Color(0xFFFF6B35),
                              ],
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 66,
                                height: 66,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: Transform.translate(
                                        offset: const Offset(0, 4),
                                        child: ImageFiltered(
                                          imageFilter: ui.ImageFilter.blur(
                                            sigmaX: 3.0,
                                            sigmaY: 3.0,
                                          ),
                                          child: ColorFiltered(
                                            colorFilter:
                                                const ColorFilter.mode(
                                              Color(0x4D000000),
                                              BlendMode.srcIn,
                                            ),
                                            child: Image.asset(
                                              'assets/icons2/discount.png',
                                              width: 66,
                                              height: 66,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Image.asset(
                                      'assets/icons2/discount.png',
                                      width: 66,
                                      height: 66,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: 20.6,
                                        bottom: 23.6,
                                      ),
                                      child: Text(
                                        l10n.shopGoldenWeekendTitle,
                                        style: TextStyle(
                                          fontFamily: 'Baloo 2',
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          fontVariations: [
                                            FontVariation('wght', 800)
                                          ],
                                          letterSpacing: -0.02,
                                          color: Colors.white,
                                          height: 1.55,
                                          shadows: [
                                            Shadow(
                                              color: Color(0x4D784000),
                                              offset: Offset(0, 2),
                                              blurRadius: 0,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      l10n.shopGoldenWeekendSubtitle,
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        fontVariations: [
                                          FontVariation('wght', 700)
                                        ],
                                        letterSpacing: 0.0,
                                        color: Color(0xF2FFFFFF),
                                        height: 1.55,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // .free-ad-card (rect: x=12, y=221, w=406, h=185)
                        Container(
                          height: 185.0,
                          margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFFFFB800),
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40B97A00),
                                offset: Offset(0, 6),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/icons2/chest_wood.png',
                                width: 62,
                                height: 62,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 20.0,
                                        bottom: 22.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Transform.translate(
                                            offset: const Offset(0, -0.5),
                                            child: Text(
                                              l10n.shopFreeChestTitle,
                                              style: TextStyle(
                                                fontFamily: 'Baloo 2',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                fontVariations: [
                                                  FontVariation('wght', 800)
                                                ],
                                                letterSpacing: -0.02,
                                                color: Color(0xFF141B2A),
                                                height: 1.55,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      l10n.shopFreeChestDesc,
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        fontVariations: [
                                          FontVariation('wght', 700)
                                        ],
                                        letterSpacing: -0.025,
                                        color: Color(0xFF66738A),
                                        height: 1.55,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Transform.translate(
                                offset: const Offset(0, 0.5),
                                child: Semantics(
                                  button: true,
                                  label: l10n.watchAdChestLabel,
                                  child: GestureDetector(
                                    onTap: _watchFreeChestAd,
                                    child: Container(
                                      width: 97.1,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDF0F6),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFD5DAE4),
                                          width: 2,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x26000000),
                                            offset: Offset(0, 4),
                                            blurRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFFD5DAE4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              l10n.comingSoon,
                                              maxLines: 1,
                                              softWrap: false,
                                              style: TextStyle(
                                                fontFamily: 'Baloo 2',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                fontVariations: [
                                                  FontVariation('wght', 800)
                                                ],
                                                color: Color(0xFF9AA3B2),
                                                height: 1.1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Section: Enerji
                        _buildSecHead(
                          title: l10n.shopEnergyTitle,
                          rightText: l10n.shopEnergyRefillNote,
                          onTapRight: () => _showToast(
                            l10n.shopEnergyRegenToast,
                          ),
                        ),
                        _buildShopGridRow(
                          _ShopItemData(
                            badge: l10n.shopEnergyTitle,
                            badgeGold: false,
                            iconAsset: 'assets/design/ui/icon_heart_exact.png',
                            title: l10n.shopItemEnergyPackTitle,
                            desc: l10n.shopItemEnergyPackDesc,
                            priceText: '₺29,99',
                            isCoinPrice: false,
                            onTap: () => _buyIapProduct(
                              productId: 'energy_pack_10',
                              successToast: l10n.shopEnergyAddedToast,
                            ),
                          ),
                          _ShopItemData(
                            badge: l10n.shopBadgeBest,
                            badgeGold: true,
                            iconAsset: 'assets/icons2/potion_health.png',
                            title: l10n.shopItemEnergyDepotTitle,
                            desc: l10n.shopItemEnergyDepotDesc,
                            priceText: '₺59,99',
                            isCoinPrice: false,
                            onTap: () => _buyIapProduct(
                              productId: 'full_energy',
                              successToast: l10n.shopEnergyFullToast,
                            ),
                          ),
                        ),

                        // Section: Güçlendiriciler
                        _buildSecHead(
                          title: l10n.shopPowerUpsTitle,
                          rightText: l10n.shopPowerUpsNote,
                          onTapRight: () => _showToast(
                            l10n.shopPowerUpModeOnlyToast,
                          ),
                        ),
                        for (final group in _powerGroups(l10n))
                          _buildPowGroup(group),

                        // Extra shop grid after #shopPowers
                        _buildShopGridRow(
                          _ShopItemData(
                            badge: l10n.shopBadgeDeal,
                            badgeGold: true,
                            iconAsset: 'assets/design/ui/res_star.png',
                            title: l10n.shopItemStarPackTitle,
                            desc: l10n.shopItemStarPackDesc,
                            priceText: '₺149,99',
                            isCoinPrice: false,
                            onTap: () => _buyIapProduct(
                              productId: 'mega_starter_pack',
                              successToast: l10n.shopAddedStarPackToast,
                            ),
                          ),
                          _ShopItemData(
                            badge: null,
                            badgeGold: false,
                            iconAsset: 'assets/icons2/gift_box.png',
                            title: l10n.shopItemSurpriseBoxTitle,
                            desc: l10n.shopItemSurpriseBoxDesc,
                            priceText: '350',
                            isCoinPrice: true,
                            onTap: () => _buyCoinItem(
                              toastMsg: l10n.shopAddedSurpriseBoxToast,
                              cost: 350,
                              onSuccess: () =>
                                  _pm.grantArcadeDrop(slipper: 1, spray: 1),
                            ),
                          ),
                        ),

                        // Section: Coin Paketleri
                        _buildSecHead(title: l10n.shopCoinPacksTitle),
                        _buildShopGridRow(
                          _ShopItemData(
                            badge: null,
                            badgeGold: false,
                            iconAsset: 'assets/icons2/coin_stack.png',
                            title: l10n.shopItemHandfulTitle,
                            desc: l10n.shopItemHandfulDesc,
                            priceText: '₺59,99',
                            isCoinPrice: false,
                            onTap: () => _buyIapProduct(
                              productId: 'coins_mid',
                              successToast: l10n.shopAddedCoinPackToast,
                            ),
                          ),
                          _ShopItemData(
                            badge: l10n.shopBadgeBest,
                            badgeGold: false,
                            iconAsset: 'assets/icons2/money_bag.png',
                            title: l10n.shopItemCrateTitle,
                            desc: l10n.shopItemCrateDesc,
                            priceText: '₺249,99',
                            isCoinPrice: false,
                            onTap: () => _buyIapProduct(
                              productId: 'coins_big',
                              successToast: l10n.shopAddedCoinPackToast,
                            ),
                          ),
                          topPadding: 8,
                        ),

                        // Section: Sandıklar ve İksirler
                        _buildSecHead(title: l10n.shopChestsAndPotionsTitle),
                        _buildShopGridRow(
                          _ShopItemData(
                            badge: null,
                            badgeGold: false,
                            iconAsset: 'assets/icons2/chest_wood.png',
                            title: l10n.shopItemWoodenChestTitle,
                            desc: l10n.shopItemWoodenChestDesc,
                            priceText: '200',
                            isCoinPrice: true,
                            onTap: () => _buyCoinItem(
                              toastMsg: l10n.shopAddedWoodenChestToast,
                              cost: 200,
                              onSuccess: () =>
                                  _pm.grantArcadeDrop(coins: 250, slipper: 1),
                            ),
                          ),
                          _ShopItemData(
                            badge: l10n.shopBadgeLucky,
                            badgeGold: true,
                            iconAsset: 'assets/icons2/chest_gold.png',
                            title: l10n.shopItemGoldenChestTitle,
                            desc: l10n.shopItemGoldenChestDesc,
                            priceText: '750',
                            isCoinPrice: true,
                            onTap: () => _buyCoinItem(
                              toastMsg: l10n.shopAddedGoldenChestToast,
                              cost: 750,
                              onSuccess: () => _pm.grantArcadeDrop(
                                coins: 1200,
                                f16: 1,
                                spray: 2,
                                slipper: 2,
                              ),
                            ),
                          ),
                          topPadding: 8,
                          bottomPadding: 12,
                        ),
                        _buildShopGridRow(
                          _ShopItemData(
                            badge: null,
                            badgeGold: false,
                            iconAsset: 'assets/icons2/boost_coins.png',
                            title: l10n.shopItemDoubleCoinTitle,
                            desc: l10n.shopItemDoubleCoinDesc,
                            priceText: '400',
                            isCoinPrice: true,
                            onTap: () => _buyCoinItem(
                              toastMsg: l10n.shopAddedDoubleCoinToast,
                              cost: 400,
                              onSuccess: () => _grantPowerStock('x2', 2),
                            ),
                          ),
                          _ShopItemData(
                            badge: null,
                            badgeGold: false,
                            iconAsset: 'assets/icons2/potion_luck.png',
                            title: l10n.shopItemLuckPotionTitle,
                            desc: l10n.shopItemLuckPotionDesc,
                            priceText: '180',
                            isCoinPrice: true,
                            onTap: () => _buyCoinItem(
                              toastMsg: l10n.shopAddedLuckPotionToast,
                              cost: 180,
                              onSuccess: () => _grantPowerStock('pair', 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (renderDock)
                const Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  height: 84,
                  child: _ShopFloatingDock(activeIndex: 3),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSecHead({
    required String title,
    String? rightText,
    VoidCallback? onTapRight,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Baloo 2',
              fontSize: 19,
              fontWeight: FontWeight.w800,
              fontVariations: [FontVariation('wght', 800)],
              letterSpacing: -0.04,
              color: Color(0xFF141B2A),
              height: 1.12,
            ),
          ),
          const Spacer(),
          if (rightText != null)
            Semantics(
              button: true,
              label: rightText,
              child: GestureDetector(
                onTap: onTapRight,
                child: Text(
                  rightText,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontVariations: [FontVariation('wght', 900)],
                    letterSpacing: -0.06,
                    color: Color(0xFFE01E5A),
                    height: 1.55,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShopGridRow(
    _ShopItemData left,
    _ShopItemData right, {
    double topPadding = 0,
    double bottomPadding = 8,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPadding, 12, bottomPadding),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildShopCard(left)),
            const SizedBox(width: 12),
            Expanded(child: _buildShopCard(right)),
          ],
        ),
      ),
    );
  }

  Widget _buildShopCard(_ShopItemData item) {
    final locale = Localizations.localeOf(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 277.5),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12141B2A),
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: const Offset(0.5, -0.7),
                    child: Image.asset(
                      item.iconAsset,
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 25.28, bottom: 23.28),
                    child: Text(
                      _trUpper(item.title, locale),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Baloo 2',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontVariations: [FontVariation('wght', 800)],
                        letterSpacing: -0.05,
                        color: Color(0xFF141B2A),
                        height: 1.55,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9.44),
                    child: Text(
                      item.desc,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontVariations: [FontVariation('wght', 700)],
                        letterSpacing: -0.03,
                        color: Color(0xFF66738A),
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
              Semantics(
                button: true,
                label: context.l10n.shopBuyItemLabel(item.title, item.priceText),
                excludeSemantics: true,
                child: GestureDetector(
                  // CustomPaint katmanı üzerinden dokunma
                  // ulaşmıyordu (canlı prob: düğme ölü); tüm düğme
                  // yüzeyi dokunulabilir olsun (bulgu #16).
                  behavior: HitTestBehavior.opaque,
                  onTap: item.onTap,
                  child: CustomPaint(
                  painter: _ShopBtnShadowPainter(
                    solidColor: item.isCoinPrice
                        ? const Color(0xFFB97A00)
                        : const Color(0xFF7E0A2E),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: item.isCoinPrice
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.0, 0.55, 1.0],
                              colors: [
                                Color(0xFFFFCF3F),
                                Color(0xFFFFB800),
                                Color(0xFFF59E00),
                              ],
                            )
                          : const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.0, 0.55, 1.0],
                              colors: [
                                Color(0xFFF4538B),
                                Color(0xFFE01E5A),
                                Color(0xFFB80F42),
                              ],
                            ),
                    ),
                    child: Center(
                      child: item.isCoinPrice
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/design/ui/res_coin.png',
                                  width: 21,
                                  height: 21,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  item.priceText,
                                  style: const TextStyle(
                                    fontFamily: 'Baloo 2',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    fontVariations: [
                                      FontVariation('wght', 800)
                                    ],
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                    height: 1.1,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x59000000),
                                        offset: Offset(0, 1),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Transform.translate(
                              offset: const Offset(-0.3, 0.5),
                              child: Text(
                                item.priceText,
                                style: const TextStyle(
                                  fontFamily: 'Baloo 2',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  fontVariations: [FontVariation('wght', 750)],
                                  color: Colors.white,
                                  letterSpacing: 0.05,
                                  height: 1.1,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x665A001E),
                                      offset: Offset(0, 1),
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              ),
            ],
          ),
        ),
        if (item.badge != null)
          Positioned(
            top: 9.8,
            left: 10,
            child: Transform.rotate(
              angle: -4 * math.pi / 180,
              child: CustomPaint(
                painter: const _ShopBadgeShadowPainter(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: item.badgeGold
                        ? const Color(0xFFFFB800)
                        : const Color(0xFFE01E5A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Transform.translate(
                    offset: const Offset(0, -0.7),
                    child: Text(
                      item.badge!,
                      style: TextStyle(
                        fontFamily: 'Baloo 2',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontVariations: const [FontVariation('wght', 800)],
                        letterSpacing: 0.45,
                        color: item.badgeGold
                            ? const Color(0xFF4A2E00)
                            : Colors.white,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPowGroup(_ModePowerGroup group) {
    final locale = Localizations.localeOf(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
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
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFEDF0F6),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: const Offset(0, -0.5),
                  child: Image.asset(
                    group.iconAsset,
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(width: 9),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 19.615,
                    bottom: 20.615,
                  ),
                  child: Text(
                    _trUpper(group.modeName, locale),
                    style: const TextStyle(
                      fontFamily: 'Baloo 2',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      fontVariations: [FontVariation('wght', 800)],
                      letterSpacing: -0.05,
                      color: Color(0xFF141B2A),
                      height: 1.55,
                    ),
                  ),
                ),
                const Spacer(),
                Transform.translate(
                  offset: const Offset(0, -0.5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3D1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      context.l10n.shopPowerGroupBonusCount(group.powers.length),
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        fontVariations: [FontVariation('wght', 900)],
                        letterSpacing: -0.05,
                        color: Color(0xFF8A6D00),
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (int i = 0; i < group.powers.length; i++)
            _buildPowRow(
              group: group,
              pow: group.powers[i],
              showBottomBorder: i < group.powers.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildPowRow({
    required _ModePowerGroup group,
    required _PowerRowItem pow,
    required bool showBottomBorder,
  }) {
    return CustomPaint(
      foregroundPainter: showBottomBorder
          ? const _DashedBottomBorderPainter(color: Color(0xFFE4E8F2))
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Image.asset(
                  pow.iconAsset,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pow.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Baloo 2',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      fontVariations: [FontVariation('wght', 800)],
                      color: Color(0xFF141B2A),
                      height: 1.15,
                    ),
                  ),
                  Text(
                    context.l10n.shopPowerUpDescModeSuffix(pow.desc, group.modeName),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      fontVariations: [FontVariation('wght', 700)],
                      color: Color(0xFF66738A),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Semantics(
              button: true,
              label: context.l10n.shopBuyPowerUpLabel(pow.name, pow.cost),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => _buyCoinItem(
                  toastMsg: context.l10n.shopPowerUpAddedToCartToast(pow.name, group.modeName),
                cost: pow.cost,
                onSuccess: () => _grantPowerStock(pow.id, 1),
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
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
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFFB97A00),
                      offset: Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/design/ui/res_coin.png',
                      width: 19,
                      height: 19,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${pow.cost}',
                      style: const TextStyle(
                        fontFamily: 'Baloo 2',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontVariations: [FontVariation('wght', 800)],
                        color: Colors.white,
                        height: 1.15,
                        shadows: [
                          Shadow(
                            color: Color(0x59784000),
                            offset: Offset(0, 1),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef FutureOr<T> = Future<T>?;

class _ModePowerGroup {
  final String modeName;
  final String iconAsset;
  final List<_PowerRowItem> powers;

  const _ModePowerGroup({
    required this.modeName,
    required this.iconAsset,
    required this.powers,
  });
}

class _PowerRowItem {
  final String id;
  final String name;
  final String iconAsset;
  final String desc;
  final int cost;

  const _PowerRowItem({
    required this.id,
    required this.name,
    required this.iconAsset,
    required this.desc,
    required this.cost,
  });
}

class _ShopItemData {
  final String? badge;
  final bool badgeGold;
  final String iconAsset;
  final String title;
  final String desc;
  final String priceText;
  final bool isCoinPrice;
  final VoidCallback onTap;

  const _ShopItemData({
    required this.badge,
    required this.badgeGold,
    required this.iconAsset,
    required this.title,
    required this.desc,
    required this.priceText,
    required this.isCoinPrice,
    required this.onTap,
  });
}

class _DashedBottomBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBottomBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;
    final y = size.height - 0.5;
    while (startX < size.width) {
      final endX = math.min(startX + dashWidth, size.width);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBottomBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ShopSignalPainter extends CustomPainter {
  const _ShopSignalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF141B2A)
      ..style = PaintingStyle.fill;
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawRect(const Rect.fromLTWH(2, 17, 3, 4), paint);
    canvas.drawRect(const Rect.fromLTWH(7.5, 13, 3, 8), paint);
    canvas.drawRect(const Rect.fromLTWH(13, 9, 3, 12), paint);
    canvas.drawRect(const Rect.fromLTWH(18.5, 5, 3, 16), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShopSignalPainter oldDelegate) => false;
}

class _ShopBatteryPainter extends CustomPainter {
  const _ShopBatteryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    final strokePaint = Paint()
      ..color = const Color(0xFF141B2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.5, 8, 17, 9),
        const Radius.circular(2.5),
      ),
      strokePaint,
    );
    final fillPaint = Paint()
      ..color = const Color(0xFF141B2A)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4.5, 10, 10, 5),
        const Radius.circular(1),
      ),
      fillPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShopBatteryPainter oldDelegate) => false;
}

class _ShopBtnShadowPainter extends CustomPainter {
  final Color solidColor;
  const _ShopBtnShadowPainter({required this.solidColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    // CSS: 0 5px 0 #7E0A2E, 0 10px 18px rgba(0, 0, 0, 0.28)
    // Paint blurred shadow first, then solid 5px shadow on top
    canvas.drawRRect(
      rrect.shift(const Offset(0, 10)),
      Paint()
        ..color = const Color(0x47000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9.0),
    );
    canvas.drawRRect(
      rrect.shift(const Offset(0, 5)),
      Paint()..color = solidColor,
    );
  }

  @override
  bool shouldRepaint(covariant _ShopBtnShadowPainter oldDelegate) =>
      oldDelegate.solidColor != solidColor;
}

class _ShopBadgeShadowPainter extends CustomPainter {
  const _ShopBadgeShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    // CSS: 0 3px 8px rgba(0, 0, 0, 0.3)
    canvas.drawRRect(
      rrect.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x4D000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
  }

  @override
  bool shouldRepaint(covariant _ShopBadgeShadowPainter oldDelegate) => false;
}

class _ShopFloatingDock extends StatelessWidget {
  final int activeIndex;
  const _ShopFloatingDock({required this.activeIndex});

  // S3#27: dock etiketleri tek kaynaktan (nav* anahtarları); bu
  // dosyadaki tekrar kaldırıldı. İkonlar ve rotalar const kalır,
  // etiketler build'de l10n'den okunur.
  static const _tabIcons = [
    'assets/icons2/home.png',
    'assets/icons2/target.png',
    'assets/icons2/paw.png',
    'assets/icons2/cart.png',
    'assets/icons2/trophy.png',
  ];

  static const _tabRoutes = ['hub', 'modes', 'tiers', 'shop', 'scores'];

  void _onTapTab(BuildContext context, int index) {
    AudioManager().playPop();
    if (index == activeIndex) return;
    final routeName = '/${_tabRoutes[index]}';
    try {
      Navigator.of(context).pushReplacementNamed(routeName);
    } catch (_) {}
  }

  static Widget _buildIconWithDropShadow(String asset, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(0, 2),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0x47000000),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    asset,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
          Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ],
      ),
    );
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
    return CustomPaint(
      painter: const _ShopDockOuterShadowPainter(),
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 3),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.72],
            colors: [Color(0xFF1E2538), Color(0xFF080B12)],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth =
                  (constraints.maxWidth - 14.0).clamp(100.0, 410.0);
              final tabW = usableWidth / _tabIcons.length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: _ShopDockSurfacePainter(),
                    ),
                  ),
                  Positioned(
                    left: 26,
                    right: 26,
                    top: 5,
                    height: 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x33FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 7.0 + activeIndex * tabW,
                    top: 7.0,
                    width: tabW,
                    height: 64.0,
                    child: CustomPaint(
                      painter: const _ShopDockIndShadowPainter(),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xF0FFFFFF),
                            width: 2,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.40, 0.74, 1.0],
                            colors: [
                              Color(0xFFFFE27A),
                              Color(0xFFFFB800),
                              Color(0xFFFF6B35),
                              Color(0xFFE01E5A),
                            ],
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: CustomPaint(
                                  painter: _ShopDockActiveIndInsetPainter(),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                right: 8,
                                top: 2,
                                height: 9,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0x61FFFFFF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(7),
                    child: Row(
                      children: List.generate(_tabIcons.length, (i) {
                        final active = i == activeIndex;
                        return Expanded(
                          child: Semantics(
                            button: true,
                            label: labels[i],
                            selected: active,
                            child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _onTapTab(context, i),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0x1FFFB800)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: SizedBox(
                                height: 64,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.topCenter,
                                  children: [
                                    if (active)
                                      Positioned(
                                        top: 1.8,
                                        width: 42.4,
                                        height: 42.4,
                                        child: CustomPaint(
                                          painter:
                                              const _ShopDockActiveCircleShadowPainter(),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: ClipOval(
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  const Positioned.fill(
                                                    child: CustomPaint(
                                                      painter:
                                                          _ShopDockCircleInsetPainter(
                                                        dy: -4.24,
                                                        color: Color(0x1F080B12),
                                                      ),
                                                    ),
                                                  ),
                                                  Transform.translate(
                                                    offset: const Offset(
                                                        0.5, 0.5),
                                                    child:
                                                        _buildIconWithDropShadow(
                                                      _tabIcons[i],
                                                      35,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Positioned(
                                        top: 7.0,
                                        width: 40.0,
                                        height: 40.0,
                                        child: CustomPaint(
                                          painter:
                                              const _ShopDockInactiveCircleShadowPainter(),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(0x17FFFFFF),
                                              border: Border.all(
                                                color: const Color(0x2EFFFFFF),
                                                width: 2,
                                              ),
                                            ),
                                            child: ClipOval(
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  const Positioned.fill(
                                                    child: CustomPaint(
                                                      painter:
                                                          _ShopDockCircleInsetPainter(
                                                        dy: 2.0,
                                                        color: Color(0x29FFFFFF),
                                                      ),
                                                    ),
                                                  ),
                                                  Transform.translate(
                                                    offset: const Offset(
                                                        0.5, 0.5),
                                                    child:
                                                        _buildIconWithDropShadow(
                                                      _tabIcons[i],
                                                      33,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: 46.0,
                                      height: 16.0,
                                      child: Center(
                                        child: Text(
                                          labels[i],
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontFamily: 'Baloo 2',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            fontVariations: const [
                                              FontVariation('wght', 600)
                                            ],
                                            height: 1.0,
                                            letterSpacing: -0.02,
                                            color: active
                                                ? Colors.white
                                                : const Color(0xA8FFFFFF),
                                            shadows: active
                                                ? const [
                                                    Shadow(
                                                      color: Color(0x737A082E),
                                                      offset: Offset(0, 2),
                                                      blurRadius: 0,
                                                    ),
                                                  ]
                                                : null,
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
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ShopDockOuterShadowPainter extends CustomPainter {
  const _ShopDockOuterShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    // CSS: 0 7px 0 rgba(8,11,18,.28), 0 22px 38px rgba(8,11,18,.48)
    canvas.drawRRect(
      rrect.shift(const Offset(0, 22)),
      Paint()
        ..color = const Color(0x7A080B12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 19.0),
    );
    canvas.drawRRect(
      rrect.shift(const Offset(0, 7)),
      Paint()..color = const Color(0x47080B12),
    );
  }

  @override
  bool shouldRepaint(covariant _ShopDockOuterShadowPainter oldDelegate) =>
      false;
}

class _ShopDockIndShadowPainter extends CustomPainter {
  const _ShopDockIndShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    // CSS: 0 5px 0 rgba(0,0,0,.30), 0 10px 18px rgba(224,30,90,.28)
    canvas.drawRRect(
      rrect.shift(const Offset(0, 10)),
      Paint()
        ..color = const Color(0x47E01E5A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9.0),
    );
    canvas.drawRRect(
      rrect.shift(const Offset(0, 5)),
      Paint()..color = const Color(0x4D000000),
    );
  }

  @override
  bool shouldRepaint(covariant _ShopDockIndShadowPainter oldDelegate) => false;
}

class _ShopDockActiveCircleShadowPainter extends CustomPainter {
  const _ShopDockActiveCircleShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // CSS: 0 4px 0 rgba(122,8,46,.35), 0 7px 12px rgba(0,0,0,.24)
    canvas.drawOval(
      rect.shift(const Offset(0, 7)),
      Paint()
        ..color = const Color(0x3D000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
    );
    canvas.drawOval(
      rect.shift(const Offset(0, 4)),
      Paint()..color = const Color(0x597A082E),
    );
  }

  @override
  bool shouldRepaint(
          covariant _ShopDockActiveCircleShadowPainter oldDelegate) =>
      false;
}

class _ShopDockInactiveCircleShadowPainter extends CustomPainter {
  const _ShopDockInactiveCircleShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addOval(Offset.zero & size);
    // CSS: 0 3px 0 rgba(0,0,0,.30) — clipped outside the semi-transparent circle
    final crescent = Path.combine(
      PathOperation.difference,
      outer.shift(const Offset(0, 3)),
      outer,
    );
    canvas.drawPath(crescent, Paint()..color = const Color(0x4D000000));
  }

  @override
  bool shouldRepaint(
          covariant _ShopDockInactiveCircleShadowPainter oldDelegate) =>
      false;
}

class _ShopDockSurfacePainter extends CustomPainter {
  const _ShopDockSurfacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.translate(size.width * 0.18, -size.height * 0.30);
    canvas.scale(size.width * 1.20, size.height * 1.60);
    final radialPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1.0,
        const [Color(0x38FFFFFF), Color(0x00FFFFFF)],
        const [0.0, 0.48],
      );
    canvas.drawRect(const Rect.fromLTRB(-2, -2, 2, 2), radialPaint);
    canvas.restore();

    final radius = Radius.circular(size.height / 2);
    final outerPath = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));

    final topInsetPath = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, 3)),
    );
    canvas.drawPath(topInsetPath, Paint()..color = const Color(0x29FFFFFF));

    final bottomInsetPath = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, -7)),
    );
    canvas.drawPath(bottomInsetPath, Paint()..color = const Color(0x57000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShopDockActiveIndInsetPainter extends CustomPainter {
  const _ShopDockActiveIndInsetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final outerPath = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));

    final topInset = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, 3)),
    );
    canvas.drawPath(topInset, Paint()..color = const Color(0x8CFFFFFF));

    final bottomInset = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, -6)),
    );
    canvas.drawPath(bottomInset, Paint()..color = const Color(0x3D7A082E));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShopDockCircleInsetPainter extends CustomPainter {
  final double dy;
  final Color color;

  const _ShopDockCircleInsetPainter({required this.dy, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addOval(Offset.zero & size);
    final crescent = Path.combine(
      PathOperation.difference,
      outer,
      outer.shift(Offset(0, dy)),
    );
    canvas.drawPath(crescent, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ShopDockCircleInsetPainter oldDelegate) =>
      oldDelegate.dy != dy || oldDelegate.color != color;
}
