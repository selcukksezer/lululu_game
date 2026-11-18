import 'package:flutter/material.dart';

/// Paylaşılan çıkış-sonrası bildirim yardımcısı (S6, Faz 3).
///
/// Sorun: enerji iadesi `PopScope` `didPop` SONRASINDA olur; o anda
/// çıkan ekranın bağlamı artık ağaçta değildir, bu yüzden
/// `ScaffoldMessenger.of(context)` kullanılamaz. Çözüm: `MaterialApp`
/// düzeyinde tek bir [messengerKey] ([main.dart] içinde
/// `scaffoldMessengerKey` olarak bağlanır) ve pop-sonrası güvenli
/// [showSnackBar]. Bildirim metni yerelleştirilmiş hâliyle çağrı
/// noktasında (çıkıştan ÖNCE, `build` içinde) yakalanır; bu yardımcı
/// yalnızca gösterimi üstlenir.
///
/// Güvenlik sözleşmesi: anahtar bağlı değilse, messenger `mounted`
/// değilse veya metin boşsa SESSİZCE no-op olur — asla fırlatmaz.
/// Bildirim kaybı oyunu bozmaz; iade her hâlükârda yapılmış olur.
///
/// Stil, balon/stack S6 bildirimleriyle birebir aynıdır (koyu yüzen
/// çubuk, Nunito 800, 1600 ms) — modlar arası tutarlılık için
/// burada tekilleştirilmiştir.
class GlobalNotify {
  GlobalNotify._();

  /// `MaterialApp.scaffoldMessengerKey` — `lib/main.dart` içinde
  /// `MaterialApp`'a bağlanır. `Navigator` üstünde yaşadığı için rota
  /// çıkışlarında (pop) hayatta kalır.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// [message] metnini paylaşılan messenger üzerinden gösterir.
  ///
  /// Gösterim bir sonraki kareye ertelenir (`addPostFrameCallback`):
  /// `didPop` anında pop animasyonu sürüyor olabilir; erteleme
  /// bildirimin çıkış yapılan (alttaki) ekranın üstünde görünmesini
  /// sağlar. [message] `null` veya boşsa, ya da messenger o anda
  /// kullanılamıyorsa sessizce geçilir.
  static void showSnackBar(String? message) {
    if (message == null || message.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final messenger = messengerKey.currentState;
        if (messenger == null || !messenger.mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              message,
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
      } catch (_) {
        // Bildirim en iyi çabayla gösterilir: messenger'ın o anda
        // kullanılamaz olması (örn. ağaç sökülürken) iade akışını
        // veya çıkışı asla bozmamalıdır.
      }
    });
  }
}
