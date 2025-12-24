/// Dashboard Screen
/// 
/// Overview of today's activities across all plugins
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/plugin_data_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _summaryData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final data = <String, dynamic>{};
    
    // Todo
    final todoService = PluginDataService('todo');
    final todoEntries = await todoService.getTodayEntries();
    final completedTodos = todoEntries.where((e) => e.data['done'] == true).length;
    data['todo'] = {'total': todoEntries.length, 'completed': completedTodos};
    
    // Mood
    final moodService = PluginDataService('mood');
    final moodEntries = await moodService.getTodayEntries();
    if (moodEntries.isNotEmpty) {
      final avgScore = moodEntries.fold<double>(0, (s, e) => s + (e.data['score'] as int? ?? 2)) / moodEntries.length;
      data['mood'] = {'score': avgScore.round(), 'count': moodEntries.length};
    }
    
    // Pomodoro
    final pomodoroService = PluginDataService('pomodoro');
    final pomodoroEntries = await pomodoroService.getTodayEntries();
    final focusMinutes = pomodoroEntries.fold<int>(0, (s, e) => s + (e.data['duration'] as int? ?? 0));
    data['pomodoro'] = {'sessions': pomodoroEntries.length, 'minutes': focusMinutes};
    
    // Water
    final waterService = PluginDataService('water');
    final waterEntries = await waterService.getTodayEntries();
    final waterMl = waterEntries.fold<int>(0, (s, e) => s + (e.data['amount'] as int? ?? 0));
    data['water'] = {'ml': waterMl, 'goal': 2000};
    
    // Habit
    final habitService = PluginDataService('habit');
    final habitEntries = await habitService.getTodayEntries();
    data['habit'] = {'completed': habitEntries.length};
    
    // Expense
    final expenseService = PluginDataService('expense');
    final expenseEntries = await expenseService.getTodayEntries();
    final totalExpense = expenseEntries.fold<int>(0, (s, e) => s + (e.data['amount'] as int? ?? 0));
    data['expense'] = {'total': totalExpense, 'count': expenseEntries.length};
    
    // Workout
    final workoutService = PluginDataService('workout');
    final workoutEntries = await workoutService.getTodayEntries();
    final workoutMinutes = workoutEntries.fold<int>(0, (s, e) => s + (e.data['duration'] as int? ?? 0));
    data['workout'] = {'minutes': workoutMinutes, 'count': workoutEntries.length};
    
    // Sleep
    final sleepService = PluginDataService('sleep');
    final sleepEntries = await sleepService.getTodayEntries();
    String? bedTime;
    String? wakeTime;
    int? quality;
    for (final entry in sleepEntries) {
      if (entry.data['type'] == 'bed') bedTime = entry.data['time'] as String?;
      if (entry.data['type'] == 'wake') {
        wakeTime = entry.data['time'] as String?;
        quality = entry.data['quality'] as int?;
      }
    }
    data['sleep'] = {'bed': bedTime, 'wake': wakeTime, 'quality': quality};
    
    // Reading
    final readingService = PluginDataService('reading');
    final readingEntries = await readingService.getTodayEntries();
    final pagesRead = readingEntries.fold<int>(0, (s, e) => s + (e.data['pages'] as int? ?? 0));
    data['reading'] = {'pages': pagesRead};
    
    // Meal
    final mealService = PluginDataService('meal');
    final mealEntries = await mealService.getTodayEntries();
    final mealsLogged = mealEntries.length;
    data['meal'] = {'count': mealsLogged};
    
    // Notes
    final noteService = PluginDataService('quick_note');
    final noteEntries = await noteService.getTodayEntries();
    data['notes'] = {'count': noteEntries.length};

    setState(() {
      _summaryData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // App bar with date
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  DateFormat('M月d日（E）', 'ja').format(DateTime.now()),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        children: [
                          const Text(
                            '今日の活動',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            _isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Quick stats row
                        _QuickStatsRow(data: _summaryData),
                        
                        const SizedBox(height: 24),
                        
                        // Main cards
                        _SectionTitle(title: '今日の記録', icon: Icons.today),
                        const SizedBox(height: 12),
                        
                        // Grid of cards
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.3,
                          children: [
                            _DashboardCard(
                              icon: '✅',
                              title: 'タスク',
                              value: '${_summaryData['todo']?['completed'] ?? 0}/${_summaryData['todo']?['total'] ?? 0}',
                              subtitle: '完了',
                              color: Colors.blue,
                            ),
                            _DashboardCard(
                              icon: _getMoodEmoji(_summaryData['mood']?['score']),
                              title: '気分',
                              value: _getMoodLabel(_summaryData['mood']?['score']),
                              subtitle: '${_summaryData['mood']?['count'] ?? 0}回記録',
                              color: Colors.orange,
                            ),
                            _DashboardCard(
                              icon: '🍅',
                              title: '集中',
                              value: '${_summaryData['pomodoro']?['minutes'] ?? 0}',
                              subtitle: '分',
                              color: Colors.red,
                            ),
                            _DashboardCard(
                              icon: '💧',
                              title: '水分',
                              value: '${_summaryData['water']?['ml'] ?? 0}',
                              subtitle: 'ml / 2000ml',
                              color: Colors.cyan,
                              progress: (_summaryData['water']?['ml'] ?? 0) / 2000,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Health & Lifestyle
                        _SectionTitle(title: '健康 & ライフスタイル', icon: Icons.favorite),
                        const SizedBox(height: 12),
                        
                        // Sleep card
                        _WideCard(
                          icon: '🌙',
                          title: '睡眠',
                          content: _buildSleepContent(),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.3,
                          children: [
                            _DashboardCard(
                              icon: '🏋️',
                              title: '運動',
                              value: '${_summaryData['workout']?['minutes'] ?? 0}',
                              subtitle: '分',
                              color: Colors.deepOrange,
                            ),
                            _DashboardCard(
                              icon: '🍽️',
                              title: '食事',
                              value: '${_summaryData['meal']?['count'] ?? 0}/4',
                              subtitle: '記録',
                              color: Colors.green,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Other stats
                        _SectionTitle(title: 'その他', icon: Icons.more_horiz),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _CompactCard(
                                icon: '📚',
                                label: '読書',
                                value: '${_summaryData['reading']?['pages'] ?? 0}ページ',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CompactCard(
                                icon: '💴',
                                label: '支出',
                                value: '¥${_summaryData['expense']?['total'] ?? 0}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CompactCard(
                                icon: '📝',
                                label: 'メモ',
                                value: '${_summaryData['notes']?['count'] ?? 0}件',
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                      ]),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepContent() {
    final bed = _summaryData['sleep']?['bed'] as String?;
    final wake = _summaryData['sleep']?['wake'] as String?;
    final quality = _summaryData['sleep']?['quality'] as int?;

    if (bed == null && wake == null) {
      return const Text('まだ記録がありません', style: TextStyle(color: Colors.grey));
    }

    return Row(
      children: [
        if (bed != null) ...[
          Column(
            children: [
              const Text('就寝', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(bed, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 24),
        ],
        if (wake != null) ...[
          Column(
            children: [
              const Text('起床', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(wake, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 24),
        ],
        if (quality != null) ...[
          Column(
            children: [
              const Text('品質', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(_getQualityEmoji(quality), style: const TextStyle(fontSize: 24)),
            ],
          ),
        ],
      ],
    );
  }

  String _getMoodEmoji(int? score) {
    if (score == null) return '😐';
    const emojis = ['😢', '😕', '😐', '🙂', '😊'];
    return emojis[score.clamp(0, 4)];
  }

  String _getMoodLabel(int? score) {
    if (score == null) return '-';
    const labels = ['最悪', '悪い', '普通', '良い', '最高'];
    return labels[score.clamp(0, 4)];
  }

  String _getQualityEmoji(int quality) {
    const emojis = ['😫', '😕', '😐', '😊', '😴'];
    return emojis[(quality - 1).clamp(0, 4)];
  }
}

class _QuickStatsRow extends StatelessWidget {
  final Map<String, dynamic> data;

  const _QuickStatsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final todoTotal = data['todo']?['total'] ?? 0;
    final todoCompleted = data['todo']?['completed'] ?? 0;
    final habitCount = data['habit']?['completed'] ?? 0;
    final focusMinutes = data['pomodoro']?['minutes'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickStat(
            label: 'タスク',
            value: '$todoCompleted/$todoTotal',
            icon: Icons.check_circle,
          ),
          _QuickStat(
            label: '習慣',
            value: '$habitCount',
            icon: Icons.repeat,
          ),
          _QuickStat(
            label: '集中',
            value: '${focusMinutes}分',
            icon: Icons.timer,
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _QuickStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final double? progress;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress!.clamp(0.0, 1.0),
              backgroundColor: color.withAlpha(50),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ],
      ),
    );
  }
}

class _WideCard extends StatelessWidget {
  final String icon;
  final String title;
  final Widget content;

  const _WideCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade800,
            Colors.purple.shade900,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: content,
          ),
        ],
      ),
    );
  }
}

class _CompactCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _CompactCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
