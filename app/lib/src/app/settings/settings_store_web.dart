import 'settings.dart';

/// Browser sessions intentionally start from the same clean demo state.
class KolkhozAppSettingsStore {
  KolkhozAppSettingsStore();

  KolkhozAppSettings _settings = const KolkhozAppSettings(
    language: KolkhozLanguage.en,
  );

  static KolkhozAppSettingsStore defaultStore() => KolkhozAppSettingsStore();

  KolkhozAppSettings load() => _settings;

  void save(KolkhozAppSettings settings) {
    _settings = settings;
  }
}
