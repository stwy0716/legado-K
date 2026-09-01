import 'package:flutter/material.dart';
import '../services/database_service.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final DatabaseService _db = DatabaseService();
  bool _enabled = false;
  String _sourceLang = 'auto';
  String _targetLang = 'zh-CN';
  String _engine = 'google';
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();

  final List<String> _engines = ['google', 'baidu', 'youdao', 'deepl', 'custom'];
  final List<String> _langs = ['auto', 'zh-CN', 'zh-TW', 'en', 'ja', 'ko', 'fr', 'de', 'es', 'ru'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('翻译设置')),
      body: ListView(children: [
        SwitchListTile(title: const Text('启用翻译'), subtitle: const Text('自动翻译正文内容'), value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
        const Divider(),
        ListTile(title: const Text('翻译引擎'), trailing: DropdownButton<String>(value: _engine, items: _engines.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _engine = v ?? 'google'))),
        ListTile(title: const Text('源语言'), trailing: DropdownButton<String>(value: _sourceLang, items: _langs.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(), onChanged: (v) => setState(() => _sourceLang = v ?? 'auto'))),
        ListTile(title: const Text('目标语言'), trailing: DropdownButton<String>(value: _targetLang, items: _langs.where((l) => l != 'auto').map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(), onChanged: (v) => setState(() => _targetLang = v ?? 'zh-CN'))),
        const Divider(),
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _apiKeyController, decoration: const InputDecoration(labelText: 'API Key', border: OutlineInputBorder()))),
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _apiUrlController, decoration: const InputDecoration(labelText: 'API URL (自定义引擎)', border: OutlineInputBorder()))),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: FilledButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置已保存'))), child: const Text('保存设置'))),
        const SizedBox(height: 24),
      ]),
    );
  }
}
