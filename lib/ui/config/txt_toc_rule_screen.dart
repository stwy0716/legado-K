import 'package:flutter/material.dart';
import 'package:legado_md3/data/model/txt_toc_rule.dart';
import 'package:legado_md3/data/local/app_database.dart';

class TxtTocRuleScreen extends StatefulWidget {
  const TxtTocRuleScreen({super.key});

  @override
  State<TxtTocRuleScreen> createState() => _TxtTocRuleScreenState();
}

class _TxtTocRuleScreenState extends State<TxtTocRuleScreen> {
  final DatabaseService _db = DatabaseService();
  List<TxtTocRule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    // 从数据库或预定义加载
    _rules = [
      TxtTocRule(id: 1, name: '默认规则', chapterRule: r'^第[0-9零一二三四五六七八九十百千万]+[章节回卷集部篇].*', enable: true),
      TxtTocRule(id: 2, name: '简单章节', chapterRule: r'^第\d+章.*', enable: false),
      TxtTocRule(id: 3, name: '中文数字', chapterRule: r'^第[零一二三四五六七八九十百千万]+章.*', enable: false),
    ];
    setState(() => _isLoading = false);
  }

  void _showEditDialog({TxtTocRule? rule}) {
    final nameController = TextEditingController(text: rule?.name ?? '');
    final ruleController = TextEditingController(text: rule?.chapterRule ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(rule == null ? '添加规则' : '编辑规则'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: '规则名称', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: ruleController, maxLines: 3, decoration: const InputDecoration(labelText: '正则表达式', border: OutlineInputBorder(), hintText: '例如: ^第\\d+章.*')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () {
            setState(() {
              if (rule == null) {
                _rules.add(TxtTocRule(id: DateTime.now().millisecondsSinceEpoch, name: nameController.text, chapterRule: ruleController.text, enable: true));
              } else {
                final index = _rules.indexWhere((r) => r.id == rule.id);
                if (index >= 0) _rules[index] = TxtTocRule(id: rule.id, name: nameController.text, chapterRule: ruleController.text, enable: rule.enable);
              }
            });
            Navigator.pop(context);
          }, child: const Text('保存')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TXT目录规则'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: () => _showEditDialog()),
      ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? const Center(child: Text('暂无规则'))
              : ListView.builder(
                  itemCount: _rules.length,
                  itemBuilder: (context, index) {
                    final rule = _rules[index];
                    return ListTile(
                      title: Text(rule.name),
                      subtitle: Text(rule.chapterRule, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      trailing: Switch(
                        value: rule.enable,
                        onChanged: (v) => setState(() => _rules[index] = TxtTocRule(id: rule.id, name: rule.name, chapterRule: rule.chapterRule, enable: v)),
                      ),
                      onTap: () => _showEditDialog(rule: rule),
                      onLongPress: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(title: const Text('删除规则'), content: Text('确定删除"${rule.name}"吗？'), actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () { setState(() => _rules.removeAt(index)); Navigator.pop(context); }, child: const Text('删除')),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
