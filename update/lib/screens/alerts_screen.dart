import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/db_models.dart';
import '../services/alerts_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_max_width.dart';
import '../widgets/app_skeleton.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _alertsService = AlertsService();
  late Stream<List<DbAlert>> _alertsStream;

  @override
  void initState() {
    super.initState();
    _alertsStream = _alertsService.alertsStream();
  }

  Future<void> _markAllRead() async {
    await _alertsService.markAllRead();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _iconForSeverity(String severity) {
    switch (severity) {
      case 'high':
        return Icons.flag;
      case 'medium':
        return Icons.business;
      default:
        return Icons.notifications;
    }
  }

  String _severityLabel(String severity) => severity.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts & Notifications'),
        actions: [
          AppButton.text(
            label: 'Mark all read',
            compact: true,
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: StreamBuilder<List<DbAlert>>(
        stream: _alertsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppSkeletonList(count: 5);
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off,
                        color: AppTheme.dangerRed, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load alerts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final alerts = snapshot.data ?? [];
          final unread = alerts.where((a) => !a.isRead).length;

          if (alerts.isEmpty) {
            return Center(
              child: Text(
                'No notifications yet',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          return AppMaxWidth(
            maxWidth: 700,
            child: Column(
              children: [
                if (unread > 0)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: AppTheme.navyMid,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerRed.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppTheme.dangerRed.withOpacity(0.5)),
                          ),
                          child: Text(
                            '$unread unread',
                            style: const TextStyle(
                              color: AppTheme.dangerRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'You have $unread new notification${unread > 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: alerts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                    final alert = alerts[i];
                    return GestureDetector(
                      onTap: () => _alertsService.markRead(alert.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: alert.isRead
                                ? AppTheme.steelBlue.withOpacity(0.3)
                                : alert.color.withOpacity(0.5),
                            width: alert.isRead ? 1 : 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: alert.color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _iconForSeverity(alert.severity),
                                color: alert.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          alert.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontSize: 14,
                                                color: alert.isRead
                                                    ? AppTheme.offWhite
                                                        .withOpacity(0.7)
                                                    : AppTheme.offWhite,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: alert.color.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _severityLabel(alert.severity),
                                          style: TextStyle(
                                            color: alert.color,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    alert.body,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: alert.isRead
                                              ? AppTheme.textMuted
                                                  .withOpacity(0.6)
                                              : AppTheme.textMuted,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _timeAgo(alert.createdAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontSize: 11,
                                              color: AppTheme.textMuted
                                                  .withOpacity(0.7),
                                            ),
                                      ),
                                      if (!alert.isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: alert.color,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          );
        },
      ),
    );
  }
}
