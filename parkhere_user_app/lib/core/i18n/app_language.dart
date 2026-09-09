import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, Locale>((
  ref,
) {
  return AppLanguageNotifier();
});

class AppLanguageNotifier extends StateNotifier<Locale> {
  AppLanguageNotifier() : super(const Locale('pt', 'BR')) {
    _load();
  }

  static const _key = 'app_language';
  Locale _currentLocale = const Locale('pt', 'BR');

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_key);
    if (value == 'en') {
      _setLocale(const Locale('en'));
    }
  }

  Future<void> setLanguage(Locale locale) async {
    final language = locale.languageCode == 'en' ? 'en' : 'pt';
    _setLocale(language == 'en' ? const Locale('en') : const Locale('pt', 'BR'));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, language);
  }

  void _setLocale(Locale locale) {
    _currentLocale = locale;
    state = locale;
  }

  bool get isEnglish => _currentLocale.languageCode == 'en';
}

String appNameFor(Locale locale) =>
    locale.languageCode == 'en' ? 'Park Here' : 'Estacione Aqui';
