import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:snooze_fest/helpers/alarm_provider.dart';
import 'package:snooze_fest/widgets/equation_diffuse_dialog.dart';
import 'package:file_picker/file_picker.dart';
import '../app.dart'; // Import CustomAlarm and AlarmRecurrence
import '../helpers/alarm_provider.dart'; // For RingtonePlayer
import 'alarm_edit_screen.dart';

class AlarmHomeScreen extends ConsumerWidget {
  const AlarmHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmState = ref.watch(alarmListProvider);
    final alarmNotifier = ref.read(alarmListProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Clock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            tooltip: 'Test Calculator Popup',
            onPressed: () async {
              final dummyAlarm = AlarmSettings(
                id: 99999,
                dateTime: DateTime.now(),
                assetAudioPath: 'assets/alarm.mp3',
                loopAudio: false,
                vibrate: false,
                androidFullScreenIntent: false,
                notificationSettings: const NotificationSettings(
                  title: 'Test Alarm',
                  body: 'Test Equation Dialog',
                ),
                volumeSettings: VolumeSettings.fade(
                  volume: 0.5,
                  fadeDuration: const Duration(seconds: 1),
                  volumeEnforced: false,
                ),
              );
              showDialog(
                context: context,
                builder: (context) =>
                    EquationDiffuseDialog(alarm: dummyAlarm, tasks: const []),
              );
            },
          ),
        ],
      ),
      body: alarmState.isEmpty
          ? const Center(child: Text('No alarms set.'))
          : ListView.builder(
              itemCount: alarmState.length,
              itemBuilder: (context, idx) {
                final alarm = alarmState[idx];
                return ListTile(
                  leading: const Icon(Icons.alarm),
                  title: Text(
                    DateFormat('hh:mm a').format(alarm.settings.dateTime),
                  ),
                  subtitle: Text(
                    alarm.settings.notificationSettings.title ?? '',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: alarm.enabled,
                        onChanged: (val) async {
                          final updatedAlarm = CustomAlarm(
                            settings: alarm.settings,
                            recurrence: alarm.recurrence,
                            tasks: alarm.tasks,
                            enabled: val,
                          );
                          await alarmNotifier.addAlarm(updatedAlarm);
                          if (val) {
                            await Alarm.set(alarmSettings: alarm.settings);
                          } else {
                            await Alarm.stop(alarm.settings.id);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          await alarmNotifier.deleteAlarm(alarm.settings.id);
                        },
                      ),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AlarmEditScreen(
                          initialAlarm: alarm,
                          isEditing: true,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AlarmEditScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AlarmOptionsDialog extends StatefulWidget {
  @override
  State<AlarmOptionsDialog> createState() => _AlarmOptionsDialogState();
}

class _AlarmOptionsResult {
  final String tonePath;
  final bool vibrate;
  final bool silent;
  _AlarmOptionsResult({
    required this.tonePath,
    required this.vibrate,
    required this.silent,
  });
}

class _AlarmOptionsDialogState extends State<AlarmOptionsDialog> {
  String? _selectedTone;
  bool _vibrate = true;
  bool _silent = false;
  final List<String> _builtInTones = [
    'assets/alarm.mp3',
    // Add more built-in tones here if available
  ];
  String? _userTonePath;
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    debugPrint('AlarmOptionsDialog is being shown');
    return AlertDialog(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.red, width: 4),
        borderRadius: BorderRadius.circular(12),
      ),
      title: const Text('Alarm Options'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ringing Tone:'),
            ..._builtInTones.map(_buildToneOption),
            RadioListTile<String>(
              title: Text(
                _userTonePath == null
                    ? 'Pick from device'
                    : 'Custom: ${_userTonePath!.split('/').last}',
              ),
              value: _userTonePath ?? 'user',
              groupValue: _selectedTone,
              onChanged: _silent
                  ? null
                  : (val) async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.audio,
                      );
                      if (result != null && result.files.single.path != null) {
                        setState(() {
                          _userTonePath = result.files.single.path;
                          _selectedTone = _userTonePath;
                        });
                      }
                    },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Vibrate'),
              value: _vibrate,
              onChanged: _silent
                  ? null
                  : (val) {
                      setState(() {
                        _vibrate = val;
                      });
                    },
            ),
            SwitchListTile(
              title: const Text('Silent'),
              value: _silent,
              onChanged: (val) {
                setState(() {
                  _silent = val;
                  if (_silent) {
                    _vibrate = false;
                  }
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final tonePath = _silent
                ? ''
                : (_selectedTone ?? _builtInTones.first);
            Navigator.of(context).pop(
              _AlarmOptionsResult(
                tonePath: tonePath,
                vibrate: _vibrate,
                silent: _silent,
              ),
            );
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _buildToneOption(String tone) {
    final isPlaying = _selectedTone == tone && _isPlaying;
    return Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            title: Text(tone.split('/').last),
            value: tone,
            groupValue: _selectedTone,
            onChanged: _silent
                ? null
                : (val) {
                    setState(() {
                      _selectedTone = val;
                      _userTonePath = null;
                    });
                  },
          ),
        ),
        IconButton(
          icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
          onPressed: _silent
              ? null
              : () async {
                  if (isPlaying) {
                    await RingtonePlayer.stop();
                    setState(() => _isPlaying = false);
                  } else {
                    await RingtonePlayer.play(tone);
                    setState(() => _isPlaying = true);
                  }
                },
        ),
      ],
    );
  }

  @override
  void dispose() {
    RingtonePlayer.stop();
    super.dispose();
  }
}
