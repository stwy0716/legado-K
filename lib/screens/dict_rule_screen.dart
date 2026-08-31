import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DictRuleScreen extends StatefulWidget {
  const DictRuleScreen({super.key});

  @override
  State<DictRuleScreen> createState() => _DictRuleScreenState();
}

class _DictRuleScreenState extends State<DictRuleScreen> {
  final TextEditingController _ruleController = TextEditingController();
  final TextEditingController _replacementController = TextEditingController();
  List<Map<String, String>> _rules = [];
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('dict_rule_enabled') ?? true;
    final rulesStr = prefs.getStringList('dict_rules') ?? [];
    setState(() {
      _rules = rulesStr.map((s) {
        final parts = s.split('|||');
        return {'rule': parts[0], 'replacement': parts.length > 1 ? parts[1] : ''};
      }).toList();
    });
  }

  Future<void> _saveRules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dict_rule_enabled', _enabled);
    await prefs.setStringList('dict_rules', _rules.map((r) => '${r['rule']}|||${r['replacement']}').toList());
  }

  void _addRule() {
    if (_ruleController.text.trim().isEmpty) return;
    setState(() {
      _rules.add({'rule': _ruleController.text.trim(), 'replacement': _replacementController.text.trim()});
      _ruleController.clear();
      _replacementController.clear();
    });
    _saveRules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('字典规则')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('启用字典规则'),
            value: _enabled,
            onChanged: (v) => setState(() { _enabled = v; _saveRules(); }),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(controller: _ruleController, decoration: const InputDecoration(labelText: '查找内容(正则)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _replacementController, decoration: const InputDecoration(labelText: '替换为', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _addRule, child: const Text('添加规则'))),
            ]),
          ),
          const Divider(),
          Expanded(
            child: _rules.isEmpty
                ? const Center(child: Text('暂无字典规则'))
                : ListView.builder(
                    itemCount: _rules.length,
                    itemBuilder: (context, index) {
                      final rule = _rules[index];
                      return ListTile(
                        title: Text(rule['rule']!, style: const TextStyle(fontFamily: 'monospace')),
                        subtitle: Text('→ ${rule['replacement']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() { _rules.removeAt(index); _saveRules(); })),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
