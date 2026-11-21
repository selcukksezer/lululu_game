import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/audio_manager.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/leaderboard_service.dart';
import '../widgets/auth_panel.dart';
import '../widgets/home/lululu_dock_bar.dart';

/// 1:1 Pixel-Perfect AuthScreen matching HTML prototype `#scr-account`
/// (`reference-account.png` & `reference-account-spec.json`).
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.embedded = false,
    this.onSuccess,
    this.onBack,
    this.onSelectNavIndex,
  });

  final bool embedded;
  final VoidCallback? onSuccess;
  final VoidCallback? onBack;
  final ValueChanged<int>? onSelectNavIndex;

  static Future<bool?> open(BuildContext context) {
    return openOn(Navigator.of(context));
  }

  /// [open] ile aynı akış; ancak navigator çağrı öncesi yakalanmış
  /// olabilir (ör. ayar sayfası pop sonrası aynı context'i kullanamaz).
  static Future<bool?> openOn(NavigatorState navigator) {
    return navigator.push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => AuthScreen(
          onSuccess: () => Navigator.of(ctx).maybePop(true),
          onBack: () => Navigator.of(ctx).maybePop(false),
        ),
      ),
    );
  }

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _userCtl = TextEditingController();
  final TextEditingController _passCtl = TextEditingController();
  final FocusNode _userFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  bool _isRegister = false;
  bool _obscurePassword = true;
  bool _busy = false;
  bool _signedOutExplicitly = false;
  String? _error;

  static TextStyle _baloo2({
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

  static TextStyle _nunito({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    ).copyWith(
      fontFamily: 'Nunito',
      fontWeight: fontWeight,
      fontFamilyFallback: const ['Baloo 2'],
    );
  }

  @override
  void initState() {
    super.initState();
    // Best-effort: bulut kuyruğu yüklenemezse ekran çevrimdışı çalışır;
    // hata yutulur, işlenmemiş async hata bırakılmaz (B29).
    unawaited(_ensureCloudLoaded());
  }

  Future<void> _ensureCloudLoaded() async {
    try {
      await CloudSyncService.instance.ensureLoaded();
    } catch (e) {
      debugPrint('[lululu] AuthScreen ensureLoaded failed: $e');
    }
  }

  @override
  void dispose() {
    _userCtl.dispose();
    _passCtl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() op, {
    String Function()? successMessage,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await op();
      await LeaderboardService.instance.onAuthChanged();
      await CloudSyncService.instance.enableOnlineWhenSignedIn();
      if (!mounted) return;
      setState(() {
        _signedOutExplicitly = false;
      });
      // S5: başarı bildirimi kapanma ÖNCESİ gösterilir; ScaffoldMessenger
      // rota üstünde yaşadığı için bildirim dönen ekranda da görünür.
      final message = successMessage?.call();
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      widget.onSuccess?.call();
    } on AuthSignInCancelledException {
      // 2E-UI (a): Apple/Google iptali sessizce yutulur — hata bandı
      // yok, form açık kalır. `_busy` finally'de sıfırlanır.
    } catch (e) {
      if (!mounted) return;
      final message = _authErrorMessage(e, context.l10n);
      setState(() => _error = message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Servis hatalarını çevrilmiş kullanıcı mesajlarına çevirir (B12).
  /// Ham `e.toString()` / servis Türkçe metni kullanıcıya gösterilmez.
  /// Eşleme, [AuthService] hata metinlerinin kararlı alt dizelerine dayanır.
  String _authErrorMessage(Object e, AppLocalizations l10n) {
    final message = e is StateError
        ? e.message
        : e is ArgumentError
            ? (e.message?.toString() ?? '')
            : e.toString();
    if (message.contains('zaten kayıtlı')) return l10n.authUsernameTaken;
    if (message.contains('Çok fazla başarısız')) {
      return l10n.authTooManyAttempts;
    }
    if (message.contains('Kullanıcı bulunamadı')) return l10n.authUserNotFound;
    if (message.contains('Şifre yanlış')) return l10n.authWrongPassword;
    if (message.contains('Kullanıcı adı')) return l10n.authUsernameInvalid;
    if (message.contains('Şifre')) {
      if (message.contains('en az')) return l10n.authPasswordTooShort;
      if (message.contains('en fazla')) return l10n.authPasswordTooLong;
      return l10n.authPasswordInvalid;
    }
    return l10n.authGenericFailed;
  }

  Future<void> _submitLocal() async {
    if (_busy) return;
    AudioManager().playPop();
    // Kullanıcı adı kırpılır (servis de kırpar); şifre kırpılmaz —
    // servis ham şifreyi hash'ler, kırpmak kimlik bilgisini değiştirir.
    final u = _userCtl.text.trim();
    final p = _passCtl.text;
    final validationError = _validateLocalInput(u, p);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    // 2E-UI (b): kayıt bilgisi, servisin söylediği kadardır — doğrulama
    // e-postası vb. iddia edilmez; yerel-öncelikli kayıt bayrağı
    // servisin `lastRegistrationWasLocalOnly` sözleşmesinden okunur.
    final wasRegister = _isRegister;
    final l10n = context.l10n;
    await _run(
      () async {
        if (_isRegister) {
          await AuthService.instance.register(username: u, password: p);
        } else {
          await AuthService.instance.login(username: u, password: p);
        }
        _passCtl.clear();
      },
      successMessage: () {
        if (!wasRegister) return l10n.authSignInSuccess;
        if (AuthService.instance.lastRegistrationWasLocalOnly) {
          return l10n.authRegisterLocalOnly;
        }
        return l10n.authRegisterSuccess;
      },
    );
  }

  /// İstemci doğrulaması (B12): servis kurallarının aynası.
  /// Kullanıcı adı, servisin normalizasyonundan geçirilip doğrulanır
  /// (küçük harf, boşluk→`_`, e-posta girdisinde yerel kısım); böylece
  /// servisin kabul edeceği girdi istemcide reddedilmez.
  /// Geçerliyse `null`, değilse çevrilmiş hata mesajı döner.
  String? _validateLocalInput(String username, String password) {
    final l10n = context.l10n;
    if (username.isEmpty) return l10n.authUsernameRequired;
    final normalized = _normalizeUsernameForValidation(username);
    if (normalized.length < 3 ||
        normalized.length > 20 ||
        !RegExp(r'^[a-z0-9_]+$').hasMatch(normalized)) {
      return l10n.authUsernameInvalid;
    }
    if (password.isEmpty) return l10n.authPasswordRequired;
    if (_controlChars.hasMatch(password)) return l10n.authPasswordInvalid;
    if (password.length < 6 || password.trim().length < 6) {
      return l10n.authPasswordTooShort;
    }
    if (password.length > 128) return l10n.authPasswordTooLong;
    return null;
  }

  /// [AuthService._normalizeUsername] aynası (yalnız doğrulama için).
  static String _normalizeUsernameForValidation(String raw) {
    final cleaned = raw.replaceAll(_controlChars, '').trim().toLowerCase();
    if (cleaned.contains('@')) {
      final localPart = cleaned.split('@').first;
      return localPart
          .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
    }
    return cleaned.replaceAll(RegExp(r'\s+'), '_');
  }

  static final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');

  /// Oturum kapatma (B29): kilit + try/catch + hata bildirimi.
  /// Tek çıkış noktasıdır (oturum kartındaki düğme).
  Future<void> _signOut() async {
    if (_busy) return;
    AudioManager().playPop();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signOut();
      await LeaderboardService.instance.onAuthChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.l10n.authSignOutFailed;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _signedOutExplicitly = true;
    });
  }

  void _closeOrPop() {
    AudioManager().playPop();
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: ValueListenableBuilder<AuthUser?>(
                valueListenable: AuthService.instance.currentUserNotifier,
                builder: (context, user, _) {
                  final showSession = !_signedOutExplicitly && user != null && user.isSignedIn;
                  final whoName = (user != null && user.isSignedIn)
                      ? '${user.displayName} · ${user.username}'
                      : 'Apple Oyuncu · apple';
                  final whoSub = context.l10n.authSessionOpen;

                  return Column(
                    children: [
                      _buildPageTitle(),
                      Expanded(
                        child: SingleChildScrollView(
                          clipBehavior: Clip.none,
                          padding: EdgeInsets.only(
                            bottom: widget.embedded ? 24 : 120,
                          ),
                          child: _buildAuthCard(
                            showSession: showSession,
                            whoName: whoName,
                            whoSub: whoSub,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (!widget.embedded)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              height: 84,
              child: _AccountFloatingDock(
                activeTab: LululuDockTab.home,
                onSelectTab: (tab) {
                  if (widget.onSelectNavIndex != null) {
                    widget.onSelectNavIndex!(tab.index);
                  } else {
                    _closeOrPop();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  /// `.page-title` -> height 60, padding: 10px 14px 2px 14px, gap: 10px
  Widget _buildPageTitle() {
    return Container(
      height: 60,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 29x29 olan yalnızca iç simgedir; dokunma alanı zaten
          // 48x48 kaptır. Görsel aynen korunur, etiket eklenir.
          Semantics(
            button: true,
            label: context.l10n.goBackLabel,
            excludeSemantics: true,
            child: Tooltip(
              message: context.l10n.goBackLabel,
              excludeFromSemantics: true,
              child: GestureDetector(
                onTap: _closeOrPop,
                child: Container(
                  width: 48,
                  height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A141B2A),
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/design/ui/back_btn.png',
                width: 29,
                height: 29,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: Color(0xFF141B2A),
                ),
              ),
            ),
          ),
          ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                context.l10n.accountTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _baloo2(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF141B2A),
                  letterSpacing: -0.1,
                  height: 25.76 / 23.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// `.auth-card.auth-page-card` -> margin: 36px 12px 12px, padding: 20px 18px 18px
  Widget _buildAuthCard({
    required bool showSession,
    required String whoName,
    required String whoSub,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 36, 12, 12),
      child: CustomPaint(
        painter: const _AccountBlurredRRectShadowPainter(
          color: Color(0x732B1600),
          offset: Offset(0, 24),
          sigma: 22.0,
          radius: 26.0,
        ),
        child: Container(
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
                color: Color(0xFF8A5220),
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: const CustomPaint(
                    painter: _AuthCardPatternPainter(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCardHeader(),
                    const SizedBox(height: 7),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 41.0),
                      child: Text(
                        context.l10n.authCardSubtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _nunito(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7A5A28),
                          letterSpacing: 0.0,
                          height: 19.5 / 13.5,
                        ),
                      ),
                    ),
                    if (showSession) ...[
                      const SizedBox(height: 14),
                      _buildSessionCard(whoName: whoName, whoSub: whoSub),
                    ],
                    const SizedBox(height: 14),
                    _buildTabs(),
                    const SizedBox(height: 13),
                    _buildInputField(
                      controller: _userCtl,
                      hintText: context.l10n.usernameHint,
                      obscureText: false,
                      focusNode: _userFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _passFocus.requestFocus(),
                    ),
                    const SizedBox(height: 10),
                    _buildInputField(
                      controller: _passCtl,
                      hintText: context.l10n.passwordHint,
                      obscureText: _obscurePassword,
                      focusNode: _passFocus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitLocal(),
                      suffix: Semantics(
                        button: true,
                        label: _obscurePassword
                            ? context.l10n.showPasswordLabel
                            : context.l10n.hidePasswordLabel,
                        child: GestureDetector(
                        onTap: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const CustomPaint(
                            size: Size(23, 23),
                            painter: _AuthEyeIconPainter(),
                          ),
                        ),
                      ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFECEC),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: const Color(0xFFE52E2E),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: _nunito(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB41E1E),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildSubmitButton(),
                    const SizedBox(height: 13),
                    _buildOrDivider(),
                    const SizedBox(height: 11),
                    GuestSignInButton(
                      onTap: _busy
                          ? null
                          : () {
                              AudioManager().playPop();
                              _run(
                                () => AuthService.instance.signInAsGuest(),
                                successMessage: () =>
                                    context.l10n.authSignInSuccess,
                              );
                            },
                    ),
                    const SizedBox(height: 9),
                    _buildSocialButton(
                      label: context.l10n.continueWithApple,
                      icon: const CustomPaint(
                        size: Size(21, 21),
                        painter: _AppleLogoPainter(),
                      ),
                      onTap: _busy
                          ? null
                          : () {
                              AudioManager().playPop();
                              _run(
                                () => AuthService.instance.signInWithApple(),
                                successMessage: () =>
                                    context.l10n.authSignInSuccess,
                              );
                            },
                    ),
                    const SizedBox(height: 9),
                    _buildSocialButton(
                      label: context.l10n.continueWithGoogle,
                      icon: const CustomPaint(
                        size: Size(21, 21),
                        painter: _GoogleLogoPainter(),
                      ),
                      onTap: _busy
                          ? null
                          : () {
                              AudioManager().playPop();
                              _run(
                                () => AuthService.instance.signInWithGoogle(),
                                successMessage: () =>
                                    context.l10n.authSignInSuccess,
                              );
                            },
                    ),
                  ],
                ),
              ),
              // `.auth-mascot`: top: -30px, left: 20px, width: 58, height: 58, rotate(-9deg)
              Positioned(
                top: -30,
                left: 20,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: -9 * math.pi / 180,
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: Image.asset(
                        'assets/design/bugs_hd/tier1_hd.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `.auth-head`
  Widget _buildCardHeader() {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              _isRegister
                  ? context.l10n.authHeaderRegister
                  : context.l10n.authHeaderLogin,
              style: _baloo2(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFE01E5A),
                letterSpacing: 0.4,
                height: 28.35 / 27.0,
                shadows: const [
                  Shadow(
                    color: Color(0x8CFFB800),
                    offset: Offset(0, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
            ),
          ),
          Semantics(
            button: true,
            label: context.l10n.closeLabel,
            excludeSemantics: true,
            child: Tooltip(
              message: context.l10n.closeLabel,
              excludeFromSemantics: true,
              child: GestureDetector(
                onTap: _closeOrPop,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                color: Colors.white,
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
              child: const CustomPaint(
                size: Size(19, 19),
                painter: _CloseXIconPainter(),
              ),
            ),
          ),
          ),
          ),
        ],
      ),
    );
  }

  /// `.auth-session` -> height: 70, padding: 9px 8px 9px 11px, border: 2px solid #12B76A
  Widget _buildSessionCard({
    required String whoName,
    required String whoSub,
  }) {
    return Container(
      height: 70,
      padding: const EdgeInsets.fromLTRB(11, 7, 6, 7),
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
        crossAxisAlignment: CrossAxisAlignment.center,
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
            child: const CustomPaint(
              size: Size(19, 19),
              painter: _SessionCheckPainter(),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 16.7,
                    child: Text(
                      whoName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _baloo2(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF4A2E00),
                        letterSpacing: -0.1,
                        height: 16.675 / 14.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 16.0,
                    child: Text(
                      whoSub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0A9553),
                        letterSpacing: -0.1,
                        height: 16.0 / 12.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Semantics(
            button: true,
            label: context.l10n.signOutButton,
            child: GestureDetector(
              onTap: _busy ? null : _signOut,
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
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
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
          ),
        ],
      ),
    );
  }

  /// `.auth-tabs` -> height: 58, padding: 5px, gap: 5px, bg: #F3DFAE
  Widget _buildTabs() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
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
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x1F8A5220),
                ),
              ),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (active)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x73FFFFFF),
                      ),
                    ),
                  ),
                Text(
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `.auth-field input` -> height: 56, padding: 14px 56px 14px 16px, border: 2px solid #E3C98F
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    Widget? suffix,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 54, 0),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              obscureText: obscureText,
              style: _nunito(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF33200A),
                letterSpacing: -0.65,
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
                  letterSpacing: -0.65,
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

  /// `#authSubmit.btn.auth-primary` -> height: 56, borderRadius: 17, gold gradient
  Widget _buildSubmitButton() {
    return Semantics(
      button: true,
      label: _isRegister ? context.l10n.createAccountButton : context.l10n.signInButton,
      child: GestureDetector(
        onTap: _busy ? null : _submitLocal,
        child: CustomPaint(
          painter: const _AccountBlurredRRectShadowPainter(
            color: Color(0x47000000),
            offset: Offset(0, 10),
            sigma: 9.0,
            radius: 17.0,
          ),
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
                  color: Color(0xFFB97A00),
                  offset: Offset(0, 5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `.auth-or` -> VEYA with dashed lines
  Widget _buildOrDivider() {
    return SizedBox(
      height: 17.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            const Expanded(
              child: CustomPaint(
                size: Size(double.infinity, 2),
                painter: _DashedLinePainter(),
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
                height: 1.0,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: CustomPaint(
                size: Size(double.infinity, 2),
                painter: _DashedLinePainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `.auth-social` -> height: 52, white bg, border: 2px solid #E3C98F
  Widget _buildSocialButton({
    required String label,
    required Widget icon,
    required VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 9),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  label,
                  style: _baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF33200A),
                    letterSpacing: 0.0,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountBlurredRRectShadowPainter extends CustomPainter {
  final Color color;
  final Offset offset;
  final double sigma;
  final double radius;

  const _AccountBlurredRRectShadowPainter({
    required this.color,
    required this.offset,
    required this.sigma,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).shift(offset);
    final paint = Paint()
      ..color = color
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AccountBlurredRRectShadowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.offset != offset ||
      oldDelegate.sigma != sigma ||
      oldDelegate.radius != radius;
}

class _AuthCardPatternPainter extends CustomPainter {
  const _AuthCardPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stripePaint = Paint()
      ..color = const Color(0x1AB97A2E)
      ..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += 62) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), stripePaint);
    }

    // CSS: radial-gradient(130% 90% at 50% -12%, rgba(255,255,255,.7), rgba(255,255,255,0) 55%)
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

class _CloseXIconPainter extends CustomPainter {
  const _CloseXIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = const Color(0xFF8A5220)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(6, 6), const Offset(18, 18), paint);
    canvas.drawLine(const Offset(18, 6), const Offset(6, 18), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SessionCheckPainter extends CustomPainter {
  const _SessionCheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(4, 12.5)
      ..lineTo(9.5, 18)
      ..lineTo(20, 7);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AuthEyeIconPainter extends CustomPainter {
  const _AuthEyeIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = const Color(0xFF8A6A30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(2, 12)
      ..cubicTo(5.5, 6.0, 18.5, 6.0, 22, 12)
      ..cubicTo(18.5, 18.0, 5.5, 18.0, 2, 12)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(const Offset(12, 12), 3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE3C98F)
      ..style = PaintingStyle.fill;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      final endX = (startX + dashWidth).clamp(0.0, size.width);
      canvas.drawRect(Rect.fromLTRB(startX, 0, endX, 2), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AppleLogoPainter extends CustomPainter {
  const _AppleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = const Color(0xFF33200A)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(16.365, 1.43)
      ..cubicTo(16.365, 2.57, 15.945, 3.67, 15.175, 4.49)
      ..cubicTo(14.335, 5.39, 13.025, 6.09, 11.835, 5.99)
      ..cubicTo(11.755, 4.88, 12.265, 3.73, 13.025, 2.95)
      ..cubicTo(13.855, 2.09, 15.225, 1.46, 16.365, 1.43)
      ..close()
      ..moveTo(20.67, 17.07)
      ..cubicTo(20.09, 18.41, 19.81, 19.01, 19.07, 20.19)
      ..cubicTo(18.03, 21.84, 16.57, 23.89, 14.76, 23.91)
      ..cubicTo(13.15, 23.93, 12.73, 22.86, 10.54, 22.88)
      ..cubicTo(8.35, 22.89, 7.89, 23.93, 6.28, 23.91)
      ..cubicTo(4.47, 23.89, 3.09, 22.04, 2.05, 20.39)
      ..cubicTo(-0.85, 15.79, -0.32, 10.39, 1.54, 7.51)
      ..cubicTo(2.86, 5.47, 4.94, 4.28, 6.89, 4.28)
      ..cubicTo(8.88, 4.28, 10.13, 5.38, 11.78, 5.38)
      ..cubicTo(13.38, 5.38, 14.35, 4.28, 16.65, 4.28)
      ..cubicTo(18.39, 4.28, 20.23, 5.23, 21.55, 6.87)
      ..cubicTo(17.24, 9.23, 17.92, 15.39, 20.67, 17.07)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);

    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final pBlue = Path()
      ..moveTo(21.6, 12.23)
      ..cubicTo(21.6, 11.51, 21.54, 10.82, 21.42, 10.15)
      ..lineTo(12.0, 10.15)
      ..lineTo(12.0, 14.09)
      ..lineTo(17.38, 14.09)
      ..cubicTo(17.15, 15.33, 16.45, 16.39, 15.39, 17.1)
      ..lineTo(15.39, 19.6)
      ..lineTo(18.62, 19.6)
      ..cubicTo(20.51, 17.86, 21.6, 15.29, 21.6, 12.23)
      ..close();
    canvas.drawPath(pBlue, blue);

    final green = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final pGreen = Path()
      ..moveTo(12.0, 22.0)
      ..cubicTo(14.7, 22.0, 16.96, 21.1, 18.62, 19.57)
      ..lineTo(15.39, 17.07)
      ..cubicTo(14.49, 17.67, 13.34, 18.03, 12.0, 18.03)
      ..cubicTo(9.39, 18.03, 7.18, 16.27, 6.39, 13.9)
      ..lineTo(3.06, 13.9)
      ..lineTo(3.06, 16.48)
      ..cubicTo(4.71, 19.75, 8.09, 22.0, 12.0, 22.0)
      ..close();
    canvas.drawPath(pGreen, green);

    final yellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final pYellow = Path()
      ..moveTo(6.39, 13.9)
      ..cubicTo(6.19, 13.3, 6.07, 12.66, 6.07, 12.0)
      ..cubicTo(6.07, 11.34, 6.19, 10.7, 6.39, 10.1)
      ..lineTo(6.39, 7.52)
      ..lineTo(3.06, 7.52)
      ..cubicTo(2.38, 8.87, 2.0, 10.39, 2.0, 12.0)
      ..cubicTo(2.0, 13.61, 2.38, 15.13, 3.06, 16.48)
      ..lineTo(6.39, 13.9)
      ..close();
    canvas.drawPath(pYellow, yellow);

    final red = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final pRed = Path()
      ..moveTo(12.0, 5.97)
      ..cubicTo(13.47, 5.97, 14.79, 6.48, 15.82, 7.47)
      ..lineTo(18.69, 4.6)
      ..cubicTo(16.96, 2.99, 14.7, 2.0, 12.0, 2.0)
      ..cubicTo(8.09, 2.0, 4.71, 4.25, 3.06, 7.52)
      ..lineTo(6.39, 10.1)
      ..cubicTo(7.18, 7.73, 9.39, 5.97, 12.0, 5.97)
      ..close();
    canvas.drawPath(pRed, red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AccountFloatingDock extends StatelessWidget {
  final LululuDockTab activeTab;
  final ValueChanged<LululuDockTab> onSelectTab;

  const _AccountFloatingDock({
    required this.activeTab,
    required this.onSelectTab,
  });

  static const _tabs = LululuDockTab.values;

  static String _label(BuildContext context, LululuDockTab tab) {
    final l10n = context.l10n;
    return switch (tab) {
      LululuDockTab.home => l10n.navHome,
      LululuDockTab.modes => l10n.navModes,
      LululuDockTab.family => l10n.navFamily,
      LululuDockTab.shop => l10n.navShop,
      LululuDockTab.scores => l10n.navScores,
    };
  }

  static String _icon(LululuDockTab tab) => switch (tab) {
        LululuDockTab.home => 'assets/icons2/home.png',
        LululuDockTab.modes => 'assets/icons2/target.png',
        LululuDockTab.family => 'assets/icons2/paw.png',
        LululuDockTab.shop => 'assets/icons2/cart.png',
        LululuDockTab.scores => 'assets/icons2/trophy.png',
      };

  static Widget _buildIconWithDropShadow(String asset, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(0, 2),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0x47000000),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    asset,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _AccountBlurredRRectShadowPainter(
        color: Color(0x7A080B12),
        offset: Offset(0, 22),
        sigma: 19.0,
        radius: 42.0,
      ),
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 3),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.72],
            colors: [
              Color(0xFF1E2538),
              Color(0xFF080B12),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x47080B12),
              offset: Offset(0, 7),
              blurRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth =
                  (constraints.maxWidth - 14.0).clamp(100.0, 410.0);
              final tabWidth = usableWidth / _tabs.length;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: _AccountDockSurfacePainter(),
                    ),
                  ),
                  Positioned(
                    left: 26,
                    right: 26,
                    top: 5,
                    height: 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.20),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 7.0 + activeTab.index * tabWidth,
                    top: 7.0,
                    width: tabWidth,
                    height: 64.0,
                    child: CustomPaint(
                      painter: const _AccountBlurredRRectShadowPainter(
                        color: Color(0x47E01E5A),
                        offset: Offset(0, 10),
                        sigma: 9.0,
                        radius: 32.0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xF0FFFFFF),
                            width: 2,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.40, 0.74, 1.0],
                            colors: [
                              Color(0xFFFFE27A),
                              Color(0xFFFFB800),
                              Color(0xFFFF6B35),
                              Color(0xFFE01E5A),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D000000),
                              offset: Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: CustomPaint(
                                  painter: _AccountDockActiveIndInsetPainter(),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                right: 8,
                                top: 2,
                                height: 9,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0x61FFFFFF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(7),
                    child: Row(
                      children: [
                        for (final tab in _tabs)
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: _label(context, tab),
                              selected: tab == activeTab,
                              child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelectTab(tab),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: tab == activeTab
                                      ? const Color(0x1FFFB800)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: SizedBox(
                                  height: 64,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.topCenter,
                                    children: [
                                      if (tab == activeTab)
                                        Positioned(
                                          top: 1.8,
                                          width: 42.4,
                                          height: 42.4,
                                          child: CustomPaint(
                                            painter:
                                                const _AccountBlurredRRectShadowPainter(
                                              color: Color(0x3D000000),
                                              offset: Offset(0, 7),
                                              sigma: 6.0,
                                              radius: 21.2,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color(0x597A082E),
                                                    offset: Offset(0, 4),
                                                    blurRadius: 0,
                                                  ),
                                                ],
                                              ),
                                              child: ClipOval(
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    const Positioned.fill(
                                                      child: CustomPaint(
                                                        painter:
                                                            _AccountDockCircleInsetPainter(
                                                          dy: -4.24,
                                                          color:
                                                              Color(0x1F080B12),
                                                        ),
                                                      ),
                                                    ),
                                                    _buildIconWithDropShadow(
                                                      _icon(tab),
                                                      35,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Positioned(
                                          top: 7.0,
                                          width: 40.0,
                                          height: 40.0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(0x17FFFFFF),
                                              border: Border.all(
                                                color: const Color(0x2EFFFFFF),
                                                width: 2,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x4D000000),
                                                  offset: Offset(0, 3),
                                                  blurRadius: 0,
                                                ),
                                              ],
                                            ),
                                            child: ClipOval(
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  const Positioned.fill(
                                                    child: CustomPaint(
                                                      painter:
                                                          _AccountDockCircleInsetPainter(
                                                        dy: 2.0,
                                                        color:
                                                            Color(0x29FFFFFF),
                                                      ),
                                                    ),
                                                  ),
                                                  _buildIconWithDropShadow(
                                                    _icon(tab),
                                                    33,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        left: -4,
                                        right: -4,
                                        top: 49.0,
                                        child: Text(
                                          _label(context, tab),
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          style: _AuthScreenState._baloo2(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            height: 1.0,
                                            letterSpacing: -0.1,
                                            color: tab == activeTab
                                                ? Colors.white
                                                : const Color(0xA8FFFFFF),
                                            shadows: tab == activeTab
                                                ? const [
                                                    Shadow(
                                                      color:
                                                          Color(0x737A082E),
                                                      offset: Offset(0, 2),
                                                      blurRadius: 0,
                                                    ),
                                                  ]
                                                : const [
                                                    Shadow(
                                                      color:
                                                          Color(0xBF000000),
                                                      offset: Offset(0, 1),
                                                      blurRadius: 0,
                                                    ),
                                                  ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AccountDockSurfacePainter extends CustomPainter {
  const _AccountDockSurfacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.translate(size.width * 0.18, -size.height * 0.30);
    canvas.scale(size.width * 1.20, size.height * 1.60);
    final radialPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1.0,
        const [Color(0x38FFFFFF), Color(0x00FFFFFF)],
        const [0.0, 0.48],
      );
    canvas.drawRect(const Rect.fromLTRB(-2, -2, 2, 2), radialPaint);
    canvas.restore();

    final radius = Radius.circular(size.height / 2);
    final outerPath = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));

    final topInsetPath = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, 3)),
    );
    canvas.drawPath(topInsetPath, Paint()..color = const Color(0x29FFFFFF));

    final bottomInsetPath = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, -7)),
    );
    canvas.drawPath(bottomInsetPath, Paint()..color = const Color(0x57000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AccountDockActiveIndInsetPainter extends CustomPainter {
  const _AccountDockActiveIndInsetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final outerPath = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));

    final topInset = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, 3)),
    );
    canvas.drawPath(topInset, Paint()..color = const Color(0x8CFFFFFF));

    final bottomInset = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, -6)),
    );
    canvas.drawPath(bottomInset, Paint()..color = const Color(0x3D7A082E));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AccountDockCircleInsetPainter extends CustomPainter {
  final double dy;
  final Color color;

  const _AccountDockCircleInsetPainter({required this.dy, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addOval(Offset.zero & size);
    final crescent = Path.combine(
      PathOperation.difference,
      outer,
      outer.shift(Offset(0, dy)),
    );
    canvas.drawPath(crescent, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _AccountDockCircleInsetPainter oldDelegate) =>
      oldDelegate.dy != dy || oldDelegate.color != color;
}

