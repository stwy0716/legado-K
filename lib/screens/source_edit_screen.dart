import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/book_source.dart';
import '../services/database_service.dart';

/// 书源编辑屏幕 - JSON编辑器（完全兼容原版Legado格式）
class SourceEditScreen extends StatefulWidget {
  final BookSource? source;
  const SourceEditScreen({super.key, this.source});

  @override
  State<SourceEditScreen> createState() => _SourceEditScreenState();
}

class _SourceEditScreenState extends State<SourceEditScreen> {
  final DatabaseService _db = DatabaseService();
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _groupController;
  late TextEditingController _jsonController;
  bool _enabled = true;
  bool _enabledExplore = false;
  bool _isJsonMode = false;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _nameController = TextEditingController(text: s?.bookSourceName ?? '');
    _urlController = TextEditingController(text: s?.bookSourceUrl ?? '');
    _groupController = TextEditingController(text: s?.bookSourceGroup ?? '');
    _enabled = s?.enabled ?? true;
    _enabledExplore = s?.enabledExplore ?? false;
    _jsonController = TextEditingController(
      text: s != null ? const JsonEncoder.withIndent('  ').convert(s.toJson()) : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _groupController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      if (_isJsonMode) {
        // JSON模式：直接解析JSON
        final json = jsonDecode(_jsonController.text);
        if (json is! Map<String, dynamic>) {
          _showError('JSON格式错误：必须是对象');
          return;
        }
        final source = BookSource.fromJson(json);
        if (source.bookSourceName.isEmpty || source.bookSourceUrl.isEmpty) {
          _showError('书源名称和URL不能为空');
          return;
        }
        await _db.insertSource(source);
      } else {
        // 表单模式
        if (_nameController.text.trim().isEmpty || _urlController.text.trim().isEmpty) {
          _showError('书源名称和URL不能为空');
          return;
        }
        final source = widget.source ?? BookSource(
          bookSourceUrl: _urlController.text.trim(),
          bookSourceName: _nameController.text.trim(),
        );
        source.bookSourceName = _nameController.text.trim();
        source.bookSourceUrl = _urlController.text.trim();
        source.bookSourceGroup = _groupController.text.trim().isEmpty ? null : _groupController.text.trim();
        source.enabled = _enabled;
        source.enabledExplore = _enabledExplore;
        await _db.insertSource(source);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('保存失败: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source == null ? '新建书源' : '编辑书源'),
        actions: [
          IconButton(
            icon: Icon(_isJsonMode ? Icons.edit : Icons.code),
            tooltip: _isJsonMode ? '表单模式' : 'JSON模式',
            onPressed: () {
              setState(() => _isJsonMode = !_isJsonMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: _isJsonMode ? _buildJsonEditor() : _buildFormEditor(),
    );
  }

  Widget _buildFormEditor() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTextField('书源名称 *', _nameController),
        const SizedBox(height: 12),
        _buildTextField('书源URL *', _urlController),
        const SizedBox(height: 12),
        _buildTextField('书源分组', _groupController),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('启用书源'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        SwitchListTile(
          title: const Text('启用发现'),
          value: _enabledExplore,
          onChanged: (v) => setState(() => _enabledExplore = v),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('提示：点击右上角代码图标切换到JSON模式',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('JSON模式可编辑完整书源规则（搜索/目录/正文等）',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJsonEditor() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Text(
            '编辑书源JSON（完全兼容Legado原版格式）',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _jsonController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
