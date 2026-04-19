import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/user_model.dart';
import 'logging_service.dart';

/// Centralized Firebase Authentication Service
/// Handles caregiver auth (email/password) and elderly setup (no password)
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Caregiver Authentication ───────────────────────────────────────

  /// Sign up a new caregiver with email and password
  /// Returns the caregiver UID on success
  Future<String> caregiverSignUp({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
  }) async {
    try {
      logger.debug('Starting caregiver signup for email: $email');

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;
      logger.success('Firebase Auth user created: $uid');

      logger.info('Writing caregiver profile to Firestore...');
      await _firestore.collection('caregivers').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'role': 'caregiver',
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
        'linkedElderlyIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      logger.success('Caregiver profile saved successfully');

      return uid;
    } on FirebaseAuthException catch (e) {
      logger.error('FirebaseAuthException: ${e.code} - ${e.message}', e);
      throw _handleAuthException(e);
    } catch (e) {
      logger.error('General Exception in caregiverSignUp', e);
      throw Exception('Signup failed: $e');
    }
  }

  /// Sign in an existing caregiver with email and password
  /// Returns the caregiver UID on success
  Future<String> caregiverSignIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ─── Elderly Setup (No Password) ────────────────────────────────────

  /// Create an elderly profile (first-time setup, no password required).
  /// IC number is used as the permanent link key — caregivers enter it to connect.
  Future<String> elderlySetup({
    required String name,
    required String dateOfBirth, // e.g., "1945-03-15"
    required String emergencyContact,
    required String icNumber, // 12 digits, stored without dashes
  }) async {
    try {
      final elderlyUid = _firestore.collection('elderly').doc().id;

      // Check for duplicate IC number
      final existing = await _firestore
          .collection('elderly')
          .where('icNumber', isEqualTo: icNumber)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        throw Exception('A profile with this IC number already exists.');
      }

      await _firestore.collection('elderly').doc(elderlyUid).set({
        'uid': elderlyUid,
        'name': name,
        'dateOfBirth': dateOfBirth,
        'emergencyContact': emergencyContact,
        'icNumber': icNumber,
        'role': 'elderly',
        'caregiverId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return elderlyUid;
    } catch (e) {
      throw Exception('Failed to setup elderly profile: $e');
    }
  }

  /// Link an elderly profile to a caregiver using the elderly's IC number.
  /// Called by the caregiver after the elderly shares their IC.
  Future<void> linkElderlyByIC({
    required String icNumber,
    required String caregiverUid,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('elderly')
          .where('icNumber', isEqualTo: icNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('No profile found with that IC number.');
      }

      final elderlyDoc = querySnapshot.docs.first;
      final elderlyUid = elderlyDoc.id;

      if (elderlyDoc['caregiverId'] != null) {
        throw Exception('This profile is already linked to a caregiver.');
      }

      await _firestore.collection('elderly').doc(elderlyUid).update({
        'caregiverId': caregiverUid,
      });

      await _firestore.collection('caregivers').doc(caregiverUid).update({
        'linkedElderlyIds': FieldValue.arrayUnion([elderlyUid]),
      });
    } catch (e) {
      throw Exception('Failed to link elderly: $e');
    }
  }

  // ─── Get Current Auth State ────────────────────────────────────────

  /// Get the currently authenticated user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _auth.currentUser != null;
  }

  /// Get current user's UID
  String? getCurrentUserUid() {
    return _auth.currentUser?.uid;
  }

  // ─── Logout ────────────────────────────────────────────────────────

  /// Sign out the current user (caregiver or elderly)
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to logout: $e');
    }
  }

  // ─── Fetch User Profiles ───────────────────────────────────────────

  /// Fetch caregiver profile by UID
  Future<UserModel?> getCaregiverProfile(String caregiverUid) async {
    try {
      final doc =
          await _firestore.collection('caregivers').doc(caregiverUid).get();

      if (!doc.exists) return null;

      return UserModel(
        id: doc['uid'],
        name: doc['name'],
        role: UserRole.caregiver,
        avatarUrl: doc['avatarUrl'] as String?,
      );
    } catch (e) {
      throw Exception('Failed to fetch caregiver profile: $e');
    }
  }

  /// Fetch elderly profile by UID
  Future<UserModel?> getElderlyProfile(String elderlyUid) async {
    try {
      final doc = await _firestore.collection('elderly').doc(elderlyUid).get();

      if (!doc.exists) return null;

      return UserModel(
        id: doc['uid'],
        name: doc['name'],
        role: UserRole.elderly,
        avatarUrl: doc['avatarUrl'] as String?,
      );
    } catch (e) {
      throw Exception('Failed to fetch elderly profile: $e');
    }
  }

  /// Verify setup code for existing elderly profile (for re-login)
  /// Returns the elderly UID if code is valid, null if not found
  Future<String?> verifyElderlySetupCode(String bindingCode) async {
    try {
      // Look up elderly by binding code
      final querySnapshot = await _firestore
          .collection('elderly')
          .where('bindingCode', isEqualTo: bindingCode.toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final elderlyDoc = querySnapshot.docs.first;
      return elderlyDoc.id;
    } catch (e) {
      logger.error('Error verifying elderly setup code', e);
      return null;
    }
  }

  /// Find an elderly profile by IC number (used for re-login).
  /// Returns the elderly UID if found, null otherwise.
  Future<String?> findElderlyByIC(String icNumber) async {
    try {
      final snapshot = await _firestore
          .collection('elderly')
          .where('icNumber', isEqualTo: icNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.id;
    } catch (e) {
      logger.error('Error finding elderly by IC', e);
      return null;
    }
  }

  /// Find an elderly profile by name + date of birth (used for re-login).
  /// Returns the elderly UID if found, null otherwise.
  Future<String?> findElderlyByNameAndDOB({
    required String name,
    required String dateOfBirth, // "YYYY-MM-DD"
  }) async {
    try {
      // Query by DOB first (narrow the set), then match name in memory
      final snapshot = await _firestore
          .collection('elderly')
          .where('dateOfBirth', isEqualTo: dateOfBirth)
          .get();

      final nameLower = name.trim().toLowerCase();
      for (final doc in snapshot.docs) {
        final storedName = (doc['name'] as String? ?? '').trim().toLowerCase();
        if (storedName == nameLower) {
          return doc.id;
        }
      }
      return null;
    } catch (e) {
      logger.error('Error finding elderly by name and DOB', e);
      return null;
    }
  }

  /// Get elderly profile by UID for restoration
  Future<Map<String, dynamic>?> getElderlyProfileData(String elderlyUid) async {
    try {
      final doc = await _firestore.collection('elderly').doc(elderlyUid).get();

      if (!doc.exists) return null;

      return doc.data();
    } catch (e) {
      logger.error('Error fetching elderly profile data', e);
      return null;
    }
  }

  // ─── Helper Methods ────────────────────────────────────────────────

/// Handle Firebase Auth exceptions and return user-friendly messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'operation-not-allowed':
        return 'Email/password authentication is not enabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}
