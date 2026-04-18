import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/firebase_alerts_service.dart';
import '../../../shared/services/user_session_service.dart';

/// AI-generated alerts for caregivers.
/// Grouped by day, severity-coded, ≥16px fonts throughout, MD3 cards.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Alerts',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<String?>(
        future: UserSessionService.instance.getSavedUserId(),
        builder: (context, userIdSnapshot) {
          // Loading state
          if (userIdSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Error getting userId
          if (userIdSnapshot.hasError || !userIdSnapshot.hasData || userIdSnapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.accentRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load session',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMid,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please log in again',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final caregiverId = userIdSnapshot.data!;

          return StreamBuilder<List<AlertGroup>>(
            stream: FirebaseAlertsService.instance.getAlertsStream(caregiverId),
            builder: (context, snapshot) {
              // Loading state
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              // Error state
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppTheme.accentRed,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load alerts',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textMid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              // Empty state
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_rounded,
                        size: 48,
                        color: AppTheme.textLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No alerts yet',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMid,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Everything looks good!',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Data loaded
              final groups = snapshot.data!;
              final unreadCount =
                  groups.expand((g) => g.alerts).where((a) => a.isUnread).length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // ── Summary bar ────────────────────────────────────────────────
                  if (unreadCount > 0) ...[
                    _SummaryBar(unreadCount: unreadCount),
                    const SizedBox(height: 20),
                  ],

                  // ── Alert groups ───────────────────────────────────────────────
                  for (final group in groups) ...[
                    _GroupLabel(label: group.dateLabel),
                    const SizedBox(height: 8),
                    for (final alert in group.alerts) ...[
                      _AlertCardFirebase(
                        alert: alert,
                        caregiverId: caregiverId,
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}


// ── Summary Bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int unreadCount;
  const _SummaryBar({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle_notifications_rounded,
              color: AppTheme.accentOrange, size: 20),
          const SizedBox(width: 10),
          Text(
            '$unreadCount unread alert${unreadCount > 1 ? 's' : ''} requiring attention',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentOrange,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Group Label ───────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textLight,
        letterSpacing: 1.0,
      ),
    );
  }
}

// ── Alert Card (Firebase) ──────────────────────────────────────────────────────

class _AlertCardFirebase extends StatefulWidget {
  final AlertModel alert;
  final String caregiverId;

  const _AlertCardFirebase({
    required this.alert,
    required this.caregiverId,
  });

  @override
  State<_AlertCardFirebase> createState() => _AlertCardFirebaseState();
}

class _AlertCardFirebaseState extends State<_AlertCardFirebase> {
  late bool isUnread;

  @override
  void initState() {
    super.initState();
    isUnread = widget.alert.isUnread;
  }

  AlertSeverity get _severityEnum => _parseSeverity(widget.alert.severity);
  _SeverityStyle get _style => _SeverityStyle.of(_severityEnum);

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _markAsRead() async {
    if (isUnread) {
      await FirebaseAlertsService.instance
          .markAsRead(widget.caregiverId, widget.alert.id);
      setState(() => isUnread = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).colorScheme.surface : AppTheme.surfaceWhite;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.divider;
    final titleColor = isDark ? Colors.white.withValues(alpha: 0.9) : AppTheme.textDark;
    final bodyColor = isDark ? Colors.white.withValues(alpha: 0.65) : AppTheme.textMid;
    final timeColor = isDark ? Colors.white.withValues(alpha: 0.4) : AppTheme.textLight;

    final title = widget.alert.type.isNotEmpty ? widget.alert.type : 'Alert';
    final body = widget.alert.body.isNotEmpty ? widget.alert.body : 'No details available.';

    return GestureDetector(
      onTap: _markAsRead,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              // Left accent bar
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(width: 4, color: _style.accentColor),
              ),
              Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: icon + type + badge + time ─────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _style.accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_style.icon, color: _style.accentColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 6),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _SeverityBadge(style: _style),
                            const Spacer(),
                            Text(
                              _formatTime(widget.alert.timestamp),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: timeColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Body ────────────────────────────────────────────────────
              Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: bodyColor,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper: Parse Severity ────────────────────────────────────────────────────

AlertSeverity _parseSeverity(String severity) {
  return switch (severity.toLowerCase()) {
    'critical' => AlertSeverity.critical,
    'warning' => AlertSeverity.warning,
    'normal' => AlertSeverity.normal,
    'info' || _ => AlertSeverity.info,
  };
}

// ── Severity Badge ────────────────────────────────────────────────────────────

class _SeverityBadge extends StatelessWidget {
  final _SeverityStyle style;
  const _SeverityBadge({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        style.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: style.accentColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Severity Style ────────────────────────────────────────────────────────────

enum AlertSeverity { critical, warning, normal, info }

class _SeverityStyle {
  final Color accentColor;
  final IconData icon;
  final String label;

  const _SeverityStyle({
    required this.accentColor,
    required this.icon,
    required this.label,
  });

  static _SeverityStyle of(AlertSeverity severity) {
    return switch (severity) {
      AlertSeverity.critical => const _SeverityStyle(
          accentColor: AppTheme.accentRed,
          icon: Icons.error_rounded,
          label: 'CRITICAL',
        ),
      AlertSeverity.warning => const _SeverityStyle(
          accentColor: AppTheme.accentOrange,
          icon: Icons.warning_rounded,
          label: 'WARNING',
        ),
      AlertSeverity.normal => const _SeverityStyle(
          accentColor: AppTheme.accentGreen,
          icon: Icons.check_circle_rounded,
          label: 'NORMAL',
        ),
      AlertSeverity.info => const _SeverityStyle(
          accentColor: AppTheme.primaryBlue,
          icon: Icons.info_rounded,
          label: 'INFO',
        ),
    };
  }
}
