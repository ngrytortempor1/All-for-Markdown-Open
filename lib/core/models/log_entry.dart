/// Log Entry Model
/// 
/// Unified data structure for all plugin entries
library;

import 'dart:convert';

class LogEntry {
  final String id;
  final String pluginId;
  final DateTime timestamp;
  final String date;
  final Map<String, dynamic> data;

  LogEntry({
    required this.id,
    required this.pluginId,
    required this.timestamp,
    required this.date,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plugin_id': pluginId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'date': date,
      'data': jsonEncode(data),
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'] as String,
      pluginId: map['plugin_id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      date: map['date'] as String,
      data: jsonDecode(map['data'] as String) as Map<String, dynamic>,
    );
  }
}
