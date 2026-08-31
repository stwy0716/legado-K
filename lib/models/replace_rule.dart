class ReplaceRule {
  int? id;
  String replaceSummary;
  String replaceRule;
  String replacement;
  bool? enable;
  String? scope; // 书源URL或"all"
  int? order;

  ReplaceRule({
    this.id,
    required this.replaceSummary,
    required this.replaceRule,
    required this.replacement,
    this.enable = true,
    this.scope,
    this.order,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'replaceSummary': replaceSummary,
    'replaceRule': replaceRule,
    'replacement': replacement,
    'enable': enable == true ? 1 : 0,
    'scope': scope,
    'order': order,
  };

  factory ReplaceRule.fromMap(Map<String, dynamic> map) => ReplaceRule(
    id: map['id'] as int?,
    replaceSummary: map['replaceSummary'] as String,
    replaceRule: map['replaceRule'] as String,
    replacement: map['replacement'] as String,
    enable: (map['enable'] as int?) == 1,
    scope: map['scope'] as String?,
    order: map['order'] as int?,
  );
}

class ReadRecord {
  int? id;
  String bookName;
  String author;
  int? duration; // 阅读时长(秒)
  int? readDate; // 日期时间戳
  int? chapterIndex;
  String? chapterTitle;
  int? startPos;
  int? endPos;

  ReadRecord({
    this.id,
    required this.bookName,
    required this.author,
    this.duration,
    this.readDate,
    this.chapterIndex,
    this.chapterTitle,
    this.startPos,
    this.endPos,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'bookName': bookName,
    'author': author,
    'duration': duration,
    'readDate': readDate,
    'chapterIndex': chapterIndex,
    'chapterTitle': chapterTitle,
    'startPos': startPos,
    'endPos': endPos,
  };

  factory ReadRecord.fromMap(Map<String, dynamic> map) => ReadRecord(
    id: map['id'] as int?,
    bookName: map['bookName'] as String,
    author: map['author'] as String,
    duration: map['duration'] as int?,
    readDate: map['readDate'] as int?,
    chapterIndex: map['chapterIndex'] as int?,
    chapterTitle: map['chapterTitle'] as String?,
    startPos: map['startPos'] as int?,
    endPos: map['endPos'] as int?,
  );
}
