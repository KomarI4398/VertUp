import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  String _currentTheme = 'dark_cyber';
  String _currentLanguage = 'ru';
  
  String get currentTheme => _currentTheme;
  String get currentLanguage => _currentLanguage;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _currentTheme = prefs.getString('theme_key') ?? 'dark_cyber';
    _currentLanguage = prefs.getString('lang_key') ?? 'ru';
    notifyListeners();
  }

  Future<void> setTheme(String themeName) async {
    _currentTheme = themeName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_key', themeName);
  }

  Future<void> setLanguage(String langCode) async {
    _currentLanguage = langCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang_key', langCode);
  }

  String translate(String keyRu, String keyEn) {
    return _currentLanguage == 'ru' ? keyRu : keyEn;
  }
}