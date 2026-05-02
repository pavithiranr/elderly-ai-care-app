import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_checkin_model.dart';
import 'gemini_service.dart';

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

      debugPrint('Check-in submitted for $userId on $dateString');
      _generateAndCacheAiSummary(userId, checkin, dateString);

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
      _generateAndCacheAiSummary(userId, updatedCheckin, dateString);
      return updatedCheckin;
    } catch (e) {
      debugPrint('Error updating check-in: $e');
      rethrow;
    }
  }

  /// Calls Gemini and saves the summary as `ai_summary` on the checkin doc.
  /// Fire-and-forget — never awaited by callers.
  Future<void> _generateAndCacheAiSummary(
    String userId,
    DailyCheckin checkin,
    String dateString,
  ) async {
    try {
      final doc = await _firestore.collection('elderly').doc(userId).get();
      final patientName = (doc.data()?['name'] as String?) ?? 'Patient';

      final events = [
        'Mood: ${checkin.moodText} (score ${checkin.moodScore}/4)',
        'Pain: ${checkin.painScore}/10 at ${checkin.painLocation}',
        if (checkin.painDescription.isNotEmpty)
          'Pain description: ${checkin.painDescription}',
        'Daily plan: ${checkin.dailyPlan}',
        if (checkin.additionalNotes?.isNotEmpty == true)
          'Notes: ${checkin.additionalNotes}',
      ];

      final summary = await GeminiService.instance.generateDailySummary(
        patientName: patientName,
        events: events,
      );

      await _firestore
          .collection('elderly')
          .doc(userId)
          .collection('daily_checkins')
          .doc(dateString)
          .update({'ai_summary': summary});

      debugPrint('AI summary cached for $userId on $dateString');
    } catch (e) {
      debugPrint('Error generating/caching AI summary: $e');
    }
  }

  /// Reads the cached caregiver AI summary for today (no Gemini call).
  Future<String?> getCachedAiSummary(String userId) async {
    try {
      final dateString = _todayString();
      final snapshot = await _firestore
          .collection('elderly')
          .doc(userId)
          .collection('daily_checkins')
          .doc(dateString)
          .get();
      return snapshot.data()?['ai_summary'] as String?;
    } catch (e) {
      debugPrint('Error fetching cached AI summary: $e');
      return null;
    }
  }

  /// Saves a caregiver AI summary to today's checkin doc (creates doc if needed).
  Future<void> saveCaregiverAiSummary(String userId, String summary) async {
    try {
      await _firestore
          .collection('elderly')
          .doc(userId)
          .collection('daily_checkins')
          .doc(_todayString())
          .set({'ai_summary': summary}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving caregiver AI summary: $e');
    }
  }

  /// Reads the cached elderly-facing health summary for today.
  Future<String?> getCachedElderlyHealthSummary(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('elderly')
          .doc(userId)
          .collection('daily_checkins')
          .doc(_todayString())
          .get();
      return snapshot.data()?['elderly_health_summary'] as String?;
    } catch (e) {
      debugPrint('Error fetching cached elderly health summary: $e');
      return null;
    }
  }

  /// Saves the elderly-facing health summary to today's checkin doc.
  Future<void> saveElderlyHealthSummary(String userId, String summary) async {
    try {
      await _firestore
          .collection('elderly')
          .doc(userId)
          .collection('daily_checkins')
          .doc(_todayString())
          .set({'elderly_health_summary': summary}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving elderly health summary: $e');
    }
  }

  String _todayString() {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
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
