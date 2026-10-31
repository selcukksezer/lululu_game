import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'auth_service.dart';

/// Arkadaş davet / rival kod — yerel; deep link sonra.
class FriendInviteService extends ChangeNotifier {
  FriendInviteService._();
  static final instance = FriendInviteService._();

  String? _code;

  String get inviteCode {
    _code ??= _makeCode();
    return _code!;
  }

  String _makeCode() {
    final id = AuthService.instance.playerId.hashCode.abs().toRadixString(36);
    final r = Random().nextInt(999).toString().padLeft(3, '0');
    return 'LULU-${id.toUpperCase().padLeft(4, 'X').substring(0, 4)}$r';
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
