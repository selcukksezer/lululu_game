import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/audio_manager.dart';
import '../services/chat_service.dart';
import '../widgets/home/lululu_dock_bar.dart';

class _ChatItem {
  const _ChatItem({
    required this.sender,
    required this.text,
    required this.time,
    required this.avatarAsset,
    required this.isMe,
    this.stickerAsset,
    this.messageId,
  });

  final String sender;
  final String text;
  final String time;
  final String avatarAsset;
  final bool isMe;
  final String? stickerAsset;

  /// ChatService mesaj kimliği; bulut gönderim durumu bununla sorgulanır.
  final String? messageId;
}

/// 1:1 Pixel-Perfect ChatScreen matching HTML prototype `#scr-chat`
/// (`reference-chat.png` & `reference-chat-spec.json`).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _sendError;
  bool _isSending = false;

  // Exact initial messages from `#scr-chat` (`reference-chat.png` & `reference-chat-spec.json`)
  final List<_ChatItem> _messages = <_ChatItem>[
    const _ChatItem(
      sender: 'TerlikUstası',
      text: 'Dün gece 8.540 yaptım, Suika rekoru yine bende!',
      time: '09:12',
      avatarAsset: 'assets/design/bugs_hd/tier4_hd.png',
      isMe: false,
    ),
    const _ChatItem(
      sender: 'MakaraMehmet',
      text: "Pembe Bornozlu'ya tek birleşme kaldı. Bu akşam bitiriyorum, izleyin.",
      time: '09:18',
      avatarAsset: 'assets/design/bugs_hd/tier3_hd.png',
      isMe: false,
    ),
    const _ChatItem(
      sender: 'HuniKafa',
      text: "Lonca turnuvası cumartesi 20.00'da. Herkes arenada olsun!",
      time: '09:24',
      avatarAsset: 'assets/design/bugs_hd/tier1_hd.png',
      isMe: false,
    ),
    const _ChatItem(
      sender: 'BilgeDede',
      text: "Kombo rekorumu x12'ye çıkardım. Darısı başınıza gençler.",
      time: '09:31',
      avatarAsset: 'assets/design/bugs_hd/tier8_hd.png',
      isMe: false,
    ),
    const _ChatItem(
      sender: 'Sen · LülüSever',
      text: 'Cumartesi oradayım — rekoru geri alacağım!',
      time: '09:33',
      avatarAsset: 'assets/design/bugs_hd/tier5_hd.png',
      isMe: true,
    ),
  ];

  static String _toTurkishUpper(String input) {
    return input
        .replaceAll('i', 'İ')
        .replaceAll('ı', 'I')
        .replaceAll('ğ', 'Ğ')
        .replaceAll('ü', 'Ü')
        .replaceAll('ş', 'Ş')
        .replaceAll('ö', 'Ö')
        .replaceAll('ç', 'Ç')
        .toUpperCase();
  }

  static TextStyle _baloo2({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    ).copyWith(
      fontFamily: 'Baloo 2',
      fontWeight: fontWeight,
      fontFamilyFallback: const ['Nunito'],
    );
  }

  static TextStyle _nunito({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    ).copyWith(
      fontFamily: 'Nunito',
      fontWeight: fontWeight,
      fontFamilyFallback: const ['Baloo 2'],
    );
  }

  @override
  void initState() {
    super.initState();
    // Kanal görünümü açılırken okundu işaretle (S2#19): yükleme bitince
    // çağrılır; aktif kanalın yoklama sayacı sıfırlanır. Odak dönüşünde
    // tekrar gerekmez — aktif kanalın bulut akışı yeni mesajları
    // geldiğinde okundu sayar (ChatService._bindCloudStreamIfReady).
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _closeOrPop() {
    AudioManager().playPop();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    AudioManager().playPop();
    setState(() {
      _isSending = true;
      _sendError = null;
    });
    // Bağlantı denetimi için yeni bağımlılık yok: gönderim hatası görünür
    // duruma bağlanır, metin alanda kalır, tekrar dene düğmesi sunulur.
    late final ChatMessage sent;
    try {
      sent = await ChatService.instance.sendText(text);
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
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _isSending = false;
      _messages.add(
        _ChatItem(
          sender: 'Sen · LülüSever',
          text: sent.body,
          time: timeStr,
          avatarAsset: 'assets/design/bugs_hd/tier5_hd.png',
          isMe: true,
          messageId: sent.id,
        ),
      );
      _controller.clear();
    });
    _scrollToBottom();
  }

  /// Buluta gönderilemeyen mesajların bulut yazımını yeniden dener.
  Future<void> _retryCloudPushes() async {
    await ChatService.instance.retryFailedCloudPushes();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _sendSticker(
    int tier,
    ({String name, String line, String asset}) sticker,
  ) async {
    AudioManager().playPop();
    late final ChatMessage sent;
    try {
      sent = await ChatService.instance.sendBugSticker(tier);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendError = e is StateError
            ? e.message.toString()
            : context.l10n.stickerSendFailed;
      });
      return;
    }
    if (!mounted) return;
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _sendError = null;
      _messages.add(
        _ChatItem(
          sender: 'Sen · LülüSever',
          text: sticker.line,
          time: timeStr,
          avatarAsset: 'assets/design/bugs_hd/tier5_hd.png',
          isMe: true,
          stickerAsset: sticker.asset,
          messageId: sent.id,
        ),
      );
    });
    _scrollToBottom();
  }

  void _openStickerSheet() {
    AudioManager().playPop();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.l10n.quickStickerTitle,
                  style: _baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF141B2A),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ChatService.bugStickerCatalog.entries.map((entry) {
                    final sticker = entry.value;
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _sendSticker(entry.key, sticker);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE6EAF2),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              sticker.asset,
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ChatService.bugStickerNameFor(
                                entry.key,
                                Localizations.localeOf(ctx),
                              ),
                              style: _nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF141B2A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mqTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (mqTop == 0) const _ChatPrototypeStatusBar(),
                  _buildPageTitle(),
                  Expanded(
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        14,
                        11.8,
                        14,
                        widget.embedded ? 90 : 178,
                      ),
                      itemCount: _messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12.2),
                      itemBuilder: (context, index) =>
                          _buildMessageRow(_messages[index]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: widget.embedded ? 12 : 98,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_sendError != null ||
                    ChatService.instance.hasCloudFailures)
                  _buildSendStatusBanner(),
                _buildChatInput(),
              ],
            ),
          ),
          if (!widget.embedded)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              height: 84,
              child: _ChatFloatingDock(
                activeTab: LululuDockTab.home,
                onSelectTab: (_) => _closeOrPop(),
              ),
            ),
        ],
      ),
    );
  }

  /// `.page-title` -> height: 60, padding: 10px 14px 2px 14px, gap: 10px
  Widget _buildPageTitle() {
    return Container(
      height: 60,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            button: true,
            label: context.l10n.goBackLabel,
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeOrPop,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A141B2A),
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/design/ui/back_btn.png',
                width: 29,
                height: 29,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: Color(0xFF141B2A),
                ),
              ),
            ),
          ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                context.l10n.chatTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _baloo2(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF141B2A),
                  letterSpacing: -0.1,
                  height: 25.76 / 23.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x73080B12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF37E08B),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x4D37E08B),
                        blurRadius: 0,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.onlineCount5,
                  style: _baloo2(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.55,
                    height: 17.05 / 11.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `.msg` -> display: flex; gap: 9px; align-items: flex-start
  Widget _buildMessageRow(_ChatItem item) {
    final avatar = CustomPaint(
      painter: const _BlurredRRectShadowPainter(
        color: Color(0x26141B2A),
        offset: Offset(0, 3),
        sigma: 3.0,
        radius: 20.0,
      ),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Image.asset(
            item.avatarAsset,
            width: 36,
            height: 36,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );

    final bubble = Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 329.64),
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6.9, 12, 10.15),
            decoration: BoxDecoration(
              color: item.isMe ? null : Colors.white,
              gradient: item.isMe
                  ? const LinearGradient(
                      begin: Alignment(-0.5362, -2.5571),
                      end: Alignment(0.5362, 2.5571),
                      colors: [
                        Color(0xFFF4538B),
                        Color(0xFF9B5DE5),
                      ],
                    )
                  : null,
              borderRadius: item.isMe
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F141B2A),
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _toTurkishUpper(item.sender),
                  style: _baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: item.isMe
                        ? const Color(0xFFFFD34D)
                        : const Color(0xFFB80F42),
                    letterSpacing: 0.24,
                    height: 18.6 / 12.0,
                  ),
                ),
                const SizedBox(height: 0.8),
                if (item.stickerAsset != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          item.stickerAsset!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            item.text,
                            style: _nunito(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: item.isMe
                                  ? Colors.white
                                  : const Color(0xFF141B2A),
                              letterSpacing: 0.0,
                              height: 18.225 / 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    item.text,
                    style: _nunito(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: item.isMe ? Colors.white : const Color(0xFF141B2A),
                      letterSpacing: 0.0,
                      height: 18.225 / 13.5,
                    ),
                  ),
                const SizedBox(height: 3.2),
                Text(
                  item.time,
                  textAlign: item.isMe ? TextAlign.right : TextAlign.left,
                  style: _nunito(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: item.isMe
                        ? const Color(0xBFFFFFFF)
                        : const Color(0xFF93A0B5),
                    height: 16.275 / 10.5,
                  ),
                ),
                if (item.messageId != null &&
                    ChatService.instance.isCloudFailed(item.messageId!))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      context.l10n.notSentLocalOnly,
                      textAlign:
                          item.isMe ? TextAlign.right : TextAlign.left,
                      style: _nunito(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: item.isMe
                            ? const Color(0xFFFFE27A)
                            : const Color(0xFFB80F42),
                        height: 16.275 / 10.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Row(
      mainAxisAlignment:
          item.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: item.isMe
          ? [bubble, const SizedBox(width: 9), avatar]
          : [avatar, const SizedBox(width: 9), bubble],
    );
  }

  /// Gönderim hatası / buluta gönderilememe durumu: görünür uyarı + tekrar dene.
  Widget _buildSendStatusBanner() {
    final isError = _sendError != null;
    final message = isError
        ? _sendError!
        : context.l10n.cloudSendFailedNote;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFDECEA) : const Color(0xFFFFF4E0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isError ? const Color(0xFFF5C6C2) : const Color(0xFFFFD98A),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: _nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF141B2A),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isError ? _sendMessage : _retryCloudPushes,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF141B2A),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.l10n.retryCaps,
                  style: _baloo2(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `.chat-input` -> left: 10, right: 10, bottom: 98, height: 66, padding: 8px, gap: 8px
  Widget _buildChatInput() {
    return CustomPaint(
      painter: const _BlurredRRectShadowPainter(
        color: Color(0x29141B2A),
        offset: Offset(0, 10),
        sigma: 11.0,
        radius: 33.0,
      ),
      child: Container(
        height: 66,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFFE6EAF2),
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: _nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF141B2A),
                    letterSpacing: 0.0,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: context.l10n.guildMessageHint,
                    hintStyle: _nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF757575),
                      letterSpacing: 0.0,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: context.l10n.sendMessageLabel,
              onLongPressHint: context.l10n.sendStickerHint,
              child: GestureDetector(
              onTap: _sendMessage,
              onLongPress: _openStickerSheet,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF37E08B),
                      Color(0xFF12B76A),
                      Color(0xFF0A9553),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF066C3C),
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const CustomPaint(
                  size: Size(20, 20),
                  painter: _ChatSendPlanePainter(),
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatSendPlanePainter extends CustomPainter {
  const _ChatSendPlanePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // SVG path: M3.4 20.4 21.8 12 3.4 3.6l-.01 6.53L14 12 3.39 13.87z
    final path = Path()
      ..moveTo(3.4, 20.4)
      ..lineTo(21.8, 12.0)
      ..lineTo(3.4, 3.6)
      ..lineTo(3.39, 10.13)
      ..lineTo(14.0, 12.0)
      ..lineTo(3.39, 13.87)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChatFloatingDock extends StatelessWidget {
  final LululuDockTab activeTab;
  final ValueChanged<LululuDockTab> onSelectTab;

  const _ChatFloatingDock({
    required this.activeTab,
    required this.onSelectTab,
  });

  static const _tabs = LululuDockTab.values;

  static String _label(AppLocalizations l10n, LululuDockTab tab) =>
      switch (tab) {
        LululuDockTab.home => l10n.navHome,
        LululuDockTab.modes => l10n.navModes,
        LululuDockTab.family => l10n.navFamily,
        LululuDockTab.shop => l10n.navShop,
        LululuDockTab.scores => l10n.navScores,
      };

  static String _icon(LululuDockTab tab) => switch (tab) {
        LululuDockTab.home => 'assets/icons2/home.png',
        LululuDockTab.modes => 'assets/icons2/target.png',
        LululuDockTab.family => 'assets/icons2/paw.png',
        LululuDockTab.shop => 'assets/icons2/cart.png',
        LululuDockTab.scores => 'assets/icons2/trophy.png',
      };

  static Widget _buildIconWithDropShadow(String asset, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(0, 2),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0x47000000),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    asset,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _BlurredRRectShadowPainter(
        color: Color(0x7A080B12),
        offset: Offset(0, 22),
        sigma: 19.0,
        radius: 42.0,
      ),
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 3),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.72],
            colors: [
              Color(0xFF1E2538),
              Color(0xFF080B12),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x47080B12),
              offset: Offset(0, 7),
              blurRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth =
                  (constraints.maxWidth - 14.0).clamp(100.0, 410.0);
              final tabWidth = usableWidth / _tabs.length;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: _ChatDockSurfacePainter(),
                    ),
                  ),
                  Positioned(
                    left: 26,
                    right: 26,
                    top: 5,
                    height: 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.20),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 7.0 + activeTab.index * tabWidth,
                    top: 7.0,
                    width: tabWidth,
                    height: 64.0,
                    child: CustomPaint(
                      painter: const _BlurredRRectShadowPainter(
                        color: Color(0x47E01E5A),
                        offset: Offset(0, 10),
                        sigma: 9.0,
                        radius: 32.0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xF0FFFFFF),
                            width: 2,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.40, 0.74, 1.0],
                            colors: [
                              Color(0xFFFFE27A),
                              Color(0xFFFFB800),
                              Color(0xFFFF6B35),
                              Color(0xFFE01E5A),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D000000),
                              offset: Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: CustomPaint(
                                  painter: _ChatDockActiveIndInsetPainter(),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                right: 8,
                                top: 2,
                                height: 9,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0x61FFFFFF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(7),
                    child: Row(
                      children: [
                        for (final tab in _tabs)
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: _label(context.l10n, tab),
                              selected: tab == activeTab,
                              child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelectTab(tab),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: tab == activeTab
                                      ? const Color(0x1FFFB800)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: SizedBox(
                                  height: 64,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.topCenter,
                                    children: [
                                      if (tab == activeTab)
                                        Positioned(
                                          top: 1.8,
                                          width: 42.4,
                                          height: 42.4,
                                          child: CustomPaint(
                                            painter:
                                                const _BlurredRRectShadowPainter(
                                              color: Color(0x3D000000),
                                              offset: Offset(0, 7),
                                              sigma: 6.0,
                                              radius: 21.2,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color(0x597A082E),
                                                    offset: Offset(0, 4),
                                                    blurRadius: 0,
                                                  ),
                                                ],
                                              ),
                                              child: ClipOval(
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    const Positioned.fill(
                                                      child: CustomPaint(
                                                        painter:
                                                            _ChatDockCircleInsetPainter(
                                                          dy: -4.24,
                                                          color:
                                                              Color(0x1F080B12),
                                                        ),
                                                      ),
                                                    ),
                                                    _buildIconWithDropShadow(
                                                      _icon(tab),
                                                      35,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Positioned(
                                          top: 7.0,
                                          width: 40.0,
                                          height: 40.0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(0x17FFFFFF),
                                              border: Border.all(
                                                color: const Color(0x2EFFFFFF),
                                                width: 2,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x4D000000),
                                                  offset: Offset(0, 3),
                                                  blurRadius: 0,
                                                ),
                                              ],
                                            ),
                                            child: ClipOval(
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  const Positioned.fill(
                                                    child: CustomPaint(
                                                      painter:
                                                          _ChatDockCircleInsetPainter(
                                                        dy: 2.0,
                                                        color:
                                                            Color(0x29FFFFFF),
                                                      ),
                                                    ),
                                                  ),
                                                  _buildIconWithDropShadow(
                                                    _icon(tab),
                                                    33,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        left: -4,
                                        right: -4,
                                        top: 49.0,
                                        child: Text(
                                          _label(context.l10n, tab),
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          style: _ChatScreenState._baloo2(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            height: 1.0,
                                            letterSpacing: -0.1,
                                            color: tab == activeTab
                                                ? Colors.white
                                                : const Color(0xA8FFFFFF),
                                            shadows: tab == activeTab
                                                ? const [
                                                    Shadow(
                                                      color:
                                                          Color(0x737A082E),
                                                      offset: Offset(0, 2),
                                                      blurRadius: 0,
                                                    ),
                                                  ]
                                                : const [
                                                    Shadow(
                                                      color:
                                                          Color(0xBF000000),
                                                      offset: Offset(0, 1),
                                                      blurRadius: 0,
                                                    ),
                                                  ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BlurredRRectShadowPainter extends CustomPainter {
  final Color color;
  final Offset offset;
  final double sigma;
  final double radius;

  const _BlurredRRectShadowPainter({
    required this.color,
    required this.offset,
    required this.sigma,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).shift(offset);
    final paint = Paint()
      ..color = color
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BlurredRRectShadowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.offset != offset ||
      oldDelegate.sigma != sigma ||
      oldDelegate.radius != radius;
}

class _ChatDockSurfacePainter extends CustomPainter {
  const _ChatDockSurfacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.translate(size.width * 0.18, -size.height * 0.30);
    canvas.scale(size.width * 1.20, size.height * 1.60);
    final radialPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1.0,
        const [Color(0x38FFFFFF), Color(0x00FFFFFF)],
        const [0.0, 0.48],
      );
    canvas.drawRect(const Rect.fromLTRB(-2, -2, 2, 2), radialPaint);
    canvas.restore();

    final radius = Radius.circular(size.height / 2);
    final outerPath = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));

    final topInsetPath = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, 3)),
    );
    canvas.drawPath(topInsetPath, Paint()..color = const Color(0x29FFFFFF));

    final bottomInsetPath = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, -7)),
    );
    canvas.drawPath(bottomInsetPath, Paint()..color = const Color(0x57000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChatDockActiveIndInsetPainter extends CustomPainter {
  const _ChatDockActiveIndInsetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final outerPath = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));

    final topInset = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, 3)),
    );
    canvas.drawPath(topInset, Paint()..color = const Color(0x8CFFFFFF));

    final bottomInset = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, -6)),
    );
    canvas.drawPath(bottomInset, Paint()..color = const Color(0x3D7A082E));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChatDockCircleInsetPainter extends CustomPainter {
  final double dy;
  final Color color;

  const _ChatDockCircleInsetPainter({required this.dy, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addOval(Offset.zero & size);
    final crescent = Path.combine(
      PathOperation.difference,
      outer,
      outer.shift(Offset(0, dy)),
    );
    canvas.drawPath(crescent, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ChatDockCircleInsetPainter oldDelegate) =>
      oldDelegate.dy != dy || oldDelegate.color != color;
}

class _ChatPrototypeStatusBar extends StatelessWidget {
  const _ChatPrototypeStatusBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 35.4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '09:41',
              style: _ChatScreenState._nunito(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF141B2A),
                height: 1.55,
              ),
            ),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: Size(15, 15),
                  painter: _ChatSignalPainter(),
                ),
                SizedBox(width: 5),
                CustomPaint(
                  size: Size(15, 15),
                  painter: _ChatBatteryPainter(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatSignalPainter extends CustomPainter {
  const _ChatSignalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = const Color(0xFF141B2A)
      ..style = PaintingStyle.fill;
    canvas.drawRect(const Rect.fromLTWH(2, 17, 3, 4), paint);
    canvas.drawRect(const Rect.fromLTWH(7.5, 13, 3, 8), paint);
    canvas.drawRect(const Rect.fromLTWH(13, 9, 3, 12), paint);
    canvas.drawRect(const Rect.fromLTWH(18.5, 5, 3, 16), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChatBatteryPainter extends CustomPainter {
  const _ChatBatteryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    final strokePaint = Paint()
      ..color = const Color(0xFF141B2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.5, 8, 17, 9),
        const Radius.circular(2.5),
      ),
      strokePaint,
    );
    final fillPaint = Paint()
      ..color = const Color(0xFF141B2A)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4.5, 10, 10, 5),
        const Radius.circular(1),
      ),
      fillPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
