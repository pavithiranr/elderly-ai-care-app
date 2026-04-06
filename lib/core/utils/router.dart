import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/role_selection_screen.dart';
import '../../features/elderly/home/elderly_home_screen.dart';
import '../../features/elderly/checkin/checkin_screen.dart';
import '../../features/elderly/medication/medication_screen.dart';
import '../../features/elderly/sos/sos_screen.dart';
import '../../features/elderly/chat/elderly_chat_screen.dart';
import '../../features/elderly/settings/settings_screen.dart';
import '../../features/caregiver/dashboard/caregiver_dashboard_screen.dart';
import '../../features/caregiver/alerts/alerts_screen.dart';
import '../../features/caregiver/reports/reports_screen.dart';
import '../constants/app_constants.dart';
import '../../shared/services/user_session_service.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppConstants.routeOnboarding,
  redirect: (BuildContext context, GoRouterState state) async {
    final isDone = await UserSessionService.instance.isOnboardingDone();
    if (!isDone) return null; // show onboarding

    final role = await UserSessionService.instance.getSavedRole();
    final onOnboarding = state.matchedLocation == AppConstants.routeOnboarding ||
        state.matchedLocation == AppConstants.routeRoleSelect;

    if (isDone && onOnboarding) {
      return role == AppConstants.roleCaregiver
          ? AppConstants.routeCaregiverDashboard
          : AppConstants.routeElderlyHome;
    }
    return null;
  },
  routes: [
    GoRoute(
      path: AppConstants.routeOnboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppConstants.routeRoleSelect,
      builder: (context, state) => const RoleSelectionScreen(),
    ),

    // ── Elderly routes ──────────────────────────────────────────────────
    GoRoute(
      path: AppConstants.routeElderlyHome,
      builder: (context, state) => const ElderlyHomeScreen(),
    ),
    GoRoute(
      path: AppConstants.routeElderlyCheckin,
      builder: (context, state) => const CheckinScreen(),
    ),
    GoRoute(
      path: AppConstants.routeMedication,
      builder: (context, state) => const MedicationScreen(),
    ),
    GoRoute(
      path: AppConstants.routeSos,
      builder: (context, state) => const SosScreen(),
    ),
    GoRoute(
      path: AppConstants.routeElderlyChat,
      builder: (context, state) => const ElderlyCharScreen(),
    ),
    GoRoute(
      path: AppConstants.routeElderlySettings,
      builder: (context, state) => const SettingsScreen(),
    ),

    // ── Caregiver routes ─────────────────────────────────────────────────
    GoRoute(
      path: AppConstants.routeCaregiverDashboard,
      builder: (context, state) => const CaregiverDashboardScreen(),
    ),
    GoRoute(
      path: AppConstants.routeCaregiverAlerts,
      builder: (context, state) => const AlertsScreen(),
    ),
    GoRoute(
      path: AppConstants.routeCaregiverReports,
      builder: (context, state) => const ReportsScreen(),
    ),
  ],
);
