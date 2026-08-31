class Book {
  String name;
  String author;
  String? coverUrl;
  String? intro;
  String? kind;
  String? lastChapter;
  int? lastChapterIndex;
  int? durChapterIndex;
  int? durChapterPos;
  int? durChapterTime;
  String? noteUrl;
  String? bookUrl;
  String? origin;
  String? originName;
  String? tag;
  int? wordCount;
  bool? canUpdate;
  bool? local;
  String? type;
  String? group;
  int? order;
  int? latestChapterTime;
  int? lastCheckTime;
  String? infoHtml;
  String? tocHtml;
  String? variable;
  int? customOrder;
  bool? allowUpdate;
  String? fileName;

  Book({
    required this.name,
    required this.author,
    this.coverUrl,
    this.intro,
    this.kind,
    this.lastChapter,
    this.lastChapterIndex,
    this.durChapterIndex = 0,
    this.durChapterPos = 0,
    this.durChapterTime = 0,
    this.noteUrl,
    this.bookUrl,
    this.origin,
    this.originName,
    this.tag,
    this.wordCount,
    this.canUpdate = true,
    this.local = false,
    this.type,
    this.group,
    this.order,
    this.latestChapterTime,
    this.lastCheckTime,
    this.infoHtml,
    this.tocHtml,
    this.variable,
    this.customOrder,
    this.allowUpdate = true,
    this.fileName,
  });

  String get uniqueKey => '${origin}_$name';

  Map<String, dynamic> toMap() => {
    'name': name,
    'author': author,
    'coverUrl': coverUrl,
    'intro': intro,
    'kind': kind,
    'lastChapter': lastChapter,
    'lastChapterIndex': lastChapterIndex,
    'durChapterIndex': durChapterIndex,
    'durChapterPos': durChapterPos,
    'durChapterTime': durChapterTime,
    'noteUrl': noteUrl,
    'bookUrl': bookUrl,
    'origin': origin,
    'originName': originName,
    'tag': tag,
    'wordCount': wordCount,
    'canUpdate': canUpdate == true ? 1 : 0,
    'local': local == true ? 1 : 0,
    'type': type,
    'group_name': group,
    'order': order,
    'latestChapterTime': latestChapterTime,
    'lastCheckTime': lastCheckTime,
    'infoHtml': infoHtml,
    'tocHtml': tocHtml,
    'variable': variable,
    'customOrder': customOrder,
    'allowUpdate': allowUpdate == true ? 1 : 0,
    'fileName': fileName,
  };

  factory Book.fromMap(Map<String, dynamic> map) => Book(
    name: map['name'] as String,
    author: map['author'] as String,
    coverUrl: map['coverUrl'] as String?,
    intro: map['intro'] as String?,
    kind: map['kind'] as String?,
    lastChapter: map['lastChapter'] as String?,
    lastChapterIndex: map['lastChapterIndex'] as int?,
    durChapterIndex: map['durChapterIndex'] as int? ?? 0,
    durChapterPos: map['durChapterPos'] as int? ?? 0,
    durChapterTime: map['durChapterTime'] as int? ?? 0,
    noteUrl: map['noteUrl'] as String?,
    bookUrl: map['bookUrl'] as String?,
    origin: map['origin'] as String?,
    originName: map['originName'] as String?,
    tag: map['tag'] as String?,
    wordCount: map['wordCount'] as int?,
    canUpdate: (map['canUpdate'] as int?) == 1,
    local: (map['local'] as int?) == 1,
    type: map['type'] as String?,
    group: map['group_name'] as String?,
    order: map['order'] as int?,
    latestChapterTime: map['latestChapterTime'] as int?,
    lastCheckTime: map['lastCheckTime'] as int?,
    infoHtml: map['infoHtml'] as String?,
    tocHtml: map['tocHtml'] as String?,
    variable: map['variable'] as String?,
    customOrder: map['customOrder'] as int?,
    allowUpdate: (map['allowUpdate'] as int?) == 1,
    fileName: map['fileName'] as String?,
  );
}
