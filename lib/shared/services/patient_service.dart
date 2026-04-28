import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Model for elderly patient data
class PatientProfile {
  final String id;
  final String name;
  final String dateOfBirth; // "YYYY-MM-DD"
  final String emergencyContact;
  final String? photoUrl;
  final DateTime lastSeen;
  final String status;
  final String? caregiverId;
  final String uniqueId;
  final String icNumber;

  PatientProfile({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    required this.emergencyContact,
    this.photoUrl,
    required this.lastSeen,
    required this.status,
    this.caregiverId,
    required this.uniqueId,
    this.icNumber = '',
  });

  /// Age computed from dateOfBirth - no need to store it separately.
  int get age {
    if (dateOfBirth.isEmpty) return 0;
    try {
      final parts = dateOfBirth.split('-');
      final dob = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final today = DateTime.now();
      int years = today.year - dob.year;
      if (today.month < dob.month ||
          (today.month == dob.month && today.day < dob.day)) {
        years--;
      }
      return years;
    } catch (_) {
      return 0;
    }
  }

  factory PatientProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PatientProfile(
      id: doc.id,
      name: data['name'] as String? ?? 'Patient',
      dateOfBirth: data['dateOfBirth'] as String? ?? '',
      emergencyContact: data['emergencyContact'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'active',
      caregiverId: data['caregiverId'] as String?,
      uniqueId: data['uniqueId'] as String? ?? '',
      icNumber: data['icNumber'] as String? ?? '',
    );
  }
}

/// Model for patient health data
class PatientHealthData {
  final String elderlyId;
  final String mood;
  final int painLevel;
  final int medicationsTaken;
  final int medicationsTotal;
  final int sosAlerts;
  final DateTime timestamp;

  PatientHealthData({
    required this.elderlyId,
    required this.mood,
    required this.painLevel,
    required this.medicationsTaken,
    required this.medicationsTotal,
    required this.sosAlerts,
    required this.timestamp,
  });

  factory PatientHealthData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PatientHealthData(
      elderlyId: data['elderlyId'] as String? ?? '',
      mood: data['mood'] as String? ?? 'unknown',
      painLevel: data['painLevel'] as int? ?? 0,
      medicationsTaken: data['medicationsTaken'] as int? ?? 0,
      medicationsTotal: data['medicationsTotal'] as int? ?? 0,
      sosAlerts: data['sosAlerts'] as int? ?? 0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Model for medication compliance tracking
class MedicationComplianceData {
  final String name;
  final int daysTotal;
  final int daysTaken;
  final String time;

  MedicationComplianceData({
    required this.name,
    required this.daysTotal,
    required this.daysTaken,
    required this.time,
  });
}

/// Service to handle patient profile and health data operations
class PatientService {
  PatientService._();
  static final PatientService instance = PatientService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final http.Client _httpClient = http.Client();

  /// Get a specific patient profile by ID
  Future<PatientProfile?> getPatientById(String patientId) async {
    try {
      final doc = await _firestore.collection('elderly').doc(patientId).get();
      if (doc.exists) {
        return PatientProfile.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error fetching patient: $e');
    }
    return null;
  }

  /// Get patient profile by their unique ID
  /// Used by caregivers to look up elderly when linking by ID
  Future<PatientProfile?> getPatientByUniqueId(String uniqueId) async {
    try {
      final snapshot =
          await _firestore
              .collection('elderly')
              .where('uniqueId', isEqualTo: uniqueId.toUpperCase())
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        return PatientProfile.fromFirestore(snapshot.docs.first);
      }
    } catch (e) {
      debugPrint('Error fetching patient by unique ID: $e');
    }
    return null;
  }

  /// Get all patients assigned to a caregiver
  Future<List<PatientProfile>> getPatientsByCaregiver(
    String caregiverId,
  ) async {
    try {
      final snapshot =
          await _firestore
              .collection('elderly')
              .where('caregiverId', isEqualTo: caregiverId)
              .get();

      return snapshot.docs
          .map((doc) => PatientProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching patients for caregiver: $e');
      return [];
    }
  }

  /// Stream of patient profiles for a caregiver (real-time updates)
  Stream<List<PatientProfile>> getPatientsByCaregiver$Stream(
    String caregiverId,
  ) {
    return _firestore
        .collection('elderly')
        .where('caregiverId', isEqualTo: caregiverId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => PatientProfile.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Get today's health data for a patient - reads from the `daily_checkins` collection
  /// which is written by CheckinService (used by the elderly check-in screen).
  Future<PatientHealthData?> getTodayHealthData(String patientId) async {
    try {
      final today = DateTime.now();
      // CheckinService uses zero-padded 'YYYY-MM-DD' as the document ID
      final docId =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc =
          await _firestore
              .collection('elderly')
              .doc(patientId)
              .collection('daily_checkins')
              .doc(docId)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        // moodScore: 1=Great, 2=Good, 3=Okay, 4=Not Great
        final moodScore = data['moodScore'] as int? ?? 0;
        final mood = _moodScoreToString(moodScore);

        // Count medications
        final (medsTaken, medsTotal) = await _countTodayMedications(patientId);

        return PatientHealthData(
          elderlyId: patientId,
          mood: mood,
          painLevel: (data['painScore'] as num?)?.toInt() ?? 0,
          medicationsTaken: medsTaken,
          medicationsTotal: medsTotal,
          sosAlerts: 0,
          timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? today,
        );
      }
    } catch (e) {
      debugPrint('Error fetching health data: $e');
    }
    return null;
  }

  /// Count today's medications (taken and total)
  Future<(int taken, int total)> _countTodayMedications(
    String patientId,
  ) async {
    try {
      final today = DateTime.now();

      // Get all medications
      final medsSnap =
          await _firestore
              .collection('elderly')
              .doc(patientId)
              .collection('medications')
              .get();

      int medsTaken = 0;
      final medsTotal = medsSnap.docs.length;

      // Count how many have logs for today
      for (final medDoc in medsSnap.docs) {
        final logsSnap =
            await _firestore
                .collection('elderly')
                .doc(patientId)
                .collection('medications')
                .doc(medDoc.id)
                .collection('logs')
                .where(
                  'timestamp',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(
                    DateTime(today.year, today.month, today.day),
                  ),
                )
                .where(
                  'timestamp',
                  isLessThan: Timestamp.fromDate(
                    DateTime(today.year, today.month, today.day + 1),
                  ),
                )
                .limit(1)
                .get();

        if (logsSnap.docs.isNotEmpty) {
          medsTaken++;
        }
      }

      return (medsTaken, medsTotal);
    } catch (e) {
      debugPrint('Error counting medications: $e');
      return (0, 0);
    }
  }

  /// Convert moodScore (1–4) from CheckinService to a mood string.
  /// 1=Great, 2=Good, 3=Okay, 4=Not Great
  static String _moodScoreToString(int score) => switch (score) {
    1 => 'great',
    2 => 'good',
    3 => 'okay',
    4 => 'sad',
    _ => 'unknown',
  };

  /// Count SOS alerts fired today for a patient.
  Future<int> getTodaySosCount(String patientId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final snap =
          await _firestore
              .collection('elderly')
              .doc(patientId)
              .collection('sos_alerts')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  /// Stream of today's SOS alert count - updates in real-time.
  Stream<int> getTodaySosCount$Stream(String patientId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return _firestore
        .collection('elderly')
        .doc(patientId)
        .collection('sos_alerts')
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Stream of today's health data - listens to the `daily_checkins` collection
  /// and medications to update in real-time when medications are taken.
  Stream<PatientHealthData?> getTodayHealthData$Stream(String patientId) {
    final today = DateTime.now();
    final docId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Create a custom stream that updates when either checkins or medications change
    return Stream.multi((controller) async {
      // Listen to checkins
      final checkinSub = _firestore
          .collection('elderly')
          .doc(patientId)
          .collection('daily_checkins')
          .doc(docId)
          .snapshots()
          .listen((checkinDoc) async {
            if (!checkinDoc.exists) {
              controller.add(null);
              return;
            }

            // Fetch medication counts
            final (medsTaken, medsTotal) = await _countTodayMedications(
              patientId,
            );

            final data = checkinDoc.data()!;
            final moodScore = data['moodScore'] as int? ?? 0;

            controller.add(
              PatientHealthData(
                elderlyId: patientId,
                mood: _moodScoreToString(moodScore),
                painLevel: (data['painScore'] as num?)?.toInt() ?? 0,
                medicationsTaken: medsTaken,
                medicationsTotal: medsTotal,
                sosAlerts: 0,
                timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? today,
              ),
            );
          });

      // Also listen to medications changes to trigger updates
      final medsSub = _firestore
          .collection('elderly')
          .doc(patientId)
          .collection('medications')
          .snapshots()
          .listen((_) async {
            // When medications change, re-fetch checkin and medication counts
            final checkinDoc =
                await _firestore
                    .collection('elderly')
                    .doc(patientId)
                    .collection('daily_checkins')
                    .doc(docId)
                    .get();

            if (!checkinDoc.exists) {
              controller.add(null);
              return;
            }

            final (medsTaken, medsTotal) = await _countTodayMedications(
              patientId,
            );

            final data = checkinDoc.data()!;
            final moodScore = data['moodScore'] as int? ?? 0;

            controller.add(
              PatientHealthData(
                elderlyId: patientId,
                mood: _moodScoreToString(moodScore),
                painLevel: (data['painScore'] as num?)?.toInt() ?? 0,
                medicationsTaken: medsTaken,
                medicationsTotal: medsTotal,
                sosAlerts: 0,
                timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? today,
              ),
            );
          });

      // Clean up subscriptions when stream is cancelled
      controller.onCancel = () {
        checkinSub.cancel();
        medsSub.cancel();
      };
    });
  }

  /// Get activity stream for a patient
  Stream<List<Map<String, dynamic>>> getActivityStream(
    String patientId, {
    int limitDays = 7,
  }) {
    final since = DateTime.now().subtract(Duration(days: limitDays));

    return _firestore
        .collection('elderly')
        .doc(patientId)
        .collection('activity')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Get weekly medication compliance data for a patient
  Future<List<MedicationComplianceData>> getWeeklyMedicationCompliance(
    String patientId, {
    int limitDays = 7,
  }) async {
    try {
      final since = DateTime.now().subtract(Duration(days: limitDays));

      final snapshot =
          await _firestore
              .collection('elderly')
              .doc(patientId)
              .collection('medications')
              .get();

      List<MedicationComplianceData> meds = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final medicationName = data['name'] as String? ?? 'Unknown Medication';
        final dosage = data['dosage'] as String? ?? '';
        final time = data['time'] as String? ?? 'Morning';

        // Count doses in the past week
        final logsSnapshot =
            await _firestore
                .collection('elderly')
                .doc(patientId)
                .collection('medications')
                .doc(doc.id)
                .collection('logs')
                .where(
                  'timestamp',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(since),
                )
                .get();

        int daysTaken =
            logsSnapshot.docs
                .map((d) => (d['timestamp'] as Timestamp).toDate())
                .fold<Set<String>>({}, (set, date) {
                  set.add('${date.year}-${date.month}-${date.day}');
                  return set;
                })
                .length;

        meds.add(
          MedicationComplianceData(
            name: '$medicationName $dosage',
            daysTotal: limitDays,
            daysTaken: daysTaken,
            time: time,
          ),
        );
      }

      return meds;
    } catch (e) {
      debugPrint('Error fetching medication compliance: $e');
      return [];
    }
  }

  /// Log a medication dose taken by the patient
  /// Add a new medication to the patient's medications list.
  Future<String> addMedication(
    String patientId, {
    required String name,
    required String dosage,
    required List<String> times,
    required String frequency,
    String note = '',
  }) async {
    debugPrint(
      'DEBUG: Adding medication to path: elderly/$patientId/medications',
    );
    debugPrint(
      'DEBUG: Medication data: name=$name, dosage=$dosage, times=$times, frequency=$frequency',
    );

    try {
      final docRef = await _firestore
          .collection('elderly')
          .doc(patientId)
          .collection('medications')
          .add({
            'name': name,
            'dosage': dosage,
            'times': times,
            'frequency': frequency,
            'note': note,
            'createdAt': Timestamp.now(),
          });

      debugPrint('DEBUG: Medication added successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('DEBUG: Error adding medication: $e');
      rethrow;
    }
  }

  /// Update an existing medication
  Future<void> updateMedication(
    String patientId,
    String medicationId, {
    required String name,
    required String dosage,
    required List<String> times,
    required String frequency,
    String note = '',
  }) async {
    await _firestore
        .collection('elderly')
        .doc(patientId)
        .collection('medications')
        .doc(medicationId)
        .update({
          'name': name,
          'dosage': dosage,
          'times': times,
          'frequency': frequency,
          'note': note,
          'updatedAt': Timestamp.now(),
        });
  }

  /// Delete a medication and all its logs.
  Future<void> deleteMedication(String patientId, String medicationId) async {
    // Delete the medication doc (logs subcollection is left to Firestore cleanup,
    // which is fine for a demo - subcollections don't block parent deletion)
    await _firestore
        .collection('elderly')
        .doc(patientId)
        .collection('medications')
        .doc(medicationId)
        .delete();
  }

  Future<void> logMedicationDose(String patientId, String medicationId) async {
    try {
      await _firestore
          .collection('elderly')
          .doc(patientId)
          .collection('medications')
          .doc(medicationId)
          .collection('logs')
          .add({'timestamp': Timestamp.now(), 'taken': true});
    } catch (e) {
      debugPrint('Error logging medication dose: $e');
      rethrow;
    }
  }

  /// Save a daily health check-in for the patient
  Future<void> saveCheckin(
    String patientId,
    int moodIndex,
    double painLevel,
    String? notes,
  ) async {
    try {
      final today = DateTime.now();
      final docId = '${today.year}-${today.month}-${today.day}';

      await _firestore
          .collection('elderly')
          .doc(patientId)
          .collection('checkins')
          .doc(docId)
          .set({
            'moodIndex': moodIndex,
            'painLevel': painLevel,
            'notes': notes ?? '',
            'timestamp': Timestamp.now(),
          });
    } catch (e) {
      debugPrint('Error saving check-in: $e');
      rethrow;
    }
  }

  /// Get weekly mood and pain trend data for the past 7 days.
  /// Mood values are inverted (5 - moodScore) so higher bars = better mood in charts.
  Future<Map<String, List<double>>> getWeeklyMoodPainTrends(
    String patientId,
  ) async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));

      final snapshot =
          await _firestore
              .collection('elderly')
              .doc(patientId)
              .collection('daily_checkins')
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(since),
              )
              .orderBy('createdAt')
              .get();

      // Initialize 7 days of data (0 for missing days)
      List<double> moodData = List.filled(7, 0);
      List<double> painData = List.filled(7, 0);

      // Map timestamp to day index (0 = 6 days ago, 6 = today)
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docTimestamp = (data['createdAt'] as Timestamp).toDate();
        final daysAgo = DateTime.now().difference(docTimestamp).inDays;

        if (daysAgo >= 0 && daysAgo < 7) {
          final dayIndex = 6 - daysAgo; // Reverse: 6=today
          final rawMood = (data['moodScore'] as num?)?.toInt() ?? 0;
          // Invert moodScore (1=Great→4, 4=Not Great→1) so chart bars are taller for better mood
          final mood = rawMood > 0 ? (5 - rawMood).toDouble() : 0.0;
          final pain = (data['painScore'] as num?)?.toDouble() ?? 0;

          if (dayIndex >= 0 && dayIndex < 7) {
            moodData[dayIndex] = mood > 0 ? mood : moodData[dayIndex];
            painData[dayIndex] = pain > 0 ? pain : painData[dayIndex];
          }
        }
      }

      return {'mood': moodData, 'pain': painData};
    } catch (e) {
      debugPrint('Error fetching mood/pain trends: $e');
      return {'mood': List.filled(7, 0), 'pain': List.filled(7, 0)};
    }
  }

  /// Get weekly statistics (check-ins count, med adherence %, avg pain, SOS alerts)
  Future<Map<String, dynamic>> getWeeklyStats(String patientId) async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));

      // Count check-ins this week
      final checkinsSnapshot =
          await _firestore
              .collection('elderly')
              .doc(patientId)
              .collection('daily_checkins')
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(since),
              )
              .get();

      final checkinCount = checkinsSnapshot.docs.length;
      final checkinCountStr = '$checkinCount / 7';

      // Calculate medication adherence
      final medsSnapshot =
          await _firestore
              .collection('elderly')
              .doc(patientId)
              .collection('medications')
              .get();

      double adherencePercent = 0;
      if (medsSnapshot.docs.isNotEmpty) {
        int totalDoses = 0;
        int takenDoses = 0;

        for (final medDoc in medsSnapshot.docs) {
          final logsSnapshot =
              await _firestore
                  .collection('elderly')
                  .doc(patientId)
                  .collection('medications')
                  .doc(medDoc.id)
                  .collection('logs')
                  .where(
                    'timestamp',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(since),
                  )
                  .get();

          // Assume 1 dose per day per medication for 7 days
          totalDoses += 7;
          takenDoses += logsSnapshot.docs.length;
        }

        adherencePercent =
            totalDoses > 0 ? (takenDoses / totalDoses * 100).round() / 1 : 0;
      }

      // Calculate average pain
      double avgPain = 0;
      if (checkinsSnapshot.docs.isNotEmpty) {
        double totalPain = 0;
        for (final doc in checkinsSnapshot.docs) {
          totalPain += (doc['painScore'] as num?)?.toDouble() ?? 0;
        }
        avgPain =
            (totalPain / checkinsSnapshot.docs.length) *
            10 /
            10; // Round to 1 decimal
      }

      // Count SOS alerts
      final sosSnapshot =
          await _firestore
              .collection('elderly')
              .doc(patientId)
              .collection('sos_alerts')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(since),
              )
              .get();

      final sosCount = sosSnapshot.docs.length;

      return {
        'checkins': checkinCountStr,
        'adherence': '${adherencePercent.toStringAsFixed(0)}%',
        'avgPain': '${avgPain.toStringAsFixed(1)} / 10',
        'sosAlerts': sosCount.toString(),
      };
    } catch (e) {
      debugPrint('Error fetching weekly stats: $e');
      return {
        'checkins': '0 / 7',
        'adherence': '0%',
        'avgPain': '0 / 10',
        'sosAlerts': '0',
      };
    }
  }

  /// Fetch medication history (logs) for the past 30 days
  Future<List<Map<String, dynamic>>> getMedicationHistory(
    String patientId,
    String medicationId,
  ) async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 30));

      final logsSnapshot =
          await _firestore
              .collection('elderly')
              .doc(patientId)
              .collection('medications')
              .doc(medicationId)
              .collection('logs')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(since),
              )
              .orderBy('timestamp', descending: true)
              .get();

      return logsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
          'taken': data['taken'] ?? true,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching medication history: $e');
      return [];
    }
  }

  /// Fetch drug information from openFDA API
  /// Returns the indications/usage info for the drug
  /// Searches both brand_name and generic_name for better compatibility
  Future<String> fetchDrugInfo(String drugName) async {
    try {
      // Search both brand_name and generic_name for better compatibility
      final Uri url = Uri.parse(
        'https://api.fda.gov/drug/label.json?search=(openfda.brand_name:"$drugName"+OR+openfda.generic_name:"$drugName")&limit=1',
      );

      debugPrint('🔍 Fetching drug info for: $drugName');
      final response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final results = json['results'] as List<dynamic>?;

        if (results != null && results.isNotEmpty) {
          final firstResult = results[0] as Map<String, dynamic>;
          final openfda = firstResult['openfda'] as Map<String, dynamic>?;

          // Try to get indications_and_usage first
          if (openfda != null) {
            final indicationsList =
                openfda['indications_and_usage'] as List<dynamic>?;
            if (indicationsList != null && indicationsList.isNotEmpty) {
              // Get first item from list
              var indication = indicationsList[0];

              // If it's a list, deduplicate and join it; if it's a string, use it directly
              String indicationText;
              if (indication is List) {
                // Deduplicate list items (case-insensitive)
                final uniqueItems = <String>{};
                for (var item in indication) {
                  final itemStr = item.toString().trim();
                  if (itemStr.isNotEmpty) {
                    uniqueItems.add(itemStr);
                  }
                }
                indicationText = uniqueItems.join(' ');
              } else {
                indicationText = indication.toString();
              }

              // Clean HTML tags and entities
              indicationText = indicationText.replaceAll(
                RegExp(r'<[^>]*>'),
                '',
              );
              indicationText = indicationText.replaceAll('&nbsp;', ' ');
              indicationText = indicationText.replaceAll('&quot;', '"');
              indicationText = indicationText.replaceAll('&amp;', '&');

              // Remove duplicate words
              indicationText = _removeDuplicateWords(indicationText);

              // Extract first sentence only (ends with . or \n)
              indicationText = _extractFirstSentence(indicationText);
              debugPrint(
                '\u2705 Found indications_and_usage: ${indicationText.substring(0, indicationText.length > 50 ? 50 : indicationText.length)}...',
              );
              return indicationText;
            }
          }

          // Fallback to purpose field
          final purpose = firstResult['purpose'] as List<dynamic>?;
          if (purpose != null && purpose.isNotEmpty) {
            var purposeItem = purpose[0];

            // If it's a list, deduplicate and join it; if it's a string, use it directly
            String purposeText;
            if (purposeItem is List) {
              // Deduplicate list items (case-insensitive)
              final uniqueItems = <String>{};
              for (var item in purposeItem) {
                final itemStr = item.toString().trim();
                if (itemStr.isNotEmpty) {
                  uniqueItems.add(itemStr);
                }
              }
              purposeText = uniqueItems.join(' ');
            } else {
              purposeText = purposeItem.toString();
            }

            purposeText = purposeText.replaceAll(RegExp(r'<[^>]*>'), '');
            purposeText = _removeDuplicateWords(purposeText);
            purposeText = _extractFirstSentence(purposeText);
            debugPrint(
              '✅ Found purpose field: ${purposeText.substring(0, purposeText.length > 50 ? 50 : purposeText.length)}...',
            );
            return purposeText;
          }
        }

        debugPrint('⚠️ No results found for drug: $drugName');
        return 'Detailed info not found, but please follow your doctor\'s prescription.';
      } else if (response.statusCode == 404) {
        debugPrint('❌ Drug not found in FDA database: $drugName');
        return 'Detailed info not found, but please follow your doctor\'s prescription.';
      }

      debugPrint(
        '❌ API error (${response.statusCode}): Unable to fetch drug information',
      );
      return 'Unable to fetch information. Please follow your doctor\'s prescription.';
    } catch (e) {
      debugPrint('❌ Error fetching drug info: $e');
      return 'Unable to fetch information. Please follow your doctor\'s prescription.';
    }
  }

  /// Remove duplicate phrases and consecutive words
  String _removeDuplicateWords(String text) {
    // Remove common FDA headers/labels (case-insensitive)
    text = text.replaceAll(RegExp(r'^purposes?\s+', caseSensitive: false), '');
    text = text.replaceAll(
      RegExp(r'^indications?\s+', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'^purpose[s]?:?\s*', caseSensitive: false),
      '',
    );

    // First, split by common delimiters to get the first meaningful phrase
    final delimiter = RegExp(r'[.;:\--]');
    final parts = text.split(delimiter);
    final firstPart = parts.isNotEmpty ? parts[0].trim() : '';

    if (firstPart.isEmpty) {
      return text;
    }

    // Now remove consecutive duplicate words from the first part
    final words = firstPart.split(RegExp(r'\s+'));
    final uniqueWords = <String>[];
    String? previousWord;

    for (var word in words) {
      final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (cleanWord.isNotEmpty && cleanWord != previousWord?.toLowerCase()) {
        uniqueWords.add(word);
        previousWord = cleanWord;
      }
    }

    return uniqueWords.join(' ');
  }

  /// Extract only the first sentence from text
  String _extractFirstSentence(String text) {
    text = text.trim();
    if (text.isEmpty) return text;

    // Split by period or newline, take first part
    final firstSentence = text.split(RegExp(r'[.\n]')).first.trim();
    if (firstSentence.isEmpty) return text; // Fallback if no period found

    // Add period back if it doesn't end with one
    if (!firstSentence.endsWith('.')) {
      return '$firstSentence.';
    }
    return firstSentence;
  }
}
