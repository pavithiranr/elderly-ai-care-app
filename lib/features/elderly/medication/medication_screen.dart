import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/medication_model.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/patient_service.dart';
import '../../../shared/services/user_session_service.dart';

/// Medication reminder screen - loads from Firestore, supports add/delete.
class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen>
    with TickerProviderStateMixin {
  String? _patientId;
  List<Medication> _meds = [];
  Map<String, bool> _takenToday = {};
  Map<String, DateTime> _takenTimestamps = {};
  late TabController _tabController;
  bool _loading = true;

  /// Get medications not yet taken today
  List<Medication> get _remainingMeds {
    final remaining = <Medication>[];
    for (final med in _meds) {
      final isTaken = _takenToday[med.id] ?? false;
      if (!isTaken) {
        remaining.add(med);
      }
    }
    return remaining;
  }

  /// Get medications already taken today
  List<Medication> get _completedMeds {
    final completed = <Medication>[];
    for (final med in _meds) {
      final isTaken = _takenToday[med.id] ?? false;
      if (isTaken) {
        completed.add(med);
      }
    }
    return completed;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Get start and end timestamps for today
  ({Timestamp start, Timestamp end}) _getDateRange() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day + 1);
    final result = (
      start: Timestamp.fromDate(startOfDay),
      end: Timestamp.fromDate(endOfDay),
    );
    return result;
  }

  Future<void> _load() async {
    final id = await UserSessionService.instance.getSavedUserId();
    if (id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final dateRange = _getDateRange();

      // Fetch all medications
      final medsSnap =
          await firestore
              .collection('elderly')
              .doc(id)
              .collection('medications')
              .orderBy('createdAt')
              .get();

      final meds =
          medsSnap.docs
              .map((d) => Medication.fromFirestore(d.id, d.data()))
              .toList();

      // Batch-fetch all logs for today (optimization: no N+1 queries)
      final takenToday = <String, bool>{};
      final takenTimestamps = <String, DateTime>{};

      // Initialize all meds as NOT taken
      for (final med in meds) {
        takenToday[med.id] = false;
      }

      // Then check if any have logs
      for (final med in meds) {
        final logSnap =
            await firestore
                .collection('elderly')
                .doc(id)
                .collection('medications')
                .doc(med.id)
                .collection('logs')
                .where('timestamp', isGreaterThanOrEqualTo: dateRange.start)
                .where('timestamp', isLessThan: dateRange.end)
                .orderBy('timestamp', descending: true)
                .limit(1)
                .get();

        if (logSnap.docs.isNotEmpty) {
          final doc = logSnap.docs.first;
          takenToday[med.id] = true;
          final timestamp = (doc.data()['timestamp'] as Timestamp).toDate();
          takenTimestamps[med.id] = timestamp;
        }
      }

      if (mounted) {
        setState(() {
          _patientId = id;
          _meds = meds;
          _takenToday = takenToday;
          _takenTimestamps = takenTimestamps;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleMed(String medId, bool newValue) async {
    final id = _patientId;
    if (id == null) return;

    // Optimistic update
    final oldValue = _takenToday[medId];
    setState(() {
      _takenToday[medId] = newValue;
      if (newValue) {
        _takenTimestamps[medId] = DateTime.now();
      } else {
        _takenTimestamps.remove(medId);
      }
    });

    try {
      if (newValue) {
        await PatientService.instance.logMedicationDose(id, medId);
      } else {
        final firestore = FirebaseFirestore.instance;
        final dateRange = _getDateRange();
        final logSnap =
            await firestore
                .collection('elderly')
                .doc(id)
                .collection('medications')
                .doc(medId)
                .collection('logs')
                .where('timestamp', isGreaterThanOrEqualTo: dateRange.start)
                .where('timestamp', isLessThan: dateRange.end)
                .get();
        for (final doc in logSnap.docs) {
          await doc.reference.delete();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _takenToday[medId] = oldValue ?? false;
          if (oldValue == true) {
            _takenTimestamps[medId] = _takenTimestamps[medId] ?? DateTime.now();
          } else {
            _takenTimestamps.remove(medId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save - please try again')),
        );
      }
    }
  }

  Future<void> _deleteMed(String medId) async {
    final id = _patientId;
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              'Remove medication?',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'This medication will be removed from your list.',
              style: GoogleFonts.inter(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      // Cancel scheduled notifications
      await NotificationService.instance.cancelMedicationNotifications(medId);

      await PatientService.instance.deleteMedication(id, medId);
      setState(() {
        _meds.removeWhere((m) => m.id == medId);
        _takenToday.remove(medId);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove - please try again')),
        );
      }
    }
  }

  void _showMedicationHistory() {
    if (_patientId == null) return;
    showDialog(
      context: context,
      builder:
          (ctx) => _MedicationHistoryScreen(
            patientId: _patientId!,
            medications: _meds,
          ),
    );
  }

  void _showMedicationInfoSheet(Medication med) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _MedicationInfoSheet(medication: med),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => _AddMedicationDialog(
            onAdd: (name, dosage, times, frequency, note) async {
              Navigator.pop(ctx);
              await _addMed(
                name: name,
                dosage: dosage,
                times: times,
                frequency: frequency,
                note: note,
              );
            },
          ),
    );
  }

  Future<void> _addMed({
    required String name,
    required String dosage,
    required List<String> times,
    required String frequency,
    required String note,
  }) async {
    final id = _patientId;
    if (id == null) return;

    try {
      // Add medication and get the real Firestore document ID
      final medicationId = await PatientService.instance.addMedication(
        id,
        name: name,
        dosage: dosage,
        times: times,
        frequency: frequency,
        note: note,
      );

      // Schedule notifications with the REAL medication ID
      await NotificationService.instance.scheduleMedicationNotifications(
        medicationId: medicationId,
        medicationName: name,
        dosage: dosage,
        times: times,
        frequency: frequency,
      );

      // Reload to update the UI
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add medication')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _meds.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Medications'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Medication history',
              onPressed: _showMedicationHistory,
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add medication',
              onPressed: _patientId == null ? null : _showAddDialog,
            ),
          ],
          bottom:
              total == 0
                  ? null
                  : TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Remaining'),
                      Tab(text: 'Completed'),
                    ],
                  ),
        ),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _meds.isEmpty
                ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.medication_outlined,
                        size: 64,
                        color: AppTheme.textLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No medications yet',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add your first medication',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                )
                : TabBarView(
                  controller: _tabController,
                  children: [
                    // ─── REMAINING TAB ───────────────────────────────────────
                    RefreshIndicator(
                      onRefresh: _load,
                      child:
                          _remainingMeds.isEmpty
                              ? SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 80,
                                        color: AppTheme.accentGreen,
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Great job! 🌟',
                                        style: GoogleFonts.inter(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'You are all caught up for today',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: AppTheme.textMid,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              : ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(20),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryLight,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          color: AppTheme.primaryBlue,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            '${_remainingMeds.length} of $total medications remaining today',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: AppTheme.primaryBlue,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ..._remainingMeds.map((med) {
                                    final label = [
                                      if (med.dosage.isNotEmpty) med.dosage,
                                      if (med.note.isNotEmpty) med.note,
                                    ].join('  ·  ');

                                    return Dismissible(
                                      key: ValueKey('${med.id}-remaining'),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                          right: 20,
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.delete_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      confirmDismiss: (_) async {
                                        await _deleteMed(med.id);
                                        return false;
                                      },
                                      child: _MedicationCard(
                                        name: med.name,
                                        times: med.times,
                                        frequency: med.frequency,
                                        label: label,
                                        taken: false,
                                        onChanged:
                                            (v) =>
                                                _toggleMed(med.id, v ?? false),
                                        onInfoTap:
                                            () => _showMedicationInfoSheet(med),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _showAddDialog,
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Add medication'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryBlue,
                                      textStyle: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                    ),

                    // ─── COMPLETED TAB ───────────────────────────────────────
                    RefreshIndicator(
                      onRefresh: _load,
                      child:
                          _completedMeds.isEmpty
                              ? SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.hourglass_empty_rounded,
                                        size: 64,
                                        color: AppTheme.textLight,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No medications completed yet',
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textMid,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              : ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(20),
                                children: [
                                  ..._completedMeds.map((med) {
                                    final label = [
                                      if (med.dosage.isNotEmpty) med.dosage,
                                      if (med.note.isNotEmpty) med.note,
                                    ].join('  ·  ');
                                    final takenTime = _takenTimestamps[med.id];

                                    return Dismissible(
                                      key: ValueKey('${med.id}-completed'),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                          right: 20,
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.delete_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      confirmDismiss: (_) async {
                                        await _deleteMed(med.id);
                                        return false;
                                      },
                                      child: _MedicationCard(
                                        name: med.name,
                                        times: med.times,
                                        frequency: med.frequency,
                                        label: label,
                                        taken: true,
                                        takenTime: takenTime,
                                        onChanged:
                                            (v) =>
                                                _toggleMed(med.id, v ?? false),
                                        onInfoTap:
                                            () => _showMedicationInfoSheet(med),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final String name;
  final List<String> times;
  final String frequency;
  final String label;
  final bool taken;
  final DateTime? takenTime;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onInfoTap;

  const _MedicationCard({
    required this.name,
    required this.times,
    required this.frequency,
    required this.label,
    required this.taken,
    this.takenTime,
    required this.onChanged,
    this.onInfoTap,
  });

  /// Format DateTime to 12-hour time string (e.g., "08:15 AM")
  String _formatTakenTime(DateTime dt) {
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final displayHour =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${displayHour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final dividerColor = Theme.of(context).dividerColor;
    final timesStr = times.join(', ');
    final statusText =
        taken && takenTime != null
            ? 'Taken at ${_formatTakenTime(takenTime!)}'
            : timesStr;
    final subtitle = [
      if (statusText.isNotEmpty) statusText,
      if (label.isNotEmpty && !taken) label,
    ].join('  ·  ');
    final opacity = taken ? 0.6 : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:
            taken
                ? surfaceColor.withAlpha((220 * opacity).toInt())
                : surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: taken ? AppTheme.accentGreen : dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status indicator
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: taken ? AppTheme.accentGreen : AppTheme.textLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),

          // Med info (name, dosage, times) - expand to fill available space
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: AppTheme.elderlyBodyFontSize,
                    fontWeight: FontWeight.w600,
                    color: taken ? AppTheme.textMid : AppTheme.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$subtitle${!taken ? '  ·  $frequency' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: taken ? AppTheme.textLight : AppTheme.textMid,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Info icon (if provided)
          if (onInfoTap != null)
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                onPressed: onInfoTap,
                icon: const Icon(Icons.info_rounded, size: 20),
                color: AppTheme.primaryBlue,
                tooltip: 'Medication info',
                padding: EdgeInsets.zero,
              ),
            )
          else
            const SizedBox(width: 40), // Placeholder for alignment

          const SizedBox(width: 8),

          // Checkbox (standard size, no transform)
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: taken,
              activeColor: AppTheme.accentGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Medication Info Bottom Sheet ──────────────────────────────────────────

/// Medication info bottom sheet - displays med details and purpose (fetched from openFDA)
class _MedicationInfoSheet extends StatefulWidget {
  final Medication medication;

  const _MedicationInfoSheet({required this.medication});

  @override
  State<_MedicationInfoSheet> createState() => _MedicationInfoSheetState();
}

class _MedicationInfoSheetState extends State<_MedicationInfoSheet> {
  late Future<String> _drugInfoFuture;

  @override
  void initState() {
    super.initState();
    _drugInfoFuture = PatientService.instance.fetchDrugInfo(
      widget.medication.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.medication.name,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _InfoRow(
              icon: Icons.local_pharmacy_rounded,
              label: 'Dosage',
              value:
                  widget.medication.dosage.isNotEmpty
                      ? widget.medication.dosage
                      : '-',
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.schedule_rounded,
              label: 'Times',
              value: widget.medication.times.join(', '),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.repeat_rounded,
              label: 'Frequency',
              value: widget.medication.frequency,
            ),
            const SizedBox(height: 20),
            Text(
              'Purpose',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<String>(
              future: _drugInfoFuture,
              builder: (context, snapshot) {
                String displayText =
                    widget.medication.note.isNotEmpty
                        ? widget.medication.note
                        : 'Helps manage your health and well-being';

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryBlue,
                            ),
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Loading information from FDA...',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textMid,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  displayText =
                      'Unable to fetch information. Please follow your doctor\'s prescription.';
                }

                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  displayText = snapshot.data!;
                }

                return Text(
                  displayText,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppTheme.textDark,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget for info sheet rows
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textLight,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Full medication history screen showing logs for all medications
class _MedicationHistoryScreen extends StatefulWidget {
  final String patientId;
  final List<Medication> medications;

  const _MedicationHistoryScreen({
    required this.patientId,
    required this.medications,
  });

  @override
  State<_MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<_MedicationHistoryScreen> {
  late Map<String, List<Map<String, dynamic>>> _allLogs;
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _loadAllHistory();
  }

  Future<void> _loadAllHistory() async {
    _allLogs = {};
    for (final med in widget.medications) {
      final logs = await PatientService.instance.getMedicationHistory(
        widget.patientId,
        med.id,
      );
      _allLogs[med.id] = logs;
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  /// Get all logs for a specific date
  Map<String, bool> _getLogsForDate(DateTime date) {
    final result = <String, bool>{};

    for (final med in widget.medications) {
      final logs = _allLogs[med.id] ?? [];
      final takenOnDate = logs.any((log) {
        final logDate = log['timestamp'] as DateTime;
        return logDate.year == date.year &&
            logDate.month == date.month &&
            logDate.day == date.day;
      });
      result[med.id] = takenOnDate;
    }

    return result;
  }

  /// Check adherence for a date (how many of total meds were taken)
  (int taken, int total) _getAdherenceForDate(DateTime date) {
    final logsForDate = _getLogsForDate(date);
    final taken = logsForDate.values.where((v) => v).length;
    return (taken, widget.medications.length);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Medication History',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── CALENDAR SECTION ────────────────────────────────────
                        _buildMonthHeader(),
                        const SizedBox(height: 16),
                        _buildCalendarGrid(),
                        const SizedBox(height: 24),

                        // ─── SELECTED DATE DETAILS ──────────────────────────────
                        _buildDateDetails(),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month - 1,
                );
              });
            },
          ),
          Text(
            _getMonthYearString(_currentMonth),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month + 1,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  String _getMonthYearString(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startingWeekday = firstDay.weekday; // 1=Monday, 7=Sunday

    // Create list of days (with empty slots for days before month starts)
    final days = <DateTime?>[];
    for (int i = 1; i < startingWeekday; i++) {
      days.add(null);
    }
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }

    return Column(
      children: [
        // Day header (Mon, Tue, etc.)
        Row(
          children:
              const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMid,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 12),

        // Calendar days
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final date = days[index];
            if (date == null) {
              return const SizedBox.shrink();
            }

            final isSelected =
                _selectedDate.year == date.year &&
                _selectedDate.month == date.month &&
                _selectedDate.day == date.day;
            final isToday =
                DateTime.now().year == date.year &&
                DateTime.now().month == date.month &&
                DateTime.now().day == date.day;

            final (taken, total) = _getAdherenceForDate(date);
            final adherencePercent =
                total > 0 ? (taken / total * 100).toInt() : 0;

            return GestureDetector(
              onTap: () {
                setState(() => _selectedDate = date);
              },
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? AppTheme.primaryBlue
                          : isToday
                          ? AppTheme.primaryLight
                          : AppTheme.backgroundGray,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      isToday && !isSelected
                          ? Border.all(color: AppTheme.primaryBlue, width: 2)
                          : null,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 0,
                        ),
                        decoration: BoxDecoration(
                          color: _getAdherenceColor(
                            adherencePercent,
                          ).withAlpha(isSelected ? 200 : 150),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '$taken/$total',
                          style: GoogleFonts.inter(
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getAdherenceColor(int percent) {
    if (percent == 100) return AppTheme.accentGreen;
    if (percent >= 66) return const Color(0xFFF59E0B); // Amber
    if (percent > 0) return const Color(0xFFEF4444); // Red
    return AppTheme.textLight; // Gray for no doses
  }

  Widget _buildDateDetails() {
    final logsForDate = _getLogsForDate(_selectedDate);
    final dateStr = _formatDateFull(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: AppTheme.divider, height: 1),
        const SizedBox(height: 20),
        Text(
          'Medications for $dateStr',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),
        if (widget.medications.isEmpty)
          Center(
            child: Text(
              'No medications to display',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMid,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.medications.length,
            itemBuilder: (context, index) {
              final med = widget.medications[index];
              final wasTaken = logsForDate[med.id] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      wasTaken
                          ? AppTheme.primaryLight
                          : AppTheme.backgroundGray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: wasTaken ? AppTheme.primaryBlue : AppTheme.divider,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Status icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            wasTaken
                                ? AppTheme.accentGreen
                                : AppTheme.textLight,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          wasTaken ? Icons.check_rounded : Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Medication info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${med.dosage} • ${med.times.join(", ")}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status label
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            wasTaken
                                ? AppTheme.accentGreen.withAlpha(200)
                                : AppTheme.accentRed.withAlpha(200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        wasTaken ? 'Taken' : 'Missed',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  String _formatDateFull(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayOfWeek = days[date.weekday - 1];
    return '$dayOfWeek, ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ── Add Medication Dialog (with Time Picker & Accessible Design) ─────────────

class _AddMedicationDialog extends StatefulWidget {
  final Function(
    String name,
    String dosage,
    List<String> times,
    String frequency,
    String note,
  )
  onAdd;

  const _AddMedicationDialog({required this.onAdd});

  @override
  State<_AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<_AddMedicationDialog> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<String> _selectedTimes = []; // List of times like "08:00", "20:00"
  String? _selectedUnit = 'mg';
  String _selectedFrequency = 'Daily';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Format TimeOfDay to 24-hour format "HH:MM"
  String _formatTimeForStorage(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Format TimeOfDay to readable 12-hour format
  String _formatTimeForDisplay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return timeStr;

      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${displayHour.toString().padLeft(2, '0')}:$minute $period';
    } catch (_) {
      return timeStr;
    }
  }

  /// Open native time picker
  Future<void> _openTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final timeStr = _formatTimeForStorage(picked);
      if (!_selectedTimes.contains(timeStr)) {
        setState(() => _selectedTimes.add(timeStr));
        // Sort times
        _selectedTimes.sort();
      }
    }
  }

  /// Remove a time from selection
  void _removeTime(String time) {
    setState(() => _selectedTimes.remove(time));
  }

  /// Quick select time chip
  void _setQuickTime(int hour) {
    final timeStr = '${hour.toString().padLeft(2, '0')}:00';
    if (!_selectedTimes.contains(timeStr)) {
      setState(() => _selectedTimes.add(timeStr));
      _selectedTimes.sort();
    }
  }

  /// Format dosage with unit
  String _formatDosage() {
    final dosage = _dosageCtrl.text.trim();
    if (dosage.isEmpty) return '';
    return '$dosage $_selectedUnit';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one time')),
      );
      return;
    }

    widget.onAdd(
      _nameCtrl.text.trim(),
      _formatDosage(),
      _selectedTimes,
      _selectedFrequency,
      _noteCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Add Medication',
        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Medication Name ────────────────────────────────────
              _DialogField(
                controller: _nameCtrl,
                label: 'Medication Name',
                hint: 'e.g. Metformin, Aspirin, Lisinopril',
                validator:
                    (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // ── Multiple Times Section ────────────────────────────
              Text(
                'Times to Take',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Quick select chips
              Wrap(
                spacing: 8,
                children: [
                  _QuickTimeChip(
                    label: 'Morning (8 AM)',
                    isSelected: _selectedTimes.contains('08:00'),
                    onTap: () => _setQuickTime(8),
                  ),
                  _QuickTimeChip(
                    label: 'Noon (12 PM)',
                    isSelected: _selectedTimes.contains('12:00'),
                    onTap: () => _setQuickTime(12),
                  ),
                  _QuickTimeChip(
                    label: 'Afternoon (2 PM)',
                    isSelected: _selectedTimes.contains('14:00'),
                    onTap: () => _setQuickTime(14),
                  ),
                  _QuickTimeChip(
                    label: 'Evening (8 PM)',
                    isSelected: _selectedTimes.contains('20:00'),
                    onTap: () => _setQuickTime(20),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Time picker button
              ElevatedButton.icon(
                onPressed: _openTimePicker,
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  'Select Custom Time',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 12),

              // Display selected times as removable chips
              if (_selectedTimes.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _selectedTimes.map((time) {
                        return Chip(
                          label: Text(
                            _formatTimeForDisplay(time),
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          onDeleted: () => _removeTime(time),
                          backgroundColor: AppTheme.primaryLight,
                          deleteIconColor: AppTheme.primaryBlue,
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // ── Dosage ────────────────────────────────────────────
              TextFormField(
                controller: _dosageCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Dosage',
                  hintText: 'e.g. 500',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                style: GoogleFonts.inter(fontSize: 16),
              ),
              const SizedBox(height: 12),

              // ── Unit ───────────────────────────────────────────────
              DropdownButtonFormField<String>(
                initialValue: _selectedUnit,
                isDense: true,
                items:
                    ['mg', 'mcg', 'ml', 'tablets'].map((unit) {
                      return DropdownMenuItem(
                        value: unit,
                        child: Text(
                          unit,
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      );
                    }).toList(),
                onChanged: (unit) {
                  setState(() => _selectedUnit = unit);
                },
                decoration: InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Frequency ─────────────────────────────────────────
              DropdownButtonFormField<String>(
                initialValue: _selectedFrequency,
                isDense: true,
                items:
                    ['Daily', 'Every Other Day', 'Weekly'].map((freq) {
                      return DropdownMenuItem(
                        value: freq,
                        child: Text(
                          freq,
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      );
                    }).toList(),
                onChanged: (freq) {
                  setState(() => _selectedFrequency = freq ?? 'Daily');
                },
                decoration: InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Note ───────────────────────────────────────────────
              TextFormField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Take with food',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                maxLines: 2,
                style: GoogleFonts.inter(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: Text(
              'Add Medication',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

// ── Quick Time Selection Chip ──────────────────────────────────────────────

class _QuickTimeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickTimeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color:
              isSelected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.transparent,
      selectedColor: Theme.of(context).colorScheme.primary,
      side: BorderSide(
        color:
            isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;

  const _DialogField({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      style: GoogleFonts.inter(fontSize: 16),
    );
  }
}
