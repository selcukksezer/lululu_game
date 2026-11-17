import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Tekil bir frame çizim süresini (build + raster) ve jank durumunu temsil eder.
@immutable
class FrameTimingSample {
  const FrameTimingSample({
    required this.buildDuration,
    required this.rasterDuration,
    required this.timestamp,
  });

  final Duration buildDuration;
  final Duration rasterDuration;
  final DateTime timestamp;

  /// Toplam frame işleme süresi (`buildDuration + rasterDuration`).
  Duration get totalDuration => buildDuration + rasterDuration;

  /// Milisaniye cinsinden build süresi.
  double get buildMs => buildDuration.inMicroseconds / 1000.0;

  /// Milisaniye cinsinden raster süresi.
  double get rasterMs => rasterDuration.inMicroseconds / 1000.0;

  /// Milisaniye cinsinden toplam frame süresi.
  double get totalMs => totalDuration.inMicroseconds / 1000.0;

  /// 120Hz (8.33ms = 8333µs) bütçesini aşan frame olup olmadığı.
  bool get isJank120Hz =>
      totalDuration.inMicroseconds >
      GameTelemetryService.jankThreshold120HzMicroseconds;

  /// 60Hz (16.67ms = 16667µs) bütçesini aşan frame olup olmadığı.
  bool get isJank60Hz =>
      totalDuration.inMicroseconds >
      GameTelemetryService.jankThreshold60HzMicroseconds;

  Map<String, Object?> toJson() => <String, Object?>{
        'buildMs': double.parse(buildMs.toStringAsFixed(3)),
        'rasterMs': double.parse(rasterMs.toStringAsFixed(3)),
        'totalMs': double.parse(totalMs.toStringAsFixed(3)),
        'isJank120Hz': isJank120Hz,
        'isJank60Hz': isJank60Hz,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };
}

/// Oyun içi kritik olay izi (crash / tanı breadcrumb kaydı).
@immutable
class TelemetryBreadcrumb {
  const TelemetryBreadcrumb({
    required this.category,
    required this.action,
    required this.timestamp,
    this.meta = const <String, Object?>{},
  });

  final String category;
  final String action;
  final DateTime timestamp;
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => <String, Object?>{
        'category': category,
        'action': action,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (meta.isNotEmpty) 'meta': meta,
      };

  @override
  String toString() =>
      'TelemetryBreadcrumb(category: $category, action: $action, meta: $meta)';
}

/// Sabit boyutlu dairesel tampon (Ring Buffer).
///
/// Kapasite (`capacity`) dolduğunda en eski kaydın üzerine yazar; böylece
/// uzun oyun oturumlarında bellek sızıntısı (memory leak) oluşmasını engeller.
class _FixedRingBuffer<T> {
  _FixedRingBuffer(this.capacity)
      : assert(capacity > 0, 'Ring buffer capacity must be positive'),
        _slots = List<T?>.filled(capacity, null, growable: false);

  final int capacity;
  final List<T?> _slots;
  int _writeIndex = 0;
  int _length = 0;

  int get length => _length;
  bool get isEmpty => _length == 0;
  bool get isFull => _length == capacity;

  void add(T item) {
    _slots[_writeIndex] = item;
    _writeIndex = (_writeIndex + 1) % capacity;
    if (_length < capacity) {
      _length++;
    }
  }

  void clear() {
    for (var i = 0; i < capacity; i++) {
      _slots[i] = null;
    }
    _writeIndex = 0;
    _length = 0;
  }

  /// Kayıtları kronolojik sırayla (en eskiden en yeniye) döndürür.
  List<T> toList() {
    if (_length == 0) return const <Never>[];
    final result = <T>[];
    final start = _length < capacity ? 0 : _writeIndex;
    for (var i = 0; i < _length; i++) {
      final idx = (start + i) % capacity;
      final item = _slots[idx];
      if (item != null) {
        result.add(item);
      }
    }
    return List<T>.unmodifiable(result);
  }
}

/// 120FPS Performans İzleme, Jank Dedektörü ve Çökme Breadcrumb Servisi.
///
/// Sorumluluklar:
/// 1. Sabit boyutlu dairesel tampon (`maxRingBufferSize = 200`) kullanarak
///    frame sürelerini (`buildDuration`, `rasterDuration`) bellek sızıntısı
///    yapmadan kaydeder.
/// 2. Ortalama FPS, ortalama frame süresi, P95/P99 frame süresi ve
///    `> 16.67ms` (60Hz) / `> 8.33ms` (120Hz) jank sayaçlarını hesaplar.
/// 3. Mod başlatma, mağaza satın alımı, güçlendirici kullanımı ve yakalanan
///    hatalar için kritik olay izlerini (`recordBreadcrumb`) dairesel tamponda
///    tutar.
/// 4. Tanılama ve çökme raporlaması için `exportDiagnosticsSummary()` sunar.
class GameTelemetryService extends ChangeNotifier {
  GameTelemetryService._internal({int maxBufferSize = maxRingBufferSize})
      : maxCapacity = maxBufferSize.clamp(1, maxRingBufferSize),
        _frameBuffer =
            _FixedRingBuffer<FrameTimingSample>(maxBufferSize.clamp(1, maxRingBufferSize)),
        _breadcrumbBuffer =
            _FixedRingBuffer<TelemetryBreadcrumb>(maxBufferSize.clamp(1, maxRingBufferSize));

  /// Özel kapasiteli test örneği oluşturur (maksimum 200 kayıt ile sınırlandırılır).
  factory GameTelemetryService({int maxBufferSize = maxRingBufferSize}) {
    if (maxBufferSize == maxRingBufferSize) {
      return instance;
    }
    return GameTelemetryService._internal(maxBufferSize: maxBufferSize);
  }

  static final GameTelemetryService instance = GameTelemetryService._internal();

  /// Dairesel tampon üst sınırı (maksimum 200 kayıt — bellek sızıntısı yapmaz).
  static const int maxRingBufferSize = 200;

  /// 120Hz frame bütçesi eşiği: 8.33ms (8333 mikrosaniye).
  static const double jankThreshold120HzMs = 8.33;
  static const int jankThreshold120HzMicroseconds = 8333;

  /// 60Hz frame bütçesi eşiği: 16.67ms (16667 mikrosaniye).
  static const double jankThreshold60HzMs = 16.67;
  static const int jankThreshold60HzMicroseconds = 16667;

  /// Hedef tavan FPS değeri.
  static const double targetMaxFps = 120.0;

  final int maxCapacity;
  final _FixedRingBuffer<FrameTimingSample> _frameBuffer;
  final _FixedRingBuffer<TelemetryBreadcrumb> _breadcrumbBuffer;

  int _totalFramesRecorded = 0;
  int _totalJank120HzCount = 0;
  int _totalJank60HzCount = 0;
  int _totalBreadcrumbsRecorded = 0;
  bool _schedulerAttached = false;

  /// Oturum başlangıcından itibaren kaydedilen toplam frame sayısı.
  int get totalFramesRecorded => _totalFramesRecorded;

  /// Dairesel tamponda şu an tutulan frame örneği sayısı (`<= 200`).
  int get bufferedFrameCount => _frameBuffer.length;

  /// Dairesel tamponda şu an tutulan breadcrumb sayısı (`<= 200`).
  int get bufferedBreadcrumbCount => _breadcrumbBuffer.length;

  /// Oturum boyunca kaydedilen toplam breadcrumb sayısı.
  int get totalBreadcrumbsRecorded => _totalBreadcrumbsRecorded;

  /// `> 8.33ms` (120Hz bütçesi aşımı) toplam jank sayısı.
  int get jankCount120Hz => _totalJank120HzCount;

  /// `> 16.67ms` (60Hz bütçesi aşımı) toplam jank sayısı.
  int get jankCount60Hz => _totalJank60HzCount;

  /// `jankCount60Hz` için kısa alias (`> 16.67ms` ağır jank sayacı).
  int get jankCount => _totalJank60HzCount;

  /// Tampondaki mevcut örnekler içindeki `> 8.33ms` jank sayısı.
  int get bufferedJankCount120Hz =>
      _frameBuffer.toList().where((s) => s.isJank120Hz).length;

  /// Tampondaki mevcut örnekler içindeki `> 16.67ms` jank sayısı.
  int get bufferedJankCount60Hz =>
      _frameBuffer.toList().where((s) => s.isJank60Hz).length;

  /// Kronolojik frame örnekleri (en eskiden en yeniye, en fazla [maxCapacity] kayıt).
  List<FrameTimingSample> get frameSamples => _frameBuffer.toList();

  /// Kronolojik olay izleri (en eskiden en yeniye, en fazla [maxCapacity] kayıt).
  List<TelemetryBreadcrumb> get breadcrumbs => _breadcrumbBuffer.toList();

  /// Tekil bir frame'in build ve raster süresini kaydeder.
  void recordFrameTiming(
    Duration buildDuration,
    Duration rasterDuration, {
    DateTime? timestamp,
  }) {
    final safeBuild =
        buildDuration.isNegative ? Duration.zero : buildDuration;
    final safeRaster =
        rasterDuration.isNegative ? Duration.zero : rasterDuration;

    final sample = FrameTimingSample(
      buildDuration: safeBuild,
      rasterDuration: safeRaster,
      timestamp: timestamp ?? DateTime.now(),
    );

    _frameBuffer.add(sample);
    _totalFramesRecorded++;

    if (sample.isJank120Hz) {
      _totalJank120HzCount++;
    }
    if (sample.isJank60Hz) {
      _totalJank60HzCount++;
    }
  }

  /// Flutter `SchedulerBinding` üzerinden gelen [FrameTiming] listesini işler.
  void recordSchedulerFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      recordFrameTiming(timing.buildDuration, timing.rasterDuration);
    }
  }

  /// `SchedulerBinding.instance` frame timing dinleyicisini etkinleştirir.
  void attachSchedulerListener() {
    if (_schedulerAttached) return;
    try {
      SchedulerBinding.instance.addTimingsCallback(recordSchedulerFrameTimings);
      _schedulerAttached = true;
    } catch (_) {
      // Widget binding henüz başlatılmamışsa güvenli şekilde yoksay.
    }
  }

  /// `SchedulerBinding.instance` frame timing dinleyicisini kaldırır.
  void detachSchedulerListener() {
    if (!_schedulerAttached) return;
    try {
      SchedulerBinding.instance.removeTimingsCallback(
        recordSchedulerFrameTimings,
      );
    } catch (_) {}
    _schedulerAttached = false;
  }

  /// Tampondaki örneklerin ortalama toplam frame süresi (ms).
  double get averageFrameTimeMs {
    final samples = _frameBuffer.toList();
    if (samples.isEmpty) return 0.0;
    var totalMicros = 0;
    for (final s in samples) {
      totalMicros += s.totalDuration.inMicroseconds;
    }
    return (totalMicros / samples.length) / 1000.0;
  }

  /// Tampondaki örneklerin ortalama build süresi (ms).
  double get averageBuildTimeMs {
    final samples = _frameBuffer.toList();
    if (samples.isEmpty) return 0.0;
    var totalMicros = 0;
    for (final s in samples) {
      totalMicros += s.buildDuration.inMicroseconds;
    }
    return (totalMicros / samples.length) / 1000.0;
  }

  /// Tampondaki örneklerin ortalama raster süresi (ms).
  double get averageRasterTimeMs {
    final samples = _frameBuffer.toList();
    if (samples.isEmpty) return 0.0;
    var totalMicros = 0;
    for (final s in samples) {
      totalMicros += s.rasterDuration.inMicroseconds;
    }
    return (totalMicros / samples.length) / 1000.0;
  }

  /// Ortalama FPS değeri (`0.0 .. 120.0` aralığında kırpılmış).
  ///
  /// Henüz örnek yoksa varsayılan olarak [targetMaxFps] (`120.0`) döner.
  double get averageFps {
    final avgMs = averageFrameTimeMs;
    if (avgMs <= 0.0) return targetMaxFps;
    final rawFps = 1000.0 / avgMs;
    return rawFps.clamp(0.0, targetMaxFps);
  }

  /// Belirtilen yüzdelik dilimdeki (`0.0 .. 1.0`, örn. `0.99`) frame süresini (ms) hesaplar.
  double percentileFrameTimeMs(double percentile) {
    final samples = _frameBuffer.toList();
    if (samples.isEmpty) return 0.0;
    final clampedP = percentile.clamp(0.0, 1.0);
    final sortedMicros = samples
        .map((s) => s.totalDuration.inMicroseconds)
        .toList()
      ..sort();
    final rawIndex = (clampedP * sortedMicros.length).ceil() - 1;
    final idx = rawIndex.clamp(0, sortedMicros.length - 1);
    return sortedMicros[idx] / 1000.0;
  }

  /// `%95` (P95) frame süresi (ms).
  double get p95FrameTimeMs => percentileFrameTimeMs(0.95);

  /// `%99` (P99) frame süresi (ms).
  double get p99FrameTimeMs => percentileFrameTimeMs(0.99);

  /// `%99` (P99) frame süresi ([Duration] olarak).
  Duration get p99FrameDuration =>
      Duration(microseconds: (p99FrameTimeMs * 1000).round());

  /// 60Hz (`> 16.67ms`) jank oranı (`0.0 .. 1.0`).
  double get jankRatio60Hz {
    if (_totalFramesRecorded <= 0) return 0.0;
    return (_totalJank60HzCount / _totalFramesRecorded).clamp(0.0, 1.0);
  }

  /// 120Hz (`> 8.33ms`) jank oranı (`0.0 .. 1.0`).
  double get jankRatio120Hz {
    if (_totalFramesRecorded <= 0) return 0.0;
    return (_totalJank120HzCount / _totalFramesRecorded).clamp(0.0, 1.0);
  }

  /// Oyun içi kritik olay izi (breadcrumb) kaydeder.
  ///
  /// Kategori ve aksiyon adlarındaki kontrol karakterlerini temizler,
  /// `meta` haritasını güvenli şekilde kopyalar ve 200 kayıtlık dairesel
  /// tamponda saklar.
  void recordBreadcrumb(
    String category,
    String action, {
    Map<String, Object?>? meta,
    DateTime? timestamp,
  }) {
    final cleanCategory = _sanitizeToken(category, fallback: 'general');
    final cleanAction = _sanitizeToken(action, fallback: 'event');

    final sanitizedMeta = <String, Object?>{};
    if (meta != null && meta.isNotEmpty) {
      var entryCount = 0;
      for (final entry in meta.entries) {
        if (entryCount >= 24) break;
        final key = _sanitizeToken(entry.key, fallback: 'key_$entryCount');
        sanitizedMeta[key] = _sanitizeMetaValue(entry.value);
        entryCount++;
      }
    }

    final crumb = TelemetryBreadcrumb(
      category: cleanCategory,
      action: cleanAction,
      timestamp: timestamp ?? DateTime.now(),
      meta: Map<String, Object?>.unmodifiable(sanitizedMeta),
    );

    _breadcrumbBuffer.add(crumb);
    _totalBreadcrumbsRecorded++;
    notifyListeners();
  }

  /// Oyun modu başlatma olayını kaydeder.
  void recordModeStart(
    String modeId, {
    int? levelId,
    Map<String, Object?>? meta,
  }) {
    recordBreadcrumb(
      'mode',
      'start',
      meta: <String, Object?>{
        'modeId': modeId,
        'levelId': ?levelId,
        ...?meta,
      },
    );
  }

  /// Mağaza satın alma işlemini kaydeder.
  void recordPurchase(
    String itemId, {
    required int cost,
    String currency = 'coins',
    bool success = true,
    Map<String, Object?>? meta,
  }) {
    recordBreadcrumb(
      'shop',
      success ? 'purchase_success' : 'purchase_failed',
      meta: <String, Object?>{
        'itemId': itemId,
        'cost': cost,
        'currency': currency,
        'success': success,
        ...?meta,
      },
    );
  }

  /// Güçlendirici kullanımını kaydeder.
  void recordBoosterUse(
    String boosterKey, {
    String? modeId,
    int? remainingCount,
    Map<String, Object?>? meta,
  }) {
    recordBreadcrumb(
      'booster',
      'use',
      meta: <String, Object?>{
        'booster': boosterKey,
        'modeId': ?modeId,
        'remaining': ?remainingCount,
        ...?meta,
      },
    );
  }

  /// Yakalanan hata veya çökme izini kaydeder.
  void recordError(
    Object error, {
    StackTrace? stackTrace,
    String category = 'error',
    String action = 'caught_exception',
    Map<String, Object?>? meta,
  }) {
    final stackPreview = stackTrace
        ?.toString()
        .split('\n')
        .take(5)
        .join(' | ');
    recordBreadcrumb(
      category,
      action,
      meta: <String, Object?>{
        'error': error.toString(),
        if (stackPreview != null && stackPreview.isNotEmpty)
          'stack': stackPreview,
        ...?meta,
      },
    );
  }

  /// Tanılama ve performans özet raporunu dışa aktarır.
  Map<String, Object?> exportDiagnosticsSummary() {
    final crumbs = _breadcrumbBuffer.toList();
    final errorCount =
        crumbs.where((c) => c.category == 'error' || c.category == 'crash').length;

    return <String, Object?>{
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'ringBufferCapacity': maxCapacity,
      'frames': <String, Object?>{
        'bufferedCount': bufferedFrameCount,
        'totalRecorded': _totalFramesRecorded,
        'averageFps': double.parse(averageFps.toStringAsFixed(2)),
        'averageFrameTimeMs':
            double.parse(averageFrameTimeMs.toStringAsFixed(3)),
        'averageBuildTimeMs':
            double.parse(averageBuildTimeMs.toStringAsFixed(3)),
        'averageRasterTimeMs':
            double.parse(averageRasterTimeMs.toStringAsFixed(3)),
        'p95FrameTimeMs': double.parse(p95FrameTimeMs.toStringAsFixed(3)),
        'p99FrameTimeMs': double.parse(p99FrameTimeMs.toStringAsFixed(3)),
        'jankCount60Hz': _totalJank60HzCount,
        'jankCount120Hz': _totalJank120HzCount,
        'bufferedJankCount60Hz': bufferedJankCount60Hz,
        'bufferedJankCount120Hz': bufferedJankCount120Hz,
        'jankRatio60Hz': double.parse(jankRatio60Hz.toStringAsFixed(4)),
        'jankRatio120Hz': double.parse(jankRatio120Hz.toStringAsFixed(4)),
      },
      'breadcrumbs': <String, Object?>{
        'bufferedCount': bufferedBreadcrumbCount,
        'totalRecorded': _totalBreadcrumbsRecorded,
        'errorCount': errorCount,
        'items': crumbs.map((c) => c.toJson()).toList(growable: false),
      },
    };
  }

  /// Tanılama raporunu JSON metni olarak dışa aktarır.
  String exportDiagnosticsJson() => jsonEncode(exportDiagnosticsSummary());

  /// Tüm frame ve breadcrumb tamponlarını, sayaçları sıfırlar.
  void reset() {
    _frameBuffer.clear();
    _breadcrumbBuffer.clear();
    _totalFramesRecorded = 0;
    _totalJank120HzCount = 0;
    _totalJank60HzCount = 0;
    _totalBreadcrumbsRecorded = 0;
    notifyListeners();
  }

  static String _sanitizeToken(String raw, {required String fallback}) {
    final cleaned = raw
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    if (cleaned.isEmpty) return fallback;
    return cleaned.length > 64 ? cleaned.substring(0, 64) : cleaned;
  }

  static Object? _sanitizeMetaValue(Object? value) {
    if (value == null || value is bool || value is int) return value;
    if (value is double) {
      if (value.isNaN || value.isInfinite) return 0.0;
      return value;
    }
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
      return cleaned.length > 256
          ? cleaned.substring(0, math.min(256, cleaned.length))
          : cleaned;
    }
    if (value is Iterable) {
      return value.take(20).map(_sanitizeMetaValue).toList(growable: false);
    }
    if (value is Map) {
      final result = <String, Object?>{};
      for (final entry in value.entries.take(20)) {
        result[entry.key.toString()] = _sanitizeMetaValue(entry.value);
      }
      return result;
    }
    return value.toString();
  }
}
