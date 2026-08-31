import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'source_manage_screen.dart';
import 'replace_rule_screen.dart';
import 'reading_stats_screen.dart';
import 'settings_screen.dart';
import 'backup_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: ListView(
        children: [
          // 阅读统计卡片
          _buildStatsCard(context),
          const SizedBox(height: 8),
          // 功能列表
          _buildSectionTitle(context, '内容管理'),
          _buildListItem(
            context,
            icon: Icons.menu_book_outlined,
            title: '书源管理',
            subtitle: '管理网络书源',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourceManageScreen())),
          ),
          _buildListItem(
            context,
            icon: Icons.find_replace_outlined,
            title: '替换净化',
            subtitle: '管理内容替换规则',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReplaceRuleScreen())),
          ),
          _buildListItem(
            context,
            icon: Icons.subscriptions_outlined,
            title: '订阅源',
            subtitle: '管理订阅内容',
            onTap: () {},
          ),
          const Divider(height: 24),
          _buildSectionTitle(context, '数据'),
          _buildListItem(
            context,
            icon: Icons.backup_outlined,
            title: '备份与恢复',
            subtitle: '备份阅读数据',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
          ),
          _buildListItem(
            context,
            icon: Icons.bar_chart_outlined,
            title: '阅读统计',
            subtitle: '查看阅读记录',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadingStatsScreen())),
          ),
          const Divider(height: 24),
          _buildSectionTitle(context, '设置'),
          _buildListItem(
            context,
            icon: Icons.palette_outlined,
            title: '主题',
            subtitle: '深色模式、配色',
            onTap: () => _showThemeSettings(context),
          ),
          _buildListItem(
            context,
            icon: Icons.settings_outlined,
            title: '设置',
            subtitle: '通用、阅读、其他设置',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          _buildListItem(
            context,
            icon: Icons.info_outline,
            title: '关于',
            subtitle: '版本 3.26.7',
            onTap: () => _showAbout(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('阅读统计', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(context, '0', '阅读时长'),
                  _buildStatItem(context, '0', '阅读天数'),
                  _buildStatItem(context, '0', '已读书籍'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _buildListItem(BuildContext context, {required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showThemeSettings(BuildContext context) {
    final appTheme = context.read<AppTheme>();
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('主题设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: const Text('深色模式'),
                trailing: DropdownButton<ThemeMode>(
                  value: appTheme.themeMode,
                  onChanged: (value) {
                    if (value != null) {
                      appTheme.setThemeMode(value);
                      setState(() {});
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
                  ],
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('主题色', style: TextStyle(fontWeight: FontWeight.w500)),
              ),
              Wrap(
                spacing: 12,
                children: [
                  0xFF6750A4, 0xFF6200EE, 0xFF03DAC6, 0xFF018786,
                  0xFFB00020, 0xFFCF6679, 0xFF3700B3, 0xFF000000,
                ].map((color) => GestureDetector(
                  onTap: () {
                    appTheme.setSeedColor(Color(color));
                    setState(() {});
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: appTheme.seedColor.value == color ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于 Legado MD3'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: 3.26.7'),
            SizedBox(height: 8),
            Text('基于 Legado 开源项目的 Material Design 3 跨平台版本'),
            SizedBox(height: 8),
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
