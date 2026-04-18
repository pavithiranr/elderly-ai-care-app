import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/role_selection_screen.dart';
import '../../features/auth/caregiver_login_screen.dart';
import '../../features/auth/caregiver_signup_screen.dart';
import '../../features/auth/elderly_setup_screen.dart';
import '../../features/auth/elderly_existing_profile_login.dart';
import '../../features/elderly/home/elderly_home_screen.dart';
import '../../features/elderly/checkin/checkin_screen.dart';
import '../../features/elderly/medication/medication_screen.dart';
import '../../features/elderly/sos/sos_screen.dart';
import '../../features/elderly/chat/elderly_chat_screen.dart';
import '../../features/elderly/settings/settings_screen.dart';
import '../../features/caregiver/dashboard/caregiver_dashboard_screen.dart';
import '../../features/caregiver/settings/caregiver_settings_screen.dart';
import '../../features/caregiver/elderly/link_by_ic_screen.dart';
import '../../features/caregiver/elderly/link_by_unique_id_screen.dart';
import '../../features/caregiver/elderly/linked_elderly_screen.dart';
import '../../features/caregiver/elderly/patient_detail_screen.dart';
import '../../features/caregiver/alerts/alerts_screen.dart';
import '../../features/caregiver/reports/reports_screen.dart';
import '../constants/app_constants.dart';
import '../../shared/services/user_session_service.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppConstants.routeOnboarding,
  redirect: (BuildContext context, GoRouterState state) async {
    final isDone = await UserSessionService.instance.isOnboardingDone();
    final role = await UserSessionService.instance.getSavedRole();
    final isAuthenticated = UserSessionService.instance.isAuthenticated();

    // If onboarding not done, show onboarding
    if (!isDone) {
      return null; // show onboarding
    }

    // If onboarding done but no role selected, go to role select
    if (role == null) {
      return AppConstants.routeRoleSelect;
    }

    // If role is caregiver but not authenticated, redirect to login
    if (role == AppConstants.roleCaregiver && !isAuthenticated) {
      // Allow if already on auth screens
      if (state.matchedLocation == AppConstants.routeCaregiverLogin ||
          state.matchedLocation == AppConstants.routeCaregiverSignup) {
        return null;
      }
      return AppConstants.routeCaregiverLogin;
    }

    // If role is elderly but hasn't set up profile, redirect to setup
    if (role == AppConstants.roleElderly) {
      // If just passed role selection, redirect to setup if needed
      if (state.matchedLocation == AppConstants.routeRoleSelect) {
        return AppConstants.routeElderlySetup;
      }
    }

    // If on onboarding/role select but onboarding is done, redirect to home
    if (isDone &&
        (state.matchedLocation == AppConstants.routeOnboarding ||
            state.matchedLocation == AppConstants.routeRoleSelect)) {
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

    // ── Caregiver Auth routes ─────────────────────────────────────────
    GoRoute(
      path: AppConstants.routeCaregiverLogin,
      builder: (context, state) => const CaregiverLoginScreen(),
    ),
    GoRoute(
      path: AppConstants.routeCaregiverSignup,
      builder: (context, state) => const CaregiverSignupScreen(),
    ),

    // ── Elderly Auth routes ───────────────────────────────────────────
    GoRoute(
      path: AppConstants.routeElderlySetup,
      builder: (context, state) => const ElderlySetupScreen(),
    ),
    GoRoute(
      path: AppConstants.routeElderlyExistingLogin,
      builder: (context, state) => const ElderlyExistingProfileLoginScreen(),
    ),

    // ── Elderly routes ────────────────────────────────────────────────
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

    // ── Caregiver routes ──────────────────────────────────────────────
    GoRoute(
      path: AppConstants.routeCaregiverDashboard,
      builder: (context, state) => const CaregiverDashboardScreen(),
    ),
    GoRoute(
      path: AppConstants.routeCaregiverSettings,
      builder: (context, state) => const CaregiverSettingsScreen(),
    ),
    GoRoute(
      path: '/caregiver/link-elderly',
      builder: (context, state) => const LinkByIcScreen(),
    ),
    GoRoute(
      path: AppConstants.routeLinkByUniqueId,
      builder: (context, state) => const LinkByUniqueIdScreen(),
    ),
    GoRoute(
      path: '/caregiver/linked-elderly',
      builder: (context, state) => const LinkedElderlyScreen(),
    ),
    GoRoute(
      path: '/caregiver/patient-detail/:patientId',
      builder: (context, state) {
        final patientId = state.pathParameters['patientId'];
        return PatientDetailScreen(patientId: patientId ?? '');
      },
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
