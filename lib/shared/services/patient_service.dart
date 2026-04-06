import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for elderly patient data
class PatientProfile {
  final String id;
  final String name;
  final int age;
  final String? photoUrl;
  final DateTime lastSeen;
  final String status; // 'active', 'inactive', etc.
  final String? caregiverId;

  PatientProfile({
    required this.id,
    required this.name,
    required this.age,
    this.photoUrl,
    required this.lastSeen,
    required this.status,
    this.caregiverId,
  });

  factory PatientProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PatientProfile(
      id: doc.id,
      name: data['name'] as String? ?? 'Patient',
      age: data['age'] as int? ?? 0,
      photoUrl: data['photoUrl'] as String?,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'unknown',
      caregiverId: data['caregiverId'] as String?,
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
      print('Error fetching patient: $e');
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
      print('Error fetching patients for caregiver: $e');
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

  /// Get today's health data for a patient
  Future<PatientHealthData?> getTodayHealthData(String patientId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('elderly')
          .doc(patientId)
          .collection('health_data')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return PatientHealthData.fromFirestore(snapshot.docs.first);
      }
    } catch (e) {
      print('Error fetching health data: $e');
    }
    return null;
  }

  /// Stream of health data for a patient (real-time updates)
  Stream<PatientHealthData?> getTodayHealthData$Stream(String patientId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('elderly')
        .doc(patientId)
        .collection('health_data')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.isNotEmpty
                ? PatientHealthData.fromFirestore(snapshot.docs.first)
                : null);
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
}
