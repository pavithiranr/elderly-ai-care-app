import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../shared/services/user_session_service.dart';

/// Re-login screen for returning elderly users.
/// Identifies them by IC number - no passwords or codes needed.
class ElderlyExistingProfileLoginScreen extends StatefulWidget {
  const ElderlyExistingProfileLoginScreen({super.key});

  @override
  State<ElderlyExistingProfileLoginScreen> createState() =>
      _ElderlyExistingProfileLoginScreenState();
}

class _ElderlyExistingProfileLoginScreenState
    extends State<ElderlyExistingProfileLoginScreen> {
  final _icController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _icController.dispose();
    super.dispose();
  }

  Future<void> _handleRestore() async {
    final icRaw = _icController.text.trim();
    final icNumber = icRaw.replaceAll('-', '');

    if (icNumber.length != 12) {
      setState(
        () => _errorMessage = 'Please enter your full 12-digit IC number',
      );
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final elderlyId = await AuthService.instance.findElderlyByIC(icNumber);

      if (elderlyId == null) {
        throw Exception(
          'No profile found with that IC number.\nPlease check your details or create a new profile.',
        );
      }

      await UserSessionService.instance.setElderlyProfileId(elderlyId);
      await UserSessionService.instance.saveRole(AppConstants.roleElderly);
      await UserSessionService.instance.setBool(
        AppConstants.prefOnboardingDone,
        true,
      );

      if (!mounted) return;
      context.go(AppConstants.routeElderlyHome);
    } catch (e) {
      // Clear invalid session on auth error
      await UserSessionService.instance.clearSession();
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasIC = _icController.text.replaceAll('-', '').length == 12;

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
              'Enter your IC number to access your profile.',
              style: GoogleFonts.inter(
                fontSize: AppTheme.elderlyBodyFontSize,
                color: AppTheme.textMid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

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
                    const Icon(
                      Icons.error_rounded,
                      color: AppTheme.accentRed,
                      size: 22,
                    ),
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

            Text(
              'IC Number (MyKad)',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMid,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _icController,
              enabled: !_isLoading,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleRestore(),
              onChanged: (_) => setState(() {}),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d\-]')),
                LengthLimitingTextInputFormatter(14),
                _IcNumberFormatter(),
              ],
              style: GoogleFonts.inter(
                fontSize: AppTheme.elderlyBodyFontSize,
                color: AppTheme.textDark,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText: '901231-14-5678',
                hintStyle: GoogleFonts.inter(
                  fontSize: AppTheme.elderlyBodyFontSize,
                  color: AppTheme.textLight,
                ),
                prefixIcon: Icon(
                  Icons.badge_rounded,
                  color: hasIC ? AppTheme.primaryBlue : AppTheme.textLight,
                  size: 24,
                ),
                filled: true,
                fillColor: AppTheme.surfaceWhite,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppTheme.divider,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppTheme.divider,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryBlue,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              height: AppTheme.elderlyButtonHeight,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRestore,
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 26,
                          width: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
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

            SizedBox(
              width: double.infinity,
              height: AppTheme.elderlyButtonHeight,
              child: OutlinedButton(
                onPressed:
                    _isLoading
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

/// Auto-formats IC number as XXXXXX-XX-XXXX while typing.
class _IcNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
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
