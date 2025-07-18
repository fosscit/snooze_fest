import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../helpers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: settings.darkMode,
            onChanged: (val) => notifier.setDarkMode(val),
          ),
          SwitchListTile(
            title: const Text('Accessibility Mode'),
            value: settings.accessibilityMode,
            onChanged: (val) => notifier.setAccessibilityMode(val),
          ),
          SwitchListTile(
            title: const Text('Backup Enabled'),
            value: settings.backupEnabled,
            onChanged: (val) => notifier.setBackupEnabled(val),
          ),
          const Divider(),
          ListTile(
            title: const Text('Restore Defaults'),
            trailing: Icon(Icons.restore),
            onTap: () => notifier.reset(),
          ),
        ],
      ),
    );
  }
}
