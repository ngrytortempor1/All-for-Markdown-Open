/// Plugin Registry Tests
/// 
/// Verifies all plugins are registered and have correct properties
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_logger/core/plugin_registry.dart';

void main() {
  group('Plugin Registry', () {
    test('should have at least 6 plugins registered', () {
      expect(PluginRegistry.plugins.length, greaterThanOrEqualTo(6));
    });

    test('all plugins should have unique IDs', () {
      final ids = PluginRegistry.plugins.map((p) => p.id).toList();
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, ids.length, reason: 'Duplicate plugin IDs found');
    });

    test('all plugins should have non-empty names', () {
      for (final plugin in PluginRegistry.plugins) {
        expect(plugin.name.isNotEmpty, true, reason: '${plugin.id} has empty name');
      }
    });

    test('all plugins should have non-empty descriptions', () {
      for (final plugin in PluginRegistry.plugins) {
        expect(plugin.description.isNotEmpty, true, 
          reason: '${plugin.id} has empty description');
      }
    });

    test('getPlugin should return correct plugin by ID', () {
      final todoPlugin = PluginRegistry.getPlugin('todo');
      expect(todoPlugin, isNotNull);
      expect(todoPlugin!.id, 'todo');
      expect(todoPlugin.name, 'Todo');
    });

    test('getPlugin should return null for unknown ID', () {
      final unknown = PluginRegistry.getPlugin('nonexistent_plugin');
      expect(unknown, isNull);
    });
  });

  group('Required Plugins', () {
    test('Todo plugin should be registered', () {
      final plugin = PluginRegistry.getPlugin('todo');
      expect(plugin, isNotNull);
    });

    test('Mood plugin should be registered', () {
      final plugin = PluginRegistry.getPlugin('mood');
      expect(plugin, isNotNull);
    });

    test('Pomodoro plugin should be registered', () {
      final plugin = PluginRegistry.getPlugin('pomodoro');
      expect(plugin, isNotNull);
    });

    test('Quick Note plugin should be registered', () {
      final plugin = PluginRegistry.getPlugin('quick_note');
      expect(plugin, isNotNull);
    });

    test('Water plugin should be registered', () {
      final plugin = PluginRegistry.getPlugin('water');
      expect(plugin, isNotNull);
    });

    test('Habit plugin should be registered', () {
      final plugin = PluginRegistry.getPlugin('habit');
      expect(plugin, isNotNull);
    });
  });
}
