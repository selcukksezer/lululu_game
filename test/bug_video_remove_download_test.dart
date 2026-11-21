import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/bug_video_service.dart';

// Dalga 3F: kimlikle silme (`removeDownload`) sözleşmesi — indeksle
// silme (`removeDownloadAt`) listeler ayrışınca yanlış kaydı siler;
// kimlikle silme doğru kaydı silmeli, yanlış kimlikte hiçbir şeye
// dokunmamalı ve kalıcılığa (`SharedPreferences`) yansımalıdır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await BugVideoService.instance.load();
  });

  BugDownloadEntry entry(String id) => BugDownloadEntry(
        id: id,
        title: '$id.mp4',
        sizeText: '1,0 MB · Az önce',
        thumbAsset: 'assets/design/ui/studio_downloads/img_1.png',
        isBugIcon: false,
        createdAtMs: 0,
        sizeMb: 1.0,
      );

  test('removeDownload kimlikle doğru kaydı siler, diğerleri kalır',
      () async {
    final service = BugVideoService.instance;
    await service.addDownload(entry('dl_3f_keep'));
    await service.addDownload(entry('dl_3f_drop'));

    final removed = await service.removeDownload('dl_3f_drop');

    expect(removed, isTrue);
    final ids = service.downloads.map((d) => d.id).toSet();
    expect(ids, contains('dl_3f_keep'));
    expect(ids, isNot(contains('dl_3f_drop')));
    // Kalıcılık: prefs'teki arşivde de silinen kimlik yok.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('LululuStudioDownloadsV1') ?? '';
    expect(raw, isNot(contains('dl_3f_drop')));
    expect(raw, contains('dl_3f_keep'));
  });

  test('removeDownload yanlış kimlikte hiçbir şeyi silmez', () async {
    final service = BugVideoService.instance;
    await service.addDownload(entry('dl_3f_stay'));
    final before = service.downloads.map((d) => d.id).toList();

    final removed =
        await service.removeDownload('dl_3f_yok_boyle_bir_kimlik');

    expect(removed, isFalse);
    expect(service.downloads.map((d) => d.id).toList(), before);
  });
}
