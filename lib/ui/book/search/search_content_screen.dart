import 'package:flutter/material.dart';
import 'package:legado_md3/data/local/app_database.dart';
import 'package:legado_md3/data/model/book.dart';
import 'package:legado_md3/data/model/book_chapter.dart';

/// 书内全文搜索 - 对齐原版SearchContentScreen
class SearchContentScreen extends StatefulWidget {
  final Book book;
  const SearchContentScreen({super.key, required this.book});

  @override
  State<SearchContentScreen> createState() => _SearchContentScreenState();
}

class _Result {
  final BookChapter chapter;
  final int chapterIndex;
  final List<String> snippets;
  _Result(this.chapter, this.chapterIndex, this.snippets);
}

class _SearchContentScreenState extends State<SearchContentScreen> {
  final _db = DatabaseService();
  final _controller = TextEditingController();
  List<BookChapter> _chapters = [];
  List<_Result> _results = [];
  bool _searching = false;
  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    _chapters = await _db.getChapters(widget.book.name, widget.book.author);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _searching = true);
    if (!_history.contains(query)) { _history.insert(0, query); if (_history.length > 20) _history.removeLast(); }
    await Future.delayed(const Duration(milliseconds: 100));
    final results = <_Result>[];
    for (var i = 0; i < _chapters.length; i++) {
      final ch = _chapters[i];
      final content = ch.content ?? '';
      if (content.isEmpty) continue;
      final snippets = <String>[];
      var idx = content.indexOf(query);
      while (idx >= 0 && snippets.length < 3) {
        final start = (idx - 20).clamp(0, content.length);
        final end = (idx + query.length + 20).clamp(0, content.length);
        snippets.add('...${content.substring(start, end)}...');
        idx = content.indexOf(query, idx + query.length);
      }
      if (snippets.isNotEmpty) results.add(_Result(ch, i, snippets));
    }
    setState(() { _results = results; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: '在本书中搜索', border: InputBorder.none),
          onSubmitted: _search,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => _search(_controller.text)),
        ],
      ),
      body: _searching
        ? const Center(child: CircularProgressIndicator())
        : _results.isNotEmpty
          ? ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final r = _results[i];
                return ExpansionTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: Text(r.chapter.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${r.snippets.length} 处匹配', style: const TextStyle(fontSize: 11)),
                  children: r.snippets.map((s) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 56, right: 16),
                    title: Text(s, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(context, r.chapterIndex),
                  )).toList(),
                );
              },
            )
          : _controller.text.isEmpty && _history.isNotEmpty
            ? ListView(children: [
                const Padding(padding: EdgeInsets.all(16), child: Text('搜索历史', style: TextStyle(fontWeight: FontWeight.bold))),
                ..._history.map((h) => ListTile(
                  leading: const Icon(Icons.history, size: 20),
                  title: Text(h),
                  onTap: () { _controller.text = h; _search(h); },
                )),
              ])
            : const Center(child: Text('输入关键词搜索本书内容', style: TextStyle(color: Colors.grey))),
    );
  }
}
