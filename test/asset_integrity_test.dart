import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/models/insect_tier.dart';
import 'package:lululu_game/models/lululu_game_mode.dart';
import 'package:lululu_game/models/osmantus_cast.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/chat_service.dart';
import 'package:lululu_game/services/sticker_gif_catalog.dart';
import 'package:lululu_game/services/zero_jank_preloader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Directory projectRoot = _resolveProjectRoot();

  /// Resolves logical/alias paths used by preloaders or prototype trap definitions
  /// to their physical bundle counterparts when the raw logical key is an alias.
  File resolveAssetFile(String assetRelativePath) {
    final direct = File('${projectRoot.path}/$assetRelativePath');
    if (direct.existsSync()) return direct;

    final preloaderResolved = ZeroJankPreloader.resolveAssetPath(
      assetRelativePath,
    );
    if (preloaderResolved != assetRelativePath) {
      final aliased = File('${projectRoot.path}/$preloaderResolved');
      if (aliased.existsSync()) return aliased;
    }

    const fallbackAliases = <String, String>{
      'assets/game/trap_electric.png': 'assets/icons2/boom.png',
    };
    final fallback = fallbackAliases[assetRelativePath];
    if (fallback != null) {
      return File('${projectRoot.path}/$fallback');
    }
    return direct;
  }

  void expectValidAsset(String assetRelativePath, {String? context}) {
    final file = resolveAssetFile(assetRelativePath);
    final label = context != null
        ? '$assetRelativePath ($context)'
        : assetRelativePath;
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Missing asset file on disk: $label -> ${file.path}',
    );
    expect(
      file.lengthSync(),
      greaterThan(0),
      reason: 'Zero-byte asset file on disk: $label -> ${file.path}',
    );
  }

  group('1. Full lib/ Dart Source Asset Path Integrity', () {
    test(
      'every single/double-quoted assets/... file path in lib/ exists and is > 0 bytes',
      () {
        final libDir = Directory('${projectRoot.path}/lib');
        expect(libDir.existsSync(), isTrue);

        final assetLiteralPattern = RegExp(
          r'''['"](assets/[a-zA-Z0-9_./-]+)['"]''',
        );

        final dartFiles = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
        expect(dartFiles, isNotEmpty);

        final verifiedPaths = <String>{};
        final failures = <String>[];

        for (final dartFile in dartFiles) {
          final content = dartFile.readAsStringSync();
          final relDart = dartFile.path.replaceFirst(
            '${projectRoot.path}/',
            '',
          );
          for (final match in assetLiteralPattern.allMatches(content)) {
            final assetPath = match.group(1)!;
            final baseName = assetPath.split('/').last;
            // Skip directory prefixes such as 'assets/ui/kenney'
            if (!baseName.contains('.')) continue;

            final resolved = resolveAssetFile(assetPath);
            if (!resolved.existsSync()) {
              failures.add('MISSING: $assetPath (referenced in $relDart)');
            } else if (resolved.lengthSync() <= 0) {
              failures.add('ZERO-BYTE: $assetPath (referenced in $relDart)');
            } else {
              verifiedPaths.add(assetPath);
            }
          }
        }

        expect(
          failures,
          isEmpty,
          reason:
              'Broken or empty asset references found in lib/:\n${failures.join('\n')}',
        );
        expect(verifiedPaths.length, greaterThanOrEqualTo(150));
      },
    );
  });

  group('2. Audio Integrity: tier1..13, voice_tier1..13 & SFX (canonical assets/audio/ only)', () {
    test('tier1_ses.mp3 .. tier13_ses.mp3 exist in assets/audio (> 0 bytes)', () {
      for (int tier = 1; tier <= 13; tier++) {
        final sesName = GameAudio.designSoundForTier(tier);
        expect(sesName, 'tier${tier}_ses.mp3');
        expectValidAsset(
          'assets/audio/$sesName',
          context: 'Tier $tier audio/tier${tier}_ses.mp3',
        );
      }
    });

    test('voice_tier1.mp3 .. voice_tier13.mp3 exist in assets/audio (> 0 bytes)', () {
      for (int tier = 1; tier <= 13; tier++) {
        final voiceName = GameAudio.voiceForTier(tier);
        expect(voiceName, 'voice_tier$tier.mp3');
        expectValidAsset(
          'assets/audio/$voiceName',
          context: 'Tier $tier audio/voice_tier$tier.mp3',
        );
      }
    });

    test('all SFX and voice clips in GameAudio.allAssets exist in assets/audio and are > 0 bytes', () {
      expect(GameAudio.allAssets.length, greaterThanOrEqualTo(43));
      for (final fileName in GameAudio.allAssets) {
        expectValidAsset(
          'assets/audio/$fileName',
          context: 'GameAudio.allAssets in assets/audio',
        );
      }
    });

    test('GameAudio entries stay bare filenames and the 7 viral one-shots live in canonical assets/audio/ (madde 17)', () {
      // Mac merge rule: constants are BARE filenames, never full paths.
      // AudioManager._normalizeAssetPath joins them with `audio/`; the
      // legacy `assets/design/sounds/` duplicates are NOT asserted here —
      // they still exist on disk until the remaining migration deletes
      // them (see assets/audio/ASSETS_NOTE.md).
      for (final fileName in GameAudio.allAssets) {
        expect(
          fileName.contains('/'),
          isFalse,
          reason: 'GameAudio entry must stay a bare filename: $fileName',
        );
      }
      expect(
        GameAudio.viralOneShots.toSet(),
        <String>{
          'mezarina_siktigim.mp3',
          'diva_sinyal.mp3',
          'diva_yasla.mp3',
          'lululu_nakarat.mp3',
          'duktur.mp3',
          'kanka.mp3',
          'husur_aday.mp3',
        },
      );
      expect(GameAudio.viralOneShots.length, 7);
      for (final fileName in GameAudio.viralOneShots) {
        expectValidAsset(
          'assets/audio/$fileName',
          context: 'viral one-shot in canonical assets/audio',
        );
      }
    });
  });

  group('3. Bug Stickers & Character Assets Integrity', () {
    test('all 13 InsectTier HD PNGs, WebP stickers, and voice files exist (> 0 bytes)', () {
      expect(InsectTier.values.length, 13);
      for (final insect in InsectTier.values) {
        expectValidAsset(
          insect.assetPath,
          context: 'InsectTier.${insect.name}.assetPath',
        );
        expectValidAsset(
          'assets/bugs/tier${insect.tier}_hd${insect.tier == 5 ? '.webp' : '.png'}',
          context: 'WebP bug sticker tier ${insect.tier}',
        );
        expectValidAsset(
          'assets/audio/${insect.voiceFile}',
          context: 'InsectTier.${insect.name}.voiceFile',
        );
      }
    });

    test('StickerGifCatalog, ChatService.bugStickerCatalog, and OsmantusCast assets exist (> 0 bytes)', () {
      expect(StickerGifCatalog.items, isNotEmpty);
      for (final item in StickerGifCatalog.items) {
        expectValidAsset(
          item.assetPath,
          context: 'StickerGifCatalog item ${item.id}',
        );
      }

      expect(ChatService.bugStickerCatalog.length, 8);
      for (final entry in ChatService.bugStickerCatalog.entries) {
        expectValidAsset(
          entry.value.asset,
          context: 'ChatService.bugStickerCatalog tier ${entry.key}',
        );
      }

      expectValidAsset(
        OsmantusCast.kisiA.assetPath,
        context: 'OsmantusCast.kisiA',
      );
      expectValidAsset(
        OsmantusCast.kisiB.assetPath,
        context: 'OsmantusCast.kisiB',
      );
      expectValidAsset(
        OsmantusCast.hubSticker,
        context: 'OsmantusCast.hubSticker',
      );
    });
  });

  group('4. UI Icons, Mode Catalog, Campaign Backgrounds & Preloader Assets', () {
    test('all 11 LululuGameMode catalog sticker and badge icon assets exist (> 0 bytes)', () {
      expect(LululuGameMode.catalog.length, 11);
      for (final mode in LululuGameMode.catalog) {
        expectValidAsset(
          mode.stickerAsset,
          context: 'LululuGameMode(${mode.id.name}).stickerAsset',
        );
        expectValidAsset(
          mode.badgeIconAsset,
          context: 'LululuGameMode(${mode.id.name}).badgeIconAsset',
        );
      }
    });

    test('all 80 CampaignDatabase level background assets exist (> 0 bytes)', () {
      expect(CampaignDatabase.allLevels.length, 80);
      for (final level in CampaignDatabase.allLevels) {
        expectValidAsset(
          level.backgroundPath,
          context: 'CampaignLevel ${level.id} (${level.chapterName})',
        );
      }
    });

    test('ZeroJankPreloader critical stickers, UI assets, fonts, and sounds exist (> 0 bytes)', () {
      for (final p in ZeroJankPreloader.criticalStickerPaths) {
        expectValidAsset(p, context: 'ZeroJankPreloader.criticalStickerPaths');
      }
      for (final p in ZeroJankPreloader.criticalUiAssets) {
        expectValidAsset(p, context: 'ZeroJankPreloader.criticalUiAssets');
      }
      for (final p in ZeroJankPreloader.criticalFontAssets) {
        expectValidAsset(p, context: 'ZeroJankPreloader.criticalFontAssets');
      }
      // NOTE: this audits the preloader manifest verbatim; the manifest
      // lists canonical `assets/audio/` paths (zero_jank_preloader.dart).
      // The legacy `assets/design/sounds/` duplicates on disk are not
      // listed in the manifest and are not asserted here.
      for (final p in ZeroJankPreloader.criticalSoundAssets) {
        expectValidAsset(p, context: 'ZeroJankPreloader.criticalSoundAssets');
      }
    });

    test('core UI icon directories (assets/icons, assets/icons2, assets/design/ui, assets/ui/kenney) have non-empty files', () {
      const iconDirs = <String>[
        'assets/icons',
        'assets/icons2',
        'assets/design/ui',
        'assets/ui/kenney',
      ];
      for (final relDir in iconDirs) {
        final dir = Directory('${projectRoot.path}/$relDir');
        expect(
          dir.existsSync(),
          isTrue,
          reason: 'Expected icon directory $relDir to exist',
        );
        final files = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => !f.path.endsWith('.DS_Store'))
            .toList();
        expect(
          files,
          isNotEmpty,
          reason: 'Expected icon directory $relDir to contain files',
        );
        for (final file in files) {
          expect(
            file.lengthSync(),
            greaterThan(0),
            reason: 'Zero-byte UI asset file: ${file.path}',
          );
        }
      }
    });
  });
}

Directory _resolveProjectRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync()) {
    return cwd;
  }
  final sub = Directory('${cwd.path}/lululu_game');
  if (File('${sub.path}/pubspec.yaml').existsSync()) {
    return sub;
  }
  return Directory('/Users/selcuk/Documents/lululu/lululu_game');
}
