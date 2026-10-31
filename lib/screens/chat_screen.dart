import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/lululu_theme.dart';
import 'auth_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    ChatService.instance.addListener(_onChat);
    AuthService.instance.addListener(_onChat);
    _boot();
  }

  Future<void> _boot() async {
    await AuthService.instance.ensureLoaded();
    await ChatService.instance.ensureLoaded();
    if (mounted) setState(() => _loading = false);
    _jumpBottom();
  }

  void _onChat() {
    if (!mounted) return;
    setState(() {});
    _jumpBottom();
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    ChatService.instance.removeListener(_onChat);
    AuthService.instance.removeListener(_onChat);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _error = null);
    if (!AuthService.instance.isSignedIn) {
      await AuthScreen.open(context);
      return;
    }
    try {
      await ChatService.instance.send(_ctrl.text);
      _ctrl.clear();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final msgs = ChatService.instance.messages;

    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lobi Sohbet',
                            style: GoogleFonts.exo2(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: LululuColors.ink,
                            ),
                          ),
                          Text(
                            auth.isSignedIn
                                ? '${auth.displayName} · lokal lobi'
                                : 'Giriş yap → yaz',
                            style: GoogleFonts.exo2(
                              fontSize: 12,
                              color: LululuColors.mutedTitanium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!auth.isSignedIn)
                      TextButton(
                        onPressed: () => AuthScreen.open(context),
                        child: Text(
                          'GİRİŞ',
                          style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w900,
                            color: LululuColors.liquidGold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: LululuColors.darkObsidian,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: LululuColors.warningSolar.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 16, color: LululuColors.warningSolar),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Online realtime yakında — mesajlar şimdilik cihazda.',
                        style: GoogleFonts.exo2(
                          fontSize: 11,
                          color: LululuColors.mutedTitanium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final mine = m.authorId == auth.playerId;
                    return _Bubble(message: m, mine: mine);
                  },
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: LululuColors.mysticRuby,
                      fontSize: 12,
                    ),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          style: const TextStyle(color: LululuColors.ink),
                          decoration: InputDecoration(
                            hintText: 'Mesaj yaz…',
                            hintStyle: const TextStyle(
                              color: LululuColors.mutedTitanium,
                            ),
                            filled: true,
                            fillColor: LululuColors.darkObsidian,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: LululuColors.cyberFuchsia
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: LululuColors.cyberFuchsia
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: LululuColors.liquidGold,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _send,
                          borderRadius: BorderRadius.circular(14),
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.send_rounded,
                              color: LululuColors.carbonVoid,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

    return body;
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = message.isSystem
        ? LululuColors.darkObsidian
        : mine
            ? LululuColors.cyberFuchsia.withValues(alpha: 0.35)
            : LululuColors.spaceNavy;
    final border = message.isSystem
        ? LululuColors.mutedTitanium.withValues(alpha: 0.35)
        : mine
            ? LululuColors.cyberFuchsia.withValues(alpha: 0.6)
            : LululuColors.liquidGold.withValues(alpha: 0.25);

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.authorName,
              style: GoogleFonts.exo2(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: message.isSystem
                    ? LululuColors.warningSolar
                    : LululuColors.liquidGold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.body,
              style: GoogleFonts.exo2(
                fontSize: 13,
                height: 1.3,
                color: LululuColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
