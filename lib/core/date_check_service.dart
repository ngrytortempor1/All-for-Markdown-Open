/// Date Check Service
/// 
/// Handles date change detection and markdown generation on app start
library;

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/markdown_generator.dart';

class DateCheckService {
  static const String _lastDateKey = 'last_active_date';

  /// Check if date has changed since last app launch
  /// If so, generate markdown for the previous day
  static Future<void> checkAndGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString(_lastDateKey);

    if (lastDate != null && lastDate != today) {
      // Date has changed, generate markdown for previous date
      final previousDate = DateTime.parse(lastDate);
      await MarkdownGenerator.generateDailyMarkdown(previousDate);
    }

    // Update last active date
    await prefs.setString(_lastDateKey, today);
  }
}
