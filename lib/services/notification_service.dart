// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> showBroadcastNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'kostify_broadcasts',
      'Broadcast Kostify',
      channelDescription: 'Notifikasi broadcast untuk tenant Kostify',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}
