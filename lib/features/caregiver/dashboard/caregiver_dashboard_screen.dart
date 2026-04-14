import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/services/caregiver_service.dart';
import '../../../shared/services/gemini_service.dart';
import '../../../shared/services/notification_service.dart';
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

  // SOS listener — fires a local notification when a new alert arrives
  final List<StreamSubscription<QuerySnapshot>> _sosSubs = [];

  @override
  void initState() {
    super.initState();
    _patientPageController = PageController(viewportFraction: 0.95);
    _caregiverProfileFuture = CaregiverService.instance.getCurrentCaregiverProfile();
    _startSosListeners();
  }

  Future<void> _startSosListeners() async {
    final profile = await _caregiverProfileFuture;
    if (profile == null) return;

    for (final patientId in profile.linkedElderlyIds) {
      final patient = await PatientService.instance.getPatientById(patientId);
      final name = patient?.name ?? 'Your patient';

      final sub = FirebaseFirestore.instance
          .collection('elderly')
          .doc(patientId)
          .collection('sos_alerts')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .skip(1) // skip the initial snapshot — only react to NEW docs
          .listen((snap) {
        if (snap.docs.isNotEmpty) {
          NotificationService.instance.showSosNotification(name);
        }
      });

      _sosSubs.add(sub);
    }
  }

  @override
  void dispose() {
    _patientPageController.dispose();
    for (final sub in _sosSubs) {
      sub.cancel();
    }
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

          // ── AI Summary ────────────────────────────────────────────────
          FutureBuilder<CaregiverProfile?>(
            future: _caregiverProfileFuture,
            builder: (context, snap) {
              final ids = snap.data?.linkedElderlyIds ?? [];
              if (ids.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  _AiSummaryLoader(patientId: ids[_currentPatientIndex.clamp(0, ids.length - 1)]),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),

          // ── Health stats ───────────────────────────────────────────────
          _SectionHeader(title: "Today's Health"),
          const SizedBox(height: 10),
          FutureBuilder<CaregiverProfile?>(
            future: _caregiverProfileFuture,
            builder: (context, snap) {
              final ids = snap.data?.linkedElderlyIds ?? [];
              if (ids.isEmpty) return const _StatsGrid(health: null, sosCount: 0);
              final patientId = ids[_currentPatientIndex.clamp(0, ids.length - 1)];
              return FutureBuilder<PatientHealthData?>(
                future: PatientService.instance.getTodayHealthData(patientId),
                builder: (context, healthSnap) {
                  return FutureBuilder<int>(
                    future: PatientService.instance.getTodaySosCount(patientId),
                    builder: (context, sosSnap) {
                      return _StatsGrid(
                        health: healthSnap.data,
                        sosCount: sosSnap.data ?? 0,
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Quick links ────────────────────────────────────────────────
          _QuickLink(
            icon: Icons.bar_chart_rounded,
            iconColor: Theme.of(context).colorScheme.primary,
            iconBg: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            label: 'Weekly Health Report',
            sublabel: 'AI-generated summary & charts',
            onTap: () => context.push(AppConstants.routeCaregiverReports),
          ),
          const SizedBox(height: 10),
          _QuickLink(
            icon: Icons.notifications_active_rounded,
            iconColor: const Color(0xFFEA580C),
            iconBg: const Color(0xFFEA580C),
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
                          style: GoogleFonts.inter(
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
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
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(
                      text: caregiverName,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        color: Theme.of(context).colorScheme.onSurface,
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
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              caregiverInitial,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkMode ? Theme.of(context).dividerColor.withValues(alpha: 0.6) : Theme.of(context).dividerColor,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: isDarkMode ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
            ),
            child: Icon(
              Icons.elderly_rounded,
              color: Theme.of(context).colorScheme.primary,
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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${patient.age} years old  ·  Last seen: ${_formatLastSeen(patient.lastSeen)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
        return const Color(0xFF10B981); // green
      case 'inactive':
        return const Color(0xFFEA580C); // orange
      default:
        return Colors.grey[400] ?? Colors.grey;
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.person_off_rounded,
              color: Theme.of(context).textTheme.bodyMedium?.color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'No patients assigned',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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

// ── AI Summary Loader ─────────────────────────────────────────────────────────

class _AiSummaryLoader extends StatefulWidget {
  final String patientId;
  const _AiSummaryLoader({required this.patientId});

  @override
  State<_AiSummaryLoader> createState() => _AiSummaryLoaderState();
}

class _AiSummaryLoaderState extends State<_AiSummaryLoader> {
  late Future<String> _summaryFuture;
  String? _lastPatientId; // Track current patient to detect changes

  @override
  void initState() {
    super.initState();
    _lastPatientId = widget.patientId;
    _summaryFuture = _fetchSummary();
  }

  @override
  void didUpdateWidget(_AiSummaryLoader old) {
    super.didUpdateWidget(old);
    if (old.patientId != widget.patientId) {
      // Clear old data and reset summary
      _lastPatientId = widget.patientId;
      final newSummaryFuture = _fetchSummary();
      
      // Use setState only to update the future reference, NOT async
      if (mounted) {
        setState(() {
          _summaryFuture = newSummaryFuture;
        });
      }
    }
  }

  Future<String> _fetchSummary() async {
    try {
      final patientId = widget.patientId;
      
      final patient = await PatientService.instance.getPatientById(patientId);
      if (!mounted || _lastPatientId != patientId) return ''; // Cancel stale request
      if (patient == null) return 'No patient data available.';

      final health = await PatientService.instance.getTodayHealthData(patientId);
      if (!mounted || _lastPatientId != patientId) return ''; // Cancel stale request

      final events = <String>[
        'Patient: ${patient.name}, Age: ${patient.age}',
        if (health != null) ...[
          'Mood today: ${health.mood}',
          'Pain level: ${health.painLevel}/10',
          'Medications taken: ${health.medicationsTaken} of ${health.medicationsTotal}',
          if (health.sosAlerts > 0) 'SOS alerts today: ${health.sosAlerts}',
        ] else
          'No check-in recorded today',
      ];

      final summary = await GeminiService.instance.generateHealthSummary(events);
      if (!mounted || _lastPatientId != patientId) return ''; // Cancel stale request
      
      return summary;
    } catch (_) {
      if (!mounted) return ''; // Widget was disposed
      return 'Unable to generate summary right now.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _summaryFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF4338CA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
          );
        }
        final summary = snap.data ?? 'Unable to generate summary.';
        if (summary.isEmpty) {
          return const SizedBox.shrink(); // Don't show empty summaries from cancelled requests
        }
        return _AiSummaryBanner(summary: summary);
      },
    );
  }
}

// ── AI Summary Banner ─────────────────────────────────────────────────────────

class _AiSummaryBanner extends StatelessWidget {
  final String summary;
  const _AiSummaryBanner({required this.summary});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    // In dark mode, use a darker shade with lower opacity for less glare
    final bannerPrimary = isDarkMode 
      ? primaryColor.withValues(alpha: 0.8)  // Darker/more transparent
      : primaryColor;
    final bannerSecondary = isDarkMode
      ? primaryColor.withValues(alpha: 0.5)
      : primaryColor.withValues(alpha: 0.7);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bannerPrimary,
            bannerSecondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isDarkMode ? 0.15 : 0.25),
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
                    color: Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: isDarkMode ? 0.15 : 0.25)),
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
                    color: Colors.white.withValues(alpha: isDarkMode ? 0.1 : 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Just now',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: isDarkMode ? 0.65 : 0.75),
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
                color: Colors.white.withValues(alpha: isDarkMode ? 0.87 : 1.0),
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
                    color: Colors.white.withValues(alpha: isDarkMode ? 0.55 : 0.65),
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
  final PatientHealthData? health;
  final int sosCount;

  const _StatsGrid({required this.health, required this.sosCount});

  @override
  Widget build(BuildContext context) {
    // Mood
    const moodLabels = ['Terrible 😢', 'Sad 😟', 'Okay 😐', 'Good 🙂', 'Great 😊'];
    final moodIndex = health?.mood == 'terrible' ? 0
        : health?.mood == 'sad' ? 1
        : health?.mood == 'okay' ? 2
        : health?.mood == 'good' ? 3
        : health?.mood == 'great' ? 4
        : -1;
    final moodLabel = health == null ? 'No check-in' : (moodIndex >= 0 ? moodLabels[moodIndex] : health!.mood);
    final moodGood = moodIndex >= 3;

    // Pain
    final pain = health?.painLevel ?? 0;
    final painLabel = health == null ? '— / 10' : '$pain / 10';
    final painGood = pain <= 3;
    final painSub = pain == 0 ? 'None reported' : pain <= 3 ? 'Low — stable' : pain <= 6 ? 'Moderate' : 'High — check in';

    // Meds
    final medsTaken = health?.medicationsTaken ?? 0;
    final medsTotal = health?.medicationsTotal ?? 0;
    final medsLabel = health == null ? '— / —' : '$medsTaken / $medsTotal';
    final medsGood = medsTotal == 0 || medsTaken >= medsTotal;

    // SOS
    final sosLabel = sosCount == 0 ? 'None' : sosCount.toString();
    final sosGood = sosCount == 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.mood_rounded,
                iconColor: health == null ? AppTheme.textLight : (moodGood ? AppTheme.accentGreen : AppTheme.accentOrange),
                iconBg: health == null ? AppTheme.backgroundGray : (moodGood ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED)),
                label: 'Mood Today',
                value: moodLabel,
                sub: health == null ? 'No check-in yet' : 'Reported today',
                subColor: health == null ? AppTheme.textLight : (moodGood ? AppTheme.accentGreen : AppTheme.accentOrange),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.healing_rounded,
                iconColor: health == null ? AppTheme.textLight : (painGood ? AppTheme.accentGreen : AppTheme.accentOrange),
                iconBg: health == null ? AppTheme.backgroundGray : (painGood ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED)),
                label: 'Pain Level',
                value: painLabel,
                sub: health == null ? 'No check-in yet' : painSub,
                subColor: health == null ? AppTheme.textLight : (painGood ? AppTheme.accentGreen : AppTheme.accentOrange),
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
                iconColor: medsGood ? AppTheme.accentGreen : AppTheme.accentOrange,
                iconBg: medsGood ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                label: 'Meds Taken',
                value: medsLabel,
                sub: medsTotal == 0 ? 'No meds scheduled' : (medsGood ? 'All taken' : '${medsTotal - medsTaken} remaining'),
                subColor: medsGood ? AppTheme.accentGreen : AppTheme.accentOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.emergency_rounded,
                iconColor: sosGood ? AppTheme.accentGreen : AppTheme.accentRed,
                iconBg: sosGood ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E4),
                label: 'SOS Alerts',
                value: sosLabel,
                sub: sosGood ? 'All clear today' : 'Needs attention',
                subColor: sosGood ? AppTheme.accentGreen : AppTheme.accentRed,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode 
          ? Theme.of(context).colorScheme.surface 
          : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode 
            ? Colors.white.withValues(alpha: 0.1)
            : AppTheme.divider,
        ),
        boxShadow: isDarkMode ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : [],
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
                    color: isDarkMode 
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppTheme.textMid,
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
              color: isDarkMode 
                ? Colors.white.withValues(alpha: 0.87)
                : AppTheme.textDark,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDarkMode 
        ? Theme.of(context).colorScheme.surface 
        : AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDarkMode 
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.divider,
            ),
            boxShadow: isDarkMode ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : [],
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
                          color: isDarkMode 
                            ? Colors.white.withValues(alpha: 0.87)
                            : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        sublabel,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDarkMode 
                            ? Colors.white.withValues(alpha: 0.6)
                            : AppTheme.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5) ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
        return const Color(0xFFEA580C);
      case 'checkin':
        return const Color(0xFF10B981);
      case 'alert':
      case 'warning':
        return const Color(0xFFEF4444);
      case 'chat':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF3B82F6);
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _getIconColor(type).withValues(alpha: 0.2),
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
                    color: Theme.of(context).colorScheme.onSurface,
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
        color: Theme.of(context).colorScheme.onSurface,
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

  // mood is stored as a string: 'great','good','okay','sad','terrible'
  String _moodEmoji(String mood) {
    return switch (mood) {
      'great'    => '😊',
      'good'     => '🙂',
      'okay'     => '😐',
      'sad'      => '😟',
      'terrible' => '😢',
      _          => '❓',
    };
  }

  String _moodLabel(String mood) {
    return switch (mood) {
      'great'    => 'Great',
      'good'     => 'Good',
      'okay'     => 'Okay',
      'sad'      => 'Not Great',
      'terrible' => 'Bad',
      _          => 'Unknown',
    };
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

        final emoji = _moodEmoji(healthData.mood);
        final moodLabel = _moodLabel(healthData.mood);

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
