/// Advanced Expense Plugin
/// 
/// Full-featured expense tracking with customizable categories
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';
import '../../core/plugin_feature_system.dart';

class ExpensePlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'expense';
  
  @override
  String get name => 'Expense';
  
  @override
  IconData get icon => Icons.payments;
  
  @override
  String get description => '支出記録';

  final _dataService = PluginDataService('expense');
  
  late final PluginFeatureManager featureManager = PluginFeatureManager(
    pluginId: 'expense',
    availableFeatures: const [
      PluginFeature(
        id: 'categories',
        name: 'カテゴリ',
        description: 'カテゴリ別に表示',
        icon: Icons.category,
      ),
      PluginFeature(
        id: 'daily_budget',
        name: '日次予算',
        description: '1日の予算を設定',
        icon: Icons.account_balance_wallet,
      ),
      PluginFeature(
        id: 'quick_input',
        name: 'クイック入力',
        description: 'よく使う金額をワンタップ',
        icon: Icons.flash_on,
      ),
      PluginFeature(
        id: 'payment_method',
        name: '支払い方法',
        description: '現金/カード/電子マネー',
        icon: Icons.credit_card,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'receipt_photo',
        name: 'レシート',
        description: 'レシート写真を保存',
        icon: Icons.receipt_long,
        defaultEnabled: false,
      ),
    ],
  );

  @override
  Widget buildWidget(BuildContext context) => AdvancedExpenseWidget(
    dataService: _dataService,
    featureManager: featureManager,
  );

  @override
  Widget buildCompactWidget(BuildContext context) => const ExpenseCompactWidget();

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

// Category manager - saves custom categories to SharedPreferences
class ExpenseCategoryManager {
  static const _key = 'expense_categories';
  static const _budgetKey = 'expense_daily_budget';
  static const _quickAmountsKey = 'expense_quick_amounts';
  
  static final List<Map<String, dynamic>> defaultCategories = [
    {'id': 'food', 'name': '食費', 'icon': '🍔', 'color': 0xFFFF9800},
    {'id': 'transport', 'name': '交通費', 'icon': '🚃', 'color': 0xFF2196F3},
    {'id': 'shopping', 'name': '買い物', 'icon': '🛍️', 'color': 0xFFE91E63},
    {'id': 'entertainment', 'name': '娯楽', 'icon': '🎮', 'color': 0xFF9C27B0},
    {'id': 'health', 'name': '医療', 'icon': '💊', 'color': 0xFF4CAF50},
    {'id': 'utilities', 'name': '光熱費', 'icon': '💡', 'color': 0xFFFFEB3B},
    {'id': 'cafe', 'name': 'カフェ', 'icon': '☕', 'color': 0xFF795548},
    {'id': 'other', 'name': 'その他', 'icon': '📦', 'color': 0xFF607D8B},
  ];

  static final List<int> defaultQuickAmounts = [100, 300, 500, 1000, 2000, 5000];

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    
    if (stored == null) {
      await saveCategories(defaultCategories);
      return List.from(defaultCategories);
    }
    
    final List<dynamic> decoded = jsonDecode(stored);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> saveCategories(List<Map<String, dynamic>> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(categories));
  }

  static Future<void> addCategory(Map<String, dynamic> category) async {
    final categories = await getCategories();
    categories.add(category);
    await saveCategories(categories);
  }

  static Future<void> removeCategory(String categoryId) async {
    final categories = await getCategories();
    categories.removeWhere((c) => c['id'] == categoryId);
    await saveCategories(categories);
  }

  static Future<void> updateCategory(String categoryId, Map<String, dynamic> updated) async {
    final categories = await getCategories();
    final index = categories.indexWhere((c) => c['id'] == categoryId);
    if (index >= 0) {
      categories[index] = updated;
      await saveCategories(categories);
    }
  }

  static Future<void> resetToDefaults() async {
    await saveCategories(List.from(defaultCategories));
  }

  static Future<int> getDailyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_budgetKey) ?? 3000;
  }

  static Future<void> setDailyBudget(int budget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_budgetKey, budget);
  }

  static Future<List<int>> getQuickAmounts() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_quickAmountsKey);
    if (stored == null) return defaultQuickAmounts;
    final List<dynamic> decoded = jsonDecode(stored);
    return decoded.cast<int>();
  }

  static Future<void> setQuickAmounts(List<int> amounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_quickAmountsKey, jsonEncode(amounts));
  }
}

class AdvancedExpenseWidget extends StatefulWidget {
  final PluginDataService dataService;
  final PluginFeatureManager featureManager;
  
  const AdvancedExpenseWidget({
    super.key,
    required this.dataService,
    required this.featureManager,
  });

  @override
  State<AdvancedExpenseWidget> createState() => _AdvancedExpenseWidgetState();
}

class _AdvancedExpenseWidgetState extends State<AdvancedExpenseWidget> {
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  String _selectedCategory = 'food';
  List<LogEntry> _entries = [];
  List<Map<String, dynamic>> _categories = [];
  List<int> _quickAmounts = [];
  int _totalAmount = 0;
  int _dailyBudget = 3000;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    widget.featureManager.addListener(_onFeatureChanged);
  }

  Future<void> _initialize() async {
    await widget.featureManager.initialize();
    await _loadCategories();
    await _loadSettings();
    await _loadEntries();
    setState(() => _initialized = true);
  }

  Future<void> _loadCategories() async {
    final categories = await ExpenseCategoryManager.getCategories();
    setState(() {
      _categories = categories;
      if (_categories.isNotEmpty && !_categories.any((c) => c['id'] == _selectedCategory)) {
        _selectedCategory = _categories.first['id'] as String;
      }
    });
  }

  Future<void> _loadSettings() async {
    final budget = await ExpenseCategoryManager.getDailyBudget();
    final quickAmounts = await ExpenseCategoryManager.getQuickAmounts();
    setState(() {
      _dailyBudget = budget;
      _quickAmounts = quickAmounts;
    });
  }

  @override
  void dispose() {
    widget.featureManager.removeListener(_onFeatureChanged);
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _onFeatureChanged() => setState(() {});

  Future<void> _loadEntries() async {
    final entries = await widget.dataService.getTodayEntries();
    final total = entries.fold<int>(0, (sum, e) => sum + (e.data['amount'] as int? ?? 0));
    setState(() {
      _entries = entries.reversed.toList();
      _totalAmount = total;
    });
  }

  Future<void> _addExpense([int? quickAmount]) async {
    final amount = quickAmount ?? (int.tryParse(_amountController.text) ?? 0);
    if (amount <= 0) return;
    
    final category = _categories.firstWhere(
      (c) => c['id'] == _selectedCategory,
      orElse: () => _categories.isNotEmpty ? _categories.first : {'id': 'other', 'name': 'その他', 'icon': '📦'},
    );
    
    await widget.dataService.createEntry({
      'amount': amount,
      'category': _selectedCategory,
      'categoryName': category['name'],
      'icon': category['icon'],
      'memo': _memoController.text,
      'time': DateFormat('HH:mm').format(DateTime.now()),
    });
    
    _amountController.clear();
    _memoController.clear();
    await _loadEntries();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${category['icon']} ${_formatCurrency(amount)}を記録')),
      );
    }
  }

  String _formatCurrency(int amount) {
    return NumberFormat.currency(locale: 'ja', symbol: '¥', decimalDigits: 0).format(amount);
  }

  Map<String, int> get _categoryTotals {
    final totals = <String, int>{};
    for (final entry in _entries) {
      final cat = entry.data['category'] as String? ?? 'other';
      final amount = entry.data['amount'] as int? ?? 0;
      totals[cat] = (totals[cat] ?? 0) + amount;
    }
    return totals;
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ExpenseSettingsScreen(
          categories: _categories,
          dailyBudget: _dailyBudget,
          quickAmounts: _quickAmounts,
          featureManager: widget.featureManager,
          onChanged: () async {
            await _loadCategories();
            await _loadSettings();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasBudget = widget.featureManager.isEnabled('daily_budget');
    final hasQuickInput = widget.featureManager.isEnabled('quick_input');
    final hasCategories = widget.featureManager.isEnabled('categories');
    
    final budgetProgress = (_totalAmount / _dailyBudget).clamp(0.0, 1.5);
    final isOverBudget = _totalAmount > _dailyBudget;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Budget display
          if (hasBudget)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOverBudget 
                    ? Colors.red.withAlpha(30)
                    : Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOverBudget ? Colors.red : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatCurrency(_totalAmount),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isOverBudget ? Colors.red : null,
                        ),
                      ),
                      Text(
                        '/ ${_formatCurrency(_dailyBudget)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: budgetProgress.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.withAlpha(30),
                    valueColor: AlwaysStoppedAnimation(
                      isOverBudget ? Colors.red : Colors.green,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  if (isOverBudget)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '⚠️ 予算を${_formatCurrency(_totalAmount - _dailyBudget)}超過',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                _formatCurrency(_totalAmount),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),

          const SizedBox(height: 16),

          // Quick amounts (if enabled)
          if (hasQuickInput && _quickAmounts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickAmounts.map((amount) => ActionChip(
                  label: Text(_formatCurrency(amount)),
                  onPressed: () {
                    if (_categories.isNotEmpty) {
                      _selectedCategory = _categories.first['id'] as String;
                    }
                    _addExpense(amount);
                  },
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
          ],

          // Manual input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Category selector
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 80,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat['id'] as String),
                            child: Column(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? Color(cat['color'] as int).withAlpha(50)
                                        : Colors.grey.withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected 
                                        ? Border.all(color: Color(cat['color'] as int), width: 2)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(cat['icon'] as String, style: const TextStyle(fontSize: 24)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cat['name'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 16),

                // Amount input
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '金額',
                    prefixText: '¥ ',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 24),
                ),

                const SizedBox(height: 12),

                // Memo and submit
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _memoController,
                        decoration: const InputDecoration(
                          labelText: 'メモ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _addExpense(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      ),
                      child: const Text('記録'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Category breakdown (if enabled)
          if (hasCategories && _entries.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('カテゴリ別', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._categoryTotals.entries.map((e) {
                    final cat = _categories.firstWhere(
                      (c) => c['id'] == e.key,
                      orElse: () => {'id': 'other', 'name': 'その他', 'icon': '📦', 'color': 0xFF607D8B},
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(cat['icon'] as String, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(cat['name'] as String),
                          const Spacer(),
                          Text(
                            _formatCurrency(e.value),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Entry list
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final icon = entry.data['icon'] as String? ?? '📦';
              final amount = entry.data['amount'] as int? ?? 0;
              final memo = entry.data['memo'] as String? ?? '';
              final time = entry.data['time'] as String? ?? '';
              return ListTile(
                leading: Text(icon, style: const TextStyle(fontSize: 24)),
                title: Text(_formatCurrency(amount)),
                subtitle: Text('$time${memo.isNotEmpty ? ' - $memo' : ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    await widget.dataService.deleteEntry(entry.id);
                    await _loadEntries();
                  },
                ),
              );
            },
          ),

          // Settings button
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('設定'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseSettingsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final int dailyBudget;
  final List<int> quickAmounts;
  final PluginFeatureManager featureManager;
  final VoidCallback onChanged;

  const _ExpenseSettingsScreen({
    required this.categories,
    required this.dailyBudget,
    required this.quickAmounts,
    required this.featureManager,
    required this.onChanged,
  });

  @override
  State<_ExpenseSettingsScreen> createState() => _ExpenseSettingsScreenState();
}

class _ExpenseSettingsScreenState extends State<_ExpenseSettingsScreen> {
  late List<Map<String, dynamic>> _categories;
  late int _dailyBudget;
  late List<int> _quickAmounts;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
    _dailyBudget = widget.dailyBudget;
    _quickAmounts = List.from(widget.quickAmounts);
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CategoryEditDialog(category: category),
    );

    if (result != null) {
      await ExpenseCategoryManager.updateCategory(category['id'] as String, result);
      await _reload();
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CategoryEditDialog(),
    );

    if (result != null) {
      await ExpenseCategoryManager.addCategory({
        ...result,
        'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
      });
      await _reload();
    }
  }

  Future<void> _deleteCategory(String categoryId) async {
    await ExpenseCategoryManager.removeCategory(categoryId);
    await _reload();
  }

  Future<void> _reload() async {
    final categories = await ExpenseCategoryManager.getCategories();
    final budget = await ExpenseCategoryManager.getDailyBudget();
    setState(() {
      _categories = categories;
      _dailyBudget = budget;
    });
    widget.onChanged();
  }

  Future<void> _editBudget() async {
    final controller = TextEditingController(text: _dailyBudget.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('日次予算'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            prefixText: '¥ ',
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
      await ExpenseCategoryManager.setDailyBudget(result);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('支出設定'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'reset') {
                await ExpenseCategoryManager.resetToDefaults();
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
          // Budget setting
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('日次予算'),
            subtitle: Text('¥${_dailyBudget.toString()}'),
            trailing: const Icon(Icons.edit),
            onTap: _editBudget,
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
                  pluginName: 'Expense',
                  featureManager: widget.featureManager,
                ),
              ),
            ),
          ),
          const Divider(),

          // Categories header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('カテゴリ', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('追加'),
                ),
              ],
            ),
          ),

          // Categories list
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final item = _categories.removeAt(oldIndex);
              _categories.insert(newIndex, item);
              await ExpenseCategoryManager.saveCategories(_categories);
              widget.onChanged();
              setState(() {});
            },
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return ListTile(
                key: ValueKey(cat['id']),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(cat['color'] as int).withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text(cat['icon'] as String, style: const TextStyle(fontSize: 20))),
                ),
                title: Text(cat['name'] as String),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _editCategory(cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _deleteCategory(cat['id'] as String),
                    ),
                    const Icon(Icons.drag_handle),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryEditDialog extends StatefulWidget {
  final Map<String, dynamic>? category;

  const _CategoryEditDialog({this.category});

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late TextEditingController _nameController;
  late String _selectedIcon;
  late int _selectedColor;

  static const List<String> _icons = [
    '🍔', '🚃', '🛍️', '🎮', '💊', '💡', '☕', '📦',
    '🏠', '📱', '🎬', '✈️', '🎁', '📚', '💇', '🚗',
    '🍺', '🍰', '🎵', '⚡', '💰', '🏖️', '🏥', '🎓',
  ];

  static const List<int> _colors = [
    0xFFFF9800, 0xFF2196F3, 0xFFE91E63, 0xFF9C27B0,
    0xFF4CAF50, 0xFFFFEB3B, 0xFF795548, 0xFF607D8B,
    0xFFFF5722, 0xFF00BCD4, 0xFF673AB7, 0xFF3F51B5,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?['name'] as String? ?? '');
    _selectedIcon = widget.category?['icon'] as String? ?? '📦';
    _selectedColor = widget.category?['color'] as int? ?? 0xFF607D8B;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category != null ? 'カテゴリを編集' : '新しいカテゴリ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'カテゴリ名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('アイコン', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: GridView.count(
              crossAxisCount: 8,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: _icons.map((icon) => GestureDetector(
                onTap: () => setState(() => _selectedIcon = icon),
                child: Container(
                  decoration: BoxDecoration(
                    color: _selectedIcon == icon ? Colors.blue.withAlpha(30) : Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: _selectedIcon == icon ? Border.all(color: Colors.blue, width: 2) : null,
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('色', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colors.map((color) => GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: _selectedColor == color 
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: _selectedColor == color
                      ? [BoxShadow(color: Color(color).withAlpha(100), blurRadius: 8)]
                      : null,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              Navigator.pop(context, {
                'id': widget.category?['id'] ?? '',
                'name': _nameController.text,
                'icon': _selectedIcon,
                'color': _selectedColor,
              });
            }
          },
          child: Text(widget.category != null ? '更新' : '追加'),
        ),
      ],
    );
  }
}

class ExpenseCompactWidget extends StatelessWidget {
  const ExpenseCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.payments),
        title: Text('Expense'),
        subtitle: Text('支出記録'),
      ),
    );
  }
}
