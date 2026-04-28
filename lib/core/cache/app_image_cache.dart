// lib/core/cache/app_image_cache.dart
//
// 메모리 기반 URL→바이트 캐시. 사용량이 무한히 늘지 않도록 LRU 한도를 둠.
// Dart `Map` 은 삽입 순서를 보존하므로, get/set 시 키를 재삽입해 MRU 위치로 옮긴다.
import 'dart:typed_data';

class AppImageCache {
  AppImageCache._();
  static final AppImageCache instance = AppImageCache._();

  /// 동시에 캐시할 최대 항목 수. 50KB 썸네일 기준 약 10MB.
  /// 초과 시 가장 오래 쓰이지 않은 항목부터 제거.
  static const int _maxItems = 200;

  final Map<String, Uint8List> _cache = {};

  Uint8List? get(String url) {
    final value = _cache.remove(url);
    if (value != null) _cache[url] = value; // MRU 위치로 이동
    return value;
  }

  void set(String url, Uint8List bytes) {
    _cache.remove(url);
    _cache[url] = bytes;
    while (_cache.length > _maxItems) {
      _cache.remove(_cache.keys.first); // 가장 오래된 항목 제거
    }
  }

  bool has(String url) => _cache.containsKey(url);
  void clear() => _cache.clear();
}
