/// Advanced Reading Plugin (Bookly level)
/// 
/// Full-featured reading tracker with books, progress, and goals
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/plugin_interface.dart';
import '../../core/models/log_entry.dart';
import '../../core/plugin_data_service.dart';
import '../../core/plugin_feature_system.dart';

class ReadingPlugin implements MarkdownLoggerPlugin {
  @override
  String get id => 'reading';
  
  @override
  String get name => 'Reading';
  
  @override
  IconData get icon => Icons.menu_book;
  
  @override
  String get description => '読書記録';

  final _dataService = PluginDataService('reading');
  
  late final PluginFeatureManager featureManager = PluginFeatureManager(
    pluginId: 'reading',
    availableFeatures: const [
      PluginFeature(
        id: 'book_library',
        name: 'ライブラリ',
        description: '読書中の本を管理',
        icon: Icons.library_books,
      ),
      PluginFeature(
        id: 'reading_goal',
        name: '読書目標',
        description: '年間読書目標を設定',
        icon: Icons.flag,
      ),
      PluginFeature(
        id: 'timer',
        name: '読書タイマー',
        description: '読書時間を計測',
        icon: Icons.timer,
      ),
      PluginFeature(
        id: 'quotes',
        name: '引用',
        description: 'お気に入りの文章を保存',
        icon: Icons.format_quote,
        defaultEnabled: false,
      ),
      PluginFeature(
        id: 'genres',
        name: 'ジャンル',
        description: '本のジャンルを記録',
        icon: Icons.category,
        defaultEnabled: false,
      ),
    ],
  );

  @override
  Widget buildWidget(BuildContext context) => AdvancedReadingWidget(
    dataService: _dataService,
    featureManager: featureManager,
  );

  @override
  Widget buildCompactWidget(BuildContext context) => const ReadingCompactWidget();

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

// Genre list
const List<Map<String, dynamic>> _genres = [
  {'id': 'fiction', 'name': '小説', 'icon': '📚'},
  {'id': 'nonfiction', 'name': 'ノンフィクション', 'icon': '📖'},
  {'id': 'business', 'name': 'ビジネス', 'icon': '💼'},
  {'id': 'self-help', 'name': '自己啓発', 'icon': '🌟'},
  {'id': 'tech', 'name': '技術書', 'icon': '💻'},
  {'id': 'manga', 'name': '漫画', 'icon': '📕'},
];

class AdvancedReadingWidget extends StatefulWidget {
  final PluginDataService dataService;
  final PluginFeatureManager featureManager;
  
  const AdvancedReadingWidget({
    super.key,
    required this.dataService,
    required this.featureManager,
  });

  @override
  State<AdvancedReadingWidget> createState() => _AdvancedReadingWidgetState();
}

class _AdvancedReadingWidgetState extends State<AdvancedReadingWidget> {
  final _titleController = TextEditingController();
  final _pagesController = TextEditingController();
  List<LogEntry> _entries = [];
  int _totalPagesToday = 0;
  int _yearlyGoal = 24;
  int _booksRead = 0;
  String? _currentBook;
  int _currentBookProgress = 0;
  int _currentBookTotal = 0;
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
    _titleController.dispose();
    _pagesController.dispose();
    super.dispose();
  }

  void _onFeatureChanged() => setState(() {});

  Future<void> _loadEntries() async {
    final entries = await widget.dataService.getTodayEntries();
    final total = entries.fold<int>(0, (sum, e) => sum + (e.data['pages'] as int? ?? 0));
    setState(() {
      _entries = entries.reversed.toList();
      _totalPagesToday = total;
      
      // Get current book from latest entry
      if (entries.isNotEmpty) {
        final latest = entries.last;
        _currentBook = latest.data['title'] as String?;
        _currentBookProgress = latest.data['currentPage'] as int? ?? 0;
        _currentBookTotal = latest.data['totalPages'] as int? ?? 0;
      }
    });
  }

  Future<void> _addReading() async {
    if (_titleController.text.isEmpty || _pagesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本のタイトルとページ数を入力してください')),
      );
      return;
    }
    
    final pages = int.tryParse(_pagesController.text) ?? 0;
    if (pages <= 0) return;
    
    await widget.dataService.createEntry({
      'title': _titleController.text,
      'pages': pages,
      'time': DateFormat('HH:mm').format(DateTime.now()),
    });
    
    _pagesController.clear();
    await _loadEntries();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📚 ${pages}ページ読了！')),
      );
    }
  }

  Future<void> _addBookWithDetails() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddReadingSheet(
        featureManager: widget.featureManager,
        currentBook: _currentBook,
        currentProgress: _currentBookProgress,
        totalPages: _currentBookTotal,
      ),
    );

    if (result != null) {
      await widget.dataService.createEntry({
        'title': result['title'],
        'pages': result['pages'],
        'currentPage': result['currentPage'],
        'totalPages': result['totalPages'],
        'genre': result['genre'],
        'finished': result['finished'] ?? false,
        'time': DateFormat('HH:mm').format(DateTime.now()),
      });
      
      if (result['finished'] == true) {
        setState(() => _booksRead++);
      }
      
      await _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasLibrary = widget.featureManager.isEnabled('book_library');
    final hasGoal = widget.featureManager.isEnabled('reading_goal');
    final hasTimer = widget.featureManager.isEnabled('timer');

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Today's progress
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade600, Colors.indigo.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('📚', style: TextStyle(fontSize: 36)),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('今日の読書', style: TextStyle(color: Colors.white70)),
                        Text(
                          '$_totalPagesToday ページ',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Current book progress
                if (hasLibrary && _currentBook != null && _currentBookTotal > 0) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentBook!,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_currentBookProgress / $_currentBookTotal ページ',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${((_currentBookProgress / _currentBookTotal) * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _currentBookProgress / _currentBookTotal,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ],
            ),
          ),

          // Yearly goal (if enabled)
          if (hasGoal) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.flag, size: 20),
                  const SizedBox(width: 8),
                  Text('年間目標: $_booksRead / $_yearlyGoal 冊'),
                  const Spacer(),
                  Text('${((_booksRead / _yearlyGoal) * 100).round()}%'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Add reading section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasLibrary)
                  ElevatedButton.icon(
                    onPressed: _addBookWithDetails,
                    icon: const Icon(Icons.add),
                    label: const Text('読書を記録'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  )
                else ...[
                  // Simple input
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '本のタイトル',
                      prefixIcon: Icon(Icons.book),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pagesController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: '読んだページ数',
                            suffixText: 'ページ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _addReading,
                        icon: const Icon(Icons.add),
                        label: const Text('記録'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Timer button (if enabled)
          if (hasTimer) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.timer),
              label: const Text('読書タイマー'),
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
                        pluginName: 'Reading',
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
              final title = entry.data['title'] as String? ?? '';
              final pages = entry.data['pages'] as int? ?? 0;
              final time = entry.data['time'] as String? ?? '';
              final finished = entry.data['finished'] as bool? ?? false;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: finished ? Colors.green.withAlpha(30) : Colors.purple.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(finished ? '🏆' : '📖', style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  title: Text(title),
                  subtitle: Text('$time · ${pages}ページ${finished ? ' · 読了!' : ''}'),
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

class _AddReadingSheet extends StatefulWidget {
  final PluginFeatureManager featureManager;
  final String? currentBook;
  final int currentProgress;
  final int totalPages;

  const _AddReadingSheet({
    required this.featureManager,
    this.currentBook,
    required this.currentProgress,
    required this.totalPages,
  });

  @override
  State<_AddReadingSheet> createState() => _AddReadingSheetState();
}

class _AddReadingSheetState extends State<_AddReadingSheet> {
  late TextEditingController _titleController;
  final _pagesController = TextEditingController();
  final _currentPageController = TextEditingController();
  final _totalPagesController = TextEditingController();
  String? _selectedGenre;
  bool _isFinished = false;
  bool _isNewBook = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentBook);
    if (widget.currentBook != null) {
      _isNewBook = false;
      _currentPageController.text = widget.currentProgress.toString();
      _totalPagesController.text = widget.totalPages.toString();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pagesController.dispose();
    _currentPageController.dispose();
    _totalPagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasGenres = widget.featureManager.isEnabled('genres');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('📚 読書を記録', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Book title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '本のタイトル',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Pages read today
            TextField(
              controller: _pagesController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '今日読んだページ数',
                suffixText: 'ページ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Current page / total pages
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _currentPageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '現在のページ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('/'),
                ),
                Expanded(
                  child: TextField(
                    controller: _totalPagesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '総ページ数',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            // Genre (if enabled)
            if (hasGenres) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _genres.map((g) => ChoiceChip(
                  avatar: Text(g['icon'] as String),
                  label: Text(g['name'] as String),
                  selected: _selectedGenre == g['id'],
                  onSelected: (s) => setState(() => _selectedGenre = s ? g['id'] as String : null),
                )).toList(),
              ),
            ],

            // Finished checkbox
            CheckboxListTile(
              value: _isFinished,
              onChanged: (v) => setState(() => _isFinished = v ?? false),
              title: const Text('この本を読了した'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final pages = int.tryParse(_pagesController.text) ?? 0;
                if (_titleController.text.isEmpty || pages <= 0) return;
                
                Navigator.pop(context, {
                  'title': _titleController.text,
                  'pages': pages,
                  'currentPage': int.tryParse(_currentPageController.text) ?? 0,
                  'totalPages': int.tryParse(_totalPagesController.text) ?? 0,
                  'genre': _selectedGenre,
                  'finished': _isFinished,
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('記録'),
            ),
          ],
        ),
      ),
    );
  }
}

class ReadingCompactWidget extends StatelessWidget {
  const ReadingCompactWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.menu_book),
        title: Text('Reading'),
        subtitle: Text('読書記録'),
      ),
    );
  }
}
