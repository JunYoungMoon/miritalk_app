// lib/core/cache/app_image_cache.dart
import 'dart:typed_data';

class AppImageCache {
  AppImageCache._();
  static final AppImageCache instance = AppImageCache._();

  final Map<String, Uint8List> _cache = {};

  Uint8List? get(String url) => _cache[url];
  void set(String url, Uint8List bytes) => _cache[url] = bytes;
  bool has(String url) => _cache.containsKey(url);
  void clear() => _cache.clear();
}