class CookieManager {
  final Map<String, String> _cookies = {};
  String? getCookie(String url) => _cookies[url];
  void setCookie(String url, String cookie) => _cookies[url] = cookie;
}
