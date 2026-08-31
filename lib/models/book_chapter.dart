class BookChapter {
  String title;
  String url;
  int index;
  bool isVolume;
  String? content;
  int? startPos;
  int? endPos;
  String? variable;

  BookChapter({
    required this.title,
    required this.url,
    required this.index,
    this.isVolume = false,
    this.content,
    this.startPos,
    this.endPos,
    this.variable,
  });

  Map<String, dynamic> toMap(String bookName, String bookAuthor) => {
    'bookName': bookName,
    'bookAuthor': bookAuthor,
    'title': title,
    'url': url,
    'chapter_index': index,
    'isVolume': isVolume ? 1 : 0,
    'content': content,
    'start_pos': startPos,
    'end_pos': endPos,
    'variable': variable,
  };

  factory BookChapter.fromMap(Map<String, dynamic> map) => BookChapter(
    title: map['title'] as String,
    url: map['url'] as String,
    index: map['chapter_index'] as int? ?? map['index'] as int? ?? 0,
    isVolume: (map['isVolume'] as int? ?? 0) == 1,
    content: map['content'] as String?,
    startPos: map['start_pos'] as int? ?? map['start'] as int?,
    endPos: map['end_pos'] as int? ?? map['end'] as int?,
    variable: map['variable'] as String?,
  );
}
