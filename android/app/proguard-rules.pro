# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / Postgrest / Realtime (JSON models)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.supabase.** { *; }

# Google Fonts
-keep class com.google.fonts.** { *; }

# Firebase & Notifications
-keep class com.google.firebase.** { *; }
-keep class com.dexterous.** { *; }
-keep class com.google.android.gms.internal.firebase_messaging.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class io.flutter.plugins.firebase.messaging.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.dexterous.**

# General Android
-dontwarn io.flutter.embedding.android.FlutterActivity
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
