import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  ThemeMode get themeMode => ThemeMode.system;

  bool get isDarkMode {
    return SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  Future<void> init() async {
    // No longer need to load from SharedPreferences as we follow system
    // notifyListeners() removed to prevent build-time exceptions
  }
}
