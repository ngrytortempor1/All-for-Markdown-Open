/// Health Connect Plugin
/// 
/// Automatically sync health data from Health Connect (Android) / HealthKit (iOS)
/// Uses PluginDataService for loose coupling with core
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';

class HealthPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'health';
  
  @override
  String get name => 'Health';
  
  @override
  IconData get icon => Icons.favorite;
  
  @override
  String get description => 'ヘルスデータ';

  final _dataService = PluginDataService('health');

  @override
  Widget buildWidget(BuildContext context) => HealthWidget(dataService: _dataService);

  @override
  Widget buildCompactWidget(BuildContext context) => const HealthCompactWidget();

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

class HealthWidget extends StatefulWidget {
  final PluginDataService dataService;
  
  const HealthWidget({super.key, required this.dataService});

  @override
  State<HealthWidget> createState() => _HealthWidgetState();
}

class _HealthWidgetState extends State<HealthWidget> {
  final Health _health = Health();
  bool _authorized = false;
  bool _loading = false;
  Map<String, dynamic> _healthData = {};
  String? _error;

  // Health data types to request
  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
  ];

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  Future<void> _checkAuthorization() async {
    try {
      final hasPermissions = await _health.hasPermissions(_types);
      setState(() => _authorized = hasPermissions ?? false);
      
      if (_authorized) {
        await _loadHealthData();
      }
    } catch (e) {
      setState(() => _error = 'Health Connect未対応: $e');
    }
  }

  Future<void> _requestAuthorization() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final authorized = await _health.requestAuthorization(_types);
      setState(() => _authorized = authorized);
      
      if (authorized) {
        await _loadHealthData();
      }
    } catch (e) {
      setState(() => _error = '認証エラー: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      final healthData = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: startOfDay,
        endTime: now,
      );
      
      // Aggregate data
      int steps = 0;
      double calories = 0;
      double distance = 0;
      List<double> heartRates = [];
      
      for (final data in healthData) {
        switch (data.type) {
          case HealthDataType.STEPS:
            steps += (data.value as NumericHealthValue).numericValue.toInt();
            break;
          case HealthDataType.HEART_RATE:
            heartRates.add((data.value as NumericHealthValue).numericValue.toDouble());
            break;
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            calories += (data.value as NumericHealthValue).numericValue.toDouble();
            break;
          case HealthDataType.DISTANCE_WALKING_RUNNING:
            distance += (data.value as NumericHealthValue).numericValue.toDouble();
            break;
          default:
            break;
        }
      }
      
      final avgHeartRate = heartRates.isNotEmpty 
          ? heartRates.reduce((a, b) => a + b) / heartRates.length 
          : 0.0;
      
      setState(() {
        _healthData = {
          'steps': steps,
          'calories': calories.round(),
          'distance': (distance / 1000).toStringAsFixed(2), // km
          'heartRate': avgHeartRate.round(),
        };
      });
      
      // Save to database
      await widget.dataService.createEntry({
        'steps': steps,
        'calories': calories.round(),
        'distance': distance,
        'heartRate': avgHeartRate.round(),
        'syncedAt': DateFormat('HH:mm').format(now),
      });
      
    } catch (e) {
      setState(() => _error = 'データ取得エラー: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Center(
            child: Text('❤️', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Health Connect',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),
          
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!)),
                  ],
                ),
              ),
            ),
          
          if (!_authorized) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.health_and_safety, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Health Connectへのアクセスを許可してください',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _requestAuthorization,
                      icon: _loading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_user),
                      label: const Text('アクセスを許可'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Health data cards
            _HealthDataCard(
              icon: Icons.directions_walk,
              title: '歩数',
              value: '${_healthData['steps'] ?? 0}',
              unit: '歩',
              color: Colors.blue,
              goal: 10000,
              current: _healthData['steps'] ?? 0,
            ),
            const SizedBox(height: 12),
            _HealthDataCard(
              icon: Icons.local_fire_department,
              title: 'カロリー',
              value: '${_healthData['calories'] ?? 0}',
              unit: 'kcal',
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _HealthDataCard(
              icon: Icons.straighten,
              title: '距離',
              value: '${_healthData['distance'] ?? '0.00'}',
              unit: 'km',
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _HealthDataCard(
              icon: Icons.favorite,
              title: '心拍数',
              value: '${_healthData['heartRate'] ?? 0}',
              unit: 'bpm',
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadHealthData,
              icon: _loading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('データを更新'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthDataCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final Color color;
  final int? goal;
  final int? current;

  const _HealthDataCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
    this.goal,
    this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(text: value),
                        TextSpan(
                          text: ' $unit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (goal != null && current != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (current! / goal!).clamp(0.0, 1.0),
                      backgroundColor: color.withAlpha(50),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '目標: $goal $unit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HealthCompactWidget extends StatelessWidget {
  const HealthCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.favorite, color: Colors.red),
        title: Text('Health'),
        subtitle: Text('ヘルスデータ'),
      ),
    );
  }
}
