import 'package:flutter/material.dart';

import '../theme/lululu_theme.dart';

/// Masaüstü/web'de oyunu telefon-tablet çerçevesine oturtur.
///
/// Pencere genişliği 834 dp ve altındaysa çerçeveyi doldurur; üstündeyse
/// ortalanmış, tam yükseklikte 834 dp genişliğinde bir çerçeve çizer,
/// çerçeve dışı [LululuColors.carbonVoid] olur. Çerçeve içinde
/// [MediaQuery] boyutu çerçeve boyutuyla override edilir — ekranlar
/// pencere genişliğini (örn. 2560) değil çerçeve genişliğini görür,
/// yoksa 834'lük çerçevenin içinde taşarlar.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  /// Çerçevenin azami genişliği — tablet üst sınırı.
  static const double maxWidth = 834.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final windowWidth = constraints.maxWidth;
        final frameWidth = windowWidth.isFinite && windowWidth < maxWidth
            ? windowWidth
            : maxWidth;
        final framed = SizedBox(
          width: frameWidth,
          height: constraints.maxHeight,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(size: Size(frameWidth, constraints.maxHeight)),
            child: child,
          ),
        );
        if (!windowWidth.isFinite || windowWidth <= maxWidth) {
          return framed;
        }
        return ColoredBox(
          color: LululuColors.carbonVoid,
          child: Center(child: framed),
        );
      },
    );
  }
}
