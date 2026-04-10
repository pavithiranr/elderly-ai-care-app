import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/user_session_service.dart';
import '../../core/services/auth_service.dart';

/// Screen for returning elderly users to enter their binding code
/// and restore their existing profile
class ElderlyExistingProfileLoginScreen extends StatefulWidget {
  const ElderlyExistingProfileLoginScreen({super.key});

  @override
  State<ElderlyExistingProfileLoginScreen> createState() =>
      _ElderlyExistingProfileLoginScreenState();
}

class _ElderlyExistingProfileLoginScreenState
    extends State<ElderlyExistingProfileLoginScreen> {
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getFullCode() {
    return _codeControllers.map((c) => c.text).join();
  }

  Future<void> _handleRestoreProfile() async {
    final code = _getFullCode();

    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      // Verify the code matches a stored elderly profile
      final elderlyId = await AuthService.instance.verifyElderlySetupCode(code);
      
      if (elderlyId == null) {
        throw Exception('Invalid code. Please check and try again.');
      }

      // Save elderly profile ID locally
      await UserSessionService.instance.setElderlyProfileId(elderlyId);
      await UserSessionService.instance.saveRole(AppConstants.roleElderly);
      await UserSessionService.instance.setBool(AppConstants.prefOnboardingDone, true);

      if (!mounted) return;

      // Navigate to elderly home
      context.go(AppConstants.routeElderlyHome);
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

  void _focusNextField(int index) {
    if (index < 5 && _codeControllers[index].text.isNotEmpty) {
      FocusScope.of(context).nextFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // Go back to role selection instead of popping
            // because this screen uses context.go() (replacement, not push)
            context.go(AppConstants.routeRoleSelect);
          },
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
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter the 6-digit code from your caregiver\nto restore your existing profile.',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppTheme.textMid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

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
            if (_errorMessage != null) const SizedBox(height: 24),

            // Code input fields
            Text(
              'Enter Setup Code',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMid,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(
                6,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: index == 0 || index == 5 ? 0 : 4,
                    ),
                    child: TextField(
                      controller: _codeControllers[index],
                      enabled: !_isLoading,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9A-Za-z]')),
                        _UpperCaseTextFormatter(),
                      ],
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                        letterSpacing: 2,
                      ),
                      decoration: InputDecoration(
                        counter: const SizedBox.shrink(),
                        filled: true,
                        fillColor: AppTheme.surfaceWhite,
                        contentPadding: const EdgeInsets.all(20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppTheme.divider, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppTheme.divider, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryBlue,
                            width: 3,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppTheme.divider, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty && index > 0) {
                          FocusScope.of(context).previousFocus();
                        } else if (value.isNotEmpty && index < 5) {
                          _focusNextField(index);
                        }
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.1),
                border: Border.all(
                    color: AppTheme.accentGreen.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_rounded,
                    color: AppTheme.accentGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ask your caregiver for the code\nfrom your initial setup.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.accentGreen,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Restore button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRestoreProfile,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Restore Profile',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Create new profile button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => context.go(AppConstants.routeRoleSelect),
                child: Text(
                  'Create New Profile Instead',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

/// Custom formatter to convert text to uppercase
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
