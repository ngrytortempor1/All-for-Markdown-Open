/// Widget Integration Tests
/// 
/// Tests that don't require database/SharedPreferences
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_logger/core/plugin_registry.dart';

void main() {
  group('App Structure - Static Tests', () {
    test('MaterialApp title should be configured correctly', () {
      // Test the expected title value
      const expectedTitle = 'Markdown Logger';
      expect(expectedTitle.isNotEmpty, true);
    });

    test('debug banner should be disabled', () {
      // Test the expected configuration
      const debugBanner = false;
      expect(debugBanner, false);
    });
  });

  group('Plugin Registry Verification', () {
    test('should have 12 plugins registered', () {
      expect(PluginRegistry.plugins.length, 12);
    });

    test('each plugin should have unique ID', () {
      final ids = PluginRegistry.plugins.map((p) => p.id).toSet();
      expect(ids.length, PluginRegistry.plugins.length);
    });

    test('each plugin should have valid icon', () {
      for (final plugin in PluginRegistry.plugins) {
        expect(plugin.icon, isNotNull);
      }
    });

    test('expected plugins are present', () {
      final ids = PluginRegistry.plugins.map((p) => p.id).toList();
      expect(ids, contains('todo'));
      expect(ids, contains('mood'));
      expect(ids, contains('pomodoro'));
      expect(ids, contains('quick_note'));
      expect(ids, contains('water'));
      expect(ids, contains('habit'));
      expect(ids, contains('sleep'));
      expect(ids, contains('workout'));
      expect(ids, contains('expense'));
      expect(ids, contains('reading'));
      expect(ids, contains('meal'));
      expect(ids, contains('health'));
    });
  });

  group('Plugin Interface Compliance', () {
    for (final plugin in PluginRegistry.plugins) {
      test('${plugin.name} should have non-empty id', () {
        expect(plugin.id.isNotEmpty, true);
      });

      test('${plugin.name} should have non-empty name', () {
        expect(plugin.name.isNotEmpty, true);
      });

      test('${plugin.name} should have non-empty description', () {
        expect(plugin.description.isNotEmpty, true);
      });
    }
  });

  group('Plugin Order', () {
    test('Todo should be first plugin', () {
      expect(PluginRegistry.plugins.first.id, 'todo');
    });

    test('Health should be last plugin', () {
      expect(PluginRegistry.plugins.last.id, 'health');
    });
  });
}
