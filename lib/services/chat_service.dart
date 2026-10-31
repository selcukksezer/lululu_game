import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.utcTicks,
    this.isSystem = false,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final int utcTicks;
  final bool isSystem;

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'body': body,
        'utcTicks': utcTicks,
        'isSystem': isSystem,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '?',
      body: json['body'] as String? ?? '',
      utcTicks: (json['utcTicks'] as num?)?.toInt() ?? 0,
      isSystem: json['isSystem'] as bool? ?? false,
    );
  }
}

/// Lobby sohbeti — local-first; bulut realtime online dalgasında bağlanacak.
class ChatService extends ChangeNotifier {
  ChatService._();
  static final ChatService instance = ChatService._();

  static const _prefsKey = 'LululuChatLobbyV1';
  static const maxMessages = 200;

  final List<ChatMessage> _messages = [];
  bool _loaded = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _messages.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          _messages.add(ChatMessage.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {
        _messages.clear();
      }
    }
    if (_messages.isEmpty) {
      _seedWelcome();
    }
    _loaded = true;
    notifyListeners();
  }

  void _seedWelcome() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _messages.addAll([
      ChatMessage(
        id: 'sys_1',
        authorId: 'system',
        authorName: 'Lülülü',
        body: 'Lobi sohbetine hoş geldin! Online eşleşme yakında.',
        utcTicks: now - 60000,
        isSystem: true,
      ),
      ChatMessage(
        id: 'bot_kongo',
        authorId: 'npc_kongo',
        authorName: 'Kongo Lideri',
        body: 'Kurban olduğum Kongo istilası! Kim Suika rekor kıracak?',
        utcTicks: now - 45000,
      ),
      ChatMessage(
        id: 'bot_diva',
        authorId: 'npc_diva',
        authorName: 'Hamam Diva',
        body: 'Ay bayılazaam — Match3 komboları flaş flaş ✨',
        utcTicks: now - 30000,
      ),
    ]);
  }

  Future<void> send(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    await AuthService.instance.ensureLoaded();
    final auth = AuthService.instance;
    if (!auth.isSignedIn) {
      throw StateError('Sohbet için giriş yap');
    }
    final msg = ChatMessage(
      id: 'm_${DateTime.now().microsecondsSinceEpoch}',
      authorId: auth.playerId,
      authorName: auth.displayName,
      body: body,
      utcTicks: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    _messages.add(msg);
    if (_messages.length > maxMessages) {
      _messages.removeRange(0, _messages.length - maxMessages);
    }
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_messages.map((m) => m.toJson()).toList()),
    );
  }
}
