import 'package:flutter/material.dart';
import '../models/book_chapter.dart';

class ChapterListScreen extends StatefulWidget {
  final List<BookChapter> chapters;
  final int currentIndex;

  const ChapterListScreen({super.key, required this.chapters, required this.currentIndex});

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends State<ChapterListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<BookChapter> _filteredChapters = [];
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _filteredChapters = widget.chapters;
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.currentIndex < widget.chapters.length) {
        final itemHeight = 56.0;
        _scrollController.animateTo(
          widget.currentIndex * itemHeight,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filterChapters(String query) {
    if (query.isEmpty) {
      _filteredChapters = widget.chapters;
    } else {
      _filteredChapters = widget.chapters
          .where((c) => c.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('目录 (${widget.chapters.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新目录',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在更新目录...')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索章节',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterChapters('');
                        },
                      )
                    : null,
              ),
              onChanged: _filterChapters,
            ),
          ),
          Expanded(
            child: _filteredChapters.isEmpty
                ? Center(child: Text('未找到章节', style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _filteredChapters.length,
                    itemBuilder: (context, index) {
                      final chapter = _filteredChapters[index];
                      final isCurrent = chapter.index == widget.currentIndex;
                      return ListTile(
                        title: Text(
                          chapter.title,
                          style: TextStyle(
                            color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                            fontWeight: isCurrent ? FontWeight.bold : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isCurrent ? Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary) : null,
                        onTap: () => Navigator.pop(context, chapter.index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
