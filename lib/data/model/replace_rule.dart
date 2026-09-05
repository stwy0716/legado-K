class ReplaceRule {
  int? id;
  String replaceSummary;
  String replaceRule;
  String replacement;
  bool? enable;
  bool isTitle;
  bool isContent;
  bool isRegex;
  String? scope; // 书源URL或"all"
  int? order;

  ReplaceRule({
    this.id,
    required this.replaceSummary,
    required this.replaceRule,
    required this.replacement,
    this.enable = true,
    this.isTitle = false,
    this.isContent = true,
    this.isRegex = true,
    this.scope,
    this.order,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'replaceSummary': replaceSummary,
    'replaceRule': replaceRule,
    'replacement': replacement,
    'enable': enable == true ? 1 : 0,
    'isTitle': isTitle ? 1 : 0,
    'isContent': isContent ? 1 : 0,
    'isRegex': isRegex ? 1 : 0,
    'scope': scope,
    'order_num': order,
  };

  factory ReplaceRule.fromMap(Map<String, dynamic> map) => ReplaceRule(
    id: map['id'] as int?,
    replaceSummary: (map['replaceSummary'] ?? map['summary'] ?? '') as String,
    replaceRule: (map['replaceRule'] ?? map['regex'] ?? map['pattern'] ?? '') as String,
    replacement: (map['replacement'] ?? '') as String,
    enable: map['enable'] == null ? true : (map['enable'] is bool ? map['enable'] as bool : (map['enable'] as int) == 1),
    isTitle: map['isTitle'] == null ? false : (map['isTitle'] is bool ? map['isTitle'] as bool : (map['isTitle'] as int) == 1),
    isContent: map['isContent'] == null ? true : (map['isContent'] is bool ? map['isContent'] as bool : (map['isContent'] as int) != 0),
    isRegex: map['isRegex'] == null ? true : (map['isRegex'] is bool ? map['isRegex'] as bool : (map['isRegex'] as int) != 0),
    scope: (map['scope'] ?? map['scopeContent']) as String?,
    order: map['order_num'] as int? ?? map['order'] as int?,
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
