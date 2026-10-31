import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../theme/lululu_theme.dart';
import '../widgets/auth_panel.dart';
import '../widgets/lululu_press.dart';

/// Ayarlar: ses, titreşim, bildirimler (yakında) ve hesap satırı.
/// "HESAP / GİRİŞ YAP" AuthPanel'i TAM EKRAN açar (modal değil).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sound = true;
  bool _vibration = true;

  void _openAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: LululuColors.paper,
          appBar: AppBar(
            backgroundColor: LululuColors.paper,
            foregroundColor: LululuColors.inkDark,
            elevation: 0,
            title: Text(
              'HESAP',
              style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
            ),
          ),
          body: const SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: AuthPanel(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    return Scaffold(
      backgroundColor: LululuColors.paper,
      appBar: AppBar(
        backgroundColor: LululuColors.paper,
        foregroundColor: LululuColors.inkDark,
        elevation: 0,
        title: Text(
          'AYARLAR',
          style: GoogleFonts.exo2(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: auth,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _SwitchRow(
              icon: Icons.volume_up_rounded,
              title: 'SES',
              subtitle: 'Oyun sesleri ve efektler',
              value: _sound,
              onChanged: (v) => setState(() => _sound = v),
            ),
            const SizedBox(height: 10),
            _SwitchRow(
              icon: Icons.vibration_rounded,
              title: 'TİTREŞİM',
              subtitle: 'Dokunma ve kombo geri bildirimi',
              value: _vibration,
              onChanged: (v) => setState(() => _vibration = v),
            ),
            const SizedBox(height: 10),
            _SoonRow(
              icon: Icons.notifications_rounded,
              title: 'BİLDİRİMLER',
              subtitle: 'Günlük ödül ve görev hatırlatmaları',
            ),
            const SizedBox(height: 10),
            LululuPress(
              onTap: _openAccount,
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LululuGradients.fuchsiaToGold,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      color: LululuColors.paper,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'HESAP / GİRİŞ YAP',
                            style: GoogleFonts.exo2(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: LululuColors.paper,
                            ),
                          ),
                          Text(
                            auth.isSignedIn
                                ? auth.displayName
                                : 'Hesabınla giriş yap, ilerlemeni sakla',
                            style: GoogleFonts.exo2(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: LululuColors.paper
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: LululuColors.paper,
                      size: 26,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: LululuColors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: LululuColors.mutedTitanium.withValues(alpha: 0.3),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      child: Row(
        children: [
          Icon(icon, color: LululuColors.cyberFuchsia, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.exo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.inkDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: LululuColors.cyberFuchsia,
          ),
        ],
      ),
    );
  }
}

class _SoonRow extends StatelessWidget {
  const _SoonRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      enabled: false,
      child: Row(
        children: [
          Icon(icon, color: LululuColors.mutedTitanium, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: LululuColors.inkDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: LululuColors.liquidGold
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'YAKINDA',
                        style: GoogleFonts.exo2(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: LululuColors.liquidGold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
