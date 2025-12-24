/// Plugin Interface
/// 
/// Base interface that all plugins must implement
library;

import 'package:flutter/material.dart';
import 'models/log_entry.dart';

abstract class MarkdownLoggerPlugin {
  /// Unique identifier for this plugin
  String get id;
  
  /// Display name shown in UI
  String get name;
  
  /// Icon for this plugin
  IconData get icon;
  
  /// Short description
  String get description;
  
  /// Build the main widget for this plugin
  Widget buildWidget(BuildContext context);
  
  /// Build a compact widget for dashboard
  Widget buildCompactWidget(BuildContext context);
  
  /// Get all entries for a specific date
  Future<List<LogEntry>> getEntries(DateTime date);
  
  /// Save a new entry
  Future<void> saveEntry(LogEntry entry);
  
  /// Delete an entry
  Future<void> deleteEntry(String id);
}
