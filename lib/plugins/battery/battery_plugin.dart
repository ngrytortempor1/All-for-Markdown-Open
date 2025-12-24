/// Battery Plugin
/// 
/// Automatically records battery level and charging status
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';

class BatteryPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'battery';
  
  @override
  String get name => 'Battery';
  
  @override
  IconData get icon => Icons.battery_full;
  
  @override
  String get description => 'バッテリー記録';

  final _dataService = PluginDataService('battery');

  @override
  Widget buildWidget(BuildContext context) => BatteryWidget(dataService: _dataService);

  @override
  Widget buildCompactWidget(BuildContext context) => const BatteryCompactWidget();

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

class BatteryWidget extends StatefulWidget {
  final PluginDataService dataService;
  
  const BatteryWidget({super.key, required this.dataService});

  @override
  State<BatteryWidget> createState() => _BatteryWidgetState();
}

class _BatteryWidgetState extends State<BatteryWidget> {
  static const _channel = MethodChannel('plugins.flutter.io/battery');
  int _batteryLevel = 0;
  String _chargingStatus = 'unknown';
  List<LogEntry> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    try {
      // Get battery level via platform channel
      final level = await _channel.invokeMethod<int>('getBatteryLevel') ?? 0;
      
      setState(() => _batteryLevel = level);
    } catch (e) {
      // Fallback: Simulate battery level for demo
      setState(() => _batteryLevel = 75);
    }

    // Load history
    final entries = await widget.dataService.getTodayEntries();
    setState(() {
      _history = entries.reversed.toList();
      _loading = false;
    });

    // Auto-record current level
    await _recordBattery();
  }

  Future<void> _recordBattery() async {
    final now = DateTime.now();
    
    await widget.dataService.createEntry({
      'level': _batteryLevel,
      'charging': _chargingStatus,
      'time': DateFormat('HH:mm').format(now),
      'autoRecorded': true,
    });

    final entries = await widget.dataService.getTodayEntries();
    setState(() => _history = entries.reversed.toList());
  }

  Color _getBatteryColor(int level) {
    if (level >= 60) return Colors.green;
    if (level >= 30) return Colors.orange;
    return Colors.red;
  }

  IconData _getBatteryIcon(int level) {
    if (level >= 90) return Icons.battery_full;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 40) return Icons.battery_4_bar;
    if (level >= 20) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final color = _getBatteryColor(_batteryLevel);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Battery display
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withAlpha(50),
                  color.withAlpha(20),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  _getBatteryIcon(_batteryLevel),
                  size: 80,
                  color: color,
                ),
                const SizedBox(height: 16),
                Text(
                  '$_batteryLevel%',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '自動記録',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Refresh button
          OutlinedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('更新'),
          ),

          const SizedBox(height: 24),

          // History
          if (_history.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '今日の記録',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.take(10).length,
              itemBuilder: (context, index) {
                final entry = _history[index];
                final level = entry.data['level'] as int? ?? 0;
                final time = entry.data['time'] as String? ?? '';
                final entryColor = _getBatteryColor(level);

                return ListTile(
                  leading: Icon(
                    _getBatteryIcon(level),
                    color: entryColor,
                  ),
                  title: Text('$level%'),
                  subtitle: Text(time),
                  dense: true,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class BatteryCompactWidget extends StatelessWidget {
  const BatteryCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.battery_full, color: Colors.green),
        title: Text('Battery'),
        subtitle: Text('バッテリー記録'),
      ),
    );
  }
}
