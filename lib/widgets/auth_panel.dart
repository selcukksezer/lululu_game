import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/audio_manager.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/leaderboard_service.dart';

/// Reusable `#scr-account` auth card widget (`406px` max-width) matching
/// `reference-account.png` and `reference-account-spec.json`.
class AuthPanel extends StatefulWidget {
  final VoidCallback? onSuccess;
  final VoidCallback? onClose;

  const AuthPanel({
    super.key,
    this.onSuccess,
    this.onClose,
  });

  static Future<bool?> showSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 12,
          right: 12,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: AuthPanel(
            onSuccess: () => Navigator.of(ctx).pop(true),
            onClose: () => Navigator.of(ctx).pop(false),
          ),
        ),
      ),
    );
  }

  @override
  State<AuthPanel> createState() => _AuthPanelState();
}

/// Paylaşılan misafir-giriş düğmesi (`#authGuest.auth-guest` -> height: 52,
/// beyaz zemin, 2px `#B97A2E` kenarlık).
///
/// AuthPanel ve AuthScreen'deki yinelenen misafir düğmelerinin tek tanımıdır.
/// Görünüm burada, dokunma davranışı (`onTap`) çağıran ekrana aittir; her
/// ekranın kendi meşgul/hata akışı (AuthScreen'de `_run`, AuthPanel'de
/// `_continueAsGuest`) aynen korunur.
class GuestSignInButton extends StatelessWidget {
  const GuestSignInButton({super.key, required this.onTap});

  /// Null ise düğme devre dışıdır.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: context.l10n.guestContinueLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFB97A2E),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFFB97A2E),
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            context.l10n.guestContinueButton,
            style: GoogleFonts.baloo2(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF8A5220),
              letterSpacing: 0.4,
              height: 1.0,
            ).copyWith(
              fontFamily: 'Baloo 2',
              fontWeight: FontWeight.w800,
              fontFamilyFallback: const ['Nunito'],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthPanelState extends State<AuthPanel> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isRegister = false;
  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  TextStyle _baloo2({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    ).copyWith(
      fontFamily: 'Baloo 2',
      fontWeight: fontWeight,
      fontFamilyFallback: const ['Nunito'],
    );
  }

  TextStyle _nunito({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    ).copyWith(
      fontFamily: 'Nunito',
      fontWeight: fontWeight,
      fontFamilyFallback: const ['Baloo 2'],
    );
  }

  Future<void> _submitLocal() async {
    if (_busy) return;
    AudioManager().playPop();
    setState(() {
      _busy = true;
      _error = null;
    });
    final username = _usernameCtrl.text;
    final password = _passwordCtrl.text;
    try {
      if (_isRegister) {
        await AuthService.instance.register(
          username: username,
          password: password,
        );
      } else {
        await AuthService.instance.login(
          username: username,
          password: password,
        );
      }
      await LeaderboardService.instance.onAuthChanged();
      await CloudSyncService.instance.enableOnlineWhenSignedIn();
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Invalid argument(s): ', '');
      });
    }
  }

  Future<void> _continueAsGuest() async {
    if (_busy) return;
    AudioManager().playPop();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInAsGuest();
      await LeaderboardService.instance.onAuthChanged();
      await CloudSyncService.instance.enableOnlineWhenSignedIn();
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Invalid argument(s): ', '');
      });
    }
  }

  Future<void> _signInProvider(String provider) async {
    if (_busy) return;
    AudioManager().playPop();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (provider == 'google') {
        await AuthService.instance.signInWithGoogle();
      } else {
        await AuthService.instance.signInWithApple();
      }
      await LeaderboardService.instance.onAuthChanged();
      await CloudSyncService.instance.enableOnlineWhenSignedIn();
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Invalid argument(s): ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final hasSession = user != null && !user.isGuest;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFFB97A2E),
              width: 3,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFBEC),
                Color(0xFFFFEFC4),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x732B1600),
                offset: Offset(0, 24),
                blurRadius: 44,
              ),
              BoxShadow(
                color: Color(0xFF8A5220),
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: CustomPaint(
              painter: const _AuthPanelPatternPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isRegister
                              ? context.l10n.registerButtonShort
                              : context.l10n.loginButtonShort,
                          style: _baloo2(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFE01E5A),
                            letterSpacing: 0.3,
                            height: 28.35 / 27.0,
                            shadows: const [
                              Shadow(
                                color: Colors.white,
                                offset: Offset(0, 2),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                        ),
                        if (widget.onClose != null)
                          Semantics(
                            button: true,
                            label: context.l10n.closeLabel,
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: () {
                              AudioManager().playPop();
                              widget.onClose!();
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFB97A2E),
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFFB97A2E),
                                    offset: Offset(0, 3),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF8A5220),
                                size: 22,
                              ),
                            ),
                          ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      context.l10n.authCardSubtitle,
                      style: _nunito(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7A5A28),
                        height: 20.25 / 13.5,
                      ),
                    ),
                    if (hasSession) ...[
                      const SizedBox(height: 14),
                      _buildSessionBanner(user),
                    ],
                    const SizedBox(height: 14),
                    _buildTabs(),
                    const SizedBox(height: 13),
                    _buildInputField(
                      controller: _usernameCtrl,
                      hintText: context.l10n.usernameHintDetailed,
                      obscureText: false,
                    ),
                    const SizedBox(height: 10),
                    _buildInputField(
                      controller: _passwordCtrl,
                      hintText: context.l10n.passwordHintDetailed,
                      obscureText: _obscurePassword,
                      suffix: Semantics(
                        button: true,
                        label: _obscurePassword
                            ? context.l10n.showPasswordLabel
                            : context.l10n.hidePasswordLabel,
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () {
                            AudioManager().playPop();
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF8A6A30),
                            size: 21,
                          ),
                        ),
                      ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        style: _nunito(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFC81E1E),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildSubmitButton(),
                    const SizedBox(height: 13),
                    _buildOrDivider(),
                    const SizedBox(height: 11),
                    GuestSignInButton(
                      onTap: _busy ? null : _continueAsGuest,
                    ),
                    const SizedBox(height: 9),
                    _buildSocialButton(
                      label: context.l10n.continueWithApple,
                      icon: const Icon(
                        Icons.apple,
                        color: Color(0xFF33200A),
                        size: 22,
                      ),
                      onTap: () => _signInProvider('apple'),
                    ),
                    const SizedBox(height: 9),
                    _buildSocialButton(
                      label: context.l10n.continueWithGoogle,
                      icon: const Icon(
                        Icons.g_mobiledata_rounded,
                        color: Color(0xFF4285F4),
                        size: 26,
                      ),
                      onTap: () => _signInProvider('google'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 22,
          top: -28,
          child: Transform.rotate(
            angle: -8 * 3.141592653589793 / 180.0,
            child: Image.asset(
              'assets/design/ui/studio_create/img_3.png',
              width: 60,
              height: 60,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionBanner(AuthUser user) {
    return Container(
      height: 70,
      padding: const EdgeInsets.fromLTRB(11, 9, 8, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFBF3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF12B76A),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x590A9553),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2FE079),
                  Color(0xFF0A9553),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF066C3C),
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.displayName} · ${user.provider.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _baloo2(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4A2E00),
                    height: 16.675 / 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.authSessionOpen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0A9553),
                    height: 16.0 / 12.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Semantics(
            button: true,
            label: context.l10n.signOutButton,
            child: GestureDetector(
              onTap: _busy
                  ? null
                  : () async {
                      AudioManager().playPop();
                      await AuthService.instance.signOut();
                      await LeaderboardService.instance.onAuthChanged();
                      if (!mounted) return;
                      setState(() {});
                    },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0x66E52E2E),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  context.l10n.signOutButton,
                  style: _baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE52E2E),
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3DFAE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              label: context.l10n.loginTab,
              active: !_isRegister,
              onTap: () {
                AudioManager().playPop();
                setState(() {
                  _isRegister = false;
                  _error = null;
                });
              },
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _buildTabItem(
              label: context.l10n.registerTab,
              active: _isRegister,
              onTap: () {
                AudioManager().playPop();
                setState(() {
                  _isRegister = true;
                  _error = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.55, 1.0],
                    colors: [
                      Color(0xFFFFCF3F),
                      Color(0xFFFFB800),
                      Color(0xFFF59E00),
                    ],
                  )
                : null,
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0xFFB97A00),
                      offset: Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: _baloo2(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: active
                  ? const Color(0xFF4A2E00)
                  : const Color(0xFF8A6A30),
              letterSpacing: 0.3,
              height: 1.0,
            ),
          ),
        ),
      );
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    Widget? suffix,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE3C98F),
          width: 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 54, 0),
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              style: _nunito(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF33200A),
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: _nunito(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFA08860),
                ),
              ),
            ),
          ),
          if (suffix != null)
            Positioned(
              right: 3,
              top: 2,
              bottom: 2,
              child: suffix,
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Semantics(
      button: true,
      label: _isRegister ? context.l10n.createAccountButton : context.l10n.signInButton,
      child: GestureDetector(
        onTap: _busy ? null : _submitLocal,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
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
                color: Color(0x47000000),
                offset: Offset(0, 10),
                blurRadius: 18,
              ),
              BoxShadow(
                color: Color(0xFFB97A00),
                offset: Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _isRegister
                ? context.l10n.createAccountButton
                : context.l10n.signInButton,
            style: _baloo2(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.4,
              height: 1.0,
              shadows: const [
                Shadow(
                  color: Color(0x59000000),
                  offset: Offset(0, 2),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ),
      );
    );
  }

  Widget _buildOrDivider() {
    return SizedBox(
      height: 17.8,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2,
              color: const Color(0xFFE3C98F),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            context.l10n.orDivider,
            style: _baloo2(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFA67C3D),
              letterSpacing: 1.0,
              height: 17.825 / 11.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 2,
              color: const Color(0xFFE3C98F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: _busy ? null : onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE3C98F),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFFE0C184),
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(
                label,
                style: _baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF33200A),
                  letterSpacing: 0.3,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    );
  }
}

class _AuthPanelPatternPainter extends CustomPainter {
  const _AuthPanelPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stripePaint = Paint()
      ..color = const Color(0x1AB97A2E)
      ..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += 62) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), stripePaint);
    }

    final cx = size.width * 0.50;
    final cy = -size.height * 0.12;
    final rx = size.width * 1.30;
    final ry = size.height * 0.90;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(1.0, ry / rx);
    final glowRect = Rect.fromCircle(center: Offset.zero, radius: rx);
    final glowPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        stops: [0.0, 0.55],
        colors: [
          Color(0xB3FFFFFF),
          Color(0x00FFFFFF),
        ],
      ).createShader(glowRect);
    canvas.drawCircle(Offset.zero, rx, glowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
