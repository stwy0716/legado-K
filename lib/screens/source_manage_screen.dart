import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../models/book_source.dart';
import '../services/database_service.dart';
import 'source_edit_screen.dart';

class SourceManageScreen extends StatefulWidget {
  const SourceManageScreen({super.key});

  @override
  State<SourceManageScreen> createState() => _SourceManageScreenState();
}

class _SourceManageScreenState extends State<SourceManageScreen> {
  final DatabaseService _db = DatabaseService();
  List<BookSource> _sources = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    setState(() => _isLoading = true);
    _sources = await _db.getAllSources();
    if (mounted) setState(() => _isLoading = false);
  }

  List<BookSource> get _filteredSources {
    if (_searchQuery.isEmpty) return _sources;
    return _sources
        .where((s) =>
            s.bookSourceName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.bookSourceUrl.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _toggleSource(BookSource source, bool enabled) async {
    source.enabled = enabled;
    await _db.updateSource(source);
    setState(() {});
  }

  Future<void> _deleteSource(BookSource source) async {
    await _db.deleteSource(source.bookSourceUrl);
    _loadSources();
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_link),
              title: const Text('网络导入'),
              subtitle: const Text('从URL导入书源JSON'),
              onTap: () {
                Navigator.pop(context);
                _showImportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('新建书源'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SourceEditScreen()),
                ).then((_) => _loadSources());
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('本地导入'),
              subtitle: const Text('从JSON文件导入'),
              onTap: () {
                Navigator.pop(context);
                _importFromFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromUrl(String url) async {
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));
      final response = await dio.get(url);
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      int count = await _importSourcesFromData(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 $count 个书源')),
        );
      }
      _loadSources();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );
      if (result == null || result.files.isEmpty || result.files.first.path == null) return;
      final content = await File(result.files.first.path!).readAsString();
      final data = jsonDecode(content);
      int count = await _importSourcesFromData(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 $count 个书源')),
        );
      }
      _loadSources();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  Future<int> _importSourcesFromData(dynamic data) async {
    int count = 0;
    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          try {
            final source = BookSource.fromJson(Map<String, dynamic>.from(item));
            await _db.insertSource(source);
            count++;
          } catch (_) {}
        }
      }
    } else if (data is Map) {
      try {
        final source = BookSource.fromJson(Map<String, dynamic>.from(data));
        await _db.insertSource(source);
        count++;
      } catch (_) {}
    }
    return count;
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('网络导入书源'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入书源URL（JSON格式）'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              Navigator.pop(context);
              if (url.isNotEmpty) _importFromUrl(url);
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('书源管理 (${_sources.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: SourceSearchDelegate(_sources, (source) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SourceEditScreen(source: source))).then((_) => _loadSources());
                }),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'enable_all':
                  for (final s in _sources) {
                    s.enabled = true;
                    _db.updateSource(s);
                  }
                  setState(() {});
                  break;
                case 'disable_all':
                  for (final s in _sources) {
                    s.enabled = false;
                    _db.updateSource(s);
                  }
                  setState(() {});
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'enable_all', child: Text('全部启用')),
              PopupMenuItem(value: 'disable_all', child: Text('全部禁用')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredSources.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredSources.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final source = _filteredSources[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: source.enabled == true
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Text(
                            source.bookSourceName.isNotEmpty ? source.bookSourceName[0] : '?',
                            style: TextStyle(color: source.enabled == true ? Theme.of(context).colorScheme.primary : Colors.grey),
                          ),
                        ),
                        title: Text(source.bookSourceName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(source.bookSourceUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                            if (source.bookSourceGroup != null && source.bookSourceGroup!.isNotEmpty)
                              Text('分组: ${source.bookSourceGroup}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                        trailing: Switch(
                          value: source.enabled == true,
                          onChanged: (value) => _toggleSource(source, value),
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => SourceEditScreen(source: source))).then((_) => _loadSources());
                        },
                        onLongPress: () => _showSourceOptions(source),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.source_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('暂无书源', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('点击右下角添加或导入书源', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _showSourceOptions(BookSource source) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SourceEditScreen(source: source))).then((_) => _loadSources());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () {
                Navigator.pop(context);
                _deleteSource(source);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SourceSearchDelegate extends SearchDelegate<BookSource> {
  final List<BookSource> sources;
  final Function(BookSource) onSelect;

  SourceSearchDelegate(this.sources, this.onSelect);

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => Navigator.pop(context),
  );

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = query.isEmpty
        ? sources
        : sources.where((s) => s.bookSourceName.contains(query) || s.bookSourceUrl.contains(query)).toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final source = results[index];
        return ListTile(
          title: Text(source.bookSourceName),
          subtitle: Text(source.bookSourceUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => onSelect(source),
        );
      },
    );
  }
}
