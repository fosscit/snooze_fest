import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../helpers/alarm_provider.dart'; // For RingtonePlayer
import '../helpers/alarm_provider.dart' show AlarmTask, AlarmTaskType;
import 'dart:convert';

class AlarmOptionsDialog extends StatefulWidget {
  final dynamic initial;
  const AlarmOptionsDialog({this.initial, super.key});
  @override
  State<AlarmOptionsDialog> createState() => _AlarmOptionsDialogState();
}

class AlarmOptionsResult {
  final String tonePath;
  final bool vibrate;
  final bool silent;
  final List<AlarmTask> tasks;
  AlarmOptionsResult({
    required this.tonePath,
    required this.vibrate,
    required this.silent,
    required this.tasks,
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
  List<AlarmTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      if (widget.initial is CustomAlarm) {
        final settings = (widget.initial as CustomAlarm).settings;
        _selectedTone = settings.assetAudioPath;
        _vibrate = settings.vibrate;
        _silent = settings.assetAudioPath == '';
        if (_selectedTone != null && !_builtInTones.contains(_selectedTone)) {
          _userTonePath = _selectedTone;
        }
        if ((widget.initial as CustomAlarm).tasks != null) {
          _tasks = List<AlarmTask>.from((widget.initial as CustomAlarm).tasks);
        }
      } else {
        _selectedTone = widget.initial.assetAudioPath;
        _vibrate = widget.initial.vibrate;
        _silent = widget.initial.assetAudioPath == '';
        if (_selectedTone != null && !_builtInTones.contains(_selectedTone)) {
          _userTonePath = _selectedTone;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alarm Options'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ringing Tone:'),
            ..._builtInTones.map(_buildToneOption),
            _buildUserToneOption(),
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
            const SizedBox(height: 16),
            const Text('Alarm Tasks:'),
            ..._tasks.asMap().entries.map(
              (entry) => _buildTaskTile(entry.key, entry.value),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
              onPressed: _showAddTaskDialog,
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
              AlarmOptionsResult(
                tonePath: tonePath,
                vibrate: _vibrate,
                silent: _silent,
                tasks: _tasks,
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

  Widget _buildUserToneOption() {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
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
        ),
        if (_userTonePath != null)
          IconButton(
            icon: Icon(
              _selectedTone == _userTonePath && _isPlaying
                  ? Icons.stop
                  : Icons.play_arrow,
            ),
            onPressed: _silent
                ? null
                : () async {
                    final isPlaying =
                        _selectedTone == _userTonePath && _isPlaying;
                    if (isPlaying) {
                      await RingtonePlayer.stop();
                      setState(() => _isPlaying = false);
                    } else if (_userTonePath != null) {
                      await RingtonePlayer.play(_userTonePath!);
                      setState(() => _isPlaying = true);
                    }
                  },
          ),
      ],
    );
  }

  Widget _buildTaskTile(int index, AlarmTask task) {
    return ListTile(
      title: Text(task.type.toString().split('.').last),
      subtitle: Text(task.settings.toString()),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () {
          setState(() {
            _tasks.removeAt(index);
          });
        },
      ),
    );
  }

  void _showAddTaskDialog() async {
    AlarmTaskType? selectedType;
    Map<String, dynamic> settings = {};
    String? mathDifficulty;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<AlarmTaskType>(
                    value: selectedType,
                    hint: const Text('Select Task Type'),
                    items: AlarmTaskType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.toString().split('.').last),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => selectedType = val);
                    },
                  ),
                  // If timeBased is selected, show formula input
                  if (selectedType == AlarmTaskType.timeBased)
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Custom Time Formula',
                        hintText: '(A+B)*C',
                      ),
                      onChanged: (val) {
                        settings['formula'] = val;
                      },
                    ),
                  if (selectedType == AlarmTaskType.math)
                    DropdownButtonFormField<String>(
                      value: mathDifficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          mathDifficulty = val;
                          settings = {'difficulty': val};
                        });
                      },
                    ),
                  if (selectedType != null &&
                      selectedType != AlarmTaskType.math)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('No extra settings for this task type.'),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedType != null
                      ? () {
                          if (selectedType == AlarmTaskType.timeBased &&
                              (settings['formula'] == null ||
                                  settings['formula'].isEmpty)) {
                            final formulas = [
                              '(A+B)',
                              '(A*B)',
                              '(A+B)*C',
                              '(A*B)+C',
                              '(A+B+C+D)',
                              '(A*B*C)',
                              '(A+B)*(C-D)',
                              '(A*B)-(C+D)',
                              '(A+B+C)*D',
                              '(A*B)+(C*D)',
                            ];
                            final shuffled = List<String>.from(formulas)
                              ..shuffle();
                            settings['formula'] = shuffled.first;
                          }
                          Navigator.of(context).pop();
                          setState(() {
                            _tasks.add(
                              AlarmTask(
                                type: selectedType!,
                                settings: settings,
                              ),
                            );
                          });
                        }
                      : null,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    setState(() {});
  }

  @override
  void dispose() {
    RingtonePlayer.stop();
    super.dispose();
  }
}
