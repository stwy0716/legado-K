import 'package:flutter/material.dart';
import '../models/book_source.dart';
import '../services/database_service.dart';

class SourceEditScreen extends StatefulWidget {
  final BookSource? source;
  const SourceEditScreen({super.key, this.source});

  @override
  State<SourceEditScreen> createState() => _SourceEditScreenState();
}

class _SourceEditScreenState extends State<SourceEditScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late BookSource _source;
  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _source = widget.source ??
        BookSource(
          bookSourceUrl: '',
          bookSourceName: '',
          enabled: true,
          enabledExplore: true,
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_source.bookSourceName.isEmpty || _source.bookSourceUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写书源名称和URL')),
      );
      return;
    }
    await _db.insertSource(_source);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存成功')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source == null ? '新建书源' : '编辑书源'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '基本'),
            Tab(text: '搜索'),
            Tab(text: '发现'),
            Tab(text: '详情'),
            Tab(text: '目录/正文'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicTab(),
          _buildSearchTab(),
          _buildExploreTab(),
          _buildDetailTab(),
          _buildTocContentTab(),
        ],
      ),
    );
  }

  Widget _buildBasicTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTextField('书源名称', _source.bookSourceName, (v) => _source.bookSourceName = v),
        const SizedBox(height: 12),
        _buildTextField('书源URL', _source.bookSourceUrl, (v) => _source.bookSourceUrl = v),
        const SizedBox(height: 12),
        _buildTextField('书源分组', _source.bookSourceGroup ?? '', (v) => _source.bookSourceGroup = v),
        const SizedBox(height: 12),
        _buildTextField('书源类型', _source.bookSourceType ?? '', (v) => _source.bookSourceType = v),
        const SizedBox(height: 12),
        _buildTextField('备注', _source.bookSourceComment ?? '', (v) => _source.bookSourceComment = v, maxLines: 3),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('启用书源'),
          value: _source.enabled == true,
          onChanged: (v) => setState(() => _source.enabled = v),
        ),
        SwitchListTile(
          title: const Text('启用发现'),
          value: _source.enabledExplore == true,
          onChanged: (v) => setState(() => _source.enabledExplore = v),
        ),
      ],
    );
  }

  Widget _buildSearchTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTextField('搜索地址', _source.searchUrl ?? '', (v) => _source.searchUrl = v, maxLines: 2),
        const SizedBox(height: 12),
        _buildTextField('搜索结果列表', _source.ruleSearch ?? '', (v) => _source.ruleSearch = v),
        const SizedBox(height: 12),
        _buildTextField('作者', _source.ruleSearchAuthor ?? '', (v) => _source.ruleSearchAuthor = v),
        const SizedBox(height: 12),
        _buildTextField('封面', _source.ruleSearchCover ?? '', (v) => _source.ruleSearchCover = v),
        const SizedBox(height: 12),
        _buildTextField('简介', _source.ruleSearchIntro ?? '', (v) => _source.ruleSearchIntro = v, maxLines: 2),
        const SizedBox(height: 12),
        _buildTextField('分类', _source.ruleSearchKind ?? '', (v) => _source.ruleSearchKind = v),
        const SizedBox(height: 12),
        _buildTextField('最新章节', _source.ruleSearchLastChapter ?? '', (v) => _source.ruleSearchLastChapter = v),
        const SizedBox(height: 12),
        _buildTextField('详情页URL', _source.ruleSearchNoteUrl ?? '', (v) => _source.ruleSearchNoteUrl = v),
      ],
    );
  }

  Widget _buildExploreTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTextField('发现地址', _source.exploreUrl ?? '', (v) => _source.exploreUrl = v, maxLines: 2),
        const SizedBox(height: 12),
        _buildTextField('发现列表', _source.ruleExplore ?? '', (v) => _source.ruleExplore = v, maxLines: 2),
      ],
    );
  }

  Widget _buildDetailTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTextField('书名', _source.ruleBookName ?? '', (v) => _source.ruleBookName = v),
        const SizedBox(height: 12),
        _buildTextField('作者', _source.ruleBookAuthor ?? '', (v) => _source.ruleBookAuthor = v),
        const SizedBox(height: 12),
        _buildTextField('封面', _source.ruleBookCover ?? '', (v) => _source.ruleBookCover = v),
        const SizedBox(height: 12),
        _buildTextField('简介', _source.ruleBookIntro ?? '', (v) => _source.ruleBookIntro = v, maxLines: 2),
        const SizedBox(height: 12),
        _buildTextField('分类', _source.ruleBookKind ?? '', (v) => _source.ruleBookKind = v),
        const SizedBox(height: 12),
        _buildTextField('最新章节', _source.ruleBookLastChapter ?? '', (v) => _source.ruleBookLastChapter = v),
      ],
    );
  }

  Widget _buildTocContentTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('目录规则', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        _buildTextField('目录列表', _source.ruleToc ?? '', (v) => _source.ruleToc = v),
        const SizedBox(height: 12),
        _buildTextField('章节名称', _source.ruleTocName ?? '', (v) => _source.ruleTocName = v),
        const SizedBox(height: 12),
        _buildTextField('章节URL', _source.ruleTocUrl ?? '', (v) => _source.ruleTocUrl = v),
        const SizedBox(height: 12),
        _buildTextField('目录下一页', _source.ruleTocNext ?? '', (v) => _source.ruleTocNext = v),
        const SizedBox(height: 24),
        const Text('正文规则', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        _buildTextField('正文内容', _source.ruleContent ?? '', (v) => _source.ruleContent = v, maxLines: 2),
        const SizedBox(height: 12),
        _buildTextField('正文下一页', _source.ruleContentNext ?? '', (v) => _source.ruleContentNext = v),
        const SizedBox(height: 12),
        _buildTextField('图片URL', _source.ruleImageUrl ?? '', (v) => _source.ruleImageUrl = v),
      ],
    );
  }

  Widget _buildTextField(String label, String value, ValueChanged<String> onChanged, {int maxLines = 1}) {
    return TextFormField(
      initialValue: value,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}
