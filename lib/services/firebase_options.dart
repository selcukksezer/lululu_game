import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// FlutterFire options. Fill via `--dart-define` or replace placeholders
/// after `flutterfire configure`.
///
/// Defines (optional):
/// `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`,
/// `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_IOS_CLIENT_ID`,
/// `FIREBASE_IOS_BUNDLE_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_DATABASE_URL`
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _databaseUrl = String.fromEnvironment('FIREBASE_DATABASE_URL');
  static const _iosClientId =
      String.fromEnvironment('FIREBASE_IOS_CLIENT_ID');
  static const _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.lululu.game.lululuGame',
  );

  static bool? _overrideConfigured;

  /// True when required dart-defines (or runtime override) are present.
  static bool get isConfigured =>
      _overrideConfigured ??
      (_apiKey.isNotEmpty &&
          _appId.isNotEmpty &&
          _messagingSenderId.isNotEmpty &&
          _projectId.isNotEmpty);

  /// Alias for [isConfigured] used by cloud-ready services.
  static bool get isAvailable => isConfigured;

  /// Optional test/runtime hook to override configuration detection.
  static void setConfiguredOverride(bool? value) {
    _overrideConfigured = value;
  }

  static String get projectId =>
      _projectId.isNotEmpty ? _projectId : 'lululu-offline-local';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _apiKey.isNotEmpty ? _apiKey : 'AIzaSyLocalFallbackKey000000000000',
        appId: _appId.isNotEmpty ? _appId : '1:000000000000:web:localfallback',
        messagingSenderId:
            _messagingSenderId.isNotEmpty ? _messagingSenderId : '000000000000',
        projectId: projectId,
        authDomain: _authDomain.isEmpty ? null : _authDomain,
        databaseURL: _databaseUrl.isEmpty ? null : _databaseUrl,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _apiKey.isNotEmpty ? _apiKey : 'AIzaSyLocalFallbackKey000000000000',
        appId:
            _appId.isNotEmpty ? _appId : '1:000000000000:android:localfallback',
        messagingSenderId:
            _messagingSenderId.isNotEmpty ? _messagingSenderId : '000000000000',
        projectId: projectId,
        databaseURL: _databaseUrl.isEmpty ? null : _databaseUrl,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: _apiKey.isNotEmpty ? _apiKey : 'AIzaSyLocalFallbackKey000000000000',
        appId: _appId.isNotEmpty ? _appId : '1:000000000000:ios:localfallback',
        messagingSenderId:
            _messagingSenderId.isNotEmpty ? _messagingSenderId : '000000000000',
        projectId: projectId,
        databaseURL: _databaseUrl.isEmpty ? null : _databaseUrl,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        iosClientId: _iosClientId.isEmpty ? null : _iosClientId,
        iosBundleId: _iosBundleId,
      );

  static FirebaseOptions get macos => ios;
}
