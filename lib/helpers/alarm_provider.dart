// NOTE: Ensure you have just_audio and audio_session in your pubspec.yaml dependencies.
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'dart:convert';
import '../app.dart'; // For CustomAlarm, AlarmRecurrence
import 'dart:io';
import 'package:get_storage/get_storage.dart';

class AlarmListState {
  final List<CustomAlarm> alarms;
  final bool loading;

  const AlarmListState({required this.alarms, this.loading = false});

  AlarmListState copyWith({List<CustomAlarm>? alarms, bool? loading}) {
    return AlarmListState(
      alarms: alarms ?? this.alarms,
      loading: loading ?? this.loading,
    );
  }
}

class AlarmListNotifier extends StateNotifier<List<CustomAlarm>> {
  AlarmListNotifier() : super([]) {
    _loadAlarms();
  }

  final _storage = GetStorage();
  static const _alarmsKey = 'alarms';

  Future<void> _loadAlarms() async {
    final data = _storage.read(_alarmsKey);
    if (data is List) {
      state = data
          .map((e) => CustomAlarm.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      // Schedule only enabled alarms with a future occurrence
      for (final alarm in state) {
        if (alarm.enabled && alarm.settings.dateTime.isAfter(DateTime.now())) {
          await Alarm.set(alarmSettings: alarm.settings);
        } else {
          await Alarm.stop(alarm.settings.id);
        }
      }
    }
  }

  Future<void> _saveAlarms() async {
    await _storage.write(_alarmsKey, state.map((e) => e.toJson()).toList());
  }

  Future<void> addAlarm(CustomAlarm alarm) async {
    final idx = state.indexWhere((a) => a.settings.id == alarm.settings.id);
    if (idx >= 0) {
      state = [...state.sublist(0, idx), alarm, ...state.sublist(idx + 1)];
    } else {
      state = [...state, alarm];
    }
    await _saveAlarms();
    if (alarm.enabled && alarm.settings.dateTime.isAfter(DateTime.now())) {
      await Alarm.set(alarmSettings: alarm.settings);
    } else {
      await Alarm.stop(alarm.settings.id);
    }
  }

  Future<void> deleteAlarm(int id) async {
    state = state.where((a) => a.settings.id != id).toList();
    await _saveAlarms();
    await Alarm.stop(id);
  }

  Future<void> stopAlarm(int id) async {
    await Alarm.stop(id);
    final idx = state.indexWhere((a) => a.settings.id == id);
    if (idx != -1) {
      final alarm = state[idx];
      if (alarm.recurrence.type != AlarmRecurrenceType.once) {
        // Remove the occurrence that just rang
        final nextTimes = computeNextOccurrences(alarm, max: 1);
        if (nextTimes.isNotEmpty) {
          final nextDt = nextTimes.first;
          final settings = alarm.settings.copyWith(dateTime: nextDt);
          await Alarm.set(alarmSettings: settings);
        }
      }
    }
  }

  Future<void> snoozeAlarm(CustomAlarm alarm, Duration duration) async {
    // Implement snooze by creating a new alarm with a new dateTime
    final snoozeTime = DateTime.now().add(duration);
    final snoozedSettings = alarm.settings.copyWith(dateTime: snoozeTime);
    await Alarm.set(alarmSettings: snoozedSettings);
  }
}

// 1. Add a helper to compute next occurrences for a CustomAlarm:
// 4. Refactor AlarmRecurrence to class-based schedules
abstract class AlarmSchedule {
  const AlarmSchedule();
  DateTime? getNextOccurrence(DateTime base);
  Map<String, dynamic> toJson();
  static AlarmSchedule fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'once':
        return const OnceSchedule();
      case 'daily':
        return const DailySchedule();
      case 'weekly':
        return WeeklySchedule((json['weekdays'] as List?)?.cast<int>() ?? []);
      case 'dates':
        return DatesSchedule(
          (json['dates'] as List?)?.map((s) => DateTime.parse(s)).toList() ??
              [],
        );
      case 'range':
        return RangeSchedule(
          json['rangeStart'] != null
              ? DateTime.parse(json['rangeStart'])
              : null,
          json['rangeEnd'] != null ? DateTime.parse(json['rangeEnd']) : null,
          json['intervalDays'],
        );
      default:
        return const OnceSchedule();
    }
  }
}

class OnceSchedule extends AlarmSchedule {
  const OnceSchedule();
  @override
  DateTime? getNextOccurrence(DateTime base) =>
      base.isAfter(DateTime.now()) ? base : null;
  @override
  Map<String, dynamic> toJson() => {'type': 'once'};
}

class DailySchedule extends AlarmSchedule {
  const DailySchedule();
  @override
  DateTime? getNextOccurrence(DateTime base) {
    final now = DateTime.now();
    return base.isAfter(now) ? base : base.add(Duration(days: 1));
  }

  @override
  Map<String, dynamic> toJson() => {'type': 'daily'};
}

class WeeklySchedule extends AlarmSchedule {
  final List<int> weekdays; // 1=Mon, 7=Sun
  const WeeklySchedule(this.weekdays);
  @override
  DateTime? getNextOccurrence(DateTime base) {
    final now = DateTime.now();
    for (int i = 0; i < 14; i++) {
      final dt = base.add(Duration(days: i));
      if (dt.isAfter(now) && weekdays.contains(dt.weekday)) {
        return dt;
      }
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() => {'type': 'weekly', 'weekdays': weekdays};
}

class DatesSchedule extends AlarmSchedule {
  final List<DateTime> dates;
  const DatesSchedule(this.dates);
  @override
  DateTime? getNextOccurrence(DateTime base) {
    final now = DateTime.now();
    for (final d in dates) {
      final dt = DateTime(d.year, d.month, d.day, base.hour, base.minute);
      if (dt.isAfter(now)) return dt;
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'dates',
    'dates': dates.map((d) => d.toIso8601String()).toList(),
  };
}

class RangeSchedule extends AlarmSchedule {
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final int? intervalDays;
  const RangeSchedule(this.rangeStart, this.rangeEnd, this.intervalDays);
  @override
  DateTime? getNextOccurrence(DateTime base) {
    if (rangeStart == null || rangeEnd == null || intervalDays == null)
      return null;
    final now = DateTime.now();
    DateTime dt = DateTime(
      rangeStart!.year,
      rangeStart!.month,
      rangeStart!.day,
      base.hour,
      base.minute,
    );
    while (dt.isBefore(rangeEnd!) || dt.isAtSameMomentAs(rangeEnd!)) {
      if (dt.isAfter(now)) return dt;
      dt = dt.add(Duration(days: intervalDays!));
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'range',
    'rangeStart': rangeStart?.toIso8601String(),
    'rangeEnd': rangeEnd?.toIso8601String(),
    'intervalDays': intervalDays,
  };
}

// Update computeNextOccurrences to use AlarmSchedule
List<DateTime> computeNextOccurrences(CustomAlarm alarm, {int max = 10}) {
  final now = DateTime.now();
  final base = alarm.settings.dateTime;
  final List<DateTime> result = [];
  AlarmSchedule schedule;
  switch (alarm.recurrence.type) {
    case AlarmRecurrenceType.once:
      schedule = OnceSchedule();
      break;
    case AlarmRecurrenceType.daily:
      schedule = DailySchedule();
      break;
    case AlarmRecurrenceType.weekly:
      schedule = WeeklySchedule(alarm.recurrence.weekdays ?? []);
      break;
    case AlarmRecurrenceType.specificDates:
      schedule = DatesSchedule(alarm.recurrence.specificDates ?? []);
      break;
    case AlarmRecurrenceType.dateRange:
      schedule = RangeSchedule(
        alarm.recurrence.rangeStart,
        alarm.recurrence.rangeEnd,
        alarm.recurrence.rangeIntervalDays,
      );
      break;
  }
  DateTime? next = schedule.getNextOccurrence(base);
  int count = 0;
  while (next != null && count < max) {
    result.add(next);
    count++;
    // For recurring schedules, get the next one after this
    if (schedule is DailySchedule) {
      next = next.add(Duration(days: 1));
      if (next.isAfter(now)) result.add(next);
      break;
    } else if (schedule is WeeklySchedule) {
      next = next.add(Duration(days: 7));
      if (next.isAfter(now)) result.add(next);
      break;
    } else if (schedule is RangeSchedule) {
      next = next.add(Duration(days: schedule.intervalDays ?? 1));
      if (next.isAfter(now)) result.add(next);
      break;
    } else {
      break;
    }
  }
  return result;
}

// 1. Storage utility for alarms and tasks
class AlarmStorage {
  static const String alarmsFile = 'alarms.json';

  static Future<List<CustomAlarm>> loadAlarms() async {
    try {
      final file = File(alarmsFile);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => CustomAlarm.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveAlarms(List<CustomAlarm> alarms) async {
    final file = File(alarmsFile);
    final jsonList = alarms.map((a) => a.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }
}

// 2. AlarmTaskType and AlarmTask
enum AlarmTaskType { math, retype, sequence, memory, timeBased }

class AlarmTask {
  final AlarmTaskType type;
  final Map<String, dynamic> settings;
  AlarmTask({required this.type, required this.settings});

  factory AlarmTask.fromJson(Map<String, dynamic> json) => AlarmTask(
    type: AlarmTaskType.values[json['type'] ?? 0],
    settings: Map<String, dynamic>.from(json['settings'] ?? {}),
  );
  Map<String, dynamic> toJson() => {'type': type.index, 'settings': settings};
}

// 3. Refactor CustomAlarm to support tasks and improved recurrence
class CustomAlarm {
  final AlarmSettings settings;
  final AlarmRecurrence recurrence;
  final List<AlarmTask> tasks;
  final bool enabled;
  CustomAlarm({
    required this.settings,
    required this.recurrence,
    this.tasks = const [],
    this.enabled = true,
  });

  factory CustomAlarm.fromJson(Map<String, dynamic> json) => CustomAlarm(
    settings: AlarmSettings.fromJson(
      Map<String, dynamic>.from(json['settings']),
    ),
    recurrence: AlarmRecurrence.fromJson(json['recurrence']),
    tasks:
        (json['tasks'] as List?)
            ?.map((e) => AlarmTask.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [],
    enabled: json['enabled'] ?? true,
  );
  Map<String, dynamic> toJson() => {
    'settings': settings.toJson(),
    'recurrence': recurrence.toJson(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'enabled': enabled,
  };
}

final alarmListProvider =
    StateNotifierProvider<AlarmListNotifier, List<CustomAlarm>>((ref) {
      return AlarmListNotifier();
    });

// --- RingtonePlayer utility ---
class RingtonePlayer {
  static final AudioPlayer _player = AudioPlayer();
  static bool _initialized = false;

  static Future<void> _init() async {
    if (!_initialized) {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _initialized = true;
    }
  }

  static Future<void> play(String path) async {
    await _init();
    if (path.startsWith('assets/')) {
      await _player.setAudioSource(AudioSource.asset(path));
    } else {
      await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
    }
    await _player.setLoopMode(LoopMode.one);
    await _player.play();
  }

  static Future<void> stop() async {
    await _player.stop();
  }
}
