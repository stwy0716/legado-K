import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:legado_md3/data/model/book_source.dart';
import 'package:legado_md3/data/model/search_book.dart';
import 'package:legado_md3/data/model/book_chapter.dart';
import 'package:legado_md3/data/model/book.dart';
import 'package:legado_md3/data/model/replace_rule.dart';
import 'package:legado_md3/help/source/replace_rule_service.dart';

/// 规则类型
enum _RuleType { css, xpath, json, js, regex, defaultRule, none }

/// Legado书源引擎 - 完全兼容原版规则格式
class BookSourceEngine {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    },
  ));

  final ReplaceRuleService _replaceService = ReplaceRuleService();

  /// 解析规则类型
  _RuleType _parseRuleType(String rule) {
    if (rule.isEmpty) return _RuleType.none;
    if (rule.startsWith('@css:')) return _RuleType.css;
    if (rule.startsWith('@xpath:') || rule.startsWith('//')) return _RuleType.xpath;
    if (rule.startsWith('@json:') || rule.startsWith('\$.')) return _RuleType.json;
    if (rule.startsWith('@js:')) return _RuleType.js;
    if (rule.startsWith(':')) return _RuleType.regex;
    if (rule.startsWith('\$.js')) return _RuleType.js;
    return _RuleType.defaultRule;
  }

  /// 去掉规则前缀
  String _stripPrefix(String rule) {
    if (rule.startsWith('@css:')) return rule.substring(5);
    if (rule.startsWith('@xpath:')) return rule.substring(7);
    if (rule.startsWith('@json:')) return rule.substring(6);
    if (rule.startsWith('@js:')) return rule.substring(4);
    return rule;
  }

  /// 处理URL中的{{key}}和{{page}}模板
  String _processUrlTemplate(String url, String keyword, int page) {
    String result = url;
    // 替换{{key}}
    result = result.replaceAll('{{key}}', Uri.encodeComponent(keyword));
    result = result.replaceAll('{{key}}', keyword);
    // 替换{{page}}
    result = result.replaceAll('{{page}}', page.toString());
    // 处理{{(page-1)*20}}等简单计算
    final pageCalc = RegExp(r'\{\{\(page-1\)\*(\d+)\}\}');
    result = result.replaceAllMapped(pageCalc, (m) {
      final perPage = int.parse(m.group(1)!);
      return ((page - 1) * perPage).toString();
    });
    return result;
  }

  /// 解析URL和选项（原版格式：url,{options}）
  Map<String, dynamic> _parseUrlWithOptions(String urlStr) {
    String url = urlStr;
    Map<String, dynamic> options = {};
    final commaIndex = urlStr.indexOf(',{');
    if (commaIndex > 0) {
      url = urlStr.substring(0, commaIndex);
      final optionsStr = urlStr.substring(commaIndex + 1);
      try {
        options = jsonDecode(optionsStr);
      } catch (_) {}
    }
    return {'url': url, 'options': options};
  }

  /// 发送HTTP请求
  Future<String> _fetch(String url, {Map<String, dynamic>? options, String? body}) async {
    final parsed = _parseUrlWithOptions(url);
    String finalUrl = parsed['url'];
    final opts = parsed['options'] as Map<String, dynamic>;

    // 处理相对URL
    if (finalUrl.startsWith('/')) {
      // 需要baseUrl，这里简化处理
    }

    final method = (opts['method'] ?? 'GET').toString().toUpperCase();
    final charset = opts['charset'] ?? 'utf-8';

    Options dioOptions = Options(
      method: method,
      headers: opts['headers'] != null
          ? Map<String, dynamic>.from(jsonDecode(opts['headers']))
          : null,
      responseType: ResponseType.plain,
    );

    if (method == 'POST') {
      final postBody = body ?? opts['body'] ?? '';
      final response = await _dio.post(finalUrl, data: postBody, options: dioOptions);
      return response.data.toString();
    } else {
      final response = await _dio.get(finalUrl, options: dioOptions);
      return response.data.toString();
    }
  }

  /// 从HTML中按规则提取字符串列表
  List<String> _getStringListFromHtml(dom.Document doc, String rule) {
    final type = _parseRuleType(rule);
    final cleanRule = _stripPrefix(rule);

    switch (type) {
      case _RuleType.css:
        try {
          final elements = doc.querySelectorAll(cleanRule);
          return elements.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toList();
        } catch (_) {
          return [];
        }
      case _RuleType.xpath:
      case _RuleType.defaultRule:
        return _defaultRuleExtractList(doc, cleanRule);
      default:
        return [];
    }
  }

  /// Default规则提取列表（class/id/tag格式）
  List<String> _defaultRuleExtractList(dom.Document doc, String rule) {
    // 处理 @ 分隔的多级规则
    final parts = rule.split('@');
    if (parts.isEmpty) return [];

    List<dom.Element> currentElements = [];
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;

      // 解析 type.name.index
      final match = RegExp(r'^(class|id|tag)\.([^.]+)(?:\.(\d+))?$').firstMatch(part);
      if (match == null) continue;

      final type = match.group(1)!;
      final name = match.group(2)!;
      final index = int.tryParse(match.group(3) ?? '');

      if (i == 0) {
        if (type == 'class') {
          currentElements = doc.getElementsByClassName(name);
        } else if (type == 'id') {
          final el = doc.getElementById(name);
          currentElements = el != null ? [el] : [];
        } else if (type == 'tag') {
          currentElements = doc.getElementsByTagName(name);
        }
      } else {
        List<dom.Element> next = [];
        for (final el in currentElements) {
          if (type == 'class') {
            next.addAll(el.getElementsByClassName(name));
          } else if (type == 'tag') {
            next.addAll(el.getElementsByTagName(name));
          }
        }
        currentElements = next;
      }

      if (index != null && currentElements.isNotEmpty) {
        if (index >= 0 && index < currentElements.length) {
          currentElements = [currentElements[index]];
        } else if (index < 0 && -index <= currentElements.length) {
          currentElements = [currentElements[currentElements.length + index]];
        }
      }
    }

    // 最后一部分可能是获取内容的方式（text/href/src等）
    final lastPart = parts.last;
    if (lastPart == 'text' || lastPart == 'textNodes' || lastPart == 'ownText') {
      return currentElements.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toList();
    } else if (lastPart == 'href') {
      return currentElements
          .map((e) => e.attributes['href'] ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (lastPart == 'src') {
      return currentElements
          .map((e) => e.attributes['src'] ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (lastPart == 'html') {
      return currentElements.map((e) => e.innerHtml).toList();
    }

    return currentElements.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// 从HTML中提取单个字符串
  String? _getStringFromHtml(dom.Document doc, String rule) {
    final list = _getStringListFromHtml(doc, rule);
    return list.isNotEmpty ? list.first : null;
  }

  /// 从JSON中按JSONPath提取
  dynamic _getJsonValue(dynamic json, String path) {
    if (path.isEmpty || json == null) return null;
    String cleanPath = path;
    if (cleanPath.startsWith('\$.')) cleanPath = cleanPath.substring(2);
    if (cleanPath.startsWith('\$')) cleanPath = cleanPath.substring(1);

    final parts = cleanPath.split('.');
    dynamic current = json;

    for (final part in parts) {
      if (current == null) return null;
      if (part.contains('[*]')) {
        // 数组通配
        final key = part.replaceAll('[*]', '');
        if (current is Map && current[key] is List) {
          return current[key]; // 返回整个列表
        }
        return null;
      } else if (part.contains('[')) {
        final match = RegExp(r'^([^\[]+)\[(\d+)\]$').firstMatch(part);
        if (match != null) {
          final key = match.group(1)!;
          final index = int.parse(match.group(2)!);
          if (current is Map && current[key] is List) {
            final list = current[key] as List;
            current = index < list.length ? list[index] : null;
          } else {
            return null;
          }
        }
      } else {
        if (current is Map) {
          current = current[part];
        } else {
          return null;
        }
      }
    }
    return current;
  }

  /// 从JSON中提取字符串列表
  List<String> _getStringListFromJson(dynamic json, String rule) {
    final value = _getJsonValue(json, rule);
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [value.toString()];
  }

  /// 从JSON中提取单个字符串
  String? _getStringFromJson(dynamic json, String rule) {
    final value = _getJsonValue(json, rule);
    if (value == null) return null;
    return value.toString();
  }

  /// 通用提取字符串列表（自动判断HTML或JSON）
  List<String> _extractList(String content, String rule, {bool isJson = false}) {
    if (rule.isEmpty) return [];
    final type = _parseRuleType(rule);

    if (isJson || type == _RuleType.json) {
      try {
        final json = jsonDecode(content);
        return _getStringListFromJson(json, _stripPrefix(rule));
      } catch (_) {
        return [];
      }
    }

    try {
      final doc = html_parser.parse(content);
      return _getStringListFromHtml(doc, rule);
    } catch (_) {
      return [];
    }
  }

  /// 通用提取单个字符串
  String? _extractString(String content, String rule, {bool isJson = false}) {
    final list = _extractList(content, rule, isJson: isJson);
    return list.isNotEmpty ? list.first : null;
  }

  /// 提取元素列表（用于搜索结果的书籍列表）
  List<Map<String, String>> _extractBookList(
      String content, Map<String, dynamic> rule, String baseUrl) {
    final bookListRule = rule['bookList'] ?? '';
    if (bookListRule.isEmpty) return [];

    final type = _parseRuleType(bookListRule);
    final isJson = type == _RuleType.json || _isJsonContent(content);

    if (isJson) {
      return _extractBookListFromJson(content, rule, baseUrl);
    } else {
      return _extractBookListFromHtml(content, rule, baseUrl);
    }
  }

  /// 判断内容是否为JSON
  bool _isJsonContent(String content) {
    final trimmed = content.trim();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }

  /// 从JSON提取书籍列表
  List<Map<String, String>> _extractBookListFromJson(
      String content, Map<String, dynamic> rule, String baseUrl) {
    try {
      final json = jsonDecode(content);
      final listValue = _getJsonValue(json, rule['bookList'] ?? '');
      if (listValue is! List) return [];

      return listValue.map((item) {
        if (item is! Map) return <String, String>{};
        return {
          'name': _getJsonValue(item, rule['name'] ?? '')?.toString() ?? '',
          'author': _getJsonValue(item, rule['author'] ?? '')?.toString() ?? '',
          'coverUrl': _getJsonValue(item, rule['coverUrl'] ?? '')?.toString() ?? '',
          'bookUrl': _resolveUrl(
              _getJsonValue(item, rule['bookUrl'] ?? '')?.toString() ?? '', baseUrl),
          'intro': _getJsonValue(item, rule['intro'] ?? '')?.toString() ?? '',
          'kind': _getJsonValue(item, rule['kind'] ?? '')?.toString() ?? '',
          'lastChapter':
              _getJsonValue(item, rule['lastChapter'] ?? '')?.toString() ?? '',
        };
      }).where((b) => b['name']!.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// 从HTML提取书籍列表
  List<Map<String, String>> _extractBookListFromHtml(
      String content, Map<String, dynamic> rule, String baseUrl) {
    try {
      final doc = html_parser.parse(content);
      final bookListRule = rule['bookList'] ?? '';
      final type = _parseRuleType(bookListRule);

      List<dom.Element> elements = [];
      if (type == _RuleType.css) {
        elements = doc.querySelectorAll(_stripPrefix(bookListRule));
      } else {
        // Default规则
        elements = _getElements(doc, _stripPrefix(bookListRule));
      }

      return elements.map((el) {
        return {
          'name': _extractFromElement(el, rule['name'] ?? '') ?? '',
          'author': _extractFromElement(el, rule['author'] ?? '') ?? '',
          'coverUrl': _extractAttrFromElement(el, rule['coverUrl'] ?? '', 'src') ?? '',
          'bookUrl': _resolveUrl(
              _extractAttrFromElement(el, rule['bookUrl'] ?? '', 'href') ?? '', baseUrl),
          'intro': _extractFromElement(el, rule['intro'] ?? '') ?? '',
          'kind': _extractFromElement(el, rule['kind'] ?? '') ?? '',
          'lastChapter': _extractFromElement(el, rule['lastChapter'] ?? '') ?? '',
        };
      }).where((b) => b['name']!.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// 从元素提取文本
  String? _extractFromElement(dom.Element el, String rule) {
    if (rule.isEmpty) return null;
    final type = _parseRuleType(rule);
    final clean = _stripPrefix(rule);

    if (type == _RuleType.css) {
      final found = el.querySelector(clean);
      return found?.text.trim();
    }
    // Default规则简化处理
    final parts = clean.split('@');
    dom.Element? current = el;
    for (final part in parts) {
      if (part.isEmpty) continue;
      final match = RegExp(r'^(class|id|tag)\.([^.]+)(?:\.(\d+))?$').firstMatch(part);
      if (match == null) {
        if (part == 'text') return current?.text.trim();
        continue;
      }
      final ptype = match.group(1)!;
      final name = match.group(2)!;
      if (ptype == 'class') {
        final list = current?.getElementsByClassName(name) ?? [];
        current = list.isNotEmpty ? list.first : null;
      } else if (ptype == 'tag') {
        final list = current?.getElementsByTagName(name) ?? [];
        current = list.isNotEmpty ? list.first : null;
      }
    }
    return current?.text.trim();
  }

  /// 从元素提取属性
  String? _extractAttrFromElement(dom.Element el, String rule, String defaultAttr) {
    if (rule.isEmpty) return null;
    final type = _parseRuleType(rule);
    final clean = _stripPrefix(rule);

    if (type == _RuleType.css) {
      // 检查规则是否以@href或@src结尾
      if (clean.endsWith('@href')) {
        final selector = clean.substring(0, clean.length - 5);
        return el.querySelector(selector)?.attributes['href'];
      }
      if (clean.endsWith('@src')) {
        final selector = clean.substring(0, clean.length - 4);
        return el.querySelector(selector)?.attributes['src'];
      }
      return el.querySelector(clean)?.text.trim();
    }
    return _extractFromElement(el, rule);
  }

  /// 获取HTML元素列表
  List<dom.Element> _getElements(dom.Document doc, String rule) {
    final parts = rule.split('@');
    if (parts.isEmpty) return [];
    List<dom.Element> current = [];
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;
      final match = RegExp(r'^(class|id|tag)\.([^.]+)(?:\.(\d+))?$').firstMatch(part);
      if (match == null) continue;
      final ptype = match.group(1)!;
      final name = match.group(2)!;
      if (i == 0) {
        if (ptype == 'class') current = doc.getElementsByClassName(name);
        if (ptype == 'tag') current = doc.getElementsByTagName(name);
        if (ptype == 'id') {
          final el = doc.getElementById(name);
          current = el != null ? [el] : [];
        }
      } else {
        List<dom.Element> next = [];
        for (final el in current) {
          if (ptype == 'class') next.addAll(el.getElementsByClassName(name));
          if (ptype == 'tag') next.addAll(el.getElementsByTagName(name));
        }
        current = next;
      }
    }
    return current;
  }

  /// 解析相对URL
  String _resolveUrl(String url, String baseUrl) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (baseUrl.isEmpty) return url;
    final uri = Uri.parse(baseUrl);
    if (url.startsWith('/')) {
      return '${uri.scheme}://${uri.host}$url';
    }
    final basePath = baseUrl.substring(0, baseUrl.lastIndexOf('/') + 1);
    return '$basePath$url';
  }

  // ==================== 公开API ====================

  /// 搜索书籍
  Future<List<SearchBook>> search(BookSource source, String keyword, {int page = 1}) async {
    if (source.searchUrl == null || source.searchUrl!.isEmpty) return [];
    if (source.ruleSearch == null) return [];

    try {
      final url = _processUrlTemplate(source.searchUrl!, keyword, page);
      final content = await _fetch(url);
      final books = _extractBookList(content, source.ruleSearch!, source.bookSourceUrl);

      return books.map((b) => SearchBook(
        name: b['name'] ?? '',
        author: b['author'] ?? '',
        coverUrl: b['coverUrl'] ?? '',
        bookUrl: b['bookUrl'] ?? '',
        intro: b['intro'] ?? '',
        kind: b['kind'] ?? '',
        lastChapter: b['lastChapter'] ?? '',
        originName: source.bookSourceName,
        origin: source.bookSourceUrl,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// 发现书籍
  Future<List<SearchBook>> explore(BookSource source, {int page = 1}) async {
    if (source.exploreUrl == null || source.exploreUrl!.isEmpty) return [];
    if (source.ruleExplore == null) return [];

    try {
      final url = _processUrlTemplate(source.exploreUrl!, '', page);
      final content = await _fetch(url);
      final books = _extractBookList(content, source.ruleExplore!, source.bookSourceUrl);

      return books.map((b) => SearchBook(
        name: b['name'] ?? '',
        author: b['author'] ?? '',
        coverUrl: b['coverUrl'] ?? '',
        bookUrl: b['bookUrl'] ?? '',
        intro: b['intro'] ?? '',
        kind: b['kind'] ?? '',
        lastChapter: b['lastChapter'] ?? '',
        originName: source.bookSourceName,
        origin: source.bookSourceUrl,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取书籍详情
  Future<Book?> getBookInfo(BookSource source, String bookUrl) async {
    try {
      final content = await _fetch(bookUrl);
      final rule = source.ruleBookInfo ?? {};
      final doc = html_parser.parse(content);
      final isJson = _isJsonContent(content);

      String name = '';
      String author = '';
      String coverUrl = '';
      String intro = '';
      String kind = '';
      String lastChapter = '';
      String tocUrl = bookUrl;

      if (isJson) {
        final json = jsonDecode(content);
        name = _getStringFromJson(json, rule['name'] ?? '') ?? '';
        author = _getStringFromJson(json, rule['author'] ?? '') ?? '';
        coverUrl = _getStringFromJson(json, rule['coverUrl'] ?? '') ?? '';
        intro = _getStringFromJson(json, rule['intro'] ?? '') ?? '';
        kind = _getStringFromJson(json, rule['kind'] ?? '') ?? '';
        lastChapter = _getStringFromJson(json, rule['lastChapter'] ?? '') ?? '';
        final toc = _getStringFromJson(json, rule['tocUrl'] ?? '');
        if (toc != null && toc.isNotEmpty) tocUrl = _resolveUrl(toc, source.bookSourceUrl);
      } else {
        name = _extractString(content, rule['name'] ?? '') ?? '';
        author = _extractString(content, rule['author'] ?? '') ?? '';
        coverUrl = _extractString(content, rule['coverUrl'] ?? '') ?? '';
        intro = _extractString(content, rule['intro'] ?? '') ?? '';
        kind = _extractString(content, rule['kind'] ?? '') ?? '';
        lastChapter = _extractString(content, rule['lastChapter'] ?? '') ?? '';
        final toc = _extractString(content, rule['tocUrl'] ?? '');
        if (toc != null && toc.isNotEmpty) tocUrl = _resolveUrl(toc, source.bookSourceUrl);
      }

      if (name.isEmpty) return null;

      return Book(
        name: name,
        author: author,
        coverUrl: coverUrl,
        intro: intro,
        kind: kind,
        lastChapter: lastChapter,
        noteUrl: tocUrl, bookUrl: bookUrl,
        originName: source.bookSourceName,
        origin: source.bookSourceUrl,
      );
    } catch (e) {
      return null;
    }
  }

  /// 获取章节目录
  Future<List<BookChapter>> getToc(BookSource source, String tocUrl) async {
    if (source.ruleToc == null) return [];

    try {
      final content = await _fetch(tocUrl);
      final rule = source.ruleToc!;
      final chapterListRule = rule['chapterList'] ?? '';
      if (chapterListRule.isEmpty) return [];

      final isJson = _isJsonContent(content);
      List<Map<String, String>> chapters = [];

      if (isJson) {
        final json = jsonDecode(content);
        final listValue = _getJsonValue(json, chapterListRule);
        if (listValue is List) {
          chapters = listValue.map((item) {
            if (item is! Map) return <String, String>{};
            return {
              'title': _getJsonValue(item, rule['chapterName'] ?? '')?.toString() ?? '',
              'url': _resolveUrl(
                  _getJsonValue(item, rule['chapterUrl'] ?? '')?.toString() ?? '',
                  source.bookSourceUrl),
            };
          }).toList();
        }
      } else {
        final doc = html_parser.parse(content);
        final type = _parseRuleType(chapterListRule);
        List<dom.Element> elements = [];

        if (type == _RuleType.css) {
          elements = doc.querySelectorAll(_stripPrefix(chapterListRule));
        } else {
          elements = _getElements(doc, _stripPrefix(chapterListRule));
        }

        chapters = elements.map((el) {
          return {
            'title': _extractFromElement(el, rule['chapterName'] ?? '') ?? el.text.trim(),
            'url': _resolveUrl(
                _extractAttrFromElement(el, rule['chapterUrl'] ?? '', 'href') ?? '',
                source.bookSourceUrl),
          };
        }).toList();
      }

      // 处理目录倒序（规则以-开头）
      if (chapterListRule.startsWith('-')) {
        chapters = chapters.reversed.toList();
      }

      return chapters.asMap().entries.map((e) => BookChapter(
        index: e.key,
        title: e.value['title'] ?? '',
        url: e.value['url'] ?? '',
      )).where((c) => c.title.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取正文内容
  Future<String?> getContent(BookSource source, String contentUrl,
      {List<ReplaceRule>? replaceRules}) async {
    if (source.ruleContent == null) return null;

    try {
      final content = await _fetch(contentUrl);
      final rule = source.ruleContent!;
      final contentRule = rule['content'] ?? '';
      if (contentRule.isEmpty) return null;

      String? result;
      final isJson = _isJsonContent(content);

      if (isJson) {
        final json = jsonDecode(content);
        result = _getStringFromJson(json, contentRule);
      } else {
        result = _extractString(content, contentRule);
      }

      if (result == null) return null;

      // 应用替换净化规则
      if (replaceRules != null && replaceRules.isNotEmpty) {
        result = _replaceService.applyRules(result, replaceRules,
            scope: source.bookSourceUrl);
      }

      // 清理HTML
      result = _cleanHtml(result);
      return result.trim();
    } catch (e) {
      return null;
    }
  }

  /// 清理HTML标签
  String _cleanHtml(String html) {
    // 移除script和style
    html = html.replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '');
    html = html.replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');
    // 转换段落
    html = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    html = html.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    html = html.replaceAll(RegExp(r'<[^>]+>'), '');
    // 解码HTML实体
    html = html
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    // 清理多余空行
    html = html.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return html.trim();
  }
}
