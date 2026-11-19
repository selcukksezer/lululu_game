import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/audio_manager.dart';
import '../services/friend_invite_service.dart';

/// 9A — davet sheet'ini açar (profil satırı + hub kartı aynı sheet'i
/// kullanır; paylaşım akışı aynen korunur, altına kod karşılama
/// eklenir).
Future<void> showInviteRedeemSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => Padding(
      padding: MediaQuery.viewInsetsOf(sheetContext),
      child: const SingleChildScrollView(child: InviteRedeemSheet()),
    ),
  );
}

/// Davet paylaşımı + kod karşılama (redeem) sheet'i.
///
/// Üstte kendi kodu + paylaş düğmesi (K17 akışı aynen), altta kod
/// girişi + karşılama düğmesi (9A). Sunucu doğrulaması yoktur: redeem
/// yalnız yerel biçim denetimi + bu cihazda kod başına tek-kullanım
/// kuralıdır; bu sınır sheet'in altında açıkça yazar.
class InviteRedeemSheet extends StatefulWidget {
  const InviteRedeemSheet({super.key});

  @override
  State<InviteRedeemSheet> createState() => _InviteRedeemSheetState();
}

class _InviteRedeemSheetState extends State<InviteRedeemSheet> {
  final TextEditingController _codeController = TextEditingController();
  InviteRedeemResult? _errorResult;
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _shareInvite() async {
    AudioManager().playPop();
    try {
      await FriendInviteService.instance.shareInvite();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileInviteFailed)),
      );
    }
  }

  Future<void> _redeem() async {
    if (_busy) return;
    AudioManager().playPop();
    setState(() {
      _busy = true;
      _errorResult = null;
    });
    final outcome = await FriendInviteService.instance.redeemCode(
      _codeController.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final l10n = context.l10n;
    if (outcome.succeeded) {
      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.inviteRedeemSuccess(outcome.rewardCoins)),
        ),
      );
      return;
    }
    setState(() => _errorResult = outcome.result);
  }

  String _errorText(AppLocalizations l10n) {
    return switch (_errorResult) {
      InviteRedeemResult.invalidFormat => l10n.inviteRedeemErrorInvalid,
      InviteRedeemResult.ownCode => l10n.inviteRedeemErrorOwn,
      InviteRedeemResult.alreadyRedeemed => l10n.inviteRedeemErrorUsed,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ownCode = FriendInviteService.instance.inviteCode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.profileInviteRowTitle,
            style: const TextStyle(
              fontFamily: 'Baloo 2',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF141B2A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.profileInviteRowSub,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF66738A),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ownCode,
                    style: const TextStyle(
                      fontFamily: 'Baloo 2',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF141B2A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: l10n.shareButton,
                child: GestureDetector(
                  onTap: _shareInvite,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFCF3F),
                          Color(0xFFFFB800),
                          Color(0xFFF59E00),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.shareButton,
                      style: const TextStyle(
                        fontFamily: 'Baloo 2',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE3E8F0)),
          const SizedBox(height: 16),
          Text(
            l10n.inviteRedeemTitle,
            style: const TextStyle(
              fontFamily: 'Baloo 2',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF141B2A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('invite_redeem_code_field'),
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 12,
            decoration: InputDecoration(
              hintText: l10n.inviteRedeemHint,
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF4F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _redeem(),
            onChanged: (_) {
              if (_errorResult != null) {
                setState(() => _errorResult = null);
              }
            },
          ),
          if (_errorResult != null) ...[
            const SizedBox(height: 6),
            Text(
              _errorText(l10n),
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD32F2F),
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: l10n.inviteRedeemButton,
            child: GestureDetector(
              key: const Key('invite_redeem_button'),
              onTap: _redeem,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFCF3F),
                      Color(0xFFFFB800),
                      Color(0xFFF59E00),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFFB97A00),
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n.inviteRedeemButton,
                        style: const TextStyle(
                          fontFamily: 'Baloo 2',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.inviteRedeemLocalNote,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF66738A),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
