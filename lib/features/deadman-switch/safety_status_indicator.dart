// lib/widgets/safety_status_indicator.dart
//
// The subtle "Monitoring Safety..." badge shown on the dashboard.
// Changes appearance based on monitoring state.
//
// Usage in your dashboard Scaffold:
//   SafetyStatusIndicator(
//     isActive: inactivityMonitorActive && isWithinActiveHours,
//     timeSinceLastActivity: timeSinceLastActivity,
//   )

import 'package:flutter/material.dart';

enum MonitoringState { active, sleepHours, alertFired }

class SafetyStatusIndicator extends StatefulWidget {
  final bool isActive;
  final bool isWithinActiveHours;
  final Duration timeSinceLastActivity;

  const SafetyStatusIndicator({
    super.key,
    required this.isActive,
    required this.isWithinActiveHours,
    required this.timeSinceLastActivity,
  });

  @override
  State<SafetyStatusIndicator> createState() => _SafetyStatusIndicatorState();
}

class _SafetyStatusIndicatorState extends State<SafetyStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  late Animation<double> _dotAnimation;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _dotAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _dotController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  MonitoringState get _state {
    if (!widget.isActive) return MonitoringState.sleepHours;
    if (!widget.isWithinActiveHours) return MonitoringState.sleepHours;
    return MonitoringState.active;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final config = _stateConfig(_state, isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated dot
          AnimatedBuilder(
            animation: _dotAnimation,
            builder: (_, __) => Opacity(
              opacity: _state == MonitoringState.active
                  ? _dotAnimation.value
                  : 1.0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: config.dotColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            config.label,
            style: TextStyle(
              color: config.textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  _IndicatorConfig _stateConfig(MonitoringState state, bool isDark) {
    switch (state) {
      case MonitoringState.active:
        return _IndicatorConfig(
          label: 'Monitoring Safety...',
          dotColor: const Color(0xFF22C55E),
          textColor: const Color(0xFF16A34A),
          bgColor: const Color(0xFFDCFCE7),
          borderColor: const Color(0xFF86EFAC),
        );
      case MonitoringState.sleepHours:
        return _IndicatorConfig(
          label: 'Monitoring paused (night)',
          dotColor: const Color(0xFF94A3B8),
          textColor: const Color(0xFF64748B),
          bgColor: isDark
              ? const Color(0xFF1E293B)
              : const Color(0xFFF1F5F9),
          borderColor: const Color(0xFFCBD5E1),
        );
      case MonitoringState.alertFired:
        return _IndicatorConfig(
          label: 'Wellness check sent',
          dotColor: const Color(0xFFF97316),
          textColor: const Color(0xFFEA580C),
          bgColor: const Color(0xFFFFF7ED),
          borderColor: const Color(0xFFFDBA74),
        );
    }
  }
}

class _IndicatorConfig {
  final String label;
  final Color dotColor;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;

  const _IndicatorConfig({
    required this.label,
    required this.dotColor,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
  });
}
