import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/user_session_service.dart';

class ElderlySetupScreen extends StatefulWidget {
  const ElderlySetupScreen({super.key});

  @override
  State<ElderlySetupScreen> createState() => _ElderlySetupScreenState();
}

class _ElderlySetupScreenState extends State<ElderlySetupScreen> {
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  // Stores only the digits after +60 — prefix is shown via InputDecoration
  final _emergencyContactController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  /// Validates and returns the full +60 number, or null if invalid.
  /// Malaysian format: +60 followed by 8–10 digits.
  /// Mobile: +601X-XXXXXXX(X)   Landline: +60X-XXXXXXX
  String? _validateMalaysianPhone(String digits) {
    final cleaned = digits.replaceAll(RegExp(r'\s'), '');
    if (cleaned.isEmpty) return null; // caught by empty check
    if (!RegExp(r'^\d{8,10}$').hasMatch(cleaned)) return null;
    return '+60$cleaned';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(1960),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      _dobController.text =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _handleSetup() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final dob = _dobController.text.trim();
      final contact = _emergencyContactController.text.trim();

      if (name.isEmpty || dob.isEmpty || contact.isEmpty) {
        throw Exception('Please fill in all fields');
      }

      final fullPhone = _validateMalaysianPhone(contact);
      if (fullPhone == null) {
        throw Exception(
            'Enter a valid Malaysian number after +60\n(e.g. 123456789 for +60123456789)');
      }

      final code = await UserSessionService.instance.elderlySetup(
        name: name,
        dateOfBirth: dob,
        emergencyContact: fullPhone,
      );

      if (!mounted) return;

      _showBindingCodeDialog(code);
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

  void _showBindingCodeDialog(String code) {
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
            const SizedBox(height: 20),
            Text(
              'Setup Successful!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Share this code with your caregiver\nso they can link to your profile.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMid,
              ),
            ),
            const SizedBox(height: 24),
            // Binding code display
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                border: Border.all(color: AppTheme.primaryBlue),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Your Binding Code',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMid,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    code,
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Copy button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Copy to clipboard
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Binding code copied to clipboard!',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: AppTheme.accentGreen,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.content_copy_rounded),
                label: const Text('Copy Code'),
              ),
            ),
            const SizedBox(height: 12),
            // Continue button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go(AppConstants.routeElderlyHome);
                },
                child: Text(
                  'Continue to Home',
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                onPressed: () => context.go(AppConstants.routeRoleSelect),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.surfaceWhite,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 24),

              // Header
              Text(
                'Welcome!',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Let's set up your profile so your\ncaregiver can monitor your health.",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.textMid,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.1),
                    border: Border.all(color: AppTheme.accentRed),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_rounded,
                          color: AppTheme.accentRed, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppTheme.accentRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 20),

              // Name field (Large text for accessibility)
              Text(
                'Full Name',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                enabled: !_isLoading,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: AppTheme.textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Margaret Smith',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 18,
                    color: AppTheme.textLight,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceWhite,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppTheme.primaryBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Date of Birth field
              Text(
                'Date of Birth',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _isLoading ? null : _pickDate,
                child: TextField(
                  controller: _dobController,
                  enabled: false,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: AppTheme.textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'YYYY-MM-DD',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 18,
                      color: AppTheme.textLight,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceWhite,
                    suffixIcon: const Icon(
                      Icons.calendar_month_rounded,
                      size: 24,
                      color: AppTheme.primaryBlue,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Emergency Contact field
              Text(
                'Emergency Contact Phone',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Malaysian number only (+60)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textLight,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emergencyContactController,
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: AppTheme.textDark,
                ),
                decoration: InputDecoration(
                  prefixText: '+60 ',
                  prefixStyle: GoogleFonts.inter(
                    fontSize: 18,
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: '12-3456789',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 18,
                    color: AppTheme.textLight,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceWhite,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppTheme.primaryBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Setup button (Elderly-sized — large)
              SizedBox(
                width: double.infinity,
                height: AppTheme.elderlyButtonHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSetup,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 28,
                          width: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Get Started',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
