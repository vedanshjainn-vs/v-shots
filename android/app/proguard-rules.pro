# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Supabase
-keep class io.supabase.** { *; }

# Freezed
-keep class **$Freezed { *; }
-keep class **$*$ { *; }

# JSON Serializable
-keep class **$*.g.dart { *; }
-keep class **$*.freezed.dart { *; }

# Dio
-keep class com.squareup.okhttp3.** { *; }
-keep class okhttp3.** { *; }
