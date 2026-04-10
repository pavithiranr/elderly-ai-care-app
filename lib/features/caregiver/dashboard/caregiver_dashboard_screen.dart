import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/services/caregiver_service.dart';
import '../../../shared/services/patient_service.dart';

/// Caregiver Dashboard — MD3 card-based layout, ≥16px fonts.
class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  late PageController _patientPageController;
  int _currentPatientIndex = 0;
  late Future<CaregiverProfile?> _caregiverProfileFuture;

  @override
  void initState() {
    super.initState();
    _patientPageController = PageController(viewportFraction: 0.95);
    _caregiverProfileFuture = CaregiverService.instance.getCurrentCaregiverProfile();
  }

  @override
  void dispose() {
    _patientPageController.dispose();
    super.dispose();
  }

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
                onProfileTap: () => context.push(AppConstants.routeCaregiverSettings),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Patient card (Swipeable Carousel) ────────────────────────
          // Fetches patient data from Firestore using linkedElderlyIds
          FutureBuilder<CaregiverProfile?>(
            future: _caregiverProfileFuture,
            builder: (context, caregiverSnapshot) {
              if (caregiverSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final caregiver = caregiverSnapshot.data;
              if (caregiver == null || caregiver.linkedElderlyIds.isEmpty) {
                return const _PatientCardPlaceholder();
              }

              final elderlyIds = caregiver.linkedElderlyIds;

              return Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      controller: _patientPageController,
                      onPageChanged: (index) {
                        setState(() => _currentPatientIndex = index);
                      },
                      physics: const BouncingScrollPhysics(),
                      itemCount: elderlyIds.length,
                      itemBuilder: (context, index) {
                        return FutureBuilder<PatientProfile?>(
                          future: PatientService.instance.getPatientById(elderlyIds[index]),
                          builder: (context, patientSnapshot) {
                            if (patientSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            final patient = patientSnapshot.data;
                            return patient != null
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: _PatientCard(patient: patient),
                                  )
                                : const SizedBox.shrink();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dot indicator
                  if (elderlyIds.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        elderlyIds.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPatientIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPatientIndex == index
                                ? Theme.of(context).primaryColor
                                : Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // ── Today's Check-in (Real-time) ───────────────────────────────
          FutureBuilder<CaregiverProfile?>(
            future: CaregiverService.instance.getCurrentCaregiverProfile(),
            builder: (context, caregiverSnapshot) {
              if (caregiverSnapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }

              final caregiver = caregiverSnapshot.data;
              if (caregiver == null || caregiver.linkedElderlyIds.isEmpty || _currentPatientIndex >= caregiver.linkedElderlyIds.length) {
                return const SizedBox.shrink();
              }

              final currentPatientId = caregiver.linkedElderlyIds[_currentPatientIndex];
              return _TodayCheckinBanner(patientId: currentPatientId);
            },
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
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: Theme.of(context).primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            AppConstants.appName,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
      actions: [
        // Dark Mode Toggle Button
        ListenableBuilder(
          listenable: ThemeProvider.instance,
          builder: (context, _) {
            final isDarkMode = ThemeProvider.instance.isDarkMode;
            return IconButton(
              icon: Icon(
                isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 24,
                color: Theme.of(context).iconTheme.color,
              ),
              onPressed: () {
                ThemeProvider.instance.setDarkMode(!isDarkMode);
              },
              tooltip: isDarkMode ? 'Light Mode' : 'Dark Mode',
            );
          },
        ),
        const SizedBox(width: 8),
        // Alerts/Notifications button
        Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_outlined,
                size: 24,
                color: Theme.of(context).iconTheme.color,
              ),
              onPressed: () => context.push(AppConstants.routeCaregiverAlerts),
            ),
            // Unread badge
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
    );
  }
}

// ── Greeting Header ───────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final String greeting;
  final String date;
  final String caregiverName;
  final String caregiverInitial;
  final VoidCallback? onProfileTap;
  const _GreetingHeader({
    required this.greeting,
    required this.date,
    required this.caregiverName,
    required this.caregiverInitial,
    this.onProfileTap,
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
        GestureDetector(
          onTap: onProfileTap,
          child: CircleAvatar(
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
// Today's Check-in Banner (Real-time)
// ──────────────────────────────────────────────────────────────────────────────

class _TodayCheckinBanner extends StatelessWidget {
  final String patientId;
  const _TodayCheckinBanner({required this.patientId});

  String _moodIndexToEmoji(int index) {
    const emojis = ['😊', '🙂', '😐', '😟', '😢'];
    return index >= 0 && index < emojis.length ? emojis[index] : '❓';
  }

  String _moodIndexToLabel(int index) {
    const labels = ['Great', 'Good', 'Okay', 'Not Great', 'Bad'];
    return index >= 0 && index < labels.length ? labels[index] : 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PatientHealthData?>(
      stream: PatientService.instance.getTodayHealthData$Stream(patientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF4338CA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          );
        }

        final healthData = snapshot.data;

        if (healthData == null) {
          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE0E7FF), Color(0xFFF3E8FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_rounded, color: AppTheme.primaryBlue, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'Check-in',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Waiting for today\'s check-in...',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppTheme.textMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final emoji = _moodIndexToEmoji(healthData.mood.isNotEmpty ? int.tryParse(healthData.mood) ?? 0 : 0);
        final moodLabel = _moodIndexToLabel(healthData.mood.isNotEmpty ? int.tryParse(healthData.mood) ?? 0 : 0);

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
                // Header badge
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
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'Today\'s Check-in',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Main stats
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mood: $moodLabel $emoji',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pain Level: ${healthData.painLevel.toInt()}/10',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        'Submitted',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// String extension for utility methods
// ──────────────────────────────────────────────────────────────────────────────

extension StringExtension on String {
  String capitalize() => isNotEmpty ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
}
