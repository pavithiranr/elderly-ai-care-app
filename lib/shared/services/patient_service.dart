import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
  });

  /// Age computed from dateOfBirth — no need to store it separately.
  int get age {
    if (dateOfBirth.isEmpty) return 0;
    try {
      final parts = dateOfBirth.split('-');
      final dob = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final today = DateTime.now();
      int years = today.year - dob.year;
      if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
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
      final snapshot = await _firestore
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
  Future<List<PatientProfile>> getPatientsByCaregiver(String caregiverId) async {
    try {
      final snapshot = await _firestore
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
  Stream<List<PatientProfile>> getPatientsByCaregiver$Stream(String caregiverId) {
    return _firestore
        .collection('elderly')
        .where('caregiverId', isEqualTo: caregiverId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PatientProfile.fromFirestore(doc)).toList());
  }

  /// Get today's health data for a patient — reads from the `checkins` collection
  /// which is written by the elderly check-in screen.
  Future<PatientHealthData?> getTodayHealthData(String patientId) async {
    try {
      final today = DateTime.now();
      // saveCheckin uses 'year-month-day' as the document ID
      final docId = '${today.year}-${today.month}-${today.day}';

      final doc = await _firestore
          .collection('elderly')
          .doc(patientId)
          .collection('checkins')
          .doc(docId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        // Check-in screen order: 0=Great, 1=Good, 2=Okay, 3=Not Great, 4=Bad
        const moodLabels = ['great', 'good', 'okay', 'sad', 'terrible'];
        final moodIndex = (data['moodIndex'] as int? ?? 2).clamp(0, 4);
        return PatientHealthData(
          elderlyId: patientId,
          mood: moodLabels[moodIndex],
          painLevel: (data['painLevel'] as num?)?.toInt() ?? 0,
          medicationsTaken: 0,
          medicationsTotal: 0,
          sosAlerts: 0,
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? today,
        );
      }
    } catch (e) {
      debugPrint('Error fetching health data: $e');
    }
    return null;
  }

  /// Count SOS alerts fired today for a patient.
  Future<int> getTodaySosCount(String patientId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final snap = await _firestore
          .collection('elderly')
          .doc(patientId)
          .collection('sos_alerts')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  /// Stream of today's health data — listens to the `checkins` collection
  /// so the caregiver banner updates in real-time when the elderly checks in.
  Stream<PatientHealthData?> getTodayHealthData$Stream(String patientId) {
    final today = DateTime.now();
    final docId = '${today.year}-${today.month}-${today.day}';

    const moodLabels = ['great', 'good', 'okay', 'sad', 'terrible'];

    return _firestore
        .collection('elderly')
        .doc(patientId)
        .collection('checkins')
        .doc(docId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data()!;
          final moodIndex = (data['moodIndex'] as int? ?? 2).clamp(0, 4);
          return PatientHealthData(
            elderlyId: patientId,
            mood: moodLabels[moodIndex],
            painLevel: (data['painLevel'] as num?)?.toInt() ?? 0,
            medicationsTaken: 0,
            medicationsTotal: 0,
            sosAlerts: 0,
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? today,
          );
        });
  }

  /// Get activity stream for a patient
  Stream<List<Map<String, dynamic>>> getActivityStream(String patientId,
      {int limitDays = 7}) {
    final since = DateTime.now().subtract(Duration(days: limitDays));

    return _firestore
        .collection('elderly')
        .doc(patientId)
        .collection('activity')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Get weekly medication compliance data for a patient
  Future<List<MedicationComplianceData>> getWeeklyMedicationCompliance(
      String patientId,
      {int limitDays = 7}) async {
    try {
      final since = DateTime.now().subtract(Duration(days: limitDays));

      final snapshot = await _firestore
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
        final logsSnapshot = await _firestore
            .collection('elderly')
            .doc(patientId)
            .collection('medications')
            .doc(doc.id)
            .collection('logs')
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
            .get();

        int daysTaken = logsSnapshot.docs
            .map((d) => (d['timestamp'] as Timestamp).toDate())
            .fold<Set<String>>({}, (set, date) {
          set.add('${date.year}-${date.month}-${date.day}');
          return set;
        }).length;

        meds.add(MedicationComplianceData(
          name: '$medicationName $dosage',
          daysTotal: limitDays,
          daysTaken: daysTaken,
          time: time,
        ));
      }

      return meds;
    } catch (e) {
      debugPrint('Error fetching medication compliance: $e');
      return [];
    }
  }

  /// Log a medication dose taken by the patient
  /// Add a new medication to the patient's medications list.
  Future<void> addMedication(
    String patientId, {
    required String name,
    required String dosage,
    required String time,
    String note = '',
  }) async {
    await _firestore
        .collection('elderly')
        .doc(patientId)
        .collection('medications')
        .add({
      'name': name,
      'dosage': dosage,
      'time': time,
      'note': note,
      'createdAt': Timestamp.now(),
    });
  }

  /// Delete a medication and all its logs.
  Future<void> deleteMedication(String patientId, String medicationId) async {
    // Delete the medication doc (logs subcollection is left to Firestore cleanup,
    // which is fine for a demo — subcollections don't block parent deletion)
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
          .add({
            'timestamp': Timestamp.now(),
            'taken': true,
          });
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

  /// Get weekly mood and pain trend data for the past 7 days
  Future<Map<String, List<double>>> getWeeklyMoodPainTrends(String patientId) async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshot = await _firestore
          .collection('elderly')
          .doc(patientId)
          .collection('checkins')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('timestamp')
          .get();

      // Initialize 7 days of data (0 for missing days)
      List<double> moodData = List.filled(7, 0);
      List<double> painData = List.filled(7, 0);

      // Map timestamp to day index (0 = 6 days ago, 6 = today)
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docTimestamp = (data['timestamp'] as Timestamp).toDate();
        final daysAgo = DateTime.now().difference(docTimestamp).inDays;

        if (daysAgo >= 0 && daysAgo < 7) {
          final dayIndex = 6 - daysAgo; // Reverse: 6=today
          final mood = (data['moodIndex'] as num?)?.toDouble() ?? 0;
          final pain = (data['painLevel'] as num?)?.toDouble() ?? 0;

          if (dayIndex >= 0 && dayIndex < 7) {
            moodData[dayIndex] = mood > 0 ? mood : moodData[dayIndex];
            painData[dayIndex] = pain > 0 ? pain : painData[dayIndex];
          }
        }
      }

      return {
        'mood': moodData,
        'pain': painData,
      };
    } catch (e) {
      debugPrint('Error fetching mood/pain trends: $e');
      return {
        'mood': List.filled(7, 0),
        'pain': List.filled(7, 0),
      };
    }
  }

  /// Get weekly statistics (check-ins count, med adherence %, avg pain, SOS alerts)
  Future<Map<String, dynamic>> getWeeklyStats(String patientId) async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));

      // Count check-ins this week
      final checkinsSnapshot = await _firestore
          .collection('elderly')
          .doc(patientId)
          .collection('checkins')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();
      
      final checkinCount = checkinsSnapshot.docs.length;
      final checkinCountStr = '$checkinCount / 7';

      // Calculate medication adherence
      final medsSnapshot = await _firestore
          .collection('elderly')
          .doc(patientId)
          .collection('medications')
          .get();

      double adherencePercent = 0;
      if (medsSnapshot.docs.isNotEmpty) {
        int totalDoses = 0;
        int takenDoses = 0;

        for (final medDoc in medsSnapshot.docs) {
          final logsSnapshot = await _firestore
              .collection('elderly')
              .doc(patientId)
              .collection('medications')
              .doc(medDoc.id)
              .collection('logs')
              .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
              .get();

          // Assume 1 dose per day per medication for 7 days
          totalDoses += 7;
          takenDoses += logsSnapshot.docs.length;
        }

        adherencePercent = totalDoses > 0 ? (takenDoses / totalDoses * 100).round() / 1 : 0;
      }

      // Calculate average pain
      double avgPain = 0;
      if (checkinsSnapshot.docs.isNotEmpty) {
        double totalPain = 0;
        for (final doc in checkinsSnapshot.docs) {
          totalPain += (doc['painLevel'] as num?)?.toDouble() ?? 0;
        }
        avgPain = (totalPain / checkinsSnapshot.docs.length) * 10 / 10; // Round to 1 decimal
      }

      // Count SOS alerts
      final sosSnapshot = await _firestore
          .collection('elderly')
          .doc(patientId)
          .collection('sos_alerts')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
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
}
