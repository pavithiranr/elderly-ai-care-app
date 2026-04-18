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

/// Medication reminder screen — loads from Firestore, supports add/delete.
class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  String? _patientId;
  List<Medication> _meds = [];
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
          .map((d) => Medication.fromFirestore(d.id, d.data()))
          .toList();

      final takenToday = <String, bool>{};
      for (final med in meds) {
        final logSnap = await firestore
            .collection('elderly')
            .doc(id)
            .collection('medications')
            .doc(med.id)
            .collection('logs')
            .where('timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                    DateTime(today.year, today.month, today.day)))
            .where('timestamp',
                isLessThan: Timestamp.fromDate(
                    DateTime(today.year, today.month, today.day + 1)))
            .limit(1)
            .get();
        takenToday[med.id] = logSnap.docs.isNotEmpty;
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
          const SnackBar(content: Text('Could not remove — please try again')),
        );
      }
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddMedicationDialog(
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
      await PatientService.instance.addMedication(
        id,
        name: name,
        dosage: dosage,
        times: times,
        frequency: frequency,
        note: note,
      );

      // Schedule notifications
      await NotificationService.instance.scheduleMedicationNotifications(
        medicationId: '${DateTime.now().millisecondsSinceEpoch}',
        medicationName: name,
        dosage: dosage,
        times: times,
        frequency: frequency,
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
                      final taken = _takenToday[med.id] ?? false;
                      final label = [
                        if (med.dosage.isNotEmpty) med.dosage,
                        if (med.note.isNotEmpty) med.note,
                      ].join('  ·  ');

                      return Dismissible(
                        key: ValueKey(med.id),
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
                          await _deleteMed(med.id);
                          return false;
                        },
                        child: _MedicationCard(
                          name: med.name,
                          times: med.times,
                          frequency: med.frequency,
                          label: label,
                          taken: taken,
                          onChanged: (v) => _toggleMed(med.id, v ?? false),
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
  final List<String> times;
  final String frequency;
  final String label;
  final bool taken;
  final ValueChanged<bool?> onChanged;

  const _MedicationCard({
    required this.name,
    required this.times,
    required this.frequency,
    required this.label,
    required this.taken,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final dividerColor = Theme.of(context).dividerColor;
    final timesStr = times.join(', ');
    final subtitle = [if (timesStr.isNotEmpty) timesStr, if (label.isNotEmpty) label]
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
                      '$subtitle  ·  $frequency',
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

// ── Add Medication Dialog (with Time Picker & Accessible Design) ─────────────

class _AddMedicationDialog extends StatefulWidget {
  final Function(String name, String dosage, List<String> times, String frequency, String note) onAdd;

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
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // ── Multiple Times Section ────────────────────────────
              Text(
                'Times to Take',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
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
                  children: _selectedTimes.map((time) {
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
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[\d.]'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Dosage',
                  hintText: 'e.g. 500',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: GoogleFonts.inter(fontSize: 16),
              ),
              const SizedBox(height: 12),

              // ── Unit ───────────────────────────────────────────────
              DropdownButtonFormField<String>(
                initialValue: _selectedUnit,
                isDense: true,
                items: ['mg', 'mcg', 'ml', 'tablets'].map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(unit, style: GoogleFonts.inter(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (unit) {
                  setState(() => _selectedUnit = unit);
                },
                decoration: InputDecoration(
                  labelText: 'Unit',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // ── Frequency ─────────────────────────────────────────
              DropdownButtonFormField<String>(
                initialValue: _selectedFrequency,
                isDense: true,
                items: ['Daily', 'Every Other Day', 'Weekly'].map((freq) {
                  return DropdownMenuItem(
                    value: freq,
                    child: Text(freq, style: GoogleFonts.inter(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (freq) {
                  setState(() => _selectedFrequency = freq ?? 'Daily');
                },
                decoration: InputDecoration(
                  labelText: 'Frequency',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // ── Note ───────────────────────────────────────────────
              TextFormField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Take with food',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
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
          color: isSelected 
            ? Colors.white 
            : Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.transparent,
      selectedColor: Theme.of(context).colorScheme.primary,
      side: BorderSide(
        color: isSelected 
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: GoogleFonts.inter(fontSize: 16),
    );
  }
}
