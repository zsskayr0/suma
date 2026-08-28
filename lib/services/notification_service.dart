import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// "Lembretes de pesagem" - local notifications on chosen weekdays/times
/// (see AppState.notif* fields, set from Ajustes). Entirely device-local,
/// same as [AppState.themePref] - nothing about this syncs through the
/// account.
///
/// Real, repeating OS-level scheduling only works on Android: AlarmManager
/// keeps firing on schedule even with Suma closed, and survives reboots via
/// the boot receiver registered in AndroidManifest.xml. Windows has no
/// equivalent for a plain (non-MSIX-packaged) desktop app - a scheduled
/// Windows toast doesn't repeat on its own, and there's no reliable way to
/// keep re-arming it while Suma isn't running - so [scheduleWeekly] is a
/// deliberate no-op there. Ajustes tells the user reminders need Suma open
/// on Windows instead of silently pretending they'll arrive in the
/// background.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'suma_weigh_in';
  static const _channelName = 'Lembretes de pesagem';
  static const _channelDescription = 'Lembra você de registrar seu peso nos dias e horários escolhidos.';

  // Stable per-weekday ids (DateTime.weekday: 1=Mon..7=Sun) so a
  // reschedule can be a clean cancel-and-replace.
  static int _idFor(int weekday) => 900 + weekday;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // Falls back to the `timezone` package's own default (UTC) - better
      // than failing init over a lookup hiccup on some odd device/VM.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: WindowsInitializationSettings(
          appName: 'Suma',
          appUserModelId: 'Suma.WeightTracker.Desktop',
          guid: '5c2f2b0a-6e0a-4d0c-9a7a-9a6b7a6a2b39',
        ),
      ),
    );
    _initialized = true;
  }

  /// Android 13+ requires runtime consent to post notifications at all;
  /// exact-alarm access (12+) is requested too but is best-effort and never
  /// blocks turning reminders on - landing a couple minutes late is fine
  /// for a "peça pra se pesar" nudge. Windows never gates local
  /// notifications behind a prompt, so this is a no-op there.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    return granted ?? true;
  }

  Future<void> scheduleWeekly({required Set<int> weekdays, required int hour, required int minute}) async {
    await _plugin.cancelAll();
    if (!Platform.isAndroid || weekdays.isEmpty) return; // see class doc
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    for (final weekday in weekdays) {
      await _plugin.zonedSchedule(
        id: _idFor(weekday),
        title: 'Hora de se pesar ⚖️',
        body: 'Registre seu peso de hoje no Suma.',
        scheduledDate: _nextInstanceOf(weekday, hour, minute),
        notificationDetails: details,
        androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  tz.TZDateTime _nextInstanceOf(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
