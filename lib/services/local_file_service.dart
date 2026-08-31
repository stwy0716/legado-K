import 'dart:convert';
import 'dart:io';
import '../models/book.dart';
import '../models/book_chapter.dart';

/// 本地导入结果
class LocalImportResult {
  final Book book;
  final List<BookChapter> chapters;
  LocalImportResult({required this.book, required this.chapters});
}

/// 本地文件导入服务
class LocalFileService {
  static const List<String> defaultTocPatterns = [
    r'^第[一二三四五六七八九十百千万零〇两\d]+[章节回卷集部篇].*$',
    r'^Chapter\s+\d+.*$',
    r'^\d+、.*$',
    r'^\d+\..*$',
    r'^【.*】.*$',
    r'^\[.*\].*$',
  ];

  /// 导入TXT文件，返回书籍和章节列表
  Future<LocalImportResult?> importTxt(String filePath, {List<String>? customPatterns}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      final fileName = filePath.split('/').last.replaceAll('.txt', '');

      final patterns = customPatterns ?? defaultTocPatterns;
      final chapters = _parseTxtChapters(content, patterns);

      final book = Book(
        name: fileName,
        author: '未知',
        local: true,
        type: 'txt',
        fileName: fileName,
        wordCount: content.length,
        lastChapter: chapters.isNotEmpty ? chapters.last.title : null,
        lastChapterIndex: chapters.length - 1,
        lastCheckTime: DateTime.now().millisecondsSinceEpoch,
      );

      return LocalImportResult(book: book, chapters: chapters);
    } catch (e) {
      return null;
    }
  }

  List<BookChapter> _parseTxtChapters(String content, List<String> patterns) {
    final chapters = <BookChapter>[];
    final lines = content.split('\n');
    final combinedPattern = RegExp(patterns.map((p) => '($p)').join('|'));

    int chapterStart = -1;
    String currentTitle = '';
    int index = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (combinedPattern.hasMatch(line)) {
        if (chapterStart >= 0) {
          final chapterContent = lines.sublist(chapterStart, i).join('\n').trim();
          chapters.add(BookChapter(
            title: currentTitle,
            url: 'local_$index',
            index: index,
            content: chapterContent,
          ));
          index++;
        }
        chapterStart = i + 1;
        currentTitle = line;
      }
    }

    if (chapterStart >= 0) {
      final chapterContent = lines.sublist(chapterStart).join('\n').trim();
      chapters.add(BookChapter(
        title: currentTitle,
        url: 'local_$index',
        index: index,
        content: chapterContent,
      ));
    }

    if (chapters.isEmpty) {
      chapters.add(BookChapter(
        title: '正文',
        url: 'local_0',
        index: 0,
        content: content,
      ));
    }

    return chapters;
  }

  /// 导入EPUB文件（简化实现）
  Future<LocalImportResult?> importEpub(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final fileName = filePath.split('/').last.replaceAll('.epub', '');
      final book = Book(
        name: fileName,
        author: '未知',
        local: true,
        type: 'epub',
        fileName: fileName,
        lastCheckTime: DateTime.now().millisecondsSinceEpoch,
      );

      return LocalImportResult(book: book, chapters: []);
    } catch (e) {
      return null;
    }
  }

  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) return await file.length();
    return 0;
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
