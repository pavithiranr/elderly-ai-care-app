import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caresync_ai/core/constants/app_constants.dart';
import 'package:caresync_ai/core/theme/app_theme.dart';
import 'package:caresync_ai/shared/services/caregiver_service.dart';
import 'package:caresync_ai/shared/services/patient_service.dart';

class LinkedElderlyScreen extends StatefulWidget {
  const LinkedElderlyScreen({super.key});

  @override
  State<LinkedElderlyScreen> createState() => _LinkedElderlyScreenState();
}

class _LinkedElderlyScreenState extends State<LinkedElderlyScreen> {
  late CaregiverService _caregiverService;
  late PatientService _patientService;

  @override
  void initState() {
    super.initState();
    _caregiverService = CaregiverService.instance;
    _patientService = PatientService.instance;
  }

  Future<void> _unlinkElderly(String elderlyId, String elderlyName) async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Link?',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        content: Text(
          'You will no longer be able to monitor $elderlyName\'s health.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textMid,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppTheme.textMid,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _caregiverService.unlinkElderly(
                  elderlyId: elderlyId,
                );

                if (mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop(); // Close dialog using State's context
                  setState(() {}); // Refresh list
                }
              } catch (e) {
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error: $e',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: AppTheme.accentRed,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Remove',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppTheme.accentRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddElderlyOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect with Elderly',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 20),
            // Binding code option
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.pop();
                  context.push('/caregiver/link-elderly');
                },
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Enter Binding Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Link by Unique ID option
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.pop();
                  context.push(AppConstants.routeLinkByUniqueId);
                },
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Link by Binding ID'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Cancel
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Linked Elderly',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<CaregiverProfile?>(
        future: _caregiverService.getCurrentCaregiverProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data;
          if (profile == null) {
            return Center(
              child: Text(
                'Error loading profile',
                style: GoogleFonts.inter(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            );
          }

          final linkedIds = profile.linkedElderlyIds;

          if (linkedIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.people_outline_rounded,
                      color: AppTheme.primaryBlue,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Elderly Linked Yet',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask the elderly for their binding code\nto get started.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMid,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      onPressed: _showAddElderlyOptions,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Elderly'),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: linkedIds.length + 1,
            itemBuilder: (context, index) {
              // Add button at the end
              if (index == linkedIds.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 32),
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _showAddElderlyOptions,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Another Elderly'),
                    ),
                  ),
                );
              }

              final elderlyId = linkedIds[index];

              return FutureBuilder<PatientProfile?>(
                future: _patientService.getPatientById(elderlyId),
                builder: (context, patientSnapshot) {
                  if (patientSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final patient = patientSnapshot.data;
                  if (patient == null) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Unable to load profile',
                          style: GoogleFonts.inter(color: AppTheme.textMid),
                        ),
                      ),
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: AppTheme.primaryBlue,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patient.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ID: ${elderlyId.substring(0, 8)}...',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppTheme.textMid,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton(
                                itemBuilder: (context) => <PopupMenuEntry<dynamic>>[
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.visibility_rounded,
                                            size: 18),
                                        SizedBox(width: 8),
                                        Text('View Profile'),
                                      ],
                                    ),
                                    onTap: () {
                                      context.push('/caregiver/patient-detail/$elderlyId');
                                    },
                                  ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete_rounded,
                                            size: 18, color: AppTheme.accentRed),
                                        SizedBox(width: 8),
                                        Text(
                                          'Remove',
                                          style: TextStyle(
                                              color: AppTheme.accentRed),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      _unlinkElderly(elderlyId, patient.name);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatChip(
                                  icon: Icons.mood_rounded,
                                  label: 'Last Check-in',
                                  value: 'Today',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatChip(
                                  icon: Icons.favorite_rounded,
                                  label: 'Status',
                                  value: 'Good',
                                  valueColor: AppTheme.accentGreen,
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
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddElderlyOptions,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Link Elderly'),
      ),
    );
  }
}

// ── Stat Chip ──────────────────────────────────────────────────────────────

// ── Helper Widget ──────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.textMid),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMid,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
