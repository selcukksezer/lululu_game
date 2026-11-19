import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/audio_manager.dart';
import '../theme/lululu_theme.dart';

/// 3 sayfalık animasyonlu açılış (HTML prototype scr-splash ile birebir).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _pageIndex = 0;

  // Sayfa 1 Animasyonları
  late AnimationController _logoBobController;
  late Animation<double> _logoBobY;
  late Animation<double> _logoBobAngle;

  late AnimationController _mascotController;
  late Animation<double> _mascotProgress;

  late AnimationController _bubbleController;
  late Animation<double> _bubbleProgress;

  // Sayfa 3 loading bar & cycling messages
  Timer? _loadTimer;
  Timer? _msgTimer;
  Timer? _soundTimer;
  Timer? _finishTimer;
  double _progress = 0;
  bool _loading = false;
  bool _done = false;
  // `_done` yükleme-bitti arayüz durumudur; `onDone` tek-atımlık
  // koruması ayrı bayraktadır — eskiden `_finish` her iki dalda da
  // `onDone()` çağırıyor, çift boot'a yol açıyordu (R2).
  bool _notified = false;
  int _msgIndex = 0;

  // S2#10: web otomatik-oynatma politikası — 650 ms zamanlayıcısının
  // intro sesi web'de yalnız kullanıcı etkileşiminden sonra çalınır;
  // etkileşim yoksa çalma denemesi bile yapılmaz. Mobilde davranış
  // değişmez. Bayrak her kullanıcı hareketinde (kaydırma, GEÇ,
  // DEVAM dokunuşları) true'ya çevrilir; arayüz durumu değildir.
  bool _hasInteracted = false;

  // Yükleme döngü mesajı sayısı; metinler AppLocalizations
  // splashLoadMessage(index) metodundadır (0-4). Sayı ile metot
  // kasaları birlikte değişmelidir.
  static const _loadMessageCount = 5;

  @override
  void initState() {
    super.initState();

    // 1. Logo Bobbing Animasyonu (3.2s infinite ease-in-out)
    _logoBobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _logoBobController.repeat(reverse: true);
    }

    _logoBobY = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(
        parent: _logoBobController,
        curve: Curves.easeInOut,
      ),
    );

    _logoBobAngle = Tween<double>(
      begin: 1.0 * math.pi / 180.0,
      end: -1.0 * math.pi / 180.0,
    ).animate(
      CurvedAnimation(
        parent: _logoBobController,
        curve: Curves.easeInOut,
      ),
    );

    // 2. Mascot Entrance Animasyonu (.85s cubic-bezier(.3,1.45,.5,1))
    _mascotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _mascotProgress = CurvedAnimation(
      parent: _mascotController,
      curve: const Cubic(0.3, 1.45, 0.5, 1.0),
    );

    // 3. Speech Bubble Animasyonu (.4s cubic-bezier(.3,1.6,.5,1) after .55s delay)
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bubbleProgress = CurvedAnimation(
      parent: _bubbleController,
      curve: const Cubic(0.3, 1.6, 0.5, 1.0),
    );

    // Animasyonları başlat
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTesting) {
      _mascotController.value = 1.0;
      _bubbleController.value = 1.0;
    } else {
      _mascotController.forward();
      Future.delayed(const Duration(milliseconds: 550), () {
        if (mounted) _bubbleController.forward();
      });

      // Ses: 650ms sonra Kongo Lideri sesi (tier 7)
      _soundTimer = Timer(const Duration(milliseconds: 650), () {
        // Web'de etkileşim yoksa çalma denemesi yapılmaz (tarayıcı
        // otomatik-oynatma politikası); mobilde eski davranış korunur.
        if (kIsWeb && !_hasInteracted) return;
        AudioManager().playMerge(tierNumber: 7).catchError((_) {});
      });
    }
  }

  @override
  void dispose() {
    _logoBobController.dispose();
    _mascotController.dispose();
    _bubbleController.dispose();
    _pageController.dispose();
    _loadTimer?.cancel();
    _msgTimer?.cancel();
    _soundTimer?.cancel();
    _finishTimer?.cancel();
    super.dispose();
  }

  void _onPageChanged(int index) {
    _hasInteracted = true;
    setState(() => _pageIndex = index);
    if (index == 0) {
      AudioManager().playMerge(tierNumber: 7).catchError((_) {});
    } else if (index == 1) {
      AudioManager().playMerge(tierNumber: 1).catchError((_) {});
    } else if (index == 2 && !_loading) {
      AudioManager().playMerge(tierNumber: 8).catchError((_) {});
    }
  }

  void _skipToEnd() {
    _hasInteracted = true;
    _finish();
  }

  void _nextPage() {
    _hasInteracted = true;
    if (_pageIndex < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _startLoading();
    }
  }

  void _startLoading() {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _progress = 0;
    });

    _msgTimer?.cancel();
    _msgTimer = Timer.periodic(const Duration(milliseconds: 550), (_) {
      if (!mounted) return;
      setState(() {
        _msgIndex = (_msgIndex + 1) % _loadMessageCount;
      });
    });

    _loadTimer?.cancel();
    _loadTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      // 6I: 2.4'lük adımlar 100.8'de durur ve ekranda %101 görünür;
      // ilerleme 100'de kelepçelenir, bitiş dalı (`>= 100`) aynen çalışır.
      setState(() => _progress = (_progress + 2.4).clamp(0.0, 100.0));
      if (_progress >= 100) {
        t.cancel();
        _msgTimer?.cancel();
        setState(() => _done = true);
        // İptal edilebilir Timer: dispose'da iptal edilir, `mounted`
        // değilse ateşlenmez; GEÇ ile yarışan gecikmeli `_finish`
        // `_notified` korumasına takılır.
        _finishTimer?.cancel();
        _finishTimer = Timer(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          _finish();
        });
      }
    });
  }

  void _finish() {
    if (_notified) return;
    _notified = true;
    _done = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: LululuColors.carbonVoid,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Arka plan görseli (WebP ikizi: 277 KB, 3.2 MB PNG ile aynı kare)
          Image.asset(
            'assets/design/splash/bg_splash.webp',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: 860,
            cacheHeight: 1911,
            errorBuilder: (_, _, _) => Image.asset(
              'assets/design/backgrounds/bg_splash.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: 860,
              cacheHeight: 1911,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: LululuColors.carbonVoid),
            ),
          ),

          // 4-stop shade gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.26, 0.58, 1.0],
                  colors: [
                    Color(0x0A080B12), // rgba(8,11,18,.04)
                    Color(0x0A080B12), // rgba(8,11,18,.04)
                    Color(0x4D080B12), // rgba(8,11,18,.30)
                    Color(0xC7080B12), // rgba(8,11,18,.78)
                  ],
                ),
              ),
            ),
          ),

          // İçerik sayfaları (ob-viewport: top: 0, bottom: 122 -> 810px on 430x932)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 122,
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _wrapPageViewport(_buildPage1()),
                _wrapPageViewport(_buildPage2()),
                _wrapPageViewport(_buildPage3()),
              ],
            ),
          ),

          // GEÇ butonu (üst sağ) — 6I: PageView'UN ALTINDA çiziliyordu;
          // Stack isabet sırası sondan başa olduğundan PageView
          // (y 0-810) hapın dokunuşunu yutuyor, `_skipToEnd` hiç
          // ateşlenmiyordu (widget testinde de kanıtlandı: hap üstü
          // PageView'de 0 dokunma). Hap PageView'UN ÜSTÜNE alınır;
          // köşesinde sayfa içeriğiyle çakışan öğe yoktur
          // (kicker/logo ortalıdır), görsel değişmez.
          Positioned(
            top: 44,
            right: 14,
            child: Semantics(
              button: true,
              label: l10n.splashSkipPlain,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: _skipToEnd,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 86,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xB8080B12), // rgba(8,11,18,.72)
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0x73FFFFFF), // rgba(255,255,255,.45)
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.splashSkip,
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Alt göstergeler (ob-foot height: 122)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 122,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 2, 22, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 3 Dot Indicator (height 48)
                  SizedBox(
                    height: 48,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          Semantics(
                            button: true,
                            selected: _pageIndex == i,
                            label: l10n.onboardingPageLabel(i + 1),
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  i,
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              child: Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: _pageIndex == i ? 30 : 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _pageIndex == i
                                        ? const Color(0xFFFFB800)
                                        : const Color(0x73FFFFFF),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: _pageIndex == i
                                        ? const [
                                            BoxShadow(
                                              color: Color(0xB3FFB800),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // DEVAM › Butonu
                  Semantics(
                    button: true,
                    label: _pageIndex == 2
                        ? l10n.splashStartButtonPlain
                        : l10n.splashContinueButtonPlain,
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: _nextPage,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _pageIndex == 2 && _loading ? 0.0 : 1.0,
                        child: Container(
                          width: 190,
                          height: 52,
                          decoration: BoxDecoration(
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
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFFB97A00),
                                offset: Offset(0, 5),
                              ),
                              BoxShadow(
                                color: Color(0x47000000), // rgba(0,0,0,.28)
                                blurRadius: 18,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _pageIndex == 2
                                ? l10n.splashStartButton
                                : l10n.splashContinueButton,
                            style: GoogleFonts.baloo2(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.36,
                              shadows: const [
                                Shadow(
                                  color: Color(0x59784000),
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Version label (v1.0 · Tasarım Prototipi)
          Positioned(
            right: 18,
            bottom: 14,
            child: Text(
              l10n.splashVersionLabel,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0x8CFFFFFF),
                height: 17.05 / 11.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sayfa tasarımının referans ölçüleri: 430x932 ekranda üstten 0,
  /// alttan 122px'lik ayak hariç kalan 430x810'luk görünüm alanı.
  /// Sayfalar bu ölçüleri yalnızca referans oran olarak alır;
  /// gerçek boyut her zaman LayoutBuilder constraints'inden gelir.
  static const double _refPageWidth = 430.0;
  static const double _refPageHeight = 810.0;

  /// Sayfayı mevcut alana yayar: referans boyutta veya daha büyük ekranda
  /// sayfa alanı doldurur (double.infinity); daha küçük ekranda
  /// (360x640, 375x667) referans oranı korunarak küçültülür, taşma olmaz.
  Widget _wrapPageViewport(Widget pageContent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return pageContent;
        }
        final availWidth = constraints.maxWidth;
        final availHeight = constraints.maxHeight;
        if (availWidth >= _refPageWidth - 5 &&
            availHeight >= _refPageHeight - 10) {
          return pageContent;
        }
        final scale = math.min(
          availWidth / _refPageWidth,
          availHeight / _refPageHeight,
        );
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: _refPageWidth * scale,
            height: _refPageHeight * scale,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _refPageWidth,
                height: _refPageHeight,
                child: pageContent,
              ),
            ),
          ),
        );
      },
    );
  }

  // SAYFA 1: Logo + Maskot Girişi
  Widget _buildPage1() {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 56.0, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Kicker (YENİ MACERA at y=54, height=28.6 unrotated / 32.7 rotated, ends at 86.7)
          Transform.rotate(
            angle: -2 * math.pi / 180,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE01E5A),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    offset: Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                l10n.splashKicker1,
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.44,
                  height: 18.6 / 12.0,
                ),
              ),
            ),
          ),

          const SizedBox(height: 7.1),

          // 2. Logo (#splashLogo: margin-top: 16px from unrotated kicker, drop-shadow(0 12px 24px rgba(0,0,0,.5)))
          AnimatedBuilder(
            animation: _logoBobController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _logoBobY.value),
                child: Transform.rotate(
                  angle: _logoBobAngle.value,
                  child: child,
                ),
              );
            },
            child: SizedBox(
              width: 336.0,
              height: 112.0,
              child: OverflowBox(
                minWidth: 396.0,
                maxWidth: 396.0,
                minHeight: 172.0,
                maxHeight: 172.0,
                child: Image.asset(
                  'assets/design/splash/splash_logo_shadow.png',
                  width: 396.0,
                  height: 172.0,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 12),
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: 12.0,
                            sigmaY: 12.0,
                          ),
                          child: Image.asset(
                            'assets/design/ui/logo_lululu.webp',
                            width: 336.0,
                            height: 112.0,
                            fit: BoxFit.contain,
                            color: const Color(0x80000000),
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                      ),
                      Image.asset(
                        'assets/design/ui/logo_lululu.webp',
                        width: 336.0,
                        height: 112.0,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20.5),

          // 3. Title H2 (starts at y=222.6, height=62.6)
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Baloo 2',
                fontSize: 29,
                fontWeight: FontWeight.w800,
                height: 1.08,
                shadows: [
                  Shadow(
                    color: Color(0x8C7A082E),
                    offset: Offset(0, 3),
                  ),
                  Shadow(
                    color: Color(0x73000000),
                    offset: Offset(0, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              children: [
                TextSpan(
                  text: l10n.splashTitle1Line1,
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: l10n.splashTitle1Line2,
                  style: TextStyle(color: Color(0xFFFFD34D)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 5.0),

          // 4. Subtitle (starts at y=293.2, width=290, height=67.4)
          SizedBox(
            width: 320,
            child: Text(
              l10n.splashSubtitle1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xF0FFFFFF),
                letterSpacing: -0.05,
                height: 21.7 / 14.5,
                shadows: [
                  Shadow(
                    color: Color(0x8C000000),
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // 5. Mascot Zone (starts at y=465.8, height=334.2)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Speech Bubble (y=465.8, height=45.4, width=141.9)
              AnimatedBuilder(
                animation: _bubbleProgress,
                builder: (context, child) {
                  final val = _bubbleProgress.value;
                  return Opacity(
                    opacity: val.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 12.0 * (1.0 - val)),
                      child: Transform.scale(
                        scale: 0.5 + 0.5 * val,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      bottom: -7,
                      child: Transform.rotate(
                        angle: 45 * math.pi / 180,
                        child: Container(
                          width: 14,
                          height: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      width: 141.9,
                      height: 45.4,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x59000000),
                            offset: Offset(0, 8),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.splashBubbleText,
                          maxLines: 1,
                          softWrap: false,
                          style: GoogleFonts.bangers(
                            fontSize: 19,
                            letterSpacing: 0.8,
                            color: const Color(0xFFB80F42),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Maskot Görseli (y=521.2, width=172, height=278.8)
              AnimatedBuilder(
                animation: _mascotProgress,
                builder: (context, child) {
                  final t = _mascotProgress.value;
                  double tx, ty, rot, sc, op;
                  if (t <= 0.72) {
                    final p = t / 0.72;
                    tx = -190.0 + (10.0 - (-190.0)) * p;
                    ty = 26.0 + (-16.0 - 26.0) * p;
                    rot = (-14.0 + (4.0 - (-14.0)) * p) * math.pi / 180.0;
                    sc = 0.6 + (1.06 - 0.6) * p;
                  } else {
                    final p = (t - 0.72) / (1.0 - 0.72);
                    tx = 10.0 + (0.0 - 10.0) * p;
                    ty = -16.0 + (0.0 - (-16.0)) * p;
                    rot = (4.0 + (0.0 - 4.0) * p) * math.pi / 180.0;
                    sc = 1.06 + (1.0 - 1.06) * p;
                  }
                  op = t <= 0.55 ? (t / 0.55).clamp(0.0, 1.0) : 1.0;

                  return Opacity(
                    opacity: op,
                    child: Transform.translate(
                      offset: Offset(tx, ty),
                      child: Transform.rotate(
                        angle: rot,
                        child: Transform.scale(
                          scale: sc,
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: Image.asset(
                  // WebP ikizi (76 KB, PNG ile piksel-birebir aynı; S2#34).
                  'assets/design/splash/splash_mascot.webp',
                  width: 172,
                  height: 278.8,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Image.asset(
                    'assets/design/ui/tier7_kongo_lideri.png',
                    width: 172,
                    height: 278.8,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // SAYFA 2: Oyun Modları Geçidi
  Widget _buildPage2() {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 56, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Kicker (11 OYUN MODU)
          Transform.rotate(
            angle: -2 * math.pi / 180,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE01E5A),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    offset: Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                l10n.splashKicker2,
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.44,
                  height: 18.6 / 12.0,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Title H2
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.baloo2(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                height: 1.08,
                shadows: const [
                  Shadow(
                    color: Color(0x8C7A082E),
                    offset: Offset(0, 3),
                  ),
                  Shadow(
                    color: Color(0x73000000),
                    offset: Offset(0, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              children: [
                TextSpan(
                  text: l10n.splashTitle2Line1,
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: l10n.splashTitle2Line2,
                  style: TextStyle(color: Color(0xFFFFD34D)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Parade Container (238px height with golden ground and walking bugs)
          Container(
            width: double.infinity,
            height: 238,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.62, 1.0],
                colors: [
                  Color(0x33FFFFFF),
                  Color(0x0DFFFFFF),
                  Color(0x475A2C00),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0x59FFFFFF),
                width: 2,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Golden Ground (height 34)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 34,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFD34D), Color(0xFFF59E00)],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Color(0x8CFFFFFF),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),

                // 8 Walking Bugs
                const _ParadeWalkersWidget(),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 10 Mode Chips (2 column grid: [tier1, tier2, tier1, tier5, tier3, tier6, powerup_terlik, osmantus_kisi_a, tier7, tier3])
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              childAspectRatio: 185 / 40,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ModeChip(
                  title: l10n.suikaArenaTitle,
                  assetPath: 'assets/bugs/tier1_hd.png',
                  fallbackAssetPath: 'assets/design/bugs_hd/tier1_hd.png',
                ),
                _ModeChip(
                  title: l10n.grid2048Title,
                  assetPath: 'assets/bugs/tier2_hd.png',
                  fallbackAssetPath: 'assets/design/bugs_hd/tier2_hd.png',
                ),
                _ModeChip(
                  title: l10n.balloonPopTitle,
                  assetPath: 'assets/bugs/tier1_hd.png',
                  fallbackAssetPath: 'assets/design/bugs_hd/tier1_hd.png',
                ),
                _ModeChip(
                  title: l10n.match3Title,
                  assetPath: 'assets/bugs/tier5_hd.webp',
                  fallbackAssetPath: 'assets/design/bugs_hd/tier5_hd.png',
                ),
                _ModeChip(
                  title: l10n.linkPopTitle,
                  assetPath: 'assets/bugs/tier3_hd.png',
                  fallbackAssetPath: 'assets/design/bugs_hd/tier3_hd.png',
                ),
                _ModeChip(
                  title: l10n.stackDropTitle,
                  assetPath: 'assets/bugs/tier6_hd.png',
                  fallbackAssetPath: 'assets/design/bugs_hd/tier6_hd.png',
                ),
                _ModeChip(
                  title: l10n.slipperTapTitle,
                  assetPath: 'assets/design/ui/powerup_terlik.png',
                  fallbackAssetPath: 'assets/design/ui/powerup_terlik.png',
                ),
                _ModeChip(
                  title: l10n.osmantusTitle,
                  assetPath: 'assets/osman/osmantus_kisi_a.png',
                  fallbackAssetPath: 'assets/design/osman/osmantus_kisi_a.png',
                ),
                _ModeChip(
                  title: l10n.screamBugTitle,
                  assetPath: 'assets/bugs/tier7_hd.png',
                  fallbackAssetPath: 'assets/design/bugs_hd/tier7_hd.png',
                ),
                _ModeChip(
                  title: l10n.makarayizTitle,
                  assetPath: 'assets/bugs/tier3_hd.png',
                  fallbackAssetPath: 'assets/design/bugs_hd/tier3_hd.png',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _loadBugLeft(int index) {
    const leads = <double>[0.0, 34.0, 62.0];
    final lead = leads[index];
    final lp = math.max(0.0, _progress - lead * 0.55);
    return ((lp / 100.0) * 340.0 - (lp * 0.42).roundToDouble())
        .clamp(0.0, 298.0);
  }

  // SAYFA 3: Başlat + Loading Bar
  Widget _buildPage3() {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 56, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Kicker (SON ADIM)
          Transform.rotate(
            angle: -2 * math.pi / 180,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE01E5A),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    offset: Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                l10n.splashKicker3,
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.44,
                  height: 18.6 / 12.0,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Title H2
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.baloo2(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                height: 1.08,
                shadows: const [
                  Shadow(
                    color: Color(0x8C7A082E),
                    offset: Offset(0, 3),
                  ),
                  Shadow(
                    color: Color(0x73000000),
                    offset: Offset(0, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              children: [
                TextSpan(
                  text: l10n.splashTitle3Line1,
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: l10n.splashTitle3Line2,
                  style: TextStyle(color: Color(0xFFFFD34D)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3 Standing Bugs (.ob-start-bugs)
          SizedBox(
            height: 82,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Image.asset(
                  'assets/design/bugs_hd/tier2_hd.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 2),
                Image.asset(
                  'assets/design/bugs_hd/tier7_hd.png',
                  width: 82,
                  height: 82,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 2),
                Image.asset(
                  'assets/design/bugs_hd/tier4_hd.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Fuchsia Start Button (#btnStart)
          Semantics(
            button: true,
            label: _loading
                ? (_done
                    ? l10n.splashStarting
                    : l10n.splashLoadingPercent(_progress.round()))
                : l10n.splashStartAdventure,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _startLoading,
              behavior: HitTestBehavior.opaque,
              child: Container(
                constraints: const BoxConstraints(minWidth: 248),
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFF3377),
                      Color(0xFFE01E5A),
                      Color(0xFFB80F42),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF7A082E),
                      offset: Offset(0, 5),
                    ),
                    BoxShadow(
                      color: Color(0x47000000),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/design/ui/icons/play.png',
                      width: 23,
                      height: 23,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _loading
                          ? (_done
                              ? l10n.splashStarting
                              : l10n.splashLoadingPercent(_progress.round()))
                          : l10n.splashStartAdventure,
                      style: GoogleFonts.baloo2(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // Loading Zone (.ob-load-zone)
          SizedBox(
            width: 340,
            height: 106,
            child: Stack(
              children: [
                // 3 Walking Bugs on Top of Bar (.ob-load-bugs: at 0% all 3 start at left: 0)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: _loadBugLeft(0),
                        top: 0,
                        child: Image.asset(
                          'assets/design/bugs_hd/tier7_hd.png',
                          width: 42,
                          height: 42,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        left: _loadBugLeft(1),
                        top: 0,
                        child: Image.asset(
                          'assets/design/bugs_hd/tier3_hd.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        left: _loadBugLeft(2),
                        top: 0,
                        child: Image.asset(
                          'assets/design/bugs_hd/tier1_hd.png',
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),

                // Loading Bar (.ob-loadbar)
                Positioned(
                  top: 44,
                  left: 0,
                  right: 0,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF), // rgba(255,255,255,.20)
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0x80FFFFFF), // rgba(255,255,255,.5)
                        width: 2.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4D000000),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (_progress / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFFB800),
                                  Color(0xFFFF6B4A),
                                  Color(0xFFE01E5A),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Meta row: Text + Percentage
                Positioned(
                  top: 73,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _loading
                            ? l10n.splashLoadMessage(_msgIndex)
                            : l10n.splashPressToStart,
                        style: GoogleFonts.nunito(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xEBFFFFFF),
                        ),
                      ),
                      Text(
                        '%${_progress.round()}',
                        style: GoogleFonts.baloo2(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFFD34D),
                          shadows: const [
                            Shadow(
                              color: Color(0x99000000),
                              offset: Offset(0, 2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Sayfa 2 Geçit Böcekleri (Parade Walkers)
class _ParadeWalkersWidget extends StatefulWidget {
  const _ParadeWalkersWidget();

  @override
  State<_ParadeWalkersWidget> createState() => _ParadeWalkersWidgetState();
}

class _ParadeWalkersWidgetState extends State<_ParadeWalkersWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          children: [
            _buildWalker(
              tier: 1,
              bottom: 24,
              size: 62,
              progress: (t * (10.0 / 7.0) + 0.14) % 1.0,
            ),
            _buildWalker(
              tier: 2,
              bottom: 64,
              size: 52,
              progress: (t * (10.0 / 8.5) + 0.47) % 1.0,
            ),
            _buildWalker(
              tier: 3,
              bottom: 18,
              size: 74,
              progress: (t * (10.0 / 6.2) + 0.52) % 1.0,
            ),
            _buildWalker(
              tier: 4,
              bottom: 104,
              size: 48,
              progress: (t * (10.0 / 9.4) + 0.64) % 1.0,
            ),
            _buildWalker(
              tier: 5,
              bottom: 30,
              size: 58,
              progress: (t * (10.0 / 7.8) + 0.69) % 1.0,
            ),
            _buildWalker(
              tier: 6,
              bottom: 78,
              size: 54,
              progress: (t * (10.0 / 8.9) + 0.25) % 1.0,
            ),
            _buildWalker(
              tier: 7,
              bottom: 14,
              size: 80,
              progress: (t * (10.0 / 5.8) + 0.10) % 1.0,
            ),
            _buildWalker(
              tier: 8,
              bottom: 118,
              size: 46,
              progress: (t * (10.0 / 10.2) + 0.75) % 1.0,
            ),
          ],
        );
      },
    );
  }

  Widget _buildWalker({
    required int tier,
    required double bottom,
    required double size,
    required double progress,
  }) {
    // x from -84 to 360
    final x = -84.0 + (360.0 - (-84.0)) * progress;
    final bob = math.sin(progress * 40 * math.pi) * 3.0;
    final rot = math.sin(progress * 40 * math.pi) * (3.5 * math.pi / 180);

    return Positioned(
      left: x,
      bottom: bottom + bob,
      child: Transform.rotate(
        angle: rot,
        child: Image.asset(
          'assets/design/bugs_hd/tier${tier}_hd.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Sayfa 2 Mod Çipi
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.title,
    required this.assetPath,
    required this.fallbackAssetPath,
  });

  final String title;
  final String assetPath;
  final String fallbackAssetPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xA8080B12), // rgba(8,11,18,.66)
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            assetPath,
            width: 27,
            height: 27,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Image.asset(
              fallbackAssetPath,
              width: 27,
              height: 27,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.05,
                letterSpacing: 0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
