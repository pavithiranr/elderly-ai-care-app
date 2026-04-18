/// Medication model with support for multiple times per day and frequency.
class Medication {
  final String id;
  final String name;
  final String dosage;
  final List<String> times; // e.g., ["08:00", "20:00"]
  final String frequency; // "Daily", "Every Other Day", "Weekly"
  final String note;
  final DateTime createdAt;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.times,
    required this.frequency,
    required this.note,
    required this.createdAt,
  });

  /// Convert Medication to Firestore-compatible Map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'dosage': dosage,
      'times': times,
      'frequency': frequency,
      'note': note,
      'createdAt': createdAt,
    };
  }

  /// Convert Firestore document to Medication
  factory Medication.fromFirestore(String id, Map<String, dynamic> data) {
    return Medication(
      id: id,
      name: data['name'] as String? ?? 'Unknown',
      dosage: data['dosage'] as String? ?? '',
      times: List<String>.from(data['times'] as List<dynamic>? ?? []),
      frequency: data['frequency'] as String? ?? 'Daily',
      note: data['note'] as String? ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Map for display (backward compatibility)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'times': times,
      'frequency': frequency,
      'note': note,
      'createdAt': createdAt,
    };
  }

  /// Create a copy with modified fields
  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    List<String>? times,
    String? frequency,
    String? note,
    DateTime? createdAt,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      times: times ?? this.times,
      frequency: frequency ?? this.frequency,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
