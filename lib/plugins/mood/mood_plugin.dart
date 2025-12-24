/// Advanced Mood Plugin (Daylio level)
/// 
/// Full-featured mood tracking with activities and journaling
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';
import '../../core/plugin_feature_system.dart';

class MoodPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'mood';
  
  @override
  String get name => 'Mood';
  
  @override
  IconData get icon => Icons.mood;
  
  @override
  String get description => '気分記録';

  final _dataService = PluginDataService('mood');
  
  late final PluginFeatureManager featureManager = PluginFeatureManager(
    pluginId: 'mood',
    availableFeatures: const [
      PluginFeature(
        id: 'activities',
        name: 'アクティビティ',
        description: '気分に影響した活動を記録',
        icon: Icons.local_activity,
      ),
      PluginFeature(
        id: 'journal',
        name: 'ジャーナル',
        description: '詳細なメモを追加',
        icon: Icons.note,
      ),
      PluginFeature(
        id: 'photos',
        name: '写真',
        description: '写真を添付',
        icon: Icons.photo,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'factors',
        name: '要因分析',
        description: '気分の要因を記録',
        icon: Icons.analytics,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'weekly_stats',
        name: '週間統計',
        description: '過去7日間の推移',
        icon: Icons.show_chart,
      ),
    ],
  );

  @override
  Widget buildWidget(BuildContext context) => AdvancedMoodWidget(
    dataService: _dataService,
    featureManager: featureManager,
  );

  @override
  Widget buildCompactWidget(BuildContext context) => const MoodCompactWidget();

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

// Mood levels
const List<Map<String, dynamic>> _moods = [
  {'score': 0, 'emoji': '😢', 'label': '最悪', 'color': 0xFFE53935},
  {'score': 1, 'emoji': '😕', 'label': '悪い', 'color': 0xFFFF7043},
  {'score': 2, 'emoji': '😐', 'label': '普通', 'color': 0xFF9E9E9E},
  {'score': 3, 'emoji': '🙂', 'label': '良い', 'color': 0xFF66BB6A},
  {'score': 4, 'emoji': '😊', 'label': '最高', 'color': 0xFF43A047},
];

// Activities
const List<Map<String, dynamic>> _activities = [
  {'id': 'work', 'name': '仕事', 'icon': '💼'},
  {'id': 'exercise', 'name': '運動', 'icon': '🏃'},
  {'id': 'friends', 'name': '友人', 'icon': '👥'},
  {'id': 'family', 'name': '家族', 'icon': '👨‍👩‍👧'},
  {'id': 'dating', 'name': 'デート', 'icon': '💑'},
  {'id': 'relax', 'name': 'リラックス', 'icon': '🛋️'},
  {'id': 'shopping', 'name': '買い物', 'icon': '🛍️'},
  {'id': 'food', 'name': '美味しいもの', 'icon': '🍽️'},
  {'id': 'hobby', 'name': '趣味', 'icon': '🎮'},
  {'id': 'travel', 'name': '旅行', 'icon': '✈️'},
  {'id': 'music', 'name': '音楽', 'icon': '🎵'},
  {'id': 'movie', 'name': '映画', 'icon': '🎬'},
];

class AdvancedMoodWidget extends StatefulWidget {
  final PluginDataService dataService;
  final PluginFeatureManager featureManager;
  
  const AdvancedMoodWidget({
    super.key,
    required this.dataService,
    required this.featureManager,
  });

  @override
  State<AdvancedMoodWidget> createState() => _AdvancedMoodWidgetState();
}

class _AdvancedMoodWidgetState extends State<AdvancedMoodWidget> {
  List<LogEntry> _entries = [];
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
    super.dispose();
  }

  void _onFeatureChanged() => setState(() {});

  Future<void> _loadEntries() async {
    final entries = await widget.dataService.getTodayEntries();
    setState(() => _entries = entries.reversed.toList());
  }

  Future<void> _recordMood(int score) async {
    final hasActivities = widget.featureManager.isEnabled('activities');
    final hasJournal = widget.featureManager.isEnabled('journal');

    if (hasActivities || hasJournal) {
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _MoodEntrySheet(
          score: score,
          hasActivities: hasActivities,
          hasJournal: hasJournal,
        ),
      );

      if (result != null) {
        await widget.dataService.createEntry({
          'score': score,
          'time': DateFormat('HH:mm').format(DateTime.now()),
          ...result,
        });
        await _loadEntries();
      }
    } else {
      await widget.dataService.createEntry({
        'score': score,
        'time': DateFormat('HH:mm').format(DateTime.now()),
      });
      await _loadEntries();
      
      if (mounted) {
        final mood = _moods[score];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${mood['emoji']} ${mood['label']}を記録しました')),
        );
      }
    }
  }

  double get _averageMood {
    if (_entries.isEmpty) return 2.0;
    final sum = _entries.fold<int>(0, (s, e) => s + (e.data['score'] as int? ?? 2));
    return sum / _entries.length;
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasWeeklyStats = widget.featureManager.isEnabled('weekly_stats');

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          
          // Question
          const Text(
            '今の気分は？',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Mood selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _moods.map((mood) {
                return GestureDetector(
                  onTap: () => _recordMood(mood['score'] as int),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(mood['color'] as int).withAlpha(30),
                          border: Border.all(
                            color: Color(mood['color'] as int),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            mood['emoji'] as String,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mood['label'] as String,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 32),

          // Today's average
          if (_entries.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _moods[_averageMood.round()]['emoji'] as String,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('今日の平均', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        _moods[_averageMood.round()]['label'] as String,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Weekly stats (if enabled)
          if (hasWeeklyStats) ...[
            const SizedBox(height: 24),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('今週の気分', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _WeeklyMoodChart(entries: _entries),
                ],
              ),
            ),
          ],

          // Entry list
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('今日の記録 (${_entries.length}回)', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PluginFeatureSettings(
                        pluginName: 'Mood',
                        featureManager: widget.featureManager,
                      ),
                    ),
                  ),
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
              final score = entry.data['score'] as int? ?? 2;
              final mood = _moods[score];
              final time = entry.data['time'] as String? ?? '';
              final activities = (entry.data['activities'] as List?)?.cast<String>() ?? [];
              final note = entry.data['note'] as String? ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(mood['color'] as int).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(mood['emoji'] as String, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(mood['label'] as String),
                      const Spacer(),
                      Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activities.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: activities.map((a) {
                            final activity = _activities.firstWhere(
                              (act) => act['id'] == a,
                              orElse: () => {'icon': '❓'},
                            );
                            return Text(activity['icon'] as String, style: const TextStyle(fontSize: 12));
                          }).toList(),
                        ),
                      if (note.isNotEmpty)
                        Text(
                          note,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

class _MoodEntrySheet extends StatefulWidget {
  final int score;
  final bool hasActivities;
  final bool hasJournal;

  const _MoodEntrySheet({
    required this.score,
    required this.hasActivities,
    required this.hasJournal,
  });

  @override
  State<_MoodEntrySheet> createState() => _MoodEntrySheetState();
}

class _MoodEntrySheetState extends State<_MoodEntrySheet> {
  final _noteController = TextEditingController();
  final Set<String> _selectedActivities = {};

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = _moods[widget.score];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mood display
            Row(
              children: [
                Text(mood['emoji'] as String, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 12),
                Text(
                  mood['label'] as String,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Activities
            if (widget.hasActivities) ...[
              const Text('何をしていた？', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _activities.map((activity) {
                  final isSelected = _selectedActivities.contains(activity['id']);
                  return FilterChip(
                    avatar: Text(activity['icon'] as String),
                    label: Text(activity['name'] as String),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedActivities.add(activity['id'] as String);
                        } else {
                          _selectedActivities.remove(activity['id']);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Journal
            if (widget.hasJournal) ...[
              const Text('メモ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: '今の気持ちを書いてみよう...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
            ],

            // Save button
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'activities': _selectedActivities.toList(),
                  'note': _noteController.text,
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('記録する'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyMoodChart extends StatelessWidget {
  final List<LogEntry> entries;

  const _WeeklyMoodChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final day = DateTime.now().subtract(Duration(days: 6 - index));
          final dayName = DateFormat('E', 'ja').format(day);
          final isToday = index == 6;
          
          // This is a simplified version - would need actual data
          final score = isToday && entries.isNotEmpty 
              ? entries.first.data['score'] as int? ?? 2
              : 2;
          final mood = _moods[score.clamp(0, 4)];

          return Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isToday 
                      ? Color(mood['color'] as int).withAlpha(50)
                      : Colors.grey.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    isToday ? (mood['emoji'] as String) : '-',
                    style: TextStyle(fontSize: isToday ? 20 : 14),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dayName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class MoodCompactWidget extends StatelessWidget {
  const MoodCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.mood),
        title: Text('Mood'),
        subtitle: Text('気分記録'),
      ),
    );
  }
}
