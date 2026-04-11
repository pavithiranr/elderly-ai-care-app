import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/user_session_service.dart';
import '../../core/services/auth_service.dart';

/// Re-login screen for returning elderly users.
/// Identifies them by name + date of birth — no codes needed.
class ElderlyExistingProfileLoginScreen extends StatefulWidget {
  const ElderlyExistingProfileLoginScreen({super.key});

  @override
  State<ElderlyExistingProfileLoginScreen> createState() =>
      _ElderlyExistingProfileLoginScreenState();
}

class _ElderlyExistingProfileLoginScreenState
    extends State<ElderlyExistingProfileLoginScreen> {
  final _nameController = TextEditingController();
  DateTime? _selectedDOB;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime(1950),
      firstDate: DateTime(1920),
      lastDate: DateTime(DateTime.now().year - 18),
      helpText: 'Select your date of birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.copyWith(
                bodyLarge: GoogleFonts.inter(fontSize: 18),
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDOB = picked);
    }
  }

  Future<void> _handleRestoreProfile() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name');
      return;
    }
    if (_selectedDOB == null) {
      setState(() => _errorMessage = 'Please select your date of birth');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final dob = DateFormat('yyyy-MM-dd').format(_selectedDOB!);

      final elderlyId = await AuthService.instance.findElderlyByNameAndDOB(
        name: name,
        dateOfBirth: dob,
      );

      if (elderlyId == null) {
        throw Exception(
            'No profile found with that name and date of birth.\nPlease check your details or create a new profile.');
      }

      await UserSessionService.instance.setElderlyProfileId(elderlyId);
      await UserSessionService.instance.saveRole(AppConstants.roleElderly);
      await UserSessionService.instance
          .setBool(AppConstants.prefOnboardingDone, true);

      if (!mounted) return;
      context.go(AppConstants.routeElderlyHome);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dobLabel = _selectedDOB != null
        ? DateFormat('MMMM d, yyyy').format(_selectedDOB!)
        : 'Select your date of birth';
    final hasDob = _selectedDOB != null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppConstants.routeRoleSelect),
        ),
        title: Text(
          'Welcome Back!',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Restore Your Profile',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter your name and date of birth\nto access your profile.',
              style: GoogleFonts.inter(
                fontSize: AppTheme.elderlyBodyFontSize,
                color: AppTheme.textMid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.08),
                  border: Border.all(color: AppTheme.accentRed),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_rounded,
                        color: AppTheme.accentRed, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppTheme.accentRed,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],

            // Name field
            Text(
              'Your Full Name',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMid,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              style: GoogleFonts.inter(
                fontSize: AppTheme.elderlyBodyFontSize,
                color: AppTheme.textDark,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Margaret Johnson',
                hintStyle: GoogleFonts.inter(
                  fontSize: AppTheme.elderlyBodyFontSize,
                  color: AppTheme.textLight,
                ),
                prefixIcon: const Icon(Icons.person_rounded,
                    color: AppTheme.primaryBlue, size: 24),
                filled: true,
                fillColor: AppTheme.surfaceWhite,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppTheme.divider, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppTheme.divider, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // Date of birth picker
            Text(
              'Date of Birth',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMid,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _isLoading ? null : _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasDob ? AppTheme.primaryBlue : AppTheme.divider,
                    width: hasDob ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cake_rounded,
                      color: hasDob
                          ? AppTheme.primaryBlue
                          : AppTheme.textLight,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        dobLabel,
                        style: GoogleFonts.inter(
                          fontSize: AppTheme.elderlyBodyFontSize,
                          color: hasDob
                              ? AppTheme.textDark
                              : AppTheme.textLight,
                          fontWeight: hasDob
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: hasDob
                          ? AppTheme.primaryBlue
                          : AppTheme.textLight,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Restore button
            SizedBox(
              width: double.infinity,
              height: AppTheme.elderlyButtonHeight,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRestoreProfile,
                child: _isLoading
                    ? const SizedBox(
                        height: 26,
                        width: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Find My Profile',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Create new profile
            SizedBox(
              width: double.infinity,
              height: AppTheme.elderlyButtonHeight,
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => context.go(AppConstants.routeElderlySetup),
                child: Text(
                  'Create New Profile Instead',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
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
