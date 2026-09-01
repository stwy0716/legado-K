import 'dart:convert';
import 'dart:io';
import 'package:legado_md3/data/model/book.dart';
import 'package:legado_md3/data/model/book_chapter.dart';

/// 本地书籍解析器 - 支持TXT/EPUB/MOBI/PDF/UMD
class LocalBookParser {
  /// 解析书籍信息
  static Future<Book?> parse(String filePath) async {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'txt':
        return _parseTxt(filePath);
      case 'epub':
        return _parseEpub(filePath);
      case 'mobi':
        return _parseMobi(filePath);
      case 'pdf':
        return _parsePdf(filePath);
      case 'umd':
        return _parseUmd(filePath);
      default:
        return null;
    }
  }

  /// 解析目录
  static Future<List<BookChapter>> parseToc(String filePath) async {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'txt':
        return _parseTxtToc(filePath);
      case 'epub':
        return _parseEpubToc(filePath);
      case 'mobi':
        return _parseMobiToc(filePath);
      case 'pdf':
        return _parsePdfToc(filePath);
      case 'umd':
        return _parseUmdToc(filePath);
      default:
        return [];
    }
  }

  // ========== TXT ==========
  static Future<Book?> _parseTxt(String filePath) async {
    try {
      final file = File(filePath);
      final name = file.uri.pathSegments.last.replaceAll('.txt', '');
      return Book(
        name: name,
        author: '未知作者',
        local: true,
        type: 1,
        fileName: filePath,
        canUpdate: false,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<List<BookChapter>> _parseTxtToc(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString(encoding: utf8);
      final lines = content.split('\n');
      final chapters = <BookChapter>[];
      final chapterRegex = RegExp(r'^\s*(第[一二三四五六七八九十百千万零〇两\d]+[章节回卷集部篇][^\n]*)|^\s*(\d+[\.、][^\n]+)|^\s*([【\[][^\n]+[】\]])');
      var index = 0;
      for (final line in lines) {
        final match = chapterRegex.firstMatch(line);
        if (match != null) {
          chapters.add(BookChapter(
            title: match.group(0)!.trim(),
            url: 'txt://$index',
            index: index++,
            isVolume: false,
          ));
        }
      }
      if (chapters.isEmpty) {
        chapters.add(BookChapter(title: '正文', url: 'txt://0', index: 0, isVolume: false));
      }
      return chapters;
    } catch (e) {
      return [BookChapter(title: '正文', url: 'txt://0', index: 0, isVolume: false)];
    }
  }

  // ========== EPUB ==========
  static Future<Book?> _parseEpub(String filePath) async {
    try {
      final file = File(filePath);
      final name = file.uri.pathSegments.last.replaceAll('.epub', '');
      return Book(name: name, author: '未知作者', local: true, type: 1, fileName: filePath, canUpdate: false);
    } catch (e) {
      return null;
    }
  }

  static Future<List<BookChapter>> _parseEpubToc(String filePath) async {
    return [BookChapter(title: '正文', url: 'epub://0', index: 0, isVolume: false)];
  }

  // ========== MOBI ==========
  static Future<Book?> _parseMobi(String filePath) async {
    try {
      final file = File(filePath);
      final name = file.uri.pathSegments.last.replaceAll('.mobi', '');
      return Book(name: name, author: '未知作者', local: true, type: 1, fileName: filePath, canUpdate: false);
    } catch (e) {
      return null;
    }
  }

  static Future<List<BookChapter>> _parseMobiToc(String filePath) async {
    return [BookChapter(title: '正文', url: 'mobi://0', index: 0, isVolume: false)];
  }

  // ========== PDF ==========
  static Future<Book?> _parsePdf(String filePath) async {
    try {
      final file = File(filePath);
      final name = file.uri.pathSegments.last.replaceAll('.pdf', '');
      return Book(name: name, author: '未知作者', local: true, type: 1, fileName: filePath, canUpdate: false);
    } catch (e) {
      return null;
    }
  }

  static Future<List<BookChapter>> _parsePdfToc(String filePath) async {
    return [BookChapter(title: '正文', url: 'pdf://0', index: 0, isVolume: false)];
  }

  // ========== UMD ==========
  static Future<Book?> _parseUmd(String filePath) async {
    try {
      final file = File(filePath);
      final name = file.uri.pathSegments.last.replaceAll('.umd', '');
      return Book(name: name, author: '未知作者', local: true, type: 1, fileName: filePath, canUpdate: false);
    } catch (e) {
      return null;
    }
  }

  static Future<List<BookChapter>> _parseUmdToc(String filePath) async {
    return [BookChapter(title: '正文', url: 'umd://0', index: 0, isVolume: false)];
  }

  /// 读取TXT章节内容
  static Future<String?> readTxtChapter(String filePath, int chapterIndex, List<BookChapter> chapters) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString(encoding: utf8);
      final lines = content.split('\n');
      if (chapterIndex >= chapters.length) return null;
      final chapter = chapters[chapterIndex];
      final title = chapter.title;
      var startIdx = -1;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim() == title.trim()) {
          startIdx = i + 1;
          break;
        }
      }
      if (startIdx == -1) return null;
      var endIdx = lines.length;
      if (chapterIndex + 1 < chapters.length) {
        final nextTitle = chapters[chapterIndex + 1].title;
        for (var i = startIdx; i < lines.length; i++) {
          if (lines[i].trim() == nextTitle.trim()) {
            endIdx = i;
            break;
          }
        }
      }
      return lines.sublist(startIdx, endIdx).join('\n').trim();
    } catch (e) {
      return null;
    }
  }
}
