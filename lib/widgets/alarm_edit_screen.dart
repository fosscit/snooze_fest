import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../helpers/alarm_provider.dart';
import 'package:alarm/alarm.dart';
import '../app.dart';

// Add recurrence type enum for inline selection
enum InlineRecurrenceType { once, daily, weekly, specificDates, dateRange }

class AlarmEditScreen extends ConsumerStatefulWidget {
  final CustomAlarm? initialAlarm;
  final bool isEditing;
  const AlarmEditScreen({Key? key, this.initialAlarm, this.isEditing = false})
    : super(key: key);

  @override
  ConsumerState<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends ConsumerState<AlarmEditScreen> {
  late DateTime _alarmTime;
  late String _label;
  late String? _selectedTone;
  late bool _vibrate;
  late bool _silent;
  late List<AlarmTask> _tasks;
  String? _userTonePath;
  final List<String> _builtInTones = [
    'assets/alarm.mp3',
    // Add more built-in tones here if available
  ];
  bool _isPlaying = false;
  bool _showTonePicker = false;
  AlarmTaskType? _newTaskType;
  String? _newTaskDifficulty;

  // Recurrence state
  InlineRecurrenceType _recurrenceType = InlineRecurrenceType.once;
  List<bool> _weekdays = List.filled(7, false);
  List<DateTime> _specificDates = [];
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  int _rangeIntervalDays = 1;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.initialAlarm != null) {
      final settings = widget.initialAlarm!.settings;
      _alarmTime = settings.dateTime;
      _label = settings.notificationSettings?.title ?? '';
      _selectedTone = settings.assetAudioPath;
      _vibrate = settings.vibrate;
      _silent = settings.assetAudioPath == '';
      _tasks = List<AlarmTask>.from(widget.initialAlarm!.tasks ?? []);
      if (_selectedTone != null && !_builtInTones.contains(_selectedTone)) {
        _userTonePath = _selectedTone;
      }
      // Recurrence
      final rec = widget.initialAlarm!.recurrence;
      if (rec.type == AlarmRecurrenceType.once) {
        _recurrenceType = InlineRecurrenceType.once;
      } else if (rec.type == AlarmRecurrenceType.daily) {
        _recurrenceType = InlineRecurrenceType.daily;
      } else if (rec.type == AlarmRecurrenceType.weekly) {
        _recurrenceType = InlineRecurrenceType.weekly;
        _weekdays = List.filled(7, false);
        if (rec.weekdays != null) {
          for (final i in rec.weekdays!) {
            if (i >= 0 && i < 7) _weekdays[i] = true;
          }
        }
      } else if (rec.type == AlarmRecurrenceType.specificDates) {
        _recurrenceType = InlineRecurrenceType.specificDates;
        _specificDates = List<DateTime>.from(rec.specificDates ?? []);
      } else if (rec.type == AlarmRecurrenceType.dateRange) {
        _recurrenceType = InlineRecurrenceType.dateRange;
        _rangeStart = rec.rangeStart;
        _rangeEnd = rec.rangeEnd;
        _rangeIntervalDays = rec.rangeIntervalDays ?? 1;
      }
    } else {
      _alarmTime = now.add(const Duration(minutes: 1));
      _label = '';
      _selectedTone = _builtInTones.first;
      _vibrate = true;
      _silent = false;
      _tasks = [];
      _userTonePath = null;
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _alarmTime.hour, minute: _alarmTime.minute),
    );
    if (picked != null) {
      setState(() {
        _alarmTime = DateTime(
          _alarmTime.year,
          _alarmTime.month,
          _alarmTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _pickToneFromDevice() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _userTonePath = result.files.single.path;
        _selectedTone = _userTonePath;
        _silent = false;
      });
    }
  }

  void _save() async {
    final alarmNotifier = ref.read(alarmListProvider.notifier);
    // Build recurrence from inline state
    AlarmRecurrence recurrence;
    switch (_recurrenceType) {
      case InlineRecurrenceType.once:
        recurrence = const AlarmRecurrence.once();
        break;
      case InlineRecurrenceType.daily:
        recurrence = const AlarmRecurrence.daily();
        break;
      case InlineRecurrenceType.weekly:
        recurrence = AlarmRecurrence.weekly(
          List.generate(
            7,
            (i) => _weekdays[i] ? i : null,
          ).whereType<int>().toList(),
        );
        break;
      case InlineRecurrenceType.specificDates:
        recurrence = AlarmRecurrence.specificDates(_specificDates);
        break;
      case InlineRecurrenceType.dateRange:
        recurrence = AlarmRecurrence.dateRange(
          _rangeStart,
          _rangeEnd,
          _rangeIntervalDays,
        );
        break;
    }
    final alarmSettings = AlarmSettings(
      id:
          widget.initialAlarm?.settings.id ??
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
      dateTime: _alarmTime.isBefore(DateTime.now())
          ? _alarmTime.add(const Duration(days: 1))
          : _alarmTime,
      assetAudioPath: _silent ? '' : (_selectedTone ?? _builtInTones.first),
      loopAudio: true, // Always loop alarm audio
      vibrate: _vibrate && !_silent,
      androidFullScreenIntent: true,
      notificationSettings: NotificationSettings(
        title: _label.isEmpty ? 'Alarm' : _label,
        body: 'Solve the equation to stop the alarm!',
      ),
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
    );
    final customAlarm = CustomAlarm(
      settings: alarmSettings,
      recurrence: recurrence,
      tasks: _tasks,
    );
    await alarmNotifier.addAlarm(customAlarm);
    if (mounted) Navigator.of(context).pop(customAlarm);
  }

  void _addTaskInline() {
    if (_newTaskType == null) return;
    Map<String, dynamic> settings = {};
    if (_newTaskType == AlarmTaskType.math) {
      settings = {'difficulty': _newTaskDifficulty ?? 'easy'};
    }
    // Add support for custom formula for timeBased
    if (_newTaskType == AlarmTaskType.timeBased) {
      if (_newTaskDifficulty != null && _newTaskDifficulty!.isNotEmpty) {
        settings = {'formula': _newTaskDifficulty};
      } else {
        // Generate and store a random formula
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
        final shuffled = List<String>.from(formulas)..shuffle();
        settings = {'formula': shuffled.first};
      }
    }
    setState(() {
      _tasks.add(AlarmTask(type: _newTaskType!, settings: settings));
      _newTaskType = null;
      _newTaskDifficulty = null;
    });
  }

  Widget _buildTonePicker(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note),
                const SizedBox(width: 8),
                const Text(
                  'Ringing Tone',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showTonePicker = false),
                ),
              ],
            ),
            ..._builtInTones.map(
              (tone) => RadioListTile<String>(
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
                secondary: IconButton(
                  icon: Icon(
                    _selectedTone == tone && _isPlaying
                        ? Icons.stop
                        : Icons.play_arrow,
                  ),
                  onPressed: _silent
                      ? null
                      : () async {
                          if (_isPlaying && _selectedTone == tone) {
                            await RingtonePlayer.stop();
                            setState(() => _isPlaying = false);
                          } else {
                            await RingtonePlayer.play(tone);
                            setState(() {
                              _isPlaying = true;
                              _selectedTone = tone;
                            });
                          }
                        },
                ),
              ),
            ),
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
                      await _pickToneFromDevice();
                    },
              secondary: _userTonePath != null
                  ? IconButton(
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
                                setState(() {
                                  _isPlaying = true;
                                  _selectedTone = _userTonePath;
                                });
                              }
                            },
                    )
                  : null,
            ),
            SwitchListTile(
              title: const Text('Silent'),
              value: _silent,
              onChanged: (val) {
                setState(() {
                  _silent = val;
                  if (_silent) _vibrate = false;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Vibrate'),
              value: _vibrate,
              onChanged: _silent
                  ? null
                  : (val) => setState(() => _vibrate = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.repeat),
                SizedBox(width: 8),
                Text(
                  'Recurrence',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButton<InlineRecurrenceType>(
              value: _recurrenceType,
              onChanged: (val) {
                if (val != null) setState(() => _recurrenceType = val);
              },
              items: const [
                DropdownMenuItem(
                  value: InlineRecurrenceType.once,
                  child: Text('Once'),
                ),
                DropdownMenuItem(
                  value: InlineRecurrenceType.daily,
                  child: Text('Daily'),
                ),
                DropdownMenuItem(
                  value: InlineRecurrenceType.weekly,
                  child: Text('Weekly'),
                ),
                DropdownMenuItem(
                  value: InlineRecurrenceType.specificDates,
                  child: Text('Specific Dates'),
                ),
                DropdownMenuItem(
                  value: InlineRecurrenceType.dateRange,
                  child: Text('Date Range'),
                ),
              ],
            ),
            if (_recurrenceType == InlineRecurrenceType.weekly)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(7, (i) {
                    final weekday = [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ][i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _weekdays[i],
                            onChanged: (val) {
                              setState(() => _weekdays[i] = val ?? false);
                            },
                          ),
                          Text(weekday, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            if (_recurrenceType == InlineRecurrenceType.specificDates)
              Column(
                children: [
                  ..._specificDates.map(
                    (date) => ListTile(
                      title: Text(DateFormat('yyyy-MM-dd').format(date)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() => _specificDates.remove(date));
                        },
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _specificDates.add(picked));
                      }
                    },
                    child: const Text('Add Date'),
                  ),
                ],
              ),
            if (_recurrenceType == InlineRecurrenceType.dateRange)
              Column(
                children: [
                  ListTile(
                    title: Text(
                      'Start: ${_rangeStart != null ? DateFormat('yyyy-MM-dd').format(_rangeStart!) : 'Not set'}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.date_range),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _rangeStart ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null)
                          setState(() => _rangeStart = picked);
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                      'End: ${_rangeEnd != null ? DateFormat('yyyy-MM-dd').format(_rangeEnd!) : 'Not set'}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.date_range),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _rangeEnd ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _rangeEnd = picked);
                      },
                    ),
                  ),
                  Row(
                    children: [
                      const Text('Interval (days):'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: _rangeIntervalDays.toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed > 0) {
                              setState(() => _rangeIntervalDays = parsed);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.task),
                SizedBox(width: 8),
                Text(
                  'Alarm Tasks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._tasks.asMap().entries.map(
              (entry) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: ListTile(
                  title: Text(entry.value.type.toString().split('.').last),
                  subtitle: Text(entry.value.settings.toString()),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _tasks.removeAt(entry.key);
                      });
                    },
                  ),
                ),
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<AlarmTaskType>(
                    value: _newTaskType,
                    hint: const Text('Select Task Type'),
                    isExpanded: true,
                    items: AlarmTaskType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.toString().split('.').last),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _newTaskType = val;
                        _newTaskDifficulty = null;
                      });
                    },
                  ),
                ),
                if (_newTaskType == AlarmTaskType.math)
                  const SizedBox(width: 8),
                if (_newTaskType == AlarmTaskType.math)
                  Expanded(
                    child: DropdownButton<String>(
                      value: _newTaskDifficulty,
                      hint: const Text('Difficulty'),
                      isExpanded: true,
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
                          _newTaskDifficulty = val;
                        });
                      },
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task'),
                  onPressed: _newTaskType != null ? _addTaskInline : null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Alarm' : 'New Alarm',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.black
            : Colors.white,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.black
              : Colors.white,
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text(
                'Time',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(DateFormat('HH:mm').format(_alarmTime)),
              onTap: _pickTime,
              trailing: const Icon(Icons.edit),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.label),
              title: const Text(
                'Label',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: TextFormField(
                initialValue: _label,
                decoration: const InputDecoration(
                  hintText: 'Alarm label',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (val) => setState(() => _label = val),
              ),
            ),
          ),
          _buildRecurrenceSection(context),
          _showTonePicker
              ? _buildTonePicker(context)
              : Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.music_note),
                    title: const Text(
                      'Ringing Tone',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _silent
                          ? 'Silent'
                          : (_selectedTone == null
                                ? 'Default'
                                : _selectedTone!.split('/').last),
                    ),
                    onTap: () => setState(() => _showTonePicker = true),
                    trailing: const Icon(Icons.edit),
                  ),
                ),
          _buildTaskSection(context),
        ],
      ),
    );
  }
}
