import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/services/user_session_service.dart';
import '../../../shared/services/caregiver_service.dart';
import '../../../shared/services/patient_service.dart';

/// Settings screen for elderly users.
/// Displays account info, caregiver contact, app information, and accessibility options.
/// Design rules: ≥22px font, ≥64px buttons, high contrast, MD3.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeProvider _themeProvider;

  @override
  void initState() {
    super.initState();
    _themeProvider = ThemeProvider.instance;
  }

  Future<void> _toggleDarkMode(bool value) async {
    debugPrint('Toggle Dark Mode: $value');
    await _themeProvider.setDarkMode(value);
  }

  Future<void> _toggleHighContrast(bool value) async {
    debugPrint('Toggle High Contrast: $value');
    await _themeProvider.setHighContrast(value);
  }

  Future<void> _toggleColorBlindMode(bool value) async {
    debugPrint('Toggle Color Blind Mode: $value');
    await _themeProvider.setColorBlindMode(value);
  }

  Future<void> _setTextScaling(double value) async {
    debugPrint('Set Text Scaling: ${(value * 100).toInt()}%');
    await _themeProvider.setTextScaling(value);
  }

  @override
  Widget build(BuildContext context) {
    // Wrap entire screen in ListenableBuilder so it rebuilds when settings change
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, _) {
        // Get current settings from ThemeProvider (updated each rebuild)
        final isDarkMode = _themeProvider.isDarkMode;
        final isHighContrast = _themeProvider.isHighContrast;
        final isColorBlindMode = _themeProvider.isColorBlindMode;
        final textScale = _themeProvider.textScaling;
        
        // Get colors from current theme
        final theme = Theme.of(context);
        final bgColor = theme.scaffoldBackgroundColor;
        final surfaceColor = theme.cardColor;
        final primaryColor = theme.primaryColor;
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
        final dividerColor = theme.dividerColor;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 28),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Settings',
              style: GoogleFonts.inter(
                fontSize: 22 * textScale,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            backgroundColor: surfaceColor,
            toolbarHeight: 64,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // ── Accessibility Section ──────────────────────────────────
              _SectionLabel(
                'Accessibility & Display', 
                textScale: textScale,
                textColor: textColor,
              ),
              const SizedBox(height: 12),
              
              // Dark Mode Toggle
              _AccessibilityTile(
                icon: Icons.dark_mode_rounded,
                title: 'Dark Mode',
                subtitle: 'Easier on the eyes at night',
                value: isDarkMode,
                onChanged: _toggleDarkMode,
                textScale: textScale,
                theme: theme,
              ),
              const SizedBox(height: 8),
              
              // High Contrast Toggle
              _AccessibilityTile(
                icon: Icons.contrast_rounded,
                title: 'High Contrast',
                subtitle: 'Bold text and colors for clarity',
                value: isHighContrast,
                onChanged: _toggleHighContrast,
                textScale: textScale,
                theme: theme,
              ),
              const SizedBox(height: 8),
              
              // Color Blind Mode Toggle
              _AccessibilityTile(
                icon: Icons.palette_rounded,
                title: 'Color Blind Mode',
                subtitle: 'Optimized for deuteranopia',
                value: isColorBlindMode,
                onChanged: _toggleColorBlindMode,
                textScale: textScale,
                theme: theme,
              ),
              const SizedBox(height: 12),
              
              // Text Scaling Slider
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border.all(color: dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.text_fields_rounded, 
                          color: primaryColor, 
                          size: 28 * textScale),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Text Size',
                                style: GoogleFonts.inter(
                                  fontSize: 18 * textScale,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                '${(textScale * 100).toInt()}%',
                                style: GoogleFonts.inter(
                                  fontSize: 14 * textScale,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 8,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 16 * textScale,
                          elevation: 4,
                        ),
                      ),
                      child: Slider(
                        value: textScale,
                        min: 1.0,
                        max: 2.0,
                        divisions: 10,
                        label: '${(textScale * 100).toInt()}%',
                        onChanged: _setTextScaling,
                        activeColor: primaryColor,
                        inactiveColor: dividerColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Drag to adjust text size (100% - 200%)',
                        style: GoogleFonts.inter(
                          fontSize: 12 * textScale,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Account Section ────────────────────────────────────────
              _SectionLabel(
                'Your Account', 
                textScale: textScale,
                textColor: textColor,
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.person_rounded,
                title: 'Profile',
                subtitle: 'View and update your profile',
                onTap: () => _showProfileInfo(context),
                textScale: textScale,
                theme: theme,
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.phone_rounded,
                title: 'Emergency Contact',
                subtitle: 'Caregiver information',
                onTap: () => _showCaregiverInfo(context),
                textScale: textScale,
                theme: theme,
              ),
              const SizedBox(height: 32),

              // ── Binding Information Section ────────────────────────────
              _SectionLabel(
                'Share Your Binding ID', 
                textScale: textScale,
                textColor: textColor,
              ),
              const SizedBox(height: 12),
              _UniqueIdTile(
                textScale: textScale,
                theme: theme,
              ),
              const SizedBox(height: 32),

              // ── App Section ────────────────────────────────────────────
              _SectionLabel(
                'App', 
                textScale: textScale,
                textColor: textColor,
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.info_rounded,
                title: 'About CareSync AI',
                subtitle: 'v1.0.0 · Care. Connect. Protect.',
                onTap: () => _showAbout(context),
                textScale: textScale,
                theme: theme,
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.help_rounded,
                title: 'Help & Support',
                subtitle: 'FAQ and troubleshooting',
                onTap: () => _showHelp(context),
                textScale: textScale,
                theme: theme,
              ),
              const SizedBox(height: 32),

              // ── Logout ──────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: AppTheme.elderlyButtonHeight * textScale,
                child: ElevatedButton.icon(
                  onPressed: () => _showLogoutConfirm(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 22 * textScale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: Icon(Icons.logout_rounded, size: 28 * textScale),
                  label: const Text('Sign Out'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
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
        content: FutureBuilder<Map<String, String>?>(
          future: _getUserProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final profile = snapshot.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile != null) ...[
                  _ProfileRow(label: 'Name', value: profile['name'] ?? 'N/A'),
                  const SizedBox(height: 16),
                  _ProfileRow(label: 'Date of Birth', value: profile['dob'] ?? 'N/A'),
                  const SizedBox(height: 16),
                  _ProfileRow(label: 'Emergency Contact', value: profile['emergencyContact'] ?? 'N/A'),
                ] else
                  Text(
                    'No profile information available.',
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

  Future<Map<String, String>?> _getUserProfile() async {
    try {
      final elderlyId = await UserSessionService.instance.getElderlyProfileId();
      if (elderlyId == null) return null;
      final profile = await PatientService.instance.getPatientById(elderlyId);
      if (profile == null) return null;
      return {
        'name': profile.name,
        'dob': profile.dateOfBirth.isNotEmpty ? profile.dateOfBirth : 'Not set',
        'emergencyContact': profile.emergencyContact.isNotEmpty ? profile.emergencyContact : 'Not set',
      };
    } catch (e) {
      debugPrint('Error loading profile: $e');
      return null;
    }
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
          future: _getLinkedCaregiver(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final caregiver = snapshot.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caregiver != null) ...[
                  _ProfileRow(label: 'Name', value: caregiver.name),
                  const SizedBox(height: 16),
                  _ProfileRow(label: 'Email', value: caregiver.email),
                  if (caregiver.phoneNumber != null && caregiver.phoneNumber!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ProfileRow(label: 'Phone', value: caregiver.phoneNumber!),
                  ],
                ] else
                  Text(
                    'No caregiver linked yet.',
                    style: GoogleFonts.inter(fontSize: 18, color: AppTheme.textMid),
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

  Future<CaregiverProfile?> _getLinkedCaregiver() async {
    try {
      final elderlyId = await UserSessionService.instance.getElderlyProfileId();
      if (elderlyId == null) return null;
      final profile = await PatientService.instance.getPatientById(elderlyId);
      if (profile?.caregiverId == null) return null;
      return CaregiverService.instance.getCaregiverById(profile!.caregiverId!);
    } catch (e) {
      debugPrint('Error loading linked caregiver: $e');
      return null;
    }
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About CareSync AI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CareSync AI v1.0.0',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Care. Connect. Protect.',
              style: GoogleFonts.inter(fontSize: 18, color: AppTheme.textMid, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Your trusted companion for health and safety.',
              style: GoogleFonts.inter(fontSize: 18, color: AppTheme.textMid, height: 1.5),
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
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frequently Asked Questions',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildFaqItem('How do I report an emergency?', 'Tap the SOS button on the home screen.'),
            _buildFaqItem('Can I change my caregiver?', 'Contact support for assistance.'),
            _buildFaqItem('How do I update my medications?', 'Go to the Medications tab and add or update entries.'),
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

  Widget _buildFaqItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textDark),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textMid, height: 1.5),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await UserSessionService.instance.clearSession();
              if (context.mounted) {
                context.go(AppConstants.routeRoleSelect);
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}

// ── Profile Row ────────────────────────────────────────────────────────────

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMid,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 20, color: AppTheme.textDark),
        ),
      ],
    );
  }
}

// ── Section Label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final double textScale;
  final Color textColor;

  const _SectionLabel(
    this.label, {
    required this.textScale,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 16 * textScale,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: 0.5,
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
  final double textScale;
  final ThemeData theme;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.textScale,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.primaryColor, size: 32 * textScale),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20 * textScale,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14 * textScale,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 20 * textScale),
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16 * textScale, vertical: 12 * textScale),
      ),
    );
  }
}

// ── Accessibility Tile (Toggle) ────────────────────────────────────────────

class _AccessibilityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double textScale;
  final ThemeData theme;

  const _AccessibilityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.textScale,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? theme.primaryColor : theme.dividerColor,
          width: value ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16 * textScale, vertical: 14 * textScale),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8 * textScale),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: theme.primaryColor, size: 24 * textScale),
            ),
            SizedBox(width: 12 * textScale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18 * textScale,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13 * textScale,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: theme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Unique ID Tile ─────────────────────────────────────────────────────────

class _UniqueIdTile extends StatefulWidget {
  final double textScale;
  final ThemeData theme;

  const _UniqueIdTile({
    required this.textScale,
    required this.theme,
  });

  @override
  State<_UniqueIdTile> createState() => _UniqueIdTileState();
}

class _UniqueIdTileState extends State<_UniqueIdTile> {
  String? _uniqueId;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadUniqueId();
  }

  Future<void> _loadUniqueId() async {
    try {
      final elderlyId = await UserSessionService.instance.getElderlyProfileId();
      if (elderlyId != null) {
        final profile = await PatientService.instance.getPatientById(elderlyId);
        if (mounted && profile != null) {
          setState(() {
            _uniqueId = profile.uniqueId;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading unique ID: $e');
    }
  }

  Future<void> _copyToClipboard() async {
    if (_uniqueId == null) return;
    
    await Clipboard.setData(ClipboardData(text: _uniqueId!));
    
    if (mounted) {
      setState(() {
        _copied = true;
      });
      
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uniqueId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.theme.dividerColor),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Binding ID',
            style: GoogleFonts.inter(
              fontSize: 14 * widget.textScale,
              fontWeight: FontWeight.w600,
              color: widget.theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.theme.dividerColor),
                  ),
                  child: Text(
                    _uniqueId!,
                    style: GoogleFonts.inter(
                      fontSize: 20 * widget.textScale,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: widget.theme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48 * widget.textScale,
                width: 48 * widget.textScale,
                child: ElevatedButton(
                  onPressed: _copyToClipboard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.theme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Icon(
                    _copied ? Icons.check : Icons.copy,
                    color: Colors.white,
                    size: 20 * widget.textScale,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Share this ID with your caregiver to link your accounts. They can enter it in the app to connect with you.',
            style: GoogleFonts.inter(
              fontSize: 13 * widget.textScale,
              color: widget.theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

