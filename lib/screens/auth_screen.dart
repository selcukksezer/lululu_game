import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/leaderboard_service.dart';
import '../theme/lululu_theme.dart';

/// Gerçek kullanıcı adı + şifre kayıt/giriş · Apple · Google · Misafir.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.embedded = false});

  final bool embedded;

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => const AuthScreen(),
        transitionsBuilder: (_, anim, __, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
          return FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: curved, child: child),
          );
        },
      ),
    );
  }

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  bool _registerMode = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    AuthService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await LeaderboardService.instance.onAuthChanged();
      await CloudSyncService.instance.enableOnlineWhenSignedIn();
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ArgumentError || e is StateError
              ? e.toString().replaceFirst(RegExp(r'^(Bad state|Invalid argument):\s*'), '')
              : e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitLocal() async {
    final user = _userCtrl.text;
    final pass = _passCtrl.text;
    if (_registerMode) {
      await AuthService.instance.register(username: user, password: pass);
    } else {
      await AuthService.instance.login(username: user, password: pass);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final body = _AuthCard(
          busy: _busy,
          error: _error,
          userCtrl: _userCtrl,
          passCtrl: _passCtrl,
          registerMode: _registerMode,
          obscure: _obscure,
          signedIn: auth.isSignedIn,
          displayName: auth.displayName,
          provider: auth.user?.provider,
          onToggleMode: () => setState(() {
            _registerMode = !_registerMode;
            _error = null;
          }),
          onToggleObscure: () => setState(() => _obscure = !_obscure),
          onSubmit: () => _run(_submitLocal),
          onGuest: () => _run(() => auth.signInAsGuest()),
          onApple: () => _run(() => auth.signInWithApple()),
          onGoogle: () => _run(() => auth.signInWithGoogle()),
          onSignOut: () => _run(() async {
            await auth.signOut();
            await LeaderboardService.instance.onAuthChanged();
            await CloudSyncService.instance.enableOnlineWhenSignedIn();
          }),
          onClose: () => Navigator.of(context).maybePop(),
        );

        if (widget.embedded) return body;

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: LululuColors.carbonVoid.withValues(alpha: 0.5),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: body,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.busy,
    required this.userCtrl,
    required this.passCtrl,
    required this.registerMode,
    required this.obscure,
    required this.signedIn,
    required this.displayName,
    required this.onToggleMode,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onGuest,
    required this.onApple,
    required this.onGoogle,
    required this.onSignOut,
    required this.onClose,
    this.error,
    this.provider,
  });

  final bool busy;
  final String? error;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final bool registerMode;
  final bool obscure;
  final bool signedIn;
  final String displayName;
  final AuthProviderKind? provider;
  final VoidCallback onToggleMode;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onGuest;
  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onSignOut;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LululuColors.spaceNavy, LululuColors.carbonVoid],
        ),
        border: Border.all(
          color: LululuColors.liquidGold.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: LululuColors.liquidGold.withValues(alpha: 0.2),
            blurRadius: 28,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _AuthDots()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        registerMode ? 'KAYIT' : 'GİRİŞ',
                        style: GoogleFonts.exo2(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: LululuColors.ink,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                        color: LululuColors.mutedTitanium,
                      ),
                    ],
                  ),
                  Text(
                    'Kullanıcı adı + şifre ile gerçek hesap. Skorlar sıralamaya bağlanır.',
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      color: LululuColors.mutedTitanium,
                    ),
                  ),
                  if (signedIn) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: LululuColors.darkObsidian,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: LululuColors.toxicNeon.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: LululuColors.toxicNeon),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$displayName · ${provider?.name ?? ''}',
                              style: GoogleFonts.exo2(
                                fontWeight: FontWeight.w700,
                                color: LululuColors.ink,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: busy ? null : onSignOut,
                            child: Text(
                              'Çıkış',
                              style: GoogleFonts.exo2(
                                color: LululuColors.mysticRuby,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ModeChip(
                          label: 'Giriş',
                          selected: !registerMode,
                          onTap: registerMode ? onToggleMode : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ModeChip(
                          label: 'Kayıt',
                          selected: registerMode,
                          onTap: !registerMode ? onToggleMode : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: userCtrl,
                    style: const TextStyle(color: LululuColors.ink),
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDeco('Kullanıcı adı'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: obscure,
                    style: const TextStyle(color: LululuColors.ink),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => busy ? null : onSubmit(),
                    decoration: _fieldDeco('Şifre').copyWith(
                      suffixIcon: IconButton(
                        onPressed: onToggleObscure,
                        icon: Icon(
                          obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: LululuColors.mutedTitanium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _AuthBtn(
                    label: registerMode ? 'KAYIT OL' : 'GİRİŞ YAP',
                    accent: LululuColors.liquidGold,
                    primary: true,
                    busy: busy,
                    onTap: onSubmit,
                  ),
                  const SizedBox(height: 10),
                  _AuthBtn(
                    label: 'MİSAFİR DEVAM ET',
                    accent: LululuColors.mutedTitanium,
                    busy: busy,
                    onTap: onGuest,
                  ),
                  const SizedBox(height: 10),
                  _AuthBtn(
                    label: 'Apple ile devam',
                    icon: Icons.apple,
                    accent: LululuColors.ink,
                    busy: busy,
                    onTap: onApple,
                  ),
                  const SizedBox(height: 10),
                  _AuthBtn(
                    label: 'Google ile devam',
                    icon: Icons.g_mobiledata_rounded,
                    accent: LululuColors.coralFlare,
                    busy: busy,
                    onTap: onGoogle,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: GoogleFonts.exo2(
                        color: LululuColors.mysticRuby,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  InputDecoration _fieldDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: LululuColors.mutedTitanium),
      filled: true,
      fillColor: LululuColors.darkObsidian,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: LululuColors.cyberFuchsia.withValues(alpha: 0.4),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: LululuColors.cyberFuchsia.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? LululuColors.darkObsidian
              : LululuColors.carbonVoid.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? LululuColors.toxicNeon.withValues(alpha: 0.55)
                : LululuColors.mutedTitanium.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: selected ? LululuColors.toxicNeon : LululuColors.mutedTitanium,
          ),
        ),
      ),
    );
  }
}

class _AuthBtn extends StatefulWidget {
  const _AuthBtn({
    required this.label,
    required this.accent,
    required this.onTap,
    this.icon,
    this.primary = false,
    this.busy = false,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;
  final IconData? icon;
  final bool primary;
  final bool busy;

  @override
  State<_AuthBtn> createState() => _AuthBtnState();
}

class _AuthBtnState extends State<_AuthBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.busy ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.busy ? null : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.busy ? null : widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: widget.primary
                ? const LinearGradient(
                    colors: [
                      LululuColors.liquidGold,
                      LululuColors.warningSolar,
                    ],
                  )
                : null,
            color: widget.primary ? null : LululuColors.darkObsidian,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.5),
            ),
          ),
          child: widget.busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: widget.accent, size: 22),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.6,
                        color: widget.primary
                            ? LululuColors.carbonVoid
                            : LululuColors.ink,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AuthDots extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 14.0;
    final paint = Paint()..color = LululuColors.dotMesh(opacity: 0.08);
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
