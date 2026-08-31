import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/book_source.dart';
import '../models/search_book.dart';
import '../models/book_chapter.dart';
import '../models/book.dart';
import '../models/replace_rule.dart';
import 'replace_rule_service.dart';

/// 规则类型
enum _RuleType { css, xpath, json, js, regex, none }

/// 严格兼容Legado原版规则格式的书源引擎
class BookSourceEngine {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    },
  ));

  final ReplaceRuleService _replaceService = ReplaceRuleService();

  _RuleType _parseRuleType(String rule) {
    if (rule.isEmpty) return _RuleType.none;
    if (rule.startsWith('@css:')) return _RuleType.css;
    if (rule.startsWith('@xpath:')) return _RuleType.xpath;
    if (rule.startsWith('@json:')) return _RuleType.json;
    if (rule.startsWith('@js:')) return _RuleType.js;
    if (rule.startsWith('@regex:')) return _RuleType.regex;
    if (rule.startsWith('\$.js')) return _RuleType.js;
    if (rule.startsWith('\$.')) return _RuleType.json;
    return _RuleType.css;
  }

  String _stripRulePrefix(String rule) {
    if (rule.startsWith('@css:')) return rule.substring(5);
    if (rule.startsWith('@xpath:')) return rule.substring(7);
    if (rule.startsWith('@json:')) return rule.substring(6);
    if (rule.startsWith('@js:')) return rule.substring(4);
    if (rule.startsWith('@regex:')) return rule.substring(7);
    if (rule.startsWith('\$.js')) return rule;
    if (rule.startsWith('\$.')) return rule.substring(2);
    return rule;
  }

  String? _extractText(dynamic doc, String? rule) {
    if (rule == null || rule.trim().isEmpty) return null;
    rule = rule.trim();
    final parts = rule.split('|').where((p) => p.trim().isNotEmpty).toList();
    if (parts.isEmpty) return null;

    dynamic current = doc;
    String? result;

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].trim();
      final type = _parseRuleType(part);

      switch (type) {
        case _RuleType.css:
          result = _extractByCss(current, _stripRulePrefix(part));
          break;
        case _RuleType.xpath:
          result = _extractByXPath(current, _stripRulePrefix(part));
          break;
        case _RuleType.json:
          result = _extractByJson(current, _stripRulePrefix(part));
          break;
        case _RuleType.js:
          result = _extractByJs(current, part);
          break;
        case _RuleType.regex:
          result = _extractByRegex(current, _stripRulePrefix(part));
          break;
        case _RuleType.none:
          return null;
      }

      if (result == null) return null;
      if (i < parts.length - 1) {
        try {
          current = html_parser.parse(result);
        } catch (_) {
          current = result;
        }
      }
    }
    return result;
  }

  String? _extractByCss(dynamic doc, String selector) {
    if (selector.isEmpty) {
      if (doc is dom.Document) return doc.body?.text;
      if (doc is dom.Element) return doc.text;
      return doc?.toString();
    }

    String sel = selector;
    String? attr;
    final atIndex = selector.lastIndexOf('@');
    if (atIndex > 0) {
      sel = selector.substring(0, atIndex);
      attr = selector.substring(atIndex + 1);
    }

    try {
      List<dom.Element> elements;
      if (doc is dom.Document) {
        elements = doc.querySelectorAll(sel);
      } else if (doc is dom.Element) {
        elements = doc.querySelectorAll(sel);
      } else {
        final parsed = html_parser.parse(doc.toString());
        elements = parsed.querySelectorAll(sel);
      }

      if (elements.isEmpty) return null;

      if (attr == null || attr == 'text' || attr.isEmpty) {
        return elements.map((e) => e.text.trim()).where((t) => t.isNotEmpty).join('\n');
      } else if (attr == 'html') {
        return elements.map((e) => e.innerHtml).join('\n');
      } else if (attr == 'ownText') {
        return elements.first.nodes.whereType<dom.Text>().map((t) => t.text).join().trim();
      } else if (attr == 'textNodes') {
        return elements.first.nodes.whereType<dom.Text>().map((t) => t.text).join('\n').trim();
      } else {
        return elements.first.attributes[attr];
      }
    } catch (e) {
      return null;
    }
  }

  String? _extractByXPath(dynamic doc, String xpath) {
    try {
      String css = xpath.replaceAll('//', ' ').replaceAll('/', ' > ').trim();
      css = css.replaceAllMapped(RegExp(r"\[@(\w+)='([^']+)'\]"), (m) => '[${m.group(1)}="${m.group(2)}"]');
      css = css.replaceAllMapped(RegExp(r'\[(\d+)\]'), (m) => ':nth-child(${m.group(1)})');
      return _extractByCss(doc, css);
    } catch (e) {
      return null;
    }
  }

  String? _extractByJson(dynamic doc, String path) {
    try {
      dynamic data;
      if (doc is String) {
        data = jsonDecode(doc);
      } else if (doc is dom.Document) {
        data = jsonDecode(doc.body?.text ?? '{}');
      } else if (doc is Map || doc is List) {
        data = doc;
      } else {
        data = jsonDecode(doc.toString());
      }

      String p = path;
      if (p.startsWith('\$.')) p = p.substring(2);
      if (p.startsWith('\$')) p = p.substring(1);
      if (p.isEmpty) return data?.toString();

      String? attr;
      final atIndex = p.lastIndexOf('@');
      if (atIndex > 0) {
        attr = p.substring(atIndex + 1);
        p = p.substring(0, atIndex);
      }

      final parts = p.split('.');
      dynamic current = data;

      for (final part in parts) {
        if (part.isEmpty) continue;
        final arrayMatch = RegExp(r'^(\w+)\[(\d+)\]$').firstMatch(part);
        if (arrayMatch != null) {
          final field = arrayMatch.group(1)!;
          final index = int.parse(arrayMatch.group(2)!);
          if (current is Map && current.containsKey(field)) {
            current = current[field];
            if (current is List && current.length > index) {
              current = current[index];
            } else {
              return null;
            }
          } else {
            return null;
          }
        } else if (current is Map && current.containsKey(part)) {
          current = current[part];
        } else if (current is List) {
          current = current.map((e) => e is Map ? e[part] : null).toList();
        } else {
          return null;
        }
      }

      if (current == null) return null;
      if (current is List) {
        return current.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).join('\n');
      }
      if (attr != null && current is Map) {
        return current[attr]?.toString();
      }
      return current.toString();
    } catch (e) {
      return null;
    }
  }

  String? _extractByJs(dynamic doc, String script) {
    try {
      String text;
      if (doc is dom.Document) {
        text = doc.body?.innerHtml ?? '';
      } else if (doc is dom.Element) {
        text = doc.innerHtml;
      } else {
        text = doc.toString();
      }

      String result = text;
      final jsMatch = RegExp(r'\$\.js\((.+)\)').firstMatch(script);
      String code = jsMatch?.group(1) ?? script;

      final replaceMatches = RegExp(r'''result\.replace\(/(.+?)/g?,\s*['"](.*?)['"]\)''').allMatches(code);
      for (final m in replaceMatches) {
        try {
          result = result.replaceAll(RegExp(m.group(1)!), m.group(2)!);
        } catch (_) {}
      }

      final matchMatch = RegExp(r"result\.match\(/(.+?)/\)\[(\d+)\]").firstMatch(code);
      if (matchMatch != null) {
        try {
          final m = RegExp(matchMatch.group(1)!).firstMatch(result);
          if (m != null) {
            final idx = int.parse(matchMatch.group(2)!);
            result = m.group(idx) ?? result;
          }
        } catch (_) {}
      }

      final splitMatch = RegExp(r'''result\.split\(['"](.+?)['"]\)\[(\d+)\]''').firstMatch(code);
      if (splitMatch != null) {
        try {
          final parts = result.split(splitMatch.group(1)!);
          final idx = int.parse(splitMatch.group(2)!);
          if (idx < parts.length) result = parts[idx];
        } catch (_) {}
      }

      final subMatch = RegExp(r'result\.substring\((\d+),?\s*(\d+)?\)').firstMatch(code);
      if (subMatch != null) {
        try {
          final start = int.parse(subMatch.group(1)!);
          final end = subMatch.group(2) != null ? int.parse(subMatch.group(2)!) : null;
          result = end != null ? result.substring(start, end) : result.substring(start);
        } catch (_) {}
      }

      return result;
    } catch (e) {
      return null;
    }
  }

  String? _extractByRegex(dynamic doc, String pattern) {
    try {
      String text;
      if (doc is dom.Document) {
        text = doc.body?.text ?? '';
      } else if (doc is dom.Element) {
        text = doc.text;
      } else {
        text = doc.toString();
      }

      String? group;
      final dollarMatch = RegExp(r'(.+?)\$(\d+)$').firstMatch(pattern);
      if (dollarMatch != null) {
        pattern = dollarMatch.group(1)!;
        group = dollarMatch.group(2);
      }

      final regex = RegExp(pattern, dotAll: true);
      final match = regex.firstMatch(text);
      if (match != null) {
        if (group != null) return match.group(int.parse(group));
        if (match.groupCount > 0) return match.group(1);
        return match.group(0);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  List<dynamic> _extractList(dynamic doc, String rule) {
    if (rule.isEmpty) return [];
    final type = _parseRuleType(rule);

    if (type == _RuleType.json) {
      return _extractJsonList(doc, _stripRulePrefix(rule));
    }

    try {
      String sel = _stripRulePrefix(rule);
      final atIndex = sel.lastIndexOf('@');
      if (atIndex > 0) sel = sel.substring(0, atIndex);

      if (type == _RuleType.xpath) {
        sel = sel.replaceAll('//', ' ').replaceAll('/', ' > ').trim();
      }

      if (doc is dom.Document) {
        return doc.querySelectorAll(sel);
      } else if (doc is dom.Element) {
        return doc.querySelectorAll(sel);
      } else {
        final parsed = html_parser.parse(doc.toString());
        return parsed.querySelectorAll(sel);
      }
    } catch (e) {
      return [];
    }
  }

  List<dynamic> _extractJsonList(dynamic doc, String path) {
    try {
      dynamic data;
      if (doc is String) {
        data = jsonDecode(doc);
      } else if (doc is dom.Document) {
        data = jsonDecode(doc.body?.text ?? '[]');
      } else {
        data = doc;
      }

      String p = path;
      if (p.startsWith('\$.')) p = p.substring(2);
      if (p.startsWith('\$')) p = p.substring(1);

      final parts = p.split('.');
      dynamic current = data;

      for (final part in parts) {
        if (part.isEmpty) continue;
        final arrayMatch = RegExp(r'^(\w+)\[(\d+)\]$').firstMatch(part);
        if (arrayMatch != null) {
          final field = arrayMatch.group(1)!;
          final index = int.parse(arrayMatch.group(2)!);
          if (current is Map) current = current[field];
          if (current is List && current.length > index) current = current[index];
        } else if (current is Map) {
          current = current[part];
        }
      }

      if (current is List) return current;
      return [];
    } catch (e) {
      return [];
    }
  }

  String? _extractFromElement(dynamic element, String rule) {
    if (rule.isEmpty) return null;
    final type = _parseRuleType(rule);

    if (type == _RuleType.json && element is Map) {
      return _extractByJson(element, _stripRulePrefix(rule));
    }

    if (element is! dom.Element) {
      return _extractText(element, rule);
    }

    try {
      String sel = _stripRulePrefix(rule);
      String? attr;
      final atIndex = sel.lastIndexOf('@');
      if (atIndex > 0) {
        attr = sel.substring(atIndex + 1);
        sel = sel.substring(0, atIndex);
      }

      dom.Element target = element;
      if (sel.isNotEmpty) {
        final found = element.querySelector(sel);
        if (found == null) return null;
        target = found;
      }

      if (attr == null || attr == 'text' || attr.isEmpty) return target.text.trim();
      if (attr == 'html') return target.innerHtml;
      if (attr == 'ownText') {
        return target.nodes.whereType<dom.Text>().map((t) => t.text).join().trim();
      }
      return target.attributes[attr];
    } catch (e) {
      return null;
    }
  }

  String? _resolveUrl(String base, String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    try {
      final baseUri = Uri.parse(base);
      return baseUri.resolve(url).toString();
    } catch (_) {
      return url;
    }
  }

  Future<List<SearchBook>> searchBooks(BookSource source, String keyword) async {
    final results = <SearchBook>[];
    if (source.searchUrl == null || source.searchUrl!.isEmpty) return results;

    try {
      String searchUrl = source.searchUrl!
          .replaceAll('{{key}}', Uri.encodeComponent(keyword))
          .replaceAll('{{searchKey}}', Uri.encodeComponent(keyword))
          .replaceAll('{{page}}', '1');

      String method = 'GET';
      String? body;
      Map<String, String>? headers;

      if (searchUrl.contains(',') && searchUrl.split(',').first.trim().toUpperCase() == 'POST') {
        final parts = searchUrl.split(',');
        method = 'POST';
        searchUrl = parts[1].trim();
        if (parts.length > 2) body = parts.sublist(2).join(',');
      }

      if (source.header != null && source.header!.isNotEmpty) {
        try {
          final headerJson = jsonDecode(source.header!);
          if (headerJson is Map) {
            headers = Map<String, String>.from(headerJson.map((k, v) => MapEntry(k.toString(), v.toString())));
          }
        } catch (_) {}
      }

      final options = Options(headers: headers);
      final Response response;
      if (method == 'POST') {
        response = await _dio.post(searchUrl, data: body ?? {'key': keyword}, options: options);
      } else {
        response = await _dio.get(searchUrl, options: options);
      }

      final contentType = response.headers.value('content-type') ?? '';
      dynamic doc;
      bool isJson = contentType.contains('json');

      if (isJson) {
        doc = response.data is String ? jsonDecode(response.data) : response.data;
      } else {
        doc = html_parser.parse(response.data.toString());
      }

      final listRule = source.ruleSearch ?? '';
      final items = _extractList(doc, listRule);

      for (final item in items) {
        final name = _extractFromElement(item, source.ruleSearchNoteUrl ?? '');
        final author = _extractFromElement(item, source.ruleSearchAuthor ?? '');
        final cover = _extractFromElement(item, source.ruleSearchCover ?? '');
        final intro = _extractFromElement(item, source.ruleSearchIntro ?? '');
        final kind = _extractFromElement(item, source.ruleSearchKind ?? '');
        final lastChapter = _extractFromElement(item, source.ruleSearchLastChapter ?? '');
        final noteUrl = _extractFromElement(item, source.ruleSearchNoteUrl ?? '');

        if (name != null && name.trim().isNotEmpty) {
          results.add(SearchBook(
            name: name.trim(),
            author: (author ?? '未知').trim(),
            coverUrl: _resolveUrl(source.bookSourceUrl, cover),
            intro: intro?.trim(),
            kind: kind?.trim(),
            lastChapter: lastChapter?.trim(),
            origin: source.bookSourceUrl,
            originName: source.bookSourceName,
            noteUrl: _resolveUrl(source.bookSourceUrl, noteUrl),
          ));
        }
      }
    } catch (e) {
      // 静默失败
    }
    return results;
  }

  Future<Book?> getBookInfo(BookSource source, String noteUrl) async {
    try {
      final response = await _dio.get(noteUrl);
      final contentType = response.headers.value('content-type') ?? '';
      dynamic doc = contentType.contains('json')
          ? (response.data is String ? jsonDecode(response.data) : response.data)
          : html_parser.parse(response.data.toString());

      final name = _extractText(doc, source.ruleBookName ?? '') ?? '';
      final author = _extractText(doc, source.ruleBookAuthor ?? '') ?? '未知';
      final cover = _extractText(doc, source.ruleBookCover ?? '');
      final intro = _extractText(doc, source.ruleBookIntro ?? '');
      final kind = _extractText(doc, source.ruleBookKind ?? '');
      final lastChapter = _extractText(doc, source.ruleBookLastChapter ?? '');

      if (name.trim().isEmpty) return null;

      return Book(
        name: name.trim(),
        author: author.trim(),
        coverUrl: _resolveUrl(source.bookSourceUrl, cover),
        intro: intro?.trim(),
        kind: kind?.trim(),
        lastChapter: lastChapter?.trim(),
        noteUrl: noteUrl,
        origin: source.bookSourceUrl,
        originName: source.bookSourceName,
        lastCheckTime: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<BookChapter>> getChapters(BookSource source, String tocUrl) async {
    final chapters = <BookChapter>[];
    try {
      final response = await _dio.get(tocUrl);
      final contentType = response.headers.value('content-type') ?? '';
      dynamic doc = contentType.contains('json')
          ? (response.data is String ? jsonDecode(response.data) : response.data)
          : html_parser.parse(response.data.toString());

      final nameRule = source.ruleTocName ?? '';
      final urlRule = source.ruleTocUrl ?? '';
      final listRule = source.ruleToc ?? '';

      if (listRule.isNotEmpty) {
        final items = _extractList(doc, listRule);
        for (int i = 0; i < items.length; i++) {
          final title = _extractFromElement(items[i], nameRule) ?? '第${i + 1}章';
          final url = _extractFromElement(items[i], urlRule) ?? '';
          chapters.add(BookChapter(
            title: title.trim(),
            url: _resolveUrl(source.bookSourceUrl, url) ?? '',
            index: i,
          ));
        }
      } else {
        final names = _extractTextList(doc, nameRule);
        final urls = _extractTextList(doc, urlRule);
        for (int i = 0; i < names.length; i++) {
          chapters.add(BookChapter(
            title: names[i].trim(),
            url: i < urls.length ? (_resolveUrl(source.bookSourceUrl, urls[i]) ?? '') : '',
            index: i,
          ));
        }
      }

      final nextRule = source.ruleTocNext ?? '';
      if (nextRule.isNotEmpty && chapters.isNotEmpty) {
        String? nextUrl = _extractText(doc, nextRule);
        int pageCount = 0;
        while (nextUrl != null && nextUrl.isNotEmpty && pageCount < 30) {
          nextUrl = _resolveUrl(source.bookSourceUrl, nextUrl);
          if (nextUrl == tocUrl) break;
          try {
            final nextResponse = await _dio.get(nextUrl!);
            final nextDoc = html_parser.parse(nextResponse.data.toString());
            final nextNames = _extractTextList(nextDoc, nameRule);
            final nextUrls = _extractTextList(nextDoc, urlRule);
            final baseIndex = chapters.length;
            for (int i = 0; i < nextNames.length; i++) {
              chapters.add(BookChapter(
                title: nextNames[i].trim(),
                url: i < nextUrls.length ? (_resolveUrl(source.bookSourceUrl, nextUrls[i]) ?? '') : '',
                index: baseIndex + i,
              ));
            }
            nextUrl = _extractText(nextDoc, nextRule);
          } catch (_) {
            break;
          }
          pageCount++;
        }
      }
    } catch (e) {
      // 解析失败
    }
    return chapters;
  }

  List<String> _extractTextList(dynamic doc, String rule) {
    if (rule.isEmpty) return [];
    final type = _parseRuleType(rule);

    if (type == _RuleType.json) {
      final list = _extractJsonList(doc, _stripRulePrefix(rule));
      return list.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }

    try {
      String sel = _stripRulePrefix(rule);
      String? attr;
      final atIndex = sel.lastIndexOf('@');
      if (atIndex > 0) {
        attr = sel.substring(atIndex + 1);
        sel = sel.substring(0, atIndex);
      }
      if (sel.isEmpty) return [];

      List<dom.Element> elements;
      if (doc is dom.Document) {
        elements = doc.querySelectorAll(sel);
      } else if (doc is dom.Element) {
        elements = doc.querySelectorAll(sel);
      } else {
        final parsed = html_parser.parse(doc.toString());
        elements = parsed.querySelectorAll(sel);
      }

      return elements.map((e) {
        if (attr == null || attr == 'text') return e.text.trim();
        if (attr == 'html') return e.innerHtml;
        return e.attributes[attr] ?? '';
      }).where((s) => s.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String?> getChapterContent(BookSource source, String contentUrl, {List<ReplaceRule>? replaceRules}) async {
    try {
      final response = await _dio.get(contentUrl);
      final contentType = response.headers.value('content-type') ?? '';
      dynamic doc = contentType.contains('json')
          ? (response.data is String ? jsonDecode(response.data) : response.data)
          : html_parser.parse(response.data.toString());

      final contentRule = source.ruleContent ?? '';
      var content = _extractText(doc, contentRule);

      if (content == null || content.trim().isEmpty) return null;

      final nextRule = source.ruleContentNext ?? '';
      if (nextRule.isNotEmpty) {
        String? nextUrl = _extractText(doc, nextRule);
        int pageCount = 0;
        while (nextUrl != null && nextUrl.isNotEmpty && pageCount < 15) {
          nextUrl = _resolveUrl(source.bookSourceUrl, nextUrl);
          if (nextUrl == contentUrl) break;
          try {
            final nextResponse = await _dio.get(nextUrl!);
            final nextDoc = html_parser.parse(nextResponse.data.toString());
            final nextContent = _extractText(nextDoc, contentRule);
            if (nextContent != null && nextContent.trim().isNotEmpty) {
              content = '$content\n\n$nextContent';
            }
            nextUrl = _extractText(nextDoc, nextRule);
          } catch (_) {
            break;
          }
          pageCount++;
        }
      }

      if (replaceRules != null && replaceRules.isNotEmpty && content != null) {
        content = _replaceService.applyRules(content, replaceRules, scope: source.bookSourceUrl);
      }

      if (content != null) {
        content = _cleanHtml(content);
        return content.trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  Future<List<Map<String, String>>> getExplore(BookSource source, String url) async {
    final results = <Map<String, String>>[];
    try {
      final response = await _dio.get(url);
      final doc = html_parser.parse(response.data.toString());
      final exploreRule = source.ruleExplore ?? '';
      final items = _extractList(doc, exploreRule);
      for (final item in items) {
        String name;
        String href;
        if (item is dom.Element) {
          name = item.text.trim();
          href = item.attributes['href'] ?? '';
        } else if (item is Map) {
          name = item['name']?.toString() ?? item['title']?.toString() ?? '';
          href = item['url']?.toString() ?? item['link']?.toString() ?? '';
        } else {
          name = item.toString();
          href = '';
        }
        if (name.isNotEmpty) {
          results.add({'name': name, 'url': _resolveUrl(source.bookSourceUrl, href) ?? href});
        }
      }
    } catch (e) {
      // 忽略
    }
    return results;
  }

  Future<bool> testSource(BookSource source) async {
    try {
      if (source.searchUrl == null || source.searchUrl!.isEmpty) return false;
      final results = await searchBooks(source, '测试');
      return results.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
