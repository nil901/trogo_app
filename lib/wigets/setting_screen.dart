import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:trogo_app/localization/app_language.dart';
import 'package:trogo_app/localization/app_language_controller.dart';
import 'package:trogo_app/localization/app_strings.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Settings variables
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  String _selectedLanguage = 'English';

  final List<String> _languages = AppLanguage.values
      .map((language) => language.displayName)
      .toList();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved settings
  Future<void> _loadSettings() async {
    final notificationStatus = await Permission.notification.status;
    final locationPermission = await Permission.location.status;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    setState(() {
      _selectedLanguage =
          AppLanguageController.instance.currentLanguage.displayName;
      _notificationsEnabled =
          AppPreference().getBool(
            PreferencesKey.notificationsEnabled,
            defValue: notificationStatus.isGranted,
          ) &&
          notificationStatus.isGranted;
      _locationEnabled =
          AppPreference().getBool(
            PreferencesKey.locationEnabled,
            defValue: locationPermission.isGranted && serviceEnabled,
          ) &&
          locationPermission.isGranted &&
          serviceEnabled;
    });
  }

  Future<void> _saveToggle({
    required String key,
    required bool value,
    required String successMessage,
  }) async {
    await AppPreference().setBool(key, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
  }

  Future<void> _handleNotificationToggle(bool value) async {
    if (!value) {
      setState(() {
        _notificationsEnabled = false;
      });
      await _saveToggle(
        key: PreferencesKey.notificationsEnabled,
        value: false,
        successMessage: AppStrings.t('notificationsTurnedOff'),
      );
      return;
    }

    final status = await Permission.notification.request();
    if (!mounted) return;

    if (status.isGranted) {
      setState(() {
        _notificationsEnabled = true;
      });
      await _saveToggle(
        key: PreferencesKey.notificationsEnabled,
        value: true,
        successMessage: AppStrings.t('notificationsTurnedOn'),
      );
      return;
    }

    setState(() {
      _notificationsEnabled = false;
    });
    await _saveToggle(
      key: PreferencesKey.notificationsEnabled,
      value: false,
      successMessage: AppStrings.t('notificationPermissionNotGranted'),
    );

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> _handleLocationToggle(bool value) async {
    if (!value) {
      setState(() {
        _locationEnabled = false;
      });
      await _saveToggle(
        key: PreferencesKey.locationEnabled,
        value: false,
        successMessage: AppStrings.t('locationTurnedOff'),
      );
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('turnOnLocationServices'))),
      );
      await Geolocator.openLocationSettings();
      return;
    }

    var permission = await Permission.location.status;
    if (!permission.isGranted) {
      permission = await Permission.location.request();
    }

    if (!mounted) return;

    if (permission.isGranted) {
      setState(() {
        _locationEnabled = true;
      });
      await _saveToggle(
        key: PreferencesKey.locationEnabled,
        value: true,
        successMessage: AppStrings.t('locationTurnedOn'),
      );
      return;
    }

    setState(() {
      _locationEnabled = false;
    });
    await _saveToggle(
      key: PreferencesKey.locationEnabled,
      value: false,
      successMessage: AppStrings.t('locationPermissionNotGranted'),
    );

    if (permission.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(AppStrings.t('settings')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        children: [
        
          // Preferences Section
          _buildSectionHeader(AppStrings.t('preferences')),

          // Notifications Toggle
          _buildSwitchTile(
            icon: Icons.notifications,
            title: AppStrings.t('notifications'),
            subtitle: AppStrings.t('receivePushNotifications'),
            value: _notificationsEnabled,
            onChanged: _handleNotificationToggle,
          ),

          // Location Toggle
          _buildSwitchTile(
            icon: Icons.location_on,
            title: AppStrings.t('locationServices'),
            subtitle: AppStrings.t('allowLocationAccess'),
            value: _locationEnabled,
            onChanged: _handleLocationToggle,
          ),

          _buildDropdownTile(
            icon: Icons.language,
            title: AppStrings.t('language'),
            value: _selectedLanguage,
            items: _languages,
            onChanged: (value) async {
              if (value == null) return;
              setState(() {
                _selectedLanguage = value;
              });
              await AppLanguageController.instance.setLanguage(
                appLanguageFromLabel(value),
              );
            },
          ),

          _buildListTile(
            icon: Icons.info,
            title: AppStrings.t('aboutApp'),
            onTap: () {
              _showAboutDialog();
            },
          ),

          // Version Info
          Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                '${AppStrings.t('version')} 1.0.0',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  // Helper widget for switch tiles
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 220, 228, 234),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color.fromARGB(255, 13, 14, 14)),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.green,
    );
  }

  // Helper widget for list tiles
  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
                 color: const Color.fromARGB(255, 220, 228, 234),

          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.black),
      ),
      title: Text(title),
      trailing: trailing ?? Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  // Helper widget for dropdown
  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.blue),
      ),
      title: Text(title),
      trailing: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.black87,
            ),
            items:
                items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item, style: TextStyle(color: Colors.black87)),
                  );
                }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  // Helper widget for slider
  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.blue),
      ),
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: value.round().toString(),
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
      trailing: Text(
        '${value.round()}px',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
      ),
    );
  }

  // Show about dialog
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppStrings.t('aboutApp')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Icon(Icons.apps, size: 50, color: Colors.blue),
              ),
              const SizedBox(height: 10),
              Text(
                AppStrings.t('awesomeApp'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text('${AppStrings.t('version')} 1.0.0'),
              const SizedBox(height: 14),
              Text(
                AppStrings.t('appDescription'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _aboutPoint('Fast booking and ride management in one place.'),
              const SizedBox(height: 10),
              _aboutPoint('Live location and trip history for better tracking.'),
              const SizedBox(height: 10),
              _aboutPoint('Simple profile, settings, and privacy controls.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.t('ok')),
            ),
          ],
        );
      },
    );
  }

  Widget _aboutPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.more_horiz, size: 18, color: Colors.blue),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }

  // Show logout dialog
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppStrings.t('logOutTitle')),
          content: Text(AppStrings.t('logOutMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.t('cancel')),
            ),
            TextButton(
              onPressed: () {
                // Perform logout
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppStrings.t('loggedOutSuccessfully')),
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(AppStrings.t('logOut')),
            ),
          ],
        );
      },
    );
  }
}
