import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Model for caregiver profile data
class CaregiverProfile {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? profilePhotoUrl;
  final List<String> linkedElderlyIds;

  CaregiverProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.profilePhotoUrl,
    this.linkedElderlyIds = const [],
  });

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  factory CaregiverProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CaregiverProfile(
      id: doc.id,
      name: data['name'] as String? ?? 'Caregiver',
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      profilePhotoUrl: data['profilePhotoUrl'] as String?,
      linkedElderlyIds: List<String>.from(data['linkedElderlyIds'] as List<dynamic>? ?? []),
    );
  }
}

/// Service to handle caregiver profile operations
class CaregiverService {
  CaregiverService._();
  static final CaregiverService instance = CaregiverService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current caregiver profile from Firebase Auth and Firestore
  Future<CaregiverProfile?> getCurrentCaregiverProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // Try to get profile from Firestore first
      final doc = await _firestore.collection('caregivers').doc(user.uid).get();

      if (doc.exists) {
        return CaregiverProfile.fromFirestore(doc);
      }

      // Fallback: create from Firebase Auth
      return CaregiverProfile(
        id: user.uid,
        name: user.displayName ?? 'Caregiver',
        email: user.email ?? '',
        phoneNumber: user.phoneNumber,
        profilePhotoUrl: user.photoURL,
      );
    } catch (e) {
      print('Error fetching caregiver profile: $e');
      return null;
    }
  }

  /// Get caregiver name from display name or Firestore
  Future<String?> getCaregiverName() async {
    final profile = await getCurrentCaregiverProfile();
    return profile?.name;
  }

  /// Get caregiver initial from display name
  Future<String?> getCaregiverInitial() async {
    final profile = await getCurrentCaregiverProfile();
    return profile?.initial;
  }

  /// Save or update caregiver profile
  Future<void> saveCaregiverProfile(CaregiverProfile profile) async {
    try {
      await _firestore.collection('caregivers').doc(profile.id).set({
        'name': profile.name,
        'email': profile.email,
        'phoneNumber': profile.phoneNumber,
        'profilePhotoUrl': profile.profilePhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving caregiver profile: $e');
      rethrow;
    }
  }

  /// Update specific caregiver profile fields
  Future<void> updateCaregiverProfile({
    required String uid,
    String? name,
    String? phoneNumber,
    String? profilePhotoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (profilePhotoUrl != null) updates['profilePhotoUrl'] = profilePhotoUrl;

      await _firestore.collection('caregivers').doc(uid).update(updates);
    } catch (e) {
      print('Error updating caregiver profile: $e');
      rethrow;
    }
  }

  /// Get linked elderly count for a caregiver
  Future<int> getLinkedElderlyCount(String caregiverId) async {
    try {
      final doc = await _firestore.collection('caregivers').doc(caregiverId).get();
      if (!doc.exists) return 0;
      final linkedIds = doc['linkedElderlyIds'] as List<dynamic>? ?? [];
      return linkedIds.length;
    } catch (e) {
      print('Error getting linked elderly count: $e');
      return 0;
    }
  }

  /// Unlink an elderly from caregiver
  /// Removes elderly ID from caregiver's linkedElderlyIds list
  Future<void> unlinkElderly({
    required String elderlyId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Remove elderly from caregiver's linkedElderlyIds
      await _firestore.collection('caregivers').doc(currentUser.uid).update({
        'linkedElderlyIds': FieldValue.arrayRemove([elderlyId])
      });

      // Remove caregiver link from elderly profile
      await _firestore.collection('elderly').doc(elderlyId).update({
        'linkedCaregiver': FieldValue.delete(),
      });

      print('✅ Unlocked elderly: $elderlyId');
    } catch (e) {
      print('❌ Error unlinking elderly: $e');
      throw Exception('Failed to unlink elderly: $e');
    }
  }
}
