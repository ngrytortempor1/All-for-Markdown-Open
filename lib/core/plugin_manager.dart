/// Plugin Manager
/// 
/// Manages plugin lifecycle, enabled/disabled state, and provides
/// a clean interface for plugins to interact with the core via DB only
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'plugin_interface.dart';

/// Plugin configuration stored in preferences
class PluginConfig {
  final String pluginId;
  final bool enabled;
  final int order;

  PluginConfig({
    required this.pluginId,
    required this.enabled,
    required this.order,
  });

  PluginConfig copyWith({bool? enabled, int? order}) {
    return PluginConfig(
      pluginId: pluginId,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
    );
  }
}

/// Plugin Manager - sole gateway between plugins and core
class PluginManager extends ChangeNotifier {
  static PluginManager? _instance;
  static PluginManager get instance => _instance ??= PluginManager._();
  
  PluginManager._();

  final List<MarkdownLoggerPlugin> _availablePlugins = [];
  final Map<String, PluginConfig> _configs = {};
  bool _initialized = false;

  /// Initialize the plugin manager
  Future<void> initialize(List<MarkdownLoggerPlugin> plugins) async {
    if (_initialized) return;
    
    _availablePlugins.clear();
    _availablePlugins.addAll(plugins);
    
    await _loadConfigs();
    _initialized = true;
    notifyListeners();
  }

  /// Load plugin configurations from persistent storage
  Future<void> _loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    
    for (var i = 0; i < _availablePlugins.length; i++) {
      final plugin = _availablePlugins[i];
      final enabledKey = 'plugin_${plugin.id}_enabled';
      final orderKey = 'plugin_${plugin.id}_order';
      
      _configs[plugin.id] = PluginConfig(
        pluginId: plugin.id,
        enabled: prefs.getBool(enabledKey) ?? true, // Default: enabled
        order: prefs.getInt(orderKey) ?? i,
      );
    }
  }

  /// Save plugin configuration
  Future<void> _saveConfig(PluginConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('plugin_${config.pluginId}_enabled', config.enabled);
    await prefs.setInt('plugin_${config.pluginId}_order', config.order);
    notifyListeners();
  }

  /// Get all available plugins
  List<MarkdownLoggerPlugin> get allPlugins => List.unmodifiable(_availablePlugins);

  /// Get only enabled plugins (sorted by order)
  List<MarkdownLoggerPlugin> get enabledPlugins {
    final enabled = _availablePlugins
        .where((p) => _configs[p.id]?.enabled ?? true)
        .toList();
    enabled.sort((a, b) {
      final orderA = _configs[a.id]?.order ?? 0;
      final orderB = _configs[b.id]?.order ?? 0;
      return orderA.compareTo(orderB);
    });
    return enabled;
  }

  /// Check if a plugin is enabled
  bool isEnabled(String pluginId) {
    return _configs[pluginId]?.enabled ?? true;
  }

  /// Enable a plugin
  Future<void> enablePlugin(String pluginId) async {
    final config = _configs[pluginId];
    if (config != null && !config.enabled) {
      _configs[pluginId] = config.copyWith(enabled: true);
      await _saveConfig(_configs[pluginId]!);
    }
  }

  /// Disable a plugin
  Future<void> disablePlugin(String pluginId) async {
    final config = _configs[pluginId];
    if (config != null && config.enabled) {
      _configs[pluginId] = config.copyWith(enabled: false);
      await _saveConfig(_configs[pluginId]!);
    }
  }

  /// Toggle plugin enabled state
  Future<void> togglePlugin(String pluginId) async {
    if (isEnabled(pluginId)) {
      await disablePlugin(pluginId);
    } else {
      await enablePlugin(pluginId);
    }
  }

  /// Get plugin by ID
  MarkdownLoggerPlugin? getPlugin(String pluginId) {
    try {
      return _availablePlugins.firstWhere((p) => p.id == pluginId);
    } catch (e) {
      return null;
    }
  }

  /// Get plugin config
  PluginConfig? getConfig(String pluginId) => _configs[pluginId];
}
