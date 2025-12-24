/// Screen Time Plugin
/// 
/// Tracks and logs app usage time
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';

class ScreenTimePlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'screen_time';
  
  @override
  String get name => 'Screen Time';
  
  @override
  IconData get icon => Icons.phone_android;
  
  @override
  String get description => 'スクリーンタイム';

  final _dataService = PluginDataService('screen_time');

  @override
  Widget buildWidget(BuildContext context) => ScreenTimeWidget(dataService: _dataService);

  @override
  Widget buildCompactWidget(BuildContext context) => const ScreenTimeCompactWidget();

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

class ScreenTimeWidget extends StatefulWidget {
  final PluginDataService dataService;
  
  const ScreenTimeWidget({super.key, required this.dataService});

  @override
  State<ScreenTimeWidget> createState() => _ScreenTimeWidgetState();
}

class _ScreenTimeWidgetState extends State<ScreenTimeWidget> {
  int _totalMinutes = 0;
  int _goalMinutes = 180; // 3 hours default
  Map<String, int> _appUsage = {};
  List<LogEntry> _entries = [];
  bool _loading = true;
  DateTime? _sessionStart;

  static const List<Map<String, dynamic>> _commonApps = [
    {'id': 'sns', 'name': 'SNS', 'icon': '📱', 'color': 0xFF3F51B5},
    {'id': 'youtube', 'name': 'YouTube', 'icon': '▶️', 'color': 0xFFFF0000},
    {'id': 'game', 'name': 'ゲーム', 'icon': '🎮', 'color': 0xFF9C27B0},
    {'id': 'work', 'name': '仕事', 'icon': '💼', 'color': 0xFF2196F3},
    {'id': 'browser', 'name': 'ブラウザ', 'icon': '🌐', 'color': 0xFF4CAF50},
    {'id': 'music', 'name': '音楽', 'icon': '🎵', 'color': 0xFFFF9800},
    {'id': 'reading', 'name': '読書', 'icon': '📚', 'color': 0xFF795548},
    {'id': 'other', 'name': 'その他', 'icon': '📦', 'color': 0xFF607D8B},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _trackSession();
  }

  @override
  void dispose() {
    _endSession();
    super.dispose();
  }

  Future<void> _trackSession() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('screen_time_date');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (lastDate != today) {
      // New day, reset
      await prefs.setString('screen_time_date', today);
      await prefs.setInt('screen_time_minutes', 0);
    }
    
    _sessionStart = DateTime.now();
  }

  Future<void> _endSession() async {
    if (_sessionStart != null) {
      final duration = DateTime.now().difference(_sessionStart!);
      final minutes = duration.inMinutes;
      if (minutes > 0) {
        await _addMinutes(minutes, 'other');
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final goal = prefs.getInt('screen_time_goal') ?? 180;
    
    final entries = await widget.dataService.getTodayEntries();
    
    // Calculate totals
    int total = 0;
    Map<String, int> usage = {};
    
    for (final entry in entries) {
      final minutes = entry.data['minutes'] as int? ?? 0;
      final app = entry.data['app'] as String? ?? 'other';
      total += minutes;
      usage[app] = (usage[app] ?? 0) + minutes;
    }
    
    setState(() {
      _totalMinutes = total;
      _goalMinutes = goal;
      _appUsage = usage;
      _entries = entries.reversed.toList();
      _loading = false;
    });
  }

  Future<void> _addMinutes(int minutes, String appId) async {
    if (minutes <= 0) return;

    final app = _commonApps.firstWhere(
      (a) => a['id'] == appId,
      orElse: () => _commonApps.last,
    );

    await widget.dataService.createEntry({
      'minutes': minutes,
      'app': appId,
      'appName': app['name'],
      'icon': app['icon'],
      'time': DateFormat('HH:mm').format(DateTime.now()),
    });

    await _loadData();
  }

  Future<void> _setGoal() async {
    final controller = TextEditingController(text: _goalMinutes.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('1日の目標'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: '分',
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('screen_time_goal', result);
      setState(() => _goalMinutes = result);
    }
  }

  Future<void> _addUsage() async {
    String selectedApp = 'sns';
    int minutes = 30;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('使用時間を追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonApps.map((app) {
                    final isSelected = selectedApp == app['id'];
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedApp = app['id'] as String),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Color(app['color'] as int).withAlpha(50)
                              : Colors.grey.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Color(app['color'] as int), width: 2)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(app['icon'] as String),
                            const SizedBox(width: 4),
                            Text(app['name'] as String),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('時間:'),
                    Expanded(
                      child: Slider(
                        value: minutes.toDouble(),
                        min: 5,
                        max: 180,
                        divisions: 35,
                        label: '$minutes分',
                        onChanged: (v) => setModalState(() => minutes = v.round()),
                      ),
                    ),
                    SizedBox(width: 60, child: Text('$minutes分')),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, {'app': selectedApp, 'minutes': minutes}),
                    child: const Text('追加'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      await _addMinutes(result['minutes'] as int, result['app'] as String);
    }
  }

  String _formatTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}時間${mins > 0 ? ' ${mins}分' : ''}';
    }
    return '$mins分';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final progress = _totalMinutes / _goalMinutes;
    final isOverLimit = _totalMinutes > _goalMinutes;
    final progressColor = isOverLimit ? Colors.red : Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Main display
          Container(
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
                        Icon(
                          isOverLimit ? Icons.warning : Icons.phone_android,
                          size: 32,
                          color: progressColor,
                        ),
                        Text(
                          _formatTime(_totalMinutes),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '目標: ${_formatTime(_goalMinutes)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (isOverLimit)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '⚠️ 目標を${_formatTime(_totalMinutes - _goalMinutes)}超過',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _addUsage,
                icon: const Icon(Icons.add),
                label: const Text('追加'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _setGoal,
                icon: const Icon(Icons.flag),
                label: const Text('目標'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // App breakdown
          if (_appUsage.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('アプリ別', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ..._appUsage.entries.map((e) {
              final app = _commonApps.firstWhere(
                (a) => a['id'] == e.key,
                orElse: () => _commonApps.last,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(app['icon'] as String, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Text(app['name'] as String),
                    const Spacer(),
                    Text(
                      _formatTime(e.value),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class ScreenTimeCompactWidget extends StatelessWidget {
  const ScreenTimeCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.phone_android, color: Colors.blue),
        title: Text('Screen Time'),
        subtitle: Text('スクリーンタイム'),
      ),
    );
  }
}
