import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/leaderboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Fresh singletons via reload after prefs wipe.
    await AuthService.instance.load();
    await AuthService.instance.signOut();
    await LeaderboardService.instance.load();
  });

  test('register + login with username/password', () async {
    final auth = AuthService.instance;
    final created = await auth.register(
      username: 'Makara_Abi',
      password: 'lulu123',
    );
    expect(created.username, 'makara_abi');
    expect(created.provider, AuthProviderKind.local);
    expect(auth.isSignedIn, isTrue);

    await auth.signOut();
    expect(auth.isSignedIn, isFalse);

    final again = await auth.login(
      username: 'makara_abi',
      password: 'lulu123',
    );
    expect(again.id, created.id);
    expect(again.displayName, isNotEmpty);
  });

  test('wrong password rejected', () async {
    final auth = AuthService.instance;
    await auth.register(username: 'diva', password: 'hamam1');
    await auth.signOut();
    expect(
      () => auth.login(username: 'diva', password: 'yanlis'),
      throwsA(isA<StateError>()),
    );
  });

  test('duplicate register rejected', () async {
    final auth = AuthService.instance;
    await auth.register(username: 'kongo', password: 'abcd');
    expect(
      () => auth.register(username: 'Kongo', password: 'efgh'),
      throwsA(isA<StateError>()),
    );
  });

  test('leaderboard stores real player scores without fake seeds', () async {
    final auth = AuthService.instance;
    final board = LeaderboardService.instance;
    await auth.register(username: 'suikaace', password: 'pass1');
    await board.onAuthChanged();

    final ok = await board.submitScore(LeaderboardService.modeSuika, 1500);
    expect(ok, isTrue);
    expect(board.getBest(LeaderboardService.modeSuika), 1500);

    final top = board.getTop(LeaderboardService.modeSuika);
    expect(top, isNotEmpty);
    expect(top.every((e) => e.playerId.isNotEmpty), isTrue);
    expect(
      top.any((e) => e.playerName == 'KongoReis'),
      isFalse,
    );
    expect(top.first.isLocalPlayer, isTrue);
  });

  test('scores stay bound to player across switch', () async {
    final auth = AuthService.instance;
    final board = LeaderboardService.instance;

    await auth.register(username: 'player_a', password: 'pass1');
    await board.onAuthChanged();
    await board.submitScore(LeaderboardService.mode2048, 2000);
    final idA = auth.playerId;

    await auth.signOut();
    await auth.register(username: 'player_b', password: 'pass2');
    await board.onAuthChanged();
    await board.submitScore(LeaderboardService.mode2048, 500);

    final top = board.getTop(LeaderboardService.mode2048);
    expect(top.length, greaterThanOrEqualTo(2));
    expect(top.first.score, 2000);
    expect(top.first.playerId, idA);
    expect(board.getBest(LeaderboardService.mode2048), 500);
  });
}
