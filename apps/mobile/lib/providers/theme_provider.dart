import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import 'app_providers.dart';

final appPaletteProvider =
    StateNotifierProvider<AppPaletteController, AppPalette>((ref) {
  return AppPaletteController(ref.watch(storageProvider));
});

class AppPaletteController extends StateNotifier<AppPalette> {
  AppPaletteController(this._storage) : super(AppPalette.defaultPreset) {
    _restore();
  }

  final StorageService _storage;

  Future<void> _restore() async {
    final id = await _storage.getThemePresetId();
    final preset = AppPalette.byId(id);
    if (preset != null) {
      state = preset;
      AppTheme.applyPalette(preset);
    }
  }

  Future<void> select(String id) async {
    final preset = AppPalette.byId(id);
    if (preset == null) return;
    state = preset;
    AppTheme.applyPalette(preset);
    await _storage.saveThemePresetId(id);
  }
}
