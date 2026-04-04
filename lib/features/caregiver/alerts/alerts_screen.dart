import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// AI-generated alerts for caregivers.
/// Grouped by day, severity-coded, ≥16px fonts throughout, MD3 cards.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  // TODO: replace with Firestore alerts stream grouped by date
  static const List<_AlertGroup> _groups = [
    _AlertGroup(
      dateLabel: 'Today',
      alerts: [
        _Alert(
          severity: AlertSeverity.critical,
          type: 'Missed Medication',
          body:
              'Margaret has not marked her 12:00 PM Vitamin D3 dose as taken. This is the second missed dose this week.',
          time: '12:45 PM',
          isUnread: true,
        ),
        _Alert(
          severity: AlertSeverity.warning,
          type: 'Low Activity Detected',
          body:
              'No movement or app activity recorded between 10:00 AM and 12:30 PM.',
          time: '12:32 PM',
          isUnread: true,
        ),
        _Alert(
          severity: AlertSeverity.normal,
          type: 'Morning Medications Taken',
          body:
              'Both morning medications (Metformin, Lisinopril) marked as taken on schedule.',
          time: '8:30 AM',
          isUnread: false,
        ),
        _Alert(
          severity: AlertSeverity.info,
          type: 'Daily Check-in Completed',
          body:
              'Morning check-in submitted. Mood: Good 🙂  ·  Pain: 2/10  ·  No notes added.',
          time: '8:12 AM',
          isUnread: false,
        ),
        _Alert(
          severity: AlertSeverity.info,
          type: 'AI Companion Session',
          body:
              'Margaret completed a 12-minute chat session with the AI companion. Topics: general wellbeing.',
          time: '9:05 AM',
          isUnread: false,
        ),
      ],
    ),
    _AlertGroup(
      dateLabel: 'Yesterday',
      alerts: [
        _Alert(
          severity: AlertSeverity.normal,
          type: 'Daily Check-in Completed',
          body:
              'Morning check-in submitted. Mood: Great 😊  ·  Pain: 1/10.',
          time: '8:20 AM',
          isUnread: false,
        ),
        _Alert(
          severity: AlertSeverity.normal,
          type: 'All Medications Taken',
          body: 'All 4 scheduled medications were taken on time.',
          time: '9:00 PM',
          isUnread: false,
        ),
      ],
    ),
  ];

  int get _unreadCount =>
      _groups.expand((g) => g.alerts).where((a) => a.isUnread).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
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
            color: AppTheme.textDark,
          ),
        ),
        backgroundColor: AppTheme.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // ── Summary bar ────────────────────────────────────────────────
          if (_unreadCount > 0) ...[
            _SummaryBar(unreadCount: _unreadCount),
            const SizedBox(height: 20),
          ],

          // ── Alert groups ───────────────────────────────────────────────
          for (final group in _groups) ...[
            _GroupLabel(label: group.dateLabel),
            const SizedBox(height: 8),
            for (final alert in group.alerts) ...[
              _AlertCard(alert: alert),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
          ],
        ],
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

// ── Alert Card ────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final _Alert alert;
  const _AlertCard({required this.alert});

  _SeverityStyle get _style => _SeverityStyle.of(alert.severity);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: _style.accentColor, width: 4),
          top: const BorderSide(color: AppTheme.divider),
          right: const BorderSide(color: AppTheme.divider),
          bottom: const BorderSide(color: AppTheme.divider),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon + type + badge + time ─────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon circle
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _style.accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_style.icon, color: _style.accentColor, size: 18),
                ),
                const SizedBox(width: 12),
                // Title + badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              alert.type,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                          if (alert.isUnread)
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
                            alert.time,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textLight,
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
              alert.body,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMid,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
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

// ── Data classes ──────────────────────────────────────────────────────────────

class _AlertGroup {
  final String dateLabel;
  final List<_Alert> alerts;
  const _AlertGroup({required this.dateLabel, required this.alerts});
}

class _Alert {
  final AlertSeverity severity;
  final String type;
  final String body;
  final String time;
  final bool isUnread;
  const _Alert({
    required this.severity,
    required this.type,
    required this.body,
    required this.time,
    required this.isUnread,
  });
}
