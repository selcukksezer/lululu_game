import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/lululu_theme.dart';

/// Her bonusa özel tek seferlik kullanım efekti.
///
/// OverlayEntry ile oyunun üstüne çizilir; oyunu bloklamaz (~700ms sonra
/// kendini kaldırır). Ses çalmaz — ilgili modun mevcut bonus mantığı kendi
/// sesini çalmaya devam eder, böylece çift ses olmaz.
///
/// [bonusId] eşleşmesi büyük/küçük harf duyarsızdır; tanınmayan id'ler için
/// varsayılan altın parıltı patlaması gösterilir.
Future<void> playBonusFx(
  BuildContext context, {
  required String bonusId,
  required Offset origin,
}) async {
  final key = bonusId.trim().toLowerCase();
  final Widget fx;
  if (key == 'terlik' || key == 'terlik sarsıntısı') {
    fx = const _TerlikFx();
  } else if (key == 'sprey' ||
      key == 'raid' ||
      key == 'raid sprey' ||
      key == 'raid spreyi') {
    fx = const _SpreyFx();
  } else if (key == 'aydınlat' ||
      key == 'aydınlat hele!' ||
      key == 'bomba' ||
      key == 'aydinlat') {
    fx = const _BombaFx();
  } else if (key.contains('yıldırım') ||
      key.contains('yildirim') ||
      key.contains('şimşek') ||
      key.contains('simsek')) {
    fx = const _YildirimFx();
  } else if (key.contains('buz') || key.contains('dondur')) {
    fx = const _BuzFx();
  } else if (key.contains('mıknatıs') || key.contains('miknatis')) {
    fx = const _MiknatisFx();
  } else if (key.contains('yıldız') ||
      key.contains('yildiz') ||
      key.contains('kombo') ||
      key.contains('combo')) {
    fx = const _YildizFx();
  } else {
    fx = const _GoldBurstFx();
  }

  final entry = OverlayEntry(
    builder: (_) => _FxHost(origin: origin, child: fx),
  );
  Overlay.of(context).insert(entry);
  await Future<void>.delayed(const Duration(milliseconds: 720));
  entry.remove();
}

/// Efekti [origin] noktasına ortalar; dokunmayı engellemez.
class _FxHost extends StatelessWidget {
  const _FxHost({required this.origin, required this.child});

  final Offset origin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ax = size.width <= 0
        ? 0.0
        : (origin.dx / size.width * 2 - 1).clamp(-1.0, 1.0);
    final ay = size.height <= 0
        ? 0.0
        : (origin.dy / size.height * 2 - 1).clamp(-1.0, 1.0);
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox.expand(
          child: Align(
            alignment: Alignment(ax, ay),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Terlik fırlar, hedefte toz bulutu + "ŞAK!".
class _TerlikFx extends StatelessWidget {
  const _TerlikFx();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Toz bulutu.
          for (int i = 0; i < 4; i++)
            Positioned(
              bottom: 66 + (i % 2) * 18,
              left: 70 + i * 26.0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: LululuColors.mutedTitanium.withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                ),
              )
                  .animate()
                  .fadeIn(duration: 1.ms, delay: (200 + i * 40).ms)
                  .scaleXY(
                    begin: 0.3,
                    end: 1.6,
                    delay: (200 + i * 40).ms,
                    duration: 320.ms,
                  )
                  .fadeOut(delay: (420 + i * 40).ms, duration: 200.ms),
            ),
          // Fırlayan terlik.
          const Text('🩴', style: TextStyle(fontSize: 76))
              .animate()
              .scaleXY(begin: 0.4, end: 1.15, duration: 160.ms)
              .moveY(
                begin: 0,
                end: -96,
                delay: 160.ms,
                duration: 280.ms,
                curve: Curves.easeIn,
              )
              .rotate(begin: 0.5, end: -0.5, delay: 160.ms, duration: 280.ms)
              .fadeOut(delay: 400.ms, duration: 160.ms),
          // "ŞAK!" yazısı.
          Positioned(
            top: 26,
            child: Text(
              'ŞAK!',
              style: GoogleFonts.bangers(
                fontSize: 52,
                color: LululuColors.warningSolar,
                shadows: const [
                  Shadow(
                    color: LululuColors.carbonVoid,
                    blurRadius: 0,
                    offset: Offset(3, 3),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 1.ms, delay: 190.ms)
                .scaleXY(
                  begin: 0.2,
                  end: 1.25,
                  delay: 190.ms,
                  duration: 240.ms,
                  curve: Curves.elasticOut,
                )
                .fadeOut(delay: 500.ms, duration: 180.ms),
          ),
        ],
      ),
    );
  }
}

/// Renkli sis bulutu yayılır.
class _SpreyFx extends StatelessWidget {
  const _SpreyFx();

  static const _mist = [
    LululuColors.toxicNeon,
    LululuColors.cyberFuchsia,
    LululuColors.liquidGold,
    LululuColors.coralFlare,
    LululuColors.warningSolar,
    LululuColors.mysticRuby,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < _mist.length; i++)
            Positioned(
              left: 120 - 30 + cos(i * pi / 3) * 44,
              top: 120 - 30 + sin(i * pi / 3) * 44,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _mist[i].withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _mist[i].withValues(alpha: 0.5),
                      blurRadius: 22,
                    ),
                  ],
                ),
              )
                  .animate()
                  .scaleXY(
                    begin: 0.3,
                    end: 2.1,
                    delay: (i * 45).ms,
                    duration: 420.ms,
                    curve: Curves.easeOut,
                  )
                  .fadeOut(delay: (i * 45 + 240).ms, duration: 240.ms),
            ),
          // Merkezde sprey kutusu parlaması.
          const Text('🧴', style: TextStyle(fontSize: 54))
              .animate()
              .scaleXY(begin: 0.5, end: 1.2, duration: 180.ms)
              .fadeOut(delay: 420.ms, duration: 200.ms),
        ],
      ),
    );
  }
}

/// Patlama flaşı + ışık hüzmesi + ekran sarsıntısı.
class _BombaFx extends StatelessWidget {
  const _BombaFx();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Işık hüzmesi (alttan yukarı).
          Container(
            width: 46,
            height: 260,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  LululuColors.warningSolar.withValues(alpha: 0.95),
                  LululuColors.warningSolar.withValues(alpha: 0.0),
                ],
              ),
              borderRadius: BorderRadius.circular(23),
            ),
          )
              .animate()
              .scaleY(
                begin: 0,
                end: 1,
                duration: 200.ms,
                alignment: Alignment.bottomCenter,
              )
              .fadeOut(delay: 300.ms, duration: 240.ms),
          // Genişleyen halka.
          for (int i = 0; i < 2; i++)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: LululuColors.liquidGold,
                  width: 10 - i * 3,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 1.ms, delay: (60 + i * 120).ms)
                .scaleXY(
                  begin: 0.3,
                  end: 2.0,
                  delay: (60 + i * 120).ms,
                  duration: 380.ms,
                  curve: Curves.easeOut,
                )
                .fadeOut(delay: (300 + i * 120).ms, duration: 200.ms),
          // Patlama flaşı.
          Container(
            width: 150,
            height: 150,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          )
              .animate()
              .fadeIn(duration: 60.ms)
              .scaleXY(begin: 0.4, end: 1.1, duration: 120.ms)
              .fadeOut(delay: 120.ms, duration: 320.ms),
          const Text('💥', style: TextStyle(fontSize: 84))
              .animate()
              .fadeIn(duration: 1.ms, delay: 60.ms)
              .scaleXY(
                begin: 0.3,
                end: 1.3,
                delay: 60.ms,
                duration: 220.ms,
                curve: Curves.elasticOut,
              )
              .fadeOut(delay: 420.ms, duration: 200.ms),
        ],
      ).animate().shake(hz: 4, duration: 380.ms, offset: const Offset(9, 0)),
    );
  }
}

/// Şimşek çizgisi + ekran flaşı.
class _YildirimFx extends StatelessWidget {
  const _YildirimFx();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
          ).animate().fadeIn(duration: 60.ms).fadeOut(delay: 90.ms, duration: 260.ms),
          CustomPaint(
            size: const Size(120, 200),
            painter: _BoltPainter(),
          )
              .animate()
              .fadeIn(duration: 1.ms, delay: 40.ms)
              .scaleXY(
                begin: 0.5,
                end: 1.15,
                delay: 40.ms,
                duration: 200.ms,
                curve: Curves.easeOut,
              )
              .fadeOut(delay: 380.ms, duration: 220.ms),
        ],
      ),
    );
  }
}

class _BoltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = LululuColors.warningSolar.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final core = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.62, 0)
      ..lineTo(size.width * 0.30, size.height * 0.38)
      ..lineTo(size.width * 0.52, size.height * 0.38)
      ..lineTo(size.width * 0.34, size.height)
      ..lineTo(size.width * 0.62, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.52)
      ..close();
    canvas.drawPath(path, glow);
    canvas.drawPath(path, core);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Buz kristalleri + mavi dalga.
class _BuzFx extends StatelessWidget {
  const _BuzFx();

  static const _ice = Color(0xFFAEE2FF);

  @override
  Widget build(BuildContext context) {
    final rng = Random(7);
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Mavi dalga halkası.
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _ice, width: 8),
            ),
          )
              .animate()
              .scaleXY(begin: 0.3, end: 1.9, duration: 480.ms, curve: Curves.easeOut)
              .fadeOut(delay: 280.ms, duration: 240.ms),
          // Kristaller.
          for (int i = 0; i < 7; i++)
            Positioned(
              left: 60 + rng.nextDouble() * 120,
              top: 40 + rng.nextDouble() * 60,
              child: const Text('❄', style: TextStyle(fontSize: 26, color: _ice))
                  .animate()
                  .fadeIn(duration: 1.ms, delay: (i * 45).ms)
                  .moveY(
                    begin: -14,
                    end: 44,
                    delay: (i * 45).ms,
                    duration: 420.ms,
                    curve: Curves.easeIn,
                  )
                  .rotate(
                    begin: 0,
                    end: 1.2,
                    delay: (i * 45).ms,
                    duration: 420.ms,
                  )
                  .fadeOut(delay: (i * 45 + 380).ms, duration: 180.ms),
            ),
          const Text('🧊', style: TextStyle(fontSize: 64))
              .animate()
              .scaleXY(
                begin: 0.4,
                end: 1.2,
                duration: 220.ms,
                curve: Curves.elasticOut,
              )
              .fadeOut(delay: 430.ms, duration: 200.ms),
        ],
      ),
    );
  }
}

/// İçe dönen girdap halkaları.
class _MiknatisFx extends StatelessWidget {
  const _MiknatisFx();

  static const _rings = [
    LululuColors.cyberFuchsia,
    LululuColors.liquidGold,
    LululuColors.mysticRuby,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < _rings.length; i++)
            Container(
              width: 170 - i * 34,
              height: 170 - i * 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _rings[i], width: 7),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .rotate(begin: 0, end: 2 * pi, duration: (520 + i * 130).ms)
                .animate()
                .scaleXY(begin: 1.25, end: 0.35, duration: 560.ms, curve: Curves.easeIn)
                .fadeOut(delay: 400.ms, duration: 200.ms),
          const Text('🧲', style: TextStyle(fontSize: 58))
              .animate()
              .scaleXY(begin: 0.4, end: 1.15, duration: 220.ms, curve: Curves.elasticOut)
              .fadeOut(delay: 430.ms, duration: 200.ms),
        ],
      ),
    );
  }
}

/// Yıldız yağmuru + "KOMBO!" yazısı.
class _YildizFx extends StatelessWidget {
  const _YildizFx();

  @override
  Widget build(BuildContext context) {
    final rng = Random(21);
    return SizedBox(
      width: 240,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Yağan yıldızlar.
          for (int i = 0; i < 9; i++)
            Positioned(
              left: 30 + rng.nextDouble() * 180,
              top: 0,
              child: Text(
                i.isEven ? '⭐' : '✦',
                style: const TextStyle(
                  fontSize: 26,
                  color: LululuColors.warningSolar,
                ),
              )
                  .animate()
                  .fadeIn(duration: 1.ms, delay: (i * 55).ms)
                  .moveY(
                    begin: -30,
                    end: 150,
                    delay: (i * 55).ms,
                    duration: 460.ms,
                    curve: Curves.easeIn,
                  )
                  .rotate(
                    begin: -0.4,
                    end: 0.4,
                    delay: (i * 55).ms,
                    duration: 460.ms,
                  )
                  .fadeOut(delay: (i * 55 + 420).ms, duration: 160.ms),
            ),
          // "KOMBO!" yazısı.
          Positioned(
            bottom: 30,
            child: Text(
              'KOMBO!',
              style: GoogleFonts.bangers(
                fontSize: 48,
                color: LululuColors.warningSolar,
                shadows: const [
                  Shadow(
                    color: LululuColors.carbonVoid,
                    blurRadius: 0,
                    offset: Offset(3, 3),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 1.ms, delay: 160.ms)
                .scaleXY(
                  begin: 0.2,
                  end: 1.25,
                  delay: 160.ms,
                  duration: 260.ms,
                  curve: Curves.elasticOut,
                )
                .fadeOut(delay: 520.ms, duration: 160.ms),
          ),
        ],
      ),
    );
  }
}

/// Varsayılan: altın parıltı patlaması.
class _GoldBurstFx extends StatelessWidget {
  const _GoldBurstFx();

  @override
  Widget build(BuildContext context) {
    final rng = Random(3);
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LululuColors.liquidGold.withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                  color: LululuColors.liquidGold.withValues(alpha: 0.7),
                  blurRadius: 30,
                ),
              ],
            ),
          )
              .animate()
              .scaleXY(begin: 0.3, end: 1.2, duration: 200.ms)
              .fadeOut(delay: 300.ms, duration: 260.ms),
          for (int i = 0; i < 10; i++)
            Builder(
              builder: (context) {
                final a = i * 2 * pi / 10 + rng.nextDouble() * 0.4;
                final dx = cos(a) * 95;
                final dy = sin(a) * 95;
                return const Text(
                  '✦',
                  style: TextStyle(
                    fontSize: 24,
                    color: LululuColors.warningSolar,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 1.ms, delay: (i * 18).ms)
                    .moveX(
                      begin: 0,
                      end: dx,
                      delay: (i * 18).ms,
                      duration: 420.ms,
                      curve: Curves.easeOut,
                    )
                    .moveY(
                      begin: 0,
                      end: dy,
                      delay: (i * 18).ms,
                      duration: 420.ms,
                      curve: Curves.easeOut,
                    )
                    .fadeOut(delay: (i * 18 + 380).ms, duration: 200.ms);
              },
            ),
        ],
      ),
    );
  }
}
