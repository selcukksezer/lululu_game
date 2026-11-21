import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'progress_manager.dart';

/// Davet kodu karşılama (redeem) sonucu.
enum InviteRedeemResult {
  /// Kod geçerliydi, ödül verildi.
  success,

  /// Kod biçimi `LULU-[0-9A-Z]{4}[0-9]{3}` kalıbına uymuyor.
  invalidFormat,

  /// Girilen kod oyuncunun kendi kodu.
  ownCode,

  /// Kod bu cihazda daha önce kullanıldı (ödül kod başına bir kez).
  alreadyRedeemed,
}

/// [FriendInviteService.redeemCode] dönüşü: enum'lu sonuç + başarıda
/// verilen ödül tutarı. Bool + string değil; çağrıcı UI'da doğru
/// mesajı sonuçtan seçer.
class InviteRedeemOutcome {
  const InviteRedeemOutcome(this.result, {this.rewardCoins = 0});

  final InviteRedeemResult result;

  /// Yalnız [InviteRedeemResult.success] için doludur.
  final int rewardCoins;

  bool get succeeded => result == InviteRedeemResult.success;
}

/// Arkadaş davet / rival kod — yerel; deep link sonra.
///
/// BAYRAK — sunucu doğrulaması YOKTUR: redeem yalnız yerel biçim
/// denetimi (`LULU-[0-9A-Z]{4}[0-9]{3}`) + bu cihazda kod başına
/// tek-kullanım kuralıdır. Girilen kodun gerçek bir oyuncuya ait
/// olduğu doğrulanmaz; uydurma bir kod da biçim tutuyorsa ödül
/// verir. Gerçek doğrulama sunucu tarafı ister (bu işin dışı).
///
/// BAYRAK — kod istikrarsızlığı: [inviteCode] `_makeCode` ile
/// üretilir ve üretimde `Random` 3 hane kullanılır; uygulama yeniden
/// başlatılınca kod değişebilir. Bu iş üretimi değiştirmez.
class FriendInviteService extends ChangeNotifier {
  FriendInviteService._();
  static final instance = FriendInviteService._();

  /// Başarılı redeem başına verilen coin (Selçuk kararı, brif 9A).
  /// Günlük ödül ölçeği ~55–200 coin; 100 bu aralığın ortasıdır.
  static const int redeemRewardCoins = 100;

  /// Kullanılmış kodların saklandığı prefs anahtarı (StringList,
  /// normalize edilmiş — tiresiz, büyük harfli — hâli).
  static const String redeemedCodesPrefKey =
      'lululu_redeemed_invite_codes_v1';

  /// Biçim: tireli `LULU-AB12345` veya tiresiz `LULUAB12345`.
  static final RegExp _codePattern = RegExp(r'^LULU[0-9A-Z]{4}[0-9]{3}$');

  String? _code;
  String? _codePlayerId;

  /// Kullanılmış kodlar (normalize edilmiş). `null` = henüz yüklenmedi.
  Set<String>? _redeemed;

  String get inviteCode {
    // Oyuncu kimliği değişirse (misafir -> giriş yapmış hesap) eski
    // kimlikten türetilmiş kod kullanılmaz, yeniden üretilir.
    final playerId = AuthService.instance.playerId;
    if (_code == null || _codePlayerId != playerId) {
      _codePlayerId = playerId;
      _code = _makeCode(playerId);
    }
    return _code!;
  }

  String _makeCode(String playerId) {
    final id = playerId.hashCode.abs().toRadixString(36);
    final r = Random().nextInt(999).toString().padLeft(3, '0');
    return 'LULU-${id.toUpperCase().padLeft(4, 'X').substring(0, 4)}$r';
  }

  /// Ham girdiyi kanonik biçime çevirir: trim + büyük harf + tireleri
  /// at. (Kod verisi normalizasyonudur; l10n `.toUpperCase()` yasağı
  /// UI metni içindir, kod normalizasyonunu kapsamaz.)
  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll('-', '');

  /// Kanonik (tiresiz, büyük harfli) kod biçim denetiminden geçer mi?
  static bool isValidFormat(String normalizedCode) =>
      _codePattern.hasMatch(normalizedCode);

  Future<void> ensureLoaded() async {
    if (_redeemed != null) return;
    final prefs = await SharedPreferences.getInstance();
    _redeemed = prefs.getStringList(redeemedCodesPrefKey)?.toSet() ?? <String>{};
  }

  /// Test kancası: bellek önbelleğini boşaltır; sonraki çağrı listeyi
  /// prefs'ten yeniden okur (uygulama yeniden başlatmayı simüle eder).
  @visibleForTesting
  void debugResetRedeemedCache() {
    _redeemed = null;
  }

  /// Davet kodu karşılama: biçim → kendi kodu → çift kullanım
  /// denetimlerinden geçer, başarıda +100 coin verir. Ödül kod başına
  /// bir kezdir: kod önce kalıcı listeye yazılır, sonra coin verilir;
  /// böylece iki çağrı arasında çökme olsa bile ikinci ödül çıkmaz.
  Future<InviteRedeemOutcome> redeemCode(String raw) async {
    final code = normalizeCode(raw);
    if (!isValidFormat(code)) {
      return const InviteRedeemOutcome(InviteRedeemResult.invalidFormat);
    }
    if (code == normalizeCode(inviteCode)) {
      return const InviteRedeemOutcome(InviteRedeemResult.ownCode);
    }
    await ensureLoaded();
    if (_redeemed!.contains(code)) {
      return const InviteRedeemOutcome(InviteRedeemResult.alreadyRedeemed);
    }
    _redeemed!.add(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      redeemedCodesPrefKey,
      _redeemed!.toList()..sort(),
    );
    await ProgressManager.instance.addCoins(redeemRewardCoins);
    notifyListeners();
    return const InviteRedeemOutcome(
      InviteRedeemResult.success,
      rewardCoins: redeemRewardCoins,
    );
  }

  Future<void> shareInvite() async {
    await AuthService.instance.ensureLoaded();
    final code = inviteCode;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Lülülü’de rakibim ol! Kod: $code\n#lululu #makarayız',
      ),
    );
    notifyListeners();
  }
}
