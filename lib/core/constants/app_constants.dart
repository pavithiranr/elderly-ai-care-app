class AppConstants {
  // Route names — used by go_router
  static const String routeOnboarding = '/';
  static const String routeRoleSelect = '/role-select';
  static const String routeElderlyHome = '/elderly/home';
  static const String routeElderlyCheckin = '/elderly/checkin';
  static const String routeMedication = '/elderly/medication';
  static const String routeSos = '/elderly/sos';
  static const String routeElderlyChat = '/elderly/chat';
  static const String routeCaregiverDashboard = '/caregiver/dashboard';
  static const String routeCaregiverAlerts = '/caregiver/alerts';
  static const String routeCaregiverReports = '/caregiver/reports';

  // SharedPreferences keys
  static const String prefUserRole = 'user_role';
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefUserId = 'user_id';

  // User roles
  static const String roleElderly = 'elderly';
  static const String roleCaregiver = 'caregiver';

  // App meta
  static const String appName = 'CareSync AI';
  static const String appTagline = 'Care. Connect. Protect.';
}
