import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/iap_service.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';
import 'item_detail_popup.dart';

/// Full-width shop. Dock tab uses [embedded]. Coin pill can still open [ShopDialog.show].
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.embedded = true});

  final bool embedded;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class ShopDialog {
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => const ShopScreen(embedded: false),
        transitionsBuilder: (_, anim, _, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _Offer {
  const _Offer({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.price,
    required this.type,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final int price;
  final String type;
}

class _ShopScreenState extends State<ShopScreen> {
  final progress = ProgressManager();

  static const _offers = <_Offer>[
    _Offer(
      title: 'Aydınlat Hele!',
      subtitle: 'Kongo lazeri alanı temizler',
      icon: Icons.flash_on_rounded,
      accent: LululuColors.liquidGold,
      price: 150,
      type: 'aydinlat',
    ),
    _Offer(
      title: 'Terlik',
      subtitle: 'Bir böceği anında ezer',
      icon: Icons.do_not_step_rounded,
      accent: LululuColors.mysticRuby,
      price: 100,
      type: 'slipper',
    ),
    _Offer(
      title: 'Raid Sprey',
      subtitle: 'Küçük böcekleri buharlaştırır',
      icon: Icons.air_rounded,
      accent: LululuColors.cyberFuchsia,
      price: 80,
      type: 'spray',
    ),
  ];

  int _owned(String type) {
    return switch (type) {
      'aydinlat' => progress.aydinlatCount,
      'slipper' => progress.slipperCount,
      'spray' => progress.sprayCount,
      _ => 0,
    };
  }

  Future<void> _buy(_Offer offer) async {
    if (progress.coins < offer.price) return;
    final ok = await progress.buyBooster(offer.type, offer.price);
    if (ok && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        return DecoratedBox(
          decoration: const BoxDecoration(gradient: LululuGradients.carbonToNavy),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    if (!widget.embedded)
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        color: LululuColors.liquidGold,
                      ),
                    Expanded(
                      child: Text(
                        'DÜKKAN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.exo2(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                          color: LululuColors.liquidGold,
                        ),
                      ),
                    ),
                    _CoinPill(coins: progress.coins),
                  ],
                ),
                const SizedBox(height: 14),
                const _HeroBanner(),
                const SizedBox(height: 16),
                Text(
                  'COİN PAKET · ${IapService.instance.status}',
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.none,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
                const SizedBox(height: 8),
                for (final pack in IapService.packs) ...[
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: LululuColors.liquidGold.withValues(alpha: 0.35),
                      ),
                    ),
                    title: Text(
                      pack.title,
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w800,
                        color: LululuColors.ink,
                      ),
                    ),
                    subtitle: Text(
                      '+${pack.coins} coin · ${pack.priceLabel}',
                      style: GoogleFonts.exo2(
                        color: LululuColors.mutedTitanium,
                        fontSize: 12,
                      ),
                    ),
                    trailing: FilledButton(
                      onPressed: () async {
                        await IapService.instance.purchase(pack.id);
                        if (mounted) setState(() {});
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: LululuColors.liquidGold,
                        foregroundColor: LululuColors.carbonVoid,
                      ),
                      child: Text(
                        'AL',
                        style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Text(
                  'GÜÇLENDİRİCİLER',
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.none,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
                const SizedBox(height: 8),
                for (final offer in _offers) ...[
                  _OfferCard(
                    offer: offer,
                    owned: _owned(offer.type),
                    canBuy: progress.coins >= offer.price,
                    onBuy: () => _buy(offer),
                    onOpen: () {
                      showItemDetailPopup(
                        context,
                        title: offer.title,
                        subtitle: offer.subtitle,
                        description: offer.subtitle,
                        rarityGlow: offer.accent,
                        rarityLabel: 'BOOSTER · ${_owned(offer.type)} adet',
                        valueLabel: 'DEĞER: ${offer.price} coin',
                        art: Icon(offer.icon, size: 56, color: offer.accent),
                        actions: [
                          PopupAction(
                            label: 'SATIN AL',
                            primary: true,
                            enabled: progress.coins >= offer.price,
                            onTap: () => _buy(offer),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LululuGradients.rubyToFuchsia,
        boxShadow: [
          BoxShadow(
            color: LululuColors.cyberFuchsia.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GÜNLÜK KASA',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.exo2(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              decoration: TextDecoration.none,
              color: LululuColors.liquidGold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Terlik, sprey, lazer',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.exo2(
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
              color: LululuColors.carbonVoid,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: LululuColors.spaceNavy,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LululuColors.liquidGold.withValues(alpha: 0.55)),
      ),
      child: Text(
        '$coins',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.exo2(
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
          color: LululuColors.liquidGold,
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.owned,
    required this.canBuy,
    required this.onBuy,
    required this.onOpen,
  });

  final _Offer offer;
  final int owned;
  final bool canBuy;
  final VoidCallback onBuy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LululuColors.spaceNavy,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: offer.accent.withValues(alpha: 0.55)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LululuColors.darkObsidian,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(offer.icon, color: offer.accent, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                        color: LululuColors.liquidGold,
                      ),
                    ),
                    Text(
                      offer.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        height: 1.2,
                        decoration: TextDecoration.none,
                        color: LululuColors.mutedTitanium,
                      ),
                    ),
                    Text(
                      'Stok $owned',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.exo2(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                        color: offer.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                height: 44,
                child: FilledButton(
                  onPressed: canBuy ? onBuy : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: LululuColors.liquidGold,
                    disabledBackgroundColor: LululuColors.darkObsidian,
                    foregroundColor: LululuColors.carbonVoid,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '${offer.price}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                      color: canBuy
                          ? LululuColors.carbonVoid
                          : LululuColors.mutedTitanium,
                    ),
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
