import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../services/database_service.dart';

class ChangeSourceScreen extends StatefulWidget {
  final Book book;
  const ChangeSourceScreen({super.key, required this.book});

  @override
  State<ChangeSourceScreen> createState() => _ChangeSourceScreenState();
}

class _ChangeSourceScreenState extends State<ChangeSourceScreen> {
  final DatabaseService _db = DatabaseService();
  List<BookSource> _sources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    final sources = await _db.getAllSources(enabled: true);
    setState(() {
      _sources = sources;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('换源 - ${widget.book.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sources.isEmpty
              ? const Center(child: Text('暂无可用书源'))
              : ListView.builder(
                  itemCount: _sources.length,
                  itemBuilder: (context, index) {
                    final source = _sources[index];
                    final isCurrent = source.bookSourceUrl == widget.book.origin;
                    return Card(
                      color: isCurrent ? Theme.of(context).colorScheme.primaryContainer : null,
                      child: ListTile(
                        leading: CircleAvatar(child: Text(source.bookSourceName.isNotEmpty ? source.bookSourceName[0] : '?')),
                        title: Text(source.bookSourceName),
                        subtitle: Text(source.bookSourceUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: isCurrent ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.chevron_right),
                        onTap: () {
                          if (!isCurrent) {
                            _changeSource(source);
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _changeSource(BookSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认换源'),
        content: Text('确定要将《${widget.book.name}》的书源更换为「${source.bookSourceName}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (confirmed == true) {
      final updatedBook = Book(
        name: widget.book.name, author: widget.book.author,
        origin: source.bookSourceUrl, originName: source.bookSourceName,
        bookUrl: widget.book.bookUrl, coverUrl: widget.book.coverUrl,
        intro: widget.book.intro, kind: widget.book.kind,
        latestChapterTitle: widget.book.latestChapterTitle,
        lastChapterTime: widget.book.lastChapterTime,
        updateTime: widget.book.updateTime, lastCheckTime: widget.book.lastCheckTime,
        order: widget.book.order, groupId: widget.book.groupId,
      );
      await _db.updateBook(updatedBook);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('换源成功')));
        Navigator.pop(context, true);
      }
    }
  }
}
