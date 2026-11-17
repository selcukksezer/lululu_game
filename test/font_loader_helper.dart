import 'dart:io';
import 'package:flutter/services.dart';

Future<void> loadTestFonts() async {
  // 1. Material Icons
  final matFile = File('test/assets/fonts/MaterialIcons-Regular.otf');
  if (matFile.existsSync()) {
    final bytes = await matFile.readAsBytes();
    final loader = FontLoader('MaterialIcons');
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  // 2. Baloo 2
  final balooFile = File('test/assets/fonts/Baloo2.ttf');
  if (balooFile.existsSync()) {
    final bytes = await balooFile.readAsBytes();
    for (final name in [
      'Baloo 2',
      'Baloo2',
      'Baloo2_regular',
      'Baloo2_bold',
      'Baloo2_semiBold',
      'Baloo2_extraBold',
      'Baloo2_medium',
    ]) {
      final loader = FontLoader(name);
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  }

  // 3. Nunito
  final nunitoFile = File('test/assets/fonts/Nunito.ttf');
  if (nunitoFile.existsSync()) {
    final bytes = await nunitoFile.readAsBytes();
    for (final name in [
      'Nunito',
      'Nunito_regular',
      'Nunito_bold',
      'Nunito_semiBold',
      'Nunito_extraBold',
      'Nunito_medium',
    ]) {
      final loader = FontLoader(name);
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  }
}
