import '../../../data/local/app_database.dart';
import '../../../data/model/replace_rule.dart';

/// 阅读记录用例：阅读时长统计与聚合
class ReadRecordUseCase {
  final DatabaseService _db;
  ReadRecordUseCase([DatabaseService? db]) : _db = db ?? DatabaseService();

  Future<List<ReadRecord>> recent([int? limit]) => _db.getReadRecords(limit);

  Future<void> record(String bookName, String author, int duration, int date) =>
      _db.addReadRecord(bookName, author, duration, date);

  /// 汇总总阅读时长（秒）
  Future<int> totalSeconds() async {
    final list = await _db.getReadRecords();
    return list.fold(0, (sum, r) => sum + (r.duration ?? 0));
  }

  /// 按天聚合阅读时长，返回 {日期时间戳: 秒数}
  Future<Map<int, int>> secondsByDay() async {
    final list = await _db.getReadRecords();
    final map = <int, int>{};
    for (final r in list) {
      final d = r.readDate ?? 0;
      map[d] = (map[d] ?? 0) + (r.duration ?? 0);
    }
    return map;
  }
}
