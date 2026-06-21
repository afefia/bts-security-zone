import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/local_db.dart';

/// Drop this near the top of any screen that reads/writes recruit data.
/// Shows nothing when online with no pending writes — only speaks up when
/// something the user should know about is happening (offline, syncing,
/// or queued writes waiting to go out). Staying silent the rest of the
/// time matters here: a banner that's always present stops meaning
/// anything.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  final _connectivity = ConnectivityService();
  final _sync = SyncService();

  bool _isOnline = true;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _pendingCount = 0;
  StreamSubscription? _connSub;
  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    _isOnline = _connectivity.isOnline;
    _refreshPendingCount();

    _connSub = _connectivity.onStatusChange.listen((isOnline) {
      if (mounted) setState(() => _isOnline = isOnline);
      _refreshPendingCount();
    });

    _syncSub = _sync.statusStream.listen((status) {
      if (mounted) setState(() => _syncStatus = status);
      _refreshPendingCount();
    });
  }

  Future<void> _refreshPendingCount() async {
    final count = await LocalDb.getPendingWriteCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing worth interrupting the user about.
    if (_isOnline &&
        _pendingCount == 0 &&
        _syncStatus != SyncStatus.syncing) {
      return const SizedBox.shrink();
    }

    String message;
    IconData icon;
    Color color;

    if (!_isOnline) {
      message = _pendingCount > 0
          ? 'Offline — showing cached data ($_pendingCount pending to sync)'
          : 'Offline — showing cached data';
      icon = Icons.cloud_off;
      color = AppTheme.goldAccent;
    } else if (_syncStatus == SyncStatus.syncing) {
      message = 'Syncing...';
      icon = Icons.sync;
      color = AppTheme.steelBlue;
    } else if (_pendingCount > 0) {
      message = '$_pendingCount change${_pendingCount > 1 ? 's' : ''} waiting to sync';
      icon = Icons.cloud_upload_outlined;
      color = AppTheme.goldAccent;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          if (_syncStatus == SyncStatus.syncing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!_isOnline)
            GestureDetector(
              onTap: () async {
                final online = await _connectivity.refresh();
                if (online) _sync.syncNow();
              },
              child: Text(
                'RETRY',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
