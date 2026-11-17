import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'progress_manager.dart';

/// Böcek Stüdyo video / sahne gönderisi (İzle, Üret, Yükle sekmeleri ile uyumlu).
class BugVideoPost {
  BugVideoPost({
    required this.id,
    required this.title,
    required this.authorName,
    required this.authorId,
    required this.filePath,
    required this.createdAtMs,
    required this.isPublic,
    this.durationText = '0:32',
    this.metaText = '128 B görüntülenme · 2 gün önce',
    this.thumbnailAsset = 'assets/design/ui/studio_watch/video_thumb_1.png',
    this.rawVideoPath = '',
    this.likes = 0,
    this.likedByMe = false,
    this.caption = 'LÜLÜLÜ!',
    this.stickerAsset = 'assets/design/ui/studio_create/edSticker.png',
    this.trimPercent = 62.0,
    this.isSampleViral = false,
  });

  final String id;
  String title;
  final String authorName;
  final String authorId;
  final String filePath;
  final int createdAtMs;
  bool isPublic;

  final String durationText;
  final String metaText;
  final String thumbnailAsset;
  final String rawVideoPath;
  int likes;
  bool likedByMe;
  final String caption;
  final String stickerAsset;
  final double trimPercent;
  final bool isSampleViral;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authorName': authorName,
        'authorId': authorId,
        'filePath': filePath,
        'createdAtMs': createdAtMs,
        'isPublic': isPublic,
        'durationText': durationText,
        'metaText': metaText,
        'thumbnailAsset': thumbnailAsset,
        'rawVideoPath': rawVideoPath,
        'likes': likes,
        'likedByMe': likedByMe,
        'caption': caption,
        'stickerAsset': stickerAsset,
        'trimPercent': trimPercent,
        'isSampleViral': isSampleViral,
      };

  factory BugVideoPost.fromJson(Map<String, dynamic> json) {
    return BugVideoPost(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Böcek videosu',
      authorName: json['authorName'] as String? ?? 'Misafir',
      authorId: json['authorId'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      isPublic: json['isPublic'] as bool? ?? false,
      durationText: json['durationText'] as String? ?? '0:32',
      metaText:
          json['metaText'] as String? ?? '128 B görüntülenme · 2 gün önce',
      thumbnailAsset: json['thumbnailAsset'] as String? ??
          'assets/design/ui/studio_watch/video_thumb_1.png',
      rawVideoPath: json['rawVideoPath'] as String? ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      caption: json['caption'] as String? ?? 'LÜLÜLÜ!',
      stickerAsset: json['stickerAsset'] as String? ??
          'assets/design/ui/studio_create/edSticker.png',
      trimPercent: (json['trimPercent'] as num?)?.toDouble() ?? 62.0,
      isSampleViral: json['isSampleViral'] as bool? ?? false,
    );
  }
}

/// Böcek Stüdyo GIF öğesi (GIF sekmesi için kare dizisi, metin ve hız bilgisi).
class BugGifItem {
  BugGifItem({
    required this.id,
    required this.title,
    required this.caption,
    required this.frameAssets,
    required this.speedIndex,
    required this.createdAtMs,
    required this.previewAsset,
    this.filePath = '',
  });

  final String id;
  final String title;
  final String caption;
  final List<String> frameAssets;
  final int speedIndex; // 0: Yavaş, 1: Normal, 2: Hızlı
  final int createdAtMs;
  final String previewAsset;
  final String filePath;

  Duration get frameDuration =>
      BugVideoService.frameDurationForSpeed(speedIndex);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'caption': caption,
        'frameAssets': frameAssets,
        'speedIndex': speedIndex,
        'createdAtMs': createdAtMs,
        'previewAsset': previewAsset,
        'filePath': filePath,
      };

  factory BugGifItem.fromJson(Map<String, dynamic> json) {
    final rawFrames = json['frameAssets'];
    final frames = rawFrames is List
        ? rawFrames.map((e) => e.toString()).toList()
        : const <String>[
            'assets/design/ui/studio_gif/gifImg.png',
            'assets/design/ui/studio_gif/img_3.png',
          ];
    return BugGifItem(
      id: json['id'] as String? ??
          'gif_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'dans_zamani.gif',
      caption: json['caption'] as String? ?? 'DANS ZAMANI!',
      frameAssets: frames.isEmpty
          ? const ['assets/design/ui/studio_gif/gifImg.png']
          : frames,
      speedIndex: ((json['speedIndex'] as num?)?.toInt() ?? 1).clamp(0, 2),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      previewAsset: json['previewAsset'] as String? ??
          'assets/design/ui/studio_gif/gifImg.png',
      filePath: json['filePath'] as String? ?? '',
    );
  }
}

/// Böcek Stüdyo İndirilenler arşivi öğesi (`SharedPreferences` kalıcılığı ile).
class BugDownloadEntry {
  BugDownloadEntry({
    required this.id,
    required this.title,
    required this.sizeText,
    required this.thumbAsset,
    required this.isBugIcon,
    required this.createdAtMs,
    this.filePath = '',
    this.sizeMb = 42.0,
  });

  final String id;
  final String title;
  final String sizeText;
  final String thumbAsset;
  final bool isBugIcon;
  final int createdAtMs;
  final String filePath;
  final double sizeMb;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sizeText': sizeText,
        'thumbAsset': thumbAsset,
        'isBugIcon': isBugIcon,
        'createdAtMs': createdAtMs,
        'filePath': filePath,
        'sizeMb': sizeMb,
      };

  factory BugDownloadEntry.fromJson(Map<String, dynamic> json) {
    return BugDownloadEntry(
      id: json['id'] as String? ??
          'dl_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'birlesme_rekoru.mp4',
      sizeText: json['sizeText'] as String? ?? '84,2 MB · Bugün 09:12',
      thumbAsset: json['thumbAsset'] as String? ??
          'assets/design/ui/studio_downloads/img_1.png',
      isBugIcon: json['isBugIcon'] as bool? ?? false,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      filePath: json['filePath'] as String? ?? '',
      sizeMb: (json['sizeMb'] as num?)?.toDouble() ?? 42.0,
    );
  }
}

/// Böcek Stüdyo 5 sekme (İzle, Üret, Yükle, GIF, İndirilenler) Video & GIF Motoru.
class BugVideoService extends ChangeNotifier {
  BugVideoService._();
  static final BugVideoService instance = BugVideoService._();
  factory BugVideoService() => instance;

  static const String _prefsKey = 'LululuBugVideosV1';
  static const String _gifsPrefsKey = 'LululuBugGifsV1';
  static const String _downloadsPrefsKey = 'LululuStudioDownloadsV1';
  static const String _likesPrefsKey = 'LululuStudioLikesV1';

  /// Yerel / örnek viral TikTok böcek videoları (`raw_tiktok_videos`).
  static const List<String> rawTiktokVideoPaths = <String>[
    'raw_tiktok_videos/7700956420036054293.mp4',
    'raw_tiktok_videos/7701016952956849429.mp4',
    'raw_tiktok_videos/7701289255338921237.mp4',
    'raw_tiktok_videos/7701817537155190023.mp4',
  ];

  /// Stüdyo "Üret" sekmesi çıkartma (sticker) asset'leri.
  static const List<String> studioCreateStickers = <String>[
    'assets/design/ui/studio_create/img_3.png',
    'assets/design/ui/studio_create/edSticker.png',
    'assets/design/ui/studio_create/img_5.png',
    'assets/design/ui/studio_create/img_6.png',
    'assets/design/ui/studio_create/img_7.png',
  ];

  /// Stüdyo "Üret" sekmesi sahne arka planı.
  static const String studioCreateBackground =
      'assets/design/ui/studio_create/ebg.png';

  /// Stüdyo "GIF" sekmesi kare asset'leri.
  static const List<String> studioGifFrames = <String>[
    'assets/design/ui/studio_gif/gifImg.png',
    'assets/design/ui/studio_gif/img_3.png',
    'assets/design/ui/studio_gif/img_4.png',
  ];

  final List<BugVideoPost> _posts = <BugVideoPost>[];
  final List<BugVideoPost> _viralWatchFeed = <BugVideoPost>[];
  final List<BugGifItem> _gifs = <BugGifItem>[];
  final List<BugDownloadEntry> _downloads = <BugDownloadEntry>[];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  List<BugVideoPost> get all => List<BugVideoPost>.unmodifiable(_posts);

  List<BugVideoPost> get publicFeed =>
      _posts.where((p) => p.isPublic).toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

  /// İzle sekmesindeki örnek/viral böcek videoları + herkese açık kullanıcı videoları.
  List<BugVideoPost> get watchVideos {
    if (_viralWatchFeed.isEmpty) {
      _seedViralWatchFeed();
    }
    return List<BugVideoPost>.unmodifiable(<BugVideoPost>[
      ..._viralWatchFeed,
      ..._posts.where((p) => p.isPublic && !p.isSampleViral),
    ]);
  }

  List<BugGifItem> get gifs {
    if (_gifs.isEmpty) {
      _seedDefaultGifs();
    }
    return List<BugGifItem>.unmodifiable(_gifs);
  }

  List<BugDownloadEntry> get downloads {
    if (_downloads.isEmpty) {
      _seedDefaultDownloads();
    }
    return List<BugDownloadEntry>.unmodifiable(_downloads);
  }

  /// Toplam depolama kullanımı (GB) — referans tasarımda 4 öğe için 1,21 GB.
  double get totalStorageUsedGb {
    final list = downloads;
    if (list.isEmpty) return 0.0;
    if (list.length == 4 &&
        list[0].title == 'birlesme_rekoru.mp4' &&
        list[1].title == 'kapi7_rehberi.mp4') {
      return 1.21;
    }
    final mb = list.fold<double>(0.0, (sum, item) => sum + item.sizeMb);
    return (mb / 1024.0).clamp(0.01, 4.0);
  }

  String get totalStorageUsedText {
    final gb = totalStorageUsedGb;
    final formatted = gb.toStringAsFixed(2).replaceAll('.', ',');
    return '$formatted GB';
  }

  List<BugVideoPost> mine() {
    final id = AuthService.instance.playerId;
    return _posts.where((p) => p.authorId == id).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  }

  static Duration frameDurationForSpeed(int speedIndex) {
    switch (speedIndex) {
      case 0:
        return const Duration(milliseconds: 650);
      case 2:
        return const Duration(milliseconds: 190);
      case 1:
      default:
        return const Duration(milliseconds: 380);
    }
  }

  static String formatCount(int n) {
    final clamped = n < 0 ? 0 : n;
    final s = clamped.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}';
  }

  /// Verilen `raw_tiktok_videos/...` veya yerel dosya yolunu güvenli biçimde çözer.
  File? resolvePlayableFile(String path) {
    final clean = path.trim();
    if (clean.isEmpty) return null;
    try {
      final baseName = clean.split('/').last;
      final candidates = <File>[
        File(clean),
        File('../$clean'),
        File('${Directory.current.path}/$clean'),
        File('${Directory.current.parent.path}/$clean'),
        File('${Directory.systemTemp.path}/lululu_bug_videos/$baseName'),
        File('/Users/selcuk/Documents/lululu/$clean'),
      ];
      for (final candidate in candidates) {
        if (candidate.existsSync()) return candidate;
      }
    } catch (_) {}
    return null;
  }

  void _seedViralWatchFeed() {
    if (_viralWatchFeed.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _viralWatchFeed.addAll(<BugVideoPost>[
      BugVideoPost(
        id: 'viral_watch_0',
        title: 'Böcek Birleştirme Rekoru! 51.200 Puan',
        authorName: 'Lülülü Stüdyo',
        authorId: 'studio_official',
        filePath: rawTiktokVideoPaths[0],
        rawVideoPath: rawTiktokVideoPaths[0],
        createdAtMs: now - 172800000,
        isPublic: true,
        durationText: '0:32',
        metaText: '128 B görüntülenme · 2 gün önce',
        thumbnailAsset: 'assets/design/ui/studio_watch/video_thumb_1.png',
        likes: 1248,
        isSampleViral: true,
      ),
      BugVideoPost(
        id: 'viral_watch_1',
        title: "Çığlık Böcek'te KAPI 7'ye Nasıl Geçilir?",
        authorName: 'Lülülü Stüdyo',
        authorId: 'studio_official',
        filePath: rawTiktokVideoPaths[1],
        rawVideoPath: rawTiktokVideoPaths[1],
        createdAtMs: now - 432000000,
        isPublic: true,
        durationText: '1:04',
        metaText: '86 B görüntülenme · 5 gün önce',
        thumbnailAsset: 'assets/design/ui/studio_watch/video_thumb_2.png',
        likes: 942,
        isSampleViral: true,
      ),
      BugVideoPost(
        id: 'viral_watch_2',
        title: 'Pembe Bornozlu İlk Kez Evrimleşti!',
        authorName: 'Lülülü Stüdyo',
        authorId: 'studio_official',
        filePath: rawTiktokVideoPaths[2],
        rawVideoPath: rawTiktokVideoPaths[2],
        createdAtMs: now - 604800000,
        isPublic: true,
        durationText: '0:47',
        metaText: '203 B görüntülenme · 1 hafta önce',
        thumbnailAsset: 'assets/design/ui/studio_watch/video_thumb_3.png',
        likes: 2317,
        isSampleViral: true,
      ),
      BugVideoPost(
        id: 'viral_watch_3',
        title: 'Terlik Yağmuru: Kombo x12 Nasıl Yapılır?',
        authorName: 'Lülülü Stüdyo',
        authorId: 'studio_official',
        filePath: rawTiktokVideoPaths[3],
        rawVideoPath: rawTiktokVideoPaths[3],
        createdAtMs: now - 1209600000,
        isPublic: true,
        durationText: '0:58',
        metaText: '57 B görüntülenme · 2 hafta önce',
        thumbnailAsset: 'assets/design/ui/studio_watch/video_thumb_4.png',
        likes: 618,
        isSampleViral: true,
      ),
    ]);
  }

  void _seedDefaultGifs() {
    if (_gifs.isNotEmpty) return;
    _gifs.add(
      BugGifItem(
        id: 'gif_default_dans',
        title: 'dans_zamani.gif',
        caption: 'DANS ZAMANI!',
        frameAssets: const <String>[
          'assets/design/ui/studio_gif/gifImg.png',
          'assets/design/ui/studio_gif/img_3.png',
        ],
        speedIndex: 1,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        previewAsset: 'assets/design/ui/studio_gif/gifImg.png',
      ),
    );
  }

  void _seedDefaultDownloads() {
    if (_downloads.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _downloads.addAll(<BugDownloadEntry>[
      BugDownloadEntry(
        id: 'dl_default_1',
        title: 'birlesme_rekoru.mp4',
        sizeText: '84,2 MB · Bugün 09:12',
        thumbAsset: 'assets/design/ui/studio_downloads/img_1.png',
        isBugIcon: false,
        createdAtMs: now - 3600000,
        filePath: rawTiktokVideoPaths[0],
        sizeMb: 84.2,
      ),
      BugDownloadEntry(
        id: 'dl_default_2',
        title: 'kapi7_rehberi.mp4',
        sizeText: '156,8 MB · Dün 21:40',
        thumbAsset: 'assets/design/ui/studio_downloads/img_2.png',
        isBugIcon: false,
        createdAtMs: now - 86400000,
        filePath: rawTiktokVideoPaths[1],
        sizeMb: 156.8,
      ),
      BugDownloadEntry(
        id: 'dl_default_3',
        title: 'dans_zamani.gif',
        sizeText: '6,4 MB · 28 Ekim',
        thumbAsset: 'assets/design/ui/studio_downloads/bugimg.png',
        isBugIcon: true,
        createdAtMs: now - 172800000,
        sizeMb: 6.4,
      ),
      BugDownloadEntry(
        id: 'dl_default_4',
        title: 'hamam_diva_klip.mp4',
        sizeText: '42,1 MB · 25 Ekim',
        thumbAsset: 'assets/design/ui/studio_downloads/img_4.png',
        isBugIcon: false,
        createdAtMs: now - 259200000,
        filePath: rawTiktokVideoPaths[2],
        sizeMb: 42.1,
      ),
    ]);
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<void> load() async {
    _seedViralWatchFeed();
    _seedDefaultGifs();
    _seedDefaultDownloads();

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Kullanıcı/Stüdyo videoları
      final raw = prefs.getString(_prefsKey);
      _posts.clear();
      if (raw != null && raw.isNotEmpty) {
        try {
          final list = jsonDecode(raw) as List<dynamic>;
          for (final e in list) {
            final post = BugVideoPost.fromJson(e as Map<String, dynamic>);
            if (post.isSampleViral ||
                post.filePath.startsWith('raw_tiktok_videos/') ||
                post.filePath.startsWith('assets/') ||
                _safeFileExists(post.filePath)) {
              _posts.add(post);
            }
          }
        } catch (_) {}
      }

      // 2. Beğeni durumları
      final likesRaw = prefs.getString(_likesPrefsKey);
      if (likesRaw != null && likesRaw.isNotEmpty) {
        try {
          final map = jsonDecode(likesRaw) as Map<String, dynamic>;
          for (final v in _viralWatchFeed) {
            final entry = map[v.id];
            if (entry is Map<String, dynamic>) {
              v.likes = (entry['likes'] as num?)?.toInt() ?? v.likes;
              v.likedByMe = entry['likedByMe'] as bool? ?? v.likedByMe;
            }
          }
        } catch (_) {}
      }

      // 3. GIF arşivi
      final gifsRaw = prefs.getString(_gifsPrefsKey);
      if (gifsRaw != null && gifsRaw.isNotEmpty) {
        try {
          final list = jsonDecode(gifsRaw) as List<dynamic>;
          if (list.isNotEmpty) {
            _gifs
              ..clear()
              ..addAll(
                list.map(
                  (e) => BugGifItem.fromJson(e as Map<String, dynamic>),
                ),
              );
          }
        } catch (_) {}
      }

      // 4. İndirilenler arşivi
      final downloadsRaw = prefs.getString(_downloadsPrefsKey);
      if (downloadsRaw != null && downloadsRaw.isNotEmpty) {
        try {
          final list = jsonDecode(downloadsRaw) as List<dynamic>;
          _downloads
            ..clear()
            ..addAll(
              list.map(
                (e) => BugDownloadEntry.fromJson(e as Map<String, dynamic>),
              ),
            );
        } catch (_) {}
      }
    } catch (_) {
      // SharedPreferences erişilemezse varsayılan bellek içi verilerle devam et.
    }

    _loaded = true;
    notifyListeners();
  }

  bool _safeFileExists(String path) {
    if (path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<Directory> _resolveStorageDir(String subFolder) async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/$subFolder');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      final fallback = Directory('${Directory.systemTemp.path}/lululu_$subFolder');
      if (!fallback.existsSync()) {
        fallback.createSync(recursive: true);
      }
      return fallback;
    }
  }

  /// İzle sekmesindeki bir videonun beğenisini değiştirir ve kalıcı kaydeder.
  Future<BugVideoPost?> toggleLike(String id) async {
    await ensureLoaded();
    BugVideoPost? target;
    for (final v in _viralWatchFeed) {
      if (v.id == id) {
        target = v;
        break;
      }
    }
    if (target == null) {
      for (final p in _posts) {
        if (p.id == id) {
          target = p;
          break;
        }
      }
    }
    if (target == null) return null;

    target.likedByMe = !target.likedByMe;
    target.likes += target.likedByMe ? 1 : -1;
    if (target.likes < 0) target.likes = 0;

    await _saveLikes();
    await _save();
    notifyListeners();
    return target;
  }

  /// Stüdyo "Üret" sekmesi: kırpma yüzdesi, başlık/yazı ve çıkartma ile sahne videosu üretir.
  Future<BugVideoPost> createSceneVideo({
    String title = '',
    String caption = 'LÜLÜLÜ!',
    double trimPercent = 62.0,
    int stickerIndex = 1,
    String? stickerAsset,
    String? backgroundAsset,
    bool isPublic = true,
    bool addToDownloads = true,
  }) async {
    await ensureLoaded();
    await AuthService.instance.ensureLoaded();

    final clampedTrim = trimPercent.clamp(20.0, 100.0);
    final endSec = (clampedTrim * 0.47).round().clamp(1, 47);
    final durText = '0:${endSec.toString().padLeft(2, '0')}';
    final resolvedSticker = stickerAsset ??
        studioCreateStickers[
            stickerIndex.clamp(0, studioCreateStickers.length - 1)];
    final cleanCaption = caption.trim().isEmpty ? 'LÜLÜLÜ!' : caption.trim();
    final cleanTitle =
        title.trim().isEmpty ? 'Sahne: $cleanCaption' : title.trim();

    final dir = await _resolveStorageDir('bug_videos');
    final id = 'scene_${DateTime.now().microsecondsSinceEpoch}';
    final dest = File('${dir.path}/$id.mp4');

    final rawSample = resolvePlayableFile(rawTiktokVideoPaths[0]);
    if (rawSample != null) {
      try {
        await rawSample.copy(dest.path);
      } catch (_) {
        await dest.writeAsBytes(
          utf8.encode('LULULU_SCENE:$id:$cleanCaption:$clampedTrim'),
        );
      }
    } else {
      try {
        await dest.writeAsBytes(
          utf8.encode('LULULU_SCENE:$id:$cleanCaption:$clampedTrim'),
        );
      } catch (_) {}
    }

    final post = BugVideoPost(
      id: id,
      title: cleanTitle,
      authorName: AuthService.instance.displayName,
      authorId: AuthService.instance.playerId,
      filePath: dest.path,
      rawVideoPath: rawTiktokVideoPaths[0],
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      isPublic: isPublic,
      durationText: durText,
      metaText: 'Yeni sahne · Az önce',
      thumbnailAsset: backgroundAsset ?? studioCreateBackground,
      likes: 1,
      caption: cleanCaption,
      stickerAsset: resolvedSticker,
      trimPercent: clampedTrim,
    );

    _posts.insert(0, post);
    await _save();

    if (addToDownloads) {
      await addDownload(
        BugDownloadEntry(
          id: 'dl_$id',
          title: '${id.substring(0, id.length.clamp(0, 12))}.mp4',
          sizeText: '24,8 MB · Az önce',
          thumbAsset: 'assets/design/ui/studio_downloads/img_4.png',
          isBugIcon: false,
          createdAtMs: post.createdAtMs,
          filePath: dest.path,
          sizeMb: 24.8,
        ),
      );
    }

    unawaited(_recordVideoTaskProgress());
    notifyListeners();
    return post;
  }

  /// Stüdyo "Yükle" sekmesi: galeriden veya simüle dosya seçimiyle video yükler.
  Future<BugVideoPost> uploadCustomVideo({
    required String title,
    String? sourcePath,
    bool isPublic = true,
    bool requireSignedIn = false,
  }) async {
    await ensureLoaded();
    await AuthService.instance.ensureLoaded();
    if (requireSignedIn && !AuthService.instance.isSignedIn) {
      throw StateError('Video yüklemek için giriş yap');
    }

    final dir = await _resolveStorageDir('bug_videos');
    final id = 'v_${DateTime.now().microsecondsSinceEpoch}';
    final ext = (sourcePath != null && sourcePath.contains('.'))
        ? sourcePath.split('.').last
        : 'mp4';
    final dest = File('${dir.path}/$id.$ext');

    var copied = false;
    if (sourcePath != null && sourcePath.trim().isNotEmpty) {
      final src = resolvePlayableFile(sourcePath);
      if (src != null) {
        try {
          await src.copy(dest.path);
          copied = true;
        } catch (_) {}
      }
    }

    if (!copied) {
      final fallbackRaw = resolvePlayableFile(rawTiktokVideoPaths[0]);
      if (fallbackRaw != null) {
        try {
          await fallbackRaw.copy(dest.path);
          copied = true;
        } catch (_) {}
      }
    }

    if (!copied) {
      try {
        await dest.writeAsBytes(utf8.encode('LULULU_VIDEO:$id:$title'));
      } catch (_) {}
    }

    final cleanTitle =
        title.trim().isEmpty ? 'Böcek Birleştirme Rekorum!' : title.trim();
    final post = BugVideoPost(
      id: id,
      title: cleanTitle,
      authorName: AuthService.instance.displayName,
      authorId: AuthService.instance.playerId,
      filePath: dest.path,
      rawVideoPath: rawTiktokVideoPaths[0],
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      isPublic: isPublic,
      durationText: '0:32',
      metaText: '1 görüntülenme · Az önce',
      thumbnailAsset: 'assets/design/ui/studio_watch/video_thumb_1.png',
      likes: 1,
    );

    _posts.insert(0, post);
    await _save();
    unawaited(_recordVideoTaskProgress());
    notifyListeners();
    return post;
  }

  /// Mevcut `BugVideoHubScreen` ile %100 geriye dönük uyumlu video ekleme metodu.
  Future<BugVideoPost> addFromPicker({
    required String sourcePath,
    required String title,
    required bool isPublic,
  }) async {
    return uploadCustomVideo(
      sourcePath: sourcePath,
      title: title,
      isPublic: isPublic,
      requireSignedIn: true,
    );
  }

  /// Stüdyo "GIF" sekmesi: seçili karelerden ve hızdan hareketli GIF kaydı üretir.
  Future<BugGifItem> createAnimatedGif({
    String caption = 'DANS ZAMANI!',
    Set<int> selectedFrames = const <int>{0, 1},
    int speedIndex = 1,
    bool addToDownloads = true,
  }) async {
    await ensureLoaded();
    final sortedIndices = selectedFrames.isEmpty
        ? <int>[0, 1]
        : (selectedFrames.toList()..sort());
    final resolvedFrames = <String>[
      for (final idx in sortedIndices)
        studioGifFrames[idx.clamp(0, studioGifFrames.length - 1)],
    ];

    final cleanCaption =
        caption.trim().isEmpty ? 'DANS ZAMANI!' : caption.trim();
    final id = 'gif_${DateTime.now().microsecondsSinceEpoch}';
    final dir = await _resolveStorageDir('bug_gifs');
    final file = File('${dir.path}/$id.gif');
    try {
      await file.writeAsString(
        jsonEncode({
          'id': id,
          'caption': cleanCaption,
          'frames': resolvedFrames,
          'speedIndex': speedIndex.clamp(0, 2),
        }),
      );
    } catch (_) {}

    final item = BugGifItem(
      id: id,
      title: '${cleanCaption.toLowerCase().replaceAll(' ', '_')}.gif',
      caption: cleanCaption,
      frameAssets: resolvedFrames,
      speedIndex: speedIndex.clamp(0, 2),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      previewAsset: resolvedFrames.first,
      filePath: file.path,
    );

    _gifs.insert(0, item);
    await _saveGifs();

    if (addToDownloads) {
      await addDownload(
        BugDownloadEntry(
          id: 'dl_$id',
          title: item.title,
          sizeText: '6,4 MB · Az önce',
          thumbAsset: 'assets/design/ui/studio_downloads/bugimg.png',
          isBugIcon: true,
          createdAtMs: item.createdAtMs,
          filePath: file.path,
          sizeMb: 6.4,
        ),
      );
    }

    unawaited(_recordVideoTaskProgress());
    notifyListeners();
    return item;
  }

  /// İzle ekranından bir videoyu İndirilenler arşivine ekler.
  Future<BugDownloadEntry> downloadPost(BugVideoPost post) async {
    await ensureLoaded();
    final entry = BugDownloadEntry(
      id: 'dl_${post.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: '${post.id}.mp4',
      sizeText: '48,5 MB · Az önce',
      thumbAsset: post.thumbnailAsset,
      isBugIcon: false,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      filePath: post.filePath,
      sizeMb: 48.5,
    );
    await addDownload(entry);
    return entry;
  }

  Future<void> addDownload(BugDownloadEntry entry) async {
    await ensureLoaded();
    _downloads.removeWhere((d) => d.id == entry.id);
    _downloads.insert(0, entry);
    await _saveDownloads();
    notifyListeners();
  }

  Future<BugDownloadEntry?> removeDownloadAt(int index) async {
    await ensureLoaded();
    if (index < 0 || index >= _downloads.length) return null;
    final removed = _downloads.removeAt(index);
    await _saveDownloads();
    notifyListeners();
    return removed;
  }

  Future<bool> removeDownload(String id) async {
    await ensureLoaded();
    final before = _downloads.length;
    _downloads.removeWhere((d) => d.id == id);
    if (_downloads.length == before) return false;
    await _saveDownloads();
    notifyListeners();
    return true;
  }

  Future<void> resetDefaultDownloads() async {
    _downloads.clear();
    _seedDefaultDownloads();
    await _saveDownloads();
    notifyListeners();
  }

  Future<void> setPublic(String id, bool value) async {
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0) return;
    _posts[i].isPublic = value;
    await _save();
    notifyListeners();
  }

  Future<void> _recordVideoTaskProgress() async {
    try {
      await ProgressManager.instance.recordTaskProgress('video');
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_posts.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _saveLikes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{
        for (final v in _viralWatchFeed)
          v.id: <String, dynamic>{
            'likes': v.likes,
            'likedByMe': v.likedByMe,
          },
      };
      await prefs.setString(_likesPrefsKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _saveGifs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _gifsPrefsKey,
        jsonEncode(_gifs.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _saveDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _downloadsPrefsKey,
        jsonEncode(_downloads.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }
}
