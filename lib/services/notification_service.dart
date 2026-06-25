import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
  );

  static Future<void> initialize() async {
    // Request permission for iOS/Android 13+
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted permission');
      }

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: DarwinInitializationSettings(),
      );
      
      // Fixing the initialization settings (I see a potential typo in my mind, let's check current code)

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle notification tap
        },
      );

      // Create Android Notification Channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Set foreground notification options for Firebase
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // On iOS, APNS token can take a moment to arrive
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      // Save token to Supabase
      String? token = await _messaging.getToken();
      if (token != null) {
        await SupabaseService.updateFcmToken(token);
      }

      // Handle token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        SupabaseService.updateFcmToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null && !kIsWeb) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: android.smallIcon ?? '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
          );
        }
      });

      // Handle message when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('App opened from notification: ${message.messageId}');
        }
      });
    }
  }

  static Future<void> showNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
    );
  }

  static Future<String?> getToken() async {
    return await _messaging.getToken();
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
            final newStatus = payload.newRecord['status'];
            final oldStatus = payload.oldRecord['status'];

            if (newStatus != oldStatus) {
              String title = 'Order Update 🍕';
              String body = '';

              switch (newStatus.toString().toLowerCase()) {
                case 'preparing':
                  body = 'Great news! Your order has been accepted and is now being prepared.';
                  break;
                case 'out_for_delivery':
                  body = 'Your delicious pizza is on the way! 🛵';
                  break;
                case 'delivered':
                  body = 'Enjoy your meal! Your order has been delivered. 🎁';
                  title = 'Order Delivered!';
                  break;
                case 'cancelled':
                  body = 'Sorry, your order was rejected or cancelled. ❌';
                  title = 'Order Update';
                  break;
                default:
                  return;
              }

              showNotification(title: title, body: body);
            }
          },
        )
        .subscribe();
  }
}
