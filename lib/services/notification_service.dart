
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    final windowsSettings = WindowsInitializationSettings(
      appName: 'Class Schedule',
      appUserModelId: 'com.example.class_schedule_app',
      guid: 'a4f29c61-7d82-4e56-9b31-2c8f5e6a1047',
    );

    final settings = InitializationSettings(
      android: androidSettings,
      windows: windowsSettings,
    );

    await _notifications.initialize(settings: settings);

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
  }

  static Future<void> scheduleClassReminder({
    required int id,
    required String subject,
    required DateTime classStart,
    required int minutesBefore,
  }) async {
    final reminderTime = classStart.subtract(
      Duration(minutes: minutesBefore),
    );

    if (!reminderTime.isAfter(DateTime.now())) {
      return;
    }

    await _notifications.zonedSchedule(
      id: id,
      title: 'Upcoming Class',
      body: '$subject starts in $minutesBefore minutes.',
      scheduledDate: tz.TZDateTime.from(
        reminderTime,
        tz.local,
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'class_reminders',
          'Class Reminders',
          channelDescription: 'Notifications before scheduled classes.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelReminder(int id) async {
    await _notifications.cancel(id: id);
  }
}
