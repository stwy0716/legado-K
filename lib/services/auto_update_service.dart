import 'package:collection/collection.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../models/book_chapter.dart';
import 'database_service.dart';
import 'book_source_engine.dart';

/// 自动更新服务
class AutoUpdateService {
  final DatabaseService _db = DatabaseService();
  final BookSourceEngine _engine = BookSourceEngine();
  bool _isUpdating = false;

  bool get isUpdating => _isUpdating;

  /// 更新所有书籍
  Future<UpdateResult> updateAllBooks({Function(String)? onProgress}) async {
    if (_isUpdating) return UpdateResult(success: false, message: '正在更新中');
    _isUpdating = true;

    final result = UpdateResult();
    try {
      final books = await _db.getAllBooks();
      final sources = await _db.getAllSources(enabled: true);
      final sourceMap = {for (final s in sources) s.bookSourceUrl: s};

      for (int i = 0; i < books.length; i++) {
        final book = books[i];
        onProgress?.call('正在检查: ${book.name} (${i + 1}/${books.length})');

        if (book.local || book.origin == null) continue;
        if (book.allowUpdate != true) continue;

        final source = sourceMap[book.origin];
        if (source == null || book.noteUrl == null) continue;

        try {
          // 获取最新目录
          final newChapters = await _engine.getToc(source, book.noteUrl!);
          if (newChapters.isNotEmpty) {
            final oldChapters = await _db.getChapters(book.name, book.author);
            final oldCount = oldChapters.length;

            if (newChapters.length > oldCount) {
              // 有更新
              await _db.saveChapters(book.name, book.author, newChapters);
              book.lastChapter = newChapters.last.title;
              book.lastChapterIndex = newChapters.length - 1;
              book.latestChapterTime = DateTime.now().millisecondsSinceEpoch;
              book.lastCheckTime = DateTime.now().millisecondsSinceEpoch;
              await _db.updateBook(book);
              result.updatedBooks.add(book.name);
              result.newChapterCount += newChapters.length - oldCount;
            } else {
              book.lastCheckTime = DateTime.now().millisecondsSinceEpoch;
              await _db.updateBook(book);
            }
          }
        } catch (e) {
          result.failedBooks.add(book.name);
        }
      }
      result.success = true;
    } catch (e) {
      result.message = '更新失败: $e';
    }

    _isUpdating = false;
    return result;
  }

  /// 更新单本书
  Future<BookUpdateResult> updateBook(Book book) async {
    final result = BookUpdateResult();
    try {
      if (book.local || book.origin == null || book.noteUrl == null) {
        result.message = '本地书籍无需更新';
        return result;
      }

      final sources = await _db.getAllSources(enabled: true);
      final source = sources.where((s) => s.bookSourceUrl == book.origin).firstOrNull;
      if (source == null) {
        result.message = '书源不存在或已禁用';
        return result;
      }

      final newChapters = await _engine.getToc(source, book.noteUrl!);
      if (newChapters.isEmpty) {
        result.message = '获取目录失败';
        return result;
      }

      final oldChapters = await _db.getChapters(book.name, book.author);
      result.oldChapterCount = oldChapters.length;
      result.newChapterCount = newChapters.length;

      if (newChapters.length > oldChapters.length) {
        await _db.saveChapters(book.name, book.author, newChapters);
        book.lastChapter = newChapters.last.title;
        book.lastChapterIndex = newChapters.length - 1;
        book.latestChapterTime = DateTime.now().millisecondsSinceEpoch;
        result.hasUpdate = true;
        result.newChapters = newChapters.sublist(oldChapters.length);
      }

      book.lastCheckTime = DateTime.now().millisecondsSinceEpoch;
      await _db.updateBook(book);
      result.success = true;
    } catch (e) {
      result.message = '更新失败: $e';
    }
    return result;
  }
}

/// 更新结果
class UpdateResult {
  bool success = false;
  String? message;
  List<String> updatedBooks = [];
  List<String> failedBooks = [];
  int newChapterCount = 0;

  UpdateResult({this.success = false, this.message});

  String get summary {
    if (!success) return message ?? '更新失败';
    return '检查完成: ${updatedBooks.length}本有更新, '
        '新增${newChapterCount}章, '
        '${failedBooks.length}本失败';
  }
}

/// 单本书更新结果
class BookUpdateResult {
  bool success = false;
  bool hasUpdate = false;
  String? message;
  int oldChapterCount = 0;
  int newChapterCount = 0;
  List<BookChapter> newChapters = [];
}
