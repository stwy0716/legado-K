import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../models/replace_rule.dart';
import 'database_service.dart';

/// 备份恢复服务
class BackupService {
  final DatabaseService _db = DatabaseService();

  /// 创建完整备份
  Future<Map<String, dynamic>> createBackup({
    bool includeBooks = true,
    bool includeSources = true,
    bool includeReplaceRules = true,
    bool includeReadRecords = true,
    bool includeSettings = true,
  }) async {
    final backup = <String, dynamic>{
      'version': '1.0',
      'backupTime': DateTime.now().toIso8601String(),
      'appVersion': '3.26.7',
    };

    if (includeBooks) {
      final books = await _db.getAllBooks();
      backup['books'] = books.map((b) => b.toMap()).toList();
    }

    if (includeSources) {
      final sources = await _db.getAllSources();
      backup['bookSources'] = sources.map((s) => s.toMap()).toList();
    }

    if (includeReplaceRules) {
      final rules = await _db.getReplaceRules();
      backup['replaceRules'] = rules.map((r) => r.toMap()).toList();
    }

    if (includeReadRecords) {
      final records = await _db.getReadRecords();
      backup['readRecords'] = records.map((r) => r.toMap()).toList();
    }

    return backup;
  }

  /// 导出备份到文件
  Future<String> exportBackupToFile({
    bool includeBooks = true,
    bool includeSources = true,
    bool includeReplaceRules = true,
    bool includeReadRecords = true,
  }) async {
    final backup = await createBackup(
      includeBooks: includeBooks,
      includeSources: includeSources,
      includeReplaceRules: includeReplaceRules,
      includeReadRecords: includeReadRecords,
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'legado_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonEncode(backup));
    return file.path;
  }

  /// 从文件恢复备份
  Future<BackupResult> restoreFromFile(String filePath) async {
    final result = BackupResult();
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        result.error = '文件不存在';
        return result;
      }

      final content = await file.readAsString();
      final backup = jsonDecode(content) as Map<String, dynamic>;

      // 恢复书籍
      if (backup.containsKey('books') && backup['books'] is List) {
        for (final bookMap in backup['books']) {
          try {
            final book = Book.fromMap(Map<String, dynamic>.from(bookMap));
            await _db.insertBook(book);
            result.booksRestored++;
          } catch (_) {
            result.booksFailed++;
          }
        }
      }

      // 恢复书源
      if (backup.containsKey('bookSources') && backup['bookSources'] is List) {
        for (final sourceMap in backup['bookSources']) {
          try {
            final source = BookSource.fromMap(Map<String, dynamic>.from(sourceMap));
            await _db.insertSource(source);
            result.sourcesRestored++;
          } catch (_) {
            result.sourcesFailed++;
          }
        }
      }

      // 恢复替换规则
      if (backup.containsKey('replaceRules') && backup['replaceRules'] is List) {
        for (final ruleMap in backup['replaceRules']) {
          try {
            final rule = ReplaceRule.fromMap(Map<String, dynamic>.from(ruleMap));
            await _db.insertReplaceRule(rule);
            result.rulesRestored++;
          } catch (_) {
            result.rulesFailed++;
          }
        }
      }

      result.success = true;
    } catch (e) {
      result.error = '恢复失败: $e';
    }
    return result;
  }

  /// 导入书源（JSON格式）
  Future<int> importSources(String content) async {
    int count = 0;
    try {
      final data = jsonDecode(content);
      List<dynamic> sources;
      if (data is List) {
        sources = data;
      } else if (data is Map && data.containsKey('bookSources')) {
        sources = data['bookSources'] as List;
      } else {
        sources = [data];
      }

      for (final sourceMap in sources) {
        try {
          final source = BookSource.fromMap(Map<String, dynamic>.from(sourceMap));
          await _db.insertSource(source);
          count++;
        } catch (_) {}
      }
    } catch (_) {}
    return count;
  }

  /// 导出书源
  Future<String> exportSources() async {
    final sources = await _db.getAllSources();
    return jsonEncode(sources.map((s) => s.toMap()).toList());
  }

  /// 导入替换规则
  Future<int> importReplaceRules(String content) async {
    int count = 0;
    try {
      final data = jsonDecode(content);
      final rules = data is List ? data : [data];
      for (final ruleMap in rules) {
        try {
          final rule = ReplaceRule.fromMap(Map<String, dynamic>.from(ruleMap));
          await _db.insertReplaceRule(rule);
          count++;
        } catch (_) {}
      }
    } catch (_) {}
    return count;
  }

  /// 获取备份文件列表
  Future<List<File>> getBackupFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync()
        .whereType<File>()
        .where((f) => f.path.contains('legado_backup_'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// 删除备份文件
  Future<void> deleteBackup(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }
}

/// 备份恢复结果
class BackupResult {
  bool success = false;
  String? error;
  int booksRestored = 0;
  int booksFailed = 0;
  int sourcesRestored = 0;
  int sourcesFailed = 0;
  int rulesRestored = 0;
  int rulesFailed = 0;

  String get summary {
    if (!success) return error ?? '恢复失败';
    return '书籍: $booksRestored成功/${booksFailed}失败, '
        '书源: $sourcesRestored成功/${sourcesFailed}失败, '
        '规则: $rulesRestored成功/${rulesFailed}失败';
  }
}
