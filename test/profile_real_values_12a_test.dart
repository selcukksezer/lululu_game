import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_en.dart';
import 'package:lululu_game/l10n/app_tr.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/utils/number_format.dart';

// Dalga 12A — profil gerçek değerler + sürüm v1.0 + EN sayı biçimi.
//
// 0 ilerlemede profil 0 gösterir (eski şişirme: skor 7915+, oyun 48+,
// kombo en az 6, seviye en az 18, XP sabit 1240, yıldız yedeği 86).
// XP'nin kalıcı bir alanı yoktur; ProgressManager.xp gerçek ilerlemeden
// türetilir — TABAN YOK.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressManager.instance.load();
    ProgressManager.instance.modeHighScores.clear();
  });

  group('12A — sıfır ilerlemede gerçek değerler', () {
    test('skor 0, yıldız 0, seviye 1, XP 0', () {
      final pm = ProgressManager.instance;
      expect(pm.total11ModesScore, 0);
      expect(pm.totalStars, 0);
      expect(pm.unlockedLevel, 1);
      expect(pm.xp, 0);
      // Profil/top-bar/liderlikte gösterilen seviye formülü.
      final displayLevel = pm.unlockedLevel < 1 ? 1 : pm.unlockedLevel;
      expect(displayLevel, 1);
      // XP oranı da tabansız: 0 / 2000.
      final xpRatio =
          (pm.xp / ProgressManager.xpTargetPerLevel).clamp(0.0, 1.0);
      expect(xpRatio, 0.0);
    });

    test('günlük ilerleme de 0 başlar', () {
      final pm = ProgressManager.instance;
      expect(pm.dailyTaskProgress['play'] ?? 0, 0);
      expect(pm.dailyTaskProgress['combo'] ?? 0, 0);
    });
  });

  group('12A — XP gerçek ilerlemeden, tabansız', () {
    test('tek mod skoru 5000 → XP 100 (1240 tabanı yok)', () {
      final pm = ProgressManager.instance;
      pm.modeHighScores['terlik_tap'] = 5000;
      expect(pm.total11ModesScore, 5000);
      // (5000 ~/ 50) % 760 = 100; yıldız 0, play 0.
      expect(pm.xp, 100);
    });

    test('yıldız + play + skor toplanır, 2000 hedefini aşmaz', () {
      final pm = ProgressManager.instance;
      pm.modeHighScores['terlik_tap'] = 5000;
      pm.dailyTaskProgress['play'] = 2;
      // 100 (skor) + 2 * 40 (play) = 180.
      expect(pm.xp, 180);
      expect(pm.xp, lessThan(ProgressManager.xpTargetPerLevel));
    });

    test('seviye gerçek unlockedLevel olur', () {
      final pm = ProgressManager.instance;
      pm.unlockedLevel = 3;
      final displayLevel = pm.unlockedLevel < 1 ? 1 : pm.unlockedLevel;
      expect(displayLevel, 3);
      pm.unlockedLevel = 1;
      expect(pm.unlockedLevel < 1 ? 1 : pm.unlockedLevel, 1);
    });
  });

  group('12A — sürüm satırı v1.0', () {
    test('EN ve TR onboarding satırı v1.0 ile başlar, v3.0 içermez', () {
      expect(AppLocalizationsEn().onboardingVersionLine, startsWith('v1.0'));
      expect(AppLocalizationsTr().onboardingVersionLine, startsWith('v1.0'));
      expect(
        AppLocalizationsEn().onboardingVersionLine,
        isNot(contains('v3.0')),
      );
      expect(
        AppLocalizationsTr().onboardingVersionLine,
        isNot(contains('v3.0')),
      );
    });
  });

  group('12A — dile duyarlı sayı biçimi', () {
    test('binlik ayırıcı: TR nokta, EN virgül', () {
      expect(formatGroupedInt(1240, 'tr'), '1.240');
      expect(formatGroupedInt(1240, 'en'), '1,240');
      expect(formatGroupedInt(0, 'tr'), '0');
      expect(formatGroupedInt(0, 'en'), '0');
      expect(formatGroupedInt(1000000, 'tr'), '1.000.000');
      expect(formatGroupedInt(1000000, 'en'), '1,000,000');
      expect(formatGroupedInt(86, 'en'), '86');
    });

    test('ondalık ayırıcı: TR virgül, EN nokta', () {
      expect(formatDecimal(1.21, 2, 'tr'), '1,21');
      expect(formatDecimal(1.21, 2, 'en'), '1.21');
      expect(formatDecimal(290.5, 1, 'tr'), '290,5');
      expect(formatDecimal(290.5, 1, 'en'), '290.5');
    });
  });
}
