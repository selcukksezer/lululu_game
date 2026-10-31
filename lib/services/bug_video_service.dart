import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class BugVideoPost {
  BugVideoPost({
    required this.id,
    required this.title,
    required this.authorName,
    required this.authorId,
    required this.filePath,
    required this.createdAtMs,
    required this.isPublic,
  });

  final String id;
  String title;
  final String authorName;
  final String authorId;
  final String filePath;
  final int createdAtMs;
  bool isPublic;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authorName': authorName,
        'authorId': authorId,
        'filePath': filePath,
        'createdAtMs': createdAtMs,
        'isPublic': isPublic,
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
    );
  }
}

/// Yerel böcek video feed — herkese açık paylaş bayrağı; bulut sync sonra.
class BugVideoService extends ChangeNotifier {
  BugVideoService._();
  static final instance = BugVideoService._();

  static const _prefsKey = 'LululuBugVideosV1';

  final List<BugVideoPost> _posts = [];
  bool _loaded = false;

  List<BugVideoPost> get all => List.unmodifiable(_posts);

  List<BugVideoPost> get publicFeed =>
      _posts.where((p) => p.isPublic).toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

  List<BugVideoPost> mine() {
    final id = AuthService.instance.playerId;
    return _posts.where((p) => p.authorId == id).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _posts.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          final post = BugVideoPost.fromJson(e as Map<String, dynamic>);
          if (File(post.filePath).existsSync()) {
            _posts.add(post);
          }
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<BugVideoPost> addFromPicker({
    required String sourcePath,
    required String title,
    required bool isPublic,
  }) async {
    await AuthService.instance.ensureLoaded();
    if (!AuthService.instance.isSignedIn) {
      throw StateError('Video yüklemek için giriş yap');
    }
    final dir = await getApplicationDocumentsDirectory();
    final videos = Directory('${dir.path}/bug_videos');
    if (!await videos.exists()) await videos.create(recursive: true);

    final id = 'v_${DateTime.now().microsecondsSinceEpoch}';
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'mp4';
    final dest = File('${videos.path}/$id.$ext');
    await File(sourcePath).copy(dest.path);

    final post = BugVideoPost(
      id: id,
      title: title.trim().isEmpty ? 'Böcek videosu' : title.trim(),
      authorName: AuthService.instance.displayName,
      authorId: AuthService.instance.playerId,
      filePath: dest.path,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      isPublic: isPublic,
    );
    _posts.insert(0, post);
    await _save();
    notifyListeners();
    return post;
  }

  Future<void> setPublic(String id, bool value) async {
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0) return;
    _posts[i].isPublic = value;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_posts.map((e) => e.toJson()).toList()),
    );
  }
}
