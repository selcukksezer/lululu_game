import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının seçtiği oyun dili (TR/EN).
///
/// Varsayılan davranış cihaz dilidir (EN cihazda EN, aksi hâlde TR —
/// [AppLocalizations.localeResolutionCallback] kuralı). Kullanıcı
/// Ayarlar'dan bir dil seçerse seçim kalıcı olur ve cihaz kuralını
/// ezer; seçim [overrideNotifier] üzerinden kök [MaterialApp]'e
/// bildirilir, uygulama yeniden başlatılmadan dil değiştirir.
///
/// Selçuk kararı (2026-11-18): arayüz tek dile kilitlenmez, TR/EN
/// seçeneği olur.
class LocaleService {
  LocaleService._();

  static final LocaleService instance = LocaleService._();

  static const String _prefsKey = 'lululu_locale';

  /// null = kullanıcı seçimi yok, cihaz kuralı geçerli.
  final ValueNotifier<Locale?> overrideNotifier = ValueNotifier<Locale?>(null);

  String? get currentCode => overrideNotifier.value?.languageCode;

  /// Ekranda gösterilecek etkin dil kodu ('tr' ya da 'en').
  String effectiveCode() {
    switch (currentCode) {
      case 'tr':
        return 'tr';
      case 'en':
        return 'en';
      default:
        final device = WidgetsBinding.instance.platformDispatcher.locale;
        return device.languageCode == 'en' ? 'en' : 'tr';
    }
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code == 'tr') {
        overrideNotifier.value = const Locale('tr');
      } else if (code == 'en') {
        overrideNotifier.value = const Locale('en');
      }
    } catch (e) {
      debugPrint('[LocaleService] dil tercihi okunamadi: $e');
    }
  }

  Future<void> setLocaleCode(String code) async {
    assert(code == 'tr' || code == 'en');
    overrideNotifier.value = Locale(code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (e) {
      debugPrint('[LocaleService] dil tercihi yazilamadi: $e');
    }
  }
}
