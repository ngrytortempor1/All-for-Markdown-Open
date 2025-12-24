/// Advanced Todo Plugin
/// 
/// Full-featured task management with customizable projects
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';
import '../../core/plugin_feature_system.dart';

class TodoPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'todo';
  
  @override
  String get name => 'Todo';
  
  @override
  IconData get icon => Icons.check_box_outlined;
  
  @override
  String get description => 'タスク管理';

  final _dataService = PluginDataService('todo');
  
  late final PluginFeatureManager featureManager = PluginFeatureManager(
    pluginId: 'todo',
    availableFeatures: const [
      PluginFeature(
        id: 'projects',
        name: 'プロジェクト',
        description: 'タスクをプロジェクトで分類',
        icon: Icons.folder,
      ),
      PluginFeature(
        id: 'priority',
        name: '優先度',
        description: 'タスクに優先度を設定',
        icon: Icons.flag,
      ),
      PluginFeature(
        id: 'due_date',
        name: '期限',
        description: 'タスクに期限日を設定',
        icon: Icons.calendar_today,
      ),
      PluginFeature(
        id: 'tags',
        name: 'タグ',
        description: 'タスクにタグを付ける',
        icon: Icons.label,
      ),
      PluginFeature(
        id: 'subtasks',
        name: 'サブタスク',
        description: 'タスクを細分化',
        icon: Icons.subdirectory_arrow_right,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'notes',
        name: 'メモ',
        description: 'タスクに詳細メモを追加',
        icon: Icons.notes,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'recurring',
        name: '繰り返し',
        description: '定期的なタスクを設定',
        icon: Icons.repeat,
        defaultEnabled: false,
      ),
    ],
  );

  @override
  Widget buildWidget(BuildContext context) => AdvancedTodoWidget(
    dataService: _dataService,
    featureManager: featureManager,
  );

  @override
  Widget buildCompactWidget(BuildContext context) => const TodoCompactWidget();

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

// Priority levels
enum TaskPriority {
  none(0, 'なし', Colors.grey, Icons.flag_outlined),
  low(1, '低', Colors.blue, Icons.flag),
  medium(2, '中', Colors.orange, Icons.flag),
  high(3, '高', Colors.red, Icons.flag);

  final int value;
  final String label;
  final Color color;
  final IconData icon;

  const TaskPriority(this.value, this.label, this.color, this.icon);

  static TaskPriority fromValue(int? value) {
    return TaskPriority.values.firstWhere(
      (p) => p.value == value,
      orElse: () => TaskPriority.none,
    );
  }
}

// Project manager
class TodoProjectManager {
  static const _key = 'todo_projects';
  
  static final List<Map<String, dynamic>> defaultProjects = [
    {'id': 'inbox', 'name': '受信トレイ', 'color': 0xFF607D8B, 'iconCode': 0xe156},
    {'id': 'work', 'name': '仕事', 'color': 0xFF2196F3, 'iconCode': 0xe943},
    {'id': 'personal', 'name': 'プライベート', 'color': 0xFF4CAF50, 'iconCode': 0xe491},
    {'id': 'shopping', 'name': '買い物', 'color': 0xFFFF9800, 'iconCode': 0xe8cc},
  ];

  static Future<List<Map<String, dynamic>>> getProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    
    if (stored == null) {
      await saveProjects(defaultProjects);
      return List.from(defaultProjects);
    }
    
    final List<dynamic> decoded = jsonDecode(stored);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> saveProjects(List<Map<String, dynamic>> projects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(projects));
  }

  static Future<void> addProject(Map<String, dynamic> project) async {
    final projects = await getProjects();
    projects.add(project);
    await saveProjects(projects);
  }

  static Future<void> removeProject(String projectId) async {
    if (projectId == 'inbox') return; // Can't remove inbox
    final projects = await getProjects();
    projects.removeWhere((p) => p['id'] == projectId);
    await saveProjects(projects);
  }

  static Future<void> updateProject(String projectId, Map<String, dynamic> updated) async {
    final projects = await getProjects();
    final index = projects.indexWhere((p) => p['id'] == projectId);
    if (index >= 0) {
      projects[index] = updated;
      await saveProjects(projects);
    }
  }

  static Future<void> resetToDefaults() async {
    await saveProjects(List.from(defaultProjects));
  }

  static IconData getIcon(int? code) {
    return IconData(code ?? 0xe156, fontFamily: 'MaterialIcons');
  }
}

class AdvancedTodoWidget extends StatefulWidget {
  final PluginDataService dataService;
  final PluginFeatureManager featureManager;
  
  const AdvancedTodoWidget({
    super.key,
    required this.dataService,
    required this.featureManager,
  });

  @override
  State<AdvancedTodoWidget> createState() => _AdvancedTodoWidgetState();
}

class _AdvancedTodoWidgetState extends State<AdvancedTodoWidget> {
  final _controller = TextEditingController();
  List<LogEntry> _entries = [];
  List<Map<String, dynamic>> _projects = [];
  String _selectedProject = 'inbox';
  String? _filterProject;
  bool _showCompleted = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    widget.featureManager.addListener(_onFeatureChanged);
  }

  Future<void> _initialize() async {
    await widget.featureManager.initialize();
    await _loadProjects();
    await _loadEntries();
    setState(() => _initialized = true);
  }

  Future<void> _loadProjects() async {
    final projects = await TodoProjectManager.getProjects();
    setState(() => _projects = projects);
  }

  @override
  void dispose() {
    widget.featureManager.removeListener(_onFeatureChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onFeatureChanged() => setState(() {});

  Future<void> _loadEntries() async {
    final entries = await widget.dataService.getTodayEntries();
    setState(() => _entries = entries);
  }

  Future<void> _addTask() async {
    if (_controller.text.isEmpty) return;
    
    await widget.dataService.createEntry({
      'text': _controller.text,
      'done': false,
      'project': _selectedProject,
      'priority': TaskPriority.none.value,
      'createdAt': DateFormat('HH:mm').format(DateTime.now()),
    });
    
    _controller.clear();
    await _loadEntries();
  }

  Future<void> _toggleTask(LogEntry entry) async {
    final newDone = !(entry.data['done'] as bool? ?? false);
    await widget.dataService.updateEntry(entry.id, {
      ...entry.data,
      'done': newDone,
      'completedAt': newDone ? DateFormat('HH:mm').format(DateTime.now()) : null,
    });
    await _loadEntries();
  }

  Future<void> _editTask(LogEntry entry) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TaskEditSheet(
        entry: entry,
        projects: _projects,
        featureManager: widget.featureManager,
      ),
    );

    if (result != null) {
      if (result['delete'] == true) {
        await widget.dataService.deleteEntry(entry.id);
      } else {
        await widget.dataService.updateEntry(entry.id, result);
      }
      await _loadEntries();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TodoSettingsScreen(
          projects: _projects,
          featureManager: widget.featureManager,
          onChanged: _loadProjects,
        ),
      ),
    );
  }

  List<LogEntry> get _filteredEntries {
    var entries = _entries;
    
    if (_filterProject != null) {
      entries = entries.where((e) => e.data['project'] == _filterProject).toList();
    }
    
    if (!_showCompleted) {
      entries = entries.where((e) => e.data['done'] != true).toList();
    }
    
    entries.sort((a, b) {
      final priorityA = a.data['priority'] as int? ?? 0;
      final priorityB = b.data['priority'] as int? ?? 0;
      if (priorityA != priorityB) return priorityB.compareTo(priorityA);
      return 0;
    });
    
    return entries;
  }

  Map<String, dynamic> _getProject(String id) {
    return _projects.firstWhere(
      (p) => p['id'] == id,
      orElse: () => _projects.isNotEmpty ? _projects.first : {'id': 'inbox', 'name': '受信トレイ', 'color': 0xFF607D8B, 'iconCode': 0xe156},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasProjects = widget.featureManager.isEnabled('projects');
    final completedCount = _entries.where((e) => e.data['done'] == true).length;

    return Column(
      children: [
        // Project filter chips
        if (hasProjects && _projects.isNotEmpty)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('すべて'),
                    selected: _filterProject == null,
                    onSelected: (_) => setState(() => _filterProject = null),
                  ),
                ),
                ..._projects.map((p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(TodoProjectManager.getIcon(p['iconCode'] as int?), size: 18),
                    label: Text(p['name'] as String),
                    selected: _filterProject == p['id'],
                    onSelected: (_) => setState(() => _filterProject = p['id'] as String),
                  ),
                )),
              ],
            ),
          ),
        
        // Quick add input
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'タスクを追加...',
                    border: const OutlineInputBorder(),
                    prefixIcon: hasProjects && _projects.isNotEmpty ? PopupMenuButton<String>(
                      icon: Icon(
                        TodoProjectManager.getIcon(_getProject(_selectedProject)['iconCode'] as int?),
                        color: Color(_getProject(_selectedProject)['color'] as int),
                      ),
                      onSelected: (value) => setState(() => _selectedProject = value),
                      itemBuilder: (context) => _projects.map((p) => PopupMenuItem(
                        value: p['id'] as String,
                        child: Row(
                          children: [
                            Icon(TodoProjectManager.getIcon(p['iconCode'] as int?), color: Color(p['color'] as int)),
                            const SizedBox(width: 8),
                            Text(p['name'] as String),
                          ],
                        ),
                      )).toList(),
                    ) : null,
                  ),
                  onSubmitted: (_) => _addTask(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addTask,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),

        // Stats bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${_filteredEntries.where((e) => e.data['done'] != true).length} タスク',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _showCompleted = !_showCompleted),
                icon: Icon(_showCompleted ? Icons.visibility : Icons.visibility_off, size: 18),
                label: Text('完了済み ($completedCount)'),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _openSettings,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Task list
        Expanded(
          child: _filteredEntries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'タスクがありません',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _filteredEntries[index];
                    return _TaskTile(
                      entry: entry,
                      projects: _projects,
                      featureManager: widget.featureManager,
                      onToggle: () => _toggleTask(entry),
                      onTap: () => _editTask(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  final LogEntry entry;
  final List<Map<String, dynamic>> projects;
  final PluginFeatureManager featureManager;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _TaskTile({
    required this.entry,
    required this.projects,
    required this.featureManager,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final done = entry.data['done'] as bool? ?? false;
    final priority = TaskPriority.fromValue(entry.data['priority'] as int?);
    final text = entry.data['text'] as String? ?? '';
    final projectId = entry.data['project'] as String? ?? 'inbox';
    final dueDate = entry.data['dueDate'] as String?;
    final tags = (entry.data['tags'] as List?)?.cast<String>() ?? [];

    final hasPriority = featureManager.isEnabled('priority');
    final hasProjects = featureManager.isEnabled('projects');
    final hasDueDate = featureManager.isEnabled('due_date');
    final hasTags = featureManager.isEnabled('tags');

    final project = projects.firstWhere(
      (p) => p['id'] == projectId,
      orElse: () => {'id': 'inbox', 'name': '受信トレイ', 'color': 0xFF607D8B, 'iconCode': 0xe156},
    );

    return ListTile(
      leading: GestureDetector(
        onTap: onToggle,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: hasPriority && priority != TaskPriority.none
                  ? priority.color
                  : (done ? Colors.green : Colors.grey),
              width: 2,
            ),
            color: done ? Colors.green.withAlpha(50) : null,
          ),
          child: done
              ? const Icon(Icons.check, size: 18, color: Colors.green)
              : null,
        ),
      ),
      title: Text(
        text,
        style: TextStyle(
          decoration: done ? TextDecoration.lineThrough : null,
          color: done ? Colors.grey : null,
        ),
      ),
      subtitle: Row(
        children: [
          if (hasProjects) ...[
            Icon(
              TodoProjectManager.getIcon(project['iconCode'] as int?),
              size: 14,
              color: Colors.grey,
            ),
            const SizedBox(width: 4),
          ],
          if (hasDueDate && dueDate != null) ...[
            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
            const SizedBox(width: 2),
            Text(dueDate, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
          ],
          if (hasTags && tags.isNotEmpty)
            ...tags.take(2).map((tag) => Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(tag, style: const TextStyle(fontSize: 10)),
            )),
        ],
      ),
      trailing: hasPriority && priority != TaskPriority.none
          ? Icon(priority.icon, color: priority.color, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

class _TodoSettingsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> projects;
  final PluginFeatureManager featureManager;
  final VoidCallback onChanged;

  const _TodoSettingsScreen({
    required this.projects,
    required this.featureManager,
    required this.onChanged,
  });

  @override
  State<_TodoSettingsScreen> createState() => _TodoSettingsScreenState();
}

class _TodoSettingsScreenState extends State<_TodoSettingsScreen> {
  late List<Map<String, dynamic>> _projects;

  @override
  void initState() {
    super.initState();
    _projects = List.from(widget.projects);
  }

  Future<void> _reload() async {
    final projects = await TodoProjectManager.getProjects();
    setState(() => _projects = projects);
    widget.onChanged();
  }

  Future<void> _addProject() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ProjectEditDialog(),
    );

    if (result != null) {
      await TodoProjectManager.addProject({
        ...result,
        'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
      });
      await _reload();
    }
  }

  Future<void> _editProject(Map<String, dynamic> project) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ProjectEditDialog(project: project),
    );

    if (result != null) {
      await TodoProjectManager.updateProject(project['id'] as String, result);
      await _reload();
    }
  }

  Future<void> _deleteProject(String projectId) async {
    if (projectId == 'inbox') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('受信トレイは削除できません')),
      );
      return;
    }
    await TodoProjectManager.removeProject(projectId);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo設定'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'reset') {
                await TodoProjectManager.resetToDefaults();
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
          // Feature settings
          ListTile(
            leading: const Icon(Icons.toggle_on),
            title: const Text('機能設定'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PluginFeatureSettings(
                  pluginName: 'Todo',
                  featureManager: widget.featureManager,
                ),
              ),
            ),
          ),
          const Divider(),

          // Projects header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('プロジェクト', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addProject,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('追加'),
                ),
              ],
            ),
          ),

          // Projects list
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _projects.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final item = _projects.removeAt(oldIndex);
              _projects.insert(newIndex, item);
              await TodoProjectManager.saveProjects(_projects);
              widget.onChanged();
              setState(() {});
            },
            itemBuilder: (context, index) {
              final project = _projects[index];
              final isInbox = project['id'] == 'inbox';
              return ListTile(
                key: ValueKey(project['id']),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(project['color'] as int).withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    TodoProjectManager.getIcon(project['iconCode'] as int?),
                    color: Color(project['color'] as int),
                  ),
                ),
                title: Text(project['name'] as String),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _editProject(project),
                    ),
                    if (!isInbox)
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteProject(project['id'] as String),
                      ),
                    const Icon(Icons.drag_handle),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProjectEditDialog extends StatefulWidget {
  final Map<String, dynamic>? project;

  const _ProjectEditDialog({this.project});

  @override
  State<_ProjectEditDialog> createState() => _ProjectEditDialogState();
}

class _ProjectEditDialogState extends State<_ProjectEditDialog> {
  late TextEditingController _nameController;
  late int _selectedColor;
  late int _selectedIcon;

  static const List<int> _colors = [
    0xFF607D8B, 0xFF2196F3, 0xFF4CAF50, 0xFFFF9800,
    0xFFE91E63, 0xFF9C27B0, 0xFFFF5722, 0xFF00BCD4,
  ];

  static const List<int> _icons = [
    0xe156, // inbox
    0xe943, // work
    0xe491, // person
    0xe8cc, // shopping_cart
    0xe88a, // home
    0xe838, // favorite
    0xe80c, // flight
    0xe02f, // fitness_center
    0xe865, // school
    0xe322, // music
    0xe87c, // pets
    0xe52f, // restaurant
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?['name'] as String? ?? '');
    _selectedColor = widget.project?['color'] as int? ?? 0xFF607D8B;
    _selectedIcon = widget.project?['iconCode'] as int? ?? 0xe156;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.project != null ? 'プロジェクトを編集' : '新しいプロジェクト'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'プロジェクト名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('アイコン', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _icons.map((iconCode) => GestureDetector(
              onTap: () => setState(() => _selectedIcon = iconCode),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _selectedIcon == iconCode ? Colors.blue.withAlpha(30) : Colors.grey.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: _selectedIcon == iconCode ? Border.all(color: Colors.blue, width: 2) : null,
                ),
                child: Icon(
                  IconData(iconCode, fontFamily: 'MaterialIcons'),
                  color: Color(_selectedColor),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          const Text('色', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
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
                  border: _selectedColor == color 
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: _selectedColor == color
                      ? [BoxShadow(color: Color(color).withAlpha(100), blurRadius: 8)]
                      : null,
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
                'id': widget.project?['id'] ?? '',
                'name': _nameController.text,
                'color': _selectedColor,
                'iconCode': _selectedIcon,
              });
            }
          },
          child: Text(widget.project != null ? '更新' : '追加'),
        ),
      ],
    );
  }
}

class TaskEditSheet extends StatefulWidget {
  final LogEntry entry;
  final List<Map<String, dynamic>> projects;
  final PluginFeatureManager featureManager;

  const TaskEditSheet({
    super.key,
    required this.entry,
    required this.projects,
    required this.featureManager,
  });

  @override
  State<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<TaskEditSheet> {
  late TextEditingController _textController;
  late TextEditingController _notesController;
  late String _project;
  late TaskPriority _priority;
  DateTime? _dueDate;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.entry.data['text'] as String? ?? '');
    _notesController = TextEditingController(text: widget.entry.data['notes'] as String? ?? '');
    _project = widget.entry.data['project'] as String? ?? 'inbox';
    _priority = TaskPriority.fromValue(widget.entry.data['priority'] as int?);
    
    final dueDateStr = widget.entry.data['dueDate'] as String?;
    if (dueDateStr != null) {
      try {
        _dueDate = DateFormat('yyyy-MM-dd').parse(dueDateStr);
      } catch (_) {}
    }
    
    _tags = (widget.entry.data['tags'] as List?)?.cast<String>() ?? [];
  }

  @override
  void dispose() {
    _textController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getProject(String id) {
    return widget.projects.firstWhere(
      (p) => p['id'] == id,
      orElse: () => widget.projects.isNotEmpty ? widget.projects.first : {'id': 'inbox', 'name': '受信トレイ', 'color': 0xFF607D8B, 'iconCode': 0xe156},
    );
  }

  void _save() {
    Navigator.of(context).pop({
      ...widget.entry.data,
      'text': _textController.text,
      'project': _project,
      'priority': _priority.value,
      'dueDate': _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null,
      'tags': _tags,
      'notes': _notesController.text,
    });
  }

  void _delete() {
    Navigator.of(context).pop({'delete': true});
  }

  @override
  Widget build(BuildContext context) {
    final hasProjects = widget.featureManager.isEnabled('projects');
    final hasPriority = widget.featureManager.isEnabled('priority');
    final hasDueDate = widget.featureManager.isEnabled('due_date');
    final hasTags = widget.featureManager.isEnabled('tags');
    final hasNotes = widget.featureManager.isEnabled('notes');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('タスク編集', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _delete,
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'タスク',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasProjects && widget.projects.isNotEmpty)
                  PopupMenuButton<String>(
                    initialValue: _project,
                    onSelected: (value) => setState(() => _project = value),
                    child: Chip(
                      avatar: Icon(
                        TodoProjectManager.getIcon(_getProject(_project)['iconCode'] as int?),
                        size: 18,
                      ),
                      label: Text(_getProject(_project)['name'] as String),
                    ),
                    itemBuilder: (context) => widget.projects.map((p) => PopupMenuItem(
                      value: p['id'] as String,
                      child: Row(
                        children: [
                          Icon(TodoProjectManager.getIcon(p['iconCode'] as int?), color: Color(p['color'] as int)),
                          const SizedBox(width: 8),
                          Text(p['name'] as String),
                        ],
                      ),
                    )).toList(),
                  ),

                if (hasPriority)
                  PopupMenuButton<TaskPriority>(
                    initialValue: _priority,
                    onSelected: (value) => setState(() => _priority = value),
                    child: Chip(
                      avatar: Icon(_priority.icon, size: 18, color: _priority.color),
                      label: Text('優先度: ${_priority.label}'),
                    ),
                    itemBuilder: (context) => TaskPriority.values.map((p) => PopupMenuItem(
                      value: p,
                      child: Row(
                        children: [
                          Icon(p.icon, color: p.color),
                          const SizedBox(width: 8),
                          Text(p.label),
                        ],
                      ),
                    )).toList(),
                  ),

                if (hasDueDate)
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_dueDate != null 
                        ? DateFormat('M/d').format(_dueDate!)
                        : '期限なし'),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _dueDate = date);
                      }
                    },
                  ),
              ],
            ),

            if (hasTags) ...[
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'タグ（カンマ区切り）',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                onChanged: (value) {
                  _tags = value.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                },
                controller: TextEditingController(text: _tags.join(', ')),
              ),
            ],

            if (hasNotes) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'メモ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
            ],

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _save,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class TodoCompactWidget extends StatelessWidget {
  const TodoCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.check_box_outlined),
        title: Text('Todo'),
        subtitle: Text('タスク管理'),
      ),
    );
  }
}
