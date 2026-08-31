import 'package:flutter/material.dart';
import '../models/book_source.dart';
import '../services/book_source_engine.dart';

class SourceDebugScreen extends StatefulWidget {
  final BookSource source;

  const SourceDebugScreen({super.key, required this.source});

  @override
  State<SourceDebugScreen> createState() => _SourceDebugScreenState();
}

class _SourceDebugScreenState extends State<SourceDebugScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _bookUrlController = TextEditingController();
  final _tocUrlController = TextEditingController();
  final _contentUrlController = TextEditingController();
  final _engine = BookSourceEngine();
  String _debugLog = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _bookUrlController.dispose();
    _tocUrlController.dispose();
    _contentUrlController.dispose();
    super.dispose();
  }

  void _log(String message) {
    setState(() {
      _debugLog += '[${DateTime.now().toString().substring(11, 19)}] $message\n';
    });
  }

  Future<void> _debugSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      _log('错误: 请输入搜索关键词');
      return;
    }
    setState(() => _isLoading = true);
    _log('开始搜索: $keyword');
    _log('书源: ${widget.source.bookSourceName} (${widget.source.bookSourceUrl})');
    try {
      final results = await _engine.search(widget.source, keyword);
      _log('搜索完成，找到 ${results.length} 个结果');
      for (var i = 0; i < results.length && i < 5; i++) {
        final b = results[i];
        _log('  ${i + 1}. ${b.name} - ${b.author}');
        _log('     简介: ${(b.intro ?? '').substring(0, b.intro!.length > 50 ? 50 : b.intro!.length)}');
        _log('     目录URL: ${b.noteUrl ?? b.bookUrl ?? 'N/A'}');
      }
      if (results.isNotEmpty) {
        _bookUrlController.text = results.first.noteUrl ?? results.first.bookUrl ?? '';
      }
    } catch (e) {
      _log('搜索失败: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _debugBookInfo() async {
    final url = _bookUrlController.text.trim();
    if (url.isEmpty) {
      _log('错误: 请输入书籍URL');
      return;
    }
    setState(() => _isLoading = true);
    _log('开始获取书籍信息: $url');
    try {
      final book = await _engine.getBookInfo(widget.source, url);
      if (book != null) {
        _log('书名: ${book.name}');
        _log('作者: ${book.author}');
        _log('简介: ${book.intro ?? 'N/A'}');
        _log('分类: ${book.kind ?? 'N/A'}');
        _log('最新章节: ${book.lastChapter ?? 'N/A'}');
        _log('封面: ${book.coverUrl ?? 'N/A'}');
        _log('目录URL: ${book.noteUrl ?? 'N/A'}');
        _tocUrlController.text = book.noteUrl ?? '';
      } else {
        _log('未获取到书籍信息');
      }
    } catch (e) {
      _log('获取书籍信息失败: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _debugToc() async {
    final url = _tocUrlController.text.trim();
    if (url.isEmpty) {
      _log('错误: 请输入目录URL');
      return;
    }
    setState(() => _isLoading = true);
    _log('开始获取目录: $url');
    try {
      final chapters = await _engine.getToc(widget.source, url);
      _log('目录获取完成，共 ${chapters.length} 章');
      for (var i = 0; i < chapters.length && i < 10; i++) {
        _log('  ${i + 1}. ${chapters[i].title} -> ${chapters[i].url}');
      }
      if (chapters.isNotEmpty) {
        _contentUrlController.text = chapters.first.url;
      }
    } catch (e) {
      _log('获取目录失败: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _debugContent() async {
    final url = _contentUrlController.text.trim();
    if (url.isEmpty) {
      _log('错误: 请输入正文URL');
      return;
    }
    setState(() => _isLoading = true);
    _log('开始获取正文: $url');
    try {
      final content = await _engine.getContent(widget.source, url);
      if (content != null) {
        _log('正文获取完成，长度: ${content.length} 字符');
        _log('前200字: ${content.substring(0, content.length > 200 ? 200 : content.length)}');
      } else {
        _log('未获取到正文内容');
      }
    } catch (e) {
      _log('获取正文失败: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('调试: ${widget.source.bookSourceName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '搜索'),
            Tab(text: '书籍信息'),
            Tab(text: '目录'),
            Tab(text: '正文'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchTab(),
                _buildBookInfoTab(),
                _buildTocTab(),
                _buildContentTab(),
              ],
            ),
          ),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('调试日志', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      TextButton(
                        onPressed: () => setState(() => _debugLog = ''),
                        child: const Text('清空', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: SelectableText(
                      _debugLog.isEmpty ? '暂无日志' : _debugLog,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: '搜索关键词',
              hintText: '输入书名或作者',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLoading ? null : _debugSearch,
            icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
            label: const Text('测试搜索'),
          ),
          const SizedBox(height: 16),
          Text('搜索URL: ${widget.source.searchUrl ?? '未配置'}', style: const TextStyle(fontSize: 12)),
          if (widget.source.ruleSearch != null) ...[
            const SizedBox(height: 8),
            Text('规则列表: ${widget.source.ruleSearch!['bookList'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
            Text('规则书名: ${widget.source.ruleSearch!['name'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
            Text('规则作者: ${widget.source.ruleSearch!['author'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildBookInfoTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _bookUrlController,
            decoration: const InputDecoration(
              labelText: '书籍URL',
              hintText: '输入书籍详情页URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLoading ? null : _debugBookInfo,
            icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.info_outline),
            label: const Text('测试书籍信息'),
          ),
        ],
      ),
    );
  }

  Widget _buildTocTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _tocUrlController,
            decoration: const InputDecoration(
              labelText: '目录URL',
              hintText: '输入目录页URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLoading ? null : _debugToc,
            icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.list_alt),
            label: const Text('测试目录'),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _contentUrlController,
            decoration: const InputDecoration(
              labelText: '正文URL',
              hintText: '输入章节内容页URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLoading ? null : _debugContent,
            icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.article),
            label: const Text('测试正文'),
          ),
        ],
      ),
    );
  }
}
