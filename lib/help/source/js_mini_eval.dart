/// 轻量书源 JS 子集求值器（不引入完整 JS 引擎）
///
/// 覆盖 Legado 书源中最高频的「result 清洗」写法：
///   result = <expr>; ...; result
///   result.replace(/a/g,'b') / replace('a','b') / replaceAll
///   result.trim() / result.split('x')[i] / substring / substr / slice
///   result.match(/re/) / indexOf / toLowerCase / toUpperCase
///   '前缀'+result+'后缀' 字符串拼接、result.length
///   JSON.parse(x).a.b[0]
/// 无法覆盖的（java.ajax、复杂函数/循环）返回 null，并由调用方回退。
import 'dart:convert';

class JsMiniEvaluator {
  final Map<String, dynamic> vars;
  JsMiniEvaluator({Map<String, dynamic>? initial}) : vars = Map.of(initial ?? const {});

  /// 求值入口；[fallbackResult] 作为内置 result 初值。
  static String? eval(String script, {String? result, String? key, int? page, String? baseUrl}) {
    try {
      final e = JsMiniEvaluator(initial: {
        if (result != null) 'result': result,
        if (result != null) 'java_result': result,
        if (key != null) 'key': key,
        if (page != null) 'page': page,
        if (baseUrl != null) 'baseUrl': baseUrl,
      });
      return e.run(script);
    } catch (_) {
      return null;
    }
  }

  String? run(String script) {
    var s = script.trim();
    if (s.isEmpty) return null;
    // 不支持的网络/复杂能力直接放弃
    if (RegExp(r'java\.(ajax|connect|post|get|head)|new\s+|function\s*\(|=>|\bfor\s*\(|\bwhile\s*\(').hasMatch(s)) {
      return null;
    }
    // 去掉末尾分号，按语句拆分
    final stmts = _splitStatements(s);
    dynamic last;
    for (var raw in stmts) {
      final stmt = raw.trim();
      if (stmt.isEmpty) continue;
      // var/let/const 声明
      final decl = RegExp(r'^(?:var|let|const)\s+([A-Za-z_$][\w$]*)\s*=\s*([\s\S]+)$').firstMatch(stmt);
      final assign = RegExp(r'^([A-Za-z_$][\w$]*)\s*=\s*([\s\S]+)$').firstMatch(stmt);
      if (decl != null) {
        vars[decl.group(1)!] = _evalExpr(decl.group(2)!.trim());
        last = vars[decl.group(1)!];
      } else if (assign != null && !_isComparison(stmt)) {
        vars[assign.group(1)!] = _evalExpr(assign.group(2)!.trim());
        last = vars[assign.group(1)!];
      } else {
        last = _evalExpr(stmt);
      }
    }
    // 优先返回 result
    if (vars['result'] != null) return _toStr(vars['result']);
    return last == null ? null : _toStr(last);
  }

  bool _isComparison(String stmt) => RegExp(r'===|!==|==|!=|>=|<=').hasMatch(stmt.split('=')[0]);

  List<String> _splitStatements(String s) {
    // 简单按分号拆分（忽略字符串/正则内分号）
    final out = <String>[];
    final buf = StringBuffer();
    String? q;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (q != null) {
        buf.write(ch);
        if (ch == '\\') { if (i + 1 < s.length) { buf.write(s[++i]); } continue; }
        if (ch == q) q = null;
        continue;
      }
      if (ch == "'" || ch == '"' || ch == '`') { q = ch; buf.write(ch); continue; }
      if (ch == ';') { out.add(buf.toString()); buf.clear(); continue; }
      buf.write(ch);
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  /// 求值表达式，支持字符串拼接与 result 链式方法
  dynamic _evalExpr(String expr) {
    expr = expr.trim();
    if (expr.isEmpty) return '';
    // return xxx
    final ret = RegExp(r'^return\s+([\s\S]+)$').firstMatch(expr);
    if (ret != null) expr = ret.group(1)!.trim();

    // 纯字符串字面量
    final lit = _readStringLiteral(expr, 0);
    if (lit != null && lit.end == expr.length) return lit.value;
    // 数字
    final numM = RegExp(r'^-?\d+(\.\d+)?$').firstMatch(expr);
    if (numM != null) return num.tryParse(expr) ?? expr;
    // true/false/null
    if (expr == 'true') return true;
    if (expr == 'false') return false;
    if (expr == 'null') return null;

    // 字符串拼接 a + b + ...
    if (expr.contains('+')) {
      final parts = _splitPlus(expr);
      if (parts.length > 1) {
        final sb = StringBuffer();
        for (final p in parts) {
          final v = _evalExpr(p.trim());
          if (v == null) continue;
          sb.write(_toStr(v));
        }
        return sb.toString();
      }
    }

    // 链式：base.method(...).method2(...)...  以及 [index] / .length
    final baseMatch = RegExp(r'^([A-Za-z_$][\w$]*)([\s\S]*)$').firstMatch(expr);
    if (baseMatch != null) {
      dynamic cur = vars[baseMatch.group(1)!] ?? baseMatch.group(1)!;
      return _evalChain(cur, baseMatch.group(2) ?? '');
    }
    // 括号包裹
    if (expr.startsWith('(') && expr.endsWith(')')) return _evalExpr(expr.substring(1, expr.length - 1));
    return vars[expr] ?? expr;
  }

  /// 处理 .xxx(...) 链与 [i]、.length
  dynamic _evalChain(dynamic cur, String chain) {
    var i = 0;
    while (i < chain.length) {
      final ch = chain[i];
      if (ch == '.') {
        final m = RegExp(r'^\.([A-Za-z_$][\w$]*)').firstMatch(chain.substring(i));
        if (m == null) { i++; continue; }
        final name = m.group(1)!;
        i += m.group(0)!.length;
        if (i < chain.length && chain[i] == '(') {
          final args = _readParens(chain, i);
          i = args.end;
          cur = _applyMethod(cur, name, args.args);
        } else if (name == 'length') {
          cur = _toStr(cur).length;
        } else if (name == 'toString') {
          cur = _toStr(cur);
        } else {
          // 属性（如 JSON.parse 后的 .a）
          if (cur is Map) cur = cur[name];
          i++;
        }
      } else if (ch == '[') {
        final end = chain.indexOf(']', i);
        if (end < 0) break;
        final idxExpr = chain.substring(i + 1, end).trim();
        final idx = int.tryParse(idxExpr);
        if (idx != null && cur is List && idx < cur.length) {
          cur = cur[idx];
        } else if (cur is Map) {
          cur = cur[idxExpr];
        }
        i = end + 1;
      } else {
        i++;
      }
    }
    return cur;
  }

  dynamic _applyMethod(dynamic target, String name, List<String> rawArgs) {
    final str = _toStr(target);
    final args = rawArgs.map(_evalExpr).toList();
    switch (name) {
      case 'trim': return str.trim();
      case 'toString': return str;
      case 'toLowerCase': case 'toLocaleLowerCase': return str.toLowerCase();
      case 'toUpperCase': case 'toLocaleUpperCase': return str.toUpperCase();
      case 'replace':
      case 'replaceAll':
        return _replace(str, args, global: name == 'replaceAll');
      case 'split':
        final sep = _toStr(args.isNotEmpty ? args[0] : '');
        return sep.isEmpty ? str.split('') : str.split(sep);
      case 'substring':
      case 'substr':
      case 'slice':
        final a = args.isNotEmpty ? (args[0] as num?)?.toInt() ?? 0 : 0;
        if (args.length >= 2 && args[1] != null) {
          final b = (args[1] as num?)!.toInt();
          if (name == 'substring') return str.substring(a.clamp(0, str.length), b.clamp(0, str.length));
          return str.substring(a.clamp(0, str.length), (a + b).clamp(0, str.length)); // substr 第二参为长度
        }
        return str.substring(a.clamp(0, str.length));
      case 'indexOf':
        return str.indexOf(_toStr(args.isNotEmpty ? args[0] : ''));
      case 'lastIndexOf':
        return str.lastIndexOf(_toStr(args.isNotEmpty ? args[0] : ''));
      case 'includes': case 'contains':
        return str.contains(_toStr(args.isNotEmpty ? args[0] : ''));
      case 'startsWith': return str.startsWith(_toStr(args.isNotEmpty ? args[0] : ''));
      case 'endsWith': return str.endsWith(_toStr(args.isNotEmpty ? args[0] : ''));
      case 'match':
        final re = _toRegex(args.isNotEmpty ? args[0] : '');
        if (re == null) return null;
        final m = re.firstMatch(str);
        return m == null ? null : (m.groupCount >= 1 ? (m.group(1) ?? m.group(0)) : m.group(0));
      case 'matchAll':
        final re = _toRegex(args.isNotEmpty ? args[0] : '');
        return re == null ? const [] : re.allMatches(str).map((m) => m.group(0)!).toList();
      case 'join':
        if (target is List) return target.join(_toStr(args.isNotEmpty ? args[0] : ''));
        return str;
      case 'parse': // JSON.parse
        if (target.toString() == 'JSON') {
          try { return _jsonDecodeLoose(_toStr(args.isNotEmpty ? args[0] : '')); } catch (_) { return null; }
        }
        return str;
      case 'stringify': // JSON.stringify
        try { return _jsonEncodeLoose(args.isNotEmpty ? args[0] : target); } catch (_) { return str; }
      default:
        return str;
    }
  }

  String _replace(String str, List<dynamic> args, {required bool global}) {
    if (args.isEmpty) return str;
    final replacement = args.length >= 2 ? _toStr(args[1]) : '';
    final search = args[0];
    // /regex/flags
    if (search is String && search.startsWith('/')) {
      final re = _toRegex(search);
      if (re != null) return str.replaceAll(re, replacement);
    }
    final from = _toStr(search);
    return global ? str.replaceAll(from, replacement) : str.replaceFirst(from, replacement);
  }

  RegExp? _toRegex(dynamic v) {
    var s = _toStr(v);
    if (!s.startsWith('/')) return RegExp(s.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}'));
    final lastSlash = s.lastIndexOf('/');
    if (lastSlash <= 0) return null;
    final body = s.substring(1, lastSlash);
    final flags = s.substring(lastSlash + 1);
    return RegExp(body, multiLine: flags.contains('m'), caseSensitive: !flags.contains('i'), dotAll: flags.contains('s'));
  }

  // ---- 基础工具 ----
  List<String> _splitPlus(String expr) {
    final out = <String>[];
    final buf = StringBuffer();
    String? q;
    var depth = 0;
    for (var i = 0; i < expr.length; i++) {
      final ch = expr[i];
      if (q != null) {
        buf.write(ch);
        if (ch == '\\') { if (i + 1 < expr.length) buf.write(expr[++i]); continue; }
        if (ch == q) q = null;
        continue;
      }
      if (ch == "'" || ch == '"' || ch == '`') { q = ch; buf.write(ch); continue; }
      if (ch == '(' || ch == '[') depth++;
      if (ch == ')' || ch == ']') depth--;
      if (ch == '+' && depth == 0) { out.add(buf.toString()); buf.clear(); continue; }
      buf.write(ch);
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  _Parens _readParens(String s, int openIdx) {
    var depth = 0;
    String? q;
    final args = <String>[];
    final buf = StringBuffer();
    for (var i = openIdx; i < s.length; i++) {
      final ch = s[i];
      if (q != null) {
        buf.write(ch);
        if (ch == '\\') { if (i + 1 < s.length) buf.write(s[++i]); continue; }
        if (ch == q) q = null;
        continue;
      }
      if (ch == "'" || ch == '"' || ch == '`') { q = ch; buf.write(ch); continue; }
      if (ch == '(') { depth++; if (depth == 1) { buf.clear(); continue; } }
      if (ch == ')') {
        depth--;
        if (depth == 0) { if (buf.toString().trim().isNotEmpty) args.add(buf.toString().trim()); return _Parens(args, i + 1); }
      }
      if (ch == ',' && depth == 1) { args.add(buf.toString().trim()); buf.clear(); continue; }
      buf.write(ch);
    }
    return _Parens(args, s.length);
  }

  _Lit? _readStringLiteral(String s, int start) {
    if (start >= s.length) return null;
    final q = s[start];
    if (q != "'" && q != '"' && q != '`') return null;
    final buf = StringBuffer();
    var i = start + 1;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '\\') {
        if (i + 1 < s.length) {
          final n = s[i + 1];
          buf.write(const {'n': '\n', 't': '\t', 'r': '\r'}[n] ?? n);
          i += 2; continue;
        }
      }
      if (ch == q) return _Lit(buf.toString(), i + 1);
      buf.write(ch);
      i++;
    }
    return null;
  }
  dynamic _jsonDecodeLoose(String s) {
    // 兼容 JS 对象的单引号/无引号键
    final normalized = s
        .replaceAllMapped(RegExp(r"([{,]\s*)([A-Za-z_$][\w$]*)\s*:"), (m) => '${m[1]}"${m[2]}":')
        .replaceAll("'", '"');
    return jsonDecode(normalized);
  }

  String _jsonEncodeLoose(dynamic v) => jsonEncode(v);

  String _toStr(dynamic v) => v == null ? '' : v.toString();
}

class _Parens { final List<String> args; final int end; _Parens(this.args, this.end); }
class _Lit { final String value; final int end; _Lit(this.value, this.end); }
