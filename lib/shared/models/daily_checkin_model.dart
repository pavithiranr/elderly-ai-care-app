import 'package:cloud_firestore/cloud_firestore.dart';

/// Raw check-in data submitted by elderly user
class DailyCheckin {
  final String id;
  final String userId;
  final String checkInDate; // "YYYY-MM-DD" - prevents duplicates on same day
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isUpdated;

  // ━━━━━ Raw Responses ━━━━━
  final int moodScore; // 1-4 (😞 😐 🙂 😄)
  final String moodText; // Voice transcription or manual text
  final int painScore; // 1-10 scale
  final String painLocation; // e.g. "left knee"
  final String painDescription; // Voice transcription
  final String dailyPlan; // What they're planning to do
  final String? additionalNotes;

  DailyCheckin({
    required this.id,
    required this.userId,
    required this.checkInDate,
    required this.createdAt,
    this.updatedAt,
    this.isUpdated = false,
    required this.moodScore,
    required this.moodText,
    required this.painScore,
    required this.painLocation,
    required this.painDescription,
    required this.dailyPlan,
    this.additionalNotes,
  });

  factory DailyCheckin.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyCheckin(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      checkInDate: data['checkInDate'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isUpdated: data['isUpdated'] as bool? ?? false,
      moodScore: data['moodScore'] as int? ?? 0,
      moodText: data['moodText'] as String? ?? '',
      painScore: data['painScore'] as int? ?? 0,
      painLocation: data['painLocation'] as String? ?? '',
      painDescription: data['painDescription'] as String? ?? '',
      dailyPlan: data['dailyPlan'] as String? ?? '',
      additionalNotes: data['additionalNotes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'checkInDate': checkInDate,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isUpdated': isUpdated,
      'moodScore': moodScore,
      'moodText': moodText,
      'painScore': painScore,
      'painLocation': painLocation,
      'painDescription': painDescription,
      'dailyPlan': dailyPlan,
      'additionalNotes': additionalNotes,
    };
  }
}

/// AI-generated summary from Gemini
class GeminiSummary {
  final String id;
  final String checkInId;
  final DateTime generatedAt;
  final String statusColor; // "green" | "yellow" | "red"
  final String oneSentenceSummary;
  final String caregiverAction;
  final double sentimentScore; // 0-1 for graphing
  final String riskLevel; // "low" | "medium" | "high"
  final List<String> keyInsights;
  final int version;

  GeminiSummary({
    required this.id,
    required this.checkInId,
    required this.generatedAt,
    required this.statusColor,
    required this.oneSentenceSummary,
    required this.caregiverAction,
    required this.sentimentScore,
    required this.riskLevel,
    required this.keyInsights,
    this.version = 1,
  });

  factory GeminiSummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GeminiSummary(
      id: doc.id,
      checkInId: data['checkInId'] as String? ?? '',
      generatedAt:
          (data['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      statusColor: data['statusColor'] as String? ?? 'green',
      oneSentenceSummary: data['oneSentenceSummary'] as String? ?? '',
      caregiverAction:
          data['caregiver_action'] as String? ?? 'No action needed',
      sentimentScore: (data['sentimentScore'] as num?)?.toDouble() ?? 0.5,
      riskLevel: data['riskLevel'] as String? ?? 'low',
      keyInsights: List<String>.from(data['keyInsights'] as List? ?? []),
      version: data['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'checkInId': checkInId,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'statusColor': statusColor,
      'oneSentenceSummary': oneSentenceSummary,
      'caregiver_action': caregiverAction,
      'sentimentScore': sentimentScore,
      'riskLevel': riskLevel,
      'keyInsights': keyInsights,
      'version': version,
    };
  }

  /// Color for UI display
  static const Map<String, int> colorMap = {
    'green': 0xFF66BB6A, // Material Green
    'yellow': 0xFFFDD835, // Material Amber
    'red': 0xFFEF5350, // Material Red
  };

  int getUiColor() => colorMap[statusColor] ?? 0xFF66BB6A;
}

/// Caregiver-specific settings for this patient's check-ins
class CaregiverCheckinSettings {
  final String caregiverId;
  final String patientId;
  final String nudgeTime; // "11:00" (24-hour format)
  final bool enableNudgeAlert;
  final String notificationChannel; // "SMS" | "push" | "email"
  final String timezone; // e.g. "Asia/Kuala_Lumpur"

  CaregiverCheckinSettings({
    required this.caregiverId,
    required this.patientId,
    required this.nudgeTime,
    required this.enableNudgeAlert,
    required this.notificationChannel,
    required this.timezone,
  });

  factory CaregiverCheckinSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CaregiverCheckinSettings(
      caregiverId: data['caregiverId'] as String? ?? '',
      patientId: data['patientId'] as String? ?? '',
      nudgeTime: data['nudgeTime'] as String? ?? '11:00',
      enableNudgeAlert: data['enableNudgeAlert'] as bool? ?? true,
      notificationChannel: data['notificationChannel'] as String? ?? 'push',
      timezone: data['timezone'] as String? ?? 'UTC',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'caregiverId': caregiverId,
      'patientId': patientId,
      'nudgeTime': nudgeTime,
      'enableNudgeAlert': enableNudgeAlert,
      'notificationChannel': notificationChannel,
      'timezone': timezone,
    };
  }
}
