import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/lululu_press.dart';
import '../widgets/sticker_image.dart';

/// SOHBET — lobi sohbeti (mock veriyle gezilebilir).
///
/// Çevrimiçi oyuncu listesi (avatar + isim + seviye), gelen/giden mesaj
/// baloncukları, altta 48dp mesaj yazma alanı + gönder butonu.
class ChatLobbyScreen extends StatefulWidget {
  const ChatLobbyScreen({super.key});

  @override
  State<ChatLobbyScreen> createState() => _ChatLobbyScreenState();
}

class _LobbyPlayer {
  const _LobbyPlayer({
    required this.name,
    required this.level,
    required this.avatar,
  });

  final String name;
  final int level;
  final String avatar;
}

class _ChatMsg {
  _ChatMsg({
    required this.from,
    required this.text,
    required this.mine,
    required this.avatar,
  });

  final String from;
  final String text;
  final bool mine;
  final String avatar;
}

class _ChatLobbyScreenState extends State<ChatLobbyScreen> {
  static const _players = <_LobbyPlayer>[
    _LobbyPlayer(
      name: 'HamamCan_34',
      level: 24,
      avatar: 'assets/design/bugs_hd/tier6_hd.png',
    ),
    _LobbyPlayer(
      name: 'KongoKralı',
      level: 21,
      avatar: 'assets/design/bugs_hd/tier7_hd.png',
    ),
    _LobbyPlayer(
      name: 'DivaNur',
      level: 18,
      avatar: 'assets/design/bugs_hd/tier5_hd.png',
    ),
    _LobbyPlayer(
      name: 'MakaraMehmet',
      level: 15,
      avatar: 'assets/design/bugs_hd/tier3_hd.png',
    ),
    _LobbyPlayer(
      name: 'HuniKafa',
      level: 12,
      avatar: 'assets/design/bugs_hd/tier1_hd.png',
    ),
  ];

  final _messages = <_ChatMsg>[
    _ChatMsg(
      from: 'HamamCan_34',
      text: 'Arkadaşlar 2048\u2019de 8192 yaptım!',
      mine: false,
      avatar: 'assets/design/bugs_hd/tier6_hd.png',
    ),
    _ChatMsg(
      from: 'DivaNur',
      text: 'Helal! Ben daha 4096\u2019dayım.',
      mine: false,
      avatar: 'assets/design/bugs_hd/tier5_hd.png',
    ),
    _ChatMsg(
      from: 'KongoKralı',
      text: 'Terlik yağmuru kombo x12 denediniz mi?',
      mine: false,
      avatar: 'assets/design/bugs_hd/tier7_hd.png',
    ),
  ];

  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _replyTimer;

  @override
  void dispose() {
    _replyTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    AudioManager().playPop();
    setState(() {
      _messages.add(_ChatMsg(
        from: 'Sen',
        text: text,
        mine: true,
        avatar: 'assets/design/bugs_hd/tier4_hd.png',
      ));
    });
    _ctrl.clear();
    _jumpBottom();
    // Mock cevap — lobiyi canlı hissettirir.
    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final p = _players[DateTime.now().millisecond % _players.length];
      setState(() {
        _messages.add(_ChatMsg(
          from: p.name,
          text: 'Güzel skor, eline sağlık!',
          mine: false,
          avatar: p.avatar,
        ));
      });
      _jumpBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LululuColors.paper,
      appBar: AppBar(
        backgroundColor: LululuColors.paper,
        foregroundColor: LululuColors.inkDark,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'SOHBET',
              style: GoogleFonts.exo2(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: LululuColors.toxicNeon.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: LululuColors.toxicNeon,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_players.length} ÇEVRİMİÇİ',
                    style: GoogleFonts.exo2(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: LululuColors.inkDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Çevrimiçi oyuncular.
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _players.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final p = _players[i];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: LululuColors.toxicNeon,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: StickerImage(
                          assetPath: p.avatar,
                          width: 44,
                          height: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.name,
                      style: GoogleFonts.exo2(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: LululuColors.inkDark,
                      ),
                    ),
                    Text(
                      'Sv. ${p.level}',
                      style: GoogleFonts.exo2(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: LululuColors.mutedTitanium,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Mesajlar.
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (context, i) =>
                  _Bubble(msg: _messages[i]),
            ),
          ),
          // Yazma alanı.
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: LululuColors.paper,
                border: Border(
                  top: BorderSide(
                    color: LululuColors.mutedTitanium
                        .withValues(alpha: 0.25),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      constraints:
                          const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: LululuColors.paperSoft,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: LululuColors.mutedTitanium
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Mesaj yaz…',
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.exo2(
                            fontSize: 14,
                            color: LululuColors.mutedTitanium,
                          ),
                        ),
                        style: GoogleFonts.exo2(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: LululuColors.inkDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  LululuPress(
                    onTap: _send,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            LululuColors.liquidGold,
                            LululuColors.cyberFuchsia,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: LululuColors.paper,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});

  final _ChatMsg msg;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: msg.mine
            ? LululuColors.liquidGold
            : LululuColors.paperSoft,
        borderRadius: BorderRadius.circular(18).copyWith(
          bottomRight:
              msg.mine ? Radius.zero : const Radius.circular(18),
          bottomLeft:
              msg.mine ? const Radius.circular(18) : Radius.zero,
        ),
        border: msg.mine
            ? null
            : Border.all(
                color: LululuColors.mutedTitanium
                    .withValues(alpha: 0.25),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!msg.mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                msg.from,
                style: GoogleFonts.exo2(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.cyberFuchsia,
                ),
              ),
            ),
          Text(
            msg.text,
            style: GoogleFonts.exo2(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: LululuColors.inkDark,
            ),
          ),
        ],
      ),
    );

    if (msg.mine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [bubble],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipOval(
            child: StickerImage(
              assetPath: msg.avatar,
              width: 32,
              height: 32,
            ),
          ),
          const SizedBox(width: 8),
          bubble,
        ],
      ),
    );
  }
}
