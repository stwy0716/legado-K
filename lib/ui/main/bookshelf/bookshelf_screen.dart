import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:legado_md3/data/model/book.dart';
import 'package:legado_md3/di/book_provider.dart';
import 'package:legado_md3/data/local/app_database.dart';
import 'package:legado_md3/help/source/source_engine.dart';
import 'package:legado_md3/ui/book/detail/book_detail_screen.dart';
import 'package:legado_md3/ui/book/read/reading_screen.dart';
import 'package:legado_md3/ui/book/local_import_screen.dart';
import 'package:legado_md3/ui/book/search/search_screen.dart';
import 'package:legado_md3/ui/book/detail/change_source_screen.dart';
import 'package:legado_md3/ui/book/detail/change_cover_screen.dart';
import 'package:legado_md3/ui/bookmark/book_marking_screen.dart';
import 'package:legado_md3/ui/main/bookshelf/group_manage_screen.dart';
import 'package:legado_md3/ui/book/source/source_manage_screen.dart';
import 'package:legado_md3/ui/stats/read_record_screen.dart';
import 'package:legado_md3/ui/config/settings_screen.dart';

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  final DatabaseService _db = DatabaseService();
  final BookSourceEngine _engine = BookSourceEngine();
  bool _selectMode = false;
  final Set<Book> _selectedBooks = {};
  bool _isUpdating = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<Map<String, dynamic>> _layouts = [
    {'name': '列表', 'icon': Icons.view_list},
    {'name': '紧凑列表', 'icon': Icons.view_agenda},
    {'name': '网格', 'icon': Icons.grid_view},
    {'name': '紧凑网格', 'icon': Icons.grid_on},
    {'name': '封面网格', 'icon': Icons.photo_library},
  ];

  static const List<String> _sortOptions = ['智能排序', '书名', '作者', '最近阅读', '添加时间', '字数'];
  int _sortBy = 0;
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookProvider>(context, listen: false).loadBooks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Book> get _filteredBooks {
    final provider = Provider.of<BookProvider>(context, listen: false);
    var books = provider.filteredBooks;
    if (_searchQuery.isNotEmpty) {
      books = books.where((b) =>
          b.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.author.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    books = List.from(books);
    switch (_sortBy) {
      case 1: books.sort((a, b) => _sortAsc ? a.name.compareTo(b.name) : b.name.compareTo(a.name)); break;
      case 2: books.sort((a, b) => _sortAsc ? a.author.compareTo(b.author) : b.author.compareTo(a.author)); break;
      case 3: books.sort((a, b) => _sortAsc ? (a.durChapterTime ?? 0).compareTo(b.durChapterTime ?? 0) : (b.durChapterTime ?? 0).compareTo(a.durChapterTime ?? 0)); break;
      case 4: books.sort((a, b) => _sortAsc ? (a.lastCheckTime ?? 0).compareTo(b.lastCheckTime ?? 0) : (b.lastCheckTime ?? 0).compareTo(a.lastCheckTime ?? 0)); break;
      case 5: books.sort((a, b) => _sortAsc ? (a.wordCount ?? 0).compareTo(b.wordCount ?? 0) : (b.wordCount ?? 0).compareTo(a.wordCount ?? 0)); break;
    }
    return books;
  }

  Future<void> _updateAllBooks() async {
    setState(() => _isUpdating = true);
    final provider = Provider.of<BookProvider>(context, listen: false);
    final books = provider.books.where((b) => !b.local && b.origin != null && b.noteUrl != null).toList();
    final sources = await _db.getAllSources(enabled: true);
    final sourceMap = {for (var s in sources) s.bookSourceUrl: s};
    int updated = 0;
    for (final book in books) {
      final source = sourceMap[book.origin];
      if (source == null) continue;
      try {
        final newChapters = await _engine.getToc(source, book.noteUrl!);
        final oldChapters = await _db.getChapters(book.name, book.author);
        if (newChapters.length > oldChapters.length) {
          await _db.saveChapters(book.name, book.author, newChapters);
          book.lastChapter = newChapters.last.title;
          book.lastChapterIndex = newChapters.length - 1;
          book.latestChapterTime = DateTime.now().millisecondsSinceEpoch;
          await _db.updateBook(book);
          updated++;
        }
      } catch (_) {}
    }
    await provider.loadBooks();
    setState(() => _isUpdating = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新完成，$updated 本有新章节')));
  }

  void _showLayoutDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('书架布局'),
      content: Column(mainAxisSize: MainAxisSize.min, children: List.generate(_layouts.length, (index) {
        final layout = _layouts[index];
        final isSelected = Provider.of<BookProvider>(context).bookshelfLayout == index;
        return ListTile(
          leading: Icon(layout['icon']),
          title: Text(layout['name']),
          trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
          onTap: () { Provider.of<BookProvider>(context, listen: false).setBookshelfLayout(index); Navigator.pop(context); },
        );
      })),
    ));
  }

  void _showSortDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('排序方式'),
      content: Column(mainAxisSize: MainAxisSize.min, children: List.generate(_sortOptions.length, (index) => ListTile(
        title: Text(_sortOptions[index]),
        trailing: _sortBy == index ? Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.green) : null,
        onTap: () { if (_sortBy == index) { setState(() => _sortAsc = !_sortAsc); } else { setState(() => _sortBy = index); } Navigator.pop(context); },
      ))),
    ));
  }

  void _showMoreMenu() {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.search), title: const Text('搜索书籍'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())); }),
      ListTile(leading: const Icon(Icons.refresh), title: const Text('一键更新'), onTap: () { Navigator.pop(context); _updateAllBooks(); }),
      const Divider(),
      ListTile(leading: const Icon(Icons.folder_open), title: const Text('本地导入'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalImportScreen())); }),
      ListTile(leading: const Icon(Icons.cloud_download), title: const Text('网络导入'), onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络导入功能'))); }),
      const Divider(),
      ListTile(leading: const Icon(Icons.view_module), title: const Text('布局设置'), onTap: () { Navigator.pop(context); _showLayoutDialog(); }),
      ListTile(leading: const Icon(Icons.sort), title: const Text('排序设置'), onTap: () { Navigator.pop(context); _showSortDialog(); }),
      ListTile(leading: const Icon(Icons.folder_special), title: const Text('分组管理'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupManageScreen())); }),
      ListTile(leading: const Icon(Icons.select_all), title: const Text('多选模式'), onTap: () { Navigator.pop(context); setState(() => _selectMode = true); }),
      const Divider(),
      ListTile(leading: const Icon(Icons.menu_book_outlined), title: const Text('书源管理'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SourceManageScreen())); }),
      ListTile(leading: const Icon(Icons.bar_chart_outlined), title: const Text('阅读记录'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadRecordScreen())); }),
      ListTile(leading: const Icon(Icons.settings), title: const Text('设置'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }),
      const Divider(),
      ListTile(leading: const Icon(Icons.delete_sweep, color: Colors.red), title: const Text('清空书架', style: TextStyle(color: Colors.red)), onTap: () async {
        Navigator.pop(context);
        final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('清空书架'), content: const Text('确定要清空所有书籍吗？'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('清空'))]));
        if (confirmed == true) { final provider = Provider.of<BookProvider>(context, listen: false); for (final book in provider.books) { await _db.deleteBook(book.name, book.author); } await provider.loadBooks(); }
      }),
    ])));
  }

  void _showBookMenu(Book book) {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.play_arrow), title: const Text('开始阅读'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingScreen(book: book))); }),
      ListTile(leading: const Icon(Icons.info_outline), title: const Text('书籍详情'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book))); }),
      const Divider(),
      ListTile(leading: const Icon(Icons.refresh), title: const Text('更新目录'), onTap: () async {
        Navigator.pop(context);
        if (book.local || book.origin == null || book.noteUrl == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('本地书籍无需更新'))); return; }
        final sources = await _db.getAllSources(enabled: true);
        final source = sources.where((s) => s.bookSourceUrl == book.origin).firstOrNull;
        if (source == null) return;
        try { final chapters = await _engine.getToc(source, book.noteUrl!); await _db.saveChapters(book.name, book.author, chapters); book.lastChapter = chapters.last.title; book.lastChapterIndex = chapters.length - 1; await _db.updateBook(book); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新完成，共${chapters.length}章'))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e'))); }
      }),
      ListTile(leading: const Icon(Icons.swap_horiz), title: const Text('换源'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeSourceScreen(book: book))); }),
      ListTile(leading: const Icon(Icons.image_outlined), title: const Text('换封面'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeCoverScreen(book: book))); }),
      ListTile(leading: const Icon(Icons.download), title: const Text('缓存全部'), onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('开始缓存...'))); }),
      ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('书籍标记'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => BookMarkingScreen(bookName: book.name, author: book.author))); }),
      ListTile(leading: const Icon(Icons.bookmark_border), title: const Text('添加书签'), onTap: () async {
        Navigator.pop(context);
        final bookmark = await _db.getBookmarks(book.name, book.author);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('当前共${bookmark.length}个书签')));
      }),
      const Divider(),
      ListTile(leading: const Icon(Icons.move_down), title: const Text('移动到分组'), onTap: () { Navigator.pop(context); _showMoveGroupDialog(book); }),
      ListTile(leading: const Icon(Icons.push_pin_outlined), title: Text(book.order != null && book.order! < 0 ? '取消置顶' : '置顶'), onTap: () async {
        Navigator.pop(context);
        book.order = (book.order != null && book.order! < 0) ? 0 : -1;
        await _db.updateBook(book);
        await Provider.of<BookProvider>(context, listen: false).loadBooks();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(book.order != null && book.order! < 0 ? '已置顶' : '已取消置顶')));
      }),
      ListTile(leading: const Icon(Icons.share), title: const Text('分享'), onTap: () async {
        Navigator.pop(context);
        await Share.share('《${book.name}》 - ${book.author}\n${book.intro ?? ''}', subject: book.name);
      }),
      const Divider(),
      ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('删除', style: TextStyle(color: Colors.red)), onTap: () async {
        Navigator.pop(context);
        final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text('删除《${book.name}》'), content: const Text('确定要删除这本书吗？'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('删除'))]));
        if (confirmed == true) { await _db.deleteBook(book.name, book.author); await Provider.of<BookProvider>(context, listen: false).loadBooks(); }
      }),
    ]))));
  }

  void _showMoveGroupDialog(Book book) {
    final provider = Provider.of<BookProvider>(context, listen: false);
    final controller = TextEditingController(text: book.group ?? '');
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('移动到分组'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: '输入分组名称（留空为默认）')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), FilledButton(onPressed: () async { book.group = controller.text.trim().isEmpty ? null : controller.text.trim(); await _db.updateBook(book); await provider.loadBooks(); if (mounted) Navigator.pop(context); }, child: const Text('确定'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BookProvider>(context);
    final books = _filteredBooks;
    final layout = provider.bookshelfLayout;
    return Scaffold(
      appBar: AppBar(
        title: _searchQuery.isEmpty ? const Text('书架') : TextField(controller: _searchController, autofocus: true, decoration: const InputDecoration(hintText: '搜索书籍...', border: InputBorder.none), onChanged: (v) => setState(() => _searchQuery = v)),
        actions: [
          if (_searchQuery.isEmpty) IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _searchQuery = ' ')),
          if (_searchQuery.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }),
          if (_selectMode) IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _selectMode = false; _selectedBooks.clear(); })) else IconButton(icon: const Icon(Icons.more_vert), onPressed: _showMoreMenu),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(48), child: _buildGroupTabs(provider)),
      ),
      body: _isUpdating ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在更新...')])) : books.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey[400]), const SizedBox(height: 16), Text('书架为空', style: TextStyle(color: Colors.grey[600], fontSize: 16)), const SizedBox(height: 8), Text('去搜索或发现页面添加书籍', style: TextStyle(color: Colors.grey[500])), const SizedBox(height: 24), FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())), icon: const Icon(Icons.search), label: const Text('去搜索'))])) : _buildBookList(books, layout),
      floatingActionButton: _selectMode ? FloatingActionButton.extended(onPressed: _selectedBooks.isEmpty ? null : () async { for (final book in _selectedBooks) { await _db.deleteBook(book.name, book.author); } await provider.loadBooks(); setState(() { _selectMode = false; _selectedBooks.clear(); }); }, icon: const Icon(Icons.delete), label: Text('删除 (${_selectedBooks.length})'), backgroundColor: Colors.red) : null,
    );
  }

  Widget _buildGroupTabs(BookProvider provider) => Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 8), child: ListView(scrollDirection: Axis.horizontal, children: [
    FilterChip(label: const Text('全部'), selected: provider.currentGroup == '全部', onSelected: (_) => provider.setCurrentGroup('全部')),
    const SizedBox(width: 8),
    ...provider.groups.where((g) => g != '全部').map((g) => Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(g), selected: provider.currentGroup == g, onSelected: (_) => provider.setCurrentGroup(g)))),
  ]));

  Widget _buildBookList(List<Book> books, int layout) {
    switch (layout) {
      case 0: return ListView.separated(padding: const EdgeInsets.all(8), itemCount: books.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, index) => _buildListItem(books[index]));
      case 1: return ListView.separated(padding: const EdgeInsets.all(4), itemCount: books.length, separatorBuilder: (_, __) => const Divider(height: 1, indent: 72), itemBuilder: (context, index) => _buildCompactListItem(books[index]));
      case 2: return GridView.builder(padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.65, crossAxisSpacing: 8, mainAxisSpacing: 8), itemCount: books.length, itemBuilder: (context, index) => _buildGridItem(books[index], compact: false));
      case 3: return GridView.builder(padding: const EdgeInsets.all(4), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.6, crossAxisSpacing: 4, mainAxisSpacing: 4), itemCount: books.length, itemBuilder: (context, index) => _buildGridItem(books[index], compact: true));
      case 4: return GridView.builder(padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.6, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: books.length, itemBuilder: (context, index) => _buildCoverItem(books[index]));
      default: return ListView.builder(itemCount: books.length, itemBuilder: (context, index) => _buildListItem(books[index]));
    }
  }

  Widget _buildListItem(Book book) {
    final selected = _selectedBooks.contains(book);
    return ListTile(
      leading: _buildCover(book, width: 50, height: 70),
      title: Text(book.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(book.author, maxLines: 1, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 2),
        Text(book.lastChapter ?? '暂无章节', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
      ]),
      trailing: _selectMode ? Checkbox(value: selected, onChanged: (_) => _toggleSelect(book)) : const Icon(Icons.chevron_right),
      selected: selected,
      onTap: () => _selectMode ? _toggleSelect(book) : Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingScreen(book: book))),
      onLongPress: () => _selectMode ? _toggleSelect(book) : _showBookMenu(book),
    );
  }

  Widget _buildCompactListItem(Book book) {
    final selected = _selectedBooks.contains(book);
    return ListTile(
      dense: true,
      leading: _buildCover(book, width: 36, height: 50),
      title: Text(book.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
      subtitle: Text('${book.author} · ${book.lastChapter ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
      trailing: _selectMode ? Checkbox(value: selected, onChanged: (_) => _toggleSelect(book)) : null,
      selected: selected,
      onTap: () => _selectMode ? _toggleSelect(book) : Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingScreen(book: book))),
      onLongPress: () => _selectMode ? _toggleSelect(book) : _showBookMenu(book),
    );
  }

  Widget _buildGridItem(Book book, {required bool compact}) {
    final selected = _selectedBooks.contains(book);
    return GestureDetector(
      onTap: () => _selectMode ? _toggleSelect(book) : Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingScreen(book: book))),
      onLongPress: () => _selectMode ? _toggleSelect(book) : _showBookMenu(book),
      child: Container(decoration: selected ? BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2), borderRadius: BorderRadius.circular(8)) : null, child: Column(children: [
        Expanded(child: _buildCover(book, width: double.infinity, height: double.infinity, radius: 8)),
        Padding(padding: EdgeInsets.all(compact ? 4 : 8), child: Text(book.name, maxLines: compact ? 1 : 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 11 : 13))),
      ])),
    );
  }

  Widget _buildCoverItem(Book book) {
    final selected = _selectedBooks.contains(book);
    return GestureDetector(
      onTap: () => _selectMode ? _toggleSelect(book) : Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingScreen(book: book))),
      onLongPress: () => _selectMode ? _toggleSelect(book) : _showBookMenu(book),
      child: Container(decoration: selected ? BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3), borderRadius: BorderRadius.circular(12)) : null, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildCover(book, width: double.infinity, height: double.infinity, radius: 0))),
    );
  }

  Widget _buildCover(Book book, {required double width, required double height, double radius = 4}) {
    if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
      return ClipRRect(borderRadius: BorderRadius.circular(radius), child: Image.network(book.coverUrl!, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildDefaultCover(book, width, height, radius)));
    }
    return _buildDefaultCover(book, width, height, radius);
  }

  Widget _buildDefaultCover(Book book, double width, double height, double radius) {
    final colors = [Colors.blueGrey, Colors.brown, Colors.teal, Colors.indigo, Colors.deepOrange, Colors.purple];
    final color = colors[book.name.hashCode.abs() % colors.length];
    return Container(width: width, height: height, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)), child: Center(child: Padding(padding: const EdgeInsets.all(4), child: Text(book.name, maxLines: 3, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))));
  }

  void _toggleSelect(Book book) => setState(() => _selectedBooks.contains(book) ? _selectedBooks.remove(book) : _selectedBooks.add(book));
}
