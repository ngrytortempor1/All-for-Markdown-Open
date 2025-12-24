/// Plugin Settings Screen
/// 
/// UI for enabling/disabling plugins
library;

import 'package:flutter/material.dart';
import '../core/plugin_manager.dart';

class PluginSettingsScreen extends StatefulWidget {
  const PluginSettingsScreen({super.key});

  @override
  State<PluginSettingsScreen> createState() => _PluginSettingsScreenState();
}

class _PluginSettingsScreenState extends State<PluginSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final manager = PluginManager.instance;
    final plugins = manager.allPlugins;

    return Scaffold(
      appBar: AppBar(
        title: const Text('プラグイン設定'),
      ),
      body: ListView.builder(
        itemCount: plugins.length,
        itemBuilder: (context, index) {
          final plugin = plugins[index];
          final isEnabled = manager.isEnabled(plugin.id);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              secondary: Icon(
                plugin.icon,
                color: isEnabled 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.grey,
              ),
              title: Text(
                plugin.name,
                style: TextStyle(
                  color: isEnabled ? null : Colors.grey,
                ),
              ),
              subtitle: Text(
                plugin.description,
                style: TextStyle(
                  color: isEnabled ? null : Colors.grey,
                ),
              ),
              value: isEnabled,
              onChanged: (value) async {
                await manager.togglePlugin(plugin.id);
                setState(() {});
              },
            ),
          );
        },
      ),
    );
  }
}
