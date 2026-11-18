# Audio assets — pubspec not edited

`pubspec.yaml` was left untouched (font work owns that file).
`assets/audio/` is already a directory asset entry, so these files are bundled by that entry.
If a later pubspec rewrite drops the directory, add the paths below explicitly.

- assets/audio/mezarina_siktigim.mp3
- assets/audio/diva_sinyal.mp3
- assets/audio/diva_yasla.mp3
- assets/audio/lululu_nakarat.mp3
- assets/audio/duktur.mp3
- assets/audio/kanka.mp3
- assets/audio/husur_aday.mp3

`GameAudio.allAssets` also lists these names. `test/asset_integrity_test.dart` requires every name in both `assets/audio/` and `assets/design/sounds/`. Identical copies live here:

- assets/design/sounds/mezarina_siktigim.mp3
- assets/design/sounds/diva_sinyal.mp3
- assets/design/sounds/diva_yasla.mp3
- assets/design/sounds/lululu_nakarat.mp3
- assets/design/sounds/duktur.mp3
- assets/design/sounds/kanka.mp3
- assets/design/sounds/husur_aday.mp3

`assets/design/sounds/` is already a directory asset entry. No pubspec line was added.
