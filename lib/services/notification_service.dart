import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'supabase_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> initialize() async {
    try {
      // 1. Initialize Local Notifications FIRST
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('icon');
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: DarwinInitializationSettings(),
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification tapped: ${details.payload}');
        },
      );

      // 2. Create Channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // 3. Request Permissions (Popup only on Android 13+)
      if (defaultTargetPlatform == TargetPlatform.android) {
        // This will automatically do nothing on Android 12 and below
        await Permission.notification.request();
      } else {
        await _messaging.requestPermission(alert: true, badge: true, sound: true);
      }

      // 4. Foreground Notification Options
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Setup Token & Listeners
      await updateTokenToServer();

      _messaging.onTokenRefresh.listen((newToken) {
        SupabaseService.updateFcmToken(newToken);
      });

      // 6. Handle Incoming Messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      debugPrint('Notification Service Initialized Successfully');
    } catch (e) {
      debugPrint('Notification Init Error: $e');
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && !kIsWeb) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: android?.smallIcon ?? 'icon',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
      );
    }
  }

  static Future<void> showNotification({required String title, required String body}) async {
    try {
      // Use a more unique but valid 32-bit ID
      final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      await _localNotifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            icon: 'icon',
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  static Future<void> updateTokenToServer() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        // Only update if Supabase is initialized
        try {
          await SupabaseService.updateFcmToken(token);
        } catch (e) {
          debugPrint('Supabase Token Update Error: $e');
        }
      }
    } catch (e) {
      debugPrint('FCM Token Fetch Error: $e');
    }
  }

  static void listenToOrderStatus() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Supabase.instance.client
        .channel('order_status_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'].toString().toLowerCase();
            String title = 'Order Update 🍕';
            String body = '';

            if (status == 'preparing') body = 'Your order is being prepared!';
            else if (status == 'out_for_delivery') body = 'Your pizza is on the way! 🛵';
            else if (status == 'delivered') body = 'Order delivered. Enjoy! 🎁';
            else if (status == 'cancelled') body = 'Order was cancelled. ❌';

            if (body.isNotEmpty) {
              showNotification(title: title, body: body);
            }
          },
        )
        .subscribe();
  }
}
