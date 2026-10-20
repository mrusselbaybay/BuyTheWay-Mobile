import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'api_service.dart';

/// Silent background refresh (mobile twin of the web `usePolling.js`).
///
/// - Runs [task] every [interval] (±10% jitter), never overlapping itself.
/// - Pauses while the app is in the background; refreshes on resume when the
///   last run is older than 5s.
/// - Exponential backoff on failures (cap 5 min), reset on success; honours
///   429. Stops for good on 401/403 so the existing auth handling takes over.
/// - [shouldSkip] holds a tick while the user is mid-action (in-flight
///   mutation, dialog, submitting). [isActive] tells a task whether it is still
///   current, so late responses are dropped after [stop].
/// - Failures are silent: no toast, the UI keeps its last good data.
class Poller with WidgetsBindingObserver {
  Poller(
    this.task, {
    this.interval = const Duration(seconds: 30),
    this.shouldSkip,
    this.onError,
  });

  final Future<void> Function(bool Function() isActive) task;
  final Duration interval;
  final bool Function()? shouldSkip;

  /// Called for every failure of a still-current run (e.g. to flag a 401).
  final void Function(Object error)? onError;

  static const _maxBackoff = Duration(minutes: 5);
  static const _resumeGap = Duration(seconds: 5);
  static final _random = math.Random();

  Timer? _timer;
  bool _running = false;
  bool _halted = false;
  bool _inFlight = false;
  bool _foreground = true;
  int _failures = 0;
  int _generation = 0;
  Duration? _retryAfter;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isRunning => _running;

  void start({bool immediate = false}) {
    if (_running) return;
    _running = true;
    _halted = false;
    _failures = 0;
    _generation++;
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;
    if (immediate) {
      refreshNow();
    } else {
      _schedule();
    }
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Runs once now (e.g. after a user action or when a tab becomes visible)
  /// and restarts the countdown.
  Future<void> refreshNow() async {
    if (!_running || _halted) return;
    _timer?.cancel();
    await _run();
    _schedule();
  }

  /// [refreshNow] unless a run finished within [age] (tab became visible again).
  Future<void> refreshIfStale([Duration age = const Duration(seconds: 15)]) async {
    if (DateTime.now().difference(_lastRun) > age) await refreshNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running || _halted) return;
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (DateTime.now().difference(_lastRun) > _resumeGap) {
        refreshNow();
      } else {
        _schedule();
      }
    } else if (state == AppLifecycleState.paused) {
      _foreground = false;
      _timer?.cancel();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!_running || _halted || !_foreground) return;
    final base = _retryAfter ?? interval * math.pow(2, _failures).toInt();
    _retryAfter = null;
    final capped = base > _maxBackoff ? _maxBackoff : base;
    final jittered = (capped.inMilliseconds * (0.9 + _random.nextDouble() * 0.2)).round();
    _timer = Timer(Duration(milliseconds: jittered), () async {
      await _run();
      _schedule();
    });
  }

  Future<void> _run() async {
    if (_inFlight || !_foreground || (shouldSkip?.call() ?? false)) return;
    final generation = _generation;
    _inFlight = true;
    _lastRun = DateTime.now();
    try {
      await task(() => _running && generation == _generation);
      if (generation == _generation) _failures = 0;
    } catch (error) {
      if (generation != _generation) return;
      onError?.call(error);
      final status = error is ApiException ? error.statusCode : null;
      if (status == 401 || status == 403) {
        _halted = true;
        return;
      }
      _failures++;
      if (status == 429) _retryAfter = interval * math.pow(2, _failures).toInt();
    } finally {
      _inFlight = false;
    }
  }
}
