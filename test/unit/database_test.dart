/// Database Service Unit Tests
/// 
/// Tests core database operations
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_logger/core/models/log_entry.dart';

void main() {
  group('LogEntry Model', () {
    test('should serialize to map correctly', () {
      final entry = LogEntry(
        id: 'test-id-123',
        pluginId: 'todo',
        timestamp: DateTime(2024, 12, 12, 10, 30),
        date: '2024-12-12',
        data: {'text': 'Test task', 'done': false},
      );

      final map = entry.toMap();

      expect(map['id'], 'test-id-123');
      expect(map['plugin_id'], 'todo');
      expect(map['date'], '2024-12-12');
      expect(map['data'], contains('Test task'));
    });

    test('should deserialize from map correctly', () {
      final map = {
        'id': 'test-id-456',
        'plugin_id': 'mood',
        'timestamp': DateTime(2024, 12, 12, 15, 0).millisecondsSinceEpoch,
        'date': '2024-12-12',
        'data': '{"score": 4, "time": "15:00"}',
      };

      final entry = LogEntry.fromMap(map);

      expect(entry.id, 'test-id-456');
      expect(entry.pluginId, 'mood');
      expect(entry.date, '2024-12-12');
      expect(entry.data['score'], 4);
      expect(entry.data['time'], '15:00');
    });

    test('should handle round-trip serialization', () {
      final original = LogEntry(
        id: 'round-trip-test',
        pluginId: 'pomodoro',
        timestamp: DateTime.now(),
        date: '2024-12-12',
        data: {'duration': 25, 'task': 'Focus work'},
      );

      final map = original.toMap();
      final restored = LogEntry.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.pluginId, original.pluginId);
      expect(restored.date, original.date);
      expect(restored.data['duration'], original.data['duration']);
      expect(restored.data['task'], original.data['task']);
    });
  });

  group('LogEntry Data Types', () {
    test('should handle integer data', () {
      final entry = LogEntry(
        id: 'int-test',
        pluginId: 'water',
        timestamp: DateTime.now(),
        date: '2024-12-12',
        data: {'amount': 250},
      );

      final restored = LogEntry.fromMap(entry.toMap());
      expect(restored.data['amount'], 250);
    });

    test('should handle boolean data', () {
      final entry = LogEntry(
        id: 'bool-test',
        pluginId: 'habit',
        timestamp: DateTime.now(),
        date: '2024-12-12',
        data: {'completed': true, 'skipped': false},
      );

      final restored = LogEntry.fromMap(entry.toMap());
      expect(restored.data['completed'], true);
      expect(restored.data['skipped'], false);
    });

    test('should handle string data with special characters', () {
      final entry = LogEntry(
        id: 'special-char-test',
        pluginId: 'quick_note',
        timestamp: DateTime.now(),
        date: '2024-12-12',
        data: {'text': '日本語テスト 🎉 "quotes" & symbols'},
      );

      final restored = LogEntry.fromMap(entry.toMap());
      expect(restored.data['text'], '日本語テスト 🎉 "quotes" & symbols');
    });
  });
}
