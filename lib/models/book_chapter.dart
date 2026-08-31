class BookChapter {
  String title;
  String url;
  int index;
  bool? isVolume;
  String? content;
  int? start;
  int? end;
  String? variable;

  BookChapter({
    required this.title,
    required this.url,
    required this.index,
    this.isVolume = false,
    this.content,
    this.start,
    this.end,
    this.variable,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'url': url,
    'index': index,
    'isVolume': isVolume == true ? 1 : 0,
    'content': content,
    'start': start,
    'end': end,
    'variable': variable,
  };

  factory BookChapter.fromMap(Map<String, dynamic> map) => BookChapter(
    title: map['title'] as String,
    url: map['url'] as String,
    index: map['index'] as int,
    isVolume: (map['isVolume'] as int?) == 1,
    content: map['content'] as String?,
    start: map['start'] as int?,
    end: map['end'] as int?,
    variable: map['variable'] as String?,
  );
}
