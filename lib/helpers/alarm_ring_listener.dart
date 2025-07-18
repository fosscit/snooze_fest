import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snooze_fest/widgets/equation_diffuse_dialog.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:snooze_fest/helpers/alarm_provider.dart'; // For CustomAlarm
import 'package:snooze_fest/app.dart' show AlarmRecurrence;
import 'package:flutter/services.dart';

class AlarmRingListener extends ConsumerStatefulWidget {
  /*
    A widget that listens for ringing alarms.
    When an alarm rings,
    it shows a dialog (EquationDiffuseDialog) that requires the user to solve a math equation to 
    dismiss the alarm.
  */
  final Widget child;
  const AlarmRingListener({required this.child, super.key});
  @override
  ConsumerState<AlarmRingListener> createState() => _AlarmRingListenerState();
}

class _AlarmRingListenerState extends ConsumerState<AlarmRingListener> {
  static const _alarmServiceChannel = MethodChannel('alarm_foreground_service');
  StreamSubscription<AlarmSet>? _alarmSub;
  final Set<int> _handledAlarmIds = {};
  int? _currentRingingAlarmId;

  @override
  void initState() {
    super.initState();
    _alarmSub = Alarm.ringing.listen(_onAlarmRinging);
  }

  void _onAlarmRinging(AlarmSet alarmSet) async {
    if (!mounted) return;
    final currentIds = alarmSet.alarms.map((a) => a.id).toSet();
    final newAlarms = alarmSet.alarms.where(
      (a) => !_handledAlarmIds.contains(a.id),
    );
    for (final alarm in newAlarms) {
      _handledAlarmIds.add(alarm.id);
      // Only start the service if not already running for this alarm
      if (_currentRingingAlarmId != alarm.id) {
        _currentRingingAlarmId = alarm.id;
        await _alarmServiceChannel.invokeMethod('startService', {
          'vibrate': alarm.vibrate,
          'audioPath': alarm.assetAudioPath,
          'alarmId': alarm.id,
        });
      }
      // Find the full CustomAlarm by id to get tasks
      final alarms = ref.read(alarmListProvider);
      print('Ringing alarm id: ${alarm.id}');
      print('CustomAlarm ids: ${alarms.map((a) => a.settings.id).toList()}');
      final customAlarm = alarms.firstWhere(
        (a) => a.settings.id == alarm.id,
        orElse: () => CustomAlarm(
          settings: alarm,
          recurrence: AlarmRecurrence.once(),
          tasks: [],
        ),
      );
      print('Matched CustomAlarm tasks: ${customAlarm.tasks}');
      // ignore: use_build_context_synchronously
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => EquationDiffuseDialog(
            alarm: alarm,
            tasks: customAlarm.tasks,
            onDismissed: () async {
              _handledAlarmIds.remove(alarm.id);
              // Only stop the service if this alarm is the one currently ringing
              if (_currentRingingAlarmId == alarm.id) {
                await _alarmServiceChannel.invokeMethod('stopService');
                _currentRingingAlarmId = null;
              }
            },
          ),
        ),
      );
    }
    // Remove handled alarms that are no longer ringing
    _handledAlarmIds.removeWhere((id) => !currentIds.contains(id));
  }

  @override
  void dispose() {
    _alarmSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
