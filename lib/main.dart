import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alarm/alarm.dart';
import 'package:snooze_fest/helpers/utils.dart';
import 'package:snooze_fest/app.dart';
import 'package:get_storage/get_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await Alarm.init();
  await requestNotificationPermission();
  runApp(const ProviderScope(child: App()));
}
