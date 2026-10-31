import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../theme/lululu_theme.dart';
import 'ad_mock.dart';
import 'lululu_press.dart';

/// MAĞAZA — prototip (tasarim/lululu_tasarim.html #scr-shop) ile birebir.
///
/// Gerçek para ürünleri mock (toast "yakında"); enerji ürünleri
/// EnergyService üzerinden GERÇEKTEN işler.
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
          final curved =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
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

/// assets/design/ ikon klasörü — mağaza ürün görselleri.
const _icons = 'assets/design/icons/extra_icons/All_Icons';
const _ui = 'assets/design/ui';

class _ShopScreenState extends State<ShopScreen> {
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _freeChest() async {
    final ok = await showRewardedAdMock(
      context,
      rewardLabel: 'ÜCRETSİZ SANDIK',
    );
    if (!mounted) return;
    if (ok) {
      AudioManager().playWin();
      _toast('Kazandın: Ücretsiz Ahşap Sandık + rastgele 1 güçlendirici');
    }
  }

  void _mockPay(String title) {
    AudioManager().playPop();
    _toast('$title çok yakında — mock ödeme');
  }

  void _buyEnergyPack() {
    EnergyService.instance.addEnergy(10);
    AudioManager().playWin();
    _toast('Enerji Paketi: +10 enerji (mock ödeme)');
  }

  void _buyEnergyDepot() {
    final energy = EnergyService.instance;
    final missing = EnergyService.maxEnergy - energy.energy;
    if (missing <= 0) {
      _toast('Kalbin zaten 30/30 dolu!');
      return;
    }
    energy.addEnergy(missing);
    AudioManager().playWin();
    _toast('Enerji Deposu: kalp 30/30 doldu! (mock ödeme)');
  }

  void _mockCoinItem(String title) {
    AudioManager().playPop();
    _toast('$title alındı (mock)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LululuColors.paper,
      appBar: AppBar(
        backgroundColor: LululuColors.paper,
        foregroundColor: LululuColors.inkDark,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedded,
        title: Text(
          'MAĞAZA',
          style: GoogleFonts.exo2(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Banner(),
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'ÜCRETSİZ SANDIK',
            note: 'REKLAM',
            noteAccent: LululuColors.toxicNeon,
          ),
          _ProductCard(
            imagePath: '$_icons/wooden_chest.png',
            fallbackIcon: Icons.card_giftcard_rounded,
            accent: LululuColors.toxicNeon,
            title: 'ÜCRETSİZ SANDIK',
            subtitle:
                'Reklam izle, ücretsiz Ahşap Sandık + rastgele 1 güçlendirici kazan.',
            action: _IzleButton(onTap: _freeChest),
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'ENERJİ',
            note: '5 dk = +1 kalp',
            noteAccent: LululuColors.cyberFuchsia,
          ),
          ValueListenableBuilder<int>(
            valueListenable: EnergyService.instance.energyNotifier,
            builder: (context, energy, _) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: LululuColors.cyberFuchsia
                      .withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(LululuRadii.chip),
                  border: Border.all(
                    color: LululuColors.cyberFuchsia
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      '$_icons/health_heart.png',
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.favorite_rounded,
                        color: LululuColors.cyberFuchsia,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kalbin: $energy/${EnergyService.maxEnergy}',
                        style: GoogleFonts.exo2(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: LululuColors.inkDark,
                        ),
                      ),
                    ),
                    Text(
                      energy >= EnergyService.maxEnergy
                          ? 'DOLU'
                          : 'DOLUYOR',
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: LululuColors.mutedTitanium,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          _ProductCard(
            imagePath: '$_icons/energy_boost.png',
            fallbackIcon: Icons.bolt_rounded,
            accent: LululuColors.liquidGold,
            title: 'ENERJİ PAKETİ',
            subtitle: '+10 enerji · anında dolar',
            action: _BuyButton(
              label: '₺29,99',
              onTap: _buyEnergyPack,
            ),
          ),
          const SizedBox(height: 10),
          _ProductCard(
            imagePath: '$_icons/health_heart.png',
            fallbackIcon: Icons.favorite_rounded,
            accent: LululuColors.cyberFuchsia,
            title: 'ENERJİ DEPOSU',
            subtitle: 'Kalbi 30/30 fulle · tek seferde tam enerji',
            badge: 'EN İYİ',
            badgeColor: LululuColors.liquidGold,
            action: _BuyButton(
              label: '₺59,99',
              onTap: _buyEnergyDepot,
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'GÜÇLENDİRİCİLER'),
          _ProductCard(
            imagePath: '$_icons/energy_boost.png',
            fallbackIcon: Icons.bolt_rounded,
            accent: LululuColors.cyberFuchsia,
            title: 'GÜÇLENDİRİCİLER',
            subtitle: 'Moda özel · 30 çeşit',
            badge: 'FIRSAT',
            badgeColor: LululuColors.toxicNeon,
            action: _BuyButton(
              label: '₺149,99',
              onTap: () => _mockPay('Güçlendiriciler'),
            ),
          ),
          const SizedBox(height: 10),
          _ProductCard(
            imagePath: '$_icons/xp_star.png',
            fallbackIcon: Icons.star_rounded,
            accent: LululuColors.warningSolar,
            title: 'YILDIZ PAKETİ',
            subtitle: '25 yıldız + 1.000 coin',
            badge: 'FIRSAT',
            badgeColor: LululuColors.toxicNeon,
            action: _BuyButton(
              label: '₺149,99',
              onTap: () => _mockPay('Yıldız Paketi'),
            ),
          ),
          const SizedBox(height: 10),
          _ProductCard(
            imagePath: '$_icons/mystery_box.png',
            fallbackIcon: Icons.shuffle_rounded,
            accent: LululuColors.cyberFuchsia,
            title: 'SÜRPRİZ KUTU',
            subtitle: 'Rastgele moddan 1 güçlendirici',
            action: _BuyButton(
              label: '350',
              coinIcon: true,
              onTap: () => _mockCoinItem('Sürpriz Kutu'),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'COİN PAKETLERİ'),
          _ProductCard(
            imagePath: '$_ui/icon_coin.png',
            fallbackIcon: Icons.monetization_on_rounded,
            accent: LululuColors.warningSolar,
            title: 'BİR AVUÇ',
            subtitle: '1.250 coin',
            action: _BuyButton(
              label: '₺59,99',
              onTap: () => _mockPay('Bir Avuç'),
            ),
          ),
          const SizedBox(height: 10),
          _ProductCard(
            imagePath: '$_icons/money_bag.png',
            fallbackIcon: Icons.account_balance_wallet_rounded,
            accent: LululuColors.coralFlare,
            title: 'BİR KASA',
            subtitle: '7.500 coin · +%50 bonus',
            badge: 'EN İYİ',
            badgeColor: LululuColors.liquidGold,
            action: _BuyButton(
              label: '₺249,99',
              onTap: () => _mockPay('Bir Kasa'),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'SANDIKLAR VE İKSİRLER'),
          _ProductCard(
            imagePath: '$_icons/wooden_chest.png',
            fallbackIcon: Icons.inventory_2_rounded,
            accent: LululuColors.coralFlare,
            title: 'AHŞAP SANDIK',
            subtitle: 'Rastgele güçlendirici + coin',
            action: _BuyButton(
              label: '200',
              coinIcon: true,
              onTap: () => _mockCoinItem('Ahşap Sandık'),
            ),
          ),
          const SizedBox(height: 10),
          _ProductCard(
            imagePath: '$_icons/gold_chest.png',
            fallbackIcon: Icons.workspace_premium_rounded,
            accent: LululuColors.liquidGold,
            title: 'ALTIN SANDIK',
            subtitle: 'Garantili nadir ödül içerir',
            badge: 'ŞANSLI',
            badgeColor: LululuColors.cyberFuchsia,
            action: _BuyButton(
              label: '750',
              coinIcon: true,
              onTap: () => _mockCoinItem('Altın Sandık'),
            ),
          ),
          const SizedBox(height: 10),
          _ProductCard(
            imagePath: '$_icons/double_coins.png',
            fallbackIcon: Icons.timer_rounded,
            accent: LululuColors.toxicNeon,
            title: 'ÇİFTE COİN',
            subtitle: '30 dakika boyunca 2× coin',
            action: _BuyButton(
              label: '400',
              coinIcon: true,
              onTap: () => _mockCoinItem('Çifte Coin'),
            ),
          ),
          const SizedBox(height: 10),
          _ProductCard(
            imagePath: '$_icons/luck_potion.png',
            fallbackIcon: Icons.science_rounded,
            accent: LululuColors.cyberFuchsia,
            title: 'ŞANS İKSİRİ',
            subtitle: 'Birleşmede kritik şansı artar',
            action: _BuyButton(
              label: '180',
              coinIcon: true,
              onTap: () => _mockCoinItem('Şans İksiri'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LululuGradients.fuchsiaToGold,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        children: [
          Image.asset(
            '$_icons/limited_offer.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.celebration_rounded,
              color: LululuColors.paper,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALTIN HAFTA SONU',
                  style: GoogleFonts.exo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: LululuColors.paper,
                  ),
                ),
                Text(
                  'Tüm coin paketlerinde %50 bonus',
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: LululuColors.paper,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.note,
    this.noteAccent,
  });

  final String title;
  final String? note;
  final Color? noteAccent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.exo2(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: LululuColors.inkDark,
              ),
            ),
          ),
          if (note != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: (noteAccent ?? LululuColors.mutedTitanium)
                    .withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(LululuRadii.chip),
              ),
              child: Text(
                note!,
                style: GoogleFonts.exo2(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: noteAccent ?? LululuColors.mutedTitanium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.imagePath,
    required this.fallbackIcon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.action,
    this.badge,
    this.badgeColor,
  });

  /// assets/design/ içindeki gerçek dosya (birincil). Yüklenemezse
  /// [fallbackIcon] gösterilir.
  final String imagePath;
  final IconData fallbackIcon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget action;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LululuColors.paper,
        borderRadius: BorderRadius.circular(LululuRadii.card),
        border: Border.all(
          color: LululuColors.mutedTitanium.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(fallbackIcon, color: accent, size: 30),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.exo2(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: LululuColors.inkDark,
                        ),
                      ),
                    ),
                    if (badge != null)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (badgeColor ??
                                  LululuColors.liquidGold)
                              .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge!,
                          style: GoogleFonts.exo2(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: badgeColor ??
                                LululuColors.liquidGold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.label,
    required this.onTap,
    this.coinIcon = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool coinIcon;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 88),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: LululuGradients.fuchsiaToGold,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (coinIcon)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Image.asset(
                  'assets/design/ui/icon_coin.png',
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.monetization_on_rounded,
                    color: LululuColors.paper,
                    size: 16,
                  ),
                ),
              ),
            Text(
              label,
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: LululuColors.paper,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IzleButton extends StatelessWidget {
  const _IzleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 88),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LululuColors.inkDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_circle_fill_rounded,
              color: LululuColors.liquidGold,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'İZLE',
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: LululuColors.paper,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
