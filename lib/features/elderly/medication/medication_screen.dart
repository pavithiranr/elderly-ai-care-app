import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// Medication reminder screen — placeholder list ready for Firestore integration.
class MedicationScreen extends StatelessWidget {
  const MedicationScreen({super.key});

  // Placeholder data — replace with Firestore stream
  static const List<_MedItem> _meds = [
    _MedItem(
        name: 'Metformin 500mg',
        time: '8:00 AM',
        note: 'Take with food',
        taken: true),
    _MedItem(
        name: 'Lisinopril 10mg',
        time: '8:00 AM',
        note: 'Blood pressure',
        taken: true),
    _MedItem(
        name: 'Vitamin D3',
        time: '12:00 PM',
        note: 'With lunch',
        taken: false),
    _MedItem(
        name: 'Atorvastatin 20mg',
        time: '9:00 PM',
        note: 'Cholesterol — take at night',
        taken: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Medications'),
        backgroundColor: AppTheme.surfaceWhite,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Summary chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  '2 of 4 medications taken today',
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
            'Today\'s Schedule',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 14),

          ..._meds.map((med) => _MedicationCard(med: med)),
        ],
      ),
    );
  }
}

class _MedicationCard extends StatefulWidget {
  final _MedItem med;
  const _MedicationCard({required this.med});

  @override
  State<_MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<_MedicationCard> {
  late bool _taken;

  @override
  void initState() {
    super.initState();
    _taken = widget.med.taken;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _taken ? AppTheme.accentGreen : AppTheme.divider,
        ),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _taken ? AppTheme.accentGreen : AppTheme.textLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.med.name,
                  style: GoogleFonts.inter(
                    fontSize: AppTheme.elderlyBodyFontSize,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.med.time}  ·  ${widget.med.note}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textMid,
                  ),
                ),
              ],
            ),
          ),
          // Mark as taken checkbox
          Checkbox(
            value: _taken,
            activeColor: AppTheme.accentGreen,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onChanged: (v) {
              setState(() => _taken = v ?? false);
              // TODO: update Firestore
            },
          ),
        ],
      ),
    );
  }
}

class _MedItem {
  final String name;
  final String time;
  final String note;
  final bool taken;
  const _MedItem(
      {required this.name,
      required this.time,
      required this.note,
      required this.taken});
}
