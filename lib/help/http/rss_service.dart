import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:enough_convert/enough_convert.dart';
import 'package:legado_md3/data/model/rss_source.dart';
import 'package:legado_md3/data/model/rss_article.dart';
import 'package:legado_md3/help/source/rule_pipeline.dart';

/// RSS订阅服务
class RssService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    responseType: ResponseType.bytes,
    followRedirects: true,
    validateStatus: (s) => s != null && s < 400,
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    },
  ));

  final RulePipeline _pipeline = RulePipeline();

  /// 获取RSS源内容
  Future<List<RssArticle>> fetchRss(RssSource source) async {
    final articles = <RssArticle>[];
    try {
      final content = await fetchRaw(source.url, header: source.header);
      if (content.isEmpty) return articles;

      // 标准 RSS 2.0
      articles.addAll(_parseRss(content, source));

      // Atom
      if (articles.isEmpty) articles.addAll(_parseAtom(content, source));

      // 用户自定义列表规则（网页型订阅源）
      if (articles.isEmpty &&
          (source.ruleArticles?.trim().isNotEmpty ?? false)) {
        articles.addAll(await _parseByRules(source, content));
      }

      // 通用网页抓取兜底
      if (articles.isEmpty) articles.addAll(_parseHtml(content, source));
    } catch (_) {
      // 解析失败
    }
    return articles;
  }

  /// 抓取原始页面文本（编辑页“规则补全”与测试复用），按 header/编码处理
  Future<String> fetchRaw(String url, {String? header}) async {
    try {
      final headers = <String, dynamic>{};
      if (header != null && header.trim().isNotEmpty) {
        try {
          final v = jsonDecode(header);
          if (v is Map) headers.addAll(v.map((k, val) => MapEntry(k.toString(), val)));
        } catch (_) {}
      }
      final resp = await _dio.get(url, options: Options(headers: headers));
      return _decode(resp.data ?? const <int>[], resp.headers.map);
    } catch (_) {
      return '';
    }
  }

  String _decode(List<int> bytes, Map<String, List<String>> headers) {
    var cs = '';
    final ct = (headers['content-type'] ?? headers['Content-Type'] ?? []).join(';').toLowerCase();
    final m = RegExp(r'charset=([a-z0-9\-]+)').firstMatch(ct);
    if (m != null) cs = m.group(1)!;
    if (cs.isEmpty) {
      final head = String.fromCharCodes(bytes.take(2048).map((b) => b & 0xff)).toLowerCase();
      final mm = RegExp(r'''charset=["']?([a-z0-9\-]+)''').firstMatch(head);
      if (mm != null) cs = mm.group(1)!;
    }
    cs = cs.toLowerCase();
    try {
      if (cs == 'gbk' || cs == 'gb2312' || cs == 'gb18030') return GbkCodec().decode(bytes);
      if (cs == 'big5') return Big5Codec().decode(bytes);
      if (cs == 'latin1' || cs == 'iso-8859-1') return latin1.decode(bytes);
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      try {
        return utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        try {
          return GbkCodec().decode(bytes);
        } catch (_) {
          return latin1.decode(bytes);
        }
      }
    }
  }

  /// 依据用户自定义规则抓取文章列表（支持 ruleNextPage 翻页，最多 5 页）
  Future<List<RssArticle>> _parseByRules(RssSource source, String firstContent) async {
    final out = <RssArticle>[];
    final seen = <String>{};
    var content = firstContent;
    var currentUrl = source.url;
    _pipeline.baseUrl = currentUrl;

    for (var page = 0; page < 5; page++) {
      final doc = html_parser.parse(content);
      final elements = _pipeline.selectElements(doc, source.ruleArticles!);
      for (final el in elements) {
        String? f(String? rule) =>
            (rule == null || rule.trim().isEmpty) ? null : _pipeline.fieldFromElement(el, rule);
        final title = (f(source.ruleTitle) ?? '').trim();
        var link = _resolveUrl(currentUrl, (f(source.ruleLink) ?? '').trim());
        if (title.isEmpty) continue;
        if (link.isEmpty) link = _resolveUrl(currentUrl, el.attributes['href'] ?? '');
        if (link.isNotEmpty && !seen.add(link)) continue;
        final desc = (f(source.ruleDescription) ?? '').trim();
        final pubRaw = f(source.rulePubDate);
        out.add(RssArticle(
          title: title,
          link: link,
          description: desc.isEmpty ? null : _cleanHtml(desc),
          pubDate: _parseDate(pubRaw),
          sourceName: source.name,
          sourceUrl: source.url,
        ));
      }

      final nextRule = source.ruleNextPage;
      if (nextRule == null || nextRule.trim().isEmpty) break;
      final next = _pipeline.extractStringFromRaw(content, nextRule);
      if (next == null || next.trim().isEmpty || next == currentUrl) break;
      final nextUrl = _resolveUrl(currentUrl, next.trim());
      if (nextUrl == currentUrl) break;
      currentUrl = nextUrl;
      _pipeline.baseUrl = currentUrl;
      content = await fetchRaw(currentUrl, header: source.header);
      if (content.isEmpty) break;
    }
    return out;
  }

  /// 解析RSS 2.0
  List<RssArticle> _parseRss(String content, RssSource source) {
    final articles = <RssArticle>[];
    try {
      final doc = html_parser.parse(content);
      final items = doc.querySelectorAll('item');
      for (final item in items) {
        final title = _getElementText(item, 'title');
        final link = _getElementText(item, 'link');
        final description = _getElementText(item, 'description');
        final pubDate = _getElementText(item, 'pubDate');
        final author = _getElementText(item, 'author');
        final category = _getElementText(item, 'category');

        if (title != null && title.isNotEmpty) {
          articles.add(RssArticle(
            title: title,
            link: link ?? '',
            description: _cleanHtml(description ?? ''),
            pubDate: _parseDate(pubDate),
            author: author,
            category: category,
            sourceName: source.name,
            sourceUrl: source.url,
          ));
        }
      }
    } catch (_) {}
    return articles;
  }

  /// 解析Atom
  List<RssArticle> _parseAtom(String content, RssSource source) {
    final articles = <RssArticle>[];
    try {
      final doc = html_parser.parse(content);
      final entries = doc.querySelectorAll('entry');
      for (final entry in entries) {
        final title = _getElementText(entry, 'title');
        final linkEl = entry.querySelector('link');
        final link = linkEl?.attributes['href'] ?? '';
        final summary = _getElementText(entry, 'summary');
        final content = _getElementText(entry, 'content');
        final updated = _getElementText(entry, 'updated');
        final authorEl = entry.querySelector('author name');
        final author = authorEl?.text;

        if (title != null && title.isNotEmpty) {
          articles.add(RssArticle(
            title: title,
            link: link,
            description: _cleanHtml(summary ?? content ?? ''),
            pubDate: _parseDate(updated),
            author: author,
            sourceName: source.name,
            sourceUrl: source.url,
          ));
        }
      }
    } catch (_) {}
    return articles;
  }

  /// 解析HTML（通用网页抓取）
  List<RssArticle> _parseHtml(String content, RssSource source) {
    final articles = <RssArticle>[];
    try {
      final doc = html_parser.parse(content);
      // 尝试常见的文章列表选择器
      final selectors = [
        'article', '.article-item', '.post-item', '.list-item',
        'li.article', 'div.item', '.news-item',
      ];
      for (final selector in selectors) {
        final items = doc.querySelectorAll(selector);
        if (items.isNotEmpty) {
          for (final item in items.take(20)) {
            final titleEl = item.querySelector('h1, h2, h3, h4, a.title, .title a');
            final title = titleEl?.text.trim();
            final link = titleEl?.attributes['href'] ?? item.querySelector('a')?.attributes['href'] ?? '';
            final desc = item.querySelector('.summary, .description, .excerpt, p')?.text.trim();

            if (title != null && title.isNotEmpty) {
              articles.add(RssArticle(
                title: title,
                link: _resolveUrl(source.url, link),
                description: desc ?? '',
                sourceName: source.name,
                sourceUrl: source.url,
              ));
            }
          }
          break;
        }
      }
    } catch (_) {}
    return articles;
  }

  String? _getElementText(dynamic element, String tag) {
    try {
      final el = element.querySelector(tag);
      return el?.text.trim();
    } catch (_) {
      return null;
    }
  }

  String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  int? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr).millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  String _resolveUrl(String base, String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    try {
      return Uri.parse(base).resolve(url).toString();
    } catch (_) {
      return url;
    }
  }

  /// 测试RSS源是否可用
  Future<bool> testSource(RssSource source) async {
    try {
      final articles = await fetchRss(source);
      return articles.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
