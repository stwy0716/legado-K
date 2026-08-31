import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/search_book.dart';
import '../models/book.dart';
import '../providers/book_provider.dart';
import '../services/database_service.dart';
import '../services/book_source_engine.dart';
import 'reading_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseService _db = DatabaseService();
  final BookSourceEngine _engine = BookSourceEngine();
  List<SearchBook> _results = [];
  bool _isSearching = false;
  String? _searchKeyword;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _results = [];
      _searchKeyword = keyword;
    });

    final sources = await _db.getAllSources(enabled: true);
    final List<SearchBook> allResults = [];

    // 并发搜索所有书源
    await Future.wait(sources.map((source) async {
      try {
        final books = await _engine.search(source, keyword);
        allResults.addAll(books);
      } catch (_) {}
    }));

    if (mounted) {
      setState(() {
        _results = allResults;
        _isSearching = false;
      });
    }
  }

  Future<void> _addToShelf(SearchBook book) async {
    final provider = context.read<BookProvider>();
    final newBook = book.toBook();
    await provider.addBook(newBook);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加《${book.name}》到书架')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '搜索书名、作者',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_controller.text),
          ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? _buildEmptyState()
              : _buildResults(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchKeyword == null ? '输入关键词开始搜索' : '未找到相关书籍',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          if (_searchKeyword != null) ...[
            const SizedBox(height: 8),
            Text('请检查书源是否已启用', style: TextStyle(color: Colors.grey[500])),
          ],
        ],
      ),
    );
  }

  Widget _buildResults() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final book = _results[index];
        return Card(
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                  ? Image.network(book.coverUrl!, width: 48, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 48, height: 64, color: Colors.grey[300], child: Icon(Icons.book, color: Colors.grey[500])))
                  : Container(width: 48, height: 64, color: Colors.grey[300], child: Icon(Icons.book, color: Colors.grey[500])),
            ),
            title: Text(book.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.author, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (book.originName != null)
                  Text(book.originName!, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
            trailing: FilledButton.tonal(
              onPressed: () => _addToShelf(book),
              child: const Text('加入'),
            ),
            onTap: () => _addToShelf(book),
          ),
        );
      },
    );
  }
}
