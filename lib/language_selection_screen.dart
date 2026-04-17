import 'package:flutter/material.dart';
import 'package:trogo_app/api_service/splash_service.dart';
import 'package:trogo_app/localization/app_language.dart';
import 'package:trogo_app/localization/app_language_controller.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  AppLanguage? _selectedLanguage;
  bool _saving = false;

  Future<void> _continue() async {
    final language = _selectedLanguage;
    if (language == null || _saving) return;

    setState(() => _saving = true);
    await AppLanguageController.instance.setLanguage(language);
    await AppPreference().setBool(PreferencesKey.languageSelected, true);
    if (!mounted) return;

    await SplashServices().routeNext(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text(
                'Choose your language',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'Select Marathi, Hindi or English to continue.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              ...AppLanguage.values.map(_buildLanguageTile),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedLanguage == null || _saving
                      ? null
                      : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(_saving ? 'Saving...' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageTile(AppLanguage language) {
    final isSelected = _selectedLanguage == language;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _selectedLanguage = language),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? Colors.black : const Color(0xFFE1E1E1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _languageLabel(language),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? Colors.white : Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _languageLabel(AppLanguage language) {
    switch (language) {
      case AppLanguage.marathi:
        return 'मराठी';
      case AppLanguage.hindi:
        return 'हिंदी';
      case AppLanguage.english:
        return 'English';
    }
  }
}
