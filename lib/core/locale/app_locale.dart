import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton [ChangeNotifier] that owns the current [Locale].
///
/// Usage:
///   await AppLocaleNotifier.instance.init();   // call once in main()
///   AppLocaleNotifier.instance.toggle();        // flip KO ↔ EN
class AppLocaleNotifier extends ChangeNotifier {
  AppLocaleNotifier._();
  static final AppLocaleNotifier instance = AppLocaleNotifier._();

  static const String _prefKey = 'app_locale';

  Locale _locale = const Locale('ko');
  Locale get locale => _locale;
  bool get isKorean => _locale.languageCode == 'ko';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(_prefKey) ?? 'ko';
    _locale = Locale(lang);
    // no notifyListeners() here — called before runApp
  }

  Future<void> toggle() async {
    _locale = isKorean ? const Locale('en') : const Locale('ko');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _locale.languageCode);
    notifyListeners();
  }
}
