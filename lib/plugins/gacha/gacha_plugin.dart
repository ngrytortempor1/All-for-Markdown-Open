/// Gacha Stone/Currency Tracker Plugin
/// 
/// Tracks game currency changes
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';

class GachaPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'gacha';
  
  @override
  String get name => 'ガチャ石';
  
  @override
  IconData get icon => Icons.diamond;
  
  @override
  String get description => 'ソシャゲ課金管理';

  final _dataService = PluginDataService('gacha');

  @override
  Widget buildWidget(BuildContext context) => GachaWidget(dataService: _dataService);

  @override
  Widget buildCompactWidget(BuildContext context) => const GachaCompactWidget();

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

// Default games
const List<Map<String, dynamic>> _defaultGames = [
  {'id': 'custom', 'name': 'カスタム', 'icon': '🎮', 'currency': '石'},
  {'id': 'genshin', 'name': '原神', 'icon': '⭐', 'currency': '原石'},
  {'id': 'starrail', 'name': '崩壊スターレイル', 'icon': '🌟', 'currency': '星玉'},
  {'id': 'fgo', 'name': 'FGO', 'icon': '💎', 'currency': '聖晶石'},
  {'id': 'uma', 'name': 'ウマ娘', 'icon': '🐴', 'currency': 'ジュエル'},
  {'id': 'priconne', 'name': 'プリコネ', 'icon': '👑', 'currency': 'ジュエル'},
  {'id': 'bluearchive', 'name': 'ブルアカ', 'icon': '📘', 'currency': '青輝石'},
  {'id': 'nikke', 'name': 'NIKKE', 'icon': '🔫', 'currency': 'ジェム'},
];

class GachaWidget extends StatefulWidget {
  final PluginDataService dataService;
  
  const GachaWidget({super.key, required this.dataService});

  @override
  State<GachaWidget> createState() => _GachaWidgetState();
}

class _GachaWidgetState extends State<GachaWidget> {
  List<Map<String, dynamic>> _games = [];
  String _selectedGame = 'custom';
  int _amount = 0;
  bool _isAdd = true;
  String _memo = '';
  List<LogEntry> _entries = [];
  bool _loading = true;
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    // Load games
    final prefs = await SharedPreferences.getInstance();
    final customGames = prefs.getStringList('gacha_custom_games') ?? [];
    
    _games = [..._defaultGames];
    for (final game in customGames) {
      final parts = game.split('|');
      if (parts.length >= 3) {
        _games.add({'id': parts[0], 'name': parts[1], 'icon': parts[2], 'currency': parts.length > 3 ? parts[3] : '石'});
      }
    }
    
    _selectedGame = prefs.getString('gacha_last_game') ?? 'custom';
    
    final entries = await widget.dataService.getTodayEntries();
    
    setState(() {
      _entries = entries.reversed.toList();
      _loading = false;
    });
  }

  Map<String, dynamic> get _currentGame {
    return _games.firstWhere(
      (g) => g['id'] == _selectedGame,
      orElse: () => _games.first,
    );
  }

  Future<void> _recordChange() async {
    if (_amount == 0) return;

    final game = _currentGame;
    final change = _isAdd ? _amount : -_amount;

    await widget.dataService.createEntry({
      'gameId': _selectedGame,
      'gameName': game['name'],
      'icon': game['icon'],
      'currency': game['currency'],
      'change': change,
      'isAdd': _isAdd,
      'memo': _memo,
      'time': DateFormat('HH:mm').format(DateTime.now()),
    });

    // Save last game
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gacha_last_game', _selectedGame);

    _amountController.clear();
    _memoController.clear();
    setState(() {
      _amount = 0;
      _memo = '';
    });

    await _loadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${game['icon']} ${_isAdd ? '+' : ''}$change ${game['currency']}を記録しました')),
      );
    }
  }

  int get _todayTotal {
    int total = 0;
    for (final entry in _entries) {
      total += entry.data['change'] as int? ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final game = _currentGame;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Today's summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _todayTotal >= 0 ? Colors.green.withAlpha(50) : Colors.red.withAlpha(50),
                  _todayTotal >= 0 ? Colors.green.withAlpha(20) : Colors.red.withAlpha(20),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(game['icon'] as String, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(game['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '${_todayTotal >= 0 ? '+' : ''}$_todayTotal ${game['currency']}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _todayTotal >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                Text('今日の増減', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Game selector
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('ゲーム', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _games.length,
              itemBuilder: (context, index) {
                final g = _games[index];
                final isSelected = _selectedGame == g['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedGame = g['id'] as String),
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withAlpha(30) : Colors.grey.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(g['icon'] as String, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          g['name'] as String,
                          style: const TextStyle(fontSize: 9),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Add/Subtract toggle
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isAdd = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _isAdd ? Colors.green.withAlpha(50) : Colors.grey.withAlpha(20),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                      border: _isAdd ? Border.all(color: Colors.green, width: 2) : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle, color: _isAdd ? Colors.green : Colors.grey),
                        const SizedBox(width: 8),
                        Text('増加', style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isAdd ? Colors.green : Colors.grey,
                        )),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isAdd = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: !_isAdd ? Colors.red.withAlpha(50) : Colors.grey.withAlpha(20),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                      border: !_isAdd ? Border.all(color: Colors.red, width: 2) : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_circle, color: !_isAdd ? Colors.red : Colors.grey),
                        const SizedBox(width: 8),
                        Text('使用', style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: !_isAdd ? Colors.red : Colors.grey,
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Amount input
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '${game['currency']}数',
              hintText: '例: 1600',
              prefixIcon: Icon(_isAdd ? Icons.add : Icons.remove),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _amount = int.tryParse(v) ?? 0),
          ),

          const SizedBox(height: 12),

          // Quick amount buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [10, 100, 160, 300, 1600, 3000].map((amount) {
              return ActionChip(
                label: Text('$amount'),
                onPressed: () {
                  _amountController.text = amount.toString();
                  setState(() => _amount = amount);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Memo
          TextField(
            controller: _memoController,
            decoration: const InputDecoration(
              labelText: 'メモ（任意）',
              hintText: '例: デイリー報酬、ガチャ10連',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _memo = v),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _amount > 0 ? _recordChange : null,
            icon: const Icon(Icons.save),
            label: Text('${_isAdd ? '+' : '-'}$_amount ${game['currency']}を記録'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: _isAdd ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 24),

          // History
          if (_entries.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('今日の記録', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _entries.take(10).length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final icon = entry.data['icon'] as String? ?? '🎮';
                final gameName = entry.data['gameName'] as String? ?? '';
                final currency = entry.data['currency'] as String? ?? '石';
                final change = entry.data['change'] as int? ?? 0;
                final memo = entry.data['memo'] as String? ?? '';
                final time = entry.data['time'] as String? ?? '';

                return ListTile(
                  leading: Text(icon, style: const TextStyle(fontSize: 24)),
                  title: Text(
                    '${change >= 0 ? '+' : ''}$change $currency',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: change >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  subtitle: Text('$gameName${memo.isNotEmpty ? ' - $memo' : ''} - $time'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      await widget.dataService.deleteEntry(entry.id);
                      await _loadData();
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class GachaCompactWidget extends StatelessWidget {
  const GachaCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.diamond, color: Colors.purple),
        title: Text('ガチャ石'),
        subtitle: Text('ソシャゲ課金管理'),
      ),
    );
  }
}
