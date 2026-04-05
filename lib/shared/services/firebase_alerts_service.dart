import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Represents an alert with all necessary fields.
class AlertModel {
  final String id;
  final String severity;
  final String type;
  final String body;
  final DateTime timestamp;
  final bool isUnread;
  final String? elderlyId;

  AlertModel({
    required this.id,
    required this.severity,
    required this.type,
    required this.body,
    required this.timestamp,
    required this.isUnread,
    this.elderlyId,
  });

  /// Convert from Firestore document to AlertModel.
  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id: doc.id,
      severity: data['severity'] as String? ?? 'info',
      type: data['type'] as String? ?? '',
      body: data['body'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isUnread: data['isUnread'] as bool? ?? false,
      elderlyId: data['elderlyId'] as String?,
    );
  }

  /// Convert to Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'severity': severity,
      'type': type,
      'body': body,
      'timestamp': Timestamp.fromDate(timestamp),
      'isUnread': isUnread,
      'elderlyId': elderlyId,
    };
  }
}

/// Represents a group of alerts by date.
class AlertGroup {
  final String dateLabel;
  final List<AlertModel> alerts;

  AlertGroup({required this.dateLabel, required this.alerts});
}

/// Service to handle Firebase alerts operations.
class FirebaseAlertsService {
  FirebaseAlertsService._();
  static final FirebaseAlertsService instance = FirebaseAlertsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream alerts for a specific caregiver, grouped by date.
  /// Fetches from 'caregiver_alerts/{caregiverId}/alerts' collection.
  Stream<List<AlertGroup>> getAlertsStream(String caregiverId, {int limitDays = 30}) {
    return _firestore
        .collection('caregiver_alerts')
        .doc(caregiverId)
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final alerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
      return _groupAlertsByDate(alerts);
    });
  }

  /// Group alerts by date (Today, Yesterday, etc.)
  static List<AlertGroup> _groupAlertsByDate(List<AlertModel> alerts) {
    final grouped = <String, List<AlertModel>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final alert in alerts) {
      final alertDate = DateTime(
        alert.timestamp.year,
        alert.timestamp.month,
        alert.timestamp.day,
      );

      String dateLabel;
      if (alertDate == today) {
        dateLabel = 'Today';
      } else if (alertDate == yesterday) {
        dateLabel = 'Yesterday';
      } else {
        dateLabel = DateFormat('MMMM d, yyyy').format(alert.timestamp);
      }

      grouped.putIfAbsent(dateLabel, () => []).add(alert);
    }

    // Convert to AlertGroup list in order
    return grouped.entries
        .map((entry) => AlertGroup(dateLabel: entry.key, alerts: entry.value))
        .toList();
  }

  /// Mark a specific alert as read.
  Future<void> markAsRead(String caregiverId, String alertId) async {
    await _firestore
        .collection('caregiver_alerts')
        .doc(caregiverId)
        .collection('alerts')
        .doc(alertId)
        .update({'isUnread': false});
  }

  /// Mark all alerts as read for a caregiver.
  Future<void> markAllAsRead(String caregiverId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('caregiver_alerts')
        .doc(caregiverId)
        .collection('alerts')
        .where('isUnread', isEqualTo: true)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isUnread': false});
    }

    await batch.commit();
  }

  /// Delete an alert.
  Future<void> deleteAlert(String caregiverId, String alertId) async {
    await _firestore
        .collection('caregiver_alerts')
        .doc(caregiverId)
        .collection('alerts')
        .doc(alertId)
        .delete();
  }

  /// Clear all alerts for a caregiver (use with caution).
  Future<void> clearAllAlerts(String caregiverId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('caregiver_alerts')
        .doc(caregiverId)
        .collection('alerts')
        .get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
