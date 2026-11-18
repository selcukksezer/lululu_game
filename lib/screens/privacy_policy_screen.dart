import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/audio_manager.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';

/// Uygulama içi gizlilik politikası metni.
///
/// DÜRÜSTLÜK NOTU: Bu metin, kodda görülen gerçek davranışlara dayanır
/// (AuthService yerel kayıt + Firebase Auth, CloudSyncService Firestore
/// eşitleme, MicScreamService desibel ölçümü, cihaz içi reklam yer tutucusu).
/// Toplanmayan veriler "toplanıyor" gibi yazılmadı; URL uydurulmadı.
///
/// YAYIN URL'Sİ SELÇUK'UN İŞİ: Mağaza listeleme sayfası için gereken herkese
/// açık gizlilik politikası URL'si (ve varsa iletişim adresi) Selçuk
/// tarafından sağlanacak; bu dosyaya URL eklenmedi.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF05070C),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.l10n.goBackLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          context.l10n.privacyTitle,
          style: GoogleFonts.baloo2(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.privacyIntro,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFD8E0EE),
                height: 1.55,
              ),
            ),
            _section(
              context.l10n.privacySection1Title,
              [
                context.l10n.privacySection1Body1,
                context.l10n.privacySection1Body2,
                context.l10n.privacySection1Body3,
                context.l10n.privacySection1Body4,
              ],
            ),
            _section(
              context.l10n.privacySection2Title,
              [
                context.l10n.privacySection2Body1,
                context.l10n.privacySection2Body2,
                context.l10n.privacySection2Body3,
              ],
            ),
            _section(
              context.l10n.privacySection3Title,
              [
                context.l10n.privacySection3Body1,
                context.l10n.privacySection3Body2,
              ],
            ),
            _section(
              context.l10n.privacySection4Title,
              [
                context.l10n.privacySection4Body1,
              ],
            ),
            _section(
              context.l10n.privacySection5Title,
              [
                context.l10n.privacySection5Body1,
                context.l10n.privacySection5Body2,
                context.l10n.privacySection5Body3,
              ],
            ),
            const SizedBox(height: 16),
            const _DeleteAccountButton(),
            _section(
              context.l10n.privacySection6Title,
              [
                context.l10n.privacySection6Body1,
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: context.l10n.closeLabel,
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
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
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFB97A00),
                        offset: Offset(0, 5),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: Color(0x47000000),
                        offset: Offset(0, 10),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    context.l10n.close,
                    style: GoogleFonts.baloo2(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.36,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<String> bullets) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.baloo2(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFFB800),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          for (final bullet in bullets) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD8E0EE),
                      height: 1.55,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD8E0EE),
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hesap silme düğmesi (madde 97): yalnızca gerçek (misafir olmayan)
/// oturumlarda görünür.
///
/// İki dokunuşlu onay: ilk dokunuş düğmeyi YERİNDE
/// "EMİN MİSİN? TEKRAR DOKUN" yapar; 5 saniye içinde ikinci dokunuş
/// gelmezse düğme eski hâline döner. Durum bu widget'a özeldir: ilk
/// dokunuş yalnız düğmeyi yeniden çizer, sayfanın kaydırma konumu ve
/// metin ağacı etkilenmez. İkinci dokunuş hesabı silip kullanıcıyı
/// giriş/kayıt akışına gönderir.
class _DeleteAccountButton extends StatefulWidget {
  const _DeleteAccountButton();

  @override
  State<_DeleteAccountButton> createState() => _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends State<_DeleteAccountButton> {
  bool _armed = false;
  bool _busy = false;
  Timer? _armTimer;

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    AudioManager().playPop();
    if (!_armed) {
      setState(() => _armed = true);
      _armTimer?.cancel();
      _armTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _armed = false);
        }
      });
      return;
    }
    _armTimer?.cancel();
    setState(() => _busy = true);
    try {
      await AuthService.instance.deleteAccount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _armed = false;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.accountDeleteFailed('$e'))),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.accountDeletedSnack)),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthUser?>(
      valueListenable: AuthService.instance.currentUserNotifier,
      builder: (context, user, _) {
        if (user == null || !user.isSignedIn || user.isGuest) {
          return const SizedBox.shrink();
        }
        final label = _busy
            ? context.l10n.deletingLabel
            : _armed
                ? context.l10n.confirmDeleteAgain
                : context.l10n.deleteAccountCaps;
        final armedOrBusy = _armed || _busy;
        return Semantics(
          button: true,
          enabled: !_busy,
          label: label,
          child: GestureDetector(
            onTap: _busy ? null : _handleTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(
                horizontal: 26,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: armedOrBusy ? null : const Color(0xFF121826),
                gradient: armedOrBusy
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.55, 1.0],
                        colors: [
                          Color(0xFFF4538B),
                          Color(0xFFE01E5A),
                          Color(0xFFB80F42),
                        ],
                      )
                    : null,
                border: armedOrBusy
                    ? null
                    : Border.all(
                        color: const Color(0xFFE01E5A),
                        width: 1.5,
                      ),
                boxShadow: armedOrBusy
                    ? const [
                        BoxShadow(
                          color: Color(0xFF7E0A2E),
                          offset: Offset(0, 5),
                          blurRadius: 0,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: armedOrBusy ? Colors.white : const Color(0xFFF4538B),
                  letterSpacing: 0.36,
                  height: 1.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
