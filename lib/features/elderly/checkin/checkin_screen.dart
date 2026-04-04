import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// Daily health check-in for elderly users.
/// Captures mood, pain level, and an optional note — ready for Gemini AI analysis.
/// Design rules: ≥22px font, ≥64px buttons, high contrast, MD3.
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  int _selectedMood = -1;
  double _painLevel = 0;
  final _noteController = TextEditingController();
  bool _submitted = false;

  static const List<_MoodOption> _moods = [
    _MoodOption(emoji: '😊', label: 'Great',     sublabel: 'Feeling wonderful'),
    _MoodOption(emoji: '🙂', label: 'Good',      sublabel: 'Doing well'),
    _MoodOption(emoji: '😐', label: 'Okay',      sublabel: 'So-so'),
    _MoodOption(emoji: '😟', label: 'Not Great', sublabel: 'A bit off'),
    _MoodOption(emoji: '😢', label: 'Bad',       sublabel: 'Struggling today'),
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    // TODO: send to Firestore / Gemini AI via backend service
    setState(() => _submitted = true);
  }

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
          "Today's Check-in",
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        backgroundColor: AppTheme.surfaceWhite,
        toolbarHeight: 64,
      ),
      body: _submitted
          ? _SuccessView()
          : _FormView(
              moods: _moods,
              selectedMood: _selectedMood,
              painLevel: _painLevel,
              noteController: _noteController,
              onMoodSelected: (i) => setState(() => _selectedMood = i),
              onPainChanged: (v) => setState(() => _painLevel = v),
              onSubmit: _submit,
            ),
    );
  }
}

// ── Form View ─────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final List<_MoodOption> moods;
  final int selectedMood;
  final double painLevel;
  final TextEditingController noteController;
  final ValueChanged<int> onMoodSelected;
  final ValueChanged<double> onPainChanged;
  final VoidCallback onSubmit;

  const _FormView({
    required this.moods,
    required this.selectedMood,
    required this.painLevel,
    required this.noteController,
    required this.onMoodSelected,
    required this.onPainChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section 1: Mood ─────────────────────────────────────────
          _SectionLabel('How are you feeling?'),
          const SizedBox(height: 12),
          _MoodSelector(
            moods: moods,
            selectedIndex: selectedMood,
            onSelected: onMoodSelected,
          ),
          const SizedBox(height: 32),

          // ── Section 2: Pain level ────────────────────────────────────
          _SectionLabel('Any pain today?'),
          const SizedBox(height: 16),
          _PainSelector(
            value: painLevel,
            onChanged: onPainChanged,
          ),
          const SizedBox(height: 32),

          // ── Section 3: Notes ─────────────────────────────────────────
          _SectionLabel('Anything else to share?'),
          Text(
            'Optional — your own words',
            style: GoogleFonts.inter(
              fontSize: 22,
              color: AppTheme.textMid,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            maxLines: 4,
            style: GoogleFonts.inter(
              fontSize: 22,
              color: AppTheme.textDark,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. "I slept poorly last night…"',
              hintStyle: GoogleFonts.inter(
                fontSize: 22,
                color: AppTheme.textLight,
              ),
              filled: true,
              fillColor: AppTheme.surfaceWhite,
              contentPadding: const EdgeInsets.all(18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.divider, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2.5),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // ── Submit ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: AppTheme.elderlyButtonHeight,
            child: ElevatedButton(
              onPressed: selectedMood >= 0 ? onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                disabledBackgroundColor: AppTheme.divider,
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
              child: const Text('Submit Check-in'),
            ),
          ),

          if (selectedMood < 0) ...[
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Please select a mood above to continue.',
                style: GoogleFonts.inter(
                  fontSize: 22,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryBlue : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.divider,
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2),
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
                          color: isSelected ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        mood.sublabel,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.85)
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
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 30,
                          key: ValueKey('checked'),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider, width: 1.5),
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
              inactiveTrackColor: AppTheme.divider,
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
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
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
              'Check-in Complete!',
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
            const SizedBox(height: 48),
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
          color: AppTheme.textDark,
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
