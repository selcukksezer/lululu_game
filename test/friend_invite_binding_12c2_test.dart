// 12C2 — FriendInvite bağlama testleri.
//
// Kapsar: davet kodu gösterimi + kopyalama (sheet), paylaşım
// düğmesinin varlığı, kod biçimi. Redeem akışına dokunulmaz —
// `invite_redeem_9a_test.dart` aynen geçer (bu dosya redeem
// çağırmaz, yalnız gösterim/kopyalama + biçim denetler).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/friend_invite_service.dart';
import 'package:lululu_game/widgets/invite_redeem_sheet.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('FriendInviteService kod gösterimi', () {
    test('inviteCode biçim-geçerli ve kararlı gösterilir', () {
      final code = FriendInviteService.instance.inviteCode;
      expect(code, isNotEmpty);
      expect(
        FriendInviteService.isValidFormat(
          FriendInviteService.normalizeCode(code),
        ),
        isTrue,
      );
      // Aynı oturumda aynı kod gösterilir.
      expect(FriendInviteService.instance.inviteCode, code);
    });
  });

  group('InviteRedeemSheet kopyalama', () {
    testWidgets('kod görünür, kopyalama panoya yazar + onay gösterir',
        (tester) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            SystemChannels.platform,
            (MethodCall call) async {
              if (call.method == 'Clipboard.setData') {
                copied =
                    (call.arguments as Map<String, Object?>)['text']
                        as String?;
              }
              return null;
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding
            .instance
            .defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        wrapWithL10n(const Scaffold(body: InviteRedeemSheet())),
      );
      await tester.pump();

      final code = FriendInviteService.instance.inviteCode;
      expect(find.text(code), findsOneWidget);
      // Paylaşım düğmesi (K17 akışı) yerinde durur.
      expect(find.text('PAYLAŞ'), findsOneWidget);
      expect(
        find.byKey(const Key('invite_copy_code_button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('invite_copy_code_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(copied, code);
      expect(find.text('Davet kodu kopyalandı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sheet EN dilinde de kodu + kopyalamayı gösterir',
        (tester) async {
      await tester.pumpWidget(
        wrapWithL10n(
          const Scaffold(body: InviteRedeemSheet()),
          locale: const Locale('en'),
        ),
      );
      await tester.pump();

      final code = FriendInviteService.instance.inviteCode;
      expect(find.text(code), findsOneWidget);
      expect(
        find.byKey(const Key('invite_copy_code_button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
