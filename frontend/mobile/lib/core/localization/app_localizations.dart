import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'strings_en.dart';
import 'strings_si.dart';


class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(AppLocales.english);
  }

  static AppLocalizations get global =>
      AppLocalizations(LocaleController.instance.locale);

  static String tr(String key, [Map<String, String>? params]) =>
      global.t(key, params);

  static const Map<String, Map<String, String>> _tables =
      <String, Map<String, String>>{'en': enStrings, 'si': siStrings};

  Map<String, String> get _table => _tables[locale.languageCode] ?? enStrings;

  bool get isSinhala => locale.languageCode == 'si';

  String t(String key, [Map<String, String>? params]) {
    var value = _table[key] ?? enStrings[key];

    if (value == null) {
      assert(() {
        debugPrint('[l10n] Missing translation key: "$key"');
        return true;
      }());
      value = key.split('.').last.replaceAll('_', ' ');
    }

    if (params == null || params.isEmpty) return value;

    var result = value;
    params.forEach((name, replacement) {
      result = result.replaceAll('{$name}', replacement);
    });
    return result;
  }

  String plural(String singularKey, String pluralKey, int count,
      [Map<String, String>? params]) {
    final merged = <String, String>{'count': '$count', ...?params};
    return t(count == 1 ? singularKey : pluralKey, merged);
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocales.supported
      .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String t(String key, [Map<String, String>? params]) =>
      AppLocalizations.of(this).t(key, params);

  String tPlural(String singularKey, String pluralKey, int count,
          [Map<String, String>? params]) =>
      AppLocalizations.of(this).plural(singularKey, pluralKey, count, params);

  bool get isSinhala => AppLocalizations.of(this).isSinhala;
}
