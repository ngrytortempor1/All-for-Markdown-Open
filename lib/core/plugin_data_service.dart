/// Plugin Data Service
/// 
/// Provides a clean abstraction for plugins to interact with the database.
/// Plugins should ONLY use this service - not DatabaseService directly.
/// This ensures loose coupling between plugins and core.
library;

import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'database/database_service.dart';
import 'models/log_entry.dart';

/// Abstract data service that plugins use to interact with core
/// This is the ONLY interface plugins should use for data operations
class PluginDataService {
  final String pluginId;
  
  PluginDataService(this.pluginId);

  /// Create a new log entry for this plugin
  Future<LogEntry> createEntry(Map<String, dynamic> data) async {
    final now = DateTime.now();
    final entry = LogEntry(
      id: const Uuid().v4(),
      pluginId: pluginId,
      timestamp: now,
      date: DateFormat('yyyy-MM-dd').format(now),
      data: data,
    );
    
    await DatabaseService.insertEntry(entry.toMap());
    return entry;
  }

  /// Get all entries for today
  Future<List<LogEntry>> getTodayEntries() async {
    return getEntriesForDate(DateTime.now());
  }

  /// Get entries for a specific date
  Future<List<LogEntry>> getEntriesForDate(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final maps = await DatabaseService.getEntriesByPlugin(pluginId, dateStr);
    return maps.map((m) => LogEntry.fromMap(m)).toList();
  }

  /// Update an existing entry
  Future<void> updateEntry(String entryId, Map<String, dynamic> data) async {
    // Get the existing entry first
    final existingMaps = await DatabaseService.getEntriesByDate(
      DateFormat('yyyy-MM-dd').format(DateTime.now())
    );
    
    for (final map in existingMaps) {
      if (map['id'] == entryId) {
        final updated = {
          ...map,
          'data': jsonEncode(data),
        };
        await DatabaseService.updateEntry(entryId, updated);
        return;
      }
    }
  }

  /// Delete an entry
  Future<void> deleteEntry(String entryId) async {
    await DatabaseService.deleteEntry(entryId);
  }

  /// Get entry count for today
  Future<int> getTodayCount() async {
    final entries = await getTodayEntries();
    return entries.length;
  }

  /// Get aggregated data for today (sum of numeric field)
  Future<num> getTodaySum(String field) async {
    final entries = await getTodayEntries();
    return entries.fold<num>(0, (sum, e) {
      final value = e.data[field];
      if (value is num) return sum + value;
      return sum;
    });
  }
}
