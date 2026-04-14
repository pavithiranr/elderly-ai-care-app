import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:caresync_ai/core/theme/app_theme.dart';
import 'package:caresync_ai/shared/services/user_session_service.dart';
import 'package:caresync_ai/core/services/auth_service.dart';

class BindingCodeScreen extends StatefulWidget {
  const BindingCodeScreen({super.key});

  @override
  State<BindingCodeScreen> createState() => _BindingCodeScreenState();
}

class _BindingCodeScreenState extends State<BindingCodeScreen> {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLinkElderly() async {
    final code = _pinController.text;

    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final caregiverUid = UserSessionService.instance.getCurrentUserUid();
      if (caregiverUid == null) {
        throw Exception('Not logged in');
      }

      await AuthService.instance.linkElderlyToCaregiver(
        bindingCode: code,
        caregiverUid: caregiverUid,
      );

      if (!mounted) return;

      // Show success dialog
      _showSuccessDialog();
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
              'You can now monitor this elderly\'s health.',
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
                  // Close binding code screen and refresh list
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 360;
    
    // Calculate responsive sizes
    final pinHeight = (screenHeight * 0.08).clamp(48.0, 80.0);
    final pinFontSize = (pinHeight * 0.5).clamp(20.0, 40.0);
    final headerFontSize = isSmallPhone ? 20.0 : 24.0;
    final subtitleFontSize = isSmallPhone ? 12.0 : 14.0;
    final horizontalPadding = isSmallPhone ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Link Elderly Profile',
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
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Enter Binding Code',
              style: GoogleFonts.inter(
                fontSize: headerFontSize,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask the elderly to share the 6-digit code\nfrom their setup screen.',
              style: GoogleFonts.inter(
                fontSize: subtitleFontSize,
                color: AppTheme.textMid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Error message
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
                          fontSize: subtitleFontSize,
                          color: AppTheme.accentRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Pinput OTP field
            Center(
              child: Pinput(
                length: 6,
                controller: _pinController,
                focusNode: _pinFocus,
                enabled: !_isLoading,
                autofocus: true,
                useNativeKeyboard: true,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]')),
                ],
                toolbarEnabled: true,
                pinAnimationType: PinAnimationType.fade,
                animationDuration: const Duration(milliseconds: 200),
                submittedPinTheme: PinTheme(
                  width: pinHeight,
                  height: pinHeight,
                  textStyle: GoogleFonts.inter(
                    fontSize: pinFontSize,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                    letterSpacing: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    border: Border.all(
                      color: AppTheme.primaryBlue,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                focusedPinTheme: PinTheme(
                  width: pinHeight,
                  height: pinHeight,
                  textStyle: GoogleFonts.inter(
                    fontSize: pinFontSize,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                    letterSpacing: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    border: Border.all(
                      color: AppTheme.primaryBlue,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                defaultPinTheme: PinTheme(
                  width: pinHeight,
                  height: pinHeight,
                  textStyle: GoogleFonts.inter(
                    fontSize: pinFontSize,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                    letterSpacing: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    border: Border.all(
                      color: AppTheme.divider,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                disabledPinTheme: PinTheme(
                  width: pinHeight,
                  height: pinHeight,
                  textStyle: GoogleFonts.inter(
                    fontSize: pinFontSize,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMid,
                    letterSpacing: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(
                      color: AppTheme.divider,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onCompleted: (_) {
                  // Auto-submit when all 6 digits are entered
                  _handleLinkElderly();
                },
              ),
            ),
            const SizedBox(height: 32),

            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                border: Border.all(color: AppTheme.primaryBlue),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_rounded,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'The binding code expires after 24 hours.',
                      style: GoogleFonts.inter(
                        fontSize: subtitleFontSize,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Link button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLinkElderly,
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
                        'Link Profile',
                        style: GoogleFonts.inter(
                          fontSize: 16,
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
