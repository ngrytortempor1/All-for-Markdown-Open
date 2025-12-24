/// Markdown Generator Service
/// 
/// Converts database entries to Markdown files with Obsidian links
library;

import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class MarkdownGenerator {
  static const String _rootFolderName = 'MarkdownLogger';
  static const String _customPathKey = 'markdown_save_path';

  /// Get custom save path from preferences
  static Future<String?> getCustomPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customPathKey);
  }

  /// Set custom save path
  static Future<void> setCustomPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(_customPathKey);
    } else {
      await prefs.setString(_customPathKey, path);
    }
  }

  /// Get the default storage root path
  static Future<String> getDefaultRootPath() async {
    final extDir = await getExternalStorageDirectory();
    if (extDir == null) {
      throw Exception('External storage not available');
    }
    final rootPath = extDir.path.split('Android')[0];
    return '$rootPath$_rootFolderName';
  }

  /// Get current save path (custom or default)
  static Future<String> getCurrentPath() async {
    final customPath = await getCustomPath();
    if (customPath != null && customPath.isNotEmpty) {
      return customPath;
    }
    return getDefaultRootPath();
  }

  /// Get the root directory for markdown files
  static Future<Directory> getRootDirectory() async {
    // Request storage permission
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      throw Exception('Storage permission denied');
    }

    final path = await getCurrentPath();
    final mdDir = Directory(path);
    
    if (!await mdDir.exists()) {
      await mdDir.create(recursive: true);
    }
    
    return mdDir;
  }

  /// Generate daily markdown file
  static Future<void> generateDailyMarkdown(DateTime date) async {
    final root = await getRootDirectory();
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    
    // Create directory structure: year/month/
    final monthDir = Directory('${root.path}/$year/$month');
    if (!await monthDir.exists()) {
      await monthDir.create(recursive: true);
    }

    // Get entries for this date
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final entries = await DatabaseService.getEntriesByDate(dateStr);
    
    // Generate markdown content
    final content = _buildDailyMarkdown(date, entries);
    
    // Write to file
    final file = File('${monthDir.path}/$day.md');
    await file.writeAsString(content);
    
    // Update summary files
    await _updateWeeklySummary(date, root);
    await _updateMonthlySummary(date, root);
    await _updateYearlySummary(date, root);
  }

  static String _buildDailyMarkdown(DateTime date, List<Map<String, dynamic>> entries) {
    final dateStr = DateFormat('yyyy年M月d日 (E)', 'ja').format(date);
    final buffer = StringBuffer();
    
    buffer.writeln('# $dateStr');
    buffer.writeln();
    
    // Group entries by plugin
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final entry in entries) {
      final pluginId = entry['plugin_id'] as String;
      grouped.putIfAbsent(pluginId, () => []);
      grouped[pluginId]!.add(entry);
    }
    
    // Generate sections for each plugin
    for (final pluginId in grouped.keys) {
      final pluginEntries = grouped[pluginId]!;
      buffer.writeln('## ${_getPluginDisplayName(pluginId)}');
      buffer.writeln();
      
      for (final entry in pluginEntries) {
        final data = jsonDecode(entry['data'] as String) as Map<String, dynamic>;
        buffer.writeln(_formatPluginEntry(pluginId, data));
      }
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  static String _getPluginDisplayName(String pluginId) {
    const names = {
      'todo': '📋 Todo',
      'pomodoro': '🍅 Pomodoro',
      'mood': '😊 Mood',
      'habit': '✅ Habit',
      'quick_note': '📝 Quick Note',
      'water': '💧 Water',
      'meal': '🍽️ Meal',
      'workout': '🏃 Workout',
      'sleep': '😴 Sleep',
      'expense': '💰 Expense',
      'reading': '📚 Reading',
      'health': '❤️ Health',
    };
    return names[pluginId] ?? pluginId;
  }

  static String _formatPluginEntry(String pluginId, Map<String, dynamic> data) {
    switch (pluginId) {
      case 'todo':
        final done = data['done'] == true;
        final text = data['text'] ?? '';
        return '- [${done ? 'x' : ' '}] $text';
      case 'mood':
        final score = data['score'] ?? 3;
        final emojis = ['😢', '😕', '😐', '🙂', '😊'];
        return '- ${emojis[score.clamp(0, 4)]} (${data['time'] ?? ''})';
      case 'quick_note':
        return '- ${data['text'] ?? ''}';
      case 'water':
        return '- ${data['amount'] ?? 0}ml';
      case 'pomodoro':
        return '- ${data['duration'] ?? 25}min: ${data['task'] ?? 'Focus'}';
      case 'habit':
        return '- ✅ ${data['habitId'] ?? ''} (${data['completedAt'] ?? ''})';
      case 'sleep':
        final type = data['type'] == 'bed' ? '就寝' : '起床';
        return '- $type: ${data['time'] ?? ''}';
      case 'workout':
        return '- ${data['icon'] ?? '⚡'} ${data['typeName'] ?? ''}: ${data['duration'] ?? 0}分';
      case 'expense':
        return '- ${data['icon'] ?? '📦'} ¥${data['amount'] ?? 0} (${data['categoryName'] ?? ''}) ${data['memo'] ?? ''}';
      case 'reading':
        return '- 📖 ${data['title'] ?? ''}: ${data['pages'] ?? 0}ページ';
      case 'meal':
        final memo = data['memo'] as String? ?? '';
        return '- ${data['icon'] ?? '🍽️'} ${data['typeName'] ?? ''}${memo.isNotEmpty ? ' - $memo' : ''}';
      default:
        return '- ${data.toString()}';
    }
  }

  static Future<void> _updateWeeklySummary(DateTime date, Directory root) async {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final weekNumber = _getWeekNumber(date);
    
    final monthDir = Directory('${root.path}/$year/$month');
    final file = File('${monthDir.path}/$year-W$weekNumber.md');
    
    final buffer = StringBuffer();
    buffer.writeln('# $year年 第$weekNumber週');
    buffer.writeln();
    buffer.writeln('## 日別リンク');
    
    // Get start and end of week
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    for (var i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      if (d.month == date.month) {
        final dayStr = d.day.toString().padLeft(2, '0');
        final dayName = DateFormat('E', 'ja').format(d);
        buffer.writeln('- [[$year/$month/$dayStr|${d.day}日 ($dayName)]]');
      }
    }
    
    await file.writeAsString(buffer.toString());
  }

  static Future<void> _updateMonthlySummary(DateTime date, Directory root) async {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    
    final monthDir = Directory('${root.path}/$year/$month');
    final file = File('${monthDir.path}/$year-$month.md');
    
    final buffer = StringBuffer();
    buffer.writeln('# $year年${date.month}月');
    buffer.writeln();
    buffer.writeln('## 週別リンク');
    
    // List all week files in directory
    if (await monthDir.exists()) {
      final weekFiles = monthDir.listSync()
        .whereType<File>()
        .where((f) => f.path.contains('-W'))
        .toList();
      
      for (final weekFile in weekFiles) {
        final weekName = weekFile.path.split('/').last.replaceAll('.md', '');
        buffer.writeln('- [[$year/$month/$weekName|$weekName]]');
      }
    }
    
    await file.writeAsString(buffer.toString());
  }

  static Future<void> _updateYearlySummary(DateTime date, Directory root) async {
    final year = date.year.toString();
    
    final file = File('${root.path}/$year/$year.md');
    
    final buffer = StringBuffer();
    buffer.writeln('# $year年 総括');
    buffer.writeln();
    buffer.writeln('## 月別リンク');
    
    for (var m = 1; m <= 12; m++) {
      final monthStr = m.toString().padLeft(2, '0');
      buffer.writeln('- [[$year/$monthStr/$year-$monthStr|$m月]]');
    }
    
    await file.writeAsString(buffer.toString());
  }

  static int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDiff = date.difference(firstDayOfYear).inDays;
    return ((daysDiff + firstDayOfYear.weekday - 1) / 7).ceil();
  }
}
