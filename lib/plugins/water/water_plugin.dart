/// Advanced Water Plugin
/// 
/// Full-featured hydration tracking with customizable drinks and goals
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';
import '../../core/plugin_feature_system.dart';

class WaterPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'water';
  
  @override
  String get name => 'Water';
  
  @override
  IconData get icon => Icons.water_drop;
  
  @override
  String get description => '水分摂取';

  final _dataService = PluginDataService('water');
  
  late final PluginFeatureManager featureManager = PluginFeatureManager(
    pluginId: 'water',
    availableFeatures: const [
      PluginFeature(
        id: 'custom_goal',
        name: 'カスタム目標',
        description: '1日の目標量を設定',
        icon: Icons.flag,
      ),
      PluginFeature(
        id: 'drink_types',
        name: '飲み物の種類',
        description: '水以外も記録',
        icon: Icons.local_cafe,
      ),
      PluginFeature(
        id: 'quick_add',
        name: 'クイック追加',
        description: 'よく使う量をワンタップ',
        icon: Icons.flash_on,
      ),
      PluginFeature(
        id: 'container_sizes',
        name: '容器サイズ',
        description: 'コップ/ボトル/ペットボトル',
        icon: Icons.local_drink,
      ),
      PluginFeature(
        id: 'hourly_breakdown',
        name: '時間帯別',
        description: '時間帯別の摂取量表示',
        icon: Icons.schedule,
        defaultEnabled: false,
      ),
    ],
  );

  @override
  Widget buildWidget(BuildContext context) => AdvancedWaterWidget(
    dataService: _dataService,
    featureManager: featureManager,
  );

  @override
  Widget buildCompactWidget(BuildContext context) => const WaterCompactWidget();

  @override
  Future<List<LogEntry>> getEntries(DateTime date) async {
    return _dataService.getEntriesForDate(date);
  }

  @override
  Future<void> saveEntry(LogEntry entry) async {
    await _dataService.createEntry(entry.data);
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _dataService.deleteEntry(id);
  }
}

// Drink and Container managers
class WaterSettingsManager {
  static const _drinksKey = 'water_drinks';
  static const _containersKey = 'water_containers';
  static const _goalKey = 'water_goal';

  static final List<Map<String, dynamic>> defaultDrinks = [
    {'id': 'water', 'name': '水', 'icon': '💧', 'color': 0xFF2196F3, 'hydration': 1.0},
    {'id': 'tea', 'name': 'お茶', 'icon': '🍵', 'color': 0xFF8BC34A, 'hydration': 0.9},
    {'id': 'coffee', 'name': 'コーヒー', 'icon': '☕', 'color': 0xFF795548, 'hydration': 0.8},
    {'id': 'juice', 'name': 'ジュース', 'icon': '🧃', 'color': 0xFFFF9800, 'hydration': 0.7},
    {'id': 'milk', 'name': '牛乳', 'icon': '🥛', 'color': 0xFFEEEEEE, 'hydration': 0.9},
    {'id': 'sports', 'name': 'スポドリ', 'icon': '🥤', 'color': 0xFF00BCD4, 'hydration': 1.0},
  ];

  static final List<Map<String, dynamic>> defaultContainers = [
    {'id': 'cup', 'name': 'コップ', 'ml': 200, 'icon': '🥛'},
    {'id': 'mug', 'name': 'マグカップ', 'ml': 300, 'icon': '☕'},
    {'id': 'bottle_s', 'name': '小ボトル', 'ml': 350, 'icon': '🍶'},
    {'id': 'bottle_m', 'name': 'ペットボトル', 'ml': 500, 'icon': '🧴'},
    {'id': 'bottle_l', 'name': '大ボトル', 'ml': 1000, 'icon': '🫗'},
  ];

  static Future<List<Map<String, dynamic>>> getDrinks() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_drinksKey);
    if (stored == null) {
      await saveDrinks(defaultDrinks);
      return List.from(defaultDrinks);
    }
    final List<dynamic> decoded = jsonDecode(stored);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> saveDrinks(List<Map<String, dynamic>> drinks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_drinksKey, jsonEncode(drinks));
  }

  static Future<List<Map<String, dynamic>>> getContainers() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_containersKey);
    if (stored == null) {
      await saveContainers(defaultContainers);
      return List.from(defaultContainers);
    }
    final List<dynamic> decoded = jsonDecode(stored);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> saveContainers(List<Map<String, dynamic>> containers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_containersKey, jsonEncode(containers));
  }

  static Future<int> getGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_goalKey) ?? 2000;
  }

  static Future<void> setGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_goalKey, goal);
  }

  static Future<void> resetToDefaults() async {
    await saveDrinks(List.from(defaultDrinks));
    await saveContainers(List.from(defaultContainers));
    await setGoal(2000);
  }
}

class AdvancedWaterWidget extends StatefulWidget {
  final PluginDataService dataService;
  final PluginFeatureManager featureManager;
  
  const AdvancedWaterWidget({
    super.key,
    required this.dataService,
    required this.featureManager,
  });

  @override
  State<AdvancedWaterWidget> createState() => _AdvancedWaterWidgetState();
}

class _AdvancedWaterWidgetState extends State<AdvancedWaterWidget> {
  List<LogEntry> _entries = [];
  List<Map<String, dynamic>> _drinks = [];
  List<Map<String, dynamic>> _containers = [];
  int _totalMl = 0;
  int _goal = 2000;
  String _selectedDrink = 'water';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    widget.featureManager.addListener(_onFeatureChanged);
  }

  Future<void> _initialize() async {
    await widget.featureManager.initialize();
    await _loadSettings();
    await _loadEntries();
    setState(() => _initialized = true);
  }

  Future<void> _loadSettings() async {
    final drinks = await WaterSettingsManager.getDrinks();
    final containers = await WaterSettingsManager.getContainers();
    final goal = await WaterSettingsManager.getGoal();
    setState(() {
      _drinks = drinks;
      _containers = containers;
      _goal = goal;
    });
  }

  @override
  void dispose() {
    widget.featureManager.removeListener(_onFeatureChanged);
    super.dispose();
  }

  void _onFeatureChanged() => setState(() {});

  Future<void> _loadEntries() async {
    final entries = await widget.dataService.getTodayEntries();
    final total = entries.fold<int>(0, (sum, e) => sum + (e.data['amount'] as int? ?? 0));
    setState(() {
      _entries = entries.reversed.toList();
      _totalMl = total;
    });
  }

  Future<void> _addWater(int ml) async {
    final drink = _drinks.firstWhere(
      (d) => d['id'] == _selectedDrink,
      orElse: () => _drinks.isNotEmpty ? _drinks.first : {'id': 'water', 'name': '水', 'icon': '💧'},
    );

    await widget.dataService.createEntry({
      'amount': ml,
      'drinkType': _selectedDrink,
      'drinkName': drink['name'],
      'icon': drink['icon'],
      'time': DateFormat('HH:mm').format(DateTime.now()),
    });
    
    await _loadEntries();
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WaterSettingsScreen(
          drinks: _drinks,
          containers: _containers,
          goal: _goal,
          featureManager: widget.featureManager,
          onChanged: () async {
            await _loadSettings();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasDrinkTypes = widget.featureManager.isEnabled('drink_types');
    final hasContainers = widget.featureManager.isEnabled('container_sizes');
    final hasGoal = widget.featureManager.isEnabled('custom_goal');

    final progress = _totalMl / _goal;
    final progressColor = progress >= 1.0 ? Colors.green : Colors.blue;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Progress display
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  progressColor.withAlpha(50),
                  progressColor.withAlpha(20),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.withAlpha(30),
                        valueColor: AlwaysStoppedAnimation(progressColor),
                      ),
                    ),
                    Column(
                      children: [
                        Text('💧', style: const TextStyle(fontSize: 32)),
                        Text(
                          '$_totalMl',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                        Text('ml', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
                if (hasGoal) ...[
                  const SizedBox(height: 16),
                  Text(
                    '目標: $_goal ml',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (progress >= 1.0)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '🎉 目標達成！',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Drink type selector
          if (hasDrinkTypes && _drinks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('飲み物', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _drinks.map((drink) {
                  final isSelected = _selectedDrink == drink['id'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDrink = drink['id'] as String),
                      child: Container(
                        width: 70,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(drink['color'] as int? ?? 0xFF2196F3).withAlpha(50)
                              : Colors.grey.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: Color(drink['color'] as int? ?? 0xFF2196F3), width: 2)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(drink['icon'] as String, style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(
                              drink['name'] as String,
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Container buttons
          if (hasContainers && _containers.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('追加', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _containers.map((container) {
                return ElevatedButton(
                  onPressed: () => _addWater(container['ml'] as int),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(container['icon'] as String, style: const TextStyle(fontSize: 20)),
                      Text('${container['ml']}ml'),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            // Simple quick add
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [100, 200, 300, 500].map((ml) {
                return ElevatedButton(
                  onPressed: () => _addWater(ml),
                  child: Text('+${ml}ml'),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 24),

          // Settings button
          TextButton.icon(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('設定'),
          ),

          const Divider(),

          // Entry list
          if (_entries.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _entries.take(10).length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final icon = entry.data['icon'] as String? ?? '💧';
                final amount = entry.data['amount'] as int? ?? 0;
                final time = entry.data['time'] as String? ?? '';

                return ListTile(
                  leading: Text(icon, style: const TextStyle(fontSize: 24)),
                  title: Text('$amount ml'),
                  subtitle: Text(time),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      await widget.dataService.deleteEntry(entry.id);
                      await _loadEntries();
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _WaterSettingsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> drinks;
  final List<Map<String, dynamic>> containers;
  final int goal;
  final PluginFeatureManager featureManager;
  final VoidCallback onChanged;

  const _WaterSettingsScreen({
    required this.drinks,
    required this.containers,
    required this.goal,
    required this.featureManager,
    required this.onChanged,
  });

  @override
  State<_WaterSettingsScreen> createState() => _WaterSettingsScreenState();
}

class _WaterSettingsScreenState extends State<_WaterSettingsScreen> {
  late List<Map<String, dynamic>> _drinks;
  late List<Map<String, dynamic>> _containers;
  late int _goal;

  @override
  void initState() {
    super.initState();
    _drinks = List.from(widget.drinks);
    _containers = List.from(widget.containers);
    _goal = widget.goal;
  }

  Future<void> _reload() async {
    final drinks = await WaterSettingsManager.getDrinks();
    final containers = await WaterSettingsManager.getContainers();
    final goal = await WaterSettingsManager.getGoal();
    setState(() {
      _drinks = drinks;
      _containers = containers;
      _goal = goal;
    });
    widget.onChanged();
  }

  Future<void> _editGoal() async {
    final controller = TextEditingController(text: _goal.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('目標量'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: 'ml',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      await WaterSettingsManager.setGoal(result);
      await _reload();
    }
  }

  Future<void> _addDrink() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DrinkEditDialog(),
    );

    if (result != null) {
      _drinks.add({
        ...result,
        'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
      });
      await WaterSettingsManager.saveDrinks(_drinks);
      await _reload();
    }
  }

  Future<void> _deleteDrink(String id) async {
    _drinks.removeWhere((d) => d['id'] == id);
    await WaterSettingsManager.saveDrinks(_drinks);
    await _reload();
  }

  Future<void> _addContainer() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ContainerEditDialog(),
    );

    if (result != null) {
      _containers.add({
        ...result,
        'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
      });
      await WaterSettingsManager.saveContainers(_containers);
      await _reload();
    }
  }

  Future<void> _deleteContainer(String id) async {
    _containers.removeWhere((c) => c['id'] == id);
    await WaterSettingsManager.saveContainers(_containers);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('水分設定'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'reset') {
                await WaterSettingsManager.resetToDefaults();
                await _reload();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.red),
                    SizedBox(width: 8),
                    Text('初期状態に戻す'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          // Goal
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('1日の目標'),
            subtitle: Text('$_goal ml'),
            trailing: const Icon(Icons.edit),
            onTap: _editGoal,
          ),
          const Divider(),

          // Feature settings
          ListTile(
            leading: const Icon(Icons.toggle_on),
            title: const Text('機能設定'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PluginFeatureSettings(
                  pluginName: 'Water',
                  featureManager: widget.featureManager,
                ),
              ),
            ),
          ),
          const Divider(),

          // Drinks
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('飲み物', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addDrink,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('追加'),
                ),
              ],
            ),
          ),
          ..._drinks.map((drink) => ListTile(
            leading: Text(drink['icon'] as String, style: const TextStyle(fontSize: 24)),
            title: Text(drink['name'] as String),
            trailing: IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deleteDrink(drink['id'] as String),
            ),
          )),

          const Divider(),

          // Containers
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('容器', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addContainer,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('追加'),
                ),
              ],
            ),
          ),
          ..._containers.map((container) => ListTile(
            leading: Text(container['icon'] as String, style: const TextStyle(fontSize: 24)),
            title: Text(container['name'] as String),
            subtitle: Text('${container['ml']} ml'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deleteContainer(container['id'] as String),
            ),
          )),
        ],
      ),
    );
  }
}

class _DrinkEditDialog extends StatefulWidget {
  @override
  State<_DrinkEditDialog> createState() => _DrinkEditDialogState();
}

class _DrinkEditDialogState extends State<_DrinkEditDialog> {
  final _nameController = TextEditingController();
  String _selectedIcon = '🍹';
  int _selectedColor = 0xFF2196F3;

  static const List<String> _icons = ['💧', '🍵', '☕', '🧃', '🥛', '🥤', '🍹', '🍺', '🍷', '🧋'];
  static const List<int> _colors = [
    0xFF2196F3, 0xFF8BC34A, 0xFF795548, 0xFFFF9800,
    0xFFE91E63, 0xFF9C27B0, 0xFF00BCD4, 0xFF607D8B,
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('飲み物を追加'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '名前', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _icons.map((icon) => GestureDetector(
              onTap: () => setState(() => _selectedIcon = icon),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedIcon == icon ? Colors.blue.withAlpha(30) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _colors.map((color) => GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: _selectedColor == color ? Border.all(color: Colors.white, width: 3) : null,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'icon': _selectedIcon,
                'color': _selectedColor,
                'hydration': 1.0,
              });
            }
          },
          child: const Text('追加'),
        ),
      ],
    );
  }
}

class _ContainerEditDialog extends StatefulWidget {
  @override
  State<_ContainerEditDialog> createState() => _ContainerEditDialogState();
}

class _ContainerEditDialogState extends State<_ContainerEditDialog> {
  final _nameController = TextEditingController();
  final _mlController = TextEditingController();
  String _selectedIcon = '🥛';

  static const List<String> _icons = ['🥛', '☕', '🍶', '🧴', '🫗', '🍵', '🥤', '🍺'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('容器を追加'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '名前', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mlController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '容量 (ml)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _icons.map((icon) => GestureDetector(
              onTap: () => setState(() => _selectedIcon = icon),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedIcon == icon ? Colors.blue.withAlpha(30) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
            )).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        ElevatedButton(
          onPressed: () {
            final ml = int.tryParse(_mlController.text);
            if (_nameController.text.isNotEmpty && ml != null && ml > 0) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'ml': ml,
                'icon': _selectedIcon,
              });
            }
          },
          child: const Text('追加'),
        ),
      ],
    );
  }
}

class WaterCompactWidget extends StatelessWidget {
  const WaterCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.water_drop, color: Colors.blue),
        title: Text('Water'),
        subtitle: Text('水分摂取'),
      ),
    );
  }
}
