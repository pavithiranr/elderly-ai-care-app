import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

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
          _GreetingHeader(greeting: _greeting, date: _today),
          const SizedBox(height: 20),

          // ── Patient card ───────────────────────────────────────────────
          // TODO: replace hardcoded data with Firestore patient document
          const _PatientCard(),
          const SizedBox(height: 16),

          // ── AI Summary ─────────────────────────────────────────────────
          // TODO: replace placeholder text with Gemini 2.0 generated summary
          const _AiSummaryBanner(
            summary:
                'Margaret had a good morning. She completed her check-in, reported a pain level of 2/10, and took both morning medications on time. No concerns flagged today.',
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
          // TODO: replace hardcoded list with Firestore activity stream
          ..._recentActivity.map((a) => _ActivityTile(item: a)),
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

  static const List<_ActivityItem> _recentActivity = [
    _ActivityItem(
      icon: Icons.check_circle_rounded,
      iconColor: AppTheme.accentGreen,
      title: 'Daily check-in completed',
      subtitle: 'Mood: Good · Pain: 2/10',
      time: 'Today, 8:12 AM',
    ),
    _ActivityItem(
      icon: Icons.medication_rounded,
      iconColor: AppTheme.accentOrange,
      title: 'Morning medications taken',
      subtitle: 'Metformin · Lisinopril',
      time: 'Today, 8:30 AM',
    ),
    _ActivityItem(
      icon: Icons.chat_bubble_rounded,
      iconColor: AppTheme.primaryBlue,
      title: 'Chat with AI companion',
      subtitle: '12-minute session',
      time: 'Today, 9:05 AM',
    ),
    _ActivityItem(
      icon: Icons.warning_rounded,
      iconColor: AppTheme.accentOrange,
      title: 'Missed afternoon medication',
      subtitle: 'Vitamin D3 — 12:00 PM',
      time: 'Today, 12:45 PM',
    ),
    _ActivityItem(
      icon: Icons.check_circle_rounded,
      iconColor: AppTheme.accentGreen,
      title: 'Daily check-in completed',
      subtitle: 'Mood: Great · Pain: 1/10',
      time: 'Yesterday, 8:20 AM',
    ),
  ];
}

// ── Greeting Header ───────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final String greeting;
  final String date;
  const _GreetingHeader({required this.greeting, required this.date});

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
                      // TODO: replace 'Sarah' with caregiver name from Firebase Auth
                      text: 'Sarah',
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
            'S', // TODO: replace with caregiver initial from Firebase Auth
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
  const _PatientCard();

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
                  'Margaret Johnson',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '78 years old  ·  Last seen: 9:05 AM',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textMid,
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(label: 'Active', color: AppTheme.accentGreen),
        ],
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
            // Header row with Gemini sparkle badge
            Row(
              children: [
                const _GeminiSparkle(),
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

/// Sparkle badge shown at the top-left of all AI-generated cards.
class _GeminiSparkle extends StatelessWidget {
  const _GeminiSparkle();

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'Gemini 2.0',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

// ── Activity Tile ─────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;
  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
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
              color: item.iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textMid,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.time,
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

// ── Data classes ──────────────────────────────────────────────────────────────

class _ActivityItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}
