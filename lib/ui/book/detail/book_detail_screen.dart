import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:legado_md3/data/model/book.dart';
import 'package:legado_md3/data/model/book_chapter.dart';
import 'package:legado_md3/di/book_provider.dart';
import 'package:legado_md3/data/local/app_database.dart';
import 'package:legado_md3/help/source/source_engine.dart';
import 'package:legado_md3/ui/book/read/reading_screen.dart';
import 'package:legado_md3/ui/book/chapter/chapter_list_screen.dart';
import 'package:legado_md3/ui/book/knowledge/character_list_screen.dart';

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
  bool _introExpanded = false;
  int _readChapterIndex = 0;
  int _readPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadChapters();
    _loadReadProgress();
  }

  Future<void> _loadChapters() async {
    _chapters = await _db.getChapters(widget.book.name, widget.book.author);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadReadProgress() async {
    final records = await _db.getReadRecords();
    for (final r in records) {
      if (r.bookName == widget.book.name && r.author == widget.book.author) {
        _readChapterIndex = (r.chapterIndex as int?) ?? 0;
        _readPageIndex = (r.pagePos as int?) ?? 0;
        break;
      }
    }
  }

  Future<void> _updateBook() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在更新...')));
    try {
      final sources = await _db.getAllSources(enabled: true);
      final source = sources.where((s) => s.bookSourceUrl == widget.book.origin).firstOrNull;
      if (source != null && widget.book.noteUrl != null) {
        final engine = BookSourceEngine();
        final chapters = await engine.getToc(source, widget.book.noteUrl!);
        await _db.saveChapters(widget.book.name, widget.book.author, chapters);
        widget.book.lastChapter = chapters.last.title;
        widget.book.lastChapterIndex = chapters.length - 1;
        await _db.updateBook(widget.book);
        await _loadChapters();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新完成，共${chapters.length}章')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
    }
  }

  Future<void> _downloadAll() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('开始缓存全部章节...')));
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('更新书籍'),
              onTap: () { Navigator.pop(context); _updateBook(); },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('缓存全部'),
              onTap: () { Navigator.pop(context); _downloadAll(); },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('换源'),
              onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('换源功能开发中'))); },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('换封面'),
              onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('换封面功能开发中'))); },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('角色列表'),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => CharacterListScreen(book: widget.book))); },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分享功能开发中'))); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('从书架移除', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('移除书籍'),
                    content: Text('确定要从书架移除《${widget.book.name}》吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                      FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('移除')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _db.deleteBook(widget.book.name, widget.book.author);
                  await Provider.of<BookProvider>(context, listen: false).loadBooks();
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(book),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.more_vert), onPressed: _showMoreMenu),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 基本信息
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCover(book),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(book.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), maxLines: 2),
                            const SizedBox(height: 8),
                            Text(book.author, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (book.kind != null && book.kind!.isNotEmpty) _buildTag(book.kind!),
                                _buildTag(book.local ? '本地' : '网络'),
                                if (book.wordCount != null) _buildTag('${(book.wordCount! / 10000).toStringAsFixed(1)}万字'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 操作按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingScreen(book: book))),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('开始阅读'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChapterListScreen(book: book))),
                          icon: const Icon(Icons.list_alt),
                          label: const Text('目录'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 阅读进度
                if (_chapters.isNotEmpty) Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.bookmark, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('读到: ${_chapters[_readChapterIndex.clamp(0, _chapters.length - 1)].title}', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('进度: ${((_readChapterIndex + 1) / _chapters.length * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingScreen(book: book, initialChapter: _readChapterIndex))), child: const Text('继续')),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 简介
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() => _introExpanded = !_introExpanded),
                        child: Text(
                          book.intro ?? '暂无简介',
                          style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey[700]),
                          maxLines: _introExpanded ? null : 4,
                          overflow: _introExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                      ),
                      if ((book.intro?.length ?? 0) > 100) TextButton(
                        onPressed: () => setState(() => _introExpanded = !_introExpanded),
                        child: Text(_introExpanded ? '收起' : '展开'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 最新章节
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('最新章节', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChapterListScreen(book: book))), child: const Text('全部目录')),
                        ],
                      ),
                      if (_isLoading)
                        const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                      else if (_chapters.isEmpty)
                        const Padding(padding: EdgeInsets.all(16), child: Text('暂无章节'))
                      else
                        ..._chapters.reversed.take(5).map((chapter) => ListTile(
                          dense: true,
                          title: Text(chapter.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: chapter.isVolume ? const Icon(Icons.folder, size: 16) : null,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingScreen(book: book, initialChapter: _chapters.indexOf(chapter)))),
                        )),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Book book) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).scaffoldBackgroundColor],
        ),
      ),
      child: Center(
        child: _buildCover(book, large: true),
      ),
    );
  }

  Widget _buildCover(Book book, {bool large = false}) {
    final width = large ? 120.0 : 80.0;
    final height = large ? 160.0 : 110.0;
    if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(book.coverUrl!, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildDefaultCover(book, width, height)),
      );
    }
    return _buildDefaultCover(book, width, height);
  }

  Widget _buildDefaultCover(Book book, double width, double height) {
    final colors = [Colors.blueGrey, Colors.brown, Colors.teal, Colors.indigo, Colors.deepOrange, Colors.purple];
    final color = colors[book.name.hashCode.abs() % colors.length];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Center(child: Padding(padding: const EdgeInsets.all(8), child: Text(book.name, maxLines: 3, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
    );
  }

  Widget _buildTag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSecondaryContainer)),
  );
}
