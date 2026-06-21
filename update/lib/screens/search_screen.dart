import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/db_models.dart';
import '../services/recruit_service.dart';
import '../services/fingerprint_service.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/app_button.dart';
import '../widgets/app_max_width.dart';
import '../widgets/app_screen_entry.dart';
import 'recruit_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final _recruitService = RecruitService();
  final _fingerprintService = FingerprintService();

  List<DbRecruit> _results = [];
  bool _searched = false;
  bool _isSearching = false;
  bool _scanning = false;
  bool _resultsFromCache = false;
  DateTime? _cacheTimestamp;
  String? _errorMessage;

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final result = await _recruitService.search(q);
      setState(() {
        _searched = true;
        _isSearching = false;
        _results = result.recruits;
        _resultsFromCache = result.fromCache;
        _cacheTimestamp = result.cacheTimestamp;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _scanFingerprint() async {
    setState(() {
      _scanning = true;
      _errorMessage = null;
    });

    final capture = await _fingerprintService.capture();

    if (!mounted) return;

    if (!capture.success) {
      setState(() {
        _scanning = false;
        _errorMessage = capture.error ?? 'Fingerprint scan failed';
      });
      return;
    }

    try {
      // The 1:N matching strategy now lives in FingerprintService.findMatch
      // (see fingerprint_service.dart) — this is the real identification
      // path, functional today with the software fallback provider (which
      // can only ever return "no match" since it generates a random
      // template per scan) and ready to identify real recruits the moment
      // real scanner hardware is wired in.
      final match = await _recruitService.findByFingerprint(
        capture.template!,
        _fingerprintService,
      );
      setState(() {
        _scanning = false;
        _searched = true;
        _results = match != null ? [match] : [];
        _resultsFromCache = false;
      });
    } catch (e) {
      setState(() {
        _scanning = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatCacheTime(DateTime? dt) {
    if (dt == null) return 'never synced';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search & Verify')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AppMaxWidth(
          maxWidth: 600,
          child: Column(
            children: [
              const ConnectivityBanner(),

              // Search bar
              TextField(
                controller: _controller,
                style: const TextStyle(color: AppTheme.offWhite),
                decoration: const InputDecoration(
                  labelText: 'Search by Name or ID Number',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: _search,
                textInputAction: TextInputAction.search,
              ),
              const SizedBox(height: 12),
              Center(
                child: AppButton(
                  label: 'SEARCH',
                  icon: Icons.search,
                  isLoading: _isSearching,
                  onPressed:
                      _isSearching ? null : () => _search(_controller.text),
                ),
              ),
              const SizedBox(height: 16),

              // Fingerprint section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.goldAccent.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'OR SCAN FINGERPRINT',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        letterSpacing: 2,
                        color: AppTheme.goldAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!_fingerprintService.isUsingRealHardware) ...[
                      const SizedBox(height: 6),
                      Text(
                        'No scanner connected — using simulated capture',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 10,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _scanning ? null : _scanFingerprint,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _scanning
                              ? AppTheme.goldAccent.withOpacity(0.2)
                              : AppTheme.navyMid,
                          border: Border.all(
                            color: _scanning
                                ? AppTheme.goldAccent
                                : AppTheme.steelBlue,
                            width: 2,
                          ),
                        ),
                        child: _scanning
                            ? const CircularProgressIndicator(
                                color: AppTheme.goldAccent,
                              )
                            : const Icon(
                                Icons.fingerprint,
                                size: 44,
                                color: AppTheme.goldAccent,
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _scanning ? 'Scanning...' : 'Tap to scan fingerprint',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.dangerRed.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.dangerRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                color: AppTheme.dangerRed, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Results
              if (_searched && _errorMessage == null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _results.isEmpty
                          ? 'NO RECORDS FOUND'
                          : '${_results.length} RESULT(S)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: _results.isEmpty
                            ? AppTheme.dangerRed
                            : AppTheme.goldAccent,
                      ),
                    ),
                    if (_resultsFromCache)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.goldAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'CACHED · ${_formatCacheTime(_cacheTimestamp)}',
                          style: const TextStyle(
                            color: AppTheme.goldAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final r = _results[i];
                    return AppListItemEntry(
                      index: i,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecruitProfileScreen(recruit: r),
                          ),
                        ).then((_) => _search(_controller.text)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: r.statusColor.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: r.statusColor.withOpacity(0.15),
                                child: Text(
                                  r.fullName.isNotEmpty ? r.fullName[0] : '?',
                                  style: TextStyle(
                                    color: r.statusColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.fullName,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      r.idNumber,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    Text(
                                      r.region,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: r.statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: r.statusColor.withOpacity(0.5),
                                      ),
                                    ),
                                    child: Text(
                                      r.statusLabel,
                                      style: TextStyle(
                                        color: r.statusColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppTheme.textMuted,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
