import 'package:flutter_tts/flutter_tts.dart';
import '../models/book_chapter.dart';

/// TTS朗读服务
/// 支持系统TTS和HTTP TTS
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  double _speechRate = 0.5;
  double _speechPitch = 1.0;
  double _volume = 1.0;
  String? _language;
  String? _engine;
  List<String> _chapters = [];
  int _currentIndex = 0;
  Function(String)? onProgress;
  Function()? onComplete;
  Function(String)? onError;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  double get speechRate => _speechRate;
  double get speechPitch => _speechPitch;
  double get volume => _volume;

  /// 初始化TTS
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage('zh-CN');
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(_speechPitch);
      await _flutterTts.setVolume(_volume);

      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
        // 自动播放下一章
        if (_currentIndex < _chapters.length - 1) {
          _currentIndex++;
          _speakCurrent();
        } else {
          onComplete?.call();
        }
      });

      _flutterTts.setErrorHandler((msg) {
        _isPlaying = false;
        onError?.call(msg.toString());
      });

      _flutterTts.setProgressHandler((text, start, end, word) {
        onProgress?.call(word);
      });

      _isInitialized = true;
    } catch (e) {
      onError?.call('TTS初始化失败: $e');
    }
  }

  /// 设置朗读内容
  void setChapters(List<BookChapter> chapters, {int startIndex = 0}) {
    _chapters = chapters.map((c) => c.content ?? c.title).where((c) => c.isNotEmpty).toList();
    _currentIndex = startIndex.clamp(0, _chapters.length - 1);
  }

  /// 开始朗读
  Future<void> play() async {
    if (!_isInitialized) await init();
    if (_chapters.isEmpty) return;
    _isPaused = false;
    await _speakCurrent();
  }

  Future<void> _speakCurrent() async {
    if (_currentIndex >= _chapters.length) return;
    _isPlaying = true;
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(_chapters[_currentIndex]);
    } catch (e) {
      onError?.call('朗读失败: $e');
    }
  }

  /// 暂停
  Future<void> pause() async {
    if (!_isInitialized) return;
    try {
      await _flutterTts.pause();
      _isPaused = true;
      _isPlaying = false;
    } catch (_) {}
  }

  /// 停止
  Future<void> stop() async {
    if (!_isInitialized) return;
    try {
      await _flutterTts.stop();
      _isPlaying = false;
      _isPaused = false;
    } catch (_) {}
  }

  /// 下一章
  Future<void> next() async {
    if (_currentIndex < _chapters.length - 1) {
      _currentIndex++;
      await _speakCurrent();
    }
  }

  /// 上一章
  Future<void> previous() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _speakCurrent();
    }
  }

  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    if (_isInitialized) await _flutterTts.setSpeechRate(rate);
  }

  /// 设置音调
  Future<void> setPitch(double pitch) async {
    _speechPitch = pitch;
    if (_isInitialized) await _flutterTts.setPitch(pitch);
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    _volume = volume;
    if (_isInitialized) await _flutterTts.setVolume(volume);
  }

  /// 设置语言
  Future<void> setLanguage(String lang) async {
    _language = lang;
    if (_isInitialized) await _flutterTts.setLanguage(lang);
  }

  /// 获取可用语言
  Future<List<String>> getLanguages() async {
    if (!_isInitialized) await init();
    try {
      final langs = await _flutterTts.getLanguages;
      if (langs is List) return langs.map((e) => e.toString()).toList();
      return ['zh-CN', 'en-US'];
    } catch (_) {
      return ['zh-CN', 'en-US'];
    }
  }

  /// 获取可用引擎
  Future<List<String>> getEngines() async {
    if (!_isInitialized) await init();
    try {
      final engines = await _flutterTts.getEngines;
      if (engines is List) return engines.map((e) => e.toString()).toList();
      return [];
    } catch (_) {
      return [];
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await stop();
    _chapters.clear();
    _isInitialized = false;
  }
}

/// HTTP TTS 配置
class HttpTtsConfig {
  final String url;
  final String method;
  final Map<String, String> headers;
  final Map<String, String> params;
  final String textParam;
  final String contentType;

  HttpTtsConfig({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.params = const {},
    this.textParam = 'text',
    this.contentType = 'audio/mpeg',
  });
}
