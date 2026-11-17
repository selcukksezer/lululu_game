// Ölü kod kaldırıldı (Dalga 15, ajan W15-3, 2026-11-18):
// `showRewardedAdMock` tanımı ile yalnızca onun kullandığı özel
// yardımcılar (`_AdMockOverlay`, `_AdMockOverlayState`) silindi.
// Gerekçe (grep kanıtlı): repo genelinde (lib/ + test/) 0 çağrıcı ve
// bu dosyayı import eden 0 dosya. Ödüllü reklam SDK'sı kurulu değil ve
// sahte (mock) reklamla ödül verilmez — bu mock yeniden
// canlandırılmamalıdır. Gerçek ödüllü reklam geldiğinde gerçek SDK'ya
// karşı yeni bir yerde uygulanmalıdır.
// Dosya bilerek silinmedi: içinde yalnızca bu açıklama bırakıldı.
