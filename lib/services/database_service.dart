import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../models/book.dart';
import '../models/book_chapter.dart';
import '../models/book_source.dart';
import '../models/replace_rule.dart';
import '../models/rss_source.dart';
import '../models/rss_article.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, 'legado_md3.db');
    return openDatabase(
      fullPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS book_sources');
        await _onCreate(db, newVersion);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        name TEXT NOT NULL,
        author TEXT NOT NULL,
        coverUrl TEXT,
        intro TEXT,
        kind TEXT,
        lastChapter TEXT,
        lastChapterIndex INTEGER,
        durChapterIndex INTEGER DEFAULT 0,
        durChapterPos INTEGER DEFAULT 0,
        durChapterTime INTEGER DEFAULT 0,
        noteUrl TEXT,
        origin TEXT,
        originName TEXT,
        tag TEXT,
        wordCount INTEGER,
        canUpdate INTEGER DEFAULT 1,
        local INTEGER DEFAULT 0,
        type TEXT,
        group_name TEXT,
        order_num INTEGER,
        latestChapterTime INTEGER,
        lastCheckTime INTEGER,
        infoHtml TEXT,
        tocHtml TEXT,
        variable TEXT,
        customOrder INTEGER,
        allowUpdate INTEGER DEFAULT 1,
        fileName TEXT,
        PRIMARY KEY (name, author)
      )
    ''');

    await db.execute('''
      CREATE TABLE book_chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookName TEXT NOT NULL,
        bookAuthor TEXT NOT NULL,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        isVolume INTEGER DEFAULT 0,
        content TEXT,
        start_pos INTEGER,
        end_pos INTEGER,
        variable TEXT,
        FOREIGN KEY (bookName, bookAuthor) REFERENCES books(name, author) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE book_sources (
        bookSourceUrl TEXT PRIMARY KEY,
        bookSourceName TEXT NOT NULL,
        bookSourceGroup TEXT,
        bookSourceType INTEGER DEFAULT 0,
        bookSourceComment TEXT,
        lastUpdateTime INTEGER,
        enabled INTEGER DEFAULT 1,
        enabledExplore INTEGER DEFAULT 0,
        header TEXT,
        loginUrl TEXT,
        loginUi TEXT,
        loginCheckJs TEXT,
        bookUrlPattern TEXT,
        charset TEXT,
        searchUrl TEXT,
        exploreUrl TEXT,
        checkKeyWord TEXT,
        ruleSearch TEXT,
        ruleExplore TEXT,
        ruleBookInfo TEXT,
        ruleToc TEXT,
        ruleContent TEXT,
        ruleImage TEXT,
        variableComment TEXT,
        variable TEXT,
        customOrder INTEGER DEFAULT 0,
        respondTime INTEGER,
        weight INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE replace_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        replaceSummary TEXT NOT NULL,
        replaceRule TEXT NOT NULL,
        replacement TEXT NOT NULL,
        enable INTEGER DEFAULT 1,
        scope TEXT,
        order_num INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE read_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookName TEXT NOT NULL,
        author TEXT NOT NULL,
        duration INTEGER,
        readDate INTEGER,
        chapterIndex INTEGER,
        chapterTitle TEXT,
        startPos INTEGER,
        endPos INTEGER
      )
    ''');

    await db.execute('CREATE INDEX idx_chapters_book ON book_chapters(bookName, bookAuthor)');
    await db.execute('CREATE INDEX idx_sources_enabled ON book_sources(enabled)');
    await db.execute('CREATE INDEX idx_records_date ON read_records(readDate)');

    await db.execute('''
      CREATE TABLE rss_sources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT NOT NULL UNIQUE,
        group_name TEXT,
        enabled INTEGER DEFAULT 1,
        lastUpdateTime INTEGER,
        unreadCount INTEGER DEFAULT 0,
        icon TEXT,
        description TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE rss_articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        link TEXT NOT NULL,
        description TEXT,
        content TEXT,
        pubDate INTEGER,
        author TEXT,
        category TEXT,
        sourceName TEXT,
        sourceUrl TEXT,
        isRead INTEGER DEFAULT 0,
        starred INTEGER DEFAULT 0,
        readTime INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookName TEXT NOT NULL,
        bookAuthor TEXT NOT NULL,
        chapterIndex INTEGER NOT NULL,
        chapterTitle TEXT,
        pageIndex INTEGER DEFAULT 0,
        content TEXT,
        createTime INTEGER
      )
    ''');

    await db.execute('CREATE INDEX idx_rss_articles_source ON rss_articles(sourceUrl)');
    await db.execute('CREATE INDEX idx_rss_articles_date ON rss_articles(pubDate)');
    await db.execute('CREATE INDEX idx_bookmarks_book ON bookmarks(bookName, bookAuthor)');

    // 初始化默认书源
    await _initDefaultSources(db);
  }

  Future<void> _initDefaultSources(Database db) async {
    // 不预置书源，用户自行导入
  }

  // Books
  Future<List<Book>> getAllBooks() async {
    final db = await database;
    final maps = await db.query('books', orderBy: 'customOrder ASC, lastCheckTime DESC');
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  Future<void> insertBook(Book book) async {
    final db = await database;
    await db.insert('books', book.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateBook(Book book) async {
    final db = await database;
    await db.update(
      'books',
      book.toMap(),
      where: 'name = ? AND author = ?',
      whereArgs: [book.name, book.author],
    );
  }

  Future<void> deleteBook(String name, String author) async {
    final db = await database;
    await db.delete('books', where: 'name = ? AND author = ?', whereArgs: [name, author]);
    await db.delete('book_chapters', where: 'bookName = ? AND bookAuthor = ?', whereArgs: [name, author]);
  }

  // Chapters
  Future<List<BookChapter>> getChapters(String bookName, String bookAuthor) async {
    final db = await database;
    final maps = await db.query(
      'book_chapters',
      where: 'bookName = ? AND bookAuthor = ?',
      whereArgs: [bookName, bookAuthor],
      orderBy: 'chapter_index ASC',
    );
    return maps.map((m) => BookChapter.fromMap({
      ...m,
      'index': m['chapter_index'],
      'start': m['start_pos'],
      'end': m['end_pos'],
    })).toList();
  }

  Future<void> saveChapters(String bookName, String bookAuthor, List<BookChapter> chapters) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('book_chapters', where: 'bookName = ? AND bookAuthor = ?', whereArgs: [bookName, bookAuthor]);
      for (final ch in chapters) {
        await txn.insert('book_chapters', {
          'bookName': bookName,
          'bookAuthor': bookAuthor,
          'title': ch.title,
          'url': ch.url,
          'chapter_index': ch.index,
          'isVolume': ch.isVolume == true ? 1 : 0,
          'content': ch.content,
          'start_pos': ch.start,
          'end_pos': ch.end,
          'variable': ch.variable,
        });
      }
    });
  }

  Future<void> updateChapterContent(String bookName, String bookAuthor, int index, String content) async {
    final db = await database;
    await db.update(
      'book_chapters',
      {'content': content},
      where: 'bookName = ? AND bookAuthor = ? AND chapter_index = ?',
      whereArgs: [bookName, bookAuthor, index],
    );
  }

  // Book Sources
  Future<List<BookSource>> getAllSources({bool? enabled}) async {
    final db = await database;
    final maps = await db.query(
      'book_sources',
      where: enabled != null ? 'enabled = ?' : null,
      whereArgs: enabled != null ? [enabled ? 1 : 0] : null,
      orderBy: 'customOrder ASC, lastUpdateTime DESC',
    );
    return maps.map((m) => BookSource.fromDbMap(m)).toList();
  }

  Future<void> insertSource(BookSource source) async {
    final db = await database;
    await db.insert('book_sources', source.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSource(BookSource source) async {
    final db = await database;
    await db.update(
      'book_sources',
      source.toDbMap(),
      where: 'bookSourceUrl = ?',
      whereArgs: [source.bookSourceUrl],
    );
  }

  Future<void> deleteSource(String url) async {
    final db = await database;
    await db.delete('book_sources', where: 'bookSourceUrl = ?', whereArgs: [url]);
  }

  // Replace Rules
  Future<List<ReplaceRule>> getReplaceRules({String? scope}) async {
    final db = await database;
    final maps = await db.query(
      'replace_rules',
      where: scope != null ? 'scope = ? OR scope IS NULL' : null,
      whereArgs: scope != null ? [scope] : null,
      orderBy: 'order_num ASC',
    );
    return maps.map((m) => ReplaceRule.fromMap(m)).toList();
  }

  Future<void> insertReplaceRule(ReplaceRule rule) async {
    final db = await database;
    await db.insert('replace_rules', rule.toMap());
  }

  Future<void> updateReplaceRule(ReplaceRule rule) async {
    final db = await database;
    await db.update('replace_rules', rule.toMap(), where: 'id = ?', whereArgs: [rule.id]);
  }

  Future<void> deleteReplaceRule(int id) async {
    final db = await database;
    await db.delete('replace_rules', where: 'id = ?', whereArgs: [id]);
  }

  // Read Records
  Future<List<ReadRecord>> getReadRecords({int? limit}) async {
    final db = await database;
    final maps = await db.query(
      'read_records',
      orderBy: 'readDate DESC',
      limit: limit,
    );
    return maps.map((m) => ReadRecord.fromMap(m)).toList();
  }

  Future<void> insertReadRecord(ReadRecord record) async {
    final db = await database;
    await db.insert('read_records', record.toMap());
  }

  Future<Map<String, int>> getReadingStatsByDate() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT DATE(readDate/1000, 'unixepoch', 'localtime') as date, SUM(duration) as total
      FROM read_records
      WHERE readDate IS NOT NULL
      GROUP BY date
      ORDER BY date DESC
      LIMIT 30
    ''');
    final result = <String, int>{};
    for (final m in maps) {
      result[m['date'] as String] = (m['total'] as int?) ?? 0;
    }
    return result;
  }

  // RSS Sources
  Future<List<RssSource>> getAllRssSources({bool? enabled}) async {
    final db = await database;
    final maps = await db.query(
      'rss_sources',
      where: enabled != null ? 'enabled = ?' : null,
      whereArgs: enabled != null ? [enabled ? 1 : 0] : null,
      orderBy: 'lastUpdateTime DESC',
    );
    return maps.map((m) => RssSource.fromMap(m)).toList();
  }

  Future<void> insertRssSource(RssSource source) async {
    final db = await database;
    await db.insert('rss_sources', source.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateRssSource(RssSource source) async {
    final db = await database;
    await db.update('rss_sources', source.toMap(), where: 'id = ?', whereArgs: [source.id]);
  }

  Future<void> deleteRssSource(int id) async {
    final db = await database;
    await db.delete('rss_sources', where: 'id = ?', whereArgs: [id]);
  }

  // RSS Articles
  Future<List<RssArticle>> getRssArticles({String? sourceUrl, bool? read, int? limit}) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (sourceUrl != null) { where.add('sourceUrl = ?'); args.add(sourceUrl); }
    if (read != null) { where.add('isRead = ?'); args.add(read ? 1 : 0); }
    final maps = await db.query(
      'rss_articles',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'pubDate DESC',
      limit: limit,
    );
    return maps.map((m) => RssArticle.fromMap(m)).toList();
  }

  Future<void> insertRssArticle(RssArticle article) async {
    final db = await database;
    await db.insert('rss_articles', article.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> updateRssArticle(RssArticle article) async {
    final db = await database;
    await db.update('rss_articles', article.toMap(), where: 'id = ?', whereArgs: [article.id]);
  }

  Future<void> markArticleRead(int id) async {
    final db = await database;
    await db.update('rss_articles', {'isRead': 1, 'readTime': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getUnreadCount({String? sourceUrl}) async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT COUNT(*) as count FROM rss_articles WHERE isRead = 0${sourceUrl != null ? ' AND sourceUrl = ?' : ''}',
      sourceUrl != null ? [sourceUrl] : null,
    );
    return (maps.first['count'] as int?) ?? 0;
  }

  // Bookmarks
  Future<List<Map<String, dynamic>>> getBookmarks(String bookName, String bookAuthor) async {
    final db = await database;
    return await db.query(
      'bookmarks',
      where: 'bookName = ? AND bookAuthor = ?',
      whereArgs: [bookName, bookAuthor],
      orderBy: 'chapterIndex ASC, pageIndex ASC',
    );
  }

  Future<void> addBookmark(Map<String, dynamic> bookmark) async {
    final db = await database;
    await db.insert('bookmarks', bookmark);
  }

  Future<void> deleteBookmark(int id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isBookmarked(String bookName, String bookAuthor, int chapterIndex, int pageIndex) async {
    final db = await database;
    final maps = await db.query(
      'bookmarks',
      where: 'bookName = ? AND bookAuthor = ? AND chapterIndex = ? AND pageIndex = ?',
      whereArgs: [bookName, bookAuthor, chapterIndex, pageIndex],
      limit: 1,
    );
    return maps.isNotEmpty;
  }
}
