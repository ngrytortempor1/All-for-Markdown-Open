import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/date_check_service.dart';
import 'core/plugin_registry.dart';
import 'core/plugin_manager.dart';
import 'core/app_theme.dart';
import 'core/database/markdown_generator.dart';
import 'screens/plugin_settings_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja');
  
  // Initialize theme
  await AppTheme.instance.initialize();
  
  // Initialize plugin manager with all available plugins
  await PluginManager.instance.initialize(PluginRegistry.plugins);
  
  // Check for date change and generate markdown if needed
  await DateCheckService.checkAndGenerate();
  
  // Check onboarding status
  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = !(prefs.getBool('onboarding_complete') ?? false);
  
  runApp(ProviderScope(
    child: MarkdownLoggerApp(showOnboarding: showOnboarding),
  ));
}

class MarkdownLoggerApp extends StatefulWidget {
  final bool showOnboarding;
  
  const MarkdownLoggerApp({super.key, required this.showOnboarding});

  @override
  State<MarkdownLoggerApp> createState() => _MarkdownLoggerAppState();
}

class _MarkdownLoggerAppState extends State<MarkdownLoggerApp> {
  final _theme = AppTheme.instance;
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.showOnboarding;
    _theme.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _theme.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  void _completeOnboarding() {
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdown Logger',
      debugShowCheckedModeBanner: false,
      theme: _theme.lightTheme,
      darkTheme: _theme.darkTheme,
      themeMode: _theme.themeMode,
      home: _showOnboarding
          ? OnboardingScreen(onComplete: _completeOnboarding)
          : const MainNavigation(),
    );
  }
}

/// Main navigation with bottom tabs
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: const [
          DashboardScreen(),
          PluginsPage(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'ダッシュボード',
          ),
          NavigationDestination(
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension),
            label: 'プラグイン',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}

/// Plugins page with horizontal scrollable plugin tabs
class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key});

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final plugins = PluginManager.instance.enabledPlugins;
    _tabController = TabController(length: plugins.length, vsync: this);
    PluginManager.instance.addListener(_onPluginsChanged);
  }

  @override
  void dispose() {
    PluginManager.instance.removeListener(_onPluginsChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onPluginsChanged() {
    final plugins = PluginManager.instance.enabledPlugins;
    setState(() {
      _tabController.dispose();
      _tabController = TabController(length: plugins.length, vsync: this);
    });
  }

  @override
  Widget build(BuildContext context) {
    final plugins = PluginManager.instance.enabledPlugins;
    
    if (plugins.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('プラグイン'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _openSettings,
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.extension_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('有効なプラグインがありません'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openSettings,
                child: const Text('プラグインを有効にする'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Markdown Logger'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: '今日のMarkdownを生成',
            onPressed: _generateTodayMarkdown,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'プラグイン設定',
            onPressed: _openSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: plugins.map((p) => Tab(
            icon: Icon(p.icon),
            text: p.name,
          )).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: plugins.map((p) => p.buildWidget(context)).toList(),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PluginSettingsScreen()),
    );
  }

  Future<void> _generateTodayMarkdown() async {
    try {
      await MarkdownGenerator.generateDailyMarkdown(DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Markdownを生成しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }
}

// Keep HomePage for backwards compatibility with tests
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return const MainNavigation();
  }
}
