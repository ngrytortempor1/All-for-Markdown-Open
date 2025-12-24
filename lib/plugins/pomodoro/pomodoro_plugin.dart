/// Advanced Pomodoro Plugin
/// 
/// Full-featured focus timer with customizable settings
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';
import '../../core/plugin_feature_system.dart';

class PomodoroPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'pomodoro';
  
  @override
  String get name => 'Pomodoro';
  
  @override
  IconData get icon => Icons.timer;
  
  @override
  String get description => '集中タイマー';

  final _dataService = PluginDataService('pomodoro');
  
  late final PluginFeatureManager featureManager = PluginFeatureManager(
    pluginId: 'pomodoro',
    availableFeatures: const [
      PluginFeature(
        id: 'custom_duration',
        name: 'カスタム時間',
        description: '作業時間を自由に設定',
        icon: Icons.timer,
      ),
      PluginFeature(
        id: 'break_timer',
        name: '休憩タイマー',
        description: 'ポモドーロ完了後に休憩タイマー',
        icon: Icons.coffee,
      ),
      PluginFeature(
        id: 'daily_goal',
        name: '日次目標',
        description: '1日のポモドーロ目標を設定',
        icon: Icons.flag,
      ),
      PluginFeature(
        id: 'statistics',
        name: '統計',
        description: '集中時間の統計表示',
        icon: Icons.bar_chart,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'sound',
        name: '完了音',
        description: 'タイマー完了時に通知音',
        icon: Icons.notifications,
        defaultEnabled: false,
      ),
    ],
  );

  @override
  Widget buildWidget(BuildContext context) => AdvancedPomodoroWidget(
    dataService: _dataService,
    featureManager: featureManager,
  );

  @override
  Widget buildCompactWidget(BuildContext context) => const PomodoroCompactWidget();

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
class PomodoroSettingsManager {
  static const _durationsKey = 'pomodoro_durations';
  static const _breakDurationKey = 'pomodoro_break';
  static const _dailyGoalKey = 'pomodoro_goal';

  static final List<int> defaultDurations = [15, 25, 45, 60];

  static Future<List<int>> getDurations() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_durationsKey);
    if (stored == null) return defaultDurations;
    final List<dynamic> decoded = jsonDecode(stored);
    return decoded.cast<int>();
  }

  static Future<void> saveDurations(List<int> durations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_durationsKey, jsonEncode(durations));
  }

  static Future<int> getBreakDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_breakDurationKey) ?? 5;
  }

  static Future<void> setBreakDuration(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_breakDurationKey, minutes);
  }

  static Future<int> getDailyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyGoalKey) ?? 8;
  }

  static Future<void> setDailyGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyGoalKey, goal);
  }

  static Future<void> resetToDefaults() async {
    await saveDurations(defaultDurations);
    await setBreakDuration(5);
    await setDailyGoal(8);
  }
}

class AdvancedPomodoroWidget extends StatefulWidget {
  final PluginDataService dataService;
  final PluginFeatureManager featureManager;
  
  const AdvancedPomodoroWidget({
    super.key,
    required this.dataService,
    required this.featureManager,
  });

  @override
  State<AdvancedPomodoroWidget> createState() => _AdvancedPomodoroWidgetState();
}

class _AdvancedPomodoroWidgetState extends State<AdvancedPomodoroWidget> {
  final _taskController = TextEditingController();
  
  List<int> _durations = [15, 25, 45, 60];
  int _selectedDuration = 25;
  int _seconds = 25 * 60;
  int _breakDuration = 5;
  bool _isRunning = false;
  bool _isBreak = false;
  Timer? _timer;
  List<LogEntry> _entries = [];
  int _dailyGoal = 8;
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
    final durations = await PomodoroSettingsManager.getDurations();
    final breakDuration = await PomodoroSettingsManager.getBreakDuration();
    final dailyGoal = await PomodoroSettingsManager.getDailyGoal();
    setState(() {
      _durations = durations;
      _breakDuration = breakDuration;
      _dailyGoal = dailyGoal;
      if (_durations.isNotEmpty && !_durations.contains(_selectedDuration)) {
        _selectedDuration = _durations.first;
        _seconds = _selectedDuration * 60;
      }
    });
  }

  Future<void> _loadEntries() async {
    final entries = await widget.dataService.getTodayEntries();
    setState(() => _entries = entries.reversed.toList());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _taskController.dispose();
    widget.featureManager.removeListener(_onFeatureChanged);
    super.dispose();
  }

  void _onFeatureChanged() => setState(() {});

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        _completeSession();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _seconds = _selectedDuration * 60;
      _isRunning = false;
      _isBreak = false;
    });
  }

  Future<void> _completeSession() async {
    _timer?.cancel();
    setState(() => _isRunning = false);
    
    if (!_isBreak) {
      await widget.dataService.createEntry({
        'duration': _selectedDuration,
        'task': _taskController.text.isEmpty ? 'Focus' : _taskController.text,
        'completedAt': DateFormat('HH:mm').format(DateTime.now()),
      });
      
      await _loadEntries();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🍅 ${_selectedDuration}分のポモドーロ完了！'),
            action: widget.featureManager.isEnabled('break_timer')
                ? SnackBarAction(
                    label: '休憩開始',
                    onPressed: _startBreak,
                  )
                : null,
          ),
        );
      }
      
      _resetTimer();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('☕ 休憩終了！次のポモドーロを始めましょう')),
        );
      }
      _resetTimer();
    }
  }

  void _startBreak() {
    setState(() {
      _isBreak = true;
      _seconds = _breakDuration * 60;
    });
    _startTimer();
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PomodoroSettingsScreen(
          durations: _durations,
          breakDuration: _breakDuration,
          dailyGoal: _dailyGoal,
          featureManager: widget.featureManager,
          onChanged: _loadSettings,
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasCustomDuration = widget.featureManager.isEnabled('custom_duration');
    final hasDailyGoal = widget.featureManager.isEnabled('daily_goal');
    final hasStats = widget.featureManager.isEnabled('statistics');
    
    final completedCount = _entries.length;
    final totalMinutes = _entries.fold<int>(0, (sum, e) => sum + (e.data['duration'] as int? ?? 0));

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Daily goal progress
          if (hasDailyGoal)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$completedCount / $_dailyGoal',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Text('🍅'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (completedCount / _dailyGoal).clamp(0.0, 1.0),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Timer display
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isBreak 
                  ? Colors.green.withAlpha(30)
                  : Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
              border: Border.all(
                color: _isBreak ? Colors.green : Theme.of(context).colorScheme.primary,
                width: 4,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isBreak ? '☕ 休憩' : '🍅',
                    style: const TextStyle(fontSize: 24),
                  ),
                  Text(
                    _formatTime(_seconds),
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Duration selector
          if (hasCustomDuration && !_isRunning && !_isBreak && _durations.isNotEmpty)
            Wrap(
              spacing: 8,
              children: _durations.map((d) => ChoiceChip(
                label: Text('${d}分'),
                selected: _selectedDuration == d,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedDuration = d;
                      _seconds = d * 60;
                    });
                  }
                },
              )).toList(),
            ),

          const SizedBox(height: 16),

          // Task input
          if (!_isBreak)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: TextField(
                controller: _taskController,
                decoration: const InputDecoration(
                  hintText: '何に集中する？',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
                enabled: !_isRunning,
              ),
            ),

          const SizedBox(height: 24),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isRunning ? _pauseTimer : _startTimer,
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                label: Text(_isRunning ? '一時停止' : '開始'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _resetTimer,
                icon: const Icon(Icons.refresh),
                label: const Text('リセット'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Statistics
          if (hasStats && _entries.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatBox(label: '完了', value: '$completedCount', unit: '回'),
                  _StatBox(label: '合計', value: '$totalMinutes', unit: '分'),
                  _StatBox(label: '平均', value: '${completedCount > 0 ? (totalMinutes / completedCount).round() : 0}', unit: '分'),
                ],
              ),
            ),
          ],

          // Settings button
          TextButton.icon(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('設定'),
          ),

          const SizedBox(height: 16),

          // Session list
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('今日: $completedCount ポモドーロ', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              return ListTile(
                leading: const Text('🍅', style: TextStyle(fontSize: 24)),
                title: Text(entry.data['task'] as String? ?? 'Focus'),
                subtitle: Text('${entry.data['duration']}分 @ ${entry.data['completedAt']}'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PomodoroSettingsScreen extends StatefulWidget {
  final List<int> durations;
  final int breakDuration;
  final int dailyGoal;
  final PluginFeatureManager featureManager;
  final VoidCallback onChanged;

  const _PomodoroSettingsScreen({
    required this.durations,
    required this.breakDuration,
    required this.dailyGoal,
    required this.featureManager,
    required this.onChanged,
  });

  @override
  State<_PomodoroSettingsScreen> createState() => _PomodoroSettingsScreenState();
}

class _PomodoroSettingsScreenState extends State<_PomodoroSettingsScreen> {
  late List<int> _durations;
  late int _breakDuration;
  late int _dailyGoal;

  @override
  void initState() {
    super.initState();
    _durations = List.from(widget.durations);
    _breakDuration = widget.breakDuration;
    _dailyGoal = widget.dailyGoal;
  }

  Future<void> _reload() async {
    final durations = await PomodoroSettingsManager.getDurations();
    final breakDuration = await PomodoroSettingsManager.getBreakDuration();
    final dailyGoal = await PomodoroSettingsManager.getDailyGoal();
    setState(() {
      _durations = durations;
      _breakDuration = breakDuration;
      _dailyGoal = dailyGoal;
    });
    widget.onChanged();
  }

  Future<void> _editDailyGoal() async {
    final controller = TextEditingController(text: _dailyGoal.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('1日の目標'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: 'ポモドーロ',
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
      await PomodoroSettingsManager.setDailyGoal(result);
      await _reload();
    }
  }

  Future<void> _editBreakDuration() async {
    final controller = TextEditingController(text: _breakDuration.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('休憩時間'),
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
      await PomodoroSettingsManager.setBreakDuration(result);
      await _reload();
    }
  }

  Future<void> _addDuration() async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('作業時間を追加'),
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
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (result != null && result > 0 && !_durations.contains(result)) {
      _durations.add(result);
      _durations.sort();
      await PomodoroSettingsManager.saveDurations(_durations);
      await _reload();
    }
  }

  Future<void> _removeDuration(int duration) async {
    if (_durations.length <= 1) return;
    _durations.remove(duration);
    await PomodoroSettingsManager.saveDurations(_durations);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ポモドーロ設定'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'reset') {
                await PomodoroSettingsManager.resetToDefaults();
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
          // Daily goal
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('1日の目標'),
            subtitle: Text('$_dailyGoal ポモドーロ'),
            trailing: const Icon(Icons.edit),
            onTap: _editDailyGoal,
          ),

          // Break duration
          ListTile(
            leading: const Icon(Icons.coffee),
            title: const Text('休憩時間'),
            subtitle: Text('$_breakDuration 分'),
            trailing: const Icon(Icons.edit),
            onTap: _editBreakDuration,
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
                  pluginName: 'Pomodoro',
                  featureManager: widget.featureManager,
                ),
              ),
            ),
          ),

          const Divider(),

          // Durations
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('作業時間', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addDuration,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('追加'),
                ),
              ],
            ),
          ),
          ..._durations.map((duration) => ListTile(
            leading: const Icon(Icons.timer),
            title: Text('$duration 分'),
            trailing: _durations.length > 1
                ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeDuration(duration),
                  )
                : null,
          )),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatBox({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            children: [
              TextSpan(text: value),
              TextSpan(
                text: unit,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PomodoroCompactWidget extends StatelessWidget {
  const PomodoroCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.timer),
        title: Text('Pomodoro'),
        subtitle: Text('集中タイマー'),
      ),
    );
  }
}
