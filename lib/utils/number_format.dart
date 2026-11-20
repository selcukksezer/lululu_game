/// Dile duyarlı sayı biçimlendirme (Dalga 12A).
///
/// Uygulama yalnızca TR ve EN destekler; binlik ayırıcı TR'de `.`,
/// EN'de `,` olur (Selçuk kararı: EN'de 1,240). Ondalık ayırıcı
/// TR'de `,`, EN'de `.` olur. `intl` bağımlılığı yoktur; bu yardımcı
/// 12A kapsamında dokunulan dosyalardaki `_formatNumber` /
/// `_formatDotNumber` / `_formatScore` / `_fmt` kopyalarının yerini
/// alır (grid_2048_screen, arcade_chrome ve vault_top_hud içindeki
/// aynı desenli kopyalar 14A'da çevrildi).
library;

/// Tam sayıyı dile göre gruplandırır: TR `1.240`, EN `1,240`.
String formatGroupedInt(int value, String languageCode) {
  final separator = languageCode == 'tr' ? '.' : ',';
  final negative = value < 0;
  final digits = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buf.write(separator);
    }
    buf.write(digits[i]);
  }
  final grouped = buf.toString();
  return negative ? '-$grouped' : grouped;
}

/// Ondalıklı sayıyı dile göre biçimlendirir: TR `1,21`, EN `1.21`.
/// [fractionDigits] basamak sayısı `toStringAsFixed` ile aynıdır.
String formatDecimal(double value, int fractionDigits, String languageCode) {
  final separator = languageCode == 'tr' ? ',' : '.';
  final fixed = value.toStringAsFixed(fractionDigits);
  return fixed.replaceFirst('.', separator);
}
