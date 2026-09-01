import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../models/book.dart';
import '../models/book_chapter.dart';
import '../models/book_source.dart';
import '../models/book_group.dart';
import '../models/book_knowledge.dart';
import '../models/book_progress.dart';
import '../models/book_marking.dart';
import '../models/bookmark.dart';
import '../models/cache.dart';
import '../models/cloud_tts_engine.dart';
import '../models/cookie.dart';
import '../models/dict_rule.dart';
import '../models/highlight_rule.dart';
import '../models/highlight_tag_rule.dart';
import '../models/http_tts.dart';
import '../models/read_record.dart';
import '../models/replace_rule.dart' hide ReadRecord;
import '../models/rss_source.dart';
import '../models/rss_article.dart';
import '../models/rss_star.dart';
import '../models/rule_sub.dart';
import '../models/search_content_history.dart';
import '../models/server.dart';
import '../models/tag_group_rule.dart';
import '../models/translation_cache.dart';
import '../models/txt_toc_rule.dart';
import '../models/keyboard_assist.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;
  static const int _dbVersion = 4;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, 'legado_md3.db');
    return openDatabase(fullPath, version: _dbVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _onCreate(db, newVersion);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('CREATE TABLE IF NOT EXISTS books (name TEXT NOT NULL, author TEXT NOT NULL, origin TEXT, originName TEXT, bookUrl TEXT, coverUrl TEXT, customCoverUrl TEXT, intro TEXT, kind TEXT, latestChapterTitle TEXT, lastChapterTime INTEGER, updateTime INTEGER, lastCheckTime INTEGER, "order" INTEGER, groupId INTEGER, PRIMARY KEY (name, author))');
    await db.execute('CREATE TABLE IF NOT EXISTS book_chapters (bookName TEXT NOT NULL, bookAuthor TEXT NOT NULL, "index" INTEGER NOT NULL, title TEXT, url TEXT, baseUrl TEXT, isVolume INTEGER DEFAULT 0, isPay INTEGER DEFAULT 0, tag TEXT, resourceUrl TEXT, content TEXT, PRIMARY KEY (bookName, bookAuthor, "index"))');
    await db.execute('CREATE TABLE IF NOT EXISTS book_sources (bookSourceUrl TEXT PRIMARY KEY, bookSourceName TEXT, bookSourceGroup TEXT, bookSourceType INTEGER, bookSourceComment TEXT, lastUpdateTime INTEGER, enabled INTEGER DEFAULT 1, enabledExplore INTEGER DEFAULT 1, customOrder INTEGER, respondTime INTEGER, weight INTEGER, header TEXT, loginUrl TEXT, bookUrlPattern TEXT, charset TEXT, searchUrl TEXT, exploreUrl TEXT, ruleSearch TEXT, ruleExplore TEXT, ruleBookInfo TEXT, ruleToc TEXT, ruleContent TEXT, ruleReview TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS book_groups (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, "order" INTEGER, show INTEGER DEFAULT 1, cover TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS book_knowledge (id INTEGER PRIMARY KEY AUTOINCREMENT, bookName TEXT, author TEXT, type TEXT, name TEXT, content TEXT, cover TEXT, "order" INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS book_progress (id INTEGER PRIMARY KEY AUTOINCREMENT, bookName TEXT, author TEXT, chapterIndex INTEGER, pagePos INTEGER, duration INTEGER, lastReadTime INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS book_markings (id INTEGER PRIMARY KEY AUTOINCREMENT, bookName TEXT, author TEXT, chapterIndex INTEGER, chapterTitle TEXT, pagePos INTEGER, content TEXT, note TEXT, color INTEGER, createTime INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS bookmarks (id INTEGER PRIMARY KEY AUTOINCREMENT, bookName TEXT, author TEXT, chapterIndex INTEGER, chapterTitle TEXT, pagePos INTEGER, content TEXT, note TEXT, createTime INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS caches (id INTEGER PRIMARY KEY AUTOINCREMENT, bookName TEXT, author TEXT, chapterIndex INTEGER, chapterTitle TEXT, content TEXT, size INTEGER, saveTime INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS cloud_tts_engines (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, type TEXT, url TEXT, apiKey TEXT, region TEXT, voice TEXT, rate INTEGER, pitch INTEGER, enabled INTEGER DEFAULT 1, concurrentRate INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS cookies (id INTEGER PRIMARY KEY AUTOINCREMENT, url TEXT, cookie TEXT, lastUpdateTime INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS dict_rules (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, summary TEXT, url TEXT, rule TEXT, enabled INTEGER DEFAULT 1, "order" INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS highlight_rules (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, pattern TEXT, color INTEGER, enabled INTEGER DEFAULT 1, "order" INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS highlight_tag_rules (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, pattern TEXT, color INTEGER, enabled INTEGER DEFAULT 1, "order" INTEGER, scope TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS http_tts (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, url TEXT, method TEXT, headers TEXT, body TEXT, enabled INTEGER DEFAULT 1, concurrentRate INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS read_records (id INTEGER PRIMARY KEY AUTOINCREMENT, bookName TEXT, author TEXT, duration INTEGER, date INTEGER, chapterIndex INTEGER, pagePos INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS replace_rules (id INTEGER PRIMARY KEY AUTOINCREMENT, replaceSummary TEXT, replaceRule TEXT, replacement TEXT, enable INTEGER DEFAULT 1, scope TEXT, "order" INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS rss_sources (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, url TEXT, "group" TEXT, enabled INTEGER DEFAULT 1, lastUpdateTime INTEGER, unreadCount INTEGER DEFAULT 0, icon TEXT, description TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS rss_articles (id INTEGER PRIMARY KEY AUTOINCREMENT, sourceUrl TEXT, title TEXT, link TEXT, desc TEXT, content TEXT, pubDate INTEGER, read INTEGER DEFAULT 0, star INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS rss_stars (id INTEGER PRIMARY KEY AUTOINCREMENT, sourceUrl TEXT, title TEXT, link TEXT, desc TEXT, content TEXT, starTime INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS rule_subs (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, url TEXT, type TEXT, enabled INTEGER DEFAULT 1, lastUpdateTime INTEGER, customOrder INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS search_content_history (id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT, searchTime INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS servers (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, host TEXT, port INTEGER, path TEXT, username TEXT, password TEXT, enabled INTEGER DEFAULT 1)');
    await db.execute('CREATE TABLE IF NOT EXISTS tag_group_rules (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, pattern TEXT, "group" TEXT, enabled INTEGER DEFAULT 1, "order" INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS translation_caches (id INTEGER PRIMARY KEY AUTOINCREMENT, source TEXT, target TEXT, original TEXT, translated TEXT, saveTime INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS txt_toc_rules (id INTEGER PRIMARY KEY AUTOINCREMENT, chapterRule TEXT, enable INTEGER DEFAULT 1, "order" INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS keyboard_assists (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, rule TEXT, enabled INTEGER DEFAULT 1, "order" INTEGER)');
  }

  // 书籍DAO
  Future<List<Book>> getAllBooks() async {
    final db = await database;
    final maps = await db.query('books', orderBy: '"order" ASC');
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  Future<Book?> getBook(String name, String author) async {
    final db = await database;
    final maps = await db.query('books', where: 'name = ? AND author = ?', whereArgs: [name, author]);
    return maps.isNotEmpty ? Book.fromMap(maps.first) : null;
  }

  Future<void> insertBook(Book book) async {
    final db = await database;
    await db.insert('books', book.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateBook(Book book) async {
    final db = await database;
    await db.update('books', book.toMap(), where: 'name = ? AND author = ?', whereArgs: [book.name, book.author]);
  }

  Future<void> deleteBook(String name, String author) async {
    final db = await database;
    await db.delete('books', where: 'name = ? AND author = ?', whereArgs: [name, author]);
    await db.delete('book_chapters', where: 'bookName = ? AND bookAuthor = ?', whereArgs: [name, author]);
  }

  // 章节DAO
  Future<List<BookChapter>> getChapters(String bookName, String bookAuthor) async {
    final db = await database;
    final maps = await db.query('book_chapters', where: 'bookName = ? AND bookAuthor = ?', whereArgs: [bookName, bookAuthor], orderBy: '"index" ASC');
    return maps.map((m) => BookChapter.fromMap(m)).toList();
  }

  Future<void> insertChapters(String bookName, String bookAuthor, List<BookChapter> chapters) async {
    final db = await database;
    final batch = db.batch();
    for (final ch in chapters) {
      batch.insert('book_chapters', ch.toMap(bookName, bookAuthor), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  Future<void> saveChapters(String bookName, String bookAuthor, List<BookChapter> chapters) async {
    final db = await database;
    await db.delete('book_chapters', where: 'bookName = ? AND bookAuthor = ?', whereArgs: [bookName, bookAuthor]);
    final batch = db.batch();
    for (final ch in chapters) {
      batch.insert('book_chapters', ch.toMap(bookName, bookAuthor), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  Future<void> updateChapterContent(String bookName, String author, int chapterIndex, String content) async {
    final db = await database;
    await db.update('book_chapters', {'content': content}, where: 'bookName = ? AND bookAuthor = ? AND "index" = ?', whereArgs: [bookName, author, chapterIndex]);
  }

  Future<void> deleteChapters(String bookName, String bookAuthor) async {
    final db = await database;
    await db.delete('book_chapters', where: 'bookName = ? AND bookAuthor = ?', whereArgs: [bookName, bookAuthor]);
  }

  // 书源DAO
  Future<List<BookSource>> getAllSources({bool? enabled}) async {
    final db = await database;
    final maps = enabled != null
        ? await db.query('book_sources', where: 'enabled = ?', whereArgs: [enabled ? 1 : 0], orderBy: 'customOrder ASC')
        : await db.query('book_sources', orderBy: 'customOrder ASC');
    return maps.map((m) => BookSource.fromMap(m)).toList();
  }

  Future<BookSource?> getSource(String url) async {
    final db = await database;
    final maps = await db.query('book_sources', where: 'bookSourceUrl = ?', whereArgs: [url]);
    return maps.isNotEmpty ? BookSource.fromMap(maps.first) : null;
  }

  Future<void> insertSource(BookSource source) async {
    final db = await database;
    await db.insert('book_sources', source.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSource(BookSource source) async {
    final db = await database;
    await db.update('book_sources', source.toMap(), where: 'bookSourceUrl = ?', whereArgs: [source.bookSourceUrl]);
  }

  Future<void> deleteSource(String url) async {
    final db = await database;
    await db.delete('book_sources', where: 'bookSourceUrl = ?', whereArgs: [url]);
  }

  Future<List<String>> getSourceGroups() async {
    final db = await database;
    final maps = await db.rawQuery('SELECT DISTINCT bookSourceGroup FROM book_sources WHERE bookSourceGroup IS NOT NULL AND bookSourceGroup != ""');
    return maps.map((m) => m['bookSourceGroup'].toString()).toList();
  }

  // 分组DAO
  Future<List<BookGroup>> getBookGroups() async {
    final db = await database;
    final maps = await db.query('book_groups', orderBy: '"order" ASC');
    return maps.map((m) => BookGroup.fromMap(m)).toList();
  }

  Future<void> insertBookGroup(BookGroup group) async {
    final db = await database;
    await db.insert('book_groups', group.toMap());
  }

  Future<void> deleteBookGroup(int id) async {
    final db = await database;
    await db.delete('book_groups', where: 'id = ?', whereArgs: [id]);
  }

  // 书签DAO
  Future<List<Bookmark>> getBookmarks([String? bookName, String? author]) async {
    final db = await database;
    final maps = bookName != null
        ? await db.query('bookmarks', where: 'bookName = ? AND author = ?', whereArgs: [bookName, author], orderBy: 'createTime DESC')
        : await db.query('bookmarks', orderBy: 'createTime DESC');
    return maps.map((m) => Bookmark.fromMap(m)).toList();
  }

  Future<void> insertBookmark(Bookmark bookmark) async {
    final db = await database;
    await db.insert('bookmarks', bookmark.toMap());
  }

  Future<void> addBookmark(Bookmark bookmark) async {
    await insertBookmark(bookmark);
  }

  Future<void> deleteBookmark(int id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  // 替换规则DAO
  Future<List<ReplaceRule>> getReplaceRules() async {
    final db = await database;
    final maps = await db.query('replace_rules', orderBy: '"order" ASC');
    return maps.map((m) => ReplaceRule.fromMap(m)).toList();
  }

  Future<void> insertReplaceRule(ReplaceRule rule) async {
    final db = await database;
    await db.insert('replace_rules', rule.toMap());
  }

  Future<void> updateReplaceRule(ReplaceRule rule) async {
    final db = await database;
    if (rule.id != null) await db.update('replace_rules', rule.toMap(), where: 'id = ?', whereArgs: [rule.id]);
  }

  Future<void> deleteReplaceRule(int id) async {
    final db = await database;
    await db.delete('replace_rules', where: 'id = ?', whereArgs: [id]);
  }

  // RSS DAO
  Future<List<RssSource>> getRssSources() async {
    final db = await database;
    final maps = await db.query('rss_sources', orderBy: 'lastUpdateTime DESC');
    return maps.map((m) => RssSource.fromMap(m)).toList();
  }

  Future<void> insertRssSource(RssSource source) async {
    final db = await database;
    await db.insert('rss_sources', source.toMap());
  }

  Future<void> updateRssSource(RssSource source) async {
    final db = await database;
    if (source.id != null) await db.update('rss_sources', source.toMap(), where: 'id = ?', whereArgs: [source.id]);
  }

  Future<void> deleteRssSource(int id) async {
    final db = await database;
    await db.delete('rss_sources', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RssArticle>> getRssArticles([String? sourceUrl]) async {
    final db = await database;
    final maps = sourceUrl != null
        ? await db.query('rss_articles', where: 'sourceUrl = ?', whereArgs: [sourceUrl], orderBy: 'pubDate DESC')
        : await db.query('rss_articles', orderBy: 'pubDate DESC');
    return maps.map((m) => RssArticle.fromMap(m)).toList();
  }

  Future<void> insertRssArticle(RssArticle article) async {
    final db = await database;
    await db.insert('rss_articles', article.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveRssArticles(List<RssArticle> articles) async {
    final db = await database;
    final batch = db.batch();
    for (final a in articles) {
      batch.insert('rss_articles', a.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  Future<void> markRssArticleRead(int id) async {
    final db = await database;
    await db.update('rss_articles', {'read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // TXT目录规则DAO
  Future<List<TxtTocRule>> getTxtTocRules() async {
    final db = await database;
    final maps = await db.query('txt_toc_rules', orderBy: '"order" ASC');
    return maps.map((m) => TxtTocRule.fromMap(m)).toList();
  }

  Future<void> insertTxtTocRule(TxtTocRule rule) async {
    final db = await database;
    await db.insert('txt_toc_rules', rule.toMap());
  }

  Future<void> deleteTxtTocRule(int id) async {
    final db = await database;
    await db.delete('txt_toc_rules', where: 'id = ?', whereArgs: [id]);
  }

  // 阅读记录DAO
  Future<void> updateReadPosition(String bookName, String author, int chapterIndex, int pagePos, int time) async {
    final db = await database;
    await db.insert('read_records', {'bookName': bookName, 'author': author, 'chapterIndex': chapterIndex, 'pagePos': pagePos, 'duration': 0, 'date': time});
  }

  Future<List<ReadRecord>> getReadRecords([int? limit]) async {
    final db = await database;
    final maps = await db.query('read_records', orderBy: 'date DESC', limit: limit);
    return maps.map((m) => ReadRecord.fromMap(m)).toList();
  }

  Future<void> addReadRecord(String bookName, String author, int duration, int date) async {
    final db = await database;
    await db.insert('read_records', {'bookName': bookName, 'author': author, 'duration': duration, 'date': date});
  }

  // 缓存DAO
  Future<List<Cache>> getCaches() async {
    final db = await database;
    final maps = await db.query('caches', orderBy: 'saveTime DESC');
    return maps.map((m) => Cache.fromMap(m)).toList();
  }

  Future<void> insertCache(Cache cache) async {
    final db = await database;
    await db.insert('caches', cache.toMap());
  }

  Future<void> clearCaches() async {
    final db = await database;
    await db.delete('caches');
  }

  Future<void> clearChapterContent() async {
    final db = await database;
    await db.delete('caches');
  }

  // 字典规则DAO
  Future<List<DictRule>> getDictRules() async {
    final db = await database;
    final maps = await db.query('dict_rules', orderBy: '"order" ASC');
    return maps.map((m) => DictRule.fromMap(m)).toList();
  }

  Future<void> insertDictRule(DictRule rule) async {
    final db = await database;
    await db.insert('dict_rules', rule.toMap());
  }

  Future<void> deleteDictRule(int id) async {
    final db = await database;
    await db.delete('dict_rules', where: 'id = ?', whereArgs: [id]);
  }

  // 高亮规则DAO
  Future<List<HighlightRule>> getHighlightRules() async {
    final db = await database;
    final maps = await db.query('highlight_rules', orderBy: '"order" ASC');
    return maps.map((m) => HighlightRule.fromMap(m)).toList();
  }

  Future<void> insertHighlightRule(HighlightRule rule) async {
    final db = await database;
    await db.insert('highlight_rules', rule.toMap());
  }

  Future<void> deleteHighlightRule(int id) async {
    final db = await database;
    await db.delete('highlight_rules', where: 'id = ?', whereArgs: [id]);
  }

  // 高亮标签规则DAO
  Future<List<HighlightTagRule>> getHighlightTagRules() async {
    final db = await database;
    final maps = await db.query('highlight_tag_rules', orderBy: '"order" ASC');
    return maps.map((m) => HighlightTagRule.fromMap(m)).toList();
  }

  Future<void> insertHighlightTagRule(HighlightTagRule rule) async {
    final db = await database;
    await db.insert('highlight_tag_rules', rule.toMap());
  }

  Future<void> deleteHighlightTagRule(int id) async {
    final db = await database;
    await db.delete('highlight_tag_rules', where: 'id = ?', whereArgs: [id]);
  }

  // 云TTS DAO
  Future<List<CloudTtsEngine>> getCloudTtsEngines() async {
    final db = await database;
    final maps = await db.query('cloud_tts_engines');
    return maps.map((m) => CloudTtsEngine.fromMap(m)).toList();
  }

  Future<void> insertCloudTtsEngine(CloudTtsEngine engine) async {
    final db = await database;
    await db.insert('cloud_tts_engines', engine.toMap());
  }

  Future<void> updateCloudTtsEngine(CloudTtsEngine engine) async {
    final db = await database;
    if (engine.id != null) await db.update('cloud_tts_engines', engine.toMap(), where: 'id = ?', whereArgs: [engine.id]);
  }

  Future<void> deleteCloudTtsEngine(int id) async {
    final db = await database;
    await db.delete('cloud_tts_engines', where: 'id = ?', whereArgs: [id]);
  }

  // Cookie DAO
  Future<String?> getCookie(String url) async {
    final db = await database;
    final maps = await db.query('cookies', where: 'url = ?', whereArgs: [url]);
    return maps.isNotEmpty ? maps.first['cookie'].toString() : null;
  }

  Future<void> saveCookie(String url, String cookie) async {
    final db = await database;
    await db.insert('cookies', {'url': url, 'cookie': cookie, 'lastUpdateTime': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // 书籍知识DAO
  Future<List<BookKnowledge>> getBookKnowledge(String bookName, String author, {String? type}) async {
    final db = await database;
    final maps = type != null
        ? await db.query('book_knowledge', where: 'bookName = ? AND author = ? AND type = ?', whereArgs: [bookName, author, type], orderBy: '"order" ASC')
        : await db.query('book_knowledge', where: 'bookName = ? AND author = ?', whereArgs: [bookName, author], orderBy: '"order" ASC');
    return maps.map((m) => BookKnowledge.fromMap(m)).toList();
  }

  Future<void> insertBookKnowledge(BookKnowledge knowledge) async {
    final db = await database;
    await db.insert('book_knowledge', knowledge.toMap());
  }

  // 书籍标记DAO
  Future<List<BookMarking>> getBookMarkings(String bookName, String author) async {
    final db = await database;
    final maps = await db.query('book_markings', where: 'bookName = ? AND author = ?', whereArgs: [bookName, author], orderBy: 'createTime DESC');
    return maps.map((m) => BookMarking.fromMap(m)).toList();
  }

  Future<void> insertBookMarking(BookMarking marking) async {
    final db = await database;
    await db.insert('book_markings', marking.toMap());
  }

  Future<void> deleteBookMarking(int id) async {
    final db = await database;
    await db.delete('book_markings', where: 'id = ?', whereArgs: [id]);
  }

  // 搜索历史DAO
  Future<List<String>> getSearchHistory({int limit = 20}) async {
    final db = await database;
    final maps = await db.query('search_content_history', orderBy: 'searchTime DESC', limit: limit);
    return maps.map((m) => m['content'].toString()).toList();
  }

  Future<void> saveSearchHistory(String content) async {
    final db = await database;
    await db.insert('search_content_history', {'content': content, 'searchTime': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearSearchHistory() async {
    final db = await database;
    await db.delete('search_content_history');
  }

  // 规则订阅DAO
  Future<List<RuleSub>> getRuleSubs() async {
    final db = await database;
    final maps = await db.query('rule_subs', orderBy: 'customOrder ASC');
    return maps.map((m) => RuleSub.fromMap(m)).toList();
  }

  Future<void> insertRuleSub(RuleSub sub) async {
    final db = await database;
    await db.insert('rule_subs', sub.toMap());
  }

  Future<void> deleteRuleSub(int id) async {
    final db = await database;
    await db.delete('rule_subs', where: 'id = ?', whereArgs: [id]);
  }

  // 翻译缓存DAO
  Future<String?> getTranslation(String source, String target, String original) async {
    final db = await database;
    final maps = await db.query('translation_caches', where: 'source = ? AND target = ? AND original = ?', whereArgs: [source, target, original]);
    return maps.isNotEmpty ? maps.first['translated'].toString() : null;
  }

  Future<void> saveTranslation(String source, String target, String original, String translated) async {
    final db = await database;
    await db.insert('translation_caches', {'source': source, 'target': target, 'original': original, 'translated': translated, 'saveTime': DateTime.now().millisecondsSinceEpoch});
  }

  // 键盘辅助DAO
  Future<List<KeyboardAssist>> getKeyboardAssists() async {
    final db = await database;
    final maps = await db.query('keyboard_assists', orderBy: '"order" ASC');
    return maps.map((m) => KeyboardAssist.fromMap(m)).toList();
  }

  Future<void> insertKeyboardAssist(KeyboardAssist assist) async {
    final db = await database;
    await db.insert('keyboard_assists', assist.toMap());
  }

  // HTTP TTS DAO
  Future<List<HttpTTS>> getHttpTTS() async {
    final db = await database;
    final maps = await db.query('http_tts');
    return maps.map((m) => HttpTTS.fromMap(m)).toList();
  }

  Future<void> insertHttpTTS(HttpTTS tts) async {
    final db = await database;
    await db.insert('http_tts', tts.toMap());
  }

  // RSS收藏DAO
  Future<List<RssStar>> getRssStars() async {
    final db = await database;
    final maps = await db.query('rss_stars', orderBy: 'starTime DESC');
    return maps.map((m) => RssStar.fromMap(m)).toList();
  }

  Future<void> insertRssStar(RssStar star) async {
    final db = await database;
    await db.insert('rss_stars', star.toMap());
  }

  Future<void> deleteRssStar(int id) async {
    final db = await database;
    await db.delete('rss_stars', where: 'id = ?', whereArgs: [id]);
  }

  // 服务器DAO
  Future<List<Server>> getServers() async {
    final db = await database;
    final maps = await db.query('servers');
    return maps.map((m) => Server.fromMap(m)).toList();
  }

  Future<void> insertServer(Server server) async {
    final db = await database;
    await db.insert('servers', server.toMap());
  }

  // 标签分组规则DAO
  Future<List<TagGroupRule>> getTagGroupRules() async {
    final db = await database;
    final maps = await db.query('tag_group_rules', orderBy: '"order" ASC');
    return maps.map((m) => TagGroupRule.fromMap(m)).toList();
  }

  Future<void> insertTagGroupRule(TagGroupRule rule) async {
    final db = await database;
    await db.insert('tag_group_rules', rule.toMap());
  }

  // 搜索书籍DAO
  Future<List<Book>> getSearchBooks() async {
    final db = await database;
    final maps = await db.query('search_books', orderBy: 'addTime DESC');
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  // 阅读进度DAO
  Future<BookProgress?> getBookProgress(String bookName, String author) async {
    final db = await database;
    final maps = await db.query('book_progress', where: 'bookName = ? AND author = ?', whereArgs: [bookName, author], orderBy: 'lastReadTime DESC', limit: 1);
    return maps.isNotEmpty ? BookProgress.fromMap(maps.first) : null;
  }

  Future<void> saveBookProgress(BookProgress progress) async {
    final db = await database;
    await db.insert('book_progress', progress.toMap());
  }
}
