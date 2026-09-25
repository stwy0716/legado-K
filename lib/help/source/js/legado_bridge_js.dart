/// 注入到无头 WebView（V8）中的 legado 兼容桥。
///
/// 对齐 legado（legado/app/src/main/java/io/legado/app/help/JsExtensions.kt
/// 与 AnalyzeUrl / AnalyzeRule）在书源脚本里使用的运行时环境：
///
///   * 全局对象：java / cookie / source / book / cache / result / key / page / baseUrl
///   * java.ajax / get / post / connect —— 以「同步 XHR」实现，由原生
///     shouldInterceptRequest 接管发请求（绕过 CORS、统一 Cookie/编码）。
///   * source.getVariable/setVariable/getLoginInfo/putLoginInfo
///   * cookie.getCookie/setCookie/removeCookie/getKey
///   * cache / java.put / java.get 跨阶段键值
///   * 编码：base64、hex；时间格式化；deviceID/androidId；UA
///   * startBrowser* / showBrowser* / reLoginView —— 走原生可见 WebView 交互登录
///
/// 该脚本在每个书源的无头 WebView 创建后于「全局作用域」执行一次；
/// 书源的 jsLib / loginUrl 随后也在全局作用域执行（定义全局函数）。
class LegadoBridgeJs {
  static const String code = r'''
(function () {
  if (globalThis.__legadoBridgeReady) return;
  globalThis.__legadoBridgeReady = true;

  var __state = {
    meta: { url: "", name: "", httpUrl: "" },
    variable: "",
    variableComment: "",
    lastUpdateTime: 0,
    loginInfo: "",
    kv: {},
    cookies: {},
    logs: [],
    toasts: [],
    hosts: [],
    browser: [],
    deviceId: "",
    ua: (typeof navigator !== "undefined" && navigator.userAgent) ? navigator.userAgent :
        "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
  };
  globalThis.__state = __state;
  globalThis.__pendings = {};

  // ---- Rhino（legado 安卓）Java 互操作垫片：V8 无 Java，
  // 让 jsLib 顶部的 JavaImporter/CompatibilityUtils 能安全加载；
  // 真正访问 Packages.xxx 的分支会抛错并被书源自身 try/catch 捕获后回退。----
  function JavaImporterShim() { this.importClass = function () {}; this.importPackage = function () {}; }
  globalThis.JavaImporter = JavaImporterShim;
  globalThis.importClass = function () {};
  globalThis.importPackage = function () {};
  // 任意 Packages.xxx 取值返回 null：hasJavaClass 判定为 false、new Packages.x() 抛错（被捕获）
  globalThis.Packages = new Proxy({}, { get: function () { return null; } });

  function __hostOf(url) {
    if (!url) return "";
    var s = String(url).trim();
    try {
      if (/^https?:\/\//i.test(s)) {
        return new URL(s).host.replace(/:\d+$/, "");
      }
      if (s.indexOf("/") < 0 && s.indexOf(".") >= 0) {
        return s.replace(/:\d+$/, "").replace(/^\/+/, "");
      }
    } catch (e) {}
    return s.replace(/^https?:\/\//i, "").replace(/^\/+/, "").split("/")[0].replace(/:\d+$/, "");
  }

  function __matchCookieHost(host) {
    if (!host) return "";
    if (__state.cookies[host]) return host;
    var keys = Object.keys(__state.cookies);
    for (var i = 0; i < keys.length; i++) {
      var k = keys[i];
      if (host === k || host.endsWith("." + k) || k.endsWith("." + host)) return k;
    }
    return "";
  }

  function __parseCookiePairs(str) {
    var out = {};
    String(str || "").split(/;|\n/).forEach(function (part) {
      var p = part.trim();
      if (!p) return;
      var idx = p.indexOf("=");
      if (idx <= 0) return;
      var name = p.substring(0, idx).trim();
      if (/^(path|domain|expires|max-age|secure|httponly|samesite)$/i.test(name)) return;
      out[name] = p.substring(idx + 1).trim();
    });
    return out;
  }

  // 多条 Set-Cookie 在 XHR getResponseHeader 里被合并为一行，属性（Path/Domain…）
  // 与逗号分隔相邻。先按「属性名=」回溯切分，再逐条解析，避免同名 cookie 互相覆盖。
  function __splitSetCookieLines(header) {
    var s = String(header || "");
    var out = [];
    var last = 0;
    var re = /[,;]/g, m;
    while ((m = re.exec(s)) !== null) {
      var after = s.slice(m.index + 1).trimStart();
      if (/^(expires|path|domain|max-age|samesite|secure|httponly)/i.test(after)) continue;
      out.push(s.slice(last, m.index));
      last = m.index + 1;
    }
    out.push(s.slice(last));
    return out.filter(function (x) { return x.trim().length > 0; });
  }

  function __ingestSetCookie(url, setCookieHeader) {
    if (!setCookieHeader) return;
    var host = __hostOf(url);
    var jar = __parseCookiePairs(__state.cookies[host] || "");
    var lines = __splitSetCookieLines(setCookieHeader);
    lines.forEach(function (line) {
      var fresh = __parseCookiePairs(line);
      Object.keys(fresh).forEach(function (k) { jar[k] = fresh[k]; });
    });
    __state.cookies[host] = Object.keys(jar).map(function (k) { return k + "=" + jar[k]; }).join("; ");
  }

  function __resolve(url, base) {
    var s = String(url == null ? "" : url).trim();
    if (!s) return s;
    if (/^https?:\/\//i.test(s) || s.indexOf("data:") === 0 || s.indexOf("javascript:") === 0) return s;
    if (s.indexOf("//") === 0) return "https:" + s;
    var b = base || __state.meta.httpUrl || "";
    try {
      if (b) return new URL(s, b).toString();
    } catch (e) {}
    return s;
  }

  function __b64Unicode(str) {
    var bytes = new TextEncoder().encode(String(str));
    var bin = "";
    for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    return btoa(bin);
  }
  function __unb64Unicode(str) {
    var bin = atob(String(str));
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return new TextDecoder("utf-8").decode(bytes);
  }
  function __hexToBytes(hex) {
    var h = String(hex).replace(/[^0-9a-fA-F]/g, "");
    var out = new Uint8Array(Math.floor(h.length / 2));
    for (var i = 0; i < out.length; i++) out[i] = parseInt(h.substr(i * 2, 2), 16);
    return out;
  }
  function __bytesToHex(bytes) {
    var s = "";
    for (var i = 0; i < bytes.length; i++) s += ("0" + bytes[i].toString(16)).slice(-2);
    return s;
  }

  // ---- AES（基于注入的 aes-js；ECB/CBC + PKCS7，同步）----
  function __b64ToBytes(b64) {
    var bin = atob(String(b64));
    var out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }
  // 用标准 TextEncoder/Decoder（aes-js 自带 utf8 工具对 4 字节字符处理有缺陷）
  function __utf8ToBytes(s) {
    return new Uint8Array(new TextEncoder().encode(String(s)));
  }
  function __bytesToUtf8(b) {
    return new TextDecoder("utf-8").decode(b);
  }
  function __aesKeyBytes(key) {
    var kb = __utf8ToBytes(String(key));
    var sizes = [16, 24, 32];
    for (var i = 0; i < sizes.length; i++) {
      if (kb.length <= sizes[i]) {
        var out = new Uint8Array(sizes[i]);
        out.set(kb);
        return out;
      }
    }
    return Uint8Array.from(kb.slice(0, 32));
  }
  function __aesIv(iv) {
    var b = __utf8ToBytes(String(iv || ""));
    var out = new Uint8Array(16);
    out.set(b.slice(0, 16));
    return out;
  }
  function __unpadPkcs7(bytes) {
    try {
      var p = bytes[bytes.length - 1];
      if (p > 0 && p <= 16) {
        for (var i = bytes.length - p; i < bytes.length; i++) {
          if (bytes[i] !== p) return bytes;
        }
        return bytes.slice(0, bytes.length - p);
      }
    } catch (e) {}
    return bytes;
  }
  function __aesDecryptToString(data, key, transformation, iv) {
    var cipher = __b64ToBytes(data);
    var kb = __aesKeyBytes(key);
    var mode = String(transformation || "AES/ECB/PKCS7Padding").toUpperCase();
    var dec;
    if (mode.indexOf("CBC") >= 0) {
      dec = new aesjs.ModeOfOperation.cbc(kb, __aesIv(iv)).decrypt(cipher);
    } else {
      dec = new aesjs.ModeOfOperation.ecb(kb).decrypt(cipher);
    }
    dec = __unpadPkcs7(dec);
    return __bytesToUtf8(dec);
  }
  function __aesEncryptToString(text, key, transformation, iv) {
    var kb = __aesKeyBytes(key);
    var data = __utf8ToBytes(String(text));
    var pad = 16 - (data.length % 16);
    var padded = new Uint8Array(data.length + pad);
    padded.set(data);
    for (var i = data.length; i < padded.length; i++) padded[i] = pad;
    var mode = String(transformation || "AES/ECB/PKCS7Padding").toUpperCase();
    var enc;
    if (mode.indexOf("CBC") >= 0) {
      enc = new aesjs.ModeOfOperation.cbc(kb, __aesIv(iv)).encrypt(padded);
    } else {
      enc = new aesjs.ModeOfOperation.ecb(kb).encrypt(padded);
    }
    var bin = "";
    for (var j = 0; j < enc.length; j++) bin += String.fromCharCode(enc[j]);
    return btoa(bin);
  }

  // ---- MD5（RFC 1321 公共域实现，返回小写 hex）----
  function __md5(str) {
    function rl(n, c) { return (n << c) | (n >>> (32 - c)); }
    function au(x, y) {
      var l = (x & 0xFFFF) + (y & 0xFFFF);
      var m = (x >> 16) + (y >> 16) + (l >> 16);
      return (m << 16) | (l & 0xFFFF);
    }
    function cm(q, a, b, x, s, t) { return au(rl(au(au(a, q), au(x, t)), s), b); }
    function ff(a, b, c, d, x, s, t) { return cm((b & c) | (~b & d), a, b, x, s, t); }
    function gg(a, b, c, d, x, s, t) { return cm((b & d) | (c & ~d), a, b, x, s, t); }
    function hh(a, b, c, d, x, s, t) { return cm(b ^ c ^ d, a, b, x, s, t); }
    function ii(a, b, c, d, x, s, t) { return cm(c ^ (b | ~d), a, b, x, s, t); }
    function tb(s) {
      var n = s.length, a = [];
      for (var i = 0; i < n * 8; i += 8) a[i >> 5] |= (s.charCodeAt(i / 8) & 0xFF) << (i % 32);
      a[(n * 8) >> 5] |= 0x80 << ((n * 8) % 32);
      a[(((n * 8) + 64) >>> 9 << 4) + 14] = n * 8;
      return a;
    }
    function th(n) {
      var s = "0123456789abcdef", r = "";
      for (var i = 0; i < 4; i++) r += s.charAt((n >> (i * 8 + 4)) & 0xF) + s.charAt((n >> (i * 8)) & 0xF);
      return r;
    }
    var bytes = new TextEncoder().encode(String(str));
    var binStr = "";
    for (var i = 0; i < bytes.length; i++) binStr += String.fromCharCode(bytes[i]);
    var x = tb(binStr);
    var a = 1732584193, b = -271733879, c = -1732584194, d = 271733878;
    for (var k = 0; k < x.length; k += 16) {
      var AA = a, BB = b, CC = c, DD = d;
      a = ff(a, b, c, d, x[k], 7, -680876936); d = ff(d, a, b, c, x[k + 1], 12, -389564586);
      c = ff(c, d, a, b, x[k + 2], 17, 606105819); b = ff(b, c, d, a, x[k + 3], 22, -1044525330);
      a = ff(a, b, c, d, x[k + 4], 7, -176418897); d = ff(d, a, b, c, x[k + 5], 12, 1200080426);
      c = ff(c, d, a, b, x[k + 6], 17, -1473231341); b = ff(b, c, d, a, x[k + 7], 22, -45705983);
      a = ff(a, b, c, d, x[k + 8], 7, 1770035416); d = ff(d, a, b, c, x[k + 9], 12, -1958414417);
      c = ff(c, d, a, b, x[k + 10], 17, -42063); b = ff(b, c, d, a, x[k + 11], 22, -1990404162);
      a = ff(a, b, c, d, x[k + 12], 7, 1804603682); d = ff(d, a, b, c, x[k + 13], 12, -40341101);
      c = ff(c, d, a, b, x[k + 14], 17, -1502002290); b = ff(b, c, d, a, x[k + 15], 22, 1236535329);
      a = gg(a, b, c, d, x[k + 1], 5, -165796510); d = gg(d, a, b, c, x[k + 6], 9, -1069501632);
      c = gg(c, d, a, b, x[k + 11], 14, 643717713); b = gg(b, c, d, a, x[k], 20, -373897302);
      a = gg(a, b, c, d, x[k + 5], 5, -701558691); d = gg(d, a, b, c, x[k + 10], 9, 38016083);
      c = gg(c, d, a, b, x[k + 15], 14, -660478335); b = gg(b, c, d, a, x[k + 4], 20, -405537848);
      a = gg(a, b, c, d, x[k + 9], 5, 568446438); d = gg(d, a, b, c, x[k + 14], 9, -1019803690);
      c = gg(c, d, a, b, x[k + 3], 14, -187363961); b = gg(b, c, d, a, x[k + 8], 20, 1163531501);
      a = gg(a, b, c, d, x[k + 13], 5, -1444681467); d = gg(d, a, b, c, x[k + 2], 9, -51403784);
      c = gg(c, d, a, b, x[k + 7], 14, 1735328473); b = gg(b, c, d, a, x[k + 12], 20, -1926607734);
      a = hh(a, b, c, d, x[k + 5], 4, -378558); d = hh(d, a, b, c, x[k + 8], 11, -3491214830);
      c = hh(c, d, a, b, x[k + 11], 16, -2022574463); b = hh(b, c, d, a, x[k + 14], 23, 1839030562);
      a = hh(a, b, c, d, x[k + 1], 4, -35309556); d = hh(d, a, b, c, x[k + 4], 11, -1530992060);
      c = hh(c, d, a, b, x[k + 7], 16, 1272893353); b = hh(b, c, d, a, x[k + 10], 23, -155497632);
      a = hh(a, b, c, d, x[k + 13], 4, -1094730640); d = hh(d, a, b, c, x[k], 11, 681279174);
      c = hh(c, d, a, b, x[k + 3], 16, -358537222); b = hh(b, c, d, a, x[k + 6], 23, -722521979);
      a = hh(a, b, c, d, x[k + 9], 4, 76029189); d = hh(d, a, b, c, x[k + 12], 11, -640364487);
      c = hh(c, d, a, b, x[k + 15], 16, -421815835); b = hh(b, c, d, a, x[k + 2], 23, 530742520);
      a = ii(a, b, c, d, x[k], 6, -995338651); d = ii(d, a, b, c, x[k + 7], 10, -198630844);
      c = ii(c, d, a, b, x[k + 14], 15, 1126891415); b = ii(b, c, d, a, x[k + 5], 21, -1416354905);
      a = ii(a, b, c, d, x[k + 12], 6, -57434055); d = ii(d, a, b, c, x[k + 3], 10, 1700485571);
      c = ii(c, d, a, b, x[k + 10], 15, -1894986606); b = ii(b, c, d, a, x[k + 1], 21, -1051523);
      a = ii(a, b, c, d, x[k + 8], 6, -2054922799); d = ii(d, a, b, c, x[k + 15], 10, 1873313359);
      c = ii(c, d, a, b, x[k + 6], 15, -30611744); b = ii(b, c, d, a, x[k + 13], 21, -1560198380);
      a = ii(a, b, c, d, x[k + 4], 6, 1309151649); d = ii(d, a, b, c, x[k + 11], 10, -145523070);
      c = ii(c, d, a, b, x[k + 2], 15, -1120210379); b = ii(b, c, d, a, x[k + 9], 21, 718787259);
      a = au(a, AA); b = au(b, BB); c = au(c, CC); d = au(d, DD);
    }
    return th(a) + th(b) + th(c) + th(d);
  }

  // ---- HMAC-SHA256（纯 JS，供 createSymmetricCrypto 的 AES/GCM 派生等场景备用）----
  function __pkcs7PadBytes(bytes, blockSize) {
    var pad = blockSize - (bytes.length % blockSize);
    var out = new Uint8Array(bytes.length + pad);
    out.set(bytes);
    for (var i = bytes.length; i < out.length; i++) out[i] = pad;
    return out;
  }
  function __aesEncryptBytes(padded, key, mode, iv) {
    if (mode.indexOf("CBC") >= 0) return new aesjs.ModeOfOperation.cbc(key, iv).encrypt(padded);
    return new aesjs.ModeOfOperation.ecb(key).encrypt(padded);
  }
  function __aesDecryptBytes(cipherBytes, key, mode, iv) {
    if (mode.indexOf("CBC") >= 0) return new aesjs.ModeOfOperation.cbc(key, iv).decrypt(cipherBytes);
    return new aesjs.ModeOfOperation.ecb(key).decrypt(cipherBytes);
  }
  function __symEncryptToBase64(text, key, transformation, iv) {
    var mode = String(transformation || "AES").toUpperCase();
    var kb = __aesKeyBytes(key);
    var data = __utf8ToBytes(String(text));
    var padded = __pkcs7PadBytes(data, 16);
    var enc = __aesEncryptBytes(padded, kb, mode, __aesIv(iv));
    var bin = "";
    for (var j = 0; j < enc.length; j++) bin += String.fromCharCode(enc[j]);
    return btoa(bin);
  }
  function __symDecryptToString(data, key, transformation, iv) {
    var mode = String(transformation || "AES").toUpperCase();
    var kb = __aesKeyBytes(key);
    var cipher = __b64ToBytes(data);
    var dec = __unpadPkcs7(__aesDecryptBytes(cipher, kb, mode, __aesIv(iv)));
    return __bytesToUtf8(dec);
  }

  // ============================ cookie ============================
  var cookie = {
    getCookie: function (url) {
      var host = __matchCookieHost(__hostOf(url));
      return host ? (__state.cookies[host] || "") : "";
    },
    setCookie: function (url, cookieStr) {
      var host = __hostOf(url);
      var jar = __parseCookiePairs(__state.cookies[host] || "");
      var add = __parseCookiePairs(cookieStr);
      Object.keys(add).forEach(function (k) { jar[k] = add[k]; });
      __state.cookies[host] = Object.keys(jar).map(function (k) { return k + "=" + jar[k]; }).join("; ");
      return true;
    },
    removeCookie: function (url) {
      var host = __hostOf(url);
      var k = __matchCookieHost(host);
      if (k) delete __state.cookies[k];
      return true;
    },
    getKey: function (url, name) {
      var c = this.getCookie(url);
      var m = String(c).match(new RegExp("(?:^|;\\s*)" + name + "=([^;]*)"));
      return m ? m[1] : "";
    },
    replaceCookie: function (url, c) { return this.setCookie(url, c); }
  };
  globalThis.cookie = cookie;

  // ============================ cache ============================
  var cache = {
    get: function (key) {
      var v = __state.kv[key];
      if (v === undefined || v === null) return null;
      try { return JSON.parse(v); } catch (e) { return v; }
    },
    put: function (key, value) {
      __state.kv[key] = (typeof value === "string") ? value : JSON.stringify(value);
      return true;
    },
    remove: function (key) { delete __state.kv[key]; }
  };
  globalThis.cache = cache;

  // ============================ source ============================
  var source = {
    getBookSourceUrl: function () { return __state.meta.url; },
    getBookSourceName: function () { return __state.meta.name; },
    getKey: function () { return __state.meta.url; },
    // 变量注释 / 更新时间（部分订阅源以属性方式访问）
    get variableComment() { return __state.variableComment || ""; },
    get lastUpdateTime() { return __state.lastUpdateTime || 0; },
    getVariable: function (key) {
      if (key === undefined || key === null || key === "") return __state.variable;
      try {
        var o = JSON.parse(__state.variable || "{}");
        var v = o[key];
        return v === undefined ? "" : (typeof v === "string" ? v : JSON.stringify(v));
      } catch (e) { return ""; }
    },
    setVariable: function (v) {
      __state.variable = (typeof v === "string") ? v : JSON.stringify(v);
      return __state.variable;
    },
    getLoginInfo: function () { return __state.loginInfo || ""; },
    getLoginInfoMap: function () {
      try { return JSON.parse(__state.loginInfo || "{}"); } catch (e) { return {}; }
    },
    setLoginInfo: function (v) {
      __state.loginInfo = (typeof v === "string") ? v : JSON.stringify(v);
      return true;
    },
    putLoginInfo: function (v) {
      __state.loginInfo = (typeof v === "string") ? v : JSON.stringify(v);
      return true;
    },
    getCookie: function (url) { return cookie.getCookie(url); },
    setCookie: function (url, c) { return cookie.setCookie(url, c); },
    removeCookie: function (url) { return cookie.removeCookie(url); },
    // 移除登录头（清空登录信息与由登录派生的状态）
    removeLoginHeader: function () {
      __state.loginInfo = "";
      return true;
    },
    getCookieStore: function () { return cookie; }
  };
  globalThis.source = source;

  function putLoginInfo(info) {
    __state.loginInfo = (typeof info === "string") ? info : JSON.stringify(info);
    return true;
  }
  globalThis.putLoginInfo = putLoginInfo;
  globalThis.setLoginInfo = putLoginInfo;

  // 默认的 getArgument/setArgument（书源 jsLib 通常会自带；缺失时兜底）
  if (typeof globalThis.getArgument !== "function") {
    globalThis.getArgument = function (key) {
      var o = {};
      try { o = JSON.parse(__state.variable || "{}"); } catch (e) { o = {}; }
      return o[key];
    };
  }
  if (typeof globalThis.setArgument !== "function") {
    globalThis.setArgument = function (key, value) {
      var o = {};
      try { o = JSON.parse(__state.variable || "{}"); } catch (e) { o = {}; }
      o[key] = value;
      __state.variable = JSON.stringify(o);
      return __state.variable;
    };
  }

  // ============================ 网络（同步 XHR，原生拦截） ============================
  function __parseUrlOptions(arg, extra) {
    var url = arg, opt = { method: "GET", headers: {}, body: null };
    if (typeof arg === "object" && arg !== null) {
      url = arg.url;
      if (arg.method) opt.method = String(arg.method).toUpperCase();
      if (arg.headers) Object.assign(opt.headers, arg.headers);
      if (arg.body !== undefined && arg.body !== null) opt.body = arg.body;
      if (arg.data !== undefined && arg.data !== null) opt.body = arg.data;
      if (arg.webView) opt.webView = true;
    } else if (typeof arg === "string") {
      var comma = arg.indexOf(",{");
      if (comma >= 0) {
        url = arg.substring(0, comma);
        try {
          var o = JSON.parse(arg.substring(comma + 1));
          if (o.method) opt.method = String(o.method).toUpperCase();
          if (o.headers) Object.assign(opt.headers, o.headers);
          if (o.body !== undefined && o.body !== null) opt.body = o.body;
          if (o.charset) opt.charset = o.charset;
          if (o.webView) opt.webView = true;
        } catch (e) {}
      }
      var m = /,(POST|GET|PUT|DELETE)(?::([\s\S]*))?$/i.exec(url);
      if (m) { url = url.substring(0, m.index); opt.method = m[1].toUpperCase(); if (m[2]) opt.body = m[2]; }
    }
    if (extra && typeof extra === "object") {
      if (extra.method) opt.method = String(extra.method).toUpperCase();
      if (extra.headers) Object.assign(opt.headers, extra.headers);
      if (extra.body !== undefined && extra.body !== null) opt.body = extra.body;
    }
    return { url: url, opt: opt };
  }

  function __doXhr(url, opt, respType) {
    url = __resolve(url);
    var method = opt.method || "GET";
    var headers = {};
    Object.keys(opt.headers || {}).forEach(function (k) {
      if (opt.headers[k] !== undefined && opt.headers[k] !== null) headers[k] = String(opt.headers[k]);
    });
    var bodyStr = null;
    if (opt.body !== undefined && opt.body !== null) {
      bodyStr = (typeof opt.body === "string") ? opt.body : JSON.stringify(opt.body);
    }
    if (bodyStr !== null && method !== "GET" && method !== "HEAD") {
      headers["X-Legado-Body"] = __b64Unicode(bodyStr);
      if (!__hasHeader(headers, "Content-Type")) headers["Content-Type"] = "application/x-www-form-urlencoded";
    }
    if (!__hasHeader(headers, "Cookie") && !__hasHeader(headers, "cookie")) {
      var c = cookie.getCookie(url);
      if (c) headers["Cookie"] = c;
    }
    var x = new XMLHttpRequest();
    x.open(method, url, false);
    Object.keys(headers).forEach(function (k) {
      try { x.setRequestHeader(k, headers[k]); } catch (e) {}
    });
    if (respType === "arraybuffer") x.responseType = "arraybuffer";
    x.send(bodyStr);
    var sc = null;
    try { sc = x.getResponseHeader("X-Set-Cookie"); } catch (e) {}
    if (sc) __ingestSetCookie(url, sc);
    if (__state.hosts.indexOf(__hostOf(url)) < 0) __state.hosts.push(__hostOf(url));
    if (x.status === 0) throw new Error("网络请求失败: " + url);
    if (x.status >= 400) throw new Error("HTTP " + x.status + " " + url);
    if (respType === "arraybuffer") return x.response;
    return x.responseText;
  }
  function __hasHeader(headers, name) {
    var lk = name.toLowerCase();
    return Object.keys(headers).some(function (k) { return k.toLowerCase() === lk; });
  }

  // 从合并后的 Set-Cookie 头里取指定 name 的值（多条 cookie 逐条解析）
  function __cookieValue(setCookieHeader, name) {
    var lines = __splitSetCookieLines(setCookieHeader);
    for (var i = 0; i < lines.length; i++) {
      var pairs = __parseCookiePairs(lines[i]);
      if (pairs[name] !== undefined) return pairs[name];
    }
    return null;
  }

  function __connect(url) {
    var conn = {
      __url: url, __method: "GET", __headers: {}, __body: null,
      headers: function (h) { if (h) Object.keys(h).forEach((k) => { this.__headers[k] = h[k]; }); return this; },
      addHeader: function (k, v) { this.__headers[k] = v; return this; },
      header: function (k, v) { this.__headers[k] = v; return this; },
      method: function (m) { this.__method = String(m).toUpperCase(); return this; },
      setBody: function (b) { this.__body = b; return this; },
      body: function (b) { this.__body = b; this.__method = "POST"; return this; },
      get: function () { this.__method = "GET"; return this; },
      post: function (b) { this.__method = "POST"; if (b !== undefined) this.__body = b; return this; },
      followRedirects: function () { return this; },
      timeout: function () { return this; },
      execute: function () {
        var r = __doXhrFull(this.__url, { method: this.__method, headers: this.__headers, body: this.__body });
        var text = r.text;
        return {
          code: r.status,
          statusCode: r.status,
          url: this.__url,
          body: function () { return { string: function () { return text; }, bytes: function () { return new TextEncoder().encode(text); }, text: function () { return text; } }; },
          headers: r.headers,
          header: function (name) {
            if (!name) return null;
            var lk = String(name).toLowerCase();
            var keys = Object.keys(r.headers);
            for (var i = 0; i < keys.length; i++) {
              if (keys[i].toLowerCase() === lk) return r.headers[keys[i]];
            }
            return null;
          },
          raw: text
        };
      }
    };
    return conn;
  }

  // ============================ 浏览器交互登录 ============================
  function __openBrowser(url, title, awaitFlag) {
    var id = "b" + Date.now() + Math.floor(Math.random() * 1000);
    __state.browser.push({ id: id, url: __resolve(url), title: title || "" });
    return new Promise(function (resolve) {
      __pendings[id] = resolve;
      try {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler("legadoBrowser", JSON.stringify({
            id: id, url: __resolve(url), title: title || ""
          }));
        }
      } catch (e) {}
      if (!awaitFlag) {
        setTimeout(function () { if (__pendings[id]) { delete __pendings[id]; resolve(""); } }, 0);
      }
    });
  }
  globalThis.__resolveBrowser = function (id, cookieStr, finalUrl) {
    if (cookieStr) __ingestSetCookie(finalUrl || "", cookieStr);
    if (__pendings[id]) { var r = __pendings[id]; delete __pendings[id]; r(cookieStr || ""); }
  };
  globalThis.__cancelBrowser = function (id) {
    if (__pendings[id]) { var r = __pendings[id]; delete __pendings[id]; r(""); }
  };

  // ============================ java ============================
  function __argString(args) {
    return Array.prototype.map.call(args, function (a) {
      if (typeof a === "string") return a;
      try { return JSON.stringify(a); } catch (e) { return String(a); }
    }).join(" ");
  }

  var java = {
    // 日志 / 提示
    log: function () { __state.logs.push(__argString(arguments)); },
    toast: function (msg) { var s = String(msg == null ? "" : msg); __state.toasts.push(s); __state.logs.push(s); },
    longToast: function (msg) { var s = String(msg == null ? "" : msg); __state.toasts.push(s); __state.logs.push(s); },

    // 网络
    ajax: function (url, options) {
      var p = __parseUrlOptions(url, options);
      return __doXhr(p.url, p.opt);
    },
    get: function (url, headers) {
      return __doXhr(url, { method: "GET", headers: headers || {} });
    },
    post: function (url, body, headers) {
      return __doXhr(url, { method: "POST", body: body, headers: headers || {} });
    },
    put: function (url, body, headers) {
      return __doXhr(url, { method: "PUT", body: body, headers: headers || {} });
    },
    delete: function (url, headers) {
      return __doXhr(url, { method: "DELETE", headers: headers || {} });
    },
    head: function (url, headers) {
      return __doXhr(url, { method: "HEAD", headers: headers || {} });
    },
    connect: function (url) { return __connect(url); },
    newResponse: function (url) { return __connect(url); },
    getCookie: function (url) { return cookie.getCookie(url); },

    // 编码
    base64Encode: function (str) { return __b64Unicode(str); },
    base64Decode: function (str) {
      try { return __unb64Unicode(str); } catch (e) {
        try { return atob(str); } catch (e2) { return ""; }
      }
    },
    encodeBase64: function (str) { return __b64Unicode(str); },
    decodeBase64: function (str) { return this.base64Decode(str); },
    hexDecodeToString: function (hex) {
      // 书源对「明文 JSON / HTML」与「十六进制响应」都会调用本函数。
      // 仅当整串为合法、偶数长度、可解出 UTF-8 的十六进制时才解码，否则原样返回。
      var raw = String(hex == null ? "" : hex);
      var h = raw.replace(/\s+/g, "");
      if (h.length === 0 || (h.length % 2) !== 0 || /[^0-9a-fA-F]/.test(h)) return raw;
      try {
        var bytes = new Uint8Array(h.length / 2);
        for (var i = 0; i < bytes.length; i++) bytes[i] = parseInt(h.substr(i * 2, 2), 16);
        return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
      } catch (e) { return raw; }
    },
    hexEncodeToString: function (str) { return __bytesToHex(new TextEncoder().encode(str)); },
    stringToHex: function (str) { return __bytesToHex(new TextEncoder().encode(str)); },
    // MD5：复用文件内 RFC 1321 实现，返回小写 hex（对齐 legado JsExtensions.md5Encode）
    md5Encode: function (str) { return __md5(str == null ? "" : str); },
    md5: function (str) { return __md5(str == null ? "" : str); },

    // AES 对称加解密（同步；对齐 legado JsExtensions）
    aesBase64DecodeToString: function (data, key, transformation, iv) {
      return __aesDecryptToString(data, key, transformation, iv);
    },
    aesBase64EncodeToString: function (text, key, transformation, iv) {
      return __aesEncryptToString(text, key, transformation, iv);
    },
    aesDecodeToString: function (data, key, transformation, iv) {
      return __aesDecryptToString(data, key, transformation, iv);
    },
    aesEncodeToString: function (text, key, transformation, iv) {
      return __aesEncryptToString(text, key, transformation, iv);
    },

    // 设备 / UA
    deviceID: function () { return __state.deviceId; },
    androidId: function () { return __state.deviceId; },
    getWebViewUA: function () { return __state.ua; },
    getAppVariant: function () { return "android"; },

    // 时间
    timeFormat: function (time, pattern) { return __timeFormat(time, pattern, false); },
    timeFormatUTC: function (time, pattern) { return __timeFormat(time, pattern, true); },

    // 跨阶段键值
    put: function (k, v) { cache.put(k, v); return true; },
    get: function (k) { var v = cache.get(k); return v === null ? "" : v; },
    contains: function (k) { return Object.prototype.hasOwnProperty.call(__state.kv, k); },
    remove: function (k) { cache.remove(k); },

    // 书源相关
    refreshExplore: function () { return true; },
    refreshBookToc: function () { return true; },
    refreshBook: function () { return true; },

    // 浏览器登录
    startBrowser: function (url, title) { return __openBrowser(url, title, false); },
    startBrowserDp: function (url, title) { return __openBrowser(url, title, false); },
    startBrowserAwait: function (url, title) { return __openBrowser(url, title, true); },
    showBrowser: function (url, title) { return __openBrowser(url, title, true); },
    showReadingBrowser: function (url, title) { return __openBrowser(url, title, true); },
    reLoginView: function (url) { return __openBrowser(url || "", "登录", true); },

    // 环境探测：轻阅读不可用，需抛错让书源走标准分支
    qread: function () { throw new Error("qread 不可用"); },

    // 对称加密工厂：对齐 legado JsExtensions.createSymmetricCrypto(key, mode, iv)
    // 返回对象含 encryptBase64(text) / decryptStr(data)，基于文件内 aes-js + PKCS7 实现（CBC/ECB）
    createSymmetricCrypto: function (key, mode, iv) {
      var transformation = mode || "AES/CBC/PKCS7Padding";
      return {
        encrypt: function (text) { return __symEncryptToBase64(text, key, transformation, iv); },
        encryptBase64: function (text) { return __symEncryptToBase64(text, key, transformation, iv); },
        decrypt: function (data) { return __symDecryptToString(data, key, transformation, iv); },
        decryptStr: function (data) { return __symDecryptToString(data, key, transformation, iv); }
      };
    },

    // java.lang / java.net 常见静态调用
    lang: {
      Thread: { sleep: function () {} },
      System: { currentTimeMillis: function () { return Date.now(); }, nanoTime: function () { return Date.now() * 1000000; } },
      String: function (v) { return String(v); },
      Integer: { parseInt: function (v) { return parseInt(v, 10); } }
    },
    net: {
      URLEncoder: { encode: function (s) { return encodeURIComponent(String(s)).replace(/%20/g, "+"); } },
      URLDecoder: { decode: function (s) { return decodeURIComponent(String(s).replace(/\+/g, "%20")); } }
    }
  };
  globalThis.java = java;

  function __pad(n) { return n < 10 ? "0" + n : "" + n; }
  function __timeFormat(time, pattern, utc) {
    if (!time) return "";
    var d;
    if (typeof time === "number" || /^\d+$/.test(String(time))) {
      var n = Number(time);
      if (n < 1e12) n = n * 1000;
      d = new Date(n);
    } else {
      d = new Date(String(time).replace(/-/g, "/"));
    }
    if (isNaN(d.getTime())) return "";
    var p = pattern || "yyyy-MM-dd HH:mm:ss";
    var Y = utc ? d.getUTCFullYear() : d.getFullYear();
    var M = (utc ? d.getUTCMonth() : d.getMonth()) + 1;
    var D = utc ? d.getUTCDate() : d.getDate();
    var H = utc ? d.getUTCHours() : d.getHours();
    var m = utc ? d.getUTCMinutes() : d.getMinutes();
    var s = utc ? d.getUTCSeconds() : d.getSeconds();
    return p
      .replace(/yyyy/g, "" + Y)
      .replace(/yy/g, ("" + Y).slice(-2))
      .replace(/MM/g, __pad(M))
      .replace(/dd/g, __pad(D))
      .replace(/HH/g, __pad(H))
      .replace(/mm/g, __pad(m))
      .replace(/ss/g, __pad(s));
  }

  // 供原生每次求值前重置「瞬态」输出
  globalThis.__resetTransient = function () {
    __state.logs = [];
    __state.toasts = [];
    __state.hosts = [];
    __state.browser = [];
  };

  // 求值结束后汇总输出
  globalThis.__envelope = function (ret, err) {
    if (ret === undefined) {
      try { ret = globalThis.result; } catch (e) { ret = null; }
    }
    var safeRet;
    try { safeRet = (ret === undefined) ? null : ret; } catch (e) { safeRet = String(ret); }
    return JSON.stringify({
      ret: safeRet,
      variable: __state.variable,
      loginInfo: __state.loginInfo,
      kv: __state.kv,
      cookies: __state.cookies,
      logs: __state.logs,
      toasts: __state.toasts,
      hosts: __state.hosts,
      browser: __state.browser,
      error: err ? ((err && err.stack) ? String(err.stack) : String(err)) : null
    });
  };
})();
''';
}
