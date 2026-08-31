import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/book_provider.dart';
import '../models/book.dart';
import '../services/local_file_service.dart';
import '../services/auto_update_service.dart';
import 'reading_screen.dart';
import 'search_screen.dart';
import 'book_detail_screen.dart';

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  bool _selectMode = false;
  final Set<String> _selectedBooks = {};
  bool _isUpdating = false;

  // 5种布局: 0=列表 1=紧凑列表 2=网格 3=紧凑网格 4=封面网格
  static const List<Map<String, dynamic>> _layouts = [
    {'name': '列表', 'icon': Icons.view_list},
    {'name': '紧凑列表', 'icon': Icons.view_agenda},
    {'name': '网格', 'icon': Icons.grid_view},
    {'name': '紧凑网格', 'icon': Icons.grid_on},
    {'name': '封面网格', 'icon': Icons.photo_library},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookProvider>(context, listen: false).loadBooks();
    });
  }

  void _toggleSelect(Book book) {
    setState(() {
      final key = '${book.name}_${book.author}';
      if (_selectedBooks.contains(key)) {
        _selectedBooks.remove(key);
      } else {
        _selectedBooks.add(key);
      }
      if (_selectedBooks.isEmpty) _selectMode = false;
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedBooks.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final provider = Provider.of<BookProvider>(context, listen: false);
    for (final key in _selectedBooks) {
      final parts = key.split('_');
      await provider.removeBook(parts[0], parts.sublist(1).join('_'));
    }
    _exitSelectMode();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 ${_selectedBooks.length} 本书')),
      );
    }
  }

  Future<void> _updateAll() async {
    setState(() => _isUpdating = true);
    final service = AutoUpdateService();
    final result = await service.updateAllBooks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.summary)));
      Provider.of<BookProvider>(context, listen: false).loadBooks();
    }
    setState(() => _isUpdating = false);
  }

  Future<void> _importLocal() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'epub'],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      final localService = LocalFileService();
      final provider = context.read<BookProvider>();
      int imported = 0;
      for (final file in result.files) {
        if (file.path == null) continue;
        LocalImportResult? importResult;
        if (file.extension?.toLowerCase() == 'txt') {
          importResult = await localService.importTxt(file.path!);
        } else if (file.extension?.toLowerCase() == 'epub') {
          importResult = await localService.importEpub(file.path!);
        }
        if (importResult != null) {
          await provider.addBook(importResult.book);
          if (importResult.chapters.isNotEmpty) {
            await provider.saveChapters(importResult.book, importResult.chapters);
          }
          imported++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('成功导入 $imported 本书')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  void _showLayoutPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('书架布局', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...List.generate(_layouts.length, (index) {
              final layout = _layouts[index];
              final isSelected = context.read<BookProvider>().bookshelfLayout == index;
              return ListTile(
                leading: Icon(layout['icon'] as IconData),
                title: Text(layout['name'] as String),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  context.read<BookProvider>().setBookshelfLayout(index);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 折叠AppBar
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            title: const Text('书架'),
            actions: [
              if (_isUpdating)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'layout':
                      _showLayoutPicker();
                      break;
                    case 'update':
                      _updateAll();
                      break;
                    case 'manage':
                      setState(() => _selectMode = true);
                      break;
                    case 'import':
                      _importLocal();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'layout', child: Row(children: [Icon(Icons.grid_view, size: 20), SizedBox(width: 12), Text('书架布局')])),
                  const PopupMenuItem(value: 'update', child: Row(children: [Icon(Icons.refresh, size: 20), SizedBox(width: 12), Text('一键更新')])),
                  const PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.folder_open, size: 20), SizedBox(width: 12), Text('本地导入')])),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'manage', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 12), Text('管理')])),
                ],
              ),
            ],
            // 分组选择器
            bottom: provider.groups.length > 1
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(52),
                    child: SizedBox(
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.groups.length,
                        itemBuilder: (context, index) {
                          final group = provider.groups[index];
                          final isSelected = provider.currentGroup == group;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                            child: ChoiceChip(
                              label: Text(group),
                              selected: isSelected,
                              onSelected: (_) => provider.setCurrentGroup(group),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                : null,
          ),
          // 内容区
          if (provider.isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (provider.filteredBooks.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, _selectMode ? 80 : 88),
              sliver: _buildBookshelf(provider),
            ),
        ],
      ),
      // 选择模式底部操作栏
      bottomNavigationBar: _selectMode ? _buildSelectBottomBar() : null,
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddMenu(),
              icon: const Icon(Icons.add),
              label: const Text('添加'),
            ),
    );
  }

  Widget _buildSelectBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('已选 ${_selectedBooks.length} 本', style: const TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  final provider = context.read<BookProvider>();
                  setState(() {
                    for (final book in provider.filteredBooks) {
                      _selectedBooks.add('${book.name}_${book.author}');
                    }
                  });
                },
                icon: const Icon(Icons.select_all),
                label: const Text('全选'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _selectedBooks.isEmpty ? null : _deleteSelected,
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                icon: const Icon(Icons.delete),
                label: const Text('删除'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('书架空空如也', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('点击下方按钮添加书籍', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildBookshelf(BookProvider provider) {
    switch (provider.bookshelfLayout) {
      case 0:
        return _buildListLayout(provider, compact: false);
      case 1:
        return _buildListLayout(provider, compact: true);
      case 2:
        return _buildGridLayout(provider, compact: false);
      case 3:
        return _buildGridLayout(provider, compact: true);
      case 4:
        return _buildCoverGridLayout(provider);
      default:
        return _buildListLayout(provider, compact: false);
    }
  }

  Widget _buildListLayout(BookProvider provider, {required bool compact}) {
    return SliverList.separated(
      itemCount: provider.filteredBooks.length,
      separatorBuilder: (_, __) => SizedBox(height: compact ? 2 : 6),
      itemBuilder: (context, index) {
        final book = provider.filteredBooks[index];
        final key = '${book.name}_${book.author}';
        final isSelected = _selectedBooks.contains(key);
        return _BookListItem(
          book: book,
          compact: compact,
          selectMode: _selectMode,
          isSelected: isSelected,
          onTap: () => _selectMode ? _toggleSelect(book) : _openBook(book),
          onLongPress: () => _selectMode ? _toggleSelect(book) : _showBookOptions(book),
        );
      },
    );
  }

  Widget _buildGridLayout(BookProvider provider, {required bool compact}) {
    final crossAxisCount = compact ? 4 : 3;
    return SliverMasonryGrid.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: compact ? 6 : 12,
      crossAxisSpacing: compact ? 6 : 12,
      childCount: provider.filteredBooks.length,
      itemBuilder: (context, index) {
        final book = provider.filteredBooks[index];
        final key = '${book.name}_${book.author}';
        final isSelected = _selectedBooks.contains(key);
        return _BookGridItem(
          book: book,
          compact: compact,
          selectMode: _selectMode,
          isSelected: isSelected,
          onTap: () => _selectMode ? _toggleSelect(book) : _openBook(book),
          onLongPress: () => _selectMode ? _toggleSelect(book) : _showBookOptions(book),
        );
      },
    );
  }

  Widget _buildCoverGridLayout(BookProvider provider) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final book = provider.filteredBooks[index];
          final key = '${book.name}_${book.author}';
          final isSelected = _selectedBooks.contains(key);
          return _BookCoverItem(
            book: book,
            selectMode: _selectMode,
            isSelected: isSelected,
            onTap: () => _selectMode ? _toggleSelect(book) : _openBook(book),
            onLongPress: () => _selectMode ? _toggleSelect(book) : _showBookOptions(book),
          );
        },
        childCount: provider.filteredBooks.length,
      ),
    );
  }

  void _openBook(Book book) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingScreen(book: book)));
  }

  void _showBookOptions(Book book) {
    final key = '${book.name}_${book.author}';
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('书籍详情'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('更新书籍'),
              onTap: () {
                Navigator.pop(context);
                _updateSingleBook(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('移动分组'),
              onTap: () {
                Navigator.pop(context);
                _showMoveGroupDialog(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: const Text('多选'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectMode = true;
                  _selectedBooks.add(key);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirm(book);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateSingleBook(Book book) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('正在更新《${book.name}》...')));
    try {
      final service = AutoUpdateService();
      await service.updateBook(book);
      if (mounted) {
        await context.read<BookProvider>().loadBooks();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新完成')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    }
  }

  void _showMoveGroupDialog(Book book) {
    final controller = TextEditingController(text: book.group ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移动到分组'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入分组名称（留空为默认）'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              book.group = controller.text.trim().isEmpty ? null : controller.text.trim();
              await context.read<BookProvider>().updateBook(book);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除《${book.name}》吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<BookProvider>().removeBook(book.name, book.author);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('网络添加'),
              subtitle: const Text('通过书源搜索添加'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('本地添加'),
              subtitle: const Text('从本地文件导入 TXT/EPUB'),
              onTap: () {
                Navigator.pop(context);
                _importLocal();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// 列表项
class _BookListItem extends StatelessWidget {
  final Book book;
  final bool compact;
  final bool selectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookListItem({
    required this.book,
    required this.compact,
    required this.selectMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverW = compact ? 42.0 : 56.0;
    final coverH = compact ? 58.0 : 78.0;

    return Material(
      color: isSelected ? theme.colorScheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Row(
            children: [
              if (selectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                    size: 22,
                  ),
                ),
              // 封面带阴影
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                      ? Image.network(book.coverUrl!, width: coverW, height: coverH, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(coverW, coverH, book.name))
                      : _buildPlaceholder(coverW, coverH, book.name),
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: compact ? 14 : 16),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(book.author,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      if (book.lastChapter != null)
                        Text(book.lastChapter!,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              if (book.local)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: theme.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(4)),
                  child: Text('本地', style: theme.textTheme.labelSmall),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(double w, double h, String name) {
    final colors = [
      const Color(0xFFE3F2FD),
      const Color(0xFFF3E5F5),
      const Color(0xFFFFF3E0),
      const Color(0xFFE8F5E9),
      const Color(0xFFFFEBEE),
    ];
    final color = colors[name.hashCode % colors.length];
    return Container(
      width: w,
      height: h,
      color: color,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: TextStyle(fontSize: w * 0.4, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
      ),
    );
  }
}

// 网格项
class _BookGridItem extends StatelessWidget {
  final Book book;
  final bool compact;
  final bool selectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookGridItem({
    required this.book,
    required this.compact,
    required this.selectMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                        ? Image.network(book.coverUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildGridPlaceholder(book.name))
                        : _buildGridPlaceholder(book.name),
                  ),
                ),
              ),
              if (selectMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.5)),
                    child: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? theme.colorScheme.primary : Colors.white, size: compact ? 18 : 22),
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(book.name,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, fontSize: compact ? 11 : 12),
              maxLines: compact ? 1 : 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildGridPlaceholder(String name) {
    final colors = [
      const Color(0xFFE3F2FD),
      const Color(0xFFF3E5F5),
      const Color(0xFFFFF3E0),
      const Color(0xFFE8F5E9),
      const Color(0xFFFFEBEE),
    ];
    final color = colors[name.hashCode % colors.length];
    return Container(
      color: color,
      child: Center(
        child: Text(name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black54)),
      ),
    );
  }
}

// 封面网格项（纯封面，无文字）
class _BookCoverItem extends StatelessWidget {
  final Book book;
  final bool selectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookCoverItem({
    required this.book,
    required this.selectMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                  ? Image.network(book.coverUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                      errorBuilder: (_, __, ___) => _buildCoverPlaceholder(book.name))
                  : _buildCoverPlaceholder(book.name),
            ),
          ),
          if (selectMode)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.5)),
                child: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? theme.colorScheme.primary : Colors.white, size: 22),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder(String name) {
    final colors = [
      const Color(0xFFE3F2FD),
      const Color(0xFFF3E5F5),
      const Color(0xFFFFF3E0),
      const Color(0xFFE8F5E9),
      const Color(0xFFFFEBEE),
    ];
    final color = colors[name.hashCode % colors.length];
    return Container(
      color: color,
      child: Center(
        child: Text(name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black54)),
      ),
    );
  }
}
