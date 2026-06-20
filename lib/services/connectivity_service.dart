import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Single source of truth for "are we online right now."
///
/// Note connectivity_plus tells us whether a network interface is up
/// (wifi/cellular connected), not whether Supabase is actually reachable —
/// a captive portal or a flaky cell tower can report "connected" while
/// requests still fail. [SyncService] treats failed requests as offline
/// regardless of what this reports, so this stream is a fast first signal
/// rather than the final word.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._() {
    _init();
  }

  final _connectivity = Connectivity();
  final _statusController = StreamController<bool>.broadcast();
  bool _isOnline = true;
  StreamSubscription? _subscription;

  bool get isOnline => _isOnline;
  Stream<bool> get onStatusChange => _statusController.stream;

  Future<void> _init() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _resultIndicatesConnection(result);
    _statusController.add(_isOnline);

    _subscription =
        _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = _resultIndicatesConnection(result);
      if (wasOnline != _isOnline) {
        _statusController.add(_isOnline);
      }
    });
  }

  bool _resultIndicatesConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  /// Manually re-check (e.g. after a failed request) rather than waiting
  /// for the next change event.
  Future<bool> refresh() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _resultIndicatesConnection(result);
    _statusController.add(_isOnline);
    return _isOnline;
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
