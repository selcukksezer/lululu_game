import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
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
  if (key == 'terlik' ||
      key == 'terlik sarsıntısı' ||
      key == 'anne terliği' ||
      key == 'sarsıntı' ||
      key == 'sarsinti') {
    fx = const _TerlikFx();
  } else if (key == 'sprey' ||
      key == 'raid' ||
      key == 'raid sprey' ||
      key == 'raid spreyi') {
    fx = const _SpreyFx();
  } else if (key == 'aydınlat' ||
      key == 'aydınlat hele!' ||
      key == 'f16' ||
      key == 'f16 bombardıman' ||
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
  } else if (key.contains('mıknatıs') ||
      key.contains('miknatis') ||
      key.contains('çiftleştir') ||
      key.contains('ciftlestir')) {
    fx = const _MiknatisFx();
  } else if (key.contains('yıldız') ||
      key.contains('yildiz') ||
      key.contains('kombo') ||
      key.contains('combo') ||
      key.contains('karıştır') ||
      key.contains('karistir') ||
      key.contains('geri al')) {
    fx = const _YildizFx();
  } else {
    fx = const _GoldBurstFx();
  }

  final entry = OverlayEntry(
    builder: (_) => _FxHost(origin: origin, child: fx),
  );
  var inserted = false;
  try {
    Overlay.of(context).insert(entry);
    inserted = true;
    await Future<void>.delayed(const Duration(milliseconds: 720));
  } finally {
    // Bekleme yarıda kesilse bile overlay kaldırılır; aksi hâlde efekt
    // ekranda takılı kalır.
    if (inserted) {
      try {
        entry.remove();
      } catch (_) {}
    }
  }
}

/// Prototip v4 "F16 BOMBARDIMANI": jet ekranı boydan boya geçer
/// (1500 ms), 3 bomba bırakır; bombalar hedefe düşünce patlar.
/// `_BombaFx` yalnız düğme çevresindeki çarpma efektidir (bomba/alev/
/// flaş/💥); jet yalnız bu katmandadır. Aynı anda tek uçuş olur
/// (prototipteki `f16Busy` koruması).
bool _f16FlyoverActive = false;

Future<void> playF16Flyover(BuildContext context) async {
  if (_f16FlyoverActive) return;
  _f16FlyoverActive = true;
  final entry = OverlayEntry(builder: (_) => const _F16Flyover());
  var inserted = false;
  try {
    Overlay.of(context).insert(entry);
    inserted = true;
    await Future<void>.delayed(const Duration(milliseconds: 1900));
  } finally {
    _f16FlyoverActive = false;
    if (inserted) {
      try {
        entry.remove();
      } catch (_) {}
    }
  }
}

@visibleForTesting
void debugResetF16FlyoverGuard() {
  _f16FlyoverActive = false;
}

/// Tam ekran F16 uçuşu (prototip: `.f16-layer` + `.f16-jet`).
///
/// Jet 216 px genişliğinde, soldan (ekran dışı) sağa (ekran dışı) 1500 ms
/// uçar; 560/670/780. ms'de 3 bomba bırakır; bombalar 540 ms'de alanın
/// %28/%52/%76 noktalarına düşüp patlar. Dokunmayı engellemez.
class _F16Flyover extends StatefulWidget {
  const _F16Flyover();

  @override
  State<_F16Flyover> createState() => _F16FlyoverState();
}

class _F16FlyoverState extends State<_F16Flyover>
    with SingleTickerProviderStateMixin {
  static const _flightMs = 1500;
  static const _jetWidth = 216.0;
  static const _jetHeight = 92.0;
  static const _bombDropAtMs = [560, 670, 780];
  static const _bombFallMs = 540;
  static const _targetX = [0.28, 0.52, 0.76];
  static const _targetY = [0.54, 0.60, 0.56];
  static const _flightCurve = Cubic(0.32, 0.08, 0.62, 1.0);

  late final AnimationController _flight;
  final List<_DroppedBomb> _bombs = [];
  final List<Offset> _blasts = [];
  final List<Timer> _timers = [];

  double _flightX(double t, double width) {
    if (t < 0.45) {
      return -270 + (width * 0.42 + 270) * (t / 0.45);
    }
    return width * 0.42 +
        (width + 30 - width * 0.42) * ((t - 0.45) / 0.55);
  }

  double _flightY(double t) {
    if (t < 0.45) {
      return -7 * (t / 0.45);
    }
    return -7 + 10 * ((t - 0.45) / 0.55);
  }

  @override
  void initState() {
    super.initState();
    _flight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _flightMs),
    )..forward();
    for (var i = 0; i < _bombDropAtMs.length; i++) {
      _timers.add(
        Timer(Duration(milliseconds: _bombDropAtMs[i]), () {
          if (!mounted) return;
          final size = context.size ?? MediaQuery.sizeOf(context);
          final t = _flightCurve.transform(
            _bombDropAtMs[i] / _flightMs,
          );
          final jetLeft = _flightX(t, size.width);
          final jetTop = size.height * 0.14;
          setState(() {
            _bombs.add(
              _DroppedBomb(
                index: i,
                from: Offset(
                  jetLeft + _jetWidth * 0.52,
                  jetTop + _jetHeight * 0.72,
                ),
                to: Offset(
                  size.width * _targetX[i],
                  size.height * _targetY[i],
                ),
              ),
            );
          });
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _flight.dispose();
    super.dispose();
  }

  void _onBombLanded(_DroppedBomb bomb) {
    if (!mounted) return;
    setState(() {
      _bombs.remove(bomb);
      _blasts.add(bomb.to);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox.expand(
          key: const Key('f16-flyover'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _flight,
                builder: (context, child) {
                  final t = _flightCurve.transform(_flight.value);
                  return Positioned(
                    left: _flightX(t, size.width),
                    top: size.height * 0.14 + _flightY(t),
                    child: child!,
                  );
                },
                child: const CustomPaint(
                  key: Key('f16-flyover-jet'),
                  size: Size(_jetWidth, _jetHeight),
                  painter: _F16JetPainter(),
                ),
              ),
              for (final bomb in _bombs)
                _FallingBomb(
                  key: Key('f16-flyover-bomb-${bomb.index}'),
                  bomb: bomb,
                  onLanded: () => _onBombLanded(bomb),
                ),
              for (var i = 0; i < _blasts.length; i++)
                Positioned(
                  key: Key('f16-flyover-blast-$i'),
                  left: _blasts[i].dx - 55,
                  top: _blasts[i].dy - 55,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB800),
                      shape: BoxShape.circle,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 40.ms)
                      .scaleXY(begin: 0.3, end: 1.4, duration: 220.ms)
                      .fadeOut(delay: 180.ms, duration: 180.ms),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DroppedBomb {
  const _DroppedBomb({
    required this.index,
    required this.from,
    required this.to,
  });

  final int index;
  final Offset from;
  final Offset to;
}

/// Jeti bıraktığı noktadan hedefe 540 ms'de düşer (prototip:
/// `cubic-bezier(.5,.05,.8,.6)`, 4° → 38° döner); varınca patlar.
class _FallingBomb extends StatefulWidget {
  const _FallingBomb({super.key, required this.bomb, required this.onLanded});

  final _DroppedBomb bomb;
  final VoidCallback onLanded;

  @override
  State<_FallingBomb> createState() => _FallingBombState();
}

class _FallingBombState extends State<_FallingBomb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fall;

  @override
  void initState() {
    super.initState();
    _fall = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _F16FlyoverState._bombFallMs),
    )..forward().whenComplete(() {
        if (mounted) widget.onLanded();
      });
  }

  @override
  void dispose() {
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fall,
      builder: (context, child) {
        final eased =
            const Cubic(0.5, 0.05, 0.8, 0.6).transform(_fall.value);
        final pos = Offset.lerp(widget.bomb.from, widget.bomb.to, eased)!;
        final angle = 0.07 + (0.66 - 0.07) * eased;
        return Positioned(
          left: pos.dx - 12,
          top: pos.dy - 17,
          child: Transform.rotate(angle: angle, child: child!),
        );
      },
      child: const CustomPaint(
        size: Size(24, 34),
        painter: _F16BombPainter(),
      ),
    );
  }
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
          const ExcludeSemantics(
            child: Text('🩴', style: TextStyle(fontSize: 76)),
          )
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
            child: ExcludeSemantics(
              child: Text(
                context.l10n.effectSlap,
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
          const ExcludeSemantics(
            child: Text('🧴', style: TextStyle(fontSize: 54)),
          )
              .animate()
              .scaleXY(begin: 0.5, end: 1.2, duration: 180.ms)
              .fadeOut(delay: 420.ms, duration: 200.ms),
        ],
      ),
    );
  }
}

/// 3 bomba + patlama flaşı + ışık hüzmesi + ekran sarsıntısı.
///
/// Jet bu kutuda DEĞİL — tam ekran uçuş `_F16Flyover`'dadır
/// (`playF16Flyover`); buradaki küçük jet, flaşın altında kaybolup
/// "jet yok" izlenimi veriyordu (12S).
class _BombaFx extends StatelessWidget {
  const _BombaFx();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
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
          // 3 adet F-16 bombası yukarıdan hedeflere düşer.
          for (int b = 0; b < 3; b++)
            Positioned(
              left: 72.0 + b * 68.0,
              top: 18,
              child: CustomPaint(
                size: const Size(24, 34),
                painter: const _F16BombPainter(),
              )
                  .animate()
                  .fadeIn(duration: 40.ms, delay: (b * 70).ms)
                  .moveY(
                    begin: -40,
                    end: 118,
                    delay: (b * 70).ms,
                    duration: 240.ms,
                    curve: Curves.easeIn,
                  )
                  .fadeOut(delay: (b * 70 + 220).ms, duration: 90.ms),
            ),
          // Genişleyen şok halkaları.
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
          const ExcludeSemantics(
            child: Text('💥', style: TextStyle(fontSize: 84)),
          )
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

/// Prototip v4 `JET_SVG` (viewBox 0 0 260 96) + alev + pilot madalyonu.
///
/// Mantıksal alan 260x110'dur: SVG 14 px aşağıda çizilir, pilot
/// madalyonu (prototip `.f16-pilot`: altın halkalı açık mavi daire)
/// üstte kalır. Jet sağa bakar (burun sağda).
class _F16JetPainter extends CustomPainter {
  const _F16JetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 260.0;
    final sy = size.height / 110.0;
    canvas.save();
    canvas.scale(sx, sy);

    // SVG alanı (14 px aşağı kaydırılmış).
    canvas.save();
    canvas.translate(0, 14);

    // Afterburner alevi (kuyrukta, sola uzanır; prototip `.f16-flame`).
    canvas.drawPath(
      Path()
        ..moveTo(28, 48)
        ..lineTo(0, 55)
        ..lineTo(28, 62)
        ..close(),
      Paint()..color = const Color(0xFFFF6B00),
    );
    canvas.drawPath(
      Path()
        ..moveTo(32, 51)
        ..lineTo(10, 55)
        ..lineTo(32, 59)
        ..close(),
      Paint()..color = const Color(0xFFFFE566),
    );

    // Ana gövde.
    canvas.drawPath(
      Path()
        ..moveTo(252, 52)
        ..lineTo(196, 40)
        ..quadraticBezierTo(150, 30, 108, 34)
        ..lineTo(52, 40)
        ..quadraticBezierTo(22, 43, 8, 50)
        ..lineTo(10, 56)
        ..quadraticBezierTo(24, 62, 54, 62)
        ..lineTo(120, 64)
        ..quadraticBezierTo(190, 66, 252, 52)
        ..close(),
      Paint()..color = const Color(0xFF5B6B82),
    );
    // Üst parlama.
    canvas.drawPath(
      Path()
        ..moveTo(252, 52)
        ..lineTo(196, 40)
        ..quadraticBezierTo(168, 34, 140, 33)
        ..lineTo(196, 46)
        ..quadraticBezierTo(228, 50, 252, 52)
        ..close(),
      Paint()..color = const Color(0xFF7C8DA6),
    );
    // Kokpit camı + konturu.
    canvas.drawPath(
      Path()
        ..moveTo(196, 40)
        ..quadraticBezierTo(176, 24, 148, 26)
        ..quadraticBezierTo(132, 28, 130, 36)
        ..quadraticBezierTo(158, 42, 196, 40)
        ..close(),
      Paint()..color = const Color(0xFF9FD8EF),
    );
    canvas.drawPath(
      Path()
        ..moveTo(196, 40)
        ..quadraticBezierTo(176, 24, 148, 26),
      Paint()
        ..color = const Color(0xFFDFF4FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Üst kanat.
    canvas.drawPath(
      Path()
        ..moveTo(62, 40)
        ..lineTo(34, 8)
        ..quadraticBezierTo(30, 4, 36, 5)
        ..lineTo(84, 32)
        ..quadraticBezierTo(92, 38, 84, 41)
        ..close(),
      Paint()..color = const Color(0xFF46536A),
    );
    // Alt kanat.
    canvas.drawPath(
      Path()
        ..moveTo(120, 62)
        ..lineTo(84, 88)
        ..quadraticBezierTo(80, 92, 88, 92)
        ..lineTo(168, 70)
        ..quadraticBezierTo(178, 66, 168, 62)
        ..close(),
      Paint()..color = const Color(0xFF46536A),
    );
    // Kuyruk kanadı.
    canvas.drawPath(
      Path()
        ..moveTo(52, 60)
        ..lineTo(26, 76)
        ..quadraticBezierTo(22, 80, 30, 80)
        ..lineTo(66, 66)
        ..close(),
      Paint()..color = const Color(0xFF39465C),
    );
    // Motor çıkışı + altın nokta.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(196, 44, 16, 9),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF39465C),
    );
    canvas.drawCircle(
      const Offset(238, 50),
      2.6,
      Paint()..color = const Color(0xFFFFD700),
    );
    canvas.restore();

    // Pilot madalyonu (üstte; fotoğraf yerine açık mavi daire).
    canvas.drawCircle(
      const Offset(141, 24),
      23.5,
      Paint()..color = const Color(0xFFBFE9FA),
    );
    canvas.drawCircle(
      const Offset(141, 24),
      23.5,
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      const Offset(137, 20),
      14,
      Paint()..color = const Color(0xFF5FB6DC),
    );
    canvas.drawCircle(
      const Offset(132, 14),
      4,
      Paint()..color = const Color(0xFFFFFFFF),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _F16BombPainter extends CustomPainter {
  const _F16BombPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = const Color(0xFF2B3548);
    final band = Paint()..color = const Color(0xFFFFB800);
    final r = Rect.fromLTWH(
      size.width * 0.2,
      size.height * 0.18,
      size.width * 0.6,
      size.height * 0.72,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(8)),
      body,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.2,
        size.height * 0.45,
        size.width * 0.6,
        4,
      ),
      band,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
              child: const ExcludeSemantics(
                child: Text('❄', style: TextStyle(fontSize: 26, color: _ice)),
              )
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
          const ExcludeSemantics(
            child: Text('🧊', style: TextStyle(fontSize: 64)),
          )
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
          const ExcludeSemantics(
            child: Text('🧲', style: TextStyle(fontSize: 58)),
          )
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
              child: ExcludeSemantics(
                child: Text(
                  i.isEven ? '⭐' : '✦',
                  style: const TextStyle(
                    fontSize: 26,
                    color: LululuColors.warningSolar,
                  ),
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
            child: ExcludeSemantics(
              child: Text(
                context.l10n.effectCombo,
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
                return const ExcludeSemantics(
                  child: Text(
                    '✦',
                    style: TextStyle(
                      fontSize: 24,
                      color: LululuColors.warningSolar,
                    ),
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
