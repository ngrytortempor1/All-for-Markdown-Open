/// Advanced Sleep Plugin (Sleep Cycle level)
/// 
/// Full-featured sleep tracking with quality analysis
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';
import '../../core/plugin_feature_system.dart';

class SleepPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'sleep';
  
  @override
  String get name => 'Sleep';
  
  @override
  IconData get icon => Icons.bedtime;
  
  @override
  String get description => '睡眠記録';

  final _dataService = PluginDataService('sleep');
  
  late final PluginFeatureManager featureManager = PluginFeatureManager(
    pluginId: 'sleep',
    availableFeatures: const [
      PluginFeature(
        id: 'quality_rating',
        name: '睡眠品質',
        description: '起床時の気分を評価',
        icon: Icons.star,
      ),
      PluginFeature(
        id: 'sleep_notes',
        name: 'メモ',
        description: '夢や寝つきについて記録',
        icon: Icons.note,
      ),
      PluginFeature(
        id: 'weekly_stats',
        name: '週間統計',
        description: '睡眠時間の推移',
        icon: Icons.show_chart,
      ),
      PluginFeature(
        id: 'wake_factors',
        name: '起床要因',
        description: '何で起きたか記録',
        icon: Icons.alarm,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'nap_tracking',
        name: '昼寝',
        description: '昼寝も記録',
        icon: Icons.snooze,
        defaultEnabled: false,
      ),
    ],
  );

  @override
  Widget buildWidget(BuildContext context) => AdvancedSleepWidget(
    dataService: _dataService,
    featureManager: featureManager,
  );

  @override
  Widget buildCompactWidget(BuildContext context) => const SleepCompactWidget();

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

// Sleep quality levels
const List<Map<String, dynamic>> _qualityLevels = [
  {'score': 1, 'emoji': '😫', 'label': '最悪', 'color': 0xFFE53935},
  {'score': 2, 'emoji': '😕', 'label': '悪い', 'color': 0xFFFF7043},
  {'score': 3, 'emoji': '😐', 'label': '普通', 'color': 0xFF9E9E9E},
  {'score': 4, 'emoji': '😊', 'label': '良い', 'color': 0xFF66BB6A},
  {'score': 5, 'emoji': '😴', 'label': '最高', 'color': 0xFF43A047},
];

// Wake factors
const List<Map<String, dynamic>> _wakeFactors = [
  {'id': 'alarm', 'name': 'アラーム', 'icon': '⏰'},
  {'id': 'natural', 'name': '自然', 'icon': '☀️'},
  {'id': 'noise', 'name': '騒音', 'icon': '🔊'},
  {'id': 'bathroom', 'name': 'トイレ', 'icon': '🚽'},
  {'id': 'phone', 'name': 'スマホ', 'icon': '📱'},
  {'id': 'other', 'name': 'その他', 'icon': '❓'},
];

class AdvancedSleepWidget extends StatefulWidget {
  final PluginDataService dataService;
  final PluginFeatureManager featureManager;
  
  const AdvancedSleepWidget({
    super.key,
    required this.dataService,
    required this.featureManager,
  });

  @override
  State<AdvancedSleepWidget> createState() => _AdvancedSleepWidgetState();
}

class _AdvancedSleepWidgetState extends State<AdvancedSleepWidget> {
  TimeOfDay? _bedTime;
  TimeOfDay? _wakeTime;
  int _quality = 3;
  String? _wakeFactor;
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
    setState(() {
      _entries = entries.reversed.toList();
      
      // Load today's data
      for (final entry in entries) {
        if (entry.data['type'] == 'bed') {
          final parts = (entry.data['time'] as String).split(':');
          _bedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        } else if (entry.data['type'] == 'wake') {
          final parts = (entry.data['time'] as String).split(':');
          _wakeTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          _quality = entry.data['quality'] as int? ?? 3;
        }
      }
    });
  }

  Future<void> _recordBedTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: '就寝時刻',
    );
    
    if (time != null) {
      await widget.dataService.createEntry({
        'type': 'bed',
        'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        'recordedAt': DateFormat('HH:mm').format(DateTime.now()),
      });
      setState(() => _bedTime = time);
      await _loadEntries();
    }
  }

  Future<void> _recordWakeTime() async {
    final hasQuality = widget.featureManager.isEnabled('quality_rating');
    final hasNotes = widget.featureManager.isEnabled('sleep_notes');
    final hasFactors = widget.featureManager.isEnabled('wake_factors');

    if (hasQuality || hasNotes || hasFactors) {
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _WakeUpSheet(
          hasQuality: hasQuality,
          hasNotes: hasNotes,
          hasFactors: hasFactors,
        ),
      );

      if (result != null) {
        final time = result['time'] as TimeOfDay;
        await widget.dataService.createEntry({
          'type': 'wake',
          'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          'quality': result['quality'],
          'note': result['note'],
          'wakeFactor': result['wakeFactor'],
          'recordedAt': DateFormat('HH:mm').format(DateTime.now()),
        });
        setState(() {
          _wakeTime = time;
          _quality = result['quality'] ?? 3;
        });
        await _loadEntries();
      }
    } else {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        helpText: '起床時刻',
      );
      
      if (time != null) {
        await widget.dataService.createEntry({
          'type': 'wake',
          'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          'quality': 3,
          'recordedAt': DateFormat('HH:mm').format(DateTime.now()),
        });
        setState(() => _wakeTime = time);
        await _loadEntries();
      }
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--:--';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _calculateDuration() {
    if (_bedTime == null || _wakeTime == null) return {};
    
    var bedMinutes = _bedTime!.hour * 60 + _bedTime!.minute;
    var wakeMinutes = _wakeTime!.hour * 60 + _wakeTime!.minute;
    
    if (wakeMinutes < bedMinutes) {
      wakeMinutes += 24 * 60;
    }
    
    final duration = wakeMinutes - bedMinutes;
    final hours = duration ~/ 60;
    final minutes = duration % 60;
    
    return {
      'hours': hours,
      'minutes': minutes,
      'total': duration,
      'formatted': '${hours}時間${minutes}分',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasWeeklyStats = widget.featureManager.isEnabled('weekly_stats');
    final hasNap = widget.featureManager.isEnabled('nap_tracking');
    final duration = _calculateDuration();
    final qualityData = _qualityLevels[(_quality - 1).clamp(0, 4)];

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Main sleep display
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.indigo.shade800,
                  Colors.purple.shade900,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('🌙', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                
                if (duration.isNotEmpty) ...[
                  Text(
                    duration['formatted'] as String,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(qualityData['emoji'] as String, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 4),
                      Text(
                        qualityData['label'] as String,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ] else
                  const Text(
                    '睡眠を記録しよう',
                    style: TextStyle(color: Colors.white70),
                  ),

                const SizedBox(height: 20),

                // Bed/Wake times
                Row(
                  children: [
                    Expanded(
                      child: _TimeButton(
                        icon: Icons.bedtime,
                        label: '就寝',
                        time: _formatTime(_bedTime),
                        onTap: _recordBedTime,
                        color: Colors.indigo.shade300,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeButton(
                        icon: Icons.wb_sunny,
                        label: '起床',
                        time: _formatTime(_wakeTime),
                        onTap: _recordWakeTime,
                        color: Colors.orange.shade300,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Nap button (if enabled)
          if (hasNap) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.snooze),
              label: const Text('昼寝を記録'),
            ),
          ],

          // Weekly stats (if enabled)
          if (hasWeeklyStats) ...[
            const SizedBox(height: 24),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('今週の睡眠', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _WeeklySleepChart(todayDuration: duration['total'] as int? ?? 0),
                ],
              ),
            ),
          ],

          // Sleep tips
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡 睡眠のヒント', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _SleepTip(
                  icon: '📱',
                  text: '寝る1時間前はスマホを控えよう',
                ),
                _SleepTip(
                  icon: '🌡️',
                  text: '室温は18-22℃が最適',
                ),
                _SleepTip(
                  icon: '⏰',
                  text: '毎日同じ時間に寝起きしよう',
                ),
              ],
            ),
          ),

          // Settings
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PluginFeatureSettings(
                    pluginName: 'Sleep',
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
    );
  }
}

class _TimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final VoidCallback onTap;
  final Color color;

  const _TimeButton({
    required this.icon,
    required this.label,
    required this.time,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WakeUpSheet extends StatefulWidget {
  final bool hasQuality;
  final bool hasNotes;
  final bool hasFactors;

  const _WakeUpSheet({
    required this.hasQuality,
    required this.hasNotes,
    required this.hasFactors,
  });

  @override
  State<_WakeUpSheet> createState() => _WakeUpSheetState();
}

class _WakeUpSheetState extends State<_WakeUpSheet> {
  TimeOfDay _time = TimeOfDay.now();
  int _quality = 3;
  String? _wakeFactor;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            const Text('☀️ おはよう！', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Time picker
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('起床時刻'),
              trailing: Text(
                '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (time != null) setState(() => _time = time);
              },
            ),

            // Quality rating
            if (widget.hasQuality) ...[
              const SizedBox(height: 16),
              const Text('睡眠の質は？', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _qualityLevels.map((q) {
                  final isSelected = _quality == q['score'];
                  return GestureDetector(
                    onTap: () => setState(() => _quality = q['score'] as int),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Color(q['color'] as int).withAlpha(100)
                            : Colors.grey.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected 
                            ? Border.all(color: Color(q['color'] as int), width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(q['emoji'] as String, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Wake factors
            if (widget.hasFactors) ...[
              const SizedBox(height: 16),
              const Text('何で起きた？', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _wakeFactors.map((f) => ChoiceChip(
                  avatar: Text(f['icon'] as String),
                  label: Text(f['name'] as String),
                  selected: _wakeFactor == f['id'],
                  onSelected: (selected) => setState(() => _wakeFactor = selected ? f['id'] as String : null),
                )).toList(),
              ),
            ],

            // Notes
            if (widget.hasNotes) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'メモ（夢など）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'time': _time,
                'quality': _quality,
                'wakeFactor': _wakeFactor,
                'note': _noteController.text,
              }),
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

class _WeeklySleepChart extends StatelessWidget {
  final int todayDuration;

  const _WeeklySleepChart({required this.todayDuration});

  @override
  Widget build(BuildContext context) {
    const targetHours = 8;
    
    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final day = DateTime.now().subtract(Duration(days: 6 - index));
          final dayName = DateFormat('E', 'ja').format(day);
          final isToday = index == 6;
          final hours = isToday ? (todayDuration / 60) : 0.0;
          final barHeight = (hours / targetHours * 60).clamp(0.0, 60.0);

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isToday && hours > 0)
                  Text('${hours.toStringAsFixed(1)}h', 
                    style: const TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Container(
                  height: barHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isToday ? Colors.indigo : Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _SleepTip extends StatelessWidget {
  final String icon;
  final String text;

  const _SleepTip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class SleepCompactWidget extends StatelessWidget {
  const SleepCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.bedtime),
        title: Text('Sleep'),
        subtitle: Text('睡眠記録'),
      ),
    );
  }
}
