# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Dart classes
-dontwarn io.flutter.embedding.**

# Health Connect
-keep class androidx.health.connect.** { *; }

# SQLite
-keep class io.requery.android.database.** { *; }
