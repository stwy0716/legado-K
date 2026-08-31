import 'package:flutter/material.dart';
import 'source_manage_screen.dart';
import 'replace_rule_screen.dart';
import 'txt_toc_rule_screen.dart';
import 'dict_rule_screen.dart';
import 'highlight_tag_rule_screen.dart';
import 'settings_screen.dart';
import 'bookmark_screen.dart';
import 'reading_stats_screen.dart';
import 'cache_manage_screen.dart';
import 'backup_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          _buildSectionHeader(context, '规则分段'),
          _buildMenuItem(context, Icons.menu_book_outlined, '书源管理', '管理网络书源', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourceManageScreen()))),
          _buildMenuItem(context, Icons.find_replace_outlined, '替换净化', '正文内容替换规则', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReplaceRuleScreen()))),
          _buildMenuItem(context, Icons.list_alt_outlined, 'TXT目录规则', '本地TXT目录识别', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtTocRuleScreen()))),
          _buildMenuItem(context, Icons.translate_outlined, '字典规则', '文字替换字典', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DictRuleScreen()))),
          _buildMenuItem(context, Icons.tag_outlined, '高亮标签配置', '阅读内容高亮', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HighlightTagRuleScreen()))),

          const Divider(),

          _buildSectionHeader(context, '其他'),
          _buildMenuItem(context, Icons.smart_toy_outlined, 'AI聊天', 'AI助手对话', () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI聊天功能开发中')))),
          _buildMenuItem(context, Icons.settings_outlined, '设置', '应用设置', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          _buildMenuItem(context, Icons.bookmark_border, '书签', '所有书签', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarkScreen()))),
          _buildMenuItem(context, Icons.bar_chart_outlined, '阅读记录', '阅读统计', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadingStatsScreen()))),
          _buildMenuItem(context, Icons.cleaning_services_outlined, '缓存管理', '书籍缓存', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CacheManageScreen()))),
          _buildMenuItem(context, Icons.backup_outlined, '备份恢复', '数据备份', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()))),
          _buildMenuItem(context, Icons.folder_outlined, '文件管理', '本地文件', () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('文件管理功能开发中')))),
          _buildMenuItem(context, Icons.info_outline, '关于', '应用信息', () => _showAbout(context)),

          const Divider(),

          _buildSectionHeader(context, 'Web服务'),
          SwitchListTile(
            secondary: const Icon(Icons.web_outlined),
            title: const Text('Web服务'),
            subtitle: const Text('通过浏览器管理书架'),
            value: false,
            onChanged: (v) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(v ? 'Web服务启动中...' : 'Web服务已停止'))),
          ),

          const SizedBox(height: 24),
          const Center(child: Text('Legado MD3 v3.26.7', style: TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('关于'),
      content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Legado MD3', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('版本: 3.26.7'),
        SizedBox(height: 8),
        Text('基于Legado MD3风格的跨平台阅读应用'),
        Text('支持Android和iOS'),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定'))],
    ));
  }

  Widget _buildSectionHeader(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
  );

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
