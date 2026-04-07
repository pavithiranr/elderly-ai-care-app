import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/caregiver_service.dart';
import '../../../shared/services/patient_service.dart';

/// Caregiver Dashboard — MD3 card-based layout, ≥16px fonts.
class CaregiverDashboardScreen extends StatelessWidget {
  const CaregiverDashboardScreen({super.key});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _today => DateFormat('EEEE, MMMM d').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      appBar: _buildAppBar(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // ── Greeting ──────────────────────────────────────────────────
          FutureBuilder<CaregiverProfile?>(
            future: CaregiverService.instance.getCurrentCaregiverProfile(),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              final caregiverName = profile?.name ?? 'Caregiver';
              final caregiverInitial = profile?.initial ?? '?';

              return _GreetingHeader(
                greeting: _greeting,
                date: _today,
                caregiverName: caregiverName,
                caregiverInitial: caregiverInitial,
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Patient card ───────────────────────────────────────────────
          // Fetches patient data from Firestore
          FutureBuilder<List<PatientProfile>>(
            future: CaregiverService.instance
                .getCurrentCaregiverProfile()
                .then((profile) => profile != null
                    ? PatientService.instance
                        .getPatientsByCaregiver(profile.id)
                    : []),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final patients = snapshot.data ?? [];
              final primaryPatient =
                  patients.isNotEmpty ? patients.first : null;

              return primaryPatient != null
                  ? _PatientCard(patient: primaryPatient)
                  : const _PatientCardPlaceholder();
            },
          ),
          const SizedBox(height: 16),

          // ── AI Summary ─────────────────────────────────────────────────
          // TODO: replace placeholder text with Gemini 2.0 generated summary (later)
          const _AiSummaryBanner(
            summary:
                'Patient had a good morning. Completed check-in with good mood report, took medications on time. No alerts to review.',
          ),
          const SizedBox(height: 20),

          // ── Health stats ───────────────────────────────────────────────
          _SectionHeader(title: "Today's Health"),
          const SizedBox(height: 10),
          // TODO: replace hardcoded values with live Firestore reads
          const _StatsGrid(),
          const SizedBox(height: 20),

          // ── Quick links ────────────────────────────────────────────────
          _QuickLink(
            icon: Icons.bar_chart_rounded,
            iconColor: AppTheme.primaryBlue,
            iconBg: AppTheme.primaryLight,
            label: 'Weekly Health Report',
            sublabel: 'AI-generated summary & charts',
            onTap: () => context.push(AppConstants.routeCaregiverReports),
          ),
          const SizedBox(height: 10),
          _QuickLink(
            icon: Icons.notifications_active_rounded,
            iconColor: AppTheme.accentOrange,
            iconBg: const Color(0xFFFFF7ED),
            label: 'All Alerts',
            sublabel: '1 warning today',
            onTap: () => context.push(AppConstants.routeCaregiverAlerts),
          ),
          const SizedBox(height: 20),

          // ── Recent activity ────────────────────────────────────────────
          _SectionHeader(title: 'Recent Activity'),
          const SizedBox(height: 10),
          // Fetches activity stream from Firestore (real-time updates)
          FutureBuilder<PatientProfile?>(
            future: CaregiverService.instance
                .getCurrentCaregiverProfile()
                .then((profile) => profile != null
                    ? PatientService.instance
                        .getPatientsByCaregiver(profile.id)
                        .then((patients) =>
                            patients.isNotEmpty ? patients.first : null)
                    : null),
            builder: (context, patientSnapshot) {
              if (patientSnapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }

              final patient = patientSnapshot.data;
              if (patient == null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No activity data',
                      style: GoogleFonts.inter(color: AppTheme.textMid),
                    ),
                  ),
                );
              }

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: PatientService.instance.getActivityStream(patient.id),
                builder: (context, activitySnapshot) {
                  if (!activitySnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final activities = activitySnapshot.data ?? [];
                  if (activities.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No recent activity',
                          style: GoogleFonts.inter(color: AppTheme.textMid),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: activities
                        .take(10)
                        .map((activity) =>
                            _ActivityTileFromMap(activityData: activity))
                        .toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: AppTheme.primaryBlue,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            AppConstants.appName,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
      actions: [
        // Profile button
        IconButton(
          icon: const Icon(Icons.person_rounded, size: 24),
          onPressed: () => context.push(AppConstants.routeCaregiverSettings),
          tooltip: 'Profile & Settings',
        ),
        const SizedBox(width: 4),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, size: 24),
              onPressed: () => context.push(AppConstants.routeCaregiverAlerts),
            ),
            // Unread badge
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppTheme.accentOrange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      backgroundColor: AppTheme.surfaceWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    );
  }
}

// ── Greeting Header ───────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final String greeting;
  final String date;
  final String caregiverName;
  final String caregiverInitial;
  const _GreetingHeader({
    required this.greeting,
    required this.date,
    required this.caregiverName,
    required this.caregiverInitial,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textLight,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$greeting, ',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        color: AppTheme.textMid,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(
                      text: caregiverName,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.primaryLight,
          child: Text(
            caregiverInitial,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Patient Card ──────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final PatientProfile patient;
  const _PatientCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.elderly_rounded,
              color: AppTheme.primaryBlue,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${patient.age} years old  ·  Last seen: ${_formatLastSeen(patient.lastSeen)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textMid,
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(label: patient.status.capitalize(), color: _statusColor(patient.status)),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime dateTime) {
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppTheme.accentGreen;
      case 'inactive':
        return AppTheme.accentOrange;
      default:
        return AppTheme.textMid;
    }
  }
}

/// Placeholder when no patient data available
class _PatientCardPlaceholder extends StatelessWidget {
  const _PatientCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.person_off_rounded,
              color: AppTheme.textLight,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'No patients assigned',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Summary Banner ─────────────────────────────────────────────────────────

class _AiSummaryBanner extends StatelessWidget {
  final String summary;
  const _AiSummaryBanner({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'Summary',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Just now',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Summary text
            Text(
              summary,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 14),

            // Footer
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  'Generated by Gemini 2.0',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.mood_rounded,
                iconColor: AppTheme.accentGreen,
                iconBg: const Color(0xFFDCFCE7),
                label: 'Mood Today',
                value: 'Good  🙂',
                sub: 'Check-in at 8:12 AM',
                subColor: AppTheme.accentGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.healing_rounded,
                iconColor: AppTheme.accentGreen,
                iconBg: const Color(0xFFDCFCE7),
                label: 'Pain Level',
                value: '2 / 10',
                sub: 'Low — stable',
                subColor: AppTheme.accentGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.medication_rounded,
                iconColor: AppTheme.accentOrange,
                iconBg: const Color(0xFFFFF7ED),
                label: 'Meds Taken',
                value: '2 / 4',
                sub: 'Next: 12:00 PM',
                subColor: AppTheme.accentOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.emergency_rounded,
                iconColor: AppTheme.accentGreen,
                iconBg: const Color(0xFFDCFCE7),
                label: 'SOS Alerts',
                value: 'None',
                sub: 'All clear today',
                subColor: AppTheme.accentGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String sub;
  final Color subColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMid,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: subColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Link ────────────────────────────────────────────────────────────────

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _QuickLink({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        sublabel,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textLight,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Activity Tile (Firestore) ─────────────────────────────────────────────────

class _ActivityTileFromMap extends StatelessWidget {
  final Map<String, dynamic> activityData;
  const _ActivityTileFromMap({required this.activityData});

  Color _getIconColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'medication':
        return AppTheme.accentOrange;
      case 'checkin':
        return AppTheme.accentGreen;
      case 'alert':
      case 'warning':
        return AppTheme.accentRed;
      case 'chat':
        return AppTheme.primaryBlue;
      default:
        return AppTheme.primaryBlue;
    }
  }

  IconData _getIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'medication':
        return Icons.medication_rounded;
      case 'checkin':
        return Icons.check_circle_rounded;
      case 'alert':
      case 'warning':
        return Icons.warning_rounded;
      case 'chat':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
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

  @override
  Widget build(BuildContext context) {
    final type = activityData['type'] as String?;
    final title = activityData['title'] as String? ?? 'Activity';
    final subtitle = activityData['subtitle'] as String? ?? '';
    final timestamp = (activityData['timestamp'] as dynamic);
    final DateTime? dateTime = timestamp is DateTime ? timestamp : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _getIconColor(type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getIcon(type), color: _getIconColor(type), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textMid,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(dateTime),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading state for AI-generated summary
/// (Removed - not needed)

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppTheme.textDark,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// String extension for utility methods
// ──────────────────────────────────────────────────────────────────────────────

extension StringExtension on String {
  String capitalize() => isNotEmpty ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
}
