import 'dart:ui';

enum AppLanguage { english, hindi, marathi }

extension AppLanguageX on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.hindi:
        return 'hi';
      case AppLanguage.marathi:
        return 'mr';
    }
  }

  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.hindi:
        return 'Hindi';
      case AppLanguage.marathi:
        return 'Marathi';
    }
  }

  Locale get locale => Locale(code);
}

AppLanguage appLanguageFromCode(String code) {
  switch (code.toLowerCase()) {
    case 'hi':
      return AppLanguage.hindi;
    case 'mr':
      return AppLanguage.marathi;
    default:
      return AppLanguage.english;
  }
}

AppLanguage appLanguageFromLabel(String label) {
  final normalized = label.trim().toLowerCase();
  switch (normalized) {
    case 'hindi':
    case 'हिंदी':
      return AppLanguage.hindi;
    case 'marathi':
    case 'मराठी':
      return AppLanguage.marathi;
    default:
      return AppLanguage.english;
  }
}
