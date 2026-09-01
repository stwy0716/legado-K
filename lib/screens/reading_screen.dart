import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:share_plus/share_plus.dart';
import '../models/book.dart';
import '../models/book_chapter.dart';
import '../models/read_config.dart';
import '../providers/book_provider.dart';
import '../services/database_service.dart';
import '../services/book_source_engine.dart';
import '../services/tts_service.dart';
import '../services/reading_record_service.dart';
import '../models/book_source.dart';
import 'chapter_list_screen.dart';
import 'tts_player_screen.dart';
import 'book_detail_screen.dart';

class ReadingScreen extends StatefulWidget {
  final Book book;
  final int? initialChapter;
  const ReadingScreen({super.key, required this.book, this.initialChapter});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final BookSourceEngine _engine = BookSourceEngine();
  final TtsService _ttsService = TtsService();
  final ReadingRecordService _recordService = ReadingRecordService();
  List<BookChapter> _chapters = [];
  int _currentChapterIndex = 0;
  String? _content;
  bool _isLoading = true;
  bool _isLoadingChapter = false;
  late AnimationController _menuController;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<String> _pages = [];

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _currentChapterIndex = widget.initialChapter ?? widget.book.durChapterIndex ?? 0;
    _recordService.startSession(widget.book.name, widget.book.author);
    _ttsService.init();
    _loadData();
  }

  @override
  void dispose() {
    _menuController.dispose();
    _pageController.dispose();
    _recordService.endSession(
      chapterIndex: _currentChapterIndex,
      chapterTitle: _chapters.isNotEmpty ? _chapters[_currentChapterIndex].title : null,
    );
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _chapters = await _db.getChapters(widget.book.name, widget.book.author);

    if (_chapters.isEmpty && widget.book.origin != null) {
      // 尝试从网络获取目录
      await _fetchTocFromNetwork();
    }

    if (_chapters.isNotEmpty) {
      if (_currentChapterIndex >= _chapters.length) _currentChapterIndex = 0;
      await _loadChapterContent(_currentChapterIndex);
    } else {
      // 没有章节，显示书籍信息
      _content = widget.book.intro ?? '暂无内容';
      _pages = [_content!];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchTocFromNetwork() async {
    try {
      final sources = await _db.getAllSources(enabled: true);
      final source = sources.where((s) => s.bookSourceUrl == widget.book.origin).firstOrNull;
      if (source != null && widget.book.noteUrl != null) {
        final chapters = await _engine.getToc(source, widget.book.noteUrl!);
        if (chapters.isNotEmpty) {
          _chapters = chapters;
          await _db.saveChapters(widget.book.name, widget.book.author, chapters);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadChapterContent(int index) async {
    if (index < 0 || index >= _chapters.length) return;
    setState(() => _isLoadingChapter = true);

    final chapter = _chapters[index];
    // 先尝试从数据库读取缓存
    final cachedChapters = await _db.getChapters(widget.book.name, widget.book.author);
    if (index < cachedChapters.length && cachedChapters[index].content != null) {
      _content = cachedChapters[index].content;
    } else if (widget.book.origin != null) {
      // 从网络获取
      try {
        final sources = await _db.getAllSources(enabled: true);
        final source = sources.where((s) => s.bookSourceUrl == widget.book.origin).firstOrNull;
        if (source != null && chapter.url.isNotEmpty) {
          // 加载替换净化规则
          final replaceRules = await _db.getReplaceRules();
          final content = await _engine.getContent(source, chapter.url, replaceRules: replaceRules);
          if (content != null) {
            _content = content;
            await _db.updateChapterContent(widget.book.name, widget.book.author, index, content);
          }
        }
      } catch (_) {
        _content = '加载失败，请检查网络';
      }
    } else {
      _content = chapter.content ?? '暂无内容';
    }

    _paginateContent();
    _currentChapterIndex = index;
    // 保存阅读进度
    final provider = Provider.of<BookProvider>(context, listen: false);
    await provider.saveReadingProgress(widget.book, index, 0);

    if (mounted) setState(() => _isLoadingChapter = false);
  }

  void _paginateContent() {
    if (_content == null || _content!.isEmpty) {
      _pages = ['暂无内容'];
      return;
    }
    // 简单分页：按段落分割，每页约 800 字
    final paragraphs = _content!.split(RegExp(r'\n+'));
    final List<String> pages = [];
    StringBuffer currentPage = StringBuffer();
    int charCount = 0;

    for (final para in paragraphs) {
      if (charCount + para.length > 800 && currentPage.isNotEmpty) {
        pages.add(currentPage.toString());
        currentPage = StringBuffer();
        charCount = 0;
      }
      currentPage.writeln(para);
      charCount += para.length + 1;
    }
    if (currentPage.isNotEmpty) pages.add(currentPage.toString());
    _pages = pages.isEmpty ? [_content!] : pages;
    _currentPage = 0;
    // 修复：PageView跳转到第一页
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  void _toggleMenu() {
    if (_menuController.isDismissed) {
      _menuController.forward();
    } else {
      _menuController.reverse();
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      setState(() => _currentPage++);
    } else if (_currentChapterIndex < _chapters.length - 1) {
      _loadChapterContent(_currentChapterIndex + 1);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
    } else if (_currentChapterIndex > 0) {
      _loadChapterContent(_currentChapterIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readProvider = context.watch<ReadProvider>();
    final config = readProvider.config;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Color(config.bgColor),
        statusBarIconBrightness: ThemeData.estimateBrightnessForColor(Color(config.bgColor)) == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Color(config.bgColor),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: Color(config.textColor)))
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final width = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx < width / 3) {
                    _prevPage();
                  } else if (details.globalPosition.dx > width * 2 / 3) {
                    _nextPage();
                  } else {
                    _toggleMenu();
                  }
                },
                child: Stack(
                  children: [
                    Column(
                      children: [
                        if (config.statusBarVisibility)
                          SizedBox(height: MediaQuery.of(context).padding.top),
                        if (config.titleVisibility)
                          _buildHeader(config),
                        Expanded(
                          child: _isLoadingChapter
                              ? Center(child: CircularProgressIndicator(color: Color(config.textColor)))
                              : _buildReadingContent(config),
                        ),
                        if (config.pageNumberVisibility || config.timeVisibility)
                          _buildFooter(config),
                        SizedBox(height: MediaQuery.of(context).padding.bottom),
                      ],
                    ),
                    _buildTopMenu(),
                    _buildBottomMenu(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(ReadConfig config) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: config.paddingLeft.toDouble(),
        vertical: 4,
      ),
      height: config.headerHeight.toDouble(),
      alignment: config.headerAlignCenter ? Alignment.center : Alignment.centerLeft,
      child: Text(
        _chapters.isNotEmpty ? _chapters[_currentChapterIndex].title : widget.book.name,
        style: TextStyle(
          fontSize: config.headerSize.toDouble(),
          color: Color(config.headerColor),
          fontWeight: config.headerBold ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildReadingContent(ReadConfig config) {
    return PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: (page) => setState(() => _currentPage = page),
      itemBuilder: (context, index) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            config.paddingLeft.toDouble(),
            config.paddingTop.toDouble(),
            config.paddingRight.toDouble(),
            config.paddingBottom.toDouble(),
          ),
          child: Text(
            _pages[index],
            style: TextStyle(
              fontSize: config.textSize.toDouble(),
              color: Color(config.textColor),
              height: config.lineSpacing * 0.5 + 1.0,
              fontWeight: config.boldText ? FontWeight.bold : FontWeight.normal,
              fontFamily: config.fontFamily,
            ),
            textAlign: config.textAlign == 1
                ? TextAlign.center
                : config.textAlign == 2
                    ? TextAlign.justify
                    : TextAlign.left,
          ),
        );
      },
    );
  }

  Widget _buildFooter(ReadConfig config) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: config.paddingLeft.toDouble(),
        vertical: 4,
      ),
      height: config.footerHeight.toDouble(),
      child: Row(
        mainAxisAlignment: config.footerAlignCenter ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
        children: [
          if (config.timeVisibility)
            Text(
              _formatTime(DateTime.now()),
              style: TextStyle(
                fontSize: config.footerSize.toDouble(),
                color: Color(config.footerColor),
              ),
            ),
          if (config.pageNumberVisibility && _pages.length > 1)
            Text(
              '${_currentPage + 1}/${_pages.length}',
              style: TextStyle(
                fontSize: config.footerSize.toDouble(),
                color: Color(config.footerColor),
              ),
            ),
          if (config.batteryVisibility)
            Icon(Icons.battery_full, size: 14, color: Color(config.footerColor)),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTopMenu() {
    return AnimatedBuilder(
      animation: _menuController,
      builder: (context, child) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(0, -(1 - _menuController.value) * 120),
            child: Opacity(
              opacity: _menuController.value,
              child: child,
            ),
          ),
        );
      },
      child: AppBar(
        title: Text(widget.book.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () async {
              _menuController.reverse();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChapterListScreen(
                    chapters: _chapters,
                    currentIndex: _currentChapterIndex,
                  ),
                ),
              );
              if (result != null && result is int) {
                _loadChapterContent(result);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreMenu(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomMenu() {
    return AnimatedBuilder(
      animation: _menuController,
      builder: (context, child) {
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(0, (1 - _menuController.value) * 500),
            child: Opacity(
              opacity: _menuController.value,
              child: IgnorePointer(
                ignoring: _menuController.value < 0.5,
                child: child,
              ),
            ),
          ),
        );
      },
      child: _buildReadingSettingsPanel(),
    );
  }

  Widget _buildReadingSettingsPanel() {
    final readProvider = context.read<ReadProvider>();
    final config = readProvider.config;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: _currentChapterIndex > 0 ? () => _loadChapterContent(_currentChapterIndex - 1) : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: _chapters.length <= 1 ? 0 : _currentChapterIndex / (_chapters.length - 1),
                      onChanged: _chapters.length <= 1
                          ? null
                          : (value) {
                              final index = (value * (_chapters.length - 1)).round();
                              _loadChapterContent(index);
                            },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: _currentChapterIndex < _chapters.length - 1
                        ? () => _loadChapterContent(_currentChapterIndex + 1)
                        : null,
                  ),
                ],
              ),
            ),
            // 字号和行距
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('字号'),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => readProvider.setTextSize(config.textSize - 1),
                  ),
                  Text('${config.textSize}'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => readProvider.setTextSize(config.textSize + 1),
                  ),
                  const Spacer(),
                  const Text('行距'),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => readProvider.setLineSpacing(config.lineSpacing - 1),
                  ),
                  Text('${config.lineSpacing}'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => readProvider.setLineSpacing(config.lineSpacing + 1),
                  ),
                ],
              ),
            ),
            // 背景色选择
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: ReadConfig.presets.length,
                itemBuilder: (context, index) {
                  final preset = ReadConfig.presets[index];
                  final isSelected = config.bgColor == preset['bg'];
                  return GestureDetector(
                    onTap: () {
                      readProvider.setBgColor(preset['bg'] as int);
                      readProvider.setTextColor(preset['text'] as int);
                    },
                    child: Container(
                      width: 56,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Color(preset['bg'] as int),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          preset['name'] as String,
                          style: TextStyle(
                            color: Color(preset['text'] as int),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // 底部操作按钮
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomAction(Icons.font_download, '字体', () => _showFontPicker()),
                  _buildBottomAction(Icons.animation, '翻页', () => _showPageAnimPicker()),
                  _buildBottomAction(Icons.brightness_6, '亮度', () => _showBrightnessSlider()),
                  _buildBottomAction(Icons.settings, '设置', () => _showReadingSettings()),
                  _buildBottomAction(Icons.headphones, '朗读', () => _startTTS()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu() {
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
                Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: widget.book)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('刷新目录'),
              onTap: () {
                Navigator.pop(context);
                _fetchTocFromNetwork();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('缓存全部章节'),
              onTap: () {
                Navigator.pop(context);
                _cacheAllChapters();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('添加书签'),
              onTap: () {
                Navigator.pop(context);
                _addBookmark();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmarks),
              title: const Text('书签列表'),
              onTap: () {
                Navigator.pop(context);
                _showBookmarks();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享书籍'),
              onTap: () {
                Navigator.pop(context);
                Share.share('《${widget.book.name}》- ${widget.book.author}');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cacheAllChapters() async {
    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无章节可缓存')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('开始缓存 ${_chapters.length} 章...')));
    int cached = 0;
    for (int i = 0; i < _chapters.length; i++) {
      final chapter = _chapters[i];
      // 检查是否已有缓存
      final cachedChapters = await _db.getChapters(widget.book.name, widget.book.author);
      if (i < cachedChapters.length && cachedChapters[i].content != null && cachedChapters[i].content!.isNotEmpty) {
        cached++;
        continue;
      }
      // 从网络获取
      if (widget.book.origin != null && chapter.url.isNotEmpty && !chapter.url.startsWith('local_')) {
        try {
          final sources = await _db.getAllSources(enabled: true);
          final source = sources.where((s) => s.bookSourceUrl == widget.book.origin).firstOrNull;
          if (source != null) {
            final replaceRules = await _db.getReplaceRules();
            final content = await _engine.getContent(source, chapter.url, replaceRules: replaceRules);
            if (content != null) {
              await _db.updateChapterContent(widget.book.name, widget.book.author, i, content);
              cached++;
            }
          }
        } catch (_) {}
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('缓存完成，共 $cached 章')));
    }
  }

  Future<void> _addBookmark() async {
    final currentPage = _pageController.hasClients ? _pageController.page?.round() ?? 0 : 0;
    final bookmark = {
      'bookName': widget.book.name,
      'bookAuthor': widget.book.author,
      'chapterIndex': _currentChapterIndex,
      'chapterTitle': _chapters.isNotEmpty ? _chapters[_currentChapterIndex].title : '',
      'pageIndex': currentPage,
      'content': _pages.isNotEmpty ? _pages[currentPage.clamp(0, _pages.length - 1)].substring(0, _pages[currentPage.clamp(0, _pages.length - 1)].length > 50 ? 50 : _pages[currentPage.clamp(0, _pages.length - 1)].length) : '',
      'createTime': DateTime.now().millisecondsSinceEpoch,
    };
    await _db.addBookmark(bookmark);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已添加书签')));
    }
  }

  Future<void> _showBookmarks() async {
    final bookmarks = await _db.getBookmarks(widget.book.name, widget.book.author);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('书签列表', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (bookmarks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('暂无书签', style: TextStyle(color: Colors.grey)),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final bm = bookmarks[index];
                    return ListTile(
                      leading: const Icon(Icons.bookmark),
                      title: Text(bm.chapterTitle?.toString() ?? '第${bm.chapterIndex}章'),
                      subtitle: Text('第 ${(bm['pageIndex'] as int? ?? 0) + 1} 页'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await _db.deleteBookmark(bm['id'] as int);
                          Navigator.pop(context);
                          _showBookmarks();
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        final chIndex = bm.chapterIndex as int? ?? 0;
                        if (chIndex != _currentChapterIndex) {
                          _loadChapterContent(chIndex);
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFontPicker() {
    final readProvider = context.read<ReadProvider>();
    final fonts = ['系统默认', 'serif', 'sans-serif', 'monospace', 'cursive'];
    final fontNames = ['系统默认', '衬线体', '无衬线体', '等宽字体', '手写体'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择字体'),
        content: Column(mainAxisSize: MainAxisSize.min, children: List.generate(fonts.length, (index) => RadioListTile<String>(
          title: Text(fontNames[index], style: index == 0 ? null : TextStyle(fontFamily: fonts[index])),
          value: fonts[index],
          groupValue: readProvider.config.fontFamily ?? '系统默认',
          onChanged: (value) {
            if (value != null) readProvider.updateConfig((c) => c.fontFamily = value == '系统默认' ? null : value);
            Navigator.pop(context);
          },
        ))),
      ),
    );
  }

  void _showPageAnimPicker() {
    final readProvider = context.read<ReadProvider>();
    final anims = ['覆盖', '仿真', '滑动', '滚动', '无动画', '上下'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('翻页动画'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(anims.length, (index) {
            return RadioListTile<int>(
              title: Text(anims[index]),
              value: index,
              groupValue: readProvider.config.pageAnim,
              onChanged: (value) {
                if (value != null) readProvider.setPageAnim(value);
                Navigator.pop(context);
              },
            );
          }),
        ),
      ),
    );
  }

  void _showBrightnessSlider() {
    final readProvider = context.read<ReadProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('亮度调节'),
        content: StatefulBuilder(
          builder: (context, setState) => Slider(
            value: readProvider.brightness,
            onChanged: (value) {
              readProvider.setBrightness(value);
              setState(() {});
            },
          ),
        ),
      ),
    );
  }

  void _showReadingSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('阅读设置'),
              trailing: const Icon(Icons.close),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('音量键翻页'),
              value: context.read<ReadProvider>().config.volumeKeyPage,
              onChanged: (value) => context.read<ReadProvider>().updateConfig((c) => c.volumeKeyPage = value),
            ),
            SwitchListTile(
              title: const Text('保持屏幕常亮'),
              value: context.read<ReadProvider>().config.keepScreenOn,
              onChanged: (value) => context.read<ReadProvider>().updateConfig((c) => c.keepScreenOn = value),
            ),
            SwitchListTile(
              title: const Text('显示状态栏'),
              value: context.read<ReadProvider>().config.statusBarVisibility,
              onChanged: (value) => context.read<ReadProvider>().updateConfig((c) => c.statusBarVisibility = value),
            ),
            SwitchListTile(
              title: const Text('显示标题'),
              value: context.read<ReadProvider>().config.titleVisibility,
              onChanged: (value) => context.read<ReadProvider>().updateConfig((c) => c.titleVisibility = value),
            ),
            SwitchListTile(
              title: const Text('显示时间'),
              value: context.read<ReadProvider>().config.timeVisibility,
              onChanged: (value) => context.read<ReadProvider>().updateConfig((c) => c.timeVisibility = value),
            ),
            SwitchListTile(
              title: const Text('显示页码'),
              value: context.read<ReadProvider>().config.pageNumberVisibility,
              onChanged: (value) => context.read<ReadProvider>().updateConfig((c) => c.pageNumberVisibility = value),
            ),
            SwitchListTile(
              title: const Text('自动翻页'),
              value: context.read<ReadProvider>().config.autoNextPage,
              onChanged: (value) => context.read<ReadProvider>().updateConfig((c) => c.autoNextPage = value),
            ),
            SwitchListTile(
              title: const Text('粗体文字'),
              value: context.read<ReadProvider>().config.boldText,
              onChanged: (value) => context.read<ReadProvider>().updateConfig((c) => c.boldText = value),
            ),
            ListTile(
              title: const Text('对齐方式'),
              trailing: DropdownButton<int>(
                value: context.watch<ReadProvider>().config.textAlign,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('左对齐')),
                  DropdownMenuItem(value: 1, child: Text('居中')),
                  DropdownMenuItem(value: 2, child: Text('两端对齐')),
                ],
                onChanged: (v) => context.read<ReadProvider>().updateConfig((c) => c.textAlign = v ?? 2),
              ),
            ),
            ListTile(
              title: const Text('首行缩进'),
              trailing: DropdownButton<int>(
                value: context.watch<ReadProvider>().config.textIndent,
                items: List.generate(5, (i) => DropdownMenuItem(value: i, child: Text('${i * 2}字符'))),
                onChanged: (v) => context.read<ReadProvider>().updateConfig((c) => c.textIndent = v ?? 2),
              ),
            ),
            ListTile(
              title: const Text('段间距'),
              trailing: DropdownButton<int>(
                value: context.watch<ReadProvider>().config.paragraphSpacing,
                items: List.generate(5, (i) => DropdownMenuItem(value: i, child: Text('$i行'))),
                onChanged: (v) => context.read<ReadProvider>().updateConfig((c) => c.paragraphSpacing = v ?? 1),
              ),
            ),
            SwitchListTile(
              title: const Text('护眼模式'),
              subtitle: const Text('暖色调屏幕'),
              value: context.watch<ReadProvider>().config.eyeProtection,
              onChanged: (value) => context.read<ReadProvider>().updateConfig((c) => c.eyeProtection = value),
            ),
            SwitchListTile(
              title: const Text('显示电量'),
              value: context.watch<ReadProvider>().config.batteryVisibility,
              onChanged: (value) => context.read<ReadProvider>().updateConfig((c) => c.batteryVisibility = value),
            ),
            ListTile(
              title: const Text('点击区域'),
              subtitle: const Text('点击左右两侧翻页，中间显示菜单'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _startTTS() {
    _ttsService.setChapters(_chapters, startIndex: _currentChapterIndex);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TtsPlayerScreen(
          ttsService: _ttsService,
          chapters: _chapters,
          currentIndex: _currentChapterIndex,
          bookName: widget.book.name,
        ),
      ),
    );
  }
}
