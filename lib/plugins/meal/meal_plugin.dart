/// Advanced Meal Plugin
/// 
/// Full-featured meal tracking with customizable foods
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';
import '../../core/plugin_feature_system.dart';

class MealPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'meal';
  
  @override
  String get name => 'Meal';
  
  @override
  IconData get icon => Icons.restaurant;
  
  @override
  String get description => '食事記録';

  final _dataService = PluginDataService('meal');
  
  late final PluginFeatureManager featureManager = PluginFeatureManager(
    pluginId: 'meal',
    availableFeatures: const [
      PluginFeature(
        id: 'meal_types',
        name: '食事の種類',
        description: '朝食/昼食/夕食/間食',
        icon: Icons.schedule,
      ),
      PluginFeature(
        id: 'food_items',
        name: '食品詳細',
        description: '食べた品目を個別に記録',
        icon: Icons.list,
      ),
      PluginFeature(
        id: 'calories',
        name: 'カロリー',
        description: 'カロリーを記録',
        icon: Icons.local_fire_department,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'photos',
        name: '写真',
        description: '食事の写真を保存',
        icon: Icons.photo_camera,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'water_intake',
        name: '水分記録',
        description: '食事時の水分も記録',
        icon: Icons.water_drop,
        defaultEnabled: false,
      ),
    ],
  );

  @override
  Widget buildWidget(BuildContext context) => AdvancedMealWidget(
    dataService: _dataService,
    featureManager: featureManager,
  );

  @override
  Widget buildCompactWidget(BuildContext context) => const MealCompactWidget();

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

// Settings manager
class MealSettingsManager {
  static const _foodsKey = 'meal_foods';
  static const _mealTypesKey = 'meal_types';
  static const _calorieGoalKey = 'meal_calorie_goal';

  static final List<Map<String, dynamic>> defaultMealTypes = [
    {'id': 'breakfast', 'name': '朝食', 'icon': '🌅', 'color': 0xFFFF9800},
    {'id': 'lunch', 'name': '昼食', 'icon': '☀️', 'color': 0xFF4CAF50},
    {'id': 'dinner', 'name': '夕食', 'icon': '🌙', 'color': 0xFF3F51B5},
    {'id': 'snack', 'name': '間食', 'icon': '🍪', 'color': 0xFF9C27B0},
  ];

  static final List<Map<String, dynamic>> defaultFoods = [
    {'name': 'ご飯', 'icon': '🍚', 'calories': 250},
    {'name': 'パン', 'icon': '🍞', 'calories': 180},
    {'name': 'サラダ', 'icon': '🥗', 'calories': 80},
    {'name': '味噌汁', 'icon': '🥣', 'calories': 40},
    {'name': '肉', 'icon': '🥩', 'calories': 300},
    {'name': '魚', 'icon': '🐟', 'calories': 200},
    {'name': '卵', 'icon': '🥚', 'calories': 100},
    {'name': '野菜', 'icon': '🥬', 'calories': 50},
    {'name': '果物', 'icon': '🍎', 'calories': 80},
    {'name': '乳製品', 'icon': '🥛', 'calories': 120},
  ];

  static Future<List<Map<String, dynamic>>> getMealTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_mealTypesKey);
    if (stored == null) return defaultMealTypes;
    final List<dynamic> decoded = jsonDecode(stored);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> saveMealTypes(List<Map<String, dynamic>> types) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mealTypesKey, jsonEncode(types));
  }

  static Future<List<Map<String, dynamic>>> getFoods() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_foodsKey);
    if (stored == null) {
      await saveFoods(defaultFoods);
      return List.from(defaultFoods);
    }
    final List<dynamic> decoded = jsonDecode(stored);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> saveFoods(List<Map<String, dynamic>> foods) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_foodsKey, jsonEncode(foods));
  }

  static Future<int> getCalorieGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_calorieGoalKey) ?? 2000;
  }

  static Future<void> setCalorieGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_calorieGoalKey, goal);
  }

  static Future<void> resetToDefaults() async {
    await saveFoods(List.from(defaultFoods));
    await saveMealTypes(defaultMealTypes);
    await setCalorieGoal(2000);
  }
}

class AdvancedMealWidget extends StatefulWidget {
  final PluginDataService dataService;
  final PluginFeatureManager featureManager;
  
  const AdvancedMealWidget({
    super.key,
    required this.dataService,
    required this.featureManager,
  });

  @override
  State<AdvancedMealWidget> createState() => _AdvancedMealWidgetState();
}

class _AdvancedMealWidgetState extends State<AdvancedMealWidget> {
  List<LogEntry> _entries = [];
  List<Map<String, dynamic>> _mealTypes = [];
  List<Map<String, dynamic>> _foods = [];
  int _totalCalories = 0;
  int _calorieGoal = 2000;
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
    final mealTypes = await MealSettingsManager.getMealTypes();
    final foods = await MealSettingsManager.getFoods();
    final calorieGoal = await MealSettingsManager.getCalorieGoal();
    setState(() {
      _mealTypes = mealTypes;
      _foods = foods;
      _calorieGoal = calorieGoal;
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
    final total = entries.fold<int>(0, (sum, e) => sum + (e.data['calories'] as int? ?? 0));
    setState(() {
      _entries = entries.reversed.toList();
      _totalCalories = total;
    });
  }

  Future<void> _addMeal(String mealTypeId) async {
    final mealType = _mealTypes.firstWhere(
      (m) => m['id'] == mealTypeId,
      orElse: () => _mealTypes.isNotEmpty ? _mealTypes.first : {'id': 'meal', 'name': '食事', 'icon': '🍽️', 'color': 0xFF4CAF50},
    );
    
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddMealSheet(
        mealType: mealType,
        foods: _foods,
        featureManager: widget.featureManager,
      ),
    );

    if (result != null) {
      await widget.dataService.createEntry({
        'type': mealTypeId,
        'typeName': mealType['name'],
        'icon': mealType['icon'],
        'foods': result['foods'],
        'memo': result['memo'],
        'calories': result['calories'],
        'time': DateFormat('HH:mm').format(DateTime.now()),
      });
      await _loadEntries();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MealSettingsScreen(
          mealTypes: _mealTypes,
          foods: _foods,
          calorieGoal: _calorieGoal,
          featureManager: widget.featureManager,
          onChanged: _loadSettings,
        ),
      ),
    );
  }

  Map<String, bool> get _mealStatus {
    final status = <String, bool>{};
    for (final type in _mealTypes) {
      status[type['id'] as String] = _entries.any((e) => e.data['type'] == type['id']);
    }
    return status;
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasCalories = widget.featureManager.isEnabled('calories');
    final mealStatus = _mealStatus;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Today's summary
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Meal status icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _mealTypes.map((type) {
                    final isDone = mealStatus[type['id']] ?? false;
                    return Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isDone 
                                ? Color(type['color'] as int).withAlpha(100)
                                : Colors.grey.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              type['icon'] as String,
                              style: TextStyle(fontSize: 24, 
                                color: isDone ? null : Colors.grey.withAlpha(100)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type['name'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                            color: isDone ? null : Colors.grey,
                          ),
                        ),
                        if (isDone)
                          const Icon(Icons.check_circle, size: 14, color: Colors.green),
                      ],
                    );
                  }).toList(),
                ),

                // Calorie summary
                if (hasCalories) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            '$_totalCalories / $_calorieGoal kcal',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_totalCalories / _calorieGoal).clamp(0.0, 1.0),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Add meal buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _mealTypes.map((type) {
                final isDone = mealStatus[type['id']] ?? false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    onPressed: () => _addMeal(type['id'] as String),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDone 
                          ? Color(type['color'] as int).withAlpha(30)
                          : null,
                      foregroundColor: isDone 
                          ? Color(type['color'] as int)
                          : null,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isDone 
                            ? BorderSide(color: Color(type['color'] as int))
                            : BorderSide.none,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(type['icon'] as String, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(type['name'] as String),
                        if (isDone) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check, size: 18),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Entry list
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('今日の記録', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('設定'),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final icon = entry.data['icon'] as String? ?? '🍽️';
              final typeName = entry.data['typeName'] as String? ?? '';
              final memo = entry.data['memo'] as String? ?? '';
              final time = entry.data['time'] as String? ?? '';
              final calories = entry.data['calories'] as int?;
              final foods = (entry.data['foods'] as List?)?.cast<String>() ?? [];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Text(icon, style: const TextStyle(fontSize: 28)),
                  title: Row(
                    children: [
                      Text(typeName),
                      const Spacer(),
                      Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (foods.isNotEmpty)
                        Text(
                          foods.join(', '),
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (memo.isNotEmpty)
                        Text(
                          memo,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (calories != null && calories > 0)
                        Text(
                          '$calories kcal',
                          style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      await widget.dataService.deleteEntry(entry.id);
                      await _loadEntries();
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MealSettingsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> mealTypes;
  final List<Map<String, dynamic>> foods;
  final int calorieGoal;
  final PluginFeatureManager featureManager;
  final VoidCallback onChanged;

  const _MealSettingsScreen({
    required this.mealTypes,
    required this.foods,
    required this.calorieGoal,
    required this.featureManager,
    required this.onChanged,
  });

  @override
  State<_MealSettingsScreen> createState() => _MealSettingsScreenState();
}

class _MealSettingsScreenState extends State<_MealSettingsScreen> {
  late List<Map<String, dynamic>> _foods;
  late int _calorieGoal;

  @override
  void initState() {
    super.initState();
    _foods = List.from(widget.foods);
    _calorieGoal = widget.calorieGoal;
  }

  Future<void> _reload() async {
    final foods = await MealSettingsManager.getFoods();
    final calorieGoal = await MealSettingsManager.getCalorieGoal();
    setState(() {
      _foods = foods;
      _calorieGoal = calorieGoal;
    });
    widget.onChanged();
  }

  Future<void> _editCalorieGoal() async {
    final controller = TextEditingController(text: _calorieGoal.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('1日の目標カロリー'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: 'kcal',
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
      await MealSettingsManager.setCalorieGoal(result);
      await _reload();
    }
  }

  Future<void> _addFood() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FoodEditDialog(),
    );

    if (result != null) {
      _foods.add(result);
      await MealSettingsManager.saveFoods(_foods);
      await _reload();
    }
  }

  Future<void> _deleteFood(String name) async {
    _foods.removeWhere((f) => f['name'] == name);
    await MealSettingsManager.saveFoods(_foods);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('食事設定'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'reset') {
                await MealSettingsManager.resetToDefaults();
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
          // Calorie goal
          ListTile(
            leading: const Icon(Icons.local_fire_department, color: Colors.orange),
            title: const Text('1日の目標カロリー'),
            subtitle: Text('$_calorieGoal kcal'),
            trailing: const Icon(Icons.edit),
            onTap: _editCalorieGoal,
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
                  pluginName: 'Meal',
                  featureManager: widget.featureManager,
                ),
              ),
            ),
          ),
          const Divider(),

          // Foods
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('よく食べるもの', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addFood,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('追加'),
                ),
              ],
            ),
          ),
          ..._foods.map((food) => ListTile(
            leading: Text(food['icon'] as String, style: const TextStyle(fontSize: 24)),
            title: Text(food['name'] as String),
            subtitle: food['calories'] != null ? Text('${food['calories']} kcal') : null,
            trailing: IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deleteFood(food['name'] as String),
            ),
          )),
        ],
      ),
    );
  }
}

class _FoodEditDialog extends StatefulWidget {
  @override
  State<_FoodEditDialog> createState() => _FoodEditDialogState();
}

class _FoodEditDialogState extends State<_FoodEditDialog> {
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  String _selectedIcon = '🍽️';

  static const List<String> _icons = [
    '🍚', '🍞', '🥗', '🥣', '🥩', '🐟', '🥚', '🥬', '🍎', '🥛',
    '🍜', '🍝', '🍕', '🍔', '🍣', '🍱', '🥪', '🌮', '🍛', '🥘',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('食べ物を追加'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '名前', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caloriesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'カロリー（任意）', suffixText: 'kcal', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
            if (_nameController.text.isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'icon': _selectedIcon,
                'calories': int.tryParse(_caloriesController.text),
              });
            }
          },
          child: const Text('追加'),
        ),
      ],
    );
  }
}

class _AddMealSheet extends StatefulWidget {
  final Map<String, dynamic> mealType;
  final List<Map<String, dynamic>> foods;
  final PluginFeatureManager featureManager;

  const _AddMealSheet({
    required this.mealType,
    required this.foods,
    required this.featureManager,
  });

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<_AddMealSheet> {
  final _memoController = TextEditingController();
  final _caloriesController = TextEditingController();
  final Set<String> _selectedFoods = {};

  @override
  void dispose() {
    _memoController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFoodItems = widget.featureManager.isEnabled('food_items');
    final hasCalories = widget.featureManager.isEnabled('calories');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Text(
                  widget.mealType['icon'] as String,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.mealType['name'] as String,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Food items
            if (hasFoodItems && widget.foods.isNotEmpty) ...[
              const Text('何を食べた？', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.foods.map((food) {
                  final isSelected = _selectedFoods.contains(food['name']);
                  return FilterChip(
                    avatar: Text(food['icon'] as String),
                    label: Text(food['name'] as String),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedFoods.add(food['name'] as String);
                        } else {
                          _selectedFoods.remove(food['name']);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Memo
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '内容メモ',
                hintText: '例：カレーライス、サラダ',
                border: OutlineInputBorder(),
              ),
            ),

            // Calories
            if (hasCalories) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'カロリー（任意）',
                  suffixText: 'kcal',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_fire_department),
                ),
              ),
            ],

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'foods': _selectedFoods.toList(),
                  'memo': _memoController.text,
                  'calories': int.tryParse(_caloriesController.text) ?? 0,
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('記録'),
            ),
          ],
        ),
      ),
    );
  }
}

class MealCompactWidget extends StatelessWidget {
  const MealCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.restaurant),
        title: Text('Meal'),
        subtitle: Text('食事記録'),
      ),
    );
  }
}
