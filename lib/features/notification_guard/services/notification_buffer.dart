import 'dart:async';

import 'package:flutter/foundation.dart';

/// 같은 대화방/발신자에서 조각으로 쪼개져 들어오는 알림을 모아 평가.
///
/// 키 = `packageName + sender` (sender 는 알림의 title — 카톡은 대화방 이름).
///
/// 트리거:
///   - 동일 (text, lastSeen) 가 dedupWindow 내 들어오면 무시 (안드로이드 갱신)
///   - 누적 점수가 thresholdScore 이상이면 즉시 flush + cooldown 시작
///   - cooldown 중에는 score 재상승해도 flush 안 함 (overspam 방지)
///   - quietGap 동안 같은 키에서 추가 알림 없으면 그 시점에 1회 flush
///   - 첫 알림 후 maxWindow 가 지나면 강제 flush + 버퍼 리셋
class NotificationBuffer {
  /// dedup window — 같은 (key, text) 가 이 시간 내 다시 오면 무시.
  final Duration dedupWindow;

  /// quiet flush — 같은 키에서 이 시간 동안 새 알림이 없으면 그동안 모인 버퍼를 1회 flush.
  final Duration quietGap;

  /// max window — 첫 알림 이후 최대 보관 시간. 넘으면 강제 flush + 리셋.
  final Duration maxWindow;

  /// flush 트리거 후 같은 키에 적용되는 쿨다운. 이 동안엔 추가 flush 안 함.
  final Duration cooldown;

  /// 누적 점수가 이 값 이상이면 즉시 flush.
  final int thresholdScore;

  /// 버퍼 텍스트 최대 길이. 활성 단톡방 등에서 60초 maxWindow 사이에 수십 건이
  /// 쌓이면 매 ingest 마다 quadratic 재스코어링이 발생해 spike 가능 — 오래된 머리를
  /// 잘라내고 최근 텍스트만 유지. 사기 핵심 신호는 보통 후반부에 등장하므로 안전.
  final int maxBufferChars;

  /// flush 콜백 — 호출자가 /judge API 를 부르고 후속 처리(경고 알림 노출 등) 책임.
  final FutureOr<void> Function(BufferFlush flush) onFlush;

  NotificationBuffer({
    required this.onFlush,
    this.dedupWindow   = const Duration(seconds: 2),
    this.quietGap      = const Duration(seconds: 5),
    this.maxWindow     = const Duration(seconds: 60),
    this.cooldown      = const Duration(seconds: 60),
    this.thresholdScore = 50,
    this.maxBufferChars = 2000,
  });

  final Map<String, _Entry> _byKey = {};

  /// 알림 1건 수신. text 는 이미 정제된 본문(타이틀+content 합치거나 한 줄).
  void ingest({
    required String packageName,
    required String sender,
    required String text,
    required int score,
    required ScoreCallback rescoreFn,
  }) {
    if (text.trim().isEmpty) return;

    final key = _makeKey(packageName, sender);
    final now = DateTime.now();
    final entry = _byKey[key];

    if (entry == null) {
      final e = _Entry(
        packageName: packageName,
        sender: sender,
        firstSeen: now,
        lastSeen: now,
        lastText: text,
        bufferText: text,
        score: score,
      );
      _byKey[key] = e;
      _maybeFlushAfterIngest(e, rescoreFn);
      return;
    }

    // dedup — 안드로이드는 같은 알림을 살짝 갱신해 다시 보내는 경우가 있다.
    if (now.difference(entry.lastSeen) < dedupWindow && entry.lastText == text) {
      return;
    }

    // 쿨다운 중이면 버퍼는 갱신하되 flush 는 안 함 (다음 사이클에 처리).
    final appended = '${entry.bufferText}\n$text';
    entry.bufferText = appended.length > maxBufferChars
        ? appended.substring(appended.length - maxBufferChars)
        : appended;
    entry.lastText = text;
    entry.lastSeen = now;

    // 누적 텍스트 전체로 다시 점수 매김 — 조각이 합쳐졌을 때 임계값 초과 가능성.
    entry.score = rescoreFn(entry.bufferText);

    _maybeFlushAfterIngest(entry, rescoreFn);
  }

  void _maybeFlushAfterIngest(_Entry e, ScoreCallback rescoreFn) {
    // max window 초과 → 강제 flush 후 리셋
    if (DateTime.now().difference(e.firstSeen) >= maxWindow) {
      _doFlush(e, FlushReason.maxWindow);
      _reset(e.key);
      return;
    }

    // 점수 임계값 도달 + 쿨다운 아님 → 즉시 flush
    final now = DateTime.now();
    final inCooldown = e.cooldownUntil != null && now.isBefore(e.cooldownUntil!);
    if (e.score >= thresholdScore && !inCooldown) {
      _doFlush(e, FlushReason.thresholdHit);
      e.cooldownUntil = now.add(cooldown);
      // 쿨다운 중 추가 누적은 그대로 두되, quiet timer 만 재예약.
    }

    // quiet timer 재예약 — 같은 키에 더 안 들어오면 quietGap 후 한 번 더 flush.
    e.quietTimer?.cancel();
    e.quietTimer = Timer(quietGap, () {
      // 다시 점수 매겨 의미 있을 때만 flush (이미 cooldown 직후라 flush 안 했을 수도).
      final entry = _byKey[e.key];
      if (entry == null) return;
      final stillInCooldown = entry.cooldownUntil != null && DateTime.now().isBefore(entry.cooldownUntil!);
      if (!stillInCooldown && entry.score >= thresholdScore) {
        _doFlush(entry, FlushReason.quietGap);
      }
      _reset(entry.key);
    });
  }

  void _doFlush(_Entry e, FlushReason reason) {
    try {
      onFlush(BufferFlush(
        packageName: e.packageName,
        sender: e.sender,
        text: e.bufferText,
        score: e.score,
        reason: reason,
      ));
    } catch (err) {
      debugPrint('NotificationBuffer flush 콜백 실패: $err');
    }
  }

  void _reset(String key) {
    final e = _byKey.remove(key);
    e?.quietTimer?.cancel();
  }

  /// 외부에서 모든 타이머 정리 (앱 종료, 기능 OFF 시).
  void dispose() {
    for (final e in _byKey.values) {
      e.quietTimer?.cancel();
    }
    _byKey.clear();
  }

  static String _makeKey(String pkg, String sender) => '$pkg::$sender';
}

typedef ScoreCallback = int Function(String text);

class _Entry {
  final String packageName;
  final String sender;
  final DateTime firstSeen;
  DateTime lastSeen;
  String lastText;
  String bufferText;
  int score;
  Timer? quietTimer;
  DateTime? cooldownUntil;

  String get key => '$packageName::$sender';

  _Entry({
    required this.packageName,
    required this.sender,
    required this.firstSeen,
    required this.lastSeen,
    required this.lastText,
    required this.bufferText,
    required this.score,
  });
}

class BufferFlush {
  final String packageName;
  final String sender;
  final String text;
  final int score;
  final FlushReason reason;

  const BufferFlush({
    required this.packageName,
    required this.sender,
    required this.text,
    required this.score,
    required this.reason,
  });
}

enum FlushReason { thresholdHit, quietGap, maxWindow }
