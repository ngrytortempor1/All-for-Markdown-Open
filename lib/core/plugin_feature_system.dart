/// Plugin Feature System
/// 
/// Allows plugins to have sub-features that can be enabled/disabled
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single feature within a plugin
class PluginFeature {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final bool defaultEnabled;

  const PluginFeature({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.defaultEnabled = true,
  });
}

/// Manages features for a specific plugin
class PluginFeatureManager extends ChangeNotifier {
  final String pluginId;
  final List<PluginFeature> availableFeatures;
  final Map<String, bool> _enabledFeatures = {};
  bool _initialized = false;

  PluginFeatureManager({
    required this.pluginId,
    required this.availableFeatures,
  });

  Future<void> initialize() async {
    if (_initialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    for (final feature in availableFeatures) {
      final key = 'plugin_${pluginId}_feature_${feature.id}';
      _enabledFeatures[feature.id] = prefs.getBool(key) ?? feature.defaultEnabled;
    }
    _initialized = true;
    notifyListeners();
  }

  bool isEnabled(String featureId) {
    return _enabledFeatures[featureId] ?? false;
  }

  Future<void> setEnabled(String featureId, bool enabled) async {
    _enabledFeatures[featureId] = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('plugin_${pluginId}_feature_$featureId', enabled);
    notifyListeners();
  }

  Future<void> toggle(String featureId) async {
    await setEnabled(featureId, !isEnabled(featureId));
  }
}

/// Widget to configure plugin features
class PluginFeatureSettings extends StatefulWidget {
  final String pluginName;
  final PluginFeatureManager featureManager;

  const PluginFeatureSettings({
    super.key,
    required this.pluginName,
    required this.featureManager,
  });

  @override
  State<PluginFeatureSettings> createState() => _PluginFeatureSettingsState();
}

class _PluginFeatureSettingsState extends State<PluginFeatureSettings> {
  @override
  void initState() {
    super.initState();
    widget.featureManager.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.featureManager.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.pluginName} 設定'),
      ),
      body: ListView.builder(
        itemCount: widget.featureManager.availableFeatures.length,
        itemBuilder: (context, index) {
          final feature = widget.featureManager.availableFeatures[index];
          final isEnabled = widget.featureManager.isEnabled(feature.id);

          return SwitchListTile(
            secondary: Icon(
              feature.icon,
              color: isEnabled ? Theme.of(context).colorScheme.primary : Colors.grey,
            ),
            title: Text(feature.name),
            subtitle: Text(feature.description),
            value: isEnabled,
            onChanged: (value) => widget.featureManager.setEnabled(feature.id, value),
          );
        },
      ),
    );
  }
}
