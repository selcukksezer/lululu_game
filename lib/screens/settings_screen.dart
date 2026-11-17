import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/audio_manager.dart';
import '../services/auth_service.dart';
import '../services/energy_service.dart';
import '../services/haptic_service.dart';
import '../services/progress_manager.dart';
import '../widgets/item_detail_popup.dart';
import 'auth_screen.dart';

/// 1:1 Pixel-Perfect Settings modal & screen matching `#settingsOverlay` (`.settings-sheet`).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.isModal = false,
    this.showExtendedOptions = false,
  });

  final bool isModal;
  final bool showExtendedOptions;

  static Future<void> show(BuildContext context) {
    AudioManager().playPop();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB305070C),
      isScrollControlled: true,
      builder: (_) => const SettingsScreen(isModal: true),
    );
  }

  /// Shows a confirmation dialog and safely resets all progress in [ProgressManager.instance].
  static Future<bool> resetAll(BuildContext context) async {
    AudioManager().playPop();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xB805070C),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 378),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF121826),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0x73FFB800),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                offset: Offset(0, 18),
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'İLERLEMEYİ SIFIRLA',
                style: GoogleFonts.baloo2(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFB800),
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tüm altın, seviye, yüksek skor ve güçlendirici ilerlemeniz sıfırlanacak. Emin misiniz?',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD8E0EE),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        AudioManager().playPop();
                        Navigator.of(dialogContext).pop(false);
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0x24FFFFFF),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D000000),
                              offset: Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'İPTAL',
                          style: GoogleFonts.baloo2(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        AudioManager().playPop();
                        Navigator.of(dialogContext).pop(true);
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.55, 1.0],
                            colors: [
                              Color(0xFFF4538B),
                              Color(0xFFE01E5A),
                              Color(0xFFB80F42),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF7E0A2E),
                              offset: Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'SIFIRLA',
                          style: GoogleFonts.baloo2(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return false;

    final prefs = await SharedPreferences.getInstance();
    const progressKeys = <String>[
      'lululu_unlocked_level',
      'lululu_coins',
      'LululuCoinBalance',
      'lululu_spray',
      'lululu_raid',
      'lululu_slipper',
      'lululu_terlik',
      'lululu_aydinlat',
      'lululu_f16',
      'lululu_shop_chest_day',
      'lululu_limited_drop_day',
      'lululu_royal_cape',
      'lululu_owned_cosmetics',
      'lululu_unlocked_tiers',
      'lululu_mode_high_scores',
      'lululu_daily_tasks_day',
      'lululu_daily_tasks_progress',
      'lululu_daily_tasks_claimed',
      'lululu_daily_streak',
      'lululu_last_streak_claim_day',
      'lululu_extra_powers',
      'lululu_level_stars',
      'lululu_level_scores',
      'lululu_power_seed_v1',
      'lululu_daily_free_energy_day',
      'lululu_daily_free_energy_claims',
      'lululu_last_free_energy_epoch_ms',
      'lululu_state_integrity_sig',
    ];
    for (final key in progressKeys) {
      await prefs.remove(key);
    }
    await ProgressManager.instance.load();
    await EnergyService.instance.refillFull();
    return true;
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AudioManager _audio = AudioManager();
  final ProgressManager _pm = ProgressManager.instance;
  bool _musicOn = true;
  bool _sfxOn = true;
  bool _voiceOn = true;
  bool _vibOn = false;

  @override
  void initState() {
    super.initState();
    _musicOn = _pm.musicEnabled;
    _sfxOn = _pm.sfxEnabled && !_audio.isMuted;
    _voiceOn = _audio.voiceEnabled;
    _vibOn = false;
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final music = prefs.getBool('LululuSetMusic') ??
        prefs.getBool('lululu_music_enabled') ??
        true;
    final sfx = prefs.getBool('LululuSetSfx') ??
        prefs.getBool('lululu_sfx_enabled') ??
        !_audio.isMuted;
    final voice = prefs.getBool('LululuSetVoice') ??
        prefs.getBool('lululu_voice_enabled') ??
        true;
    final vib = prefs.getBool('LululuSetVib') ?? false;

    _audio.setMusicEnabled(music);
    _audio.setSfxEnabled(sfx);
    _audio.setVoiceEnabled(voice && sfx);
    _audio.setVibrationEnabled(vib);
    unawaited(HapticService.instance.setEnabled(vib));

    if (!mounted) return;
    setState(() {
      _musicOn = music;
      _sfxOn = sfx;
      _voiceOn = voice;
      _vibOn = vib;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _onMusicChanged(bool v) {
    AudioManager().playPop();
    setState(() => _musicOn = v);
    AudioManager().setMusicEnabled(v);
    unawaited(ProgressManager.instance.setMusicEnabled(v));
    unawaited(_savePref('LululuSetMusic', v));
  }

  void _onSfxChanged(bool v) {
    setState(() {
      _sfxOn = v;
      _audio.isMuted = !v;
    });
    AudioManager().setSfxEnabled(v);
    AudioManager().setVoiceEnabled(v && _voiceOn);
    unawaited(ProgressManager.instance.setSfxEnabled(v));
    if (v) {
      AudioManager().playPop();
    }
    unawaited(_savePref('LululuSetSfx', v));
  }

  void _onVoiceChanged(bool v) {
    AudioManager().playPop();
    setState(() => _voiceOn = v);
    AudioManager().setVoiceEnabled(v);
    unawaited(_savePref('LululuSetVoice', v));
    unawaited(_savePref('lululu_voice_enabled', v));
  }

  void _onVibrationChanged(bool v) {
    AudioManager().playPop();
    setState(() => _vibOn = v);
    AudioManager().setVibrationEnabled(v);
    unawaited(HapticService.instance.setEnabled(v));
    unawaited(ProgressManager.instance.setVibrationEnabled(v));
    unawaited(_savePref('LululuSetVib', v));
  }

  Future<bool> resetAll([BuildContext? dialogContext]) async {
    final reset = await SettingsScreen.resetAll(dialogContext ?? context);
    if (reset && mounted) {
      setState(() {});
    }
    return reset;
  }

  void _openAuth() {
    AudioManager().playPop();
    if (widget.isModal && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    AuthScreen.open(context);
  }

  void _openHowToPlay() {
    AudioManager().playPop();
    showHowToPlayOverlay(context);
  }

  void _close() {
    AudioManager().playPop();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    final sheet = Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 430),
      padding: EdgeInsets.fromLTRB(18, 20, 18, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF121826),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x99000000),
            offset: Offset(0, -10),
            blurRadius: 40,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: ValueListenableBuilder<AuthUser?>(
          valueListenable: AuthService.instance.currentUserNotifier,
          builder: (context, user, _) {
            final signedIn = user != null && user.isSignedIn;
            final accountSub = signedIn
                ? '${user.displayName} · Oturum açık'
                : 'Giriş yap / kayıt ol';

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'AYARLAR',
                  style: GoogleFonts.baloo2(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 12),
                _buildActionRow(
                  iconAsset: 'assets/design/ui/icons/friends.png',
                  title: 'HESAP',
                  subtitle: accountSub,
                  onTap: _openAuth,
                ),
                _buildSwitchRow(
                  iconAsset: 'assets/design/ui/icons/sound_on.png',
                  title: 'Müzik',
                  subtitle: 'Arkaplan müziği',
                  value: _musicOn,
                  onChanged: _onMusicChanged,
                ),
                _buildSwitchRow(
                  iconAsset: 'assets/design/ui/icons/sound_on.png',
                  title: 'Ses Efektleri',
                  subtitle: 'Birleştirme ve tıklama sesleri',
                  value: _sfxOn,
                  onChanged: _onSfxChanged,
                ),
                _buildSwitchRow(
                  leadingSpacerWidth: 33,
                  title: 'Titreşim',
                  subtitle: 'Birleştirmede hafif titreşim',
                  value: _vibOn,
                  onChanged: _onVibrationChanged,
                ),
                if (widget.showExtendedOptions) ...[
                  _buildSwitchRow(
                    iconAsset: 'assets/design/ui/icons/sound_on.png',
                    title: 'Böcek Seslendirmeleri',
                    subtitle: 'Karakter replikleri ve efektleri',
                    value: _voiceOn,
                    onChanged: _onVoiceChanged,
                  ),
                  _buildActionRow(
                    leadingSpacerWidth: 33,
                    title: 'NASIL OYNANIR',
                    subtitle: 'Oyun kuralları, birleştirme ve güçler',
                    onTap: _openHowToPlay,
                  ),
                  _buildActionRow(
                    leadingSpacerWidth: 33,
                    title: 'İlerlemeyi Sıfırla',
                    subtitle: 'Tüm kayıtlı oyun verilerini temizle',
                    onTap: () => resetAll(context),
                  ),
                ],
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _close,
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
                      'KAPAT',
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.36,
                        height: 1.0,
                        shadows: const [
                          Shadow(
                            color: Color(0x59784000),
                            offset: Offset(0, 1),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    if (widget.isModal) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: sheet,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xB305070C),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: sheet,
      ),
    );
  }

  Widget _buildLeadingIcon({String? iconAsset, double? spacerWidth}) {
    if (iconAsset != null) {
      return Image.asset(
        iconAsset,
        width: 33,
        height: 33,
        fit: BoxFit.contain,
      );
    }
    if (spacerWidth != null) {
      return SizedBox(width: spacerWidth, height: 33);
    }
    return const SizedBox(width: 33, height: 33);
  }

  /// `.set-row` clickable row with gold `›` chevron
  Widget _buildActionRow({
    String? iconAsset,
    double? leadingSpacerWidth,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0x1AFFFFFF), width: 1),
          ),
        ),
        child: Row(
          children: [
            _buildLeadingIcon(
              iconAsset: iconAsset,
              spacerWidth: leadingSpacerWidth,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8E9CAE),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '›',
              style: GoogleFonts.baloo2(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFFB800),
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `.set-row` with `.switch` (`54x32` pill)
  Widget _buildSwitchRow({
    String? iconAsset,
    double? leadingSpacerWidth,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0x1AFFFFFF), width: 1),
          ),
        ),
        child: Row(
          children: [
            _buildLeadingIcon(
              iconAsset: iconAsset,
              spacerWidth: leadingSpacerWidth,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8E9CAE),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 54,
              height: 32,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFF12B76A)
                    : const Color(0xFF39445C),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
