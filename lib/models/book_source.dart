import 'dart:convert';

/// Legado书源模型 - 完全兼容原版JSON格式
class BookSource {
  // 基础信息
  String bookSourceUrl;       // 书源URL（唯一标识）
  String bookSourceName;      // 书源名称
  String? bookSourceGroup;    // 书源分组
  int? bookSourceType;        // 书源类型: 0=文本, 1=音频, 2=图片, 3=文件
  String? bookSourceComment;  // 书源注释
  int? lastUpdateTime;        // 最后更新时间
  bool? enabled;              // 是否启用
  bool? enabledExplore;       // 是否启用发现
  int? customOrder;           // 自定义排序
  int? respondTime;           // 响应时间
  int? weight;                // 权重

  // 请求相关
  String? header;             // 请求头(JSON字符串)
  String? loginUrl;           // 登录URL
  String? loginUi;            // 登录UI
  String? loginCheckJs;       // 登录检查JS
  String? bookUrlPattern;     // 书籍URL正则
  String? charset;            // 字符编码

  // 搜索
  String? searchUrl;          // 搜索地址
  String? checkKeyWord;       // 检查关键字

  // 发现
  String? exploreUrl;         // 发现地址

  // 规则（嵌套JSON对象 - 原版格式）
  Map<String, dynamic>? ruleSearch;    // 搜索规则
  Map<String, dynamic>? ruleExplore;   // 发现规则
  Map<String, dynamic>? ruleBookInfo;  // 详情规则
  Map<String, dynamic>? ruleToc;       // 目录规则
  Map<String, dynamic>? ruleContent;   // 正文规则
  Map<String, dynamic>? ruleImage;     // 图片规则

  // 变量
  String? variableComment;    // 变量注释
  String? variable;           // 变量

  BookSource({
    required this.bookSourceUrl,
    required this.bookSourceName,
    this.bookSourceGroup,
    this.bookSourceType = 0,
    this.bookSourceComment,
    this.lastUpdateTime,
    this.enabled = true,
    this.enabledExplore = false,
    this.customOrder = 0,
    this.respondTime,
    this.weight = 0,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.bookUrlPattern,
    this.charset,
    this.searchUrl,
    this.checkKeyWord,
    this.exploreUrl,
    this.ruleSearch,
    this.ruleExplore,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
    this.ruleImage,
    this.variableComment,
    this.variable,
  });

  /// 从JSON Map创建书源（兼容原版格式）
  factory BookSource.fromJson(Map<String, dynamic> json) {
    return BookSource(
      bookSourceUrl: json['bookSourceUrl'] ?? '',
      bookSourceName: json['bookSourceName'] ?? '',
      bookSourceGroup: json['bookSourceGroup'],
      bookSourceType: json['bookSourceType'] is int
          ? json['bookSourceType']
          : int.tryParse(json['bookSourceType']?.toString() ?? '0') ?? 0,
      bookSourceComment: json['bookSourceComment'],
      lastUpdateTime: json['lastUpdateTime'] is int
          ? json['lastUpdateTime']
          : int.tryParse(json['lastUpdateTime']?.toString() ?? '0'),
      enabled: json['enabled'] ?? true,
      enabledExplore: json['enabledExplore'] ?? false,
      customOrder: json['customOrder'] is int
          ? json['customOrder']
          : int.tryParse(json['customOrder']?.toString() ?? '0') ?? 0,
      respondTime: json['respondTime'] is int
          ? json['respondTime']
          : int.tryParse(json['respondTime']?.toString() ?? ''),
      weight: json['weight'] is int
          ? json['weight']
          : int.tryParse(json['weight']?.toString() ?? '0') ?? 0,
      header: json['header'],
      loginUrl: json['loginUrl'],
      loginUi: json['loginUi'],
      loginCheckJs: json['loginCheckJs'],
      bookUrlPattern: json['bookUrlPattern'],
      charset: json['charset'],
      searchUrl: json['searchUrl'],
      checkKeyWord: json['checkKeyWord'],
      exploreUrl: json['exploreUrl'],
      ruleSearch: _parseRule(json['ruleSearch']),
      ruleExplore: _parseRule(json['ruleExplore']),
      ruleBookInfo: _parseRule(json['ruleBookInfo']),
      ruleToc: _parseRule(json['ruleToc']),
      ruleContent: _parseRule(json['ruleContent']),
      ruleImage: _parseRule(json['ruleImage']),
      variableComment: json['variableComment'],
      variable: json['variable'],
    );
  }

  /// 解析规则字段（可能是Map或JSON字符串）
  static Map<String, dynamic>? _parseRule(dynamic rule) {
    if (rule == null) return null;
    if (rule is Map<String, dynamic>) return rule;
    if (rule is String) {
      try {
        final decoded = jsonDecode(rule);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }

  /// 转为JSON Map
  Map<String, dynamic> toJson() {
    return {
      'bookSourceUrl': bookSourceUrl,
      'bookSourceName': bookSourceName,
      'bookSourceGroup': bookSourceGroup,
      'bookSourceType': bookSourceType,
      'bookSourceComment': bookSourceComment,
      'lastUpdateTime': lastUpdateTime ?? DateTime.now().millisecondsSinceEpoch,
      'enabled': enabled,
      'enabledExplore': enabledExplore,
      'customOrder': customOrder,
      'respondTime': respondTime,
      'weight': weight,
      'header': header,
      'loginUrl': loginUrl,
      'loginUi': loginUi,
      'loginCheckJs': loginCheckJs,
      'bookUrlPattern': bookUrlPattern,
      'charset': charset,
      'searchUrl': searchUrl,
      'checkKeyWord': checkKeyWord,
      'exploreUrl': exploreUrl,
      'ruleSearch': ruleSearch,
      'ruleExplore': ruleExplore,
      'ruleBookInfo': ruleBookInfo,
      'ruleToc': ruleToc,
      'ruleContent': ruleContent,
      'ruleImage': ruleImage,
      'variableComment': variableComment,
      'variable': variable,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  /// 转为数据库存储格式（规则字段序列化为JSON字符串）
  Map<String, dynamic> toDbMap() {
    return {
      'bookSourceUrl': bookSourceUrl,
      'bookSourceName': bookSourceName,
      'bookSourceGroup': bookSourceGroup,
      'bookSourceType': bookSourceType,
      'bookSourceComment': bookSourceComment,
      'lastUpdateTime': lastUpdateTime ?? DateTime.now().millisecondsSinceEpoch,
      'enabled': enabled == true ? 1 : 0,
      'enabledExplore': enabledExplore == true ? 1 : 0,
      'customOrder': customOrder,
      'respondTime': respondTime,
      'weight': weight,
      'header': header,
      'loginUrl': loginUrl,
      'loginUi': loginUi,
      'loginCheckJs': loginCheckJs,
      'bookUrlPattern': bookUrlPattern,
      'charset': charset,
      'searchUrl': searchUrl,
      'checkKeyWord': checkKeyWord,
      'exploreUrl': exploreUrl,
      'ruleSearch': ruleSearch != null ? jsonEncode(ruleSearch) : null,
      'ruleExplore': ruleExplore != null ? jsonEncode(ruleExplore) : null,
      'ruleBookInfo': ruleBookInfo != null ? jsonEncode(ruleBookInfo) : null,
      'ruleToc': ruleToc != null ? jsonEncode(ruleToc) : null,
      'ruleContent': ruleContent != null ? jsonEncode(ruleContent) : null,
      'ruleImage': ruleImage != null ? jsonEncode(ruleImage) : null,
      'variableComment': variableComment,
      'variable': variable,
    };
  }

  /// 从数据库Map创建（规则字段从JSON字符串解析）
  factory BookSource.fromDbMap(Map<String, dynamic> map) {
    return BookSource(
      bookSourceUrl: map['bookSourceUrl'] ?? '',
      bookSourceName: map['bookSourceName'] ?? '',
      bookSourceGroup: map['bookSourceGroup'],
      bookSourceType: map['bookSourceType'] is int
          ? map['bookSourceType']
          : int.tryParse(map['bookSourceType']?.toString() ?? '0') ?? 0,
      bookSourceComment: map['bookSourceComment'],
      lastUpdateTime: map['lastUpdateTime'] is int
          ? map['lastUpdateTime']
          : int.tryParse(map['lastUpdateTime']?.toString() ?? ''),
      enabled: (map['enabled'] ?? 1) == 1,
      enabledExplore: (map['enabledExplore'] ?? 0) == 1,
      customOrder: map['customOrder'] ?? 0,
      respondTime: map['respondTime'],
      weight: map['weight'] ?? 0,
      header: map['header'],
      loginUrl: map['loginUrl'],
      loginUi: map['loginUi'],
      loginCheckJs: map['loginCheckJs'],
      bookUrlPattern: map['bookUrlPattern'],
      charset: map['charset'],
      searchUrl: map['searchUrl'],
      checkKeyWord: map['checkKeyWord'],
      exploreUrl: map['exploreUrl'],
      ruleSearch: _parseDbRule(map['ruleSearch']),
      ruleExplore: _parseDbRule(map['ruleExplore']),
      ruleBookInfo: _parseDbRule(map['ruleBookInfo']),
      ruleToc: _parseDbRule(map['ruleToc']),
      ruleContent: _parseDbRule(map['ruleContent']),
      ruleImage: _parseDbRule(map['ruleImage']),
      variableComment: map['variableComment'],
      variable: map['variable'],
    );
  }

  static Map<String, dynamic>? _parseDbRule(dynamic rule) {
    if (rule == null) return null;
    if (rule is Map<String, dynamic>) return rule;
    if (rule is String) {
      try {
        final decoded = jsonDecode(rule);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }

  static BookSource fromJsonString(String str) =>
      BookSource.fromJson(jsonDecode(str));

  static List<BookSource> fromJsonStringList(String str) {
    final decoded = jsonDecode(str);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => BookSource.fromJson(e))
          .toList();
    } else if (decoded is Map<String, dynamic>) {
      return [BookSource.fromJson(decoded)];
    }
    return [];
  }

  // 搜索规则快捷访问
  String? get searchBookList => ruleSearch?['bookList'];
  String? get searchName => ruleSearch?['name'];
  String? get searchAuthor => ruleSearch?['author'];
  String? get searchCoverUrl => ruleSearch?['coverUrl'];
  String? get searchBookUrl => ruleSearch?['bookUrl'];
  String? get searchIntro => ruleSearch?['intro'];
  String? get searchKind => ruleSearch?['kind'];
  String? get searchLastChapter => ruleSearch?['lastChapter'];
  String? get searchWordCount => ruleSearch?['wordCount'];

  // 目录规则快捷访问
  String? get tocChapterList => ruleToc?['chapterList'];
  String? get tocChapterName => ruleToc?['chapterName'];
  String? get tocChapterUrl => ruleToc?['chapterUrl'];
  String? get tocNextUrl => ruleToc?['nextTocUrl'];
  String? get tocIsVip => ruleToc?['isVip'];

  // 正文规则快捷访问
  String? get contentRule => ruleContent?['content'];
  String? get contentNextUrl => ruleContent?['nextContentUrl'];
  String? get contentWebJs => ruleContent?['webJs'];
  String? get contentSourceRegex => ruleContent?['sourceRegex'];

  // 详情规则快捷访问
  String? get bookInfoName => ruleBookInfo?['name'];
  String? get bookInfoAuthor => ruleBookInfo?['author'];
  String? get bookInfoCover => ruleBookInfo?['coverUrl'];
  String? get bookInfoIntro => ruleBookInfo?['intro'];
  String? get bookInfoKind => ruleBookInfo?['kind'];
  String? get bookInfoLastChapter => ruleBookInfo?['lastChapter'];
  String? get bookInfoTocUrl => ruleBookInfo?['tocUrl'];
  String? get bookInfoInit => ruleBookInfo?['bookInfoInit'];
}
