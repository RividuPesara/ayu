import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocales {
  const AppLocales._();

  static const Locale english = Locale('en');
  static const Locale sinhala = Locale('si');

  static const List<Locale> supported = <Locale>[english, sinhala];

  static String nativeName(Locale locale) {
    switch (locale.languageCode) {
      case 'si':
        return 'සිංහල';
      case 'en':
      default:
        return 'English';
    }
  }
}

class LocaleController extends ChangeNotifier {
  LocaleController._();

  static final LocaleController instance = LocaleController._();

  static const String _prefsKey = 'app_locale_code';

  Locale _locale = AppLocales.english;
  bool _loaded = false;

  Locale get locale => _locale;
  bool get isLoaded => _loaded;
  bool get isSinhala => _locale.languageCode == 'si';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null) {
        final match = AppLocales.supported.where(
          (l) => l.languageCode == code,
        );
        if (match.isNotEmpty) {
          _locale = match.first;
        }
      }
    } catch (_) {
      // Storage unavailable — keep the English default.
    }
    await _applyIntlLocale();
    _loaded = true;
    notifyListeners();
  }

  /// Date-symbol data must be initialised before `DateFormat` runs or it throws.
  Future<void> _applyIntlLocale() async {
    try {
      await initializeDateFormatting();
      Intl.defaultLocale = _locale.languageCode;
    } catch (_) {
      Intl.defaultLocale = 'en';
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;
    await _applyIntlLocale();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, locale.languageCode);
    } catch (_) {
      // Applies for this session even if it could not be saved.
    }
  }

  Future<void> toggle() =>
      setLocale(isSinhala ? AppLocales.english : AppLocales.sinhala);
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    return scope?.notifier ?? LocaleController.instance;
  }
}
