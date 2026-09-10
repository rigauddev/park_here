import 'package:flutter/material.dart';

/// Local strings used by the app. Keep product copy here instead of scattering
/// language conditionals through widgets; feature-specific keys can be added
/// incrementally without changing the language selector or persistence layer.
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static const delegate = _AppLocalizationsDelegate();
  static const supportedLocales = [Locale('pt', 'BR'), Locale('en')];

  bool get isEnglish => locale.languageCode == 'en';
  String get appName => isEnglish ? 'ParkHere' : 'Estacione Aqui';
  String get loginTagline => isEnglish
      ? 'Parking, mobility and services in one place'
      : 'Mobilidade, vagas e serviços em um só lugar';
  String get email => isEnglish ? 'Email' : 'E-mail';
  String get password => isEnglish ? 'Password' : 'Senha';
  String get customer => isEnglish ? 'Customer' : 'Cliente';
  String get partner => isEnglish ? 'Partner' : 'Parceiro';
  String get bookParking => isEnglish ? 'Book parking' : 'Reservar vaga';
  String get manageServices => isEnglish ? 'Manage services' : 'Gerir serviços';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'pt' || locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get strings =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      const AppLocalizations(Locale('pt', 'BR'));
}
