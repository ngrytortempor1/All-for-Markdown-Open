/// Settings Screen
/// 
/// App-wide settings including theme, data, and about
library;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../core/app_theme.dart';
import '../core/plugin_manager.dart';
import '../core/database/database_service.dart';
import '../core/database/markdown_generator.dart';
import 'plugin_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _theme = AppTheme.instance;
  String? _currentPath;

  @override
  void initState() {
    super.initState();
    _theme.addListener(_onThemeChanged);
    _loadCurrentPath();
  }

  Future<void> _loadCurrentPath() async {
    final path = await MarkdownGenerator.getCurrentPath();
    if (mounted) {
      setState(() => _currentPath = path);
    }
  }

  @override
  void dispose() {
    _theme.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          // Appearance section
          _SectionHeader(title: '外観'),
          
          // Theme mode
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('テーマ'),
            subtitle: Text(_getThemeModeLabel(_theme.themeMode)),
            onTap: () => _showThemeDialog(),
          ),
          
          // Accent color
          ListTile(
            leading: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _theme.accentColor,
                shape: BoxShape.circle,
              ),
            ),
            title: const Text('アクセントカラー'),
            onTap: () => _showColorDialog(),
          ),

          const Divider(),

          // Plugins section
          _SectionHeader(title: 'プラグイン'),
          
          ListTile(
            leading: const Icon(Icons.extension),
            title: const Text('プラグイン管理'),
            subtitle: Text('${PluginManager.instance.enabledPlugins.length}個有効'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PluginSettingsScreen()),
            ),
          ),

          const Divider(),

          // Data section
          _SectionHeader(title: 'データ'),
          
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('今日のMarkdownを生成'),
            onTap: () async {
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
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('保存先'),
            subtitle: Text(_currentPath ?? '読み込み中...', 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.edit),
            onTap: () => _showSaveLocationDialog(),
          ),
          


          const Divider(),

          // About section
          _SectionHeader(title: 'アプリ情報'),
          
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('バージョン'),
            subtitle: Text('1.0.0'),
          ),
          
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('友達に紹介'),
            onTap: () {
              Share.share(
                'Markdown Loggerで日々のデータをスマートに記録しよう！\nhttps://example.com/app',
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('アプリを評価'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ストアページに移動します')),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('プライバシーポリシー'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('プライバシーポリシーを表示')),
              );
            },
          ),

          const SizedBox(height: 32),
          
          // Footer
          Center(
            child: Column(
              children: [
                const Text('📝', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  'Markdown Logger',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Made with ❤️',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'システム設定に従う';
      case ThemeMode.light:
        return 'ライト';
      case ThemeMode.dark:
        return 'ダーク';
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テーマを選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            return RadioListTile<ThemeMode>(
              title: Text(_getThemeModeLabel(mode)),
              value: mode,
              groupValue: _theme.themeMode,
              onChanged: (value) {
                if (value != null) {
                  _theme.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showColorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アクセントカラー'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AppTheme.accentColors.map((color) {
            final isSelected = color == _theme.accentColor;
            return GestureDetector(
              onTap: () {
                _theme.setAccentColor(color);
                Navigator.pop(context);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected 
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: isSelected 
                      ? [BoxShadow(color: color.withAlpha(100), blurRadius: 8)]
                      : null,
                ),
                child: isSelected 
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSaveLocationDialog() async {
    final defaultPath = await MarkdownGenerator.getDefaultRootPath();
    
    if (!mounted) return;
    
    // Show options dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存先を設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('現在の保存先:\n${_currentPath ?? defaultPath}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text('保存先を変更しますか？'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await MarkdownGenerator.setCustomPath(null);
              await _loadCurrentPath();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('デフォルトの保存先に戻しました')),
                );
              }
            },
            child: const Text('デフォルトに戻す'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Use FilePicker to select directory
              final result = await FilePicker.platform.getDirectoryPath(
                dialogTitle: '保存先フォルダを選択',
              );
              
              if (result != null) {
                await MarkdownGenerator.setCustomPath(result);
                await _loadCurrentPath();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ 保存先を変更:\n$result')),
                  );
                }
              }
            },
            child: const Text('フォルダを選択'),
          ),
        ],
      ),
    );
  }


}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
