/// Plugin Registry
/// 
/// Manages all available plugins
library;

import 'package:markdown_logger/core/plugin_interface.dart';
import 'package:markdown_logger/plugins/todo/todo_plugin.dart';
import 'package:markdown_logger/plugins/mood/mood_plugin.dart';
import 'package:markdown_logger/plugins/quick_note/quick_note_plugin.dart';
import 'package:markdown_logger/plugins/pomodoro/pomodoro_plugin.dart';
import 'package:markdown_logger/plugins/water/water_plugin.dart';
import 'package:markdown_logger/plugins/habit/habit_plugin.dart';
import 'package:markdown_logger/plugins/sleep/sleep_plugin.dart';
import 'package:markdown_logger/plugins/workout/workout_plugin.dart';
import 'package:markdown_logger/plugins/expense/expense_plugin.dart';
import 'package:markdown_logger/plugins/reading/reading_plugin.dart';
import 'package:markdown_logger/plugins/meal/meal_plugin.dart';
import 'package:markdown_logger/plugins/health/health_plugin.dart';
import 'package:markdown_logger/plugins/battery/battery_plugin.dart';
import 'package:markdown_logger/plugins/weather/weather_plugin.dart';
import 'package:markdown_logger/plugins/screen_time/screen_time_plugin.dart';
import 'package:markdown_logger/plugins/gacha/gacha_plugin.dart';

class PluginRegistry {
  static final List<MarkdownLoggerPlugin> plugins = [
    // Core productivity
    TodoPlugin(),
    HabitPlugin(),
    PomodoroPlugin(),
    QuickNotePlugin(),
    
    // Health & Wellness
    MoodPlugin(),
    WaterPlugin(),
    SleepPlugin(),
    WorkoutPlugin(),
    MealPlugin(),
    HealthPlugin(),
    
    // Lifestyle
    ExpensePlugin(),
    ReadingPlugin(),
    GachaPlugin(),  // New: Game currency tracker
    
    // Auto-tracking
    BatteryPlugin(),
    WeatherPlugin(),
    ScreenTimePlugin(),
  ];

  static MarkdownLoggerPlugin? getPlugin(String id) {
    try {
      return plugins.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}
