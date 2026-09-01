import 'package:flutter/material.dart';
import 'package:legado_md3/data/model/replace_rule.dart';
import 'package:legado_md3/data/local/app_database.dart';

class ReplaceRuleScreen extends StatefulWidget {
  const ReplaceRuleScreen({super.key});

  @override
  State<ReplaceRuleScreen> createState() => _ReplaceRuleScreenState();
}

class _ReplaceRuleScreenState extends State<ReplaceRuleScreen> {
  final DatabaseService _db = DatabaseService();
  List<ReplaceRule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    _rules = await _db.getReplaceRules();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleRule(ReplaceRule rule, bool enabled) async {
    rule.enable = enabled;
    await _db.updateReplaceRule(rule);
    setState(() {});
  }

  Future<void> _deleteRule(ReplaceRule rule) async {
    if (rule.id != null) {
      await _db.deleteReplaceRule(rule.id!);
      _loadRules();
    }
  }

  void _showEditDialog({ReplaceRule? rule}) {
    final summaryController = TextEditingController(text: rule?.replaceSummary ?? '');
    final regexController = TextEditingController(text: rule?.replaceRule ?? '');
    final replacementController = TextEditingController(text: rule?.replacement ?? '');
    final scopeController = TextEditingController(text: rule?.scope ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(rule == null ? '新建替换规则' : '编辑替换规则'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: summaryController,
                decoration: const InputDecoration(labelText: '规则说明'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: regexController,
                decoration: const InputDecoration(labelText: '替换规则(正则)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replacementController,
                decoration: const InputDecoration(labelText: '替换为'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scopeController,
                decoration: const InputDecoration(labelText: '作用范围(书源URL，留空为全部)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final newRule = ReplaceRule(
                id: rule?.id,
                replaceSummary: summaryController.text,
                replaceRule: regexController.text,
                replacement: replacementController.text,
                scope: scopeController.text.isEmpty ? null : scopeController.text,
                enable: rule?.enable ?? true,
              );
              if (rule == null) {
                await _db.insertReplaceRule(newRule);
              } else {
                await _db.updateReplaceRule(newRule);
              }
              Navigator.pop(context);
              _loadRules();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('替换净化 (${_rules.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final rule = _rules[index];
                    return Card(
                      child: ListTile(
                        title: Text(rule.replaceSummary, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rule.replaceRule, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                            if (rule.scope != null) Text('范围: ${rule.scope}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                        trailing: Switch(
                          value: rule.enable == true,
                          onChanged: (v) => _toggleRule(rule, v),
                        ),
                        onTap: () => _showEditDialog(rule: rule),
                        onLongPress: () => _showDeleteConfirm(rule),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.find_replace_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('暂无替换规则', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('点击右下角添加规则', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _showDeleteConfirm(ReplaceRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('确定要删除"${rule.replaceSummary}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(context);
              _deleteRule(rule);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('替换净化说明'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('替换净化可以去除书籍内容里的广告、错别字、屏蔽词等。'),
              SizedBox(height: 8),
              Text('规则说明：', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 替换规则：支持正则表达式'),
              Text('• 替换为：替换后的内容，留空表示删除'),
              Text('• 作用范围：指定书源URL，留空表示对所有书源生效'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
        ],
      ),
    );
  }
}
