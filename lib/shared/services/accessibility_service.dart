import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Accessibility Service - Manages theme preferences with reactive updates
class AccessibilityService extends ChangeNotifier {
  static final AccessibilityService _instance = AccessibilityService._();
  late SharedPreferences _prefs;
  bool _initialized = false;

  // Preference keys
  static const String _keyDarkMode = 'accessibility_dark_mode';
  static const String _keyHighContrast = 'accessibility_high_contrast';
  static const String _keyColorBlindMode = 'accessibility_color_blind_mode';
  static const String _keyTextScaling = 'accessibility_text_scaling';

  // Current values (cached)
  bool _darkModeEnabled = false;
  bool _highContrastEnabled = false;
  bool _colorBlindModeEnabled = false;
  double _textScaling = 1.0;

  AccessibilityService._();

  static AccessibilityService get instance => _instance;

  /// Initialize the accessibility service (should be called at app start)
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs();
    _initialized = true;
  }

  /// Load all preferences from storage
  void _loadFromPrefs() {
    _darkModeEnabled = _prefs.getBool(_keyDarkMode) ?? false;
    _highContrastEnabled = _prefs.getBool(_keyHighContrast) ?? false;
    _colorBlindModeEnabled = _prefs.getBool(_keyColorBlindMode) ?? false;
    _textScaling = _prefs.getDouble(_keyTextScaling) ?? 1.0;
  }

  // ── Dark Mode ──────────────────────────────────────────────────────

  bool get isDarkModeEnabled => _darkModeEnabled;

  Future<void> setDarkMode(bool enabled) async {
    if (_darkModeEnabled == enabled) return;
    _darkModeEnabled = enabled;
    await _prefs.setBool(_keyDarkMode, enabled);
    notifyListeners();
  }

  // ── High Contrast Mode ─────────────────────────────────────────────

  bool get isHighContrastEnabled => _highContrastEnabled;

  Future<void> setHighContrast(bool enabled) async {
    if (_highContrastEnabled == enabled) return;
    _highContrastEnabled = enabled;
    await _prefs.setBool(_keyHighContrast, enabled);
    notifyListeners();
  }

  // ── Color Blind Mode ───────────────────────────────────────────────

  bool get isColorBlindModeEnabled => _colorBlindModeEnabled;

  Future<void> setColorBlindMode(bool enabled) async {
    if (_colorBlindModeEnabled == enabled) return;
    _colorBlindModeEnabled = enabled;
    await _prefs.setBool(_keyColorBlindMode, enabled);
    notifyListeners();
  }

  // ── Text Scaling ───────────────────────────────────────────────────

  double get textScaling => _textScaling;

  Future<void> setTextScaling(double scale) async {
    final validScale = scale.clamp(1.0, 2.0);
    if ((_textScaling - validScale).abs() < 0.01) return;
    _textScaling = validScale;
    await _prefs.setDouble(_keyTextScaling, validScale);
    notifyListeners();
  }

  // ── Batch get current preferences ──────────────────────────────────

  AccessibilityPreferences getCurrentPreferences() {
    return AccessibilityPreferences(
      darkModeEnabled: _darkModeEnabled,
      highContrastEnabled: _highContrastEnabled,
      colorBlindModeEnabled: _colorBlindModeEnabled,
      textScaling: _textScaling,
    );
  }
}

/// Model for accessibility preferences
class AccessibilityPreferences {
  final bool darkModeEnabled;
  final bool highContrastEnabled;
  final bool colorBlindModeEnabled;
  final double textScaling;

  AccessibilityPreferences({
    required this.darkModeEnabled,
    required this.highContrastEnabled,
    required this.colorBlindModeEnabled,
    required this.textScaling,
  });
}
