import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/patient_service.dart';
import '../../../shared/services/user_session_service.dart';

/// Medication reminder screen — loads from Firestore, supports add/delete.
class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  String? _patientId;
  List<Map<String, dynamic>> _meds = [];
  Map<String, bool> _takenToday = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await UserSessionService.instance.getSavedUserId();
    if (id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final today = DateTime.now();

      final medsSnap = await firestore
          .collection('elderly')
          .doc(id)
          .collection('medications')
          .orderBy('createdAt')
          .get();

      final meds = medsSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      final takenToday = <String, bool>{};
      for (final med in meds) {
        final medId = med['id'] as String;
        final logSnap = await firestore
            .collection('elderly')
            .doc(id)
            .collection('medications')
            .doc(medId)
            .collection('logs')
            .where('timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                    DateTime(today.year, today.month, today.day)))
            .where('timestamp',
                isLessThan: Timestamp.fromDate(
                    DateTime(today.year, today.month, today.day + 1)))
            .limit(1)
            .get();
        takenToday[medId] = logSnap.docs.isNotEmpty;
      }

      if (mounted) {
        setState(() {
          _patientId = id;
          _meds = meds;
          _takenToday = takenToday;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('MedicationScreen load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleMed(String medId, bool newValue) async {
    final id = _patientId;
    if (id == null) return;

    setState(() => _takenToday[medId] = newValue);

    try {
      if (newValue) {
        await PatientService.instance.logMedicationDose(id, medId);
      } else {
        final firestore = FirebaseFirestore.instance;
        final today = DateTime.now();
        final logSnap = await firestore
            .collection('elderly')
            .doc(id)
            .collection('medications')
            .doc(medId)
            .collection('logs')
            .where('timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                    DateTime(today.year, today.month, today.day)))
            .where('timestamp',
                isLessThan: Timestamp.fromDate(
                    DateTime(today.year, today.month, today.day + 1)))
            .get();
        for (final doc in logSnap.docs) {
          await doc.reference.delete();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _takenToday[medId] = !newValue);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save — please try again')),
        );
      }
    }
  }

  Future<void> _deleteMed(String medId) async {
    final id = _patientId;
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove medication?',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600)),
        content: Text('This medication will be removed from your list.',
            style: GoogleFonts.inter(fontSize: 16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await PatientService.instance.deleteMedication(id, medId);
      setState(() {
        _meds.removeWhere((m) => m['id'] == medId);
        _takenToday.remove(medId);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove — please try again')),
        );
      }
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Medication',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(
                  controller: nameCtrl,
                  label: 'Medication Name',
                  hint: 'e.g. Metformin',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _DialogField(
                  controller: dosageCtrl,
                  label: 'Dosage',
                  hint: 'e.g. 500mg',
                ),
                const SizedBox(height: 12),
                _DialogField(
                  controller: timeCtrl,
                  label: 'Time',
                  hint: 'e.g. 8:00 AM',
                  inputFormatters: [LengthLimitingTextInputFormatter(20)],
                ),
                const SizedBox(height: 12),
                _DialogField(
                  controller: noteCtrl,
                  label: 'Note (optional)',
                  hint: 'e.g. Take with food',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await _addMed(
                name: nameCtrl.text.trim(),
                dosage: dosageCtrl.text.trim(),
                time: timeCtrl.text.trim(),
                note: noteCtrl.text.trim(),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMed({
    required String name,
    required String dosage,
    required String time,
    required String note,
  }) async {
    final id = _patientId;
    if (id == null) return;

    try {
      await PatientService.instance.addMedication(
        id,
        name: name,
        dosage: dosage,
        time: time,
        note: note,
      );
      // Reload to get the new doc ID from Firestore
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add medication')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final takenCount = _takenToday.values.where((v) => v).length;
    final total = _meds.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Medications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add medication',
            onPressed: _patientId == null ? null : _showAddDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _meds.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.medication_outlined,
                          size: 64, color: AppTheme.textLight),
                      const SizedBox(height: 16),
                      Text(
                        'No medications yet',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMid),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add your first medication',
                        style: GoogleFonts.inter(
                            fontSize: 16, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Summary chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppTheme.primaryBlue, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            '$takenCount of $total medications taken today',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "Today's Schedule",
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 14),

                    ..._meds.map((med) {
                      final medId = med['id'] as String;
                      final taken = _takenToday[medId] ?? false;
                      final label = [
                        if ((med['dosage'] as String? ?? '').isNotEmpty)
                          med['dosage'] as String,
                        if ((med['note'] as String? ?? '').isNotEmpty)
                          med['note'] as String,
                      ].join('  ·  ');

                      return Dismissible(
                        key: ValueKey(medId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_rounded,
                              color: Colors.white, size: 28),
                        ),
                        confirmDismiss: (_) async {
                          await _deleteMed(medId);
                          return false; // We handle removal in _deleteMed
                        },
                        child: _MedicationCard(
                          name: med['name'] as String? ?? 'Unknown',
                          time: med['time'] as String? ?? '',
                          label: label,
                          taken: taken,
                          onChanged: (v) => _toggleMed(medId, v ?? false),
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
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final String name;
  final String time;
  final String label;
  final bool taken;
  final ValueChanged<bool?> onChanged;

  const _MedicationCard({
    required this.name,
    required this.time,
    required this.label,
    required this.taken,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final dividerColor = Theme.of(context).dividerColor;
    final subtitle = [if (time.isNotEmpty) time, if (label.isNotEmpty) label]
        .join('  ·  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: taken ? AppTheme.accentGreen : dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: taken ? AppTheme.accentGreen : AppTheme.textLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: AppTheme.elderlyBodyFontSize,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppTheme.textMid),
                    ),
                  ),
              ],
            ),
          ),
          Checkbox(
            value: taken,
            activeColor: AppTheme.accentGreen,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const _DialogField({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: GoogleFonts.inter(fontSize: 16),
    );
  }
}
