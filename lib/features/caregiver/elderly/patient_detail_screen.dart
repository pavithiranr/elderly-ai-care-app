import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caresync_ai/core/theme/app_theme.dart';
import 'package:caresync_ai/shared/services/patient_service.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  const PatientDetailScreen({super.key, required this.patientId});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  late final Future<PatientProfile?> _profileFuture;
  late final Future<PatientHealthData?> _healthFuture;
  late final Future<Map<String, dynamic>> _statsFuture;
  late final Future<Map<String, List<double>>> _trendsFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = PatientService.instance.getPatientById(widget.patientId);
    _healthFuture = PatientService.instance.getTodayHealthData(widget.patientId);
    _statsFuture = PatientService.instance.getWeeklyStats(widget.patientId);
    _trendsFuture = PatientService.instance.getWeeklyMoodPainTrends(widget.patientId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Patient Profile',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<PatientProfile?>(
        future: _profileFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final patient = snap.data;
          if (patient == null) {
            return Center(
              child: Text('Unable to load patient profile',
                  style: GoogleFonts.inter(color: AppTheme.textMid)),
            );
          }
          return _buildBody(patient);
        },
      ),
    );
  }

  Widget _buildBody(PatientProfile patient) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // ── Profile Header ────────────────────────────────────────────
        _ProfileHeader(patient: patient),
        const SizedBox(height: 20),

        // ── Today's Status ────────────────────────────────────────────
        _SectionTitle('Today\'s Status'),
        const SizedBox(height: 10),
        FutureBuilder<PatientHealthData?>(
          future: _healthFuture,
          builder: (context, snap) {
            final health = snap.data;
            final loading = snap.connectionState == ConnectionState.waiting;
            return Row(
              children: [
                Expanded(
                  child: _StatusCard(
                    icon: Icons.mood_rounded,
                    label: 'Mood',
                    value: loading
                        ? '—'
                        : health == null
                            ? 'No check-in'
                            : _capitalize(health.mood),
                    valueColor: health == null
                        ? AppTheme.textLight
                        : _moodColor(health.mood),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatusCard(
                    icon: Icons.healing_rounded,
                    label: 'Pain Level',
                    value: loading
                        ? '—'
                        : health == null
                            ? 'No check-in'
                            : '${health.painLevel} / 10',
                    valueColor: health == null
                        ? AppTheme.textLight
                        : health.painLevel <= 3
                            ? AppTheme.accentGreen
                            : AppTheme.accentOrange,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // ── Information ───────────────────────────────────────────────
        _SectionTitle('Information'),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          color: AppTheme.surfaceWhite,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InfoRow(icon: Icons.cake_rounded, label: 'Age',
                    value: patient.age > 0 ? '${patient.age} years' : '—'),
                const Divider(height: 20, color: AppTheme.divider),
                _InfoRow(icon: Icons.calendar_today_rounded, label: 'Date of Birth',
                    value: patient.dateOfBirth.isNotEmpty ? patient.dateOfBirth : '—'),
                const Divider(height: 20, color: AppTheme.divider),
                _InfoRow(icon: Icons.phone_rounded, label: 'Emergency Contact',
                    value: patient.emergencyContact.isNotEmpty ? patient.emergencyContact : '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Weekly Summary ────────────────────────────────────────────
        _SectionTitle('Weekly Summary'),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>>(
          future: _statsFuture,
          builder: (context, snap) {
            final s = snap.data ?? {};
            return Row(
              children: [
                Expanded(child: _StatChip(
                  icon: Icons.check_circle_rounded,
                  color: AppTheme.accentGreen,
                  label: 'Check-ins',
                  value: s['checkins'] ?? '— / 7',
                )),
                const SizedBox(width: 8),
                Expanded(child: _StatChip(
                  icon: Icons.medication_rounded,
                  color: AppTheme.primaryBlue,
                  label: 'Adherence',
                  value: s['adherence'] ?? '—',
                )),
                const SizedBox(width: 8),
                Expanded(child: _StatChip(
                  icon: Icons.emergency_rounded,
                  color: AppTheme.accentOrange,
                  label: 'SOS',
                  value: s['sosAlerts'] ?? '0',
                )),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // ── Mood Trend ────────────────────────────────────────────────
        _SectionTitle('Mood This Week'),
        const SizedBox(height: 4),
        Text('Daily mood (1 = bad, 5 = great)',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMid)),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, List<double>>>(
          future: _trendsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 160,
                  child: Center(child: CircularProgressIndicator()));
            }
            return _TrendChart(
              data: snap.data?['mood'] ?? List.filled(7, 0),
              maxY: 5,
              barColor: AppTheme.accentGreen,
              gradientEnd: const Color(0xFF4ADE80),
              tooltipSuffix: '/5',
            );
          },
        ),
        const SizedBox(height: 20),

        // ── Pain Trend ────────────────────────────────────────────────
        _SectionTitle('Pain Levels This Week'),
        const SizedBox(height: 4),
        Text('Daily pain (0 = none, 10 = severe)',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMid)),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, List<double>>>(
          future: _trendsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 160,
                  child: Center(child: CircularProgressIndicator()));
            }
            return _TrendChart(
              data: snap.data?['pain'] ?? List.filled(7, 0),
              maxY: 10,
              barColor: AppTheme.accentOrange,
              gradientEnd: const Color(0xFFFB923C),
              tooltipSuffix: '/10',
            );
          },
        ),
      ],
    );
  }

  Color _moodColor(String mood) {
    return switch (mood) {
      'great' || 'good' => AppTheme.accentGreen,
      'okay' => AppTheme.accentOrange,
      _ => AppTheme.accentRed,
    };
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(
        title,
        style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark),
      );
}

class _ProfileHeader extends StatelessWidget {
  final PatientProfile patient;
  const _ProfileHeader({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name,
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark)),
                const SizedBox(height: 4),
                Text(
                  patient.age > 0 ? '${patient.age} years old' : 'Age unknown',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppTheme.textMid),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    patient.status.isNotEmpty ? _capitalize(patient.status) : 'Active',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentGreen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.textMid),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMid)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppTheme.textDark)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMid)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryBlue),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMid,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

// ── Trend Bar Chart ───────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final List<double> data;
  final double maxY;
  final Color barColor;
  final Color gradientEnd;
  final String tooltipSuffix;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  const _TrendChart({
    required this.data,
    required this.maxY,
    required this.barColor,
    required this.gradientEnd,
    required this.tooltipSuffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: SizedBox(
        height: 160,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppTheme.textDark,
                getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                  '${rod.toY.toStringAsFixed(0)}$tooltipSuffix',
                  GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= _days.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_days[i],
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppTheme.textMid)),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY <= 5 ? 1 : 2,
              getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppTheme.divider, strokeWidth: 1, dashArray: [4, 4]),
            ),
            borderData: FlBorderData(show: false),
            barGroups: data.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value,
                    width: 16,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(5)),
                    gradient: LinearGradient(
                      colors: [
                        barColor.withValues(alpha: 0.7),
                        gradientEnd,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: AppTheme.backgroundGray,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
