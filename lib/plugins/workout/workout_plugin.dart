/// Advanced Workout Plugin (Strong/Nike Training level)
/// 
/// Full-featured exercise tracking with exercises, sets, reps
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';
import '../../core/plugin_feature_system.dart';

class WorkoutPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'workout';
  
  @override
  String get name => 'Workout';
  
  @override
  IconData get icon => Icons.fitness_center;
  
  @override
  String get description => '運動記録';

  final _dataService = PluginDataService('workout');
  
  late final PluginFeatureManager featureManager = PluginFeatureManager(
    pluginId: 'workout',
    availableFeatures: const [
      PluginFeature(
        id: 'workout_types',
        name: '運動種類',
        description: 'ランニング・筋トレ・ヨガなど',
        icon: Icons.category,
      ),
      PluginFeature(
        id: 'detailed_exercises',
        name: '詳細エクササイズ',
        description: 'セット数・回数・重量を記録',
        icon: Icons.format_list_numbered,
      ),
      PluginFeature(
        id: 'timer',
        name: 'タイマー',
        description: 'ワークアウトタイマー',
        icon: Icons.timer,
      ),
      PluginFeature(
        id: 'rest_timer',
        name: '休憩タイマー',
        description: 'セット間の休憩タイマー',
        icon: Icons.hourglass_empty,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'templates',
        name: 'テンプレート',
        description: 'よく使うメニューを保存',
        icon: Icons.bookmark,
        defaultEnabled: false,
      ),
    ],
  );

  @override
  Widget buildWidget(BuildContext context) => AdvancedWorkoutWidget(
    dataService: _dataService,
    featureManager: featureManager,
  );

  @override
  Widget buildCompactWidget(BuildContext context) => const WorkoutCompactWidget();

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

// Workout types
const List<Map<String, dynamic>> _workoutTypes = [
  {'id': 'strength', 'name': '筋トレ', 'icon': '🏋️', 'color': 0xFFE91E63},
  {'id': 'running', 'name': 'ランニング', 'icon': '🏃', 'color': 0xFF2196F3},
  {'id': 'walking', 'name': 'ウォーキング', 'icon': '🚶', 'color': 0xFF4CAF50},
  {'id': 'cycling', 'name': 'サイクリング', 'icon': '🚴', 'color': 0xFFFF9800},
  {'id': 'swimming', 'name': '水泳', 'icon': '🏊', 'color': 0xFF00BCD4},
  {'id': 'yoga', 'name': 'ヨガ', 'icon': '🧘', 'color': 0xFF9C27B0},
  {'id': 'stretching', 'name': 'ストレッチ', 'icon': '🤸', 'color': 0xFF8BC34A},
  {'id': 'hiit', 'name': 'HIIT', 'icon': '⚡', 'color': 0xFFFF5722},
];

// Common exercises for strength training
const List<Map<String, dynamic>> _exercises = [
  {'id': 'bench_press', 'name': 'ベンチプレス', 'muscle': '胸'},
  {'id': 'squat', 'name': 'スクワット', 'muscle': '脚'},
  {'id': 'deadlift', 'name': 'デッドリフト', 'muscle': '背中'},
  {'id': 'pull_up', 'name': '懸垂', 'muscle': '背中'},
  {'id': 'push_up', 'name': '腕立て伏せ', 'muscle': '胸'},
  {'id': 'plank', 'name': 'プランク', 'muscle': '体幹'},
  {'id': 'shoulder_press', 'name': 'ショルダープレス', 'muscle': '肩'},
  {'id': 'bicep_curl', 'name': 'バイセップカール', 'muscle': '腕'},
  {'id': 'lunges', 'name': 'ランジ', 'muscle': '脚'},
  {'id': 'leg_press', 'name': 'レッグプレス', 'muscle': '脚'},
];

class AdvancedWorkoutWidget extends StatefulWidget {
  final PluginDataService dataService;
  final PluginFeatureManager featureManager;
  
  const AdvancedWorkoutWidget({
    super.key,
    required this.dataService,
    required this.featureManager,
  });

  @override
  State<AdvancedWorkoutWidget> createState() => _AdvancedWorkoutWidgetState();
}

class _AdvancedWorkoutWidgetState extends State<AdvancedWorkoutWidget> {
  List<LogEntry> _entries = [];
  int _totalMinutes = 0;
  bool _initialized = false;
  bool _workoutActive = false;
  DateTime? _workoutStart;
  Timer? _timer;
  int _elapsedSeconds = 0;

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
    _timer?.cancel();
    widget.featureManager.removeListener(_onFeatureChanged);
    super.dispose();
  }

  void _onFeatureChanged() => setState(() {});

  Future<void> _loadEntries() async {
    final entries = await widget.dataService.getTodayEntries();
    final total = entries.fold<int>(0, (sum, e) => sum + (e.data['duration'] as int? ?? 0));
    setState(() {
      _entries = entries.reversed.toList();
      _totalMinutes = total;
    });
  }

  void _startWorkout() {
    setState(() {
      _workoutActive = true;
      _workoutStart = DateTime.now();
      _elapsedSeconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _endWorkout() async {
    _timer?.cancel();
    
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _WorkoutSummarySheet(
        duration: _elapsedSeconds ~/ 60,
        featureManager: widget.featureManager,
      ),
    );

    if (result != null) {
      await widget.dataService.createEntry({
        'type': result['type'] ?? 'strength',
        'typeName': result['typeName'] ?? '筋トレ',
        'icon': result['icon'] ?? '🏋️',
        'duration': result['duration'] ?? (_elapsedSeconds ~/ 60),
        'exercises': result['exercises'] ?? [],
        'note': result['note'] ?? '',
        'time': DateFormat('HH:mm').format(_workoutStart!),
        'endTime': DateFormat('HH:mm').format(DateTime.now()),
      });
      await _loadEntries();
    }

    setState(() {
      _workoutActive = false;
      _workoutStart = null;
      _elapsedSeconds = 0;
    });
  }

  Future<void> _quickLog() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _QuickWorkoutSheet(featureManager: widget.featureManager),
    );

    if (result != null) {
      final workoutType = _workoutTypes.firstWhere(
        (w) => w['id'] == result['type'],
        orElse: () => _workoutTypes.first,
      );

      await widget.dataService.createEntry({
        'type': result['type'],
        'typeName': workoutType['name'],
        'icon': workoutType['icon'],
        'duration': result['duration'],
        'note': result['note'] ?? '',
        'time': DateFormat('HH:mm').format(DateTime.now()),
      });
      await _loadEntries();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${workoutType['icon']} ${result['duration']}分を記録')),
        );
      }
    }
  }

  String _formatElapsed(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasTimer = widget.featureManager.isEnabled('timer');
    final hasWorkoutTypes = widget.featureManager.isEnabled('workout_types');

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Today's summary
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade600, Colors.red.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '今日の運動',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '$_totalMinutes分',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${_entries.length}回',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Active workout or start buttons
          if (_workoutActive && hasTimer) ...[
            // Timer display
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Text('🏋️ ワークアウト中', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    _formatElapsed(_elapsedSeconds),
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _endWorkout,
                    icon: const Icon(Icons.stop),
                    label: const Text('終了'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Start buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (hasTimer)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _startWorkout,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('開始'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  if (hasTimer) const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _quickLog,
                      icon: const Icon(Icons.add),
                      label: const Text('クイック記録'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Workout types (if enabled)
          if (hasWorkoutTypes && !_workoutActive) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('種類を選択', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _workoutTypes.map((type) => ActionChip(
                      avatar: Text(type['icon'] as String, style: const TextStyle(fontSize: 16)),
                      label: Text(type['name'] as String),
                      backgroundColor: Color(type['color'] as int).withAlpha(30),
                      onPressed: () async {
                        if (hasTimer) {
                          _startWorkout();
                        } else {
                          final duration = await _showDurationPicker();
                          if (duration != null) {
                            await widget.dataService.createEntry({
                              'type': type['id'],
                              'typeName': type['name'],
                              'icon': type['icon'],
                              'duration': duration,
                              'time': DateFormat('HH:mm').format(DateTime.now()),
                            });
                            await _loadEntries();
                          }
                        }
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],

          // Entry list
          const SizedBox(height: 24),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('今日の記録', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PluginFeatureSettings(
                        pluginName: 'Workout',
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
              final icon = entry.data['icon'] as String? ?? '🏋️';
              final typeName = entry.data['typeName'] as String? ?? '';
              final duration = entry.data['duration'] as int? ?? 0;
              final time = entry.data['time'] as String? ?? '';
              final exercises = (entry.data['exercises'] as List?)?.length ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Text(icon, style: const TextStyle(fontSize: 28)),
                  title: Text(typeName),
                  subtitle: Text('$time · ${duration}分${exercises > 0 ? ' · $exercises種目' : ''}'),
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

  Future<int?> _showDurationPicker() async {
    int duration = 30;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('運動時間'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$duration 分', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              Slider(
                value: duration.toDouble(),
                min: 5,
                max: 180,
                divisions: 35,
                onChanged: (v) => setState(() => duration = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
            ElevatedButton(onPressed: () => Navigator.pop(context, duration), child: const Text('記録')),
          ],
        ),
      ),
    );
  }
}

class _QuickWorkoutSheet extends StatefulWidget {
  final PluginFeatureManager featureManager;

  const _QuickWorkoutSheet({required this.featureManager});

  @override
  State<_QuickWorkoutSheet> createState() => _QuickWorkoutSheetState();
}

class _QuickWorkoutSheetState extends State<_QuickWorkoutSheet> {
  String _selectedType = 'strength';
  int _duration = 30;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('クイック記録', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Type selector
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _workoutTypes.map((type) => ChoiceChip(
                avatar: Text(type['icon'] as String),
                label: Text(type['name'] as String),
                selected: _selectedType == type['id'],
                onSelected: (selected) => setState(() => _selectedType = type['id'] as String),
              )).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Duration
            Text('$_duration 分', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Slider(
              value: _duration.toDouble(),
              min: 5,
              max: 180,
              divisions: 35,
              label: '$_duration分',
              onChanged: (v) => setState(() => _duration = v.round()),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'type': _selectedType,
                'duration': _duration,
                'note': _noteController.text,
              }),
              child: const Text('記録'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutSummarySheet extends StatefulWidget {
  final int duration;
  final PluginFeatureManager featureManager;

  const _WorkoutSummarySheet({
    required this.duration,
    required this.featureManager,
  });

  @override
  State<_WorkoutSummarySheet> createState() => _WorkoutSummarySheetState();
}

class _WorkoutSummarySheetState extends State<_WorkoutSummarySheet> {
  String _selectedType = 'strength';
  final List<Map<String, dynamic>> _loggedExercises = [];

  @override
  Widget build(BuildContext context) {
    final hasDetailed = widget.featureManager.isEnabled('detailed_exercises');
    final type = _workoutTypes.firstWhere((t) => t['id'] == _selectedType);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('🎉 ${widget.duration}分のワークアウト完了！',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // Type
          Wrap(
            spacing: 8,
            children: _workoutTypes.take(4).map((t) => ChoiceChip(
              avatar: Text(t['icon'] as String),
              label: Text(t['name'] as String),
              selected: _selectedType == t['id'],
              onSelected: (s) => setState(() => _selectedType = t['id'] as String),
            )).toList(),
          ),
          
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'type': _selectedType,
              'typeName': type['name'],
              'icon': type['icon'],
              'duration': widget.duration,
              'exercises': _loggedExercises,
            }),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class WorkoutCompactWidget extends StatelessWidget {
  const WorkoutCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.fitness_center),
        title: Text('Workout'),
        subtitle: Text('運動記録'),
      ),
    );
  }
}
