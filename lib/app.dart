import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snooze_fest/helpers/alarm_provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'widgets/alarm_options_dialog.dart';
import 'helpers/alarm_provider.dart'
    show CustomAlarm, AlarmTask, AlarmTaskType, AlarmStorage;
import 'package:alarm/alarm.dart';
import 'package:snooze_fest/helpers/alarm_ring_listener.dart';
import 'widgets/settings_screen.dart';
import 'helpers/settings_provider.dart';
import 'widgets/alarm_edit_screen.dart';

// 1. Add AlarmRecurrenceType enum and AlarmRecurrence model at the top (after imports):
enum AlarmRecurrenceType { once, daily, weekly, specificDates, dateRange }

class AlarmRecurrence {
  final AlarmRecurrenceType type;
  final List<int>? weekdays; // for weekly
  final List<DateTime>? specificDates; // for specific dates
  final DateTime? rangeStart; // for date range
  final DateTime? rangeEnd; // for date range
  final int? rangeIntervalDays; // for date range

  const AlarmRecurrence.once()
    : type = AlarmRecurrenceType.once,
      weekdays = null,
      specificDates = null,
      rangeStart = null,
      rangeEnd = null,
      rangeIntervalDays = null;
  const AlarmRecurrence.daily()
    : type = AlarmRecurrenceType.daily,
      weekdays = null,
      specificDates = null,
      rangeStart = null,
      rangeEnd = null,
      rangeIntervalDays = null;
  const AlarmRecurrence.weekly(this.weekdays)
    : type = AlarmRecurrenceType.weekly,
      specificDates = null,
      rangeStart = null,
      rangeEnd = null,
      rangeIntervalDays = null;
  const AlarmRecurrence.specificDates(this.specificDates)
    : type = AlarmRecurrenceType.specificDates,
      weekdays = null,
      rangeStart = null,
      rangeEnd = null,
      rangeIntervalDays = null;
  const AlarmRecurrence.dateRange(
    this.rangeStart,
    this.rangeEnd,
    this.rangeIntervalDays,
  ) : type = AlarmRecurrenceType.dateRange,
      weekdays = null,
      specificDates = null;

  factory AlarmRecurrence.fromJson(Map<String, dynamic> json) {
    final type = AlarmRecurrenceType.values[json['type'] ?? 0];
    switch (type) {
      case AlarmRecurrenceType.once:
        return const AlarmRecurrence.once();
      case AlarmRecurrenceType.daily:
        return const AlarmRecurrence.daily();
      case AlarmRecurrenceType.weekly:
        return AlarmRecurrence.weekly(
          (json['weekdays'] as List?)?.cast<int>() ?? [],
        );
      case AlarmRecurrenceType.specificDates:
        return AlarmRecurrence.specificDates(
          (json['specificDates'] as List?)
                  ?.map((s) => DateTime.parse(s))
                  .toList() ??
              [],
        );
      case AlarmRecurrenceType.dateRange:
        return AlarmRecurrence.dateRange(
          json['rangeStart'] != null
              ? DateTime.parse(json['rangeStart'])
              : null,
          json['rangeEnd'] != null ? DateTime.parse(json['rangeEnd']) : null,
          json['rangeIntervalDays'],
        );
    }
  }

  Map<String, dynamic> toJson() {
    switch (type) {
      case AlarmRecurrenceType.once:
        return {'type': type.index};
      case AlarmRecurrenceType.daily:
        return {'type': type.index};
      case AlarmRecurrenceType.weekly:
        return {'type': type.index, 'weekdays': weekdays};
      case AlarmRecurrenceType.specificDates:
        return {
          'type': type.index,
          'specificDates': specificDates
              ?.map((d) => d.toIso8601String())
              .toList(),
        };
      case AlarmRecurrenceType.dateRange:
        return {
          'type': type.index,
          'rangeStart': rangeStart?.toIso8601String(),
          'rangeEnd': rangeEnd?.toIso8601String(),
          'rangeIntervalDays': rangeIntervalDays,
        };
    }
  }
}

class NavScaffold extends StatefulWidget {
  const NavScaffold({super.key});

  @override
  State<NavScaffold> createState() => _NavScaffoldState();
}

class _NavScaffoldState extends State<NavScaffold> {
  int _currentIndex = 0;

  static final List<Widget> _screens = <Widget>[
    const AlarmScreen(),
    const ClockScreenPlaceholder(),
    const TimerScreenPlaceholder(),
    const StopwatchScreenPlaceholder(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.alarm), label: 'Alarm'),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Clock',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Timer'),
          BottomNavigationBarItem(
            icon: Icon(Icons.av_timer),
            label: 'Stopwatch',
          ),
        ],
      ),
    );
  }
}

class AlarmScreen extends ConsumerWidget {
  const AlarmScreen({super.key});

  // 2. Update _showAddOrEditAlarmDialog and AlarmCard to use CustomAlarm:
  Future<void> _showAddOrEditAlarmScreen(
    BuildContext context,
    WidgetRef ref, {
    CustomAlarm? initialAlarm,
  }) async {
    final alarmNotifier = ref.read(alarmListProvider.notifier);
    final result = await Navigator.of(context).push<CustomAlarm>(
      MaterialPageRoute(
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: AppBarTheme(
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.white
                  : null,
              foregroundColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : null,
              iconTheme: IconThemeData(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white,
              ),
              titleTextStyle: TextStyle(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          child: AlarmEditScreen(
            initialAlarm: initialAlarm,
            isEditing: initialAlarm != null,
          ),
        ),
      ),
    );
    if (result != null) {
      if (initialAlarm == null) {
        await alarmNotifier.addAlarm(result);
      } else {
        await alarmNotifier.deleteAlarm(initialAlarm.settings.id);
        await alarmNotifier.addAlarm(result);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmState = ref.watch(alarmListProvider);
    final alarmNotifier = ref.read(alarmListProvider.notifier);
    // TEMP: Wrap AlarmSettings in CustomAlarm for display
    final List<CustomAlarm> customAlarms = alarmState;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: customAlarms.isEmpty
          ? const Center(child: Text('No alarms set.'))
          : ListView.builder(
              itemCount: customAlarms.length,
              itemBuilder: (context, idx) {
                final alarm = customAlarms[idx];
                return AlarmCard(
                  alarm: alarm,
                  onDelete: () => alarmNotifier.deleteAlarm(alarm.settings.id),
                  onEdit: () => _showAddOrEditAlarmScreen(
                    context,
                    ref,
                    initialAlarm: alarm,
                  ),
                  onDuplicate: () async {
                    final duplicatedSettings = AlarmSettings(
                      id: DateTime.now().millisecondsSinceEpoch.remainder(
                        100000,
                      ),
                      dateTime: alarm.settings.dateTime.add(
                        const Duration(minutes: 1),
                      ),
                      assetAudioPath: alarm.settings.assetAudioPath,
                      loopAudio: alarm.settings.loopAudio,
                      vibrate: alarm.settings.vibrate,
                      androidFullScreenIntent:
                          alarm.settings.androidFullScreenIntent,
                      notificationSettings: alarm.settings.notificationSettings,
                      volumeSettings: alarm.settings.volumeSettings,
                    );
                    await alarmNotifier.addAlarm(
                      CustomAlarm(
                        settings: duplicatedSettings,
                        recurrence: alarm.recurrence,
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditAlarmScreen(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AlarmCard extends StatelessWidget {
  final CustomAlarm alarm;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  const AlarmCard({
    super.key,
    required this.alarm,
    required this.onDelete,
    required this.onEdit,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.alarm),
        title: Text(DateFormat('HH:mm').format(alarm.settings.dateTime)),
        subtitle: Text(
          'ID: ${alarm.settings.id} | ${_recurrenceDescription(alarm.recurrence)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.orange),
              onPressed: onDuplicate,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _recurrenceDescription(AlarmRecurrence? recurrence) {
    if (recurrence == null) return 'Once';
    switch (recurrence.type) {
      case AlarmRecurrenceType.once:
        return 'Once';
      case AlarmRecurrenceType.daily:
        return 'Daily';
      case AlarmRecurrenceType.weekly:
        if (recurrence.weekdays == null || recurrence.weekdays!.isEmpty)
          return 'Weekly';
        final days = recurrence.weekdays!
            .map((i) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i])
            .join(', ');
        return 'Weekly: $days';
      case AlarmRecurrenceType.specificDates:
        if (recurrence.specificDates == null ||
            recurrence.specificDates!.isEmpty)
          return 'Specific Dates';
        return 'Dates: ' +
            recurrence.specificDates!
                .map((d) => DateFormat('MM/dd').format(d))
                .join(', ');
      case AlarmRecurrenceType.dateRange:
        return 'Range: ${recurrence.rangeStart != null ? DateFormat('MM/dd').format(recurrence.rangeStart!) : '?'} - ${recurrence.rangeEnd != null ? DateFormat('MM/dd').format(recurrence.rangeEnd!) : '?'} every ${recurrence.rangeIntervalDays ?? '?'}d';
    }
  }
}

// 3. Add AlarmRecurrenceDialog widget (after AlarmOptionsDialog):
class AlarmRecurrenceDialog extends StatefulWidget {
  final AlarmRecurrence? initial;
  const AlarmRecurrenceDialog({this.initial, super.key});
  @override
  State<AlarmRecurrenceDialog> createState() => _AlarmRecurrenceDialogState();
}

class _AlarmRecurrenceDialogState extends State<AlarmRecurrenceDialog> {
  AlarmRecurrenceType _type = AlarmRecurrenceType.once;
  List<bool> _weekdays = List.filled(7, false);
  List<DateTime> _specificDates = [];
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  int _rangeIntervalDays = 1;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _type = widget.initial!.type;
      _weekdays = List<bool>.from(
        widget.initial!.weekdays ?? List.filled(7, false),
      );
      _specificDates = List<DateTime>.from(widget.initial!.specificDates ?? []);
      _rangeStart = widget.initial!.rangeStart;
      _rangeEnd = widget.initial!.rangeEnd;
      _rangeIntervalDays = widget.initial!.rangeIntervalDays ?? 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recurrence'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<AlarmRecurrenceType>(
              value: _type,
              onChanged: (val) {
                if (val != null) setState(() => _type = val);
              },
              items: AlarmRecurrenceType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toString().split('.').last),
                );
              }).toList(),
            ),
            if (_type == AlarmRecurrenceType.weekly)
              Wrap(
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
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _weekdays[i],
                        onChanged: (val) {
                          setState(() => _weekdays[i] = val ?? false);
                        },
                      ),
                      Text(weekday),
                    ],
                  );
                }),
              ),
            if (_type == AlarmRecurrenceType.specificDates)
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
            if (_type == AlarmRecurrenceType.dateRange)
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            AlarmRecurrence recurrence;
            switch (_type) {
              case AlarmRecurrenceType.once:
                recurrence = const AlarmRecurrence.once();
                break;
              case AlarmRecurrenceType.daily:
                recurrence = const AlarmRecurrence.daily();
                break;
              case AlarmRecurrenceType.weekly:
                recurrence = AlarmRecurrence.weekly(
                  List.generate(
                    7,
                    (i) => _weekdays[i] ? i : null,
                  ).whereType<int>().toList(),
                );
                break;
              case AlarmRecurrenceType.specificDates:
                recurrence = AlarmRecurrence.specificDates(_specificDates);
                break;
              case AlarmRecurrenceType.dateRange:
                recurrence = AlarmRecurrence.dateRange(
                  _rangeStart,
                  _rangeEnd,
                  _rangeIntervalDays,
                );
                break;
            }
            Navigator.of(context).pop(recurrence);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class ClockScreenPlaceholder extends StatelessWidget {
  const ClockScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Clock Screen'));
  }
}

class TimerScreenPlaceholder extends StatelessWidget {
  const TimerScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Timer Screen'));
  }
}

class StopwatchScreenPlaceholder extends StatelessWidget {
  const StopwatchScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Stopwatch Screen'));
  }
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'Alarm Clock',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        // Accessibility: increase text scale if enabled
        final scale = settings.accessibilityMode ? 1.3 : 1.0;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: scale),
          child: child!,
        );
      },
      home: AlarmRingListener(child: const NavScaffold()),
    );
  }
}
