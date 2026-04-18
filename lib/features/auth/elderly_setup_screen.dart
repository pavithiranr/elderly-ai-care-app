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
  final _emergencyContactController = TextEditingController();
  final _icController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  /// Malaysian IC: 12 digits formatted as XXXXXX-XX-XXXX
  /// Returns raw 12-digit string or null if invalid.
  String? _validateIC(String input) {
    final digits = input.replaceAll('-', '');
    if (!RegExp(r'^\d{12}$').hasMatch(digits)) return null;
    return digits;
  }

  /// Malaysian format: +60 followed by 8–10 digits.
  String? _validateMalaysianPhone(String digits) {
    final cleaned = digits.replaceAll(RegExp(r'\s'), '');
    if (cleaned.isEmpty) return null;
    if (!RegExp(r'^\d{8,10}$').hasMatch(cleaned)) return null;
    return '+60$cleaned';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _emergencyContactController.dispose();
    _icController.dispose();
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
      final icRaw = _icController.text.trim();

      if (name.isEmpty || dob.isEmpty || icRaw.isEmpty) {
        throw Exception('Please fill in your name, date of birth, and IC number');
      }

      // Emergency contact is optional — validate only if provided
      String? fullPhone;
      if (contact.isNotEmpty) {
        fullPhone = _validateMalaysianPhone(contact);
        if (fullPhone == null) {
          throw Exception(
              'Enter a valid Malaysian number after +60\n(e.g. 123456789 for +60123456789)');
        }
      }

      final icNumber = _validateIC(icRaw);
      if (icNumber == null) {
        throw Exception('IC number must be exactly 12 digits\n(e.g. 901231-14-5678)');
      }

      await UserSessionService.instance.elderlySetup(
        name: name,
        dateOfBirth: dob,
        emergencyContact: fullPhone ?? '',
        icNumber: icNumber,
      );

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
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
              'Profile Created!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Share your IC number with your caregiver so they can link to your profile.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                border: Border.all(color: AppTheme.primaryBlue),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.badge_rounded,
                      color: AppTheme.primaryBlue, size: 22),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Your IC number is your link key',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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
              IconButton(
                onPressed: () => context.go(AppConstants.routeRoleSelect),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.surfaceWhite,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 24),
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

              if (_errorMessage != null) ...[
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
                              fontSize: 14, color: AppTheme.accentRed),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              _buildLabel('Full Name'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameController,
                hint: 'Margaret Smith',
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),

              _buildLabel('Date of Birth'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _isLoading ? null : _pickDate,
                child: TextField(
                  controller: _dobController,
                  enabled: false,
                  style: GoogleFonts.inter(fontSize: 18, color: AppTheme.textDark),
                  decoration: InputDecoration(
                    hintText: 'YYYY-MM-DD',
                    hintStyle: GoogleFonts.inter(fontSize: 18, color: AppTheme.textLight),
                    filled: true,
                    fillColor: AppTheme.surfaceWhite,
                    suffixIcon: const Icon(Icons.calendar_month_rounded,
                        size: 24, color: AppTheme.primaryBlue),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.divider)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.divider)),
                    disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.divider)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildLabel('IC Number'),
              const SizedBox(height: 4),
              Text(
                'MyKad number (12 digits)',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textLight),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _icController,
                hint: '901231-14-5678',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d\-]')),
                  LengthLimitingTextInputFormatter(14), // 12 digits + 2 dashes
                  _IcNumberFormatter(),
                ],
              ),
              const SizedBox(height: 24),

              _buildLabel('Emergency Contact Phone (Optional)'),
              const SizedBox(height: 4),
              Text(
                'Malaysian number only (+60)',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textLight),
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
                style: GoogleFonts.inter(fontSize: 18, color: AppTheme.textDark),
                decoration: InputDecoration(
                  prefixText: '+60 ',
                  prefixStyle: GoogleFonts.inter(
                      fontSize: 18, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                  hintText: '12-3456789',
                  hintStyle: GoogleFonts.inter(fontSize: 18, color: AppTheme.textLight),
                  filled: true,
                  fillColor: AppTheme.surfaceWhite,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.divider)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.divider)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2)),
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: AppTheme.elderlyButtonHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSetup,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
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
                              fontSize: 20, fontWeight: FontWeight.w700),
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

  Widget _buildLabel(String text) => Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textDark),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) =>
      TextField(
        controller: controller,
        enabled: !_isLoading,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: GoogleFonts.inter(fontSize: 18, color: AppTheme.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 18, color: AppTheme.textLight),
          filled: true,
          fillColor: AppTheme.surfaceWhite,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.divider)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.divider)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2)),
        ),
      );
}

/// Auto-formats IC number as XXXXXX-XX-XXXX while typing.
class _IcNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('-', '');
    if (digits.length > 12) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 6 || i == 8) buffer.write('-');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
