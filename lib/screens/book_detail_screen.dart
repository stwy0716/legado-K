import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../models/book_chapter.dart';
import '../providers/book_provider.dart';
import '../services/database_service.dart';
import '../services/auto_update_service.dart';
import 'reading_screen.dart';
import 'chapter_list_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;
  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final DatabaseService _db = DatabaseService();
  List<BookChapter> _chapters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    _chapters = await _db.getChapters(widget.book.name, widget.book.author);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateBook() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在更新...')));
    try {
      final service = AutoUpdateService();
      await service.updateBook(widget.book);
      await context.read<BookProvider>().loadBooks();
      await _loadChapters();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新完成')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    }
  }

  Future<void> _cacheAll() async {
    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无章节')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('开始缓存 ${_chapters.length} 章...')));
    int cached = 0;
    for (int i = 0; i < _chapters.length; i++) {
      if (_chapters[i].content != null && _chapters[i].content!.isNotEmpty) {
        cached++;
        continue;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已缓存 $cached/${_chapters.length} 章')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.book.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.book.coverUrl != null && widget.book.coverUrl!.isNotEmpty)
                    Image.network(widget.book.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.primaryContainer))
                  else
                    Container(color: Theme.of(context).colorScheme.primaryContainer),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]))),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: widget.book.coverUrl != null && widget.book.coverUrl!.isNotEmpty
                            ? Image.network(widget.book.coverUrl!, width: 100, height: 140, fit: BoxFit.cover)
                            : Container(width: 100, height: 140, color: Colors.grey[300], child: Icon(Icons.book, size: 50, color: Colors.grey[500])),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.book.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('作者: ${widget.book.author}', style: Theme.of(context).textTheme.bodyMedium),
                            if (widget.book.kind != null) ...[
                              const SizedBox(height: 4),
                              Text('分类: ${widget.book.kind}', style: Theme.of(context).textTheme.bodyMedium),
                            ],
                            if (widget.book.originName != null) ...[
                              const SizedBox(height: 4),
                              Text('来源: ${widget.book.originName}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                            ],
                            if (widget.book.lastChapter != null) ...[
                              const SizedBox(height: 4),
                              Text('最新: ${widget.book.lastChapter}', style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 4),
                            Text('共 ${_chapters.length} 章', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ReadingScreen(book: widget.book))),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('开始阅读'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _updateBook,
                        icon: const Icon(Icons.refresh),
                        label: const Text('更新'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (widget.book.intro != null && widget.book.intro!.isNotEmpty) ...[
                    Text('简介', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(widget.book.intro!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                    const SizedBox(height: 24),
                  ],
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.list_alt),
                          title: const Text('目录'),
                          subtitle: Text('共 ${_chapters.length} 章'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _chapters.isEmpty
                              ? null
                              : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChapterListScreen(chapters: _chapters, currentIndex: widget.book.durChapterIndex ?? 0))),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.download),
                          title: const Text('缓存'),
                          subtitle: Text('已缓存 ${_chapters.where((c) => c.content != null && c.content!.isNotEmpty).length}/${_chapters.length} 章'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _cacheAll,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
