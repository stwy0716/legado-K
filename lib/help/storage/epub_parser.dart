import 'dart:io';
import 'package:archive/archive.dart';
import 'package:legado_md3/data/model/book.dart';
import 'package:legado_md3/data/model/book_chapter.dart';

/// EPUB书籍解析器
class EpubParser {
  /// 解析EPUB文件
  static Future<Book?> parse(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 查找OPF文件
      String? opfPath;
      for (final file in archive.files) {
        if (file.name.endsWith('.opf')) {
          opfPath = file.name;
          break;
        }
      }

      if (opfPath == null) return null;

      final opfFile = archive.files.firstWhere((f) => f.name == opfPath);
      final opfContent = String.fromCharCodes(opfFile.content as List<int>);

      // 解析书名和作者
      final titleMatch = RegExp(r'<dc:title>([^<]+)</dc:title>').firstMatch(opfContent);
      final creatorMatch = RegExp(r'<dc:creator[^>]*>([^<]+)</dc:creator>').firstMatch(opfContent);
      final descMatch = RegExp(r'<dc:description>([^<]+)</dc:description>').firstMatch(opfContent);

      final book = Book(
        name: titleMatch?.group(1) ?? '未知书籍',
        author: creatorMatch?.group(1) ?? '未知作者',
        intro: descMatch?.group(1),
        local: true,
        type: 1,
        fileName: filePath,
        canUpdate: false,
      );

      return book;
    } catch (e) {
      return null;
    }
  }

  /// 解析EPUB目录
  static Future<List<BookChapter>> parseToc(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return [];

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 查找toc.ncx
      final tocFile = archive.files.where((f) => f.name.endsWith('toc.ncx')).toList();
      if (tocFile.isEmpty) return [];

      final tocContent = String.fromCharCodes(tocFile.first.content as List<int>);

      // 解析navPoint
      final navPoints = RegExp(r'<navPoint[^>]*id="([^"]*)"[^>]*>.*?<text>([^<]+)</text>.*?<content src="([^"]+)"', dotAll: true).allMatches(tocContent);

      final chapters = <BookChapter>[];
      var index = 0;
      for (final match in navPoints) {
        chapters.add(BookChapter(
          title: match.group(2) ?? '第${index + 1}章',
          url: match.group(3) ?? '',
          index: index++,
          isVolume: false,
        ));
      }

      return chapters;
    } catch (e) {
      return [];
    }
  }

  /// 解析EPUB章节内容
  static Future<String?> parseChapterContent(String filePath, String chapterUrl) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 查找章节文件
      final chapterFile = archive.files.where((f) => f.name.endsWith(chapterUrl) || f.name.contains(chapterUrl)).toList();
      if (chapterFile.isEmpty) return null;

      final content = String.fromCharCodes(chapterFile.first.content as List<int>);

      // 提取正文（去除HTML标签）
      final bodyMatch = RegExp(r'<body[^>]*>(.*?)</body>', dotAll: true).firstMatch(content);
      var text = bodyMatch?.group(1) ?? content;

      // 去除HTML标签
      text = text.replaceAll(RegExp(r'<[^>]+>'), '\n');
      text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
      text = text.trim();

      return text;
    } catch (e) {
      return null;
    }
  }
}
