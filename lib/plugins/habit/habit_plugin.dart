/// Advanced Habit Plugin
/// 
/// Full-featured habit tracking with customizable habits
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';
import '../../core/plugin_feature_system.dart';

class HabitPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'habit';
  
  @override
  String get name => 'Habit';
  
  @override
  IconData get icon => Icons.repeat;
  
  @override
  String get description => '習慣トラッカー';

  final _dataService = PluginDataService('habit');
  
  late final PluginFeatureManager featureManager = PluginFeatureManager(
    pluginId: 'habit',
    availableFeatures: const [
      PluginFeature(
        id: 'custom_habits',
        name: 'カスタム習慣',
        description: '自分だけの習慣を追加',
        icon: Icons.add_circle,
      ),
      PluginFeature(
        id: 'streaks',
        name: '連続記録',
        description: '継続日数を表示',
        icon: Icons.local_fire_department,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'reminders',
        name: 'リマインダー',
        description: '習慣の時間設定',
        icon: Icons.alarm,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'categories',
        name: 'カテゴリ',
        description: '習慣をカテゴリ分け',
        icon: Icons.category,
        defaultEnabled: false,
      ),
    ],
  );

  @override
  Widget buildWidget(BuildContext context) => AdvancedHabitWidget(
    dataService: _dataService,
    featureManager: featureManager,
  );

  @override
  Widget buildCompactWidget(BuildContext context) => const HabitCompactWidget();

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

// Habit manager - saves custom habits to SharedPreferences
class HabitManager {
  static const _key = 'habit_list';
  
  static final List<Map<String, dynamic>> defaultHabits = [
    {'id': 'exercise', 'name': '運動', 'icon': '🏃', 'category': 'health'},
    {'id': 'reading', 'name': '読書', 'icon': '📚', 'category': 'growth'},
    {'id': 'meditation', 'name': '瞑想', 'icon': '🧘', 'category': 'health'},
    {'id': 'journal', 'name': '日記', 'icon': '✍️', 'category': 'growth'},
    {'id': 'sleep_early', 'name': '早寝', 'icon': '🌙', 'category': 'health'},
    {'id': 'water', 'name': '水を飲む', 'icon': '💧', 'category': 'health'},
  ];

  static Future<List<Map<String, dynamic>>> getHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    
    if (stored == null) {
      // First time - save defaults and return
      await saveHabits(defaultHabits);
      return List.from(defaultHabits);
    }
    
    final List<dynamic> decoded = jsonDecode(stored);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> saveHabits(List<Map<String, dynamic>> habits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(habits));
  }

  static Future<void> addHabit(Map<String, dynamic> habit) async {
    final habits = await getHabits();
    habits.add(habit);
    await saveHabits(habits);
  }

  static Future<void> removeHabit(String habitId) async {
    final habits = await getHabits();
    habits.removeWhere((h) => h['id'] == habitId);
    await saveHabits(habits);
  }

  static Future<void> updateHabit(String habitId, Map<String, dynamic> updated) async {
    final habits = await getHabits();
    final index = habits.indexWhere((h) => h['id'] == habitId);
    if (index >= 0) {
      habits[index] = updated;
      await saveHabits(habits);
    }
  }

  static Future<void> resetToDefaults() async {
    await saveHabits(List.from(defaultHabits));
  }
}

class AdvancedHabitWidget extends StatefulWidget {
  final PluginDataService dataService;
  final PluginFeatureManager featureManager;
  
  const AdvancedHabitWidget({
    super.key,
    required this.dataService,
    required this.featureManager,
  });

  @override
  State<AdvancedHabitWidget> createState() => _AdvancedHabitWidgetState();
}

class _AdvancedHabitWidgetState extends State<AdvancedHabitWidget> {
  final Set<String> _completedToday = {};
  List<LogEntry> _entries = [];
  List<Map<String, dynamic>> _habits = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    widget.featureManager.addListener(_onFeatureChanged);
  }

  Future<void> _initialize() async {
    await widget.featureManager.initialize();
    await _loadHabits();
    await _loadEntries();
    setState(() => _initialized = true);
  }

  Future<void> _loadHabits() async {
    final habits = await HabitManager.getHabits();
    setState(() => _habits = habits);
  }

  @override
  void dispose() {
    widget.featureManager.removeListener(_onFeatureChanged);
    super.dispose();
  }

  void _onFeatureChanged() => setState(() {});

  Future<void> _loadEntries() async {
    final entries = await widget.dataService.getTodayEntries();
    setState(() {
      _entries = entries;
      _completedToday.clear();
      for (final entry in entries) {
        final habitId = entry.data['habitId'] as String?;
        if (habitId != null) _completedToday.add(habitId);
      }
    });
  }

  Future<void> _toggleHabit(String habitId) async {
    if (_completedToday.contains(habitId)) {
      // Remove - find and delete the entry
      for (final entry in _entries) {
        if (entry.data['habitId'] == habitId) {
          await widget.dataService.deleteEntry(entry.id);
          break;
        }
      }
    } else {
      // Add
      await widget.dataService.createEntry({
        'habitId': habitId,
        'completedAt': DateFormat('HH:mm').format(DateTime.now()),
      });
    }
    
    await _loadEntries();
  }

  Future<void> _addHabit() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _HabitEditDialog(),
    );

    if (result != null) {
      await HabitManager.addHabit({
        'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
        'name': result['name'],
        'icon': result['icon'] ?? '✨',
        'category': 'custom',
      });
      await _loadHabits();
    }
  }

  Future<void> _editHabit(Map<String, dynamic> habit) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _HabitOptionsSheet(habit: habit),
    );

    if (result == 'edit') {
      final edited = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _HabitEditDialog(
          initialName: habit['name'] as String,
          initialIcon: habit['icon'] as String,
        ),
      );

      if (edited != null) {
        await HabitManager.updateHabit(habit['id'] as String, {
          ...habit,
          'name': edited['name'],
          'icon': edited['icon'],
        });
        await _loadHabits();
      }
    } else if (result == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('習慣を削除'),
          content: Text('「${habit['name']}」を削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('削除'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await HabitManager.removeHabit(habit['id'] as String);
        await _loadHabits();
      }
    }
  }

  Future<void> _manageHabits() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _HabitManageScreen(
          onChanged: _loadHabits,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final completedCount = _completedToday.length;
    final totalCount = _habits.length;

    return Column(
      children: [
        const SizedBox(height: 24),
        
        // Progress ring
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: totalCount > 0 ? completedCount / totalCount : 0,
                strokeWidth: 10,
                backgroundColor: Colors.grey.withAlpha(30),
                valueColor: AlwaysStoppedAnimation(
                  completedCount == totalCount && totalCount > 0 
                      ? Colors.green 
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  '$completedCount/$totalCount',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Text(
                  completedCount == totalCount && totalCount > 0 ? '🎉 完璧!' : '完了',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Actions row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _addHabit,
              icon: const Icon(Icons.add),
              label: const Text('追加'),
            ),
            TextButton.icon(
              onPressed: _manageHabits,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('管理'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PluginFeatureSettings(
                    pluginName: 'Habit',
                    featureManager: widget.featureManager,
                  ),
                ),
              ),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('設定'),
            ),
          ],
        ),

        const Divider(),

        // Habits list
        Expanded(
          child: _habits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('習慣を追加しましょう', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addHabit,
                        icon: const Icon(Icons.add),
                        label: const Text('習慣を追加'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _habits.length,
                  itemBuilder: (context, index) {
                    final habit = _habits[index];
                    final habitId = habit['id'] as String;
                    final isCompleted = _completedToday.contains(habitId);
                    
                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isCompleted 
                              ? Colors.green.withAlpha(30)
                              : Colors.grey.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            habit['icon'] as String,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      title: Text(
                        habit['name'] as String,
                        style: TextStyle(
                          fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? Colors.grey : null,
                        ),
                      ),
                      trailing: Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: isCompleted,
                          onChanged: (_) => _toggleHabit(habitId),
                          shape: const CircleBorder(),
                        ),
                      ),
                      onTap: () => _toggleHabit(habitId),
                      onLongPress: () => _editHabit(habit),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _HabitOptionsSheet extends StatelessWidget {
  final Map<String, dynamic> habit;

  const _HabitOptionsSheet({required this.habit});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Text(habit['icon'] as String, style: const TextStyle(fontSize: 24)),
            title: Text(habit['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('編集'),
            onTap: () => Navigator.pop(context, 'edit'),
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('削除', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _HabitEditDialog extends StatefulWidget {
  final String? initialName;
  final String? initialIcon;

  const _HabitEditDialog({this.initialName, this.initialIcon});

  @override
  State<_HabitEditDialog> createState() => _HabitEditDialogState();
}

class _HabitEditDialogState extends State<_HabitEditDialog> {
  late TextEditingController _nameController;
  late String _selectedIcon;
  
  static const List<String> _icons = [
    '✨', '🎯', '💪', '🧠', '❤️', '🌟', '🚀', '🎨', '🎵', '🌱',
    '📚', '🏃', '🧘', '✍️', '🌙', '💧', '📵', '📖', '🍎', '☀️',
    '🎮', '🎬', '🐶', '🌸', '⭐', '🔥', '💎', '🎸', '🏋️', '🧗',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedIcon = widget.initialIcon ?? '✨';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName != null ? '習慣を編集' : '新しい習慣'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '習慣名',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          const Text('アイコン', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: GridView.count(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: _icons.map((icon) => GestureDetector(
                onTap: () => setState(() => _selectedIcon = icon),
                child: Container(
                  decoration: BoxDecoration(
                    color: _selectedIcon == icon 
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: _selectedIcon == icon
                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'icon': _selectedIcon,
              });
            }
          },
          child: Text(widget.initialName != null ? '更新' : '追加'),
        ),
      ],
    );
  }
}

class _HabitManageScreen extends StatefulWidget {
  final VoidCallback onChanged;

  const _HabitManageScreen({required this.onChanged});

  @override
  State<_HabitManageScreen> createState() => _HabitManageScreenState();
}

class _HabitManageScreenState extends State<_HabitManageScreen> {
  List<Map<String, dynamic>> _habits = [];

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final habits = await HabitManager.getHabits();
    setState(() => _habits = habits);
  }

  Future<void> _deleteHabit(Map<String, dynamic> habit) async {
    await HabitManager.removeHabit(habit['id'] as String);
    await _loadHabits();
    widget.onChanged();
  }

  Future<void> _editHabit(Map<String, dynamic> habit) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _HabitEditDialog(
        initialName: habit['name'] as String,
        initialIcon: habit['icon'] as String,
      ),
    );

    if (result != null) {
      await HabitManager.updateHabit(habit['id'] as String, {
        ...habit,
        'name': result['name'],
        'icon': result['icon'],
      });
      await _loadHabits();
      widget.onChanged();
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('初期状態に戻す'),
        content: const Text('すべての習慣を初期状態に戻しますか？\nカスタム習慣は削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('リセット'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HabitManager.resetToDefaults();
      await _loadHabits();
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('習慣を管理'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') _resetToDefaults();
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
      body: ReorderableListView.builder(
        itemCount: _habits.length,
        onReorder: (oldIndex, newIndex) async {
          if (newIndex > oldIndex) newIndex--;
          final item = _habits.removeAt(oldIndex);
          _habits.insert(newIndex, item);
          await HabitManager.saveHabits(_habits);
          widget.onChanged();
          setState(() {});
        },
        itemBuilder: (context, index) {
          final habit = _habits[index];
          return ListTile(
            key: ValueKey(habit['id']),
            leading: Text(habit['icon'] as String, style: const TextStyle(fontSize: 28)),
            title: Text(habit['name'] as String),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editHabit(habit),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteHabit(habit),
                ),
                const Icon(Icons.drag_handle),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<Map<String, String>>(
            context: context,
            builder: (context) => _HabitEditDialog(),
          );

          if (result != null) {
            await HabitManager.addHabit({
              'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
              'name': result['name'],
              'icon': result['icon'] ?? '✨',
              'category': 'custom',
            });
            await _loadHabits();
            widget.onChanged();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class HabitCompactWidget extends StatelessWidget {
  const HabitCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.repeat),
        title: Text('Habit'),
        subtitle: Text('習慣トラッカー'),
      ),
    );
  }
}
