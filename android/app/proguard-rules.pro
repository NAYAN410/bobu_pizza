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

# General Android
-dontwarn io.flutter.embedding.android.FlutterActivity
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
