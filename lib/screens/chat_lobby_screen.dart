import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/audio_manager.dart';
import '../services/chat_service.dart';
import '../theme/lululu_theme.dart';
import '../widgets/lululu_press.dart';
import '../widgets/sticker_image.dart';

/// SOHBET — lobi sohbeti (mock veriyle gezilebilir).
///
/// Çevrimiçi oyuncu listesi (avatar + isim + seviye), gelen/giden mesaj
/// baloncukları, altta 48dp mesaj yazma alanı + gönder butonu.
/// Üstteki kanal satırı ChatService'e bağlıdır: kanal seçimi
/// switchChannel üzerinden gider, okunmamış rozetleri S2#19 sayacını
/// gösterir (mock mesaj listesi kanala göre değişmez).
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
  void initState() {
    super.initState();
    // Kanal görünümü açılırken okundu işaretle (S2#19): yükleme bitince
    // çağrılır ki önbellekteki mesajlar "görüldü" sayılsın; yoklama
    // bunları tekrar okunmamış saymaz.
    unawaited(_markCurrentChannelRead());
  }

  Future<void> _markCurrentChannelRead() async {
    try {
      await ChatService.instance.ensureLoaded();
    } catch (e) {
      debugPrint('[lululu] Chat okundu işaretlenemedi: $e');
      return;
    }
    if (!mounted) return;
    ChatService.instance.markChannelRead(
      ChatService.instance.currentChannel,
    );
  }

  /// Okunmamış rozet etiketi: sayaç yoklama penceresi
  /// ([ChatService.unreadProbeLimit]) ile sınırlı olduğundan sınırda
  /// "10+" gösterilir; 10'u aşan kesin sayı iddia edilmez.
  static String _unreadLabel(int count) {
    if (count >= ChatService.unreadProbeLimit) {
      return '${ChatService.unreadProbeLimit}+';
    }
    return '$count';
  }

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

  /// Kanal satırı: 3 kanal çipi + okunmamış rozeti (S2#19). Seçim
  /// [ChatService.switchChannel] üzerinden gider; geçiş hem ayrılınan
  /// hem girilen kanalı okundu sayar. Rozetler [ListenableBuilder] ile
  /// güncellenir; sayı 0 ise rozet gizlidir.
  Widget _buildChannelRow() {
    return ListenableBuilder(
      listenable: ChatService.instance,
      builder: (context, _) {
        final channels = ChatChannel.values;
        final current = ChatService.instance.currentChannel;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Row(
            children: [
              for (var i = 0; i < channels.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _buildChannelChip(
                    channel: channels[i],
                    selected: channels[i] == current,
                    unreadCount: ChatService.instance.unreadCountFor(
                      channels[i],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildChannelChip({
    required ChatChannel channel,
    required bool selected,
    required int unreadCount,
  }) {
    return Semantics(
      button: true,
      label: context.l10n.channelSelectLabel(channel.displayNameFor(Localizations.localeOf(context))),
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ChatService.instance.switchChannel(channel),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? LululuColors.inkDark : LululuColors.paperSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? LululuColors.inkDark
                  : LululuColors.mutedTitanium.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  channel.displayNameFor(Localizations.localeOf(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color:
                        selected ? LululuColors.paper : LululuColors.inkDark,
                  ),
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  height: 18,
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: LululuColors.mysticRuby,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _unreadLabel(unreadCount),
                    style: GoogleFonts.exo2(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      color: LululuColors.paper,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
              context.l10n.chatTitle,
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
                    context.l10n.onlinePlayersCount(_players.length),
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
          // Kanal seçimi + okunmamış rozetleri (S2#19).
          _buildChannelRow(),
          // Çevrimiçi oyuncular.
          SizedBox(
            height: 110, // 11pt seviye satırı ve 1.3x metin ölçeği taşmasın diye.
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
                      context.l10n.levelShort(p.level),
                      style: GoogleFonts.exo2(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: LululuColors.inkDark,
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
                          hintText: context.l10n.messageHint,
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.exo2(
                            fontSize: 14,
                            color: LululuColors.bodyOnLight,
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
