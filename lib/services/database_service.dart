import 'dart:convert';
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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        // 重建所有表以确保结构最新
        await db.execute('DROP TABLE IF EXISTS book_chapters');
        await db.execute('DROP TABLE IF EXISTS book_sources');
        await db.execute('DROP TABLE IF EXISTS replace_rules');
        await db.execute('DROP TABLE IF EXISTS read_records');
        await db.execute('DROP TABLE IF EXISTS rss_sources');
        await db.execute('DROP TABLE IF EXISTS rss_articles');
        await db.execute('DROP TABLE IF EXISTS bookmarks');
        await db.execute('DROP TABLE IF EXISTS books');
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
        bookUrl TEXT,
        origin TEXT,
        originName TEXT,
        tag TEXT,
        wordCount INTEGER,
        canUpdate INTEGER DEFAULT 1,
        local INTEGER DEFAULT 0,
        type INTEGER DEFAULT 0,
        group_name TEXT,
        order_num INTEGER,
        latestChapterTime INTEGER,
        lastCheckTime INTEGER,
        infoHtml TEXT,
        tocHtml TEXT,
        variable TEXT,
        customOrder INTEGER DEFAULT 0,
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
        exploreScreen TEXT,
        checkKeyWord TEXT,
        ruleSearch TEXT,
        ruleExplore TEXT,
        ruleBookInfo TEXT,
        ruleToc TEXT,
        ruleContent TEXT,
        ruleReview TEXT,
        ruleImage TEXT,
        variableComment TEXT,
        variable TEXT,
        customOrder INTEGER DEFAULT 0,
        respondTime INTEGER DEFAULT 180000,
        weight INTEGER DEFAULT 0,
        coverDecodeJs TEXT,
        eventListener INTEGER DEFAULT 0,
        customButton INTEGER DEFAULT 0,
        homepageModules TEXT
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

    await db.execute('CREATE INDEX idx_chapters_book ON book_chapters(bookName, bookAuthor)');
    await db.execute('CREATE INDEX idx_sources_enabled ON book_sources(enabled)');
    await db.execute('CREATE INDEX idx_records_date ON read_records(readDate)');
    await db.execute('CREATE INDEX idx_rss_articles_source ON rss_articles(sourceUrl)');
    await db.execute('CREATE INDEX idx_rss_articles_date ON rss_articles(pubDate)');
    await db.execute('CREATE INDEX idx_bookmarks_book ON bookmarks(bookName, bookAuthor)');
  }

  // ==================== Books ====================

  Future<List<Book>> getAllBooks() async {
    final db = await database;
    final maps = await db.query('books', orderBy: 'customOrder ASC, lastCheckTime DESC');
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  Future<Book?> getBook(String name, String author) async {
    final db = await database;
    final maps = await db.query(
      'books',
      where: 'name = ? AND author = ?',
      whereArgs: [name, author],
      limit: 1,
    );
    return maps.isNotEmpty ? Book.fromMap(maps.first) : null;
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
    await db.delete('bookmarks', where: 'bookName = ? AND bookAuthor = ?', whereArgs: [name, author]);
    await db.delete('read_records', where: 'bookName = ? AND author = ?', whereArgs: [name, author]);
  }

  Future<void> updateReadPosition(String name, String author, int chapterIndex, int pagePos, int time) async {
    final db = await database;
    await db.update(
      'books',
      {
        'durChapterIndex': chapterIndex,
        'durChapterPos': pagePos,
        'durChapterTime': time,
        'lastCheckTime': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'name = ? AND author = ?',
      whereArgs: [name, author],
    );
  }

  // ==================== Chapters ====================

  Future<List<BookChapter>> getChapters(String bookName, String bookAuthor) async {
    final db = await database;
    final maps = await db.query(
      'book_chapters',
      where: 'bookName = ? AND bookAuthor = ?',
      whereArgs: [bookName, bookAuthor],
      orderBy: 'chapter_index ASC',
    );
    return maps.map((m) => BookChapter.fromMap(m)).toList();
  }

  Future<void> saveChapters(String bookName, String bookAuthor, List<BookChapter> chapters) async {
    final db = await database;
    await db.delete('book_chapters', where: 'bookName = ? AND bookAuthor = ?', whereArgs: [bookName, bookAuthor]);
    final batch = db.batch();
    for (final chapter in chapters) {
      batch.insert('book_chapters', chapter.toMap(bookName, bookAuthor));
    }
    await batch.commit(noResult: true);
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

  Future<void> clearChapterContent(String bookName, String bookAuthor) async {
    final db = await database;
    await db.update(
      'book_chapters',
      {'content': null},
      where: 'bookName = ? AND bookAuthor = ?',
      whereArgs: [bookName, bookAuthor],
    );
  }

  // ==================== Book Sources ====================

  Future<List<BookSource>> getAllSources({bool? enabled}) async {
    final db = await database;
    final maps = await db.query(
      'book_sources',
      where: enabled != null ? 'enabled = ?' : null,
      whereArgs: enabled != null ? [enabled ? 1 : 0] : null,
      orderBy: 'customOrder ASC, lastUpdateTime DESC',
    );
    return maps.map((m) => BookSource.fromMap(m)).toList();
  }

  Future<BookSource?> getSource(String url) async {
    final db = await database;
    final maps = await db.query(
      'book_sources',
      where: 'bookSourceUrl = ?',
      whereArgs: [url],
      limit: 1,
    );
    return maps.isNotEmpty ? BookSource.fromMap(maps.first) : null;
  }

  Future<void> insertSource(BookSource source) async {
    final db = await database;
    await db.insert('book_sources', source.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSource(BookSource source) async {
    final db = await database;
    await db.update(
      'book_sources',
      source.toMap(),
      where: 'bookSourceUrl = ?',
      whereArgs: [source.bookSourceUrl],
    );
  }

  Future<void> deleteSource(String url) async {
    final db = await database;
    await db.delete('book_sources', where: 'bookSourceUrl = ?', whereArgs: [url]);
  }

  // ==================== Replace Rules ====================

  Future<List<ReplaceRule>> getReplaceRules() async {
    final db = await database;
    final maps = await db.query('replace_rules', orderBy: 'order_num ASC');
    return maps.map((m) => ReplaceRule.fromMap(m)).toList();
  }

  Future<void> insertReplaceRule(ReplaceRule rule) async {
    final db = await database;
    await db.insert('replace_rules', rule.toMap());
  }

  Future<void> updateReplaceRule(ReplaceRule rule) async {
    final db = await database;
    await db.update(
      'replace_rules',
      rule.toMap(),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  Future<void> deleteReplaceRule(int id) async {
    final db = await database;
    await db.delete('replace_rules', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Read Records ====================

  Future<void> addReadRecord(String bookName, String author, int duration, int chapterIndex, String chapterTitle) async {
    final db = await database;
    await db.insert('read_records', {
      'bookName': bookName,
      'author': author,
      'duration': duration,
      'readDate': DateTime.now().millisecondsSinceEpoch,
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
    });
  }

  Future<List<Map<String, dynamic>>> getReadRecords({int? limit}) async {
    final db = await database;
    return await db.query(
      'read_records',
      orderBy: 'readDate DESC',
      limit: limit,
    );
  }

  Future<Map<String, int>> getReadingStats() async {
    final db = await database;
    final totalResult = await db.rawQuery('SELECT SUM(duration) as total FROM read_records');
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final todayResult = await db.rawQuery(
      'SELECT SUM(duration) as total FROM read_records WHERE readDate >= ?',
      [todayStart],
    );
    final booksResult = await db.rawQuery('SELECT COUNT(DISTINCT bookName) as count FROM read_records');
    return {
      'totalMinutes': ((totalResult.first['total'] as int?) ?? 0) ~/ 60000,
      'todayMinutes': ((todayResult.first['total'] as int?) ?? 0) ~/ 60000,
      'bookCount': (booksResult.first['count'] as int?) ?? 0,
    };
  }

  // ==================== RSS ====================

  Future<List<RssSource>> getRssSources() async {
    final db = await database;
    final maps = await db.query('rss_sources', orderBy: 'lastUpdateTime DESC');
    return maps.map((m) => RssSource.fromMap(m)).toList();
  }

  Future<void> insertRssSource(RssSource source) async {
    final db = await database;
    await db.insert('rss_sources', source.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRssSource(int id) async {
    final db = await database;
    await db.delete('rss_sources', where: 'id = ?', whereArgs: [id]);
    await db.delete('rss_articles', where: 'sourceUrl = (SELECT url FROM rss_sources WHERE id = ?)', whereArgs: [id]);
  }

  Future<List<RssArticle>> getRssArticles({String? sourceUrl, bool? unreadOnly}) async {
    final db = await database;
    String where = '';
    List<dynamic> args = [];
    if (sourceUrl != null) {
      where += 'sourceUrl = ?';
      args.add(sourceUrl);
    }
    if (unreadOnly == true) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'isRead = 0';
    }
    final maps = await db.query(
      'rss_articles',
      where: where.isEmpty ? null : where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'pubDate DESC',
      limit: 200,
    );
    return maps.map((m) => RssArticle.fromMap(m)).toList();
  }

  Future<void> saveRssArticles(List<RssArticle> articles) async {
    final db = await database;
    final batch = db.batch();
    for (final article in articles) {
      batch.insert('rss_articles', article.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> markRssArticleRead(int id, bool read) async {
    final db = await database;
    await db.update(
      'rss_articles',
      {'isRead': read ? 1 : 0, 'readTime': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Bookmarks ====================

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
