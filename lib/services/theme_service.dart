import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themeKey = "theme_mode_setting";
  AppThemeMode _currentMode = AppThemeMode.system;

  AppThemeMode get modeSetting => _currentMode;

  ThemeMode get themeMode {
    switch (_currentMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  bool get isDarkMode {
    if (_currentMode == AppThemeMode.system) {
      return SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _currentMode == AppThemeMode.dark;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeKey);
    
    if (savedMode == null) {
      _currentMode = AppThemeMode.system;
    } else {
      _currentMode = AppThemeMode.values.firstWhere(
        (e) => e.toString() == savedMode,
        orElse: () => AppThemeMode.system,
      );
    }
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _currentMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
    notifyListeners();
  }

  // Legacy support for toggle (if still used)
  Future<void> toggleTheme() async {
    if (isDarkMode) {
      await setThemeMode(AppThemeMode.light);
    } else {
      await setThemeMode(AppThemeMode.dark);
    }
  }
}
