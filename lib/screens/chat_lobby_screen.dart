import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../navigation/game_routes.dart';
import '../services/audio_manager.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/lululu_theme.dart';
import '../widgets/lululu_press.dart';
import '../widgets/sticker_image.dart';

/// SOHBET LOBİSİ — canlı lobi sohbeti.
///
/// 12D1: mock oyuncu/mesaj listeleri kaldırıldı, ekran
/// [ChatService] verisine bağlandı:
/// * Mesajlar: aktif kanalın gerçek listesi
///   ([ChatService.messagesForChannel]) — kullanıcı/bulut mesajı
///   yoksa servisin tohum akışı (kanal başına) gösterilir; liste
///   asla elle yazılmış sahte veriye düşmez.
/// * Çevrimiçi oyuncular: aktif kanal mesajlarındaki farklı
///   yazarlar (sistem mesajı hariç); seviye satırı yok — yazarın
///   gerçek seviyesi serviste tutulmaz, uydurulmaz.
/// * Gönderim: [ChatService.sendText] üzerinden gider; şart onayı
///   yoksa [ChatScreen] ile aynı diyalog akışı çalışır (misafir
///   kimliği + şart onayı akışı bozulmaz).
/// * Kanal satırı zaten servise bağlıydı (değişmedi): kanal seçimi
///   switchChannel üzerinden gider, okunmamış rozetleri S2#19
///   sayacını gösterir.
class ChatLobbyScreen extends StatefulWidget {
  const ChatLobbyScreen({super.key});

  @override
  State<ChatLobbyScreen> createState() => _ChatLobbyScreenState();
}

class _LobbyPlayer {
  const _LobbyPlayer({required this.name, required this.avatar});

  final String name;
  final String avatar;
}

class _ChatLobbyScreenState extends State<ChatLobbyScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _isSending = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    ChatService.instance.addListener(_onChatChanged);
    // Kanal görünümü açılırken okundu işaretle (S2#19): yükleme bitince
    // çağrılır ki önbellekteki mesajlar "görüldü" sayılsın; yoklama
    // bunları tekrar okunmamış saymaz.
    unawaited(_markCurrentChannelRead());
    unawaited(_ensureGuestIdentityForChat());
  }

  void _onChatChanged() {
    if (mounted) setState(() {});
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

  /// Misafir kimliği ilk sohbet kullanımında oluşur (kalıcı UUID + ad);
  /// kayıtlı kullanıcıda çağrı kimlik oluşturmaz.
  /// [ChatScreen._ensureGuestIdentityForChat] ile aynı akış.
  Future<void> _ensureGuestIdentityForChat() async {
    try {
      await ChatService.instance.ensureLoaded();
      await AuthService.instance.ensureLoaded();
      final auth = AuthService.instance;
      if (!auth.isSignedIn || (auth.user?.isGuest ?? false)) {
        await ChatService.instance.ensureGuestIdentity();
      }
    } catch (e) {
      debugPrint('[lululu] Misafir kimliği oluşturulamadı: $e');
    }
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

  /// Görüntülenecek mesajlar: aktif kanalın gerçek listesi; kullanıcı/
  /// bulut mesajı yoksa servisin tohum akışı döner (boş kanal olmaz).
  List<ChatMessage> _displayMessages() {
    return ChatService.instance.messagesForChannel(
      ChatService.instance.currentChannel,
    );
  }

  /// Lobi oyuncu satırı: aktif kanal mesajlarındaki farklı yazarlar
  /// (sistem mesajı hariç), mesaj sırasıyla; en fazla 8 kişi.
  List<_LobbyPlayer> _lobbyPlayers() {
    final seen = <String>{};
    final players = <_LobbyPlayer>[];
    for (final msg in _displayMessages()) {
      if (msg.isSystem) continue;
      if (!seen.add(msg.authorId)) continue;
      players.add(
        _LobbyPlayer(name: msg.authorName, avatar: _avatarFor(msg)),
      );
      if (players.length >= 8) break;
    }
    return players;
  }

  /// Yazar avatarı: çıkartmalı mesajda çıkartma görseli, misafirde
  /// varsayılan simge, diğerlerinde yazar kimliğine kararlı bir tier
  /// görseli (aynı yazar hep aynı simgeyle görünür).
  /// [ChatScreen._avatarFor] ile aynı kural.
  static String _avatarFor(ChatMessage msg) {
    if (msg.stickerAsset != null) return msg.stickerAsset!;
    if (msg.isGuestAuthor) return 'assets/design/bugs_hd/tier1_hd.png';
    var hash = 0;
    for (final unit in msg.authorId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final tier = (hash % 13) + 1;
    return 'assets/design/bugs_hd/tier${tier}_hd.png';
  }

  @override
  void dispose() {
    ChatService.instance.removeListener(_onChatChanged);
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

  void _closeOrPop() {
    AudioManager().playPop();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    // Yığında ekran yoksa (bağımsız/ilk açılış): suskun kalma, ana sekmeye git.
    goTo(context, LululuRoutes.hub, replace: true);
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isSending) return;
    AudioManager().playPop();
    setState(() {
      _isSending = true;
      _sendError = null;
    });
    // Gönderilen mesaj servisten okunur (dinleyici yeniden çizer); yerel
    // listeye ekleme yapılmaz.
    try {
      await ChatService.instance.sendText(text);
    } on ChatTermsRequiredException {
      // Şart onayı yok: diyaloğu göster, kabulde bir kez tekrar dene.
      bool accepted;
      try {
        accepted = await _showTermsDialog();
      } catch (e) {
        debugPrint('[lululu] Sohbet şart diyaloğu açılamadı: $e');
        if (!mounted) return;
        setState(() {
          _isSending = false;
          _sendError = context.l10n.messageSendFailed;
        });
        return;
      }
      if (!mounted) return;
      if (!accepted) {
        setState(() {
          _isSending = false;
          _sendError = context.l10n.chatTermsRequired;
        });
        return;
      }
      try {
        await ChatService.instance.sendText(text);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSending = false;
          _sendError = e is StateError
              ? e.message.toString()
              : context.l10n.messageSendFailed;
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _sendError = e is StateError
            ? e.message.toString()
            : context.l10n.messageSendFailed;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _ctrl.clear();
    });
    _jumpBottom();
  }

  /// Sohbet şart diyaloğu: kabulde onay kalıcı kaydedilir, true döner.
  /// [ChatScreen._showTermsDialog] ile aynı akış.
  Future<bool> _showTermsDialog() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(ctx.l10n.chatTermsTitle),
          content: Text(ctx.l10n.chatTermsBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.l10n.chatTermsDecline),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(ctx.l10n.chatTermsAccept),
            ),
          ],
        );
      },
    );
    if (accepted == true) {
      try {
        await ChatService.instance.acceptChatTerms();
      } catch (e) {
        debugPrint('[lululu] Sohbet şart onayı kaydedilemedi: $e');
        return false;
      }
      return true;
    }
    return false;
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
    final messages = _displayMessages();
    final players = _lobbyPlayers();
    return Scaffold(
      backgroundColor: LululuColors.paper,
      appBar: AppBar(
        backgroundColor: LululuColors.paper,
        foregroundColor: LululuColors.inkDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Semantics(
          button: true,
          label: context.l10n.goBackLabel,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _closeOrPop,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                context.l10n.chatLobbyTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.exo2(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
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
                    context.l10n.onlinePlayersCount(players.length),
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
          // Çevrimiçi oyuncular (gerçek yazarlar; boşsa satır gizlenir).
          if (players.isNotEmpty)
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: players.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final p = players[i];
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.exo2(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
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
              itemCount: messages.length,
              itemBuilder: (context, i) => _Bubble(
                msg: messages[i],
                mine: ChatService.instance.isOwnMessage(messages[i]),
              ),
            ),
          ),
          // Gönderim hatası (varsa).
          if (_sendError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Text(
                _sendError!,
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: LululuColors.mysticRuby,
                ),
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
  const _Bubble({required this.msg, required this.mine});

  final ChatMessage msg;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final text = msg.body.isNotEmpty ? msg.body : (msg.voiceLine ?? '');
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine
            ? LululuColors.liquidGold
            : LululuColors.paperSoft,
        borderRadius: BorderRadius.circular(18).copyWith(
          bottomRight:
              mine ? Radius.zero : const Radius.circular(18),
          bottomLeft:
              mine ? const Radius.circular(18) : Radius.zero,
        ),
        border: mine
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
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                msg.authorName,
                style: GoogleFonts.exo2(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.cyberFuchsia,
                ),
              ),
            ),
          Text(
            text,
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

    if (mine) {
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
              assetPath: _ChatLobbyScreenState._avatarFor(msg),
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
