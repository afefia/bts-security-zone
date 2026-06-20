import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/db_models.dart';
import '../services/recruit_service.dart';
import '../services/company_service.dart';
import '../services/auth_service.dart';
import '../services/alerts_service.dart';
import '../services/local_db.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/push_notification_service.dart';
import '../config/supabase_service.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/app_button.dart';
import 'search_screen.dart';
import 'recruit_profile_screen.dart';
import 'company_list_screen.dart';
import 'register_recruit_screen.dart';
import 'admin_panel_screen.dart';
import 'login_screen.dart';
import 'alerts_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _recruitService = RecruitService();
  final _companyService = CompanyService();
  final _alertsService = AlertsService();

  bool _isLoading = true;
  String? _errorMessage;
  List<DbRecruit> _recruits = [];
  int _companyCount = 0;
  DbCompany? _myCompany;
  DbUserProfile? _myProfile;
  int _unreadAlerts = 0;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _watchAuthState();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Redirect to login if the session expires mid-use (e.g. the refresh
  /// token itself expired, or the user was signed out remotely/from
  /// another device). A signedOut event is the reliable signal here —
  /// Supabase fires it whenever there's no valid session left, including
  /// when a refresh attempt fails.
  void _watchAuthState() {
    _authSub = SupabaseService.authStateChanges.listen((event) {
      if (event.event == AuthChangeEvent.signedOut && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final recruitResult = await _recruitService.getAll(limit: 100);

      List<DbCompany> companies = [];
      DbCompany? myCompany;
      DbUserProfile? myProfile;
      int unread = 0;
      try {
        final companyResult = await _companyService.getAll();
        companies = companyResult.companies;
        myCompany = await _companyService.getMyCompany();
        myProfile = await _companyService.getMyProfile();
        unread = await _alertsService.getUnreadCount();
      } catch (_) {}

      setState(() {
        _recruits = recruitResult.recruits;
        _companyCount = companies.isNotEmpty ? companies.length : _companyCount;
        _myCompany = myCompany ?? _myCompany;
        _myProfile = myProfile ?? _myProfile;
        _unreadAlerts = unread;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flagged =
        _recruits.where((r) => r.status != 'clear').length;

    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      drawer: _AppDrawer(
        companyName: _myCompany?.name,
        isAdmin: _myProfile?.isAdmin ?? false,
      ),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield, color: AppTheme.goldAccent, size: 20),
            const SizedBox(width: 8),
            const Text('THE SECURITY ZONE'),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AlertsScreen()),
                  );
                  // Refresh unread count after returning from alerts
                  final count = await _alertsService.getUnreadCount();
                  if (mounted) setState(() => _unreadAlerts = count);
                },
                tooltip: 'Alerts',
              ),
              if (_unreadAlerts > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppTheme.dangerRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Menu',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.goldAccent),
            )
          : _errorMessage != null
              ? _buildErrorState(context)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.goldAccent,
                  backgroundColor: AppTheme.cardBg,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ConnectivityBanner(),

                        // Welcome
                        _buildWelcomeBanner(context),
                        const SizedBox(height: 20),

                        // Stats row
                        Row(
                          children: [
                            _StatCard(
                              label: 'Recruits',
                              value: '${_recruits.length}',
                              icon: Icons.people,
                              color: AppTheme.successGreen,
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              label: 'Companies',
                              value: '$_companyCount',
                              icon: Icons.business,
                              color: AppTheme.steelBlue,
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              label: 'Flagged',
                              value: '$flagged',
                              icon: Icons.flag,
                              color: AppTheme.dangerRed,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Quick actions
                        Text(
                          'QUICK ACTIONS',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                letterSpacing: 2,
                                color: AppTheme.goldAccent,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.4,
                          children: [
                            _ActionCard(
                              icon: Icons.search,
                              label: 'Search Recruit',
                              subtitle: 'By ID or fingerprint',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SearchScreen()),
                              ),
                            ),
                            _ActionCard(
                              icon: Icons.person_add,
                              label: 'Register Recruit',
                              subtitle: 'Add new personnel',
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const RegisterRecruitScreen(),
                                  ),
                                );
                                _loadData();
                              },
                            ),
                            _ActionCard(
                              icon: Icons.business_center,
                              label: 'Companies',
                              subtitle: 'Manage & verify',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CompanyListScreen()),
                              ),
                            ),
                            _ActionCard(
                              icon: Icons.admin_panel_settings,
                              label: 'Admin Panel',
                              subtitle: 'Reports & oversight',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AdminPanelScreen()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Recent flags
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'RECENT FLAGS',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    letterSpacing: 2,
                                    color: AppTheme.goldAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            AppButton.text(
                              label: 'View All',
                              compact: true,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SearchScreen()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_recruits.where((r) => r.status != 'clear').isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'No flagged recruits — all clear ✅',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          )
                        else
                          ..._recruits
                              .where((r) => r.status != 'clear')
                              .map((r) => _RecruitListTile(
                                    recruit: r,
                                    onReturn: _loadData,
                                  )),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        ),
        backgroundColor: AppTheme.goldAccent,
        foregroundColor: AppTheme.navyDark,
        icon: const Icon(Icons.fingerprint),
        label: const Text(
          'VERIFY',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppTheme.dangerRed, size: 48),
            const SizedBox(height: 16),
            Text(
              'Could not load dashboard data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'RETRY',
              icon: Icons.refresh,
              onPressed: _loadData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context) {
    final isVerified = _myCompany?.isVerified ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.navyMid, AppTheme.steelBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  _myCompany?.name ?? 'Loading...',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: AppTheme.goldAccent),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isVerified
                            ? AppTheme.successGreen
                            : AppTheme.goldAccent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isVerified ? 'Verified Company' : 'Pending Verification',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(
                        color: isVerified
                            ? AppTheme.successGreen
                            : AppTheme.goldAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_user, color: AppTheme.goldAccent, size: 40),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.steelBlue.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.goldAccent, size: 28),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _RecruitListTile extends StatelessWidget {
  final DbRecruit recruit;
  final VoidCallback? onReturn;

  const _RecruitListTile({required this.recruit, this.onReturn});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecruitProfileScreen(recruit: recruit),
        ),
      ).then((_) => onReturn?.call()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: recruit.statusColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: recruit.statusColor.withOpacity(0.15),
              child: Text(
                recruit.fullName[0],
                style: TextStyle(
                  color: recruit.statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recruit.fullName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    recruit.idNumber,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: recruit.statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: recruit.statusColor.withOpacity(0.5)),
              ),
              child: Text(
                recruit.statusLabel,
                style: TextStyle(
                  color: recruit.statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App Drawer ────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final String? companyName;
  final bool isAdmin;

  const _AppDrawer({this.companyName, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.navyMid,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.navyMid, AppTheme.steelBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.goldAccent,
                    child: Icon(Icons.shield, color: AppTheme.navyDark, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(companyName ?? 'Loading...',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAdmin ? 'Admin' : 'Verified Company',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isAdmin
                                ? AppTheme.goldAccent
                                : AppTheme.successGreen,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            _DrawerItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.search,
              label: 'Search Recruit',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()));
              },
            ),
            _DrawerItem(
              icon: Icons.person_add_outlined,
              label: 'Register Recruit',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RegisterRecruitScreen()));
              },
            ),


            // Only admins see the Admin Panel link
            if (isAdmin)
              _DrawerItem(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Admin Panel',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
                },
              ),

            const Divider(color: AppTheme.steelBlue, height: 16),

            _SyncStatusDrawerItem(),

            const Divider(color: AppTheme.steelBlue, height: 32),

            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => Navigator.pop(context),
            ),

            const Spacer(),

            // Sign out
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Center(
                child: AppButton.danger(
                  label: 'SIGN OUT',
                  icon: Icons.logout,
                  onPressed: () async {
                    await PushNotificationService().unregisterToken();
                    await AuthService().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusDrawerItem extends StatefulWidget {
  @override
  State<_SyncStatusDrawerItem> createState() => _SyncStatusDrawerItemState();
}

class _SyncStatusDrawerItemState extends State<_SyncStatusDrawerItem> {
  final _connectivity = ConnectivityService();
  final _sync = SyncService();
  int _pendingCount = 0;
  bool _isOnline = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _isOnline = _connectivity.isOnline;
    _refresh();
  }

  Future<void> _refresh() async {
    final count = await LocalDb.getPendingWriteCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    await _connectivity.refresh();
    await _sync.syncNow();
    await _refresh();
    if (mounted) setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        _pendingCount > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
        color: _pendingCount > 0 ? AppTheme.goldAccent : AppTheme.successGreen,
        size: 22,
      ),
      title: Text(
        _pendingCount > 0
            ? '$_pendingCount pending sync'
            : 'All synced',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing: _isSyncing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.goldAccent,
              ),
            )
          : AppButton.text(
              label: 'SYNC',
              compact: true,
              onPressed: _syncNow,
            ),
      horizontalTitleGap: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.goldAccent, size: 22),
      title: Text(label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w500)),
      onTap: onTap,
      horizontalTitleGap: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }
}
