import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/logging_service.dart';

/// Session service — integrates Firebase Auth with local SharedPreferences storage.
/// Handles caregiver auth (email/password) and elderly setup (no password).
class UserSessionService {
  UserSessionService._();
  static final UserSessionService instance = UserSessionService._();

  final AuthService _authService = AuthService.instance;

  // ─── Caregiver Authentication ───────────────────────────────────────

  /// Sign up a new caregiver
  Future<String> caregiverSignUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final uid = await _authService.caregiverSignUp(
        email: email,
        password: password,
        name: name,
      );

      // Save session locally
      await saveRole(AppConstants.roleCaregiver);
      await saveUserId(uid);
      await setBool(AppConstants.prefOnboardingDone, true);

      return uid;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in an existing caregiver
  Future<String> caregiverSignIn({
    required String email,
    required String password,
  }) async {
    try {
      final uid = await _authService.caregiverSignIn(
        email: email,
        password: password,
      );

      // Save session locally
      await saveRole(AppConstants.roleCaregiver);
      await saveUserId(uid);
      await setBool(AppConstants.prefOnboardingDone, true);

      return uid;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Elderly Setup (No Password) ────────────────────────────────────

  /// Set up a new elderly profile.
  /// Saves the elderly UID locally so the session persists.
  /// Returns the binding code to display to the user.
  Future<String> elderlySetup({
    required String name,
    required String dateOfBirth,
    required String emergencyContact,
  }) async {
    try {
      final result = await _authService.elderlySetup(
        name: name,
        dateOfBirth: dateOfBirth,
        emergencyContact: emergencyContact,
      );

      // Save the elderly UID locally — this is what getElderlyProfileId() reads
      await setElderlyProfileId(result.elderlyUid);
      await saveRole(AppConstants.roleElderly);
      await setBool(AppConstants.prefOnboardingDone, true);

      return result.bindingCode;
    } catch (e) {
      rethrow;
    }
  }

  /// Link elderly to caregiver using binding code
  /// Called by caregiver after scanning/entering code
  Future<void> linkElderlyToCaregiver({
    required String bindingCode,
  }) async {
    try {
      final caregiverUid = _authService.getCurrentUserUid();
      if (caregiverUid == null) {
        throw Exception('No caregiver logged in');
      }

      await _authService.linkElderlyToCaregiver(
        bindingCode: bindingCode,
        caregiverUid: caregiverUid,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ─── Session Management ────────────────────────────────────────────

  Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefUserRole, role);
  }

  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefUserRole);
  }

  Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
  }

  /// Clear all session data and logout from Firebase
  Future<void> clearSession() async {
    try {
      // Logout from Firebase Auth
      await _authService.logout();

      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      // Log error but don't throw — clearing should succeed even if auth fails
      logger.error('Error clearing session', e);
    }
  }

  Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefUserId, userId);
  }

  Future<String?> getSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefUserId);
  }

  /// Check if user is currently authenticated in Firebase
  bool isAuthenticated() {
    return _authService.isAuthenticated();
  }

  /// Get current user's UID
  String? getCurrentUserUid() {
    return _authService.getCurrentUserUid();
  }

  /// Save elderly profile ID locally (for elderly users)
  Future<void> setElderlyProfileId(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('elderly_profile_id', profileId);
    await prefs.setString(AppConstants.prefUserId, profileId);
  }

  /// Get saved elderly profile ID
  Future<String?> getElderlyProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('elderly_profile_id');
  }

  /// Helper to save boolean preference
  Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// Helper to get boolean preference
  Future<bool> getBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }
}
