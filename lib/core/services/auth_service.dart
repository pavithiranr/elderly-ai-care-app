import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/user_model.dart';

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
  }) async {
    try {
      print('🔐 Starting caregiver signup for email: $email');
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;
      print('✅ Firebase Auth user created: $uid');

      // Store caregiver profile in Firestore
      print('📝 Writing caregiver profile to Firestore...');
      await _firestore.collection('caregivers').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'role': 'caregiver',
        'linkedElderlyIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Caregiver profile saved successfully');

      return uid;
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ General Exception: $e');
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

  /// Create an elderly profile (first-time setup, no password required)
  /// Generates a random UID for the elderly user
  /// Returns binding code to share with caregiver
  Future<String> elderlySetup({
    required String name,
    required String dateOfBirth, // e.g., "1945-03-15"
    required String emergencyContact,
  }) async {
    try {
      // Generate a custom UID for elderly (can also use auto-generated)
      final elderlyUid = _firestore.collection('elderly').doc().id;
      final bindingCode = _generateBindingCode();
      final uniqueId = _generateUniqueId();

      // Create elderly profile in Firestore
      await _firestore.collection('elderly').doc(elderlyUid).set({
        'uid': elderlyUid,
        'name': name,
        'dateOfBirth': dateOfBirth,
        'emergencyContact': emergencyContact,
        'uniqueId': uniqueId, // Add the unique ID for binding
        'role': 'elderly',
        'linkedCaregiver': null, // Will be set after binding
        'bindingCode': bindingCode,
        'bindingCodeExpiresAt': DateTime.now().add(const Duration(hours: 24)),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return bindingCode;
    } catch (e) {
      throw Exception('Failed to setup elderly profile: $e');
    }
  }

  /// Verify and use a binding code to link elderly to caregiver
  /// Called by caregiver when entering binding code
  Future<void> linkElderlyToCaregiver({
    required String bindingCode,
    required String caregiverUid,
  }) async {
    try {
      // Find elderly by binding code
      final querySnapshot = await _firestore
          .collection('elderly')
          .where('bindingCode', isEqualTo: bindingCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Invalid binding code');
      }

      final elderlyDoc = querySnapshot.docs.first;
      final elderlyUid = elderlyDoc.id;
      final bindingCodeExpiresAt =
          (elderlyDoc['bindingCodeExpiresAt'] as Timestamp).toDate();

      // Check if binding code is expired
      if (DateTime.now().isAfter(bindingCodeExpiresAt)) {
        throw Exception('Binding code has expired. Please generate a new one.');
      }

      // Check if already linked
      if (elderlyDoc['linkedCaregiver'] != null) {
        throw Exception('This elderly is already linked to a caregiver.');
      }

      // Link elderly to caregiver
      await _firestore.collection('elderly').doc(elderlyUid).update({
        'linkedCaregiver': caregiverUid,
        'bindingCode': FieldValue.delete(), // Remove binding code after use
        'bindingCodeExpiresAt': FieldValue.delete(),
      });

      // Add elderly to caregiver's linked list
      await _firestore.collection('caregivers').doc(caregiverUid).update({
        'linkedElderlyIds': FieldValue.arrayUnion([elderlyUid])
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
      print('Error verifying elderly setup code: $e');
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
      print('Error fetching elderly profile data: $e');
      return null;
    }
  }

  // ─── Helper Methods ────────────────────────────────────────────────

  /// Generate a random 6-character binding code
  String _generateBindingCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().microsecond;
    String code = '';

    for (int i = 0; i < 6; i++) {
      code += chars[(random + i) % chars.length];
    }

    return code;
  }

  /// Generate an 8-character unique ID for elderly binding
  /// Uses alphanumeric characters, excluding confusing ones (O, I, 0, 1)
  /// Example: "A7K3M2P9" or "B4Q8N1R6"
  String _generateUniqueId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluded O, I, 0, 1
    final random = Random();
    String id = '';

    for (int i = 0; i < 8; i++) {
      id += chars[random.nextInt(chars.length)];
    }

    return id;
  }

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
