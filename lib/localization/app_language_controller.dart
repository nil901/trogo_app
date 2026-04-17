import 'package:flutter/foundation.dart';
import 'package:trogo_app/localization/app_language.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';

class AppLanguageController extends ChangeNotifier {
  AppLanguageController._();

  static final AppLanguageController instance = AppLanguageController._();

  AppLanguage _currentLanguage = appLanguageFromCode(
    AppPreference().getString(
      PreferencesKey.appLanguage,
      defValue: AppLanguage.english.code,
    ),
  );

  AppLanguage get currentLanguage => _currentLanguage;

  Future<void> setLanguage(AppLanguage language) async {
    final didChange = _currentLanguage != language;
    _currentLanguage = language;
    await AppPreference().setString(PreferencesKey.appLanguage, language.code);
    if (didChange) {
      notifyListeners();
    }
  }
}
