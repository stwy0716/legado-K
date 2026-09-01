import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:legado_md3/data/model/book.dart';
import 'package:legado_md3/data/model/read_record.dart';
import 'package:legado_md3/di/book_provider.dart';
import 'package:legado_md3/data/local/app_database.dart';
import 'package:legado_md3/help/readaloud/reading_record.dart';
import 'package:legado_md3/ui/book/search/search_screen.dart';
import 'package:legado_md3/ui/book/read/reading_screen.dart';
import 'package:legado_md3/ui/book/detail/book_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  List<Book> _recentBooks = [];
  List<ReadRecord> _readRecords = [];
  int _todayMinutes = 0;
  int _totalMinutes = 0;
  int _readingDays = 0;
  int _dailyGoal = 30;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _dailyGoal = prefs.getInt('daily_goal') ?? 30;

    // 加载最近阅读的书籍
    final books = await _db.getAllBooks();
    _recentBooks = books.where((b) => (b.durChapterTime ?? 0) > 0).toList()
      ..sort((a, b) => (b.durChapterTime ?? 0).compareTo(a.durChapterTime ?? 0));
    if (_recentBooks.length > 6) _recentBooks = _recentBooks.sublist(0, 6);

    // 加载阅读记录
    _readRecords = await _db.getReadRecords(50);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayMs = today.millisecondsSinceEpoch;

    for (final r in _readRecords) {
      final duration = (r.duration as int?) ?? 0;
      _totalMinutes += duration ~/ 60000;
      final readDate = r.date as int?;
      if (readDate != null && readDate >= todayMs) {
        _todayMinutes += duration ~/ 60000;
      }
    }

    // 计算阅读天数
    final days = <String>{};
    for (final r in _readRecords) {
      final readDate = r.date as int?;
      if (readDate != null) {
        final d = DateTime.fromMillisecondsSinceEpoch(readDate);
        days.add('${d.year}-${d.month}-${d.day}');
      }
    }
    _readingDays = days.length;

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 搜索栏
                  _buildSearchBar(),
                  const SizedBox(height: 16),

                  // 阅读目标卡片
                  _buildReadingGoalCard(),
                  const SizedBox(height: 16),

                  // 最近阅读
                  if (_recentBooks.isNotEmpty) ...[
                    _buildSectionHeader('最近阅读', onMore: () {}),
                    const SizedBox(height: 8),
                    _buildRecentBooks(),
                    const SizedBox(height: 16),
                  ],

                  // 阅读统计
                  _buildSectionHeader('阅读统计'),
                  const SizedBox(height: 8),
                  _buildStatsGrid(),
                  const SizedBox(height: 16),

                  // 快捷功能
                  _buildSectionHeader('快捷功能'),
                  const SizedBox(height: 8),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Text('搜索书籍、作者...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingGoalCard() {
    final progress = _dailyGoal > 0 ? (_todayMinutes / _dailyGoal).clamp(0.0, 1.0) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('今日阅读', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('$_todayMinutes / $_dailyGoal 分钟', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progress >= 1.0 ? '已完成今日目标！' : '还差 ${_dailyGoal - _todayMinutes} 分钟完成目标',
              style: TextStyle(fontSize: 12, color: progress >= 1.0 ? Colors.green : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onMore}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        if (onMore != null) TextButton(onPressed: onMore, child: const Text('更多')),
      ],
    );
  }

  Widget _buildRecentBooks() {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _recentBooks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final book = _recentBooks[index];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingScreen(book: book))),
            onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book))),
            child: SizedBox(
              width: 100,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                        ? Image.network(book.coverUrl!, width: 100, height: 130, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildDefaultCover(book))
                        : _buildDefaultCover(book),
                  ),
                  const SizedBox(height: 6),
                  Text(book.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDefaultCover(Book book) {
    final colors = [Colors.blueGrey, Colors.brown, Colors.teal, Colors.indigo, Colors.deepOrange, Colors.purple];
    final color = colors[book.name.hashCode.abs() % colors.length];
    return Container(
      width: 100,
      height: 130,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Center(child: Padding(padding: const EdgeInsets.all(8), child: Text(book.name, maxLines: 3, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
    );
  }

  Widget _buildStatsGrid() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _buildStatItem('今日阅读', '$_todayMinutes分钟', Icons.today)),
            Expanded(child: _buildStatItem('累计阅读', '${_totalMinutes ~/ 60}小时', Icons.menu_book)),
            Expanded(child: _buildStatItem('阅读天数', '$_readingDays天', Icons.calendar_today)),
            Expanded(child: _buildStatItem('在读书籍', '${_recentBooks.length}本', Icons.library_books)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.folder_open, 'label': '本地导入', 'color': Colors.blue},
      {'icon': Icons.cloud_download, 'label': '网络导入', 'color': Colors.green},
      {'icon': Icons.backup_outlined, 'label': '备份恢复', 'color': Colors.orange},
      {'icon': Icons.cleaning_services_outlined, 'label': '缓存管理', 'color': Colors.purple},
      {'icon': Icons.bookmark_border, 'label': '书签管理', 'color': Colors.red},
      {'icon': Icons.find_replace_outlined, 'label': '替换净化', 'color': Colors.teal},
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 16, crossAxisSpacing: 16),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return GestureDetector(
              onTap: () => _handleQuickAction(action['label'] as String),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: (action['color'] as Color).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: Icon(action['icon'] as IconData, color: action['color'] as Color),
                  ),
                  const SizedBox(height: 6),
                  Text(action['label'] as String, style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleQuickAction(String label) {
    switch (label) {
      case '本地导入':
        Navigator.pushNamed(context, '/local_import');
        break;
      case '网络导入':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络导入功能')));
        break;
      case '备份恢复':
        Navigator.pushNamed(context, '/backup');
        break;
      case '缓存管理':
        Navigator.pushNamed(context, '/cache');
        break;
      case '书签管理':
        Navigator.pushNamed(context, '/bookmark');
        break;
      case '替换净化':
        Navigator.pushNamed(context, '/replace');
        break;
    }
  }
}
