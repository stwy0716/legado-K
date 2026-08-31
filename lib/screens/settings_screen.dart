import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SharedPreferences? _prefs;
  bool _autoUpdate = true;
  bool _wifiOnly = false;
  bool _volumeKeyPage = true;
  bool _keepScreenOn = true;
  bool _showMenuOnTap = true;
  bool _showNotification = true;
  bool _landscapeLock = false;
  int _preDownloadCount = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoUpdate = _prefs?.getBool('auto_update') ?? true;
      _wifiOnly = _prefs?.getBool('wifi_only') ?? false;
      _volumeKeyPage = _prefs?.getBool('volume_key_page') ?? true;
      _keepScreenOn = _prefs?.getBool('keep_screen_on') ?? true;
      _showMenuOnTap = _prefs?.getBool('show_menu_on_tap') ?? true;
      _showNotification = _prefs?.getBool('show_notification') ?? true;
      _landscapeLock = _prefs?.getBool('landscape_lock') ?? false;
      _preDownloadCount = _prefs?.getInt('pre_download_count') ?? 5;
    });
  }

  Future<void> _setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<AppTheme>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _buildSection('外观'),
          SwitchListTile(
            title: const Text('深色模式'),
            subtitle: Text(theme.themeMode == ThemeMode.dark ? '已开启' : theme.themeMode == ThemeMode.system ? '跟随系统' : '已关闭'),
            value: theme.themeMode == ThemeMode.dark,
            onChanged: (v) => theme.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
          ),
          SwitchListTile(
            title: const Text('跟随系统'),
            value: theme.themeMode == ThemeMode.system,
            onChanged: (v) => theme.setThemeMode(v ? ThemeMode.system : ThemeMode.light),
          ),
          SwitchListTile(
            title: const Text('动态颜色'),
            subtitle: const Text('从壁纸提取颜色'),
            value: theme.dynamicColor,
            onChanged: (v) => theme.setDynamicColor(v),
          ),
          ListTile(
            title: const Text('主题色'),
            trailing: Container(width: 24, height: 24, decoration: BoxDecoration(color: theme.seedColor, borderRadius: BorderRadius.circular(6))),
            onTap: () => _showColorPicker(theme),
          ),
          const Divider(height: 24),
          _buildSection('通用'),
          SwitchListTile(
            title: const Text('自动更新'),
            subtitle: const Text('启动时自动检查书籍更新'),
            value: _autoUpdate,
            onChanged: (v) { _autoUpdate = v; _setBool('auto_update', v); },
          ),
          SwitchListTile(
            title: const Text('仅WiFi下更新'),
            value: _wifiOnly,
            onChanged: (v) { _wifiOnly = v; _setBool('wifi_only', v); },
          ),
          ListTile(
            title: const Text('预下载章节数'),
            trailing: Text('$_preDownloadCount'),
            onTap: () => _showPreDownloadDialog(),
          ),
          const Divider(height: 24),
          _buildSection('阅读'),
          SwitchListTile(
            title: const Text('音量键翻页'),
            value: _volumeKeyPage,
            onChanged: (v) { _volumeKeyPage = v; _setBool('volume_key_page', v); },
          ),
          SwitchListTile(
            title: const Text('保持屏幕常亮'),
            value: _keepScreenOn,
            onChanged: (v) { _keepScreenOn = v; _setBool('keep_screen_on', v); },
          ),
          SwitchListTile(
            title: const Text('点击中央显示菜单'),
            value: _showMenuOnTap,
            onChanged: (v) { _showMenuOnTap = v; _setBool('show_menu_on_tap', v); },
          ),
          const Divider(height: 24),
          _buildSection('缓存'),
          ListTile(
            title: const Text('清除缓存'),
            subtitle: const Text('清除书籍内容缓存'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showClearCacheDialog(),
          ),
          const Divider(height: 24),
          _buildSection('其他'),
          SwitchListTile(
            title: const Text('显示通知栏'),
            value: _showNotification,
            onChanged: (v) { _showNotification = v; _setBool('show_notification', v); },
          ),
          SwitchListTile(
            title: const Text('横屏锁定'),
            value: _landscapeLock,
            onChanged: (v) { _landscapeLock = v; _setBool('landscape_lock', v); },
          ),
          ListTile(
            title: const Text('关于'),
            subtitle: const Text('阅读 MD3 v1.0.0'),
            onTap: () => _showAboutDialog(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }

  void _showColorPicker(AppTheme theme) {
    final colors = [
      const Color(0xFF6750A4), // 紫
      const Color(0xFF006874), // 青
      const Color(0xFF0061A4), // 蓝
      const Color(0xFF00696B), // 绿
      const Color(0xFF755900), // 橙
      const Color(0xFF984061), // 粉
      const Color(0xFF8C4000), // 棕
      const Color(0xFF496057), // 灰绿
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题色'),
        content: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: colors.map((c) => GestureDetector(
            onTap: () {
              theme.setSeedColor(c);
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(20),
                border: theme.seedColor == c ? Border.all(color: Colors.white, width: 3) : null,
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  void _showPreDownloadDialog() {
    int value = _preDownloadCount;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('预下载章节数'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: value.toDouble(),
                min: 0,
                max: 20,
                divisions: 20,
                label: '$value',
                onChanged: (v) => setDialogState(() => value = v.round()),
              ),
              Text('预下载 $value 章'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              _preDownloadCount = value;
              await _prefs?.setInt('pre_download_count', value);
              if (mounted) {
                setState(() {});
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有书籍内容缓存吗？清除后需要重新下载。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清除')));
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('阅读 MD3', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('版本: 1.0.0'),
            SizedBox(height: 4),
            Text('基于 Material Design 3 的开源阅读器'),
            SizedBox(height: 4),
            Text('支持 Android / iOS'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }
}
