import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../theme/lululu_theme.dart';
import '../widgets/lululu_press.dart';

/// Giriş/kayıt paneli (widget). Ayarlar ekranından tam sayfa açılır.
class AuthPanel extends StatefulWidget {
  const AuthPanel({super.key});

  @override
  State<AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends State<AuthPanel> {
  bool _registerMode = false;
  bool _busy = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^.*?: '), '');
      _toast(msg.isEmpty ? 'Bir hata oluştu' : msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (user.isEmpty || pass.isEmpty) {
      _toast('Kullanıcı adı ve şifre gerekli');
      return;
    }
    if (_registerMode && pass != _confirmCtrl.text) {
      _toast('Şifreler eşleşmiyor');
      return;
    }
    final auth = AuthService.instance;
    if (_registerMode) {
      _run(() => auth.register(username: user, password: pass));
    } else {
      _run(() => auth.login(username: user, password: pass));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final auth = AuthService.instance;
        if (auth.isSignedIn) {
          return _SignedInCard(
            name: auth.displayName,
            busy: _busy,
            onSignOut: () => _run(() => auth.signOut()),
          );
        }
        return _AuthForm(
          registerMode: _registerMode,
          busy: _busy,
          obscurePass: _obscurePass,
          obscureConfirm: _obscureConfirm,
          userCtrl: _userCtrl,
          passCtrl: _passCtrl,
          confirmCtrl: _confirmCtrl,
          onToggleMode: (v) => setState(() => _registerMode = v),
          onToggleObscurePass: () =>
              setState(() => _obscurePass = !_obscurePass),
          onToggleObscureConfirm: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
          onSubmit: _submit,
          onGuest: () => _run(() => auth.signInAsGuest()),
          onApple: () => _run(() => auth.signInWithApple()),
          onGoogle: () => _run(() => auth.signInWithGoogle()),
        );
      },
    );
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({
    required this.name,
    required this.busy,
    required this.onSignOut,
  });

  final String name;
  final bool busy;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LululuGradients.paperHero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: LululuColors.paper,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 38,
              color: LululuColors.cyberFuchsia,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'GİRİŞ YAPILDI',
            style: GoogleFonts.exo2(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: LululuColors.paper.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: GoogleFonts.exo2(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: LululuColors.paper,
            ),
          ),
          const SizedBox(height: 16),
          LululuPress(
            onTap: busy ? () {} : onSignOut,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LululuColors.inkDark,
                borderRadius: BorderRadius.circular(14),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: LululuColors.liquidGold,
                      ),
                    )
                  : Text(
                      'ÇIKIŞ YAP',
                      style: GoogleFonts.exo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: LululuColors.paper,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.registerMode,
    required this.busy,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.userCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.onToggleMode,
    required this.onToggleObscurePass,
    required this.onToggleObscureConfirm,
    required this.onSubmit,
    required this.onGuest,
    required this.onApple,
    required this.onGoogle,
  });

  final bool registerMode;
  final bool busy;
  final bool obscurePass;
  final bool obscureConfirm;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final ValueChanged<bool> onToggleMode;
  final VoidCallback onToggleObscurePass;
  final VoidCallback onToggleObscureConfirm;
  final VoidCallback onSubmit;
  final VoidCallback onGuest;
  final VoidCallback onApple;
  final VoidCallback onGoogle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: LululuColors.paperSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              for (final tab in const [(false, 'GİRİŞ'), (true, 'KAYIT')])
                Expanded(
                  child: LululuPress(
                    onTap: () => onToggleMode(tab.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: registerMode == tab.$1
                            ? LululuColors.paper
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tab.$2,
                        style: GoogleFonts.exo2(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: registerMode == tab.$1
                              ? LululuColors.inkDark
                              : LululuColors.mutedTitanium,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Field(
          controller: userCtrl,
          hint: 'Kullanıcı adı',
          icon: Icons.person_outline_rounded,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 10),
        _Field(
          controller: passCtrl,
          hint: 'Şifre',
          icon: Icons.lock_outline_rounded,
          obscure: obscurePass,
          onToggleObscure: onToggleObscurePass,
        ),
        if (registerMode) ...[
          const SizedBox(height: 10),
          _Field(
            controller: confirmCtrl,
            hint: 'Şifre (tekrar)',
            icon: Icons.lock_outline_rounded,
            obscure: obscureConfirm,
            onToggleObscure: onToggleObscureConfirm,
          ),
        ],
        const SizedBox(height: 16),
        LululuPress(
          onTap: busy ? () {} : onSubmit,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LululuGradients.fuchsiaToGold,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: LululuColors.paper,
                    ),
                  )
                : Text(
                    registerMode ? 'KAYIT OL' : 'GİRİŞ YAP',
                    style: GoogleFonts.exo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: LululuColors.paper,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        LululuPress(
          onTap: busy ? () {} : onGuest,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: LululuColors.mutedTitanium.withValues(alpha: 0.4),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'MİSAFİR DEVAM ET',
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: LululuColors.inkDark,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'veya',
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  color: LululuColors.mutedTitanium,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        LululuPress(
          onTap: busy ? () {} : onApple,
          child: _SocialButton(
            label: 'Apple ile devam',
            icon: Icons.apple_rounded,
          ),
        ),
        const SizedBox(height: 10),
        LululuPress(
          onTap: busy ? () {} : onGoogle,
          child: _SocialButton(
            label: 'Google ile devam',
            icon: Icons.g_mobiledata_rounded,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.exo2(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: LululuColors.inkDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.exo2(color: LululuColors.mutedTitanium),
        prefixIcon: Icon(icon, color: LululuColors.mutedTitanium),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: LululuColors.mutedTitanium,
                ),
                onPressed: onToggleObscure,
              ),
        filled: true,
        fillColor: LululuColors.paperSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LululuColors.inkDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: LululuColors.paper, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.exo2(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: LululuColors.paper,
            ),
          ),
        ],
      ),
    );
  }
}
