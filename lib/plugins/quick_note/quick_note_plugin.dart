/// Advanced Quick Note Plugin (Google Keep level)
/// 
/// Full-featured note taking with colors, pins, and categories
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';
import '../../core/plugin_feature_system.dart';

class QuickNotePlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'quick_note';
  
  @override
  String get name => 'Notes';
  
  @override
  IconData get icon => Icons.note;
  
  @override
  String get description => 'メモ';

  final _dataService = PluginDataService('quick_note');
  
  late final PluginFeatureManager featureManager = PluginFeatureManager(
    pluginId: 'quick_note',
    availableFeatures: const [
      PluginFeature(
        id: 'colors',
        name: 'カラー',
        description: 'メモに色を付ける',
        icon: Icons.palette,
      ),
      PluginFeature(
        id: 'pins',
        name: 'ピン留め',
        description: '重要なメモを上部に固定',
        icon: Icons.push_pin,
      ),
      PluginFeature(
        id: 'tags',
        name: 'タグ',
        description: 'メモを分類',
        icon: Icons.label,
      ),
      PluginFeature(
        id: 'checklists',
        name: 'チェックリスト',
        description: 'リスト形式のメモ',
        icon: Icons.checklist,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'search',
        name: '検索',
        description: 'メモを検索',
        icon: Icons.search,
        defaultEnabled: false,
      ),
    ],
  );

  @override
  Widget buildWidget(BuildContext context) => AdvancedNoteWidget(
    dataService: _dataService,
    featureManager: featureManager,
  );

  @override
  Widget buildCompactWidget(BuildContext context) => const NoteCompactWidget();

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

// Note colors
const List<Map<String, dynamic>> _noteColors = [
  {'name': 'default', 'color': 0xFFFFFFFF},
  {'name': 'red', 'color': 0xFFFFCDD2},
  {'name': 'orange', 'color': 0xFFFFE0B2},
  {'name': 'yellow', 'color': 0xFFFFF9C4},
  {'name': 'green', 'color': 0xFFC8E6C9},
  {'name': 'blue', 'color': 0xFFBBDEFB},
  {'name': 'purple', 'color': 0xFFE1BEE7},
  {'name': 'pink', 'color': 0xFFF8BBD9},
];

class AdvancedNoteWidget extends StatefulWidget {
  final PluginDataService dataService;
  final PluginFeatureManager featureManager;
  
  const AdvancedNoteWidget({
    super.key,
    required this.dataService,
    required this.featureManager,
  });

  @override
  State<AdvancedNoteWidget> createState() => _AdvancedNoteWidgetState();
}

class _AdvancedNoteWidgetState extends State<AdvancedNoteWidget> {
  final _controller = TextEditingController();
  List<LogEntry> _entries = [];
  String _searchQuery = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    widget.featureManager.addListener(_onFeatureChanged);
  }

  Future<void> _initialize() async {
    await widget.featureManager.initialize();
    await _loadEntries();
    setState(() => _initialized = true);
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
    // Sort: pinned first, then by time
    entries.sort((a, b) {
      final pinA = a.data['pinned'] == true ? 0 : 1;
      final pinB = b.data['pinned'] == true ? 0 : 1;
      if (pinA != pinB) return pinA.compareTo(pinB);
      return 0;
    });
    setState(() => _entries = entries.reversed.toList());
  }

  Future<void> _addQuickNote() async {
    if (_controller.text.isEmpty) return;
    
    await widget.dataService.createEntry({
      'text': _controller.text,
      'time': DateFormat('HH:mm').format(DateTime.now()),
      'color': 0xFFFFFFFF,
      'pinned': false,
    });
    
    _controller.clear();
    await _loadEntries();
  }

  Future<void> _addDetailedNote() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddNoteSheet(featureManager: widget.featureManager),
    );

    if (result != null) {
      await widget.dataService.createEntry({
        'text': result['text'],
        'title': result['title'],
        'color': result['color'],
        'pinned': result['pinned'] ?? false,
        'tags': result['tags'] ?? [],
        'checklist': result['checklist'],
        'time': DateFormat('HH:mm').format(DateTime.now()),
      });
      await _loadEntries();
    }
  }

  Future<void> _editNote(LogEntry entry) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddNoteSheet(
        featureManager: widget.featureManager,
        existingEntry: entry,
      ),
    );

    if (result != null) {
      if (result['delete'] == true) {
        await widget.dataService.deleteEntry(entry.id);
      } else {
        await widget.dataService.updateEntry(entry.id, {
          ...entry.data,
          ...result,
        });
      }
      await _loadEntries();
    }
  }

  Future<void> _togglePin(LogEntry entry) async {
    await widget.dataService.updateEntry(entry.id, {
      ...entry.data,
      'pinned': !(entry.data['pinned'] as bool? ?? false),
    });
    await _loadEntries();
  }

  List<LogEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;
    return _entries.where((e) {
      final text = e.data['text'] as String? ?? '';
      final title = e.data['title'] as String? ?? '';
      return text.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasColors = widget.featureManager.isEnabled('colors');
    final hasPins = widget.featureManager.isEnabled('pins');
    final hasSearch = widget.featureManager.isEnabled('search');
    
    final entries = _filteredEntries;
    final pinnedEntries = entries.where((e) => e.data['pinned'] == true).toList();
    final otherEntries = entries.where((e) => e.data['pinned'] != true).toList();

    return Column(
      children: [
        // Search bar (if enabled)
        if (hasSearch)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'メモを検索...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

        // Quick add bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'メモを追加...',
                    border: const OutlineInputBorder(),
                    suffixIcon: hasColors 
                        ? IconButton(
                            icon: const Icon(Icons.edit_note),
                            onPressed: _addDetailedNote,
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _addQuickNote(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addQuickNote,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),

        // Notes list
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('メモがありません', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Pinned notes
                    if (pinnedEntries.isNotEmpty && hasPins) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.push_pin, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('ピン留め', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                      ...pinnedEntries.map((e) => _NoteCard(
                        entry: e,
                        hasColors: hasColors,
                        hasPins: hasPins,
                        onTap: () => _editNote(e),
                        onTogglePin: () => _togglePin(e),
                      )),
                      const SizedBox(height: 16),
                      if (otherEntries.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('その他', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ),
                    ],
                    
                    // Other notes
                    ...otherEntries.map((e) => _NoteCard(
                      entry: e,
                      hasColors: hasColors,
                      hasPins: hasPins,
                      onTap: () => _editNote(e),
                      onTogglePin: () => _togglePin(e),
                    )),
                    
                    // Settings button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PluginFeatureSettings(
                              pluginName: 'Notes',
                              featureManager: widget.featureManager,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('設定'),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final LogEntry entry;
  final bool hasColors;
  final bool hasPins;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  const _NoteCard({
    required this.entry,
    required this.hasColors,
    required this.hasPins,
    required this.onTap,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final text = entry.data['text'] as String? ?? '';
    final title = entry.data['title'] as String? ?? '';
    final time = entry.data['time'] as String? ?? '';
    final color = hasColors 
        ? Color(entry.data['color'] as int? ?? 0xFFFFFFFF)
        : Colors.white;
    final isPinned = entry.data['pinned'] as bool? ?? false;
    final tags = (entry.data['tags'] as List?)?.cast<String>() ?? [];

    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (title.isNotEmpty) ...[
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (hasPins)
                    IconButton(
                      icon: Icon(
                        isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 18,
                        color: isPinned ? Colors.black87 : Colors.grey,
                      ),
                      onPressed: onTogglePin,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              if (title.isNotEmpty) const SizedBox(height: 8),
              Text(
                text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    time,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ...tags.take(2).map((tag) => Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(tag, style: const TextStyle(fontSize: 10)),
                    )),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddNoteSheet extends StatefulWidget {
  final PluginFeatureManager featureManager;
  final LogEntry? existingEntry;

  const _AddNoteSheet({
    required this.featureManager,
    this.existingEntry,
  });

  @override
  State<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<_AddNoteSheet> {
  late TextEditingController _titleController;
  late TextEditingController _textController;
  late TextEditingController _tagController;
  int _selectedColor = 0xFFFFFFFF;
  bool _isPinned = false;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    final entry = widget.existingEntry;
    _titleController = TextEditingController(text: entry?.data['title'] as String? ?? '');
    _textController = TextEditingController(text: entry?.data['text'] as String? ?? '');
    _tagController = TextEditingController();
    _selectedColor = entry?.data['color'] as int? ?? 0xFFFFFFFF;
    _isPinned = entry?.data['pinned'] as bool? ?? false;
    _tags = (entry?.data['tags'] as List?)?.cast<String>() ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasColors = widget.featureManager.isEnabled('colors');
    final hasPins = widget.featureManager.isEnabled('pins');
    final hasTags = widget.featureManager.isEnabled('tags');
    final isEditing = widget.existingEntry != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Color(_selectedColor),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Text(
                  isEditing ? 'メモを編集' : '新しいメモ',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => Navigator.pop(context, {'delete': true}),
                  ),
                if (hasPins)
                  IconButton(
                    icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                    onPressed: () => setState(() => _isPinned = !_isPinned),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'タイトル（任意）',
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            // Content
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'メモを入力...',
                border: InputBorder.none,
              ),
              maxLines: 5,
              autofocus: true,
            ),

            // Tags
            if (hasTags) ...[
              Wrap(
                spacing: 4,
                children: [
                  ..._tags.map((tag) => Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('タグ', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final tag = await showDialog<String>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('タグを追加'),
                          content: TextField(
                            controller: _tagController,
                            autofocus: true,
                            decoration: const InputDecoration(hintText: 'タグ名'),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, _tagController.text),
                              child: const Text('追加'),
                            ),
                          ],
                        ),
                      );
                      if (tag != null && tag.isNotEmpty) {
                        setState(() => _tags.add(tag));
                        _tagController.clear();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Color picker
            if (hasColors) ...[
              const SizedBox(height: 8),
              Row(
                children: _noteColors.map((c) {
                  final color = c['color'] as int;
                  final isSelected = _selectedColor == color;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: isSelected 
                            ? const Icon(Icons.check, size: 16)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                if (_textController.text.isEmpty) return;
                Navigator.pop(context, {
                  'title': _titleController.text,
                  'text': _textController.text,
                  'color': _selectedColor,
                  'pinned': _isPinned,
                  'tags': _tags,
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(isEditing ? '更新' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class NoteCompactWidget extends StatelessWidget {
  const NoteCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.note),
        title: Text('Notes'),
        subtitle: Text('メモ'),
      ),
    );
  }
}
