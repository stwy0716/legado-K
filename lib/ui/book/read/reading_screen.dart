import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:legado_md3/data/model/bookmark.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:share_plus/share_plus.dart';
import 'package:legado_md3/data/model/book.dart';
import 'package:legado_md3/data/model/book_chapter.dart';
import 'package:legado_md3/ui/config/txt_toc_rule_screen.dart';
import 'package:legado_md3/data/model/read_config.dart';
import 'package:legado_md3/di/book_provider.dart';
import 'package:legado_md3/data/local/app_database.dart';
import 'package:legado_md3/help/source/source_engine.dart';
import 'package:legado_md3/help/source/replace_rule_service.dart';
import 'package:legado_md3/help/translate/translation_service.dart';
import 'package:legado_md3/help/readaloud/tts_service.dart';
import 'package:legado_md3/help/readaloud/reading_record.dart';
import 'package:legado_md3/data/model/book_source.dart';
import 'package:legado_md3/ui/book/read/config/reading_settings_screen.dart';
import 'package:legado_md3/ui/book/chapter/chapter_list_screen.dart';
import 'package:legado_md3/ui/config/replace_rule_screen.dart';
import 'package:legado_md3/ui/book/search/search_content_screen.dart';
import 'package:legado_md3/ui/book/read/widgets/download_sheet.dart';
import 'package:legado_md3/ui/book/read/widgets/change_chapter_source_sheet.dart';
import 'package:legado_md3/ui/book/read/tts_player_screen.dart';
import 'package:legado_md3/ui/book/detail/book_detail_screen.dart';

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
  List<int> _clickActions = [1,3,2,1,3,2,1,3,2];
  Future<void> _loadClickActions() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('click_actions');
    if (raw != null) {
      final l = raw.split(',').map((e)=>int.tryParse(e)??2).toList();
      if (l.length==9) _clickActions = l;
    }
  }
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
    _loadClickActions();
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

  void _nextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) _loadChapterContent(_currentChapterIndex + 1);
  }

  void _prevChapter() {
    if (_currentChapterIndex > 0) _loadChapterContent(_currentChapterIndex - 1);
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
                  final size = MediaQuery.of(context).size;
                  final col = details.globalPosition.dx < size.width / 3 ? 0 : (details.globalPosition.dx > size.width * 2 / 3 ? 2 : 1);
                  final row = details.globalPosition.dy < size.height / 3 ? 0 : (details.globalPosition.dy > size.height * 2 / 3 ? 2 : 1);
                  final action = _clickActions[row * 3 + col];
                  switch (action) {
                    case 1: _prevChapter(); break;
                    case 2: _nextChapter(); break;
                    case 3: _toggleMenu(); break;
                    case 4: _prevPage(); break;
                    case 5: _nextPage(); break;
                    default: break;
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
              leading: const Icon(Icons.list_alt),
              title: const Text('目录'),
              onTap: () { Navigator.pop(context); _showChapterList(); },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('搜索'),
              onTap: () { Navigator.pop(context); _showSearchInBook(); },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('翻译'),
              onTap: () { Navigator.pop(context); _showTranslateDialog(); },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('章节换源'),
              onTap: () async {
                Navigator.pop(context);
                final source = await showModalBottomSheet(
                  context: context, isScrollControlled: true,
                  builder: (_) => ChangeChapterSourceSheet(bookName: widget.book.name, author: widget.book.author),
                );
                if (source != null) {
                  widget.book.origin = source.bookSourceUrl;
                  widget.book.originName = source.bookSourceName;
                  _loadChapterContent(_currentChapterIndex);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('复制当前页'),
              onTap: () async {
                Navigator.pop(context);
                if (_chapters.isNotEmpty && _currentChapterIndex < _chapters.length) {
                  await Clipboard.setData(ClipboardData(text: _chapters[_currentChapterIndex].content ?? ''));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.subject),
              title: const Text('章节摘要'),
              onTap: () { Navigator.pop(context); _showChapterSummary(); },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('内容编辑'),
              onTap: () { Navigator.pop(context); _showContentEditor(); },
            ),
            ListTile(
              leading: const Icon(Icons.find_replace),
              title: const Text('生效替换'),
              onTap: () { Navigator.pop(context); _showReplaceRules(); },
            ),
            const Divider(),
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
              title: const Text('离线缓存'),
              onTap: () async {
                Navigator.pop(context);
                final range = await showModalBottomSheet<List<int>>(
                  context: context,
                  builder: (_) => DownloadSheet(chapters: _chapters, currentIndex: _currentChapterIndex),
                );
                if (range != null) _cacheChapters(range[0], range[1]);
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_vert),
              title: const Text('反转内容'),
              onTap: () { Navigator.pop(context); _reverseContent(); },
            ),
            ListTile(
              leading: const Icon(Icons.format_align_left),
              title: const Text('重新分段'),
              onTap: () { Navigator.pop(context); _reSegment(); },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('删除注音(ruby)'),
              onTap: () { Navigator.pop(context); _cleanContent('ruby'); },
            ),
            ListTile(
              leading: const Icon(Icons.title),
              title: const Text('删除标题标签'),
              onTap: () { Navigator.pop(context); _cleanContent('h'); },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('选择编码'),
              onTap: () { Navigator.pop(context); _selectCharset(); },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('TXT目录规则'),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtTocRuleScreen())); },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('调试日志'),
              onTap: () { Navigator.pop(context); _showDebugLog(); },
            ),
          ],
        ),
      ),
    );
  }

  /// 反转章节内容（每段倒序）
  void _reverseContent() {
    if (_content == null) return;
    final paras = _content!.split(RegExp(r'\n+'));
    setState(() {
      _content = paras.reversed.map((p) => p.split('').reversed.join()).join('\n\n');
      _paginateContent();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已反转内容')));
  }

  /// 重新分段：把粘连文本按句号/问号/叹号重新换行
  void _reSegment() {
    if (_content == null) return;
    var text = _content!.replaceAll(RegExp(r'\s+'), '');
    text = text.replaceAllMapped(RegExp(r'[。！？…](?!["”』」])'), (m) => '${m[0]}\n\n');
    setState(() {
      _content = text;
      _paginateContent();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已重新分段')));
  }

  /// 清理内容标签：ruby=注音标签，h=标题标签
  void _cleanContent(String type) {
    if (_content == null) return;
    var text = _content!;
    if (type == 'ruby') {
      text = text.replaceAll(RegExp(r'<ruby[^>]*>'), '').replaceAll(RegExp(r'</ruby>'), '').replaceAll(RegExp(r'<rt[^>]*>.*?</rt>', dotAll: true), '');
    } else {
      text = text.replaceAll(RegExp(r'<h[1-6][^>]*>'), '').replaceAll(RegExp(r'</h[1-6]>'), '');
    }
    setState(() {
      _content = text;
      _paginateContent();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(type == 'ruby' ? '已删除注音' : '已删除标题标签')));
  }

  void _selectCharset() {
    const charsets = ['UTF-8', 'GBK', 'GB2312', 'GB18030', 'Big5', 'ISO-8859-1'];
    showModalBottomSheet(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('选择编码', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      ...charsets.map((cs) => ListTile(title: Text(cs), onTap: () {
        Navigator.pop(c);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已选择 $cs，重新加载章节')));
        _loadChapterContent(_currentChapterIndex);
      })),
    ])));
  }

  void _showDebugLog() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('调试日志'),
      content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: const [
        ListTile(dense: true, leading: Icon(Icons.info_outline, size: 18), title: Text('章节加载/解析日志', style: TextStyle(fontSize: 12))),
        ListTile(dense: true, leading: Icon(Icons.check_circle_outline, size: 18), title: Text('书源引擎运行正常', style: TextStyle(fontSize: 12))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('关闭'))],
    ));
  }

  Future<void> _cacheChapters(int start, int end) async {
    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无章节可缓存')));
      return;
    }
    final total = end - start + 1;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('开始缓存 $total 章...')));
    int cached = 0;
    for (int i = start; i <= end && i < _chapters.length; i++) {
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
    await _db.addBookmark(Bookmark.fromMap(bookmark));
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
                      subtitle: Text('第 ${(bm.pageIndex as int? ?? 0) + 1} 页'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await _db.deleteBookmark(bm.id!);
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

  void _showChapterList() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChapterListScreen(book: widget.book, chapters: _chapters, currentIndex: _currentChapterIndex)));
  }

  Future<void> _showSearchInBook() async {
    final chapterIndex = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => SearchContentScreen(book: widget.book)));
    if (chapterIndex != null) _loadChapterContent(chapterIndex);
  }

  Future<void> _showTranslateDialog() async {
    final p = await SharedPreferences.getInstance();
    bool auto = p.getBool('translate_enabled') ?? false;
    const langs = ['zh-CN','zh-TW','en','ja','ko','fr','de','es','ru'];
    const names = {'zh-CN':'简体中文','zh-TW':'繁体中文','en':'英语','ja':'日语','ko':'韩语','fr':'法语','de':'德语','es':'西班牙语','ru':'俄语'};
    String target = p.getString('tr_target') ?? 'zh-CN';
    if (!mounted) return;
    await showDialog(context: context, builder: (dctx) => StatefulBuilder(builder: (dctx, setD) => AlertDialog(
      title: const Text('翻译设置'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(
          title: const Text('本章自动翻译'),
          value: auto,
          onChanged: (v) async { await p.setBool('translate_enabled', v); await TranslationService.instance.loadPrefs(); setD(() => auto = v); },
        ),
        ListTile(
          leading: const Icon(Icons.swap_horiz), title: const Text('目标语言'),
          trailing: DropdownButton<String>(value: target, items: langs.map((l) => DropdownMenuItem(value: l, child: Text(names[l] ?? l))).toList(),
            onChanged: (v) async { await p.setString('tr_target', v ?? 'zh-CN'); await TranslationService.instance.loadPrefs(); setD(() => target = v ?? 'zh-CN'); }),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('关闭')),
        FilledButton(onPressed: () async { Navigator.pop(dctx); await _translateCurrentChapter(); }, child: const Text('立即翻译本章')),
      ],
    )));
  }

  Future<void> _translateCurrentChapter() async {
    if ((_content ?? '').isEmpty) return;
    await TranslationService.instance.loadPrefs();
    if (mounted) setState(() => _isLoadingChapter = true);
    final translated = await TranslationService.instance.translateParagraphs(_content!);
    if (mounted) setState(() { _content = translated; _paginateContent(); _isLoadingChapter = false; });
  }

  void _showChapterSummary() {
    final summary = _chapters.isNotEmpty && _currentChapterIndex < _chapters.length ? _chapters[_currentChapterIndex].title : '无';
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('章节摘要'),
      content: Text('当前章节: $summary\n\n共${_chapters.length}章\n当前第${_currentChapterIndex + 1}章'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
    ));
  }

  void _showContentEditor() {
    final controller = TextEditingController(text: _chapters.isNotEmpty ? _chapters[_currentChapterIndex].content : null ?? '');
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('内容编辑'),
      content: SizedBox(width: double.maxFinite, child: TextField(controller: controller, maxLines: 10, decoration: const InputDecoration(border: OutlineInputBorder()))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () async {
          if (_chapters.isNotEmpty && _currentChapterIndex < _chapters.length) {
            _chapters[_currentChapterIndex].content = controller.text;
            await _db.saveChapters(widget.book.name, widget.book.author, _chapters);
            if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('内容已保存'))); }
          }
          Navigator.pop(context);
        }, child: const Text('保存')),
      ],
    ));
  }

  Future<void> _showReplaceRules() async {
    final all = await _db.getReplaceRules();
    final enabled = all.where((r) => r.enable).toList();
    final scopeForBook = enabled.where((r) => r.scope == null || r.scope!.isEmpty || r.scope == 'all' || r.scope == widget.book.origin || (r.scope ?? '').contains(widget.book.name)).toList();
    if (!mounted) return;
    showDialog(context: context, builder: (d) => AlertDialog(
      title: const Text('生效替换规则'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.rule), title: const Text('全局替换规则'),
          subtitle: Text('${enabled.length} 条已启用'), trailing: const Icon(Icons.chevron_right),
          onTap: () { Navigator.pop(d); Navigator.push(context, MaterialPageRoute(builder: (_) => const ReplaceRuleScreen())); },
        ),
        ListTile(
          leading: const Icon(Icons.rule_folder), title: const Text('本书生效规则'),
          subtitle: Text('${scopeForBook.length} 条对本书生效'),
        ),
        if ((_content ?? '').isNotEmpty) ListTile(
          leading: const Icon(Icons.preview), title: const Text('预览当前章节替换效果'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            Navigator.pop(d);
            final svc = ReplaceRuleService();
            final preview = svc.applyRules(_content!, enabled, scope: widget.book.origin);
            if (!mounted) return;
            showDialog(context: context, builder: (p) => AlertDialog(
              title: const Text('替换预览'),
              content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Text(preview, style: const TextStyle(fontSize: 13)))),
              actions: [TextButton(onPressed: () => Navigator.pop(p), child: const Text('关闭'))],
            ));
          },
        ),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('关闭'))],
    ));
  }

  void _showReadingSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadingSettingsScreen()));
  }

  Future<void> _startTTS() async {
    // 注入按需加载器：朗读到未缓存章节时自动联网取正文
    _ttsService.contentLoader = (index) async {
      if (index < 0 || index >= _chapters.length) return null;
      final ch = _chapters[index];
      if ((ch.content ?? '').isNotEmpty) return ch.content;
      if (widget.book.origin == null) return null;
      final sources = await _db.getAllSources(enabled: true);
      final source = sources.where((s) => s.bookSourceUrl == widget.book.origin).firstOrNull;
      if (source == null || ch.url.isEmpty) return null;
      final rules = await _db.getReplaceRules();
      final content = await _engine.getContent(source, ch.url, replaceRules: rules);
      if (content != null && content.isNotEmpty) {
        await _db.updateChapterContent(widget.book.name, widget.book.author, ch.index, content);
        ch.content = content;
      }
      return content;
    };
    _ttsService.setChapters(_chapters, startIndex: _currentChapterIndex);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => TtsPlayerScreen(
      ttsService: _ttsService,
      chapters: _chapters,
      currentIndex: _currentChapterIndex,
      bookName: widget.book.name,
    )));
  }
}