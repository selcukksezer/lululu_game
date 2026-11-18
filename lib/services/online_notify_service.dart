import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Online modu "haberdar et" tercihi — tek kaynak (3H B7/K19).
///
/// Hub'daki "Haberdar Et" düğmesi ile Online ekranındaki düğme AYNI
/// servisi okuyup yazar; durum [SharedPreferences] ile kalıcıdır,
/// yeniden başlatmada korunur, iki ekran tutarlı gösterir.
///
/// DÜRÜSTLÜK: bu servis bildirim GÖNDERMEZ — push altyapısı yoktur.
/// Yalnızca kullanıcının "kayıtlı tercih"ini saklar.
class OnlineNotifyService extends ChangeNotifier {
  OnlineNotifyService._();
  static final OnlineNotifyService instance = OnlineNotifyService._();
  factory OnlineNotifyService() => instance;

  static const _prefsKey = 'lululu.online_notify';

  bool _loaded = false;
  bool _subscribed = false;

  /// Devam eden `load()` çağrısı (uçuş koruması): eşzamanlı
  /// `load()`/`ensureLoaded()` çağrıları aynı yüklemeyi paylaşır.
  Future<void>? _loadFuture;

  bool get isSubscribed => _subscribed;
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  /// Kalıcı tercihi yükler. Eşzamanlı çağrılar aynı yüklemeyi
  /// paylaşır (uçuş koruması); yükleme bittikten sonra yeniden
  /// çağrılırsa prefs'ten tekrar okur (yeniden yükleme korunur).
  Future<void> load() async {
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;
    final future = _loadAsync();
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
  }

  Future<void> _loadAsync() async {
    final prefs = await SharedPreferences.getInstance();
    _subscribed = prefs.getBool(_prefsKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  /// Tercihi yazar (önce yükleme tamamlanır ki geç tamamlanan bir
  /// `load()` yazmayı ezmesin). Değer değişmediyse yazma/bildirim yok.
  Future<void> setSubscribed(bool value) async {
    await ensureLoaded();
    if (_subscribed == value) return;
    _subscribed = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
    notifyListeners();
  }

  /// Tercihi çevirir, yeni durumu döner (düğme bildirimleri için).
  Future<bool> toggle() async {
    await ensureLoaded();
    await setSubscribed(!_subscribed);
    return _subscribed;
  }
}
