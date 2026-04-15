import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/services/logging_service.dart';
import '../../../shared/services/checkin_service.dart';
import '../../../shared/services/user_session_service.dart';
import '../../../shared/models/daily_checkin_model.dart';

/// Daily health check-in for elderly users.
/// Captures mood, pain level, daily plan, and pain details — ready for Gemini AI analysis.
/// Design rules: ≥22px font, ≥64px buttons, high contrast, MD3.
/// 
/// The "Golden 3 Questions":
/// 1. How are you feeling mentally today? (Emoji mood)
/// 2. Do you have any physical pain or discomfort? (1-10 scale + location)
/// 3. What is one thing you're planning to do today? (Conversation starter for caregivers)
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  int _selectedMood = -1; // 1-4 (emoji indexes)
  double _painLevel = 0; // 1-10
  final _painLocationController = TextEditingController();
  final _painDescriptionController = TextEditingController();
  final _dailyPlanController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _submitted = false;
  bool _isLoading = false;
  DailyCheckin? _existingCheckin;
  GeminiSummary? _geminiSummary;

  static const List<_MoodOption> _moods = [
    _MoodOption(emoji: '😊', label: 'Great',     sublabel: 'Feeling wonderful'),
    _MoodOption(emoji: '🙂', label: 'Good',      sublabel: 'Doing well'),
    _MoodOption(emoji: '😐', label: 'Okay',      sublabel: 'So-so'),
    _MoodOption(emoji: '😟', label: 'Not Great', sublabel: 'A bit off'),
  ];

  @override
  void dispose() {
    _painLocationController.dispose();
    _painDescriptionController.dispose();
    _dailyPlanController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkExistingCheckin();
  }

  /// Check if user has already checked in today
  Future<void> _checkExistingCheckin() async {
    try {
      final userId = await UserSessionService.instance.getSavedUserId();
      if (userId == null) return;

      final existingCheckin = await CheckinService.instance.getCheckInToday(userId);
      final geminiSummary = existingCheckin != null 
          ? await CheckinService.instance.getGeminiSummaryForToday(userId)
          : null;

      if (mounted) {
        setState(() {
          _existingCheckin = existingCheckin;
          _geminiSummary = geminiSummary;
          
          // Pre-fill form if updating
          if (existingCheckin != null) {
            _selectedMood = existingCheckin.moodScore - 1;
            _painLevel = existingCheckin.painScore.toDouble();
            _painLocationController.text = existingCheckin.painLocation;
            _painDescriptionController.text = existingCheckin.painDescription;
            _dailyPlanController.text = existingCheckin.dailyPlan;
          }
        });
      }
    } catch (e) {
      logger.error('Error checking existing check-in', e);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMood < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mood to continue')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = await UserSessionService.instance.getSavedUserId();
      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Determine mood text from selection
      final moodText = _moods[_selectedMood].label;

      if (_existingCheckin != null) {
        // Update existing check-in
        await CheckinService.instance.updateCheckin(
          userId: userId,
          moodScore: _selectedMood + 1,
          moodText: moodText,
          painScore: _painLevel.toInt(),
          painLocation: _painLocationController.text.trim(),
          painDescription: _painDescriptionController.text.trim(),
          dailyPlan: _dailyPlanController.text.trim(),
        );
      } else {
        // Submit new check-in
        await CheckinService.instance.submitCheckin(
          userId: userId,
          moodScore: _selectedMood + 1,
          moodText: moodText,
          painScore: _painLevel.toInt(),
          painLocation: _painLocationController.text.trim(),
          painDescription: _painDescriptionController.text.trim(),
          dailyPlan: _dailyPlanController.text.trim(),
        );
      }

      if (mounted) {
        setState(() => _submitted = true);
      }
    } catch (e) {
      logger.error('Error submitting check-in', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving check-in: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 28),
            onPressed: () => context.pop(),
          ),
          title: Text(
            "Today's Check-in",
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          toolbarHeight: 64,
        ),
        body: _SuccessView(
          geminiSummary: _geminiSummary,
          isUpdate: _existingCheckin != null,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _existingCheckin != null ? "Update Check-in" : "Today's Check-in",
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        toolbarHeight: 64,
      ),
      body: Form(
        key: _formKey,
        child: _FormView(
          moods: _moods,
          selectedMood: _selectedMood,
          painLevel: _painLevel,
          painLocationController: _painLocationController,
          painDescriptionController: _painDescriptionController,
          dailyPlanController: _dailyPlanController,
          geminiSummary: _geminiSummary,
          onMoodSelected: (i) => setState(() => _selectedMood = i),
          onPainChanged: (v) => setState(() => _painLevel = v),
          onSubmit: _isLoading ? null : _submit,
          isLoading: _isLoading,
          isUpdate: _existingCheckin != null,
        ),
      ),
    );
  }
}

// ── Form View ─────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final List<_MoodOption> moods;
  final int selectedMood;
  final double painLevel;
  final TextEditingController painLocationController;
  final TextEditingController painDescriptionController;
  final TextEditingController dailyPlanController;
  final GeminiSummary? geminiSummary;
  final ValueChanged<int> onMoodSelected;
  final ValueChanged<double> onPainChanged;
  final VoidCallback? onSubmit;
  final bool isLoading;
  final bool isUpdate;

  const _FormView({
    required this.moods,
    required this.selectedMood,
    required this.painLevel,
    required this.painLocationController,
    required this.painDescriptionController,
    required this.dailyPlanController,
    required this.geminiSummary,
    required this.onMoodSelected,
    required this.onPainChanged,
    required this.onSubmit,
    required this.isLoading,
    required this.isUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Show Gemini summary if available and updating
          if (geminiSummary != null) ...[
            _GeminiSummaryCard(summary: geminiSummary!),
            const SizedBox(height: 32),
          ],

          // ── Question 1: Mood ─────────────────────────────────────────
          _SectionLabel('How are you feeling?'),
          Text(
            'On a scale of feeling great to struggling',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          _MoodSelector(
            moods: moods,
            selectedIndex: selectedMood,
            onSelected: onMoodSelected,
          ),
          const SizedBox(height: 32),

          // ── Question 2: Pain ────────────────────────────────────────
          _SectionLabel('Any pain or discomfort?'),
          Text(
            'Tell us the level and location',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          _PainSelector(
            value: painLevel,
            onChanged: onPainChanged,
          ),
          const SizedBox(height: 16),
          
          // Pain location field
          TextFormField(
            controller: painLocationController,
            style: GoogleFonts.inter(fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Where does it hurt?',
              hintText: 'e.g. left knee, lower back',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) {
              if (painLevel > 0 && (v == null || v.trim().isEmpty)) {
                return 'Please specify the location';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Pain description (voice-first)
          TextFormField(
            controller: painDescriptionController,
            style: GoogleFonts.inter(fontSize: 18),
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Describe the pain',
              hintText: 'e.g. Sharp, dull, constant, comes and goes',
              suffixIcon: IconButton(
                icon: const Icon(Icons.mic_rounded),
                tooltip: 'Voice input (coming soon)',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voice input coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) {
              if (painLevel > 0 && (v == null || v.trim().isEmpty)) {
                return 'Please describe the pain';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // ── Question 3: Daily Plan ──────────────────────────────────
          _SectionLabel('What\'s planned for today?'),
          Text(
            'Your caregiver loves to know!',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: dailyPlanController,
            style: GoogleFonts.inter(fontSize: 18),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. Going to the garden, visiting grandchildren, etc.',
              suffixIcon: IconButton(
                icon: const Icon(Icons.mic_rounded),
                tooltip: 'Voice input (coming soon)',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voice input coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Please share your plans' : null,
          ),
          const SizedBox(height: 40),

          // ── Submit ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: AppTheme.elderlyButtonHeight,
            child: ElevatedButton(
              onPressed: selectedMood >= 0 && !isLoading ? onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                disabledBackgroundColor: Theme.of(context).disabledColor,
                disabledForegroundColor: AppTheme.textLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(isUpdate ? 'Update Check-in' : 'Submit Check-in'),
            ),
          ),

          if (selectedMood < 0) ...[
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Please select a mood above to continue.',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: AppTheme.textMid,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Mood Selector — vertical full-width list ──────────────────────────────────

class _MoodSelector extends StatelessWidget {
  final List<_MoodOption> moods;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _MoodSelector({
    required this.moods,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: moods.asMap().entries.map((entry) {
        final i = entry.key;
        final mood = entry.value;
        final isSelected = i == selectedIndex;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MoodTile(
            mood: mood,
            isSelected: isSelected,
            onTap: () => onSelected(i),
          ),
        );
      }).toList(),
    );
  }
}

class _MoodTile extends StatelessWidget {
  final _MoodOption mood;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodTile({
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final primaryColor = Theme.of(context).primaryColor;
    final dividerColor = Theme.of(context).dividerColor;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected ? primaryColor : surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? primaryColor : dividerColor,
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Emoji
                Text(
                  mood.emoji,
                  style: const TextStyle(fontSize: 36),
                ),
                const SizedBox(width: 16),
                // Labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mood.label,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Theme.of(context).colorScheme.onPrimary : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        mood.sublabel,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85)
                              : AppTheme.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                // Selection indicator
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 30,
                          key: const ValueKey('checked'),
                        )
                      : Container(
                          key: const ValueKey('unchecked'),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.textLight,
                              width: 2,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pain Selector ─────────────────────────────────────────────────────────────

class _PainSelector extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _PainSelector({required this.value, required this.onChanged});

  Color get _painColor {
    if (value <= 3) return AppTheme.accentGreen;
    if (value <= 6) return AppTheme.accentOrange;
    return AppTheme.accentRed;
  }

  String get _painLabel {
    if (value == 0) return 'No pain';
    if (value <= 3) return 'Mild pain';
    if (value <= 6) return 'Moderate pain';
    if (value <= 8) return 'Severe pain';
    return 'Very severe pain';
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final isHighContrast = ThemeProvider.instance.isHighContrast;
    final borderColor = isHighContrast 
        ? (Theme.of(context).brightness == Brightness.dark 
            ? Colors.white 
            : Colors.black)
        : Theme.of(context).dividerColor;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: isHighContrast ? 2 : 1.5,
        ),
      ),
      child: Column(
        children: [
          // Current pain display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _painLabel,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _painColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _painColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${value.toInt()} / 10',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: _painColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              activeTrackColor: _painColor,
              thumbColor: _painColor,
              overlayColor: _painColor.withValues(alpha: 0.15),
              inactiveTrackColor: Theme.of(context).dividerColor,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 10,
              divisions: 10,
              onChanged: onChanged,
            ),
          ),
          // Scale labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'None',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    color: AppTheme.textMid,
                  ),
                ),
                Text(
                  'Severe',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    color: AppTheme.textMid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success View ──────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final GeminiSummary? geminiSummary;
  final bool isUpdate;

  const _SuccessView({
    required this.geminiSummary,
    required this.isUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppTheme.accentGreen,
                size: 60,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              isUpdate ? 'Check-in Updated!' : 'Check-in Complete!',
              style: GoogleFonts.inter(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              'Your health data has been recorded.\nYour caregiver will be notified.',
              style: GoogleFonts.inter(
                fontSize: 22,
                color: AppTheme.textMid,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Show Gemini summary if available
            if (geminiSummary != null) ...[
              _GeminiSummaryCard(summary: geminiSummary!),
              const SizedBox(height: 32),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: AppTheme.elderlyButtonHeight,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gemini Summary Card ───────────────────────────────────────────────────────

class _GeminiSummaryCard extends StatelessWidget {
  final GeminiSummary summary;

  const _GeminiSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final statusColor = GeminiSummary.colorMap[summary.statusColor] ?? 0xFF66BB6A;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(statusColor).withValues(alpha: 0.08),
        border: Border.all(
          color: Color(statusColor).withValues(alpha: 0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(statusColor),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AI Summary',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary.oneSentenceSummary,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          if (summary.keyInsights.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Key Insights:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            ...summary.keyInsights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      insight,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (summary.caregiverAction.isNotEmpty &&
              summary.caregiverAction != 'No action needed') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(statusColor).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Caregiver Action: ${summary.caregiverAction}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(statusColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _MoodOption {
  final String emoji;
  final String label;
  final String sublabel;
  const _MoodOption({
    required this.emoji,
    required this.label,
    required this.sublabel,
  });
}
