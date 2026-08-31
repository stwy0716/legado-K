class BookSource {
  String bookSourceUrl;
  String bookSourceName;
  String? bookSourceGroup;
  String? bookSourceType;
  String? bookSourceComment;
  int? lastUpdateTime;
  bool? enabled;
  bool? enabledExplore;
  String? header;
  String? loginUrl;
  String? loginUi;
  String? loginCheckJs;
  String? bookUrlPattern;
  String? searchUrl;
  String? exploreUrl;
  String? checkKeyWord;
  String? ruleSearch;
  String? ruleExplore;
  String? ruleBookInfo;
  String? ruleToc;
  String? ruleContent;
  String? ruleImage;
  String? ruleSearchAuthor;
  String? ruleSearchCover;
  String? ruleSearchIntro;
  String? ruleSearchKind;
  String? ruleSearchLastChapter;
  String? ruleSearchNoteUrl;
  String? ruleBookName;
  String? ruleBookAuthor;
  String? ruleBookCover;
  String? ruleBookIntro;
  String? ruleBookKind;
  String? ruleBookLastChapter;
  String? ruleTocName;
  String? ruleTocUrl;
  String? ruleTocNext;
  String? ruleContentUrl;
  String? ruleContentNext;
  String? ruleImageUrl;
  String? ruleImageStyle;
  String? variableComment;
  String? variable;
  int? customOrder;
  int? respondTime;

  BookSource({
    required this.bookSourceUrl,
    required this.bookSourceName,
    this.bookSourceGroup,
    this.bookSourceType,
    this.bookSourceComment,
    this.lastUpdateTime,
    this.enabled = true,
    this.enabledExplore = true,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.bookUrlPattern,
    this.searchUrl,
    this.exploreUrl,
    this.checkKeyWord,
    this.ruleSearch,
    this.ruleExplore,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
    this.ruleImage,
    this.ruleSearchAuthor,
    this.ruleSearchCover,
    this.ruleSearchIntro,
    this.ruleSearchKind,
    this.ruleSearchLastChapter,
    this.ruleSearchNoteUrl,
    this.ruleBookName,
    this.ruleBookAuthor,
    this.ruleBookCover,
    this.ruleBookIntro,
    this.ruleBookKind,
    this.ruleBookLastChapter,
    this.ruleTocName,
    this.ruleTocUrl,
    this.ruleTocNext,
    this.ruleContentUrl,
    this.ruleContentNext,
    this.ruleImageUrl,
    this.ruleImageStyle,
    this.variableComment,
    this.variable,
    this.customOrder,
    this.respondTime,
  });

  Map<String, dynamic> toMap() => {
    'bookSourceUrl': bookSourceUrl,
    'bookSourceName': bookSourceName,
    'bookSourceGroup': bookSourceGroup,
    'bookSourceType': bookSourceType,
    'bookSourceComment': bookSourceComment,
    'lastUpdateTime': lastUpdateTime,
    'enabled': enabled == true ? 1 : 0,
    'enabledExplore': enabledExplore == true ? 1 : 0,
    'header': header,
    'loginUrl': loginUrl,
    'loginUi': loginUi,
    'loginCheckJs': loginCheckJs,
    'bookUrlPattern': bookUrlPattern,
    'searchUrl': searchUrl,
    'exploreUrl': exploreUrl,
    'checkKeyWord': checkKeyWord,
    'ruleSearch': ruleSearch,
    'ruleExplore': ruleExplore,
    'ruleBookInfo': ruleBookInfo,
    'ruleToc': ruleToc,
    'ruleContent': ruleContent,
    'ruleImage': ruleImage,
    'ruleSearchAuthor': ruleSearchAuthor,
    'ruleSearchCover': ruleSearchCover,
    'ruleSearchIntro': ruleSearchIntro,
    'ruleSearchKind': ruleSearchKind,
    'ruleSearchLastChapter': ruleSearchLastChapter,
    'ruleSearchNoteUrl': ruleSearchNoteUrl,
    'ruleBookName': ruleBookName,
    'ruleBookAuthor': ruleBookAuthor,
    'ruleBookCover': ruleBookCover,
    'ruleBookIntro': ruleBookIntro,
    'ruleBookKind': ruleBookKind,
    'ruleBookLastChapter': ruleBookLastChapter,
    'ruleTocName': ruleTocName,
    'ruleTocUrl': ruleTocUrl,
    'ruleTocNext': ruleTocNext,
    'ruleContentUrl': ruleContentUrl,
    'ruleContentNext': ruleContentNext,
    'ruleImageUrl': ruleImageUrl,
    'ruleImageStyle': ruleImageStyle,
    'variableComment': variableComment,
    'variable': variable,
    'customOrder': customOrder,
    'respondTime': respondTime,
  };

  factory BookSource.fromMap(Map<String, dynamic> map) => BookSource(
    bookSourceUrl: map['bookSourceUrl'] as String,
    bookSourceName: map['bookSourceName'] as String,
    bookSourceGroup: map['bookSourceGroup'] as String?,
    bookSourceType: map['bookSourceType'] as String?,
    bookSourceComment: map['bookSourceComment'] as String?,
    lastUpdateTime: map['lastUpdateTime'] as int?,
    enabled: (map['enabled'] as int?) == 1,
    enabledExplore: (map['enabledExplore'] as int?) == 1,
    header: map['header'] as String?,
    loginUrl: map['loginUrl'] as String?,
    loginUi: map['loginUi'] as String?,
    loginCheckJs: map['loginCheckJs'] as String?,
    bookUrlPattern: map['bookUrlPattern'] as String?,
    searchUrl: map['searchUrl'] as String?,
    exploreUrl: map['exploreUrl'] as String?,
    checkKeyWord: map['checkKeyWord'] as String?,
    ruleSearch: map['ruleSearch'] as String?,
    ruleExplore: map['ruleExplore'] as String?,
    ruleBookInfo: map['ruleBookInfo'] as String?,
    ruleToc: map['ruleToc'] as String?,
    ruleContent: map['ruleContent'] as String?,
    ruleImage: map['ruleImage'] as String?,
    ruleSearchAuthor: map['ruleSearchAuthor'] as String?,
    ruleSearchCover: map['ruleSearchCover'] as String?,
    ruleSearchIntro: map['ruleSearchIntro'] as String?,
    ruleSearchKind: map['ruleSearchKind'] as String?,
    ruleSearchLastChapter: map['ruleSearchLastChapter'] as String?,
    ruleSearchNoteUrl: map['ruleSearchNoteUrl'] as String?,
    ruleBookName: map['ruleBookName'] as String?,
    ruleBookAuthor: map['ruleBookAuthor'] as String?,
    ruleBookCover: map['ruleBookCover'] as String?,
    ruleBookIntro: map['ruleBookIntro'] as String?,
    ruleBookKind: map['ruleBookKind'] as String?,
    ruleBookLastChapter: map['ruleBookLastChapter'] as String?,
    ruleTocName: map['ruleTocName'] as String?,
    ruleTocUrl: map['ruleTocUrl'] as String?,
    ruleTocNext: map['ruleTocNext'] as String?,
    ruleContentUrl: map['ruleContentUrl'] as String?,
    ruleContentNext: map['ruleContentNext'] as String?,
    ruleImageUrl: map['ruleImageUrl'] as String?,
    ruleImageStyle: map['ruleImageStyle'] as String?,
    variableComment: map['variableComment'] as String?,
    variable: map['variable'] as String?,
    customOrder: map['customOrder'] as int?,
    respondTime: map['respondTime'] as int?,
  );
}
