import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_checkin_model.dart';

/// Service to manage daily health check-ins with Firestore and Gemini integration
class CheckinService {
  CheckinService._();
  static final CheckinService instance = CheckinService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if elderly has already checked in today (calendar day)
  Future<bool> hasCheckInToday(String userId) async {
    try {
      final today = DateTime.now();
      final dateString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final snapshot = await _firestore
          .collection('elderly')
          .doc(userId)
          .collection('daily_checkins')
          .doc(dateString)
          .get();

      return snapshot.exists;
    } catch (e) {
      debugPrint('Error checking if checked in today: $e');
      return false;
    }
  }

  /// Get today's check-in if it exists
  Future<DailyCheckin?> getCheckInToday(String userId) async {
    try {
      final today = DateTime.now();
      final dateString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final snapshot = await _firestore
          .collection('elderly')
          .doc(userId)
          .collection('daily_checkins')
          .doc(dateString)
          .get();

      if (snapshot.exists) {
        return DailyCheckin.fromFirestore(snapshot);
      }
    } catch (e) {
      debugPrint('Error fetching check-in for today: $e');
    }
    return null;
  }

  /// Submit a new daily check-in
  Future<DailyCheckin> submitCheckin({
    required String userId,
    required int moodScore,
    required String moodText,
    required int painScore,
    required String painLocation,
    required String painDescription,
    required String dailyPlan,
    String? additionalNotes,
  }) async {
    try {
      final now = DateTime.now();
      final dateString =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final checkin = DailyCheckin(
        id: dateString,
        userId: userId,
        checkInDate: dateString,
        createdAt: now,
        updatedAt: null,
        isUpdated: false,
        moodScore: moodScore,
        moodText: moodText,
        painScore: painScore,
        painLocation: painLocation,
        painDescription: painDescription,
        dailyPlan: dailyPlan,
        additionalNotes: additionalNotes,
      );

      await _firestore
          .collection('elderly')
          .doc(userId)
          .collection('daily_checkins')
          .doc(dateString)
          .set(checkin.toFirestore());

      // Trigger Gemini Cloud Function here (optional client-side call)
      // In production, use Cloud Functions to call Gemini
      debugPrint('Check-in submitted for $userId on $dateString');

      return checkin;
    } catch (e) {
      debugPrint('Error submitting check-in: $e');
      rethrow;
    }
  }

  /// Update an existing check-in (soft update after initial submission)
  Future<DailyCheckin> updateCheckin({
    required String userId,
    required int moodScore,
    required String moodText,
    required int painScore,
    required String painLocation,
    required String painDescription,
    required String dailyPlan,
    String? additionalNotes,
  }) async {
    try {
      final now = DateTime.now();
      final dateString =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final updatedCheckin = DailyCheckin(
        id: dateString,
        userId: userId,
        checkInDate: dateString,
        createdAt: now, // Keep original
        updatedAt: now,
        isUpdated: true,
        moodScore: moodScore,
        moodText: moodText,
        painScore: painScore,
        painLocation: painLocation,
        painDescription: painDescription,
        dailyPlan: dailyPlan,
        additionalNotes: additionalNotes,
      );

      await _firestore
          .collection('elderly')
          .doc(userId)
          .collection('daily_checkins')
          .doc(dateString)
          .update(updatedCheckin.toFirestore());

      debugPrint('Check-in updated for $userId on $dateString');
      return updatedCheckin;
    } catch (e) {
      debugPrint('Error updating check-in: $e');
      rethrow;
    }
  }

  /// Get Gemini summary for today's check-in
  Future<GeminiSummary?> getGeminiSummaryForToday(String userId) async {
    try {
      final today = DateTime.now();
      final dateString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final snapshot = await _firestore
          .collection('elderly')
          .doc(userId)
          .collection('daily_checkins')
          .doc(dateString)
          .collection('gemini_summary')
          .orderBy('generatedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return GeminiSummary.fromFirestore(snapshot.docs.first);
      }
    } catch (e) {
      debugPrint('Error fetching Gemini summary: $e');
    }
    return null;
  }

  /// Get check-in history for the past N days (for trends)
  Future<List<DailyCheckin>> getCheckInHistory(
    String userId, {
    int days = 7,
  }) async {
    try {
      final since = DateTime.now().subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('elderly')
          .doc(userId)
          .collection('daily_checkins')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => DailyCheckin.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching check-in history: $e');
      return [];
    }
  }

  /// Get caregiver's check-in settings for this patient
  Future<CaregiverCheckinSettings?> getCaregiverSettings(
    String caregiverId,
    String patientId,
  ) async {
    try {
      final doc = await _firestore
          .collection('caregivers')
          .doc(caregiverId)
          .collection('patients')
          .doc(patientId)
          .collection('settings')
          .doc('checkin_preferences')
          .get();

      if (doc.exists) {
        return CaregiverCheckinSettings.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error fetching caregiver settings: $e');
    }
    return null;
  }

  /// Update caregiver's check-in settings
  Future<void> updateCaregiverSettings(
    CaregiverCheckinSettings settings,
  ) async {
    try {
      await _firestore
          .collection('caregivers')
          .doc(settings.caregiverId)
          .collection('patients')
          .doc(settings.patientId)
          .collection('settings')
          .doc('checkin_preferences')
          .set(settings.toFirestore());

      debugPrint(
          'Updated caregiver settings for ${settings.patientId}');
    } catch (e) {
      debugPrint('Error updating caregiver settings: $e');
      rethrow;
    }
  }

  /// Get mood trends (last 7 days) for graphing
  Future<List<double>> getMoodTrends(String userId, {int days = 7}) async {
    try {
      final history = await getCheckInHistory(userId, days: days);
      return history.map((c) => c.moodScore.toDouble()).toList();
    } catch (e) {
      debugPrint('Error fetching mood trends: $e');
      return [];
    }
  }

  /// Get pain trends (last 7 days) for graphing
  Future<List<double>> getPainTrends(String userId, {int days = 7}) async {
    try {
      final history = await getCheckInHistory(userId, days: days);
      return history.map((c) => c.painScore.toDouble()).toList();
    } catch (e) {
      debugPrint('Error fetching pain trends: $e');
      return [];
    }
  }
}
