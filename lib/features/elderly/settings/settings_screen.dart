import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/services/user_session_service.dart';
import '../../../shared/services/caregiver_service.dart';

/// Settings screen for elderly users.
/// Displays account info, caregiver contact, and app information.
/// Design rules: ≥22px font, ≥64px buttons, high contrast, MD3.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        backgroundColor: AppTheme.surfaceWhite,
        toolbarHeight: 64,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ── Account Section ────────────────────────────────────────
          _SectionLabel('Your Account'),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.person_rounded,
            title: 'Profile',
            subtitle: 'View and update your profile',
            onTap: () => _showProfileInfo(context),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.phone_rounded,
            title: 'Emergency Contact',
            subtitle: 'Caregiver information',
            onTap: () => _showCaregiverInfo(context),
          ),
          const SizedBox(height: 32),

          // ── App Section ────────────────────────────────────────────
          _SectionLabel('App'),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.info_rounded,
            title: 'About CareSync AI',
            subtitle: 'v1.0.0 · Care. Connect. Protect.',
            onTap: () => _showAbout(context),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.help_rounded,
            title: 'Help & Support',
            subtitle: 'FAQ and troubleshooting',
            onTap: () => _showHelp(context),
          ),
          const SizedBox(height: 32),

          // ── Logout ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: AppTheme.elderlyButtonHeight,
            child: ElevatedButton.icon(
              onPressed: () => _showLogoutConfirm(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 28),
              label: const Text('Sign Out'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showProfileInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Your Profile',
          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account settings and profile updates coming soon.',
              style: GoogleFonts.inter(fontSize: 22, color: AppTheme.textMid),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCaregiverInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Emergency Contact',
          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        content: FutureBuilder<CaregiverProfile?>(
          future: CaregiverService.instance.getCurrentCaregiverProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final caregiver = snapshot.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caregiver != null) ...[
                  Text(
                    'Name',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMid,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caregiver.name,
                    style: GoogleFonts.inter(fontSize: 22, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Email',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMid,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caregiver.email,
                    style: GoogleFonts.inter(fontSize: 22, color: AppTheme.textDark),
                  ),
                ] else
                  Text(
                    'No caregiver information available.',
                    style: GoogleFonts.inter(fontSize: 22, color: AppTheme.textMid),
                  ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'About CareSync AI',
          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CareSync AI — Care. Connect. Protect.',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'An AI-powered care companion for elderly users and their caregivers. Track health, medication adherence, and stay connected.',
              style: GoogleFonts.inter(fontSize: 22, color: AppTheme.textMid, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Help & Support',
          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For support, contact your caregiver or email support@caresync.ai',
              style: GoogleFonts.inter(fontSize: 22, color: AppTheme.textMid, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sign Out?',
          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'You will be returned to the login screen.',
          style: GoogleFonts.inter(fontSize: 22, color: AppTheme.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await UserSessionService.instance.clearSession();
              if (context.mounted) {
                context.go(AppConstants.routeOnboarding);
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppTheme.textDark,
      ),
    );
  }
}

// ── Settings Tile ──────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryBlue, size: 32),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textMid,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
