import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caresync_ai/core/theme/app_theme.dart';
import 'package:caresync_ai/shared/services/user_session_service.dart';
import 'package:caresync_ai/shared/services/patient_service.dart';

class LinkByUniqueIdScreen extends StatefulWidget {
  const LinkByUniqueIdScreen({super.key});

  @override
  State<LinkByUniqueIdScreen> createState() => _LinkByUniqueIdScreenState();
}

class _LinkByUniqueIdScreenState extends State<LinkByUniqueIdScreen> {
  final _idController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _handleLinkElderly() async {
    final uniqueId = _idController.text.trim().toUpperCase();

    if (uniqueId.isEmpty) {
      setState(() => _errorMessage = 'Please enter the elderly\'s binding ID');
      return;
    }

    if (uniqueId.length != 8) {
      setState(() => _errorMessage = 'Binding ID must be 8 characters');
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });

    try {
      // Look up the elderly by unique ID
      final patient = await PatientService.instance.getPatientByUniqueId(uniqueId);

      if (patient == null) {
        setState(() {
          _errorMessage = 'Binding ID not found. Please check and try again.';
        });
        return;
      }

      // Check if already linked to another caregiver
      if (patient.caregiverId != null) {
        setState(() {
          _errorMessage = '${patient.name} is already linked to a caregiver.';
        });
        return;
      }

      // Get current caregiver UID
      final caregiverUid = UserSessionService.instance.getCurrentUserUid();
      if (caregiverUid == null) {
        throw Exception('Not logged in');
      }

      // Link the elderly to this caregiver
      await _linkElderlyToCaregiver(patient.id, caregiverUid);

      if (!mounted) return;

      // Show success dialog
      _showSuccessDialog(patient.name);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _linkElderlyToCaregiver(String elderlyId, String caregiverUid) async {
    try {
      // Update elderly document with caregiver ID
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('elderly').doc(elderlyId).update({
        'caregiverId': caregiverUid,
      });

      // Add elderly to caregiver's linked list
      await firestore.collection('caregivers').doc(caregiverUid).update({
        'linkedElderlyIds': FieldValue.arrayUnion([elderlyId])
      });
    } catch (e) {
      throw Exception('Failed to link elderly: $e');
    }
  }

  void _showSuccessDialog(String elderlyName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.accentGreen,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Linked Successfully!',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are now connected with $elderlyName.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMid,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Close binding screen and refresh list
                  context.pop();
                },
                child: Text(
                  'Continue',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
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
      backgroundColor: AppTheme.backgroundGray,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Link by Binding ID',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Text(
              'Enter Binding ID',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask the elderly person for their 8-character Binding ID. They can find it in their Settings under "Share Your Binding ID".',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textMid,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),

            // Input Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Binding ID (8 characters)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMid,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _idController,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'e.g., A7K3M2P9',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppTheme.textLight,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.divider,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.divider,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryBlue,
                          width: 2,
                        ),
                      ),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            // Error Message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Success Message
            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentGreen),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.accentGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLinkElderly,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  disabledBackgroundColor:
                      AppTheme.primaryBlue.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Link Elderly',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_rounded,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'About Binding IDs',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Each elderly user gets a unique 8-character Binding ID when they create their account\n• The ID is permanent and can be found in their Settings\n• You can only link with one elderly person per account\n• Once linked, you\'ll see all their health updates',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textMid,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
