import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

/// ThemeProvider — Manages app theme based on accessibility settings
/// Extends ChangeNotifier to rebuild the entire app when theme changes
class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._();
  late SharedPreferences _prefs;

  // Preference keys
  static const String _keyDarkMode = 'theme_dark_mode';
  static const String _keyHighContrast = 'theme_high_contrast';
  static const String _keyColorBlindMode = 'theme_color_blind_mode';
  static const String _keyTextScaling = 'theme_text_scaling';

  // Current state
  bool _isDarkMode = false;
  bool _isHighContrast = false;
  bool _isColorBlindMode = false;
  double _textScaling = 1.0;

  ThemeProvider._();

  static ThemeProvider get instance => _instance;

  /// Initialize theme provider
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromStorage();
    debugPrint('✅ ThemeProvider initialized');
    debugPrint('   Dark Mode: $_isDarkMode');
    debugPrint('   High Contrast: $_isHighContrast');
    debugPrint('   Color Blind: $_isColorBlindMode');
    debugPrint('   Text Scale: $_textScaling');
  }

  /// Load settings from shared preferences
  void _loadFromStorage() {
    _isDarkMode = _prefs.getBool(_keyDarkMode) ?? false;
    _isHighContrast = _prefs.getBool(_keyHighContrast) ?? false;
    _isColorBlindMode = _prefs.getBool(_keyColorBlindMode) ?? false;
    _textScaling = _prefs.getDouble(_keyTextScaling) ?? 1.0;
  }

  // ── Getters ────────────────────────────────────────────────────────

  bool get isDarkMode => _isDarkMode;
  bool get isHighContrast => _isHighContrast;
  bool get isColorBlindMode => _isColorBlindMode;
  double get textScaling => _textScaling;

  /// Get the current theme based on all settings
  ThemeData get currentTheme {
    debugPrint('═══ THEME UPDATE ═══');
    debugPrint('Dark Mode: $_isDarkMode | High Contrast: $_isHighContrast | Color Blind: $_isColorBlindMode | Text Scale: $_textScaling');
    
    if (_isDarkMode) {
      debugPrint('Generating darkTheme...');
      return AppTheme.darkTheme(
        textScale: _textScaling,
        isHighContrast: _isHighContrast,
        isColorBlind: _isColorBlindMode,
      );
    } else {
      debugPrint('Generating lightTheme...');
      return AppTheme.lightTheme(
        textScale: _textScaling,
        isHighContrast: _isHighContrast,
        isColorBlind: _isColorBlindMode,
      );
    }
  }

  // ── Setters with persistence ───────────────────────────────────────

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    debugPrint('🌙 Setting Dark Mode: $value');
    _isDarkMode = value;
    await _prefs.setBool(_keyDarkMode, value);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    if (_isHighContrast == value) {
      debugPrint('⚠️ High Contrast already set to $value, skipping');
      return;
    }
    debugPrint('◼️ Setting High Contrast: $value');
    _isHighContrast = value;
    await _prefs.setBool(_keyHighContrast, value);
    debugPrint('✅ High Contrast saved, calling notifyListeners()');
    notifyListeners();
  }

  Future<void> setColorBlindMode(bool value) async {
    if (_isColorBlindMode == value) {
      debugPrint('⚠️ Color Blind Mode already set to $value, skipping');
      return;
    }
    debugPrint('🎨 Setting Color Blind Mode: $value');
    _isColorBlindMode = value;
    await _prefs.setBool(_keyColorBlindMode, value);
    debugPrint('✅ Color Blind Mode saved, calling notifyListeners()');
    notifyListeners();
  }

  Future<void> setTextScaling(double value) async {
    final validValue = value.clamp(1.0, 2.0);
    if ((_textScaling - validValue).abs() < 0.01) return;
    debugPrint('📝 Setting Text Scale: ${(validValue * 100).toInt()}%');
    _textScaling = validValue;
    await _prefs.setDouble(_keyTextScaling, validValue);
    notifyListeners();
  }

  /// Get all settings as a map (useful for debugging)
  Map<String, dynamic> getSettings() {
    return {
      'darkMode': _isDarkMode,
      'highContrast': _isHighContrast,
      'colorBlindMode': _isColorBlindMode,
      'textScaling': _textScaling,
    };
  }
}
